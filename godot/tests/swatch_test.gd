extends Node3D
## Test du nuancier : compare les couleurs de sommet rendues à la palette sRGB.
##   Godot --path godot res://tests/swatch_test.tscn
## Rangées 0 et 1 : non éclairées (vertex_is_srgb 0 / 1). Rangée 2 (lot B) : matériau du jeu sous la lumière du diorama
## (Diorama.make_environment / make_sun) : un dessus au soleil doit rendre la palette sans dérive (erreur ≤ 3/255 par canal).

const KEYS := ["red", "yellow", "blue", "green", "grass", "water", "gravel", "asphalt", "white", "dark"]

var cam: Camera3D


func _ready() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded;
uniform float vertex_is_srgb = 0.0;
vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c)); }
void fragment() { vec3 c = COLOR.rgb; if (vertex_is_srgb > 0.5) { c = to_linear(c); } ALBEDO = c; }
"""
	for flag in [0.0, 1.0]:
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("vertex_is_srgb", flag)
		var n := Assets.instance("swatch", mat)
		n.position = Vector3(0, 0, flag * 2.0)
		add_child(n)
	# rangée éclairée : environnement et soleil du jeu, matériau partagé
	var we := WorldEnvironment.new()
	we.environment = Diorama.make_environment()
	add_child(we)
	add_child(Diorama.make_sun())
	var lit := Assets.instance("swatch")
	lit.position = Vector3(0, 0, 4.0)
	add_child(lit)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = 13.0
	cam.position = Vector3(5.4, 10, 2.0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	add_child(cam)
	cam.make_current()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := [0.0, 0.0, 0.0]
	var worst_lit := 0.0
	for i in KEYS.size():
		var want := Assets.color(KEYS[i])
		var line := "%-8s attendu %s" % [KEYS[i], want.to_html(false)]
		for f in 3:
			var p := cam.unproject_position(Vector3(i * 1.2, 0.2, f * 2.0))
			p = p * Vector2(img.get_size()) / get_viewport().get_visible_rect().size
			var got := img.get_pixelv(Vector2i(p))
			line += "  %s%d %s" % ["lit" if f == 2 else "flag", f, got.to_html(false)]
			var e := absf(got.r - want.r) + absf(got.g - want.g) + absf(got.b - want.b)
			err[f] += e
			if f == 2:
				worst_lit = maxf(worst_lit, maxf(absf(got.r - want.r), maxf(absf(got.g - want.g), absf(got.b - want.b))))
		print(line)
	print("ERREUR flag0 (linéaire) = %.3f   flag1 (sRGB) = %.3f   éclairé (dessus au soleil) = %.3f" % [err[0], err[1], err[2]])
	print("=> vertex_is_srgb = %d" % (0 if err[0] < err[1] else 1))
	print("=> dérive maximale d'un canal au soleil : %.1f/255 (%s)" % [worst_lit * 255.0, "ok" if worst_lit * 255.0 <= 3.0 else "DÉRIVE"])
	get_tree().quit()
