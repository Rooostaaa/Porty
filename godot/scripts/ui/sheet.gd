class_name Sheet
extends Control
## Écran : en-tête indigo + flèche retour, onglets optionnels, contenu défilant de cartes blanches.
## Deux formats (lot D-UI) :
## - **plein cadre** (Gestion, Missions, Réglages) : fond opaque, le port est en pause derrière ;
## - **mi-hauteur** (`half`, Améliorer et Commerce) : feuille basse sur 58 % de l'écran au-dessus du port qui continue de
##   vivre (surcouche monde visible au-dessus, effets non suspendus) ; toucher le port au-dessus la referme.
## Les deux portent un mini-solde dans l'en-tête et un « ? » qui rouvre l'aide (le texte d'aide n'est affiché qu'une fois).

signal closed()

## Haut de la feuille mi-hauteur, en fraction de la hauteur d'écran (la feuille occupe les 58 % du bas).
const HALF_TOP := 0.42

var title: String = ""
var tabs: Array[String] = []
var tab: int = 0
var half := false
var content: VBoxContainer
var scroll: ScrollContainer
var tab_buttons: Array[Button] = []
var header_extra: HBoxContainer
var money_l: Label                     # mini-solde de l'en-tête
var help_btn: Button
var panel_root: Control                # la feuille elle-même (en-tête + contenu) : en mi-hauteur, le bas de l'écran
var _refresh_t := 0.0
var _help_lines: Array[String] = []     # aides de l'onglet affiché (« ? » de l'en-tête)
var _help_here: Dictionary = {}         # aides affichées dans cet écran (elles y restent jusqu'à sa fermeture)
var _closing := false

## Aides déjà lues (clé -> vrai) : une aide d'en-tête n'est déroulée qu'une fois par partie lancée, ensuite repliée
## dans le « ? » de l'en-tête (revue D-UI, cosmétique).
static var help_seen: Dictionary = {}


func _init(t: String = "", tab_names: Array[String] = []) -> void:
	title = t
	tabs = tab_names


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	var root := UI.vbox(0)
	if half:
		# le haut de l'écran reste au port : seule la feuille a un fond
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.anchor_top = HALF_TOP
		bg.offset_top = 60.0          # sous les coins arrondis de l'en-tête
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.anchor_top = HALF_TOP
		root.offset_top = 0.0
		root.offset_bottom = 0.0
		root.offset_left = 0.0
		root.offset_right = 0.0
	else:
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(root)
	panel_root = root
	# en-tête
	var head := PanelContainer.new()
	var hs := UI.flat(UI.INDIGO, 0, 24, 18)
	if half:
		hs.corner_radius_top_left = 44
		hs.corner_radius_top_right = 44
		hs.content_margin_top = 20
		hs.shadow_color = Color(0.1, 0.05, 0.3, 0.35)
		hs.shadow_size = 16
	else:
		hs.content_margin_top = 44
	hs.corner_radius_bottom_left = 40
	hs.corner_radius_bottom_right = 40
	head.add_theme_stylebox_override("panel", hs)
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(head)
	var hv := UI.vbox(14 if half else 18)
	head.add_child(hv)
	var hrow := UI.hbox(14)
	hv.add_child(hrow)
	var back := UI.button("", UI.INDIGO_DARK, 36, 96 if half else 104)
	back.icon = UI.icon_tex("close" if half else "back")
	back.expand_icon = true
	back.custom_minimum_size = Vector2(96, 96) if half else Vector2(104, 104)
	back.add_theme_constant_override("icon_max_width", 48 if half else 56)
	back.pressed.connect(close)
	hrow.add_child(back)
	var tl := UI.label(title, 44 if half else 52, Color.WHITE)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.clip_text = true
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hrow.add_child(tl)
	header_extra = UI.hbox(10)
	hrow.add_child(header_extra)
	# « ? » : l'aide de l'onglet (repliée après la première lecture)
	help_btn = UI.button("", UI.INDIGO_DARK, 30, 96)
	help_btn.icon = UI.icon_tex("help")
	help_btn.expand_icon = true
	help_btn.custom_minimum_size = Vector2(96, 96)
	help_btn.add_theme_constant_override("icon_max_width", 44)
	help_btn.tooltip_text = "Aide"
	help_btn.pressed.connect(_show_help)
	help_btn.visible = false
	header_extra.add_child(help_btn)
	# mini-solde : on voit toujours ce qu'on a en poche (revue D-UI)
	var mp := PanelContainer.new()
	mp.add_theme_stylebox_override("panel", UI.flat(UI.INDIGO_DARK, 30, 14, 4))
	mp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var mh := UI.hbox(6)
	mp.add_child(mh)
	mh.add_child(UI.icon("money", 40))
	money_l = UI.label("", 34, UI.MONEY.lightened(0.25), true)
	mh.add_child(money_l)
	header_extra.add_child(mp)
	_update_money()
	if not tabs.is_empty():
		var trow := UI.hbox(10)
		hv.add_child(trow)
		for i in tabs.size():
			var b := UI.button(tabs[i], UI.INDIGO_DARK, 30, 96)      # cible tactile ≥ 96 px (lot E ; 84 avant)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.clip_text = true
			b.pressed.connect(_select_tab.bind(i))
			trow.add_child(b)
			tab_buttons.append(b)
	var body := Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(body)
	var bbg := ColorRect.new()
	bbg.color = UI.BG
	bbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(bbg)
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 22 if half else 26)
	margin.add_theme_constant_override("margin_bottom", 60)
	scroll.add_child(margin)
	content = UI.vbox(22)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)
	_select_tab(tab)
	if half:
		# entrée : la feuille monte du bas de l'écran
		root.offset_top = 200.0
		root.offset_bottom = 200.0
		bg.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(root, "offset_top", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(root, "offset_bottom", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(bg, "modulate:a", 1.0, 0.12)


## Haut de la feuille (coordonnées écran) : en mi-hauteur, le port est visible au-dessus.
func top_y() -> float:
	if not half:
		return 0.0
	return get_viewport_rect().size.y * HALF_TOP


## Toucher au-dessus d'une feuille mi-hauteur (sur le port) : elle se referme.
func _gui_input(event: InputEvent) -> void:
	if not half:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.position.y < top_y():
		# l'appui est pris ici : la caméra ne le voit pas, donc son relâchement n'est jamais un toucher du monde (lot E, E5 ;
		# voir `CameraRig.input_enabled`)
		accept_event()
		close()


func _select_tab(i: int) -> void:
	tab = i
	for k in tab_buttons.size():
		UI.style_button(tab_buttons[k], UI.VIOLET if k == i else UI.INDIGO_DARK)
	rebuild()
	_keep_scroll = -1          # nouvel onglet : en haut de la liste
	_fling = 0.0
	scroll.scroll_vertical = 0
	Sfx.play("click")


# --- défilement (lot F1) -----------------------------------------------------------------------------------------------
## Défilement au doigt et à la souris, géré par la feuille (lot F1, bug « défilement parfois impossible ») : Godot ne fait
## défiler une ScrollContainer au glissé que sur un écran tactile et seulement si l'appui tombe sur elle (pas sur un bouton,
## qui garde l'appui) ; et `refresh()` reconstruisait la liste en plein glissé. Ici, un glissé vertical de plus de
## DRAG_START px fait défiler la liste d'où qu'il parte (texte, carte, bouton d'achat) ; le bouton sous le doigt est relâché
## sans effet (NOTIFICATION_SCROLL_BEGIN : BaseButton oublie l'appui, HoldRepeat arrête sa rafale) ; un appui bref garde son
## effet ; au relâchement, la liste garde son élan. Une reconstruction demandée pendant qu'un doigt est posé attend le
## relâchement (`request_rebuild`) ; le défilement est gardé à travers une reconstruction.
const DRAG_START := 14.0        # px (coordonnées de la vue, 1080 de large)
const FLING_MIN := 250.0        # px/s : en dessous, pas d'élan
const FLING_DAMP := 4.0         # 1/s
const NO_PTR := -99
var _ptr := NO_PTR              # doigt (index) ou souris (−2) posé dans la liste
var _ptr_from := Vector2.ZERO
var _scroll0 := 0
var _dragging := false
var _drag_last := Vector2.ZERO
var _drag_t := 0
var _drag_v := 0.0              # vitesse du glissé (px/s, vers le bas > 0)
var _fling := 0.0               # élan (px/s de défilement)
var _rebuild_pending := false
var _keep_scroll := -1          # défilement à rétablir après une reconstruction (deux images, le temps de la mise en page)
var _keep_frames := 0
var drags_done := 0             # glissés qui ont fait défiler la liste (tests)
var rebuilds_deferred := 0      # reconstructions différées au relâchement (tests)


## Un doigt (ou le bouton de la souris) est-il posé dans la liste ?
func touching() -> bool:
	return _ptr != NO_PTR


func is_dragging() -> bool:
	return _dragging


## Reconstruction demandée par `refresh()` (la liste a changé) : différée tant qu'un doigt est posé dans la liste.
func request_rebuild() -> void:
	if touching():
		if not _rebuild_pending:
			rebuilds_deferred += 1
		_rebuild_pending = true
		return
	rebuild()


func _input(event: InputEvent) -> void:
	if scroll == null or _closing or not is_visible_in_tree():
		return
	var pos := Vector2.ZERO
	var id := NO_PTR
	var pressed := false
	var move := false
	if event is InputEventScreenTouch:
		id = (event as InputEventScreenTouch).index
		pos = (event as InputEventScreenTouch).position
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventScreenDrag:
		id = (event as InputEventScreenDrag).index
		pos = (event as InputEventScreenDrag).position
		move = true
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		# (souris réelle seulement : sur le téléphone, la souris émulée double le toucher)
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		id = -2
		pos = mb.position
		pressed = mb.pressed
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		id = -2
		pos = mm.position
		move = true
	else:
		return
	if move:
		if id != _ptr:
			return
		var dy := pos.y - _ptr_from.y
		if not _dragging and absf(dy) > DRAG_START and absf(dy) > absf(pos.x - _ptr_from.x):
			_dragging = true
			_ptr_from.y += signf(dy) * DRAG_START      # pas de saut au début du glissé
			scroll.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
		if _dragging:
			var now := Time.get_ticks_usec()
			var dt := maxf(0.004, float(now - _drag_t) / 1e6)
			_drag_v = lerpf(_drag_v, (pos.y - _drag_last.y) / dt, 0.5)
			_drag_last = pos
			_drag_t = now
			scroll.scroll_vertical = roundi(float(_scroll0) - (pos.y - _ptr_from.y))
			get_viewport().set_input_as_handled()
		return
	if pressed:
		if _ptr != NO_PTR or not scroll.get_global_rect().has_point(pos):
			return
		# (seulement la feuille du dessus, et jamais sous une fenêtre)
		if Hud.main != null and (Hud.main.current_sheet() != self or Hud.main._npopups() > 0):
			return
		_ptr = id
		_ptr_from = pos
		_scroll0 = scroll.scroll_vertical
		_dragging = false
		_fling = 0.0
		_drag_last = pos
		_drag_t = Time.get_ticks_usec()
		_drag_v = 0.0
	elif id == _ptr:
		if _dragging:
			drags_done += 1
			if absf(_drag_v) > FLING_MIN and Time.get_ticks_usec() - _drag_t < 120000:
				_fling = -_drag_v
		_ptr = NO_PTR
		_dragging = false
		if _rebuild_pending:
			_rebuild_pending = false
			rebuild.call_deferred()


func _scroll_step(delta: float) -> void:
	if scroll == null:
		return
	if _keep_frames > 0:
		_keep_frames -= 1
		if _keep_scroll >= 0 and not _dragging:
			scroll.scroll_vertical = _keep_scroll
	if _fling != 0.0 and not _dragging:
		var before := scroll.scroll_vertical
		scroll.scroll_vertical = roundi(float(before) + _fling * delta)
		_fling *= exp(-FLING_DAMP * delta)
		if absf(_fling) < 30.0 or scroll.scroll_vertical == before:
			_fling = 0.0


## À surcharger : remplit `content`.
func build() -> void:
	pass


## À surcharger : met à jour les valeurs dynamiques.
func refresh() -> void:
	pass


func rebuild() -> void:
	if content == null:
		return
	# (lot F1) le défilement est gardé : rétabli tout de suite et pendant deux images (mise en page de la nouvelle liste)
	var keep := scroll.scroll_vertical if scroll != null else 0
	for c in content.get_children():
		c.queue_free()
	_help_lines.clear()
	build()
	help_btn.visible = not _help_lines.is_empty()
	refresh()
	if scroll != null:
		scroll.scroll_vertical = keep
		_keep_scroll = keep
		_keep_frames = 2


## Texte d'aide d'en-tête : déroulé la première fois (et tant que cet écran reste ouvert), ensuite replié dans le « ? ».
func help(key: String, text: String) -> void:
	_help_lines.append(text)
	if not help_seen.has(key) or _help_here.has(key):
		help_seen[key] = true
		_help_here[key] = true
		content.add_child(UI.wrap_label(text, 28))


func _show_help() -> void:
	if Hud.main == null or _help_lines.is_empty():
		return
	Sfx.play("click")
	var body: Array = []
	for t in _help_lines:
		body.append(UI.wrap_label(t, 30, UI.TEXT))
	Hud.main.show_popup(title, body, "help")


func _update_money() -> void:
	if money_l != null and GameState.sim != null:
		money_l.text = Fmt.money(GameState.sim.money)


func _process(delta: float) -> void:
	_update_money()
	_refresh_t += delta
	if _refresh_t >= 0.2:
		_refresh_t = 0.0
		refresh()
	_scroll_step(delta)


func close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.play("click")
	closed.emit()
	queue_free()


func sim() -> PortSim:
	return GameState.sim
