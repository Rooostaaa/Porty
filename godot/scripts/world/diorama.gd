class_name Diorama
extends Node3D
## Le port en 3D : construit le décor selon le palier et les bâtiments, et reflète la simulation.

signal ship_tapped(ship_id: int)
signal place_tapped(dept: String)
signal assist_done(pos: Vector3, amount: float)     # coup de main donné à une grue
signal ship_prioritized(ship_id: int)               # accostage en priorité demandé

var sim: PortSim
var rig: CameraRig
var env: Environment
var sun: DirectionalLight3D
var water_mat: ShaderMaterial
var static_root: Node3D
var ships_root: Node3D
var cranes_root: Node3D
var yard: YardView
var traffic: TrafficView
var ship_views: Dictionary = {}       # id -> ShipView
var crane_views: Array[CraneView] = []
var marker: MeshInstance3D
var marker_mat: StandardMaterial3D
var manager_people: Dictionary = {}
var _marker_t := 0.0
var _fog := 0.0
var wind_fx: CPUParticles3D
var _sig := ""
var fx_paused := false                 # un écran couvre le monde (le HUD le règle) : les effets attendent
var _stage_shown: Dictionary = {}     # département -> éléments de palier déjà montrés
var _pending_pops: Array[Node3D] = [] # éléments apparus pendant qu'un écran couvrait le monde


func _ready() -> void:
	_build_env()
	_build_water()
	static_root = Node3D.new()
	add_child(static_root)
	cranes_root = Node3D.new()
	add_child(cranes_root)
	ships_root = Node3D.new()
	add_child(ships_root)
	yard = YardView.new()
	add_child(yard)
	traffic = TrafficView.new()
	traffic.yard = yard
	add_child(traffic)
	rig = CameraRig.new()
	add_child(rig)
	rig.tapped.connect(_on_tapped)
	_build_marker()
	_build_wind()


func bind(s: PortSim) -> void:
	if sim != null:
		for c in [["ship_spawned", _on_ship_spawned], ["ship_removed", _on_ship_removed], ["purchased", _on_purchased],
				["tier_changed", _on_tier_changed], ["truck_served", _on_truck_served]]:
			if sim.is_connected(c[0], c[1]):
				sim.disconnect(c[0], c[1])
	sim = s
	sim.ship_spawned.connect(_on_ship_spawned)
	sim.ship_removed.connect(_on_ship_removed)
	sim.purchased.connect(_on_purchased)
	sim.tier_changed.connect(_on_tier_changed)
	sim.truck_served.connect(_on_truck_served)
	for v in ship_views.values():
		(v as Node).queue_free()
	ship_views.clear()
	_stage_shown.clear()     # nouvelle partie : pas d'effet d'apparition au premier décor
	_pending_pops.clear()
	for sh in sim.ships:
		_on_ship_spawned(sh)
	_sig = signature()
	rebuild()


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Lumière (règle 7 du brief, lot B) : dessus 100 %, flanc +X (vers la droite de l'écran) ≈ 75 %, flanc +Z ≈ 65 %
## (ambiance seule), ombres portées nettes à −18 % environ, légèrement bleu-violet, jamais noires.
## Le soleil est placé en haut à droite derrière la caméra (il vient de +X, +Y, −Z) : les ombres tombent vers +Z,
## c'est-à-dire en bas à gauche de l'écran, comme dans la référence ISM.
## Les couleurs (valeurs linéaires ci-dessous) sont calculées pour que ambiance + soleil = blanc exact sur une face horizontale :
## un dessus éclairé rend la teinte de palette.json sans dérive (vérifié par tests/swatch_test.tscn).
const AMBIENT_ENERGY := 0.67
const AMBIENT_COLOR := Color(0.96, 0.94, 1.0)         # teinte des flancs à l'ombre et des ombres portées
const SUN_DIR := Vector3(-0.243, -0.85, 0.467)         # direction de la lumière (normalisée ensuite)
const SHADOW_OPACITY := 0.5                            # ombre portée = −18 % sur un dessus
const SHADOW_BLUR := 0.4                               # ombres nettes (1,5 avant)


## Environnement du diorama (fond, ambiance, correction linéaire, brouillard désactivé). Partagé avec swatch_test.
static func make_environment() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#8fd0f0")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Godot convertit cette couleur de sRGB en linéaire : on lui donne l'équivalent sRGB de la valeur linéaire voulue
	e.ambient_light_color = AMBIENT_COLOR.linear_to_srgb()
	e.ambient_light_energy = AMBIENT_ENERGY
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.adjustment_enabled = false      # plus de saturation/contraste ajoutés : la palette est rendue telle quelle
	e.fog_enabled = true
	e.fog_light_color = Color("#e9eef5")
	e.fog_density = 0.0
	e.fog_sky_affect = 0.0
	return e


## Soleil du diorama : énergie et couleur déduites de l'ambiance pour que dessus = blanc exact (voir AMBIENT_*).
static func make_sun() -> DirectionalLight3D:
	var s := DirectionalLight3D.new()
	var d := SUN_DIR.normalized()
	s.transform = Transform3D(Basis.looking_at(d, Vector3.UP), Vector3.ZERO)
	var rest := Color(1.0 - AMBIENT_COLOR.r * AMBIENT_ENERGY, 1.0 - AMBIENT_COLOR.g * AMBIENT_ENERGY, 1.0 - AMBIENT_COLOR.b * AMBIENT_ENERGY)
	var peak := maxf(rest.r, maxf(rest.g, rest.b))
	s.light_energy = peak / absf(d.y)                   # ≈ 0,44 : soleil × cos(incidence) sur un dessus = 1 − ambiance
	s.light_color = Color(rest.r / peak, rest.g / peak, rest.b / peak).linear_to_srgb()   # idem : valeur linéaire voulue → sRGB
	s.shadow_enabled = true
	s.shadow_blur = SHADOW_BLUR
	s.shadow_opacity = SHADOW_OPACITY
	s.directional_shadow_max_distance = 320.0
	s.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	return s


func _build_env() -> void:
	var we := WorldEnvironment.new()
	env = make_environment()
	we.environment = env
	add_child(we)
	sun = make_sun()
	add_child(sun)


func _build_water() -> void:
	var w := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	pm.subdivide_width = 90
	pm.subdivide_depth = 90
	w.mesh = pm
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://assets/water.gdshader")
	var shallow := Assets.color("water")
	water_mat.set_shader_parameter("shore", shallow.lerp(Assets.color("foam"), 0.4))
	water_mat.set_shader_parameter("shallow", shallow)
	water_mat.set_shader_parameter("deep", Assets.color("water_deep"))
	water_mat.set_shader_parameter("sparkle", Assets.color("foam"))
	w.material_override = water_mat
	w.position = Vector3(40, Layout.WATER_Y, 0)
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(w)
	_update_water_land(1)


## Rectangles de terre (x0, z0, x1, z1) transmis au shader de l'eau : dégradé selon la distance au rivage.
func _update_water_land(tier: int) -> void:
	var lx: Array = Layout.LAND_X.get(tier, Layout.LAND_X[1])
	var rects: Array[Vector4] = [
		Vector4(float(lx[0]), Layout.SEA_EDGE_Z, float(lx[1]), Layout.LAND_Z1),   # le port (quai compris)
		Vector4(-120.0, Layout.LAND_Z1, 174.0, 66.0),                               # terre ferme (plages)
		Vector4(-132.0, 66.0, 186.0, 150.0),
		Vector4(-114.0, 150.0, 168.0, 168.0),
		Vector4(-60.0, -18.0, -56.0, -8.0),                                         # rochers du phare
	]
	if Assets.exists("breakwater"):
		rects.append(Vector4(-85.5, -46.0, -82.5, -7.0))
	var arr: Array = []
	for r in rects:
		arr.append(r)
	water_mat.set_shader_parameter("land", PackedVector4Array(arr))
	water_mat.set_shader_parameter("land_count", rects.size())


func _foam_strip(x0: float, x1: float, z: float) -> void:
	var m := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(x1 - x0, 1.6)
	qm.orientation = PlaneMesh.FACE_Y
	m.mesh = qm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/foam.gdshader")
	sm.set_shader_parameter("foam", Assets.color("foam"))
	m.material_override = sm
	m.position = Vector3((x0 + x1) * 0.5, Layout.WATER_Y + 0.08, z - 0.8)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	static_root.add_child(m)


func _build_marker() -> void:
	marker = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 3.4
	tm.outer_radius = 4.2
	tm.rings = 24
	tm.ring_segments = 8
	marker.mesh = tm
	marker_mat = StandardMaterial3D.new()
	marker_mat.albedo_color = Color(1.0, 0.25, 0.22, 0.85)
	marker_mat.emission_enabled = true
	marker_mat.emission = Color(1.0, 0.2, 0.15)
	marker_mat.emission_energy_multiplier = 0.8
	marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = marker_mat
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)


func _build_wind() -> void:
	wind_fx = CPUParticles3D.new()
	wind_fx.amount = 90
	wind_fx.lifetime = 2.0
	wind_fx.emitting = false
	var qm := QuadMesh.new()
	qm.size = Vector2(3.5, 0.08)
	wind_fx.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	wind_fx.material_override = m
	wind_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	wind_fx.emission_box_extents = Vector3(80, 10, 60)
	wind_fx.direction = Vector3(1, 0, 0.3)
	wind_fx.spread = 5.0
	wind_fx.gravity = Vector3.ZERO
	wind_fx.initial_velocity_min = 30.0
	wind_fx.initial_velocity_max = 45.0
	wind_fx.position = Vector3(-10, 14, 0)
	add_child(wind_fx)


func _cond_ok(cond: String) -> bool:
	if cond == "":
		return true
	if cond == "t1":          # seulement au premier palier (vieux quai de pêcheurs)
		return sim.tier == 1
	if cond == "t2":
		return sim.tier >= 2
	if cond == "t3":
		return sim.tier >= 3
	return sim.built.has(cond)


## Reconstruit le décor statique, les grues et le parc (après un achat de bâtiment ou un palier).
func rebuild() -> void:
	for c in static_root.get_children():
		c.queue_free()
	var barriers: Array[Node3D] = []
	# dalles de sol (MultiMesh par type)
	var tiles := {}
	for g in Layout.GROUNDS:
		if not _cond_ok(String(g.cond)):
			continue
		var r: Array = g.r
		var x := float(r[0])
		while x < float(r[2]) - 0.1:
			var z := float(r[1])
			while z < float(r[3]) - 0.1:
				tiles[Vector2i(roundi(x), roundi(z))] = String(g.type)
				z += Layout.TILE
			x += Layout.TILE
	var by_type := {}
	for k in tiles:
		var t: String = tiles[k]
		if not by_type.has(t):
			by_type[t] = []
		by_type[t].append(k)
	for t in by_type:
		var arr: Array = by_type[t]
		var mi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		# routes : le modèle « road » est orienté selon X ; « road_z » est le même tourné de 90°
		var model: String = "road" if String(t).begins_with("road") else String(t)
		var tile_basis := Basis(Vector3.UP, deg_to_rad(90.0)) if t == "road_z" else Basis.IDENTITY
		mm.mesh = Assets.mesh(model)
		mm.instance_count = arr.size()
		for i in arr.size():
			var k: Vector2i = arr[i]
			mm.set_instance_transform(i, Transform3D(tile_basis, Vector3(k.x + 3.0, 0, k.y + 3.0)))
		mi.multimesh = mm
		mi.material_override = Assets.vcol_material
		static_root.add_child(mi)
	# quais : segments pour chaque poste existant + musoirs
	var nb := sim.berths.size()
	var x_end := -36.0
	for bi in nb:
		var b: Dictionary = Layout.BERTHS[mini(bi, Layout.BERTHS.size() - 1)]
		var x := float(b.x0)
		# le vieux quai est court : l'allongement (bâtiment « quay_ext ») ajoute son dernier segment
		var x1 := float(b.x1) - (12.0 if bi == 0 and not sim.built.has("quay_ext") else 0.0)
		while x < x1 - 0.1:
			var q := Assets.instance("quay")
			q.position = Vector3(x + 6.0, 0, Layout.QUAY_Z)
			q.rotation.y = 0.0
			static_root.add_child(q)
			x += 12.0
		_foam_strip(float(b.x0), x1, Layout.SEA_EDGE_Z)
		x_end = maxf(x_end, x1)
	# musoirs et quais de liaison jusqu'au bord des terres
	var lx: Array = Layout.LAND_X[sim.tier]
	var x2 := x_end
	while x2 < float(lx[1]) - 0.1:
		var qe := Assets.instance("quay_end")
		qe.position = Vector3(x2 + 3.0, 0, Layout.QUAY_Z)
		static_root.add_child(qe)
		x2 += 6.0
	for xw in [-45.0, -39.0]:
		var qw := Assets.instance("quay_end")
		qw.position = Vector3(xw, 0, Layout.QUAY_Z)
		static_root.add_child(qw)
	# décor et bâtiments
	for p in Layout.PROPS:
		if not _cond_ok(String(p.cond)):
			continue
		if p.has("not") and sim.built.has(p.not):
			continue
		# « neutral » : gris tant que la condition n'est pas remplie (entrepôts du village avant le T3)
		var neutral: bool = p.has("neutral") and not _cond_ok(String(p.neutral))
		var n := Assets.instance(String(p.m), _neutral_material() if neutral else null)
		var pp: Array = p.p
		n.position = Vector3(float(pp[0]), float(pp[1]), float(pp[2]))
		if p.has("on"):          # posé sur le sommet d'un autre modèle (mouette sur le toit du hangar)
			n.position.y += Assets.top_y(String(p.on))
		n.rotation.y = deg_to_rad(float(p.get("ry", 0.0)))
		if p.has("s"):
			n.scale = Vector3.ONE * float(p.s)
		static_root.add_child(n)
		if String(p.get("tag", "")).begins_with("barrier"):
			barriers.append(n)
	traffic.set_barriers(barriers)
	_build_scatter()
	_build_multi(Layout.quay_props(nb, sim.built.has("quay_ext"), sim.tier))
	_build_multi(Layout.street_props(sim.tier, sim.built))
	# personnel : chacun fait l'aller-retour entre deux points proches (tablier ↔ parc, douane ↔ table, capitainerie ↔ quai)
	traffic.walkers.clear()
	for i in 3:
		var a := Vector3(-30.0 + i * 11.0, 0, 1.6)
		_add_walker("docker", a, a + Vector3(2.0 - i * 2.0, 0, 9.0 + i * 1.5), 0.0)
	# douanier : de la porte du bureau à la table d'inspection du modèle customs_hut
	_add_walker("customs_officer", Layout.CUSTOMS_HUT + Vector3(3.0, 0, 1.4), Layout.CUSTOMS_HUT + Vector3(-1.5, 0, 3.6), 90.0)
	for d in PortSim.DEPTS:
		if sim.managers[d]:
			var a := Layout.dept_pos(d, sim.tier) + Vector3(3.0, 0, 3.0)
			var mg := _add_walker("manager", a, a + Layout.MANAGER_WALK.get(d, Vector3(0, 0, -5)), 0.0)
			mg.scale = Vector3.ONE * 1.25
	_build_stage_props()
	_rebuild_cranes()
	yard.rebuild(sim)
	rig.set_tier_bounds(sim.tier)
	_update_water_land(sim.tier)


## Personnage qui marche entre a et b (demi-tour instantané, léger balancement) ; ry = orientation au repos.
func _add_walker(model: String, a: Vector3, b: Vector3, ry: float) -> Node3D:
	var n := Assets.instance(model)
	n.position = a
	n.rotation.y = deg_to_rad(ry)
	static_root.add_child(n)
	traffic.add_walker(n, a, b)
	return n


static var _neutral_mat: ShaderMaterial


## Matériau gris neutre (couleurs désaturées) : bâtiments dont le département n'existe pas encore.
static func _neutral_material() -> ShaderMaterial:
	if _neutral_mat == null:
		Assets._ensure()
		_neutral_mat = Assets.vcol_material.duplicate()
		_neutral_mat.set_shader_parameter("desat", 0.85)
		_neutral_mat.set_shader_parameter("tint", Color(0.93, 0.93, 0.95))
	return _neutral_mat


## Arbres, buissons et rochers de l'arrière-pays : un MultiMesh par modèle.
func _build_scatter() -> void:
	_build_multi(Layout.scatter())


## Liste [{m, p, ry, s, on?}] → un MultiMesh par modèle. Un modèle absent (pas encore livré) est simplement ignoré.
func _build_multi(items: Array) -> void:
	var by_model := {}
	for it in items:
		var m := String(it.m)
		if not by_model.has(m):
			by_model[m] = []
		by_model[m].append(it)
	for m in by_model:
		var arr: Array = by_model[m]
		var mesh := Assets.mesh(String(m))
		if mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = arr.size()
		for i in arr.size():
			var it: Dictionary = arr[i]
			var b := Basis(Vector3.UP, deg_to_rad(float(it.ry))).scaled(Vector3.ONE * float(it.s))
			var p: Vector3 = it.p
			if it.has("on"):
				p.y += Assets.top_y(String(it.on))
			mm.set_instance_transform(i, Transform3D(b, p))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = Assets.vcol_material
		static_root.add_child(mi)


func _rebuild_cranes() -> void:
	for c in crane_views:
		c.queue_free()
	crane_views.clear()
	for bi in sim.berths.size():
		var b: Dictionary = Layout.BERTHS[mini(bi, Layout.BERTHS.size() - 1)]
		var cr: Array = sim.berths[bi].cranes
		var n := cr.size()
		var span := float(b.x1) - float(b.x0)
		for ci in n:
			var cv := CraneView.new()
			cranes_root.add_child(cv)
			var kind := String(cr[ci].kind)
			cv.setup(kind, bi)
			cv.dropped.connect(_on_crane_drop)
			var x := float(b.x0) + span * (float(ci) + 0.5) / float(n)
			cv.position = Vector3(x, 0, Layout.QUAY_Z if kind == "sts" else -1.6)
			crane_views.append(cv)


## Éléments gagnés aux paliers de niveau (Layout.STAGE_PROPS) ; ceux qui viennent d'apparaître surgissent avec un nuage de poussière.
func _build_stage_props() -> void:
	_pending_pops.clear()     # le décor est recréé : les anciens nœuds n'existent plus
	for d in PortSim.DEPTS:
		var list: Array = Layout.STAGE_PROPS.get(d, [])
		var n := mini(sim.dept_stage(d), list.size())
		var shown := int(_stage_shown.get(d, n))
		for i in n:
			var it: Dictionary = list[i]
			var node := Assets.instance(String(it.m))
			var pp: Array = it.p
			node.position = Vector3(float(pp[0]), float(pp[1]), float(pp[2]))
			node.rotation.y = deg_to_rad(float(it.get("ry", 0.0)))
			static_root.add_child(node)
			if it.has("walk"):      # personnage : aller-retour entre sa place et place + walk
				var w: Array = it.walk
				traffic.add_walker(node, node.position, node.position + Vector3(float(w[0]), 0, float(w[1])))
			if i >= shown:
				node.scale = Vector3.ONE * 0.01
				_pending_pops.append(node)
		_stage_shown[d] = n


func _play_pops() -> void:
	for node in _pending_pops:
		if not is_instance_valid(node):
			continue
		var tw := node.create_tween()
		tw.tween_property(node, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_dust(node.position)
	_pending_pops.clear()
	Sfx.play("clank", 0.2)


## Petit nuage de poussière (apparition d'un élément de palier).
func _dust(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 18
	p.lifetime = 0.9
	p.mesh = SphereMesh.new()
	(p.mesh as SphereMesh).radius = 0.35
	(p.mesh as SphereMesh).height = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.93, 0.88, 0.78, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = mat
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -3.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	add_child(p)
	p.position = pos + Vector3(0, 0.6, 0)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(1.4)
	tw.tween_callback(p.queue_free)


func signature() -> String:
	var st := ""
	for d in PortSim.DEPTS:
		st += str(sim.dept_stage(d))
	return "%d|%s|%s|%d|%s" % [sim.tier, ",".join(sim.built), str(sim.managers.values()), sim.berths.size(), st]


# ---------------------------------------------------------------------------
# Signaux
# ---------------------------------------------------------------------------

func _on_ship_spawned(s: Ship) -> void:
	if s.state == Ship.State.ARRIVING:
		Sfx.play("ship_horn", 5.0)
	var v := ShipView.new()
	ships_root.add_child(v)
	v.setup(s, sim)
	ship_views[s.id] = v
	if s.state != Ship.State.ARRIVING:
		v.position = Layout.anchor_pos(maxi(0, s.anchor_slot)) if s.berth < 0 else Layout.berth_ship_pos(s.berth, v.width)


func _on_ship_removed(s: Ship) -> void:
	if ship_views.has(s.id):
		(ship_views[s.id] as Node).queue_free()
		ship_views.erase(s.id)


func _on_crane_drop() -> void:
	Sfx.play("clank", 0.3)


func _on_purchased(_kind: String, _id: String) -> void:
	pass   # la signature (palier, bâtiments, responsables) déclenche la reconstruction


func _on_tier_changed(_t: int) -> void:
	pass


func _on_truck_served(_w: float) -> void:
	traffic.on_truck_served(sim)


# ---------------------------------------------------------------------------
# Image par image
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if sim == null:
		return
	var sig := signature()
	if sig != _sig:
		_sig = sig
		if static_root.get_child_count() > 0:
			rebuild()
	for s in sim.ships:
		var v: ShipView = ship_views.get(s.id)
		if v != null:
			v.sync(s, sim, delta)
	_sync_cranes()
	yard.sync(sim, delta)
	traffic.sync(sim, delta)
	_sync_marker(delta)
	_sync_weather(delta)
	traffic.walk_paused = fx_paused
	if not fx_paused and not _pending_pops.is_empty():
		_play_pops()
	sun.directional_shadow_max_distance = rig.dist() + 160.0


func _sync_cranes() -> void:
	var wind := sim.stat("crane_rate") <= 0.0
	var rate := sim.stat("crane_rate")
	for cv in crane_views:
		var ship: Ship = null
		var bi := cv.berth
		if bi < sim.berths.size():
			var sid := int(sim.berths[bi].ship)
			if sid >= 0:
				ship = sim.ship_by_id(sid)
		cv.stopped = wind
		cv.busy = ship != null and ship.state == Ship.State.UNLOADING and sim.apron_stock() < sim.apron_capacity() - 0.5
		cv.period = clampf(5.5 / sqrt(maxf(rate, 0.1) / 3.0), 1.4, 6.0)
		if ship != null:
			var v: ShipView = ship_views.get(ship.id)
			if v != null:
				cv.ship_rel_z = v.position.z - cv.position.z
				cv.ship_deck_y = Layout.WATER_Y + 3.0


func _sync_marker(delta: float) -> void:
	_marker_t += delta
	var dept: String = sim.analysis.get("dept", "")
	var key: String = sim.analysis.get("key", "")
	var p := Layout.dept_pos(dept, sim.tier)
	if key == "harbor" or key == "fog" or key == "pilotage":
		p = Layout.anchor_pos(0) + Vector3(16, 0, 0) if key != "harbor" else p
	elif key == "berth_count":
		var nb := sim.berths.size()
		if nb < Layout.BERTHS.size():
			p = Vector3(Layout.berth_center(nb), 0, Layout.QUAY_Z)
	elif key == "yard_space":
		p = Layout.YARD_CENTER
	var s := 1.0 + 0.12 * sin(_marker_t * 5.0)
	marker.position = p + Vector3(0, 0.35, 0)
	marker.scale = Vector3(s, 1, s)
	marker_mat.albedo_color.a = 0.55 + 0.3 * sin(_marker_t * 5.0)


func _sync_weather(delta: float) -> void:
	var fog := sim.stat("pilot_speed") <= 0.0
	_fog = move_toward(_fog, 1.0 if fog else 0.0, delta * 0.5)
	env.fog_density = 0.018 * _fog
	wind_fx.emitting = sim.stat("crane_rate") <= 0.0 or (not sim.active_event.is_empty() and sim.active_event.id == "wind")


# ---------------------------------------------------------------------------
# Sélection
# ---------------------------------------------------------------------------

func _on_tapped(wp: Vector3, _sp: Vector2) -> void:
	# coup de main : toucher une grue qui décharge (tant que le chef des grutiers n'est pas embauché)
	for cv in crane_views:
		if cv.berth < sim.berths.size() and sim.assist_ready(cv.berth) \
				and Vector2(cv.position.x - wp.x, cv.position.z - wp.z).length() < 8.0:
			var moved := sim.assist_unload(cv.berth)
			if moved > 0.0:
				assist_done.emit(cv.position + Vector3(0, 7, 0), moved)
				cv.kick()
				return
	var best_id := -1
	var best_d := 14.0
	for id in ship_views:
		var v: ShipView = ship_views[id]
		var d := Vector2(v.position.x - wp.x, v.position.z - wp.z).length()
		if d < best_d + v.length * 0.25:
			best_d = d
			best_id = id
	if best_id >= 0:
		# navire en rade : un seul toucher l'accoste en priorité (la Capitainerie le fera seule une fois embauchée)
		var sh := sim.ship_by_id(best_id)
		if sh != null and sh.state == Ship.State.ANCHORED and not sh.priority and not sim.managers.harbor:
			if sim.prioritize_ship(best_id):
				ship_prioritized.emit(best_id)
				return
		ship_tapped.emit(best_id)
		return
	var best_dept := ""
	var bd := 9.0
	for d in PortSim.DEPTS:
		var p := Layout.dept_pos(d, sim.tier)
		var dd := Vector2(p.x - wp.x, p.z - wp.z).length()
		if dd < bd:
			bd = dd
			best_dept = d
	if best_dept != "":
		rig.focus(Layout.dept_pos(best_dept, sim.tier))
		place_tapped.emit(best_dept)


## Position écran d'un point du monde (pour l'interface superposée).
func to_screen(p: Vector3) -> Vector2:
	return rig.cam.unproject_position(p)


func is_visible_point(p: Vector3) -> bool:
	return not rig.cam.is_position_behind(p)
