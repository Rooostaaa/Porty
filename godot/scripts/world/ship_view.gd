class_name ShipView
extends Node3D
## Vue d'une escale : suit l'état du navire (approche, rade, pilotage, quai, départ) et affiche sa cargaison.

const BOX_COLORS := ["box_red", "box_blue", "box_green", "box_yellow", "box_orange", "box_teal", "box_purple", "box_brown"]

var ship_id: int = 0
var cls: String = ""
var width: float = 8.0
var length: float = 30.0
var model: Node3D
var cargo_mm: MultiMeshInstance3D
var slots: Array = []
var slot_cargo: PackedInt32Array = PackedInt32Array()
var mat: ShaderMaterial
var tug: Node3D
var flag: MeshInstance3D

var _state: int = -1
var _state_dur: float = 1.0
var _from := Vector3.ZERO
var _vel := Vector3.ZERO
var _shown := -1
var _yaw := 0.0
var _bob := 0.0


func setup(s: Ship, sim: PortSim) -> void:
	ship_id = s.id
	cls = s.cls
	var sd: Dictionary = sim.db.ship_by_id[cls]
	var mname: String = sd.model
	var meta := Assets.meta(mname)
	width = float(meta.get("width", 8.0))
	length = float(meta.get("length", 30.0))
	var sc: float = Layout.SHIP_SCALE.get(cls, 1.0)
	mat = Assets.vcol_material.duplicate()
	model = Assets.instance(mname, mat)
	model.scale = Vector3.ONE * sc
	width *= sc
	length *= sc
	add_child(model)
	# pavillon de l'armateur (couleur de coque de l'armateur)
	flag = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.4, 0.9, 0.08)
	flag.mesh = bm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Assets.color(String(sim.db.owner_by_id[s.owner].hull))
	flag.material_override = fm
	flag.position = Vector3(-length * 0.47, float(meta.get("deck", 2.0)) * sc + 4.2, 0)
	model.add_child(flag)
	flag.position /= sc
	# cargaison : un bloc par emplacement
	slots = meta.get("slots", [])
	cargo_mm = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = Assets.mesh("container40")
	mm.instance_count = slots.size()
	mm.visible_instance_count = 0
	cargo_mm.multimesh = mm
	cargo_mm.material_override = Assets.tint_material
	model.add_child(cargo_mm)
	_assign_slots(s, sim)
	_from = Layout.SPAWN
	position = Layout.SPAWN
	_yaw = 0.0


func _assign_slots(s: Ship, sim: PortSim) -> void:
	# répartit les types de cargaison sur les emplacements selon le mélange du navire
	var n := slots.size()
	slot_cargo.resize(n)
	var tot := maxf(0.001, s.evp_total)
	var ci := 0
	var cum := s.left[0] / tot
	for i in n:
		var f := (float(i) + 0.5) / float(n)
		while f > cum and ci < PortSim.NCARGO - 1:
			ci += 1
			cum += s.left[ci] / tot
		slot_cargo[i] = ci
	var mm := cargo_mm.multimesh
	for i in n:
		var p: Array = slots[i]
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(float(p[0]), float(p[1]), float(p[2]))))
		mm.set_instance_custom_data(i, cargo_color(sim, slot_cargo[i], i + s.id * 7))


static func cargo_color(sim: PortSim, ci: int, h: int) -> Color:
	var id: String = sim.db.cargo[ci].id
	var key: String
	match id:
		"std":
			key = BOX_COLORS[absi(h * 2654435761) % BOX_COLORS.size()]
		"reefer":
			key = "reefer"
		"imo":
			key = "imo"
		"oog":
			key = "oog"
		_:
			key = "empty"
	return Assets.color(key).srgb_to_linear()


func _target(s: Ship, sim: PortSim) -> Dictionary:
	# renvoie {from, to, t, ctrl} pour l'état courant
	var anchor := Layout.anchor_pos(maxi(0, s.anchor_slot))
	var berth := Layout.berth_ship_pos(maxi(0, s.berth), width)
	var approach := berth + Vector3(-length * 0.3, 0, -14.0)
	var t := 1.0 - clampf(s.timer / maxf(0.01, _state_dur), 0.0, 1.0)
	match s.state:
		Ship.State.ARRIVING:
			return {"a": Layout.SPAWN, "b": anchor, "c": (Layout.SPAWN + anchor) * 0.5 + Vector3(0, 0, -30), "t": t}
		Ship.State.ANCHORED:
			return {"a": anchor, "b": anchor, "c": anchor, "t": 1.0}
		Ship.State.PILOTING:
			return {"a": _from, "b": approach, "c": (_from + approach) * 0.5 + Vector3(-20, 0, 0), "t": t}
		Ship.State.MOORING:
			return {"a": approach, "b": berth, "c": approach + Vector3(length * 0.3, 0, 0), "t": t}
		Ship.State.FORMALITIES, Ship.State.UNLOADING:
			return {"a": berth, "b": berth, "c": berth, "t": 1.0}
		Ship.State.DEPARTING:
			var out := berth + Vector3(40, 0, -30)
			return {"a": berth, "b": out.lerp(Layout.EXIT, t * t), "c": berth + Vector3(30, 0, -4), "t": t}
		Ship.State.LEAVING:
			return {"a": _from, "b": Layout.EXIT, "c": _from + Vector3(60, 0, -20), "t": t}
	return {"a": position, "b": position, "c": position, "t": 1.0}


static func _bez(a: Vector3, c: Vector3, b: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * u * u + c * 2.0 * u * t + b * t * t


func sync(s: Ship, sim: PortSim, delta: float) -> void:
	if s.state != _state:
		_from = position
		_state = s.state
		_state_dur = maxf(0.05, s.timer)
		if s.state == Ship.State.PILOTING or s.state == Ship.State.MOORING:
			_ensure_tug()
		elif tug != null and s.state >= Ship.State.FORMALITIES:
			tug.queue_free()
			tug = null
	var tg := _target(s, sim)
	var tt: float = smoothstep(0.0, 1.0, float(tg.t)) if s.state != Ship.State.DEPARTING else float(tg.t)
	var want := _bez(tg.a, tg.c, tg.b, tt)
	var prev := position
	position = position.lerp(want, 1.0 - exp(-delta * 6.0))
	var mv := position - prev
	if mv.length() > 0.01 * delta * 60.0:
		_yaw = lerp_angle(_yaw, atan2(-mv.z, mv.x), 1.0 - exp(-delta * 3.0))
	elif s.state >= Ship.State.MOORING and s.state <= Ship.State.UNLOADING:
		_yaw = lerp_angle(_yaw, 0.0, 1.0 - exp(-delta * 2.0))
	_bob += delta
	rotation = Vector3(sin(_bob * 1.3 + ship_id) * 0.015, _yaw, cos(_bob * 1.1 + ship_id) * 0.012)
	position.y = Layout.WATER_Y + sin(_bob * 1.6 + ship_id) * 0.08
	# cargaison visible
	var n := slots.size()
	var shown := n if s.evp_total <= 0.0 else ceili(float(n) * s.evp_left() / s.evp_total - 0.001)
	if s.state == Ship.State.DEPARTING:
		shown = 0
	if shown != _shown:
		_shown = shown
		cargo_mm.multimesh.visible_instance_count = shown
	# navire furieux : clignote en rouge
	var angry := s.state == Ship.State.LEAVING or (s.state == Ship.State.ANCHORED and s.mood() == Ship.Mood.ANGRY)
	mat.set_shader_parameter("flash", (0.5 + 0.5 * sin(_bob * 10.0)) * 0.8 if angry else 0.0)
	if tug != null:
		var fwd := Vector3(cos(_yaw), 0, -sin(_yaw))
		tug.position = position + fwd * (length * 0.5 + 6.0) + Vector3(0, -position.y + Layout.WATER_Y, 0)
		tug.rotation.y = _yaw


func _ensure_tug() -> void:
	if tug != null:
		return
	tug = Assets.instance("tug")
	get_parent().add_child(tug)
	tug.position = position


func _exit_tree() -> void:
	if tug != null and is_instance_valid(tug):
		tug.queue_free()


## Point d'ancrage des bulles (au-dessus de la passerelle).
func bubble_point() -> Vector3:
	return position + Vector3(0, 9.0, 0)


func is_waiting(s: Ship) -> bool:
	return s.state == Ship.State.ANCHORED or s.state == Ship.State.ARRIVING
