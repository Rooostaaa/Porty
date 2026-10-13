class_name Narrator
extends Control
## Portrait dessiné de la narratrice du tutoriel (la Capitaine Mathilde Roche) : quatre poses
## (« hello » accueil, « think » réflexion, « worry » inquiétude, « bravo »). Aucun fichier image.

const SKIN := Color("#F2C7A5")
const HAIR := Color("#6B3E26")
const NAVY := Color("#24306B")
const GOLD := Color("#FFB020")
const INK := Color("#2B2D42")

var pose := "hello":
	set(v):
		if v != pose:
			pose = v
			_bounce()
		queue_redraw()
var _t := 0.0


func _init(size_px: float = 132.0) -> void:
	custom_minimum_size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	if pose == "bravo" or pose == "worry":
		queue_redraw()


func _bounce() -> void:
	pivot_offset = custom_minimum_size * 0.5
	scale = Vector2(0.85, 0.85)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func _draw() -> void:
	var s := minf(size.x, size.y) / 132.0
	var c := Vector2(size.x * 0.5, size.y * 0.5)
	var bg := {"hello": Color("#CFE3FF"), "think": Color("#E5DDFF"), "worry": Color("#FFE0D6"), "bravo": Color("#D5F5E1")}
	draw_circle(c, 64.0 * s, bg.get(pose, Color("#CFE3FF")))
	# veste et col
	draw_circle(c + Vector2(0, 74) * s, 46.0 * s, NAVY)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 34) * s, c + Vector2(12, 34) * s, c + Vector2(0, 50) * s]), Color.WHITE)
	# cheveux (derrière le visage)
	draw_circle(c + Vector2(0, -2) * s, 33.0 * s, HAIR)
	draw_rect(Rect2(c + Vector2(-33, -2) * s, Vector2(66, 30) * s), HAIR)
	# visage
	draw_circle(c + Vector2(0, 4) * s, 27.0 * s, SKIN)
	# casquette de capitaine
	draw_colored_polygon(PackedVector2Array([c + Vector2(-34, -18) * s, c + Vector2(34, -18) * s, c + Vector2(28, -40) * s,
		c + Vector2(-28, -40) * s]), NAVY)
	draw_rect(Rect2(c + Vector2(-34, -20) * s, Vector2(68, 6) * s), Color.WHITE)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-30, -14) * s, c + Vector2(30, -14) * s, c + Vector2(22, -8) * s,
		c + Vector2(-22, -8) * s]), Color("#151C45"))
	draw_circle(c + Vector2(0, -30) * s, 5.0 * s, GOLD)
	# sourcils
	var by := -2.0
	match pose:
		"think":
			draw_line(c + Vector2(-16, by + 1) * s, c + Vector2(-6, by + 1) * s, HAIR, 3.0 * s)
			draw_line(c + Vector2(6, by - 4) * s, c + Vector2(16, by - 1) * s, HAIR, 3.0 * s)
		"worry":
			draw_line(c + Vector2(-16, by) * s, c + Vector2(-6, by - 4) * s, HAIR, 3.0 * s)
			draw_line(c + Vector2(6, by - 4) * s, c + Vector2(16, by) * s, HAIR, 3.0 * s)
		_:
			draw_line(c + Vector2(-16, by - 2) * s, c + Vector2(-6, by - 3) * s, HAIR, 3.0 * s)
			draw_line(c + Vector2(6, by - 3) * s, c + Vector2(16, by - 2) * s, HAIR, 3.0 * s)
	# yeux
	if pose == "bravo":
		draw_arc(c + Vector2(-11, 6) * s, 4.0 * s, PI, TAU, 8, INK, 2.5 * s)
		draw_arc(c + Vector2(11, 6) * s, 4.0 * s, PI, TAU, 8, INK, 2.5 * s)
	else:
		var look := Vector2(2, -1) if pose == "think" else Vector2.ZERO
		draw_circle(c + (Vector2(-11, 6) + look) * s, 3.2 * s, INK)
		draw_circle(c + (Vector2(11, 6) + look) * s, 3.2 * s, INK)
	# joues
	draw_circle(c + Vector2(-17, 14) * s, 4.0 * s, Color(1.0, 0.55, 0.55, 0.35))
	draw_circle(c + Vector2(17, 14) * s, 4.0 * s, Color(1.0, 0.55, 0.55, 0.35))
	# bouche
	match pose:
		"hello":
			draw_arc(c + Vector2(0, 14) * s, 8.0 * s, 0.2, PI - 0.2, 12, INK, 2.5 * s)
		"think":
			draw_line(c + Vector2(-5, 20) * s, c + Vector2(6, 18) * s, INK, 2.5 * s)
			_bubble(c + Vector2(40, -42) * s, s, "?")
		"worry":
			draw_arc(c + Vector2(0, 24) * s, 7.0 * s, PI + 0.4, TAU - 0.4, 12, INK, 2.5 * s)
			var drop := c + Vector2(24, -6 + 2.0 * sin(_t * 4.0)) * s
			draw_colored_polygon(PackedVector2Array([drop + Vector2(0, -7) * s, drop + Vector2(-4, 1) * s, drop + Vector2(4, 1) * s]), Color("#7FC4FF"))
			draw_circle(drop + Vector2(0, 2) * s, 4.0 * s, Color("#7FC4FF"))
		"bravo":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-10, 15) * s, c + Vector2(10, 15) * s, c + Vector2(0, 25) * s]), INK)
			for k in 3:
				var a := _t * 2.0 + float(k) * TAU / 3.0
				_star(c + Vector2(cos(a), sin(a)) * 54.0 * s, 7.0 * s)


func _bubble(p: Vector2, s: float, txt: String) -> void:
	draw_circle(p, 13.0 * s, Color.WHITE)
	draw_circle(p + Vector2(-12, 12) * s, 4.0 * s, Color.WHITE)
	var f := get_theme_default_font()
	if f != null:
		draw_string(f, p + Vector2(-5, 7) * s, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * s), UI.VIOLET)


func _star(p: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + float(i) * PI / 5.0
		pts.append(p + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, GOLD)
