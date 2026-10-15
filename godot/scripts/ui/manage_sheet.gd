class_name ManageSheet
extends Sheet
## Gestion : Bâtiments (zones, l'une après l'autre), Statistiques, Responsables, Port (paliers, politique, tarifs).

var rows: Array[Dictionary] = []
var stat_bars: Dictionary = {}
var dept_lines: Dictionary = {}
var tier_box: VBoxContainer
var policy_btns: Array[Button] = []
var tariff_label: Label
var tariff_slider: HSlider
var _prestige_confirm := false
var _sig := ""
var cargo_lines: Dictionary = {}       # cargaison -> libellé du panier
var _tags_at := -10.0                  # étiquettes « maillon » recalculées une fois par seconde (estimations coûteuses)


func _init(start_tab: int = 0) -> void:
	super._init("Gestion", ["Bâtiments", "Stats", "Responsables", "Port"] as Array[String])
	tab = start_tab


func build() -> void:
	rows.clear()
	stat_bars.clear()
	dept_lines.clear()
	policy_btns.clear()
	_sig = _signature()
	match tab:
		0:
			_build_buildings()
		1:
			_build_stats()
		2:
			_build_managers()
		3:
			_build_port()


func _signature() -> String:
	var s := sim()
	return "%d|%d|%d|%d" % [s.tier, s.built.size(), s.managers_count(), s.features.size()]


# --- Bâtiments ------------------------------------------------------------------

var built_folded := true               # « 7 construits ▸ » : les bâtiments construits, repliés en bas de la liste
var built_fold_btn: Button


## Bâtiments triés « disponible › bloqué › construit » ; les construits repliés en une ligne « 7 construits ▸ » (revue D-UI :
## la liste commençait par 7 cartes CONSTRUIT).
func _build_buildings() -> void:
	var s := sim()
	help("man_build", "Chaque construction agrandit le port. Elles se débloquent l'une après l'autre.")
	var avail: Array = []
	var later: Array = []
	var built_l: Array = []
	for b in s.db.buildings:
		var st := s.building_state(b.id)
		if st == "available":
			avail.append(b)
		elif st == "built":
			built_l.append(b)
		else:
			later.append(b)
	for b in avail + later:
		_building_card(b)
	built_fold_btn = null
	if not built_l.is_empty():
		var fold := UI.button("%d construit%s  %s" % [built_l.size(), "s" if built_l.size() > 1 else "", "▸" if built_folded else "▾"], UI.INDIGO_DARK, 30, 96)
		fold.pressed.connect(func() -> void:
			built_folded = not built_folded
			Sfx.play("click")
			rebuild())
		content.add_child(fold)
		built_fold_btn = fold
		if not built_folded:
			for b in built_l:
				_building_card(b)


func _building_card(b: Dictionary) -> void:
	var s := sim()
	var c := UI.card()
	content.add_child(c)
	var row := UI.hbox(20)
	c.add_child(row)
	var st := s.building_state(b.id)
	row.add_child(UI.icon_disc(Info.building_icon(b), UI.MONEY if st == "built" else (UI.VIOLET if st == "available" else UI.GREY), 100))
	var mid := UI.vbox(4)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	# charte : gris = impossible (bloqué), violet = à faire ; le rouge reste aux problèmes
	var nl := UI.label(String(b.name), 36, UI.MUTED if st == "locked" or st == "tier" else UI.VIOLET)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size.x = 300
	mid.add_child(nl)
	var why := String(b.desc)
	if st == "locked":
		why = "Construis d'abord le précédent."
	elif st == "tier":
		why = "Palier T%d requis." % int(b.tier)
	mid.add_child(UI.wrap_label(why, 26))
	var btn := UI.button("", UI.MONEY, 28, 110)
	btn.custom_minimum_size.x = 220
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(btn)
	if st == "built":
		btn.text = "CONSTRUIT ✓"
		btn.disabled = true
		UI.style_done(btn)
	else:
		btn.pressed.connect(_build.bind(String(b.id)))
	rows.append({"id": b.id, "btn": btn, "cost": float(b.cost), "state": st})
	_building_btn(rows.back(), s)


## Bouton d'un bâtiment : CONSTRUIRE et son prix, « Il manque … » quand il est gris faute d'argent.
func _building_btn(r: Dictionary, s: PortSim) -> void:
	var btn: Button = r.btn
	var st := String(r.state)
	if st == "built":
		return
	var cost := float(r.cost)
	btn.disabled = st != "available" or s.money < cost
	if st == "available" and s.money < cost:
		btn.text = "Il manque\n" + Fmt.money(cost - s.money)
	else:
		btn.text = "CONSTRUIRE\n" + Fmt.money(cost)


func _build(bid: String) -> void:
	var btn: Button = null
	for r in rows:
		if r.get("id", "") == bid:
			btn = r.btn
	if sim().build(bid):
		Sfx.play("build")
		Hud.main.world_shake()
		if btn != null:
			Fx.reward(btn, "Construit !", UI.MONEY, true)
	else:
		Sfx.play("bad")
	rebuild()


# --- Statistiques -------------------------------------------------------------

func _stat_bar(key: String, title: String, col: Color) -> void:
	var v := UI.vbox(4)
	var h := UI.hbox(10)
	h.add_child(UI.label(title, 30, UI.TEXT))
	h.add_child(UI.spacer(0, 0, true))
	var val := UI.label("", 30, col, true)
	h.add_child(val)
	v.add_child(h)
	var bar := RoundBar.new(30)
	bar.color = col
	v.add_child(bar)
	stat_bars[key] = {"bar": bar, "val": val}
	content.get_child(content.get_child_count() - 1).get_child(0).add_child(v)


func _build_stats() -> void:
	var c := UI.card()
	content.add_child(c)
	c.add_child(UI.vbox(18))
	_stat_bar("gain", "Gain moyen par escale", UI.MONEY)
	_stat_bar("per_evp", "Gain moyen par EVP", UI.MONEY)
	_stat_bar("serving", "Navires en cours de service", UI.INFO)
	_stat_bar("capacity", "Capacité de traitement", UI.INFO)
	_stat_bar("yard", "Remplissage du parc", UI.BAD)
	_stat_bar("gate", "Voies de gate saturées", UI.BAD)
	_stat_bar("queue", "File moyenne en rade", UI.INFO)
	_stat_bar("wait", "Attente moyenne en rade", UI.BAD)
	_stat_bar("truck", "Passage d'un camion", UI.BAD)
	_stat_bar("compliance", "Taux de conformité", UI.MONEY)
	var c2 := UI.card()
	content.add_child(c2)
	var v2 := UI.vbox(14)
	c2.add_child(v2)
	v2.add_child(UI.label("Départements", 40, UI.VIOLET))
	for d in PortSim.DEPTS:
		var h := UI.hbox(14)
		var b := UI.badge("1", Info.DEPT_COLOR[d], 28)
		b.custom_minimum_size.x = 76
		h.add_child(b)
		var n := UI.label(String(sim().db.dept_by_id[d].name), 30)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		var val := UI.label("", 28, UI.MUTED)
		h.add_child(val)
		v2.add_child(h)
		var tag := UI.label("", 24, UI.MONEY)
		tag.visible = false
		v2.add_child(tag)
		dept_lines[d] = {"badge": b.get_child(0), "val": val, "tag": tag}
	# panier du port : ce que rapporte un EVP selon sa cargaison, et la part de chacune
	var c4 := UI.card()
	content.add_child(c4)
	var v4 := UI.vbox(10)
	c4.add_child(v4)
	v4.add_child(UI.label("Panier du port", 40, UI.VIOLET))
	v4.add_child(UI.wrap_label("Ce que rapporte un EVP selon sa cargaison (licences et palier compris), et sa part dans les déchargements.", 26))
	cargo_lines.clear()
	for ci in PortSim.NCARGO:
		var hc := UI.hbox(12)
		var cd: Dictionary = sim().db.cargo[ci]
		hc.add_child(UI.icon_disc(Info.CARGO_ICON[cd.id], Info.CARGO_COLOR[cd.id], 56))
		var nl := UI.label(String(cd.name), 28)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hc.add_child(nl)
		var vl := UI.label("", 28, UI.MONEY, true)
		hc.add_child(vl)
		v4.add_child(hc)
		cargo_lines[ci] = {"row": hc, "val": vl}
	var c3 := UI.card()
	content.add_child(c3)
	var v3 := UI.vbox(10)
	c3.add_child(v3)
	v3.add_child(UI.label("Revenus par source", 40, UI.VIOLET))
	v3.add_child(UI.wrap_label("Moyenne de la dernière minute.", 26))
	var src := UI.label("", 28, UI.TEXT)
	v3.add_child(src)
	stat_bars["sources"] = {"label": src}


## « Maillon le plus rentable » : le département dont un niveau se rembourse le plus vite ;
## « Maillon le plus faible » : le goulot actuel.
func _refresh_tags(s: PortSim) -> void:
	var base := s.income_estimate_with("harbor", 0)
	var best := ""
	var best_pb := INF
	for d in dept_lines:
		if not s.feature("dept_" + d):
			continue
		var g := s.upgrade_gain(d, 1, -1, base)
		if g > 0.0 and s.dept_cost(d, 1) / g < best_pb:
			best_pb = s.dept_cost(d, 1) / g
			best = d
	var weak: String = s.analysis.get("dept", "")
	for d in dept_lines:
		var tag: Label = dept_lines[d].tag
		if d == weak:
			tag.text = "▼ Maillon le plus faible : c'est lui qui limite le flux"
			tag.add_theme_color_override("font_color", UI.BAD)
		elif d == best:
			tag.text = "★ Maillon le plus rentable : un niveau se rembourse en %s" % Fmt.duration(best_pb)
			tag.add_theme_color_override("font_color", UI.MONEY)
		tag.visible = d == weak or d == best


func _set_bar(key: String, value: float, text: String) -> void:
	if stat_bars.has(key):
		(stat_bars[key].bar as RoundBar).value = value
		(stat_bars[key].val as Label).text = text


func _refresh_stats() -> void:
	var s := sim()
	var ships_min := s.ships_per_hour() / 60.0
	var gain := s.income_per_min() / maxf(0.01, ships_min)
	_set_bar("gain", clampf(gain / maxf(1.0, gain * 1.5), 0, 1), Fmt.money(gain))
	var serving := 0
	for b in s.berths:
		if int(b.ship) >= 0:
			serving += 1
	_set_bar("serving", float(serving) / float(s.berths.size()), "%d / %d" % [serving, s.berths.size()])
	var cap := s.sustainable_flow() * 60.0
	_set_bar("capacity", clampf(s.evp_per_min() / maxf(1.0, cap), 0, 1), Fmt.num(cap) + " EVP/min")
	_set_bar("yard", s.yard_fill(), Fmt.pct(s.yard_fill()))
	_set_bar("gate", float(s.trucks_waiting()) / float(s.db.cfg("truck_queue_max")), "%d camions" % s.trucks_waiting())
	_set_bar("queue", float(s.waiting_ships()) / float(s.rade_places()), "%d / %d" % [s.waiting_ships(), s.rade_places()])
	_set_bar("wait", clampf(s.stat_rade_wait / 60.0, 0, 1), "%d s" % roundi(s.stat_rade_wait))
	_set_bar("truck", clampf(s.stat_truck_wait / 30.0, 0, 1), "%d s" % roundi(s.stat_truck_wait))
	var comp := s.counter("compliant") / maxf(1.0, s.counter("compliant") + s.counter("seizures") + s.counter("incidents"))
	var ncomp := s.counter("compliant") + s.counter("seizures") + s.counter("incidents")
	var ctxt := Fmt.pct(comp) if ncomp > 0.0 else "—"
	_set_bar("compliance", comp, "%s · %d saisies · %d incidents" % [ctxt, s.counter("seizures"), s.counter("incidents")])
	var caps: Dictionary = s.analysis.get("caps", {})
	var map := {"harbor": "traffic", "berths": "berth_cycle", "customs": "inspection", "cranes": "berth_cycle", "yard_ops": "transfer", "gate": "gate"}
	for d in dept_lines:
		(dept_lines[d].badge as Label).text = str(s.levels[d])
		(dept_lines[d].val as Label).text = "%s · cap. %s/min" % [Info.dept_effect(s, d), Fmt.num(float(caps.get(map[d], 0.0)) * 60.0)]
	# gain moyen par EVP (droits de gate compris) et panier par cargaison
	var per_evp := s.avg_value_per_evp() * (1.0 + float(s.db.cfg("gate_fee_ratio")))
	_set_bar("per_evp", 1.0, Fmt.money(per_evp))
	var shares := s.cargo_shares()
	for ci in cargo_lines:
		var ok: bool = s.unlocked[ci] == 1 and shares[ci] > 0.0005
		(cargo_lines[ci].row as Control).modulate = Color.WHITE if ok else Color(1, 1, 1, 0.45)
		(cargo_lines[ci].val as Label).text = "%s/EVP · %s" % [Fmt.money(s.stat("value", ci)), Fmt.pct(shares[ci])] if ok \
			else ("—" if s.unlocked[ci] == 1 else "verrouillée")
	if s.time - _tags_at >= 1.0 or s.time < _tags_at:
		_tags_at = s.time
		_refresh_tags(s)
	if stat_bars.has("sources"):
		var names := Info.SOURCE_NAMES      # (lot E : « fees » et « services » distingués)
		var txt := ""
		for k in names:
			if s.last_income.has(k):
				txt += "%s : %s/s\n" % [names[k], Fmt.money(float(s.last_income[k]) / 60.0)]      # une seule unité de revenu : $/s
		(stat_bars.sources.label as Label).text = txt if txt != "" else "—"


# --- Responsables ---------------------------------------------------------------

func _build_managers() -> void:
	var s := sim()
	help("man_mgr", "Un responsable automatise son département (×2) et fait tourner le port hors-ligne.")
	var locked := not s.feature("managers")
	if locked:
		content.add_child(UI.wrap_label("Les responsables se présenteront " + s.unlock_text("managers") + ".", 30, UI.BAD))
	for d in PortSim.DEPTS:
		if not s.feature("dept_" + d):
			continue        # un responsable ne se présente qu'avec son service (chapitres)
		var m: Dictionary = s.db.dept_by_id[d].manager
		var c := UI.card()
		content.add_child(c)
		if locked:
			c.modulate = Color(1, 1, 1, 0.55)
		var row := UI.hbox(20)
		c.add_child(row)
		var portrait := PanelContainer.new()
		portrait.add_theme_stylebox_override("panel", UI.flat(Info.DEPT_COLOR[d], 60))
		portrait.custom_minimum_size = Vector2(120, 120)
		var initials := ""
		for w in String(m.name).replace("«", "").replace("»", "").split(" ", false):
			if w.length() > 1 and w[0] == w[0].to_upper() and initials.length() < 2 and w != "Capitaine" and w != "Inspecteur" and w != "Ingénieur" and w != "Dr":
				initials += w[0]
		var il := UI.label(initials, 48, Color.WHITE, true)
		il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		il.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		portrait.add_child(il)
		row.add_child(portrait)
		var mid := UI.vbox(4)
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(mid)
		mid.add_child(UI.label(String(m.name), 34, UI.VIOLET))
		mid.add_child(UI.label("%s · %s" % [m.title, s.db.dept_by_id[d].name], 26, UI.MUTED))
		mid.add_child(UI.wrap_label(String(m.perk), 28, UI.TEXT))
		var col := UI.vbox(8)
		row.add_child(col)
		if s.managers[d]:
			var ok := UI.button("EMBAUCHÉ ✓", UI.MONEY, 30, 100)
			ok.disabled = true
			UI.style_done(ok)
			ok.custom_minimum_size.x = 220
			col.add_child(ok)
		else:
			var b := UI.button("EMBAUCHER\n" + Fmt.money(float(m.cost)), UI.MONEY, 28, 100)
			b.custom_minimum_size.x = 220
			b.disabled = not s.manager_available(d) or s.money < float(m.cost)
			if not s.manager_available(d):
				b.text = "Palier T%d" % int(m.tier)
			elif not s.manager_revealed(d) and not locked:
				b.text = "Niveau %d
requis" % int(s.db.cfg("manager_reveal_level", 10))
				b.disabled = true
			if locked:
				b.text = "Verrouillé"
				b.disabled = true
			b.pressed.connect(_hire.bind(d, false))
			col.add_child(b)
			var ba := UI.button("%d Ambre" % int(m.amber), UI.AMBER, 26, 96)
			ba.add_theme_color_override("font_color", UI.TEXT)
			ba.custom_minimum_size.x = 220
			ba.disabled = s.amber < int(m.amber)
			ba.disabled = ba.disabled or locked or not s.manager_revealed(d)
			ba.pressed.connect(_hire.bind(d, true))
			col.add_child(ba)
			rows.append({"dept": d, "btn": b, "abtn": ba, "cost": float(m.cost), "amber": int(m.amber)})


func _hire(d: String, amber: bool) -> void:
	var btn: Button = null
	for r in rows:
		if r.get("dept", "") == d:
			btn = r.abtn if amber else r.btn
	if sim().hire_manager(d, amber):
		Sfx.play("hire")
		if btn != null:
			Fx.reward(btn, "Embauché !", UI.MONEY, true)
	else:
		Sfx.play("bad")
	rebuild()


# --- Port -----------------------------------------------------------------------

func _build_port() -> void:
	var s := sim()
	var c := UI.card()
	content.add_child(c)
	tier_box = UI.vbox(12)
	c.add_child(tier_box)
	var td := s.db.tier_def(s.tier)
	tier_box.add_child(UI.label("Palier T%d — %s" % [s.tier, td.name], 42, UI.VIOLET))
	tier_box.add_child(UI.wrap_label(String(td.story), 28))
	var nt := s.db.tier_def(s.tier + 1)
	if not nt.is_empty() and not s.finished:
		tier_box.add_child(UI.label("Prochain : %s" % nt.name, 34, UI.TEXT))
		var checks := s.tier_check()
		for i in checks.size():
			var chk: Dictionary = checks[i]
			var h := UI.hbox(12)
			var ic := UI.icon("check" if chk.ok else "clock", 44, UI.MONEY if chk.ok else UI.MUTED)
			h.add_child(ic)
			var cl := UI.label(_check_text(chk), 30, UI.TEXT if chk.ok else UI.MUTED)
			h.add_child(cl)
			tier_box.add_child(h)
			rows.append({"chk_i": i, "chk_icon": ic, "chk_label": cl})   # mis à jour en direct (EVP, argent, étoiles)
		var b := UI.button("PASSER AU PALIER SUIVANT", UI.MONEY, 34, 110)
		b.disabled = not s.can_tier_up()
		b.pressed.connect(_tier_up)
		tier_box.add_child(b)
		rows.append({"tier_btn": b})
	elif s.finished:
		tier_box.add_child(UI.label("Concession nationale obtenue !", 34, UI.MONEY))
	# prestige : nouvelle concession
	if s.tier >= 3 or s.prestiges > 0:
		_build_prestige_card()
	_build_policy_card()


func _build_prestige_card() -> void:
	var cp := UI.card(Color("#FFF8E6"))
	content.add_child(cp)
	var vp := UI.vbox(12)
	cp.add_child(vp)
	vp.add_child(UI.label("Nouvelle concession ✦", 40, UI.VIOLET))
	var ptxt := UI.wrap_label("", 28, UI.TEXT)
	vp.add_child(ptxt)
	var pbtn := UI.button("", UI.MONEY, 30, 110)
	pbtn.pressed.connect(_prestige)
	vp.add_child(pbtn)
	rows.append({"prestige_txt": ptxt, "prestige_btn": pbtn})
	_prestige_confirm = false


func _build_policy_card() -> void:
	var s := sim()
	# politique de contrôle
	if not s.customs_open:
		var cl := UI.card()
		content.add_child(cl)
		var vl := UI.vbox(8)
		cl.add_child(vl)
		vl.add_child(UI.label("Politique de contrôle (douane)", 38, UI.MUTED))
		vl.add_child(UI.wrap_label("Il n'y a pas encore de douaniers : construis le « Bureau de douane » (Bâtiments).", 28))
		_build_tariffs()
		return
	var c2 := UI.card()
	content.add_child(c2)
	var v2 := UI.vbox(12)
	c2.add_child(v2)
	v2.add_child(UI.label("Politique de contrôle (douane)", 38, UI.VIOLET))
	v2.add_child(UI.wrap_label("La douane est l'État : tu finances sa capacité et tu choisis le niveau de contrôle. Plus on contrôle, moins on risque, plus on attend.", 26))
	var prow := UI.hbox(8)
	v2.add_child(prow)
	var pols: Array = s.db.cfg("policies")
	for i in pols.size():
		var pb := UI.button(String(pols[i].name), UI.INDIGO_DARK, 26, 90)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.pressed.connect(_set_policy.bind(i))
		prow.add_child(pb)
		policy_btns.append(pb)
	var pdesc := UI.wrap_label("", 28, UI.TEXT)
	v2.add_child(pdesc)
	rows.append({"policy_desc": pdesc})
	_build_tariffs()


func _build_tariffs() -> void:
	var s := sim()
	# tarifs
	var c3 := UI.card()
	content.add_child(c3)
	var v3 := UI.vbox(12)
	c3.add_child(v3)
	v3.add_child(UI.label("Tarifs", 38, UI.VIOLET))
	tariff_label = UI.wrap_label("", 28, UI.TEXT)
	v3.add_child(tariff_label)
	tariff_slider = HSlider.new()
	tariff_slider.min_value = float(s.db.cfg("tariff_min")) * 100.0
	tariff_slider.max_value = float(s.db.cfg("tariff_max")) * 100.0
	tariff_slider.step = 5
	tariff_slider.value = s.tariff * 100.0
	tariff_slider.custom_minimum_size.y = 90
	tariff_slider.add_theme_icon_override("grabber", UI.circle_tex(56, UI.VIOLET))
	tariff_slider.add_theme_icon_override("grabber_highlight", UI.circle_tex(60, UI.VIOLET.lightened(0.1)))
	tariff_slider.add_theme_stylebox_override("slider", UI.flat(UI.GREY, 12, 0, 12))
	tariff_slider.add_theme_stylebox_override("grabber_area", UI.flat(UI.VIOLET, 12, 0, 12))
	tariff_slider.add_theme_stylebox_override("grabber_area_highlight", UI.flat(UI.VIOLET, 12, 0, 12))
	tariff_slider.value_changed.connect(func(v: float) -> void: sim().set_tariff(v / 100.0))
	v3.add_child(tariff_slider)
	# les armateurs (présence, relations, lignes) sont dans l'écran Commerce


## Texte d'une condition de palier (« EVP traités : 1,2K / 4K »).
func _check_text(chk: Dictionary) -> String:
	if chk.get("building", false):
		return "Construire : " + String(chk.label)
	if chk.get("money", false):
		return "Coût : %s" % Fmt.money(float(chk.need))
	if chk.label == "Réputation":
		# lot E : avant sa révélation, la Réputation (★) n'est pas citée — c'est la satisfaction des navires qu'elle mesure
		if not sim().feature("stars"):
			return "Navires satisfaits : %d %% / %d %%" % [roundi((float(chk.have) - 1.0) * 25.0), roundi((float(chk.need) - 1.0) * 25.0)]
		return "Réputation : %s / %s ★" % [("%.1f" % float(chk.have)).replace(".", ","), ("%.1f" % float(chk.need)).replace(".", ",")]
	return "%s : %s / %s" % [chk.label, Fmt.num(float(chk.have)), Fmt.num(float(chk.need))]


func _tier_up() -> void:
	# la cérémonie du palier (gerbe, caméra, jingle, puis la fenêtre) part du signal tier_changed (Hud._on_tier)
	if sim().tier_up():
		close()
		return
	Sfx.play("bad")
	rebuild()


func _prestige() -> void:
	var s := sim()
	if not s.can_prestige():
		Sfx.play("bad")
		return
	if not _prestige_confirm:
		refresh()      # une reconstruction en attente (fonction révélée entre-temps) effacerait la confirmation
		_prestige_confirm = true
		Sfx.play("bad")
		refresh()
		return
	if GameState.prestige():
		var ns := GameState.sim
		close()
		Hud.main.world_shake()
		# cérémonie (gerbe plein écran, jingle du prestige), puis la fenêtre (lot D-UI)
		var title := "Concession n°%d ouverte !" % (ns.prestiges + 1)
		var body: Array = [
			UI.label("Renom ✦ %d" % ns.renown, 52, UI.AMBER, true),
			UI.wrap_label("Revenus ×%s, débit ×%s, escales plus courtes. +%d Ambre. Le port repart de zéro : fais mieux, plus vite." % [
				("%.2f" % ns.renown_mult()).replace(".", ","), ("%.2f" % ns.renown_throughput_mult()).replace(".", ","),
				int(ns.db.cfg("renown").amber)], 30, UI.TEXT)]
		Hud.main.ceremony(title, "Renom ✦ %d" % ns.renown, UI.AMBER, "prestige", CameraRig.START, func() -> void:
			Hud.main.show_popup(title, body, "trophy"))


func _set_policy(i: int) -> void:
	sim().set_policy(i)
	Sfx.play("click")
	refresh()


func _refresh_port() -> void:
	var s := sim()
	for i in policy_btns.size():
		UI.style_button(policy_btns[i], UI.VIOLET if i == s.policy else UI.INDIGO_DARK)
	var checks := s.tier_check()
	for r in rows:
		if r.has("chk_i"):
			# les conditions du palier suivant avançaient à l'écran du joueur sans que la liste bouge (bouton actif, liste « en attente »)
			if int(r.chk_i) < checks.size():
				var chk: Dictionary = checks[int(r.chk_i)]
				(r.chk_label as Label).text = _check_text(chk)
				(r.chk_label as Label).add_theme_color_override("font_color", UI.TEXT if chk.ok else UI.MUTED)
				var ic: TextureRect = r.chk_icon
				ic.texture = UI.icon_tex("check" if chk.ok else "clock")
				ic.modulate = UI.MONEY if chk.ok else UI.MUTED
		if r.has("prestige_txt"):
			var rn: Dictionary = s.db.cfg("renown")
			var now := "Concession n°%d · Renom ✦ %d : revenus ×%s, débit ×%s, escales plus courtes." % [s.prestiges + 1, s.renown,
				("%.2f" % s.renown_mult()).replace(".", ","), ("%.2f" % s.renown_throughput_mult()).replace(".", ",")]
			var pbtn: Button = r.prestige_btn
			if s.can_prestige():
				var g := s.prestige_gain()
				(r.prestige_txt as Label).text = "%s\nRepartir maintenant : +%d Renom (→ ✦ %d). Bâtiments, niveaux et argent repartent de zéro ; " % [now, g, s.renown + g] \
					+ "tu gardes le Renom, l'Ambre (+%d) et les missions réclamées." % int(rn.amber)
				pbtn.text = "CONFIRMER : TOUT REPART DE ZÉRO" if _prestige_confirm else "OUVRIR LA CONCESSION N°%d  (+%d ✦)" % [s.prestiges + 2, g]
				pbtn.disabled = false
				UI.style_button(pbtn, UI.BAD if _prestige_confirm else UI.MONEY)
			else:
				var why := "Traite encore des EVP pour gagner au moins 1 point de Renom." if s.finished \
					else "Se débloque avec la Concession nationale (fin du palier T3). Plus tu traites d'EVP, plus tu gagnes de Renom."
				(r.prestige_txt as Label).text = "%s\n%s" % [now, why]
				pbtn.text = "VERROUILLÉ"
				pbtn.disabled = true
		if r.has("policy_desc"):
			var p: Dictionary = s.db.cfg("policies")[s.policy]
			(r.policy_desc as Label).text = "%s — %s inspecté(s), méthode : %s, détection ~%s." % [p.desc, Fmt.pct(float(p.fraction)), p.method, Fmt.pct(float(p.detect))]
		if r.has("tier_btn"):
			(r.tier_btn as Button).disabled = not s.can_tier_up()
	if tariff_label:
		var dm := pow(1.0 / s.tariff, float(s.db.cfg("tariff_demand_exp")))
		tariff_label.text = "%d %% du tarif de base : revenus ×%s, trafic ×%s." % [roundi(s.tariff * 100.0), ("%.2f" % s.tariff).replace(".", ","), ("%.2f" % dm).replace(".", ",")]


func refresh() -> void:
	var s := sim()
	if _signature() != _sig:
		request_rebuild()
		return
	match tab:
		0:
			for r in rows:
				if r.has("state"):
					_building_btn(r, s)
		1:
			_refresh_stats()
		2:
			for r in rows:
				if r.has("dept"):
					var off := not s.feature("managers")
					var b: Button = r.btn
					b.disabled = off or not s.manager_available(r.dept) or s.money < float(r.cost)
					if not off and s.manager_available(r.dept) and s.manager_revealed(r.dept):
						b.text = "EMBAUCHER\n" + Fmt.money(float(r.cost)) if not b.disabled else "Il manque\n" + Fmt.money(float(r.cost) - s.money)
					(r.abtn as Button).disabled = off or s.amber < int(r.amber)
		3:
			_refresh_port()
