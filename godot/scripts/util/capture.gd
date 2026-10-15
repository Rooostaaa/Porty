class_name Capture
extends RefCounted
## Capture d'écran automatique pour les vérifications :
##   Godot --path godot -- --capture=C:/chemin/image.png --delay=6 [--speed=4] [--debug-money=1e6] [--fresh]


static func args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return out


static func schedule(node: Node) -> void:
	var a := args()
	if not a.has("capture"):
		return
	var delay := float(a.get("delay", "5"))
	await node.get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var img := node.get_viewport().get_texture().get_image()
	var path := String(a.capture)
	img.save_png(path)
	print("CAPTURE ", path, " ", img.get_size(), " fps=", Engine.get_frames_per_second(),
		" primitives=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		" draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	var cams := node.get_tree().root.find_children("*", "CameraRig", true, false)
	if not cams.is_empty():
		print("CAMERA target=", cams[0].target, " zoom=", cams[0].zoom)
	if not a.has("keep"):
		node.get_tree().quit()
