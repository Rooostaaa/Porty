extends Node3D
## Galerie : tous les assets alignés à l'échelle réelle (vérifier tailles, couleurs, ombres).
##   Godot --path godot res://scenes/gallery.tscn -- --capture=docs/captures/gallery.png


func _ready() -> void:
	var meta: Variant = DataDB.load_json(Assets.DIR + "assets_meta.json")
	var names: Array = (meta as Dictionary).keys()
	names.sort()
	var x := 0.0
	var z := 0.0
	var row_depth := 0.0
	for n in names:
		var inst := Assets.instance(String(n))
		var aabb := _aabb(inst)
		if x + aabb.size.x > 120.0:
			x = 0.0
			z += row_depth + 4.0
			row_depth = 0.0
		inst.position = Vector3(x - aabb.position.x, 0, z - aabb.position.z)
		add_child(inst)
		x += aabb.size.x + 3.0
		row_depth = maxf(row_depth, aabb.size.z)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(300, 300)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#aeb8c6")
	ground.material_override = gm
	ground.position = Vector3(60, -0.02, 60)
	add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis.looking_at(Vector3(0.9, -1.5, 0.55).normalized(), Vector3.UP), Vector3.ZERO)
	sun.shadow_enabled = true
	add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#8fd0f0")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#dfe9ff")
	env.ambient_light_energy = 0.6
	we.environment = env
	add_child(we)
	var rig := CameraRig.new()
	add_child(rig)
	rig.bounds = Rect2(-50, -50, 300, 300)
	rig.zoom_max = 250.0
	rig.focus(Vector3(60, 0, z * 0.5))
	rig.target = rig.goal
	rig.zoom_goal = 150.0
	rig.zoom = 150.0
	Capture.schedule(self)


func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var b := mi.transform * mi.get_aabb()
		var p := mi.get_parent()
		while p != n and p is Node3D:
			b = (p as Node3D).transform * b
			p = p.get_parent()
		box = b if first else box.merge(b)
		first = false
	return box
