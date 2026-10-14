class_name CommerceSheet
extends Sheet
## Commerce : faire venir des navires. Trafic (demande, campagnes, équipements), Armateurs (démarchage, lignes régulières),
## Contrats (accepter une offre : ses navires viennent plus souvent ; la tenir avant l'échéance).

const TAB_TRAFFIC := 0
const TAB_OWNERS := 1
const TAB_CONTRACTS := 2

var rows: Array[Dictionary] = []
var _sig := ""
var traffic_l: Label
var capacity_l: Label
var verdict_l: Label


func _init(start_tab: int = 0) -> void:
	super._init("Commerce", ["Trafic", "Armateurs", "Contrats"] as Array[String])
	tab = start_tab
	half = true          # feuille mi-hauteur au-dessus du port (lot D-UI) : on voit la rade et la capitainerie


func _ready() -> void:
	super._ready()
	if Hud.main != null and Hud.main.diorama != null:
		var d := Hud.main.diorama
		Hud.main.frame_point(d.call("rade_anchor") if d.has_method("rade_anchor") else Layout.anchor_pos(0))


func _signature() -> String:
	var s := sim()
	var ids: Array = [s.tier, s.built.size(), s.owners_on.size(), JSON.stringify(s.lines), s.line_offers.size(), s.features.size()]
	if tab == TAB_CONTRACTS:
		for c in s.contract_offers + s.contracts_active:
			# récompense et cible : elles sont revalorisées en place quand le port grandit (palier, rafraîchissement du jour)
			ids.append("%s:%d:%d" % [c.tpl, roundi(float(c.reward)), roundi(float(c.target))])
	return ",".join(ids)


func build() -> void:
	rows.clear()
	traffic_l = null
	_sig = _signature()
	match tab:
		TAB_TRAFFIC:
			_build_traffic()
		TAB_OWNERS:
			_build_owners()
		TAB_CONTRACTS:
			_build_contracts()


# --- Trafic -------------------------------------------------------------------

func _build_traffic() -> void:
	var s := sim()
	var c := UI.card()
	content.add_child(c)
	var v := UI.vbox(10)
	c.add_child(v)
	var h := UI.hbox(14)
	v.add_child(h)
	h.add_child(UI.icon_disc("ship", UI.INFO, 100))
	var mid := UI.vbox(2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(mid)
	traffic_l = UI.label("", 40, UI.VIOLET, true)
	mid.add_child(traffic_l)
	capacity_l = UI.label("", 28, UI.MUTED)
	mid.add_child(capacity_l)
	var why := UI.button("POURQUOI ?", UI.INFO, 26, 84)
	why.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	why.pressed.connect(func() -> void: Hud.main.show_breakdown("Trafic", "demand"))
	h.add_child(why)
	verdict_l = UI.wrap_label("", 28, UI.TEXT)
	v.add_child(verdict_l)
	# campagnes de démarchage
	content.add_child(UI.label("Démarchage", 40, UI.VIOLET))
	# (la consigne « lance-la quand tes quais ont de la marge » est déjà dans le verdict ci-dessus : pas de phrase en double)
	help("com_camp", "Une campagne fait venir plus de navires pendant quelques minutes, puis se recharge.")
	for cdef in Commerce.campaigns(s):
		_campaign_card(cdef)
	# équipements qui attirent du trafic
	content.add_child(UI.label("Équipements qui attirent", 40, UI.VIOLET))
	var c2 := UI.card()
	content.add_child(c2)
	var v2 := UI.vbox(8)
	c2.add_child(v2)
	for b in s.db.buildings:
		if not _attracts(b) or int(b.tier) > s.tier + 1:
			continue
		var st := s.building_state(b.id)
		var line := UI.hbox(10)
		line.add_child(UI.icon("check" if st == "built" else "lock", 40, UI.MONEY if st == "built" else UI.MUTED))
		var nl := UI.label(String(b.name), 28, UI.TEXT if st == "built" else UI.MUTED)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(nl)
		var tag := "construit" if st == "built" else ("palier T%d" % int(b.tier) if st == "tier" else Fmt.money(float(b.cost)))
		line.add_child(UI.label(tag, 26, UI.MONEY if st == "built" else UI.MUTED, true))
		v2.add_child(line)
	var go := UI.button("BÂTIMENTS", UI.INDIGO, 28, 90)
	go.pressed.connect(func() -> void:
		close()
		Hud.main.open_sheet(ManageSheet.new(0)))
	v2.add_child(go)


## Un bâtiment fait-il venir des navires (plus grands, d'autres armateurs, ou des services) ?
static func _attracts(b: Dictionary) -> bool:
	for e in b.effects:
		var t := String(e.type)
		if t == "berth_depth" or t == "customs_open" or (t == "stat_mult" and String(e.stat) == "demand"):
			return true
		if t == "add_berth" and int(e.depth) >= 4:
			return true
	return false


func _campaign_card(cdef: Dictionary) -> void:
	var s := sim()
	var c := UI.card()
	content.add_child(c)
	var row := UI.hbox(18)
	c.add_child(row)
	row.add_child(UI.icon_disc("horn", UI.ORANGE, 96))
	var mid := UI.vbox(4)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	mid.add_child(UI.label(String(cdef.name), 34, UI.VIOLET))
	var desc := String(cdef.desc)
	if not Commerce.campaign_available(s, cdef):
		var r := String(cdef.get("require", ""))
		desc = "Avec « %s » (Gestion → Bâtiments)." % s.db.building_by_id[r].name if r != "" else "Palier T%d requis." % int(cdef.get("tier", 1))
	mid.add_child(UI.wrap_label(desc, 26))
	var btn := UI.button("", UI.ORANGE, 28, 110)
	btn.custom_minimum_size.x = 230
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_start_campaign.bind(String(cdef.id), btn))
	row.add_child(btn)
	rows.append({"kind": "campaign", "id": String(cdef.id), "btn": btn, "def": cdef})


func _start_campaign(id: String, btn: Button) -> void:
	if Commerce.start_campaign(sim(), id):
		Sfx.play("buy")
		Fx.reward(btn, "Trafic ×%s" % Fmt.mult(float(Commerce.campaign_def(sim(), id).mult)), UI.ORANGE)
	else:
		Sfx.play("bad")
	refresh()


# --- Armateurs ------------------------------------------------------------------

func _build_owners() -> void:
	var s := sim()
	var ml := Commerce.max_lines(s)
	var intro := "Chaque armateur envoie ses navires. Une ligne régulière les fait venir bien plus souvent."
	intro += " Les lignes régulières s'ouvrent au palier T2." if ml == 0 else " Au plus %d lignes par armateur à ce palier ; un contrat réussi rend la suivante moitié moins chère." % ml
	content.add_child(UI.wrap_label(intro, 26))
	for o in s.db.owners:
		if int(o.tier) > s.tier + 1:
			continue
		_owner_card(o)


func _owner_card(o: Dictionary) -> void:
	var s := sim()
	var oid := String(o.id)
	var c := UI.card()
	content.add_child(c)
	var v := UI.vbox(10)
	c.add_child(v)
	var h := UI.hbox(14)
	v.add_child(h)
	h.add_child(UI.icon_disc("ship", Assets.color(String(o.hull)), 96))
	var mid := UI.vbox(2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(mid)
	mid.add_child(UI.label(String(o.name), 34, UI.VIOLET))
	mid.add_child(UI.label(String(o.home), 24, UI.MUTED))
	var st := Commerce.recruit_state(s, oid)
	var present := s.owner_present(o)
	v.add_child(UI.wrap_label(String(o.blurb), 24))
	var info := UI.label("", 28, UI.TEXT)
	v.add_child(info)
	var rel: RoundBar = null
	if present:
		rel = RoundBar.new(30)
		v.add_child(rel)
	var btn: Button = null
	if st == "tier":
		info.text = "Arrive au palier T%d." % int(o.tier)
		info.add_theme_color_override("font_color", UI.MUTED)
	elif not present and st == "available":
		info.text = "À démarcher au salon maritime : ses navires feront escale chez toi."
		btn = UI.button("", UI.INFO, 28, 100)
		btn.pressed.connect(_recruit.bind(oid))
	elif not present:
		var rq := String(o.get("require", ""))
		info.text = ("Viendra avec « %s » (Gestion → Bâtiments)." % s.db.building_by_id[rq].name) if rq != "" else "Pas encore présent."
		info.add_theme_color_override("font_color", UI.MUTED)
	elif Commerce.max_lines(s) > 0:
		btn = UI.button("", UI.MONEY, 28, 100)
		btn.pressed.connect(_sign.bind(oid))
	if btn != null:
		v.add_child(btn)
	rows.append({"kind": "owner", "id": oid, "btn": btn, "info": info, "rel": rel, "present": present, "state": st})


func _recruit(oid: String) -> void:
	if Commerce.recruit(sim(), oid):
		Sfx.play("hire")
	else:
		Sfx.play("bad")
	rebuild()


func _sign(oid: String) -> void:
	var btn: Button = null
	for r in rows:
		if r.get("id", "") == oid:
			btn = r.btn
	if Commerce.sign_line(sim(), oid):
		Sfx.play("buy")
		if btn != null:
			Fx.reward(btn, "Ligne signée !", UI.MONEY, true)
	else:
		Sfx.play("bad")
	rebuild()


# --- Contrats ------------------------------------------------------------------

func _build_contracts() -> void:
	var s := sim()
	if not s.feature("contracts"):
		content.add_child(UI.wrap_label("Les armateurs te proposeront des contrats " + s.unlock_text("contracts") + ".", 30))
		return
	content.add_child(UI.label("En cours (%d/%d)" % [s.contracts_active.size(), int(s.db.cfg("contract_active_max"))], 40, UI.VIOLET))
	if s.contracts_active.is_empty():
		content.add_child(UI.wrap_label("Aucun contrat en cours. Accepte une offre ci-dessous : l'armateur enverra plus de navires pendant le contrat.", 28))
	for c in s.contracts_active:
		_contract_card(c, true, -1)
	content.add_child(UI.label("Offres", 40, UI.VIOLET))
	for i in s.contract_offers.size():
		_contract_card(s.contract_offers[i], false, i)


func _contract_card(c: Dictionary, active: bool, index: int) -> void:
	var s := sim()
	var card := UI.card()
	content.add_child(card)
	var v := UI.vbox(10)
	card.add_child(v)
	var h := UI.hbox(14)
	v.add_child(h)
	var col: Color = Assets.color(String(s.db.owner_by_id[c.owner].hull))
	h.add_child(UI.icon_disc("contracts", col, 90))
	var mid := UI.vbox(2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(mid)
	mid.add_child(UI.label(String(c.title), 36, UI.VIOLET))
	mid.add_child(UI.label(String(c.owner_name), 26, UI.MUTED))
	v.add_child(UI.wrap_label(String(c.text), 30, UI.TEXT))
	var rw := UI.hbox(10)
	v.add_child(rw)
	rw.add_child(UI.icon("money", 48))
	rw.add_child(UI.label(Fmt.money(float(c.reward)), 32, UI.MONEY, true))
	rw.add_child(UI.icon("amber", 44))
	rw.add_child(UI.label("+%d" % int(c.amber), 32, UI.AMBER, true))
	var perk := "  ligne −50 %" if Commerce.max_lines(s) > 0 else "  relation +%d" % int(c.relation)
	rw.add_child(UI.label(perk, 26, UI.MUTED))
	if active:
		var bar := RoundBar.new(44)
		bar.color = UI.INFO
		v.add_child(bar)
		var tl := UI.label("", 28, UI.MUTED)
		v.add_child(tl)
		rows.append({"kind": "contract", "c": c, "bar": bar, "time": tl})
	else:
		var h2 := UI.hbox(14)
		v.add_child(h2)
		var acc := UI.button("ACCEPTER", UI.MONEY, 30, 96)
		acc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		acc.disabled = s.contracts_active.size() >= int(s.db.cfg("contract_active_max"))
		acc.pressed.connect(_accept.bind(index))
		h2.add_child(acc)
		var dec := UI.button("REFUSER", UI.INDIGO_DARK, 30, 96)      # le gris est réservé à l'impossible
		dec.pressed.connect(_decline.bind(index))
		h2.add_child(dec)


func _accept(i: int) -> void:
	if Objectives.accept(sim(), i):
		Sfx.play("buy")
	rebuild()


func _decline(i: int) -> void:
	Objectives.decline(sim(), i)
	Sfx.play("click")
	rebuild()


# --- mise à jour ----------------------------------------------------------------

func refresh() -> void:
	var s := sim()
	if _signature() != _sig:
		rebuild()
		return
	if traffic_l != null:
		var dem := s.stat("demand")
		var cap := s.service_capacity()
		traffic_l.text = "Trafic : %s" % Info.per_min(dem)
		capacity_l.text = "Ton port peut en traiter %s" % Info.per_min(cap)
		if dem < cap * 0.9:
			verdict_l.text = "Pas assez de navires : tes quais ont de la marge. Lance une campagne, démarche un armateur ou signe une ligne."
		elif dem > cap * 1.3:
			verdict_l.text = "Plus de navires que tu ne peux en servir : améliore ton port (Améliorer, Bâtiments) avant de démarcher."
		else:
			verdict_l.text = "Trafic et capacité sont équilibrés."
	for r in rows:
		match String(r.kind):
			"campaign":
				var btn: Button = r.btn
				var id := String(r.id)
				if not Commerce.campaign_available(s, r.def):
					btn.text = "VERROUILLÉ"
					btn.disabled = true
				elif Commerce.campaign_active(s, id):
					btn.text = "EN COURS\n%s" % Fmt.duration(_mod_left(s, "camp_" + id))
					btn.disabled = true
				elif not Commerce.campaign_ready(s, id):
					btn.text = "RECHARGE\n%s" % Fmt.duration(float(s.campaign_ready_at.get(id, 0.0)) - s.time)
					btn.disabled = true
				else:
					var cost := Commerce.campaign_cost(s, id)
					btn.disabled = s.money < cost
					btn.text = "LANCER\n%s" % Fmt.money(cost) if not btn.disabled else "Il manque\n%s" % Fmt.money(cost - s.money)
			"owner":
				var oid := String(r.id)
				if r.rel != null:
					var rb: RoundBar = r.rel
					rb.value = float(s.relations[oid]) / 100.0
					rb.text = "Relation %d" % roundi(float(s.relations[oid]))
					rb.color = UI.MONEY if rb.value >= 0.5 else (UI.AMBER if rb.value >= 0.25 else UI.BAD)
				if bool(r.present):
					var nl := int(s.lines.get(oid, 0))
					(r.info as Label).text = "Trafic : %s · lignes %d/%d" % [Info.per_min(s.owner_traffic(oid)), nl, Commerce.max_lines(s)]
				var b: Button = r.btn
				if b == null:
					continue
				if String(r.state) == "available" and not bool(r.present):
					var rc := float(s.db.owner_by_id[oid].recruit)
					b.disabled = s.money < rc
					b.text = "DÉMARCHER · %s" % Fmt.money(rc) if not b.disabled else "DÉMARCHER · il manque %s" % Fmt.money(rc - s.money)
				elif not Commerce.line_available(s, oid):
					b.text = "LIGNES AU COMPLET"
					b.disabled = true
				else:
					var lc := Commerce.line_cost(s, oid)
					b.disabled = s.money < lc
					if not b.disabled:
						b.text = "SIGNER UNE LIGNE · %s%s" % [Fmt.money(lc), "  (−50 %)" if s.line_offers.has(oid) else ""]
					else:
						b.text = "SIGNER UNE LIGNE · il manque %s" % Fmt.money(lc - s.money)
			"contract":
				var c: Dictionary = r.c
				(r.bar as RoundBar).value = float(c.progress) / float(c.target)
				(r.bar as RoundBar).text = "%s / %s EVP" % [Fmt.num(minf(float(c.progress), float(c.target))), Fmt.num(float(c.target))]
				(r.time as Label).text = "Reste " + Fmt.duration(maxf(0.0, float(c.deadline) - s.time))


static func _mod_left(s: PortSim, id: String) -> float:
	for e in s.mods.entries:
		if e.id == id:
			return maxf(0.0, float(e.until) - s.time)
	return 0.0
