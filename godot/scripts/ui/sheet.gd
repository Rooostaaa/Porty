class_name Sheet
extends Control
## Écran plein cadre : en-tête indigo + flèche retour, onglets optionnels, contenu défilant de cartes blanches.

signal closed()

var title: String = ""
var tabs: Array[String] = []
var tab: int = 0
var content: VBoxContainer
var scroll: ScrollContainer
var tab_buttons: Array[Button] = []
var header_extra: HBoxContainer
var _refresh_t := 0.0


func _init(t: String = "", tab_names: Array[String] = []) -> void:
	title = t
	tabs = tab_names


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := UI.vbox(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	# en-tête
	var head := PanelContainer.new()
	var hs := UI.flat(UI.INDIGO, 0, 24, 18)
	hs.corner_radius_bottom_left = 40
	hs.corner_radius_bottom_right = 40
	hs.content_margin_top = 44
	head.add_theme_stylebox_override("panel", hs)
	root.add_child(head)
	var hv := UI.vbox(18)
	head.add_child(hv)
	var hrow := UI.hbox(18)
	hv.add_child(hrow)
	var back := UI.button("", UI.INDIGO_DARK, 36, 104)
	back.icon = UI.icon_tex("back")
	back.expand_icon = true
	back.custom_minimum_size = Vector2(104, 104)
	back.add_theme_constant_override("icon_max_width", 56)
	back.pressed.connect(close)
	hrow.add_child(back)
	var tl := UI.label(title, 52, Color.WHITE)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hrow.add_child(tl)
	header_extra = UI.hbox(10)
	hrow.add_child(header_extra)
	if not tabs.is_empty():
		var trow := UI.hbox(10)
		hv.add_child(trow)
		for i in tabs.size():
			var b := UI.button(tabs[i], UI.INDIGO_DARK, 30, 84)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(_select_tab.bind(i))
			trow.add_child(b)
			tab_buttons.append(b)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 60)
	scroll.add_child(margin)
	content = UI.vbox(22)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)
	_select_tab(tab)


func _select_tab(i: int) -> void:
	tab = i
	for k in tab_buttons.size():
		UI.style_button(tab_buttons[k], UI.VIOLET if k == i else UI.INDIGO_DARK)
	rebuild()
	scroll.scroll_vertical = 0
	Sfx.play("click")


## À surcharger : remplit `content`.
func build() -> void:
	pass


## À surcharger : met à jour les valeurs dynamiques.
func refresh() -> void:
	pass


func rebuild() -> void:
	if content == null:
		return
	for c in content.get_children():
		c.queue_free()
	build()
	refresh()


func _process(delta: float) -> void:
	_refresh_t += delta
	if _refresh_t >= 0.2:
		_refresh_t = 0.0
		refresh()


func close() -> void:
	Sfx.play("click")
	closed.emit()
	queue_free()


func sim() -> PortSim:
	return GameState.sim
