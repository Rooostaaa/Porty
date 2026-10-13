extends Node3D
## Test de teinte MultiMesh (COLOR d'instance vs INSTANCE_CUSTOM) dans le rendu courant.

func _ready() -> void:
	var codes := {
		"custom": "shader_type spatial; render_mode unshaded; varying vec3 t; void vertex(){ t = INSTANCE_CUSTOM.rgb; } void fragment(){ ALBEDO = COLOR.rgb * t; }",
		"color": "shader_type spatial; render_mode unshaded; void fragment(){ ALBEDO = COLOR.rgb; }",
	}
	var i := 0
	for k in codes:
		var sh := Shader.new()
		sh.code = codes[k]
		var m := ShaderMaterial.new()
		m.shader = sh
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		var bm := BoxMesh.new()
		bm.size = Vector3(1, 0.2, 1)
		mm.mesh = bm
		mm.instance_count = 1
		mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(i * 2.0, 0, 0)))
		mm.set_instance_color(0, Color(1, 0, 0))
		mm.set_instance_custom_data(0, Color(0, 0, 1))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = m
		add_child(mi)
		i += 1
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = 5.0
	cam.position = Vector3(1, 10, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	add_child(cam)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	for k in 2:
		var p := cam.unproject_position(Vector3(k * 2.0, 0.1, 0)) * Vector2(img.get_size()) / get_viewport().get_visible_rect().size
		print(["custom", "color"][k], " -> ", img.get_pixelv(Vector2i(p)))
	get_tree().quit()
