class_name ShipView
extends Node3D
## Vue d'un navire (lot F1) : un navire « physique » qui fait son propre voyage à l'écran, à **vitesse de croisière constante**
## par classe (jamais plus vite parce que le port s'améliore, aucun rattrapage), avec ses manœuvres : arrivée au mouillage,
## pilotage par le chenal (remorqueur en tête), évitage au bassin (le remorqueur pousse la hanche), approche déjà parallèle au
## quai, glissement latéral lent jusqu'au poste (remorqueur à l'épaule, côté large), déchargement, glissement inverse (le
## remorqueur tire), départ. Trajets et points d'attente : Layout (« Lot F1 — manœuvres »).
## La simulation va bien plus vite qu'un vrai navire (une escale occupe un poste 1 à 7 s) : le monde montre un **échantillon**
## des escales au rythme d'un port réel (Diorama, « Navires à l'écran ») ; une vue n'est liée à une escale de la simulation
## (`sid`) que pendant son séjour en rade.

const BOX_COLORS := ["box_red", "box_blue", "box_green", "box_yellow", "box_orange", "box_teal", "box_purple", "box_brown"]

## Lot H2 : BACK_IN — marche arrière dans la darse (du point d'attente à la hauteur du poste, remorqueur à la proue).
enum Phase { ARRIVE, ANCHOR, INBOUND, BACK_IN, CRAB_IN, MOORED, CRAB_OUT, OUTBOUND, LEAVE, DONE }

## Vitesse de croisière par classe (u/s). Un navire ne la dépasse jamais.
const CRUISE := {"mini": 7.5, "coaster": 7.0, "feeder": 6.0, "panamax": 5.0}
const CRUISE_DEFAULT := 6.0
const HARBOR_K := 0.55            # vitesse dans le port (sortie du chenal, voie d'évitage, départ le long des quais)
const MANEUVER_K := 0.38          # vitesse de manœuvre (évitage, approche du poste, écart de départ)
const SPEED_MIN := 1.8
const ACCEL := 0.6                # u/s² : prise de vitesse
const DECEL := 0.45               # u/s² : freinage doux (avant le bassin, le poste, le point d'attente)
const ARRIVE_DECEL := 0.9         # u/s² : arrêt au mouillage
const HOLD_DECEL := 3.5           # u/s² : arrêt derrière un autre navire (règles de passage)
const CRAB_V := 1.1               # u/s : glissement latéral, au plus
const CRAB_ACCEL := 0.22
const MAX_YAW_RATE := 0.33        # rad/s (19°/s) : plafond de la vitesse de rotation, partout
const ANCHOR_YAW_RATE := 0.06     # rad/s : au mouillage, le navire évite au vent lentement
const BLEND_LEN := 14.0           # u : en fin d'approche, le cap rejoint celui du quai (parallèle avant le glissement)
const FORMAL_T := 2.0             # s à quai avant les grues (formalités)
const UNLOAD_PER_SLOT := 0.3      # s de déchargement à l'écran par emplacement de conteneur…
const UNLOAD_MIN := 8.0           # … entre 8 et 20 s par navire
const UNLOAD_MAX := 20.0
const LINGER := 1.5               # s à quai, vide, avant de demander le départ
## Lot H2 : vitesse de manœuvre sur les MAN_LEAD derniers mètres avant le point d'attente final ; marche arrière (remorqueur à
## la proue) : prise de vitesse plus vive, vitesse Layout.REVERSE_V.
const MAN_LEAD := 18.0
const REVERSE_ACCEL := 0.9
const TUG_SPEED := 11.0
const TUG_TURN := 2.5             # rad/s
## Remorqueur : base dans la crique (à côté du remorqueur du pôle nautique), rendez-vous à l'entrée du chenal (postes 1–2) ou
## dans la passe est (postes 3–4) ; il accompagne le navire jusqu'au quai, revient pour le départ.
const TUG_BASE := Vector3(-51, 0, -15)
const TUG_MEET_W := Vector3(-31, 0, -97)
const TUG_MEET_E := Vector3(152, 0, -31)
const TUG_WAIT_MAX := 10.0        # s : un départ n'attend pas son remorqueur plus longtemps

static var _next_vid := 1

var vid: int = 0                     # identifiant de la vue (unique ; règles de passage, foule)
var ship_id: int = 0                 # escale de la simulation à la création de la vue
var sid: int = -1                    # escale liée (en rade seulement ; Diorama)
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
var wake: MeshInstance3D

var phase: int = Phase.ARRIVE
var berth_i := -1                    # poste visé (pilotage) ou occupé (à quai, départ)
var vslot := -1                      # place de mouillage à l'écran
var angry := false                   # repart furieux (départ de la rade)
var moody := false                   # (escale liée) humeur furieuse en rade : la coque clignote
var queue_t := 0.0                   # instant de l'envoi vers le poste (ordre de passage)
var unbound_t := 0.0                 # instant où la vue a perdu son escale (file des envois, Diorama)
var gate_level := 2                  # Diorama : 0 = attendre au point d'attente 1, 1 = au point 2, 2 = libre
var cranes_on := true                # Diorama : les grues peuvent travailler (pas de vent fort, tablier pas plein)
var dwell := 0.0                     # s à quai
var unload_dur := 10.0
var cargo_frac := 1.0                # cargaison restante à bord (0–1), à l'écran
var hold := false                    # Diorama : navire retenu derrière un autre (règles de passage, ShipRules)
var held_t := 0.0                    # Diorama (E-Flux) : depuis combien de temps la vue est retenue sans interruption (s)
var force_t := 0.0                   # Diorama (E-Flux) : retenue levée pendant ce temps (s) après HOLD_MAX s d'attente
var hold_d := -1.0                   # lot F3 : abscisse d'attente imposée (caboteur de la bascule, à l'entrée du chenal, tant que
                                     # le chantier du vieux quai n'est pas fini) ; −1 : aucune

var _path: Array[Vector3] = []
var _len := 0.0
var _d := 0.0                        # abscisse curviligne de la vue sur son trajet
var _v := 0.0                        # vitesse (u/s)
var _cruise := CRUISE_DEFAULT
var _vh := 3.3                       # vitesse dans le port
var _vman := 2.3                     # vitesse de manœuvre
var _stop_end := true
var _zones: Array[Vector2] = []      # (abscisse de début, vitesse au plus) : la vitesse du tronçon, freinage avant le suivant
var _gates: Array[float] = []        # abscisses des points d'attente (pilotage)
var _man_end := -1.0                 # abscisse de la fin de la manœuvre de départ
var _depart_rest: Array[Vector3] = []
var _unload_t := 0.0
var _idle := 0.0
var _yaw := 0.0
var _yaw0 := 0.0                     # cap au début du trajet (poupe hors trajet, E-Flux)
var _turn := 0.0                     # sens du virage en cours (lissé : > 0 à gauche, < 0 à droite)
var _off := Vector3.ZERO             # écart du centre de la coque au point du trajet (E-Flux, lissé)
var _bob := 0.0
var _shown := -1
var _horn_done := false
var _tug_state := ""                 # « meet » (va au rendez-vous), « attached » (à poste), « home » (rentre)
var _tug_meet := Vector3.ZERO
var _tug_wait := 0.0
var _tug_side := -1.0                # côté de la poussée à la hanche (−1 bâbord, +1 tribord)
var max_yaw_rate_seen := 0.0         # (tests) plus grande vitesse de rotation observée, rad/s
var _straight_from := INF            # lot H2 : abscisse du tronçon droit de la marche arrière (cap tenu)


func setup(s: Ship, sim: PortSim) -> void:
	vid = _next_vid
	_next_vid += 1
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
	mm.use_colors = true          # (lot G2 : sans couleur d'instance, le rendu de compatibilité OpenGL dessine la cargaison en noir)
	mm.use_custom_data = true
	mm.mesh = Assets.mesh("container40")
	mm.instance_count = slots.size()
	for i in slots.size():
		mm.set_instance_color(i, Color.WHITE)
	mm.visible_instance_count = 0
	cargo_mm.multimesh = mm
	cargo_mm.material_override = Assets.tint_material
	model.add_child(cargo_mm)
	_assign_slots(s, sim)
	_cruise = float(CRUISE.get(cls, CRUISE_DEFAULT))
	_vh = maxf(SPEED_MIN, _cruise * HARBOR_K)
	_vman = maxf(SPEED_MIN, _cruise * MANEUVER_K)
	unload_dur = clampf(float(slots.size()) * UNLOAD_PER_SLOT, UNLOAD_MIN, UNLOAD_MAX)
	position = Layout.SPAWN
	_path = [Layout.SPAWN]
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


## Vitesses de la vue (u/s) : croisière, dans le port, de manœuvre ; vitesse actuelle.
func cruise_speed() -> float:
	return _cruise


func harbor_speed() -> float:
	return _vh


func maneuver_speed() -> float:
	return _vman


func speed() -> float:
	return _v


func path_pos() -> float:
	return _d


func path_len() -> float:
	return _len


func yaw() -> float:
	return _yaw


# ---------------------------------------------------------------------------
# Ordres (Diorama, ou `sync` pour une vue liée à son escale)
# ---------------------------------------------------------------------------

func _here() -> Vector3:
	return Vector3(position.x, 0.0, position.z)


func _start(ph: int, p: Array, stop_end := true) -> void:
	phase = ph
	_yaw0 = _yaw
	_path.assign(p)
	_len = Layout.path_length(_path)
	_d = 0.0
	_stop_end = stop_end
	_zones = [Vector2(0.0, _cruise)]
	_gates.clear()
	_man_end = -1.0


## Arrivée du large jusqu'à la place de mouillage `slot`.
func arrive_to(slot: int) -> void:
	vslot = slot
	var p := Layout.ship_path_arrive(maxi(0, slot))
	var at_spawn := _here().distance_to(Layout.SPAWN) <= 1.0
	if not at_spawn:
		p[0] = _here()
	_start(Phase.ARRIVE, p)
	if at_spawn:
		_v = _cruise
		_yaw = float(Layout.polyline_at(p, 0.0)[1])
		_yaw0 = _yaw


## Avance la vue sur son trajet d'arrivée pour qu'elle mouille dans environ `t` s (elle arrive au mouillage quand
## l'escale y arrive dans la simulation, au lieu de tout le trajet depuis le large).
func arrive_in(t: float) -> void:
	if phase != Phase.ARRIVE:
		return
	var brake := _cruise * _cruise / (2.0 * ARRIVE_DECEL)
	var need := brake + _cruise * maxf(0.0, t - _cruise / ARRIVE_DECEL)
	_d = clampf(_len - need, 0.0, _len)
	_v = _cruise
	var p: Vector3 = Layout.polyline_at(_path, _frac())[0]
	position = Vector3(p.x, Layout.WATER_Y, p.z)
	_yaw = _chord_yaw()
	_yaw0 = _yaw
	_off = Vector3.ZERO


## Pilotage vers le poste bi, depuis là où se trouve la vue (mouillage, ou en route vers le mouillage).
func dispatch(bi: int) -> void:
	berth_i = bi
	angry = false
	var p := Layout.ship_path_pilot_from(_here(), bi)
	_start(Phase.INBOUND, p)
	var g := Layout.pilot_gates(bi)
	var g1 := _abscissa(p, g[0])
	var g2 := _abscissa(p, g[1])
	_gates = [g1, g2]
	# lot H2 : vitesse du port jusqu'aux dernières encablures avant le point d'attente final (l'attente de darse est loin de la
	# darse), puis vitesse de manœuvre
	var man := maxf(g2, _len - MAN_LEAD)
	if bi < Layout.EAST_BERTH0:
		_zones = [Vector2(0.0, _cruise), Vector2(g1, _vh), Vector2(man, _vman)]
	else:
		_zones = [Vector2(0.0, _cruise), Vector2(man, _vman)]      # (passe est : au large jusqu'à la darse, comme avant H2)
	gate_level = 0
	cargo_frac = 1.0
	_horn_done = false
	_call_tug()


## Lot F2 — premier navire du T1 : il naît sur le trajet `p` (dans le chenal, hors champ) déjà à sa vitesse de croisière et
## suit le même pilotage que `dispatch` (points d'attente, vitesses du port, remorqueur, évitage, glissement).
func dispatch_on(bi: int, p: Array[Vector3]) -> void:
	position = Vector3(p[0].x, Layout.WATER_Y, p[0].z)
	berth_i = bi
	angry = false
	_yaw = float(Layout.polyline_at(p, 0.0)[1])      # cap du trajet (le navire arrive déjà dans l'axe du chenal)
	_start(Phase.INBOUND, p)
	var g := Layout.pilot_gates(bi)
	var g1 := _abscissa(p, g[0])
	var g2 := _abscissa(p, g[1])
	_gates = [g1, g2]
	_zones = [Vector2(0.0, _cruise), Vector2(g1, _vh), Vector2(maxf(g2, _len - MAN_LEAD), _vman)]
	gate_level = 0
	cargo_frac = 1.0
	_horn_done = false
	_v = _cruise
	_off = Vector3.ZERO
	_call_tug()


## Départ furieux depuis la rade (ou depuis l'arrivée).
func leave_angry() -> void:
	angry = true
	_start(Phase.LEAVE, Layout.ship_path_leave(_here()), false)


## À quai et déchargé : le remorqueur vient, glissement latéral vers le large, puis la route de départ.
func depart() -> void:
	if phase != Phase.MOORED:
		return
	var dep := Layout.ship_path_depart(berth_i, width)
	dep[0] = _here()
	_start(Phase.CRAB_OUT, [dep[0], dep[1]])
	_depart_rest.assign(dep.slice(1))
	_tug_wait = 0.0
	_ensure_tug()
	_tug_state = "attached"


## Pose la vue à quai au poste bi (chargement d'une partie, tests), cargaison déjà déchargée de `done` (0–1).
func moor_now(bi: int, done: float = 0.0) -> void:
	berth_i = bi
	var b := Layout.berth_ship_pos(bi, width)
	_start(Phase.MOORED, [b])
	_v = 0.0
	_unload_t = clampf(done, 0.0, 1.0) * unload_dur
	cargo_frac = 1.0 - clampf(done, 0.0, 1.0)
	dwell = FORMAL_T if done > 0.0 else 0.0
	_idle = 0.0
	_yaw = Layout.berth_yaw(bi)
	_off = Vector3.ZERO
	position = Vector3(b.x, Layout.WATER_Y, b.z)
	rotation.y = _yaw
	_free_tug()


## Durée complète de l'état courant d'une escale (au chargement, le minuteur restant ne dit pas où en est le navire).
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


## Pose la vue à sa place logique d'après l'état de l'escale (apparition, chargement d'une partie, nouvelle concession) :
## sur son trajet, jamais au poste pour un navire encore en pilotage (revue C7 A6).
func place(s: Ship, sim: PortSim) -> void:
	var anchor := Layout.anchor_pos(maxi(0, s.anchor_slot))
	vslot = s.anchor_slot
	var f := 1.0 - clampf(s.timer / _full_duration(s, sim), 0.0, 1.0)
	_off = Vector3.ZERO
	match s.state:
		Ship.State.ARRIVING:
			arrive_to(maxi(0, s.anchor_slot))
			arrive_in(s.timer)
			return
		Ship.State.ANCHORED:
			_start(Phase.ANCHOR, [anchor])
			_v = 0.0
		Ship.State.PILOTING, Ship.State.MOORING:
			position = Vector3(anchor.x, Layout.WATER_Y, anchor.z)
			dispatch(maxi(0, s.berth))
			var g1: float = _gates[0]
			_d = g1 if s.state == Ship.State.MOORING else f * g1
			_v = _vh if s.state == Ship.State.MOORING else _cruise
		Ship.State.FORMALITIES, Ship.State.UNLOADING:
			moor_now(maxi(0, s.berth), s.progress() if s.state == Ship.State.UNLOADING else 0.0)
			return
		Ship.State.DEPARTING:
			berth_i = maxi(0, s.berth)
			_yaw = Layout.berth_yaw(berth_i)
			var dep := Layout.ship_path_depart(berth_i, width)
			_start_outbound(dep.slice(1))
			_d = f * _len
			_v = _cruise if _d > _man_end else _vman
			cargo_frac = 0.0
		Ship.State.LEAVING:
			angry = true
			_start(Phase.LEAVE, Layout.ship_path_leave(anchor), false)
			_d = f * _len
			_v = _cruise
	var p: Vector3 = Layout.polyline_at(_path, _frac())[0]
	position = Vector3(p.x, Layout.WATER_Y, p.z)
	if phase == Phase.ANCHOR:
		_yaw = Layout.ANCHOR_YAW
	elif _len > 1.0:
		_yaw = _chord_yaw()
	_yaw0 = _yaw
	rotation.y = _yaw
	if phase == Phase.INBOUND and tug != null and _d > 0.0:
		# (chargement en plein pilotage : le remorqueur est déjà avec le navire)
		_tug_state = "attached"
		tug.position = _tug_station()[0]


func _start_outbound(p: Array) -> void:
	_start(Phase.OUTBOUND, p, false)
	_man_end = _abscissa(_path, Layout.depart_maneuver_end(berth_i, width))
	_zones = [Vector2(0.0, _vh if berth_i < Layout.EAST_BERTH0 else _vman), Vector2(_man_end, _cruise)]


func _frac() -> float:
	return _d / _len if _len > 0.0001 else 1.0


## Abscisse du point du trajet le plus proche de q.
static func _abscissa(p: Array, q: Vector3) -> float:
	var best := INF
	var at := 0.0
	var acc := 0.0
	var q2 := Vector2(q.x, q.z)
	for i in p.size() - 1:
		var a := Vector2((p[i] as Vector3).x, (p[i] as Vector3).z)
		var b := Vector2((p[i + 1] as Vector3).x, (p[i + 1] as Vector3).z)
		var c := Geometry2D.get_closest_point_to_segment(q2, a, b)
		var dd := c.distance_to(q2)
		if dd < best - 0.001:
			best = dd
			at = acc + a.distance_to(c)
		acc += a.distance_to(b)
	return at


static func _stationary(ph: int) -> bool:
	return ph == Phase.ANCHOR or ph == Phase.MOORED or ph == Phase.DONE


## Phase équivalente de la simulation (règles de passage, ShipRules) : arrivée, pilotage (et accostage), départ, furieux.
func rule_state() -> int:
	match phase:
		Phase.ARRIVE:
			return Ship.State.ARRIVING
		Phase.ANCHOR:
			return Ship.State.ANCHORED
		Phase.INBOUND, Phase.BACK_IN, Phase.CRAB_IN:
			return Ship.State.PILOTING
		Phase.MOORED:
			return Ship.State.UNLOADING
		Phase.CRAB_OUT, Phase.OUTBOUND:
			return Ship.State.DEPARTING
		Phase.LEAVE:
			return Ship.State.LEAVING
	return -1


# ---------------------------------------------------------------------------
# Image par image
# ---------------------------------------------------------------------------

## Vue liée à son escale (en rade) : suit les décisions de la simulation (pilotage vers le poste, départ furieux, départ du
## quai), puis avance d'une image.
func sync(s: Ship, sim: PortSim, delta: float) -> void:
	if phase == Phase.ARRIVE or phase == Phase.ANCHOR:
		if s.state == Ship.State.LEAVING:
			leave_angry()
		elif s.state >= Ship.State.PILOTING and s.state <= Ship.State.DEPARTING:
			dispatch(maxi(0, s.berth))
			gate_level = 2
	elif phase == Phase.MOORED and (s.state == Ship.State.DEPARTING or s.state == Ship.State.LEAVING):
		depart()
	moody = s.state == Ship.State.ANCHORED and s.mood() == Ship.Mood.ANGRY
	step(delta)


## Vue qui finit son trajet sans escale liée (départ, furieux) ; `rules` : le diorama applique encore ses règles de passage
## (retenue bornée par HOLD_MAX), sinon plus de retenue. Renvoie true une fois au bout.
func sync_parting(delta: float, rules := false) -> bool:
	if not rules:
		hold = false
	moody = false
	step(delta)
	return phase == Phase.DONE


func _flash() -> void:
	mat.set_shader_parameter("flash", (0.5 + 0.5 * sin(_bob * 10.0)) * 0.8 if (angry or moody) else 0.0)


## Une image : vitesse, abscisse, phase suivante au bout du trajet, pose, remorqueur, cargaison.
func step(delta: float) -> void:
	var dt := delta * maxf(1.0, Sim.speed)      # (débogage ×N : la vue suit la simulation accélérée)
	match phase:
		Phase.ANCHOR:
			_v = 0.0
		Phase.MOORED:
			_v = 0.0
			dwell += dt
			if dwell > FORMAL_T and cargo_frac > 0.0 and cranes_on:
				_unload_t += dt
			cargo_frac = clampf(1.0 - _unload_t / maxf(0.1, unload_dur), 0.0, 1.0)
			if cargo_frac <= 0.0:
				_idle += dt
		Phase.DONE:
			pass
		_:
			_move(dt)
	_pose(dt)
	_sync_tug(dt)
	_sync_cargo()
	_flash()


func _move(dt: float) -> void:
	var crab := phase == Phase.CRAB_IN or phase == Phase.CRAB_OUT
	if phase == Phase.CRAB_OUT and not _tug_ready():
		_tug_wait += dt
		if _tug_wait < TUG_WAIT_MAX:
			return          # le remorqueur n'est pas encore à poste
	var vlim := _speed_limit(crab)
	var rate := (CRAB_ACCEL if crab else (REVERSE_ACCEL if phase == Phase.BACK_IN else ACCEL)) if vlim > _v else maxf(DECEL * 2.0, CRAB_ACCEL)
	if hold and not crab:
		vlim = 0.0
		rate = HOLD_DECEL
	_v = move_toward(_v, vlim, rate * dt)
	var nd := minf(_len, _d + _v * dt)
	var stop := _gate_stop()
	if stop >= 0.0 and _d <= stop + 0.01:
		nd = minf(nd, stop)
		if nd >= stop - 0.01:
			_v = 0.0
	_d = nd
	if _d >= _len - 0.01 and (not _stop_end or _v < 0.4):
		_d = _len
		_path_done()


## Point d'attente où la vue doit s'arrêter (abscisse), −1 si elle est libre : le niveau donné par le diorama, et jamais
## au-delà du dernier point d'attente tant que le remorqueur n'est pas à poste.
func _gate_stop() -> float:
	if phase == Phase.INBOUND and hold_d >= 0.0 and hold_d >= _d - 0.01:
		return hold_d
	if phase != Phase.INBOUND or _gates.is_empty():
		return -1.0
	var lv := gate_level
	if not _tug_ready():
		lv = mini(lv, _gates.size() - 1)
	if lv >= _gates.size():
		return -1.0
	var g: float = _gates[lv]
	return g if g >= _d - 0.01 else -1.0


func _speed_limit(crab: bool) -> float:
	if crab:
		return minf(CRAB_V, sqrt(2.0 * CRAB_ACCEL * maxf(0.0, _len - _d)) + 0.04)
	var vmax := _cruise
	for z in _zones:
		if z.x <= _d:
			vmax = z.y
	for z in _zones:
		if z.x > _d:
			vmax = minf(vmax, sqrt(z.y * z.y + 2.0 * DECEL * (z.x - _d)))
	if _stop_end:
		var dec := ARRIVE_DECEL if phase == Phase.ARRIVE else DECEL
		vmax = minf(vmax, sqrt(2.0 * dec * maxf(0.0, _len - _d)) + 0.12)
	var stop := _gate_stop()
	if stop >= 0.0:
		vmax = minf(vmax, sqrt(2.0 * DECEL * maxf(0.0, stop - _d)))
	return vmax


func _path_done() -> void:
	match phase:
		Phase.ARRIVE:
			phase = Phase.ANCHOR
			_v = 0.0
		Phase.INBOUND:
			# lot H2 : au point d'attente final, le navire recule dans la darse (≤ REVERSE_V, le remorqueur à la proue)
			_v = 0.0
			_start(Phase.BACK_IN, Layout.ship_path_back_in(berth_i, null, width))
			_zones = [Vector2(0.0, Layout.REVERSE_V)]
			# dernier tronçon (droit, vers le poste) : cap tenu au nord, le navire se rapproche du quai en reculant
			_straight_from = _len - (_path[-1] as Vector3).distance_to(_path[-2])
		Phase.BACK_IN:
			_v = 0.0
			_start(Phase.CRAB_IN, [_path[-1], Layout.berth_ship_pos(berth_i, width)])
		Phase.CRAB_IN:
			_v = 0.0
			phase = Phase.MOORED
			dwell = 0.0
			_unload_t = 0.0
			_idle = 0.0
			cargo_frac = 1.0
			_tug_home()
		Phase.CRAB_OUT:
			_v = 0.0
			_start_outbound(_depart_rest)
		Phase.OUTBOUND, Phase.LEAVE:
			phase = Phase.DONE
			_free_tug()


## À quai : formalités (2 s), puis déchargement à l'écran.
func in_formalities() -> bool:
	return phase == Phase.MOORED and dwell < FORMAL_T


func unloading() -> bool:
	return phase == Phase.MOORED and dwell >= FORMAL_T and cargo_frac > 0.0


func unload_done() -> bool:
	return phase == Phase.MOORED and cargo_frac <= 0.0 and _idle >= LINGER


func progress() -> float:
	return 1.0 - cargo_frac


## Le navire est-il encore dans sa manœuvre de départ (glissement, écart, virage vers la passe) ?
func in_depart_maneuver() -> bool:
	return phase == Phase.CRAB_OUT or (phase == Phase.OUTBOUND and _d < _man_end + 4.0)


## Le navire est-il dans sa manœuvre d'arrivée (au-delà du dernier point d'attente : évitage, approche) ?
func in_maneuver() -> bool:
	return phase == Phase.BACK_IN or (phase == Phase.INBOUND and not _gates.is_empty() and _d >= float(_gates[-1]) + 0.5)


## Cap = corde entre l'étrave et la poupe posées sur le trajet : la coque suit les virages sans balayer les bouées
## (c'est ce que vérifie run_all, revue N1).
func _chord_yaw() -> float:
	var yaw_goal := float(Layout.polyline_at(_path, _frac())[1])
	var hl := length * 0.5
	var pa: Vector3 = Layout.polyline_at(_path, (_d + hl) / _len)[0]
	var pb: Vector3 = Layout.polyline_at(_path, (_d - hl) / _len)[0]
	if pa.distance_to(pb) > 0.5:
		yaw_goal = atan2(-(pa.z - pb.z), pa.x - pb.x)
	if phase == Phase.BACK_IN:
		yaw_goal = wrapf(yaw_goal + PI, -PI, PI)      # lot H2 : en marche arrière, la poupe va devant
	if _d < hl and hl > 0.01:
		# (E-Flux) tant que la poupe n'est pas sur le trajet, le cap passe peu à peu du cap de départ (à quai, au mouillage, ou
		# celui du trajet précédent) à la corde : le navire tourne en avançant au lieu de pivoter d'un coup vers sa route
		yaw_goal = lerp_angle(_yaw0, yaw_goal, _d / hl)
	return yaw_goal


## Centre de la coque (E-Flux) : au milieu de la corde étrave–poupe, l'une et l'autre posées sur le trajet ; aux bouts du
## trajet (poupe ou étrave pas encore dessus), on revient au point du trajet.
func hull_center() -> Vector3:
	var p: Vector3 = Layout.polyline_at(_path, _frac())[0]
	var hl := length * 0.5
	if _len <= 1.0 or hl <= 0.01:
		return p
	# (lot F1) un trajet sans arrêt au bout (départ, hors champ) garde la corde jusqu'au bout : pas d'à-coup final
	var w := clampf((minf(_d, _len - _d) if _stop_end else _d) / hl, 0.0, 1.0)
	if w <= 0.0:
		return p
	var pa: Vector3 = Layout.polyline_at(_path, (_d + hl) / _len)[0]
	var pb: Vector3 = Layout.polyline_at(_path, (_d - hl) / _len)[0]
	return p.lerp((pa + pb) * 0.5, w)


## Points du trajet à ces distances devant la vue (règle du croisement balisé, ShipRules).
func ahead(dists: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if _len <= 0.5:
		return out
	for dd in dists:
		var q: Vector3 = Layout.polyline_at(_path, minf(1.0, (_d + float(dd)) / _len))[0]
		out.append(Vector2(q.x, q.z))
	return out


## Coque (points du trajet sous la coque) et bande que l'étrave va balayer (règles de passage, ShipRules.holds).
func hull_sweep() -> Array:
	return ShipRules.hull_and_sweep(_path, _d, length, _yaw0)


## La vue est-elle en route (elle a encore du chemin à faire) ?
func is_moving() -> bool:
	return not _stationary(phase)


## Trajet affiché (tests).
func shown_path() -> Array[Vector3]:
	return _path


## Position (sur le trajet), cap (vitesse de rotation plafonnée), roulis, sillage.
func _pose(dt: float) -> void:
	var prev := position
	var at_path: Vector3 = Layout.polyline_at(_path, _frac())[0]
	var on_lane := phase == Phase.ARRIVE or phase == Phase.INBOUND or phase == Phase.BACK_IN or phase == Phase.OUTBOUND or phase == Phase.LEAVE or phase == Phase.DONE
	var goal_off := hull_center() - at_path if on_lane else Vector3.ZERO
	if not hold:
		_off = _off.lerp(goal_off, 1.0 - exp(-dt * 4.0))
	position.x = at_path.x + _off.x
	position.z = at_path.z + _off.z
	var mv := position - prev
	mv.y = 0.0
	# vitesse le long du cap (un glissement latéral ne laisse pas de sillage)
	var spd := absf(mv.dot(Vector3(cos(_yaw), 0, -sin(_yaw)))) / maxf(dt, 0.0001)
	var target := _yaw
	var rate := MAX_YAW_RATE
	match phase:
		Phase.ANCHOR:
			target = Layout.ANCHOR_YAW
			rate = ANCHOR_YAW_RATE
		Phase.CRAB_IN, Phase.CRAB_OUT, Phase.MOORED:
			target = Layout.berth_yaw(berth_i)
		Phase.DONE:
			pass
		_:
			if _len > 1.0 and _v > 0.05:
				target = _chord_yaw()          # (navire arrêté : il ne tourne pas — jamais de pivot sur place)
			if phase == Phase.INBOUND and _v > 0.05:
				# fin de l'approche : le cap rejoint celui du point d'attente final (lot H2 : cap à l'est devant D1–D2, au nord
				# devant D3) avant la marche arrière (jamais de pivot sur place)
				var gh := Layout.berth_gate_heading(berth_i)
				target = lerp_angle(target, atan2(-gh.y, gh.x), smoothstep(_len - BLEND_LEN, _len, _d))
			if phase == Phase.BACK_IN and _d >= _straight_from - 0.01:
				target = Layout.berth_yaw(berth_i)
	var prev_yaw := _yaw
	var diff := angle_difference(_yaw, target)
	_yaw += clampf(diff * (1.0 - exp(-dt * 3.0)), -rate * dt, rate * dt)
	if dt > 0.0:
		var yr := angle_difference(prev_yaw, _yaw) / dt
		max_yaw_rate_seen = maxf(max_yaw_rate_seen, absf(yr))
		_turn = lerpf(_turn, yr, 1.0 - exp(-dt * 2.0))
	# corne en franchissant la passe
	if phase == Phase.INBOUND and not _horn_done and prev.z < Layout.PASS_Z and position.z >= Layout.PASS_Z:
		_horn_done = true
		Sfx.play("ship_horn", 3.0)
	_bob += dt
	rotation = Vector3(sin(_bob * 1.3 + ship_id) * 0.015, _yaw, cos(_bob * 1.1 + ship_id) * 0.012)
	position.y = Layout.WATER_Y + sin(_bob * 1.6 + ship_id) * 0.08
	_sync_wake(0.0 if phase == Phase.BACK_IN else spd, dt)      # (lot H2 : en marche arrière, pas de sillage en V)


func _sync_cargo() -> void:
	var n := slots.size()
	var shown := n
	match phase:
		Phase.CRAB_OUT, Phase.OUTBOUND, Phase.DONE:
			shown = 0
		Phase.MOORED:
			shown = ceili(float(n) * cargo_frac - 0.001)
	if shown != _shown:
		_shown = shown
		cargo_mm.multimesh.visible_instance_count = shown


# ---------------------------------------------------------------------------
# Remorqueur
# ---------------------------------------------------------------------------

func _ensure_tug() -> void:
	if tug != null and is_instance_valid(tug):
		return
	tug = Assets.instance("tug")
	if get_parent() != null:
		get_parent().add_child(tug)
	else:
		add_child(tug)
	tug.position = Vector3(TUG_BASE.x, Layout.WATER_Y, TUG_BASE.z)


## Pilotage : le remorqueur part de sa base au rendez-vous (entrée du chenal, ou passe est), y attend le navire et le prend.
func _call_tug() -> void:
	_ensure_tug()
	_tug_state = "meet"
	_tug_meet = TUG_MEET_E if berth_i >= Layout.EAST_BERTH0 else TUG_MEET_W


func _tug_home() -> void:
	if tug != null:
		_tug_state = "home"


func _free_tug() -> void:
	if tug != null and is_instance_valid(tug):
		tug.queue_free()
	tug = null
	_tug_state = ""


## Le remorqueur est-il à poste contre le navire ?
func _tug_ready() -> bool:
	if tug == null or not is_instance_valid(tug) or _tug_state != "attached":
		return false
	var st: Vector3 = _tug_station()[0]
	return Vector2(tug.position.x - st.x, tug.position.z - st.z).length() < 3.0


## Remorqueur à poste (tests, captures).
func tug_attached() -> bool:
	return _tug_ready()


## Poste du remorqueur : en tête (remorque) dans le chenal et dans le port ; à la hanche pendant l'évitage et l'approche (côté
## intérieur du virage : il pousse la poupe vers l'extérieur) ; à l'épaule côté large pendant le glissement vers le quai (il
## pousse) ; au large, remorque tendue, pendant le glissement inverse (il tire) ; à la hanche pendant la manœuvre de départ.
func _tug_station() -> Array:
	var fwd := Vector3(cos(_yaw), 0, -sin(_yaw))
	var side := Vector3(sin(_yaw), 0, cos(_yaw))       # tribord
	var hw := width * 0.5 + 1.7
	var here := Vector3(position.x, Layout.WATER_Y, position.z)
	if absf(_turn) > 0.04:
		_tug_side = 1.0 if _turn < 0.0 else -1.0      # virage à gauche (cap qui croît) : bâbord ; à droite : tribord
	# lot H2 : côté eau du poste (vers l'axe de la darse) ; le remorqueur pousse depuis l'axe, tire vers l'axe
	var s2 := Layout.berth_sea(maxi(0, berth_i))
	var sea := Vector3(s2.x, 0, s2.y)
	var sea_yaw := atan2(-sea.z, sea.x)
	match phase:
		Phase.INBOUND:
			if _gates.size() >= 2 and _d < float(_gates[1]) - 30.0:
				return [here + fwd * (length * 0.5 + 7.0), _yaw]
			return [here - fwd * (length * 0.32) + side * (hw * _tug_side), _yaw - PI * 0.5 * _tug_side]
		Phase.BACK_IN:
			# à la proue (côté large), face au navire : il retient et oriente l'étrave pendant le recul
			return [here + fwd * (length * 0.5 + 6.0), _yaw + PI]
		Phase.CRAB_IN:
			return [here + fwd * (length * 0.22) + sea * hw, sea_yaw + PI]
		Phase.CRAB_OUT, Phase.MOORED:
			return [here + fwd * (length * 0.2) + sea * (width * 0.5 + 6.0), sea_yaw]
		Phase.OUTBOUND:
			return [here - fwd * (length * 0.32) + side * (hw * _tug_side), _yaw - PI * 0.5 * _tug_side]
	return [here + fwd * (length * 0.5 + 7.0), _yaw]


func _sync_tug(dt: float) -> void:
	if tug == null:
		return
	if not is_instance_valid(tug):
		tug = null
		return
	var target := Vector3(TUG_BASE.x, Layout.WATER_Y, TUG_BASE.z)
	var ty := tug.rotation.y
	var follow := false
	match _tug_state:
		"meet":
			target = Vector3(_tug_meet.x, Layout.WATER_Y, _tug_meet.z)
			var near := Vector2(tug.position.x - position.x, tug.position.z - position.z).length() < 26.0
			if phase != Phase.INBOUND or near or (not _gates.is_empty() and _d >= float(_gates[0]) - 30.0):
				_tug_state = "attached"
		"attached":
			var st := _tug_station()
			target = st[0]
			ty = st[1]
			follow = true
			if phase == Phase.OUTBOUND and _d > _man_end + 8.0:
				_tug_home()
			elif phase == Phase.LEAVE or phase == Phase.ANCHOR or phase == Phase.ARRIVE or phase == Phase.DONE:
				_tug_home()
		"home":
			if Vector2(tug.position.x - TUG_BASE.x, tug.position.z - TUG_BASE.z).length() < 1.5:
				_free_tug()
				return
	var d := target - tug.position
	d.y = 0.0
	var dist := d.length()
	if follow and dist < 4.0:
		tug.position = tug.position.lerp(target, 1.0 - exp(-dt * 6.0))
	elif dist > 0.001:
		tug.position += d / dist * minf(dist, TUG_SPEED * dt)
	tug.position.y = Layout.WATER_Y
	var goal_y := ty if (follow and dist < 4.0) else (atan2(-d.z, d.x) if dist > 0.5 else tug.rotation.y)
	tug.rotation.y += clampf(angle_difference(tug.rotation.y, goal_y), -TUG_TURN * dt, TUG_TURN * dt)


# ---------------------------------------------------------------------------
# Sillage
# ---------------------------------------------------------------------------

## Sillage en V : deux traînées d'écume qui s'ouvrent depuis la poupe et s'estompent vers l'arrière (dégradé), visibles
## seulement quand le navire avance (revue du 13/10 : plus de bande droite).
const WAKE_LEN := 18.0
const WAKE_ANGLE := 0.26
static var _wake_tex: GradientTexture2D


func _sync_wake(spd: float, delta: float) -> void:
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
	# (lot F1 : vitesses de croisière 5–7,5 u/s, au lieu des 10–60 u/s d'avant — l'écume se règle sur la croisière)
	m2.albedo_color.a = lerpf(m2.albedo_color.a, clampf(spd / 8.0, 0.0, 0.7), 1.0 - exp(-delta * 4.0))
	wake.visible = m2.albedo_color.a > 0.02


func _exit_tree() -> void:
	_free_tug()


## Point d'ancrage des bulles (au-dessus de la passerelle).
func bubble_point() -> Vector3:
	return position + Vector3(0, 9.0, 0)


func is_waiting(s: Ship) -> bool:
	return s.state == Ship.State.ANCHORED or s.state == Ship.State.ARRIVING
