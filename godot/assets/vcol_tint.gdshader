shader_type spatial;
// Variante pour MultiMesh : la couleur d'instance (INSTANCE_CUSTOM, en linéaire) multiplie la couleur de sommet.
// Sans brillant, comme vcol.gdshader.

uniform float vertex_is_srgb = 0.0;
varying vec3 inst_tint;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	inst_tint = INSTANCE_CUSTOM.rgb;
}

void fragment() {
	vec3 c = COLOR.rgb;
	if (vertex_is_srgb > 0.5) {
		c = to_linear(c);
	}
	ALBEDO = c * inst_tint;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
