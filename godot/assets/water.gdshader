shader_type spatial;
// Eau stylisée : dégradé selon la distance au rivage (claire près des quais et des plages, profonde au large),
// vaguelettes, reflets doux. Les terres (polygones du plan coté : côte, brise-lames, terre-plein) sont rastérisées
// une fois dans une texture de distance par le diorama (Diorama.distance_texture), recalculée quand le terre-plein apparaît.

uniform vec4 shore : source_color = vec4(0.55, 0.82, 0.93, 1.0);    // bord de plage / pied de quai
uniform vec4 shallow : source_color = vec4(0.25, 0.64, 0.86, 1.0);  // eau côtière
uniform vec4 deep : source_color = vec4(0.16, 0.44, 0.72, 1.0);     // large
uniform vec4 sparkle : source_color = vec4(0.9, 0.97, 1.0, 1.0);
uniform sampler2D dist_tex : filter_linear, repeat_disable;
uniform vec4 mask_rect = vec4(-200.0, -230.0, 260.0, 230.0);        // x0, z0, x1, z1 du monde couvert par la texture
uniform float shore_width = 7.0;     // largeur (u) de la bande claire au pied des terres
uniform float deep_start = 14.0;     // distance (u) à partir de laquelle l'eau fonce
uniform float deep_full = 70.0;      // distance (u) où elle atteint la teinte du large

varying vec3 wp;

// Distance au rivage le plus proche (positive dans l'eau) ; hors de la texture : le large.
float shore_dist(vec2 p) {
	vec2 uv = (p - mask_rect.xy) / (mask_rect.zw - mask_rect.xy);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 200.0;
	}
	return texture(dist_tex, uv).r;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wp.x * 0.12 + TIME * 0.9) * 0.07 + cos(wp.z * 0.17 + TIME * 1.1) * 0.07;
}

void fragment() {
	float d = shore_dist(wp.xz);
	// la ligne de rivage ondule un peu pour ne pas dessiner un contour géométrique
	d += sin(wp.x * 0.45 + TIME * 0.5) * 0.6 + cos(wp.z * 0.38 - TIME * 0.4) * 0.6;
	vec3 c = mix(shore.rgb, shallow.rgb, smoothstep(0.0, shore_width, d));
	c = mix(c, deep.rgb, smoothstep(deep_start, deep_full, d));
	// liseré clair au contact des terres (en plus de l'écume des quais)
	c = mix(c, sparkle.rgb, (1.0 - smoothstep(0.0, 1.6, d)) * 0.35);
	float n = sin(wp.x * 0.35 + TIME * 0.8) * cos(wp.z * 0.28 - TIME * 0.6) + 0.5 * sin((wp.x + wp.z) * 0.6 - TIME * 1.4);
	c = mix(c, sparkle.rgb, smoothstep(1.3, 1.45, n) * 0.22);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.05;
}
