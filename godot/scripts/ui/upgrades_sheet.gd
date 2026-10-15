class_name UpgradesSheet
extends Sheet
## Améliorations : cartes de départements (niveau, effet → suivant, palier, achat ×1/×10/×100/max) et licences de cargaison.

const MULTS := [1, 10, 100, -1]

static var mult_index: int = 0
var focus_dept: String = ""
var cards: Array[Dictionary] = []
var mult_btn: Button
var _gain_cache: Dictionary = {}     # « d:cranes:10 » / « c:2:1 » -> gain estimé {total, flow, fees} (par seconde)
var _gain_base: Dictionary = {}      # revenu estimé sans achat {total, fees}, commun à toutes les cartes
var _gain_at := 0                    # instant (ms) du dernier calcul
var _burst_n := 0                    # achats réussis (pour ne jouer qu'un son sur 3 pendant un appui long)
var _feat_n := -1                    # fonctions révélées à la construction des cartes
var best_dept := ""                   # service du « meilleur achat » (le plus vite rentabilisé)
var shown_dept := ""                  # service sur lequel la feuille s'est ouverte (tests)


func _init(dept: String = "") -> void:
	super._init("Améliorations", ["Départements", "Cargaisons"] as Array[String])
	focus_dept = dept
	half = true          # feuille mi-hauteur : on achète au-dessus du port qui vit (lot D-UI)


func _ready() -> void:
	super._ready()
	mult_btn = UI.button("", UI.AMBER, 30, 96)
	mult_btn.custom_minimum_size.x = 120
	mult_btn.add_theme_color_override("font_color", UI.TEXT)
	mult_btn.pressed.connect(_cycle_mult)
	header_extra.add_child(mult_btn)
	_update_mult()
	# ouverte sur le service demandé, sinon sur le goulot, sinon sur le meilleur achat : sa carte en haut de la feuille, et la
	# caméra cadre son poste dans la moitié haute de l'écran (lot D-UI)
	var d := focus_dept
	if Hud.fishing_cards(sim()):
		# lot F3/G1 : la Crique — les cartes de la pêche ; la caméra cadre l'anse au-dessus de la feuille
		if Hud.main != null:
			Hud.main.frame_point(Vector3(-122.0, 0.0, 44.0))
		return
	if d == "":
		var gd := String(sim().shown_analysis().get("dept", ""))
		d = gd if gd != "" and sim().feature("dept_" + gd) else best_dept
	shown_dept = d
	if Hud.main != null:
		# sans goulot de service ni meilleur achat (« pas assez de navires ») : on cadre la grue, le cœur du port — jamais la
		# mer vide du cadrage de départ au-dessus de la feuille
		Hud.main.frame_dept(d if d != "" else "cranes")
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or d == "":
		return
	scroll_to_dept(d)


## Fait défiler la feuille pour que la carte du service soit en haut.
func scroll_to_dept(d: String) -> void:
	var c := _card_for("dept", d)
	if c.is_empty():
		return
	var root: Control = c.root
	scroll.scroll_vertical = maxi(0, int(root.get_global_rect().position.y - scroll.get_global_rect().position.y) + scroll.scroll_vertical - 12)


func _cycle_mult() -> void:
	mult_index = (mult_index + 1) % MULTS.size()
	_update_mult()
	refresh()
	Sfx.play("click")


func _update_mult() -> void:
	var m: int = MULTS[mult_index]
	mult_btn.text = "MAX" if m < 0 else "×%d" % m


## Ordre de présentation des services (lot G2 : l'ordre du processus) : Arrivées · Accostage · Déchargement · Douane ·
## Stockage · Sortie camions.
const CARD_ORDER := ["harbor", "berths", "cranes", "customs", "yard_ops", "gate"]


## Cartes du chapitre en cours (services révélés) plus **une** carte grisée « à venir » avec sa condition.
func build() -> void:
	cards.clear()
	var s := sim()
	_feat_n = _card_features(s)
	if Hud.fishing_cards(s):
		_build_fishing(s)
		return
	if tab == 0:
		help("upg_depts", "Le département qui limite le flux porte la pastille rouge GOULOT. Touche « i » pour voir les étapes et le « pourquoi ». Garde le doigt sur AMÉLIORER pour acheter en rafale.")
		var next_locked := _next_locked_dept(s)
		# lot G2 : le prochain bâtiment en tête de liste (un seul achat à la fois tant que le terre-plein se bâtit)
		if s.g2:
			var nb := Zones.next_building(s)
			if nb != "":
				_building_card(s, nb)
		for d in CARD_ORDER:
			if not s.feature("dept_" + d) and d != next_locked:
				continue
			_dept_card(d)
		# lot G1 : après la Concession, les cartes de la Crique restantes, en bas, sous un titre
		if s.fishing.places > 0 and not s.fishing.act0 and not s.fishing.maxed():
			var title := UI.label("La Crique", 36, UI.MUTED)
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			content.add_child(title)
			_fish_cards(s)
	else:
		help("upg_lic", "Les licences augmentent la valeur de chaque EVP traité. Chaque palier du port relève leur niveau maximal.")
		for ci in PortSim.NCARGO:
			if s.feature("licences") or ci == 0:
				_cargo_card(ci)


## Lot G2 — la carte du prochain bâtiment (CONSTRUIRE), en tête d'AMÉLIORER.
func _building_card(s: PortSim, bid: String) -> void:
	var b: Dictionary = s.db.building_by_id[bid]
	var c := UI.card()
	content.add_child(c)
	var row := UI.hbox(20)
	c.add_child(row)
	row.add_child(UI.icon_disc(Info.building_icon(b), UI.VIOLET, 110))
	var mid := UI.vbox(6)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	mid.add_child(UI.label(String(b.name), 40, UI.VIOLET))
	mid.add_child(UI.wrap_label(String(b.desc), 28, UI.TEXT))
	var buy := UI.button("", UI.MONEY, 30, 120)
	buy.custom_minimum_size.x = 230
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.pressed.connect(func() -> void:
		if Hud.main != null:
			Hud.main.build_from_world(bid)
		else:
			sim().build(bid)
		request_rebuild())
	row.add_child(buy)
	cards.append({"build": bid, "root": c, "buy": buy})


func _refresh_building_cards(s: PortSim) -> void:
	for c in cards:
		if not c.has("build"):
			continue
		var cost := float(s.db.building_by_id[String(c.build)].cost)
		var b: Button = c.buy
		b.disabled = cost > s.money or s.building_state(String(c.build)) != "available"
		b.text = "CONSTRUIRE\n%s" % Fmt.money(cost) if not b.disabled else "Il manque\n%s" % Fmt.money(maxf(0.0, cost - s.money))


## Le prochain service à se révéler (ordre de data/unlocks.json), "" si tout est révélé.
func _next_locked_dept(s: PortSim) -> String:
	for u in s.db.unlocks:
		var id := String(u.id)
		if id.begins_with("dept_") and not s.feature(id):
			return id.substr(5)
	return ""


func _dept_card(d: String) -> void:
	var s := sim()
	var def: Dictionary = s.db.dept_by_id[d]
	var c := UI.card()
	content.add_child(c)
	var row := UI.hbox(20)
	c.add_child(row)
	var left := UI.vbox(8)
	left.add_child(UI.icon_disc(Info.DEPT_ICON[d], Info.DEPT_COLOR[d], 110))
	var lv := UI.badge("1")
	lv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(lv)
	row.add_child(left)
	var mid := UI.vbox(6)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	var trow := HFlowContainer.new()      # nom + GOULOT + MEILLEUR ACHAT : les pastilles passent à la ligne plutôt qu'élargir la liste
	trow.add_theme_constant_override("h_separation", 10)
	trow.add_theme_constant_override("v_separation", 0)
	mid.add_child(trow)
	var name_l := UI.label(String(def.name), 40, UI.VIOLET)
	trow.add_child(name_l)
	var dot := UI.label("● GOULOT", 26, UI.BAD)
	trow.add_child(dot)
	var best := UI.label("★ MEILLEUR ACHAT", 24, UI.MONEY)
	best.visible = false
	trow.add_child(best)
	trow.add_child(_info_button(def, d, -1))
	var stage_l := UI.wrap_label("", 26, UI.VIOLET)
	mid.add_child(stage_l)
	# effet actuel → suivant (texte : le « pourquoi » est dans la fiche « i », une cible de 96 px au lieu d'une ligne de 44)
	var eff := UI.wrap_label("", 32, UI.TEXT)
	mid.add_child(eff)
	var det := UI.wrap_label("", 26, UI.MUTED)      # retour à la ligne : au T3 la carte débordait de l'écran (revue D-UI)
	mid.add_child(det)
	var pay := UI.wrap_label("", 26, UI.MONEY)
	mid.add_child(pay)
	var bar := RoundBar.new(34)
	bar.color = UI.INFO
	mid.add_child(bar)
	var buy := UI.button("", UI.MONEY, 30, 120)
	buy.custom_minimum_size.x = 230
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hold(buy, _buy_dept.bind(d), func() -> bool: return _buy_dept(d, true))
	row.add_child(buy)
	cards.append({"dept": d, "root": c, "lv": lv.get_child(0), "eff": eff, "det": det, "bar": bar, "buy": buy, "dot": dot,
		"best": best, "pay": pay, "stage": stage_l})


func _cargo_card(ci: int) -> void:
	var s := sim()
	var def: Dictionary = s.db.cargo[ci]
	var cid: String = def.id
	var c := UI.card()
	content.add_child(c)
	var row := UI.hbox(20)
	c.add_child(row)
	var left := UI.vbox(8)
	left.add_child(UI.icon_disc(Info.CARGO_ICON[cid], Info.CARGO_COLOR[cid], 110))
	var lv := UI.badge("1")
	lv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(lv)
	row.add_child(left)
	var mid := UI.vbox(6)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	var trow := UI.hbox(10)
	trow.add_child(UI.label(String(def.name), 40, UI.VIOLET))
	trow.add_child(_info_button(def, "", ci))
	mid.add_child(trow)
	var stage_l := UI.wrap_label("", 26, UI.VIOLET)
	mid.add_child(stage_l)
	var eff := UI.wrap_label("", 32, UI.TEXT)
	mid.add_child(eff)
	var det := UI.wrap_label(String(def.desc), 26)
	mid.add_child(det)
	var pay := UI.wrap_label("", 26, UI.MONEY)
	mid.add_child(pay)
	var bar := RoundBar.new(34)
	bar.color = UI.MONEY
	mid.add_child(bar)
	var buy := UI.button("", UI.MONEY, 30, 120)
	buy.custom_minimum_size.x = 230
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hold(buy, _buy_licence.bind(ci), func() -> bool: return _buy_licence(ci, true))
	row.add_child(buy)
	cards.append({"cargo": ci, "root": c, "lv": lv.get_child(0), "eff": eff, "det": det, "bar": bar, "buy": buy, "pay": pay, "stage": stage_l})


## Bouton « i » : frise de toutes les étapes (niveau, multiplicateur, nom), l'étape suivante mise en valeur.
func _info_button(def: Dictionary, d: String, ci: int) -> Button:
	# pastille « i » de 56 px, zone de toucher de 96 px (cible tactile, revue D-UI)
	var b := UI.hit_button(UI.INFO, "i", 56.0, 96.0)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = "Toutes les étapes"
	b.pressed.connect(func() -> void:
		Sfx.play("click")
		show_stages(def, d, ci))
	return b


func show_stages(def: Dictionary, d: String, ci: int) -> Control:
	var s := sim()
	var lv: int = s.licences[ci] if ci >= 0 else int(s.levels[d])
	var cur := Info.stage(def, lv)
	var nxt := Info.next_stage(def, lv)
	var body: Array = []
	var total := 1.0
	for st in def.get("stages", []):
		var slv := int(st.lv)
		var m := Info.stage_mult(s, ci, slv)
		total *= m
		var reached := slv <= lv
		var is_next := not nxt.is_empty() and slv == int(nxt.lv)
		var row := PanelContainer.new()
		var bg := Color("#EDE8FF") if st == cur else (Color("#FFF4DD") if is_next else Color.WHITE)
		row.add_theme_stylebox_override("panel", UI.flat(bg, 18, 14, 6))
		var h := UI.hbox(14)
		row.add_child(h)
		var lvl := UI.label("Niv. %d" % slv, 28, UI.VIOLET if reached else UI.MUTED, true)
		lvl.custom_minimum_size.x = 130
		h.add_child(lvl)
		var v := UI.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := UI.label(("✓ " if reached else ("→ " if is_next else "")) + String(st.name), 30, UI.TEXT if reached or is_next else UI.MUTED)
		v.add_child(nm)
		var tx := UI.wrap_label(String(st.text), 24)
		v.add_child(tx)
		h.add_child(v)
		h.add_child(UI.label("" if slv <= 1 else Fmt.mult(m), 28, UI.MONEY if reached else UI.MUTED, true))
		body.append(row)
	var sum := "Toutes les étapes : %s au total." % Fmt.mult(total)
	if ci >= 0 and s.licence_cap() < (1 << 30):
		sum += " Niveau maximal au palier T%d : %d." % [s.tier, s.licence_cap()]
	body.append(UI.wrap_label(sum, 26, UI.MUTED))
	# « pourquoi » : le détail du calcul de l'effet (il était sur la ligne de l'effet, une cible trop petite)
	var why := UI.button("POURQUOI ?", UI.INFO, 30, 100)
	why.pressed.connect(func() -> void:
		if ci >= 0:
			Hud.main.show_breakdown("Valeur " + String(def.short), "value", ci)
		else:
			Hud.main.show_breakdown(String(def.stat_label), Info.dept_stat_name(d)))
	return Hud.main.show_popup("%s — étapes" % String(def.name), body, Info.CARGO_ICON[def.id] if ci >= 0 else Info.DEPT_ICON[d], [why])


## Appui bref : un achat. Appui long : achats en rafale qui accélèrent, un seul effet à la fin.
func _hold(b: Button, single: Callable, again: Callable) -> void:
	# `_burst_n` repart de zéro à chaque rafale (lot E : la hauteur du son dérivait d'une rafale à l'autre)
	var h := HoldRepeat.attach(b, single, func(n: int) -> bool:
		if n <= 1:
			_burst_n = 0
		return again.call())
	h.burst_ended.connect(func(n: int) -> void:
		if n > 0 and is_instance_valid(b):
			Fx.reward(b, "+%d niveaux" % n if n > 1 else "", UI.MONEY))


func _n_for(max_fn: Callable) -> int:
	var m: int = MULTS[mult_index]
	if m > 0:
		return m
	return maxi(1, max_fn.call())


## Gain de revenu d'un achat ({"total", "flow", "fees"} : `PortSim.upgrade_gain_parts`). Chaque estimation rejoue l'analyse
## du goulot : on les recalcule une fois par seconde (et après un achat) au lieu de 5 fois, avec une seule estimation de
## référence pour toutes les cartes.
func _gain_for(key: String, dept: String, n: int, cargo_i: int = -1) -> Dictionary:
	var now := Time.get_ticks_msec()
	if now - _gain_at > 1000:
		_gain_cache.clear()
		_gain_base = {}
		_gain_at = now
	if not _gain_cache.has(key):
		var s := sim()
		if _gain_base.is_empty():
			_gain_base = s.income_parts_with("harbor", 0)
		_gain_cache[key] = s.upgrade_gain_parts(dept, n, cargo_i, _gain_base)
	return _gain_cache[key]


## Lot E : règles d'un « bon achat » dans `Advice` (sans dépendance aux autoloads, testées par run_all).
const GOOD_PAYBACK := Advice.GOOD_PAYBACK


static func is_good(parts: Dictionary, cost: float) -> bool:
	return Advice.is_good(parts, cost)


static func moves_flow(parts: Dictionary) -> bool:
	return Advice.moves_flow(parts)


static func _payback(parts: Dictionary, cost: float, label: String = "", bottleneck: bool = false) -> Dictionary:
	return Advice.payback(parts, cost, label, bottleneck)


static func _effect_label(s: PortSim, d: String, n: int) -> String:
	return Advice.effect_label(s, d, n)


func refresh() -> void:
	var s := sim()
	if _card_features(s) != _feat_n:      # un chapitre s'ouvre pendant que l'écran est ouvert : ses cartes apparaissent
		request_rebuild()
		return
	if Hud.fishing_cards(s):
		_refresh_fishing(s)
		return
	_refresh_fishing(s)      # (lot G1 : les cartes de la Crique restantes, en bas)
	_refresh_building_cards(s)      # (lot G2 : le prochain bâtiment, en tête)
	var best_secs := INF
	var best_card: Dictionary = {}
	for c in cards:
		if c.has("dept"):
			var d: String = c.dept
			var lv: int = s.levels[d]
			(c.lv as Label).text = str(lv)
			_stage_text(c, s.db.dept_by_id[d], lv)
			if _locked(c, "dept_" + d):
				continue
			var n := _n_for(s.dept_max_affordable.bind(d))
			var cost := s.dept_cost(d, n)
			var hit := Info.event_hits(s, d)          # aléa en cours sur ce service (lot E, E3)
			var e0 := Info.dept_effect(s, d)
			var e1 := Info.dept_effect(s, d, n)
			if hit and (e0 == "Suspendu" or s.stat(Info.dept_stat_name(d)) <= 0.0):
				(c.eff as Label).text = "Suspendu (%s)" % Info.event_name(s)
			else:
				(c.eff as Label).text = "%s  →  %s" % [e0, e1] + ("  (%s)" % Info.event_name(s) if hit else "")
			var mgr := "Responsable ✓" if s.managers[d] else "Sans responsable"
			(c.det as Label).text = "%s\nAgents %d/%d · %s" % [Info.dept_detail(s, d), s.agents(d), s.agents_max(), mgr]
			var nm := s.next_dept_milestone(lv)
			var prev := 0
			for l in s.db.cfg("dept_milestones"):
				if int(l) <= lv:
					prev = int(l)
			var bar: RoundBar = c.bar
			bar.value = 0.0 if nm == 0 else float(lv - prev) / float(nm - prev)
			bar.text = "" if nm == 0 else "Palier ×%s au niveau %d" % [str(int(s.db.cfg("dept_milestone_mult"))), nm]
			var b: Button = c.buy
			b.disabled = cost > s.money
			# bouton gris : ce qui manque, pas seulement le prix (revue D-UI)
			b.text = "AMÉLIORER ×%d\n%s" % [n, Fmt.money(cost)] if not b.disabled else "Il manque\n%s" % Fmt.money(cost - s.money)
			(c.dot as Label).visible = s.shown_analysis().get("dept", "") == d
			var parts := _gain_for("d:%s:%d" % [d, n], d, n)
			var pb := _payback(parts, cost, _effect_label(s, d, n), String(s.shown_analysis().get("dept", "")) == d)
			var goal := s.chapter_goal()
			if not moves_flow(parts) and String(goal.get("dept", "")) == d:
				# le service du chapitre en cours : même sans gain immédiat, chaque niveau rapproche du chapitre suivant
				pb = {"text": "Niveau %d : ouvre « %s » (%d/%d)" % [int(goal.min), String(goal.name), mini(lv, int(goal.min)), int(goal.min)], "secs": INF, "good": false, "goal": true}
			if hit:
				pb.good = false          # sous un aléa, jamais le meilleur achat (son gain n'est pas représentatif)
			(c.pay as Label).text = String(pb.text)
			# vert seulement pour un bon achat (rentabilisé en moins de 10 min) qu'on peut payer ; gris sinon (lot E)
			var pay_col := UI.MONEY if bool(pb.good) and cost <= s.money else (UI.VIOLET if pb.has("goal") else UI.MUTED)
			(c.pay as Label).add_theme_color_override("font_color", pay_col)
			if bool(pb.good) and float(pb.secs) < best_secs:
				best_secs = float(pb.secs)
				best_card = c
		elif c.has("cargo"):
			var ci: int = c.cargo
			var cid: String = s.db.cargo[ci].id
			var b2: Button = c.buy
			(c.lv as Label).text = str(s.licences[ci])
			_stage_text(c, s.db.cargo[ci], s.licences[ci])
			if _locked(c, "licences"):
				continue
			if s.unlocked[ci] == 0:
				(c.eff as Label).text = "Débloqué par : " + Info.building_name_for_cargo(s, cid)
				b2.text = "Verrouillé"
				b2.disabled = true
				(c.bar as RoundBar).value = 0.0
				(c.bar as RoundBar).text = ""
				continue
			var room := s.licence_room(ci)
			var lv2: int = s.licences[ci]
			if room <= 0:
				# plafond du palier : c'est le palier suivant du port qui le relève
				(c.eff as Label).text = "%s/EVP" % Fmt.money(Info.cargo_value(s, ci))
				(c.bar as RoundBar).value = 1.0
				(c.bar as RoundBar).text = "Plafond du palier T%d : niveau %d" % [s.tier, lv2]
				b2.text = "PLAFOND\nniv. %d" % lv2
				b2.disabled = true
				(c.pay as Label).text = "Le palier suivant du port relève le plafond."
				(c.pay as Label).add_theme_color_override("font_color", UI.MUTED)
				continue
			var n2 := mini(room, _n_for(s.licence_max_affordable.bind(ci)))
			var cost2 := s.licence_cost(ci, n2)
			(c.eff as Label).text = "%s/EVP  →  %s" % [Fmt.money(Info.cargo_value(s, ci)), Fmt.money(Info.cargo_value(s, ci, n2))]
			# prochain palier de valeur, lu dans la config ([[niveau, mult], …])
			var ms: Array = s.db.cfg("licence_milestones")
			var nxt := Progression.next_step(lv2, ms)
			var prev2 := 0
			for st in ms:
				if int(st[0]) <= lv2:
					prev2 = maxi(prev2, int(st[0]))
			var bar2: RoundBar = c.bar
			bar2.value = 0.0 if nxt.is_empty() else float(lv2 - prev2) / float(int(nxt[0]) - prev2)
			bar2.text = "Plus de palier : +%s par niveau" % Fmt.pct(float(s.db.cfg("licence_per_level"))) if nxt.is_empty() \
				else "Palier %s au niveau %d" % [Fmt.mult(float(nxt[1])), int(nxt[0])]
			b2.disabled = cost2 > s.money
			b2.text = "LICENCE ×%d\n%s" % [n2, Fmt.money(cost2)] if not b2.disabled else "Il manque\n%s" % Fmt.money(cost2 - s.money)
			var pb2 := _payback(_gain_for("c:%d:%d" % [ci, n2], "", n2, ci), cost2, "Licence")
			(c.pay as Label).text = String(pb2.text)
			(c.pay as Label).add_theme_color_override("font_color", UI.MONEY if bool(pb2.good) and cost2 <= s.money else UI.MUTED)
	best_dept = String(best_card.get("dept", ""))
	# « meilleur achat » : le département qui rentabilise le plus vite (parmi ceux qui rapportent)
	for c in cards:
		if c.has("best"):
			(c.best as Label).visible = best_secs < INF and c == best_card



## Étape actuelle et suivante d'une carte (« Grue révisée · niv. 25 : Grutiers de jour et de nuit »).
func _stage_text(c: Dictionary, def: Dictionary, lv: int) -> void:
	var cur := Info.stage(def, lv)
	var nxt := Info.next_stage(def, lv)
	var t := "« %s »" % String(cur.get("name", ""))
	if not nxt.is_empty():
		t += "  ·  niv. %d : %s" % [int(nxt.lv), String(nxt.name)]
	(c.stage as Label).text = t


## Carte d'une fonction pas encore révélée : visible mais grisée, avec sa condition (on voit ce qui arrive).
func _locked(c: Dictionary, feature_id: String) -> bool:
	var s := sim()
	var root: Control = c.root
	if s.feature(feature_id):
		root.modulate = Color.WHITE
		return false
	root.modulate = Color(1, 1, 1, 0.55)
	(c.eff as Label).text = "Se débloque " + s.unlock_text(feature_id)
	(c.pay as Label).text = ""
	if c.has("dot"):
		(c.dot as Label).visible = false
		(c.det as Label).text = ""
	var bar: RoundBar = c.bar
	bar.value = 0.0
	bar.text = ""
	var b: Button = c.buy
	b.text = "Verrouillé"
	b.disabled = true
	return true


func _card_for(key: String, value: Variant) -> Dictionary:
	for c in cards:
		if c.get(key) == value:
			return c
	return {}


## Achat d'un département. `quiet` : répétition d'un appui long (un son sur 3, pas de gerbe, la fanfare reste pour les paliers).
func _buy_dept(d: String, quiet: bool = false) -> bool:
	if not quiet:
		_gain_at = 0      # les gains estimés dépendent de l'état : à recalculer après l'achat
	var s := sim()
	var n: int = MULTS[mult_index]
	var lv0: int = s.levels[d]
	var stat0 := s.stat(Info.dept_stat_name(d))
	if not s.buy_dept(d, n):
		if not quiet:
			Sfx.play("bad")
		return false
	_burst_n += 1
	Hud.main.note_purchase("dept", d, stat0)      # retour dans le monde : caméra, effet, « +X $/s » ou « +6 % »
	Hud.main.flash_money()
	var card := _card_for("dept", d)
	var lv1: int = s.levels[d]
	var milestone := s.dept_milestone_mult(lv1) > s.dept_milestone_mult(lv0)
	if milestone:
		Sfx.play("milestone")
		Hud.main.toast("Palier ×%d : %s niveau %d !" % [int(s.db.cfg("dept_milestone_mult")), s.db.dept_by_id[d].name, lv1], "good")
		Hud.main.world_shake()
	elif not quiet or _burst_n % 3 == 0:
		Sfx.play("buy", 0.0, mini(12, int(_burst_n / 3)) if quiet else 0)      # appui long : un demi-ton de plus toutes les 3 répétitions
	if not card.is_empty():
		Fx.pop(card.root, 1.02 if quiet else 1.04)
		if milestone or not quiet:
			Fx.reward(card.buy, "Palier ×2 !" if milestone else "Niv. %d" % lv1, UI.AMBER if milestone else UI.MONEY, milestone)
	refresh()
	return true


func _buy_licence(ci: int, quiet: bool = false) -> bool:
	if not quiet:
		_gain_at = 0
	var s := sim()
	var n: int = MULTS[mult_index]
	var lv0: int = s.licences[ci]
	var stat0 := s.stat("value", ci)
	if not s.buy_licence(ci, n):
		if not quiet:
			Sfx.play("bad")
		return false
	_burst_n += 1
	if Hud.main != null:
		Hud.main.note_purchase("licence", String(s.db.cargo[ci].id), stat0)
	var lv1: int = s.licences[ci]
	var ms: Array = s.db.cfg("licence_milestones")
	var m0 := Progression.step_mult(lv0, ms)
	var m1 := Progression.step_mult(lv1, ms)
	var milestone := m1 > m0
	if milestone:
		Sfx.play("milestone")
		Hud.main.toast("Palier de licence %s : %s niveau %d !" % [Fmt.mult(m1 / m0), s.db.cargo[ci].name, lv1], "good")
	elif not quiet or _burst_n % 3 == 0:
		Sfx.play("buy", 0.0, mini(12, int(_burst_n / 3)) if quiet else 0)      # appui long : un demi-ton de plus toutes les 3 répétitions
	var card := _card_for("cargo", ci)
	if not card.is_empty():
		Fx.pop(card.root, 1.02 if quiet else 1.04)
		if milestone or not quiet:
			Fx.reward(card.buy, "Palier %s !" % Fmt.mult(m1 / m0) if milestone else "Licence niv. %d" % lv1, UI.AMBER if milestone else UI.MONEY, milestone)
	refresh()
	return true


## Fonctions révélées qui changent les cartes (services, licences) : les autres révélations ne reconstruisent pas l'écran.
func _card_features(s: PortSim) -> int:
	var n := 0
	for id in s.features:
		if String(id).begins_with("dept_") or id == "licences":
			n += 1
	# lot F3/G1 : la Crique (ses cartes changent avec les bâtiments et la Concession) ou la bascule (les cartes du port)
	if Hud.fishing_cards(s):
		n += 1000
	n += 10 * s.fishing.built.size() + (100 if s.fishing.concession_available() else 0) + (5 if s.fishing.maxed() else 0) \
		+ (3 if s.fishing.places > 0 else 0)
	if s.g2:
		n += 1000 * s.built.size()          # lot G2 : un bâtiment construit change la carte de tête
	return n


# --- lot F3/G1 : chapitre 1 « La Crique » — les cartes de la pêche, sur les mêmes cartes (pas d'écran nouveau) ---------------
# Pendant la Crique : [la Concession dès la marina] · le prochain bâtiment · Places au ponton · Services à quai (×1/×10/max,
# maintien). Après la Concession : un titre « La Crique » et les cartes restantes en bas de la liste, jusqu'à leur maximum.

const FISH_COLOR := Color("#2E9BB5")


func _build_fishing(s: PortSim) -> void:
	if tab != 0:
		help("upg_lic0", "Les licences de cargaison viendront avec le port à conteneurs, de l'autre côté du cap.")
		return
	help("upg_fish", "La crique d'Odette : chaque bateau rentré paie sa place et les services du quai. Touche-le pour encaisser, ou confie ça à Marcel. Une place de plus = une barque de plus.")
	_fish_cards(s)


## Cartes de la Crique (pendant, puis après la Concession sous un titre).
func _fish_cards(s: PortSim) -> void:
	var f := s.fishing
	if f.places <= 0:
		_fish_card(s, "places")
		return
	if f.concession_available():
		_fish_card(s, "concession")
	var nb := f.next_building()
	if not nb.is_empty():
		_fish_card(s, String(nb.id))
	if f.places < f.places_max():
		_fish_card(s, "places")
	if f.services < f.services_max():
		_fish_card(s, "services")


func _fish_card(s: PortSim, id: String) -> void:
	var f := s.fishing
	var c := UI.card()
	content.add_child(c)
	var row := UI.hbox(20)
	c.add_child(row)
	var def: Dictionary = f.cfg.get(id, {}) if id == "places" or id == "services" else f.building_def(id)
	var left := UI.vbox(8)
	left.add_child(UI.icon_disc(String(def.get("icon", "ship")), UI.AMBER if id == "concession" else FISH_COLOR, 110))
	var lv: Control = null
	if id == "places" or id == "services":
		lv = UI.badge("0")
		lv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		left.add_child(lv)
	row.add_child(left)
	var mid := UI.vbox(6)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	mid.add_child(UI.label(String(def.get("name", id)), 40, UI.VIOLET))
	var eff := UI.wrap_label(String(def.get("text", "")), 28, UI.TEXT)
	mid.add_child(eff)
	var pay := UI.wrap_label("", 26, UI.MONEY)
	mid.add_child(pay)
	var buy := UI.button("", UI.AMBER if id == "concession" else UI.MONEY, 30, 120)
	buy.custom_minimum_size.x = 230
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if id == "places" or id == "services":
		var h := HoldRepeat.attach(buy, _buy_fish.bind(id, false), func(_n: int) -> bool: return _buy_fish(id, true))
		h.burst_ended.connect(func(_count: int) -> void: refresh())
	else:
		buy.pressed.connect(_buy_fish.bind(id, false))
	row.add_child(buy)
	cards.append({"fish": id, "root": c, "buy": buy, "eff": eff, "pay": pay, "lv": lv.get_child(0) if lv != null else null})


func _refresh_fishing(s: PortSim) -> void:
	var f := s.fishing
	var n_want: int = MULTS[mult_index]
	for c in cards:
		if not c.has("fish"):
			continue
		var id: String = c.fish
		var b: Button = c.buy
		var pay: Label = c.pay
		var cost := 0.0
		var n := 1
		match id:
			"places":
				n = maxi(1, mini(f.places_max() - f.places, f.places_affordable(s.money) if n_want < 0 else n_want)) if f.places > 0 else 1
				cost = f.places_cost(n)
				(c.lv as Label).text = str(f.places)
				if f.places <= 0:
					b.text = "RÉPARER\ngratuit"
					pay.text = ""
				else:
					b.text = "AMÉLIORER ×%d\n%s" % [n, Fmt.money(cost)]
					pay.text = "%d barques · niv. %d/%d · revenu de la pêche %s/s" % [f.boat_count("dinghy"), f.places, f.places_max(), Fmt.num(f.rate_estimate())]
			"services":
				n = maxi(1, mini(f.services_max() - f.services, f.services_affordable(s.money) if n_want < 0 else n_want))
				cost = f.services_cost(n)
				(c.lv as Label).text = str(f.services)
				var nl := f.named_level(f.services + 1)
				b.text = ("CONSTRUIRE\n%s" if not nl.is_empty() and n == 1 else "AMÉLIORER ×%d\n%s" % [n, "%s"]) % Fmt.money(cost)
				var nxt := ""
				for k in range(f.services + 1, f.services_max() + 1):
					if not f.named_level(k).is_empty():
						nxt = "niv. %d : %s" % [k, String(f.named_level(k).name)]
						break
				pay.text = "Escale ×%s · niv. %d/%d%s" % [Fmt.num(f.ticket()), f.services, f.services_max(), (" · " + nxt) if nxt != "" else ""]
				if not nl.is_empty():
					(c.eff as Label).text = "%s — %s" % [String(nl.name), String(nl.get("text", ""))]
			_:
				cost = float(f.building_def(id).get("cost", 0.0))
				b.text = ("SIGNER\n%s" if id == "concession" else "CONSTRUIRE\n%s") % Fmt.money(cost)
				pay.text = "La Crique est à toi : de l'autre côté du cap, le port à conteneurs." if id == "concession" else ""
		b.disabled = cost > s.money
		if b.disabled:
			b.text = "Il manque\n%s" % Fmt.money(cost - s.money)


func _buy_fish(id: String, quiet: bool = false) -> bool:
	var s := sim()
	var f := s.fishing
	var n: int = MULTS[mult_index]
	var ok := false
	match id:
		"places":
			ok = s.buy_fish_places(1 if f.places <= 0 else n)
		"services":
			ok = s.buy_fish_services(n)
		_:
			ok = s.buy_fish_building(id)
	if not ok:
		if not quiet:
			Sfx.play("bad")
		return false
	_burst_n += 1
	if id == "concession":
		Sfx.play("milestone")
	elif not quiet or _burst_n % 3 == 0:
		Sfx.play("buy", 0.0, mini(12, int(_burst_n / 3)) if quiet else 0)
	if Hud.main != null:
		Hud.main.flash_money()
		var r := Hud.main.diorama.fishing_view.focus_of(id) if Hud.main.diorama != null else Rect2()
		if r.has_area() and not quiet:
			Hud.main.frame_point(Vector3(r.get_center().x, 0, r.get_center().y))
	var card := _card_for("fish", id)
	if not card.is_empty():
		Fx.pop(card.root, 1.02 if quiet else 1.04)
		if not quiet:
			Fx.reward(card.buy, "✓" if id != "places" and id != "services" else "Niv. %d" % (f.places if id == "places" else f.services), UI.MONEY)
	if id == "places" or id == "services":
		refresh()
	else:
		request_rebuild()
	return true
