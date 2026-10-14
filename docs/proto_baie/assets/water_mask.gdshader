shader_type spatial;
// Eau du prototype : même dégradé que water.gdshader, mais la distance au rivage vient d'une texture de distance
// calculée une fois à partir des polygones de terre (côte quelconque au lieu de rectangles).

uniform vec4 shore : source_color = vec4(0.55, 0.82, 0.93, 1.0);
uniform vec4 shallow : source_color = vec4(0.25, 0.64, 0.86, 1.0);
uniform vec4 deep : source_color = vec4(0.16, 0.44, 0.72, 1.0);
uniform vec4 sparkle : source_color = vec4(0.9, 0.97, 1.0, 1.0);
uniform sampler2D dist_tex : filter_linear, repeat_disable;
uniform vec4 mask_rect = vec4(-200.0, -230.0, 260.0, 230.0);   // x0, z0, x1, z1 du monde couvert par la texture
uniform float shore_width = 7.0;
uniform float deep_start = 14.0;
uniform float deep_full = 70.0;

varying vec3 wp;

float shore_dist(vec2 p) {
	vec2 uv = (p - mask_rect.xy) / (mask_rect.zw - mask_rect.xy);
	return texture(dist_tex, uv).r;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wp.x * 0.12 + TIME * 0.9) * 0.07 + cos(wp.z * 0.17 + TIME * 1.1) * 0.07;
}

void fragment() {
	float d = shore_dist(wp.xz);
	d += sin(wp.x * 0.45 + TIME * 0.5) * 0.6 + cos(wp.z * 0.38 - TIME * 0.4) * 0.6;
	vec3 c = mix(shore.rgb, shallow.rgb, smoothstep(0.0, shore_width, d));
	c = mix(c, deep.rgb, smoothstep(deep_start, deep_full, d));
	c = mix(c, sparkle.rgb, (1.0 - smoothstep(0.0, 1.6, d)) * 0.35);
	float n = sin(wp.x * 0.35 + TIME * 0.8) * cos(wp.z * 0.28 - TIME * 0.6) + 0.5 * sin((wp.x + wp.z) * 0.6 - TIME * 1.4);
	c = mix(c, sparkle.rgb, smoothstep(1.3, 1.45, n) * 0.22);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.05;
}
