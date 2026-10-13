class_name TrafficView
extends Node3D
## Camions (arrivée par l'autoroute, file sur la route d'accès, attente dans l'aire, sortie chargée), barrières,
## engins du parc, train (T3), personnel, voitures civiles sur l'autoroute.

const QUEUE_X := -22.5          # voie d'entrée (vers le nord, la gate)
const OUT_X := -19.5            # voie de sortie (vers l'autoroute)
const QUEUE_Z0 := 37.0
const QUEUE_GAP := 7.5
const ROAD_SLOTS := 5           # places de file sur la route avant de passer dans l'aire d'attente
const SPEED := 15.0
const OUT_GAP := 0.7            # écart minimal (s réelles) entre deux camions sortants affichés
const MAX_LEAVING := 16
const HEAD_NORTH := 90.0        # cap d'un camion garé (face au nord)

var queue: Array[Node3D] = []
var leaving: Array[Dictionary] = []      # {node, t, kind, phase}
var vehicles: Array[Dictionary] = []     # engins du parc {node, a, b, t, dir, carry}
var cars: Array[Dictionary] = []         # voitures civiles {node, dir, speed}
var barriers: Array[Node3D] = []
var _barrier_open := 0.0
var _out_cool := 0.0
var _vehicle_kind := ""
var train: Node3D
var _train_t := -1.0
var _train_next := 20.0
var rng := RandomNumberGenerator.new()
var yard: YardView
## Personnages qui marchent : {node, a, b, t (0→1 vers b), dir (+1 vers b, −1 vers a), wait (pause au bout, s), phase}
var walkers: Array[Dictionary] = []
var walk_paused := false        # un écran couvre le monde : les personnages s'arrêtent
const WALK_SPEED := 1.7         # u/s
const WALK_PAUSE := 1.2         # s d'arrêt à chaque bout avant le demi-tour (instantané)
var _bob := 0.0
var _lot_slots := 0
var _honk_cool := 0.0


func _make_truck(loaded: bool, sim: PortSim) -> Node3D:
	var t := Assets.instance("truck")
	if loaded:
		var c := MeshInstance3D.new()
		c.mesh = Assets.mesh("container40")
		var m: ShaderMaterial = Assets.vcol_material.duplicate()
		m.set_shader_parameter("tint", ShipView.cargo_color(sim, 0, rng.randi()).linear_to_srgb())
		c.material_override = m
		var meta := Assets.meta("truck")
		c.position = Vector3(float(meta.get("container_x", -0.6)), float(meta.get("container_z", 1.0)), 0)
		t.add_child(c)
	return t


func set_barriers(list: Array[Node3D]) -> void:
	barriers = list


## Nombre de camions affichables : la route, puis l'aire d'attente, puis un débordement sur la route.
func max_queue() -> int:
	return ROAD_SLOTS + _lot_slots + 4 if _lot_slots > 0 else 9


## Position de la place `i` de la file : près de la gate, puis dans l'aire d'attente, puis de nouveau sur la route.
func slot_pos(i: int) -> Vector3:
	if i < ROAD_SLOTS or _lot_slots <= 0:
		return Vector3(QUEUE_X, 0, QUEUE_Z0 + i * QUEUE_GAP)
	var j := i - ROAD_SLOTS
	if j < _lot_slots:
		return Layout.lot_slot(j)
	return Vector3(QUEUE_X, 0, QUEUE_Z0 + (ROAD_SLOTS + j - _lot_slots) * QUEUE_GAP)


## Itinéraire entre deux points : la route d'accès sert de lien entre l'autoroute, la file et l'aire d'attente.
func _route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var start := from
	if from.z > Layout.HIGHWAY_Z0 - 2.0 and absf(from.x - QUEUE_X) > 1.5:
		start = Vector3(QUEUE_X, 0, from.z)       # sur l'autoroute : on rejoint d'abord la route d'accès
		out.append(start)
	var road_from := absf(start.x - QUEUE_X) < 1.5
	var road_to := absf(to.x - QUEUE_X) < 1.5
	if road_from and road_to:
		out.append(to)
	elif road_from:
		out.append(Vector3(QUEUE_X, 0, to.z))
		out.append(to)
	elif road_to:
		out.append(Vector3(QUEUE_X, 0, start.z))
		out.append(to)
	else:
		out.append(to)
	return out


func _assign(t: Node3D, target: Vector3) -> void:
	if t.has_meta("target") and (t.get_meta("target") as Vector3).is_equal_approx(target):
		return
	t.set_meta("target", target)
	t.set_meta("route", _route(t.position, target))


func _drive(t: Node3D, delta: float) -> void:
	var route: Array = t.get_meta("route", [])
	if route.is_empty():
		t.rotation.y = lerp_angle(t.rotation.y, deg_to_rad(HEAD_NORTH), 1.0 - exp(-delta * 6.0))
		return
	var tgt: Vector3 = route[0]
	var d := tgt - t.position
	d.y = 0.0
	var step := SPEED * delta
	if d.length() <= step:
		t.position = Vector3(tgt.x, t.position.y, tgt.z)
		route.pop_front()
	else:
		t.position += d.normalized() * step
		t.rotation.y = lerp_angle(t.rotation.y, atan2(-d.z, d.x), 1.0 - exp(-delta * 10.0))


func on_truck_served(sim: PortSim) -> void:
	# en vitesse accélérée la gate sert plusieurs camions par image : on n'en montre qu'un par OUT_GAP
	if _out_cool > 0.0 or leaving.size() >= MAX_LEAVING:
		return
	_out_cool = OUT_GAP
	if queue.is_empty():
		var t := _make_truck(false, sim)
		t.position = slot_pos(1)
		t.rotation.y = deg_to_rad(HEAD_NORTH)
		t.set_meta("route", [])
		t.set_meta("target", slot_pos(0))
		add_child(t)
		queue.append(t)
	var head: Node3D = queue.pop_front()
	leaving.append({"node": head, "t": 0.0, "kind": "in", "phase": 0})
	var out := _make_truck(true, sim)
	out.rotation.y = deg_to_rad(-90.0)
	out.position = Vector3(OUT_X, 0, 27.0)
	out.visible = false
	add_child(out)
	leaving.append({"node": out, "t": -0.8, "kind": "out", "phase": 0})
	_barrier_open = 1.4


func _spawn_queue_truck(sim: PortSim) -> void:
	var t := _make_truck(false, sim)
	t.position = Vector3(Layout.MAINLAND_X[0] + 4.0, 0, Layout.HIGHWAY_LANE_E)
	t.rotation.y = 0.0
	add_child(t)
	queue.append(t)
	_assign(t, slot_pos(queue.size() - 1))


func sync(sim: PortSim, delta: float) -> void:
	_bob += delta
	_out_cool = maxf(0.0, _out_cool - delta)
	_lot_slots = sim.parking_slots
	# file de camions = camions en attente dans la simulation (plafonné visuellement)
	var want := mini(max_queue(), sim.trucks_waiting())
	while queue.size() < want:
		_spawn_queue_truck(sim)
	while queue.size() > want and queue.size() > 0:
		var last: Node3D = queue.pop_back()
		last.queue_free()
	var honk := sim.trucks_honking() > 0
	_honk_cool = maxf(0.0, _honk_cool - delta)
	if honk and _honk_cool <= 0.0:
		_honk_cool = 7.0
		Sfx.play("truck_honk", 2.0)
	for i in queue.size():
		var t: Node3D = queue[i]
		_assign(t, slot_pos(i))
		_drive(t, delta)
		t.position.y = 0.04 * sin(_bob * 30.0 + i) if (honk and i < 3) else 0.0
	# camions qui passent la gate
	var keep: Array[Dictionary] = []
	for l in leaving:
		l.t += delta
		var n: Node3D = l.node
		if l.kind == "in":
			n.rotation.y = lerp_angle(n.rotation.y, deg_to_rad(HEAD_NORTH), 1.0 - exp(-delta * 8.0))
			n.position.x = lerpf(n.position.x, QUEUE_X, 1.0 - exp(-delta * 6.0))
			n.position.z -= delta * 12.0
			if n.position.z < 24.0:
				n.queue_free()
				continue
		else:
			if l.t >= 0.0:
				n.visible = true
				if l.phase == 0:
					n.position.z += delta * 13.0
					if n.position.z >= Layout.HIGHWAY_LANE_E - 1.0:
						l.phase = 1
				else:
					# tourne vers l'est et file sur l'autoroute
					n.position.z = lerpf(n.position.z, Layout.HIGHWAY_LANE_E, 1.0 - exp(-delta * 5.0))
					n.rotation.y = lerp_angle(n.rotation.y, 0.0, 1.0 - exp(-delta * 5.0))
					n.position.x += delta * 16.0
				if n.position.x > Layout.MAINLAND_X[1] - 6.0:
					n.queue_free()
					continue
		keep.append(l)
	leaving = keep
	# barrières
	_barrier_open = maxf(0.0, _barrier_open - delta)
	for b in barriers:
		if is_instance_valid(b):
			b.rotation.z = lerp_angle(b.rotation.z, deg_to_rad(80.0) if _barrier_open > 0.0 else 0.0, 1.0 - exp(-delta * 8.0))
	_sync_vehicles(sim, delta)
	_sync_train(sim, delta)
	_sync_cars(delta)
	_sync_walkers(delta)


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
		n.position = p
		var to := (b - a) * float(w.dir)
		if to.length() > 0.01:
			n.rotation.y = atan2(to.x, to.z)      # face à sa destination (face principale du modèle en +Z)


## Voitures civiles : de l'activité sur l'autoroute, indépendante de la simulation.
func _sync_cars(delta: float) -> void:
	if cars.is_empty():
		for i in 7:
			var east := i % 2 == 0
			var n := Assets.instance("car_a" if i % 3 != 0 else "car_b")
			n.rotation.y = 0.0 if east else PI
			var x0 := Layout.MAINLAND_X[0] + 10.0 + float(i) * 42.0
			n.position = Vector3(x0, 0, Layout.HIGHWAY_LANE_E - 0.2 if east else Layout.HIGHWAY_LANE_W + 0.2)
			add_child(n)
			cars.append({"node": n, "dir": 1.0 if east else -1.0, "speed": 9.0 + float(i % 4) * 2.5})
	var x_min: float = Layout.MAINLAND_X[0] + 2.0
	var x_max: float = Layout.MAINLAND_X[1] - 2.0
	for c in cars:
		var n: Node3D = c.node
		n.position.x += float(c.dir) * float(c.speed) * delta
		if n.position.x > x_max:
			n.position.x = x_min
		elif n.position.x < x_min:
			n.position.x = x_max


func _sync_vehicles(sim: PortSim, delta: float) -> void:
	var kind := "forklift" if sim.tier == 1 else ("reach_stacker" if sim.tier == 2 or not sim.built.has("rtg") else "straddle")
	var count := clampi(sim.agents("yard_ops") + (1 if sim.managers.yard_ops else 0), 1, 7)
	if kind != _vehicle_kind:
		for v in vehicles:
			(v.node as Node3D).queue_free()
		vehicles.clear()
		_vehicle_kind = kind
	while vehicles.size() < count:
		var n := Assets.instance(kind)
		add_child(n)
		var a := _apron_point(sim)
		vehicles.append({"node": n, "a": a, "b": yard.random_yard_point(rng) if yard else Layout.YARD_CENTER, "t": rng.randf(), "dir": 1.0})
		n.position = a
	while vehicles.size() > count:
		var v: Dictionary = vehicles.pop_back()
		(v.node as Node3D).queue_free()
	var speed := clampf(sqrt(sim.stat("transfer_rate")) * 0.08, 0.12, 0.6)
	var active := sim.apron_stock() > 0.5 or sim.yard_stock() > 1.0
	for v in vehicles:
		if active:
			v.t += delta * speed * float(v.dir)
		if v.t >= 1.0:
			v.t = 1.0
			v.dir = -1.0
		elif v.t <= 0.0:
			v.t = 0.0
			v.dir = 1.0
			v.a = _apron_point(sim)
			v.b = yard.random_yard_point(rng) if yard else Layout.YARD_CENTER
		var a: Vector3 = v.a
		var b: Vector3 = v.b
		var mid := Vector3(a.x, 0, b.z)
		var t: float = v.t
		var p: Vector3 = (a.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(b, (t - 0.5) * 2.0))
		var n: Node3D = v.node
		var dpos := p - n.position
		n.position = p
		if dpos.length() > 0.001:
			n.rotation.y = lerp_angle(n.rotation.y, atan2(-dpos.z, dpos.x), 1.0 - exp(-delta * 10.0))


func _apron_point(sim: PortSim) -> Vector3:
	var bi := rng.randi_range(0, sim.berths.size() - 1)
	var b: Dictionary = Layout.BERTHS[mini(bi, Layout.BERTHS.size() - 1)]
	return Vector3(rng.randf_range(float(b.x0) + 3.0, float(b.x1) - 3.0), 0, 3.2)


func _sync_train(sim: PortSim, delta: float) -> void:
	if not sim.built.has("rail"):
		if train != null:        # nouvelle concession : le terminal rail n'existe plus, le train ne doit pas rester figé sur la voie
			train.queue_free()
			train = null
			_train_t = -1.0
			_train_next = 20.0
		return
	if train == null:
		train = Node3D.new()
		add_child(train)
		var loco := Assets.instance("locomotive")
		train.add_child(loco)
		for i in 4:
			var w := Assets.instance("wagon")
			w.position = Vector3(-9.6 * (i + 1), 0, 0)
			train.add_child(w)
			for sx in [-2.1, 2.1]:
				var c := MeshInstance3D.new()
				c.mesh = Assets.mesh("container20")
				var m: ShaderMaterial = Assets.vcol_material.duplicate()
				m.set_shader_parameter("tint", ShipView.cargo_color(sim, 0, rng.randi()).linear_to_srgb())
				c.material_override = m
				c.position = Vector3(sx, 0.95, 0)
				w.add_child(c)
		train.visible = false
	_train_next -= delta
	if _train_t < 0.0 and _train_next <= 0.0:
		_train_t = 0.0
		train.visible = true
	if _train_t >= 0.0:
		_train_t += delta
		train.position = Vector3(10.0 + _train_t * 12.0, 0.2, 45.0)
		if train.position.x > 200.0:
			_train_t = -1.0
			_train_next = 35.0
			train.visible = false
