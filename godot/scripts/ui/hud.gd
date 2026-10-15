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
var prog_btn: Control             # cible de toucher de la barre de palier (bloc argent + barre, ≥ 96 px)
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
var hint_dot: PanelContainer
var _hint_can := true          # le conseil propose une action possible (vert) ; restylé seulement au changement
var _hint_alert := true        # carte Goulot en alerte (rouge) ; restylée seulement au changement (lot D-Éco)
var event_card: PanelContainer
var ev_icon: TextureRect
var ev_title: Label
var ev_text: Label
var ev_bar: RoundBar
var ev_btn: Button
var toast_box: VBoxContainer
var top_box: Control
var head_bar: Control
var bottom_box: Control
var skip_hint: Label                   # « Toucher pour passer » pendant une ouverture de zone
var _toast_queue: Array = []           # notifications en attente (une à la fois ; aucune pendant une ouverture)
var _toast_cur: Control
var hud_fade := 1.0                     # 0 pendant une ouverture de zone : le HUD est masqué, on ne voit que le port
var boost_btn: BoostButton
var contracts_badge: PanelContainer
var amber_btn: Button
var line_box: Control                  # ligne du coffre et de la carte Goulot
var strip_box: Control                 # bandeau des missions (replié par défaut)
var settings_btn: Button
var manage_btn: Button
var upgrade_btn: Button
var mgr_pill: PanelContainer           # pastille « responsables à embaucher » sur Gestion
var mgr_pill_l: Label
var _chest_claim := false
var _hint_open_t := 0.0                # le détail de la carte Goulot se replie seul après quelques secondes
var _aff_n := 0                        # achats abordables qui rapportent (pastille d'Améliorer), recalculés une fois par seconde
var _aff_t := -10.0
var _cam_back := Vector3.INF           # cadrage du joueur avant une feuille mi-hauteur (rendu à sa fermeture)
var _cam_set := Vector3.INF            # dernier cadrage posé par l'interface pendant la feuille
var _buy_fx: Dictionary = {}           # achat en attente de son retour (service, stat avant, instant)
var _buy_fx_t := -10.0
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
var _fee_prev := 0.0           # dont services facturés (lot E : un achat qui ne bouge que les services n'est pas « le goulot »)
var _est_t := 0.0
var _purchase_seen := false
var _lifts: Array = []         # [temps de jeu de l'achat, gain par seconde]
var _gain_sum := 0.0
var _gain_time := -100.0
# bandeau des missions (sous la barre du haut)
var mission_strip: HBoxContainer
var chest_btn: Button
var strip_fold: Button
var strip_folded := true           # bandeau des missions replié par défaut (le coffre le déroule)
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
	_build_event_pill()
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
	diorama.lot_tapped.connect(open_building)
	diorama.zone_tapped.connect(func(zid: int, pos: Vector3) -> void: overlay.show_zone_info(zid, pos))
	diorama.zone_opened.connect(_on_zone_opened)
	diorama.gesture_done.connect(_on_gesture)
	# lot F3 : débarque vendue sur le ponton ou à la criée (« +X $ »), plus grande après un coup de main
	diorama.fish_popup.connect(func(p: Vector3, t: String, big: bool) -> void:
		fish_popups += 1
		Sfx.play("coin", 0.05)
		overlay.add_popup(p, t, UI.AMBER if big else UI.MONEY, big))
	if diorama.has_signal("ship_paid"):
		diorama.connect("ship_paid", _on_ship_paid)
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
	# nouvelle partie (prestige, réinitialisation, chargement) : rien de l'ancienne ne s'affiche plus (revue C7 B2) —
	# notifications et bandeaux en file ou à l'écran, narratrice, bulle d'une zone grise
	_toast_queue.clear()
	for c in [_toast_cur, _banner, _narration]:
		if c != null and is_instance_valid(c):
			(c as Node).queue_free()
	_toast_cur = null
	_banner = null
	_narration = null
	_banner_queue.clear()
	if overlay != null:
		overlay.zone_info = {}
	if diorama != null and diorama.rig != null:
		diorama.rig.input_enabled = true
	_money_disp = -1.0
	_refresh(s)
	# lot F2 : partie neuve — cartes d'intro (la première fois), friche, séquence de chantiers du T1, premier navire
	_end_start()
	if GameState.consume_start():
		_begin_start()
	elif s.fishing.act0:
		_resume_act0()          # lot F3 : partie chargée pendant l'acte 0 (ou pendant la bascule) : on reprend dans l'anse
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

## Lot D-UI : HUD du haut sous 20 % de l'écran (ISM ≈ 15 %) — la barre indigo, puis **une ligne** : le coffre des missions
## (bandeau replié par défaut) et la carte Goulot réduite à son titre et son bouton (le détail au toucher). Plus de colonne
## de boutons carrés à droite : Améliorer est le gros bouton en bas à droite, Stats est dans Gestion, Responsables est une
## pastille sur Gestion, Missions est le coffre.
func _build_top() -> void:
	var top := UI.vbox(12)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 0
	top.offset_right = 0
	add_child(top)
	top_box = top
	# barre haute indigo
	var bar := PanelContainer.new()
	var bs := UI.flat(UI.INDIGO, 0, 22, 12)
	bs.content_margin_top = 30
	bs.corner_radius_bottom_left = 44
	bs.corner_radius_bottom_right = 44
	bs.shadow_color = Color(0.1, 0.05, 0.3, 0.3)
	bs.shadow_size = 12
	bar.add_theme_stylebox_override("panel", bs)
	head_bar = bar
	top.add_child(bar)
	var row := UI.hbox(10)
	bar.add_child(row)
	# revenu par seconde (une seule unité de revenu partout : $/s)
	var inc := _top_pill(row, "money", UI.MONEY)
	income_l = inc
	# pastille « +X $/s » sous le revenu après un achat (hors de la barre : elle ne la fait pas grandir)
	gain_pill = PanelContainer.new()
	gain_pill.add_theme_stylebox_override("panel", UI.flat(Color.WHITE, 22, 14, 4))
	gain_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gain_pill.top_level = true
	gain_pill.visible = false
	gain_pill.z_index = 6
	gain_l = UI.label("", 28, UI.MONEY, true)
	gain_pill.add_child(gain_l)
	add_child(gain_pill)
	row.add_child(UI.spacer(0, 0, true))
	var mv := UI.vbox(2)
	mv.alignment = BoxContainer.ALIGNMENT_CENTER
	money_l = UI.label("0 $", 56, Color.WHITE, true)
	money_l.pivot_offset = Vector2(120, 34)
	money_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(money_l)
	# progression vers le palier suivant (touche : ouvre l'onglet Port) — texte foncé sur ambre, 24 px
	prog_bar = RoundBar.new(36)
	prog_bar.custom_minimum_size = Vector2(320, 36)
	prog_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	prog_bar.font_size = 24
	prog_bar.color = UI.AMBER
	prog_bar.bg = Color("#FFE3A3")
	prog_bar.dark_text = true
	# lot E : la cible de toucher est le bloc argent + barre (≥ 96 px de haut), plus la seule barre de 36 px
	prog_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mv.add_child(prog_bar)
	# (un conteneur, pas un bouton : il n'apparaît pas parmi les boutons du HUD, et ne réagit qu'une fois la barre révélée)
	var pb := MarginContainer.new()
	pb.mouse_filter = Control.MOUSE_FILTER_STOP
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.custom_minimum_size = Vector2(0, 96)
	pb.tooltip_text = "Palier suivant"
	pb.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and prog_bar.is_visible_in_tree():
			open_sheet(ManageSheet.new(3)))
	mv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.add_child(mv)
	prog_btn = pb
	row.add_child(pb)
	row.add_child(UI.spacer(0, 0, true))
	# Ambre : la pastille et son « + » ne font qu'une cible de 96 px, qui explique comment en gagner
	var amb := Button.new()
	amb.focus_mode = Control.FOCUS_NONE
	amb.flat = true
	for st in ["normal", "hover", "pressed", "focus"]:
		amb.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	amb.custom_minimum_size = Vector2(0, 96)
	amb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	amb.tooltip_text = "Comment gagner de l'Ambre"
	amb.pressed.connect(show_amber_help)
	var ah := UI.hbox(4)
	ah.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ah.alignment = BoxContainer.ALIGNMENT_CENTER
	amb.add_child(ah)
	var apill := PanelContainer.new()
	apill.add_theme_stylebox_override("panel", UI.flat(UI.INDIGO_DARK, 30, 12, 6))
	apill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var aph := UI.hbox(6)
	apill.add_child(aph)
	aph.add_child(UI.icon("amber", 48))
	amber_l = UI.label("0", 36, UI.AMBER, true)
	aph.add_child(amber_l)
	ah.add_child(apill)
	var plus := PanelContainer.new()
	plus.add_theme_stylebox_override("panel", UI.flat(UI.AMBER, 24))
	plus.custom_minimum_size = Vector2(48, 48)
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pl := UI.label("+", 38, UI.TEXT, true)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.add_child(pl)
	ah.add_child(plus)
	amber_btn = amb
	row.add_child(amb)
	# la largeur du bouton suit son contenu (pastille + « + »)
	ah.resized.connect(func() -> void: amb.custom_minimum_size.x = ah.get_combined_minimum_size().x)
	feature_ctl["amber"] = [amb]
	stars_l = _top_pill(row, "star", UI.AMBER)
	feature_ctl["stars"] = [stars_l.get_parent().get_parent()]
	feature_ctl["progress"] = [prog_bar]
	# --- une ligne : coffre des missions + carte Goulot ----------------------------------------------------------
	var m2 := MarginContainer.new()
	m2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m2.add_theme_constant_override("margin_left", 20)
	m2.add_theme_constant_override("margin_right", 20)
	top.add_child(m2)
	line_box = m2
	var row2 := UI.hbox(12)
	m2.add_child(row2)
	# coffre des missions : n/N, devient vert « ! » quand une mission est à réclamer (un toucher la réclame)
	chest_btn = UI.button("", UI.INDIGO, 26, 104)
	chest_btn.icon = UI.icon_tex("chest")
	chest_btn.expand_icon = true
	chest_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chest_btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	chest_btn.add_theme_constant_override("icon_max_width", 46)
	chest_btn.add_theme_constant_override("h_separation", 0)
	chest_btn.custom_minimum_size = Vector2(110, 104)
	chest_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chest_btn.tooltip_text = "Missions"
	chest_btn.pressed.connect(_on_chest)
	row2.add_child(chest_btn)
	miss_badge = _badge_on(chest_btn, "!")
	miss_badge.position = Vector2(76, -12)
	tut_targets["missions"] = chest_btn
	tut_targets["mission_strip"] = chest_btn
	# carte Goulot : une ligne (pastille, titre, bouton « quoi · combien ») ; toucher la carte déroule le détail
	hint_card = UI.card(Color.WHITE, 14)
	hint_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_card.mouse_filter = Control.MOUSE_FILTER_STOP
	hint_card.gui_input.connect(_on_hint_card_input)
	row2.add_child(hint_card)
	var hv := UI.vbox(6)
	hint_card.add_child(hv)
	var hh := UI.hbox(10)
	hv.add_child(hh)
	var dot := PanelContainer.new()
	dot.add_theme_stylebox_override("panel", UI.flat(UI.BAD, 14))
	dot.custom_minimum_size = Vector2(28, 28)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hh.add_child(dot)
	hint_dot = dot
	hint_title = UI.label("", 30, UI.BAD)
	hint_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_title.clip_text = true
	hint_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hh.add_child(hint_title)
	hint_btn = UI.button("AGIR", UI.MONEY, 26, 96)
	hint_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint_btn.pressed.connect(_on_hint_pressed)
	hh.add_child(hint_btn)
	hint_text = UI.wrap_label("", 26, UI.TEXT)
	hint_text.visible = false
	hv.add_child(hint_text)
	tut_targets["hint"] = hint_card
	# bandeau des missions (replié par défaut, sous la ligne) : les 2 missions en cours
	_build_mission_strip(top)
	feature_ctl["missions"] = [chest_btn, strip_box]
	# bandeau d'aléa, compact : icône, titre + minuterie, bouton
	var m3 := MarginContainer.new()
	m3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m3.add_theme_constant_override("margin_left", 20)
	m3.add_theme_constant_override("margin_right", 20)
	top.add_child(m3)
	event_card = UI.card(Color("#FFF1DE"), 14)
	event_card.visible = false
	m3.add_child(event_card)
	var eh := UI.hbox(12)
	event_card.add_child(eh)
	var ed := PanelContainer.new()
	ed.add_theme_stylebox_override("panel", UI.flat(UI.ORANGE, 34))
	ed.custom_minimum_size = Vector2(68, 68)
	ed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ev_icon = UI.icon("wind", 42)
	ev_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ev_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ed.add_child(ev_icon)
	eh.add_child(ed)
	var et := UI.vbox(4)
	et.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eh.add_child(et)
	ev_title = UI.label("", 28, UI.ORANGE.darkened(0.2))
	ev_title.clip_text = true
	ev_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	et.add_child(ev_title)
	ev_text = UI.wrap_label("", 24, UI.TEXT)
	ev_text.visible = false          # le détail de l'aléa : au toucher (comme la carte Goulot)
	et.add_child(ev_text)
	ev_bar = RoundBar.new(32)
	ev_bar.color = UI.ORANGE
	ev_bar.font_size = 24
	et.add_child(ev_bar)
	ev_btn = UI.button("", UI.ORANGE, 24, 96)
	ev_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ev_btn.pressed.connect(_on_event_pay)
	eh.add_child(ev_btn)
	event_card.mouse_filter = Control.MOUSE_FILTER_STOP
	event_card.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			ev_text.visible = not ev_text.visible)
	# notifications : une à la fois, en file, sous l'en-tête (jamais au milieu de l'écran sur un navire) ; voir _process
	toast_box = UI.vbox(10)
	toast_box.top_level = true
	toast_box.z_index = 4
	add_child(toast_box)
	feature_ctl["stats"] = []            # les statistiques sont dans Gestion (onglet Stats)


var ev_pill: PanelContainer        # aléa en cours, en pastille compacte au-dessus d'une feuille mi-hauteur (lot E)
var ev_pill_l: Label
var ev_pill_icon: TextureRect


## Pastille d'aléa : pendant une feuille mi-hauteur le HUD du haut est replié ; l'aléa en cours reste visible en haut à
## gauche du port (icône, nom, secondes). Elle laisse passer le toucher : toucher le port referme la feuille, et la carte
## complète de l'aléa (avec « Sécuriser ») réapparaît.
func _build_event_pill() -> void:
	ev_pill = PanelContainer.new()
	ev_pill.add_theme_stylebox_override("panel", UI.card_style(Color("#FFF1DE"), 30, 14))
	ev_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ev_pill.position = Vector2(24, 24)
	ev_pill.visible = false
	var h := UI.hbox(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ev_pill.add_child(h)
	var d := PanelContainer.new()
	d.add_theme_stylebox_override("panel", UI.flat(UI.ORANGE, 26))
	d.custom_minimum_size = Vector2(52, 52)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ev_pill_icon = UI.icon("wind", 34)
	ev_pill_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ev_pill_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	d.add_child(ev_pill_icon)
	h.add_child(d)
	ev_pill_l = UI.label("", 28, UI.ORANGE.darkened(0.25))
	ev_pill_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(ev_pill_l)
	add_child(ev_pill)


func _refresh_event_pill(s: PortSim) -> void:
	var ev := s.active_event
	var on := not ev.is_empty() and half_sheet_open() and hud_fade > 0.02
	ev_pill.visible = on
	if on:
		ev_pill_l.text = "%s · %d s" % [String(ev.name), maxi(0, ceili(float(ev.until) - s.time))]
		var ic := String(ev.get("icon", ""))
		ev_pill_icon.texture = UI.icon_tex(ic) if UI.icon_tex(ic) != null else UI.icon_tex("info")
		ev_pill.reset_size()


## Toucher la carte Goulot (hors de son bouton) : le détail du conseil se déroule ou se replie.
func _on_hint_card_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		hint_text.visible = not hint_text.visible
		Sfx.play("click")
		if hint_text.visible:
			_hint_open_t = 0.0


## Bandeau des missions (replié par défaut, sous la ligne du coffre) : les 2 missions en cours avec leur barre.
## Toucher une mission terminée la réclame ; sinon il ouvre l'écran Missions.
func _build_mission_strip(top: VBoxContainer) -> void:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	top.add_child(m)
	strip_box = m
	mission_strip = UI.hbox(10)
	m.add_child(mission_strip)
	for i in 2:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_contents = true
		UI.style_button(b, Color(1, 1, 1, 0.94), 22)
		var v := UI.vbox(4)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 14
		v.offset_right = -14
		v.offset_top = 8
		v.offset_bottom = -8
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var l := UI.label("", 24, UI.TEXT)
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
		var bar := RoundBar.new(32)
		bar.font_size = 24
		bar.color = UI.INFO
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(bar)
		b.pressed.connect(_on_strip_mission.bind(i))
		mission_strip.add_child(b)
		strip_items.append({"btn": b, "label": l, "bar": bar, "id": ""})
	strip_fold = UI.button("▲", UI.INDIGO, 30, 96)
	strip_fold.custom_minimum_size = Vector2(96, 96)
	strip_fold.tooltip_text = "Replier les missions"
	strip_fold.pressed.connect(func() -> void:
		strip_folded = true
		Sfx.play("click")
		_refresh_strip(GameState.sim))
	mission_strip.add_child(strip_fold)


func _refresh_strip(s: PortSim) -> void:
	var vis := Objectives.visible_missions(s)
	var claim := false
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
		claim = claim or done
		(it.label as Label).text = ("✓ " if done else "") + String(mi.text)
		var bar: RoundBar = it.bar
		bar.value = p / maxf(t, 0.0001)
		bar.color = UI.MONEY if done else UI.INFO
		bar.text = "RÉCLAMER" if done else ("%s / %s" % [Fmt.num(minf(p, t)), Fmt.num(t)] if t > 1.0 else "")
	strip_box.visible = s.feature("missions") and not strip_folded
	var cp := Objectives.chest_progress(s)
	chest_btn.text = "%d/%d" % [cp.x, cp.y] if cp.y > 0 else "Missions"
	if claim != _chest_claim:
		_chest_claim = claim
		UI.style_button(chest_btn, UI.MONEY if claim else UI.INDIGO)
	strip_fold.text = "▲"


## Coffre : une mission à réclamer → réclamée d'un toucher ; sinon le bandeau des missions se déroule (ou se replie).
func _on_chest() -> void:
	var s := GameState.sim
	var vis := Objectives.visible_missions(s)
	for i in mini(vis.size(), strip_items.size()):
		var mi: Dictionary = vis[i]
		if Objectives.mission_progress(s, mi) >= float(mi.target):
			strip_items[i].id = String(mi.id)
			_on_strip_mission(i)
			return
	strip_folded = not strip_folded
	Sfx.play("click")
	_refresh_strip(s)


func _on_strip_mission(i: int) -> void:
	var s := GameState.sim
	var it: Dictionary = strip_items[i]
	var b: Button = it.btn if (it.btn as Button).is_visible_in_tree() else chest_btn
	if Objectives.claim(s, String(it.id)):
		var lc := s.last_claim
		Sfx.play("chest" if bool(lc.get("chest", false)) else "coin")
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
	h.add_child(UI.icon(icon_name, 50))
	var l := UI.label("0", 34, col, true)
	h.add_child(l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(p)
	return l


func _badge_on(b: Control, text: String, col: Color = UI.BAD) -> PanelContainer:
	var bd := UI.badge(text, col, 26)
	bd.position = Vector2(80, -10)
	bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(bd)
	bd.visible = false
	return bd


## Barre du bas : Réglages en petit rond dans le coin, puis Gestion, Commerce et le gros bouton vert AMÉLIORER à droite
## (sous le pouce). Heures sup : bouton rond flottant au-dessus (voir BoostButton), hors de la barre.
func _build_bottom() -> void:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	m.offset_top = -200
	m.offset_bottom = 0
	m.offset_left = 0
	m.offset_right = 0
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_bottom", 28)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(m)
	bottom_box = m
	var row := UI.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_END
	m.add_child(row)
	# Réglages : petit rond dans le coin (96 px)
	var st := UI.button("", UI.INDIGO, 30, 96)
	st.custom_minimum_size = Vector2(96, 96)
	st.icon = UI.icon_tex("gear")
	st.expand_icon = true
	st.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.add_theme_constant_override("icon_max_width", 52)
	UI.style_button(st, UI.INDIGO, 48)
	st.size_flags_vertical = Control.SIZE_SHRINK_END
	st.tooltip_text = "Réglages"
	st.pressed.connect(func() -> void: open_sheet(SettingsSheet.new()))
	row.add_child(st)
	settings_btn = st
	row.add_child(UI.spacer(0, 0, true))
	# Gestion (avant « manage » : RESPONSABLES) avec la pastille des responsables à embaucher (ambre : « touche-moi »)
	var mg := _big("manage", "GESTION", UI.INDIGO, _on_manage_btn)
	mg.custom_minimum_size = Vector2(220, 150)
	row.add_child(mg)
	manage_btn = mg
	tut_targets["manage"] = mg
	tut_targets["managers"] = mg
	feature_ctl["manage"] = [mg]
	mgr_pill = PanelContainer.new()
	mgr_pill.add_theme_stylebox_override("panel", UI.flat(UI.AMBER, 22, 10, 2))
	mgr_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mph := UI.hbox(4)
	mgr_pill.add_child(mph)
	mph.add_child(UI.icon("people", 34, UI.TEXT))
	mgr_pill_l = UI.label("1", 28, UI.TEXT, true)
	mph.add_child(mgr_pill_l)
	mgr_pill.position = Vector2(140, -18)
	mgr_pill.visible = false
	mg.add_child(mgr_pill)
	feature_ctl["managers"] = [mgr_pill]
	mgr_btn = mg
	var cb := _big("ship", "COMMERCE", UI.VIOLET, func() -> void: open_sheet(CommerceSheet.new(_commerce_tab())))
	cb.custom_minimum_size = Vector2(220, 150)
	row.add_child(cb)
	tut_targets["commerce"] = cb
	tut_targets["contracts"] = cb
	commerce_btn = cb
	feature_ctl["commerce"] = [cb]       # rebondit à sa révélation ; visible aussi avec les seuls contrats (voir `_refresh`)
	contracts_badge = _badge_on(cb, "1")
	contracts_badge.position = Vector2(170, -14)
	# AMÉLIORER : le gros bouton vert en bas à droite, avec la pastille des achats qui rapportent
	var ub := _big("upgrade", "AMÉLIORER", UI.MONEY, func() -> void: open_upgrades(""))
	ub.custom_minimum_size = Vector2(300, 150)
	row.add_child(ub)
	upgrade_btn = ub
	upgrade_badge = _badge_on(ub, "0", UI.BAD)
	upgrade_badge.position = Vector2(246, -16)
	tut_targets["upgrade"] = ub
	# Heures sup : rond flottant au-dessus du bouton Améliorer (n'apparaît en grand que lorsqu'il est prêt)
	boost_btn = BoostButton.new()
	boost_btn.pressed.connect(_on_boost)
	add_child(boost_btn)
	feature_ctl["boost"] = [boost_btn]


func _big(icon_name: String, text: String, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(250, 150)
	UI.style_button(b, col, 36)
	b.pressed.connect(cb)
	var v := UI.vbox(0)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(v)
	var ic := UI.icon(icon_name, 66)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := UI.label(text, 28, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	b.set_meta("label", l)
	b.set_meta("icon", ic)
	return b


## Gestion (ou Responsables tant que Gestion n'est pas révélée) : sur l'onglet Responsables s'il y en a à embaucher.
func _on_manage_btn() -> void:
	var s := GameState.sim
	var tabi := 2 if (not s.feature("manage") or _waiting_managers(s) > 0) else 0
	open_sheet(ManageSheet.new(tabi))


func _waiting_managers(s: PortSim) -> int:
	var n := 0
	for d in PortSim.DEPTS:
		if not s.managers[d] and s.manager_revealed(d) and s.manager_available(d):
			n += 1
	return n


## « + » de l'Ambre : comment en gagner (il ouvrait les Missions, revue D-UI).
func show_amber_help() -> Control:
	Sfx.play("click")
	var body: Array = []
	body.append(UI.wrap_label("L'Ambre est la monnaie rare du port. Elle ne s'achète pas : elle se gagne.", 30, UI.TEXT))
	for line in [
		["chest", "Missions : chaque mission réclamée en rapporte (touche le coffre sous ton argent). Le coffre en donne en plus."],
		["contracts", "Contrats tenus avant l'échéance (Commerce → Contrats)."],
		["trophy", "Paliers du port et nouvelles concessions."],
	]:
		var h := UI.hbox(14)
		h.add_child(UI.icon_disc(String(line[0]), UI.AMBER, 76))
		h.add_child(UI.wrap_label(String(line[1]), 28, UI.TEXT))
		body.append(h)
	body.append(UI.wrap_label("Elle sert à embaucher un responsable en avance ou à relancer les Heures sup.", 28, UI.MUTED))
	var buttons: Array = []
	if GameState.sim.feature("missions"):
		var go := UI.button("MISSIONS", UI.VIOLET, 30, 100)
		go.pressed.connect(func() -> void: open_sheet(MissionsSheet.new()))
		buttons.append(go)
	return show_popup("Comment gagner de l'Ambre", body, "amber", buttons)


# ---------------------------------------------------------------------------
# Mise à jour
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	var s := GameState.sim
	if s == null:
		return
	_ui_t += delta
	var full := full_sheet_open()
	var half := half_sheet_open()
	# plein cadre ou fenêtre : les éléments gagnés à un palier et les ouvertures de zone attendent qu'on revienne au port.
	# Feuille mi-hauteur (Améliorer, Commerce) : le port continue de vivre au-dessus (lot D-UI) — seule une ouverture de zone
	# en attente patiente (elle masquerait l'interface sous la feuille).
	diorama.fx_paused = full or _npopups() > 0 or ceremony_active() or (half and not diorama.opening_queue.is_empty())
	_sync_start()
	_sync_opening(delta)
	# la surcouche monde est « top_level » : elle passerait sur les écrans plein cadre ; pendant une ouverture de zone, rien
	# lot E : ni sous une fenêtre (la bulle « en rade » passait au-dessus de la fenêtre du palier)
	overlay.visible = not full and not diorama.opening_active() and not ceremony_active() and _npopups() == 0
	_sync_toasts()
	# argent : le compteur monte en douceur, et chute d'un coup quand on dépense
	if _money_disp < 0.0 or s.money < _money_disp or absf(s.money - _money_disp) < 0.5:
		_money_disp = s.money
	else:
		_money_disp = lerpf(_money_disp, s.money, 1.0 - exp(-delta * 9.0))
	money_l.text = Fmt.money(_money_disp)
	_track_estimate(s, delta)
	_flush_buy_fx(s)
	_place_boost()
	if hint_text.visible:
		_hint_open_t += delta
		if _hint_open_t > 8.0:
			hint_text.visible = false
	if _ui_t >= 0.1:
		_ui_t = 0.0
		_refresh(s)
	_rev_t += delta
	if _rev_t >= 1.2:
		_rev_t = 0.0
		_flush_revenue(s)


## Heures sup : rond flottant au-dessus du bouton Améliorer, à droite.
func _place_boost() -> void:
	if boost_btn == null or upgrade_btn == null:
		return
	var r := upgrade_btn.get_global_rect()
	boost_btn.size = Vector2(BoostButton.HIT, BoostButton.HIT)
	boost_btn.global_position = Vector2(r.end.x - BoostButton.HIT + 6.0, r.position.y - BoostButton.HIT - 14.0)
	boost_btn.modulate.a = hud_fade
	boost_btn.visible = GameState.sim.feature("boost") and hud_fade > 0.02 and not any_sheet_open()


func _refresh(s: PortSim) -> void:
	# revenu net par seconde ; tant que rien n'a été déchargé, on n'affiche pas les salaires seuls
	# (lot E : revenu réel sur la fenêtre écoulée depuis le chargement — juste après un chargement, `income_per_min`
	# affichait « +41K $/s » pour un port qui en gagne 1,3M : les seaux d'une minute ne sont pas sauvegardés)
	var ips := s.real_income_rate() + _income_lift(s)
	# (lot F3 : la pêche rapporte avant le premier conteneur — acte 0, puis revenu passif)
	if s.counter("evp") <= 0.0 and s.prestiges == 0 and s.fishing.earned <= 0.0:
		ips = 0.0
	income_l.text = ("+" if ips >= 0 else "") + Fmt.num(ips) + " $/s"
	amber_l.text = str(s.amber)
	stars_l.text = ("%.1f" % s.stars()).replace(".", ",")
	_refresh_progress(s)
	for id in feature_ctl:
		var on := s.feature(String(id))
		for c in feature_ctl[id]:
			(c as Control).visible = on
	boost_btn.visible = s.feature("boost") and hud_fade > 0.02 and not any_sheet_open()
	commerce_btn.visible = s.feature("commerce") or s.feature("contracts")
	# pastille d'Améliorer : seulement les achats abordables qui rapportent (ou qui ouvrent le chapitre en cours)
	var n_aff := _affordable_count(s)
	upgrade_badge.visible = n_aff > 0
	(upgrade_badge.get_child(0) as Label).text = str(n_aff)
	# Responsables : intégrés à Gestion. Avant Gestion, le bouton s'appelle RESPONSABLES ; ensuite une pastille ambre
	# (« touche-moi ») compte ceux qui attendent qu'on les embauche — plus jamais un bouton gris (revue D-UI)
	var waiting_mgr := _waiting_managers(s)
	var on_manage := s.feature("manage")
	manage_btn.visible = on_manage or s.feature("managers")
	var ml: Label = manage_btn.get_meta("label")
	ml.text = "GESTION" if on_manage else "RESPONSABLES"
	(manage_btn.get_meta("icon") as TextureRect).texture = UI.icon_tex("manage" if on_manage else "people")
	mgr_pill.visible = s.feature("managers") and waiting_mgr > 0
	mgr_pill_l.text = str(waiting_mgr)
	miss_badge.visible = s.feature("missions") and Objectives.claimable_count(s) > 0
	if s.feature("missions"):
		_refresh_strip(s)
	# un seul badge numérique à la fois (revue N13) : celui des améliorations abordables passe avant le nombre de contrats
	contracts_badge.visible = s.contracts_active.size() > 0 and not upgrade_badge.visible
	(contracts_badge.get_child(0) as Label).text = str(s.contracts_active.size())
	# conseil de goulot (masqué pendant une carte du tutoriel : la narratrice parle seule, revue N3)
	hint_card.visible = not (tutorial != null and tutorial.active and tutorial._card.visible and tutorial.idx < tutorial.steps.size()
		and String(tutorial.steps[tutorial.idx].get("target", "")) != "ctl:hint") and not s.fishing.act0      # lot F3 : pas de goulot pendant l'acte 0
	var key: String = s.shown_analysis().get("key", "")
	hint_title.text = hint_title_for(s)
	hint_text.text = String(s.shown_analysis().get("hint", ""))
	# le bouton dit quoi et combien (« AMÉLIORER PARC · 12K $ », « QUAI N°2 · 150K $ ») ; vert dès qu'une action règle le goulot
	var act := hint_action(s)
	hint_btn.text = String(act.label)
	# règle « vert si possible, gris sinon » pour le bouton ; la carte ne passe au rouge qu'en alerte (lot D-Éco : un
	# goulot normal — il y en a toujours un — n'est pas une alerte ; `PortSim.alert_reason` : brouillard, navire sur le
	# point de repartir, parc presque plein, camions bloqués)
	var can := bool(act.can)
	if can != _hint_can:
		_hint_can = can
		UI.style_button(hint_btn, UI.MONEY if can else UI.GREY.darkened(0.15))
	var alert := String(s.shown_analysis().get("alert", "")) != ""
	if alert != _hint_alert:
		_hint_alert = alert
		hint_title.add_theme_color_override("font_color", UI.BAD if alert else UI.INDIGO)
		hint_dot.add_theme_stylebox_override("panel", UI.flat(UI.BAD if alert else UI.INFO, 14))
	if key != _last_hint:
		_last_hint = key
		var tw := create_tween()
		hint_card.modulate = Color(1.4, 1.2, 1.2)
		tw.tween_property(hint_card, "modulate", Color.WHITE, 0.5)
	# aléa
	var ev := s.active_event
	event_card.visible = not ev.is_empty()
	_refresh_event_pill(s)
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
			var pc := float(ev.get("pay_cost", 0.0))
			ev_btn.disabled = s.money < pc
			ev_btn.text = "%s\n%s" % [ev.pay_label, Fmt.money(pc)] if not ev_btn.disabled else "Il manque\n%s" % Fmt.money(pc - s.money)
		else:
			ev_btn.visible = true
			ev_btn.text = "Patienter"
			ev_btn.disabled = true
	# heures sup : rond flottant, grand seulement quand il est prêt (anneau discret pendant la recharge)
	var boost_state := "actif" if s.boost_active() else ("pret" if s.boost_ready() else "recharge")
	var bdef: Dictionary = s.db.cfg("boost")
	boost_btn.state = boost_state
	if boost_state == "actif":
		boost_btn.caption = "%d s" % ceili(s.boost_until - s.time)
		boost_btn.progress = clampf((s.boost_until - s.time) / maxf(1.0, float(bdef.duration)), 0.0, 1.0)
	elif boost_state == "pret":
		boost_btn.caption = "×%s" % Fmt.num(float(bdef.mult))
		boost_btn.progress = 1.0
	else:
		boost_btn.caption = ""
		var cd := maxf(1.0, float(bdef.get("cooldown", 300.0)))
		boost_btn.progress = clampf(1.0 - (s.boost_ready_at - s.time) / cd, 0.0, 1.0)
	boost_btn.tooltip_text = "Heures sup : " + ("actives" if boost_state == "actif" else ("prêtes" if boost_state == "pret" else "recharge %s" % Fmt.duration(s.boost_ready_at - s.time)))
	if boost_state != _boost_state:
		var was := _boost_state
		_boost_state = boost_state
		if boost_state == "pret" and was == "recharge":
			_pop_in(boost_btn)
		# les Heures sup se voient dans le monde (gyrophares, grues plus rapides : D-Monde)
		if diorama != null and diorama.has_method("set_overtime"):
			diorama.call("set_overtime", boost_state == "actif")
	# campagne de démarchage : pavillons sur la capitainerie (D-Monde)
	var camp := false
	for c in Commerce.campaigns(s):
		if Commerce.campaign_active(s, String(c.id)):
			camp = true
	if camp != _campaign_on:
		_campaign_on = camp
		if diorama != null and diorama.has_method("set_campaign"):
			diorama.call("set_campaign", camp)


var _campaign_on := false


## Titre de la carte Goulot.
static func hint_title_for(s: PortSim) -> String:
	var key: String = s.shown_analysis().get("key", "")
	var dept: String = s.shown_analysis().get("dept", "")
	var dname: String = s.db.dept_by_id[dept].name if s.db.dept_by_id.has(dept) else ""
	match key:
		"yard_space":
			# capacité théorique (place × rotation), pas le remplissage : « saturé » contredisait une jauge verte (revue D-UI)
			return "Goulot : parc trop petit"
		"berth_count":
			return "Goulot : postes à quai"
		"min_time":
			return "Goulot : escales au plancher"
		"tier":
			return "Goulot : taille des navires"
		"fog":
			return "Brouillard sur la rade"
		"harbor", "attract":
			return "Goulot : pas assez de navires"
	return "Goulot : " + dname


func _on_purchased(kind: String, id: String) -> void:
	_purchase_seen = true      # l'analyse n'est pas encore à jour : on compare à l'image suivante
	_aff_t = -10.0             # la pastille d'Améliorer est recomptée tout de suite
	if kind == "building" or kind == "manager":
		_aff_t = -10.0


## Compare le revenu estimé avant et après un achat (une estimation fraîche par seconde, et juste après chaque achat).
func _track_estimate(s: PortSim, delta: float) -> void:
	_est_t += delta
	if _purchase_seen:
		_purchase_seen = false
		var parts := s.income_parts_with("harbor", 0)
		var est := float(parts.total)
		var g := est - _est_prev if _est_prev >= 0.0 else 0.0
		var gf := float(parts.fees) - _fee_prev if _est_prev >= 0.0 else 0.0
		if g > 0.0:
			# la pastille verte « +X $/s » seulement si le débit bouge ; sinon `_flush_buy_fx` dit « pas le goulot »
			_add_gain(s, g, UpgradesSheet.moves_flow({"total": g, "flow": g - gf}) or _buy_fx.is_empty())
		if not _buy_fx.is_empty():
			_buy_fx.gain = float(_buy_fx.get("gain", 0.0)) + maxf(0.0, g)
			_buy_fx.fees = float(_buy_fx.get("fees", 0.0)) + maxf(0.0, gf)
			_buy_fx.seen = true
		_est_prev = est
		_fee_prev = float(parts.fees)
		_est_t = 0.0
	elif _est_t >= 1.0 or _est_prev < 0.0:
		_est_t = 0.0
		var p0 := s.income_parts_with("harbor", 0)
		_est_prev = float(p0.total)
		_fee_prev = float(p0.fees)
	if gain_pill.visible:
		if half_sheet_open():
			# feuille mi-hauteur : la pastille passe en haut du port visible (le revenu du HUD est sous la feuille)
			var gy := 36.0 if ev_pill == null or not ev_pill.visible else ev_pill.get_global_rect().end.y + 12.0
			gain_pill.global_position = Vector2((get_viewport_rect().size.x - gain_pill.size.x) * 0.5, gy)
		else:
			var r := income_l.get_global_rect()
			gain_pill.global_position = Vector2(r.position.x, r.end.y + 22)


## Gain d'un achat : pastille « +X $/s » (cumulée pendant une rafale d'achats) qui s'efface en 3 s.
func _add_gain(s: PortSim, g: float, pill: bool = true) -> void:
	_lifts.append([s.time, g])
	if not pill:
		return
	if s.time - _gain_time > 3.0:
		_gain_sum = 0.0
	_gain_sum += g
	_gain_time = s.time
	_show_pill("+%s $/s" % Fmt.num(_gain_sum), UI.MONEY)


func _show_pill(text: String, col: Color) -> void:
	gain_l.text = text
	gain_l.add_theme_color_override("font_color", col)
	gain_pill.visible = true
	gain_pill.modulate.a = 1.0
	gain_pill.reset_size()
	Fx.pop(gain_pill, 1.12)
	if _gain_tw != null:
		_gain_tw.kill()
	_gain_tw = gain_pill.create_tween()
	_gain_tw.tween_property(gain_pill, "modulate:a", 0.0, 1.0).set_delay(2.2)
	_gain_tw.tween_callback(func() -> void: gain_pill.visible = false)


## Achat d'un niveau (service ou licence), juste après (avec la stat d'avant l'achat) : retenu pour son retour dans le monde (caméra sur le
## service, effet D-Monde, « +12 $/s » ou « +6 % » flottant au-dessus du poste, pastille même hors goulot).
func note_purchase(kind: String, id: String, stat_before: float) -> void:
	var s := GameState.sim
	if _buy_fx.is_empty() or String(_buy_fx.id) != id:
		if not _buy_fx.is_empty():
			_flush_buy_fx(s, true)
		_buy_fx = {"kind": kind, "id": id, "stat0": stat_before, "gain": 0.0, "seen": false, "n": 0}
	_buy_fx.n = int(_buy_fx.n) + 1
	if kind == "dept":
		var now := Time.get_ticks_msec() / 1000.0
		if diorama != null and diorama.has_method("feedback_purchase") and now - _fb_t > 0.3:
			_fb_t = now
			diorama.call("feedback_purchase", id)
		if half_sheet_open():
			frame_dept(id)


var _fb_t := -10.0


## Retour d'un achat (au plus un toutes les 0,35 s pendant un appui long) : texte flottant au-dessus du poste et pastille.
func _flush_buy_fx(s: PortSim, force: bool = false) -> void:
	if _buy_fx.is_empty() or not bool(_buy_fx.get("seen", false)):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if not force and now - _buy_fx_t < 0.35:
		return
	_buy_fx_t = now
	var fx := _buy_fx
	_buy_fx = {}
	var kind := String(fx.kind)
	var id := String(fx.id)
	var stat_now := _buy_stat(s, kind, id)
	var pct := stat_now / float(fx.stat0) - 1.0 if float(fx.stat0) > 0.0 else 0.0
	var g := float(fx.gain)
	var gf := float(fx.get("fees", 0.0))
	var pos := dept_anchor(id) + Vector3(0, 9, 0) if kind == "dept" else Layout.YARD_CENTER + Vector3(0, 8, 0)
	var name := String(s.db.dept_by_id[id].name) if kind == "dept" and s.db.dept_by_id.has(id) else "Licence"
	if UpgradesSheet.moves_flow({"total": g, "flow": g - gf}):
		overlay.add_popup(pos, "+%s/s" % Fmt.money(g), UI.MONEY, true)
	else:
		# hors goulot : l'achat n'est pas muet (revue D-UI) — l'effet du service, et pourquoi le débit ne bouge pas ; lot E :
		# les services facturés montent quand même (« Portiques +6 % · pas le goulot (+15 $/s de services) »), en bleu, jamais
		# comme un gain du port
		var ptxt := "+%d %%" % maxi(1, roundi(pct * 100.0)) if pct > 0.0005 else "Niv. +%d" % int(fx.n)
		overlay.add_popup(pos, ptxt, UI.INFO, true)
		var fee_txt := " (+%s/s de services)" % Fmt.money(gf) if gf * 60.0 >= 0.05 else ""
		_show_pill("%s %s · pas le goulot%s" % [name, ptxt, fee_txt], UI.INFO)


static func _buy_stat(s: PortSim, kind: String, id: String) -> float:
	if kind == "dept":
		return s.stat(Info.dept_stat_name(id))
	for ci in PortSim.NCARGO:
		if String(s.db.cargo[ci].id) == id:
			return s.stat("value", ci)
	return 1.0


## Point du monde où cadrer un service : `Diorama.dept_anchor` (plan réorganisé, D-Monde), sinon le poste du plan.
func dept_anchor(d: String) -> Vector3:
	if diorama != null and diorama.has_method("dept_anchor"):
		return diorama.call("dept_anchor", d)
	return Layout.dept_pos(d, GameState.sim.tier if GameState.sim != null else 1)


## Feuille mi-hauteur : la caméra amène le service dans la moitié haute de l'écran (au-dessus de la feuille).
func frame_dept(d: String) -> void:
	if diorama == null or diorama.rig == null or d == "":
		return
	frame_point(dept_anchor(d))


func frame_point(p: Vector3) -> void:
	var rig := diorama.rig
	var vs := get_viewport_rect().size
	var c := vs * 0.5
	# le point doit paraître au milieu de la bande visible (entre le haut de l'écran et le haut de la feuille)
	var want_y := vs.y * Sheet.HALF_TOP * 0.5
	var off := rig.screen_to_ground(Vector2(c.x, c.y + (c.y - want_y))) - rig.screen_to_ground(c)
	rig.focus(Vector3(p.x, 0.0, p.z) + Vector3(off.x, 0.0, off.z))
	_cam_set = rig.goal


func _income_lift(s: PortSim) -> float:
	var lift := 0.0
	for i in range(_lifts.size() - 1, -1, -1):
		var age: float = s.time - float(_lifts[i][0])
		if age >= 60.0 or age < 0.0:
			_lifts.remove_at(i)
			continue
		lift += float(_lifts[i][1]) * smoothstep(0.0, 3.0, age) * (1.0 - age / 60.0)
	return lift


## Pastille d'Améliorer : achats abordables **qui valent le coup** — le débit bouge et l'achat se rentabilise en moins de
## 10 minutes (lot E : avec les services facturés, tout achat rapportait un peu et la pastille comptait 9 au T3) —, ou qui
## font avancer le chapitre en cours (le service dont le niveau ouvre le chapitre suivant). Jamais un service sous un aléa.
## Les estimations rejouent l'analyse : une fois par seconde.
func _affordable_count(s: PortSim) -> int:
	if s.clock() - _aff_t < 1.0 and s.clock() >= _aff_t:      # (lot F3 : l'horloge du port ne tourne pas pendant l'acte 0)
		return _aff_n
	_aff_t = s.clock()
	_aff_n = worthwhile_count(s)
	return _aff_n


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


## Pluie fine des recettes : la gate seulement (lot D-UI). La manutention s'encaisse navire par navire (`_on_ship_paid`),
## les autres recettes restent dans le compteur sans pastille (elles étaient groupées toutes les 1,2 s, sans événement).
func _flush_revenue(_s: PortSim) -> void:
	var a: float = float(_rev_acc.get("gate", 0.0))
	if a >= 0.5:
		overlay.add_popup(Layout.GATE + Vector3(0, 6, 4), "+" + Fmt.money(a))
	_rev_acc.clear()


## Encaissement par événement (lot D-UI) : un navire termine son escale → gros « +X $ » au poste, des pièces volent jusqu'au
## compteur, qui pulse à leur arrivée. Montant estimé par le monde (Diorama.ship_paid, voir sa documentation).
func _on_ship_paid(world_pos: Vector3, amount: float) -> void:
	if amount < 0.5 or overlay == null:
		return
	ships_paid_shown += 1
	overlay.add_popup(world_pos, "+" + Fmt.money(amount), UI.MONEY, true)
	if full_sheet_open() or diorama.opening_active() or _npopups() > 0:
		return
	var from := diorama.to_screen(world_pos)
	var target: Control = money_l
	if half_sheet_open():
		var sh := sheet_layer.get_child(0) as Sheet
		if sh != null and sh.money_l != null:
			target = sh.money_l
	if not target.is_visible_in_tree():
		return
	Sfx.play("coin", 0.15)
	# lot E : le montant reste lisible 0,6 s, puis les pièces partent d'au-dessus de lui (jamais dessus)
	Fx.coins(from, Fx.center_of(target), 7, func() -> void:
		flash_money(target), COIN_DELAY, COIN_LIFT)


var ships_paid_shown := 0      # encaissements affichés (tests)
const COIN_DELAY := 0.6        # le « +X $ » d'un navire payé se lit seul pendant 0,6 s
const COIN_LIFT := 150.0       # les pièces naissent 150 px au-dessus du point payé (au-dessus du texte)


## Bas des cartes du haut (ligne Goulot, bandeau des missions, aléa, notifications), en coordonnées écran : la surcouche
## monde n'écrit pas dessous.
func top_cards_bottom() -> float:
	var y := 0.0
	if _top_cards.is_empty():
		_top_cards = [line_box, strip_box, event_card, toast_box]
	for ctl in _top_cards:
		if ctl.is_visible_in_tree() and (ctl != toast_box or _toast_showing()):
			y = maxf(y, ctl.get_global_rect().end.y)
	return y


## Bas du « chrome » du haut (barre indigo, ligne Goulot, bandeau des missions, aléa), sans les notifications passagères :
## lot D-UI, il doit rester sous 20 % de la hauteur de l'écran (ISM ≈ 15 %).
func top_chrome_bottom() -> float:
	var y := 0.0
	for ctl in [head_bar, line_box, strip_box, event_card]:
		var c: Control = ctl
		if c != null and c.is_visible_in_tree():
			y = maxf(y, c.get_global_rect().end.y)
	return y


## Listes de contrôles relues à chaque image (rectangle utile, notifications) : faites une fois (revue C7 D).
var _top_cards: Array[Control] = []
var _anchor_ctls: Array[Control] = []
var _bottom_buttons: Array[Control] = []


## Rectangle utile de l'écran pour la surcouche monde : sous les cartes du haut, au-dessus des boutons du bas et de la
## carte du tutoriel, à 8 px des bords (aucune bulle sur le HUD ni coupée par le bord).
func useful_rect() -> Rect2:
	var vs := get_viewport_rect().size
	if half_sheet_open():
		# feuille mi-hauteur : tout le port visible au-dessus d'elle (le HUD du haut est replié), sous la carte du tutoriel
		var hb := vs.y * Sheet.HALF_TOP - 8.0
		var ht := 8.0
		if ev_pill != null and ev_pill.visible:
			ht = minf(hb - 60.0, ev_pill.get_global_rect().end.y + 8.0)      # sous la pastille d'aléa
		if tutorial != null and tutorial._card != null and tutorial._card.is_visible_in_tree() and tutorial._card_top:
			ht = minf(hb - 60.0, maxf(ht, tutorial._card.get_global_rect().end.y + 8.0))
		return Rect2(8.0, ht, maxf(1.0, vs.x - 16.0), maxf(1.0, hb - ht))
	var top := top_cards_bottom() + 6.0
	if head_bar != null and head_bar.is_visible_in_tree():
		top = maxf(top, head_bar.get_global_rect().end.y + 6.0)
	var bottom := vs.y - 8.0
	if bottom_box != null and bottom_box.visible:
		if _bottom_buttons.is_empty():      # liste faite une fois (revue C7 D : plus de find_children à chaque image)
			for b in bottom_box.find_children("*", "Button", true, false):
				_bottom_buttons.append(b as Control)
		for b in _bottom_buttons:
			if b.is_visible_in_tree():
				bottom = minf(bottom, b.get_global_rect().position.y - 8.0)
	if tutorial != null and tutorial._card != null and tutorial._card.is_visible_in_tree():
		bottom = minf(bottom, tutorial._card.get_global_rect().position.y - 8.0)
	return Rect2(8.0, top, maxf(1.0, vs.x - 16.0), maxf(1.0, bottom - top))


func flash_money(target: Control = null) -> void:
	var l: Control = target if target != null and is_instance_valid(target) else money_l
	l.pivot_offset = l.size * 0.5
	var tw := l.create_tween()
	l.scale = Vector2(1.15, 1.15)
	tw.tween_property(l, "scale", Vector2.ONE, 0.2)


func world_shake() -> void:
	diorama.rig.shake(0.8)


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

## Goulots qui se règlent par un bâtiment (le bouton du conseil ouvre Gestion → Bâtiments, ou la fiche du bâtiment tant que
## Gestion n'est pas révélée).
const BUILD_KEYS := Advice.BUILD_KEYS


## Le conseil de goulot propose-t-il une action possible tout de suite (bâtiment, niveau, palier, campagne abordable) ?
static func hint_actionable(s: PortSim) -> bool:
	return bool(hint_action(s).can)


## Action proposée par la carte Goulot (lot E : logique dans `Advice`, sans dépendance aux autoloads, testée par run_all).
static func hint_action(s: PortSim) -> Dictionary:
	return Advice.hint_action(s)


static func fix_building(s: PortSim, key: String) -> String:
	return Advice.fix_building(s, key)


static func _fixes(key: String, e: Dictionary, s: PortSim) -> bool:
	return Advice.fixes(key, e, s)


## Nombre d'achats d'un niveau abordables qui valent le coup (pastille d'Améliorer, voir `Advice.worthwhile_count`).
static func worthwhile_count(s: PortSim) -> int:
	if fishing_cards(s):
		return 1 if s.money >= s.fishing.next_cost() else 0      # lot F3 : l'achat suivant de l'acte 0
	return Advice.worthwhile_count(s)


## Lot F3 : la feuille Améliorer montre les achats de la pêche (acte 0 en cours, bascule pas encore possible).
static func fishing_cards(s: PortSim) -> bool:
	return s != null and s.fishing.act0 and not s.act0_ready()


func _on_hint_pressed() -> void:
	var key: String = GameState.sim.shown_analysis().get("key", "")
	GameState.sim.add_counter("hint_used")     # le tutoriel attend ce geste (« corrige le goulot »)
	var act := hint_action(GameState.sim)
	var kind := String(act.kind)
	if kind == "dept":
		open_upgrades(String(act.id))
		return
	if kind == "build" or (kind == "manage" and key in BUILD_KEYS):
		# Gestion n'apparaît qu'au chapitre 3 : avant, le bouton ouvre la fiche du bâtiment, sur son emplacement doré
		# (revue C7 B6 : pas de renvoi à un écran que le joueur ne voit pas encore)
		var bid := String(act.id) if kind == "build" else Zones.first_unbuilt(GameState.sim)
		if not GameState.sim.feature("manage") and bid != "" and Layout.LOTS.has(bid):
			var lp: Vector3 = Layout.LOTS[bid].p
			diorama.rig.focus(Vector3(lp.x - 4.0, 0.0, lp.z + 6.0))
			open_building(bid)
		else:
			open_sheet(ManageSheet.new(0))
	elif kind == "campaign" or kind == "commerce":
		open_sheet(CommerceSheet.new(CommerceSheet.TAB_TRAFFIC))
	elif kind == "tier":
		open_sheet(ManageSheet.new(3))
	elif key == "fog":
		Sfx.play("click")
	else:
		open_upgrades(GameState.sim.shown_analysis().get("dept", ""))


## Coup de main sur une grue (touche dans le monde).
func _on_assist(pos: Vector3, amount: float) -> void:
	Sfx.play("coin", 0.1)
	overlay.add_popup(pos, "Coup de main ! +%s" % Fmt.money(evp_value(amount)), UI.AMBER, true)
	diorama.rig.shake(0.15)


## Geste du parc ou de la gate : affiché en $ (les EVP rangés ou sortis, à la valeur moyenne d'un EVP du port).
func _on_gesture(pos: Vector3, text: String, evp: float = -1.0) -> void:
	Sfx.play("coin", 0.1)
	overlay.add_popup(pos, gesture_text(text, evp), UI.AMBER, true)
	diorama.rig.shake(0.12)


## Valeur de `evp` EVP pour le joueur : valeur moyenne d'un EVP (licences, palier) et droits de gate compris.
static func evp_value(evp: float) -> float:
	var s := GameState.sim
	return evp * s.avg_value_per_evp() * (1.0 + float(s.db.cfg("gate_fee_ratio")))


## « Rangé ! +12 EVP » → « Rangé ! +340 $ » (lot D-UI : les gestes manuels payés en $). Lot D-Monde : le nombre d'EVP vient
## du signal `gesture_done` (`evp` ≥ 0) ; sans lui (ancien appel), il est relu dans le texte.
static func gesture_text(text: String, evp: float = -1.0) -> String:
	var re := RegEx.create_from_string("\\+([0-9]+(?:,[0-9]+)?)([KMBT]?) EVP")
	var m := re.search(text)
	var v := evp
	if v < 0.0:
		if m == null:
			return text
		v = float(m.get_string(1).replace(",", "."))
		v *= float({"": 1.0, "K": 1.0e3, "M": 1.0e6, "B": 1.0e9, "T": 1.0e12}.get(m.get_string(2), 1.0))
	if m == null:
		return "%s +%s" % [text, Fmt.money(evp_value(v))]
	return text.substr(0, m.get_start()) + "+" + Fmt.money(evp_value(v)) + text.substr(m.get_end())


func _on_prioritized(_id: int) -> void:
	Sfx.play("bell", 0.3)
	toast("Accostage en priorité : le pilote file plus vite.", "info")


func _on_boost() -> void:
	var s := GameState.sim
	var b: Dictionary = s.db.cfg("boost")
	if s.start_boost():
		Sfx.play("boost")
		if diorama.has_method("set_overtime"):
			diorama.call("set_overtime", true)
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
	var had_half := half_sheet_open()
	for c in sheet_layer.get_children():
		c.queue_free()
	if s.half and not had_half:
		# le cadrage **du joueur**, rendu à la fermeture de la feuille (lot E, E6) : pendant le regard de 2 s d'un chapitre,
		# sa vue d'avant (`view_home`) ; sinon ce qu'il voit (`target`) — un toucher sur un poste du monde vient de viser le
		# poste (`goal`), mais la caméra n'a pas encore bougé
		_cam_back = diorama.view_home if diorama.view_home != Vector3.INF else diorama.rig.target
		_cam_back.y = 0.0
		_cam_set = Vector3.INF
	elif not s.half and had_half:
		_restore_camera()
	sheet_layer.add_child(s)
	diorama.rig.input_enabled = false
	s.closed.connect(_on_sheet_closed.bind(s))
	Sfx.play("click")


func _on_sheet_closed(s: Sheet) -> void:
	diorama.rig.input_enabled = true
	if s.half:
		_restore_camera()


## Fermeture d'une feuille mi-hauteur : la caméra revient au cadrage du joueur (s'il n'a pas été déplacé entre-temps).
func _restore_camera() -> void:
	if _cam_back != Vector3.INF and (_cam_set == Vector3.INF or diorama.rig.goal.distance_to(_cam_set) < 0.5):
		diorama.rig.focus(_cam_back)
	_cam_back = Vector3.INF
	_cam_set = Vector3.INF


func any_sheet_open() -> bool:
	return sheet_layer.get_child_count() > 0


## Écran affiché (le dernier ouvert, hors écran en cours de fermeture), null sinon.
func current_sheet() -> Sheet:
	for i in range(sheet_layer.get_child_count() - 1, -1, -1):
		var c := sheet_layer.get_child(i)
		if c is Sheet and not c.is_queued_for_deletion():
			return c as Sheet
	return null


## Feuille mi-hauteur ouverte (Améliorer, Commerce) : le port vit au-dessus.
func half_sheet_open() -> bool:
	var c := current_sheet()
	return c != null and c.half


## Écran plein cadre ouvert (ou un écran en cours de fermeture) : le port est couvert.
func full_sheet_open() -> bool:
	var c := current_sheet()
	return c != null and not c.half


# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------

## Notification : mise en file, affichée une à la fois sous l'en-tête (jamais pendant une ouverture de zone).
const TOAST_QUEUE_MAX := 2          # revue N8 : file courte, sans doublon
const TOAST_REPEAT := 60.0          # revue N2 : le même texte pas avant 60 s
const TOAST_GAP := 4.0             # une notification toutes les 4 s au plus
const TOAST_CALM := 3.0            # 3 s de calme après une ouverture de zone
var _calm_until := 0.0
var _next_toast_at := 0.0


func toast(text: String, kind: String = "info") -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# pas de doublon avant TOAST_REPEAT secondes, ni deux fois le même texte dans la file
	if now - float(_toasts_recent.get(text, -1000.0)) < TOAST_REPEAT:
		return
	for q in _toast_queue:
		if String(q[0]) == text:
			return
	if _toasts_recent.size() > 24:      # les textes portent des montants : sans purge la table grossit toute la partie
		for k in _toasts_recent.keys():
			if now - float(_toasts_recent[k]) >= TOAST_REPEAT:
				_toasts_recent.erase(k)
	_toast_queue.append([text, kind])
	# une rafale : on garde les plus récentes, mais une « bad » ne cède jamais sa place à une « info » ou une « good » :
	# on jette la plus ancienne qui n'est pas « bad » (revue C7 B2)
	while _toast_queue.size() > TOAST_QUEUE_MAX:
		var drop := 0
		for i in _toast_queue.size():
			if String(_toast_queue[i][1]) != "bad":
				drop = i
				break
		_toast_queue.remove_at(drop)
	_sync_toasts()


## Bas de la pile du haut (en-tête, missions, Responsables, carte Goulot, aléa), hors notifications : la notification se
## pose dessous, dans la colonne de gauche, jamais sur un bouton ni une puce du HUD (revue N2).
func _toast_anchor_y() -> float:
	var y := 0.0
	if _anchor_ctls.is_empty():
		_anchor_ctls = [head_bar, line_box, strip_box, event_card]
	for c in _anchor_ctls:
		if c != null and c.is_visible_in_tree():
			y = maxf(y, c.get_global_rect().end.y)
	return y + 10.0


## Affiche la notification suivante si aucune n'est à l'écran : sous la carte Goulot, une toutes les TOAST_GAP secondes,
## TOAST_CALM secondes de calme après une ouverture de zone.
func _sync_toasts() -> void:
	if head_bar != null:
		var hb := head_bar.get_global_rect()
		var w := hint_card.size.x if hint_card != null and hint_card.size.x > 100.0 else hb.size.x - 60.0
		var x0 := hint_card.global_position.x if hint_card != null and hint_card.size.x > 100.0 else hb.position.x + 30.0
		toast_box.position = Vector2(x0, _toast_anchor_y())
		toast_box.custom_minimum_size.x = w
		toast_box.size = Vector2(w, 0.0)       # hauteur réelle (celle de la notification affichée, 0 sans) : revue C7 B2
	# jamais par-dessus un écran, une fenêtre ou la carte du tutoriel (revue C7 B2) : masquée, et la suivante attend
	var covered := any_sheet_open() or _npopups() > 0
	var over_tuto := false
	if tutorial != null and tutorial._card != null and tutorial._card.is_visible_in_tree() and _toast_showing():
		over_tuto = toast_box.get_global_rect().intersects(tutorial._card.get_global_rect())
	toast_box.visible = not covered and not over_tuto
	var now := Time.get_ticks_msec() / 1000.0
	# le calme d'après une ouverture compte même si une notification était à l'écran pendant la séquence (lot D-UI :
	# sinon la suivante pouvait paraître aussitôt la séquence finie)
	if diorama != null and diorama.opening_active():
		_calm_until = now + TOAST_CALM
	if _toast_showing():
		return
	_toast_cur = null
	if diorama != null and diorama.opening_active():
		return
	if covered or _toast_queue.is_empty() or now < _calm_until or now < _next_toast_at:
		return
	_next_toast_at = now + TOAST_GAP
	var item: Array = _toast_queue.pop_front()
	_toasts_recent[String(item[0])] = now      # l'anti-doublon ne compte qu'une notification réellement affichée
	var col := {"good": UI.MONEY, "bad": UI.BAD}.get(String(item[1]), UI.INFO) as Color
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.card_style(col, 26, 20))      # fond opaque
	var l := UI.wrap_label(String(item[0]), 28, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(p)
	_toast_cur = p
	var tw := p.create_tween()
	p.modulate.a = 0.0
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(3.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


func _toast_showing() -> bool:
	return _toast_cur != null and is_instance_valid(_toast_cur) and not _toast_cur.is_queued_for_deletion()


## Un écran ou une fenêtre couvre-t-il le port ? (notifications, bandeaux, narratrice et « Toucher pour passer » attendent)
func _covered() -> bool:
	return any_sheet_open() or _npopups() > 0


## Ouverture de zone : le HUD s'efface (barres, cartes, boutons, notifications, bandeaux, tutoriel), « Toucher pour
## passer » discret en bas ; il revient à la fin. Les notifications et bandeaux attendent leur tour (file).
func _sync_opening(delta: float) -> void:
	var op := diorama.opening_active() or intro_active()      # (lot F3 : le HUD s'efface aussi sous les cartes d'intro)
	hud_fade = move_toward(hud_fade, 0.0 if op else 1.0, delta * 4.0)
	for c in [top_box, bottom_box, toast_box, gain_pill, _banner, tutorial]:
		if c != null and is_instance_valid(c):
			var ctl: Control = c
			ctl.modulate.a = hud_fade
	# masqué : un toucher passe la séquence au lieu d'appuyer un bouton ; sous une feuille mi-hauteur, le HUD se replie (le
	# solde est dans l'en-tête de la feuille) et le port garde toute la moitié haute de l'écran
	var half := half_sheet_open()
	for c in [top_box, bottom_box]:
		(c as Control).visible = hud_fade > 0.02 and not half
	if _banner != null and is_instance_valid(_banner):
		_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE if op else Control.MOUSE_FILTER_STOP
	if skip_hint == null:
		# lisible sur l'eau comme sur le sable : texte blanc 34 px sur une pastille sombre (revue N11)
		skip_hint = UI.label("Toucher pour passer", 34, Color.WHITE)
		var shs := UI.flat(Color(0.1, 0.08, 0.25, 0.55), 30, 24, 8)
		skip_hint.add_theme_stylebox_override("normal", shs)
		skip_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
		skip_hint.add_theme_constant_override("shadow_offset_y", 2)
		skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skip_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		skip_hint.offset_left = -220
		skip_hint.offset_right = 220
		skip_hint.offset_top = -110
		skip_hint.offset_bottom = -50
		add_child(skip_hint)

	# n'apparaît qu'une fois la séquence passable (revue N12), sans clignoter ; jamais sur une fenêtre (revue C7 B3)
	var covered := _covered()
	skip_hint.visible = op and diorama.opening_skippable() and not covered
	skip_hint.modulate.a = 0.9
	if _narration != null and is_instance_valid(_narration):
		_narration.visible = not covered
	# bandeau : caché sous un écran ou une fenêtre ; le suivant (et le recentrage de la caméra) attend leur fermeture (C7 B4)
	if _banner != null and is_instance_valid(_banner):
		var hidden := covered or ceremony_active()
		_banner.visible = not hidden
		# minuterie du bandeau suspendue tant qu'il est masqué (lot E, E6 : il expirait sous la feuille)
		var btw: Variant = _banner.get_meta("tween", null)
		if btw is Tween and (btw as Tween).is_valid():
			if hidden and (btw as Tween).is_running():
				(btw as Tween).pause()
			elif not hidden and not (btw as Tween).is_running():
				(btw as Tween).play()
	if not op and not covered and not ceremony_active() and _banner == null and not _banner_queue.is_empty():
		_next_banner()


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

## Une fonction se révèle : son bouton apparaît avec un rebond, et un bandeau explique à quoi elle sert (avec VOIR).
func _on_feature(id: String) -> void:
	var u: Dictionary = GameState.db.unlock_by_id.get(id, {})
	if u.is_empty():
		return
	var ctls: Array = feature_ctl.get(id, [])
	if ctls.is_empty() and (id.begins_with("dept_") or id == "licences"):
		ctls = [tut_targets["upgrade"]]        # nouvelle carte dans Améliorer : on fait rebondir ce bouton
	if id == "managers" or id == "manage":
		ctls = [manage_btn]
	for c in ctls:
		_pop_in(c as Control)
	var where := " (dans Améliorer)" if id.begins_with("dept_") or id == "licences" else ""
	# chapitre d'un service : la caméra montre son poste pendant 2 s, puis revient (revue N9)
	var foc := Vector3.INF
	if bool(u.get("opens_chapter", false)) and id.begins_with("dept_"):
		foc = dept_anchor(id.substr(5))
	_queue_banner("Nouveau : %s%s" % [u.name, where], String(u.text), String(u.get("icon", "info")), UI.VIOLET, foc, foc != Vector3.INF, id)
	_refresh(GameState.sim)          # pastilles et boutons tout de suite (Responsables : la pastille de Gestion)


## Bouton VOIR d'un bandeau « Nouveau : … » : ouvre le bon écran ou fait rebondir le bon bouton (revue D-UI) ; null si rien
## à montrer de plus que le bandeau.
func banner_action(feature_id: String) -> Callable:
	match feature_id:
		"":
			return Callable()
		"licences":
			return func() -> void:
				var up := UpgradesSheet.new("")
				up.tab = 1
				open_sheet(up)
		"managers":
			return func() -> void: open_sheet(ManageSheet.new(2))
		"manage":
			return func() -> void: open_sheet(ManageSheet.new(0))
		"stats":
			return func() -> void: open_sheet(ManageSheet.new(1))
		"progress", "stars":
			return func() -> void: open_sheet(ManageSheet.new(3))
		"commerce":
			return func() -> void: open_sheet(CommerceSheet.new(CommerceSheet.TAB_TRAFFIC))
		"contracts":
			return func() -> void: open_sheet(CommerceSheet.new(CommerceSheet.TAB_CONTRACTS))
		"missions":
			return func() -> void: open_sheet(MissionsSheet.new())
		"amber":
			return func() -> void: show_amber_help()
		"boost":
			return func() -> void:
				_pop_in(boost_btn)
				toast("Heures sup : le bouton rond au-dessus d'AMÉLIORER. Tout le port tourne ×2 pendant une minute.", "info")
	if feature_id.begins_with("dept_"):
		var d := feature_id.substr(5)
		return func() -> void: open_upgrades(d)
	return Callable()


## Premier navire d'une nouvelle classe (le quai allongé, le chenal dragué… portent leurs fruits) : on le montre.
func _on_first_class(sh: Ship) -> void:
	var sd: Dictionary = GameState.db.ship_by_id[sh.cls]
	Sfx.play("ship_horn", 0.5)
	_queue_banner("Premier %s en approche !" % String(sd.name).to_lower(), String(sd.get("arrival", "")), "ship", UI.MONEY,
		Layout.anchor_pos(maxi(0, sh.anchor_slot)))      # la caméra va au mouillage quand le bandeau paraît (jamais pendant une ouverture)


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


const CHAPTER_LOOK := 2.0       # secondes sur le poste d'un service dont le chapitre s'ouvre


func _queue_banner(title: String, text: String, icon_name: String, col: Color, focus: Vector3 = Vector3.INF, back: bool = false, feature_id: String = "") -> void:
	_banner_queue.append({"title": title, "text": text, "icon": icon_name, "col": col, "focus": focus, "back": back, "feature": feature_id})
	if _banner == null and not _banner_blocked():
		_next_banner()


var banner_voir: Button        # bouton VOIR du bandeau affiché (tests)


## Bandeau non bloquant (toucher pour le fermer, VOIR pour y aller) ; les suivants attendent leur tour.
func _next_banner() -> void:
	if _banner_queue.is_empty():
		_banner = null
		return
	var b: Dictionary = _banner_queue.pop_front()
	if b.get("focus", Vector3.INF) != Vector3.INF:
		var back_to: Vector3 = diorama.rig.goal
		diorama.rig.focus(b.focus)
		if bool(b.get("back", false)):
			var g_after: Vector3 = diorama.rig.goal
			# une ouverture de zone pendant ces 2 s reviendra à la vue du joueur, pas au cadrage du chapitre (revue C7 B4)
			diorama.view_home = back_to
			get_tree().create_timer(CHAPTER_LOOK).timeout.connect(func() -> void:
				if diorama.view_home == back_to:
					diorama.view_home = Vector3.INF
				if diorama.rig.goal.distance_to(g_after) < 0.5:      # le joueur n'a pas déplacé la vue entre-temps
					diorama.rig.focus(back_to))
	Sfx.play("bell", 0.2)
	var card := UI.card(Color.WHITE, 26)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	card.custom_minimum_size = Vector2(940, 0)
	card.offset_left = -470
	card.offset_right = 470
	card.offset_top = 760
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.z_index = 5            # au-dessus des bulles de la surcouche monde (dessinée hors colonne, « top_level »)
	var h := UI.hbox(16)
	card.add_child(h)
	h.add_child(UI.icon_disc(String(b.icon), b.col, 96))
	var v := UI.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var tl := UI.wrap_label(String(b.title), 34, b.col)
	v.add_child(tl)
	if String(b.text) != "":
		v.add_child(UI.wrap_label(String(b.text), 26, UI.TEXT))
	banner_voir = null
	var act := banner_action(String(b.get("feature", "")))
	if act.is_valid():
		var go := UI.button("VOIR", UI.AMBER, 30, 100)
		go.add_theme_color_override("font_color", UI.TEXT)
		go.custom_minimum_size.x = 150
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		go.pressed.connect(func() -> void:
			Sfx.play("click")
			# lot E (E6) : l'écran s'ouvre **avant** que le bandeau se ferme — le suivant attend donc sa fermeture (avant, il
			# paraissait et déplaçait la caméra juste avant l'ouverture de l'écran)
			act.call()
			_close_banner(card))
		h.add_child(go)
		banner_voir = go
	add_child(card)
	move_child(card, popup_layer.get_index())     # sous les fenêtres, au-dessus du reste
	_banner = card
	card.modulate.a = 0.0
	card.pivot_offset = Vector2(470, 60)
	card.scale = Vector2(0.85, 0.85)
	var tw := card.create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "modulate:a", 1.0, 0.2)
	tw.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	tw.set_parallel(false)
	tw.tween_interval(6.5)
	tw.tween_property(card, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_close_banner.bind(card))
	card.set_meta("tween", tw)       # suspendu tant que le bandeau est masqué (sous un écran, une fenêtre, une cérémonie)
	card.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed:
			_close_banner(card))


func _close_banner(card: Control) -> void:
	if card != _banner or not is_instance_valid(card):
		return
	card.queue_free()
	_banner = null
	# lot E (E6) : le suivant n'enchaîne pas sous un écran ou une fenêtre (ni pendant une ouverture de zone ou une
	# cérémonie) ; `_sync_opening` le présentera au retour au port
	if not _banner_blocked():
		_next_banner()


## Un bandeau ne peut pas paraître maintenant : écran, fenêtre, ouverture de zone ou cérémonie à l'écran.
func _banner_blocked() -> bool:
	return _covered() or (diorama != null and diorama.opening_active()) or ceremony_active()


func _on_event(ev: Dictionary) -> void:
	Sfx.play("horn", 1.0)
	if ev.id == "wind" or ev.id == "strike":
		world_shake()


## Passage de palier : cérémonie (gerbe plein écran, dézoom sur ce qui s'ouvre, jingle du palier), puis la fenêtre.
func _on_tier(t: int) -> void:
	var td := GameState.sim.db.tier_def(t)
	if t >= 4:
		ceremony("Concession nationale !", "Le terminal de Port Horizon est à toi", UI.AMBER, "finale", Vector3.INF, _end_screen)
		return
	var tv := tier_view(GameState.sim, t)
	ceremony("Palier T%d atteint !" % t, String(td.name), UI.AMBER, "tier%d" % t if t <= 3 else "tier", tv.get("p", Vector3.INF), func() -> void:
		tier_popup(t))


var tier_voir: Button          # bouton VOIR de la fenêtre du palier affichée (tests)


## Fenêtre du palier (lot E, cérémonie qui montre) : le texte propre au palier, 2–3 icônes « ce qui s'ouvre »
## (`tiers.json` → `opens`) et VOIR, qui cadre les zones qui s'ouvrent.
func tier_popup(t: int) -> Control:
	var td := GameState.sim.db.tier_def(t)
	var body: Array = [UI.label(String(td.name), 44, UI.VIOLET), UI.wrap_label(String(td.story), 30, UI.TEXT)]
	for o in td.get("opens", []):
		var h := UI.hbox(14)
		h.add_child(UI.icon_disc(String(o.get("icon", "info")), UI.AMBER, 76))
		var l := UI.wrap_label(String(o.get("text", "")), 28, UI.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
		body.append(h)
	if int(td.get("amber", 0)) > 0:
		body.append(UI.wrap_label("+%d Ambre." % int(td.amber), 28, UI.AMBER.darkened(0.25)))
	var buttons: Array = []
	tier_voir = null
	if not tier_view(GameState.sim, t).is_empty():
		var go := UI.button("VOIR", UI.AMBER, 34, 100)
		go.add_theme_color_override("font_color", UI.TEXT)
		go.pressed.connect(func() -> void:
			Sfx.play("click")
			frame_tier(t))
		buttons.append(go)
		tier_voir = go
	return show_popup("Palier T%d atteint !" % t, body, "trophy", buttons)


## Ce que le palier `t` ouvre, à cadrer : la zone du prochain bâtiment s'il est de ce palier (Quai n°2 au T2, terre-plein et
## quai profond n°3 au T3), sinon les zones ouvertes par le palier lui-même. {"p", "zoom"}, {} s'il n'y a rien à montrer.
static func tier_view(s: PortSim, t: int) -> Dictionary:
	var bid := Zones.first_unbuilt(s) if s != null else ""
	if bid != "" and int(s.db.building_by_id[bid].tier) == t:
		var z := Zones.zone_of(bid)
		if not z.is_empty():
			return Zones.focus(z)
	var foc := tier_focus(t)
	if foc == Vector3.INF:
		return {}
	var zoom := 70.0
	for z in Layout.ZONES:
		if String(z.get("open", "")) == "t%d" % t:
			zoom = maxf(zoom, float(Zones.focus(z).get("zoom", 70.0)))
	return {"p": foc, "zoom": zoom}


## VOIR de la fenêtre du palier : la caméra cadre ce qui s'ouvre (centre et recul qui le font tenir à l'écran).
func frame_tier(t: int) -> void:
	if diorama == null or diorama.rig == null:
		return
	var v := tier_view(GameState.sim, t)
	if v.is_empty():
		return
	diorama.rig.focus(v.p)
	diorama.rig.zoom_goal = clampf(float(v.zoom), diorama.rig.zoom_min, diorama.rig.zoom_max)


## Centre des zones qui s'ouvrent avec le palier `t` (Vector3.INF s'il n'y en a pas).
static func tier_focus(t: int) -> Vector3:
	var acc := Vector3.ZERO
	var n := 0
	for z in Layout.ZONES:
		if String(z.get("open", "")) == "t%d" % t and z.has("sign"):
			acc += z.sign as Vector3
			n += 1
	return acc / float(n) if n > 0 else Vector3.INF


# --- cérémonie (palier, prestige, fin de partie) ---------------------------------------------------------------------------

const CEREMONY_TIME := 2.8
var _ceremony: Control
var _cer_then: Callable
var _cer_cam: Array = []        # [cible, zoom] d'avant la cérémonie
var ceremonies := 0             # cérémonies jouées (tests)


## Moment fort plein écran : titre géant, gerbes sur toute la largeur, jingle, la caméra recule sur ce qui s'ouvre ; puis
## `then` (la fenêtre). Un toucher l'abrège. Les effets du monde attendent la fin (pas d'ouverture de zone par-dessus).
func ceremony(title: String, sub: String, col: Color, jingle: String, focus: Vector3, then: Callable = Callable()) -> void:
	if _ceremony != null and is_instance_valid(_ceremony):
		_finish_ceremony()
	ceremonies += 1
	Sfx.play(jingle if jingle != "" else "tier", 0.0)
	world_shake()
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	# lot E : plus de z_index (il passait au-dessus des fenêtres et en interceptait les touchers) — la couche est rangée juste
	# sous `popup_layer` (voir plus bas), au-dessus du HUD, des écrans et du tutoriel
	var veil := ColorRect.new()          # voile léger (pas une fenêtre : `_npopups` ne le compte pas)
	veil.color = Color(0.1, 0.06, 0.3, 0.0)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(veil)
	var v := UI.vbox(10)
	v.set_anchors_preset(Control.PRESET_CENTER_TOP)
	v.anchor_left = 0.0
	v.anchor_right = 1.0
	v.offset_top = 420
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	layer.add_child(v)
	var tl := UI.label(title, 76, Color.WHITE, true)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.add_theme_color_override("font_outline_color", UI.INDIGO_DARK)
	tl.add_theme_constant_override("outline_size", 22)
	v.add_child(tl)
	if sub != "":
		var sl := UI.label(sub, 46, col, true)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.add_theme_color_override("font_outline_color", UI.INDIGO_DARK)
		sl.add_theme_constant_override("outline_size", 16)
		v.add_child(sl)
	add_child(layer)
	move_child(layer, popup_layer.get_index())     # sous les fenêtres (la gerbe passe dessus)
	_ceremony = layer
	_cer_then = then
	var lid := layer.get_instance_id()      # les minuteries comparent l'identifiant : la couche peut être libérée avant elles
	layer.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed:
			_finish_ceremony())
	# entrée : le titre tombe et rebondit, le voile monte
	tl.pivot_offset = Vector2(540, 40)
	v.modulate.a = 0.0
	v.scale = Vector2(1.6, 1.6)
	v.pivot_offset = Vector2(540, 80)
	var tw := layer.create_tween().set_parallel(true)
	tw.tween_property(v, "modulate:a", 1.0, 0.25)
	tw.tween_property(v, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(veil, "color:a", 0.35, 0.3)
	var vr := get_viewport_rect()
	Fx.celebration(vr)
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if _ceremony_is(lid):
			Fx.celebration(vr, [UI.AMBER, Color.WHITE, UI.MONEY]))
	# la caméra recule sur ce qui s'ouvre
	if diorama != null and diorama.rig != null:
		_cer_cam = [diorama.rig.goal, diorama.rig.zoom_goal]
		if focus != Vector3.INF:
			diorama.rig.focus(focus)
		diorama.rig.zoom_goal = minf(diorama.rig.zoom_max, maxf(diorama.rig.zoom_goal * 1.5, 100.0))
	get_tree().create_timer(CEREMONY_TIME).timeout.connect(func() -> void:
		if _ceremony_is(lid):
			_finish_ceremony())


func _ceremony_is(id: int) -> bool:
	return _ceremony != null and is_instance_valid(_ceremony) and _ceremony.get_instance_id() == id


func ceremony_active() -> bool:
	return _ceremony != null and is_instance_valid(_ceremony)


## Fin de la cérémonie (au bout de CEREMONY_TIME, ou au toucher) : la caméra revient, puis la fenêtre.
func _finish_ceremony() -> void:
	if _ceremony == null or not is_instance_valid(_ceremony):
		return
	var layer := _ceremony
	_ceremony = null
	var tw := layer.create_tween()
	tw.tween_property(layer, "modulate:a", 0.0, 0.25)
	tw.tween_callback(layer.queue_free)
	if diorama != null and diorama.rig != null and _cer_cam.size() == 2:
		diorama.rig.focus(_cer_cam[0])
		diorama.rig.zoom_goal = float(_cer_cam[1])
	_cer_cam = []
	var then := _cer_then
	_cer_then = Callable()
	if then.is_valid():
		then.call()


# ---------------------------------------------------------------------------
# Fenêtres
# ---------------------------------------------------------------------------

func show_popup(title: String, body: Array, icon_name: String = "info", buttons: Array = [], ok_text: String = "OK", show_ok: bool = true) -> Control:
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
	ok.visible = show_ok
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
	# le montant défile de 0 à la somme gagnée, puis ENCAISSER fait voler les pièces jusqu'au compteur (lot D-UI)
	var amount := float(r.money)
	var ml := UI.label("+0 $", 52, UI.MONEY, true)
	h.add_child(ml)
	body.append(h)
	var roll := func(x: float) -> void: ml.text = "+" + Fmt.money(x)
	ml.create_tween().tween_method(roll, 0.0, amount, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.25)
	body.append(UI.label("%s EVP traités pendant ton absence" % Fmt.num(float(r.evp)), 30, UI.MUTED))
	body.append(UI.wrap_label("Rendement hors-ligne : %s (%d responsable(s) sur %d). Chaque responsable augmente ce rendement." % [Fmt.pct(float(r.yield)), int(r.managers), PortSim.DEPTS.size()], 28))
	var go := UI.button("ENCAISSER", UI.MONEY, 36, 110)
	go.pressed.connect(func() -> void:
		Sfx.play("chest")
		var from := Fx.center_of(ml) if ml.is_inside_tree() else get_viewport_rect().size * 0.5
		Fx.coins(from, Fx.center_of(money_l), 12, func() -> void: flash_money()))
	show_popup("Bon retour, directeur·rice !", body, "harbor", [go], "OK", false)


## Premier lancement : trois idées, pas plus (le tutoriel guidé viendra ensuite).
func _intro() -> void:
	Settings.set_intro_seen()
	var body: Array = []
	body.append(UI.wrap_label("La pêche de l'anse tourne toute seule ; derrière le cap, le vieux quai est rebâti… et tout un terminal reste à construire.", 32, UI.TEXT))
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


# ---------------------------------------------------------------------------
# Lot F2 — le départ ; lot F3 — l'acte 0 « La Crique » et la bascule vers le T1.
# Partie neuve : trois cartes d'intro (simulation gelée), puis l'acte 0 dans l'anse des pêcheurs : HUD visible, la pêche tourne,
# le port à conteneurs est fermé (`PortSim.fishing.act0` : son horloge ne tourne pas). Quand `act0_ready()`, la bascule : le
# caboteur de Corsaire & Fils (l'escale initiale de la simulation) paraît au large, la narratrice, la cérémonie « Palier 1 —
# Le Vieux Quai » (la caméra passe le cap), la séquence de chantiers du T1 (≤ 15 s, chantiers qui se chevauchent, caméra qui
# suit), HUD visible et pêche qui rapporte ; le port ouvre (`open_port`) quand le premier navire glisse vers le quai
# (mécanisme F2 : `Diorama.start_flow_active`). Nouvelle concession : pas d'acte 0, la bascule se joue tout de suite
# (`hold_port`). Une partie chargée pendant l'acte 0 reprend dans l'anse (`_resume_act0`), sans cartes.
# ---------------------------------------------------------------------------
var intro_layer: Control              # carte d'intro affichée (null sinon)
var _intro_cards: Array = []
var _intro_i := -1
var intro_shown := 0                  # (tests) cartes montrées
var start_flow := false               # départ en cours (acte 0, bascule)
var bascule_on := false               # la bascule vers le T1 se joue
var bascule_t := -1.0                 # (tests) instant (horloge du diorama) du début de la bascule
var fish_popups := 0                  # (tests) « +X $ » de débarques montrés
var story_layer: Control              # carte de la narratrice pendant la bascule (null sinon)
var _story_then: Callable
var _story_left := 0.0
const STORY_AUTO := 7.0               # s : la carte de la bascule se passe seule (un toucher l'abrège)


func _begin_start() -> void:
	start_flow = true
	bascule_on = false
	var s := GameState.sim
	if s.fishing.level <= 0 and not s.fishing.act0:
		s.begin_act0()          # partie neuve : l'acte 0 (0 $, port fermé)
	elif not s.fishing.act0:
		s.hold_port()           # nouvelle concession : la pêche continue, la bascule se joue port fermé
	Sim.paused = true
	diorama.start_works_pending()
	_frame(INTRO_LOOK, INTRO_ZOOM, true)
	var cards: Array = GameState.db.tier_def(0).get("intro", [])
	if not Settings.intro_seen and not cards.is_empty() and s.prestiges == 0:
		_intro_cards = cards
		_intro_i = -1
		_next_intro_card()
	else:
		_intro_done()


## Partie chargée pendant l'acte 0 (ou pendant la bascule) : l'anse, sans cartes ni chantier rejoué.
func _resume_act0() -> void:
	start_flow = true
	bascule_on = false
	diorama.start_works_pending()
	_frame(Layout.ANSE_LOOK, Layout.ANSE_ZOOM, true)
	_intro_done()


## Cadrage des cartes d'intro : le fond du golfe, l'anse des pêcheurs, le cap et la friche de l'autre côté.
const INTRO_LOOK := Vector3(-92.0, 0.0, 26.0)
const INTRO_ZOOM := 100.0


func _frame(p: Vector3, zoom: float, now: bool = false) -> void:
	if diorama == null or diorama.rig == null or diorama.rig.locked:
		return
	diorama.rig.focus(p)
	diorama.rig.zoom_goal = clampf(zoom, diorama.rig.zoom_min, diorama.rig.zoom_max)
	if now:
		diorama.rig.target = diorama.rig.goal
		diorama.rig.zoom = diorama.rig.zoom_goal


func intro_active() -> bool:
	return intro_layer != null and is_instance_valid(intro_layer)


func story_active() -> bool:
	return story_layer != null and is_instance_valid(story_layer)


## Partie remplacée pendant le départ : on arrête tout (la nouvelle partie décide de son propre départ).
func _end_start() -> void:
	if intro_active():
		intro_layer.queue_free()
	intro_layer = null
	_intro_cards = []
	if story_active():
		story_layer.queue_free()
	story_layer = null
	_story_then = Callable()
	bascule_on = false
	if start_flow:
		start_flow = false
		Sim.paused = false


func _sync_start() -> void:
	if not start_flow:
		return
	var s := GameState.sim
	Sim.paused = intro_active()          # seules les cartes d'intro gèlent tout ; ensuite la pêche tourne
	if intro_active():
		return
	if story_active():
		_story_left -= get_process_delta_time()
		if _story_left <= 0.0:
			_close_story()
	if not bascule_on and s.act0_ready():
		_begin_bascule()
	# le premier navire glisse vers le quai (chantiers finis) : le port ouvre
	if bascule_on and not diorama.start_flow_active() and not story_active() and not ceremony_active():
		s.open_port()
		bascule_on = false
		start_flow = false


## Les cartes sont passées : l'acte 0 (la caméra descend sur l'anse ; le tutoriel prend la main), ou la bascule tout de suite
## (nouvelle concession).
func _intro_done() -> void:
	Sim.paused = false
	_frame(Layout.ANSE_LOOK, Layout.ANSE_ZOOM)


## Bascule vers le T1 : le caboteur au large (la caméra le suit), la narratrice, puis la cérémonie et les chantiers.
func _begin_bascule() -> void:
	bascule_on = true
	bascule_t = diorama._t
	var v := diorama.spawn_bascule_ship()
	if v != null:
		_frame(v.position + Vector3(-10.0, 0, 26.0), 84.0)
	if GameState.sim.fishing.replay:
		_bascule_ceremony()
		return
	var card: Dictionary = GameState.db.tier_def(0).get("bascule", {})
	if card.is_empty():
		_bascule_ceremony()
	else:
		_show_story(card, _bascule_ceremony)


func _bascule_ceremony() -> void:
	var td := GameState.db.tier_def(1)
	ceremony("Palier 1 — %s" % String(td.get("name", "")), "De l'autre côté du cap", UI.AMBER, "tier1", Vector3(-70.0, 0, -6.0),
		func() -> void: diorama.start_t1_works())


## Carte de la narratrice (même habit que les cartes d'intro), passée d'un toucher ou seule au bout de STORY_AUTO s.
func _show_story(c: Dictionary, then: Callable) -> void:
	_story_then = then
	_story_left = STORY_AUTO
	story_layer = _narrator_card(c, "Toucher pour continuer", _close_story)


func _close_story() -> void:
	if story_active():
		story_layer.queue_free()
	story_layer = null
	var then := _story_then
	_story_then = Callable()
	if then.is_valid():
		then.call()


func _next_intro_card() -> void:
	if intro_active():
		intro_layer.queue_free()
	intro_layer = null
	_intro_i += 1
	if _intro_i >= _intro_cards.size():
		Settings.set_intro_seen()
		_intro_done()
		return
	var c: Dictionary = _intro_cards[_intro_i]
	intro_layer = _narrator_card(c, "%d / %d  ·  Toucher pour continuer" % [_intro_i + 1, _intro_cards.size()], _next_intro_card)
	intro_shown += 1


## Carte de la narratrice en bas de l'écran ; toute la surface est un bouton transparent : un toucher n'importe où appelle `cb`.
func _narrator_card(c: Dictionary, foot_text: String, cb: Callable) -> Control:
	var layer := Button.new()
	layer.flat = true
	layer.focus_mode = Control.FOCUS_NONE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var clear := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		layer.add_theme_stylebox_override(st, clear)
	layer.pressed.connect(func() -> void:
		Sfx.play("click")
		cb.call())
	add_child(layer)
	var card := PanelContainer.new()
	var sb := UI.card_style(Color.WHITE, 30, 22)
	sb.border_color = UI.AMBER
	sb.set_border_width_all(5)
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	card.offset_left = 40
	card.offset_right = -40
	card.offset_bottom = -150
	card.offset_top = -150
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer.add_child(card)
	var h := UI.hbox(18)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(h)
	var left := UI.vbox(2)
	var nar := Narrator.new(132.0)
	nar.pose = String(c.get("pose", "hello"))
	left.add_child(nar)
	var who := UI.label("Capitaine Roche", 24, UI.MUTED)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(who)
	h.add_child(left)
	var v := UI.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UI.label(String(c.get("title", "")), 38, UI.VIOLET))
	v.add_child(UI.wrap_label(String(c.get("text", "")), 30, UI.TEXT))
	var foot := UI.label(foot_text, 24, UI.MUTED)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(foot)
	for n in card.find_children("*", "Control", true, false):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	card.create_tween().tween_property(card, "modulate:a", 1.0, 0.25)
	return layer

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


# ---------------------------------------------------------------------------
# Plan de la baie : fiche du bâtiment touché dans le monde, fiche d'une zone grisée, narratrice à l'ouverture
# ---------------------------------------------------------------------------

## Fenêtres ouvertes (voiles) : les effets du monde attendent qu'elles soient fermées.
func _npopups() -> int:
	var n := 0
	for c in popup_layer.get_children():
		if c is ColorRect and not c.is_queued_for_deletion():
			n += 1
	return n


## Fiche d'un bâtiment (la même que Gestion → Bâtiments) : ce qu'il apporte, son prix, CONSTRUIRE.
func open_building(bid: String) -> Control:
	var s := GameState.sim
	if not s.db.building_by_id.has(bid):
		return null
	var b: Dictionary = s.db.building_by_id[bid]
	var st := s.building_state(bid)
	var body: Array = []
	var z := Zones.zone_of(bid)
	if not z.is_empty():
		body.append(UI.label("Zone : %s" % z.name, 28, UI.MUTED))
	body.append(UI.wrap_label(String(b.desc), 30, UI.TEXT))
	var buttons: Array = []
	if st == "built":
		body.append(UI.label("Construit ✓", 32, UI.MONEY))
	elif st == "available":
		var go := UI.button("CONSTRUIRE\n" + Fmt.money(float(b.cost)), UI.MONEY, 30, 110)
		go.disabled = s.money < float(b.cost)
		go.pressed.connect(func() -> void: build_from_world(bid))
		buttons.append(go)
		if s.money < float(b.cost):
			body.append(UI.wrap_label("Il manque %s." % Fmt.money(float(b.cost) - s.money), 28, UI.BAD))
	elif st == "tier":
		body.append(UI.wrap_label("Se construit au palier T%d." % int(b.tier), 28, UI.BAD))
	else:
		body.append(UI.wrap_label("Construis d'abord le bâtiment précédent.", 28, UI.BAD))
	Sfx.play("click")
	return show_popup(String(b.name), body, Info.building_icon(b), buttons, "FERMER")


## Achat depuis la fiche ouverte dans le monde (même effet que depuis Gestion → Bâtiments).
func build_from_world(bid: String) -> bool:
	if GameState.sim.build(bid):
		Sfx.play("build")
		flash_money()
		return true
	Sfx.play("bad")
	return false


## Fiche d'une zone grisée : nom, ce qu'elle apporte, sa condition.
func open_zone(zone_id: int) -> Control:
	var s := GameState.sim
	var z := Layout.zone_by_id(zone_id)
	if z.is_empty():
		return null
	var body: Array = [UI.wrap_label(String(z.desc), 30, UI.TEXT)]
	var key := String(z.get("key", ""))
	var cond := ""
	if key != "" and s.db.building_by_id.has(key):
		var b: Dictionary = s.db.building_by_id[key]
		cond = "S'ouvre avec « %s » (%s), palier T%d." % [b.name, Fmt.money(float(b.cost)), int(b.tier)]
	elif String(z.open).begins_with("t"):
		cond = "S'ouvre au palier T%s." % String(z.open).substr(1)
	if Zones.state(s, z) == Zones.NEXT:
		cond += " C'est la prochaine étape !"
	body.append(UI.wrap_label(cond, 28, UI.VIOLET))
	Sfx.play("click")
	return show_popup(String(z.name), body, "info", [], "OK")


## Temps fort d'une ouverture de zone : la narratrice dit une phrase.
func _on_zone_opened(zone_id: int) -> void:
	var say := String(Layout.ZONE_SAY.get(zone_id, ""))
	if say != "":
		narrate(say)


var _narration: Control


## Bulle de la narratrice (Capitaine Roche) en bas de l'écran, non bloquante, 4 s.
func narrate(text: String) -> void:
	if _narration != null and is_instance_valid(_narration):
		_narration.queue_free()
	var card := PanelContainer.new()
	var sb := UI.card_style(Color.WHITE, 30, 18)
	sb.border_color = UI.AMBER
	sb.set_border_width_all(4)
	card.add_theme_stylebox_override("panel", sb)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	card.custom_minimum_size = Vector2(900, 0)
	card.offset_left = -450
	card.offset_right = 450
	card.offset_bottom = -250
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UI.hbox(16)
	card.add_child(h)
	var nar := Narrator.new(104.0)
	nar.pose = "bravo"
	h.add_child(nar)
	var l := UI.wrap_label(text, 30, UI.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	add_child(card)
	move_child(card, popup_layer.get_index())
	_narration = card
	card.modulate.a = 0.0
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.25)
	tw.tween_interval(3.6)
	tw.tween_property(card, "modulate:a", 0.0, 0.4)
	tw.tween_callback(card.queue_free)
