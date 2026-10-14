class_name TrafficView
extends Node3D
## Circulation à sens unique du plan de la baie (habillage : calée sur `truck_served`, aucune simulation ici).
## Camions : sortie du tunnel ouest → autoroute → voie d'entrée → file / aire d'attente → gate d'entrée → voie des camions
## → arrêt devant le bloc qui le sert → le conteneur descend de l'engin sur la remorque → bout de la boucle → gate de sortie
## → autoroute → tunnel est. Ils n'apparaissent et ne disparaissent que sous les collines-tunnels, hors écran.
## Engins (côté mer) : grue → tablier → bloc réel → bord du parc → camion. Train (T3) et navette du tracteur entre le parc
## RTG et la gare, personnel, voitures civiles.

const QUEUE_X := -22.5          # voie d'entrée (vers le nord, la gate)
const ROAD_SLOTS := 5           # places de file sur la route avant de passer dans l'aire d'attente
const SPEED := 15.0             # u/s sur la route et dans le port
const HIGHWAY_SPEED := 24.0     # u/s sur l'autoroute (les trajets jusqu'aux tunnels sont longs)
const OUT_GAP := 0.7            # écart minimal (s réelles) entre deux camions servis affichés
const MAX_LEAVING := 16
const HEAD_NORTH := 90.0        # cap d'un camion garé (face au nord)
const LOAD_WAIT := 3.0          # sans engin libre, attente au point de chargement (puis le conteneur passe quand même)
const LOAD_WAIT_MAX := 30.0     # garde-fou : un engin en route est attendu au plus ce temps
const TRANSFER_TIME := 0.6      # descente du conteneur sur la remorque (s)
const STOP_GAP := 6.8           # écart minimal entre deux camions arrêtés le long du parc (un camion : 6,25 u)

var queue: Array[Node3D] = []
var trucks: Array[Dictionary] = []      # camions dans le port {node, route, phase, stop_x, t, container, loader}
var vehicles: Array[Dictionary] = []    # engins du parc {node, route, task, carry, x_slot, x_apron, truck}
var cars: Array[Dictionary] = []        # voitures civiles {node, dir, speed}
var barriers: Array[Node3D] = []
var _out_cool := 0.0
var _vehicle_kind := ""
var train: Node3D
var _train_t := -1.0
var _train_next := 3.0
var rng := RandomNumberGenerator.new()
var yard: YardView
## Personnages qui marchent : {node, a, b, t (0→1 vers b), dir (+1 vers b, −1 vers a), wait (pause au bout, s), phase}
var walkers: Array[Dictionary] = []
var walk_paused := false        # un écran couvre le monde : les personnages s'arrêtent
const WALK_SPEED := 1.7         # u/s
const WALK_PAUSE := 1.2         # s d'arrêt à chaque bout, pendant lequel il fait demi-tour (progressif, lot D)
const WALK_TURN := 6.0          # vitesse du demi-tour (1/s)
var _bob := 0.0
var _lot_slots := 0
var _honk_cool := 0.0
var _tier := 1
var _gate2 := false
var loads_done := 0             # camions chargés (tests)
## Point du monde visible à l'écran ? (réglé par le diorama ; depuis E-Flux, le train ne s'en sert plus : il est découpé à la
## bouche du tunnel).
var on_screen: Callable


func _seen(p: Vector3) -> bool:
	return on_screen.is_valid() and bool(on_screen.call(p))


func _make_truck(loaded: bool, sim: PortSim) -> Node3D:
	var t := Assets.instance("truck")
	if loaded:
		t.add_child(_make_container(sim))
	return t


## Conteneur posé sur la remorque d'un camion (position lue dans assets_meta.json).
func _make_container(sim: PortSim) -> MeshInstance3D:
	var c := MeshInstance3D.new()
	c.mesh = Assets.mesh("container40")
	var m: ShaderMaterial = Assets.vcol_material.duplicate()
	m.set_shader_parameter("tint", ShipView.cargo_color(sim, 0, rng.randi()).linear_to_srgb())
	c.material_override = m
	c.name = "container"
	return c


func _trailer_pos() -> Vector3:
	var meta := Assets.meta("truck")
	return Vector3(float(meta.get("container_x", -0.6)), float(meta.get("container_z", 1.0)), 0)


func set_barriers(list: Array[Node3D]) -> void:
	barriers = list


## Nombre de camions affichables : la route, puis l'aire d'attente, puis un débordement sur la route.
func max_queue() -> int:
	return ROAD_SLOTS + _lot_slots + 4 if _lot_slots > 0 else 9


## Voie d'entrée de la route d'accès (circulation à droite, lot D : à l'est ; une seule voie, la file attend dessus).
func _in_x(_i: int = 0) -> float:
	return Layout.road_in_x(_gate2)


## Position de la place `i` de la file : sur la voie d'entrée, puis dans l'aire d'attente, puis de nouveau sur la route.
func slot_pos(i: int) -> Vector3:
	if i < ROAD_SLOTS or _lot_slots <= 0:
		return Vector3(_in_x(), 0, Layout.QUEUE_Z0 + i * Layout.QUEUE_GAP)
	var j := i - ROAD_SLOTS
	if j < _lot_slots:
		return Layout.lot_slot(j)
	var k := ROAD_SLOTS + j - _lot_slots
	return Vector3(_in_x(), 0, Layout.QUEUE_Z0 + k * Layout.QUEUE_GAP)


## Avance un véhicule le long de sa route ; renvoie true quand elle est finie.
func _drive(t: Node3D, route: Array, speed: float, delta: float, park_yaw: float = INF) -> bool:
	if route.is_empty():
		if park_yaw != INF:
			t.rotation.y = lerp_angle(t.rotation.y, park_yaw, 1.0 - exp(-delta * 6.0))
		return true
	var tgt: Vector3 = route[0]
	var d := tgt - t.position
	d.y = 0.0
	var step := speed * delta
	if d.length() <= step:
		t.position = Vector3(tgt.x, t.position.y, tgt.z)
		route.pop_front()
	else:
		t.position += d.normalized() * step
		t.rotation.y = lerp_angle(t.rotation.y, atan2(-d.z, d.x), 1.0 - exp(-delta * 10.0))
	return route.is_empty()


func _assign(t: Node3D, target: Vector3) -> void:
	if t.has_meta("target") and (t.get_meta("target") as Vector3).is_equal_approx(target):
		return
	t.set_meta("target", target)
	t.set_meta("route", road_route(t.position, target))


## Le camion est-il dans l'aire d'attente (à l'est de la route d'accès) ?
static func _in_lot(p: Vector3) -> bool:
	return p.x > -14.0 and p.z > 50.0 and p.z < Layout.HIGHWAY_Z0 - 1.0


## Itinéraire par les routes depuis `from` (autoroute, voie d'entrée ou aire d'attente) jusqu'à la place `target` de la
## file : bretelle de la voie d'entrée, voie d'entrée, puis la place (revue C7 A2 : plus de diagonale à travers les terres
## quand la place d'un camion change). Lot D : une seule voie d'entrée (à l'est, circulation à droite).
func road_route(from: Vector3, target: Vector3) -> Array:
	var in_x := _in_x()
	var r: Array = []
	if from.z > Layout.HIGHWAY_Z0 - 1.0:
		# sur l'autoroute (voie vers l'est, au sud) : jusqu'à la bretelle de la voie d'entrée
		if from.x < in_x - 3.0:
			r.append(Vector3(in_x - 3.0, 0, Layout.HIGHWAY_LANE_E))
		r.append(Vector3(in_x, 0, Layout.HIGHWAY_LANE_E - 3.0))
	elif _in_lot(from):
		if _in_lot(target):
			return [target]             # d'une place de l'aire à une autre : on reste dans l'aire
		r.append(Vector3(from.x, 0, from.z - 3.0))
		r.append(Vector3(in_x, 0, from.z - 5.0))
	elif absf(from.x - in_x) > 0.5:
		r.append(Vector3(in_x, 0, from.z - 2.0))      # changement de voie sur la route d'accès (gate2 construite)
	if absf(target.x - in_x) > 0.5:
		r.append(Vector3(in_x, 0, target.z))
	r.append(target)
	return r


## Camion en trop dans la file (la gate a rattrapé, nouvelle concession…) : il repart vers le tunnel est par les routes —
## sur l'autoroute il poursuit sa route, sinon demi-tour sur la voie de sortie, autoroute (jamais effacé à l'écran, jamais
## en diagonale à travers les terres).
func exit_route(from: Vector3) -> Array:
	var east := Vector3(float(Layout.HIGHWAY_ENDS[1]), 0, Layout.HIGHWAY_LANE_E)
	if from.z > Layout.HIGHWAY_Z0 - 1.0:
		return [Vector3(from.x + 2.0, 0, Layout.HIGHWAY_LANE_E), east]
	var out_x := Layout.road_out_x(_gate2)
	var r: Array = []
	if _in_lot(from):
		r.append(Vector3(from.x, 0, from.z + 3.0))
	r.append_array([Vector3(out_x, 0, from.z + 4.0), Vector3(out_x, 0, Layout.HIGHWAY_LANE_W - 2.0),
		Vector3(out_x + 2.0, 0, Layout.HIGHWAY_LANE_E), east])
	return r


func on_truck_served(sim: PortSim) -> void:
	# en vitesse accélérée la gate sert plusieurs camions par image : on n'en montre qu'un par OUT_GAP
	if _out_cool > 0.0 or trucks.size() >= MAX_LEAVING:
		return
	var stop_x := _pick_stop()
	if is_nan(stop_x):
		return          # tous les points de chargement sont pris : le camion attend son tour dans la file
	_out_cool = OUT_GAP
	var head: Node3D
	var route: Array = []
	var in_x := _in_x()
	if queue.is_empty():
		# la file affichée est vide (gate très rapide) : un camion arrive tout de même, depuis le tunnel ouest
		head = _make_truck(false, sim)
		var arr := Layout.truck_route_arrive(in_x, Vector3(in_x, 0, Layout.GATE_IN_Z + 6.0))
		head.position = arr[0]
		add_child(head)
		route.append_array(arr.slice(1))
	else:
		head = queue.pop_front()
		route.append_array(head.get_meta("route", []))      # il finit d'abord son trajet jusqu'à sa place
		var hp: Vector3 = route[-1] if not route.is_empty() else head.position
		if absf(hp.x - in_x) > 0.5:      # depuis l'aire d'attente : on rejoint la voie d'entrée
			route.append(Vector3(hp.x, 0, hp.z - 3.0))
			route.append(Vector3(in_x, 0, hp.z - 5.0))
	# lot D : la boucle se fait à l'aller (voie A), le chargement au retour (voie B, le long du parc) ; E-Flux (E8) : demi-tour
	# au bout du groupe de blocs de l'arrêt (Layout.tier_for_stop), plus au bout de la boucle du palier
	route.append_array(Layout.truck_route_in(in_x, stop_x))
	trucks.append({"node": head, "route": route, "phase": "in", "stop_x": stop_x, "t": 0.0, "container": null, "loader": -1})


## Arrêt d'un camion : devant une travée réelle du parc (un conteneur y est stocké), dans la boucle du palier.
func _pick_stop() -> float:
	var rg := Layout.stop_range(_tier, _gate2)      # (E-Flux, E7 : de quoi se ranger et repartir en biais doux)
	var x0 := float(rg[0])
	var x1 := float(rg[1])
	var cands: Array[float] = []
	if yard != null:
		for p in yard.visible_slots(0):
			var v: Vector3 = p
			if v.x >= x0 and v.x <= x1 and _stop_free(v.x):
				cands.append(v.x)
	if cands.is_empty():
		var x := x0
		while x <= x1:
			if _stop_free(x):
				cands.append(x)
			x += 4.4
	if cands.is_empty():
		return NAN
	return cands[rng.randi_range(0, cands.size() - 1)]


## Point de chargement libre : aucun autre camion n'y est arrêté ou en route (un camion de long, 7,5 u).
func _stop_free(x: float) -> bool:
	for tk in trucks:
		if String(tk.phase) != "out" and absf(float(tk.stop_x) - x) < STOP_GAP:
			return false
	return true


func _spawn_queue_truck(sim: PortSim) -> void:
	var t := _make_truck(false, sim)
	var slot := slot_pos(queue.size())
	var r := Layout.truck_route_arrive(_in_x(), slot)
	t.position = r[0]
	r.pop_front()
	t.rotation.y = 0.0
	add_child(t)
	t.set_meta("route", r)
	t.set_meta("target", slot)
	queue.append(t)


func sync(sim: PortSim, delta: float) -> void:
	_bob += delta
	_out_cool = maxf(0.0, _out_cool - delta)
	_lot_slots = sim.parking_slots
	_tier = sim.tier
	_gate2 = sim.built.has("gate2")
	# file de camions = camions en attente dans la simulation (plafonné visuellement)
	var want := mini(max_queue(), sim.trucks_waiting())
	while queue.size() < want:
		_spawn_queue_truck(sim)
	# camions en trop : ils repartent vers le tunnel est par la voie de sortie (jamais effacés à l'écran)
	while queue.size() > want and queue.size() > 0:
		var last: Node3D = queue.pop_back()
		trucks.append({"node": last, "route": exit_route(last.position), "phase": "out", "stop_x": 0.0, "t": 0.0, "container": null, "loader": -1})
	var honk := sim.trucks_honking() > 0
	_honk_cool = maxf(0.0, _honk_cool - delta)
	if honk and _honk_cool <= 0.0:
		_honk_cool = 7.0
		Sfx.play("truck_honk", 2.0)
	for i in queue.size():
		var t: Node3D = queue[i]
		_assign(t, slot_pos(i))
		var r: Array = t.get_meta("route", [])
		var spd := HIGHWAY_SPEED if t.position.z > Layout.HIGHWAY_Z0 - 1.0 else SPEED
		_drive(t, r, spd, delta, deg_to_rad(HEAD_NORTH))
		t.position.y = 0.04 * sin(_bob * 30.0 + i) if (honk and i < 3 and r.is_empty()) else 0.0
	_sync_trucks(sim, delta)
	_sync_barriers(delta)
	_sync_vehicles(sim, delta)
	_sync_train(sim, delta)
	_sync_shuttle(sim, delta)
	_sync_cars(delta)
	_sync_walkers(delta)


## Camions dans le port : entrée, arrêt et chargement devant le bloc, boucle, sortie, autoroute, tunnel.
func _sync_trucks(sim: PortSim, delta: float) -> void:
	var keep: Array[Dictionary] = []
	for tk in trucks:
		var n: Node3D = tk.node
		if not is_instance_valid(n):
			continue
		tk.t = float(tk.t) + delta
		match String(tk.phase):
			"in":
				if _drive(n, tk.route, HIGHWAY_SPEED if n.position.z > Layout.HIGHWAY_Z0 - 1.0 else SPEED, delta):
					tk.phase = "wait"
					tk.t = 0.0
					_call_loader(tk, sim)
			"wait":
				# E-Flux (E7) : arrêté sur la voie B, face à l'ouest (cap d'arrivée et de départ à moins de 30°) — plus de pivot
				n.rotation.y = lerp_angle(n.rotation.y, Layout.LOAD_YAW, 1.0 - exp(-delta * 8.0))
				if int(tk.loader) < 0 and float(tk.t) > 0.8:
					_call_loader(tk, sim)
				var ld: int = tk.loader
				# l'engin est arrivé au bord du parc avec son conteneur : le conteneur passe sur la remorque. Un engin en route
				# est attendu (revue C7 A7 : LOAD_WAIT ne coupe plus un trajet de 4 à 15 s) ; sans engin libre, le conteneur
				# passe quand même au bout de LOAD_WAIT s (LOAD_WAIT_MAX : garde-fou)
				var ready := ld >= 0 and ld < vehicles.size() and String(vehicles[ld].task) == "at_truck"
				if ready or (ld < 0 and float(tk.t) > LOAD_WAIT) or float(tk.t) > LOAD_WAIT_MAX:
					_start_transfer(tk, sim, ready)
			"loading":
				if float(tk.t) >= TRANSFER_TIME:
					tk.phase = "out"
					loads_done += 1
					tk.route = Layout.truck_route_out(n.position.x, _tier, _gate2, loads_done % 2)      # gate2 : une voie de sortie sur deux
			"out":
				var spd := HIGHWAY_SPEED if n.position.z > Layout.HIGHWAY_Z0 - 1.0 else SPEED
				if _drive(n, tk.route, spd, delta):
					n.queue_free()          # sous la colline-tunnel est, hors écran
					continue
		keep.append(tk)
	trucks = keep


## Un engin libre va chercher un conteneur au bloc et l'apporte au bord du parc, devant le camion.
func _call_loader(tk: Dictionary, sim: PortSim) -> void:
	var best := -1
	var best_d := INF
	for i in vehicles.size():
		var v: Dictionary = vehicles[i]
		if String(v.task) != "idle" and String(v.task) != "to_block":
			continue
		var d := absf((v.node as Node3D).position.x - float(tk.stop_x))
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return
	var v2: Dictionary = vehicles[best]
	v2.task = "to_truck"
	v2.truck = tk
	v2.x_slot = float(tk.stop_x)
	var n: Node3D = v2.node
	# il rejoint l'allée transversale par le chemin le plus court des allées, puis le bord du parc
	var r: Array = []
	if absf(n.position.z - Layout.YARD_AISLE_Z) > 0.5:
		var ax := Layout.aisle_x(n.position.x)
		r.append(Vector3(ax, 0, n.position.z))
		r.append(Vector3(ax, 0, Layout.YARD_AISLE_Z))
	r.append(Vector3(float(tk.stop_x), 0, Layout.YARD_AISLE_Z))
	r.append_array(Layout.engine_route_to_truck(float(tk.stop_x)).slice(1))
	v2.route = r
	_carry(v2, sim, true)      # il prend le conteneur au bloc en passant
	tk.loader = best


## Le conteneur descend de l'engin (ou du bord du parc) sur la remorque ; le camion repartira chargé.
func _start_transfer(tk: Dictionary, sim: PortSim, from_vehicle: bool) -> void:
	var n: Node3D = tk.node
	var c: MeshInstance3D
	var start := Vector3(float(tk.stop_x), 2.6, Layout.LOAD_EDGE_Z)
	var ld: int = tk.loader
	if from_vehicle and ld >= 0 and ld < vehicles.size() and vehicles[ld].carry != null:
		c = vehicles[ld].carry
		start = c.global_position
		c.get_parent().remove_child(c)
		vehicles[ld].carry = null
	else:
		c = _make_container(sim)
	if ld >= 0 and ld < vehicles.size():
		var v: Dictionary = vehicles[ld]
		v.task = "back"
		v.truck = null
		# retour au tablier par les allées, depuis là où il est (au bord du parc, ou encore en chemin)
		v.route = Layout.engine_route_home((v.node as Node3D).position, _apron_x(sim))
	n.add_child(c)
	c.global_position = start
	var tw := c.create_tween()
	tw.tween_property(c, "position", _trailer_pos(), TRANSFER_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	c.rotation = Vector3.ZERO
	tk.container = c
	tk.phase = "loading"
	tk.t = 0.0
	tk.loader = -1


## Retour d'achat (lot D, Diorama.feedback_purchase) : les engins du parc tressaillent.
func kick_vehicles() -> void:
	for v in vehicles:
		var n: Node3D = v.node
		if not is_instance_valid(n):
			continue
		var tw := n.create_tween()
		tw.tween_property(n, "scale", Vector3(1.12, 0.9, 1.12), 0.07)
		tw.tween_property(n, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)


## Retour d'achat (lot D) : les barrières de la gate se lèvent un instant.
var _barrier_kick := 0.0


func kick_barriers() -> void:
	_barrier_kick = 0.9


## Barrières : la barrière d'entrée se lève quand un camion la franchit, celle de sortie de même.
func _sync_barriers(delta: float) -> void:
	_barrier_kick = maxf(0.0, _barrier_kick - delta)
	for b in barriers:
		if not is_instance_valid(b):
			continue
		var lane := String(b.get_meta("lane", "in"))
		var gz := Layout.GATE_IN_Z if lane == "in" else Layout.GATE_OUT_Z
		# milieu du bras (la barrière pivote à un bord de la route ; lot D : deux voies de sortie avec gate2)
		var arm_x := b.position.x + 1.9 * b.scale.x * cos(b.rotation.y)
		var open := _barrier_kick > 0.0
		for tk in trucks:
			var p: Vector3 = (tk.node as Node3D).position
			var on_lane := (lane == "in" and String(tk.phase) == "in") or (lane == "out" and String(tk.phase) == "out")
			if on_lane and absf(p.z - gz) < 4.5 and absf(p.x - arm_x) < 2.6:
				open = true
				break
		b.rotation.z = lerp_angle(b.rotation.z, deg_to_rad(80.0) if open else 0.0, 1.0 - exp(-delta * 8.0))


## Ajoute un personnage qui fait l'aller-retour entre a et b (pas de pathfinding : segment droit, demi-tour instantané).
func add_walker(node: Node3D, a: Vector3, b: Vector3) -> void:
	walkers.append({"node": node, "a": a, "b": b, "t": 0.0, "dir": 1.0, "wait": float(walkers.size() % 3) * 0.4, "phase": float(walkers.size()) * 1.3})


func _sync_walkers(delta: float) -> void:
	if walk_paused:
		return
	for w in walkers:
		var n: Node3D = w.node
		if not is_instance_valid(n):
			continue
		var a: Vector3 = w.a
		var b: Vector3 = w.b
		var len := maxf(0.5, a.distance_to(b))
		# demi-tour progressif (lot D) : il se tourne pendant sa pause au bout du trajet, au lieu de pivoter d'un coup
		var face := (b - a) * float(w.dir)
		if face.length() > 0.01:
			n.rotation.y = lerp_angle(n.rotation.y, atan2(face.x, face.z), 1.0 - exp(-delta * WALK_TURN))
		if float(w.wait) > 0.0:
			w.wait = float(w.wait) - delta
			n.position.y = a.y
			continue
		w.t = float(w.t) + float(w.dir) * delta * WALK_SPEED / len
		if float(w.t) >= 1.0 or float(w.t) <= 0.0:
			w.t = clampf(float(w.t), 0.0, 1.0)
			w.dir = -float(w.dir)
			w.wait = WALK_PAUSE
		var p := a.lerp(b, float(w.t))
		w.phase = float(w.phase) + delta * 9.0
		p.y = a.y + absf(sin(float(w.phase))) * 0.07     # léger balancement vertical (pas)
		n.position = p          # (face à sa destination, face principale du modèle en +Z : voir plus haut)


## Voitures civiles : de l'activité sur l'autoroute, indépendante de la simulation ; elles passent d'un tunnel à l'autre.
func _sync_cars(delta: float) -> void:
	var x_min: float = Layout.HIGHWAY_ENDS[0]
	var x_max: float = Layout.HIGHWAY_ENDS[1]
	if cars.is_empty():
		for i in 7:
			var east := i % 2 == 0
			var n := Assets.instance("car_a" if i % 3 != 0 else "car_b")
			n.rotation.y = 0.0 if east else PI
			n.position = Vector3(x_min + 10.0 + float(i) * 42.0, 0, Layout.HIGHWAY_LANE_E - 0.2 if east else Layout.HIGHWAY_LANE_W + 0.2)
			add_child(n)
			cars.append({"node": n, "dir": 1.0 if east else -1.0, "speed": 9.0 + float(i % 4) * 2.5})
	for c in cars:
		var n: Node3D = c.node
		n.position.x += float(c.dir) * float(c.speed) * delta
		if n.position.x > x_max:
			n.position.x = x_min
		elif n.position.x < x_min:
			n.position.x = x_max


## Engins du parc : grue → tablier → bloc réel, et bloc → bord du parc → camion quand un camion attend.
func _sync_vehicles(sim: PortSim, delta: float) -> void:
	var kind := "forklift" if sim.tier == 1 else ("reach_stacker" if sim.tier == 2 or not sim.built.has("rtg") else "straddle")
	var count := clampi(sim.agents("yard_ops") + (1 if sim.managers.yard_ops else 0), 1, 7)
	if kind != _vehicle_kind:
		for v in vehicles:
			(v.node as Node3D).queue_free()
		vehicles.clear()
		_vehicle_kind = kind
		for tk in trucks:
			tk.loader = -1
	while vehicles.size() < count:
		var n := Assets.instance(kind)
		add_child(n)
		_add_beacon(n, kind)
		var xa := _apron_x(sim)
		n.position = Vector3(xa, 0, Layout.APRON_LANE_Z)
		vehicles.append({"node": n, "route": [], "task": "idle", "carry": null, "x_slot": 0.0, "x_apron": xa, "truck": null})
	while vehicles.size() > count:
		var v: Dictionary = vehicles.pop_back()
		(v.node as Node3D).queue_free()
		for tk in trucks:
			if int(tk.loader) >= vehicles.size():
				tk.loader = -1
	var speed := clampf(4.0 + sqrt(maxf(sim.stat("transfer_rate"), 0.0)) * 1.2, 4.0, 14.0)
	var active := sim.apron_stock() > 0.5 or sim.yard_stock() > 1.0
	for v in vehicles:
		var n: Node3D = v.node
		var task := String(v.task)
		if task == "at_truck":
			continue
		if task == "to_truck":
			if _drive(n, v.route, speed, delta):
				v.task = "at_truck"
			continue
		if not active and task == "idle":
			continue
		if _drive(n, v.route, speed, delta):
			match task:
				"idle", "back":
					if not active:
						v.task = "idle"       # rien à transporter : il attend au tablier (revue C7 A7)
						continue
					# au tablier : il prend un conteneur au pied d'une grue et l'emporte vers une travée réelle du parc
					var xs := _slot_x()
					v.x_slot = xs
					v.route = Layout.engine_route_to_block(n.position.x, xs).slice(1)
					v.task = "to_block"
					_carry(v, sim, true)
				"to_block":
					# conteneur posé dans le bloc ; retour au tablier
					_carry(v, sim, false)
					var xa := _apron_x(sim)
					var back := Layout.engine_route_to_block(xa, float(v.x_slot))
					back.reverse()
					v.route = back.slice(1)
					v.task = "back"


## Conteneur porté par un engin (sur les fourches, ou entre les jambes du cavalier).
func _carry(v: Dictionary, sim: PortSim, on: bool) -> void:
	if on and v.carry == null:
		var c := _make_container(sim)
		c.position = Vector3(2.4 if _vehicle_kind == "forklift" else 0.4, 1.0 if _vehicle_kind == "forklift" else 2.2, 0)
		(v.node as Node3D).add_child(c)
		v.carry = c
	elif not on and v.carry != null:
		(v.carry as Node).queue_free()
		v.carry = null


## Abscisse d'une travée réelle du parc (un emplacement de conteneur visible), sinon d'un bloc.
func _slot_x() -> float:
	if yard != null:
		var vs := yard.visible_slots(0)
		if not vs.is_empty():
			return (vs[rng.randi_range(0, vs.size() - 1)] as Vector3).x
		var all := yard.zone_slots[0] as Array
		if not all.is_empty():
			return (all[rng.randi_range(0, all.size() - 1)] as Vector3).x
	return Layout.YARD_CENTER.x


## Point du tablier au pied d'une grue (là où elle pose ses conteneurs).
func _apron_x(sim: PortSim) -> float:
	var bi := rng.randi_range(0, sim.berths.size() - 1)
	var b: Dictionary = Layout.BERTHS[mini(bi, Layout.BERTHS.size() - 1)]
	var x1 := float(b.x1) - (12.0 if bi == 0 and not sim.built.has("quay_ext") else 0.0)
	return rng.randf_range(float(b.x0) + 3.0, x1 - 3.0)


## Train (gare, T3) : il sort du tunnel est, s'arrête au quai de la gare (Layout.TRAIN_DWELL s), puis repart vers l'est.
## Lot E-Flux (E12) : la rame est découpée à la bouche du tunnel, sous la colline (shader vcol_clip, Layout.RAIL_TUNNEL_X) —
## elle entre et sort sous la colline et reste visible quand la gare est à l'écran (avant : elle n'apparaissait que si les
## deux bouts de la voie étaient hors champ, donc presque jamais en regardant la gare).
var _clip_mat: ShaderMaterial
var trains_run := 0             # passages de train commencés (tests)


func _train_material(tint: Color = Color.WHITE) -> ShaderMaterial:
	if _clip_mat == null:
		_clip_mat = ShaderMaterial.new()
		_clip_mat.shader = load("res://assets/vcol_clip.gdshader")
		_clip_mat.set_shader_parameter("vertex_is_srgb", Assets.VERTEX_IS_SRGB)
		_clip_mat.set_shader_parameter("clip_x", Layout.RAIL_TUNNEL_X)
	if tint == Color.WHITE:
		return _clip_mat
	var m: ShaderMaterial = _clip_mat.duplicate()
	m.set_shader_parameter("tint", tint)
	return m


## Abscisses de la rame : caché dans le tunnel (toute la rame à l'est de la bouche), arrêt au quai.
static func train_x_hidden() -> float:
	return Layout.RAIL_TUNNEL_X + 5.0


static func train_x_stop() -> float:
	return (Layout.LOTS.rail.p as Vector3).x - 6.0


func _train_run() -> float:
	return (train_x_hidden() - train_x_stop()) / 12.0


## Le train est-il arrêté au quai (la navette du tracteur travaille) ?
func train_at_quay() -> bool:
	var run := _train_run()
	return train != null and _train_t >= run and _train_t < run + Layout.TRAIN_DWELL


func _sync_train(sim: PortSim, delta: float) -> void:
	if not sim.built.has("rail"):
		if train != null:        # nouvelle concession : le terminal rail n'existe plus, le train ne doit pas rester figé sur la voie
			train.queue_free()
			train = null
			_train_t = -1.0
			_train_next = 3.0
		return
	if train == null:
		train = Node3D.new()
		add_child(train)
		var loco := Assets.instance("locomotive", _train_material())
		loco.rotation.y = PI          # la locomotive en tête vers l'ouest
		train.add_child(loco)
		for i in 4:
			var w := Assets.instance("wagon", _train_material())
			w.position = Vector3(9.6 * (i + 1), 0, 0)
			train.add_child(w)
			for sx in [-2.1, 2.1]:
				var c := MeshInstance3D.new()
				c.mesh = Assets.mesh("container20")
				c.material_override = _train_material(ShipView.cargo_color(sim, 0, rng.randi()).linear_to_srgb())
				c.position = Vector3(sx, 0.95, 0)
				w.add_child(c)
		train.position = Vector3(train_x_hidden(), 0.2, Layout.RAIL_Z)
	var x_hidden := train_x_hidden()
	var x_stop := train_x_stop()
	var run := _train_run()
	_train_next -= delta
	if _train_t < 0.0 and _train_next <= 0.0:
		_train_t = 0.0
		trains_run += 1
	var x := x_hidden
	if _train_t >= 0.0:
		_train_t += delta
		if _train_t < run:
			x = lerpf(x_hidden, x_stop, smoothstep(0.0, 1.0, _train_t / run))
		elif _train_t < run + Layout.TRAIN_DWELL:
			x = x_stop
		else:
			x = lerpf(x_stop, x_hidden, smoothstep(0.0, 1.0, (_train_t - run - Layout.TRAIN_DWELL) / run))
		if _train_t > run * 2.0 + Layout.TRAIN_DWELL:
			_train_t = -1.0
			_train_next = 30.0
			x = x_hidden
	train.position = Vector3(x, 0.2, Layout.RAIL_Z)
	train.visible = x < x_hidden - 0.01      # rentré dans le tunnel : rien à dessiner


## Navette du tracteur de terminal (E-Flux, E12) : tant que le train est à quai, il prend un conteneur au parc RTG (allée
## x 90,1), traverse la voie des camions au passage à niveau signalé — il attend qu'aucun camion n'en approche — et le
## dépose au quai de la gare ; sinon il attend à son garage, sur la liaison.
var tractor: Node3D
var _sh := {"phase": "park", "route": [], "t": 0.0, "box": null}
var shuttles_done := 0          # conteneurs déposés à la gare (tests)
var shuttle_waits := 0          # attentes au passage à niveau (tests)
const SHUTTLE_SPEED := 9.0
## Un camion à moins de cette distance (x) du passage, sur la voie des camions, le ferme au tracteur (u).
const CROSSING_GUARD := 26.0


func crossing_clear() -> bool:
	var sx := float(Layout.RAIL_SHUTTLE.x)
	for tk in trucks:
		var n: Node3D = tk.node
		if not is_instance_valid(n):
			continue
		var p := n.position
		if p.z > float(Layout.LANE_BAND[0]) - 1.5 and p.z < float(Layout.LANE_BAND[1]) + 1.5 and absf(p.x - sx) < CROSSING_GUARD:
			return false
	return true


func _sync_shuttle(sim: PortSim, delta: float) -> void:
	if not sim.built.has("rail") or not sim.built.has(Layout.RECLAIM_BUILDING):
		if tractor != null:
			tractor.queue_free()
			tractor = null
		return
	var S: Dictionary = Layout.RAIL_SHUTTLE
	var sx := float(S.x)
	if tractor == null:
		tractor = Assets.instance("tractor")
		add_child(tractor)
		tractor.position = S.park
		tractor.rotation.y = deg_to_rad(HEAD_NORTH)
		_sh = {"phase": "park", "route": [], "t": 0.0, "box": null}
	var route: Array = _sh.route
	match String(_sh.phase):
		"park":
			if train_at_quay():
				_sh.route = [Vector3(sx, 0, float(S.hold))]
				_sh.phase = "to_cross_s"
		"to_cross_s":
			if _drive(tractor, route, SHUTTLE_SPEED, delta):
				_sh.phase = "cross_s"
				_sh.t = 0.0
		"cross_s":
			if not train_at_quay():          # le train est reparti : retour au garage
				_sh.route = [S.park]
				_sh.phase = "home"
			elif crossing_clear():
				_sh.route = [Vector3(sx, 0, float(S.pick_z))]
				_sh.phase = "down"
			elif float(_sh.t) == 0.0:
				shuttle_waits += 1
				_sh.t = 1.0
		"down":
			if _drive(tractor, route, SHUTTLE_SPEED, delta):
				_sh.phase = "pick"
				_sh.t = 0.0
				var c := _make_container(sim)
				tractor.add_child(c)
				c.position = Vector3(-0.9, 2.6, 0)
				c.create_tween().tween_property(c, "position", Vector3(-0.9, 1.05, 0), 0.5).set_trans(Tween.TRANS_QUAD)
				_sh.box = c
		"pick":
			_sh.t = float(_sh.t) + delta
			if float(_sh.t) > 0.9:
				_sh.phase = "cross_n"
				_sh.t = 0.0
		"cross_n":
			if crossing_clear():
				var lz := float(S.lane_z)
				_sh.route = [Vector3(sx, 0, float(S.hold)), Vector3(sx, 0, lz), Vector3(float(S.turn_x), 0, lz), S.drop]
				_sh.phase = "to_station"
			elif float(_sh.t) == 0.0:
				shuttle_waits += 1
				_sh.t = 1.0
		"to_station":
			if _drive(tractor, route, SHUTTLE_SPEED, delta):
				_sh.phase = "drop"
				_sh.t = 0.0
				var box: Node3D = _sh.box
				if box != null and is_instance_valid(box) and train != null:
					# le conteneur passe sur le wagon le plus proche (il y disparaît)
					var wx := train.position.x + 9.6 * clampf(roundf((tractor.position.x - train.position.x) / 9.6), 1.0, 4.0)
					var tw := box.create_tween()
					tw.tween_property(box, "global_position", Vector3(wx, 2.4, Layout.RAIL_Z), 0.7).set_trans(Tween.TRANS_QUAD)
					tw.tween_callback(box.queue_free)
				shuttles_done += 1
				_sh.box = null
		"drop":
			_sh.t = float(_sh.t) + delta
			if float(_sh.t) > 1.0:
				var lz2 := float(S.lane_z)
				_sh.route = [Vector3(float(S.turn_x), 0, lz2), Vector3(sx, 0, lz2)]
				_sh.route.append(Vector3(sx, 0, float(S.hold)) if train_at_quay() else S.park)
				_sh.phase = "to_cross_s" if train_at_quay() else "home"
				_sh.t = 0.0
		"home":
			if _drive(tractor, route, SHUTTLE_SPEED, delta, deg_to_rad(HEAD_NORTH)):
				_sh.phase = "park"




## Heures sup (lot D, Diorama.set_overtime) : un gyrophare sur chaque engin du parc (maillage et matériau partagés du
## diorama, qui le fait clignoter).
var beacons_on := false


func set_beacons(on: bool) -> void:
	beacons_on = on
	for v in vehicles:
		var n: Node3D = v.node
		if is_instance_valid(n) and n.has_node("beacon"):
			(n.get_node("beacon") as Node3D).visible = on


func _add_beacon(n: Node3D, kind: String) -> void:
	var parts := Diorama.beacon_parts()
	var bn := MeshInstance3D.new()
	bn.name = "beacon"
	bn.mesh = parts[0]
	bn.material_override = parts[1]
	bn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bn.position = Vector3(0, Assets.top_y(kind) + 0.25, 0)
	bn.visible = beacons_on
	n.add_child(bn)
