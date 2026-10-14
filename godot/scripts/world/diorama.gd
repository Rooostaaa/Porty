class_name Diorama
extends Node3D
## Le port en 3D : construit le décor selon le plan coté (Layout), le palier et les bâtiments, et reflète la simulation.
## Terrain polygonal (Terrain), zones grisées / prochaine / ouvertes (Zones), empreintes des bâtiments futurs dans leur case,
## séquence d'ouverture d'une zone (la récompense : caméra, vague de couleur, bâtiments qui surgissent, repère, narratrice).

signal ship_tapped(ship_id: int)
signal place_tapped(dept: String)
signal assist_done(pos: Vector3, amount: float)     # coup de main donné à une grue
signal ship_prioritized(ship_id: int)               # accostage en priorité demandé
signal lot_tapped(bid: String)                      # empreinte du prochain bâtiment (ou pancarte de la zone prochaine) touchée
signal zone_tapped(zone_id: int, pos: Vector3)      # zone grise touchée : une bulle d'information (2 s)
signal zone_opened(zone_id: int)                    # temps fort d'une ouverture de zone (repère, son grave, narratrice)
signal gesture_done(pos: Vector3, text: String, evp: float)       # geste optionnel du parc ou de la gate (EVP déplacés)
## Un navire a terminé son escale (il quitte son poste) : position du navire, montant encaissé pour cette escale (droits
## de port + services + manutention). La simulation ne mémorise pas ce montant par navire : il est **estimé** à partir de la
## cargaison relevée à l'arrivée du navire, des valeurs de cargaison du moment et des droits de port (même formule que
## PortSim, en lecture seule). Lot D : l'interface s'en sert pour un « +X $ » par événement.
signal ship_paid(world_pos: Vector3, amount: float)

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
var parting: Array[ShipView] = []     # navires sortis de la simulation qui finissent leur trajet à l'écran
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
# --- plan coté : zones, empreintes, pancartes ---
var dash_white: StandardMaterial3D
var dash_gold: StandardMaterial3D
var dash_faint: StandardMaterial3D       # pointillés d'une zone grise discrète (lot D)
var ghost_buoy_mat: StandardMaterial3D   # bouées fantômes du chenal à venir
var ghost_mat: ShaderMaterial
var ghost_next_mat: ShaderMaterial
var zone_nodes: Dictionary = {}        # id de zone -> {floor, nodes: Array[Node3D], landmark}
var next_lot := ""                      # bâtiment dont l'empreinte porte la pancarte (prochain achat de la chaîne)
var sign_node: Node3D                   # pancarte de la zone prochaine (modèle zone_sign)
var pass_lights: Array[Node3D] = []
var _open_ids: Array[int] = []          # zones ouvertes à la dernière construction
var _built_once := false                # la première construction d'une partie ne joue pas de séquence
var _water_key := -1                    # terre-plein présent (1) ou non (0) dans la texture de distance actuelle
var water_field: PackedFloat32Array     # distance au rivage (tests)
static var water_fields_built := 0      # champs de distance calculés depuis le lancement (tests)
var _t := 0.0
# --- séquence d'ouverture de zone ---
var opening: Dictionary = {}            # séquence en cours (vide sinon)
var opening_queue: Array[int] = []
var openings_done := 0                  # séquences terminées (tests)
var view_home := Vector3.INF            # vue du joueur pendant un recentrage provisoire de la caméra (Hud, chapitre d'un service)
# --- vie du port (lot D) : retours d'achat, Heures sup, campagne, encaissement par navire ---
var overtime_on := false                # Heures sup ×2 visibles (set_overtime)
var campaign_on := false                # campagne de démarchage en cours (set_campaign)
var _crane_rush := 0.0                  # s restantes d'accélération des grues après un achat (feedback_purchase)
var _ship_cargo0: Dictionary = {}       # id du navire -> cargaison à l'arrivée (estimation de ship_paid)
var ships_paid := 0                     # signaux ship_paid émis (tests)
var purchase_feedbacks := 0             # retours d'achat joués (tests)


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
	traffic.on_screen = func(p: Vector3) -> bool:
		return rig.cam != null and not rig.cam.is_position_behind(p) and get_viewport().get_visible_rect().has_point(rig.cam.unproject_position(p))
	rig.tapped.connect(_on_tapped)
	_build_marker()
	_build_wind()
	_build_crowd()
	dash_white = Terrain.dash_material(Assets.color("zone_dash"))
	dash_white.albedo_color.a = 0.85
	dash_faint = Terrain.dash_material(Assets.color("zone_dash"))
	dash_faint.albedo_color.a = 0.28
	dash_gold = Terrain.dash_material(Assets.color("mark_yellow"))
	ghost_buoy_mat = Terrain.dash_material(Layout.GHOST_BUOY_COLOR)
	Assets._ensure()
	ghost_mat = Assets.vcol_material.duplicate()
	ghost_mat.set_shader_parameter("tint", Color(1.0, 1.0, 1.0))
	ghost_next_mat = Assets.vcol_material.duplicate()
	ghost_next_mat.set_shader_parameter("tint", Assets.color("mark_yellow").srgb_to_linear() * 1.6)


func bind(s: PortSim) -> void:
	if sim != null:
		for c in [["ship_spawned", _on_ship_spawned], ["ship_removed", _on_ship_removed], ["purchased", _on_purchased],
				["tier_changed", _on_tier_changed], ["truck_served", _on_truck_served], ["ship_state_changed", _on_ship_state]]:
			if sim.is_connected(c[0], c[1]):
				sim.disconnect(c[0], c[1])
	sim = s
	sim.ship_spawned.connect(_on_ship_spawned)
	sim.ship_removed.connect(_on_ship_removed)
	sim.purchased.connect(_on_purchased)
	sim.tier_changed.connect(_on_tier_changed)
	sim.truck_served.connect(_on_truck_served)
	sim.ship_state_changed.connect(_on_ship_state)
	_ship_cargo0.clear()
	crowd.clear()
	for v in ship_views.values():
		(v as Node).queue_free()
	ship_views.clear()
	for v in parting:
		if is_instance_valid(v):
			v.queue_free()
	parting.clear()
	_stage_shown.clear()     # nouvelle partie : pas d'effet d'apparition au premier décor
	_pending_pops.clear()
	_built_once = false      # ni séquence d'ouverture pour ce qui est déjà ouvert
	_finish_opening(true)
	opening_queue.clear()
	view_home = Vector3.INF
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
	_sun_base = sun.light_color
	_amb_base = env.ambient_light_color


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
	var r := Layout.MASK_RECT
	water_mat.set_shader_parameter("mask_rect", Vector4(r.position.x, r.position.y, r.end.x, r.end.y))
	w.material_override = water_mat
	w.position = Vector3(40, Layout.WATER_Y, 0)
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(w)
	# la texture de distance est posée par la première construction (bind → rebuild), selon le terre-plein de la partie :
	# plus de double calcul au chargement d'une partie au palier 3 (revue C7 D)


## Texture de distance au rivage (côte, brise-lames, terre-plein) transmise au shader de l'eau ; changée quand le
## terre-plein apparaît (la mer devient terre). Chaque état n'est calculé qu'une fois (cache : nouvelle concession, retour
## au T1 après un T3…, revue C7 D).
static var _water_cache: Dictionary = {}      # 0 / 1 (terre-plein) -> [champ, texture]


func _update_water_land(reclaimed: bool) -> void:
	var key := 1 if reclaimed else 0
	if key == _water_key:
		return
	_water_key = key
	if not _water_cache.has(key):
		var f := Terrain.distance_field(Layout.land_polys(reclaimed))
		_water_cache[key] = [f, Terrain.distance_texture(f)]
		water_fields_built += 1
	water_field = _water_cache[key][0]
	water_mat.set_shader_parameter("dist_tex", _water_cache[key][1])


func _foam_strip(x0: float, x1: float, z: float) -> Node3D:
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
	return m


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


## Ajoute un nœud au décor et le range dans sa zone (pour la séquence d'ouverture).
func _add(n: Node3D, zone_id: int) -> Node3D:
	static_root.add_child(n)
	if zone_id > 0:
		if not zone_nodes.has(zone_id):
			zone_nodes[zone_id] = {"floor": null, "nodes": [], "landmark": null}
		(zone_nodes[zone_id].nodes as Array).append(n)
	return n


## Reconstruit le décor statique, les grues et le parc (après un achat de bâtiment ou un palier).
func rebuild() -> void:
	# une ouverture de zone en cours tient des nœuds qui vont être libérés : on la termine d'abord (comme un toucher qui la
	# passe : état final, narratrice, retour de la caméra) — revue C7 B1
	if not opening.is_empty():
		_finish_opening(false)
	for c in static_root.get_children():
		c.queue_free()
	zone_nodes.clear()
	pass_lights.clear()
	sign_node = null
	var open_now: Array[int] = []
	for z in Layout.ZONES:
		if Zones.is_open(sim, z):
			open_now.append(int(z.id))
	var newly: Array[int] = []
	if _built_once:
		for id in open_now:
			if not _open_ids.has(id):
				newly.append(id)
	_open_ids = open_now
	var barriers: Array[Node3D] = []
	_build_terrain()
	_build_zones()
	# dalles de sol : un MultiMesh par type ; les dalles d'une zone (sols et routes conditionnés par son bâtiment) forment
	# un MultiMesh à part, rangé dans la zone : à son ouverture, elles n'apparaissent qu'après le chantier (terre-plein :
	# après le sable)
	var tiles := {}
	var tile_zone := {}
	for g in Layout.GROUNDS:
		if not _cond_ok(String(g.cond)):
			continue
		var r: Array = g.r
		var gz := 0
		if String(g.cond) != "":
			gz = Zones.zone_for_cond(String(g.cond), Vector3((float(r[0]) + float(r[2])) * 0.5, 0, (float(r[1]) + float(r[3])) * 0.5))
		var x := float(r[0])
		while x < float(r[2]) - 0.1:
			var z := float(r[1])
			while z < float(r[3]) - 0.1:
				var k := Vector2i(roundi(x), roundi(z))
				tiles[k] = String(g.type)
				tile_zone[k] = gz
				z += Layout.TILE
			x += Layout.TILE
	var groups := {}
	for k in tiles:
		var gk := "%d|%s" % [int(tile_zone[k]), tiles[k]]
		if not groups.has(gk):
			groups[gk] = []
		groups[gk].append(k)
	for gk in groups:
		var parts := String(gk).split("|")
		var tzid := int(parts[0])
		var tmi := _tile_multimesh(parts[1], groups[gk])
		if tzid > 0:
			_add(tmi, tzid)
			tmi.set_meta("tiles", true)
		else:
			static_root.add_child(tmi)
	# quais : segments pour chaque poste existant + musoirs (le segment de l'allongement appartient à sa zone)
	var nb := sim.berths.size()
	var x_end := -36.0
	for bi in nb:
		var b: Dictionary = Layout.BERTHS[mini(bi, Layout.BERTHS.size() - 1)]
		var x := float(b.x0)
		# le vieux quai est court : l'allongement (bâtiment « quay_ext ») ajoute son dernier segment
		var x1 := float(b.x1) - (12.0 if bi == 0 and not sim.built.has("quay_ext") else 0.0)
		var zid := _berth_zone(bi)
		while x < x1 - 0.1:
			var q := Assets.instance("quay")
			q.position = Vector3(x + 6.0, 0, Layout.QUAY_Z)
			_add(q, 2 if (bi == 0 and x >= -12.1) else zid)
			x += 12.0
		_foam_strip(float(b.x0), x1, Layout.SEA_EDGE_Z)
		x_end = maxf(x_end, x1)
	# musoirs et quais de liaison jusqu'au bord des terres **existantes** (revue C7 A4 : au palier 3, tant que le terre-plein
	# n'est pas comblé, la côte s'arrête en x = 48 — plus de musoirs posés sur l'eau)
	var lx: Array = Layout.LAND_X[clampi(sim.tier, 1, 3)]
	var land_end := float(lx[1])
	if not Zones.reclaimed(sim):
		land_end = minf(land_end, float(Layout.LAND_X[2][1]))
	var x2 := x_end
	while x2 < land_end - 0.1:
		var qe := Assets.instance("quay_end")
		qe.set_meta("quay_end", true)
		qe.position = Vector3(x2 + 3.0, 0, Layout.QUAY_Z)
		var qez := Zones.zone_at(qe.position)      # musoirs du terre-plein : ils surgissent avec sa zone
		if not qez.is_empty() and String(qez.open) != "start" and _open_ids.has(int(qez.id)):
			_add(qe, int(qez.id))
		else:
			if not qez.is_empty():
				qe.set_meta("zone_id", int(qez.id))      # la suite du terre-plein attend l'asphalte pendant son ouverture
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
		if p.has("not") and _cond_ok(String(p.not)):      # retiré par un bâtiment ou un palier (hangar → halle au T3)
			continue
		var m := String(p.m)
		var sc := float(p.get("s", 1.0))
		if p.has("alt") and not Assets.exists(m):      # modèle pas encore livré : repli
			m = String(p.alt)
			sc = float(p.get("alt_s", 1.0))
		# « neutral » : gris tant que la condition n'est pas remplie (entrepôts du village avant le T3)
		var neutral: bool = p.has("neutral") and not _cond_ok(String(p.neutral))
		var n := Assets.instance(m, _neutral_material() if neutral else null)
		var pp: Array = p.p
		n.position = Vector3(float(pp[0]), float(pp[1]), float(pp[2]))
		if float(pp[1]) >= 0.0:      # posé à terre : relevé sur la butte de la Colline
			n.position.y += Layout.ground_y(Vector2(n.position.x, n.position.z))
		if p.has("on"):          # posé sur le sommet d'un autre modèle (mouette sur le toit du hangar)
			n.position.y += Assets.top_y(String(p.on))
		n.rotation.y = deg_to_rad(float(p.get("ry", 0.0)))
		if sc != 1.0:
			n.scale = Vector3.ONE * sc
			n.set_meta("rest_scale", sc)
		var zid := Zones.zone_for_cond(String(p.cond), n.position)
		_add(n, zid)
		if zid > 0 and (Layout.ZONE_LANDMARKS.get(zid, "") == m or Layout.ZONE_LANDMARKS.get(zid, "") == String(p.m)):
			zone_nodes[zid].landmark = n
		var tag := String(p.get("tag", ""))
		if tag.begins_with("barrier"):
			n.set_meta("lane", "out" if tag == "barrier_out" else "in")
			barriers.append(n)
		elif tag == "pass_light":
			pass_lights.append(n)
	traffic.set_barriers(barriers)
	_build_scatter()
	_build_hedges()
	_build_multi(Layout.quay_props(nb, sim.built.has("quay_ext"), sim.tier, sim.built))
	_build_multi(Layout.street_props(sim.tier, sim.built))
	_build_anchorage()
	_build_channel()
	_build_slipway()
	_build_jetties()
	# personnel : chacun fait l'aller-retour entre deux points (le long du quai, devant la douane, sur le perron)
	traffic.walkers.clear()
	for i in 3:
		var a := Vector3(-33.0 + i * 9.0, 0.8, -4.2)
		_add_walker("docker", a, a + Vector3(5.0, 0, 0), 90.0)
	# pêcheur sur le musoir du vieux port
	_add_walker("docker", Vector3(-46.5, 0.8, -4.5), Vector3(-41.5, 0.8, -4.5), 90.0)
	if sim.built.has("customs1"):
		_add_walker("customs_officer", Layout.CUSTOMS_HUT + Vector3(2.0, 0, -4.6), Layout.CUSTOMS_HUT + Vector3(-3.0, 0, -4.6), 0.0)
	for d in PortSim.DEPTS:
		if sim.managers[d]:
			var a := Layout.manager_pos(d, sim.tier)
			var mg := _add_walker("manager", a, a + Layout.MANAGER_WALK.get(d, Vector3(0, 0, 2)), 0.0)
			mg.scale = Vector3.ONE * 1.25
	_build_stage_props()
	_rebuild_cranes()
	if overtime_on:
		_place_crane_beacons()      # les grues sont recréées : leurs gyrophares aussi
	_build_lots()
	yard.rebuild(sim)
	rig.set_tier_bounds(sim.tier)
	_update_water_land(Zones.reclaimed(sim))
	for id in newly:
		if not opening_queue.has(id):
			opening_queue.append(id)
	_built_once = true


## Zone d'un poste à quai (le quai n°1 fait partie du vieux port, son allongement de la zone « Quai allongé »).
func _berth_zone(bi: int) -> int:
	match bi:
		0:
			return 1
		1:
			return int(Layout.LOTS.berth2.zone)
		2:
			return int(Layout.LOTS.berth3.zone)
		_:
			return int(Layout.LOTS.berth4.zone)


## Hauteurs du terrain : le dessus du continent et les sols des zones passent sous les dalles (routes à y ≈ 0).
const LAND_Y := -0.05
const ZONE_Y := -0.025


## Continent, brise-lames (polygone de repli si le modèle manque), terre-plein (au palier 3, une fois comblé).
func _build_terrain() -> void:
	var cont := Terrain.poly_mesh(Layout.COAST, Terrain.lin("grass"), LAND_Y, 2.4, null)
	static_root.add_child(cont)
	if not Assets.exists("breakwater"):
		static_root.add_child(Terrain.poly_mesh(Layout.BREAKWATER, Terrain.lin("concrete_dark"), 0.2, 1.4, null))
	if Zones.reclaimed(sim):
		var rec := Terrain.poly_mesh(Layout.RECLAIM, Terrain.lin("sand"), LAND_Y, 2.4, Terrain.land_material.duplicate())
		rec.set_meta("reclaim", true)
		_add(rec, int(Layout.LOTS[Layout.RECLAIM_BUILDING].zone))
		zone_nodes[int(Layout.LOTS[Layout.RECLAIM_BUILDING].zone)].reclaim = rec


## Sols des zones (couleur ouverte, gris voilé, contour en pointillés ; doré qui respire pour la zone prochaine).
## Une zone du terre-plein encore en mer : seul son contour est tracé sur l'eau.
func _build_zones() -> void:
	for z in Layout.ZONES:
		var st := Zones.state(sim, z)
		var id := int(z.id)
		var poly := Layout.zone_poly(z)
		if poly.is_empty():
			continue
		var water := bool(z.get("water", false)) or Zones.on_water(sim, z)
		var quay := bool(z.get("quay", false))
		if not water and not quay:
			var col := Terrain.lin(String(z.ground)) if String(z.ground) != "" else Terrain.lin("grass")
			var mat: ShaderMaterial = Terrain.land_material.duplicate() if st == Zones.OPEN else Terrain.gray_material
			if bool(z.get("discreet", false)) and st == Zones.GRAY:
				# lot D : zone grise « discrète » (pôle nautique sur le cap, dans le cadrage du tutoriel) : l'herbe du cap, sans voile
				col = Terrain.lin("grass")
				mat = Terrain.land_material.duplicate()
			var bh := float(Layout.BUTTE.h) if id == int(Layout.BUTTE.zone) else 0.0      # le pôle nautique est une butte
			var fl := Terrain.poly_mesh(poly, col, ZONE_Y + bh, bh, mat)
			fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_add(fl, id)
			zone_nodes[id].floor = fl
			if st != Zones.OPEN:
				fl.set_meta("zone_id", id)
		if st == Zones.OPEN:
			continue
		var y := (Layout.WATER_Y + 0.14) if water else (0.86 if quay else 0.05 + Layout.ground_y(Layout.poly_rect(poly).get_center()))
		var dm := dash_gold if st == Zones.NEXT else dash_white
		if bool(z.get("water", false)):
			# chenal à venir : des bouées fantômes (translucides, dorées s'il est le prochain achat) à la place des pointillés
			# (une sur deux, bleu-gris translucide, réduites : discrètes, revue N6)
			var cb := Layout.channel_buoys()
			for bi in cb.size():
				if (bi / 2) % 2 == 1:      # une paire (rouge, verte) sur deux
					continue
				var gb := Assets.instance("buoy", dm if st == Zones.NEXT else ghost_buoy_mat)
				gb.position = cb[bi].p
				gb.scale = Vector3.ONE * Layout.GHOST_BUOY_SCALE
				gb.set_meta("zone_id", id)
				static_root.add_child(gb)
		else:
			if bool(z.get("discreet", false)) and st == Zones.GRAY:
				dm = dash_faint
			var dsh := Terrain.dashes(poly, y, 1.2 if st == Zones.NEXT else 0.7, 3.0 if st == Zones.NEXT else 2.5, 1.6, dm)
			dsh.set_meta("zone_id", id)
			static_root.add_child(dsh)
		if st == Zones.NEXT:
			var sm := "zone_sign"
			var sp: Vector3 = z.sign
			if Assets.exists(sm):
				sign_node = Assets.instance(sm)
				sign_node.position = Vector3(sp.x, maxf(sp.y, 0.0) + Layout.ground_y(Vector2(sp.x, sp.z)) if not water else Layout.WATER_Y + 0.2, sp.z)
				sign_node.rotation.y = deg_to_rad(45.0)       # face vierge tournée vers la caméra
				static_root.add_child(sign_node)
			else:
				sign_node = Node3D.new()
				sign_node.position = sp
				static_root.add_child(sign_node)


## Empreintes des bâtiments futurs, chacune dans sa case, **seulement dans les zones ouvertes et la zone prochaine**
## (le reste de la carte n'est pas un « chantier de pointillés ») ; celle du prochain achat est dorée (sa pancarte est
## dessinée par la surcouche). Une case à flot (ponton, remorqueur) n'a que son contour. Rien sur l'eau du futur
## terre-plein (le contour de la zone suffit) ni dans le chenal.
func _build_lots() -> void:
	next_lot = Zones.next_building(sim)
	var first := Zones.first_unbuilt(sim)
	for bid in Layout.LOTS:
		if sim.built.has(bid) or not Zones.lot_shown(sim, bid):
			continue
		var l: Dictionary = Layout.LOTS[bid]
		var p: Vector3 = l.p
		if bool(l.get("water", false)):
			var r := Layout.lot_rect(bid)
			var outline := Terrain.dashes([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)],
				Layout.WATER_Y + 0.14, 0.8 if bid == first else 0.5, 1.4, 0.9, dash_gold if bid == first else dash_white)
			outline.set_meta("lot", bid)
			outline.set_meta("zone_id", int(l.zone))
			static_root.add_child(outline)
			continue
		var g := Assets.instance("ghost_lot", ghost_next_mat if bid == first else ghost_mat)
		var y := 0.04
		if l.has("on"):
			y = 0.84
		g.position = Vector3(p.x, y + Layout.ground_y(Vector2(p.x, p.z)), p.z)
		g.rotation.y = deg_to_rad(float(l.ry))
		g.scale = Vector3(float(l.fp[0]) / 6.0, 1.0, float(l.fp[1]) / 6.0)
		g.set_meta("lot", bid)
		g.set_meta("zone_id", int(l.zone))
		static_root.add_child(g)
		# liseré de l'empreinte (revue N14) : on lit la case même sur un sol clair ; doré pour le prochain achat
		var lr := Layout.lot_rect(bid)
		var edge := Terrain.dashes([lr.position, Vector2(lr.end.x, lr.position.y), lr.end, Vector2(lr.position.x, lr.end.y)],
			g.position.y + 0.03, 0.45, 1.6, 0.8, dash_gold if bid == first else dash_white)
		edge.set_meta("lot", bid)
		edge.set_meta("zone_id", int(l.zone))
		static_root.add_child(edge)


## Mouillage : une bouée numérotée par place en rade (une de plus tous les 10 niveaux de Capitainerie).
## Les bouées de mouillage sont **jaunes** (marque spéciale, croix jaune au sommet) : le rouge et le vert restent au
## balisage du chenal et de la passe (revue du 13/10).
func _build_anchorage() -> void:
	for k in sim.rade_places():
		var b := _special_buoy()
		b.position = anchor_buoy(k)
		static_root.add_child(b)


static var _buoy_mat: StandardMaterial3D
static var _buoy_body: CylinderMesh       # maillages partagés par toutes les bouées de mouillage (revue C7 D)
static var _buoy_bar: BoxMesh


## Bouée de marque spéciale (jaune, voyant en croix) construite dans Godot (pas de modèle Blender dédié).
static func _special_buoy() -> Node3D:
	if _buoy_mat == null:
		_buoy_mat = StandardMaterial3D.new()
		_buoy_mat.albedo_color = Assets.color("mark_yellow")
		_buoy_mat.roughness = 1.0
		_buoy_mat.metallic_specular = 0.0
		_buoy_body = CylinderMesh.new()
		_buoy_body.top_radius = 0.45
		_buoy_body.bottom_radius = 0.85
		_buoy_body.height = 1.9
		_buoy_body.radial_segments = 10
		_buoy_bar = BoxMesh.new()
		_buoy_bar.size = Vector3(1.0, 0.18, 0.18)
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = _buoy_body
	body.position.y = 0.95
	body.material_override = _buoy_mat
	root.add_child(body)
	for a in [45.0, -45.0]:
		var bar := MeshInstance3D.new()
		bar.mesh = _buoy_bar
		bar.position.y = 2.3
		bar.rotation = Vector3(0, 0, deg_to_rad(a))
		bar.material_override = _buoy_mat
		root.add_child(bar)
	root.set_meta("special_buoy", true)
	return root


## Bouée d'une place de mouillage (au flanc sud du navire, pas sous sa coque).
static func anchor_buoy(k: int) -> Vector3:
	return Layout.anchor_pos(k) + Vector3(0, Layout.WATER_Y, 7.5)


## Chenal dragué : bouées rouges à bâbord (est) et vertes à tribord (ouest) en entrant.
func _build_channel() -> void:
	if not sim.built.has("dredge1"):
		return
	for bp in Layout.channel_buoys():
		var n := Assets.instance("buoy" if bool(bp.red) else "buoy_green")
		n.position = bp.p
		_add(n, 5)


static var _concrete_mat: StandardMaterial3D


## Béton des ouvrages construits dans Godot (cale de halage, appontements).
static func _concrete() -> StandardMaterial3D:
	if _concrete_mat == null:
		_concrete_mat = StandardMaterial3D.new()
		_concrete_mat.albedo_color = Assets.color("concrete") if Assets.color("concrete") != Color("#ff00ff") else Color(0.78, 0.77, 0.74)
		_concrete_mat.roughness = 1.0
		_concrete_mat.metallic_specular = 0.0
	return _concrete_mat


## Cale de halage de l'atelier de réparation (Layout.SLIPWAY, lot D) : une rampe de béton de la butte du pôle nautique
## jusque sous l'eau de la crique, un bateau hissé dessus.
func _build_slipway() -> void:
	var sw: Dictionary = Layout.SLIPWAY
	if not _cond_ok(String(sw.cond)):
		return
	var a: Vector3 = sw.from
	var b: Vector3 = sw.to
	var ramp := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var flat := Vector2(b.x - a.x, b.z - a.z).length()
	bm.size = Vector3(Vector2(flat, b.y - a.y).length(), 0.35, float(sw.w))
	ramp.mesh = bm
	ramp.material_override = _concrete()
	ramp.position = (a + b) * 0.5 + Vector3(0, -0.17, 0)
	ramp.rotation = Vector3(0, -atan2(b.z - a.z, b.x - a.x), atan2(b.y - a.y, flat))
	ramp.set_meta("slipway", true)
	_add(ramp, int(Layout.LOTS[String(sw.cond)].zone))
	# bateau en réparation, à mi-pente, étrave vers l'atelier
	if Assets.exists("fishing_boat"):
		var boat := Assets.instance("fishing_boat")
		var t := 0.55
		boat.position = a.lerp(b, t) + Vector3(0, 0.15, 0)
		boat.rotation = Vector3(0, atan2(-(a.z - b.z), a.x - b.x), atan2(a.y - b.y, flat))
		_add(boat, int(Layout.LOTS[String(sw.cond)].zone))


## Appontements (Layout.JETTIES) : dalle de béton sur pieux au niveau des quais.
func _build_jetties() -> void:
	for j in Layout.JETTIES:
		if not _cond_ok(String(j.cond)):
			continue
		var c: Vector2 = j.c
		var sz: Vector2 = j.size
		var deck := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(sz.x, 0.5, sz.y)
		deck.mesh = bm
		deck.material_override = _concrete()
		deck.position = Vector3(c.x, -0.25, c.y)
		deck.set_meta("jetty", true)
		var zid := Zones.zone_for_cond(String(j.cond), deck.position)
		_add(deck, zid)
		var pile := CylinderMesh.new()
		pile.top_radius = 0.25
		pile.bottom_radius = 0.25
		pile.height = 2.4
		for k in 4:
			var p := MeshInstance3D.new()
			p.mesh = pile
			p.material_override = _concrete()
			p.position = Vector3(c.x - sz.x * 0.5 + 1.0 + k * (sz.x - 2.0) / 3.0, -1.6, c.y + sz.y * 0.5 - 0.3)
			_add(p, zid)


## Personnage qui marche entre a et b (demi-tour instantané, léger balancement) ; ry = orientation au repos.
func _add_walker(model: String, a: Vector3, b: Vector3, ry: float) -> Node3D:
	a.y += Layout.ground_y(Vector2(a.x, a.z))      # sur la butte de la Colline (responsable de la tour)
	b.y += Layout.ground_y(Vector2(b.x, b.z))
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


static var _hedge_mat: StandardMaterial3D


## Haies entre les quartiers (Layout.HEDGES) : des pavés vert sombre le long de chaque polyligne, posés sur le sol (butte
## comprise). Construites dans Godot (pas de modèle) ; une haie conditionnée par un bâtiment suit sa zone à l'ouverture.
func _build_hedges() -> void:
	if _hedge_mat == null:
		_hedge_mat = StandardMaterial3D.new()
		_hedge_mat.albedo_color = Assets.color("net_green")
		_hedge_mat.roughness = 1.0
		_hedge_mat.metallic_specular = 0.0
	for h in Layout.HEDGES:
		if not _cond_ok(String(h.cond)):
			continue
		var pts: Array = h.pts
		var zid := Zones.zone_for_cond(String(h.cond), Vector3.ZERO) if String(h.cond) != "" else 0
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var m := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(a.distance_to(b) + float(Layout.HEDGE_SIZE[0]), float(Layout.HEDGE_SIZE[1]), float(Layout.HEDGE_SIZE[0]))
			m.mesh = bm
			m.material_override = _hedge_mat
			var c := (a + b) * 0.5
			m.position = Vector3(c.x, float(Layout.HEDGE_SIZE[1]) * 0.5 + Layout.ground_y(c), c.y)
			m.rotation.y = -atan2(b.y - a.y, b.x - a.x)
			m.set_meta("hedge", true)
			if zid > 0 and _open_ids.has(zid):
				_add(m, zid)
				m.set_meta("tiles", true)
			else:
				static_root.add_child(m)


## Arbres, buissons et rochers de l'arrière-pays : un MultiMesh par modèle.
func _build_scatter() -> void:
	_build_multi(Layout.scatter(), false)


## Liste [{m, p, ry, s, on?}] → un MultiMesh par modèle. Un modèle absent (pas encore livré) est simplement ignoré.
## Les éléments posés dans une zone qui s'ouvre par un bâtiment (bollards du terre-plein, marquages de parc…) forment un
## MultiMesh à part rangé dans la zone : à son ouverture, ils n'apparaissent qu'après le chantier, avec les dalles.
func _build_multi(items: Array, zoned: bool = true) -> void:
	var by_model := {}
	for it in items:
		var zk := 0
		if zoned:
			var zz := Layout.zone_by_id(int(it.zone)) if it.has("zone") else Zones.zone_at(it.p)      # « zone » : forcée (brise-lames est)
			if not zz.is_empty() and String(zz.open) != "start" and _open_ids.has(int(zz.id)):
				zk = int(zz.id)
		var key := "%d|%s" % [zk, String(it.m)]
		if not by_model.has(key):
			by_model[key] = []
		by_model[key].append(it)
	for key in by_model:
		var parts := String(key).split("|")
		var arr: Array = by_model[key]
		var mesh := Assets.mesh(parts[1])
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
		mi.material_override = _degreen_material() if Layout.DEGREEN_MODELS.has(parts[1]) else Assets.vcol_material
		if int(parts[0]) > 0:
			_add(mi, int(parts[0]))
			mi.set_meta("tiles", true)
		else:
			static_root.add_child(mi)


## Abscisse de la grue ci du poste bi : cases fixes pour le quai n°1 (Layout.CRANE_SLOTS), réparties ailleurs.
static func crane_x(bi: int, ci: int, n: int) -> float:
	var slots: Array = Layout.CRANE_SLOTS.get(bi, [])
	if ci < slots.size() and n <= slots.size():
		return float(slots[ci])
	var b: Dictionary = Layout.BERTHS[mini(bi, Layout.BERTHS.size() - 1)]
	return float(b.x0) + (float(b.x1) - float(b.x0)) * (float(ci) + 0.5) / float(n)


func _rebuild_cranes() -> void:
	for c in crane_views:
		c.queue_free()
	crane_views.clear()
	for bi in sim.berths.size():
		var cr: Array = sim.berths[bi].cranes
		var n := cr.size()
		for ci in n:
			var cv := CraneView.new()
			cranes_root.add_child(cv)
			var kind := String(cr[ci].kind)
			cv.setup(kind, bi)
			cv.dropped.connect(_on_crane_drop)
			cv.position = Vector3(crane_x(bi, ci, n), 0, Layout.QUAY_Z if kind == "sts" else -1.6)
			crane_views.append(cv)
			var zid := _berth_zone(bi)
			if bi == 0 and cv.position.x > -12.0:
				zid = 2
			if zone_nodes.has(zid):
				(zone_nodes[zid].nodes as Array).append(cv)
				if kind == "sts" or zone_nodes[zid].landmark == null:
					zone_nodes[zid].landmark = cv


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


## Petit nuage de poussière (apparition d'un élément de palier, d'un bâtiment à l'ouverture d'une zone).
func _dust(pos: Vector3, amount: int = 18, col: Color = Color(0.93, 0.88, 0.78)) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.9
	p.mesh = SphereMesh.new()
	(p.mesh as SphereMesh).radius = 0.35
	(p.mesh as SphereMesh).height = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b, 0.8)
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
	return "%d|%s|%s|%d|%s|%d" % [sim.tier, ",".join(sim.built), str(sim.managers.values()), sim.berths.size(), st, sim.rade_places()]


# ---------------------------------------------------------------------------
# Séquence d'ouverture d'une zone (3 à 5 s, passable d'un toucher, en pause quand un écran couvre le monde)
# ---------------------------------------------------------------------------

## Lance la prochaine ouverture en attente (une à la fois).
## Toutes les zones : chantier (cônes et poussière), pointillés qui s'effacent, vague de couleur, dalles et bâtiments qui
## surgissent, repère vertical en dernier. Terre-plein : des barges arrivent du large et déversent le sable, la bande de
## sable avance d'ouest en est, puis l'asphalte, puis les quais et les portiques. Timings : Layout.OPENING / OPENING_RECLAIM.
func _start_opening(zid: int) -> void:
	var z := Layout.zone_by_id(zid)
	if z.is_empty():
		return
	var reclaim: bool = bool(z.get("reclaim", false)) and zone_nodes.has(zid) and (zone_nodes[zid] as Dictionary).has("reclaim")
	var T: Dictionary = Layout.OPENING_RECLAIM if reclaim else Layout.OPENING
	var f := Zones.focus(z)
	# vue à retrouver à la fin : celle du joueur, même si un recentrage provisoire (chapitre d'un service) est en cours
	var home := rig.goal if view_home == Vector3.INF else view_home
	view_home = Vector3.INF
	opening = {"id": zid, "t": 0.0, "T": T, "reclaim": reclaim, "prev_goal": home, "prev_zoom": rig.zoom_goal,
		"popped": 0, "landmark_done": false, "barges": [], "dash": null, "center": f.center, "props": [], "late": [],
		"next_puff": 0.0, "tiles_on": false}
	if not rig.locked:
		rig.focus(f.p)
		rig.zoom_goal = float(f.zoom)
	var info: Dictionary = zone_nodes.get(zid, {"floor": null, "nodes": [], "landmark": null})
	# état « avant » : sol gris (terre-plein : pas encore de sol), bâtiments et dalles cachés, pointillés dorés qui vont s'effacer
	var fl: MeshInstance3D = info.floor
	if fl != null and fl.material_override is ShaderMaterial:
		var m := fl.material_override as ShaderMaterial
		m.set_shader_parameter("wave_center", Vector2(f.center.x, f.center.z))
		m.set_shader_parameter("wave_r", 0.0)
		if reclaim:
			m.set_shader_parameter("reveal_from", Layout.RECLAIM_FROM)
			m.set_shader_parameter("reveal_r", 0.0)
		else:
			m.set_shader_parameter("wave_desat", Terrain.ZONE_DESAT)
			m.set_shader_parameter("veil", Terrain.ZONE_VEIL)
	var poly := Layout.zone_poly(z)
	var water := bool(z.get("water", false))
	if not poly.is_empty():
		var dm := dash_gold.duplicate() as StandardMaterial3D
		var dsh := Terrain.dashes(poly, Layout.WATER_Y + 0.14 if (water or reclaim) else 0.05, 1.2, 3.0, 1.6, dm)
		add_child(dsh)
		opening.dash = dsh
	var hidden: Array[Node3D] = []
	for n in info.nodes:
		if not is_instance_valid(n) or n == fl or (n as Node3D).has_meta("reclaim"):
			continue
		if (n as Node3D).has_meta("tiles"):
			(n as Node3D).visible = false      # dalles : elles apparaissent d'un coup après le chantier
			(opening.late as Array).append(n)
			continue
		(n as Node3D).scale = Vector3.ONE * 0.01
		hidden.append(n)
	opening.nodes = hidden
	opening.landmark = info.landmark if info.landmark != null and hidden.has(info.landmark) else (hidden.back() if not hidden.is_empty() else null)
	# chantier : quelques cônes aux coins de la zone, retirés à la fin (zones à terre seulement)
	if not water and not reclaim and poly.size() >= 3 and Assets.exists("cone"):
		var c2 := Vector2(f.center.x, f.center.z)
		var nc := mini(4, poly.size())
		for i in nc:
			var v: Vector2 = poly[i * poly.size() / nc]
			var p := v.lerp(c2, 0.18)
			var cone := Assets.instance("cone")
			cone.position = Vector3(p.x, 0.05, p.y)
			add_child(cone)
			(opening.props as Array).append(cone)
	if reclaim:
		var rec: MeshInstance3D = info.reclaim
		var rm := rec.material_override as ShaderMaterial
		rm.set_shader_parameter("reveal_from", Layout.RECLAIM_FROM)
		rm.set_shader_parameter("reveal_r", 0.0)
		# ce qui est posé sur la suite du terre-plein (sols gris, pointillés, empreintes, pancarte) attend l'asphalte
		for n in static_root.get_children():
			var nz := int((n as Node).get_meta("zone_id", 0))
			if nz > 0 and bool(Layout.zone_by_id(nz).get("reclaim", false)) and (n as Node3D).visible and n != fl and not (info.nodes as Array).has(n):
				(n as Node3D).visible = false
				(opening.late as Array).append(n)
		# barges chargées de sable qui arrivent de l'est, le long du futur bord du quai (repli : remorqueurs chargés si le
		# modèle n'est pas livré) ; ni sur le mouillage ni sur la voie de départ (revue C7 C4)
		for i in Layout.RECLAIM_BARGES.size():
			var bname := "barge_sand" if Assets.exists("barge_sand") else "tug"
			var bg := Assets.instance(bname)
			bg.position = Vector3(float(Layout.RECLAIM_BARGE_X0[i]), Layout.WATER_Y, Layout.RECLAIM_BARGE_LANE_Z)
			bg.rotation.y = PI          # étrave vers l'ouest
			if bname == "tug":
				var load_box := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(4.0, 1.4, 2.6)
				load_box.mesh = bm
				var sm := StandardMaterial3D.new()
				sm.albedo_color = Assets.color("sand")
				load_box.material_override = sm
				load_box.position = Vector3(-1.0, 2.0, 0)
				load_box.name = "sand"
				bg.add_child(load_box)
			add_child(bg)
			(opening.barges as Array).append(bg)
	Sfx.play("bell", 0.2)


## Fenêtre [début, fin] d'une phase de la séquence : avancement 0–1.
static func _phase(T: Dictionary, key: String, t: float) -> float:
	var w: Array = T.get(key, [0.0, 0.0])
	if float(w[1]) <= float(w[0]):
		return 1.0 if t >= float(w[0]) else 0.0
	return clampf((t - float(w[0])) / (float(w[1]) - float(w[0])), 0.0, 1.0)


func _process_opening(delta: float) -> void:
	if opening.is_empty():
		if not opening_queue.is_empty() and not fx_paused:
			_start_opening(opening_queue.pop_front())
		return
	if fx_paused:
		return
	opening.t = float(opening.t) + delta
	var t: float = opening.t
	var T: Dictionary = opening.T
	var zid: int = opening.id
	var info: Dictionary = zone_nodes.get(zid, {"floor": null})
	var z := Layout.zone_by_id(zid)
	# pointillés qui s'effacent
	if opening.dash != null and is_instance_valid(opening.dash):
		var dm := (opening.dash as MeshInstance3D).material_override as StandardMaterial3D
		dm.albedo_color.a = clampf(1.0 - t / float(T.dash_fade), 0.0, 1.0)
	# chantier : nuages de poussière au hasard dans la zone
	var wk: Array = T.get("works", [0.0, 0.0])
	if t >= float(wk[0]) and t < float(wk[1]) and t >= float(opening.next_puff):
		opening.next_puff = t + 0.22
		var poly := Layout.zone_poly(z)
		if poly.size() >= 3:
			var r := Layout.poly_rect(poly)
			for _try in 6:
				var p := Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))
				if Geometry2D.is_point_in_polygon(p, PackedVector2Array(poly)):
					_dust(Vector3(p.x, 0.0, p.y), 14)
					break
	if bool(opening.reclaim):
		# barges : arrivée, déversement (le sable baisse, des nuages de sable), retour au large ; la bande de sable avance,
		# puis l'asphalte
		var kin := smoothstep(0.0, 1.0, _phase(T, "barge_in", t))
		var kout := smoothstep(0.0, 1.0, _phase(T, "barge_out", t))
		var pour := _phase(T, "pour", t)
		var bi := 0
		for bg in opening.barges:
			if not is_instance_valid(bg):
				bi += 1
				continue
			var b: Node3D = bg
			var x0: float = float(Layout.RECLAIM_BARGE_X0[bi])
			var x1: float = float(Layout.RECLAIM_BARGES[bi])
			b.position.x = lerpf(lerpf(x0, x1, kin), x0, kout)
			var sand := Assets.part(b, "sand")
			if sand != null:
				sand.scale.y = clampf(1.0 - pour, 0.02, 1.0)
			if pour > 0.0 and pour < 1.0 and fmod(t + bi * 0.1, 0.3) < delta:
				_dust(b.position + Vector3(0, 1.2, 4.0), 10, Assets.color("sand"))
			bi += 1
		var rec_v: Variant = info.get("reclaim")
		if rec_v != null and is_instance_valid(rec_v):
			var rec: MeshInstance3D = rec_v
			(rec.material_override as ShaderMaterial).set_shader_parameter("reveal_r", _phase(T, "sand", t) * Layout.RECLAIM_REVEAL_R)
		var fl2_v: Variant = info.get("floor")
		if fl2_v != null and is_instance_valid(fl2_v) and (fl2_v as MeshInstance3D).material_override is ShaderMaterial:
			var fl2: MeshInstance3D = fl2_v
			(fl2.material_override as ShaderMaterial).set_shader_parameter("reveal_r", _phase(T, "asphalt", t) * Layout.RECLAIM_REVEAL_R)
	else:
		# vague de couleur sur le sol de la zone
		var fl_v: Variant = info.get("floor")
		if fl_v != null and is_instance_valid(fl_v) and (fl_v as MeshInstance3D).material_override is ShaderMaterial:
			var fl: MeshInstance3D = fl_v
			var w := clampf((t - float(T.wave_start)) / float(T.wave), 0.0, 1.0)
			(fl.material_override as ShaderMaterial).set_shader_parameter("wave_r", w * 90.0)
	# dalles (et, pour le terre-plein, ce qui est posé sur sa suite) : après le chantier
	if not bool(opening.tiles_on) and t >= float(T.tiles):
		opening.tiles_on = true
		for n in opening.late:
			if is_instance_valid(n):
				(n as Node3D).visible = true
	# les bâtiments surgissent l'un après l'autre, le repère vertical en dernier
	var nodes: Array = opening.nodes
	var others: Array = nodes.filter(func(n: Variant) -> bool: return n != opening.landmark)
	var due := 0
	if t >= float(T.pop_start):
		due = mini(others.size(), 1 + floori((t - float(T.pop_start)) / maxf(0.05, float(T.pop) / maxf(1.0, float(others.size())))))
	while int(opening.popped) < due:
		var nv: Variant = others[int(opening.popped)]
		opening.popped = int(opening.popped) + 1
		if is_instance_valid(nv):      # (revue C7 B1 : jamais d'affectation typée d'un nœud libéré)
			var n: Node3D = nv
			n.create_tween().tween_property(n, "scale", _rest_scale(n), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if int(opening.popped) % 2 == 1:
				_dust(n.global_position)
	if not bool(opening.landmark_done) and t >= float(T.landmark):
		opening.landmark_done = true
		var lm_v: Variant = opening.landmark
		if lm_v != null and is_instance_valid(lm_v):
			var lm: Node3D = lm_v
			lm.create_tween().tween_property(lm, "scale", _rest_scale(lm), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_dust(lm.global_position, 30)
		rig.shake(0.5)
		Sfx.play("ship_horn", 0.5)
		if OS.has_feature("mobile"):
			Input.vibrate_handheld(80)
		zone_opened.emit(zid)
	if t >= float(T.back) and not bool(opening.get("returned", false)):
		opening.returned = true
		if not rig.locked:
			rig.focus(opening.prev_goal)
			rig.zoom_goal = float(opening.prev_zoom)
	if t >= float(T.total):
		_finish_opening(false)


## Échelle de repos d'un nœud qui surgit (les barrières de la 2e voie sont réduites, voir PROPS « s »).
func _rest_scale(n: Node3D) -> Vector3:
	return Vector3.ONE * float(n.get_meta("rest_scale", 1.0))


## Termine la séquence (fin normale, toucher, ou nouvelle partie) : tout prend son état final.
func _finish_opening(silent: bool) -> void:
	if opening.is_empty():
		return
	var zid: int = opening.id
	var info: Dictionary = zone_nodes.get(zid, {})
	for n in opening.get("nodes", []):
		if is_instance_valid(n):
			(n as Node3D).scale = _rest_scale(n)
	for n in opening.get("late", []):
		if is_instance_valid(n):
			(n as Node3D).visible = true
	var fl_v: Variant = info.get("floor")
	if fl_v != null and is_instance_valid(fl_v) and (fl_v as MeshInstance3D).material_override is ShaderMaterial:
		var fm := (fl_v as MeshInstance3D).material_override as ShaderMaterial
		fm.set_shader_parameter("wave_desat", 0.0)
		fm.set_shader_parameter("wave_r", 1e6)
		fm.set_shader_parameter("reveal_r", 1e6)
	var rec_v: Variant = info.get("reclaim")
	if rec_v != null and is_instance_valid(rec_v):
		((rec_v as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("reveal_r", 1e6)
	for k in ["barges", "props"]:
		for bg in opening.get(k, []):
			if is_instance_valid(bg):
				(bg as Node).queue_free()
	if opening.get("dash") != null and is_instance_valid(opening.dash):
		(opening.dash as Node).queue_free()
	if not silent:
		if not bool(opening.landmark_done):
			zone_opened.emit(zid)
		if not bool(opening.get("returned", false)) and not rig.locked:
			rig.focus(opening.prev_goal)
			rig.zoom_goal = float(opening.prev_zoom)
		openings_done += 1
	opening = {}


## Toucher pendant une séquence : on la passe — mais seulement après Layout.OPENING_SKIP_AFTER s (revue N12 : un toucher
## lancé avant l'ouverture ne l'escamote pas).
func skip_opening() -> bool:
	if opening.is_empty():
		return false
	if not opening_skippable():
		return true          # le toucher est absorbé (rien d'autre ne se déclenche pendant l'ouverture)
	_finish_opening(false)
	return true


func opening_skippable() -> bool:
	return not opening.is_empty() and float(opening.get("t", 0.0)) >= Layout.OPENING_SKIP_AFTER


func opening_active() -> bool:
	return not opening.is_empty()


# ---------------------------------------------------------------------------
# Signaux
# ---------------------------------------------------------------------------

func _on_ship_spawned(s: Ship) -> void:
	if s.state == Ship.State.ARRIVING:
		Sfx.play("ship_horn", 5.0)
	if s.evp_left() >= s.evp_total - 0.001:
		_ship_cargo0[s.id] = s.left.duplicate()     # cargaison complète à l'arrivée (estimation de ship_paid)
	var v := ShipView.new()
	ships_root.add_child(v)
	v.setup(s, sim)
	ship_views[s.id] = v
	v.place(s, sim)      # à sa place logique sur le trajet de son état (chargement : revue C7 A6)


## Navire retiré de la simulation : s'il partait encore à l'écran (retenu, en retard), sa vue finit son trajet jusqu'à la
## sortie avant d'être libérée (revue C7 A1).
func _on_ship_removed(s: Ship) -> void:
	if ship_views.has(s.id):
		var v: ShipView = ship_views[s.id]
		ship_views.erase(s.id)
		if (s.state == Ship.State.DEPARTING or s.state == Ship.State.LEAVING) and v.is_moving():
			parting.append(v)
		else:
			v.queue_free()


## Changement d'état d'un navire : à la fin du déchargement (départ du poste), ship_paid avec le montant estimé.
func _on_ship_state(s: Ship) -> void:
	if s.state != Ship.State.DEPARTING or s.berth < 0:
		return
	var p := Vector3(Layout.berth_center(s.berth), 0.0, Layout.SEA_EDGE_Z - 6.0)
	var v: ShipView = ship_views.get(s.id)
	if v != null:
		p = v.position
	var amount := ship_amount(s)
	_ship_cargo0.erase(s.id)
	ships_paid += 1
	ship_paid.emit(p + Vector3(0, 6.0, 0), amount)


## Montant estimé d'une escale (voir ship_paid) : manutention de la cargaison relevée à l'arrivée (à défaut : EVP du navire
## × valeur moyenne) + droits de port et services. Lecture seule de la simulation.
func ship_amount(s: Ship) -> float:
	if sim == null or not sim.db.owner_by_id.has(s.owner) or not sim.db.ship_by_id.has(s.cls):
		return 0.0
	var pay := float(sim.db.owner_by_id[s.owner].pay)
	var handling := 0.0
	if _ship_cargo0.has(s.id):
		var c0: PackedFloat64Array = _ship_cargo0[s.id]
		for c in mini(c0.size(), PortSim.NCARGO):
			handling += c0[c] * sim.stat("value", c) * pay
	else:
		handling = s.evp_total * sim.avg_value_per_evp() * pay
	var dues := float(sim.db.ship_by_id[s.cls].dues) * float(sim.db.tier_def(sim.tier).get("dues_mult", 1.0)) * sim.tariff \
		* pay * sim.renown_mult()
	return handling + dues * (1.0 + sim.ship_fee)


func _on_crane_drop() -> void:
	Sfx.play("clank", 0.3)


func _on_purchased(kind: String, _id: String) -> void:
	# la signature (palier, bâtiments, responsables) déclenche la reconstruction ; retour tactile court sur mobile
	if OS.has_feature("mobile") and kind != "licence":
		Input.vibrate_handheld(30)


func _on_tier_changed(_t: int) -> void:
	pass


func _on_truck_served(_w: float) -> void:
	traffic.on_truck_served(sim)


# ---------------------------------------------------------------------------
# Interface publique pour l'interface (lot D) : retours d'achat, Heures sup, campagne, ancrages de caméra et de bulles.
# Sans effet (et sans erreur) si rien n'est à montrer ; aucune ne touche la simulation.
# ---------------------------------------------------------------------------

## Effet visible dans le monde quand le joueur achète un niveau du service `dept_id` (PortSim.DEPTS) : poussière et
## étincelles sur le poste du service ; grues : « kick » et accélération brève ; parc : les engins tressaillent ;
## gate : les barrières se lèvent ; capitainerie : coup de corne du pilote.
func feedback_purchase(dept_id: String) -> void:
	if sim == null or not PortSim.DEPTS.has(dept_id):
		return
	purchase_feedbacks += 1
	var p := dept_anchor(dept_id)
	_dust(p, 16)
	_sparks(p + Vector3(0, 2.0, 0))
	match dept_id:
		"cranes", "berths":
			_crane_rush = 2.5
			for cv in crane_views:
				cv.kick()
		"yard_ops":
			traffic.kick_vehicles()
		"gate":
			traffic.kick_barriers()
		"harbor":
			Sfx.play("ship_horn", 0.4)


## Heures sup ×2 visibles dans le monde : gyrophares sur les grues et les engins, grues plus rapides, lumière plus chaude.
func set_overtime(on: bool) -> void:
	if on == overtime_on:
		return
	overtime_on = on
	_apply_overtime()


## Campagne de démarchage en cours : pavillons et guirlandes sur la capitainerie.
func set_campaign(on: bool) -> void:
	if on == campaign_on:
		return
	campaign_on = on
	_apply_campaign()


## Point du monde où cadrer la caméra pour un service (poste du service sur le plan réorganisé, palier courant).
func dept_anchor(dept_id: String) -> Vector3:
	var tier := sim.tier if sim != null else 1
	return Layout.dept_pos(dept_id, tier)


## Point du mouillage où poser la bulle « n/n en rade » : centre des places occupées par des navires en rade (à défaut,
## la place n°1), un peu au-dessus de l'eau.
func rade_anchor() -> Vector3:
	var acc := Vector3.ZERO
	var n := 0
	if sim != null:
		for s in sim.ships:
			if s.state == Ship.State.ANCHORED and s.anchor_slot >= 0:
				acc += Layout.anchor_pos(s.anchor_slot)
				n += 1
	var c := acc / float(n) if n > 0 else Layout.anchor_pos(0)
	return Vector3(c.x, 4.0, c.z)


# ---------------------------------------------------------------------------
# Vie du port (lot D, revue axe 3) : dockers au déchargement et douaniers, en nombre lié aux agents des services
# ---------------------------------------------------------------------------
## Plafond de la foule (mobile) ; échelle des personnages (lisibles au zoom par défaut, 58 u de large) ; marche.
const CROWD_MAX := 28
const CROWD_SCALE := 1.45
const CROWD_SPEED := 1.6          # u/s
const CROWD_TURN := 7.0           # vitesse du demi-tour progressif (1/s)
const CROWD_PAUSE := Vector2(0.5, 1.3)
const CROWD_REFRESH := 0.5        # s entre deux réaffectations
var crowd_mm: MultiMeshInstance3D       # dockers
var crowd_mm2: MultiMeshInstance3D      # douaniers
## Personnages de la foule : {key, kind ("apron" | "deck" | "customs"), berth, ship, k, a, b (repère du navire pour le pont),
## t (0 → 1 vers b), dir, wait, yaw, phase}. Réaffectés toutes les CROWD_REFRESH s ; image par image, seules les
## transformations du MultiMesh sont écrites (aucune allocation).
var crowd: Array[Dictionary] = []
var _crowd_t := 0.0
var _crowd_rng := RandomNumberGenerator.new()


func _build_crowd() -> void:
	var mesh := Assets.mesh("docker")
	if mesh == null:
		return
	crowd_mm = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = CROWD_MAX
	mm.visible_instance_count = 0
	crowd_mm.multimesh = mm
	crowd_mm.material_override = Assets.vcol_material
	add_child(crowd_mm)
	_crowd_rng.seed = 4242
	# douaniers : même foule, modèle « customs_officer » (repli : docker)
	var mesh2 := Assets.mesh("customs_officer")
	crowd_mm2 = MultiMeshInstance3D.new()
	var mm2 := MultiMesh.new()
	mm2.transform_format = MultiMesh.TRANSFORM_3D
	mm2.mesh = mesh2 if mesh2 != null else mesh
	mm2.instance_count = 4
	mm2.visible_instance_count = 0
	crowd_mm2.multimesh = mm2
	crowd_mm2.material_override = Assets.vcol_material
	add_child(crowd_mm2)


## Combien de personnages, et où : par poste dont le navire est à quai (amarrage → déchargement), des dockers sur le
## tablier (1 + agents des Quais, 2 à 5) et, pendant le déchargement, sur le pont (agents des Portiques, 1 à 3) ; des
## douaniers dans l'aire d'inspection (agents de la Douane, 1 à 4) une fois le bureau construit. Plafond : CROWD_MAX.
func crowd_plan() -> Array:
	var out: Array = []
	if sim == null:
		return out
	for bi in sim.berths.size():
		var sid := int(sim.berths[bi].ship)
		var sh: Ship = sim.ship_by_id(sid) if sid >= 0 else null
		if sh == null or sh.state < Ship.State.MOORING or sh.state > Ship.State.UNLOADING:
			continue
		for k in clampi(1 + sim.agents("berths"), 2, 5):
			out.append({"key": "a%d_%d" % [bi, k], "kind": "apron", "berth": bi, "ship": sid, "k": k})
		if sh.state == Ship.State.UNLOADING:
			for k in clampi(sim.agents("cranes"), 1, 3):
				out.append({"key": "d%d_%d" % [bi, k], "kind": "deck", "berth": bi, "ship": sid, "k": k})
	if sim.built.has("customs1"):
		for k in clampi(sim.agents("customs"), 1, 4):
			out.append({"key": "c%d" % k, "kind": "customs", "berth": -1, "ship": -1, "k": k})
	if out.size() > CROWD_MAX:
		out.resize(CROWD_MAX)
	return out


## Réaffecte la foule : garde ceux qui sont déjà là, place les nouveaux sur leur trajet, retire les autres.
func _refresh_crowd() -> void:
	var plan := crowd_plan()
	var keep: Array[Dictionary] = []
	for want in plan:
		var cur: Dictionary = {}
		for c in crowd:
			if String(c.key) == String(want.key) and int(c.ship) == int(want.ship):
				cur = c
				break
		if cur.is_empty():
			cur = want.duplicate()
			_crowd_route(cur)
			cur.t = _crowd_rng.randf()
			cur.dir = 1.0 if _crowd_rng.randf() < 0.5 else -1.0
			cur.wait = _crowd_rng.randf_range(0.0, 0.8)
			var d0: Vector3 = (cur.b as Vector3) - (cur.a as Vector3)
			cur.yaw = atan2(d0.x * float(cur.dir), d0.z * float(cur.dir))
			cur.phase = _crowd_rng.randf() * TAU
		keep.append(cur)
	crowd = keep


## Trajet d'un personnage : tablier (le long du bord du quai, devant le navire), pont (le long du bord côté quai, dans le
## repère du navire), aire d'inspection de la douane.
func _crowd_route(c: Dictionary) -> void:
	var k := int(c.k)
	match String(c.kind):
		"apron":
			var bx := Layout.berth_center(int(c.berth))
			var span := 12.0
			var v: ShipView = ship_views.get(int(c.ship))
			if v != null:
				span = v.length * 0.42
			var x0 := bx - span + float(k) * (2.0 * span) / 5.0 + _crowd_rng.randf_range(0.0, 2.0)
			var z := Layout.SEA_EDGE_Z + 1.2 + float(k % 2) * 0.7
			c.a = Vector3(x0, 0.0, z)
			c.b = Vector3(x0 + _crowd_rng.randf_range(4.0, 7.0), 0.0, z)
		"deck":
			var v2: ShipView = ship_views.get(int(c.ship))
			var hl := 10.0 if v2 == null else v2.length * 0.32
			var hw := 2.5 if v2 == null else maxf(0.8, v2.width * 0.5 - 0.8)
			var lx := -hl + float(k) * hl * 0.8
			c.a = Vector3(lx, 0.0, hw)
			c.b = Vector3(lx + _crowd_rng.randf_range(4.0, 6.5), 0.0, hw)
		_:
			var zc := 31.8 + float(k) * 1.5
			var xa := -40.5 + float(k % 2) * 2.0
			c.a = Vector3(xa, 0.0, zc)
			c.b = Vector3(xa + _crowd_rng.randf_range(5.0, 8.0), 0.0, zc)


## Image par image : chacun marche entre a et b, s'arrête au bout et fait demi-tour progressivement (il tourne pendant sa
## pause au lieu de pivoter d'un coup) ; les transformations vont directement dans le MultiMesh.
func _sync_crowd(delta: float) -> void:
	if crowd_mm == null:
		return
	_crowd_t -= delta
	if _crowd_t <= 0.0:
		_crowd_t = CROWD_REFRESH
		_refresh_crowd()
	var mm := crowd_mm.multimesh
	var n := 0
	var n2 := 0
	for c in crowd:
		if n >= CROWD_MAX:
			break
		var a: Vector3 = c.a
		var b: Vector3 = c.b
		var len := maxf(0.5, a.distance_to(b))
		if not fx_paused:
			if float(c.wait) > 0.0:
				c.wait = float(c.wait) - delta
			else:
				c.t = float(c.t) + float(c.dir) * delta * CROWD_SPEED / len
				if float(c.t) >= 1.0 or float(c.t) <= 0.0:
					c.t = clampf(float(c.t), 0.0, 1.0)
					c.dir = -float(c.dir)
					c.wait = _crowd_rng.randf_range(CROWD_PAUSE.x, CROWD_PAUSE.y)
				c.phase = float(c.phase) + delta * 9.0
			var to := (b - a) * float(c.dir)
			c.yaw = lerp_angle(float(c.yaw), atan2(to.x, to.z), 1.0 - exp(-delta * CROWD_TURN))
		var p := a.lerp(b, float(c.t))
		if float(c.wait) <= 0.0:
			p.y += absf(sin(float(c.phase))) * 0.07
		var xf := Transform3D(Basis(Vector3.UP, float(c.yaw)).scaled(Vector3.ONE * CROWD_SCALE), p)
		match String(c.kind):
			"deck":
				var v: ShipView = ship_views.get(int(c.ship))
				if v == null:
					continue
				xf = v.global_transform * Transform3D(xf.basis, xf.origin + Vector3(0, v.deck_y + 0.05, 0))
			"apron":
				xf.origin.y += 0.8          # sur le dessus du quai
		if String(c.kind) == "customs":
			if n2 < crowd_mm2.multimesh.instance_count:
				crowd_mm2.multimesh.set_instance_transform(n2, xf)
				n2 += 1
			continue
		mm.set_instance_transform(n, xf)
		n += 1
	mm.visible_instance_count = n
	crowd_mm2.multimesh.visible_instance_count = n2


## Étincelles orange (achat d'un niveau) et anneau qui s'élargit au sol : on voit où l'achat agit.
func _sparks(pos: Vector3) -> void:
	_dust(pos, 12, Color(1.0, 0.72, 0.25))
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 2.2
		_ring_mesh.outer_radius = 2.8
		_ring_mesh.rings = 24
		_ring_mesh.ring_segments = 6
	var ring := MeshInstance3D.new()
	ring.mesh = _ring_mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.3, 0.9)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.position = Vector3(pos.x, pos.y - 1.6, pos.z)
	ring.scale = Vector3(0.6, 1.0, 0.6)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(3.2, 1.0, 3.2), 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.7)
	tw.chain().tween_callback(ring.queue_free)


static var _ring_mesh: TorusMesh


# --- Heures sup : gyrophares (grues, engins), grues plus rapides (voir _sync_cranes), lumière plus chaude ---
static var _beacon_mesh: SphereMesh
static var _beacon_mat: StandardMaterial3D
var _beacons: Array[Node3D] = []
var _warm := 0.0                   # 0 → 1 : étalonnage chaud des Heures sup
var _sun_base := Color.WHITE
var _amb_base := Color.WHITE
const OVERTIME_WARM_SUN := Color(1.0, 0.84, 0.66)
const OVERTIME_WARM_AMB := Color(1.0, 0.9, 0.78)


## Gyrophare orange partagé (un maillage, un matériau pour tous : il clignote en une seule écriture par image).
static func beacon_parts() -> Array:
	if _beacon_mesh == null:
		_beacon_mesh = SphereMesh.new()
		_beacon_mesh.radius = 0.38
		_beacon_mesh.height = 0.6
		_beacon_mesh.radial_segments = 8
		_beacon_mesh.rings = 4
		_beacon_mat = StandardMaterial3D.new()
		_beacon_mat.albedo_color = Color(1.0, 0.55, 0.1)
		_beacon_mat.emission_enabled = true
		_beacon_mat.emission = Color(1.0, 0.5, 0.05)
		_beacon_mat.emission_energy_multiplier = 2.0
		_beacon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return [_beacon_mesh, _beacon_mat]


func _apply_overtime() -> void:
	_place_crane_beacons()
	traffic.set_beacons(overtime_on)


## Un gyrophare au sommet de chaque grue (recréés avec les grues).
func _place_crane_beacons() -> void:
	for b in _beacons:
		if is_instance_valid(b):
			b.queue_free()
	_beacons.clear()
	if not overtime_on:
		return
	var parts := beacon_parts()
	for cv in crane_views:
		var bn := MeshInstance3D.new()
		bn.mesh = parts[0]
		bn.material_override = parts[1]
		bn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bn.position = Vector3(0, cv.beacon_y(), 0)
		bn.scale = Vector3.ONE * 1.4
		cv.add_child(bn)
		_beacons.append(bn)


## Clignotement des gyrophares et étalonnage chaud (progressif, seulement quand il change).
func _sync_overtime(delta: float) -> void:
	var goal := 1.0 if overtime_on else 0.0
	if not is_equal_approx(_warm, goal):
		_warm = move_toward(_warm, goal, delta * 1.2)
		sun.light_color = _sun_base.lerp(OVERTIME_WARM_SUN, 0.22 * _warm)
		env.ambient_light_color = _amb_base.lerp(OVERTIME_WARM_AMB, 0.12 * _warm)
	if overtime_on and _beacon_mat != null:
		var on := fmod(_t * 3.2, 1.0) < 0.55
		_beacon_mat.emission_energy_multiplier = 3.2 if on else 0.4
		_beacon_mat.albedo_color = Color(1.0, 0.6, 0.15) if on else Color(0.55, 0.3, 0.1)


# --- Campagne de démarchage : pavillons et guirlande de fanions sur la capitainerie ---
var _flags: Node3D
var flags_shown := 0                # fanions posés (tests)
const FLAG_COLORS := ["box_red", "box_yellow", "box_blue", "box_green", "white"]


func _apply_campaign() -> void:
	if _flags != null and is_instance_valid(_flags):
		_flags.queue_free()
	_flags = null
	flags_shown = 0
	if not campaign_on:
		return
	_flags = Node3D.new()
	add_child(_flags)
	var mats: Array[StandardMaterial3D] = []
	for k in FLAG_COLORS:
		var m := StandardMaterial3D.new()
		m.albedo_color = Assets.color(k)
		m.roughness = 1.0
		mats.append(m)
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.09
	pole_mesh.bottom_radius = 0.12
	pole_mesh.height = 7.0
	var pennant := PrismMesh.new()
	pennant.size = Vector3(0.7, 0.8, 0.05)
	var banner := BoxMesh.new()
	banner.size = Vector3(1.9, 1.15, 0.06)
	var office := Layout.HARBOR_OFFICE
	var ridge := office + Vector3(0, maxf(3.0, Assets.top_y("harbor_office") - 0.4), 0)
	var poles := [office + Vector3(-4.6, 0, -3.8), office + Vector3(4.6, 0, -3.8)]
	for i in poles.size():
		var pp: Vector3 = poles[i]
		var pole := MeshInstance3D.new()
		pole.mesh = pole_mesh
		pole.material_override = mats[4]
		pole.position = pp + Vector3(0, 3.5, 0)
		_flags.add_child(pole)
		var flag := MeshInstance3D.new()
		flag.mesh = banner
		flag.material_override = mats[2 if i == 0 else 0]
		flag.position = pp + Vector3(1.0, 6.3, 0)
		flag.set_meta("flutter", 0.2 + 0.3 * float(i))
		_flags.add_child(flag)
		# guirlande de fanions du faîte du toit au sommet du mât (chaînette)
		var top := pp + Vector3(0, 6.9, 0)
		var n := 9
		for k in n:
			var t := (float(k) + 0.5) / float(n)
			var q := ridge.lerp(top, t) - Vector3(0, sin(t * PI) * 1.1, 0)
			var pf := MeshInstance3D.new()
			pf.mesh = pennant
			pf.material_override = mats[(k + i) % 4]
			pf.position = q - Vector3(0, 0.45, 0)
			pf.rotation = Vector3(0, atan2(-(top.z - ridge.z), top.x - ridge.x), PI)
			pf.set_meta("flutter", float(k) * 0.7)
			_flags.add_child(pf)
			flags_shown += 1
	_dust(office + Vector3(0, 4.0, 0), 14, Color(1.0, 0.85, 0.4))


## Fanions et pavillons qui flottent au vent (quelques nœuds, seulement pendant une campagne).
func _sync_flags() -> void:
	if _flags == null or not is_instance_valid(_flags):
		return
	for c in _flags.get_children():
		if c.has_meta("flutter"):
			(c as Node3D).rotation.x = sin(_t * 4.0 + float(c.get_meta("flutter"))) * 0.25


# ---------------------------------------------------------------------------
# Image par image
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if sim == null:
		return
	_t += delta
	_crane_rush = maxf(0.0, _crane_rush - delta)
	var sig := signature()
	if sig != _sig:
		_sig = sig
		if static_root.get_child_count() > 0:
			rebuild()
	_hold_ships()
	for s in sim.ships:
		var v: ShipView = ship_views.get(s.id)
		if v != null:
			v.sync(s, sim, delta)
	for i in range(parting.size() - 1, -1, -1):
		var pv: ShipView = parting[i]
		if not is_instance_valid(pv) or pv.sync_parting(delta):
			if is_instance_valid(pv):
				pv.queue_free()
			parting.remove_at(i)
	_sync_cranes()
	yard.sync(sim, delta)
	traffic.sync(sim, delta)
	_sync_marker(delta)
	_sync_weather(delta)
	_sync_crowd(delta)
	_sync_overtime(delta)
	_sync_flags()
	traffic.walk_paused = fx_paused
	if not fx_paused and not _pending_pops.is_empty():
		_play_pops()
	_process_opening(delta)
	# la zone prochaine respire : pointillés dorés qui pulsent lentement ; feux de passe qui clignotent
	dash_gold.albedo_color.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 2.2))
	var on := fmod(_t, 2.0) < 0.9
	for l in pass_lights:
		var lamp := Assets.part(l, "lamp")
		if lamp != null:
			lamp.visible = on
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
		# Heures sup et retour d'achat : les grues vont visiblement plus vite (présentation seule)
		if overtime_on:
			cv.period *= 0.7
		if _crane_rush > 0.0:
			cv.period *= 0.6
		if ship != null:
			var v: ShipView = ship_views.get(ship.id)
			if v != null:
				cv.ship_rel_z = v.position.z - cv.position.z
				cv.ship_deck_y = Layout.WATER_Y + 3.0


func _sync_marker(delta: float) -> void:
	_marker_t += delta
	var dept: String = sim.shown_analysis().get("dept", "")
	var key: String = sim.shown_analysis().get("key", "")
	var p := Layout.dept_pos(dept, sim.tier)
	if key == "harbor" or key == "fog" or key == "pilotage":
		p = Layout.anchor_pos(0) + Vector3(16, 0, 0) if key != "harbor" else p
	elif key == "berth_count":
		var nb := sim.berths.size()
		if nb < Layout.BERTHS.size():
			p = Vector3(Layout.berth_center(nb), 0, Layout.QUAY_Z)
	elif key == "yard_space":
		p = Layout.YARD_CENTER
	# l'anneau du goulot ne se montre que sur un service présenté qu'on peut améliorer tout de suite (comme la carte
	# Goulot) ; un goulot qui se règle par un bâtiment est déjà désigné par l'empreinte dorée et sa pancarte
	marker.visible = not opening_active() and not (key in Hud.BUILD_KEYS) and dept != "" and sim.feature("dept_" + dept) \
		and Hud.hint_actionable(sim)
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
	# une ouverture de zone en cours se passe d'un toucher
	if skip_opening():
		return
	var pick := pick_tap(wp)
	match String(pick.get("kind", "")):
		"crane":
			var cv: CraneView = pick.node
			var moved := sim.assist_unload(cv.berth)
			if moved > 0.0:
				assist_done.emit(cv.position + Vector3(0, 7, 0), moved)
				cv.kick()
		"vehicle":
			var vn: Node3D = pick.node
			var moved2 := sim.yard_boost()
			if moved2 > 0.0:
				gesture_done.emit(vn.position + Vector3(0, 5, 0), "Rangé ! +%s EVP" % Fmt.num(moved2), moved2)
		"barrier":
			var served := sim.gate_rush()
			if served > 0.0:
				gesture_done.emit(Layout.GATE + Vector3(0, 5, 0), "Un camion passe ! +%s EVP" % Fmt.num(served), served)
		"ship":
			# navire en rade : un seul toucher l'accoste en priorité (la Capitainerie le fera seule une fois embauchée)
			var id: int = pick.id
			var sh := sim.ship_by_id(id)
			if sh != null and sh.state == Ship.State.ANCHORED and not sh.priority and not sim.managers.harbor and sim.prioritize_ship(id):
				ship_prioritized.emit(id)
			else:
				ship_tapped.emit(id)
		"lot":
			lot_tapped.emit(String(pick.id))
		"dept":
			rig.focus(Layout.dept_pos(String(pick.id), sim.tier))
			place_tapped.emit(String(pick.id))
		"zone":
			zone_tapped.emit(int(pick.id), wp)


## Ce que touche le joueur en wp : parmi les candidats à portée (grue qui peut recevoir un coup de main, engin du parc,
## barrière, navire, empreinte du prochain achat, poste d'un service présenté), celui dont le rapport distance / rayon
## est le plus petit — le plus « visé » (revue du 13/10 : la grue, de rayon 8, passait avant l'engin, de rayon 5, même
## quand on touchait l'engin). Une zone grise ne vient qu'en dernier (une bulle d'information, pas une fiche).
func pick_tap(wp: Vector3) -> Dictionary:
	var st := {"k": INF, "best": {}}      # (les fonctions anonymes capturent les variables locales par valeur)
	var p2 := Vector2(wp.x, wp.z)
	var consider := func(kind: String, pos: Vector3, radius: float, extra: Dictionary) -> void:
		var k := Vector2(pos.x, pos.z).distance_to(p2) / radius if radius > 0.0 else -radius
		if k < 1.0 and k < float(st.k):
			st.k = k
			var b := extra.duplicate()
			b.kind = kind
			st.best = b
	for cv in crane_views:
		if cv.berth < sim.berths.size() and sim.assist_ready(cv.berth):
			consider.call("crane", cv.position, float(Layout.TAP_RADIUS.crane), {"node": cv})
	if sim.yard_boost_ready():
		for v in traffic.vehicles:
			consider.call("vehicle", (v.node as Node3D).position, float(Layout.TAP_RADIUS.vehicle), {"node": v.node})
	if sim.gate_rush_ready():
		for b in traffic.barriers:
			if is_instance_valid(b):
				var arm := b.position + Vector3(1.9 * b.scale.x * cos(b.rotation.y), 0, -1.9 * b.scale.x * sin(b.rotation.y))      # milieu du bras
				consider.call("barrier", arm, float(Layout.TAP_RADIUS.barrier), {"node": b})
	for id in ship_views:
		var sv: ShipView = ship_views[id]
		consider.call("ship", sv.position, float(Layout.TAP_RADIUS.ship) + sv.length * 0.25, {"id": id})
	var lot := lot_at(wp)
	if lot != "":
		consider.call("lot", wp, -float(Layout.TAP_RADIUS.lot_k), {"id": lot})     # empreinte touchée : rapport fixe (une surface, pas un point)
	for d in PortSim.DEPTS:
		if sim.feature("dept_" + d):
			consider.call("dept", Layout.dept_pos(d, sim.tier), float(Layout.TAP_RADIUS.dept), {"id": d})
	var best: Dictionary = st.best
	if best.is_empty():
		var z := Zones.zone_at(wp)
		if not z.is_empty() and Zones.state(sim, z) != Zones.OPEN:
			best = {"kind": "zone", "id": int(z.id)}
	return best


## Bâtiment touché en wp : l'empreinte du premier bâtiment non construit (ou la pancarte de sa zone), "" sinon.
func lot_at(wp: Vector3) -> String:
	var bid := Zones.first_unbuilt(sim)
	if bid == "" or not Layout.LOTS.has(bid):
		return ""
	var r := Layout.lot_rect(bid).grow(3.0)
	if r.has_point(Vector2(wp.x, wp.z)):
		return bid
	var z := Zones.next_zone(sim)
	if not z.is_empty() and String(z.key) == bid:
		var sp: Vector3 = z.sign
		if Vector2(sp.x - wp.x, sp.z - wp.z).length() < 7.0:
			return bid
	return ""


## Point d'ancrage de la pancarte du prochain achat (monde) : la pancarte de zone si le bâtiment ouvre une zone,
## sinon au-dessus de son empreinte.
func lot_sign_point() -> Vector3:
	# en cache (revue C7 D) : ne change qu'avec le prochain achat ou la pancarte (reconstruction du décor)
	var key := "%s|%d" % [Zones.first_unbuilt(sim), sign_node.get_instance_id() if sign_node != null and is_instance_valid(sign_node) else 0]
	if key != _lsp_key:
		_lsp_key = key
		_lsp = _lot_sign_point()
	return _lsp


var _lsp_key := ""
var _lsp := Vector3.INF


func _lot_sign_point() -> Vector3:
	var bid := Zones.first_unbuilt(sim)
	if bid == "" or not Layout.LOTS.has(bid):
		return Vector3.INF
	var z := Zones.next_zone(sim)
	if not z.is_empty() and String(z.key) == bid and sign_node != null and is_instance_valid(sign_node):
		var meta := Assets.meta("zone_sign")
		if Assets.exists("zone_sign") and meta.has("counter_face"):
			var cf: Array = meta.counter_face
			return sign_node.global_transform * Vector3(float(cf[0]), float(cf[1]), float(cf[2]))
		return sign_node.global_position + Vector3(0, 3.0, 0)
	var l: Dictionary = Layout.LOTS[bid]
	var p: Vector3 = l.p
	return Vector3(p.x, (Layout.WATER_Y if bool(l.get("water", false)) else 0.0) + 2.5, p.z)


## Position écran d'un point du monde (pour l'interface superposée).
func to_screen(p: Vector3) -> Vector2:
	return rig.cam.unproject_position(p)


func is_visible_point(p: Vector3) -> bool:
	return not rig.cam.is_position_behind(p)


## MultiMesh d'un type de dalle (routes : le modèle « road » est orienté selon X ; « road_z » est le même tourné de 90°).
func _tile_multimesh(t: String, arr: Array) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var model: String = "road" if t.begins_with("road") else t
	var tile_basis := Basis(Vector3.UP, deg_to_rad(90.0)) if t == "road_z" else Basis.IDENTITY
	mm.mesh = Assets.mesh(model)
	mm.instance_count = arr.size()
	for i in arr.size():
		var k: Vector2i = arr[i]
		mm.set_instance_transform(i, Transform3D(tile_basis, Vector3(k.x + 3.0, 0, k.y + 3.0)))
	mi.multimesh = mm
	mi.material_override = Assets.vcol_material
	return mi


static var _degreen_mat: ShaderMaterial


## Matériau des modèles dont les pièces vertes passent au gris (Layout.DEGREEN_MODELS) : le feu vert du brise-lames
## contredisait le balisage (vert sur le cap, rouge sur le brise-lames).
static func _degreen_material() -> ShaderMaterial:
	if _degreen_mat == null:
		Assets._ensure()
		_degreen_mat = Assets.vcol_material.duplicate()
		_degreen_mat.set_shader_parameter("degreen", 1.0)
	return _degreen_mat


## Navires retenus (revue N10) : un navire en route qui en rattrape un autre allant dans le même sens attend derrière lui
## (distance de suivi : demi-longueurs + Layout.SHIP_FOLLOW_GAP) ; un navire dont le poste appartient à la zone en cours
## d'ouverture attend que ses quais sortent de terre.
func _hold_ships() -> void:
	var moving := [Ship.State.ARRIVING, Ship.State.PILOTING, Ship.State.MOORING, Ship.State.DEPARTING, Ship.State.LEAVING]
	var op_zone: int = int(opening.get("id", -1)) if not opening.is_empty() else -1
	var items: Array = []
	for s in sim.ships:
		var v: ShipView = ship_views.get(s.id)
		if v == null:
			continue
		v.hold = false
		# en route : d'après la simulation, ou parce que la vue n'a pas fini son trajet (rattrapage après une retenue)
		var mv := moving.has(s.state) or v.is_moving()
		if op_zone > 0 and s.berth >= 0 and _berth_zone(s.berth) == op_zone and mv:
			v.hold = true
			continue
		if mv:
			items.append({"id": s.id, "p": Vector2(v.position.x, v.position.z), "dir": Vector2(cos(v.rotation.y), -sin(v.rotation.y)),
				"len": v.length, "view": v})
	var held := holds(items)
	for it in items:
		if held.has(it.id):
			(it.view as ShipView).hold = true


## Navires qui doivent attendre (distance de suivi) parmi `items` [{id, p, dir, len}] : {id: true}. Cas symétrique (chacun
## « suit » l'autre, caps proches) : un seul des deux cède, celui de plus grand identifiant (revue C7 A1 : plus de blocage
## mutuel).
static func holds(items: Array) -> Dictionary:
	var held := {}
	for a in items:
		for b in items:
			if a == b or not follows(a.p, a.dir, a.len, b.p, b.dir, b.len):
				continue
			if follows(b.p, b.dir, b.len, a.p, a.dir, a.len) and int(a.id) < int(b.id):
				continue
			held[a.id] = true
			break
	return held


## Le navire A (position, cap unitaire, longueur) rattrape-t-il B, qui va dans le même sens juste devant lui ?
static func follows(pa: Vector2, da: Vector2, la: float, pb: Vector2, db: Vector2, lb: float) -> bool:
	var rel := pb - pa
	return rel.dot(da) > 0.0 and da.dot(db) > 0.5 and rel.length() < (la + lb) * 0.5 + Layout.SHIP_FOLLOW_GAP
