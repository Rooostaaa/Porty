class_name CloudLayer
extends Node3D
## Lot G1, brume de la Crique (cadrage § 5.1, § 12 Q5 ; revue « voile », variante A) : pendant le chapitre 1, tout ce qui
## n'est pas l'anse est sous une brume (la friche à l'est du cap, le bassin, la terre au sud, le large). Un plan unique sur
## Layout.CLOUD_COVER, non éclairé et translucide : l'opacité vient de la distance aux rectangles de Layout.CLOUD_HOLE (nulle
## dans l'anse, fondu sur FEATHER u, ≈ DENSITY au cœur : le sol y devine encore ses formes), modulée par deux nappes de bruit
## de valeur (2 octaves) qui dérivent lentement à des vitesses différentes, avec des filaments plus clairs. Un seul appel de
## rendu, aucune particule. Le cadenas « Concession · prix » est dessiné par WorldOverlay (`_draw_lock`) ; le toucher passe par
## `lock_rect` (Diorama.lock_tapped). À la Concession, la brume se dissout (fondu, légère montée, éclaircissement, DISSOLVE_S),
## puis le nœud se libère ; jamais recréée ensuite.

const DISSOLVE_S := 3.5
const VEIL_Y := 1.5            # u : le plan, juste au-dessus du sol (sans test de profondeur : le bord du trou suit le sol)
const DENSITY := 0.72          # opacité au cœur de la zone verrouillée (avant modulation du bruit)
const EDGE_DENSITY := 0.58     # opacité au sortir du fondu, montant jusqu'à DENSITY à DEEP u du trou
const FEATHER := 12.0          # u : largeur du fondu au bord de l'anse
const DEEP := 36.0             # u : distance au trou où la brume atteint DENSITY
const RISE := 6.0              # u : montée pendant la dissolution
## Dérive des deux nappes (u/s) et taille de leurs motifs (u) : 38 u à ≈ 1,2 u/s, 22 u à ≈ 0,9 u/s (≥ 20 s pour qu'un motif passe).
const DRIFT_A := Vector2(1.0, 0.6)
const DRIFT_B := Vector2(-0.55, 0.7)
const SCALE_A := 38.0
const SCALE_B := 22.0
## Parcelle de la Concession (la friche de l'autre côté du cap : quai n°1, plateforme, cabane, barrière) : le cadenas s'y pose.
const CONCESSION_AT := Vector3(-24.0, 0.0, 20.0)

var veil: MeshInstance3D
var mat: ShaderMaterial
var dissolving := false
var dissolve := 0.0                   # 0 → 1 pendant la dissolution
var gone := false                     # dissolution finie : le nœud se libère
var lock_rect := Rect2()              # cadenas et sa bulle à l'écran (WorldOverlay, image courante) : un toucher dedans → AMÉLIORER

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix, shadows_disabled, fog_disabled;
uniform vec4 holes[3];                 // x0, z0, x1, z1
uniform vec3 tint : source_color = vec3(0.86, 0.9, 0.95);
uniform vec3 glow : source_color = vec3(1.0, 1.0, 1.0);
uniform float density = 0.72;
uniform float edge_density = 0.58;
uniform float feather = 12.0;
uniform float deep = 36.0;
uniform vec2 drift_a = vec2(1.0, 0.6);
uniform vec2 drift_b = vec2(-0.55, 0.7);
uniform float scale_a = 38.0;
uniform float scale_b = 22.0;
uniform float dissolve = 0.0;
uniform float rise = 6.0;
varying vec3 wp;

void vertex() {
	VERTEX.y += dissolve * rise;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float rect_d(vec2 p, vec4 r) {
	vec2 q = abs(p - (r.xy + r.zw) * 0.5) - (r.zw - r.xy) * 0.5;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm2(vec2 p) {
	return 0.65 * vnoise(p) + 0.35 * vnoise(p * 2.03 + vec2(17.0, 9.0));
}
void fragment() {
	vec2 p = wp.xz;
	float d = 1e6;
	for (int i = 0; i < 3; i++) d = min(d, rect_d(p, holes[i]));
	// deux nappes qui dérivent (coordonnées monde : la brume ne bouge pas avec la caméra)
	float na = fbm2((p - TIME * drift_a) / scale_a);
	float nb = fbm2((p - TIME * drift_b) / scale_b + vec2(5.2, 1.3));
	float n = 0.6 * na + 0.4 * nb;
	// bord de l'anse : fondu, irrégulier mais multiplicatif (nul dans le trou : l'anse reste nette)
	float e = smoothstep(0.0, 1.0, clamp(d / feather, 0.0, 1.0) * (0.7 + 0.6 * n));
	float a = e * mix(edge_density, density, smoothstep(feather, deep, d));
	a *= 0.76 + 0.48 * n;
	// filaments plus clairs : les crêtes de la petite nappe
	float fil = smoothstep(0.78, 0.95, 1.0 - abs(2.0 * nb - 1.0)) * smoothstep(0.35, 0.7, na);
	a = min(a + 0.12 * fil * e, 0.92);
	vec3 c = mix(tint, glow, clamp(0.25 + 0.75 * fil + 0.3 * (n - 0.5), 0.0, 1.0));
	ALBEDO = mix(c, glow, dissolve * 0.6);
	ALPHA = a * (1.0 - dissolve);
}
"""


func _ready() -> void:
	name = "clouds"
	var sh := Shader.new()
	sh.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	mat.render_priority = 10        # après l'eau (transparente elle aussi)
	var hs: Array[Vector4] = []
	for r in Layout.CLOUD_HOLE:
		var rr := r as Rect2
		hs.append(Vector4(rr.position.x, rr.position.y, rr.end.x, rr.end.y))
	mat.set_shader_parameter("holes", hs)
	mat.set_shader_parameter("density", DENSITY)
	mat.set_shader_parameter("edge_density", EDGE_DENSITY)
	mat.set_shader_parameter("feather", FEATHER)
	mat.set_shader_parameter("deep", DEEP)
	mat.set_shader_parameter("drift_a", DRIFT_A)
	mat.set_shader_parameter("drift_b", DRIFT_B)
	mat.set_shader_parameter("scale_a", SCALE_A)
	mat.set_shader_parameter("scale_b", SCALE_B)
	mat.set_shader_parameter("rise", RISE)
	var pm := PlaneMesh.new()
	var cover := Layout.CLOUD_COVER
	pm.size = cover.size
	veil = MeshInstance3D.new()
	veil.name = "veil"
	veil.mesh = pm
	veil.material_override = mat
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	veil.position = Vector3(cover.get_center().x, VEIL_Y, cover.get_center().y)
	add_child(veil)


## Distance (u) au trou de l'anse, 0 dedans.
static func hole_distance(p: Vector2) -> float:
	var d := INF
	for r in Layout.CLOUD_HOLE:
		var rr := r as Rect2
		var q := Vector2(maxf(maxf(rr.position.x - p.x, 0.0), p.x - rr.end.x), maxf(maxf(rr.position.y - p.y, 0.0), p.y - rr.end.y))
		d = minf(d, q.length())
	return d


## Opacité de la brume en p, sans le bruit (miroir du shader au bruit moyen) : 0 dans l'anse, DENSITY au cœur (tests, cadenas).
static func veil_alpha(p: Vector2) -> float:
	if not Layout.CLOUD_COVER.has_point(p):
		return 0.0
	var d := hole_distance(p)
	var e := smoothstep(0.0, 1.0, clampf(d / FEATHER, 0.0, 1.0))
	return e * lerpf(EDGE_DENSITY, DENSITY, smoothstep(FEATHER, DEEP, d))


## La Concession : la brume se dissout (fondu, montée, éclaircissement), puis le nœud se libère.
func start_dissolve() -> void:
	if dissolving or gone:
		return
	dissolving = true
	lock_rect = Rect2()
	var tw := create_tween()
	tw.tween_property(self, "dissolve", 1.0, DISSOLVE_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		gone = true
		queue_free())


func _process(_delta: float) -> void:
	if dissolving:
		mat.set_shader_parameter("dissolve", dissolve)
