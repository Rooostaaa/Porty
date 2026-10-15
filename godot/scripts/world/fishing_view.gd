class_name FishingView
extends Node3D
## Lot F3 — l'anse des pêcheurs à l'écran (présentation seule) : la cabane d'Odette, le ponton pourri puis les pontons, le quai
## des chalutiers, la criée et sa route, la fabrique de glace ; les bateaux du village (barques, chalutiers, thonier) qui
## suivent le cycle de la simulation (`Fishing` : sortie, pêche, retour, débarque) sur une boucle à sens unique
## (Layout « Lot F3 ») ; les caisses débarquées, la camionnette du mareyeur qui part dans la forêt, un pêcheur sur le ponton.
## La position d'un bateau se déduit de sa phase et de sa progression (durées fixes : vitesse constante, rampes douces au
## départ et à l'arrivée, glissement latéral lent à la place, aucune rotation sur place). Seul état propre : un bateau qui
## vient d'être acheté fait son premier voyage depuis le large (il paraît en fondu, hors du cadrage de l'acte 0).

signal popup(pos: Vector3, text: String, big: bool)

const YAW_RATE := 1.4             # rad/s : rotation au plus
const FISH_R := 1.6               # rayon du cercle de dérive au coin de pêche
const TAP_R := 7.0
const VAN_SPEED := 6.0
const VAN_AWAY := 12.0            # s dans la forêt avant de revenir
const VAN_EVERY := 35.0           # s entre deux départs quand la pêche est passive

var dio: Node3D                   # Diorama (sites, poussière, tuiles de route)
var sim: PortSim
var _static: Node3D
var _boats_root: Node3D
var boats: Array[Dictionary] = []   # vue i (même indice que sim.fishing.boats) -> {node, fresh, fade, yaw, phase, crates, pos}
var _level := -1
var _t := 0.0
var _paths: Dictionary = {}
var van: Node3D
var van_state := "park"           # park, out, away, back (tests)
var _van_t := 0.0
var _van_d := 0.0
var _van_loads := 0
var van_trips := 0                # (tests) départs de la camionnette
var landings_shown := 0           # (tests) débarques montrées
var speed_seen: Dictionary = {}   # (tests) classe -> plus grande vitesse observée (u/s)
var _last_pos: Dictionary = {}
var speed_k := 1.0                 # accélération de débogage (Sim.speed, réglée par le diorama ; pas d'autoload ici : run_all)
var sub_t := 0.0                   # s simulées depuis le dernier pas (Sim.alpha × pas) : la vue interpole entre deux pas de 0,25 s


func _ready() -> void:
	_static = Node3D.new()
	_static.name = "anse_static"
	add_child(_static)
	_boats_root = Node3D.new()
	_boats_root.name = "anse_boats"
	add_child(_boats_root)


func bind(s: PortSim) -> void:
	if sim != null and sim.fish_landed.is_connected(_on_landed):
		sim.fish_landed.disconnect(_on_landed)
	if sim != null and sim.purchased.is_connected(_on_purchased):
		sim.purchased.disconnect(_on_purchased)
	sim = s
	sim.fish_landed.connect(_on_landed)
	sim.purchased.connect(_on_purchased)
	for v in boats:
		if is_instance_valid(v.node):
			(v.node as Node).queue_free()
		for c in v.crates:
			if is_instance_valid(c):
				(c as Node).queue_free()
	boats.clear()
	_last_pos.clear()
	_level = -1
	van_state = "park"
	_van_t = 0.0
	_van_loads = 0
	_ensure_boats(false)
	rebuild()


func _sites() -> SiteWorks:
	return dio.get("sites") as SiteWorks


func _buy_ids() -> Array[String]:
	var out: Array[String] = []
	var b := sim.fishing.buys()
	for i in mini(sim.fishing.level, b.size()):
		out.append(String(b[i].id))
	return out


func has(id: String) -> bool:
	return _buy_ids().has(id)


## Achat de l'acte 0 dont le chantier est fini (l'élément sert : bateaux à leur place, camionnette).
func ready_id(id: String) -> bool:
	return has(id) and not _sites().active("fish_" + id)


# --- décor -----------------------------------------------------------------------------------------------------------

func rebuild() -> void:
	for c in _static.get_children():
		c.queue_free()
	if sim == null:
		return
	_level = sim.fishing.level
	var ids := _buy_ids()
	_place(Layout.ODETTE_HUT, "")
	# état d'avant : le ponton pourri d'Odette, jusqu'à la fin de la réparation
	if not ids.has("pontoon") or _sites().hiding("fish_pontoon"):
		var r := _place(Layout.ANSE_RUIN, "")
		r.set_meta("before", "fish_pontoon")
	for id in ids:
		for pd in Layout.anse_pontoons(id):
			_pontoon(pd, "fish_" + id)
		if Layout.ANSE_BUILDINGS.has(id):
			_place(Layout.ANSE_BUILDINGS[id], "fish_" + id)
		if id == "hall":
			var road := Layout.FISH_ROAD
			var arr: Array = []
			var z := road.position.y
			while z < road.end.y - 0.1:
				arr.append(Vector2i(int(road.position.x), int(minf(z, road.end.y - 6.0))))
				z += 6.0
			var tm: MultiMeshInstance3D = dio.call("_tile_multimesh", "road_z", arr)
			tm.set_meta("site", "fish_hall")
			tm.set_meta("tiles", true)
			_static.add_child(tm)
	# un pêcheur : sur la plage devant la cabane, puis sur le ponton réparé
	var who := Assets.instance("docker")
	if ids.has("pontoon"):
		who.position = Vector3(-119.4, Layout.WATER_Y + 0.45, 51.6)
		who.rotation.y = deg_to_rad(-90.0)
	else:
		who.position = Vector3(-121.5, 0.0, 58.4)
		who.rotation.y = deg_to_rad(160.0)
	who.set_meta("fisher", true)
	_static.add_child(who)
	# camionnette du mareyeur (avec la criée)
	if van == null or not is_instance_valid(van):
		van = Assets.instance("fish_van")
		van.name = "fish_van"
		add_child(van)
	van.visible = false
	_apply_hiding()


func _place(d: Dictionary, site: String) -> Node3D:
	var n := Assets.instance(String(d.m))
	var p: Vector3 = d.p
	n.position = p
	if p.y >= 0.0:
		n.position.y += Layout.ground_y(Vector2(p.x, p.z))
	n.rotation.y = deg_to_rad(float(d.get("ry", 0.0)))
	if site != "":
		n.set_meta("site", site)
	_static.add_child(n)
	return n


func _pontoon(pd: Dictionary, site: String) -> void:
	var c: Vector2 = pd.c
	var n := int(pd.n)
	var along_x := String(pd.axis) == "x"
	for k in n:
		var off := (float(k) - float(n - 1) * 0.5) * 6.0
		var m := Assets.instance("pontoon")
		m.position = Vector3(c.x + (off if along_x else 0.0), Layout.WATER_Y, c.y + (0.0 if along_x else off))
		m.rotation.y = 0.0 if along_x else PI * 0.5
		m.set_meta("site", site)
		_static.add_child(m)


func _apply_hiding() -> void:
	for n in _static.get_children():
		var k := String(n.get_meta("site", ""))
		if k != "" and _sites().hiding(k):
			if n is MultiMeshInstance3D:
				(n as Node3D).visible = false
			else:
				(n as Node3D).scale = Vector3.ONE * 0.01


## Chantier d'un achat de l'acte 0 (le bâtiment monte) : appelé par le diorama (signal SiteWorks.risen).
func on_site_risen(key: String) -> void:
	for n in _static.get_children():
		if String(n.get_meta("site", "")) == key:
			var nd: Node3D = n
			if nd is MultiMeshInstance3D:
				nd.visible = true
				continue
			nd.scale = Vector3.ONE * 0.01
			var tw := nd.create_tween()
			tw.tween_property(nd, "scale", Vector3.ONE * SiteWorks.OVERSHOOT, SiteWorks.RISE * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(nd, "scale", Vector3.ONE, SiteWorks.RISE * 0.4).set_trans(Tween.TRANS_SINE)
		elif String(n.get_meta("before", "")) == key:
			var bn: Node3D = n
			bn.create_tween().tween_property(bn, "scale", Vector3.ONE * 0.01, SiteWorks.RISE * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			if dio.has_method("_dust"):
				dio.call("_dust", bn.global_position + Vector3(0, 0.6, 0), 10, SiteWorks.SPLASH)


func on_site_finished(key: String) -> void:
	if key.begins_with("fish_"):
		rebuild()


func _on_purchased(kind: String, id: String) -> void:
	if kind != "fish":
		return
	_ensure_boats(true)
	var spec := Layout.anse_site_spec(id)
	if not spec.is_empty():
		_sites().start("fish_" + id, spec)
	rebuild()


# --- bateaux ---------------------------------------------------------------------------------------------------------

func _ensure_boats(fresh: bool) -> void:
	while boats.size() < sim.fishing.boats.size():
		var bt: Dictionary = sim.fishing.boats[boats.size()]
		var model := "boat_" + String(bt.cls)
		var n := Assets.instance(model)
		n.visible = false
		_boats_root.add_child(n)
		boats.append({"node": n, "fresh": fresh, "fade": 0.0 if fresh else 1.0, "yaw": INF, "phase": -1, "crates": [],
			"pos": Vector3.INF, "cls": String(bt.cls)})


func _path(kind: String, cls: String, slot: int, fresh: bool) -> Dictionary:
	var key := "%s|%s|%d|%s" % [kind, cls, slot, fresh]
	if not _paths.has(key):
		var p: Dictionary
		if kind == "out":
			p = Layout.fish_path_out(cls, slot)
		else:
			if fresh:
				p = Layout.fish_path_back(cls, slot, Layout.fish_sea_entry(cls))
			else:
				var ho: Vector3 = Layout.fish_path_at(_path("out", cls, slot, false), 1.0)[1]
				p = Layout.fish_path_back(cls, slot, Layout.fish_ground(cls, slot), Vector2(ho.x, ho.z).normalized())
		_paths[key] = Layout.fish_weigh(p)
	return _paths[key]


static func yaw_of(dir: Vector3) -> float:
	return atan2(-dir.z, dir.x)


## Position, cap visé et glissement d'un bateau d'après sa phase (sans lissage) : {p, yaw, crab, visible}.
func boat_pose(i: int) -> Dictionary:
	var bt: Dictionary = sim.fishing.boats[i]
	var v: Dictionary = boats[i]
	var cls := String(bt.cls)
	var slot := int(bt.slot)
	var ph := int(bt.phase)
	var dur := float(bt.dur)
	var f := minf(1.0, sim.fishing.progress(i) + sub_t / maxf(0.1, dur))      # (interpolée entre deux pas de la simulation)
	var berth := Layout.fish_berth(cls, slot)
	match ph:
		Fishing.Phase.LAND:
			return {"p": berth, "yaw": Layout.fish_berth_yaw(cls), "crab": false, "visible": true}
		Fishing.Phase.FISH:
			if bool(v.fresh):
				var se := Layout.fish_sea_entry(cls)
				return {"p": Vector3(se.x, 0, se.y), "yaw": 0.0, "crab": false, "visible": false}
			var g := Layout.fish_ground(cls, slot)
			var wpo := _path("out", cls, slot, false)
			var h: Vector3 = (Layout.fish_path_at(wpo, 1.0)[1] as Vector3)
			var u := Vector3(h.z, 0, -h.x)        # vers le centre à gauche… le cercle passe par g avec la tangente h
			var c := Vector3(g.x, 0, g.y) - u * FISH_R
			var a := f * TAU
			var p := c + (u * cos(a) + h * sin(a)) * FISH_R
			var tan := (-u * sin(a) + h * cos(a)).normalized()
			return {"p": p, "yaw": yaw_of(tan), "crab": false, "visible": true}
		_:
			var wp := _path("out" if ph == Fishing.Phase.OUT else "back", cls, slot, bool(v.fresh))
			var e := Layout.fish_profile(f, minf(0.25, Layout.FISH_RAMP_S / maxf(0.5, dur)))
			var at := Layout.fish_path_at(wp, e)
			var crab := bool(at[2])
			var yaw := Layout.fish_berth_yaw(cls) if crab else yaw_of(at[1])
			return {"p": at[0], "yaw": yaw, "crab": crab, "visible": true}


func sync(delta: float) -> void:
	_t += delta
	if sim == null:
		return
	if sim.fishing.level != _level:
		rebuild()
	_ensure_boats(true)
	for i in boats.size():
		_sync_boat(i, delta)
	_sync_van(delta)


func _sync_boat(i: int, delta: float) -> void:
	var bt: Dictionary = sim.fishing.boats[i]
	var v: Dictionary = boats[i]
	var n: Node3D = v.node
	var ph := int(bt.phase)
	if bool(v.fresh) and ph == Fishing.Phase.LAND:
		v.fresh = false
	# à sa place d'un ponton en chantier : il attend en dehors (rien ne sert avant la fin du chantier)
	var pose := boat_pose(i)
	n.visible = bool(pose.visible)
	if not n.visible:
		v.pos = Vector3.INF
		return
	var p: Vector3 = pose.p
	if float(v.yaw) == INF:
		v.yaw = float(pose.yaw)
	else:
		v.yaw = rotate_toward(float(v.yaw), float(pose.yaw), YAW_RATE * delta * speed_k)
	v.fade = minf(1.0, float(v.fade) + delta * 1.2)
	n.scale = Vector3.ONE * maxf(0.01, ease(float(v.fade), 0.5))
	n.position = Vector3(p.x, Layout.WATER_Y + 0.05 * sin(_t * 1.7 + float(i)), p.z)
	n.rotation.y = float(v.yaw)
	n.rotation.z = 0.03 * sin(_t * 1.3 + float(i) * 0.7)
	# vitesse observée (tests) : jamais un sprint
	if (v.pos as Vector3) != Vector3.INF and delta > 0.0:
		var spd := Vector2(p.x - (v.pos as Vector3).x, p.z - (v.pos as Vector3).z).length() / (delta * speed_k)
		var cls := String(bt.cls)
		if spd < 50.0:
			speed_seen[cls] = maxf(float(speed_seen.get(cls, 0.0)), spd)
	v.pos = p
	# caisses débarquées : sur le ponton pendant la débarque
	if ph != int(v.phase):
		if ph == Fishing.Phase.LAND:
			_crates_on(i)
		elif int(v.phase) == Fishing.Phase.LAND:
			_crates_off(i)
		v.phase = ph


func _crates_on(i: int) -> void:
	var v: Dictionary = boats[i]
	var bt: Dictionary = sim.fishing.boats[i]
	var cls := String(bt.cls)
	var b := Layout.fish_berth(cls, int(bt.slot))
	var spots: Array[Vector3] = []
	if cls == "dinghy":
		var dz := 1.25 if b.z > 49.0 else 1.25
		spots = [Vector3(b.x - 0.7, 0, b.z + dz + 0.3), Vector3(b.x + 0.6, 0, b.z + dz + 0.4)]
	else:
		spots = [Vector3(-95.6, 0, b.z - 1.2), Vector3(-95.6, 0, b.z + 0.2), Vector3(-95.4, 0, b.z + 1.5)]
		if cls == "tuna":
			spots.append(Vector3(-95.8, 0, b.z + 2.8))
	for sp in spots:
		var c := Assets.instance("crate_fish")
		c.position = Vector3(sp.x, Layout.WATER_Y + 0.45, sp.z)
		c.rotation.y = randf_range(-0.4, 0.4)
		c.scale = Vector3.ONE * 0.01
		add_child(c)
		c.create_tween().tween_property(c, "scale", Vector3.ONE * 0.8, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		(v.crates as Array).append(c)


func _crates_off(i: int) -> void:
	var v: Dictionary = boats[i]
	for c in v.crates:
		if is_instance_valid(c):
			var cn: Node3D = c
			var tw := cn.create_tween()
			tw.tween_property(cn, "scale", Vector3.ONE * 0.01, 0.3)
			tw.tween_callback(cn.queue_free)
	(v.crates as Array).clear()


func _on_landed(i: int, amount: float, helped: bool) -> void:
	landings_shown += 1
	if has("hall"):
		_van_loads += 1
	if amount > 0.0 and i < boats.size():
		var bt: Dictionary = sim.fishing.boats[i]
		var b := Layout.fish_berth(String(bt.cls), int(bt.slot))
		popup.emit(b + Vector3(0, 3.0, 0), ("Débarque aidée ! +%s" if helped else "+%s") % Fmt.money(amount), helped)


## Bateaux qu'un toucher peut aider (acte 0 : qui rentrent ou débarquent), visibles.
func helpable() -> Array[int]:
	var out: Array[int] = []
	if sim == null:
		return out
	for i in mini(boats.size(), sim.fishing.boats.size()):
		if sim.fishing.can_help(i) and (boats[i].node as Node3D).visible:
			out.append(i)
	return out


func boat_pos(i: int) -> Vector3:
	if i < 0 or i >= boats.size():
		return Vector3.INF
	return (boats[i].node as Node3D).position


## Bateau qui rentre le plus proche du point touché (acte 0), -1 sinon.
func pick(wp: Vector3) -> int:
	var best := -1
	var bd := TAP_R
	for i in helpable():
		var d := Vector2(wp.x, wp.z).distance_to(Vector2(boat_pos(i).x, boat_pos(i).z))
		if d < bd:
			bd = d
			best = i
	return best


# --- camionnette du mareyeur -------------------------------------------------------------------------------------------
## Garée devant la criée (étrave au nord) ; après deux débarques (ou toutes les 35 s quand la pêche est passive), demi-tour
## devant la criée, route du mareyeur vers le sud, rue du village vers l'ouest, sous les arbres ; elle revient 12 s plus tard.
static func van_path_out() -> Array[Vector3]:
	var park := Layout.FISH_VAN_PARK
	var out: Array[Vector3] = [park]
	var c := park + Vector3(-1.5, 0, 0)
	for k in range(1, 9):
		var a := -PI * float(k) / 8.0
		out.append(Vector3(c.x + 1.5 * cos(a), 0, c.z + 1.5 * sin(a)))
	var lane_x := park.x - 3.0
	out.append(Vector3(lane_x, 0, 90.0))
	out.append_array(Layout._fillet(Vector3(lane_x, 0, 90.0), Vector3(lane_x, 0, 97.5), Vector3(-133.0, 0, 97.5), 3.0, 6))
	out.append(Vector3(-133.0, 0, 97.5))
	return out


static func van_path_back() -> Array[Vector3]:
	var park := Layout.FISH_VAN_PARK
	var out: Array[Vector3] = [Vector3(-133.0, 0, 100.5)]
	out.append_array(Layout._fillet(Vector3(-133.0, 0, 100.5), Vector3(park.x, 0, 100.5), Vector3(park.x, 0, park.z), 3.0, 6))
	out.append(park)
	return out


func _sync_van(delta: float) -> void:
	if van == null or not is_instance_valid(van):
		return
	if not ready_id("hall"):
		van.visible = false
		van_state = "park"
		return
	var dt := delta * speed_k
	_van_t += dt
	match van_state:
		"park":
			_van_pose(van_path_back(), 1.0)
			if (sim.fishing.act0 and _van_loads >= 2) or (not sim.fishing.act0 and _van_t >= VAN_EVERY):
				van_state = "out"
				_van_d = 0.0
				_van_t = 0.0
				_van_loads = 0
				van_trips += 1
		"out":
			var po := van_path_out()
			_van_d += VAN_SPEED * dt
			var L := Layout.path_length(po)
			_van_pose(po, _van_d / L)
			if _van_d >= L:
				van_state = "away"
				_van_t = 0.0
		"away":
			van.visible = false
			if _van_t >= VAN_AWAY:
				van_state = "back"
				_van_d = 0.0
		"back":
			var pb := van_path_back()
			_van_d += VAN_SPEED * dt
			var L2 := Layout.path_length(pb)
			_van_pose(pb, _van_d / L2)
			if _van_d >= L2:
				van_state = "park"
				_van_t = 0.0


func _van_pose(path: Array[Vector3], f: float) -> void:
	var at := Layout.polyline_at(path, clampf(f, 0.0, 1.0))
	var p: Vector3 = at[0]
	van.position = Vector3(p.x, 0.0, p.z)
	van.rotation.y = float(at[1])
	# sous les arbres (route du village vers la forêt) : elle s'efface dans l'ombre, jamais en pleine route
	van.visible = p.x > -131.0
