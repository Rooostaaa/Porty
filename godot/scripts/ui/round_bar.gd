class_name RoundBar
extends Control
## Barre arrondie colorée (vert = argent, bleu = information, rouge = problème), texte optionnel centré.

var value: float = 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
var color: Color = UI.MONEY:
	set(v):
		color = v
		queue_redraw()
var text: String = "":
	set(v):
		text = v
		queue_redraw()
var bg: Color = Color("#E3E6F0")
var font_size: int = 26
var light_text: bool = false   # texte toujours clair (fond sombre)


func _init(h: float = 40.0) -> void:
	custom_minimum_size = Vector2(60, h)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := size.y * 0.5
	_rounded(Rect2(Vector2.ZERO, size), bg, r)
	if value > 0.001:
		var w := maxf(size.y, size.x * value)
		_rounded(Rect2(Vector2.ZERO, Vector2(w, size.y)), color, r)
		_rounded(Rect2(Vector2(r * 0.5, size.y * 0.16), Vector2(maxf(0.0, w - r), size.y * 0.22)), Color(1, 1, 1, 0.25), size.y * 0.11)
	if text != "":
		var f := UI.font if UI.font else get_theme_default_font()
		var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var p := Vector2((size.x - ts.x) * 0.5, (size.y + font_size * 0.72) * 0.5)
		draw_string(f, p + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.25))
		draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE if (value > 0.45 or light_text) else UI.TEXT)


func _rounded(r: Rect2, c: Color, rad: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(minf(rad, r.size.y * 0.5)))
	sb.anti_aliasing = true
	draw_style_box(sb, r)
