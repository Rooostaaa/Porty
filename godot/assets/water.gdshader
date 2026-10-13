shader_type spatial;
// Eau stylisée : dégradé selon la distance au rivage (claire près des quais et des plages, profonde au large),
// vaguelettes, reflets doux. Les terres sont décrites par des rectangles (x0, z0, x1, z1) fournis par le diorama.

const int MAX_LAND = 12;

uniform vec4 shore : source_color = vec4(0.55, 0.82, 0.93, 1.0);    // bord de plage / pied de quai
uniform vec4 shallow : source_color = vec4(0.25, 0.64, 0.86, 1.0);  // eau côtière
uniform vec4 deep : source_color = vec4(0.16, 0.44, 0.72, 1.0);     // large
uniform vec4 sparkle : source_color = vec4(0.9, 0.97, 1.0, 1.0);
uniform vec4 land[MAX_LAND];
uniform int land_count = 0;
uniform float shore_width = 7.0;     // largeur (u) de la bande claire au pied des terres
uniform float deep_start = 14.0;     // distance (u) à partir de laquelle l'eau fonce
uniform float deep_full = 70.0;      // distance (u) où elle atteint la teinte du large

varying vec3 wp;

// Distance signée au rectangle de terre le plus proche (positive dans l'eau).
float shore_dist(vec2 p) {
	float d = 1e9;
	for (int i = 0; i < MAX_LAND; i++) {
		if (i >= land_count) {
			break;
		}
		vec2 c = (land[i].xy + land[i].zw) * 0.5;
		vec2 h = (land[i].zw - land[i].xy) * 0.5;
		vec2 q = abs(p - c) - h;
		d = min(d, length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0));
	}
	return d;
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
