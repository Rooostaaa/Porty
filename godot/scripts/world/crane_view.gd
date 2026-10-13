class_name CraneView
extends Node3D
## Grue de quai animée : cycle navire → tablier au rythme du déchargement. Flèche relevée par vent fort.

var kind: String = "mobile"
var berth: int = 0
var model: Node3D
var boom: Node3D
var trolley: Node3D
var spreader: Node3D
var hook: Node3D
var cable: MeshInstance3D
var carried: MeshInstance3D
var tip_local := Vector3(11.0, 6.9, 0.0)
var pivot_y := 5.0
var height := 13.0

var phase: float = 0.0
var busy: bool = false
var period: float = 4.0
var ship_rel_z: float = -8.0     # position du navire (relative à la grue)
var ship_deck_y: float = 2.0
var stopped: bool = false        # vent fort
var _boom_raise: float = 0.0
var _carry_color := Color(0.8, 0.3, 0.3)

signal dropped()


func setup(k: String, bi: int) -> void:
	kind = k
	berth = bi
	if kind == "sts":
		model = Assets.instance("crane_sts")
		var m := Assets.meta("crane_sts")
		height = float(m.get("height", 13.0))
		boom = Assets.part(model, "boom")
		trolley = Assets.part(model, "trolley")
		spreader = Assets.part(model, "spreader")
	else:
		model = Assets.instance("crane_mobile")
		var m2 := Assets.meta("crane_mobile")
		var t: Array = m2.get("boom_tip", [11.0, 6.9, 0.0])
		tip_local = Vector3(float(t[0]), float(t[1]), 0.0)
		pivot_y = float(m2.get("boom_pivot_y", 5.0))
		boom = Assets.part(model, "boom")
		hook = Assets.part(model, "hook")
	add_child(model)
	cable = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.08, 1.0, 0.08)
	cable.mesh = bm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.15, 0.16, 0.2)
	cable.material_override = cm
	add_child(cable)
	carried = MeshInstance3D.new()
	carried.mesh = Assets.mesh("container40")
	carried.material_override = Assets.vcol_material.duplicate()
	carried.visible = false
	add_child(carried)
	phase = randf()


## Retour visuel d'un coup de main : la grue « tressaille » et avance son cycle.
func kick() -> void:
	phase = fmod(phase + 0.18, 1.0)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.06, 0.94, 1.06), 0.06)
	tw.tween_property(self, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK)


func set_carry_color(c: Color) -> void:
	_carry_color = c
	(carried.material_override as ShaderMaterial).set_shader_parameter("tint", c)


func _process(delta: float) -> void:
	var raise_goal := 1.0 if stopped else 0.0
	_boom_raise = move_toward(_boom_raise, raise_goal, delta * 0.5)
	if busy and not stopped:
		var prev := phase
		phase = fmod(phase + delta / period, 1.0)
		if prev < 0.6 and phase >= 0.6:
			dropped.emit()
	elif phase > 0.0 and phase < 0.98 and not stopped:
		phase = minf(0.999, phase + delta / period)   # termine le cycle en cours
	if kind == "sts":
		_pose_sts()
	else:
		_pose_mobile()


func _seg(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


## Renvoie (position horizontale 0 = navire → 1 = tablier, hauteur de levage 0 = bas → 1 = haut, porte un conteneur).
func _cycle() -> Vector3:
	var t := phase
	if t < 0.15:
		return Vector3(0.0, 1.0 - _seg(t, 0.0, 0.15), 0.0)
	if t < 0.3:
		return Vector3(0.0, _seg(t, 0.15, 0.3), 1.0)
	if t < 0.5:
		return Vector3(smoothstep(0.0, 1.0, _seg(t, 0.3, 0.5)), 1.0, 1.0)
	if t < 0.6:
		return Vector3(1.0, 1.0 - _seg(t, 0.5, 0.6), 1.0)
	if t < 0.75:
		return Vector3(1.0, _seg(t, 0.6, 0.75), 0.0)
	return Vector3(1.0 - smoothstep(0.0, 1.0, _seg(t, 0.75, 1.0)), 1.0, 0.0)


func _pose_sts() -> void:
	boom.rotation.x = deg_to_rad(75.0) * smoothstep(0.0, 1.0, _boom_raise)
	var c := _cycle() if _boom_raise < 0.05 else Vector3(1.0, 1.0, 0.0)
	var z := lerpf(ship_rel_z, 4.0, c.x)
	var low := lerpf(ship_deck_y + 2.8, 1.6, c.x)
	var y := lerpf(low, height - 4.0, c.y)
	trolley.position = Vector3(0.0, height - 0.1, z)
	spreader.position = Vector3(0.0, y, z)
	_cable_between(Vector3(0, height - 0.6, z), Vector3(0, y + 0.3, z))
	carried.visible = c.z > 0.5
	carried.position = Vector3(0.0, y - 1.6, z)


func _pose_mobile() -> void:
	var c := _cycle()
	var yaw := lerp_angle(deg_to_rad(90.0), deg_to_rad(-13.0), smoothstep(0.0, 1.0, c.x))
	if stopped:
		yaw = deg_to_rad(180.0)
	boom.rotation.y = yaw
	var tip := Vector3(0, pivot_y, 0) + Basis(Vector3.UP, yaw) * tip_local
	var low := lerpf(ship_deck_y + 2.6, 1.8, c.x)
	var y := lerpf(low, tip.y - 3.0, c.y)
	hook.position = Vector3(tip.x, y + 1.0, tip.z)
	hook.rotation.y = yaw
	_cable_between(tip, Vector3(tip.x, y + 1.1, tip.z))
	carried.visible = c.z > 0.5 and not stopped
	carried.position = Vector3(tip.x, y - 1.2, tip.z)
	carried.rotation.y = 0.0


func _cable_between(a: Vector3, b: Vector3) -> void:
	var l := maxf(0.05, a.distance_to(b))
	cable.position = (a + b) * 0.5
	cable.scale = Vector3(1, l, 1)
