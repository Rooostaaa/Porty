shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// Écume au contact des quais : bande blanche qui pulse.

uniform vec4 foam : source_color = vec4(0.92, 0.97, 1.0, 1.0);

void fragment() {
	float edge = 1.0 - UV.y;
	float wave = 0.5 + 0.5 * sin(UV.x * 40.0 + TIME * 2.0);
	ALBEDO = foam.rgb;
	ALPHA = clamp(edge * (0.55 + 0.35 * wave), 0.0, 0.9) * smoothstep(0.0, 0.15, UV.y);
}
