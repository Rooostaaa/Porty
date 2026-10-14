shader_type spatial;
// faces avant seulement (revue C7 C3) : les triangles du terrain sont orientés par Terrain.poly_mesh
// Terrain polygonal du plan coté (continent, sols des zones, terre-plein) : couleur de sommet en linéaire (comme vcol),
// désaturation des zones grisées, vague de couleur à l'ouverture d'une zone, apparition progressive du terre-plein.

uniform vec4 tint : source_color = vec4(1.0);
uniform float desat = 0.0;            // zone grisée : 0,8
uniform float veil = 0.0;             // zone grisée : voile clair (0,4)
uniform vec2 wave_center = vec2(0.0);  // ouverture : la couleur gagne depuis ce point…
uniform float wave_r = 1e6;            // …jusqu'à ce rayon (au-delà : gris de la zone à venir)
uniform float wave_desat = 0.0;
uniform vec2 reveal_from = vec2(0.0);  // terre-plein : le sable avance (rien n'est dessiné au-delà de reveal_r)
uniform float reveal_r = 1e6;
uniform vec4 flash_color : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform float flash = 0.0;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (distance(wp.xz, reveal_from) > reveal_r) {
		discard;
	}
	vec3 c = COLOR.rgb * tint.rgb;
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	float ds = desat;
	float w = distance(wp.xz, wave_center);
	ds = max(ds, wave_desat * smoothstep(wave_r - 3.0, wave_r, w));
	c = mix(c, vec3(lum), ds);
	// voile clair : plein sur une zone à venir (desat > 0), et derrière la vague pendant une ouverture
	float gray_k = max(step(0.001, desat), step(0.001, wave_desat) * smoothstep(wave_r - 3.0, wave_r, w));
	c = mix(c, vec3(0.86, 0.86, 0.9), veil * gray_k);
	ALBEDO = mix(c, flash_color.rgb, flash * 0.35);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
