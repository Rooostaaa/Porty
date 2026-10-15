extends RefCounted
## Joueur automatique « actif mais raisonnable » pour l'équilibrage et le test d'impasse.

var sim: PortSim
var log_lines: Array[String] = []
var purchases: Array[Dictionary] = []   # {t, kind, id}
var milestones: Dictionary = {}          # nom -> temps
var use_boost := true
var use_manual := true                   # accoste et donne des coups de main comme un joueur actif
var wait_horizon := 30.0                 # secondes de revenu qu'on accepte d'attendre pour le meilleur achat
var use_commerce := true                 # démarchage, armateurs, lignes
var save_horizon := 150.0                # secondes de revenu qu'on accepte d'économiser pour l'équipement qui fait venir du trafic


func _init(s: PortSim) -> void:
	sim = s


func _mark(name: String) -> void:
	if not milestones.has(name):
		milestones[name] = sim.time
		log_lines.append("%8s  %s" % [Fmt.duration(sim.time), name])


func _bought(kind: String, id: String) -> void:
	purchases.append({"t": sim.time, "kind": kind, "id": id})
	if purchases.size() == 1:
		_mark("Premier achat (%s %s)" % [kind, id])


## Plus longue attente au palier 1 où **rien** n'était abordable (service présenté ou prochain bâtiment), mesurée
## chaque seconde avant la décision du bot : c'est le « trou » que vit le joueur, indépendamment de la stratégie d'épargne.
var dry_t1 := 0.0
var _dry_from := 0.0


func _track_dry() -> void:
	if sim.tier != 1:
		return
	var aff := false
	for d in PortSim.DEPTS:
		if sim.feature("dept_" + d) and sim.dept_cost(d, 1) <= sim.money:
			aff = true
			break
	if not aff:
		for b in sim.db.buildings:
			if sim.building_state(b.id) == "available" and float(b.cost) <= sim.money:
				aff = true
				break
	if aff:
		_dry_from = sim.time
	dry_t1 = maxf(dry_t1, sim.time - _dry_from)


## Une décision par seconde de jeu.
func think() -> void:
	_track_dry()
	if sim.can_tier_up():
		var t := sim.tier
		sim.tier_up()
		_bought("tier", str(t + 1))
		_mark("Palier T%d atteint" % (t + 1) if not sim.finished else "FIN DU MVP (concession nationale)")
		return
	for m in Objectives.visible_missions(sim):
		if Objectives.mission_done(sim, m):
			Objectives.claim(sim, m.id)
	if sim.contracts_active.size() < int(sim.db.cfg("contract_active_max")) and not sim.contract_offers.is_empty():
		Objectives.accept(sim, 0)
	if int(sim.time) % 10 == 0:
		_adjust_tariff()
	# gestes manuels : un joueur actif accoste ses navires et donne des coups de main tant qu'aucun responsable ne le fait
	if use_manual:
		if not sim.managers.harbor:
			for s in sim.ships:
				if s.state == Ship.State.ANCHORED and not s.priority:
					sim.prioritize_ship(s.id)
					break
		for bi in sim.berths.size():
			sim.assist_unload(bi)
		# gestes optionnels du parc et de la gate (accélérateurs à recharge)
		sim.yard_boost()
		sim.gate_rush()
	if use_boost and sim.boost_ready() and sim.feature("boost"):
		sim.start_boost()
	if not sim.active_event.is_empty() and sim.active_event.kind == "auction":
		Hazards.pay(sim)
	# démarchage : une campagne quand les navires manquent et que les quais ont de la marge
	var key0: String = sim.analysis.get("key", "")
	if use_commerce and sim.feature("commerce") and (key0 == "harbor" or key0 == "attract"):
		for c in Commerce.campaigns(sim):
			if Commerce.campaign_available(sim, c) and Commerce.campaign_ready(sim, c.id) and Commerce.campaign_cost(sim, c.id) <= sim.money * 0.5:
				Commerce.start_campaign(sim, c.id)
				_bought("campaign", c.id)
				break
	# un joueur guidé suit le tutoriel : il construit d'abord l'allongement du quai (étape « quai »), puis achète
	# un niveau de Portiques (étape « achète un niveau »)
	if not sim.built.has("quay_ext") and sim.tier == 1:
		if float(sim.db.building_by_id.quay_ext.cost) <= sim.money and sim.build("quay_ext"):
			_bought("building", "quay_ext")
			_mark("Bâtiment : %s" % sim.db.building_by_id.quay_ext.name)
		return
	if int(sim.levels.cranes) < 2 and sim.tier == 1:
		if sim.dept_cost("cranes", 1) <= sim.money and sim.buy_dept("cranes", 1):
			_bought("dept", "cranes")
		return
	var opts := _options()
	if opts.is_empty():
		return
	opts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
	var best: Dictionary = opts[0]
	var income := maxf(sim.income_rate_estimate(), 0.01)
	if best.cost <= sim.money:
		_do(best)
		return
	if (best.cost - sim.money) / income <= wait_horizon:
		return   # on économise
	# tout le reste du palier est prêt : un joueur économise pour le passer au lieu de dépenser en niveaux
	if best.kind == "tier":
		return
	# un joueur guidé économise pour l'équipement qui fait venir du trafic quand c'est le goulot
	if (best.kind == "building" or best.kind == "line" or best.kind == "owner") and best.score * best.cost >= 0.6 and (best.cost - sim.money) / income <= save_horizon:
		return
	for o in opts:
		if o.cost <= sim.money:
			_do(o)
			return


func _licence_mult(lv: int) -> float:
	return sim.licence_mult(lv)


## Part de chaque cargaison dans la valeur traitée.
func _value_shares() -> PackedFloat64Array:
	var sh := PackedFloat64Array()
	sh.resize(PortSim.NCARGO)
	var tot := 0.0
	for o in sim.db.owners:
		if int(o.tier) <= sim.tier and sim.owner_ok(o):
			var m := sim.cargo_mix(o.id)
			for c in PortSim.NCARGO:
				sh[c] += m[c] * sim.stat("value", c)
				tot += m[c] * sim.stat("value", c)
	for c in PortSim.NCARGO:
		sh[c] /= maxf(0.0001, tot)
	return sh


## Options d'achat avec un gain relatif estimé ; score = gain / coût.
func _options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var bn: String = sim.analysis.get("dept", "")
	var key: String = sim.analysis.get("key", "")
	var caps: Dictionary = sim.analysis.get("caps", {})
	var vals: Array = []
	for k in ["traffic", "pilotage", "berth_cycle", "transfer", "inspection", "gate", "yard_space"]:
		vals.append(float(caps.get(k, 0.0)))
	vals.sort()
	# services facturés (lot D-Éco) : gain relatif d'un niveau de plus, quel que soit le service
	var n_lv := 0
	for d0 in PortSim.DEPTS:
		n_lv += int(sim.levels[d0]) - 1
	var fee_rel := sim.service_fee_rate() / float(maxi(1, n_lv)) / maxf(sim.income_rate_estimate(), 0.01)
	var headroom := clampf(vals[1] / maxf(0.0001, vals[0]) - 1.0, 0.0, 1.0) if vals.size() > 1 else 0.5
	for d in PortSim.DEPTS:
		if not sim.feature("dept_" + d):
			continue
		var c := sim.dept_cost(d, 1)
		var lv := int(sim.levels[d])
		var g := 0.01
		if d == bn and key != "berth_count":
			g = minf(1.0 / float(lv), headroom) if headroom > 0.0 else 0.5 / float(lv)
			g = maxf(g, 0.2 / float(lv))
			if d == "harbor" and sim.waiting_ships() >= 2:
				g = 0.0
		# services facturés (lot D-Éco) : chaque niveau rapporte un minimum, goulot ou non (la pastille le montre)
		g += fee_rel
		out.append({"kind": "dept", "id": d, "cost": c, "score": g / c})
		if not sim.managers[d] and sim.manager_available(d) and sim.manager_revealed(d):
			var mc := float(sim.db.dept_by_id[d].manager.cost)
			var gm := minf(1.0, headroom + 0.3) if d == bn else 0.25
			if d == "harbor":
				gm = 0.4
			out.append({"kind": "manager", "id": d, "cost": mc, "score": gm / mc})
	var shares := _value_shares()
	for ci in PortSim.NCARGO:
		if sim.unlocked[ci] == 1 and sim.feature("licences") and sim.licence_room(ci) > 0:
			var lc := sim.licence_cost(ci, 1)
			var lv2: int = sim.licences[ci]
			var g2 := shares[ci] * (_licence_mult(lv2 + 1) / _licence_mult(lv2) - 1.0)
			out.append({"kind": "licence", "id": str(ci), "cost": lc, "score": g2 / lc})
	var req: Dictionary = sim.tier_requirements(sim.tier + 1)
	for b in sim.db.buildings:
		if sim.building_state(b.id) == "available":
			var g3 := 0.15
			if key == "yard_space" or key == "berth_count":
				g3 = 0.6
			if req.get("buildings", []).has(b.id):
				g3 = 1.0
			for e in b.effects:
				if e.type == "unlock_cargo":
					g3 = maxf(g3, 1.0)
				if (e.type == "berth_depth" or e.type == "customs_open" or (e.type == "stat_mult" and e.stat == "demand")) and key == "attract":
					g3 = maxf(g3, 1.0)
				if e.type == "time_min" and key == "min_time":
					g3 = maxf(g3, 0.8)
				if e.type == "parking" and key == "gate":
					g3 = maxf(g3, 0.6)
			out.append({"kind": "building", "id": b.id, "cost": float(b.cost), "score": g3 / float(b.cost)})
			break
	if use_commerce and sim.feature("commerce"):
		var short := key == "harbor" or key == "attract"
		for o in sim.db.owners:
			if Commerce.line_available(sim, o.id):
				var lc := Commerce.line_cost(sim, o.id)
				out.append({"kind": "line", "id": o.id, "cost": lc, "score": (1.0 if short else 0.3) / lc})
		for o in sim.db.owners:
			if Commerce.recruit_state(sim, o.id) == "available":
				out.append({"kind": "owner", "id": o.id, "cost": float(o.recruit), "score": (1.0 if short else 0.3) / float(o.recruit)})
	var chk := sim.tier_check()
	if not chk.is_empty():
		var other_ok := true
		var need := 0.0
		for c in chk:
			if c.get("money", false):
				need = float(c.need)
			elif not c.ok:
				other_ok = false
		if other_ok:
			out.append({"kind": "tier", "id": "", "cost": need, "score": 100.0 / need})
	return out


func _do(o: Dictionary) -> void:
	var ok := false
	match String(o.kind):
		"dept":
			ok = sim.buy_dept(o.id, 1)
		"manager":
			ok = sim.hire_manager(o.id)
			if ok:
				_mark("Responsable embauché : %s" % sim.db.dept_by_id[o.id].manager.name)
		"licence":
			ok = sim.buy_licence(int(o.id), 1)
		"building":
			ok = sim.build(o.id)
			if ok:
				_mark("Bâtiment : %s" % sim.db.building_by_id[o.id].name)
		"line":
			ok = Commerce.sign_line(sim, o.id)
			if ok:
				_mark("Ligne : %s n°%d" % [o.id, int(sim.lines[o.id])])
		"owner":
			ok = Commerce.recruit(sim, o.id)
			if ok:
				_mark("Armateur démarché : %s" % o.id)
		"tier":
			ok = false
	if ok:
		_bought(o.kind, o.id)


## Lot F3 — acte 0 « La Crique » : achète les cinq achats de la pêche dès qu'il peut et aide chaque bateau qui rentre
## (`use_manual`) ; à la bascule, ouvre le port. Renvoie la durée de l'acte 0 (s). Garde-fou : `max_s`.
var act0_buys: Array[float] = []        # instants (horloge de la pêche) des achats de l'acte 0


func run_act0(max_s: float = 1200.0) -> float:
	var tick := float(sim.db.cfg("tick"))
	var acc := 0.0
	while sim.fishing.act0 and sim.fishing.act0_time < max_s:
		sim.step(tick)
		acc += tick
		if acc >= 1.0:
			acc -= 1.0
			if sim.act0_ready():
				break
			if sim.money >= sim.fishing.next_cost() and sim.buy_fish():
				act0_buys.append(sim.fishing.act0_time)
			if use_manual:
				for i in sim.fishing.boats.size():
					sim.fish_help(i)
	var d := sim.fishing.act0_time
	act0_end_rate = sim.fishing.rate_estimate()
	sim.open_port()
	return d


var act0_end_rate := 0.0                 # revenu estimé de la pêche à la fin de l'acte 0 ($/s, sans coup de main)


## Fait tourner la simulation `seconds` secondes avec une décision par seconde.
func run(seconds: float, stop_when_finished: bool = true) -> void:
	if sim.fishing.act0:
		run_act0()
	var tick := float(sim.db.cfg("tick"))
	var acc := 0.0
	var end := sim.time + seconds
	while sim.time < end:
		sim.step(tick)
		acc += tick
		if acc >= 1.0:
			acc -= 1.0
			think()
		if stop_when_finished and sim.finished:
			return


## Plus long intervalle sans achat (impasse) entre t0 et t1.
func longest_gap(t0: float, t1: float) -> float:
	var last := t0
	var gap := 0.0
	for p in purchases:
		if p.t < t0 or p.t > t1:
			continue
		gap = maxf(gap, p.t - last)
		last = p.t
	return maxf(gap, t1 - last)


## Un joueur raisonnable monte les prix quand la rade déborde, les baisse quand les navires manquent.
func _adjust_tariff() -> void:
	var key: String = sim.analysis.get("key", "")
	if sim.waiting_ships() >= sim.rade_places() - 1 and key != "harbor":
		sim.set_tariff(sim.tariff + 0.05)
	elif key == "harbor" and sim.tariff > 1.0:
		sim.set_tariff(sim.tariff - 0.05)
