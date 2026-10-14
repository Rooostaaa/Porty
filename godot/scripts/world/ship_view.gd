class_name ShipView
extends Node3D
## Vue d'une escale : suit l'état du navire (approche, rade, pilotage, quai, départ) et affiche sa cargaison.

const BOX_COLORS := ["box_red", "box_blue", "box_green", "box_yellow", "box_orange", "box_teal", "box_purple", "box_brown"]

var ship_id: int = 0
var cls: String = ""
var width: float = 8.0
var length: float = 30.0
var deck_y: float = 2.0              # hauteur du pont au-dessus de la flottaison (dockers à bord, lot D)
var model: Node3D
var cargo_mm: MultiMeshInstance3D
var slots: Array = []
var slot_cargo: PackedInt32Array = PackedInt32Array()
var mat: ShaderMaterial
var tug: Node3D
var flag: MeshInstance3D

var _state: int = -1
var _state_dur: float = 1.0
var _shown := -1
var _yaw := 0.0
var _bob := 0.0
var _path: Array[Vector3] = []       # trajet affiché : reste du trajet précédent (s'il n'était pas fini) + trajet de l'état
var _len := 0.0                      # longueur du trajet affiché
var _d := 0.0                        # abscisse curviligne de la vue sur ce trajet : la vue reste toujours sur une polyligne
var _d0 := 0.0                       # longueur du reste du trajet précédent (en tête du trajet affiché)
var _angry := false
var _horn_done := false
var wake: MeshInstance3D
var hold := false                    # Diorama : navire retenu derrière un autre, ou dont le poste n'est pas encore construit à l'écran
## Rattrapage après une retenue : la vue avance le long de son trajet au plus CATCHUP_K fois sa vitesse nominale (au moins
## CATCHUP_MIN u/s), jamais en ligne droite vers la position de la simulation.
const CATCHUP_K := 2.0
const CATCHUP_MIN := 10.0


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
	deck_y = float(meta.get("deck", 2.0)) * sc
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


## Trajet de l'état courant (polyligne du plan : mouillage → chenal → bassin d'évitage → poste → sortie par la passe ou l'est),
## depuis `start` (là où la vue se trouvera en finissant le trajet précédent).
func _make_path(s: Ship, start: Vector3, tier: int = Layout.EAST_EXIT_TIER) -> Array[Vector3]:
	var anchor := Layout.anchor_pos(maxi(0, s.anchor_slot))
	var bi := maxi(0, s.berth)
	var berth := Layout.berth_ship_pos(bi, width)
	match s.state:
		Ship.State.ARRIVING:
			var p := Layout.ship_path_arrive(maxi(0, s.anchor_slot))
			p[0] = start if start.distance_to(Layout.SPAWN) > 1.0 else Layout.SPAWN
			return p
		Ship.State.ANCHORED:
			if start.distance_to(anchor) > 0.5:
				return [start, anchor]
			return [anchor]
		Ship.State.PILOTING:
			return Layout.ship_path_pilot_from(start, bi)
		Ship.State.MOORING, Ship.State.FORMALITIES, Ship.State.UNLOADING:
			var m := _to_berth(start, bi)
			m.append(berth)
			return m
		Ship.State.DEPARTING:
			var d := _to_berth(start, bi)
			var dep := Layout.ship_path_depart(bi, width, tier)      # par la passe aux paliers 1–2, par l'est au palier 3
			for i in range(1, dep.size()):
				d.append(dep[i])
			return d
		Ship.State.LEAVING:
			return Layout.ship_path_leave(start)
	return [start]


## Début d'un trajet vers le poste bi : depuis le bassin (voie d'arrivée) on y va droit ; d'ailleurs (un état sauté à grande
## vitesse de simulation), on reprend le trajet de pilotage : jamais de ligne droite à travers la terre ou le brise-lames.
func _to_berth(start: Vector3, bi: int) -> Array[Vector3]:
	var approach := Vector3(Layout.berth_center(bi), 0, Layout.APPROACH_Z)
	var berth := Layout.berth_ship_pos(bi, width)
	if start.distance_to(approach) < 30.0 or start.distance_to(berth) < 30.0:
		return [start]
	return Layout.ship_path_pilot_from(start, bi)


## Durée complète de l'état courant (au chargement, le minuteur restant ne dit pas où en est le navire).
func _full_duration(s: Ship, sim: PortSim) -> float:
	var d := s.timer
	match s.state:
		Ship.State.ARRIVING:
			d = float(sim.db.cfg("arrive_time"))
		Ship.State.PILOTING:
			d = sim.pilot_duration() * sim.time_scale(s.cls)
			if s.priority and not bool(sim.managers.harbor):
				d *= float(sim.db.cfg("manual").express_pilot)
		Ship.State.MOORING:
			d = sim.moor_duration() * sim.time_scale(s.cls)
		Ship.State.DEPARTING, Ship.State.LEAVING:
			d = float(sim.db.cfg("depart_time"))
	if is_nan(d) or is_inf(d) or d < s.timer:
		d = s.timer
	return maxf(0.05, d)


## Point de départ logique de l'état (chargement d'une partie) : le navire est posé à sa place sur son trajet
## (revue C7 A6 : un navire en pilotage n'est plus posé au poste pour repartir vers l'entrée du chenal).
func _state_start(s: Ship) -> Vector3:
	match s.state:
		Ship.State.ARRIVING:
			return Layout.SPAWN
		Ship.State.ANCHORED, Ship.State.PILOTING, Ship.State.LEAVING:
			return Layout.anchor_pos(maxi(0, s.anchor_slot))
		Ship.State.MOORING:
			return Vector3(Layout.berth_center(maxi(0, s.berth)), 0, Layout.APPROACH_Z)
	return Layout.berth_ship_pos(maxi(0, s.berth), width)


## Pose la vue à sa position logique (apparition, chargement d'une partie, nouvelle concession).
func place(s: Ship, sim: PortSim) -> void:
	_state = s.state
	_state_dur = _full_duration(s, sim)
	_set_path(_make_path(s, _state_start(s), sim.tier), 0.0)
	_d = _eased(s) * _len
	var p: Vector3 = Layout.polyline_at(_path, _frac())[0]
	position = Vector3(p.x, Layout.WATER_Y, p.z)
	if _stationary(s.state):
		_yaw = 0.35 if s.state == Ship.State.ANCHORED else 0.0
	elif _len > 1.0:
		_yaw = _chord_yaw()
	rotation.y = _yaw
	if s.state == Ship.State.PILOTING or s.state == Ship.State.MOORING:
		_ensure_tug()


func _set_path(p: Array[Vector3], prefix: float) -> void:
	_path = p
	_len = Layout.path_length(p)
	_d = 0.0
	_d0 = prefix


func _frac() -> float:
	return _d / _len if _len > 0.0001 else 1.0


## Avancement voulu (0–1) dans l'état courant, d'après le minuteur de la simulation (adouci).
func _eased(s: Ship) -> float:
	var t := 1.0 - clampf(s.timer / maxf(0.01, _state_dur), 0.0, 1.0)
	if _stationary(s.state):
		t = 1.0
	return t * t if s.state == Ship.State.DEPARTING or s.state == Ship.State.LEAVING else smoothstep(0.0, 1.0, t)


static func _stationary(st: int) -> bool:
	return st == Ship.State.ANCHORED or st == Ship.State.FORMALITIES or st == Ship.State.UNLOADING


## Reste du trajet affiché à partir de la vue (vide s'il est fini).
func _remaining() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if _path.size() < 2 or _d >= _len - 0.3:
		return out
	out.append(Layout.polyline_at(_path, _frac())[0])
	var acc := 0.0
	for i in _path.size() - 1:
		acc += _path[i].distance_to(_path[i + 1])
		if acc > _d + 0.05:
			out.append(_path[i + 1])
	return out


## Cap = corde entre l'étrave et la poupe posées sur le trajet : la coque suit les virages sans balayer les bouées
## (c'est ce que vérifie run_all, revue N1).
func _chord_yaw() -> float:
	var yaw_goal := float(Layout.polyline_at(_path, _frac())[1])
	var hl := length * 0.5
	var pa: Vector3 = Layout.polyline_at(_path, (_d + hl) / _len)[0]
	var pb: Vector3 = Layout.polyline_at(_path, (_d - hl) / _len)[0]
	if pa.distance_to(pb) > 0.5:
		yaw_goal = atan2(-(pa.z - pb.z), pa.x - pb.x)
	return yaw_goal


## La vue a-t-elle encore du chemin à faire (en route, ou en retard sur la simulation) ?
func is_moving() -> bool:
	return _len > 0.5 and _d < _len - 0.3


## Trajet affiché et abscisse de la vue (tests).
func shown_path() -> Array[Vector3]:
	return _path


func sync(s: Ship, sim: PortSim, delta: float) -> void:
	if s.state != _state:
		# la vue finit d'abord le trajet précédent (retenue, image lente), puis enchaîne le nouveau : elle reste toujours
		# sur une polyligne du plan (revue C7 A1 : plus de ligne droite à travers la terre au relâchement)
		var rest := _remaining()
		var start: Vector3 = rest.back() if not rest.is_empty() else Vector3(position.x, 0, position.z)
		_state = s.state
		_state_dur = maxf(0.05, s.timer)
		var p: Array[Vector3] = rest.duplicate()
		for q in _make_path(s, start, sim.tier):
			if p.is_empty() or p.back().distance_to(q) > 0.05:
				p.append(q)
		if p.is_empty():
			p.append(start)
		_set_path(p, Layout.path_length(rest))
		_horn_done = false
		if s.state == Ship.State.PILOTING or s.state == Ship.State.MOORING:
			_ensure_tug()
		elif tug != null and s.state >= Ship.State.FORMALITIES:
			tug.queue_free()
			tug = null
	_advance(_d0 + _eased(s) * (_len - _d0), delta)
	_pose(s.state, delta)
	# cargaison visible
	var n := slots.size()
	var shown := n if s.evp_total <= 0.0 else ceili(float(n) * s.evp_left() / s.evp_total - 0.001)
	if s.state == Ship.State.DEPARTING:
		shown = 0
	if shown != _shown:
		_shown = shown
		cargo_mm.multimesh.visible_instance_count = shown
	# navire furieux : clignote en rouge
	_angry = s.state == Ship.State.LEAVING or (s.state == Ship.State.ANCHORED and s.mood() == Ship.Mood.ANGRY)
	mat.set_shader_parameter("flash", (0.5 + 0.5 * sin(_bob * 10.0)) * 0.8 if _angry else 0.0)
	_sync_tug(s.state, delta)


## Le navire a quitté la simulation (départ terminé) : la vue finit son trajet jusqu'à la sortie, hors champ, puis le
## diorama la libère (revue C7 A1 : plus de disparition en pleine vue). Renvoie true une fois au bout.
func sync_parting(delta: float) -> bool:
	hold = false
	_advance(_len, delta, true)
	_pose(_state, delta)
	if _angry:
		mat.set_shader_parameter("flash", (0.5 + 0.5 * sin(_bob * 10.0)) * 0.8)
	_sync_tug(_state, delta)
	return _d >= _len - 0.05


## Avance l'abscisse de la vue vers `target` le long du trajet : rattrapage borné (au plus CATCHUP_K fois la vitesse
## nominale, au moins CATCHUP_MIN u/s), rien pendant une retenue (le navire attend sur son trajet).
func _advance(target: float, delta: float, steady: bool = false) -> void:
	if hold:
		return
	# durées en secondes de simulation : à vitesse ×N (débogage), la vue va N fois plus vite
	var nominal := (_len - _d0) / maxf(0.05, _state_dur)
	var vmax := maxf(nominal * CATCHUP_K, CATCHUP_MIN) * maxf(1.0, Sim.speed)
	var step := minf(target - _d, vmax * delta) if steady else clampf((target - _d) * (1.0 - exp(-delta * 12.0)), 0.0, vmax * delta)
	_d = clampf(_d + maxf(step, 0.0), 0.0, _len)


## Position (sur le trajet), cap, roulis, sillage.
func _pose(state: int, delta: float) -> void:
	var prev := position
	var want: Vector3 = Layout.polyline_at(_path, _frac())[0]
	position.x = want.x
	position.z = want.z
	var mv := position - prev
	mv.y = 0.0
	var speed := mv.length() / maxf(delta, 0.0001)
	var travelling := _d < _d0 - 0.5          # il finit le trajet de l'état précédent
	if not travelling and (state == Ship.State.MOORING or (state >= Ship.State.FORMALITIES and state <= Ship.State.UNLOADING)):
		_yaw = lerp_angle(_yaw, 0.0, 1.0 - exp(-delta * 3.0))      # accostage parallèle au quai, étrave vers l'est
	elif not travelling and state == Ship.State.ANCHORED:
		_yaw = lerp_angle(_yaw, 0.35, 1.0 - exp(-delta * 1.0))      # au mouillage, évité au vent
	elif _len > 1.0 and (mv.length() > 0.005 or hold):
		_yaw = lerp_angle(_yaw, _chord_yaw(), 1.0 - exp(-delta * 3.0))
	# corne en franchissant la passe
	if state == Ship.State.PILOTING and not _horn_done and prev.z < Layout.PASS_Z and position.z >= Layout.PASS_Z:
		_horn_done = true
		Sfx.play("ship_horn", 3.0)
	_bob += delta
	rotation = Vector3(sin(_bob * 1.3 + ship_id) * 0.015, _yaw, cos(_bob * 1.1 + ship_id) * 0.012)
	position.y = Layout.WATER_Y + sin(_bob * 1.6 + ship_id) * 0.08
	_sync_wake(speed, delta)


func _sync_tug(state: int, delta: float) -> void:
	if tug == null:
		return
	# le remorqueur tire à l'étrave dans le chenal, puis pousse le flanc au large pour plaquer le navire contre le quai
	var fwd := Vector3(cos(_yaw), 0, -sin(_yaw))
	var side := Vector3(-fwd.z, 0, fwd.x)
	var tp := position + fwd * (length * 0.5 + 6.0)
	var ty := _yaw
	if state == Ship.State.MOORING:
		tp = position - side * (width * 0.5 + 3.2)
		ty = _yaw + PI * 0.5
	tug.position = tug.position.lerp(Vector3(tp.x, Layout.WATER_Y, tp.z), 1.0 - exp(-delta * 8.0))
	tug.rotation.y = lerp_angle(tug.rotation.y, ty, 1.0 - exp(-delta * 6.0))


## Sillage en V : deux traînées d'écume qui s'ouvrent depuis la poupe et s'estompent vers l'arrière (dégradé), visibles
## seulement quand le navire avance (revue du 13/10 : plus de bande droite).
const WAKE_LEN := 18.0
const WAKE_ANGLE := 0.26
static var _wake_tex: GradientTexture2D


func _sync_wake(speed: float, delta: float) -> void:
	if wake == null:
		if _wake_tex == null:
			var g := Gradient.new()
			g.set_color(0, Color(1, 1, 1, 0.0))
			g.set_color(1, Color(1, 1, 1, 1.0))
			_wake_tex = GradientTexture2D.new()
			_wake_tex.gradient = g
			_wake_tex.width = 64
			_wake_tex.height = 4
		wake = MeshInstance3D.new()       # nœud porteur des deux traînées (même matériau)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(Assets.color("foam"), 0.0)
		m.albedo_texture = _wake_tex
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		wake.set_meta("mat", m)
		add_child(wake)
		for side in [-1.0, 1.0]:
			var arm := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(WAKE_LEN, maxf(1.0, width * 0.22))
			qm.orientation = PlaneMesh.FACE_Y
			arm.mesh = qm
			arm.material_override = m
			arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# la traînée part de la poupe (bout opaque, UV x = 1) et s'ouvre vers l'arrière
			arm.position = Vector3(-WAKE_LEN * 0.5 * cos(WAKE_ANGLE), 0.0, side * (width * 0.3 + WAKE_LEN * 0.5 * sin(WAKE_ANGLE)))
			arm.rotation.y = side * WAKE_ANGLE
			wake.add_child(arm)
	wake.position = Vector3(-length * 0.5, 0.12, 0)
	wake.rotation = Vector3(-rotation.x, 0, -rotation.z)
	var m2: StandardMaterial3D = wake.get_meta("mat")
	m2.albedo_color.a = lerpf(m2.albedo_color.a, clampf(speed / 12.0, 0.0, 0.7), 1.0 - exp(-delta * 4.0))
	wake.visible = m2.albedo_color.a > 0.02


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
