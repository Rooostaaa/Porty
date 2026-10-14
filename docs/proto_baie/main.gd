extends Node3D
## Prototype « La baie et le terre-plein » : terrain polygonal construit dans Godot (sans Blender), zones à états
## (ouverte / prochaine / grisée / tracée sur l'eau), eau masquée par une texture de distance, chenal balisé, cap et crique.
## Arguments : --tier=1|2|3  --zoom=40  --look=x,z  --capture=chemin.png  --delay=1.5

const WATER_Y := -1.0
const PITCH := -35.0
const YAW := 45.0
const MASK_RECT := Rect2(-200, -230, 460, 460)
const MASK_N := 256

var tier := 1
var zoom := 40.0
var look := Vector3(-34.5, 0, -5.5)
var pal := {}
var vcol: ShaderMaterial
var vcol_gray: ShaderMaterial
var land_mat: ShaderMaterial
var land_gray: ShaderMaterial
var cam: Camera3D
var _t := 0.0
var _ship: Node3D
var _tug: Node3D
var _path: Array[Vector3] = []
var _ship_t := 0.0

# ---------------------------------------------------------------------------
# Plan coté (x, z). Mer en z négatif, terre en z positif. Sens des polygones : quelconque (faces non masquées).
# ---------------------------------------------------------------------------
## Continent : plage ouest, cap et phare, crique (fond = quais du vieux port), côte du terminal (quais), baie est (plage).
const COAST := [
	Vector2(-132, 168), Vector2(-132, 60), Vector2(-112, 52), Vector2(-94, 48),
	Vector2(-92, 24), Vector2(-90, 0), Vector2(-86, -16), Vector2(-80, -30), Vector2(-70, -42), Vector2(-60, -40), Vector2(-56, -30),
	Vector2(-56, -14), Vector2(-52, -8), Vector2(-48, -6),
	Vector2(48, -6),
	Vector2(48, 32), Vector2(62, 40), Vector2(100, 44), Vector2(136, 42), Vector2(152, 36), Vector2(166, 44), Vector2(186, 50),
	Vector2(186, 168),
]
## Terre-plein gagné sur la mer (palier 3) : remplit la baie est.
const RECLAIM := [Vector2(48, -6), Vector2(150, -6), Vector2(152, 36), Vector2(136, 42), Vector2(100, 44), Vector2(62, 40), Vector2(48, 32)]
## Brise-lames nord-est (ferme la crique ; la passe est entre le cap et lui).
const BREAKWATER := [Vector2(0, -46), Vector2(38, -46), Vector2(38, -42), Vector2(0, -42)]

## Zones : id, palier, polygone, couleur de sol, nom affiché, prix.
var ZONES := [
	{"id": 1, "tier": 1, "poly": [Vector2(-48, -6), Vector2(0, -6), Vector2(0, 24), Vector2(-48, 24)], "col": "sand_warm", "name": "Vieux port", "price": ""},
	{"id": 2, "tier": 1, "poly": [Vector2(-12, -6), Vector2(0, -6), Vector2(0, 0), Vector2(-12, 0)], "col": "apron_warm", "name": "Quai allongé", "price": "250 $", "quay": true},
	{"id": 3, "tier": 1, "poly": [Vector2(-30, 24), Vector2(-6, 24), Vector2(-6, 48), Vector2(-30, 48)], "col": "kerb", "name": "La Porte", "price": "800 $"},
	{"id": 5, "tier": 1, "poly": [], "col": "", "name": "Chenal dragué", "price": "2 000 $", "water": true},
	{"id": 6, "tier": 2, "poly": [Vector2(0, -6), Vector2(48, -6), Vector2(48, 30), Vector2(0, 30)], "col": "asphalt_violet", "name": "Terminal", "price": "150 K$"},
	{"id": 7, "tier": 2, "poly": [Vector2(12, 30), Vector2(48, 30), Vector2(48, 44), Vector2(12, 44)], "col": "#BBD3E6", "name": "Pôle froid", "price": "10 M$"},
	{"id": 8, "tier": 2, "poly": [Vector2(-24, 48), Vector2(6, 48), Vector2(6, 84), Vector2(-24, 84)], "col": "concrete_dark", "name": "Porte n°2 et parkings", "price": "3 M$"},
	{"id": 9, "tier": 2, "poly": [Vector2(-48, 24), Vector2(-30, 24), Vector2(-30, 48), Vector2(-48, 48)], "col": "grass_lime", "name": "Colline du port", "price": "400 K$"},
	{"id": 10, "tier": 3, "poly": [Vector2(48, -6), Vector2(126, -6), Vector2(126, 30), Vector2(48, 30)], "col": "asphalt_violet", "name": "Terre-plein", "price": "200 M$", "reclaim": true},
	{"id": 11, "tier": 3, "poly": [Vector2(126, -6), Vector2(150, -6), Vector2(150, 30), Vector2(126, 30)], "col": "#B5503C", "name": "Zone sensible", "price": "350 M$", "reclaim": true},
	{"id": 12, "tier": 3, "poly": [Vector2(30, 84), Vector2(126, 84), Vector2(126, 126), Vector2(30, 126)], "col": "gravel", "name": "Gare et logistique", "price": "420 M$"},
]
## Zone « prochaine » par palier (une seule à la fois).
const NEXT := {1: 2, 2: 6, 3: 11}

## Routes (asphalte sombre) : accès à la gate, autoroute, rue du village.
const ROADS := [
	[Vector2(-24, 30), Vector2(-18, 30), Vector2(-18, 138), Vector2(-24, 138)],
	[Vector2(-132, 138), Vector2(186, 138), Vector2(186, 144), Vector2(-132, 144)],
	[Vector2(-78, 66), Vector2(-72, 66), Vector2(-72, 138), Vector2(-78, 138)],
	[Vector2(-126, 96), Vector2(-24, 96), Vector2(-24, 102), Vector2(-126, 102)],
	[Vector2(-18, 114), Vector2(30, 114), Vector2(30, 120), Vector2(-18, 120)],
]

## Chenal : de la rade (hors écran au nord) à la passe, puis au bassin d'évitage devant le vieux quai.
const CHANNEL := [Vector3(-16, 0, -110), Vector3(-30, 0, -70), Vector3(-34, 0, -52), Vector3(-30, 0, -32), Vector3(-24, 0, -18)]
const ANCHORAGE := [Vector3(-50, 0, -100), Vector3(-16, 0, -110), Vector3(20, 0, -104)]

## Décor : modèle, position, rotation, palier minimal, zone (gris tant que la zone est grisée).
var PROPS := [
	{"m": "lighthouse", "p": Vector3(-72, -1, -30), "t": 1},
	{"m": "rock", "p": Vector3(-64, -1, -42), "t": 1}, {"m": "rock", "p": Vector3(-76, -1, -40), "ry": 70, "t": 1},
	{"m": "rock", "p": Vector3(-58, -1, -32), "ry": 30, "t": 1}, {"m": "rock", "p": Vector3(-84, -1, -22), "t": 1},
	{"m": "harbor_office", "p": Vector3(-43, 0, 8), "t": 1, "z": 1},
	{"m": "hangar", "p": Vector3(-40, 0, 18), "ry": 90, "t": 1, "z": 1},
	{"m": "crane_mobile", "p": Vector3(-26, 0, -3), "t": 1, "z": 1},
	{"m": "fishing_boat", "p": Vector3(-50, -1, -12), "ry": 70, "t": 1},
	{"m": "fishing_boat", "p": Vector3(-54, -1, -20), "ry": 105, "t": 1},
	{"m": "net_pile", "p": Vector3(-46, 0, 0.5), "t": 1, "z": 1}, {"m": "crate_fish", "p": Vector3(-41, 0, 1.4), "t": 1, "z": 1},
	{"m": "life_ring_post", "p": Vector3(-39, 0, 0.6), "t": 1, "z": 1}, {"m": "lamp", "p": Vector3(-36, 0, 2), "t": 1, "z": 1},
	{"m": "customs_hut", "p": Vector3(-26, 0, 36), "t": 1, "z": 3},
	{"m": "barrier", "p": Vector3(-23.6, 0, 31), "t": 1, "z": 3},
	{"m": "gate_lanes", "p": Vector3(-21, 0.02, 40), "t": 1, "z": 3},
	{"m": "lamp", "p": Vector3(-25, 0, 44), "t": 1, "z": 3},
	{"m": "tree", "p": Vector3(-44, 0, 30), "t": 1}, {"m": "tree", "p": Vector3(-38, 0, 44), "t": 1}, {"m": "bush", "p": Vector3(-34, 0, 27), "t": 1},
	# palier 2
	{"m": "control_tower", "p": Vector3(-40, 0, 36), "t": 1, "z": 9},
	{"m": "workshop", "p": Vector3(-34, 0, 44), "ry": 0, "t": 2, "z": 9},
	{"m": "crane_sts", "p": Vector3(18, 0, -3), "t": 1, "z": 6},
	{"m": "reefer_rack", "p": Vector3(30, 0, 37), "t": 1, "z": 7},
	{"m": "gate_booth", "p": Vector3(-18, 0, 31), "t": 2, "z": 8},
	{"m": "sign_p", "p": Vector3(-19.5, 0, 55), "t": 2, "z": 8},
	{"m": "truck", "p": Vector3(-15, 0, 62), "ry": 90, "t": 2, "z": 8}, {"m": "truck", "p": Vector3(-10, 0, 62), "ry": 90, "t": 2, "z": 8},
	{"m": "truck", "p": Vector3(-5, 0, 74), "ry": 90, "t": 2, "z": 8},
	# palier 3
	{"m": "rtg", "p": Vector3(66, 0, 12), "ry": 90, "t": 3, "z": 10}, {"m": "rtg", "p": Vector3(110, 0, 12), "ry": 90, "t": 3, "z": 10},
	{"m": "crane_sts", "p": Vector3(66, 0, -3), "t": 3, "z": 10}, {"m": "crane_sts", "p": Vector3(90, 0, -3), "t": 3, "z": 10},
	{"m": "crane_sts", "p": Vector3(114, 0, -3), "t": 3, "z": 10},
	{"m": "substation", "p": Vector3(112, 0, 26), "t": 3, "z": 10},
	{"m": "silo", "p": Vector3(136, 0, 20), "t": 3, "z": 11}, {"m": "silo", "p": Vector3(143, 0, 20), "t": 3, "z": 11},
	{"m": "imo_fence", "p": Vector3(138, 0, 8), "t": 3, "z": 11},
	{"m": "warehouse", "p": Vector3(48, 0, 98), "t": 1, "z": 12}, {"m": "warehouse", "p": Vector3(72, 0, 98), "t": 1, "z": 12},
	{"m": "rail_terminal", "p": Vector3(100, 0, 100), "t": 1, "z": 12}, {"m": "silo", "p": Vector3(116, 0, 112), "t": 1, "z": 12},
	# village
	{"m": "house_a", "p": Vector3(-88, 0, 72), "ry": 90, "t": 1}, {"m": "house_b", "p": Vector3(-88, 0, 84), "ry": 90, "t": 1},
	{"m": "house_a", "p": Vector3(-88, 0, 110), "ry": 90, "t": 1}, {"m": "house_b", "p": Vector3(-62, 0, 72), "ry": -90, "t": 1},
	{"m": "shop", "p": Vector3(-62, 0, 110), "ry": -90, "t": 1}, {"m": "house_a", "p": Vector3(-106, 0, 88), "t": 1},
	{"m": "house_b", "p": Vector3(-120, 0, 112), "ry": 180, "t": 1}, {"m": "house_a", "p": Vector3(-48, 0, 88), "t": 1},
	{"m": "hill", "p": Vector3(-100, 0, 156), "s": 1.5, "t": 1}, {"m": "hill", "p": Vector3(-30, 0, 156), "t": 1},
	{"m": "hill", "p": Vector3(60, 0, 154), "s": 1.3, "t": 1}, {"m": "hill", "p": Vector3(140, 0, 150), "s": 1.6, "t": 1},
	{"m": "hill", "p": Vector3(-112, 20, 10), "s": 0.9, "t": 1},
]


func _ready() -> void:
	_args()
	var p: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/palette.json"))
	pal = p if p is Dictionary else {}
	vcol = ShaderMaterial.new()
	vcol.shader = load("res://assets/vcol.gdshader")
	vcol_gray = vcol.duplicate()
	vcol_gray.set_shader_parameter("desat", 0.85)
	vcol_gray.set_shader_parameter("tint", Color(0.93, 0.93, 0.95))
	land_mat = ShaderMaterial.new()
	land_mat.shader = load("res://assets/land.gdshader")
	land_gray = land_mat.duplicate()
	land_gray.set_shader_parameter("desat", 0.8)
	land_gray.set_shader_parameter("tint", Color(0.96, 0.96, 0.98))
	_env()
	_water()
	_land()
	_zones()
	_roads()
	_quays()
	_channel()
	_props()
	_scatter()
	_camera()
	if OS.get_cmdline_user_args().size() > 0:
		_capture()


func _args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.substr(2).split("=", true, 1)
		var v := kv[1] if kv.size() > 1 else "1"
		match kv[0]:
			"tier": tier = int(v)
			"zoom": zoom = float(v)
			"look":
				var xz := v.split(",")
				look = Vector3(float(xz[0]), 0, float(xz[1]))


func C(key: String) -> Color:
	if key.begins_with("#"):
		return Color(key)
	return Color(String(pal.get(key, "#ff00ff")))


# ---------------------------------------------------------------------------
# Lumière et eau (mêmes réglages que le jeu, lot B)
# ---------------------------------------------------------------------------
func _env() -> void:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#8fd0f0")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var amb := Color(0.96, 0.94, 1.0)
	e.ambient_light_color = amb.linear_to_srgb()
	e.ambient_light_energy = 0.67
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = e
	add_child(we)
	var s := DirectionalLight3D.new()
	var d := Vector3(-0.243, -0.85, 0.467).normalized()
	s.transform = Transform3D(Basis.looking_at(d, Vector3.UP), Vector3.ZERO)
	var rest := Color(1.0 - amb.r * 0.67, 1.0 - amb.g * 0.67, 1.0 - amb.b * 0.67)
	var peak := maxf(rest.r, maxf(rest.g, rest.b))
	s.light_energy = peak / absf(d.y)
	s.light_color = Color(rest.r / peak, rest.g / peak, rest.b / peak).linear_to_srgb()
	s.shadow_enabled = true
	s.shadow_blur = 0.4
	s.shadow_opacity = 0.5
	s.directional_shadow_max_distance = 420.0
	add_child(s)


## Texture de distance au rivage : rastérisation des polygones de terre puis transformée de distance (chanfrein 3-4).
func _water() -> void:
	var lands: Array = [PackedVector2Array(COAST), PackedVector2Array(BREAKWATER)]
	if tier >= 3:
		lands.append(PackedVector2Array(RECLAIM))
	var n := MASK_N
	var cell := MASK_RECT.size.x / float(n)
	var inside := PackedByteArray()
	inside.resize(n * n)
	for j in n:
		for i in n:
			var p := MASK_RECT.position + Vector2((i + 0.5) * cell, (j + 0.5) * cell)
			var hit := false
			for poly in lands:
				if Geometry2D.is_point_in_polygon(p, poly):
					hit = true
					break
			inside[j * n + i] = 1 if hit else 0
	var big := 1e6
	var dist := PackedFloat32Array()
	dist.resize(n * n)
	for k in n * n:
		dist[k] = 0.0 if inside[k] == 1 else big
	# deux passes de chanfrein (3-4) : distance en cellules, puis en unités monde
	for j in n:
		for i in n:
			var k := j * n + i
			var v := dist[k]
			if i > 0: v = minf(v, dist[k - 1] + 3.0)
			if j > 0:
				v = minf(v, dist[k - n] + 3.0)
				if i > 0: v = minf(v, dist[k - n - 1] + 4.0)
				if i < n - 1: v = minf(v, dist[k - n + 1] + 4.0)
			dist[k] = v
	for j in range(n - 1, -1, -1):
		for i in range(n - 1, -1, -1):
			var k := j * n + i
			var v := dist[k]
			if i < n - 1: v = minf(v, dist[k + 1] + 3.0)
			if j < n - 1:
				v = minf(v, dist[k + n] + 3.0)
				if i < n - 1: v = minf(v, dist[k + n + 1] + 4.0)
				if i > 0: v = minf(v, dist[k + n - 1] + 4.0)
			dist[k] = v
	var img := Image.create(n, n, false, Image.FORMAT_RF)
	for j in n:
		for i in n:
			var d := dist[j * n + i] / 3.0 * cell
			img.set_pixel(i, j, Color(d if inside[j * n + i] == 0 else -cell, 0, 0))
	var tex := ImageTexture.create_from_image(img)
	var w := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	pm.subdivide_width = 90
	pm.subdivide_depth = 90
	w.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/water_mask.gdshader")
	var shallow := C("water")
	m.set_shader_parameter("shore", shallow.lerp(C("foam"), 0.4))
	m.set_shader_parameter("shallow", shallow)
	m.set_shader_parameter("deep", C("water_deep"))
	m.set_shader_parameter("sparkle", C("foam"))
	m.set_shader_parameter("dist_tex", tex)
	m.set_shader_parameter("mask_rect", Vector4(MASK_RECT.position.x, MASK_RECT.position.y, MASK_RECT.end.x, MASK_RECT.end.y))
	w.material_override = m
	w.position = Vector3(40, WATER_Y, 0)
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(w)


# ---------------------------------------------------------------------------
# Terrain polygonal : dessus coloré + flancs en couches de terre (même look que les dalles Blender)
# ---------------------------------------------------------------------------
func _poly_mesh(poly: Array, top: Color, y: float, depth: float, mat: Material, sides: bool = true) -> MeshInstance3D:
	var pts := PackedVector2Array(poly)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := Geometry2D.triangulate_polygon(pts)
	st.set_normal(Vector3.UP)
	st.set_color(top)
	for i in idx:
		st.add_vertex(Vector3(pts[i].x, y, pts[i].y))
	if sides and depth > 0.0:
		var bands := [[0.0, -1.15, C("earth")], [-1.15, -depth, C("earth_dark")]]
		for e in pts.size():
			var a := pts[e]
			var b := pts[(e + 1) % pts.size()]
			var nrm := Vector3(b.y - a.y, 0, -(b.x - a.x)).normalized()
			for band in bands:
				var y0: float = y + float(band[0])
				var y1: float = y + float(band[1])
				st.set_normal(nrm)
				st.set_color(band[2])
				var p0 := Vector3(a.x, y0, a.y)
				var p1 := Vector3(b.x, y0, b.y)
				var p2 := Vector3(b.x, y1, b.y)
				var p3 := Vector3(a.x, y1, a.y)
				for v in [p0, p1, p2, p0, p2, p3]:
					st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)
	return mi


## Pointillés le long d'un contour (zone grisée ou future terre tracée sur l'eau).
func _dashes(poly: Array, y: float, col: Color, width: float, dash: float, gap: float) -> void:
	var pts := PackedVector2Array(poly)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	st.set_color(col)
	for e in pts.size():
		var a := pts[e]
		var b := pts[(e + 1) % pts.size()]
		var len := a.distance_to(b)
		var dir := (b - a) / maxf(0.01, len)
		var side := Vector2(-dir.y, dir.x) * width * 0.5
		var s := 0.0
		while s < len:
			var e1 := minf(len, s + dash)
			var q0 := a + dir * s
			var q1 := a + dir * e1
			var v := [q0 + side, q1 + side, q1 - side, q0 - side]
			for k in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(Vector3(v[k].x, y, v[k].y))
			s += dash + gap
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = land_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _land() -> void:
	_poly_mesh(COAST, C("grass"), 0.0, 2.4, land_mat)
	_poly_mesh(BREAKWATER, C("concrete_dark"), 0.2, 1.6, land_mat)
	if tier >= 3:
		_poly_mesh(RECLAIM, C("asphalt_violet"), 0.0, 2.4, land_mat)
		# enrochements au bord du terre-plein
		for i in 9:
			var r := Node3D.new()
			r = _inst("rock", vcol)
			r.position = Vector3(52 + i * 12.0, -0.8, -7.5)
			r.rotation.y = i * 0.9
			r.scale = Vector3.ONE * 1.3
	else:
		_dashes(RECLAIM, WATER_Y + 0.12, Color(1, 1, 1), 1.0, 3.0, 3.0)


func zone_state(z: Dictionary) -> String:
	if int(NEXT.get(tier, 0)) == int(z.id):
		return "next"
	return "open" if int(z.tier) < tier or (int(z.tier) == tier and int(z.id) < int(NEXT.get(tier, 0))) else "gray"


func _zones() -> void:
	for z in ZONES:
		if z.has("water") or z.has("quay"):
			continue
		var st := zone_state(z)
		if z.has("reclaim") and tier < 3:
			continue      # encore de l'eau : seul le contour est tracé (voir _land)
		var col := C(String(z.col))
		var mat := land_mat if st != "gray" else land_gray
		_poly_mesh(z.poly, col, 0.04, 0.0, mat, false)
		if st == "gray":
			_dashes(z.poly, 0.08, C("marking_thick"), 0.7, 2.5, 2.0)
		elif st == "next":
			_dashes(z.poly, 0.09, C("mark_yellow"), 1.2, 3.0, 1.5)
			_sign(z)
	# zone « prochaine » du quai : empreinte pointillée sur le quai manquant + pancarte
	for z in ZONES:
		if z.has("quay") and zone_state(z) == "next":
			for x in [-9.0, -3.0]:
				var g := _inst("ghost_lot", vcol)
				g.position = Vector3(x, 0.03, -3)
			_sign(z)


func _sign(z: Dictionary) -> void:
	var pts := PackedVector2Array(z.poly)
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var l := Label3D.new()
	l.text = "%s\n%s" % [z.name, z.price]
	l.font_size = 64
	l.outline_size = 16
	l.modulate = C("mark_yellow")
	l.outline_modulate = Color(0.2, 0.15, 0.1)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = Vector3(c.x, 6.0, c.y)
	l.pixel_size = 0.03
	add_child(l)


func _roads() -> void:
	for r in ROADS:
		_poly_mesh(r, C("asphalt_dark"), 0.05, 0.0, land_mat, false)


func _quays() -> void:
	# vieux quai : x ∈ [-36, 0] (le dernier segment vient avec la zone 2) ; quai n°2 (T2) : x ∈ [0, 36] ; quais 3-4 (T3) : x ∈ [48, 144]
	var segs: Array = [-30.0, -18.0]
	if tier >= 2:
		segs += [-6.0, 6.0, 18.0, 30.0]
	if tier >= 3:
		for x in range(54, 145, 12):
			segs.append(float(x))
	for x in segs:
		var q := _inst("quay", vcol)
		q.position = Vector3(x, 0, -3)
	for x in [-45.0, -39.0]:
		var e := _inst("quay_end", vcol)
		e.position = Vector3(x, 0, -3)
	if tier == 2:
		var e2 := _inst("quay_end", vcol)
		e2.position = Vector3(39.0, 0, -3)
	# écume au pied des quais
	var x0 := -48.0
	var x1 := (0.0 if tier == 1 else (42.0 if tier == 2 else 150.0))
	var m := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(x1 - x0, 1.6)
	qm.orientation = PlaneMesh.FACE_Y
	m.mesh = qm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/foam.gdshader")
	sm.set_shader_parameter("foam", C("foam"))
	m.material_override = sm
	m.position = Vector3((x0 + x1) * 0.5, WATER_Y + 0.08, -6.8)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)


## Chenal balisé (rouge à bâbord, vert à tribord en entrant), bouées de mouillage, navire sur le chenal, remorqueur.
func _channel() -> void:
	for i in CHANNEL.size() - 1:
		var a: Vector3 = CHANNEL[i]
		var b: Vector3 = CHANNEL[i + 1]
		var d := (b - a).normalized()
		var left := Vector3(d.z, 0, -d.x)      # à gauche du cap, vu de dessus
		for t in [0.25, 0.75]:
			var p := a.lerp(b, t)
			var r := _inst("buoy", vcol)
			r.position = p + left * 7.0 + Vector3(0, WATER_Y, 0)
			var g := _inst("buoy_green", vcol)
			g.position = p - left * 7.0 + Vector3(0, WATER_Y, 0)
	for p in ANCHORAGE:
		var b := _inst("buoy", vcol)
		b.position = p + Vector3(0, WATER_Y, 0)
	# feux de passe : rouge côté cap, vert côté brise-lames
	var fr := _inst("buoy", vcol)
	fr.position = Vector3(-56, WATER_Y, -44)
	fr.scale = Vector3.ONE * 1.6
	var fg := _inst("buoy_green", vcol)
	fg.position = Vector3(-4, WATER_Y, -48)
	fg.scale = Vector3.ONE * 1.6
	# navire sur le chenal (entre la passe et le bassin d'évitage) et navire à quai
	_ship = _inst("ship_coaster", vcol)
	_tug = _inst("tug", vcol)
	_path.assign(CHANNEL)
	_ship_t = 0.55
	_place_ship()
	var moored := _inst("ship_mini" if tier == 1 else "ship_feeder", vcol)
	moored.position = Vector3(-24, WATER_Y, -6 - (2.1 if tier == 1 else 3.5) - 0.6)
	var waiting := _inst("ship_feeder", vcol)
	waiting.position = ANCHORAGE[1] + Vector3(0, WATER_Y, 0)
	waiting.rotation.y = 0.4


func _place_ship() -> void:
	var total := 0.0
	var lens: Array[float] = []
	for i in _path.size() - 1:
		var l: float = _path[i].distance_to(_path[i + 1])
		lens.append(l)
		total += l
	var s := _ship_t * total
	for i in lens.size():
		if s <= lens[i] or i == lens.size() - 1:
			var a: Vector3 = _path[i]
			var b: Vector3 = _path[i + 1]
			var d := (b - a).normalized()
			_ship.position = a + d * s + Vector3(0, WATER_Y, 0)
			_ship.rotation.y = atan2(-d.z, d.x)
			_tug.position = _ship.position + d * 17.0
			_tug.rotation.y = _ship.rotation.y
			return
		s -= lens[i]


func _props() -> void:
	for p in PROPS:
		if int(p.get("t", 1)) > tier:
			continue
		var gray := false
		if p.has("z"):
			for z in ZONES:
				if int(z.id) == int(p.z):
					var st := zone_state(z)
					if st == "gray" or (z.has("reclaim") and tier < 3):
						gray = true
		if gray and p.has("z") and (int(p.z) == 10 or int(p.z) == 11):
			continue       # pas de bâtiment posé sur l'eau avant le terre-plein
		var n := _inst(String(p.m), vcol_gray if gray else vcol)
		n.position = p.p
		n.rotation.y = deg_to_rad(float(p.get("ry", 0.0)))
		if p.has("s"):
			n.scale = Vector3.ONE * float(p.s)


## Végétation : cap, collines, bords, hors zones et routes.
func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var coast := PackedVector2Array(COAST)
	var avoid: Array = []
	for z in ZONES:
		if not z.poly.is_empty():
			avoid.append(PackedVector2Array(z.poly))
	for r in ROADS:
		avoid.append(PackedVector2Array(r))
	avoid.append(PackedVector2Array([Vector2(-126, 66), Vector2(-24, 66), Vector2(-24, 138), Vector2(-126, 138)]))
	avoid.append(PackedVector2Array([Vector2(-48, -6), Vector2(48, -6), Vector2(48, 50), Vector2(-48, 50)]))
	var mm_by := {}
	var tries := 0
	var count := 0
	while count < 220 and tries < 4000:
		tries += 1
		var p := Vector2(rng.randf_range(-130, 184), rng.randf_range(-44, 166))
		if not Geometry2D.is_point_in_polygon(p, coast):
			continue
		var bad := false
		for a in avoid:
			if Geometry2D.is_point_in_polygon(p, a):
				bad = true
				break
		if bad:
			continue
		var pick := rng.randf()
		var m := "tree" if pick < 0.6 else ("bush" if pick < 0.85 else "rock")
		if not mm_by.has(m):
			mm_by[m] = []
		mm_by[m].append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), Vector3(p.x, 0, p.y)))
		count += 1
	for m in mm_by:
		var mesh := _mesh(m)
		if mesh == null:
			continue
		var arr: Array = mm_by[m]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = arr.size()
		for i in arr.size():
			mm.set_instance_transform(i, arr[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = vcol
		add_child(mi)


# ---------------------------------------------------------------------------
# Modèles
# ---------------------------------------------------------------------------
var _scenes := {}


func _inst(name: String, mat: Material) -> Node3D:
	if not _scenes.has(name):
		_scenes[name] = load("res://assets/models/%s.glb" % name) if ResourceLoader.exists("res://assets/models/%s.glb" % name) else null
	var ps: PackedScene = _scenes[name]
	if ps == null:
		push_warning("absent : " + name)
		var e := Node3D.new()
		add_child(e)
		return e
	var n: Node3D = ps.instantiate()
	_apply(n, mat)
	add_child(n)
	return n


func _apply(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for c in n.get_children():
		_apply(c, mat)


func _mesh(name: String) -> Mesh:
	var n := _inst(name, vcol)
	var found: Mesh = null
	var stack: Array[Node] = [n]
	while not stack.is_empty() and found == null:
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			found = (cur as MeshInstance3D).mesh
		for c in cur.get_children():
			stack.append(c)
	n.queue_free()
	return found


# ---------------------------------------------------------------------------
# Caméra (orthographique 35° / 45°, largeur visible = zoom) et capture
# ---------------------------------------------------------------------------
func _camera() -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = zoom
	cam.near = 1.0
	var half_h := zoom * 1920.0 / 1080.0 * 0.5
	var dist := maxf(160.0, half_h * cos(deg_to_rad(35.0)) / sin(deg_to_rad(35.0)) + 40.0)
	cam.far = dist + 500.0
	var basis := Basis.from_euler(Vector3(deg_to_rad(PITCH), deg_to_rad(YAW), 0.0))
	cam.transform = Transform3D(basis, look + basis.z * dist)
	add_child(cam)
	cam.make_current()


func _process(delta: float) -> void:
	_t += delta
	_ship_t = fmod(_ship_t + delta * 0.01, 1.0)
	_place_ship()


func _capture() -> void:
	var path := ""
	var delay := 1.5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			path = a.substr(10)
		elif a.begins_with("--delay="):
			delay = float(a.substr(8))
	if path == "":
		return
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("CAPTURE ", path, " ", img.get_size())
	get_tree().quit()
