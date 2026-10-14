class_name BoostButton
extends Button
## Heures sup en bouton rond flottant (lot D-UI) : gros disque ambre qui respire quand elles sont prêtes, vert avec l'anneau
## du temps restant quand elles tournent, petit disque gris discret avec l'anneau de recharge sinon. La zone de toucher
## reste de 120 px même quand le disque est petit.

const HIT := 120.0

var state := "recharge"            # "pret" | "actif" | "recharge"
var progress := 0.0                # anneau : recharge faite (recharge) ou temps restant (actif), 0..1
var caption := ""                  # « ×2 », « 25 s »
var _t := 0.0


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	custom_minimum_size = Vector2(HIT, HIT)
	size = Vector2(HIT, HIT)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	tooltip_text = "Heures sup"


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var ready := state == "pret"
	var active := state == "actif"
	var r := 60.0 if ready else (54.0 if active else 38.0)
	if ready:
		r *= 1.0 + 0.05 * sin(_t * 5.0)         # « touche-moi » : il respire
	var col := UI.AMBER if ready else (UI.MONEY if active else Color(0.55, 0.57, 0.68, 0.85))
	draw_circle(c + Vector2(0, 5), r, Color(0, 0, 0, 0.18))
	draw_circle(c, r, col)
	if ready:
		draw_arc(c, r - 4.0, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 5.0, true)
	elif progress > 0.0:
		draw_arc(c, r - 5.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(progress, 0.0, 1.0), 48, Color(1, 1, 1, 0.9), 6.0, true)
	var tex := UI.icon_tex("boost")
	var isz := 46.0 if ready else (38.0 if active else 30.0)
	if tex != null:
		var ip := c - Vector2(isz * 0.5, isz * 0.5 + (12.0 if caption != "" and (ready or active) else 0.0))
		draw_texture_rect(tex, Rect2(ip, Vector2(isz, isz)), false, Color(1, 1, 1, 1.0 if (ready or active) else 0.8))
	if caption != "" and (ready or active) and UI.font != null:
		var fs := 28
		var w := UI.font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(UI.font, c + Vector2(-w * 0.5, isz * 0.5 + 20.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE if active else UI.TEXT)
