extends Node3D
## Lot H2-0 — maquette 3D du plan « darses en peigne » (brouillon tests/h2/layout_h2.gd) avec les vrais modèles, l'eau, la
## lumière et l'angle de la caméra du jeu. Rien n'est animé : c'est le plan posé, pour le regarder comme en jeu.
##   godot --path godot res://tests/h2/iso_h2.tscn -- --tier=1|2|3 [--view=plan] [--zoom=..] [--tx=.. --tz=..] --capture=/x.png

const H := preload("res://tests/h2/layout_h2.gd")
const L := preload("res://scripts/world/layout.gd")
const EARTH := "#D2C2AC"
const GOLD := Color("#FFC83D")
const BOX_COLS := ["box_red", "box_blue", "box_green", "box_yellow", "box_orange", "box_teal", "box_purple", "box_brown"]
const FRAMES := {1: [Vector3(-2, 0, 4), 92.0], 2: [Vector3(32, 0, 0), 122.0], 3: [Vector3(70, 0, -8), 130.0]}

var A := {}
var tier := 1
var built: Array = []
var owned := 1
var root: Node3D
var boxes: Array = []
var rng := RandomNumberGenerator.new()
var _white: StandardMaterial3D


func _ready() -> void:
	A = Capture.args()
	tier = clampi(int(A.get("tier", "1")), 1, 3)
	built = H.built_for(tier)
	owned = H.parcels_owned(tier)
	rng.seed = 11
	root = Node3D.new()
	add_child(root)
	var we := WorldEnvironment.new()
	we.environment = Diorama.make_environment()
	add_child(we)
	add_child(Diorama.make_sun())
	_white = Terrain.dash_material(Color(0.97, 0.95, 0.88, 0.95))
	_land()
	_grounds()
	_darses()
	_yard()
	_cranes()
	_ships()
	_back_port()
	_ropes()
	_locks()
	_greenery()
	_containers_flush()
	_water()
	_camera()
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if A.has("capture"):
		get_viewport().get_texture().get_image().save_png(String(A.capture))
		print("CAPTURE ", A.capture)
	get_tree().quit()


# ---------------------------------------------------------------------------------------------------------------------
func _m(name: String, p: Vector3, ry_deg: float = 0.0, s: float = 1.0) -> Node3D:
	var n := Assets.instance(name)
	n.position = p
	n.rotation.y = deg_to_rad(ry_deg)
	if s != 1.0:
		n.scale = Vector3.ONE * s
	root.add_child(n)
	return n


func _floor(poly: Array, key: String, y: float) -> void:
	var mi := Terrain.poly_mesh(poly, Terrain.lin(key), y, 0.0, null)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


func _floor_r(r: Rect2, key: String, y: float = 0.0) -> void:
	_floor(Array(H.rect_poly(r)), key, y)


static func _ry_sea(sea: Vector2) -> float:
	return rad_to_deg(atan2(-sea.x, -sea.y))


static func _ry_x(d: Vector2) -> float:
	return rad_to_deg(atan2(-d.y, d.x))


func _rand_col() -> Color:
	if rng.randf() < 0.12:
		return Assets.color("empty").srgb_to_linear()
	return Assets.color(BOX_COLS[rng.randi() % BOX_COLS.size()]).srgb_to_linear()


# ---------------------------------------------------------------------------------------------------------------------
func _land() -> void:
	for gp in L.gulf_polys():
		root.add_child(Terrain.poly_mesh(Array(gp), Terrain.lin("grass_dark"), -0.05, 2.4, null))
	root.add_child(Terrain.poly_mesh(H.COAST, Terrain.lin("grass"), -0.05, 2.4, null))
	for pl in H.plugs(built):
		root.add_child(Terrain.poly_mesh(Array(pl), Terrain.lin("grass"), -0.05, 2.4, null))
	for it in L.street_props(1, []):
		if Assets.exists(String(it.m)):
			_m(String(it.m), it.p, float(it.ry), float(it.s))
	_m("lighthouse", Vector3(-66, 0, -36))
	_m("light_green", Vector3(-58, -1, -46))
	_m("light_red", Vector3(-21, -1, -44))
	if tier >= 3:
		_m("light_red", H.LIGHT_RED_E)


func _grounds() -> void:
	# parcelles non acquises : terre brun clair, rien d'autre
	for i in range(owned, H.PARCELS.size()):
		_floor(H.PARCELS[i].poly, EARTH, 0.03)
	for id in H.ZONE_POLYS:
		var z := L.zone_by_id(int(id))
		if int(z.tier) > tier or String(z.ground) == "":
			continue
		if int(id) in [8, 13, 12] and int(z.tier) > tier:
			continue
		_floor(H.zone_poly(int(id)), String(z.ground), 0.0)
	# sols des parcs, tabliers (béton clair), voie des camions, route d'accès, autoroute
	_floor_r(Rect2(2, -6, 30, 48), "gravel", 0.01)
	if tier >= 2:
		_floor_r(Rect2(74, -6, 24, 48), "asphalt_violet", 0.01)
	if tier >= 3:
		_floor_r(Rect2(148, -6, 26, 48), "asphalt_violet", 0.01)
	for bi in 4:
		if not H.berth_built(bi, built):
			continue
		var qx := H.berth_quay_x(bi)
		var x0 := minf(qx, qx - H.berth_sea(bi).x * 8.0)
		_floor_r(Rect2(x0, -6, 8, H.berth_head(bi, built) + 4.0 + 6.0), "apron_warm", 0.02)
	var xe := H.lane_end_x(tier) + 3.0
	_floor_r(Rect2(H.LANE_X0, H.LANE_BAND[0], xe - H.LANE_X0, 6), "asphalt", 0.03)
	root.add_child(Terrain.dashes([Vector2(H.LANE_X0, 51), Vector2(xe, 51)], 0.05, 0.25, 2.5, 2.5, _white))
	_floor_r(Rect2(-24, 54, 6, L.HIGHWAY_Z0 - 54), "asphalt", 0.03)
	if tier >= 2:
		_floor_r(Rect2(-18, 54, 6, L.HIGHWAY_Z0 - 54), "asphalt", 0.03)
		_floor_r(Rect2(-54, 78, 30, 6), "asphalt", 0.03)
	_floor_r(Rect2(-132, L.HIGHWAY_Z0, 330, 6), "asphalt", 0.03)
	_floor_r(Rect2(-78, 66, 6, 72), "asphalt", 0.03)
	_floor_r(Rect2(-126, 96, 102, 6), "asphalt", 0.03)
	_floor_r(Rect2(-12, 128, 56, 6), "asphalt", 0.03)
	if tier >= 3:
		_floor_r(Rect2(158.5, 54, 6, 14), "asphalt", 0.03)
		_floor_r(Rect2(108, 72, 78, 6), "gravel", 0.03)
		var x := H.RAIL_X[0] + 3.0
		while x < H.RAIL_X[1]:
			_m("rail", Vector3(x, 0, H.RAIL_Z))
			x += 6.0
		_m("rail_terminal", Vector3(150, 0, 69))


## Quais (modules de 12 u tournés vers l'eau), bollards, écume ; fonds de darse ; berges de service ; enrochements.
func _quay(a: Vector2, b: Vector2, sea: Vector2) -> void:
	var l := a.distance_to(b)
	var d := (b - a) / l
	var k := maxi(1, int(round(l / 12.0)))
	var step := l / float(k)
	for i in k:
		var c := a + d * (step * (float(i) + 0.5)) - sea * 3.0
		var q := _m("quay", Vector3(c.x, 0, c.y), _ry_sea(sea))
		q.scale.x = step / 12.0
	var nb := int(l / 6.0)
	for i in nb:
		var c2 := a + d * (6.0 * (float(i) + 0.5)) - sea * 0.7
		_m("bollard", Vector3(c2.x, 0, c2.y), _ry_sea(sea))
	_foam(a, b, sea)


func _foam(a: Vector2, b: Vector2, sea: Vector2) -> void:
	var m := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(a.distance_to(b), 1.6)
	qm.orientation = PlaneMesh.FACE_Y
	m.mesh = qm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/foam.gdshader")
	sm.set_shader_parameter("foam", Assets.color("foam"))
	m.material_override = sm
	var c := (a + b) * 0.5 + sea * 0.8
	m.position = Vector3(c.x, L.WATER_Y + 0.08, c.y)
	m.rotation.y = deg_to_rad(_ry_x(b - a))
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(m)


func _rocks(a: Vector2, b: Vector2, sea: Vector2) -> void:
	var rr := ["riprap", "riprap_b", "riprap_c"]
	var l := a.distance_to(b)
	var n := int(l / 2.6)
	for i in n:
		var p := a.lerp(b, (float(i) + 0.5) / float(n)) + sea * 0.6
		_m(rr[i % 3], Vector3(p.x, -1.0, p.y), float(i * 67 % 360), 0.9 + float(i % 3) * 0.1)
	_foam(a, b, sea)


func _darses() -> void:
	for bi in 4:
		if not H.berth_built(bi, built):
			continue
		var qx := H.berth_quay_x(bi)
		_quay(Vector2(qx, -6), Vector2(qx, H.berth_head(bi, built)), H.berth_sea(bi))
	for k in H.DARSES.size():
		var d: Dictionary = H.DARSES[k]
		var head := H.darse_head(k, built)
		if head <= H.FRONT_Z:
			continue
		_quay(Vector2(float(d.x0), head), Vector2(float(d.x1), head), Vector2(0, -1))
		# berges sans poste construit : quai de service (F0), enrochement
		for sb in H.SERVICE_BANKS:
			if int(sb.darse) == k:
				if String(sb.kind) == "service":
					_quay(Vector2(float(sb.x), -6), Vector2(float(sb.x), head), sb.sea)
				else:
					_rocks(Vector2(float(sb.x), -6), Vector2(float(sb.x), head), sb.sea)
		if k == 2 and not built.has("berth4"):
			_rocks(Vector2(140, -6), Vector2(140, head), Vector2(-1, 0))
	# musoirs : un module de quai en travers du bout de chaque doigt bâti (bord du front de mer)
	_quay(Vector2(-48, -6), Vector2(-36, -6), Vector2(0, -1))
	_quay(Vector2(-6, -6), Vector2(34, -6), Vector2(0, -1))
	if tier >= 2:
		_quay(Vector2(66, -6), Vector2(106, -6), Vector2(0, -1))
	if tier >= 3:
		_quay(Vector2(140, -6), Vector2(186, -6), Vector2(0, -1))
	# vieux quai : capitainerie, hangar, avitaillement et remorqueur sur la berge de service
	_m("harbor_office", Vector3(-43, 0, 6))
	_m("hangar" if tier < 3 else "inspection_hall", Vector3(-42.6, 0, 19), 90.0)
	if built.has("supply"):
		_m("pilot_boat", Vector3(-33.5, -1, 8), 90.0)
	if built.has("tug2"):
		_m("tug", Vector3(-33.0, -1, 30), 90.0)


func _yard() -> void:
	for b in H.blocks_built(built):
		var r := H.block_rect(b)
		root.add_child(Terrain.dashes(Array(H.rect_poly(r.grow(0.5))), 0.04, 0.22, 1000.0, 0.0, _white))
		var maxh := int(b.tiers)
		var fill := rng.randf_range(0.45, 0.75)
		var mesh_zone := int(b.zone)
		for i in int(b.bays):
			for j in int(b.rows):
				var h := clampi(int(round(fill * maxh + rng.randf_range(-1.4, 1.4))), 0, maxh)
				for k in h:
					var p := Vector3(float(b.x) + 0.75 + j * H.ROW, k * 1.32, float(b.z) + 2.2 + i * H.BAY)
					var col := _rand_col()
					if mesh_zone == 1:
						col = Assets.color("reefer").srgb_to_linear()
					elif mesh_zone == 2:
						col = Assets.color("imo").srgb_to_linear()
					boxes.append([Transform3D(Basis(Vector3.UP, PI * 0.5), p), col])
	# conteneurs du tablier : une rangée de 8 le long de chaque quai
	for bi in 4:
		if not H.berth_built(bi, built):
			continue
		var x := H.berth_quay_x(bi) - H.berth_sea(bi).x * H.APRON_BOX_OFF
		for i in 6:
			if rng.randf() < 0.4:
				continue
			boxes.append([Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, 0, 4.0 + i * 5.2)), _rand_col()])
	if built.has("rtg"):
		_m("rtg", Vector3(155.5, 0, 12), 0.0)
		_m("rtg", Vector3(167.5, 0, 28), 0.0)
	if built.has("reefer"):
		_m("reefer_rack", Vector3(86, 0, 44), 0.0)
	if built.has("lng"):
		_m("lng_sphere", Vector3(179, 0, 28.5))
		_m("lng_sphere", Vector3(179, 0, 37.5))
	if built.has("imo"):
		_m("imo_fence", Vector3(178.5, 0, 8.4), 90.0)
	# engins sur leur allée (un par doigt) : cavalier sur l'allée centrale, tracteur sur l'allée de tablier
	for f in H.FINGERS:
		if int(f.tier) <= tier:
			_m("straddle", Vector3(float(f.xc), 0, 14), 90.0)
	_m("reach_stacker", Vector3(H.apron_lane(0), 0, 20), 90.0)


func _cranes() -> void:
	var cr: Array = H.cranes_for(built)
	for bi in cr.size():
		var list: Array = cr[bi]
		for ci in list.size():
			var kind := String(list[ci])
			var p := H.crane_pos(bi, ci, list.size(), kind, built)
			var sea := H.berth_sea(bi)
			if kind == "sts":
				_m("crane_sts", p, _ry_sea(sea))
			else:
				_m("crane_mobile", p, _ry_x(sea))


func _ship(cls: String, c: Vector2, fwd: Vector2, fill: float) -> void:
	var model := String(H.SHIP_MODELS[cls])
	var s := float(H.SHIP_SCALE[cls])
	var ry := _ry_x(fwd)
	var n := _m(model, Vector3(c.x, L.WATER_Y, c.y), ry, s)
	var xf := n.transform
	var meta := Assets.meta(model)
	for sl in meta.get("slots", []):
		if rng.randf() > fill:
			continue
		var p := xf * Vector3(float(sl[0]), float(sl[1]), float(sl[2]))
		boxes.append([Transform3D(Basis(Vector3.UP, deg_to_rad(ry)).scaled(Vector3.ONE * s), p), _rand_col()])


func _ships() -> void:
	var moving: int = {1: 0, 2: 1, 3: 2}[tier]          # le navire qui recule (T1 : poste 1 ; T2 : poste 2 ; T3 : poste 3)
	for bi in 4:
		if not H.berth_built(bi, built):
			continue
		var cls := H.berth_class(bi, built)
		var sz := H.ship_size(cls)
		if bi == moving and tier > 1:
			# en marche arrière dans la darse (le remorqueur tient la proue, côté large)
			var poses := H.path_poses(H.ship_path_back_in(bi, built), 1.0, true)
			var ps: Dictionary = poses[int(poses.size() * (0.32 if tier == 2 else 0.55))]
			_ship(cls, ps.c, ps.fwd, 0.7)
			var bow: Vector2 = (ps.c as Vector2) + (ps.fwd as Vector2) * (sz.x * 0.5 + 4.0)
			_m("tug", Vector3(bow.x, L.WATER_Y, bow.y), _ry_x(-(ps.fwd as Vector2)))
			continue
		var p := H.berth_ship_pos(bi, sz.y, built)
		_ship(cls, Vector2(p.x, p.z), Vector2(0, -1), 0.65)
	if tier == 1:
		# un caboteur au point d'attente de D1, cap à l'est, avant de reculer
		var g := H.berth_gate(0)
		_ship("coaster", Vector2(g.x, g.z), Vector2(1, 0), 0.6)


func _back_port() -> void:
	# douane, gate, file (reculées de 18 u)
	_m("customs_office" if built.has("customs1") else "customs_hut", Vector3(-28.5, 0, 58.5))
	_m("barrier_post", Vector3(-21, 0, 62))
	_m("gate_lanes", Vector3(-21 if tier < 2 else -18, 0.02, 58), 180.0)
	if built.has("scanner1"):
		_m("customs_office", Vector3(-39.4, 0, 58.5))
		_m("van", Vector3(-35.4, 0, 58.5), 90.0)
	if built.has("scanner2"):
		_m("scanner", Vector3(-22.5, 0, 57.5), 90.0)
	if built.has("gate2"):
		_m("gate_booth", Vector3(-17.25, 0.15, 64.5), 0.0, 0.85)
	if built.has("ewindow"):
		_m("office", Vector3(-31, 0, 72))
	if built.has("ecustoms"):
		_m("it_center", Vector3(-40, 0, 72))
	if built.has("tos"):
		_m("it_center", Vector3(-49, 0, 72))
	if tier >= 2:
		_m("control_tower", Vector3(-62, 0, -16))
	# camions : sur la voie (A vers l'est, B à l'arrêt devant un doigt), dans la file
	var stops := H.stop_ranges(tier)
	for i in stops.size():
		var rg: Array = stops[i]
		_m("truck", Vector3(lerpf(float(rg[0]), float(rg[1]), 0.4), 0, H.LOAD_STOP_Z + 0.6), 180.0)
		_m("truck", Vector3(lerpf(float(rg[0]), float(rg[1]), 0.8), 0, H.LANE_A_Z), 0.0)
	for k in 3:
		_m("truck", Vector3(L.ROAD_IN_X[0], 0, H.QUEUE_Z0 + k * 7.5), -90.0)
	# village (inchangé) : maisons, et la logistique au loin
	for p in L.PROPS:
		var m := String(p.m)
		if m.begins_with("house") or m == "shop" or m == "warehouse" or m == "silo":
			var pp: Array = p.p
			_m(m, Vector3(float(pp[0]), float(pp[1]), float(pp[2])), float(p.get("ry", 0.0)))


## Piquets et corde (style b) : MultiMesh de piquets (cylindre bois 0,5 × 2,6) et de corde (boîte 0,3 étirée), blanc ou or.
func _ropes() -> void:
	var r := H.ropes(owned, built)
	var stake := CylinderMesh.new()
	stake.top_radius = 0.22
	stake.bottom_radius = 0.26
	stake.height = 2.6
	stake.radial_segments = 6
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	var smm := MultiMesh.new()
	smm.transform_format = MultiMesh.TRANSFORM_3D
	smm.use_colors = true
	smm.mesh = stake
	smm.instance_count = r.stakes.size()
	for i in r.stakes.size():
		var p: Vector2 = r.stakes[i].p
		smm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(p.x, 1.3, p.y)))
		smm.set_instance_color(i, Color("#8A6440") if not r.stakes[i].gold else Color("#B07A2A"))
	var smi := MultiMeshInstance3D.new()
	smi.multimesh = smm
	smi.material_override = mat
	root.add_child(smi)
	var rope := BoxMesh.new()
	rope.size = Vector3(1, 0.3, 0.3)
	var rmat := StandardMaterial3D.new()
	rmat.vertex_color_use_as_albedo = true
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rmm := MultiMesh.new()
	rmm.transform_format = MultiMesh.TRANSFORM_3D
	rmm.use_colors = true
	rmm.mesh = rope
	rmm.instance_count = r.segs.size()
	for i in r.segs.size():
		var s: Dictionary = r.segs[i]
		var a: Vector2 = s.a
		var b: Vector2 = s.b
		var c := (a + b) * 0.5
		var w := 1.6 if s.gold else 1.0
		var basis := Basis(Vector3.UP, atan2(-(b - a).y, (b - a).x)).scaled(Vector3(a.distance_to(b), w, w))
		rmm.set_instance_transform(i, Transform3D(basis, Vector3(c.x, 2.1, c.y)))
		rmm.set_instance_color(i, GOLD if s.gold else Color(0.98, 0.97, 0.94))
	var rmi := MultiMeshInstance3D.new()
	rmi.multimesh = rmm
	rmi.material_override = rmat
	rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(rmi)


## Cadenas + prix (dans le jeu : la surcouche 2D ; ici des étiquettes 3D à taille fixe à l'écran).
func _locks() -> void:
	var prices := {1: 500.0}
	var tiers = JSON.parse_string(FileAccess.get_file_as_string("res://data/tiers.json"))
	for t in tiers:
		if t.get("req") != null:
			prices[int(t.id)] = float(t.req.money)
	for i in range(owned, H.PARCELS.size()):
		var pc: Dictionary = H.PARCELS[i]
		var bp: Vector2 = pc.badge
		var nxt := i == owned
		var sp := Sprite3D.new()
		sp.texture = load("res://assets/icons/lock.svg")
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.fixed_size = true
		sp.pixel_size = 0.0007 if nxt else 0.00055
		sp.offset = Vector2(0, 40)
		sp.modulate = Color("#F2A93B") if nxt else Color("#4B4FA8")
		sp.no_depth_test = true
		sp.position = Vector3(bp.x, 6.0, bp.y)
		root.add_child(sp)
		var lb := Label3D.new()
		lb.text = Fmt.money(float(prices.get(int(pc.tier), 0.0)))
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.fixed_size = true
		lb.pixel_size = 0.0016 if nxt else 0.0013
		lb.font_size = 32
		lb.outline_size = 10
		lb.modulate = Color("#7A4A00") if nxt else Color("#2B2E70")
		lb.outline_modulate = Color(1, 1, 1, 0.95)
		lb.no_depth_test = true
		lb.position = Vector3(bp.x, 6.0, bp.y)
		lb.offset = Vector2(0, -40)
		lb.position = Vector3(bp.x, 6.0, bp.y)
		root.add_child(lb)


## Arbres de l'arrière-pays (Layout.scatter, filtré : jamais sur le port reculé ni sur une parcelle) et forêt.
func _greenery() -> void:
	var avoid := [Rect2(-50, -8, 240, 64), Rect2(-60, 46, 70, 90), Rect2(104, 54, 84, 30), Rect2(-27, 52, 36, 90)]
	for it in L.scatter():
		var p: Vector3 = it.p
		var bad := false
		for r in avoid:
			if (r as Rect2).has_point(Vector2(p.x, p.z)):
				bad = true
		if not bad:
			_m(String(it.m), p, float(it.ry), float(it.s))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Assets.mesh("forest_block")
	var fl: Array = L.forest()
	mm.instance_count = fl.size()
	for i in fl.size():
		var f: Dictionary = fl[i]
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, deg_to_rad(float(f.ry))).scaled(Vector3.ONE * float(f.s)), f.p))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = Assets.vcol_material
	root.add_child(mi)


func _containers_flush() -> void:
	if boxes.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = Assets.mesh("container40")
	mm.instance_count = boxes.size()
	for i in boxes.size():
		mm.set_instance_transform(i, boxes[i][0])
		mm.set_instance_color(i, Color.WHITE)
		mm.set_instance_custom_data(i, boxes[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = Assets.tint_material
	root.add_child(mi)


func _water() -> void:
	var w := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	pm.subdivide_width = 90
	pm.subdivide_depth = 90
	w.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/water.gdshader")
	var shallow := Assets.color("water")
	m.set_shader_parameter("shore", shallow.lerp(Assets.color("foam"), 0.4))
	m.set_shader_parameter("shallow", shallow)
	m.set_shader_parameter("deep", Assets.color("water_deep"))
	m.set_shader_parameter("sparkle", Assets.color("foam"))
	var r := L.MASK_RECT
	m.set_shader_parameter("mask_rect", Vector4(r.position.x, r.position.y, r.end.x, r.end.y))
	var polys: Array = []
	polys.append_array(H.land_polys(built))
	polys.append_array(L.gulf_polys())
	m.set_shader_parameter("dist_tex", Terrain.distance_texture(Terrain.distance_field(polys)))
	w.material_override = m
	w.position = Vector3(40, L.WATER_Y, 0)
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(w)


func _camera() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	var fr: Array = FRAMES[tier]
	var t: Vector3 = fr[0]
	var z := float(fr[1])
	var basis := Basis.from_euler(Vector3(deg_to_rad(CameraRig.PITCH), deg_to_rad(CameraRig.YAW), 0.0))
	if String(A.get("view", "iso")) == "plan":
		basis = Basis.from_euler(Vector3(deg_to_rad(-90.0), 0.0, 0.0))
		t = Vector3(68, 0, 30)
		z = 280.0
	if A.has("tx"):
		t.x = float(A.tx)
	if A.has("tz"):
		t.z = float(A.tz)
	if A.has("zoom"):
		z = float(A.zoom)
	cam.size = z
	cam.near = 1.0
	cam.far = 1200.0
	add_child(cam)
	cam.global_transform = Transform3D(basis, t + basis.z * 400.0)
	cam.make_current()
