class_name Terrain
extends RefCounted
## Terrain polygonal construit dans Godot (plan coté, pas de côte Blender) : dessus coloré et flancs en couches de terre
## (même aspect que les dalles Blender), pointillés des zones, texture de distance au rivage pour l'eau.
## Les couleurs de palette.json (sRGB) sont passées en linéaire, comme les couleurs de sommet exportées par Blender.

## Couches de terre des flancs : [haut, bas, couleur] (sous le dessus, en u).
const BANDS := [[0.0, -1.15, "earth"], [-1.15, -2.4, "earth_dark"]]
## Zone à venir : sa teinte de quartier reste lisible (désaturation partielle) sous un voile clair (revue du 13/10).
const ZONE_DESAT := 0.55
const ZONE_VEIL := 0.25

static var land_material: ShaderMaterial
static var gray_material: ShaderMaterial


static func _ensure() -> void:
	if land_material != null:
		return
	land_material = ShaderMaterial.new()
	land_material.shader = load("res://assets/land.gdshader")
	gray_material = land_material.duplicate()
	gray_material.set_shader_parameter("desat", ZONE_DESAT)
	gray_material.set_shader_parameter("veil", ZONE_VEIL)
	gray_material.set_shader_parameter("tint", Color(1, 1, 1))


## Couleur de palette (ou « #rrggbb ») en linéaire, pour une couleur de sommet.
static func lin(key: String) -> Color:
	var c := Color(key) if key.begins_with("#") else Assets.color(key)
	return c.srgb_to_linear()


## Dessus d'un polygone (x, z) à la hauteur y, avec ses flancs (profondeur depth) si demandé.
static func poly_mesh(poly: Array, top: Color, y: float, depth: float, mat: Material) -> MeshInstance3D:
	_ensure()
	var pts := PackedVector2Array(poly)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := Geometry2D.triangulate_polygon(pts)
	st.set_normal(Vector3.UP)
	st.set_color(top)
	for t in range(0, idx.size() - 2, 3):
		_tri(st, Vector3(pts[idx[t]].x, y, pts[idx[t]].y), Vector3(pts[idx[t + 1]].x, y, pts[idx[t + 1]].y),
			Vector3(pts[idx[t + 2]].x, y, pts[idx[t + 2]].y), Vector3.UP)
	if depth > 0.0:
		var ccw := _area(pts) > 0.0
		for e in pts.size():
			var a := pts[e]
			var b := pts[(e + 1) % pts.size()]
			var nrm := Vector3(b.y - a.y, 0, -(b.x - a.x)).normalized()
			if not ccw:
				nrm = -nrm
			for band in BANDS:
				var y0: float = y + float(band[0])
				var y1: float = maxf(y - depth, y + float(band[1]))
				if y1 >= y0:
					continue
				st.set_normal(nrm)
				st.set_color(lin(String(band[2])))
				var p0 := Vector3(a.x, y0, a.y)
				var p1 := Vector3(b.x, y0, b.y)
				var p2 := Vector3(b.x, y1, b.y)
				var p3 := Vector3(a.x, y1, a.y)
				_tri(st, p0, p1, p2, nrm)
				_tri(st, p0, p2, p3, nrm)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat if mat != null else land_material
	return mi


## Triangle tourné vers `n` (Godot : face avant = sommets dans le sens horaire vue de face). Le terrain n'est plus rendu
## « deux faces » : un flanc à l'envers était éclairé par sa normale retournée (revue C7 C3).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (c - a).cross(b - a).dot(n) < 0.0:
		var t := b
		b = c
		c = t
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


## Aire signée (x, z) : le sens de parcours décide de l'orientation des flancs.
static func _area(pts: PackedVector2Array) -> float:
	var a := 0.0
	for i in pts.size():
		var p := pts[i]
		var q := pts[(i + 1) % pts.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


## Pointillés le long d'un contour fermé (zone grisée, future terre tracée sur l'eau), couleur de sommet blanche.
static func dashes(poly: Array, y: float, width: float, dash: float, gap: float, mat: Material) -> MeshInstance3D:
	var pts := PackedVector2Array(poly)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	st.set_color(Color.WHITE)
	for e in pts.size():
		var a := pts[e]
		var b := pts[(e + 1) % pts.size()]
		var l := a.distance_to(b)
		var dir := (b - a) / maxf(0.01, l)
		var side := Vector2(-dir.y, dir.x) * width * 0.5
		var s := 0.0
		while s < l:
			var e1 := minf(l, s + dash)
			var q0 := a + dir * s
			var q1 := a + dir * e1
			var v := [q0 + side, q1 + side, q1 - side, q0 - side]
			for k in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(Vector3(v[k].x, y, v[k].y))
			s += dash + gap
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Matériau des pointillés (non éclairé, transparent pour la pulsation de la zone prochaine).
static func dash_material(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Distance au rivage (u, positive dans l'eau, négative sur la terre) sur la grille MASK_N × MASK_N de Layout.MASK_RECT :
## rastérisation des polygones par balayage de lignes, puis transformée de distance de chanfrein (3-4), comme le prototype.
static func distance_field(polys: Array) -> PackedFloat32Array:
	var n := Layout.MASK_N
	var rect := Layout.MASK_RECT
	var cell := rect.size.x / float(n)
	var inside := PackedByteArray()
	inside.resize(n * n)
	for j in n:
		var z := rect.position.y + (float(j) + 0.5) * cell
		for poly in polys:
			var pts: PackedVector2Array = poly
			var xs: Array[float] = []
			for e in pts.size():
				var a := pts[e]
				var b := pts[(e + 1) % pts.size()]
				if (a.y <= z and b.y > z) or (b.y <= z and a.y > z):
					xs.append(a.x + (z - a.y) / (b.y - a.y) * (b.x - a.x))
			xs.sort()
			for k in range(0, xs.size() - 1, 2):
				var i0 := maxi(0, ceili((xs[k] - rect.position.x) / cell - 0.5))
				var i1 := mini(n - 1, floori((xs[k + 1] - rect.position.x) / cell - 0.5))
				for i in range(i0, i1 + 1):
					inside[j * n + i] = 1
	var big := 1e6
	var dist := PackedFloat32Array()
	dist.resize(n * n)
	for k in n * n:
		dist[k] = 0.0 if inside[k] == 1 else big
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
	for k in n * n:
		dist[k] = -cell if inside[k] == 1 else dist[k] / 3.0 * cell
	return dist


## Valeur du champ de distance en un point (x, z) du monde (plus proche cellule).
static func field_at(field: PackedFloat32Array, p: Vector2) -> float:
	var n := Layout.MASK_N
	var rect := Layout.MASK_RECT
	var cell := rect.size.x / float(n)
	var i := clampi(floori((p.x - rect.position.x) / cell), 0, n - 1)
	var j := clampi(floori((p.y - rect.position.y) / cell), 0, n - 1)
	return field[j * n + i]


## Texture du champ de distance, en demi-flottants (R16F) : le filtrage linéaire d'une texture R32F n'est pas garanti sur
## Android (revue C7 A8) ; en R16F l'erreur reste sous 0,25 u jusqu'à 512 u, invisible sur le dégradé (0–70 u).
static func distance_texture(field: PackedFloat32Array) -> ImageTexture:
	var n := Layout.MASK_N
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RF, field.to_byte_array())
	img.convert(Image.FORMAT_RH)
	return ImageTexture.create_from_image(img)
