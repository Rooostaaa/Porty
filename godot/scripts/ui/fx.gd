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
static func burst(pos: Vector2, color: Color = UI.MONEY, count: int = 22, power: float = 1.0) -> void:
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
	p.scale_amount_min = 7.0
	p.scale_amount_max = 14.0
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
