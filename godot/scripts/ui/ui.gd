class_name UI
extends RefCounted
## Kit d'interface : thème (police ronde, cartes blanches arrondies) et constructeurs de widgets.
## Repère : 1080 px de large (portrait). Cibles tactiles ≥ 96 px.

const INDIGO := Color("#4B3FB5")
const INDIGO_DARK := Color("#372C93")
const VIOLET := Color("#6A4FD8")
const BG := Color("#EEF0F8")
const CARD := Color("#FFFFFF")
const TEXT := Color("#2B2D42")
const MUTED := Color("#8A8FA8")
const MONEY := Color("#2FB86A")
const INFO := Color("#3D8BEB")
const BAD := Color("#EB4D4B")
const AMBER := Color("#FFB020")
const GREY := Color("#C9CCD8")
const ORANGE := Color("#FF8A3D")

static var font: Font
static var font_num: Font
static var theme: Theme
static var _icons: Dictionary = {}


static func init_theme() -> Theme:
	if theme != null:
		return theme
	font = _pick_font(["Fredoka", "Fredoka One", "Nunito", "Segoe UI"], 800)
	font_num = _pick_font(["Lilita One", "Fredoka", "Segoe UI Black", "Segoe UI"], 900)
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 36
	theme.set_color("font_color", "Label", TEXT)
	for cls in ["Button", "CheckButton"]:
		theme.set_color("font_color", cls, Color.WHITE)
		theme.set_color("font_hover_color", cls, Color.WHITE)
		theme.set_color("font_pressed_color", cls, Color.WHITE)
		theme.set_color("font_disabled_color", cls, Color(1, 1, 1, 0.8))
		theme.set_font_size("font_size", cls, 36)
	var sb := flat(INDIGO, 28)
	theme.set_stylebox("normal", "Button", sb)
	theme.set_stylebox("hover", "Button", flat(INDIGO.lightened(0.08), 28))
	theme.set_stylebox("pressed", "Button", flat(INDIGO_DARK, 28))
	theme.set_stylebox("disabled", "Button", flat(GREY, 28))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	var sbg := flat(Color(0, 0, 0, 0.12), 8)
	theme.set_stylebox("scroll", "VScrollBar", sbg)
	theme.set_stylebox("grabber", "VScrollBar", flat(Color(0.3, 0.3, 0.5, 0.35), 8))
	theme.set_stylebox("grabber_highlight", "VScrollBar", flat(Color(0.3, 0.3, 0.5, 0.5), 8))
	theme.set_stylebox("grabber_pressed", "VScrollBar", flat(Color(0.3, 0.3, 0.5, 0.6), 8))
	theme.set_stylebox("slider", "HSlider", flat(GREY, 14, 0, 0, 14))
	theme.set_stylebox("grabber_area", "HSlider", flat(VIOLET, 14, 0, 0, 14))
	theme.set_stylebox("grabber_area_highlight", "HSlider", flat(VIOLET, 14, 0, 0, 14))
	theme.set_stylebox("panel", "PopupPanel", flat(CARD, 32))
	theme.set_stylebox("panel", "Panel", flat(CARD, 32))
	theme.set_stylebox("panel", "PanelContainer", flat(CARD, 32))
	return theme


static func _pick_font(names: Array, weight: int) -> Font:
	for n in ["Fredoka-Bold", "Fredoka-SemiBold", "Fredoka"]:
		var p := "res://assets/fonts/%s.ttf" % n
		if ResourceLoader.exists(p):
			return load(p)
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(names)
	sf.font_weight = weight
	sf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	sf.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return sf


static func flat(c: Color, radius: int = 24, ml: int = 0, mt: int = 0, mr: int = -1, mb: int = -1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.content_margin_left = ml
	s.content_margin_right = mr if mr >= 0 else ml
	s.content_margin_top = mt
	s.content_margin_bottom = mb if mb >= 0 else mt
	s.anti_aliasing = true
	return s


static func card_style(c: Color = CARD, radius: int = 32, pad: int = 26, shadow: bool = true) -> StyleBoxFlat:
	var s := flat(c, radius, pad, pad - 4)
	if shadow:
		s.shadow_color = Color(0.17, 0.15, 0.4, 0.12)
		s.shadow_size = 10
		s.shadow_offset = Vector2(0, 5)
	return s


## Disque plein (curseurs).
static func circle_tex(size: int, c: Color) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			var col := c if d < r - 5.0 else Color.WHITE
			col.a = a
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## Pièce d'or de 64 px (encaissement d'un navire, lot E) : dessinée depuis un SVG en mémoire (pas de fichier à importer).
const COIN_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
<circle cx="32" cy="34" r="29" fill="#B9770E"/>
<circle cx="32" cy="31" r="29" fill="#F5B82E"/>
<circle cx="32" cy="31" r="22" fill="#FFD25A" stroke="#D99A1C" stroke-width="3"/>
<path d="M39 22.5c-1.8-2-4.4-3-7.2-3-4.2 0-7.3 2.2-7.3 5.6 0 7.4 15 3.9 15 11.3 0 3.4-3.3 5.8-7.7 5.8-3.1 0-5.9-1.2-7.8-3.3"
 fill="none" stroke="#9C5F06" stroke-width="4.2" stroke-linecap="round"/>
<path d="M32 15.5v31" stroke="#9C5F06" stroke-width="4" stroke-linecap="round"/>
<ellipse cx="22" cy="17" rx="7" ry="3.2" fill="#FFF3C4" opacity="0.8" transform="rotate(-30 22 17)"/>
</svg>"""
static var _coin: Texture2D


static func coin_tex() -> Texture2D:
	if _coin == null:
		var img := Image.new()
		if img.load_svg_from_string(COIN_SVG, 1.0) == OK:
			_coin = ImageTexture.create_from_image(img)
		else:
			_coin = icon_tex("money")
	return _coin


static func icon_tex(name: String) -> Texture2D:
	if not _icons.has(name):
		var p := "res://assets/icons/%s.svg" % name
		_icons[name] = load(p) if ResourceLoader.exists(p) else null
	return _icons[name]


static func icon(name: String, size: float = 56.0, col: Color = Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon_tex(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.modulate = col
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func label(text: String, size: int = 36, col: Color = TEXT, num: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if num:
		l.add_theme_font_override("font", font_num)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap_label(text: String, size: int = 30, col: Color = MUTED) -> Label:
	var l := label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 100
	return l


static func button(text: String, col: Color = INDIGO, size: int = 36, min_h: float = 96.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(96, min_h)
	style_button(b, col)
	b.focus_mode = Control.FOCUS_NONE
	return b


static func style_button(b: Button, col: Color, radius: int = 28) -> void:
	b.add_theme_stylebox_override("normal", flat(col, radius, 22, 8))
	b.add_theme_stylebox_override("hover", flat(col.lightened(0.08), radius, 22, 8))
	b.add_theme_stylebox_override("pressed", flat(col.darkened(0.15), radius, 22, 8))
	b.add_theme_stylebox_override("disabled", flat(GREY, radius, 22, 8))


static func hbox(sep: int = 16) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


static func card(col: Color = CARD, pad: int = 26) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_style(col, 32, pad))
	return p


static func spacer(w: float = 0.0, h: float = 0.0, expand: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## Pastille ronde colorée contenant une icône.
static func icon_disc(name: String, bg: Color, size: float = 96.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(bg, int(size / 2)))
	p.custom_minimum_size = Vector2(size, size)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER     # jamais étirée en ovale par une rangée plus haute (revue D-UI)
	var ic := icon(name, size * 0.6)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(ic)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Badge de niveau (ex. « 37 »).
static func badge(text: String, bg: Color = VIOLET, size: int = 28) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(bg, 18, 14, 2))
	var l := label(text, size, Color.WHITE, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Bouton rond discret (pastille de `visual` px) dont la zone de toucher fait `hit` px : la cible tactile est grande sans
## alourdir l'écran (revue D-UI : « i », ▲, « + » à 56–64 px).
static func hit_button(col: Color, text: String, visual: float = 56.0, hit: float = 96.0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(hit, hit)
	var dot := PanelContainer.new()
	dot.add_theme_stylebox_override("panel", flat(col, int(visual * 0.5)))
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.custom_minimum_size = Vector2(visual, visual)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.offset_left = -visual * 0.5
	dot.offset_right = visual * 0.5
	dot.offset_top = -visual * 0.5
	dot.offset_bottom = visual * 0.5
	var l := label(text, int(visual * 0.55), Color.WHITE, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dot.add_child(l)
	b.add_child(dot)
	return b


## Bouton d'un état acquis (CONSTRUIT, EMBAUCHÉ) : inactif mais vert pâle, pas gris (le gris est réservé à l'impossible).
static func style_done(b: Button) -> void:
	b.add_theme_stylebox_override("disabled", flat(MONEY.lightened(0.35), 28, 22, 8))
	b.add_theme_color_override("font_disabled_color", Color.WHITE)
