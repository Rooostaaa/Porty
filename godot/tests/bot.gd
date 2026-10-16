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
	_hrng.seed = s.rng.seed + 7


func _mark(name: String) -> void:
	if not milestones.has(name):
		milestones[name] = sim.time
		log_lines.append("%8s  %s" % [Fmt.duration(sim.time), name])


func _bought(kind: String, id: String) -> void:
	purchases.append({"t": sim.time, "kind": kind, "id": id})
	if purchases.size() == 1:
		_mark("Premier achat (%s %s)" % [kind, id])


## Lot G2 — délai humain : un geste n'est fait que 1 à 3 s (tirage, moyenne `human_delay`) après être devenu possible (le
## joueur voit, puis touche).
var human_delay := 2.0
var _ready_at: Dictionary = {}           # geste -> instant où il sera fait
var _hrng := RandomNumberGenerator.new()


func _human(kind: String, possible: bool) -> bool:
	if not possible:
		_ready_at.erase(kind)
		return false
	if not _ready_at.has(kind):
		_ready_at[kind] = sim.time + _hrng.randf_range(human_delay - 1.0, human_delay + 1.0)
	if sim.time >= float(_ready_at[kind]):
		_ready_at.erase(kind)
		return true
	return false


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
	# gestes manuels : un joueur actif accoste ses navires tant qu'aucun responsable ne le fait ; lot G2 : il tamponne et
	# laisse passer les camions, avec un délai humain (`human_delay` s après que le geste est devenu possible)
	if use_manual:
		var auto_berth := bool(sim.managers.harbor) or (sim.g2 and bool(sim.managers.berths))
		var anch := false
		if not auto_berth:
			for s in sim.ships:
				if s.state == Ship.State.ANCHORED and not s.priority:
					anch = true
					if _human("berth", true):
						sim.prioritize_ship(s.id)
					break
		if not anch:
			_human("berth", false)
		if _human("stamp", sim.stamp_ready()):
			sim.stamp()
		if _human("pass", sim.pass_ready()):
			sim.pass_truck()
	if sim.g2 and sim.counter("trucks") + sim.counter("passes") > 0.0:
		_mark("Premier camion")
	# lot G2 : la friche — les six pièces du départ, une à une, dès qu'on peut ; chaque responsable des gestes dès qu'il se
	# présente (on économise pour lui)
	if sim.g2:
		for d in PortSim.OFFER_ORDER:
			if sim.manager_revealed(d) and not sim.managers[d]:
				if sim.money >= sim.manager_cost(d) and sim.hire_manager(d):
					_bought("manager", d)
					_mark("Responsable embauché : %s" % sim.db.dept_by_id[d].manager.name)
				return
		var st := sim.next_starter()
		if st != "":
			if sim.building_state(st) == "available" and float(sim.db.building_by_id[st].cost) <= sim.money and sim.build(st):
				_bought("building", st)
				_mark("Bâtiment : %s" % sim.db.building_by_id[st].name)
			return
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
	if int(sim.levels.cranes) < 2 and sim.tier == 1 and sim.feature("dept_cranes"):
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
			var mc := sim.manager_cost(d)
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
	# lot G1 : après la Concession, les cartes de la Crique restent achetables jusqu'à leur maximum (loyer par bateau, marina)
	var f := sim.fishing
	if not f.act0 and f.places > 0 and not f.maxed():
		var r0 := f.rate_estimate()
		var inc := maxf(sim.income_rate_estimate() + r0, 0.01)
		if f.places < f.places_max():
			var g := float(f.boat_def("dinghy").get("value", 0.0)) * f.ticket() / 52.0 / inc
			out.append({"kind": "fish", "id": "places", "cost": f.places_cost(), "score": g / maxf(1.0, f.places_cost())})
		if f.services < f.services_max():
			var g2 := r0 * float(f.cfg.get("ticket_step", 0.15)) / f.ticket() / inc
			out.append({"kind": "fish", "id": "services", "cost": f.services_cost(), "score": g2 / maxf(1.0, f.services_cost())})
		var nb := f.next_building()
		if not nb.is_empty():
			var g3 := 0.0
			for cls in nb.get("boats", {}):
				g3 += float(nb.boats[cls]) * float(f.boat_def(cls).get("value", 0.0)) * f.ticket() / 90.0
			g3 += float(f.cfg.get("sail_rent", 0.0)) * maxf(0.0, float(nb.get("sail", 0)) - float(f.sails()))
			out.append({"kind": "fish", "id": String(nb.id), "cost": float(nb.cost), "score": g3 / inc / float(nb.cost)})
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
		"fish":
			match String(o.id):
				"places":
					ok = sim.buy_fish_places(1)
				"services":
					ok = sim.buy_fish_services(1)
				_:
					ok = sim.buy_fish_building(String(o.id))
		"tier":
			ok = false
	if ok:
		_bought(o.kind, o.id)


## Lot G1 — chapitre 1 « La Crique » : encaisse les loyers (tant que Marcel n'est pas là), embauche Marcel dès qu'il se
## présente, achète dans l'ordre de la liste AMÉLIORER (le prochain bâtiment en tête, puis la moins chère des deux cartes à
## niveaux) ; « pressé » (`hurry`) signe la Concession dès qu'elle est abordable, « tranquille » après le plafond (tout au
## maximum). Renvoie la durée de la Crique (s). Garde-fou : `max_s`.
var act0_buys: Array[String] = []        # « 1:24 criée » : instants (horloge de la pêche) et achats de la Crique
var hurry := false


func _act0_log(what: String) -> void:
	act0_buys.append("%s %s" % [Fmt.duration(sim.fishing.act0_time), what])


func run_act0(max_s: float = 1500.0) -> float:
	var tick := float(sim.db.cfg("tick"))
	var acc := 0.0
	var f := sim.fishing
	while f.act0 and f.act0_time < max_s:
		sim.step(tick)
		acc += tick
		if acc >= 1.0:
			acc -= 1.0
			if sim.act0_ready():
				break
			if use_manual and not f.marcel:
				for i in f.boats.size():
					sim.fish_collect(i)
			if f.marcel_offered and not f.marcel:
				if sim.hire_marcel():
					_act0_log("Marcel")
				continue      # Marcel d'abord (l'objectif de la première session) : on économise pour lui
			if f.places == 0:
				if sim.buy_fish_places(1):
					_act0_log("ponton")
				continue
			if f.concession_available() and (hurry or f.maxed()):
				var cc := String(f.concession_def().id)
				if sim.buy_fish_building(cc):
					_act0_log("Concession")
					break
				if hurry:
					# pressé : seul un achat qui se rembourse avant la Concession vaut encore le coup
					var left := (float(f.concession_def().cost) - sim.money) / maxf(0.05, f.rate_estimate())
					var o := _fish_best()
					if not o.is_empty() and float(o.payback) < left * 0.9 and _fish_do(o):
						_act0_log(String(o.id))
				continue      # on économise pour la Concession
			if hurry:
				# pressé : l'achat qui se rembourse le plus vite (niveau, bâtiment) ; la marina même lente (elle ouvre la Concession)
				var o2 := _fish_best()
				if not o2.is_empty() and float(o2.cost) <= sim.money and _fish_do(o2):
					_act0_log(String(o2.id))
				continue
			var nb := f.next_building()
			if not nb.is_empty() and sim.money >= float(nb.cost):
				if sim.buy_fish_building(String(nb.id)):
					_act0_log(String(nb.id))
				continue
			var cp := f.places_cost()
			var cs := f.services_cost()
			if cp <= cs and cp <= sim.money:
				if sim.buy_fish_places(1):
					_act0_log("places %d" % f.places)
			elif cs <= sim.money:
				if sim.buy_fish_services(1):
					_act0_log("services %d" % f.services)
	var d := f.act0_time
	act0_end_rate = f.rate_estimate()
	sim.open_port()
	return d


var act0_end_rate := 0.0                 # revenu estimé de la pêche à la fin de la Crique ($/s)


## Achats de la Crique avec leur temps de retour {id, cost, gain, payback} ; le meilleur (temps de retour le plus court).
func _fish_options() -> Array[Dictionary]:
	var f := sim.fishing
	var out: Array[Dictionary] = []
	# (lot H1 : revenu d'un bateau au niveau actuel, stations comprises — sans station, la formule de G1)
	if f.places < f.places_max():
		out.append({"id": "places", "cost": f.places_cost(), "gain": f.boat_rate("dinghy")})
	if f.services < f.services_max():
		var g2 := 0.0
		for bt in f.boats:
			g2 += f.boat_rate(String(bt.cls), f.services + 1) - f.boat_rate(String(bt.cls))
		out.append({"id": "services", "cost": f.services_cost(), "gain": maxf(0.0001, g2)})
	var nb := f.next_building()
	if not nb.is_empty():
		var g3 := 0.0
		for cls in nb.get("boats", {}):
			g3 += float(nb.boats[cls]) * f.boat_rate(cls)
		g3 += float(f.cfg.get("sail_rent", 0.0)) * maxf(0.0, float(nb.get("sail", 0)) - float(f.sails()))
		# la marina ouvre la Concession : pour un joueur pressé elle vaut autant qu'un bon achat
		if String(nb.id) == "marina":
			g3 = maxf(g3, float(nb.cost) / 120.0)
		out.append({"id": String(nb.id), "cost": float(nb.cost), "gain": g3})
	for o in out:
		o.payback = float(o.cost) / maxf(0.0001, float(o.gain))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.payback) < float(b.payback))
	return out


func _fish_best() -> Dictionary:
	var opts := _fish_options()
	return opts[0] if not opts.is_empty() else {}


func _fish_do(o: Dictionary) -> bool:
	match String(o.id):
		"places":
			return sim.buy_fish_places(1)
		"services":
			return sim.buy_fish_services(1)
	return sim.buy_fish_building(String(o.id))


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
