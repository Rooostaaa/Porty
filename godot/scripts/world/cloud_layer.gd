class_name CloudLayer
extends Node3D
## Lot G1 — les nuages de la Crique (cadrage § 5.1, § 12 Q5) : pendant le chapitre 1, tout ce qui n'est pas l'anse est sous
## des bancs de nuages épais (la friche à l'est du cap, le bassin, la terre au sud, le large au-delà du passage du caboteur).
## Bancs posés sur une grille (Layout.CLOUD_COVER moins Layout.CLOUD_HOLE), dérive lente, dissolution par shader (fondu +
## montée, DISSOLVE_S) à la Concession ; jamais recréés ensuite. Modèle `cloud_bank` / `cloud_puff` s'il est livré, sinon une
## primitive : des demi-sphères basse définition sur une dalle (face du dessous plate, aucune face à l'intérieur).

const DISSOLVE_S := 3.5
const SHEET_Y := 6.5                  # u : la nappe, sous le bas des bancs (CLOUD_Y − 1)
const SHEET_CELL := 12.0
const DRIFT := Vector2(3.0, 2.0)       # u : amplitude de la dérive
const DRIFT_T := Vector2(23.0, 31.0)   # s : période de la dérive

var banks: MultiMeshInstance3D
var puffs: MultiMeshInstance3D
var sheet: MeshInstance3D            # lot G1-d : nappe basse et continue sous les bancs (le verrou est opaque à tous les zooms)
var sheet_tris := 0
var mat: ShaderMaterial
var bank_count := 0
var puff_count := 0
var dissolving := false
var dissolve := 0.0                   # 0 → 1 pendant la dissolution
var gone := false                     # dissolution finie : le nœud se libère
var primitive := false                # (rapport) modèle absent, primitive
var _t := 0.0

const SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;
uniform float dissolve = 0.0;
uniform vec3 tint : source_color = vec3(0.97, 0.98, 1.0);
uniform float rise = 14.0;
void vertex() {
	VERTEX.y += dissolve * rise;
}
void fragment() {
	ALBEDO = tint * mix(1.0, 0.9, clamp(-NORMAL.y, 0.0, 1.0));
	ALPHA = (1.0 - dissolve) * 0.98;
	ROUGHNESS = 1.0;
}
"""


func _ready() -> void:
	name = "clouds"
	var sh := Shader.new()
	sh.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	_build()


## Un banc : demi-sphères (8 segments, 3 anneaux) sur une dalle plate, toutes dans un seul maillage.
static func _bank_mesh(size: Vector2, seed_v: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var domes: Array = []
	var nx := 4
	var nz := 2
	for i in nx:
		for j in nz:
			var cx := (float(i) + 0.5) / float(nx) * size.x - size.x * 0.5 + rng.randf_range(-1.5, 1.5)
			var cz := (float(j) + 0.5) / float(nz) * size.y - size.y * 0.5 + rng.randf_range(-1.0, 1.0)
			var r := rng.randf_range(0.42, 0.55) * size.y
			domes.append([Vector3(cx, 0, cz), r, rng.randf_range(0.55, 0.8)])
	for d in domes:
		_dome(st, d[0], float(d[1]), float(d[2]))
	# la dalle du dessous (face vers le bas : vue d'en dessous, jamais ; elle ferme le banc)
	var hx := size.x * 0.5 + 1.0
	var hz := size.y * 0.5 + 1.0
	var y := 0.0
	var quad := [Vector3(-hx, y, -hz), Vector3(hx, y, -hz), Vector3(hx, y, hz), Vector3(-hx, y, hz)]
	st.set_normal(Vector3.DOWN)
	st.add_vertex(quad[0])
	st.add_vertex(quad[2])
	st.add_vertex(quad[1])
	st.add_vertex(quad[0])
	st.add_vertex(quad[3])
	st.add_vertex(quad[2])
	# et une dalle fine vue du dessus entre les dômes (rien ne passe entre eux)
	st.set_normal(Vector3.UP)
	var y2 := 0.6
	var top := [Vector3(-hx, y2, -hz), Vector3(hx, y2, -hz), Vector3(hx, y2, hz), Vector3(-hx, y2, hz)]
	st.add_vertex(top[0])
	st.add_vertex(top[1])
	st.add_vertex(top[2])
	st.add_vertex(top[0])
	st.add_vertex(top[2])
	st.add_vertex(top[3])
	return st.commit()


static func _dome(st: SurfaceTool, c: Vector3, r: float, h: float) -> void:
	var segs := 8
	var rings := 3
	for i in rings:
		var a0 := PI * 0.5 * float(i) / float(rings)
		var a1 := PI * 0.5 * float(i + 1) / float(rings)
		for j in segs:
			var b0 := TAU * float(j) / float(segs)
			var b1 := TAU * float(j + 1) / float(segs)
			var p00 := c + Vector3(cos(b0) * cos(a0) * r, sin(a0) * r * h, sin(b0) * cos(a0) * r)
			var p10 := c + Vector3(cos(b1) * cos(a0) * r, sin(a0) * r * h, sin(b1) * cos(a0) * r)
			var p01 := c + Vector3(cos(b0) * cos(a1) * r, sin(a1) * r * h, sin(b0) * cos(a1) * r)
			var p11 := c + Vector3(cos(b1) * cos(a1) * r, sin(a1) * r * h, sin(b1) * cos(a1) * r)
			var n := ((p10 - p00).cross(p01 - p00)).normalized()
			if n.y < 0.0:
				n = -n
			st.set_normal(n)
			st.add_vertex(p00)
			st.add_vertex(p01)
			st.add_vertex(p10)
			if i < rings - 1:
				st.add_vertex(p10)
				st.add_vertex(p01)
				st.add_vertex(p11)


func _build() -> void:
	var size := Layout.CLOUD_BANK
	var mesh: Mesh = null
	if Assets.exists("cloud_bank"):
		mesh = Assets.mesh("cloud_bank")
	if mesh == null:
		primitive = true
		mesh = _bank_mesh(size, 7)
	var pmesh: Mesh = null
	if Assets.exists("cloud_puff"):
		pmesh = Assets.mesh("cloud_puff")
	if pmesh == null:
		pmesh = _bank_mesh(Vector2(8.0, 5.0), 11)
	# bancs : une grille sur le rectangle habillé, sauf le trou de l'anse (un banc dont le centre tombe dans le trou est omis,
	# et un banc qui chevauche le trou est remplacé par des nuages isolés sur sa partie couverte)
	var cover := Layout.CLOUD_COVER
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var xf: Array[Transform3D] = []
	var pxf: Array[Transform3D] = []
	var x := cover.position.x
	while x < cover.end.x:
		var z := cover.position.y
		while z < cover.end.y:
			var c := Vector2(x + size.x * 0.5, z + size.y * 0.5)
			var corners := [Vector2(x, z), Vector2(x + size.x, z), Vector2(x, z + size.y), Vector2(x + size.x, z + size.y)]
			var inside := 0
			for q in corners:
				if Layout.in_cloud_hole(q):
					inside += 1
			if inside == 0 and not Layout.in_cloud_hole(c):
				var b := Basis.from_euler(Vector3(0, rng.randf_range(-0.08, 0.08), 0)).scaled(Vector3(rng.randf_range(0.95, 1.1), rng.randf_range(0.8, 1.2), rng.randf_range(0.95, 1.1)))
				xf.append(Transform3D(b, Vector3(c.x + rng.randf_range(-1.5, 1.5), Layout.CLOUD_Y + rng.randf_range(-1.0, 1.5), c.y + rng.randf_range(-1.0, 1.0))))
			elif inside < 4:
				# le bord du trou : des nuages isolés sur les parties couvertes du banc
				for k in 6:
					var q := Vector2(x + rng.randf_range(0.0, size.x), z + rng.randf_range(0.0, size.y))
					if not Layout.in_cloud_hole(q):
						var pb := Basis.from_euler(Vector3(0, rng.randf_range(-0.6, 0.6), 0)).scaled(Vector3.ONE * rng.randf_range(0.9, 1.4))
						pxf.append(Transform3D(pb, Vector3(q.x, Layout.CLOUD_Y - 1.5 + rng.randf_range(-0.5, 0.5), q.y)))
			z += size.y
		x += size.x
	banks = _multi(mesh, xf)
	bank_count = xf.size()
	puffs = _multi(pmesh, pxf)
	puff_count = pxf.size()
	_build_sheet()


## La nappe : un quadrillage de cellules plates à SHEET_Y sur toute la couverture, sauf le trou (cellules à cheval : découpées en
## 3 × 3, on garde les sous-cellules dont le centre est couvert). Rien ne se voit entre les bancs ; la dissolution l'emporte aussi.
func _build_sheet() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var cover := Layout.CLOUD_COVER
	var n := 0
	var x := cover.position.x
	while x < cover.end.x:
		var z := cover.position.y
		while z < cover.end.y:
			var r := Rect2(x, z, SHEET_CELL, SHEET_CELL)
			var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.get_center()]
			var inside := 0
			for q in corners:
				if Layout.in_cloud_hole(q):
					inside += 1
			if inside == 0:
				n += _sheet_quad(st, r)
			elif inside < 5:
				var k := 3
				for i in k:
					for j in k:
						var sr := Rect2(x + SHEET_CELL * float(i) / float(k), z + SHEET_CELL * float(j) / float(k), SHEET_CELL / float(k), SHEET_CELL / float(k))
						if not Layout.in_cloud_hole(sr.get_center()):
							n += _sheet_quad(st, sr)
			z += SHEET_CELL
		x += SHEET_CELL
	sheet = MeshInstance3D.new()
	sheet.mesh = st.commit()
	sheet.material_override = mat
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sheet)
	sheet_tris = n


static func _sheet_quad(st: SurfaceTool, r: Rect2) -> int:
	var y := SHEET_Y
	st.add_vertex(Vector3(r.position.x, y, r.position.y))
	st.add_vertex(Vector3(r.end.x, y, r.position.y))
	st.add_vertex(Vector3(r.end.x, y, r.end.y))
	st.add_vertex(Vector3(r.position.x, y, r.position.y))
	st.add_vertex(Vector3(r.end.x, y, r.end.y))
	st.add_vertex(Vector3(r.position.x, y, r.end.y))
	return 2


func _multi(mesh: Mesh, xf: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## La Concession : les nuages se dissolvent (fondu + montée), puis le nœud se libère.
func start_dissolve() -> void:
	if dissolving or gone:
		return
	dissolving = true
	var tw := create_tween()
	tw.tween_property(self, "dissolve", 1.0, DISSOLVE_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		gone = true
		queue_free())


func _process(delta: float) -> void:
	_t += delta
	position = Vector3(DRIFT.x * sin(_t * TAU / DRIFT_T.x), 0.0, DRIFT.y * sin(_t * TAU / DRIFT_T.y))
	if mat != null:
		mat.set_shader_parameter("dissolve", dissolve)
