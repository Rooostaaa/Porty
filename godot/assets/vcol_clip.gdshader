shader_type spatial;
// Variante de vcol.gdshader pour la rame de la gare (lot E-Flux, E12) : tout ce qui passe à l'est de clip_x (la bouche du
// tunnel, sous la colline) est découpé — le train entre et sort sous la colline au lieu d'apparaître à l'écran.
// Réservée au train : `discard` coûte sur mobile, le matériau partagé (vcol.gdshader) n'en a pas.

uniform float vertex_is_srgb = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float clip_x = 100000.0;
varying float world_x;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	world_x = (MODEL_MATRIX * vec4(VERTEX, 1.0)).x;
}

void fragment() {
	if (world_x > clip_x) {
		discard;
	}
	vec3 c = COLOR.rgb;
	if (vertex_is_srgb > 0.5) {
		c = to_linear(c);
	}
	ALBEDO = c * tint.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
