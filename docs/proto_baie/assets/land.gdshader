shader_type spatial;
render_mode cull_disabled;
// Terrain polygonal du prototype : couleur de sommet, désaturation pour les zones grisées (même logique que vcol.gdshader).

uniform vec4 tint : source_color = vec4(1.0);
uniform float desat = 0.0;

void fragment() {
	vec3 c = COLOR.rgb * tint.rgb;
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = mix(c, vec3(lum), desat);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
