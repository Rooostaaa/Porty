extends SceneTree
## Tests headless de la simulation :
##   godot --headless --path godot --script res://tests/run_all.gd

const Bot := preload("res://tests/bot.gd")

var failures := 0
var passes := 0


func check(cond: bool, label: String) -> void:
	if cond:
		passes += 1
		print("  ok   ", label)
	else:
		failures += 1
		printerr("  ÉCHEC ", label)


func _init() -> void:
	print("=== Tests Port Horizon ===")
	var db := DataDB.new()
	test_format()
	test_progression()
	test_conservation(db)
	test_determinism(db)
	test_save_roundtrip(db)
	test_bottleneck_moves(db)
	test_events_and_offline(db)
	test_contract_rescale(db)
	test_no_dead_end(db)
	test_payback(db)
	test_career_missions(db)
	test_manual_chores(db)
	test_world_levers(db)
	test_tutorial_data(db)
	test_prestige(db)
	test_review_fixes(db)
	test_gentle_start(db)
	test_commerce(db)
	test_ism_gaps(db)
	test_lot_b(db)
	print("=== %d ok, %d échec(s) ===" % [passes, failures])
	quit(1 if failures > 0 else 0)


func test_format() -> void:
	print("[format]")
	check(Fmt.num(999) == "999", "999")
	check(Fmt.num(12500) == "12,5K", "12,5K -> " + Fmt.num(12500))
	check(Fmt.num(2.5e6) == "2,5M", "2,5M -> " + Fmt.num(2.5e6))
	check(Fmt.num(1e15) == "1aa", "aa -> " + Fmt.num(1e15))
	check(Fmt.num(1e12) == "1T", "T -> " + Fmt.num(1e12))


func test_progression() -> void:
	print("[progression]")
	var c1 := Progression.bulk_cost(10, 1.15, 0, 1)
	check(is_equal_approx(c1, 10.0), "coût niveau 1 = base")
	var c10 := Progression.bulk_cost(10, 1.15, 0, 10)
	var s := 0.0
	for i in 10:
		s += 10.0 * pow(1.15, i)
	check(absf(c10 - s) < 1e-6, "coût ×10 = somme")
	var n := Progression.max_affordable(10, 1.15, 0, s)
	check(n == 10, "max achetable = 10 (%d)" % n)
	check(Progression.milestone_mult(25, [10, 25, 50], [150]) == 4.0, "paliers ×2 ×2")


func _conservation_error(sim: PortSim) -> float:
	var inside := 0.0
	for sh in sim.ships:
		if sh.state != Ship.State.LEAVING:
			inside += sh.evp_left()
	for c in PortSim.NCARGO:
		inside += sim.apron[c] + sim.yard_pending[c] + sim.yard_cleared[c] + sim.delivered[c]
	inside += sim.sailed_away
	return absf(inside - sim.arrived_total) / maxf(1.0, sim.arrived_total)


func _negatives(sim: PortSim) -> bool:
	if sim.money < 0.0:
		return true
	for arr in [sim.apron, sim.yard_pending, sim.yard_cleared, sim.delivered]:
		for v in arr:
			if v < -1e-6:
				return true
	for sh in sim.ships:
		for v in sh.left:
			if v < -1e-6:
				return true
	for z in PortSim.NZONE:
		if sim.yard_stock_zone(z) > sim.yard_zone_capacity(z) + 1e-3:
			return true
	return sim.apron_stock() > sim.apron_capacity() + 1e-3


func test_conservation(db: DataDB) -> void:
	print("[conservation des EVP et stocks positifs]")
	var sim := PortSim.new(db, 7)
	var bot := Bot.new(sim)
	var worst := 0.0
	var neg := false
	for i in 120:
		bot.run(30.0)
		worst = maxf(worst, _conservation_error(sim))
		neg = neg or _negatives(sim)
	check(worst < 1e-6, "entrées = sorties + stock (erreur max " + str(worst) + ")")
	check(not neg, "aucun stock négatif ni dépassement de capacité")
	check(sim.arrived_total > 0.0 and sim.counter("trucks") > 0.0, "des EVP sont entrés et sortis")


func test_determinism(db: DataDB) -> void:
	print("[déterminisme à graine fixe]")
	var a := PortSim.new(db, 42)
	var b := PortSim.new(db, 42)
	Bot.new(a).run(900.0)
	Bot.new(b).run(900.0)
	check(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "deux parties identiques")


func test_save_roundtrip(db: DataDB) -> void:
	print("[sauvegarde]")
	var a := PortSim.new(db, 3)
	Bot.new(a).run(400.0)
	var d1 := a.to_dict()
	var txt := JSON.stringify(d1)
	var b := PortSim.new(db, 99)
	b.from_dict(JSON.parse_string(txt))
	var d2 := b.to_dict()
	var s1 := JSON.stringify(d1)
	var s2 := JSON.stringify(d2)
	if false:
		for k in d1:
			if JSON.stringify(d1[k]) != JSON.stringify(d2.get(k)):
				print("    diff ", k, " : ", JSON.stringify(d1[k]).left(200), " vs ", JSON.stringify(d2.get(k)).left(200))
	check(JSON.stringify(JSON.parse_string(s1)) == JSON.stringify(JSON.parse_string(s2)), "aller-retour JSON identique")
	# la partie rechargée continue comme l'originale
	for i in 200:
		a.step(0.25)
		b.step(0.25)
	check(absf(a.money - b.money) < 1e-3 and a.next_ship_id == b.next_ship_id, "suite identique après rechargement")


## Partie neuve avec le quai allongé : les caboteurs arrivent, le goulot est un service (les grues), plus le trafic.
func _past_quay(db: DataDB) -> PortSim:
	var sim := PortSim.new(db, 5)
	sim.money = 1000.0
	sim.build("quay_ext")
	for i in 240:
		sim.step(0.25)
	check(sim.db.dept_by_id.has(String(sim.analysis.dept)), "quai allongé : le goulot est un service (%s)" % sim.analysis.key)
	return sim


func test_bottleneck_moves(db: DataDB) -> void:
	print("[goulot]")
	var sim := _past_quay(db)
	var first: String = sim.analysis.dept
	sim.levels[first] = int(sim.levels[first]) + 30
	sim.rebuild_infra()
	sim.step(0.6)
	check(sim.analysis.dept != first, "améliorer le goulot (%s) en fait apparaître un autre (%s)" % [first, sim.analysis.dept])
	check(String(sim.analysis.hint) != "", "conseil présent")


func test_events_and_offline(db: DataDB) -> void:
	print("[aléas et hors-ligne]")
	var sim := PortSim.new(db, 11)
	Bot.new(sim).run(300.0)
	var before := sim.stat("crane_rate")
	Hazards.start(sim, "wind")
	check(sim.stat("crane_rate") == 0.0 and before > 0.0, "vent fort : grues à l'arrêt")
	sim.money += 1e9
	Hazards.pay(sim)
	check(sim.stat("crane_rate") > 0.0, "sécuriser : grues reprennent")
	sim.next_event_at = sim.time + 1000.0     # aucun nouvel aléa tiré au hasard pendant qu'on attend la fin de celui-ci
	for i in 200:
		sim.step(0.25)
	check(sim.active_event.is_empty(), "l'aléa se termine")
	var m0 := sim.money
	var r := sim.apply_offline(36000.0)
	check(r.capped and is_equal_approx(r.seconds, 8.0 * 3600.0), "hors-ligne borné à 8 h")
	check(sim.money > m0 and is_equal_approx(r.yield, 0.5 + 0.5 * sim.managers_count() / 6.0), "rendement hors-ligne %.2f" % r.yield)


func test_no_dead_end(db: DataDB) -> void:
	print("[absence d'impasse — partie complète]")
	var sim := PortSim.new(db, 2024)
	var bot := Bot.new(sim)
	bot.run(3.0 * 3600.0)
	var gap := bot.longest_gap(0.0, sim.time)
	check(gap < 600.0, "jamais plus de 10 min sans achat (max %s)" % Fmt.duration(gap))
	check(sim.finished, "le MVP se termine (%s)" % Fmt.duration(sim.time))


func test_payback(db: DataDB) -> void:
	print("[rentabilité d'un achat]")
	var sim := _past_quay(db)
	var d: String = sim.analysis.dept
	var lv_before := JSON.stringify(sim.levels)
	var key_before: String = sim.analysis.key
	var g := sim.upgrade_gain(d, 1)
	check(g > 0.0, "améliorer le goulot (%s) augmente le revenu estimé (+%s/s)" % [d, Fmt.num(g)])
	check(JSON.stringify(sim.levels) == lv_before and sim.analysis.key == key_before, "l'estimation ne modifie pas l'état")
	check(sim.upgrade_gain(d, 0) == 0.0, "0 niveau = aucun gain")
	var p0 := sim.tier_progress()
	sim.counters["evp"] = 2000.0
	check(sim.tier_progress() > p0 and sim.tier_progress() <= 1.0, "progression de palier croissante")


func test_career_missions(db: DataDB) -> void:
	print("[objectifs de carrière]")
	var sim := PortSim.new(db, 9)
	sim.features["missions"] = true
	for m in db.missions:
		sim.missions_claimed.append(String(m.id))
	var vis := Objectives.visible_missions(sim)
	check(vis.size() == int(db.cfg("mission_visible")), "des objectifs restent affichés après les missions écrites (%d)" % vis.size())
	check(String(vis[0].id).begins_with("g"), "ils sont générés")
	check(float(Objectives.generated_mission(4).target) > float(Objectives.generated_mission(0).target), "difficulté croissante")
	sim.counters["evp"] = float(vis[0].target) + 1.0
	check(Objectives.claim(sim, String(vis[0].id)), "récompense réclamable")
	check(not Objectives.visible_missions(sim).any(func(m: Dictionary) -> bool: return m.id == vis[0].id), "l'objectif réclamé disparaît")


func test_manual_chores(db: DataDB) -> void:
	print("[gestes manuels du début]")
	var sim := PortSim.new(db, 31)
	# sans geste : le navire en rade attend le délai automatique
	var t0 := 0.0
	while sim.time < 60.0 and sim.berths[0].ship == -1:
		sim.step(0.25)
	t0 = sim.time
	check(t0 >= float(db.cfg("auto_berth_delay")) - 1.0, "sans geste, l'accostage attend %s (%s)" % [Fmt.duration(float(db.cfg("auto_berth_delay"))), Fmt.duration(t0)])
	# avec un toucher : le navire part tout de suite et le pilote file plus vite
	var b := PortSim.new(db, 31)
	b.step(2.0)
	var ship_id := -1
	for s in b.ships:
		if s.state == Ship.State.ANCHORED:
			ship_id = s.id
	check(ship_id >= 0 and b.prioritize_ship(ship_id), "un navire est en rade et peut être accosté en priorité")
	b.step(0.3)
	var sh := b.ship_by_id(ship_id)
	check(sh.state == Ship.State.PILOTING and b.time < t0 - 5.0, "il accoste aussitôt (%s au lieu de %s)" % [Fmt.duration(b.time), Fmt.duration(t0)])
	check(sh.timer <= b.pilot_duration() * float(db.cfg("manual").express_pilot) + 0.01, "pilotage express")
	# coup de main sur la grue
	while b.time < 120.0 and not b.assist_ready(0):
		b.step(0.25)
	check(b.assist_ready(0), "la grue peut recevoir un coup de main")
	var evp0 := b.counter("evp")
	var m0 := b.money
	var moved := b.assist_unload(0)
	check(moved > 0.0 and b.counter("evp") > evp0 and b.money > m0, "le coup de main décharge et rapporte (+%s EVP)" % Fmt.num(moved))
	check(b.assist_unload(0) == 0.0, "recharge entre deux coups de main")
	b.managers["cranes"] = true
	b.time += 10.0
	check(not b.assist_ready(0), "le chef des grutiers le fait à ta place")


func test_world_levers(db: DataDB) -> void:
	print("[leviers d'escale et aire d'attente]")
	var s := PortSim.new(db, 3)
	var pilot0 := s.min_time("pilot")
	var gate0 := s.stat("gate_rate")
	s.tier = 2
	for id in ["gravel2", "crane2", "dredge1", "gravel3", "berth2", "asphalt", "gate2", "parking1", "sts1", "tug2"]:
		s.built.append(id)
	s.rebuild_infra()
	s.invalidate()
	check(s.parking_slots == 8, "l'aire d'attente offre 8 places")
	check(is_equal_approx(s.min_time("pilot"), pilot0 * 0.7), "le remorqueur raccourcit le temps minimal de pilotage de 30 %")
	check(s.stat("gate_rate") > gate0 * 1.4, "la gate tourne mieux (×%.2f)" % (s.stat("gate_rate") / gate0))
	check(s.building_state("quickmoor") != "built" and db.building_by_id.has("ewindow"), "les autres leviers existent")
	# l'ordre séquentiel reste cohérent : chaque bâtiment T2 a un coût croissant jusqu'au scanner
	var last := 0.0
	var ok := true
	for bd in db.buildings:
		if int(bd.tier) == 2:
			ok = ok and float(bd.cost) >= last
			last = float(bd.cost)
	check(ok, "coûts des bâtiments T2 croissants")


func test_tutorial_data(db: DataDB) -> void:
	print("[tutoriel]")
	var raw: Variant = DataDB.load_json("res://data/tutorial.json")
	check(raw is Array and (raw as Array).size() >= 8, "étapes présentes")
	var sim := PortSim.new(db, 4)
	var ids := {}
	var bad := 0
	for st in raw:
		ids[st.id] = true
		for k in ["when", "done"]:
			var expr := String(st.get(k, ""))
			if expr == "":
				continue
			var e := Expression.new()
			if e.parse(expr, ["sim"]) != OK:
				bad += 1
				continue
			e.execute([sim], null, false)
			if e.has_execute_failed():
				bad += 1
				printerr("    expression en échec : ", expr)
	check(bad == 0, "toutes les conditions s'évaluent")
	check(ids.size() == (raw as Array).size(), "identifiants uniques")


func test_prestige(db: DataDB) -> void:
	print("[prestige : nouvelle concession]")
	var a := PortSim.new(db, 2024)
	Bot.new(a).run(3.0 * 3600.0)
	check(a.finished and a.can_prestige(), "prestige proposé après la concession (gain %d)" % a.prestige_gain())
	var b := PortSim.new(db, 77)
	b.carry_over(a)
	check(b.renown == a.prestige_gain() and b.prestiges == 1, "Renom %d, concession n°%d" % [b.renown, b.prestiges + 1])
	check(b.tier == 1 and b.built.is_empty() and is_equal_approx(b.money, float(db.cfg("start_money"))), "on repart de zéro")
	check(b.missions_claimed.size() == a.missions_claimed.size() and b.amber > a.amber, "missions réclamées et Ambre conservés")
	check(b.counter("evp") == 0.0 and is_equal_approx(b.counter_total("evp"), a.counter("evp")), "compteurs cumulés conservés")
	check(is_equal_approx(b.stat("value", 0) / PortSim.new(db, 77).stat("value", 0), b.renown_mult()), "le Renom multiplie la valeur (×%.2f)" % b.renown_mult())
	var d2: Dictionary = JSON.parse_string(JSON.stringify(b.to_dict()))
	var c := PortSim.new(db, 1)
	c.from_dict(d2)
	check(c.renown == b.renown and c.prestiges == 1 and is_equal_approx(c.counter_total("evp"), b.counter_total("evp")), "sauvegarde du prestige")
	Bot.new(b).run(3.0 * 3600.0)
	check(b.finished and b.time < a.time, "la 2e concession est plus rapide (%s < %s)" % [Fmt.duration(b.time), Fmt.duration(a.time)])


func test_contract_rescale(db: DataDB) -> void:
	print("[contrats suivent la croissance]")
	var sim := PortSim.new(db, 7)
	sim.step(1.0)
	Objectives.refresh_offers(sim)
	check(not sim.contract_offers.is_empty(), "des offres existent")
	var r0 := float(sim.contract_offers[0].reward)
	for d in PortSim.DEPTS:
		sim.levels[d] = int(sim.levels[d]) + 40
	sim.licences[0] = int(sim.licences[0]) + 40
	sim.rebuild_infra()
	sim.step(0.6)
	Objectives.rescale_offers(sim)
	var r1 := float(sim.contract_offers[0].reward)
	check(r1 > r0 * 10.0, "récompense revalorisée (%s -> %s)" % [Fmt.money(r0), Fmt.money(r1)])


## Régressions couvertes par la revue de code (formatage, contrats, remise à zéro, licences, tutoriel).
func test_review_fixes(db: DataDB) -> void:
	print("[correctifs de revue]")
	# formatage : pas de « 1000 » ni de « 1000K », durées arrondies avant d'être découpées
	check(Fmt.num(999.7) == "1K", "999,7 -> 1K (%s)" % Fmt.num(999.7))
	check(Fmt.num(999400.0) == "999K", "999 400 -> 999K (%s)" % Fmt.num(999400.0))
	check(Fmt.num(999700.0) == "1M", "999 700 -> 1M (%s)" % Fmt.num(999700.0))
	check(Fmt.duration(119.7) == "2 min 00 s", "119,7 s (%s)" % Fmt.duration(119.7))
	check(Fmt.duration(59.6) == "1 min 00 s", "59,6 s (%s)" % Fmt.duration(59.6))
	check(Fmt.duration(3599.7) == "1 h 00 min", "3599,7 s (%s)" % Fmt.duration(3599.7))
	check(Fmt.duration(-5.0) == "0 s", "durée négative (%s)" % Fmt.duration(-5.0))
	# un contrat refusé n'est pas reproposé aussitôt
	var again := false
	for seed_i in 12:
		var cs := PortSim.new(db, 100 + seed_i)
		Objectives.refresh_offers(cs)
		for k in 6:
			if cs.contract_offers.is_empty():
				break
			var tpl := String(cs.contract_offers[0].tpl)
			Objectives.decline(cs, 0)
			for c in cs.contract_offers:
				if String(c.tpl) == tpl:
					again = true
	check(not again, "l'offre refusée ne revient pas immédiatement")
	# from_dict sur une instance déjà utilisée ne garde rien de l'ancienne partie
	var used := PortSim.new(db, 12)
	used.renown = 3
	used.prestiges = 2
	used.lifetime = {"evp": 5.0}
	used._assist_at[0] = 99.0
	used.last_income["gate"] = 12.0
	used.from_dict(PortSim.new(db, 1).to_dict())
	check(used.renown == 0 and used.prestiges == 0 and used.lifetime.is_empty(), "le prestige d'une ancienne partie est effacé")
	check(used._assist_at.is_empty() and used.last_income.is_empty(), "l'état temporaire est effacé")
	# une licence achetée se voit tout de suite dans la valeur par EVP
	var ls := PortSim.new(db, 13)
	ls.features["licences"] = true
	ls.money = 1.0e9
	var v0 := ls.stat("value", 0)
	ls.buy_licence(0, 1)
	check(ls.stat("value", 0) > v0, "la valeur par EVP suit l'achat de licence sans attendre le pas suivant")
	# gain d'un achat : la valeur de référence fournie donne le même résultat que le calcul seul
	var gs := PortSim.new(db, 14)
	for i in 60:
		gs.step(0.25)
	var base := gs.income_estimate_with("cranes", 0)
	check(is_equal_approx(gs.upgrade_gain("cranes", 3), gs.upgrade_gain("cranes", 3, -1, base)), "gain avec référence fournie identique")
	# tutoriel : on ne reste pas bloqué à « coup de main » si le chef des grutiers est déjà embauché
	var raw: Array = DataDB.load_json("res://data/tutorial.json")
	var crane_done := ""
	for st in raw:
		if st.id == "crane":
			crane_done = String(st.done)
	var e := Expression.new()
	e.parse(crane_done, ["sim"])
	gs.managers["cranes"] = true
	check(bool(e.execute([gs], null, false)), "l'étape « coup de main » se termine si Yasmine est embauchée")


## Début de partie doux : petits navires, gabarits de quai, douane à construire, fonctions révélées une à une.
func test_gentle_start(db: DataDB) -> void:
	print("[début de partie doux]")
	var s := PortSim.new(db, 21)
	check(s.ships.size() == 1 and s.ships[0].cls == String(db.ships[0].id) and s.ships[0].evp_total <= 30.0,
		"le premier navire est un petit porte-conteneurs (%s, %d EVP)" % [s.ships[0].cls, int(s.ships[0].evp_total)])
	check(s.rade_places() == 2, "rade de 2 places au départ")
	check(not s.customs_open and s.inspect_fraction(0) == 0.0, "pas d'inspection avant le bureau de douane")
	check(s.analysis.key == "attract" and s.analysis.building == "quay_ext", "le conseil désigne l'allongement du quai (%s / %s)" % [s.analysis.key, s.analysis.get("building", "")])
	s.money = 1.0e6
	check(not s.buy_licence(0, 1) and not s.hire_manager("cranes") and not s.start_boost(), "licences, responsables et Heures sup verrouillés au départ")
	check(s.buy_dept("cranes", 1) and not s.buy_dept("customs", 1), "Portiques achetables, Douane pas encore")
	var unlocked: Array[String] = []
	s.feature_unlocked.connect(func(id: String) -> void: unlocked.append(id))
	var owners := {}
	for i in 1200:
		s.step(0.25)
		for sh in s.ships:
			owners[sh.owner] = true
	check(not owners.has("grandlarge"), "aucun armateur étranger sans douane")
	check(s.contract_offers.is_empty() and s.counter("events") == 0.0, "ni contrat ni aléa pendant les 5 premières minutes")
	check(unlocked.has("manage") and s.feature("manage"), "Gestion se révèle après quelques escales (%s)" % ", ".join(unlocked))
	# l'allongement du quai multiplie le trafic et fait venir les caboteurs
	var d0 := s.stat("demand")
	check(s.build("quay_ext"), "allongement du quai construit")
	check(s.stat("demand") > d0 * 3.0, "le trafic grimpe (%s → %s EVP/s)" % [Fmt.num(d0), Fmt.num(s.stat("demand"))])
	var firsts: Array[String] = []      # un booléen local ne serait pas modifié par la fonction anonyme
	s.ship_class_first.connect(func(sh: Ship) -> void: firsts.append(sh.cls))
	for i in 2400:
		s.step(0.25)
		if s.counter("arrived_coaster") > 0.0:
			break
	check(s.counter("arrived_coaster") > 0.0 and firsts.has("coaster"), "un caboteur arrive, annoncé comme moment marquant")
	# bureau de douane : nouvel armateur, inspections, contrats
	s.money = 1.0e6
	var dem1 := s.stat("demand")
	s.build("gravel2")
	check(s.build("customs1") and s.customs_open and s.inspect_fraction(0) > 0.0, "le bureau de douane ouvre les inspections")
	check(s.stat("demand") > dem1 * 1.5 and s.feature("contracts") and s.feature("dept_customs"), "nouvel armateur (trafic ×%.1f), contrats et Douane révélés" % (s.stat("demand") / dem1))
	# sauvegarde d'avant la révélation progressive : rien n'est perdu, les caboteurs accostent toujours
	var old := PortSim.new(db, 5)
	old.ships[0].cls = "coaster"
	old.built.append("gravel2")
	var od: Dictionary = JSON.parse_string(JSON.stringify(old.to_dict()))
	od.erase("features")
	var m := PortSim.new(db, 6)
	m.from_dict(od)
	check(str(m.built.slice(0, 3)) == str(["quay_ext", "customs1", "gravel2"]), "ancienne sauvegarde : quai allongé et douane ajoutés (%s)" % str(m.built))
	check(m.max_depth() >= 2 and m.customs_open and m.feature("contracts") and m.feature("managers"), "ancienne sauvegarde : tout reste disponible")
	for i in 240:
		m.step(0.25)
	check(m.counter("ships") >= 1.0 or m.ships[0].state >= Ship.State.PILOTING, "le caboteur de l'ancienne sauvegarde accoste")
	var rt := PortSim.new(db, 7)
	rt.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(rt.features.size() == s.features.size(), "les fonctions révélées sont sauvegardées")


func test_commerce(db: DataDB) -> void:
	print("[commerce : démarchage, armateurs, lignes, plancher]")
	var s := PortSim.new(db, 31)
	s.money = 1.0e6
	# la Capitainerie pilote : elle ne fait plus venir de navires
	var d0 := s.stat("demand")
	var p0 := s.pilot_duration()
	s.buy_dept("harbor", 20)
	check(is_equal_approx(s.stat("demand"), d0) and s.pilot_duration() < p0, "Capitainerie : trafic inchangé, pilotage plus court")
	check(s.min_time("pilot") < float(db.cfg("pilot_time_min")), "chaque niveau abaisse le plancher de pilotage (%.2f s)" % s.min_time("pilot"))
	# campagne : réservée au Commerce, trafic temporaire, recharge
	check(not Commerce.start_campaign(s, "posters"), "pas de campagne avant la révélation du Commerce")
	s.features["commerce"] = true
	var d1 := s.stat("demand")
	check(Commerce.start_campaign(s, "posters") and is_equal_approx(s.stat("demand"), d1 * 1.5), "affiches : trafic ×1,5")
	check(not Commerce.start_campaign(s, "posters"), "une campagne en cours ne se relance pas")
	check(not Commerce.start_campaign(s, "journal"), "l'annonce au journal attend le bureau de douane")
	for i in 640:
		s.step(0.25)
	check(not s.mods.has("camp_posters") and not Commerce.campaign_ready(s, "posters"), "fin de campagne, puis recharge")
	# service aux navires : un bâtiment qui attire du trafic
	s.money = 1.0e6
	for bid in ["quay_ext", "gravel2", "customs1"]:
		s.build(bid)
	var d2 := s.stat("demand")
	check(s.build("supply") and is_equal_approx(s.stat("demand"), d2 * 1.2) and s.patience_mult > 1.0, "ponton d'avitaillement : trafic +20 %, patience")
	# T2 : armateurs à démarcher, lignes régulières
	s.tier = 2
	s.invalidate()
	check(not s.owner_present(db.owner_by_id["nordhaven"]) and Commerce.recruit_state(s, "nordhaven") == "available", "Nordhaven doit être démarché")
	var d3 := s.stat("demand")
	s.money = 1.0e9
	check(Commerce.recruit(s, "nordhaven") and s.stat("demand") > d3, "démarchage : Nordhaven fait escale, le trafic monte")
	var c1 := Commerce.line_cost(s, "corsaire")
	var d4 := s.stat("demand")
	check(Commerce.sign_line(s, "corsaire") and s.stat("demand") > d4 and Commerce.line_cost(s, "corsaire") > c1, "ligne régulière : trafic en hausse, la suivante coûte plus")
	Commerce.offer_line(s, "corsaire")
	check(is_equal_approx(Commerce.line_cost(s, "corsaire"), c1 * 2.0 * 0.5), "un contrat réussi : prochaine ligne à moitié prix")
	for i in 3:
		Commerce.sign_line(s, "corsaire")
	check(int(s.lines.corsaire) == 3 and not Commerce.line_available(s, "corsaire"), "au plus 3 lignes par armateur en T2")
	# objectif de contrat atteignable : part de l'armateur, pas tout le port
	var off := Objectives.make_offer(s, db.contract_by_id["c_nordhaven_1"])
	var full := s.sustainable_flow() * float(off.days) * float(db.cfg("day_seconds"))
	check(float(off.target) > 0.0 and float(off.target) < full * 0.8, "contrat : objectif à la portée de l'armateur (%s sur %s EVP possibles)" % [Fmt.num(float(off.target)), Fmt.num(full)])
	# sauvegarde : aller-retour, puis ancienne partie (version 2)
	var rt := PortSim.new(db, 8)
	rt.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(rt.lines.get("corsaire", 0) == 3 and rt.owners_on.has("nordhaven") and is_equal_approx(rt.stat("demand"), s.stat("demand")), "commerce sauvegardé")
	var od: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	for k in ["owners_on", "lines", "line_offers", "campaign_ready_at"]:
		od.erase(k)
	var m := PortSim.new(db, 9)
	m.from_dict(od)
	check(m.owners_on.has("nordhaven") and m.owners_on.has("sakura") and m.feature("commerce") and m.legacy_notice == "commerce",
		"ancienne partie T2 : armateurs gardés, Commerce révélé, message prévu")


## Écarts relevés face à Idle Supermarket Tycoon : licences à paliers finis et plafonnées, missions de guidage
## et coffre, étapes nommées, goulot visible pour le tutoriel, sauvegarde réelle.
func test_ism_gaps(db: DataDB) -> void:
	print("[écarts ISM]")
	var s := PortSim.new(db, 21)
	# paliers de licence finis : après le dernier, seul l'effet linéaire reste
	var steps: Array = db.cfg("licence_milestones")
	var last := int(steps[-1][0])
	var total := Progression.step_mult(10000, steps)
	check(is_equal_approx(Progression.step_mult(last, steps), total) and is_equal_approx(Progression.step_mult(last - 1, steps) * float(steps[-1][1]), total),
		"paliers de licence finis (%s au total)" % Fmt.mult(total))
	check(Progression.next_step(last, steps).is_empty() and int(Progression.next_step(1, steps)[0]) == int(steps[0][0]), "prochain palier de licence")
	check(s.licence_mult(last + 10) / s.licence_mult(last + 9) < 1.02, "au-delà des paliers, +1 niveau vaut moins de 2 %")
	# plafond du palier : on ne l'achète pas au-delà, le palier suivant le relève
	s.features["licences"] = true
	s.money = 1e30
	var cap1 := s.licence_cap()
	check(s.buy_licence(0, -1) and int(s.licences[0]) == cap1, "MAX s'arrête au plafond du palier (%d)" % cap1)
	check(not s.buy_licence(0, 1) and s.licence_room(0) == 0 and s.licence_max_affordable(0) == 0, "plus d'achat au plafond")
	s.tier = 2
	check(s.licence_cap() > cap1 and s.buy_licence(0, 1), "le palier T2 relève le plafond")
	# sauvegarde d'avant les plafonds : niveau ramené au plafond, excédent remboursé, une seule fois
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	d.tier = 1
	d.money = 0.0
	var lic: Array = d.licences
	lic[0] = cap1 + 10
	var m := PortSim.new(db, 22)
	m.from_dict(d)
	var refund := Progression.bulk_cost(float(db.cargo[0].licence_cost), float(db.cargo[0].licence_growth), cap1 - 1, 10)
	check(int(m.licences[0]) == cap1 and is_equal_approx(m.money, refund) and m.legacy_notice.begins_with("licences:"),
		"ancienne sauvegarde : licence ramenée au plafond, %s remboursés" % Fmt.money(refund))
	var m2 := PortSim.new(db, 23)
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check(is_equal_approx(m2.money, m.money) and m2.legacy_notice == "", "remboursement non répété au rechargement")
	# missions de guidage : bâtiment, prime en argent ; coffre toutes les N missions
	var g := PortSim.new(db, 24)
	g.features["missions"] = true
	var t1: Dictionary = {}
	for mi in db.missions:
		if mi.id == "t1":
			t1 = mi
	check(not t1.is_empty() and Objectives.mission_progress(g, t1) == 0.0, "mission « allonger le quai » en attente")
	g.money = 1000.0
	g.build("quay_ext")
	var m0 := g.money
	for i in 400:
		g.step(0.25)
	g.money = m0
	var a0 := g.amber
	check(Objectives.claim(g, "t1") and g.money > m0 and g.amber == a0 + 1, "mission de guidage : Ambre et prime en argent (%s)" % Fmt.money(g.money - m0))
	var ch: Dictionary = db.cfg("mission_chest")
	g.missions_claimed.clear()
	for i in int(ch.every) - 1:
		g.missions_claimed.append("x%d" % i)
	g.counters["evp"] = 1e6
	var a1 := g.amber
	Objectives.claim(g, "m1")
	check(bool(g.last_claim.get("chest", false)) and g.amber == a1 + int(db.missions[0].amber) + int(ch.amber), "coffre au bout de %d missions" % int(ch.every))
	check(Objectives.chest_progress(g) == Vector2i(0, int(ch.every)), "barre de coffre remise à zéro")
	# étapes nommées : une par palier, cohérentes avec les paliers de la config
	var bad := 0
	for dd in db.departments:
		var lv_ok := [1]
		for l in db.cfg("dept_milestones"):
			lv_ok.append(int(l))
		var got: Array = dd.get("stages", []).map(func(st): return int(st.lv))
		if got != lv_ok:
			bad += 1
			printerr("    étapes de %s : %s" % [dd.id, str(got)])
	for cd in db.cargo:
		var lv_ok2 := [1]
		for st2 in steps:
			lv_ok2.append(int(st2[0]))
		var got2: Array = cd.get("stages", []).map(func(st): return int(st.lv))
		if got2 != lv_ok2:
			bad += 1
			printerr("    étapes de %s : %s" % [cd.id, str(got2)])
	check(bad == 0, "une étape nommée par palier (départements et licences)")
	var w := PortSim.new(db, 25)
	w.levels["cranes"] = 30
	check(w.dept_stage("cranes") == 2 and w.dept_stage("gate") == 0, "éléments du monde : un par palier franchi")
	# tutoriel : après l'allongement du quai, un vrai bouchon (navire qui attend en rade) se forme vite
	var t := PortSim.new(db, 26)
	var bot := Bot.new(t)
	var t_quay := -1.0
	var t_jam := -1.0
	while t.time < 1200.0 and t_jam < 0.0:
		bot.run(5.0)
		if t_quay < 0.0 and t.built.has("quay_ext"):
			t_quay = t.time
		if t_quay >= 0.0 and t.longest_wait() >= 6.0:
			t_jam = t.time
	check(t_quay > 0.0 and t_jam > 0.0 and t_jam - t_quay < 240.0, "goulot visible %s après le quai allongé" % Fmt.duration(t_jam - t_quay))
	# copie de la vraie sauvegarde du joueur (si présente) : elle se charge et tourne
	var real := OS.get_environment("PH_SAVE_COPY")
	if real != "" and FileAccess.file_exists(real):
		var sd: Variant = JSON.parse_string(FileAccess.get_file_as_string(real))
		var r := PortSim.new(db, 27)
		r.from_dict(sd.sim)
		var e0 := r.counter("evp")
		for i in 2400:
			r.step(0.25)
		check(r.counter("evp") > e0 and r.money >= 0.0, "copie de la vraie sauvegarde : chargée, 10 min jouées (licences %s)" % str(Array(r.licences)))


func test_lot_b(db: DataDB) -> void:
	print("[lot B : chargeur tolérant, bulles, débogage coupé]")
	# un modèle absent n'arrête pas la construction du monde : nœud vide, avertissement unique, MultiMesh ignoré
	var n0 := Assets.missing.size()
	var ghost := Assets.instance("modele_absent_test")
	var ghost2 := Assets.instance("modele_absent_test")
	check(ghost != null and ghost.get_child_count() == 0 and ghost2 != null and Assets.mesh("modele_absent_test") == null
		and Assets.missing.size() == n0 + 1 and Assets.top_y("modele_absent_test") == 0.0,
		"un modèle absent n'arrête pas la construction du monde (nœud vide, 1 avertissement)")
	ghost.free()
	ghost2.free()
	# les accessoires attendus de Blender sont déjà placés (bollards tous les 4 u le long du quai n°1)
	var qp := Layout.quay_props(1, true, 1)
	var bollards := qp.filter(func(it: Dictionary) -> bool: return it.m == "bollard")
	check(bollards.size() == 9 and qp.any(func(it: Dictionary) -> bool: return it.m == "ladder")
		and Layout.street_props(1, []).any(func(it: Dictionary) -> bool: return it.m == "sidewalk"),
		"emplacements préparés : %d bollards sur le quai n°1, échelles, trottoirs" % bollards.size())
	# la bulle d'un bâtiment est au-dessus de son anchor_y (boîte englobante + 0,4 tant que assets_meta.json ne le donne pas)
	var ay := Assets.anchor_y("customs_hut")
	var top := Assets.aabb("customs_hut").end.y
	check(top > 1.0 and ay >= top - 0.01 and Bubbles.anchor_point("customs_hut", Layout.CUSTOMS_HUT).y >= Layout.CUSTOMS_HUT.y + top,
		"la bulle de la douane est au-dessus de son anchor_y (%.1f u, toit à %.1f u)" % [ay, top])
	# deux bulles qui se chevauchent sont décalées latéralement
	var a := Rect2(100, 100, 200, 54)
	var b := Bubbles.settle(Rect2(150, 110, 200, 54), [a])
	check(not b.intersects(a) and b.position.y == 110.0, "deux bulles qui se chevauchent sont décalées latéralement (x %d → %d)" % [150, int(b.position.x)])
	# hors debug, --debug-money (et les autres triches) sont ignorés ; en debug, appliqués
	var s := PortSim.new(db, 31)
	var m0 := s.money
	var r := DebugArgs.apply({"debug-money": "1e6", "tier": "3", "levels": "40", "speed": "10"}, s, db, false)
	check(is_equal_approx(s.money, m0) and s.tier == 1 and int(s.levels.cranes) < 40 and r.applied.is_empty() and float(r.speed) < 0.0,
		"hors debug, --debug-money, --tier, --levels et --speed sont ignorés")
	var r2 := DebugArgs.apply({"debug-money": "1e6"}, s, db, true)
	check(s.money > m0 + 999999.0 and r2.applied.has("debug-money"), "en debug, --debug-money s'applique")
