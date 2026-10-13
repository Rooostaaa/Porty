class_name UpgradesSheet
extends Sheet
## Améliorations : cartes de départements (niveau, effet → suivant, palier, achat ×1/×10/×100/max) et licences de cargaison.

const MULTS := [1, 10, 100, -1]

static var mult_index: int = 0
var focus_dept: String = ""
var cards: Array[Dictionary] = []
var mult_btn: Button
var _gain_cache: Dictionary = {}     # « d:cranes:10 » / « c:2:1 » -> gain de revenu estimé (par seconde)
var _gain_base := -1.0               # revenu estimé sans achat, commun à toutes les cartes
var _gain_at := 0                    # instant (ms) du dernier calcul
var _burst_n := 0                    # achats réussis (pour ne jouer qu'un son sur 3 pendant un appui long)


func _init(dept: String = "") -> void:
	super._init("Améliorations", ["Départements", "Cargaisons"] as Array[String])
	focus_dept = dept


func _ready() -> void:
	super._ready()
	mult_btn = UI.button("", UI.AMBER, 34, 96)
	mult_btn.custom_minimum_size.x = 170
	mult_btn.pressed.connect(_cycle_mult)
	header_extra.add_child(mult_btn)
	_update_mult()
	if focus_dept != "":
		await get_tree().process_frame
		for c in cards:
			if c.get("dept", "") == focus_dept:
				scroll.ensure_control_visible(c.root)


func _cycle_mult() -> void:
	mult_index = (mult_index + 1) % MULTS.size()
	_update_mult()
	refresh()
	Sfx.play("click")


func _update_mult() -> void:
	var m: int = MULTS[mult_index]
	mult_btn.text = "MAX" if m < 0 else "×%d" % m


func build() -> void:
	cards.clear()
	if tab == 0:
		var hint := UI.wrap_label("Le département qui limite le flux porte une pastille rouge. Touche un effet pour voir « pourquoi ».", 28)
		content.add_child(hint)
		for d in PortSim.DEPTS:
			_dept_card(d)
	else:
		content.add_child(UI.wrap_label("Les licences augmentent la valeur de chaque EVP traité. Chaque palier du port relève leur niveau maximal.", 28))
		for ci in PortSim.NCARGO:
			_cargo_card(ci)


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
	var eff := Button.new()
	eff.flat = true
	eff.alignment = HORIZONTAL_ALIGNMENT_LEFT
	eff.add_theme_font_size_override("font_size", 32)
	eff.add_theme_color_override("font_color", UI.TEXT)
	eff.add_theme_color_override("font_hover_color", UI.VIOLET)
	eff.add_theme_color_override("font_pressed_color", UI.VIOLET)
	eff.focus_mode = Control.FOCUS_NONE
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART     # « Se débloque avec … » : sans retour à la ligne, la carte élargit toute la liste
	eff.pressed.connect(func() -> void: Hud.main.show_breakdown(String(def.stat_label), Info.dept_stat_name(d)))
	mid.add_child(eff)
	var det := UI.label("", 26, UI.MUTED)
	mid.add_child(det)
	var pay := UI.label("", 26, UI.MONEY)
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
	var eff := Button.new()
	eff.flat = true
	eff.alignment = HORIZONTAL_ALIGNMENT_LEFT
	eff.add_theme_font_size_override("font_size", 32)
	eff.add_theme_color_override("font_color", UI.TEXT)
	eff.focus_mode = Control.FOCUS_NONE
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eff.pressed.connect(func() -> void: Hud.main.show_breakdown("Valeur " + String(def.short), "value", ci))
	mid.add_child(eff)
	var det := UI.wrap_label(String(def.desc), 26)
	mid.add_child(det)
	var pay := UI.label("", 26, UI.MONEY)
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
	var b := UI.button("i", UI.INFO, 30, 56)
	b.custom_minimum_size = Vector2(56, 56)
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
	return Hud.main.show_popup("%s — étapes" % String(def.name), body, Info.CARGO_ICON[def.id] if ci >= 0 else Info.DEPT_ICON[d])


## Appui bref : un achat. Appui long : achats en rafale qui accélèrent, un seul effet à la fin.
func _hold(b: Button, single: Callable, again: Callable) -> void:
	var h := HoldRepeat.attach(b, single, func(_n: int) -> bool: return again.call())
	h.burst_ended.connect(func(n: int) -> void:
		if n > 0 and is_instance_valid(b):
			Fx.reward(b, "+%d niveaux" % n if n > 1 else "", UI.MONEY))


func _n_for(max_fn: Callable) -> int:
	var m: int = MULTS[mult_index]
	if m > 0:
		return m
	return maxi(1, max_fn.call())


## Gain de revenu d'un achat. Chaque estimation rejoue l'analyse du goulot : on les recalcule une fois par seconde
## (et après un achat) au lieu de 5 fois, avec une seule estimation de référence pour toutes les cartes.
func _gain_for(key: String, dept: String, n: int, cargo_i: int = -1) -> float:
	var now := Time.get_ticks_msec()
	if now - _gain_at > 1000:
		_gain_cache.clear()
		_gain_base = -1.0
		_gain_at = now
	if not _gain_cache.has(key):
		var s := sim()
		if _gain_base < 0.0:
			_gain_base = s.income_estimate_with("harbor", 0)
		_gain_cache[key] = s.upgrade_gain(dept, n, cargo_i, _gain_base)
	return float(_gain_cache[key])


## Texte de rentabilité : gain de revenu et temps pour rentabiliser l'achat.
func _payback(gain: float, cost: float) -> Dictionary:
	if gain * 60.0 < 0.05:
		return {"text": "Aucun gain immédiat : ce n'est pas le goulot.", "secs": INF}
	var secs := cost / gain
	return {"text": "+%s/min · rentabilisé en %s" % [Fmt.money(gain * 60.0), Fmt.duration(secs)], "secs": secs}


func refresh() -> void:
	var s := sim()
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
			(c.eff as Button).text = "%s  →  %s" % [Info.dept_effect(s, d), Info.dept_effect(s, d, n)]
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
			b.text = "AMÉLIORER ×%d\n%s" % [n, Fmt.money(cost)]
			b.disabled = cost > s.money
			(c.dot as Label).visible = s.analysis.get("dept", "") == d
			var pb := _payback(_gain_for("d:%s:%d" % [d, n], d, n), cost)
			(c.pay as Label).text = String(pb.text)
			(c.pay as Label).add_theme_color_override("font_color", UI.MONEY if float(pb.secs) < INF else UI.MUTED)
			if float(pb.secs) < best_secs:
				best_secs = float(pb.secs)
				best_card = c
		else:
			var ci: int = c.cargo
			var cid: String = s.db.cargo[ci].id
			var b2: Button = c.buy
			(c.lv as Label).text = str(s.licences[ci])
			_stage_text(c, s.db.cargo[ci], s.licences[ci])
			if _locked(c, "licences"):
				continue
			if s.unlocked[ci] == 0:
				(c.eff as Button).text = "Débloqué par : " + Info.building_name_for_cargo(s, cid)
				b2.text = "Verrouillé"
				b2.disabled = true
				(c.bar as RoundBar).value = 0.0
				(c.bar as RoundBar).text = ""
				continue
			var room := s.licence_room(ci)
			var lv2: int = s.licences[ci]
			if room <= 0:
				# plafond du palier : c'est le palier suivant du port qui le relève
				(c.eff as Button).text = "%s/EVP" % Fmt.money(Info.cargo_value(s, ci))
				(c.bar as RoundBar).value = 1.0
				(c.bar as RoundBar).text = "Plafond du palier T%d : niveau %d" % [s.tier, lv2]
				b2.text = "PLAFOND\nniv. %d" % lv2
				b2.disabled = true
				(c.pay as Label).text = "Le palier suivant du port relève le plafond."
				(c.pay as Label).add_theme_color_override("font_color", UI.MUTED)
				continue
			var n2 := mini(room, _n_for(s.licence_max_affordable.bind(ci)))
			var cost2 := s.licence_cost(ci, n2)
			(c.eff as Button).text = "%s/EVP  →  %s" % [Fmt.money(Info.cargo_value(s, ci)), Fmt.money(Info.cargo_value(s, ci, n2))]
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
			b2.text = "LICENCE ×%d\n%s" % [n2, Fmt.money(cost2)]
			b2.disabled = cost2 > s.money
			var pb2 := _payback(_gain_for("c:%d:%d" % [ci, n2], "", n2, ci), cost2)
			(c.pay as Label).text = String(pb2.text)
			(c.pay as Label).add_theme_color_override("font_color", UI.MONEY if float(pb2.secs) < INF else UI.MUTED)
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
	(c.eff as Button).text = "Se débloque " + s.unlock_text(feature_id)
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
	if not s.buy_dept(d, n):
		if not quiet:
			Sfx.play("bad")
		return false
	_burst_n += 1
	Hud.main.flash_money()
	var card := _card_for("dept", d)
	var lv1: int = s.levels[d]
	var milestone := s.dept_milestone_mult(lv1) > s.dept_milestone_mult(lv0)
	if milestone:
		Sfx.play("tier")
		Hud.main.toast("Palier ×%d : %s niveau %d !" % [int(s.db.cfg("dept_milestone_mult")), s.db.dept_by_id[d].name, lv1], "good")
		Hud.main.world_shake()
	elif not quiet or _burst_n % 3 == 0:
		Sfx.play("buy")
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
	if not s.buy_licence(ci, n):
		if not quiet:
			Sfx.play("bad")
		return false
	_burst_n += 1
	var lv1: int = s.licences[ci]
	var ms: Array = s.db.cfg("licence_milestones")
	var m0 := Progression.step_mult(lv0, ms)
	var m1 := Progression.step_mult(lv1, ms)
	var milestone := m1 > m0
	if milestone:
		Sfx.play("tier")
		Hud.main.toast("Palier de licence %s : %s niveau %d !" % [Fmt.mult(m1 / m0), s.db.cargo[ci].name, lv1], "good")
	elif not quiet or _burst_n % 3 == 0:
		Sfx.play("buy")
	var card := _card_for("cargo", ci)
	if not card.is_empty():
		Fx.pop(card.root, 1.02 if quiet else 1.04)
		if milestone or not quiet:
			Fx.reward(card.buy, "Palier %s !" % Fmt.mult(m1 / m0) if milestone else "Licence niv. %d" % lv1, UI.AMBER if milestone else UI.MONEY, milestone)
	refresh()
	return true
