class_name Hud
extends Control
## Interface portrait : barre haute (revenu/min, argent, Ambre, étoiles), responsables, boutons latéraux,
## conseil de goulot, bandeau d'aléa, notifications, barre basse, écrans et fenêtres.

static var main: Hud

var diorama: Diorama
var overlay: WorldOverlay
var income_l: Label
var money_l: Label
var amber_l: Label
var stars_l: Label
var prog_bar: RoundBar
var upgrade_badge: PanelContainer
var tutorial: Tutorial
var tut_targets: Dictionary = {}      # nom -> contrôle que le tutoriel peut désigner
var _money_disp := -1.0
var mgr_btn: Button
var miss_badge: PanelContainer
var hint_card: PanelContainer
var hint_title: Label
var hint_text: Label
var hint_btn: Button
var event_card: PanelContainer
var ev_icon: TextureRect
var ev_title: Label
var ev_text: Label
var ev_bar: RoundBar
var ev_btn: Button
var toast_box: VBoxContainer
var boost_btn: Button
var boost_sub: Label
var contracts_badge: PanelContainer
var commerce_btn: Button
var sheet_layer: Control
var popup_layer: Control
var debug_panel: Control
var _rev_acc: Dictionary = {}
var _rev_t := 0.0
var _ui_t := 0.0
var _last_hint := ""
var _toasts_recent: Dictionary = {}
var _bound: PortSim
var _mgr_on := false           # état du style du bouton Responsables / Heures sup (restylé seulement au changement)
var _boost_state := ""
var feature_ctl: Dictionary = {}      # id de fonction (data/unlocks.json) -> contrôles qui n'apparaissent qu'une fois révélée
var _banner_queue: Array[Dictionary] = []
var _banner: Control
# retour immédiat d'un achat : le revenu affiché reste le revenu réel (fenêtre de 60 s), mais il rejoint tout de suite
# l'estimation après l'achat au lieu de mettre une minute à bouger, et une pastille montre le gain
var gain_pill: PanelContainer
var gain_l: Label
var _gain_tw: Tween
var _est_prev := -1.0          # revenu estimé (par seconde) avant le dernier achat
var _est_t := 0.0
var _purchase_seen := false
var _lifts: Array = []         # [temps de jeu de l'achat, gain par seconde]
var _gain_sum := 0.0
var _gain_time := -100.0
# bandeau des missions (sous la barre du haut)
var mission_strip: HBoxContainer
var chest_btn: Button
var strip_fold: Button
var strip_folded := false
var strip_items: Array[Dictionary] = []


func _ready() -> void:
	main = self
	theme = UI.init_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay = WorldOverlay.new()
	overlay.diorama = diorama
	add_child(overlay)
	overlay.top_level = true       # dessine en coordonnées écran, hors de la colonne centrale
	_build_top()
	_build_bottom()
	sheet_layer = Control.new()
	sheet_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sheet_layer)
	tutorial = Tutorial.new()
	tutorial.hud = self
	add_child(tutorial)
	tutorial.top_level = true
	popup_layer = Control.new()
	popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup_layer)
	diorama.assist_done.connect(_on_assist)
	diorama.ship_prioritized.connect(_on_prioritized)
	diorama.ship_tapped.connect(_on_ship_tapped)
	diorama.place_tapped.connect(func(d: String) -> void: open_upgrades(d))
	bind(GameState.sim)
	GameState.sim_replaced.connect(bind)
	get_viewport().size_changed.connect(_apply_column)
	_apply_column()
	GameState.offline_applied.connect(_on_offline)
	if not GameState.offline_report.is_empty():
		var rep := GameState.offline_report
		GameState.offline_report = {}
		_on_offline(rep)
	elif Capture.args().has("intro"):
		_intro()


const COLUMN_W := 1080.0


## Interface en colonne portrait centrée (1080 px de large) : sur une fenêtre plus large, le monde reste visible
## de chaque côté. La surcouche monde et le tutoriel dessinent en coordonnées écran, hors de la colonne.
func _apply_column() -> void:
	var vs := get_viewport().get_visible_rect().size
	var side := maxf(0.0, (vs.x - COLUMN_W) * 0.5)
	offset_left = side
	offset_right = -side
	for c in [overlay, tutorial]:
		var ctl: Control = c
		ctl.set_anchors_preset(Control.PRESET_TOP_LEFT, false)   # taille fixe : plus d'ancrage sur le parent
		ctl.position = Vector2.ZERO
		ctl.size = vs
	tutorial.set_side(side)


func bind(s: PortSim) -> void:
	if _bound != null:
		for c in [["notify", _on_notify], ["revenue", _on_revenue], ["tier_changed", _on_tier], ["event_started", _on_event], ["mission_ready", _on_mission], ["feature_unlocked", _on_feature], ["ship_class_first", _on_first_class], ["purchased", _on_purchased]]:
			if _bound.is_connected(c[0], c[1]):
				_bound.disconnect(c[0], c[1])
	_bound = s
	s.notify.connect(_on_notify)
	s.revenue.connect(_on_revenue)
	s.tier_changed.connect(_on_tier)
	s.event_started.connect(_on_event)
	s.mission_ready.connect(_on_mission)
	s.feature_unlocked.connect(_on_feature)
	s.ship_class_first.connect(_on_first_class)
	s.purchased.connect(_on_purchased)
	_est_prev = -1.0
	_lifts.clear()
	for c in sheet_layer.get_children():
		c.queue_free()
	if diorama != null and diorama.rig != null:
		diorama.rig.input_enabled = true
	_money_disp = -1.0
	_refresh(s)
	if s.legacy_notice == "commerce":
		s.legacy_notice = ""
		_commerce_notice.call_deferred()
	elif s.legacy_notice.begins_with("licences:"):
		var amount := s.legacy_notice.substr(9)
		s.legacy_notice = ""
		show_popup.call_deferred("Licences : nouveaux plafonds", [UI.wrap_label(
			"Les licences ont désormais un niveau maximal à chaque palier du port. Tes niveaux au-delà du plafond " \
			+ "ont été remboursés : +%s. Le palier suivant relèvera le plafond." % amount, 30, UI.TEXT)], "box")


## Onglet du Commerce à l'ouverture : Contrats tant que le démarchage n'est pas révélé.
func _commerce_tab() -> int:
	return CommerceSheet.TAB_TRAFFIC if GameState.sim.feature("commerce") else CommerceSheet.TAB_CONTRACTS


## Partie d'avant le Commerce : la Capitainerie ne fait plus venir les navires, on l'explique une fois.
func _commerce_notice() -> void:
	var body: Array = []
	body.append(UI.wrap_label("Ton port a un nouveau service : le Commerce.", 32, UI.TEXT))
	for line in [
		["harbor", "La Capitainerie pilote désormais les navires (pilotes, rade, temps d'accostage). Elle ne les fait plus venir : ton trafic baisse."],
		["ship", "Pour attirer des navires : affiches et annonces, armateurs à démarcher, lignes régulières, services aux navires."],
	]:
		var h := UI.hbox(14)
		h.add_child(UI.icon_disc(String(line[0]), UI.VIOLET, 80))
		h.add_child(UI.wrap_label(String(line[1]), 28, UI.TEXT))
		body.append(h)
	var go := UI.button("COMMERCE", UI.VIOLET, 34, 100)
	go.pressed.connect(func() -> void: open_sheet(CommerceSheet.new(CommerceSheet.TAB_TRAFFIC)))
	show_popup("Nouveau : le Commerce", body, "ship", [go])


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _build_top() -> void:
	var top := UI.vbox(14)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 0
	top.offset_right = 0
	add_child(top)
	# barre haute indigo
	var bar := PanelContainer.new()
	var bs := UI.flat(UI.INDIGO, 0, 22, 14)
	bs.content_margin_top = 34
	bs.corner_radius_bottom_left = 44
	bs.corner_radius_bottom_right = 44
	bs.shadow_color = Color(0.1, 0.05, 0.3, 0.3)
	bs.shadow_size = 12
	bar.add_theme_stylebox_override("panel", bs)
	top.add_child(bar)
	var row := UI.hbox(12)
	bar.add_child(row)
	# revenu / min
	var inc := _top_pill(row, "money", UI.MONEY)
	income_l = inc
	# pastille « +X/s » sous le revenu après un achat (hors de la barre : elle ne la fait pas grandir)
	gain_pill = PanelContainer.new()
	gain_pill.add_theme_stylebox_override("panel", UI.flat(Color.WHITE, 22, 12, 2))
	gain_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gain_pill.top_level = true
	gain_pill.visible = false
	gain_l = UI.label("", 28, UI.MONEY, true)
	gain_pill.add_child(gain_l)
	add_child(gain_pill)
	row.add_child(UI.spacer(0, 0, true))
	var mv := UI.vbox(0)
	mv.alignment = BoxContainer.ALIGNMENT_CENTER
	money_l = UI.label("0 $", 58, Color.WHITE, true)
	money_l.pivot_offset = Vector2(120, 34)
	money_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(money_l)
	# progression vers le palier suivant (touche : ouvre l'onglet Port)
	prog_bar = RoundBar.new(30)
	prog_bar.custom_minimum_size = Vector2(300, 30)
	prog_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	prog_bar.font_size = 20
	prog_bar.color = UI.AMBER
	prog_bar.bg = UI.INDIGO_DARK
	prog_bar.light_text = true
	prog_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	prog_bar.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			open_sheet(ManageSheet.new(3)))
	mv.add_child(prog_bar)
	row.add_child(mv)
	row.add_child(UI.spacer(0, 0, true))
	amber_l = _top_pill(row, "amber", UI.AMBER)
	feature_ctl["amber"] = [amber_l.get_parent().get_parent()]
	var plus := UI.button("", UI.AMBER, 30, 64)
	plus.icon = UI.icon_tex("plus")
	plus.expand_icon = true
	plus.custom_minimum_size = Vector2(64, 64)
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plus.pressed.connect(func() -> void: open_sheet(MissionsSheet.new()))
	row.add_child(plus)
	feature_ctl["amber"].append(plus)
	stars_l = _top_pill(row, "star", UI.AMBER)
	feature_ctl["stars"] = [stars_l.get_parent().get_parent()]
	feature_ctl["progress"] = [prog_bar]
	_build_mission_strip(top)
	# deuxième rangée : responsables (gauche) + boutons carrés (droite)
	var row2 := HBoxContainer.new()
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m2 := MarginContainer.new()
	m2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m2.add_theme_constant_override("margin_left", 20)
	m2.add_theme_constant_override("margin_right", 20)
	m2.add_child(row2)
	top.add_child(m2)
	var leftcol := UI.vbox(14)
	leftcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(leftcol)
	mgr_btn = UI.button("RESPONSABLES : OFF", UI.GREY.darkened(0.25), 28, 76)
	mgr_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mgr_btn.icon = UI.icon_tex("people")
	mgr_btn.add_theme_constant_override("icon_max_width", 44)
	mgr_btn.pressed.connect(func() -> void: open_sheet(ManageSheet.new(2)))
	leftcol.add_child(mgr_btn)
	feature_ctl["managers"] = [mgr_btn]
	# conseil de goulot
	hint_card = UI.card(Color.WHITE, 22)
	leftcol.add_child(hint_card)
	var hv := UI.vbox(4)
	hint_card.add_child(hv)
	var hh := UI.hbox(10)
	hv.add_child(hh)
	var dot := PanelContainer.new()
	dot.add_theme_stylebox_override("panel", UI.flat(UI.BAD, 14))
	dot.custom_minimum_size = Vector2(28, 28)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hh.add_child(dot)
	hint_title = UI.label("", 32, UI.BAD)
	hint_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(hint_title)
	hint_btn = UI.button("AGIR", UI.MONEY, 28, 70)
	hint_btn.pressed.connect(_on_hint_pressed)
	hh.add_child(hint_btn)
	hint_text = UI.wrap_label("", 27, UI.TEXT)
	hv.add_child(hint_text)
	# bandeau d'aléa
	event_card = UI.card(Color("#FFF1DE"), 22)
	event_card.visible = false
	leftcol.add_child(event_card)
	var ev := UI.vbox(6)
	event_card.add_child(ev)
	var eh := UI.hbox(12)
	ev.add_child(eh)
	var ed := PanelContainer.new()
	ed.add_theme_stylebox_override("panel", UI.flat(UI.ORANGE, 36))
	ed.custom_minimum_size = Vector2(72, 72)
	ev_icon = UI.icon("wind", 46)
	ev_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ev_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ed.add_child(ev_icon)
	eh.add_child(ed)
	var et := UI.vbox(0)
	et.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eh.add_child(et)
	ev_title = UI.label("", 32, UI.ORANGE.darkened(0.2))
	et.add_child(ev_title)
	ev_text = UI.wrap_label("", 25, UI.TEXT)
	et.add_child(ev_text)
	var eb := UI.hbox(12)
	ev.add_child(eb)
	ev_bar = RoundBar.new(30)
	ev_bar.color = UI.ORANGE
	ev_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	eb.add_child(ev_bar)
	ev_btn = UI.button("", UI.ORANGE, 26, 76)
	ev_btn.pressed.connect(_on_event_pay)
	eb.add_child(ev_btn)
	# notifications
	toast_box = UI.vbox(10)
	leftcol.add_child(toast_box)
	# boutons carrés à droite
	var rightcol := UI.vbox(16)
	rightcol.size_flags_horizontal = Control.SIZE_SHRINK_END
	row2.add_child(UI.spacer(16))
	row2.add_child(rightcol)
	var ub := _square("upgrade", func() -> void: open_upgrades(""), "Améliorer")
	rightcol.add_child(ub)
	upgrade_badge = _badge_on(ub, "0", UI.MONEY)
	tut_targets["upgrade"] = ub
	tut_targets["hint"] = hint_card
	var sb := _square("stats", func() -> void: open_sheet(ManageSheet.new(1)), "Stats")
	rightcol.add_child(sb)
	feature_ctl["stats"] = [sb]
	var mb := _square("missions", func() -> void: open_sheet(MissionsSheet.new()), "Missions")
	rightcol.add_child(mb)
	tut_targets["missions"] = mb
	feature_ctl["missions"].append(mb)
	miss_badge = _badge_on(mb, "!")


## Bandeau compact sous la barre : coffre (n/N), les 2 missions en cours avec leur barre, et un bouton pour le replier.
## Toucher une mission terminée la réclame ; sinon il ouvre l'écran Missions.
func _build_mission_strip(top: VBoxContainer) -> void:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	top.add_child(m)
	mission_strip = UI.hbox(10)
	m.add_child(mission_strip)
	tut_targets["mission_strip"] = mission_strip
	feature_ctl["missions"] = [m]
	# coffre
	chest_btn = UI.button("", UI.INDIGO, 22, 64)
	chest_btn.icon = UI.icon_tex("amber")
	chest_btn.expand_icon = true
	chest_btn.add_theme_constant_override("icon_max_width", 34)
	chest_btn.custom_minimum_size = Vector2(118, 64)
	chest_btn.tooltip_text = "Coffre de missions"
	chest_btn.pressed.connect(func() -> void: open_sheet(MissionsSheet.new()))
	mission_strip.add_child(chest_btn)
	for i in 2:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_contents = true
		UI.style_button(b, Color(1, 1, 1, 0.94), 22)
		var v := UI.vbox(2)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 14
		v.offset_right = -14
		v.offset_top = 6
		v.offset_bottom = -6
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var l := UI.label("", 22, UI.TEXT)
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
		var bar := RoundBar.new(20)
		bar.font_size = 15
		bar.color = UI.INFO
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(bar)
		b.pressed.connect(_on_strip_mission.bind(i))
		mission_strip.add_child(b)
		strip_items.append({"btn": b, "label": l, "bar": bar, "id": ""})
	strip_fold = UI.button("▲", UI.INDIGO, 22, 64)
	strip_fold.custom_minimum_size = Vector2(64, 64)
	strip_fold.tooltip_text = "Replier les missions"
	strip_fold.pressed.connect(func() -> void:
		strip_folded = not strip_folded
		Sfx.play("click")
		_refresh_strip(GameState.sim))
	mission_strip.add_child(strip_fold)


func _refresh_strip(s: PortSim) -> void:
	var vis := Objectives.visible_missions(s)
	for i in strip_items.size():
		var it: Dictionary = strip_items[i]
		var b: Button = it.btn
		b.visible = not strip_folded and i < vis.size()
		if i >= vis.size():
			continue
		var mi: Dictionary = vis[i]
		it.id = String(mi.id)
		var p := Objectives.mission_progress(s, mi)
		var t := float(mi.target)
		var done := p >= t
		(it.label as Label).text = ("✓ " if done else "") + String(mi.text)
		var bar: RoundBar = it.bar
		bar.value = p / maxf(t, 0.0001)
		bar.color = UI.MONEY if done else UI.INFO
		bar.text = "RÉCLAMER" if done else ("%s / %s" % [Fmt.num(minf(p, t)), Fmt.num(t)] if t > 1.0 else "")
	var cp := Objectives.chest_progress(s)
	chest_btn.visible = cp.y > 0
	chest_btn.text = "%d/%d" % [cp.x, cp.y]
	strip_fold.text = "▼" if strip_folded else "▲"
	strip_fold.tooltip_text = "Afficher les missions" if strip_folded else "Replier les missions"


func _on_strip_mission(i: int) -> void:
	var s := GameState.sim
	var it: Dictionary = strip_items[i]
	var b: Button = it.btn
	if Objectives.claim(s, String(it.id)):
		var lc := s.last_claim
		Sfx.play("tier" if bool(lc.get("chest", false)) else "coin")
		Fx.reward(b, "+%d Ambre" % int(lc.get("amber", 0)), UI.AMBER, bool(lc.get("chest", false)))
		if float(lc.get("money", 0.0)) > 0.0:
			Fx.float_text(Fx.center_of(b) + Vector2(0, 50), "+" + Fmt.money(float(lc.money)), UI.MONEY, 40)
		if bool(lc.get("chest", false)):
			Fx.reward(chest_btn, "Coffre !", UI.AMBER, true)
		flash_money()
		_refresh_strip(s)
	else:
		open_sheet(MissionsSheet.new())


func _top_pill(row: HBoxContainer, icon_name: String, col: Color) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.flat(UI.INDIGO_DARK, 30, 14, 6))
	var h := UI.hbox(8)
	p.add_child(h)
	h.add_child(UI.icon(icon_name, 52))
	var l := UI.label("0", 36, col, true)
	h.add_child(l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(p)
	return l


func _square(icon_name: String, cb: Callable, caption: String = "") -> Button:
	var b := UI.button("", UI.INDIGO, 30, 118)
	b.custom_minimum_size = Vector2(118, 118 if caption == "" else 132)
	b.icon = UI.icon_tex(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 64)
	if caption != "":
		b.text = caption
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_constant_override("icon_max_width", 56)
		b.add_theme_constant_override("h_separation", 0)
	UI.style_button(b, UI.INDIGO, 30)
	b.pressed.connect(cb)
	return b


func _badge_on(b: Control, text: String, col: Color = UI.BAD) -> PanelContainer:
	var bd := UI.badge(text, col, 26)
	bd.position = Vector2(80, -10)
	bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(bd)
	bd.visible = false
	return bd


func _build_bottom() -> void:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	m.offset_top = -210
	m.offset_bottom = 0
	m.offset_left = 0
	m.offset_right = 0
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_bottom", 28)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(m)
	var row := UI.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(row)
	var st := _square("gear", func() -> void: open_sheet(SettingsSheet.new()))
	st.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(st)
	boost_btn = _big("boost", "HEURES SUP ×2", UI.AMBER, _on_boost)
	boost_sub = boost_btn.get_meta("sub")
	row.add_child(boost_btn)
	feature_ctl["boost"] = [boost_btn]
	var mg := _big("manage", "GESTION", UI.INDIGO, func() -> void: open_sheet(ManageSheet.new(0)))
	row.add_child(mg)
	tut_targets["manage"] = mg
	feature_ctl["manage"] = [mg]
	var cb := _big("ship", "COMMERCE", UI.VIOLET, func() -> void: open_sheet(CommerceSheet.new(_commerce_tab())))
	row.add_child(cb)
	tut_targets["commerce"] = cb
	tut_targets["contracts"] = cb
	commerce_btn = cb
	feature_ctl["commerce"] = [cb]       # rebondit à sa révélation ; visible aussi avec les seuls contrats (voir `_refresh`)
	contracts_badge = _badge_on(cb, "1")
	contracts_badge.position = Vector2(200, -12)


func _big(icon_name: String, text: String, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(250, 160)
	UI.style_button(b, col, 36)
	b.pressed.connect(cb)
	var v := UI.vbox(0)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(v)
	var ic := UI.icon(icon_name, 70)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := UI.label(text, 26, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var sub := UI.label("", 22, Color(1, 1, 1, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	b.set_meta("sub", sub)
	return b


# ---------------------------------------------------------------------------
# Mise à jour
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	var s := GameState.sim
	if s == null:
		return
	_ui_t += delta
	overlay.visible = not any_sheet_open()      # la surcouche monde est « top_level » : elle passerait sur les écrans
	diorama.fx_paused = not overlay.visible     # les éléments gagnés à un palier surgissent quand on revient au port
	# argent : le compteur monte en douceur, et chute d'un coup quand on dépense
	if _money_disp < 0.0 or s.money < _money_disp or absf(s.money - _money_disp) < 0.5:
		_money_disp = s.money
	else:
		_money_disp = lerpf(_money_disp, s.money, 1.0 - exp(-delta * 9.0))
	money_l.text = Fmt.money(_money_disp)
	_track_estimate(s, delta)
	if _ui_t >= 0.1:
		_ui_t = 0.0
		_refresh(s)
	_rev_t += delta
	if _rev_t >= 1.2:
		_rev_t = 0.0
		_flush_revenue(s)


func _refresh(s: PortSim) -> void:
	# revenu net par seconde ; tant que rien n'a été déchargé, on n'affiche pas les salaires seuls
	var ips := s.income_per_min() / 60.0 + _income_lift(s)
	if s.counter("evp") <= 0.0 and s.prestiges == 0:
		ips = 0.0
	income_l.text = ("+" if ips >= 0 else "") + Fmt.num(ips) + "/s"
	amber_l.text = str(s.amber)
	stars_l.text = ("%.1f" % s.stars()).replace(".", ",")
	_refresh_progress(s)
	for id in feature_ctl:
		var on := s.feature(String(id))
		for c in feature_ctl[id]:
			(c as Control).visible = on
	commerce_btn.visible = s.feature("commerce") or s.feature("contracts")
	var n_aff := _affordable_count(s)
	upgrade_badge.visible = n_aff > 0
	(upgrade_badge.get_child(0) as Label).text = str(n_aff)
	var mc := s.managers_count()
	mgr_btn.text = "RESPONSABLES %d/%d : %s" % [mc, PortSim.DEPTS.size(), "ON" if mc > 0 else "OFF"]
	if (mc > 0) != _mgr_on:        # le style ne change presque jamais : inutile de recréer 4 StyleBox à chaque rafraîchissement
		_mgr_on = mc > 0
		UI.style_button(mgr_btn, UI.MONEY if _mgr_on else UI.GREY.darkened(0.25))
	miss_badge.visible = s.feature("missions") and Objectives.claimable_count(s) > 0
	if s.feature("missions"):
		_refresh_strip(s)
	contracts_badge.visible = s.contracts_active.size() > 0
	(contracts_badge.get_child(0) as Label).text = str(s.contracts_active.size())
	# conseil de goulot
	var key: String = s.analysis.get("key", "")
	var dept: String = s.analysis.get("dept", "")
	var dname: String = s.db.dept_by_id[dept].name if s.db.dept_by_id.has(dept) else ""
	var title := "Goulot : " + dname
	if key == "yard_space":
		title = "Goulot : parc saturé"
	elif key == "berth_count":
		title = "Goulot : postes à quai"
	elif key == "min_time":
		title = "Goulot : temps d'escale au plancher"
	elif key == "tier":
		title = "Goulot : taille des navires"
	elif key == "fog":
		title = "Brouillard sur la rade"
	elif key == "harbor":
		title = "Goulot : pas assez de navires"
	elif key == "attract":
		title = "Goulot : pas assez de navires"
	hint_title.text = title
	hint_text.text = String(s.analysis.get("hint", ""))
	if key in BUILD_KEYS:
		hint_btn.text = "CONSTRUIRE"
	elif key == "harbor" and s.feature("commerce"):
		hint_btn.text = "COMMERCE"
	else:
		hint_btn.text = "PALIER" if key == "tier" else "AMÉLIORER"
	if key != _last_hint:
		_last_hint = key
		var tw := create_tween()
		hint_card.modulate = Color(1.4, 1.2, 1.2)
		tw.tween_property(hint_card, "modulate", Color.WHITE, 0.5)
	# aléa
	var ev := s.active_event
	event_card.visible = not ev.is_empty()
	if not ev.is_empty():
		ev_title.text = String(ev.name)
		ev_text.text = String(ev.text)
		ev_icon.texture = UI.icon_tex(String(ev.icon) if UI.icon_tex(String(ev.icon)) != null else "info")
		var dur := maxf(1.0, float(ev.until) - float(ev.start))
		ev_bar.value = (float(ev.until) - s.time) / dur
		ev_bar.text = "%d s" % ceili(float(ev.until) - s.time)
		if ev.kind == "auction":
			ev_btn.visible = true
			ev_btn.text = "%s\n+%s" % [ev.get("pay_label", "Encaisser"), Fmt.money(float(ev.reward))]
			ev_btn.disabled = false
		elif ev.has("pay_label") and not bool(ev.paid):
			ev_btn.visible = true
			ev_btn.text = "%s\n%s" % [ev.pay_label, Fmt.money(float(ev.get("pay_cost", 0.0)))]
			ev_btn.disabled = s.money < float(ev.get("pay_cost", 0.0))
		else:
			ev_btn.visible = true
			ev_btn.text = "Patienter"
			ev_btn.disabled = true
	# heures sup
	var boost_state := "actif" if s.boost_active() else ("pret" if s.boost_ready() else "recharge")
	if boost_state == "actif":
		boost_sub.text = "Actif : %d s" % ceili(s.boost_until - s.time)
	elif boost_state == "pret":
		boost_sub.text = "Prêt !"
	else:
		boost_sub.text = "Recharge %s" % Fmt.duration(s.boost_ready_at - s.time)
	if boost_state != _boost_state:
		_boost_state = boost_state
		var bc := UI.MONEY if boost_state == "actif" else (UI.AMBER if boost_state == "pret" else UI.GREY.darkened(0.2))
		UI.style_button(boost_btn, bc, 36)


func _on_purchased(_kind: String, _id: String) -> void:
	_purchase_seen = true      # l'analyse n'est pas encore à jour : on compare à l'image suivante


## Compare le revenu estimé avant et après un achat (une estimation fraîche par seconde, et juste après chaque achat).
func _track_estimate(s: PortSim, delta: float) -> void:
	_est_t += delta
	if _purchase_seen:
		_purchase_seen = false
		var est := s.income_estimate_with("harbor", 0)
		if _est_prev >= 0.0 and est - _est_prev > 0.0:
			_add_gain(s, est - _est_prev)
		_est_prev = est
		_est_t = 0.0
	elif _est_t >= 1.0 or _est_prev < 0.0:
		_est_t = 0.0
		_est_prev = s.income_estimate_with("harbor", 0)
	if gain_pill.visible:
		var r := income_l.get_global_rect()
		gain_pill.global_position = Vector2(r.position.x, r.end.y + 22)


## Gain d'un achat : pastille « +X/s » (cumulée pendant une rafale d'achats) qui s'efface en 3 s.
func _add_gain(s: PortSim, g: float) -> void:
	if s.time - _gain_time > 3.0:
		_gain_sum = 0.0
	_gain_sum += g
	_gain_time = s.time
	_lifts.append([s.time, g])
	gain_l.text = "+%s/s" % Fmt.num(_gain_sum)
	gain_pill.visible = true
	gain_pill.modulate.a = 1.0
	Fx.pop(gain_pill, 1.12)
	if _gain_tw != null:
		_gain_tw.kill()
	_gain_tw = gain_pill.create_tween()
	_gain_tw.tween_property(gain_pill, "modulate:a", 0.0, 1.0).set_delay(2.0)
	_gain_tw.tween_callback(func() -> void: gain_pill.visible = false)


## Ce que la fenêtre de 60 s n'a pas encore vu d'un achat récent : le gain monte en 3 s, puis s'efface
## à mesure que la fenêtre se remplit au nouveau rythme (le chiffre reste honnête, il bouge juste tout de suite).
func _income_lift(s: PortSim) -> float:
	var lift := 0.0
	for i in range(_lifts.size() - 1, -1, -1):
		var age: float = s.time - float(_lifts[i][0])
		if age >= 60.0 or age < 0.0:
			_lifts.remove_at(i)
			continue
		lift += float(_lifts[i][1]) * smoothstep(0.0, 3.0, age) * (1.0 - age / 60.0)
	return lift


## Nombre d'améliorations (départements + licences) achetables tout de suite.
func _affordable_count(s: PortSim) -> int:
	var n := 0
	for d in PortSim.DEPTS:
		if s.feature("dept_" + d) and s.dept_cost(d, 1) <= s.money:
			n += 1
	for ci in PortSim.NCARGO:
		if s.unlocked[ci] == 1 and s.feature("licences") and s.licence_cost(ci, 1) <= s.money:
			n += 1
	return n


func _refresh_progress(s: PortSim) -> void:
	var tag := "Concession %d · " % (s.prestiges + 1) if s.prestiges > 0 else ""
	if s.can_prestige():
		prog_bar.value = 1.0
		prog_bar.color = UI.MONEY
		prog_bar.text = "NOUVELLE CONCESSION ✦ +%d" % s.prestige_gain()
	elif s.finished:
		prog_bar.value = 1.0
		prog_bar.color = UI.MONEY
		prog_bar.text = tag + "Concession nationale ✓"
	else:
		prog_bar.value = s.tier_progress()
		prog_bar.color = UI.AMBER
		prog_bar.text = "%sT%d → T%d · %d %%" % [tag, s.tier, s.tier + 1, floori(s.tier_progress() * 100.0)]


func _on_revenue(amount: float, source: String) -> void:
	_rev_acc[source] = float(_rev_acc.get(source, 0.0)) + amount


func _flush_revenue(s: PortSim) -> void:
	for src in _rev_acc:
		var a: float = _rev_acc[src]
		if a < 0.5:
			continue
		var p := Layout.HARBOR_OFFICE + Vector3(0, 6, 0)
		match src:
			"handling":
				for b in s.berths.size():
					if int(s.berths[b].ship) >= 0:
						p = Vector3(Layout.berth_center(b), 10, Layout.QUAY_Z)
						break
			"gate":
				p = Layout.GATE + Vector3(0, 6, 4)
			"inspection":
				p = Bubbles.anchor_point("customs_hut", Layout.CUSTOMS_HUT) + Vector3(0, 1.5, 0)
			"reefer":
				p = Vector3(24, 6, 39)
		overlay.add_popup(p, "+" + Fmt.money(a))
	_rev_acc.clear()


## Bas des cartes du haut (conseil, aléa, notifications), en coordonnées écran : la surcouche monde n'écrit pas dessous.
func top_cards_bottom() -> float:
	var y := 0.0
	for c in [hint_card, event_card, toast_box, mgr_btn]:
		var ctl: Control = c
		if ctl.is_visible_in_tree():
			y = maxf(y, ctl.get_global_rect().end.y)
	return y


func flash_money() -> void:
	var tw := create_tween()
	money_l.scale = Vector2(1.15, 1.15)
	tw.tween_property(money_l, "scale", Vector2.ONE, 0.2)


func world_shake() -> void:
	diorama.rig.shake(0.8)


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

## Goulots qui se règlent par un bâtiment (le bouton du conseil ouvre Gestion → Bâtiments).
const BUILD_KEYS := ["yard_space", "berth_count", "min_time", "attract"]


func _on_hint_pressed() -> void:
	var key: String = GameState.sim.analysis.get("key", "")
	GameState.sim.add_counter("hint_used")     # le tutoriel attend ce geste (« corrige le goulot »)
	if key in BUILD_KEYS:
		open_sheet(ManageSheet.new(0))
	elif key == "harbor" and GameState.sim.feature("commerce"):
		open_sheet(CommerceSheet.new(CommerceSheet.TAB_TRAFFIC))
	elif key == "tier":
		open_sheet(ManageSheet.new(3))
	else:
		open_upgrades(GameState.sim.analysis.get("dept", ""))


## Coup de main sur une grue (touche dans le monde).
func _on_assist(pos: Vector3, amount: float) -> void:
	Sfx.play("coin", 0.1)
	overlay.add_popup(pos, "Coup de main ! +%s EVP" % Fmt.num(amount), UI.AMBER)
	diorama.rig.shake(0.15)


func _on_prioritized(_id: int) -> void:
	Sfx.play("bell", 0.3)
	toast("Accostage en priorité : le pilote file plus vite.", "info")


func _on_boost() -> void:
	var s := GameState.sim
	var b: Dictionary = s.db.cfg("boost")
	if s.start_boost():
		Sfx.play("tier")
		toast("Heures sup : tout le port tourne ×%s pendant %d s !" % [Fmt.num(float(b.mult)), int(b.duration)], "good")
	elif s.boost_active():
		Sfx.play("bad")
	elif s.amber >= int(b.amber_skip):
		# l'Ambre est la monnaie rare : un toucher sur le bouton ne doit pas la dépenser sans confirmation
		var go := UI.button("TERMINER LA RECHARGE\n%d Ambre" % int(b.amber_skip), UI.AMBER, 28, 100)
		go.pressed.connect(func() -> void:
			if GameState.sim.skip_boost_cooldown():
				Sfx.play("coin")
				toast("Recharge terminée grâce à l'Ambre.", "good"))
		show_popup("Heures sup en recharge", [
			UI.wrap_label("Encore %s avant de pouvoir relancer. Tu peux la terminer tout de suite pour %d Ambre (tu en as %d)." % [
				Fmt.duration(s.boost_ready_at - s.time), int(b.amber_skip), s.amber], 30, UI.TEXT)], "boost", [go], "PLUS TARD")
	else:
		Sfx.play("bad")
		toast("Recharge en cours : %s. Il faut %d Ambre pour la terminer." % [Fmt.duration(s.boost_ready_at - s.time), int(b.amber_skip)], "info")


func _on_event_pay() -> void:
	if Hazards.pay(GameState.sim):
		Sfx.play("coin")
	else:
		Sfx.play("bad")


func open_upgrades(dept: String) -> void:
	open_sheet(UpgradesSheet.new(dept))


func open_sheet(s: Sheet) -> void:
	for c in sheet_layer.get_children():
		c.queue_free()
	sheet_layer.add_child(s)
	diorama.rig.input_enabled = false
	s.closed.connect(func() -> void: diorama.rig.input_enabled = true)
	Sfx.play("click")


func any_sheet_open() -> bool:
	return sheet_layer.get_child_count() > 0


# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------

func toast(text: String, kind: String = "info") -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_toasts_recent.get(text, -100.0)) < 8.0:
		return
	if _toasts_recent.size() > 24:      # les textes portent des montants : sans purge la table grossit toute la partie
		for k in _toasts_recent.keys():
			if now - float(_toasts_recent[k]) >= 8.0:
				_toasts_recent.erase(k)
	_toasts_recent[text] = now
	while toast_box.get_child_count() >= 3:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	var col := {"good": UI.MONEY, "bad": UI.BAD}.get(kind, UI.INFO) as Color
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.card_style(col, 26, 20))
	var l := UI.wrap_label(text, 28, Color.WHITE)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(p)
	var tw := p.create_tween()      # lié au toast : s'arrête avec lui s'il est chassé par un plus récent
	p.modulate.a = 0.0
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(3.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func _on_notify(text: String, kind: String) -> void:
	toast(text, kind)
	if kind == "bad":
		Sfx.play("horn", 2.0)
	elif kind == "good":
		Sfx.play("bell", 0.5)


func _on_mission(_id: String) -> void:
	Sfx.play("bell", 1.0)
	toast("Mission accomplie : va la réclamer !", "good")


# ---------------------------------------------------------------------------
# Révélation progressive et moments marquants
# ---------------------------------------------------------------------------

## Une fonction se révèle : son bouton apparaît avec un rebond, et un bandeau explique à quoi elle sert.
func _on_feature(id: String) -> void:
	var u: Dictionary = GameState.db.unlock_by_id.get(id, {})
	if u.is_empty():
		return
	var ctls: Array = feature_ctl.get(id, [])
	if ctls.is_empty() and (id.begins_with("dept_") or id == "licences"):
		ctls = [tut_targets["upgrade"]]        # nouvelle carte dans Améliorer : on fait rebondir ce bouton
	for c in ctls:
		_pop_in(c as Control)
	var where := " (dans Améliorer)" if id.begins_with("dept_") or id == "licences" else ""
	_queue_banner("Nouveau : %s%s" % [u.name, where], String(u.text), String(u.get("icon", "info")), UI.VIOLET)


## Premier navire d'une nouvelle classe (le quai allongé, le chenal dragué… portent leurs fruits) : on le montre.
func _on_first_class(sh: Ship) -> void:
	var sd: Dictionary = GameState.db.ship_by_id[sh.cls]
	Sfx.play("ship_horn", 0.5)
	diorama.rig.focus(Layout.anchor_pos(maxi(0, sh.anchor_slot)))
	_queue_banner("Premier %s en approche !" % String(sd.name).to_lower(), String(sd.get("arrival", "")), "ship", UI.MONEY)


func _pop_in(c: Control) -> void:
	if c == null:
		return
	c.visible = true
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(0.3, 0.3)
	c.modulate = Color(1.6, 1.6, 1.6)
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate", Color.WHITE, 1.2)


func _queue_banner(title: String, text: String, icon_name: String, col: Color) -> void:
	_banner_queue.append({"title": title, "text": text, "icon": icon_name, "col": col})
	if _banner == null:
		_next_banner()


## Bandeau non bloquant au milieu de l'écran (toucher pour le fermer) ; les suivants attendent leur tour.
func _next_banner() -> void:
	if _banner_queue.is_empty():
		_banner = null
		return
	var b: Dictionary = _banner_queue.pop_front()
	Sfx.play("bell", 0.2)
	var card := UI.card(Color.WHITE, 30)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	card.custom_minimum_size = Vector2(900, 0)
	card.offset_left = -450
	card.offset_right = 450
	card.offset_top = 760
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.z_index = 5            # au-dessus des bulles de la surcouche monde (dessinée hors colonne, « top_level »)
	var h := UI.hbox(18)
	card.add_child(h)
	h.add_child(UI.icon_disc(String(b.icon), b.col, 96))
	var v := UI.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var tl := UI.wrap_label(String(b.title), 36, b.col)
	v.add_child(tl)
	if String(b.text) != "":
		v.add_child(UI.wrap_label(String(b.text), 27, UI.TEXT))
	add_child(card)
	move_child(card, popup_layer.get_index())     # sous les fenêtres, au-dessus du reste
	_banner = card
	card.modulate.a = 0.0
	card.pivot_offset = Vector2(450, 60)
	card.scale = Vector2(0.85, 0.85)
	var tw := card.create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "modulate:a", 1.0, 0.2)
	tw.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	tw.set_parallel(false)
	tw.tween_interval(6.5)
	tw.tween_property(card, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_close_banner.bind(card))
	card.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed:
			_close_banner(card))


func _close_banner(card: Control) -> void:
	if card != _banner or not is_instance_valid(card):
		return
	card.queue_free()
	_banner = null
	_next_banner()


func _on_event(ev: Dictionary) -> void:
	Sfx.play("horn", 1.0)
	if ev.id == "wind" or ev.id == "strike":
		world_shake()


func _on_tier(t: int) -> void:
	Sfx.play("tier")
	world_shake()
	if t >= 4:
		_end_screen()
	else:
		var td := GameState.sim.db.tier_def(t)
		show_popup("Palier T%d atteint !" % t, [UI.label(String(td.name), 44, UI.VIOLET), UI.wrap_label(String(td.story), 30, UI.TEXT),
			UI.wrap_label("Nouveaux bâtiments et responsables, de nouveaux armateurs à démarcher et plus de lignes régulières (Commerce). +%d Ambre." % int(td.get("amber", 0)), 28)], "trophy")


# ---------------------------------------------------------------------------
# Fenêtres
# ---------------------------------------------------------------------------

func show_popup(title: String, body: Array, icon_name: String = "info", buttons: Array = [], ok_text: String = "OK") -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.25, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	popup_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var card := UI.card(Color.WHITE, 40)
	card.custom_minimum_size = Vector2(900, 0)
	center.add_child(card)
	var v := UI.vbox(18)
	card.add_child(v)
	var h := UI.hbox(16)
	v.add_child(h)
	h.add_child(UI.icon_disc(icon_name, UI.VIOLET, 96))
	var tl := UI.wrap_label(title, 46, UI.VIOLET)
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(tl)
	for b in body:
		v.add_child(b)
	var row := UI.hbox(14)
	v.add_child(row)
	for bt in buttons:
		row.add_child(bt)
		(bt as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(bt as Button).pressed.connect(dim.queue_free)
	var ok := UI.button(ok_text, UI.INDIGO, 34, 100)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func() -> void:
		Sfx.play("click")
		dim.queue_free())
	row.add_child(ok)
	card.scale = Vector2(0.9, 0.9)
	card.pivot_offset = Vector2(450, 300)
	var tw := create_tween()
	tw.tween_property(card, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)
	return dim


func show_breakdown(title: String, stat: String, cargo_i: int = 0) -> void:
	var s := GameState.sim
	var f := s.breakdown(stat, cargo_i)
	var body: Array = []
	var total := 1.0
	for i in f.size():
		var e: Dictionary = f[i]
		total *= float(e.value)
		var h := UI.hbox(10)
		var l := UI.label(String(e.label), 32, UI.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		# la première ligne est la valeur de base (comparer les dictionnaires par valeur confondait deux lignes identiques)
		var val := Fmt.num(float(e.value)) if i == 0 else Fmt.mult(float(e.value))
		h.add_child(UI.label(val, 32, UI.BAD if float(e.value) < 1.0 else UI.MONEY, true))
		body.append(h)
	var sep := ColorRect.new()
	sep.color = UI.GREY
	sep.custom_minimum_size.y = 3
	body.append(sep)
	var unit := "/EVP" if stat == "value" else ("" if stat.ends_with("speed") else " EVP/s")
	var tot := UI.label("Total : %s%s" % [Fmt.num(total), unit], 36, UI.VIOLET, true)
	body.append(tot)
	show_popup("Pourquoi ? — " + title, body, "info")


func _on_ship_tapped(id: int) -> void:
	var s := GameState.sim
	var sh := s.ship_by_id(id)
	if sh == null:
		return
	var od: Dictionary = s.db.owner_by_id[sh.owner]
	var body: Array = []
	body.append(UI.label("%s de %s (%s)" % [s.db.ship_by_id[sh.cls].name, od.name, od.home], 32, UI.TEXT))
	body.append(UI.label("%s EVP · %s" % [Fmt.num(sh.evp_total), Ship.STATE_NAMES[sh.state]], 30, UI.MUTED))
	var mix := ""
	for c in PortSim.NCARGO:
		if sh.left[c] > 0.5:
			mix += "%s %s · " % [s.db.cargo[c].short, Fmt.num(sh.left[c])]
	if mix != "":
		body.append(UI.wrap_label("Restant : " + mix.trim_suffix(" · "), 28, UI.TEXT))
	var buttons: Array = []
	if sh.state == Ship.State.ANCHORED or sh.state == Ship.State.ARRIVING:
		var bar := RoundBar.new(40)
		bar.value = sh.patience_ratio()
		bar.color = WorldOverlay.MOOD_COL[sh.mood()]
		bar.text = "Patience %d s" % ceili(sh.patience)
		body.append(bar)
		if not s.managers.harbor and sh.state == Ship.State.ANCHORED:
			var b := UI.button("ACCOSTER EN PRIORITÉ", UI.MONEY, 30, 100)
			b.pressed.connect(func() -> void:
				if s.prioritize_ship(id):
					Sfx.play("bell"))
			buttons.append(b)
		elif s.managers.harbor:
			body.append(UI.wrap_label("La capitaine Roche gère les accostages automatiquement.", 26))
	show_popup("Escale n°%d" % id, body, "ship", buttons)
	Sfx.play("click")


## Retour après une absence (au lancement, ou après une veille / un passage en arrière-plan).
func _on_offline(rep: Dictionary) -> void:
	if float(rep.seconds) >= 300.0:
		_welcome_back(rep)
	else:
		# courte absence : un simple message, pas de fenêtre
		toast("De retour ! +%s pendant ton absence." % Fmt.money(float(rep.money)), "good")


func _welcome_back(r: Dictionary) -> void:
	var body: Array = []
	var cap_h := int(GameState.db.cfg("offline_max_hours", 8))
	body.append(UI.wrap_label("Tu étais absent·e %s%s." % [Fmt.duration(float(r.seconds)), " (plafonné à %d h)" % cap_h if r.capped else ""], 32, UI.TEXT))
	var h := UI.hbox(10)
	h.add_child(UI.icon("money", 60))
	h.add_child(UI.label("+" + Fmt.money(float(r.money)), 52, UI.MONEY, true))
	body.append(h)
	body.append(UI.label("%s EVP traités pendant ton absence" % Fmt.num(float(r.evp)), 30, UI.MUTED))
	body.append(UI.wrap_label("Rendement hors-ligne : %s (%d responsable(s) sur %d). Chaque responsable augmente ce rendement." % [Fmt.pct(float(r.yield)), int(r.managers), PortSim.DEPTS.size()], 28))
	show_popup("Bon retour, directeur·rice !", body, "harbor")


## Premier lancement : trois idées, pas plus (le tutoriel guidé viendra ensuite).
func _intro() -> void:
	Settings.set_intro_seen()
	var body: Array = []
	body.append(UI.wrap_label("Un vieux quai de pêche, une grue rouillée… et tout un terminal à bâtir.", 32, UI.TEXT))
	for line in [
		["ship", "Les navires accostent, la grue décharge, les conteneurs gagnent le parc puis sortent par la gate."],
		["upgrade", "Le maillon le plus lent est le goulot : la carte rouge en haut te dit quoi améliorer."],
		["people", "Embauche des responsables : ils font tourner le port pour toi, même quand tu es parti."],
	]:
		var h := UI.hbox(14)
		h.add_child(UI.icon_disc(String(line[0]), UI.VIOLET, 80))
		h.add_child(UI.wrap_label(String(line[1]), 28, UI.TEXT))
		body.append(h)
	show_popup("Bienvenue, directeur·rice !", body, "harbor")


func _end_screen() -> void:
	var s := GameState.sim
	var body: Array = []
	body.append(UI.wrap_label("L'État te confie le terminal de Port Horizon pour 30 ans. Le vieux quai de pêche est devenu un terminal national.", 32, UI.TEXT))
	body.append(UI.label("Temps de jeu : %s" % Fmt.duration(s.time), 30, UI.MUTED))
	body.append(UI.label("EVP traités : %s" % Fmt.num(s.counter("evp")), 30, UI.MUTED))
	body.append(UI.label("Escales : %s · Camions : %s" % [Fmt.num(s.counter("ships")), Fmt.num(s.counter("trucks"))], 30, UI.MUTED))
	body.append(UI.wrap_label("Le port tourne toujours. Tu peux aussi ouvrir une nouvelle concession : tout repart de zéro, mais ton Renom ✦ " \
		+ "accélère et enrichit chaque nouveau port.", 28))
	var go := UI.button("NOUVELLE CONCESSION", UI.MONEY, 30, 100)
	go.pressed.connect(func() -> void: open_sheet(ManageSheet.new(3)))
	show_popup("Concession nationale !", body, "trophy", [go])


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F1 and DebugArgs.allowed():   # outils de débogage : jamais en version exportée
		toggle_debug()


func toggle_debug() -> void:
	if debug_panel != null:
		debug_panel.queue_free()
		debug_panel = null
		Sim.speed = 1.0
		return
	debug_panel = DebugPanel.new()
	add_child(debug_panel)
