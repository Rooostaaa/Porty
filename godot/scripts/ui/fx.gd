class_name Fx
extends RefCounted
## Retours visuels d'interface : gerbe de particules, « pop » d'un contrôle, texte qui s'envole.
## Tout est ajouté à la couche des fenêtres du HUD (au-dessus des écrans) et se détruit seul.


static func _layer() -> Control:
	return Hud.main.popup_layer if Hud.main != null else null


## Centre (en coordonnées écran) d'un contrôle.
static func center_of(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


## Gerbe de confettis qui retombent.
static func burst(pos: Vector2, color: Color = UI.MONEY, count: int = 22, power: float = 1.0, size_mult: float = 1.0) -> void:
	var layer := _layer()
	if layer == null:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = 0.8
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.gravity = Vector2(0, 1100)
	p.initial_velocity_min = 340.0 * power
	p.initial_velocity_max = 620.0 * power
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 7.0 * size_mult
	p.scale_amount_max = 14.0 * size_mult
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([color.lightened(0.35), color, Color(color, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	p.color_ramp = ramp
	layer.add_child(p)
	p.global_position = pos
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(p.queue_free)


## Petit « pop » (le contrôle gonfle puis revient).
static func pop(c: Control, amount: float = 1.08) -> void:
	if c == null or not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(amount, amount), 0.07)
	tw.tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


## Texte qui monte et s'efface (ex. « +1 Ambre », « Palier ×2 ! »).
static func float_text(pos: Vector2, text: String, color: Color = UI.MONEY, size: int = 52) -> void:
	var layer := _layer()
	if layer == null:
		return
	var l := UI.label(text, size, color, true)
	l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.95))
	l.add_theme_constant_override("outline_size", 10)
	l.z_index = 10
	layer.add_child(l)
	l.global_position = pos - Vector2(l.get_minimum_size().x * 0.5, 40)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 130.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)


## Récompense complète sur un contrôle : gerbe + pop + texte.
static func reward(c: Control, text: String, color: Color = UI.MONEY, big: bool = false) -> void:
	var p := center_of(c)
	burst(p, color, 34 if big else 20, 1.25 if big else 1.0)
	if text != "":
		float_text(p + Vector2(0, -30), text, color, 60 if big else 48)


## Pièces qui volent d'un point de l'écran jusqu'au compteur (encaissement d'un navire, lot D-UI) ; `on_arrive` est appelé
## à l'arrivée de chaque pièce (le compteur pulse en encaissant).
static func coins(from: Vector2, to: Vector2, count: int = 7, on_arrive: Callable = Callable()) -> void:
	var layer := _layer()
	if layer == null:
		return
	var tex := UI.icon_tex("money")
	for i in count:
		var c := TextureRect.new()
		c.texture = tex
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c.size = Vector2(46, 46)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.z_index = 9
		layer.add_child(c)
		var start := from + Vector2(randf_range(-40.0, 40.0), randf_range(-30.0, 20.0)) - c.size * 0.5
		c.global_position = start
		c.modulate.a = 0.0
		# un petit arc : la pièce saute d'abord vers le haut puis file vers le compteur
		var mid := start.lerp(to - c.size * 0.5, 0.35) + Vector2(randf_range(-120.0, 120.0), -160.0)
		var end := to - c.size * 0.5
		var tw := c.create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(c, "modulate:a", 1.0, 0.08)
		var fly := func(t: float) -> void:
			var a := start.lerp(mid, t)
			var b := mid.lerp(end, t)
			c.global_position = a.lerp(b, t)
			c.scale = Vector2.ONE * lerpf(1.0, 0.6, t)
		tw.tween_method(fly, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if on_arrive.is_valid() and (i == 0 or i == count - 1 or i % 3 == 0):
			tw.tween_callback(on_arrive)
		tw.tween_callback(c.queue_free)


## Gerbe plein écran (cérémonie de palier) : plusieurs gerbes réparties sur la largeur, de couleurs alternées.
static func celebration(rect: Rect2, colors: Array = [UI.AMBER, UI.MONEY, UI.VIOLET, UI.INFO]) -> void:
	for i in 7:
		var p := Vector2(rect.position.x + rect.size.x * (0.1 + 0.8 * float(i) / 6.0), rect.position.y + rect.size.y * randf_range(0.35, 0.7))
		var col: Color = colors[i % colors.size()]
		burst(p, col, 46, 1.7, 1.8)
