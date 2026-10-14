shader_type spatial;
// Matériau partagé : la couleur de sommet (exportée par Blender) sert d'albédo.
// vertex_is_srgb : 1 si les couleurs arrivent encodées sRGB (réglé par le test du nuancier).
// Aucun brillant (rugosité 1, spéculaire 0) : les aplats restent fidèles à la palette, seul l'ombrage par face
// (dessus 100 %, flancs 65–75 %) et les ombres portées modèlent les volumes (règle 7 du brief).

uniform float vertex_is_srgb = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float desat = 0.0;          // 1 = gris neutre (entrepôts du village avant le T3)
uniform float flash = 0.0;          // surbrillance (sélection, goulot)
uniform float degreen = 0.0;        // 1 : les pièces vertes deviennent grises (feu vert du brise-lames : le vert est au cap)
uniform vec4 flash_color : source_color = vec4(1.0, 0.3, 0.25, 1.0);

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec3 c = COLOR.rgb;
	if (vertex_is_srgb > 0.5) {
		c = to_linear(c);
	}
	c *= tint.rgb;
	if (degreen > 0.5 && c.g > c.r * 1.3 && c.g > c.b * 1.15) {
		c = vec3(dot(c, vec3(0.2126, 0.7152, 0.0722)) * 0.9);
	}
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(c, vec3(lum), desat);
	ALBEDO = mix(c, flash_color.rgb, flash * 0.45);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = flash_color.rgb * flash * 0.25;
}
