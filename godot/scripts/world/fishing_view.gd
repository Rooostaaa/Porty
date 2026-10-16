class_name FishingView
extends Node3D
## Lot F3/G1 — l'anse des pêcheurs à l'écran (présentation seule) : la cabane d'Odette, le ponton pourri puis le ponton des
## places qui s'allonge, le quai des chalutiers, la grande jetée du thonier, la marina et ses voiliers, les paliers nommés des
## Services (criée et sa route, pompe, lavage, glace), Marcel sur le ponton ; les bateaux du village (barques, chalutiers,
## thonier) qui suivent le cycle de la simulation (`Fishing` : sortie, pêche, retour, débarque, attente du loyer) sur une boucle à
## sens unique (Layout « Lot F3/G1 ») ; les caisses débarquées, la camionnette du mareyeur qui part dans la forêt ; le caboteur de
## l'annonce qui traverse au large. La position d'un bateau se déduit de sa phase et de sa progression (durées fixes : vitesse
## constante, rampes douces, glissement latéral lent à la place, aucune rotation sur place). Chargeur tolérant : un modèle absent
## est remplacé par une primitive Godot (`_prim`, signalée dans `primitives`).

signal popup(pos: Vector3, text: String, big: bool)
signal served(pos: Vector3, amount: float, station: String)      # lot H1 : fin d'un service au ponton (l'anneau éclate)

const YAW_RATE := 1.4             # rad/s : rotation au plus
const FISH_R := 1.6               # rayon du cercle de dérive au coin de pêche
const TAP_R := 7.0
const VAN_SPEED := 6.0
const VAN_AWAY := 12.0            # s dans la forêt avant de revenir
const VAN_EVERY := 35.0           # s entre deux départs quand Marcel encaisse (plus de débarques « à la main »)
const PASSING_SPEED := 7.0        # u/s : le caboteur de l'annonce, à sa croisière
const SAIL_LEN := {"sailboat_a": 3.5, "sailboat_b": 4.5}

var dio: Node3D                   # Diorama (sites, poussière, tuiles de route)
var sim: PortSim
var _static: Node3D
var _boats_root: Node3D
var boats: Array[Dictionary] = []   # vue i (même indice que sim.fishing.boats) -> {node, fresh, fade, yaw, phase, crates, pos}
var _places := -1
var _services := -1
var _built := -1
var _marcel := false
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
var passing: Node3D                # caboteur de l'annonce (null sinon)
var _passing_d := 0.0
var passings := 0                  # (tests) passages joués
var sailboats: Array[Node3D] = []  # voiliers de la marina (roulis léger)
var marcel_node: Node3D            # Marcel (ou le pêcheur voisin avant lui)
var primitives: Array[String] = [] # (tests, rapport) modèles remplacés par une primitive
var bursts: Array[Dictionary] = []  # lot H1 : anneaux qui éclatent {st, t} (surcouche)
var services_shown := 0             # (tests) services payés montrés (« +X $ » au-dessus de la station)


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
	if sim != null and sim.fish_event.is_connected(_on_fish_event):
		sim.fish_event.disconnect(_on_fish_event)
	if sim != null and sim.fish_served.is_connected(_on_served):
		sim.fish_served.disconnect(_on_served)
	sim = s
	sim.fish_served.connect(_on_served)
	sim.fish_landed.connect(_on_landed)
	sim.purchased.connect(_on_purchased)
	sim.fish_event.connect(_on_fish_event)
	for v in boats:
		if is_instance_valid(v.node):
			(v.node as Node).queue_free()
		for c in v.crates:
			if is_instance_valid(c):
				(c as Node).queue_free()
	boats.clear()
	_last_pos.clear()
	_places = -1
	_services = -1
	_built = -1
	van_state = "park"
	_van_t = 0.0
	_van_loads = 0
	if passing != null and is_instance_valid(passing):
		passing.queue_free()
	passing = null
	_ensure_boats(false)
	rebuild()


func _sites() -> SiteWorks:
	return dio.get("sites") as SiteWorks


## Niveau de Places qui a ajouté le module de ponton n (1 = le premier) : les modules 1–2 viennent de la réparation.
static func module_level(n: int) -> int:
	for lv in range(1, 9):
		if int(Layout.PLACES_MODULES.get(lv, 6)) >= n:
			return lv
	return 8


## Clé de chantier de la place k (0 = la première) : les deux premières viennent de la réparation (niveau 1).
static func berth_level(k: int) -> int:
	return maxi(1, k)


## Un élément de la Crique est là et son chantier est fini (il sert : bateaux à leur place, camionnette).
func ready_key(key: String) -> bool:
	return not _sites().active("fish_" + key)


func has(id: String) -> bool:
	return sim != null and sim.fishing.has(id)


## Modèle livré, ou primitive provisoire (signalée au rapport).
func _model(name: String, fallback: String = "") -> Node3D:
	if Assets.exists(name):
		return Assets.instance(name)
	if fallback != "" and Assets.exists(fallback):
		return Assets.instance(fallback)
	if not primitives.has(name):
		primitives.append(name)
	return _prim(name)


## Primitives provisoires (en attendant les modèles de `docs/ORDRE_BLENDER_G.md`).
static func _prim(name: String) -> Node3D:
	var root := Node3D.new()
	root.name = "prim_" + name
	match name:
		"pier_long":
			_box(root, Vector3(14.0, 0.5, 2.5), Vector3(0, 0.9, 0), Color(0.72, 0.72, 0.7))
			for k in 4:
				_box(root, Vector3(0.5, 2.2, 0.5), Vector3(-5.25 + 3.5 * float(k), -0.2, 0.8), Color(0.45, 0.42, 0.4))
				_box(root, Vector3(0.5, 2.2, 0.5), Vector3(-5.25 + 3.5 * float(k), -0.2, -0.8), Color(0.45, 0.42, 0.4))
			_box(root, Vector3(0.3, 2.6, 0.3), Vector3(6.0, 2.3, 0.0), Color(0.3, 0.3, 0.32))
			_box(root, Vector3(0.6, 0.6, 0.6), Vector3(-6.0, 1.45, 0.0), Color(0.9, 0.75, 0.2))
		"marina_pontoon":
			_box(root, Vector3(1.8, 0.35, 10.0), Vector3(0, 0.45, 0), Color(0.82, 0.78, 0.68))
			for k in 4:
				var z := -3.75 + 2.5 * float(k)
				_box(root, Vector3(2.4, 0.25, 0.5), Vector3(-1.9, 0.4, z), Color(0.82, 0.78, 0.68))
				_box(root, Vector3(2.4, 0.25, 0.5), Vector3(1.9, 0.4, z), Color(0.82, 0.78, 0.68))
			_box(root, Vector3(0.4, 0.8, 0.4), Vector3(0, 0.9, 4.6), Color(0.3, 0.55, 0.9))
		"sailboat_a", "sailboat_b":
			var L := 3.5 if name == "sailboat_a" else 4.5
			_box(root, Vector3(L, 0.6, 1.2), Vector3(0, 0.25, 0), Color(0.96, 0.96, 0.94) if name == "sailboat_a" else Color(0.85, 0.3, 0.25))
			_box(root, Vector3(L * 0.5, 0.25, 0.9), Vector3(-0.2, 0.65, 0), Color(0.3, 0.45, 0.7) if name == "sailboat_a" else Color(0.95, 0.9, 0.8))
			var mast := _box(root, Vector3(0.12, 5.0, 0.12), Vector3(0.3, 3.0, 0), Color(0.9, 0.9, 0.88))
			mast.name = "mast"
			_box(root, Vector3(0.35, 3.2, 0.3), Vector3(0.3, 2.3, 0), Color(0.98, 0.98, 0.96))
		"fuel_pump":
			_box(root, Vector3(0.8, 1.4, 0.6), Vector3(0, 0.7, 0), Color(0.85, 0.15, 0.12))
			_box(root, Vector3(1.6, 0.1, 1.2), Vector3(0, 1.9, 0), Color(0.95, 0.95, 0.9))
			_box(root, Vector3(0.15, 1.9, 0.15), Vector3(-0.7, 0.95, 0.5), Color(0.5, 0.5, 0.5))
			_box(root, Vector3(0.15, 1.9, 0.15), Vector3(0.7, 0.95, 0.5), Color(0.5, 0.5, 0.5))
		"wash_bay":
			_box(root, Vector3(6.0, 0.2, 6.0), Vector3(0, 0.1, 0), Color(0.55, 0.6, 0.65))
			_box(root, Vector3(0.3, 3.0, 0.3), Vector3(-2.2, 1.6, 0), Color(0.2, 0.5, 0.85))
			_box(root, Vector3(0.3, 3.0, 0.3), Vector3(2.2, 1.6, 0), Color(0.2, 0.5, 0.85))
			_box(root, Vector3(4.7, 0.3, 0.3), Vector3(0, 3.1, 0), Color(0.2, 0.5, 0.85))
		"cloud_bank", "cloud_puff":
			pass
		_:
			_box(root, Vector3(1.0, 1.0, 1.0), Vector3(0, 0.5, 0), Color(0.8, 0.4, 0.8))
	return root


static func _box(parent: Node3D, size: Vector3, at: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	m.metallic_specular = 0.0
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


# --- décor -----------------------------------------------------------------------------------------------------------

func rebuild() -> void:
	for c in _static.get_children():
		c.queue_free()
	sailboats.clear()
	marcel_node = null
	if sim == null:
		return
	var f := sim.fishing
	_places = f.places
	_services = f.services
	_built = f.built.size()
	_marcel = f.marcel
	_place(Layout.ODETTE_HUT, "")
	# état d'avant : le ponton pourri d'Odette, jusqu'à la fin de la réparation
	if f.places <= 0 or _sites().hiding("fish_places_1"):
		var r := _place(Layout.ANSE_RUIN, "")
		r.set_meta("before", "fish_places_1")
	# le ponton des places (un module par chantier qui l'a allongé) et un taquet par place
	var pds := Layout.places_pontoons(f.places)
	if not pds.is_empty():
		var main: Dictionary = pds[0]
		var n := int(main.n)
		for k in n:
			var m := Assets.instance("pontoon")
			m.position = Vector3(Layout.PLACES_PONTOON_X0 + 3.0 + 6.0 * float(k), Layout.WATER_Y, Layout.PLACES_PONTOON_Z)
			m.set_meta("site", "fish_places_%d" % module_level(k + 1))
			_static.add_child(m)
		for g in pds.slice(1):
			_pontoon(g, "fish_places_1")
		var berths: Array = Layout.FISH_BERTHS.dinghy
		for k in mini(f.places + 1, berths.size()):
			var b: Vector3 = berths[k]
			var cl := Assets.instance("cleat")
			cl.position = Vector3(b.x, Layout.WATER_Y + 0.45, Layout.PLACES_PONTOON_Z - 0.55)
			cl.set_meta("site", "fish_places_%d" % berth_level(k))
			_static.add_child(cl)
	# paliers nommés des Services
	for lv in range(1, f.services + 1):
		var nl := f.named_level(lv)
		if nl.is_empty() or not Layout.ANSE_BUILDINGS.has(String(nl.id)):
			continue
		var key := "fish_services_%d" % lv
		var bd: Dictionary = Layout.ANSE_BUILDINGS[String(nl.id)]
		var n := _model(String(bd.m))
		var p: Vector3 = bd.p
		if bool(bd.get("float", false)):
			n.position = Vector3(p.x, Layout.WATER_Y + float(Assets.meta("pontoon").get("deck_z", 0.45)), p.z)
		else:
			n.position = p + Vector3(0, Layout.ground_y(Vector2(p.x, p.z)), 0)
		n.rotation.y = deg_to_rad(float(bd.get("ry", 0.0)))
		n.set_meta("site", key)
		_static.add_child(n)
		if String(nl.id) == "fuel":
			_service_raft(key)
		if String(nl.id) == "hall":
			var road := Layout.FISH_ROAD
			var arr: Array = []
			var z := road.position.y
			while z < road.end.y - 0.1:
				arr.append(Vector2i(int(road.position.x), int(minf(z, road.end.y - 6.0))))
				z += 6.0
			var tm: MultiMeshInstance3D = dio.call("_tile_multimesh", "road_z", arr)
			tm.set_meta("site", key)
			tm.set_meta("tiles", true)
			_static.add_child(tm)
	# quai des chalutiers, grande jetée et sa passerelle, marina et ses voiliers
	if f.has("trawler"):
		for pd in Layout.anse_pontoons("trawler"):
			_pontoon(pd, "fish_trawler")
	if f.has("pier"):
		var pier := _model(String(Layout.PIER.m))
		var pp: Vector3 = Layout.PIER.p
		pier.position = Vector3(pp.x, Layout.WATER_Y, pp.z)
		pier.rotation.y = deg_to_rad(float(Layout.PIER.ry))
		pier.set_meta("site", "fish_pier")
		_static.add_child(pier)
		for pd in Layout.anse_pontoons("pier"):
			_pontoon(pd, "fish_pier")
	var sails_left := f.sails()
	var alt := 0
	for id in ["marina", "marina2", "marina3"]:
		if not f.has(id):
			continue
		for md in Layout.MARINA_MODULES[id]:
			var mm := _model("marina_pontoon")
			var c: Vector2 = md.c
			mm.position = Vector3(c.x, Layout.WATER_Y, c.y)
			mm.rotation.y = PI * 0.5      # (modèle 10 u le long de X ; les modules suivent z)
			mm.set_meta("site", "fish_" + id)
			_static.add_child(mm)
			for sl in Layout.marina_slots(md):
				if sails_left <= 0:
					break
				sails_left -= 1
				alt += 1
				var sb := _model("sailboat_a" if alt % 3 != 0 else "sailboat_b")
				var sp: Vector3 = sl.p
				sb.position = Vector3(sp.x, Layout.WATER_Y, sp.z)
				sb.rotation.y = float(sl.yaw)
				sb.set_meta("site", "fish_" + id)
				_static.add_child(sb)
				sailboats.append(sb)
	# Marcel (patron pêcheur) sur le ponton ; avant lui, un voisin pêcheur sur la plage devant la cabane, puis sur le ponton
	var who := _model("marcel", "docker") if f.marcel else Assets.instance("docker")
	if f.places > 0:
		who.position = Vector3(-133.0, Layout.WATER_Y + 0.45, Layout.PLACES_PONTOON_Z)
		who.rotation.y = deg_to_rad(-90.0)
	else:
		who.position = Vector3(-128.5, 0.0, 58.4)
		who.rotation.y = deg_to_rad(160.0)
	who.set_meta("fisher", true)
	_static.add_child(who)
	marcel_node = who
	# camionnette du mareyeur (avec la criée)
	if van == null or not is_instance_valid(van):
		van = Assets.instance("fish_van")
		van.name = "fish_van"
		add_child(van)
	van.visible = false
	_apply_hiding()


## Lot H1 — la jetée de séparation (4 segments `breakwater`, sans feu vert), le ponton de service (radeau de 3 × 5 modules
## `pontoon`, axe z) amarré à son flanc est et sa passerelle vers la plage : bâtis avec la pompe (palier nommé niv. 3).
func _service_raft(site: String) -> void:
	var seg := 12.53
	for k in 4:
		var j := Assets.instance("breakwater", Diorama._degreen_material())
		j.position = Vector3(Layout.JETTY_X, -1.0, Layout.JETTY_Z.x + seg * (float(k) + 0.5))
		j.rotation.y = PI * 0.5
		j.set_meta("site", site)
		j.set_meta("jetty", true)
		_static.add_child(j)
	var cols := 3
	var w := (Layout.RAFT_X.y - Layout.RAFT_X.x) / float(cols)
	var n := int(round((Layout.RAFT_Z.y - Layout.RAFT_Z.x) / 6.0))
	for c in cols:
		for k in n:
			var m := Assets.instance("pontoon")
			m.position = Vector3(Layout.RAFT_X.x + w * (float(c) + 0.5), Layout.WATER_Y, Layout.RAFT_Z.x + 6.0 * (float(k) + 0.5))
			m.rotation.y = PI * 0.5
			m.set_meta("site", site)
			m.set_meta("raft", true)
			_static.add_child(m)
	_pontoon(Layout.RAFT_WALK, site)
	# taquets au bord est, un par poste (carburant, lavage, glace)
	for id in Layout.STATION_Z:
		var cl := Assets.instance("cleat")
		cl.position = Vector3(Layout.RAFT_X.y - 0.45, Layout.WATER_Y + 0.45, float(Layout.STATION_Z[id]) + 2.0)
		cl.rotation.y = PI * 0.5
		cl.set_meta("site", site)
		cl.set_meta("cleat", true)
		_static.add_child(cl)


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


## Chantier d'un élément de la Crique (le bâtiment monte) : appelé par le diorama (signal SiteWorks.risen).
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


## Chantiers des achats de la Crique : un par niveau de Places (la place nouvelle, le module nouveau), un par palier nommé des
## Services, un par bâtiment. Clé SiteWorks « fish_<clé> ».
func _on_purchased(kind: String, id: String) -> void:
	if kind == "manager" and id == "marcel":
		rebuild()
		return
	if kind != "fish":
		return
	_ensure_boats(true)
	var f := sim.fishing
	var keys: Array[String] = []
	match id:
		"places":
			for lv in range(maxi(1, _places + 1), f.places + 1):
				keys.append("places_%d" % lv)
		"services":
			for lv in range(maxi(1, _services + 1), f.services + 1):
				if not f.named_level(lv).is_empty():
					keys.append("services_%d" % lv)
		_:
			keys.append(id)
	for key in keys:
		var spec := Layout.anse_site_spec(key, f.cfg)
		if not spec.is_empty():
			_sites().start("fish_" + key, spec)
	rebuild()


## Cadre (x, z) du dernier achat, pour la caméra (vide si rien à montrer).
func focus_of(id: String) -> Rect2:
	var f := sim.fishing
	var key := id
	if id == "places":
		key = "places_%d" % f.places
	elif id == "services":
		key = "services_%d" % f.services
		if f.named_level(f.services).is_empty():
			var b: Vector3 = Layout.fish_berth("dinghy", 0)
			return Rect2(b.x - 10, b.z - 10, 20, 20)
	var spec := Layout.anse_site_spec(key, f.cfg)
	return spec.focus if not spec.is_empty() else Rect2()


func _on_fish_event(kind: String) -> void:
	if kind == "announce":
		start_passing()


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
		elif kind.begins_with("node:"):
			# lot H1 : « node:<de>:<vers> » (ponton de service)
			var parts := kind.split(":")
			p = Layout.fish_path_node(cls, slot, parts[1], parts[2])
		else:
			var to_g := kind == "back_g"
			if fresh:
				var se := Layout.fish_sea_entry(cls)
				p = Layout.fish_path_back_g(se) if to_g else Layout.fish_path_back(cls, slot, se)
			else:
				var ho: Vector3 = Layout.fish_path_at(_path("out", cls, slot, false), 1.0)[1]
				var lead := Vector2(ho.x, ho.z).normalized()
				p = Layout.fish_path_back_g(Layout.fish_ground(cls, slot), lead) if to_g else Layout.fish_path_back(cls, slot, Layout.fish_ground(cls, slot), lead)
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
		Fishing.Phase.LAND, Fishing.Phase.WAIT:
			return {"p": berth, "yaw": Layout.fish_berth_yaw(cls), "crab": false, "visible": true}
		Fishing.Phase.QUEUE, Fishing.Phase.SERVE:
			# lot H1 : au poste d'attente ou à la station, étrave au sud
			return {"p": Layout.station_pos(String(bt.at), cls), "yaw": Layout.STATION_YAW, "crab": false, "visible": true}
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
			var kind := "out"
			var fresh := bool(v.fresh)
			match ph:
				Fishing.Phase.BACK:
					kind = "back_g" if bool(bt.via) else "back"
				Fishing.Phase.MOVE, Fishing.Phase.DOCK:
					kind = "node:%s:%s" % [String(bt.at), "b" if ph == Fishing.Phase.DOCK else String(bt.to)]
					fresh = false
			var wp := _path(kind, cls, slot, fresh)
			var e := Layout.fish_profile(f, minf(0.25, Layout.FISH_RAMP_S / maxf(0.5, dur)))
			var at := Layout.fish_path_at(wp, e)
			var crab := bool(at[2])
			var cy: Dictionary = wp.get("crab_yaw", {})
			var yaw := (float(cy[int(at[3])]) if cy.has(int(at[3])) else Layout.fish_berth_yaw(cls)) if crab else yaw_of(at[1])
			return {"p": at[0], "yaw": yaw, "crab": crab, "visible": true}


func sync(delta: float) -> void:
	_t += delta
	for b in bursts:
		b.t = float(b.t) + delta
	bursts = bursts.filter(func(b: Dictionary) -> bool: return float(b.t) < 0.5)
	if sim == null:
		return
	var f := sim.fishing
	if f.places != _places or f.services != _services or f.built.size() != _built or f.marcel != _marcel:
		rebuild()
	_ensure_boats(true)
	for i in boats.size():
		_sync_boat(i, delta)
	_sync_van(delta)
	_sync_passing(delta)
	for k in sailboats.size():
		var sb := sailboats[k]
		if is_instance_valid(sb):
			sb.rotation.z = 0.04 * sin(_t * 1.1 + float(k) * 0.9)


func _sync_boat(i: int, delta: float) -> void:
	var bt: Dictionary = sim.fishing.boats[i]
	var v: Dictionary = boats[i]
	var n: Node3D = v.node
	var ph := int(bt.phase)
	if bool(v.fresh) and ph != Fishing.Phase.FISH and ph != Fishing.Phase.BACK:
		v.fresh = false
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
	# caisses débarquées : sur le ponton pendant la débarque et l'attente du loyer
	var at_berth := ph == Fishing.Phase.LAND or ph == Fishing.Phase.WAIT
	var was_at_berth := int(v.phase) == Fishing.Phase.LAND or int(v.phase) == Fishing.Phase.WAIT
	if ph != int(v.phase):
		if at_berth and not was_at_berth:
			_crates_on(i)
		elif was_at_berth and not at_berth:
			_crates_off(i)
		v.phase = ph


func _crates_on(i: int) -> void:
	var v: Dictionary = boats[i]
	var bt: Dictionary = sim.fishing.boats[i]
	var cls := String(bt.cls)
	var b := Layout.fish_berth(cls, int(bt.slot))
	var spots: Array[Vector3] = []
	if cls == "dinghy":
		spots = [Vector3(b.x - 0.7, 0, Layout.PLACES_PONTOON_Z + 0.1), Vector3(b.x + 0.6, 0, Layout.PLACES_PONTOON_Z - 0.1)]
	elif cls == "tuna":
		spots = [Vector3(-96.2, 0, b.z - 1.5), Vector3(-96.0, 0, b.z), Vector3(-96.2, 0, b.z + 1.5), Vector3(-95.8, 0, b.z + 3.0)]
	else:
		spots = [Vector3(-95.6, 0, b.z - 1.2), Vector3(-95.6, 0, b.z + 0.2), Vector3(-95.4, 0, b.z + 1.5)]
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


## Un bateau repart : s'il a payé à Marcel, le montant s'affiche (« +X $ ») ; les débarques nourrissent la camionnette.
func _on_landed(i: int, amount: float, _manual: bool) -> void:
	landings_shown += 1
	if sim.fishing.services >= 1:
		_van_loads += 1
	if amount > 0.0 and i < boats.size():
		var bt: Dictionary = sim.fishing.boats[i]
		var b := Layout.fish_berth(String(bt.cls), int(bt.slot))
		popup.emit(b + Vector3(0, 3.0, 0), "+%s" % Fmt.money(amount), false)


## Lot H1 — un service rendu au ponton : l'anneau éclate en « +X $ » au-dessus de la station (pièces vers le compteur : HUD).
func _on_served(_i: int, st: String, amount: float) -> void:
	services_shown += 1
	bursts.append({"st": st, "t": 0.0})
	if bursts.size() > 6:
		bursts.pop_front()
	served.emit(Layout.station_ring_point(st), amount, st)


## Lot H1 — stations en service, pour la surcouche : [{st, p (point de l'anneau), prog (0–1), cls}] ; une station dont le
## bateau attend la suivante (service payé) n'a plus d'anneau.
func serving() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if sim == null:
		return out
	var f := sim.fishing
	for st in f.stations():
		var bi := f.station_boat(st)
		if bi < 0 or bi >= f.boats.size() or bi >= boats.size():
			continue
		var bt: Dictionary = f.boats[bi]
		if int(bt.phase) != Fishing.Phase.SERVE or bool(bt.done) or String(bt.at) != st:
			continue
		var prog := minf(1.0, f.progress(bi) + sub_t / maxf(0.1, float(bt.dur)))
		out.append({"st": st, "p": Layout.station_ring_point(st), "prog": prog, "cls": String(bt.cls)})
	return out


## Bateaux rentrés dont le loyer attend (bulle « Loyer »), visibles ; vide avec Marcel.
func collectable() -> Array[int]:
	var out: Array[int] = []
	if sim == null:
		return out
	for i in mini(boats.size(), sim.fishing.boats.size()):
		if sim.fishing.can_collect(i) and (boats[i].node as Node3D).visible:
			out.append(i)
	return out


## (compatibilité F3 : le tutoriel et la surcouche visaient « helpable »)
func helpable() -> Array[int]:
	return collectable()


func boat_pos(i: int) -> Vector3:
	if i < 0 or i >= boats.size():
		return Vector3.INF
	return (boats[i].node as Node3D).position


## Bateau rentré le plus proche du point touché (loyer à encaisser), -1 sinon.
func pick(wp: Vector3) -> int:
	var best := -1
	var bd := TAP_R
	for i in collectable():
		var d := Vector2(wp.x, wp.z).distance_to(Vector2(boat_pos(i).x, boat_pos(i).z))
		if d < bd:
			bd = d
			best = i
	return best


# --- caboteur de l'annonce --------------------------------------------------------------------------------------------
## Lot G1 — 8ᵉ minute : le caboteur de Corsaire & Fils traverse au large (dans le trou des nuages), de l'ouest vers l'est, à sa
## croisière, puis s'efface dans les nuages. Modèle `ship_passing`, sinon `ship_coaster`.
func start_passing() -> void:
	if passing != null and is_instance_valid(passing):
		return
	passing = _model("ship_passing", "ship_coaster")
	passing.name = "ship_passing"
	add_child(passing)
	_passing_d = 0.0
	passings += 1
	_place_passing()


func passing_active() -> bool:
	return passing != null and is_instance_valid(passing)


func _place_passing() -> void:
	var path: Array = Layout.PASSING_SHIP_PATH
	var a: Vector3 = path[0]
	var b: Vector3 = path[-1]
	var L := a.distance_to(b)
	var f := clampf(_passing_d / L, 0.0, 1.0)
	var p := a.lerp(b, f)
	passing.position = Vector3(p.x, Layout.WATER_Y + 0.05 * sin(_t * 1.1), p.z)
	passing.rotation.y = yaw_of((b - a).normalized())
	var fade := minf(1.0, minf(_passing_d / 12.0, (L - _passing_d) / 12.0))
	passing.scale = Vector3.ONE * maxf(0.01, fade)


func _sync_passing(delta: float) -> void:
	if not passing_active():
		return
	var path: Array = Layout.PASSING_SHIP_PATH
	var L := (path[0] as Vector3).distance_to(path[-1])
	_passing_d += PASSING_SPEED * delta * speed_k
	_place_passing()
	if _passing_d >= L:
		passing.queue_free()
		passing = null


# --- camionnette du mareyeur -------------------------------------------------------------------------------------------
## Garée devant la criée (étrave au nord) ; après deux débarques (ou toutes les 35 s), demi-tour devant la criée, route du
## mareyeur vers le sud, rue du village vers l'ouest, sous les arbres ; elle revient 12 s plus tard.
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
	if sim.fishing.services < 1 or not ready_key("services_1"):
		van.visible = false
		van_state = "park"
		return
	var dt := delta * speed_k
	_van_t += dt
	match van_state:
		"park":
			_van_pose(van_path_back(), 1.0)
			if _van_loads >= 2 or _van_t >= VAN_EVERY:
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
