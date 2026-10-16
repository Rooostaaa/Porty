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
	# --only=nom : ne lance qu'un test (mise au point) ; sans argument, tous les tests
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			call("test_" + a.substr(7), db)
			print("=== %d ok, %d échec(s) ===" % [passes, failures])
			quit(1 if failures > 0 else 0)
			return
	# --part=1|2|3 (lot F1) : un tiers des tests, pour rester sous 5 min par processus ; sans argument, tous
	var part := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			part = int(a.substr(7))
	if part == 0 or part == 1:
		_part1(db)
	if part == 0 or part == 2:
		_part2(db)
	if part == 0 or part == 3:
		_part3(db)
	print("=== %d ok, %d échec(s) ===" % [passes, failures])
	quit(1 if failures > 0 else 0)


func _part1(db: DataDB) -> void:
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


func _part2(db: DataDB) -> void:
	test_plan_baie(db)
	test_trajets()
	test_chapitres(db)
	test_revue_baie(db)
	test_revue2_baie(db)
	test_revue2_rythme(db)
	test_c7(db)


func _part3(db: DataDB) -> void:
	test_d_monde(db)
	test_d_ui(db)
	test_d_eco(db)
	test_e_confiance(db)
	test_e_flux(db)
	test_f2(db)
	test_f3(db)
	test_g2(db)


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
	# lot G2 (remplace « coup de main sur la grue », × 4) : le coup de main ×1,2 est retiré — un responsable remplace le geste ;
	# les gestes du terre-plein (tamponner, laisser passer) sont contrôlés dans test_g2
	var tried := false
	for i in 480:
		b.step(0.25)
		tried = tried or b.assist_ready(0) or b.yard_boost_ready() or b.gate_rush_ready()
	check(not tried and b.assist_unload(0) == 0.0 and b.yard_boost() == 0.0 and b.gate_rush() == 0.0,
		"G2 : les anciens gestes (coup de main à la grue, engin du parc, barrière express) sont retirés")


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
	check(b.tier == 1 and b.built == PortSim.STARTERS and is_equal_approx(b.money, float(db.cfg("start_money"))), "on repart de zéro (lot G2, recalé : un port complet garde ses six pièces du départ)")
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
	used.truck_wait_t = 9.0      # (lot G2 : attente du camion en tête, à la place du minuteur du coup de main)
	used.last_income["gate"] = 12.0
	used.from_dict(PortSim.new(db, 1).to_dict())
	check(used.renown == 0 and used.prestiges == 0 and used.lifetime.is_empty(), "le prestige d'une ancienne partie est effacé")
	check(used.truck_wait_t == 0.0 and used.last_income.is_empty(), "l'état temporaire est effacé")
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
	# tutoriel (lot G2, remplace « l'étape coup de main se termine si Yasmine est embauchée » : l'étape n'existe plus) : on ne
	# reste pas bloqué à « tamponner » ou « laisser passer » si leur responsable est déjà embauché
	var raw: Array = DataDB.load_json("res://data/tutorial.json")
	var ok_steps := 0
	var gm := PortSim.new(db, 4)
	gm.begin_act0()
	gm.open_port()
	gm.managers["customs"] = true
	gm.managers["gate"] = true
	for st in raw:
		if String(st.id) in ["t_stamp", "t_pass"]:
			var e := Expression.new()
			e.parse(String(st.done), ["sim"])
			if bool(e.execute([gm], null, false)):
				ok_steps += 1
	check(ok_steps == 2, "G2 : les étapes « tamponner » et « laisser passer » se terminent si Paul et Tonio sont embauchés (%d/2)" % ok_steps)


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
	# chapitres : le Parc puis la première responsable arrivent quand la grue atteint le niveau 10 (plus au nombre
	# d'escales), un sujet à la fois ; Gestion vient avec la gate (revue du 13/10 : un sujet par seuil)
	var before_manage := s.feature("manage")
	s.buy_dept("cranes", 10 - int(s.levels.cranes))
	s.check_unlocks()
	var only_parc := s.feature("dept_yard_ops") and not s.feature("managers")
	for i in 280:      # 60 s (ou 20 s si le Parc a servi, revue N8)
		s.step(0.25)
	check(not before_manage and only_parc and s.manager_revealed("cranes") and not s.manager_revealed("harbor") and not s.feature("manage"),
		"le Parc, puis (60 s plus tard, ou 20 s s'il a servi) Yasmine Okafor, se révèlent quand la grue atteint le niveau 10 ; Gestion attend la gate (%s)" % ", ".join(unlocked))
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
	var dem2 := s.stat("demand")
	var customs_first := s.feature("dept_customs") and not s.feature("contracts")
	for i in 280:      # un sujet à la fois : les contrats suivent la Douane (60 s, ou 20 s si elle a servi)
		s.step(0.25)
	check(dem2 > dem1 * 1.5 and customs_first and s.feature("contracts") and s.feature("dept_customs"), "nouvel armateur (trafic ×%.1f), la Douane puis les contrats révélés" % (dem2 / dem1))
	# sauvegarde d'avant la révélation progressive : rien n'est perdu, les caboteurs accostent toujours
	var old := PortSim.new(db, 5)
	old.ships[0].cls = "coaster"
	old.built.append("gravel2")
	var od: Dictionary = JSON.parse_string(JSON.stringify(old.to_dict()))
	od.erase("features")
	var m := PortSim.new(db, 6)
	m.from_dict(od)
	check(str(m.built.slice(6, 9)) == str(["quay_ext", "customs1", "gravel2"]) and m.built.slice(0, 6) == PortSim.STARTERS, "ancienne sauvegarde : quai allongé et douane ajoutés après les pièces du départ (lot G2, recalé) (%s)" % str(m.built))
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
	check(is_equal_approx(Commerce.line_cost(s, "corsaire"), c1 * float(db.cfg("line_cost_growth")) * 0.5), "un contrat réussi : prochaine ligne à moitié prix")
	var nmax := Commerce.max_lines(s)
	for i in nmax:
		Commerce.sign_line(s, "corsaire")
	check(int(s.lines.corsaire) == nmax and nmax == int(db.cfg("lines_per_owner")[1]) and not Commerce.line_available(s, "corsaire"), "au plus %d lignes par armateur en T2" % nmax)
	# objectif de contrat atteignable : part de l'armateur, pas tout le port
	var off := Objectives.make_offer(s, db.contract_by_id["c_nordhaven_1"])
	var full := s.sustainable_flow() * float(off.days) * float(db.cfg("day_seconds"))
	check(float(off.target) > 0.0 and float(off.target) < full * 0.8, "contrat : objectif à la portée de l'armateur (%s sur %s EVP possibles)" % [Fmt.num(float(off.target)), Fmt.num(full)])
	# sauvegarde : aller-retour, puis ancienne partie (version 2)
	var rt := PortSim.new(db, 8)
	rt.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(rt.lines.get("corsaire", 0) == nmax and rt.owners_on.has("nordhaven") and is_equal_approx(rt.stat("demand"), s.stat("demand")), "commerce sauvegardé")
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
	# le quai est désormais le premier achat (à 1 s) : le bouchon se mesure en temps de jeu (avant : quai vers 1 min 30,
	# bouchon moins de 4 min après, soit avant 5 min 30 de jeu ; même borne, 6 min)
	check(t_quay > 0.0 and t_jam > 0.0 and t_jam < 360.0, "goulot visible %s après le quai allongé (à %s de jeu)" % [Fmt.duration(t_jam - t_quay), Fmt.duration(t_jam)])
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


func test_plan_baie(db: DataDB) -> void:
	print("[plan de la baie : cases, zones, terrain]")
	# chaque bâtiment a sa case, dans le polygone de sa zone (ou dans l'eau pour ce qui est à flot)
	var missing: Array[String] = []
	var outside: Array[String] = []
	for b in db.buildings:
		var bid := String(b.id)
		if not Layout.LOTS.has(bid):
			missing.append(bid)
			continue
		var l: Dictionary = Layout.LOTS[bid]
		var z := Layout.zone_by_id(int(l.zone))
		var p: Vector3 = l.p
		var poly := Layout.zone_poly(z)
		var in_zone := not poly.is_empty() and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), PackedVector2Array(poly))
		var ok := in_zone
		if bool(l.get("water", false)):
			ok = not Layout.on_land(Vector2(p.x, p.z), true) and (in_zone or int(l.zone) == 1)
		if not ok:
			outside.append(bid)
	check(missing.is_empty() and Layout.LOTS.size() == db.buildings.size(), "chaque bâtiment a une case (%d/%d, manquent %s)" % [Layout.LOTS.size(), db.buildings.size(), str(missing)])
	check(outside.is_empty(), "chaque case est dans sa zone (hors zone : %s)" % str(outside))
	# aucune empreinte n'en chevauche une autre (sauf ce qui est posé sur un quai : grues, taquets)
	var overlaps: Array[String] = []
	var ids: Array = Layout.LOTS.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a := String(ids[i])
			var c := String(ids[j])
			if Layout.LOTS[a].has("on") or Layout.LOTS[c].has("on"):
				continue
			if Layout.lot_rect(a).grow(-0.05).intersects(Layout.lot_rect(c).grow(-0.05)):
				overlaps.append("%s/%s" % [a, c])
	check(overlaps.is_empty(), "aucun chevauchement d'empreintes (%s)" % str(overlaps))
	# zones : polygones simples, une zone par id, chaque zone à bâtiment clé a ce bâtiment dans sa propre zone
	var bad_zone := 0
	for z in Layout.ZONES:
		var k := String(z.get("key", ""))
		if k != "" and (not Layout.LOTS.has(k) or int(Layout.LOTS[k].zone) != int(z.id)):
			bad_zone += 1
		if Geometry2D.triangulate_polygon(PackedVector2Array(Layout.zone_poly(z))).is_empty():
			bad_zone += 1
	check(bad_zone == 0, "zones cohérentes (bâtiment clé dans sa zone, polygone valide)")
	# texture de distance : négative sur la terre, positive sur l'eau ; le terre-plein la change
	var f0 := Terrain.distance_field(Layout.land_polys(false))
	var f1 := Terrain.distance_field(Layout.land_polys(true))
	var land_pts := [Vector2(-43, 6), Vector2(-80, 100), Vector2(-74, -30), Vector2(20, 20), Vector2(19, -44)]
	var sea_pts := [Vector2(-56, -57), Vector2(-30, -60), Vector2(-26, -22), Vector2(100, -40), Vector2(-150, -100), Vector2(100, 10)]
	var neg := land_pts.all(func(p: Vector2) -> bool: return Terrain.field_at(f0, p) < 0.0)
	var pos := sea_pts.all(func(p: Vector2) -> bool: return Terrain.field_at(f0, p) > 0.0)
	check(neg and pos, "distance au rivage : négative sur la terre, positive sur l'eau")
	check(Terrain.field_at(f0, Vector2(100, 10)) > 0.0 and Terrain.field_at(f1, Vector2(100, 10)) < 0.0 and Terrain.field_at(f1, Vector2(100, -30)) > 0.0,
		"le terre-plein change l'eau en terre (et seulement lui)")
	# une seule zone prochaine à tout instant, états cohérents avec les bâtiments, sur 4 parties de bot jusqu'à la fin
	var worst_next := 0
	var incoherent := 0
	var finished := 0
	for seed_v in [1, 2, 3, 4]:
		var s := PortSim.new(db, seed_v)
		var bot := Bot.new(s)
		while s.time < 3.0 * 3600.0 and not s.finished:
			bot.run(20.0)
			var n_next := 0
			for z in Layout.ZONES:
				var st := Zones.state(s, z)
				if st == Zones.NEXT:
					n_next += 1
					if String(z.key) != Zones.first_unbuilt(s):
						incoherent += 1
				var k := String(z.get("key", ""))
				if k != "" and (st == Zones.OPEN) != s.built.has(k):
					incoherent += 1
			worst_next = maxi(worst_next, n_next)
		if s.finished:
			finished += 1
	check(worst_next <= 1 and incoherent == 0 and finished == 4, "une seule zone prochaine à tout instant, états cohérents (4 parties, max %d, incohérences %d)" % [worst_next, incoherent])
	# décor : ce qui flotte est sur l'eau, le reste sur la terre (terre-plein compris)
	var wrong: Array[String] = []
	for p in Layout.PROPS:
		var pp: Array = p.p
		var v := Vector2(float(pp[0]), float(pp[1]))
		v = Vector2(float(pp[0]), float(pp[2]))
		var afloat := float(pp[1]) < -0.5 and String(p.m) != "rock"
		var land := Layout.on_land(v, true)
		if afloat == land and String(p.m) != "rock":
			wrong.append("%s(%d,%d)" % [p.m, int(pp[0]), int(pp[2])])
	for d in Layout.STAGE_PROPS:
		for it in Layout.STAGE_PROPS[d]:
			var pp2: Array = it.p
			var v2 := Vector2(float(pp2[0]), float(pp2[2]))
			if (float(pp2[1]) < -0.5) == Layout.on_land(v2, false):
				wrong.append("%s(%d,%d)" % [it.m, int(pp2[0]), int(pp2[2])])
	for k in 24:
		if Layout.on_land(Vector2(Layout.anchor_pos(k).x, Layout.anchor_pos(k).z), true):
			wrong.append("mouillage %d" % k)
	check(wrong.is_empty(), "bateaux et bouées sur l'eau, bâtiments sur la terre (%s)" % str(wrong))
	# cadrage d'ouverture : chaque zone tient dans un écran portrait (largeur visible raisonnable)
	var zooms: Array = []
	for z in Layout.ZONES:
		zooms.append(roundi(float(Zones.focus(z).zoom)))
	check(zooms.all(func(zz: int) -> bool: return zz >= 36 and zz <= 120), "cadrage de chaque zone à l'ouverture (largeurs %s)" % str(zooms))


## Tous les trajets du plan sont échantillonnés tous les 1,5 u (navires, camions, engins, personnages).
## Tolérances (documentées dans DECISIONS « Plan de la baie ») : navire à 2,5 u au moins de toute terre (demi-largeur d'un
## caboteur), sauf à son poste ; camions et engins sur la terre ; aucun véhicule dans l'empreinte d'un bâtiment (les parcs
## sont traversés par leurs allées, le portique scanner par la voie d'entrée) ; engins à plus de 1,75 u des camions (au point
## de chargement, la remorque touche le bord du parc) et jamais sur la bande de la voie des camions ; personnages à plus de
## 2,5 u des camions et de 1,2 u des engins.
func test_trajets() -> void:
	print("[trajets : navires, camions, engins, personnages]")
	var t0 := Time.get_ticks_msec()
	var field := Terrain.distance_field(Layout.land_polys(true))
	var field_t1 := Terrain.distance_field(Layout.land_polys(false))
	var ms := Time.get_ticks_msec() - t0
	# navires
	var ship_bad: Array[String] = []
	var widths := [4.2, 5.4, 8.0, 8.8]
	for k in 24:
		var paths := {"arrivée": Layout.ship_path_arrive(k), "départ furieux": Layout.ship_path_leave(Layout.anchor_pos(k))}
		for bi in 4:
			paths["pilotage %d" % bi] = Layout.ship_path_pilot(k, bi)
		for key in paths:
			for p in Layout.sample_path(paths[key], 1.5):
				if Terrain.field_at(field, Vector2(p.x, p.z)) < 2.5:
					ship_bad.append("%s %d (%d, %d)" % [key, k, int(p.x), int(p.z)])
					break
	for bi in 4:
		for w in widths:
			# départs : par la passe aux paliers 1–2 (postes 1 et 2), par l'est au palier 3
			for tr in ([1, 3] if bi < 2 else [3]):
				var pts := Layout.sample_path(Layout.ship_path_depart(bi, w, tr), 1.5)
				for i in range(3, pts.size()):
					if Terrain.field_at(field if tr >= 3 else field_t1, Vector2(pts[i].x, pts[i].z)) < 2.5:
						ship_bad.append("départ %d T%d (%d, %d)" % [bi, tr, int(pts[i].x), int(pts[i].z)])
						break
		# un navire qui va au poste bi ne traverse jamais un autre poste occupé
		for k in 12:
			for p in Layout.sample_path(Layout.ship_path_pilot(k, bi), 1.5):
				for bj in 4:
					var b: Dictionary = Layout.BERTHS[bj]
					if bj != bi and p.x > float(b.x0) and p.x < float(b.x1) and p.z > Layout.SEA_EDGE_Z - 11.0:
						ship_bad.append("pilotage %d traverse le poste %d" % [bi, bj])
	check(ship_bad.is_empty(), "navires : jamais sur la terre, le brise-lames ni un autre poste (%s)" % str(ship_bad.slice(0, 4)))
	# revue du 13/10 (décision 2) : aux paliers 1–2, les navires repartent par la passe, sur la voie de sortie du chenal,
	# sans croiser la voie d'entrée (≥ 4 u entre les deux dans le chenal), et ne vont jamais à l'est ; au palier 3, par l'est
	var lane_bad: Array[String] = []
	var bw_x0 := float(Layout.BREAKWATER[0].x)
	for bi in 2:
		var dep := Layout.sample_path(Layout.ship_path_depart(bi, 8.0, 1), 1.0)
		var crossed_pass := false
		for p in dep:
			if p.x > 60.0:
				lane_bad.append("départ T1 à l'est (%d, %d)" % [int(p.x), int(p.z)])
				break
			if p.z < Layout.PASS_Z - 1.0 and p.z > Layout.PASS_Z - 3.0 and p.x < bw_x0 and p.x > float(Layout.LIGHT_GREEN.x):
				crossed_pass = true
		if not crossed_pass:
			lane_bad.append("départ T1 du poste %d hors de la passe" % bi)
		for k in 12:
			var inb := Layout.sample_path(Layout.ship_path_pilot(k, bi), 1.0)
			for p in dep:
				if p.z > -96.0 and p.z < -36.0:      # dans le chenal et la passe (lot F1, recalé : -24 → -36 ; au bassin, z > -36, l'arrivée coupe la voie de départ sous la règle de la fenêtre « ouest », comme au lot E)
					for q in inb:
						if q.z > -96.0 and q.z < -36.0 and Vector2(p.x - q.x, p.z - q.z).length() < 4.0:
							lane_bad.append("croisement mouillage %d / poste %d (%d, %d)" % [k, bi, int(p.x), int(p.z)])
							break
					if lane_bad.size() > 3:
						break
	var east_t3 := Layout.ship_path_depart(2, 8.0, 3)      # (lot D : recalé sur le poste 3 — les postes 1–2 gardent la passe ouest)
	check(lane_bad.is_empty() and (east_t3[-1] as Vector3).x > 150.0,
		"navires : aux paliers 1–2, sortie par la passe sur la voie de sortie, sans croiser la voie d'entrée ; par l'est au palier 3 (%s)" % str(lane_bad.slice(0, 3)))
	# rectangles des bâtiments que les véhicules ne doivent pas traverser
	var walls: Array[Rect2] = []
	for bid in Layout.LOTS:
		var l: Dictionary = Layout.LOTS[bid]
		# (lot G2, recalé : la plateforme, le quai n°1 et la piste sont des sols, pas des murs)
		if l.has("on") or bool(l.get("portal", false)) or bool(l.get("water", false)) or bool(l.get("ground", false)) or bid in ["gravel2", "gravel3", "asphalt", "rtg", "parking1", "parking2", "quay_ext", "berth2", "berth3", "berth4", "dredge1"]:
			continue
		walls.append(Layout.lot_rect(bid))
	for m in ["harbor_office", "hangar", "control_tower"]:
		for p in Layout.PROPS:
			if p.m == m:
				var bb := Assets.aabb(m)
				var pp: Array = p.p
				var ry := int(roundf(float(p.get("ry", 0.0))))
				var sz := Vector2(bb.size.x, bb.size.z) if ry % 180 == 0 else Vector2(bb.size.z, bb.size.x)
				walls.append(Rect2(Vector2(float(pp[0]), float(pp[2])) - sz * 0.5, sz))
	# camions : tous les paliers, avec et sans la gate à deux voies, arrêts sur toute la boucle
	var truck_pts: Array[Vector3] = []
	var truck_bad: Array[String] = []
	# (lot E-Flux, E10 — recalé : la vraie file à une seule voie d'entrée, road_in_x(gate2), les arrêts possibles de
	# Layout.stop_range ; avec gate2, les **deux** voies de sortie, chacune sous un scanner à portique quand il est construit)
	var no_portal := 0
	for tier in [1, 2, 3]:
		for gate2 in [false, true]:
			var in_x := Layout.road_in_x(gate2)
			var portals := Layout.portal_rects(["scanner2", "gate2"] if gate2 else ["scanner2"])
			var rg := Layout.stop_range(tier, gate2)
			var x: float = rg[0]
			while x <= float(rg[1]) + 0.01:
				var routes := [Layout.truck_route_in(in_x, x)]
				for lane in ([0, 1] if gate2 else [0]):
					routes.append(Layout.truck_route_out(x, tier, gate2, lane))
				for ri in routes.size():
					var under := ri == 0
					for p in Layout.sample_path(routes[ri], 1.5):
						truck_pts.append(p)
						var f := Terrain.field_at(field if tier >= 3 else field_t1, Vector2(p.x, p.z))
						if f > 0.0:
							truck_bad.append("eau (%d, %d)" % [int(p.x), int(p.z)])
						for w in walls:
							if w.grow(-0.2).has_point(Vector2(p.x, p.z)):
								truck_bad.append("bâtiment (%d, %d)" % [int(p.x), int(p.z)])
						for pr in portals:
							if (pr as Rect2).has_point(Vector2(p.x, p.z)):
								under = true
					if not under:
						no_portal += 1
				x += 4.4
	for gate2 in [false, true]:
		var lots := 16 if gate2 else 0
		for i in 9 + lots:
			var road_z := Layout.QUEUE_Z0 + float(i if i < 5 else i - lots) * Layout.QUEUE_GAP
			var slot := Vector3(Layout.road_in_x(gate2), 0, road_z) if i < 5 or i >= 5 + lots else Layout.lot_slot(i - 5)
			for p in Layout.sample_path(Layout.truck_route_arrive(Layout.road_in_x(gate2), slot), 1.5):
				truck_pts.append(p)
				if Terrain.field_at(field_t1, Vector2(p.x, p.z)) > 0.0:
					truck_bad.append("eau (%d, %d)" % [int(p.x), int(p.z)])
	check(truck_bad.is_empty() and no_portal == 0, "camions : sur la terre, hors des bâtiments, du tunnel ouest au tunnel est ; chaque voie de sortie sous un portique (%d sans) (%s)" % [no_portal, str(truck_bad.slice(0, 4))])
	# engins : du tablier aux blocs réels, des blocs au bord du parc, retour
	var eng_pts: Array[Vector3] = []
	var eng_bad: Array[String] = []
	for b in Layout.BLOCKS:
		if int(b.zone) != 0:
			continue
		for i in int(b.bays):
			var xs := float(b.x) + 2.0 + i * 4.4
			for xa in [-30.0, -10.0, 10.0, 30.0, 70.0, 120.0]:
				for r in [Layout.engine_route_to_block(xa, xs), Layout.engine_route_to_truck(xs), Layout.engine_route_back(xs, xa)]:
					for p in Layout.sample_path(r, 1.5):
						eng_pts.append(p)
						if p.z > Layout.LANE_BAND[0] - 0.6:
							eng_bad.append("voie des camions (%d, %d)" % [int(p.x), int(p.z)])
						if Terrain.field_at(field, Vector2(p.x, p.z)) > 0.0:
							eng_bad.append("eau (%d, %d)" % [int(p.x), int(p.z)])
						for w in walls:
							if w.has_point(Vector2(p.x, p.z)):
								eng_bad.append("bâtiment (%d, %d)" % [int(p.x), int(p.z)])
	var tgrid := _grid_of(truck_pts)
	var egrid := _grid_of(eng_pts)
	var near := INF
	for p in eng_pts:
		near = minf(near, _min_dist(tgrid, p))
	check(eng_bad.is_empty() and near >= 1.75, "engins : côté mer, hors des bâtiments, jamais sur le trajet des camions (au plus près %.2f u) %s" % [near, str(eng_bad.slice(0, 3))])
	# personnages : aucun sur le trajet d'un camion ou d'un engin
	var walks: Array = []
	for i in 3:
		var a := Vector3(-33.0 + i * 9.0, 0.8, -4.2)
		walks.append([a, a + Vector3(5, 0, 0)])
	walks.append([Vector3(-46.5, 0.8, -4.5), Vector3(-41.5, 0.8, -4.5)])
	walks.append([Layout.CUSTOMS_HUT + Vector3(2, 0, 4.2), Layout.CUSTOMS_HUT + Vector3(-2, 0, 4.2)])
	for d in PortSim.DEPTS:
		for tier in [1, 2]:
			var mp := Layout.manager_pos(d, tier)
			walks.append([mp, mp + Layout.MANAGER_WALK.get(d, Vector3(0, 0, 2))])
	for d in Layout.STAGE_PROPS:
		for it in Layout.STAGE_PROPS[d]:
			if it.has("walk"):
				var pp: Array = it.p
				var a2 := Vector3(float(pp[0]), float(pp[1]), float(pp[2]))
				walks.append([a2, a2 + Vector3(float(it.walk[0]), 0, float(it.walk[1]))])
	var people_bad: Array[String] = []
	for w2 in walks:
		for p in Layout.sample_path(w2, 0.5):
			var hit := ""
			if _min_dist(tgrid, p) < 2.5:
				hit = "camion"
			elif _min_dist(egrid, p) < 1.2:
				hit = "engin"
			if hit == "":
				for w in walls:
					if w.has_point(Vector2(p.x, p.z)):
						hit = "bâtiment"
						break
			if hit != "":
				people_bad.append("%s (%d, %d)" % [hit, int(p.x), int(p.z)])
				break
	check(people_bad.is_empty(), "personnages : ni sur les voies des camions et des engins, ni dans un bâtiment (%s)" % str(people_bad.slice(0, 4)))
	check(ms < 2000, "terrain : deux textures de distance calculées en %d ms" % ms)


## Grille de 3 u (x, z) -> points : recherche du plus proche voisin pour les tests de trajets.
func _grid_of(pts: Array[Vector3]) -> Dictionary:
	var g := {}
	for p in pts:
		var k := Vector2i(floori(p.x / 3.0), floori(p.z / 3.0))
		if not g.has(k):
			g[k] = []
		(g[k] as Array).append(Vector2(p.x, p.z))
	return g


## Distance au point le plus proche de la grille (cherché dans les 9 cases voisines, sinon INF).
func _min_dist(g: Dictionary, p: Vector3) -> float:
	var best := INF
	var k0 := Vector2i(floori(p.x / 3.0), floori(p.z / 3.0))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for q in g.get(k0 + Vector2i(dx, dz), []):
				best = minf(best, (q as Vector2).distance_to(Vector2(p.x, p.z)))
	return best


func test_chapitres(db: DataDB) -> void:
	print("[chapitres du palier 1, gestes optionnels du parc et de la gate]")
	var s := PortSim.new(db, 41)
	# conditions nouvelles : niveau d'un service, responsable embauché, l'une ou l'autre
	check(not s.unlock_ok({"level": {"dept": "cranes", "min": 10}}) and s.unlock_text("dept_yard_ops").contains("(1/10)"),
		"condition « niveau 10 des Portiques » expliquée (%s)" % s.unlock_text("dept_yard_ops"))
	s.levels["cranes"] = 10
	s.managers["gate"] = true
	check(s.unlock_ok({"level": {"dept": "cranes", "min": 10}}) and s.unlock_ok({"manager": "gate"}) and not s.unlock_ok({"manager": "yard_ops"})
		and s.unlock_ok({"any": [{"manager": "yard_ops"}, {"level": {"dept": "cranes", "min": 5}}]}), "conditions de niveau, de responsable et « l'une ou l'autre »")
	# au départ : la grue et le poste de la capitainerie seulement
	var f := PortSim.new(db, 42)
	var hidden := ["dept_yard_ops", "dept_gate", "licences", "missions", "commerce", "boost", "managers", "manage", "stats", "events"]
	check(hidden.all(func(id: String) -> bool: return not f.feature(id)) and f.feature("dept_cranes") and f.feature("dept_harbor") and f.feature("dept_berths"),
		"chapitre 1 : seuls la grue et la capitainerie (deux services) sont présentés")
	# les chapitres s'ouvrent au niveau 10 du service précédent, les responsables un par un
	# (un sujet à la fois : chaque révélation ordinaire attend reveal_gap secondes, on fait avancer l'horloge)
	f.levels["cranes"] = 10
	_reveal_for(f, 120)
	var ch2 := f.feature("dept_yard_ops") and f.feature("managers") and not f.feature("dept_gate") and f.manager_revealed("cranes") and not f.manager_revealed("yard_ops")
	f.levels["yard_ops"] = 10
	_reveal_for(f, 120)
	var ch3 := f.feature("dept_gate") and f.feature("manage") and not f.feature("commerce")
	f.levels["gate"] = 10
	_reveal_for(f, 400)
	var ch4 := f.feature("commerce") and f.feature("missions") and f.feature("stars") and f.feature("licences") and not f.feature("boost")
	f.tier = 2
	_reveal_for(f, 450)      # lot D-Éco : statistiques et aléas espacés de 150 s
	check(ch2 and ch3 and ch4 and f.feature("boost") and f.feature("events") and f.feature("stats"),
		"chapitres : parc (grue 10), gate (parc 10), navires (gate 10), puis le palier 2 (Heures sup, aléas, statistiques)")
	# un sujet par seuil : aucune condition partagée, et sur 4 parties de bot, deux révélations ordinaires sont toujours
	# espacées d'au moins reveal_gap secondes (seules celles qui ouvrent un chapitre passent tout de suite)
	var conds := {}
	var shared := 0
	for u in db.unlocks:
		var ck := JSON.stringify(u.get("when", {}))
		shared += 1 if conds.has(ck) else 0
		conds[ck] = true
	var gap_cfg := float(db.cfg("reveal_gap_min", 0.0))      # 60 s, ou 20 s si la précédente a servi (revue N8)
	var worst_gap := INF
	var together := 0
	for seed_r in [1, 2, 3, 4]:
		var pr := PortSim.new(db, seed_r)
		var bot_r := Bot.new(pr)
		var times: Array = []
		pr.feature_unlocked.connect(func(id: String) -> void: times.append([pr.time, id]))
		while pr.tier < 2 and pr.time < 1800.0:
			bot_r.run(5.0)
		for i in range(1, times.size()):
			var dt: float = float(times[i][0]) - float(times[i - 1][0])
			if dt < 0.5:
				together += 1
			if not bool(db.unlock_by_id[String(times[i][1])].get("opens_chapter", false)):
				worst_gap = minf(worst_gap, dt)
	check(shared == 0 and together == 0 and worst_gap >= gap_cfg - 0.01,
		"un sujet par seuil : conditions distinctes, jamais deux révélations ensemble, %s s au moins avant une révélation ordinaire (min %s s, 4 parties)" % [Fmt.num(gap_cfg), Fmt.num(worst_gap)])
	f.money = 1.0e9
	check(not f.hire_manager("harbor") and f.hire_manager("cranes"), "un responsable ne s'embauche qu'au niveau 10 de son service (prix et palier inchangés)")
	# lot G2 (remplace « toucher l'engin », « toucher la barrière express », « les responsables du parc et de la gate font
	# ces gestes ») : les gestes du terre-plein — tamponner (la cabane), laisser passer et encaisser (la barrière) — et leurs
	# responsables qui les remplacent (Paul, Tonio)
	var g := PortSim.new(db, 43)
	g.begin_act0()
	g.open_port()
	g.money = 1.0e4
	for b in PortSim.STARTERS:
		g.build(String(b))
	g.yard_pending[0] = 20.0
	var m0 := g.money
	var stamped := g.stamp()
	check(stamped >= 19.9 and g.pending_total() == 0.0 and g.cleared_total() >= 19.9 and g.money > m0 and g.counter("stamps") == 1.0 and not g.stamp_ready(),
		"G2 : toucher la cabane tamponne tout le lot (%s conteneurs dédouanés, droits encaissés)" % Fmt.num(stamped))
	g.truck_queue = float(db.cfg("truck_evp"))
	var d0 := g._sum(g.delivered)
	var m1 := g.money
	var paid := g.pass_truck()
	check(paid > 0.0 and is_equal_approx(g._sum(g.delivered) - d0, float(db.cfg("truck_evp"))) and g.money > m1 and g.counter("passes") == 1.0,
		"G2 : toucher la barrière laisse passer un camion (2 conteneurs) qui paie %s" % Fmt.money(paid))
	g.managers["customs"] = true
	g.managers["gate"] = true
	g.yard_pending[0] = 10.0
	g.truck_queue = float(db.cfg("truck_evp"))
	check(not g.stamp_ready() and not g.pass_ready() and g.stamp() == 0.0 and g.pass_truck() == 0.0,
		"G2 : Paul et Tonio embauchés remplacent les gestes (plus rien à toucher)")
	# avant son chapitre, un service tourne seul au minimum : le parc n'est jamais le goulot avant d'être présenté ; la gate
	# peut l'être au plus 45 s d'affilée — c'est ce qui ouvre son chapitre (revue N7, option a : « gate goulot pendant 45 s »)
	var worst := 0.0
	var worst_gate := 0.0
	for seed_v in [1, 2, 3, 4]:
		var p := PortSim.new(db, seed_v)
		var bot := Bot.new(p)
		var t_bad := 0.0
		var run_gate := 0.0
		while p.tier < 2 and p.time < 1800.0:
			bot.run(1.0)
			if String(p.analysis.get("dept", "")) == "yard_ops" and not p.feature("dept_yard_ops"):
				t_bad += 1.0
			if String(p.analysis.get("dept", "")) == "gate" and not p.feature("dept_gate"):
				run_gate += 1.0
				worst_gate = maxf(worst_gate, run_gate)
			else:
				run_gate = 0.0
		worst = maxf(worst, t_bad)
	check(worst <= 2.0 and worst_gate <= 47.0, "le parc ne bloque jamais la chaîne avant son chapitre (au pire %d s) ; la gate au plus %d s d'affilée (≤ 45 s + 2, 4 parties)" % [int(worst), int(worst_gate)])


## Fait avancer l'horloge seconde par seconde en vérifiant les révélations (un sujet à la fois, voir PortSim.check_unlocks).
func _reveal_for(p: PortSim, secs: int) -> void:
	for i in secs:
		p.time += 1.0
		p.check_unlocks()


## Corrections de la revue du 13/10 (REVUE_PLAN_BAIE.md) testables sans scène.
func test_revue_baie(db: DataDB) -> void:
	print("[revue du plan de la baie : zones à venir, bulles, mouillage, passe, butte]")
	var s := PortSim.new(db, 71)
	# empreintes seulement dans les zones ouvertes et la zone prochaine (au départ : vieux port + quai allongé)
	var shown: Array[String] = []
	for bid in Layout.LOTS:
		if not s.built.has(bid) and Zones.lot_shown(s, bid):
			shown.append(bid)
	var zones_ok := shown.all(func(b: String) -> bool: return int(Layout.LOTS[b].zone) in [1, 2])
	check(shown.has("quay_ext") and shown.has("gravel2") and not shown.has("customs1") and zones_ok,
		"empreintes : zone ouverte et zone prochaine seulement (%s)" % ", ".join(shown))
	# chaque zone a une icône et une couleur de sol qui existe (pas de magenta : palette.json + Layout.PALETTE_EXTRA)
	var bad_z: Array[String] = []
	for z in Layout.ZONES:
		if UI.icon_tex(String(z.get("icon", ""))) == null:
			bad_z.append("icône %d" % int(z.id))
		if String(z.ground) != "" and Assets.color(String(z.ground)) == Color("#ff00ff"):
			bad_z.append("sol %d (%s)" % [int(z.id), z.ground])
	check(bad_z.is_empty(), "une icône par zone, couleurs de sol connues (%s)" % str(bad_z))
	# bulles bornées au rectangle utile : ramenées dedans, ou pas dessinées si leur ancrage est franchement dehors
	var useful := Rect2(8, 300, 524, 500)
	var r1 := Bubbles.bound(Rect2(-40, 320, 120, 54), useful)
	var r2 := Bubbles.bound(Rect2(200, 120, 120, 54), useful)
	var r3 := Bubbles.bound(Rect2(480, 790, 120, 54), useful)
	check(r1.position.x >= 8.0 and useful.encloses(r1) and not r2.has_area() and useful.encloses(r3),
		"bulles bornées au rectangle utile (hors HUD, dans l'écran)")
	# mouillage : la place n°1 loin de la pointe du cap et des feux de passe ; aucune place dans les voies du chenal
	var a1 := Layout.anchor_pos(0)
	var tip := Vector2(-64, -44)
	var clear_ch := true
	for k in 24:
		var a := Layout.anchor_pos(k)
		for i in Layout.CHANNEL.size():
			var c: Vector3 = Layout.CHANNEL[i]
			if Vector2(a.x - c.x, a.z - c.z).length() < Layout.CHANNEL_HALF + 8.0:
				clear_ch = false
		for p in Layout.EXIT_NORTH:
			if absf(a.x - (p as Vector3).x) < 22.0 and a.z > (p as Vector3).z - 10.0 and a.z < -96.0:
				clear_ch = false
	check(Vector2(a1.x, a1.z).distance_to(tip) >= 25.0 and Vector2(a1.x, a1.z).distance_to(Vector2(Layout.LIGHT_GREEN.x, Layout.LIGHT_GREEN.z)) >= 20.0
		and Vector2(a1.x, a1.z).distance_to(Vector2(Layout.LIGHT_RED.x, Layout.LIGHT_RED.z)) >= 30.0 and clear_ch,
		"mouillage : place n°1 à %d u de la pointe du cap, aucune place dans le chenal ni sur la sortie nord" % int(Vector2(a1.x, a1.z).distance_to(tip)))
	# la passe, entre la pointe du cap et la tête du brise-lames prolongé, fait ≈ 40 u
	var pass_w := float(Layout.BREAKWATER[0].x) - tip.x
	check(pass_w >= 36.0 and pass_w <= 50.0, "passe de %d u entre la pointe du cap et la tête du brise-lames" % int(pass_w))
	# la butte (lot D : recalée sur le pôle nautique du cap, ex-Colline) ; ses bâtiments sont posés dessus
	var tower_y := 0.0
	for p in Layout.PROPS:
		if p.m == "control_tower":
			tower_y = Layout.ground_y(Vector2(float(p.p[0]), float(p.p[2])))
	check(Layout.ground_y(Vector2(-66, -18)) > 1.0 and Layout.ground_y(Vector2(-30, 45)) == 0.0 and tower_y > 1.0, "butte du pôle nautique (%s u), la tour posée dessus" % Fmt.num(Layout.ground_y(Vector2(-66, -18))))
	# zone 12 neutralisée tant que la gare n'est pas construite : tout ce qui y est posé sans condition est gris
	var colored := 0
	var z12 := Layout.zone_by_id(12)
	for p in Layout.PROPS:
		if String(p.cond) == "" and Geometry2D.is_point_in_polygon(Vector2(float(p.p[0]), float(p.p[2])), PackedVector2Array(z12.poly)) and String(p.get("neutral", "")) != "rail":
			colored += 1
	check(colored == 0, "zone 12 grisée : aucun décor en couleurs avant la gare (%d)" % colored)
	# sphères de GNL au T3 (modèle livré, sinon silos de repli), dans leur case
	var spheres := Layout.PROPS.filter(func(p: Dictionary) -> bool: return p.m == "lng_sphere")
	var in_lot := spheres.all(func(p: Dictionary) -> bool: return Layout.lot_rect("lng").grow(0.1).has_point(Vector2(float(p.p[0]), float(p.p[2]))))
	check(spheres.size() == 2 and in_lot and Assets.exists("lng_sphere") and Assets.top_y("lng_sphere") >= 13.0,
		"deux sphères de GNL dans leur case (sommet %s u)" % Fmt.num(Assets.top_y("lng_sphere")))


## Coque d'un navire : rectangle orienté (centre, cap unitaire en (x, z), demi-longueur, demi-largeur).
func _hull_dist(p: Vector2, c: Vector2, h: Vector2, a: float, b: float) -> float:
	var l := p - c
	var u := absf(l.dot(h)) - a
	var v := absf(l.dot(Vector2(-h.y, h.x))) - b
	return Vector2(maxf(u, 0.0), maxf(v, 0.0)).length()


## Distance entre deux coques (échantillonnage des bords de chacune).
func _hulls_gap(c1: Vector2, h1: Vector2, a1: float, b1: float, c2: Vector2, h2: Vector2, a2: float, b2: float) -> float:
	var best := INF
	for side in 2:
		var c := c1 if side == 0 else c2
		var h := h1 if side == 0 else h2
		var a := a1 if side == 0 else a2
		var b := b1 if side == 0 else b2
		var n := Vector2(-h.y, h.x)
		for i in 21:
			var t := -1.0 + 0.1 * float(i)
			for q in [c + h * a * t + n * b, c + h * a * t - n * b, c + h * a + n * b * t, c - h * a + n * b * t]:
				best = minf(best, _hull_dist(q, c2, h2, a2, b2) if side == 0 else _hull_dist(q, c1, h1, a1, b1))
	return best


## Navire : demi-longueur et demi-largeur affichées (modèle × échelle).
func _ship_half(cls: String) -> Vector2:
	var m := Assets.meta("ship_" + cls)
	var sc := float(Layout.SHIP_SCALE.get(cls, 1.0))
	return Vector2(float(m.get("length", 30.0)) * sc * 0.5, float(m.get("width", 8.0)) * sc * 0.5)


## Seconde revue du 14/10 (REVUE_PLAN_BAIE.md) : coques et bouées, coques entre elles.
func test_revue2_baie(_db: DataDB) -> void:
	print("[seconde revue : coques, bouées, feux]")
	# N1 : sur tous les trajets du chenal et de la passe, la coque reste à ≥ 1,5 u de toute bouée et de tout feu
	var marks: Array[Vector2] = []
	for bp in Layout.channel_buoys():
		marks.append(Vector2((bp.p as Vector3).x, (bp.p as Vector3).z))
	marks.append(Vector2(Layout.LIGHT_RED.x, Layout.LIGHT_RED.z))
	marks.append(Vector2(Layout.LIGHT_GREEN.x, Layout.LIGHT_GREEN.z))
	var bad: Array[String] = []
	var worst := INF
	var worst_at := ""
	for bi in 4:
		var classes := ["mini", "coaster", "feeder"] if bi < 2 else ["feeder", "panamax"]
		for cls in classes:
			var hs := _ship_half(cls)
			var paths: Array = []
			for k in 12:
				paths.append(Layout.ship_path_pilot(k, bi))
			if bi < 2:
				paths.append(Layout.ship_path_depart(bi, hs.y * 2.0, 1))
			for path in paths:
				var pts := Layout.sample_path(path, 1.0)
				for i in range(1, pts.size()):
					var c := Vector2(pts[i].x, pts[i].z)
					# la coque suit le trajet : étrave et poupe sur la polyligne (corde de part et d'autre du point) ; (lot F1,
					# recalé) centre de la coque au milieu de la corde, comme ShipView.hull_center depuis E-Flux, et corde
					# entière : plus de pivot au bassin, le navire y tourne en avançant (avant : centre sur le point du trajet,
					# étrave arrêtée à l'entrée du bassin)
					var ia := mini(i + roundi(hs.x), pts.size() - 1)
					var ib := maxi(i - roundi(hs.x), 0)
					var d := Vector2(pts[ia].x - pts[ib].x, pts[ia].z - pts[ib].z)
					if d.length() < 0.01 or c.y < -100.0 or c.y > -36.0:
						continue          # hors du chenal et de la passe (le large ; le bassin)
					var w := clampf(float(mini(i, pts.size() - 1 - i)) / hs.x, 0.0, 1.0)
					c = c.lerp((Vector2(pts[ia].x, pts[ia].z) + Vector2(pts[ib].x, pts[ib].z)) * 0.5, w)
					var h := d.normalized()
					for m in marks:
						var dd := _hull_dist(m, c, h, hs.x, hs.y)
						if dd < worst:
							worst = dd
							worst_at = "%s poste %d (%d, %d) près de (%d, %d)" % [cls, bi, int(c.x), int(c.y), int(m.x), int(m.y)]
						if dd < 1.5 and bad.size() < 4:
							bad.append("%s poste %d (%d, %d) près de (%d, %d)" % [cls, bi, int(c.x), int(c.y), int(m.x), int(m.y)])
	check(bad.is_empty(), "N1 : coque à ≥ 1,5 u de toute bouée du chenal et des feux de passe (au plus près %.2f u : %s) %s" % [worst, worst_at, str(bad)])
	# N10 : deux coques à ≥ 2 u — navires au mouillage (12 places, panamax), à quai côte à côte, et qui se croisent dans le chenal
	var gaps: Array[String] = []
	var yaw := Vector2(cos(0.35), -sin(0.35))
	var pm := _ship_half("panamax")
	var fd := _ship_half("feeder")
	var gmin := INF
	for i in 12:
		for j in range(i + 1, 12):
			var ai := Layout.anchor_pos(i)
			var aj := Layout.anchor_pos(j)
			var g := _hulls_gap(Vector2(ai.x, ai.z), yaw, pm.x, pm.y, Vector2(aj.x, aj.z), yaw, pm.x, pm.y)
			gmin = minf(gmin, g)
			if g < 2.0:
				gaps.append("mouillages %d/%d (%s u)" % [i + 1, j + 1, Fmt.num(g)])
	for pair in [[0, 1, fd], [2, 3, pm]]:
		var hs2: Vector2 = pair[2]
		var b1 := Layout.berth_ship_pos(int(pair[0]), hs2.y * 2.0)
		var b2 := Layout.berth_ship_pos(int(pair[1]), hs2.y * 2.0)
		var g2 := _hulls_gap(Vector2(b1.x, b1.z), Vector2(1, 0), hs2.x, hs2.y, Vector2(b2.x, b2.z), Vector2(1, 0), hs2.x, hs2.y)
		if g2 < 2.0:
			gaps.append("postes %d/%d (%s u)" % [int(pair[0]), int(pair[1]), Fmt.num(g2)])
	var lane_gap := Layout.CHANNEL_LANE_IN + Layout.CHANNEL_LANE_OUT - 2.0 * fd.y
	if lane_gap < 2.0:
		gaps.append("voies du chenal (%s u)" % Fmt.num(lane_gap))
	check(gaps.is_empty(), "N10 : deux coques à ≥ 2 u (mouillages, postes voisins, voies du chenal ; au plus près au mouillage %s u) %s" % [Fmt.num(gmin), str(gaps)])


## Seconde revue, rythme et diagnostic (C6b) : une révélation par minute (ou dès que la précédente a servi), rade pleine.
func test_revue2_rythme(db: DataDB) -> void:
	print("[seconde revue : révélations espacées, rade pleine]")
	# N8 : après le Parc, Yasmine attend 60 s… ou 20 s seulement si le Parc a déjà servi
	var a := PortSim.new(db, 81)
	a.levels["cranes"] = 10
	_reveal_for(a, 40)
	var early := a.feature("managers")
	_reveal_for(a, 30)
	var b := PortSim.new(db, 82)
	b.levels["cranes"] = 10
	_reveal_for(b, 2)
	b.levels["yard_ops"] = 2          # le Parc a servi
	_reveal_for(b, 45)      # lot D-Éco : `reveal_gap_min` 20 → 45 s
	check(a.feature("dept_yard_ops") and not early and a.feature("managers") and b.feature("managers"),
		"N8 : une révélation ordinaire attend 60 s, ou 45 s si la précédente a servi (Yasmine à 40 s : %s ; avec le Parc utilisé : %s)" % [early, b.feature("managers")])
	# N5 bis : rade pleine depuis quelques secondes → le conseil affiché n'est plus « pas assez de navires » (l'analyse du
	# bot, du hors-ligne et des contrats ne change pas)
	var r := PortSim.new(db, 83)
	r._refresh_analysis()
	var k0 := String(r.analysis.key)
	r._rade_full_t = 10.0
	for sh in r.ships:
		sh.state = Ship.State.ANCHORED
	r._refresh_analysis()
	var shown := String(r.shown_analysis().key)
	check((k0 == "attract" or k0 == "harbor") and String(r.analysis.key) == k0 and shown != "attract" and shown != "harbor",
		"N5 bis : rade pleine → conseil affiché « %s » au lieu de « %s » (analyse inchangée)" % [shown, k0])


# ---------------------------------------------------------------------------
# Lot C7 : corrections de la revue de code C6
# ---------------------------------------------------------------------------

func test_c7(db: DataDB) -> void:
	print("[lot C7 : revue de code C6]")
	# A3 : sauvegarde au milieu d'une chaîne « after » : la révélation suivante attend toujours son délai
	var p := PortSim.new(db, 31)
	p.time = 500.0
	p.features["dept_gate"] = p.time          # la gate vient d'ouvrir son chapitre ; « Gestion » suit 25 s après
	p.last_reveal_t = p.time
	p.last_reveal_id = "dept_gate"
	p.time += 5.0
	var sv: Dictionary = JSON.parse_string(JSON.stringify(p.to_dict()))
	var q := PortSim.new(db, 32)
	q.from_dict(sv)
	_reveal_for(q, 10)
	var early := q.feature("manage")
	_reveal_for(q, 60)
	var later := q.feature("manage")
	var legacy := sv.duplicate(true)
	legacy.features = ["dept_gate", "manage"]
	var l2 := PortSim.new(db, 33)
	l2.from_dict(legacy)
	check(not early and later and is_equal_approx(q.feature_time("dept_gate"), 500.0) and l2.feature("manage") and l2.feature_time("dept_gate") < 0.0,
		"C7 A3 : rechargé au milieu d'une chaîne « after », « Gestion » attend son délai (à +15 s : %s, à +75 s : %s) ; l'ancien format liste se charge" % [early, later])
	# A4 (borne) : un palier hors bornes dans une sauvegarde est ramené à 1–3
	var bad_tier := sv.duplicate(true)
	bad_tier.tier = 7
	var bt := PortSim.new(db, 34)
	bt.from_dict(bad_tier)
	check(bt.tier == 3, "C7 A4 : palier borné au chargement (7 → %d)" % bt.tier)
	# A5 : outils de débogage liés au binaire de l'éditeur (vrai ici, faux dans tout APK, même exporté en debug)
	check(DebugArgs.allowed() and DebugArgs.allowed() == OS.has_feature("editor") and not OS.has_feature("template"),
		"C7 A5 : outils de débogage seulement avec la fonction « editor » (éditeur %s, modèle d'export %s)" % [OS.has_feature("editor"), OS.has_feature("template")])
	# A8 : texture de distance en demi-flottants (R16F), mêmes valeurs à 0,25 u près sur la plage utile
	var field := Terrain.distance_field(Layout.land_polys(false))
	var img := Terrain.distance_texture(field).get_image()
	var worst := 0.0
	for k in range(0, field.size(), 97):
		if field[k] < 200.0:
			worst = maxf(worst, absf(img.get_pixel(k % Layout.MASK_N, k / Layout.MASK_N).r - field[k]))
	check(img.get_format() == Image.FORMAT_RH and worst < 0.25, "C7 A8 : texture de distance R16F (écart max %.3f u)" % worst)
	# C3 : terrain rendu une face : chaque triangle (dessus et flancs, polygone dans les deux sens) est tourné vers sa normale
	var wrong := 0
	var tris := 0
	for poly in [Layout.COAST, Layout.RECLAIM, Layout.zone_by_id(9).poly, Layout.BREAKWATER]:
		for rev in [false, true]:
			var pa: Array = (poly as Array).duplicate()
			if rev:
				pa.reverse()
			var mi := Terrain.poly_mesh(pa, Color.WHITE, 0.0, 2.4, null)
			var arr := (mi.mesh as ArrayMesh).surface_get_arrays(0)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var ix := PackedInt32Array()
			if arr[Mesh.ARRAY_INDEX] != null:
				ix = arr[Mesh.ARRAY_INDEX]
			var nt := (ix.size() if not ix.is_empty() else vs.size()) / 3
			for t in nt:
				var i0 := ix[t * 3] if not ix.is_empty() else t * 3
				var i1 := ix[t * 3 + 1] if not ix.is_empty() else t * 3 + 1
				var i2 := ix[t * 3 + 2] if not ix.is_empty() else t * 3 + 2
				tris += 1
				if (vs[i2] - vs[i0]).cross(vs[i1] - vs[i0]).dot(ns[i0]) <= 0.0:
					wrong += 1
			mi.free()
	var land_sh := FileAccess.get_file_as_string("res://assets/land.gdshader")
	check(wrong == 0 and tris > 100 and not land_sh.contains("render_mode cull_disabled"),
		"C7 C3 : terrain sans « cull_disabled », %d triangles tous tournés vers leur normale (%d à l'envers)" % [tris, wrong])
	# B5 : tutoriel — le parc n'attend plus Yasmine ; une sauvegarde où « Responsables » est révélé avec une grue < 10
	# (révélation d'avant les chapitres, prestige) ne bloque pas l'étape « embauche-la » : elle se passe d'elle-même
	var steps: Array = DataDB.load_json("res://data/tutorial.json")
	var ip := -1
	var im := -1
	for i in steps.size():
		if String(steps[i].id) == "parc":
			ip = i
		elif String(steps[i].id) == "manager":
			im = i
	var ev := func(expr: String, sm: PortSim) -> bool:
		var e := Expression.new()
		e.parse(expr, ["sim"])
		return bool(e.execute([sm], null, false))
	var lg := PortSim.new(db, 36)
	lg.features["managers"] = true
	lg.money = 1000.0
	var nm := PortSim.new(db, 37)
	nm.features["managers"] = nm.time
	nm.levels["cranes"] = 10
	nm.money = 1000.0
	var mst: Dictionary = steps[im] if im >= 0 else {}
	check(ip >= 0 and im > ip and ev.call(String(mst.done), lg) and not ev.call(String(mst.when), lg)
		and ev.call(String(mst.when), nm) and not ev.call(String(mst.done), nm),
		"C7 B5 : étape « parc » avant « manager » (%d < %d) ; Yasmine absente malgré « Responsables » révélé : étape passée" % [ip, im])
	# B6 : la condition d'une Douane à venir ne renvoie à Gestion que si Gestion est là
	var b6 := PortSim.new(db, 38)
	var t_before := b6.unlock_text("dept_customs")
	b6.features["manage"] = b6.time
	var t_after := b6.unlock_text("dept_customs")
	check(not t_before.contains("Gestion") and t_after.contains("Gestion → Bâtiments"), "C7 B6 : « %s » puis « %s »" % [t_before, t_after])
	# C1 (lot G2, remplacé : la barrière express n'existe plus) : laisser passer un camion sort exactement un camion
	# (2 conteneurs livrés), le solde de la file baisse d'autant, même si elle se remplit aussi
	var g := PortSim.new(db, 39)
	g.begin_act0()
	g.open_port()
	g.money = 1.0e4
	for b in PortSim.STARTERS:
		g.build(String(b))
	g.yard_cleared[0] = 400.0
	g.truck_queue = float(db.cfg("truck_evp")) * 2.0
	var d0 := g._sum(g.delivered)
	var q0 := g.truck_queue
	g.pass_truck()
	var real := g._sum(g.delivered) - d0
	check(is_equal_approx(real, float(db.cfg("truck_evp"))) and is_equal_approx(q0 - g.truck_queue, real), "C7 C1 (G2) : laisser passer sort %s conteneurs (solde de la file : %s)" % [Fmt.num(real), Fmt.num(q0 - g.truck_queue)])
	# C2 : rade pleine comptée en temps écoulé (dix analyses au même instant n'ajoutent rien) ; pas de temps de goulot fantôme
	# au chargement
	var r := PortSim.new(db, 40)
	while r.waiting_ships() < r.rade_places():
		var xs := Ship.from_dict(r.ships[0].to_dict()) if not r.ships.is_empty() else Ship.new()
		xs.state = Ship.State.ANCHORED
		r.ships.append(xs)
	r.time = 100.0
	r._bn_last = r.time
	for i in 10:
		r._refresh_analysis()
	var same_t := r._rade_full_t
	r.time += 1.0
	r._refresh_analysis()
	var after_1s := r._rade_full_t
	var ld := PortSim.new(db, 41)
	var dsv: Dictionary = JSON.parse_string(JSON.stringify(r.to_dict()))
	dsv.time = 5000.0
	ld.from_dict(dsv)
	var ghost := 0.0
	for k in ld._bn_time:
		ghost += float(ld._bn_time[k])
	var full_now := r.waiting_ships() >= r.rade_places()
	check(same_t == 0.0 and full_now and is_equal_approx(after_1s, 1.0) and ghost == 0.0 and is_equal_approx(ld._bn_last, 5000.0),
		"C7 C2 : rade pleine en temps écoulé (10 analyses au même instant : %s ; +1 s : %s) ; au chargement, aucun temps de goulot fantôme (%s)" % [same_t, after_1s, ghost])
	# C6 : plus d'état « chapter » ni de champ « chapter » mort ; C7 : le chapitre de la gate ne promet plus le hors-ligne
	var no_chapter := true
	for u in db.unlocks:
		if (u as Dictionary).has("chapter"):
			no_chapter = false
	var src := FileAccess.get_file_as_string("res://sim/port_sim.gd")
	var gate_txt := String(db.unlock_by_id["dept_gate"].text)
	check(no_chapter and not src.contains("return \"chapter\"") and not gate_txt.contains("hors ligne") and not gate_txt.contains("es parti"),
		"C7 C6/C7 : ni état ni champ « chapter » ; texte du chapitre 3 sans promesse de gains hors ligne")
	# D : végétation calculée une fois (graine fixe) ; prochain achat et zone prochaine en cache, toujours justes
	var sc1 := Layout.scatter()
	var sc2 := Layout.scatter()
	var zs := PortSim.new(db, 42)
	var z_ok := true
	for bid in ["quay_ext", "gravel2", "customs1", "supply", "crane2", "dredge1"]:
		var naive := ""
		for b in db.buildings:
			if not zs.built.has(String(b.id)):
				naive = String(b.id)
				break
		var nz := {}
		for z in Layout.ZONES:
			if Zones.state(zs, z) == Zones.NEXT:
				nz = z
				break
		if Zones.first_unbuilt(zs) != naive or Zones.next_zone(zs) != nz:
			z_ok = false
		zs.built.append(bid)
	check(is_same(sc1, sc2) and sc1.size() > 50 and z_ok, "C7 D : végétation en cache (%d éléments), prochain achat et zone prochaine en cache et justes" % sc1.size())
	# C4 : barges du terre-plein — couloir le long du futur bord du quai, loin des places de mouillage et de la voie de départ
	# du palier 3 (avant C7 : elles descendaient du large à travers le mouillage n°5)
	var near_anchor := INF
	var near_lane := INF
	var on_land_b := false
	for i in Layout.RECLAIM_BARGES.size():
		var a2 := Vector2(float(Layout.RECLAIM_BARGE_X0[i]), Layout.RECLAIM_BARGE_LANE_Z)
		var b2 := Vector2(float(Layout.RECLAIM_BARGES[i]), Layout.RECLAIM_BARGE_LANE_Z)
		for k in 30:
			var ap := Layout.anchor_pos(k)
			var q2 := Vector2(ap.x, ap.z)
			near_anchor = minf(near_anchor, Geometry2D.get_closest_point_to_segment(q2, a2, b2).distance_to(q2))
		for bi in 2:          # (les quais n°3 et 4 n'existent pas encore pendant le comblement)
			for pp in Layout.sample_path(Layout.ship_path_depart(bi, 8.0, 3), 1.0):
				var q3 := Vector2(pp.x, pp.z)
				near_lane = minf(near_lane, Geometry2D.get_closest_point_to_segment(q3, a2, b2).distance_to(q3))
		for t in 21:
			if Layout.on_land(a2.lerp(b2, t / 20.0), false):
				on_land_b = true
	check(near_anchor > 30.0 and near_lane > 8.0 and not on_land_b,
		"C7 C4 : barges à %.0f u du mouillage le plus proche, à %.1f u de la voie de départ T3, jamais sur la terre" % [near_anchor, near_lane])


# ---------------------------------------------------------------------------
# Lot D — Monde : réorganisation du port (douane, gate, pôle nautique, gare, passe est), vie du port
# ---------------------------------------------------------------------------

func test_d_monde(db: DataDB) -> void:
	print("[lot D — monde : circulation à droite, douane, pôle nautique, gare, passe est]")
	# B1 : circulation à droite — entrée à l'est de la route, sortie à l'ouest (côté douane) ; autoroute : vers l'est au sud ;
	# voie des camions : aller (vide) au sud, retour chargé au nord le long du parc
	var right := Layout.road_in_x(false) > Layout.ROAD_OUT_X and Layout.road_in_x(true) > Layout.road_out_x(true, 1) \
		and Layout.HIGHWAY_LANE_E > Layout.HIGHWAY_LANE_W and Layout.LANE_A_Z > Layout.LANE_B_Z and Layout.LOAD_STOP_Z < Layout.LANE_B_Z
	check(right, "D B1 : circulation à droite (entrée x %s > sortie x %s ; autoroute est z %s ; aller z %s, retour chargé z %s)" % [
		Fmt.num(Layout.road_in_x(false)), Fmt.num(Layout.ROAD_OUT_X), Fmt.num(Layout.HIGHWAY_LANE_E), Fmt.num(Layout.LANE_A_Z), Fmt.num(Layout.LANE_B_Z)])
	# les camions chargés passent devant la douane et sous le scanner à portique ; les camions vides jamais
	var hut := Layout.lot_rect("customs1")
	var scan := Layout.lot_rect("scanner2")
	var loaded_ok := 0
	var loaded_n := 0
	var empty_bad: Array[String] = []
	for tier in [1, 2, 3]:
		var x := Layout.LANE_X0 + 7.0
		while x <= Layout.lane_end_x(tier) - 2.5:
			loaded_n += 1
			var under := false
			var near_hut := INF
			for p in Layout.sample_path(Layout.truck_route_out(x, tier, false), 0.5):
				var q := Vector2(p.x, p.z)
				if scan.has_point(q):
					under = true
				near_hut = minf(near_hut, _rect_dist(hut, q))
			if under and near_hut < 4.0:
				loaded_ok += 1
			for in_x in [Layout.road_in_x(false), Layout.road_in_x(true)]:
				for p in Layout.sample_path(Layout.truck_route_in(in_x, x, tier), 0.5):
					var q2 := Vector2(p.x, p.z)
					if scan.has_point(q2) or _rect_dist(hut, q2) < 4.0:
						empty_bad.append("%d,%d" % [int(p.x), int(p.z)])
						break
			x += 4.4
	check(loaded_ok == loaded_n and empty_bad.is_empty(),
		"D B1 : %d/%d trajets chargés sous le scanner à portique et à < 4 u de la douane ; camions vides loin d'eux (%s)" % [loaded_ok, loaded_n, str(empty_bad.slice(0, 3))])
	# aucun bâtiment de douane hors de l'enceinte (bureau, scanner mobile, scanner à portique dans l'enceinte ; halle
	# d'inspection dans le port, côté mer de la gate) ; guichet et douane dématérialisée côté public, aux bureaux du port
	var yard := Layout.CUSTOMS_YARD
	var outside: Array[String] = []
	for bid in ["customs1", "scanner1", "scanner2"]:
		if not yard.encloses(Layout.lot_rect(bid).grow(-0.05)):
			outside.append(bid)
	for p in Layout.PROPS:
		if String(p.m) == "inspection_hall" and not (float(p.p[2]) < Layout.GATE_OUT_Z and float(p.p[0]) > -48.8):
			outside.append("halle")
	for bid in ["ewindow", "ecustoms"]:
		if int(Layout.LOTS[bid].zone) != 13 or (Layout.LOTS[bid].p as Vector3).z < Layout.GATE_IN_Z:
			outside.append(bid)
	check(outside.is_empty(), "D B1 : douane, scanners et halle dans l'enceinte ; guichet et e-douane aux bureaux (hors : %s)" % str(outside))
	# I1 : une zone Gate (ouverte au départ, icône barrière) distincte de la zone Douane (clé customs1, icône douane) ;
	# même achat, même nom : une zone ouverte par un bâtiment porte le nom de ce bâtiment
	var zg := Layout.zone_by_id(4)
	var zd := Layout.zone_by_id(3)
	var names_bad: Array[String] = []
	for z in Layout.ZONES:
		var k := String(z.get("key", ""))
		if k != "" and String(db.building_by_id[k].name) != String(z.name):
			names_bad.append("%s ≠ %s" % [z.name, db.building_by_id[k].name])
	check(String(zg.open) == "start" and String(zg.icon) == "gate" and String(zd.key) == "customs1" and String(zd.icon) == "customs"
		and names_bad.is_empty(),
		"D I1 : zones « %s » (ouverte) et « %s » (douane) ; noms des zones = noms des bâtiments (%s)" % [zg.name, zd.name, str(names_bad)])
	# B2 : pôle nautique sur le cap — tour VTS à ≈ 35 u de la passe, pilotage au pied, atelier au bord de l'eau avec sa cale
	var pass_c := Vector2((-64.0 + float(Layout.BREAKWATER[0].x)) * 0.5, Layout.PASS_Z)
	var tw := Vector2(Layout.CONTROL_TOWER.x, Layout.CONTROL_TOWER.z)
	var f0 := Terrain.distance_field(Layout.land_polys(false))
	var rep := Layout.lot_rect("repair")
	var rp := Layout.lot_rect("rpilot")
	var sw_end: Vector3 = Layout.SLIPWAY.to
	var sw_from: Vector3 = Layout.SLIPWAY.from
	var tower_on := Layout.dept_pos("harbor", 2).is_equal_approx(Layout.CONTROL_TOWER) and Layout.dept_pos("harbor", 1).is_equal_approx(Layout.HARBOR_OFFICE)
	var mh := Layout.manager_pos("harbor", 2)
	check(tw.distance_to(pass_c) <= 40.0 and _rect_dist(rp, tw) < 5.0 and Terrain.field_at(f0, Vector2(sw_end.x, sw_end.z)) > 1.0
		and _rect_dist(rep, Vector2(sw_from.x, sw_from.z)) < 1.0 and int(Layout.LOTS.repair.zone) == 9 and tower_on
		and Layout.ground_y(Vector2(mh.x, mh.z)) > 1.0,
		"D B2 : tour VTS à %d u de la passe, pilotage au pied, cale de l'atelier dans l'eau de la crique, Capitainerie à la tour au T2" % int(tw.distance_to(pass_c)))
	# I2 : la gare contre le terre-plein, sa voie reliée au parc (liaison jusqu'à la voie des camions), dans l'ancienne
	# bande d'herbe ; la zone logistique reste derrière
	var z12 := Layout.zone_by_id(12)
	var r12 := Layout.poly_rect(z12.poly)
	var link := false
	for g in Layout.GROUNDS:
		if String(g.cond) == "rail" and String(g.type) == "road_z" and float(g.r[1]) <= float(Layout.LANE_BAND[1]) and float(g.r[3]) >= Layout.lot_rect("rail").position.y - 3.0:
			link = true
	check(r12.position.y >= 38.0 and r12.end.y <= 82.0 and Layout.RAIL_Z > 50.0 and Layout.RAIL_Z < 62.0 and link
		and Layout.lot_rect("rail").position.y > 46.0,
		"D I2 : gare contre le terre-plein (zone z %d–%d, voie z %d), reliée à la voie des camions du terre-plein" % [int(r12.position.y), int(r12.end.y), int(Layout.RAIL_Z)])
	# I3 : brise-lames est et passe est — les navires des postes 3–4 arrivent et repartent par l'est, ceux des postes 1–2
	# par la passe ouest ; aucun trajet ne coupe un brise-lames ni la terre (2,5 u), coques à ≥ 1,5 u des feux de la passe est
	var f1 := Terrain.distance_field(Layout.land_polys(true))
	var east_bad: Array[String] = []
	var marks := [Vector2(Layout.LIGHT_GREEN_E.x, Layout.LIGHT_GREEN_E.z), Vector2(Layout.LIGHT_RED_E.x, Layout.LIGHT_RED_E.z)]
	var worst := INF
	var half_w := _ship_half("panamax").y
	for bi in [2, 3]:
		for k in 24:
			var via_east := false
			var via_west := false
			var path := Layout.ship_path_pilot(k, bi)
			for p in Layout.sample_path(path, 1.0):
				if Terrain.field_at(f1, Vector2(p.x, p.z)) < 2.5:
					east_bad.append("pilotage %d→%d (%d, %d)" % [k, bi, int(p.x), int(p.z)])
					break
				if p.x > 146.0 and p.x < 190.0 and p.z > -40.0 and p.z < -10.0:
					via_east = true
				if p.z > Layout.PASS_Z - 3.0 and p.z < Layout.PASS_Z + 3.0 and p.x < float(Layout.BREAKWATER[0].x):
					via_west = true
				for m in marks:
					worst = minf(worst, Vector2(p.x, p.z).distance_to(m) - half_w)
			if not via_east or via_west:
				east_bad.append("pilotage %d→%d hors de la passe est" % [k, bi])
		var dep := Layout.ship_path_depart(bi, 8.8, 3)
		var dep_east := false
		var dpts := Layout.sample_path(dep, 1.0)
		for i in range(3, dpts.size()):
			var p: Vector3 = dpts[i]
			if Terrain.field_at(f1, Vector2(p.x, p.z)) < 2.5:
				east_bad.append("départ %d (%d, %d)" % [bi, int(p.x), int(p.z)])
				break
			if p.x > 160.0 and p.z < -30.0 and p.z > -60.0:
				dep_east = true
			for m in marks:
				worst = minf(worst, Vector2(p.x, p.z).distance_to(m) - half_w)
		if not dep_east:
			east_bad.append("départ %d hors de la passe est" % bi)
	var west_t3 := true
	for bi in [0, 1]:
		for p in Layout.sample_path(Layout.ship_path_depart(bi, 8.0, 3), 1.0):
			if p.x > 60.0:
				west_t3 = false
	check(east_bad.is_empty() and west_t3 and worst >= 1.5 and Layout.land_polys(true).size() == 4,
		"D I3 : postes 3–4 par la passe est (coques à %.1f u des feux au plus près), postes 1–2 par la passe ouest au T3, aucun brise-lames coupé (%s)" % [worst, str(east_bad.slice(0, 3))])
	# cosmétiques : touchers Quais / Portiques séparés ; IMO décalée du GNL ; GNL avec son appontement au bord du terre-plein ;
	# repère du quai n°2 cohérent avec sa zone (pas le portique du quai n°1)
	var dq := Layout.dept_pos("berths", 1).distance_to(Layout.dept_pos("cranes", 1))
	var gap_imo := Layout.lot_rect("lng").position.x - Layout.lot_rect("imo").end.x
	var jet_ok := false
	for j in Layout.JETTIES:
		var c: Vector2 = j.c
		var sz: Vector2 = j.size
		if String(j.cond) == "lng" and Layout.on_land(Vector2(c.x - sz.x * 0.5 - 0.5, c.y), true) and not Layout.on_land(Vector2(c.x + sz.x * 0.5, c.y), true):
			jet_ok = true
	check(dq >= 9.0 and gap_imo >= 5.0 and jet_ok and not String(Layout.zone_by_id(6).landmark).contains("portique"),
		"D cosmétiques : Quais / Portiques à %s u, IMO à %s u du GNL, appontement du GNL, repère du quai n°2 « %s »" % [Fmt.num(dq), Fmt.num(gap_imo), Layout.zone_by_id(6).landmark])


## Distance d'un point à un rectangle (0 dedans).
func _rect_dist(r: Rect2, q: Vector2) -> float:
	var dx := maxf(maxf(r.position.x - q.x, 0.0), q.x - r.end.x)
	var dz := maxf(maxf(r.position.y - q.y, 0.0), q.y - r.end.y)
	return Vector2(dx, dz).length()


## Lot D-UI (docs/ORDRE_D_UI.md) : contrôles sans scène (le reste est dans ui_smoke).
func test_d_ui(db: DataDB) -> void:
	print("[lot D-UI]")
	# anti-chevauchement : une bulle entre deux voisines trouve une place libre (l'ancien décalage oscillait entre elles)
	var a := Rect2(100, 100, 200, 54)
	var b := Rect2(306, 100, 120, 54)
	var r := Bubbles.settle(Rect2(250, 105, 150, 54), [a, b])
	check(not r.intersects(a) and not r.intersects(b), "D-UI : une bulle coincée entre deux voisines ne recouvre aucune d'elles (%s)" % str(r))
	# carte Goulot « parc trop petit » : conseil réécrit (capacité, pas remplissage), aucune valeur de simulation touchée
	var s := PortSim.new(db, 41)
	var hint := String(PortSim.HINTS.yard_space)
	check(hint.contains("trop petit") and not hint.contains("sature") and PortSim.HINT_DEPT.yard_space == "yard_ops",
		"D-UI : conseil « parc trop petit pour ton débit » (%s)" % hint)
	# noms courts : chaque bâtiment et chaque service a son libellé de bouton (« QUAI N°2 · 150K $ »)
	var miss: Array[String] = []
	for bd in db.buildings:
		if not Info.BUILDING_SHORT.has(String(bd.id)):
			miss.append(String(bd.id))
	for d in PortSim.DEPTS:
		if not Info.DEPT_SHORT.has(d):
			miss.append(d)
	check(miss.is_empty() and Info.building_short(s, "berth2") == "QUAI N°2", "D-UI : libellés courts des boutons pour tous les bâtiments et services (manquants : %s)" % str(miss))
	# icônes distinctes : Capitainerie (ancre), ponton, dragage, remorqueur, GNL, pilotage à distance
	var icons := {}
	for bid in ["supply", "dredge1", "tug2", "lng", "rpilot"]:
		icons[Info.building_icon(db.building_by_id[bid])] = true
	check(icons.size() == 5 and not icons.has("harbor"), "D-UI : icônes distinctes des bâtiments maritimes (%s)" % str(icons.keys()))
	# missions : une icône par type
	var micons := {}
	for m in db.missions:
		micons[Info.mission_icon(m)] = true
	check(micons.size() >= 8, "D-UI : missions illustrées par type (%d icônes)" % micons.size())
	# tutoriel : textes alignés sur l'interface (AMÉLIORER en bas, coffre des missions, Responsables dans Gestion)
	var steps: Array = DataDB.load_json("res://data/tutorial.json")
	var txt := ""
	for st in steps:
		txt += String(st.get("text", "")) + " " + String(st.get("text_sheet", ""))
	check(txt.contains("en bas à droite") and txt.contains("coffre") and not txt.contains("touche le bouton RESPONSABLES et"),
		"D-UI : tutoriel aligné sur la nouvelle interface")


## Lot D-Éco (rythme et récompense, `docs/ORDRE_D_ECO.md`) : services facturés, révélations espacées et silencieuses après
## un palier, barre de palier dès le chapitre 1, alerte du goulot seulement si un maillon est bloqué.
func test_d_eco(db: DataDB) -> void:
	print("[lot D-Éco : services facturés, révélations, barre de palier, alerte du goulot]")
	# services facturés : chaque niveau au-delà du premier rapporte un minimum, goulot ou non
	var p := PortSim.new(db, 51)
	var f0 := p.service_fee_rate()
	p.levels["berths"] = 6
	p.levels["harbor"] = 4
	p.invalidate()
	var f1 := p.service_fee_rate()
	var base := p.income_estimate_with("harbor", 0)
	var gains_ok := true
	for d in ["harbor", "berths", "cranes"]:
		gains_ok = gains_ok and p.upgrade_gain(d, 1, -1, base) > 0.0
	var fees := [0.0]
	p.revenue.connect(func(a: float, src: String) -> void:
		if src == "fees":
			fees[0] += a)
	for i in 40:
		p.step(0.25)
	var v := 0.0
	var mix := p.cargo_shares()
	for c in PortSim.NCARGO:
		v += mix[c] * float(db.cargo[c].value)
	var expect := float(db.cfg("service_fee")) * 8.0 * v * float(db.tier_def(1).value_mult) * (1.0 + float(db.cfg("gate_fee_ratio")))
	check(f0 == 0.0 and is_equal_approx(f1, expect) and gains_ok and fees[0] > 0.0,
		"services facturés : %s/s pour 8 niveaux, chaque niveau rapporte (goulot ou non), recette « fees » encaissée (%s)" % [Fmt.money(f1), Fmt.money(fees[0])])
	# révélations : écart minimal 45–60 s, rien pendant `reveal_tier_hold` s après un passage de palier
	var gmin := float(db.cfg("reveal_gap_min"))
	var q := PortSim.new(db, 52)
	q.tier = 2
	q.last_tier_t = q.time
	_reveal_for(q, int(db.cfg("reveal_tier_hold")) - 2)
	var quiet := not q.feature("boost")
	_reveal_for(q, 4)
	check(gmin >= 45.0 and gmin <= 60.0 and float(db.cfg("reveal_tier_hold")) >= 60.0 and quiet and q.feature("boost"),
		"révélations : écart minimal %s s, aucune pendant %s s après un palier (Heures sup ensuite)" % [Fmt.num(gmin), Fmt.num(float(db.cfg("reveal_tier_hold")))])
	# parties de bot jusqu'à T2 + 3 min : barre de palier au plus tard avec la Douane, au plus 4 bandeaux dans les 6 min
	# centrées sur le passage au T2, aucune révélation dans les 60 s qui suivent.
	# (Reprise G2, remplacé : mesuré sur la partie jouée — le terre-plein à la main depuis la Concession, Missions déjà révélées
	# par la Crique — et non plus sur le port complet des tests. Le T1 du terre-plein tient ses révélations en ≈ 9 min au lieu de
	# 12 : 6 à 8 bandeaux autour du T2 ; plafond recalé à 8, la cible de 4 revient au dégraissage G3, qui sort Contrats, Commerce,
	# Licences et Réputation du T1. La barre de palier paraît avec la première carte de service.)
	var worst_b := 0
	var after_t2 := 0
	var bar_late := 0
	for sd in [1, 2, 3, 4]:
		var r := PortSim.new(db, sd)
		var bot := Bot.new(r)
		r.begin_act0()
		r.fishing.migrate_done()
		r.open_port()
		r.features["missions"] = 0.0
		var ban: Array = []
		var rev := {}
		var t2 := [-1.0]
		r.feature_unlocked.connect(func(id: String) -> void:
			ban.append(r.time)
			rev[id] = r.time)
		r.ship_class_first.connect(func(_s: Ship) -> void: ban.append(r.time))
		r.tier_changed.connect(func(t: int) -> void:
			if t == 2:
				t2[0] = r.time)
		while (t2[0] < 0.0 or r.time < t2[0] + 200.0) and r.time < 2400.0:
			bot.run(5.0)
		var nb := 0
		for bt in ban:
			if absf(float(bt) - t2[0]) <= 180.0:
				nb += 1
			if float(bt) >= t2[0] and float(bt) < t2[0] + 60.0:
				after_t2 += 1
		worst_b = maxi(worst_b, nb)
		# (la barre paraît sans bandeau avec la première carte de service : son instant est lu dans `features`)
		var t_bar := float(r.features["progress"]) if r.features.has("progress") else INF
		if t_bar > float(rev.get("dept_customs", INF)):
			bar_late += 1
	check(worst_b <= 8 and after_t2 == 0 and bar_late == 0,
		"bandeaux autour du T2 (partie jouée, G2) : au plus %d en 6 min (≤ 8), %d dans la minute qui suit le palier, barre de palier avant la Douane (4 parties ; en retard : %d)" % [worst_b, after_t2, bar_late])
	# alerte du goulot : un goulot normal n'est pas rouge ; brouillard, navire sur le point de repartir, parc plein le sont
	var a := PortSim.new(db, 53)
	a._refresh_analysis()
	var calm := String(a.shown_analysis().get("alert", "x")) == ""
	var fog := a.alert_reason({"key": "fog"})
	var sh: Ship = a.ships[0] if not a.ships.is_empty() else null
	var pat := ""
	if sh != null:
		sh.state = Ship.State.ANCHORED
		sh.patience = 0.1 * sh.patience_max
		pat = a.alert_reason(a.analysis)
		sh.patience = sh.patience_max
	# (lot E, recalé : l'alerte du parc n'existe qu'une fois son chapitre ouvert — on l'ouvre pour la mesure)
	a.features["dept_yard_ops"] = a.time
	a.yard_pending[0] = a.yard_capacity()
	var yard := a.alert_reason(a.analysis)
	a._refresh_analysis()
	var held := String(a.shown_analysis().get("alert", "")) == "yard"
	a.yard_pending[0] = 0.0
	for i in 4:
		a.time += 2.0
		a._refresh_analysis()
	var gone := String(a.shown_analysis().get("alert", "x")) == ""
	check(calm and fog == "fog" and pat == "patience" and yard == "yard" and held and gone,
		"carte Goulot : rouge seulement si un maillon est bloqué (normal « », brouillard « %s », patience « %s », parc « %s », retombe après %s s)" % [fog, pat, yard, Fmt.num(float(db.cfg("alert_hold", 4.0)))])


## Lot E — Confiance (`docs/ORDRE_E_CONFIANCE.md`) : services facturés × interface (E1), bouton Goulot (E2), coût des aléas
## (E3), noms courts (E4), mineurs de simulation (sauvegarde de `last_tier_t`, `reset()`, alerte avant le chapitre, cache des
## services facturés, recettes de Stats). Partie de bot réelle : `tests/fixtures/bot_t3.json` (graine 1, T3 + 4 min, goulot
## « postes à quai », celle de la capture x3 de la revue du lot D).
func _fixture(db: DataDB, name: String) -> PortSim:
	var p := PortSim.new(db, 1)
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/%s.json" % name))
	if d is Dictionary and (d as Dictionary).has("sim"):
		p.from_dict(d.sim)
	return p


func test_e_confiance(db: DataDB) -> void:
	print("[lot E — Confiance]")
	var p := _fixture(db, "bot_t3")
	for i in 40:          # 10 s de jeu : la rade pleine depuis 3 s désigne le maillon suivant (comme à l'écran de la capture)
		p.step(0.25)
	var key := String(p.shown_analysis().get("key", ""))
	# E1 — valeurs inchangées : la part des services ne change pas l'estimation (au bit près)
	var same := true
	for d in PortSim.DEPTS:
		for n in [0, 1, 10]:
			same = same and float(p.income_parts_with(d, n).total) == p.income_estimate_with(d, n)
	for ci in [0, 1]:
		same = same and float(p.income_parts_with("", 1, ci).total) == p.income_estimate_with("", 1, ci)
	# E1 — pastille ≤ achats rentabilisés en < 10 min (calcul indépendant, avec l'API d'avant), et < achats « qui rapportent »
	var base := p.income_estimate_with("harbor", 0)
	var fast := 0
	var any_gain := 0
	var goal := String(p.chapter_goal().get("dept", ""))
	for d in PortSim.DEPTS:
		var c := p.dept_cost(d, 1)
		if p.feature("dept_" + d) and c <= p.money:
			var g := p.upgrade_gain(d, 1, -1, base)
			if g > 0.0:
				any_gain += 1
			if d == goal or (g > 0.0 and c / g < Advice.GOOD_PAYBACK):
				fast += 1
	for ci in PortSim.NCARGO:
		var lc := p.licence_cost(ci, 1)
		if p.unlocked[ci] == 1 and p.feature("licences") and p.licence_room(ci) > 0 and lc <= p.money:
			var g2 := p.upgrade_gain("", 1, ci, base)
			if g2 > 0.0:
				any_gain += 1
			if g2 > 0.0 and lc / g2 < Advice.GOOD_PAYBACK:
				fast += 1
	var badge := Advice.worthwhile_count(p)
	check(same and p.tier == 3 and badge <= fast and badge < any_gain,
		"E1 : au T3 (partie de bot), pastille %d ≤ %d achats rentabilisés en < 10 min (avant : %d achats « qui rapportent ») ; estimations inchangées (%s)" % [badge, fast, any_gain, same])
	# E1 — un niveau hors goulot : le débit ne bouge pas, seuls les services facturés montent → gris « pas le goulot (+… de
	# services) », jamais « rentabilisé en 102 h » en vert
	var off := ""
	for d in ["yard_ops", "gate", "customs", "cranes", "harbor"]:
		var parts := p.upgrade_gain_parts(d, 1)
		if not Advice.moves_flow(parts) and float(parts.fees) > 0.0:
			off = d
			break
	var pb: Dictionary = Advice.payback(p.upgrade_gain_parts(off, 1), p.dept_cost(off, 1), Advice.effect_label(p, off, 1)) if off != "" else {}
	check(off != "" and String(pb.text).contains("pas le goulot (+") and String(pb.text).contains("de services)") and not bool(pb.good)
		and not String(pb.text).contains("rentabilisé"),
		"E1 : hors goulot (%s) — « %s », gris, pas un bon achat" % [off, String(pb.get("text", ""))])
	# E2 — « postes à quai » au T3 : jamais le GNL (le bâtiment suivant de la chaîne) ; le quai n°4 s'il est disponible, sinon
	# l'amélioration des Quais, sinon GESTION
	var act := Advice.hint_action(p)
	var fb := Advice.fix_building(p, "berth_count")
	var adds_berth := fb != "" and (db.building_by_id[fb].effects as Array).any(func(e: Dictionary) -> bool: return String(e.type) == "add_berth")
	check(key == "berth_count" and String(act.id) != "lng" and not String(act.label).contains("GNL") and adds_berth
		and (String(act.kind) == "dept" and String(act.id) == "berths" or String(act.id) == fb or String(act.kind) == "manage"),
		"E2 : goulot « postes à quai » au T3 → « %s » (bâtiment qui le règle : %s, %s ; prochain de la chaîne : %s)" % [String(act.label), fb, p.building_state(fb), Zones.first_unbuilt(p)])
	# E2 — table goulot → bâtiment : chaque goulot qui se règle par un bâtiment désigne un bâtiment dont l'effet le règle
	var q := PortSim.new(db, 61)
	q.tier = 2
	for b in db.buildings:
		if String(b.id) == "gate2":
			break
		q.built.append(String(b.id))
	q.rebuild_infra()
	q.features["dept_gate"] = q.time
	q.money = 1.0e9
	q.analysis_shown = {"key": "gate", "dept": "gate", "hint": "", "flow": 1.0, "caps": {}}
	var ag := Advice.hint_action(q)
	var ys := Advice.fix_building(PortSim.new(db, 66), "yard_space")      # au départ : la friche (+500 EVP au parc)
	q.money = 0.0
	q.analysis_shown = {"key": "gate", "dept": "gate", "hint": "", "flow": 1.0, "caps": {}}
	var ag0 := Advice.hint_action(q)
	var table_ok := true
	var bad_fix: Array[String] = []
	for k in ["berth_count", "yard_space", "gate", "cranes", "inspection", "customs"]:
		var bid := Advice.fix_building(q, k)
		if bid != "" and not (db.building_by_id[bid].effects as Array).any(func(e: Dictionary) -> bool: return Advice.fixes(k, e, q)):
			bad_fix.append("%s → %s" % [k, bid])
	table_ok = bad_fix.is_empty()
	check(String(ag.kind) == "build" and String(ag.id) == "gate2" and bool(ag.can) and ys == "gravel2"
		and String(ag0.id) == "gate2" and not bool(ag0.can) and table_ok,
		"E2 : goulot gate au T2 → « %s » (sans argent : « %s », gris) ; parc trop petit → %s ; table cohérente (%s)" % [String(ag.label), String(ag0.label), ys, str(bad_fix)])
	# E3 — coût d'un aléa : revenu réel (et non débit théorique), plafonné à 25 % de la trésorerie ; brouillard « Suspendu »
	var h := _fixture(db, "bot_t3")
	for i in 120:
		h.step(0.25)
	var real := h.real_income_rate()
	var theo := h.income_rate_estimate()
	h.money = 1.0e12
	Hazards.start(h, "wind")
	var c_wind := float(h.active_event.get("pay_cost", 0.0))
	var wind_ok := is_equal_approx(c_wind, real * 25.0) or absf(c_wind - h.real_income_rate() * 25.0) <= 0.02 * c_wind
	Hazards.end_event(h)
	h.money = 1000.0
	Hazards.start(h, "wind")
	var c_cap := float(h.active_event.get("pay_cost", 0.0))
	var hit_cr := Info.event_hits(h, "cranes") and not Info.event_hits(h, "gate")
	Hazards.end_event(h)
	Hazards.start(h, "fog")
	h.invalidate()
	var fog_txt := Info.dept_effect(h, "harbor")
	var fog_hit := Info.event_hits(h, "harbor")
	h.money = 1.0e12
	var fog_badge := Advice.worthwhile_count(h)
	Hazards.end_event(h)
	check(real > 0.0 and wind_ok and c_cap <= 250.0 + 0.01 and hit_cr and fog_txt == "Suspendu" and fog_hit and not fog_txt.contains("inf"),
		"E3 : aléa « Vent fort » au T3 — %s pour 25 s de revenu réel (%s/s ; débit théorique %s/s) ; plafond 25 %% (%s pour 1 000 $) ; brouillard « %s » sur la Capitainerie (pastille %d)" % [
			Fmt.money(c_wind), Fmt.money(real), Fmt.money(theo), Fmt.money(c_cap), fog_txt, fog_badge])
	# E4 — noms courts tirés du nom des bâtiments, sans « ᵉ » ni anciens noms
	var bad_names: Array[String] = []
	for b in db.buildings:
		var sh := Info.building_short(p, String(b.id))
		if not Info.short_matches_name(sh, String(b.name)) or sh.contains("ᵉ") or sh != sh.to_upper():
			bad_names.append("%s « %s » / « %s »" % [b.id, sh, b.name])
	check(bad_names.is_empty() and Info.building_short(p, "reefer") == "PÔLE FROID" and Info.building_short(p, "quay_ext") == "ALLONGEMENT DU QUAI",
		"E4 : %d noms courts cohérents avec le nom du bâtiment (incohérents : %s)" % [db.buildings.size(), str(bad_names)])
	# mineurs — `last_tier_t` sauvegardé (version inchangée), `reset()` complet
	var r := PortSim.new(db, 62)
	r.last_tier_t = 123.5
	var r2 := PortSim.new(db, 63)
	r2.from_dict(JSON.parse_string(JSON.stringify(r.to_dict())))
	r2._alert_why = "yard"
	r2._alert_left = 3.0
	var kept := is_equal_approx(r2.last_tier_t, 123.5)
	r2.reset()
	check(kept and r2.last_tier_t < -1.0e8 and r2._alert_why == "" and r2._alert_left == 0.0 and r2._live_t == 0.0,
		"mineurs : last_tier_t sauvegardé (%s) ; reset() remet le palier, l'alerte et la fenêtre du revenu réel à zéro" % Fmt.num(r2.last_tier_t if not kept else 123.5))
	# mineurs — alerte parc / gate seulement après le chapitre du service
	var a := PortSim.new(db, 64)
	a.yard_pending[0] = a.yard_capacity()
	a.truck_queue = 50.0
	a.stat_truck_wait = 1.0e4
	var before := a.alert_reason(a.analysis)
	a.features["dept_yard_ops"] = a.time
	var after := a.alert_reason(a.analysis)
	check(before == "" and after == "yard", "mineurs : alerte du parc seulement après son chapitre (avant « %s », après « %s »)" % [before, after])
	# mineurs — services facturés en cache : mêmes valeurs que le calcul direct, recalculées quand le panier change
	var f := PortSim.new(db, 65)
	var direct := func(s: PortSim) -> float:
		var n := 0
		for dd in PortSim.DEPTS:
			n += int(s.levels[dd]) - 1
		var mix := s.cargo_shares()
		var v := 0.0
		for c in PortSim.NCARGO:
			v += mix[c] * float(db.cargo[c].value)
		v *= float(db.tier_def(s.tier).get("value_mult", 1.0)) * s.renown_mult()
		return float(db.cfg("service_fee")) * float(n) * v * (1.0 + float(db.cfg("gate_fee_ratio")))
	var fee_ok := true
	f.levels["cranes"] = 7
	fee_ok = fee_ok and f.service_fee_rate() == direct.call(f)
	f.service_fee_rate()
	f.tier = 2
	fee_ok = fee_ok and f.service_fee_rate() == direct.call(f)
	f.unlocked[1] = 1
	fee_ok = fee_ok and f.service_fee_rate() == direct.call(f)
	f.renown = 3
	fee_ok = fee_ok and f.service_fee_rate() == direct.call(f)
	f.levels["gate"] = 12
	fee_ok = fee_ok and f.service_fee_rate() == direct.call(f) and f._fee_vals.size() >= 1
	# recettes de Stats : « fees » et « services » distinctes
	var sn: Dictionary = Info.SOURCE_NAMES
	check(fee_ok and sn.has("fees") and sn.has("services") and String(sn.fees) != String(sn.services),
		"mineurs : services facturés en cache (= calcul direct après niveaux, palier, cargaisons, Renom) ; Stats : « %s » ≠ « %s »" % [String(sn.get("fees", "?")), String(sn.get("services", "?"))])	# mineurs — bulles : au bord de l'écran, la place libre est cherchée dans le rectangle utile (avant : la bulle décalée hors
	# de l'écran était ramenée par `bound` sur sa voisine)
	var useful := Rect2(8, 100, 524, 700)
	var edge := Rect2(380, 200, 150, 54)
	var moved := Bubbles.bound(Bubbles.settle(Rect2(400, 205, 140, 54), [edge], useful), useful)
	check(not moved.intersects(edge) and useful.grow(0.5).encloses(moved),
		"mineurs : bulle au bord de l'écran placée dans le rectangle utile, sans recouvrir sa voisine (%s)" % str(moved))

## Lot E-Flux (docs/ORDRE_E_FLUX.md, revue REVUE_LOT_D.md E7–E12 et mineurs du monde) : contrôles sans scène (les autres
## sont dans ui_smoke, `_e_flux_checks`).
func test_e_flux(_db: DataDB) -> void:
	print("[lot E — Flux : camions, passe est, croisements, gate2, gare, coin gate / douane, mineurs du monde]")
	# E7 : cap d'un camion à l'arrivée à son arrêt, à l'arrêt (vers l'ouest) et au départ — écart < 30° (plus de pivot)
	var worst_turn := 0.0
	var turn_at := ""
	for tier in [1, 2, 3]:
		for gate2 in [false, true]:
			var rg := Layout.stop_range(tier, gate2)
			var x: float = rg[0]
			while x <= float(rg[1]) + 0.01:
				var rin := Layout.truck_route_in(Layout.road_in_x(gate2), x)
				var a: Vector3 = rin[-1] - rin[-2]
				var yaw_in := atan2(-a.z, a.x)
				for lane in ([0, 1] if gate2 else [0]):
					var rout := Layout.truck_route_out(x, tier, gate2, lane)
					var d: Vector3 = rout[1] - rout[0]
					var yaw_out := atan2(-d.z, d.x)
					for pair in [[yaw_in, Layout.LOAD_YAW], [Layout.LOAD_YAW, yaw_out]]:      # arrivée → arrêt, arrêt → départ
						var dd := absf(rad_to_deg(angle_difference(float(pair[0]), float(pair[1]))))
						if dd > worst_turn:
							worst_turn = dd
							turn_at = "T%d x %d voie %d" % [tier, int(x), lane]
				x += 1.1
	check(worst_turn < 30.0, "E7 : camions au chargement — de l'arrivée à l'arrêt (face à l'ouest) puis au départ, le cap change de %.1f° au plus (%s) : plus de pivot sur place" % [worst_turn, turn_at])
	# E8 : demi-tour par groupe de blocs — au T3, un camion d'un bloc du T1 fait moins de 450 u (gate → tunnel est)
	var in_x0 := Layout.road_in_x(true)
	var stop_t1 := -12.0
	var len_now := Layout.path_length(Layout.truck_route_in(in_x0, stop_t1)) + Layout.path_length(Layout.truck_route_out(stop_t1, 3, true, 0))
	var len_before := Layout.path_length(Layout.truck_route_in(in_x0, stop_t1, 3)) + Layout.path_length(Layout.truck_route_out(stop_t1, 3, true, 0))
	var turns_ok := true
	for xs in [-12.0, 20.0, 100.0]:
		var r := Layout.truck_route_in(in_x0, xs)
		if not is_equal_approx((r[3] as Vector3).x, Layout.lane_end_x(Layout.tier_for_stop(xs))):
			turns_ok = false
	check(len_now < 450.0 and turns_ok and Layout.crossover_xs(3) == [-2.0, 45.0] and Layout.crossover_xs(1).is_empty(),
		"E8 : au T3, camion d'un bloc du T1 : %d u (avant : %d u) ; demi-tour au bout de son groupe de blocs, passages dessinés en x %s" % [
		int(len_now), int(len_before), str(Layout.crossover_xs(3))])
	# E9 : passe est naviguée à droite (arrivée au nord, départ au sud) ; le départ quitte la passe à l'est de la ligne
	# d'arrivée (aucun croisement) ; deux panamax sur les deux voies gardent ≥ 2 u entre leurs coques (N10 étendu)
	var pm := _ship_half("panamax")
	var arr := Layout.ship_path_pilot(0, 3)
	var dep := Layout.ship_path_depart(3, pm.y * 2.0, 3)
	var cross_east := false
	for i in arr.size() - 1:
		for j in dep.size() - 1:
			var a0 := Vector2(arr[i].x, arr[i].z)
			var a1 := Vector2(arr[i + 1].x, arr[i + 1].z)
			if a0.x < 140.0 and a1.x < 140.0:
				continue          # dans le port : l'évitage devant le poste, réglé par la règle de passage (plus bas)
			if Geometry2D.segment_intersects_segment(a0, a1, Vector2(dep[j].x, dep[j].z), Vector2(dep[j + 1].x, dep[j + 1].z)) != null:
				cross_east = true
	var lanes_gap := absf(Layout.DEPART_E_Z - Layout.ARRIVE_E_Z) - 2.0 * pm.y
	check(Layout.ARRIVE_E_Z < Layout.DEPART_E_Z and not cross_east and lanes_gap >= 2.0 and (Layout.DEPART_EAST[0] as Vector3).x > (Layout.EAST_APPROACH_E[1] as Vector3).x,
		"E9 : passe est à droite (arrivée z %s au nord, départ z %s au sud), départ à l'est de la ligne d'arrivée, aucun croisement au large ; deux panamax à %s u (N10)" % [
		Fmt.num(Layout.ARRIVE_E_Z), Fmt.num(Layout.DEPART_E_Z), Fmt.num(lanes_gap)])
	# règle d'attente du croisement balisé : l'autre courant attend, à égalité le plus petit identifiant passe ; même courant
	# (suivi) : pas de règle de croisement
	var w: Rect2 = Layout.SHIP_CROSSINGS[0].rect
	var c := w.get_center()
	var ew_in := {"id": 5, "p": c, "dir": Vector2(1, 0), "len": 45.0, "w": 8.6, "stream": "ew", "ahead": [c + Vector2(8, 0)]}
	var ns_come := {"id": 2, "p": c + Vector2(0, w.size.y), "dir": Vector2(0, -1), "len": 34.0, "w": 7.5, "stream": "ns",
		"ahead": [c + Vector2(0, w.size.y * 0.4)]}
	var ew_come := {"id": 7, "p": c - Vector2(w.size.x, 0), "dir": Vector2(1, 0), "len": 45.0, "w": 8.6, "stream": "ew",
		"ahead": [c - Vector2(w.size.x * 0.4, 0)]}
	var h1 := ShipRules.crossing_holds([ew_in, ns_come])
	var h2 := ShipRules.crossing_holds([ns_come, ew_come])
	var h3 := ShipRules.crossing_holds([ew_in, ew_come])
	check(h1.has(2) and not h1.has(5) and h2.has(7) and not h2.has(2) and h3.is_empty(),
		"E9 : croisement balisé au large (fenêtre x %d…%d) — l'autre courant attend (%s), à égalité le plus petit identifiant passe (%s), même courant libre (%s)" % [
		int(w.position.x), int(w.end.x), str(h1.keys()), str(h2.keys()), str(h3.keys())])
	# toutes les paires de trajets qui se croisent (pilotages, départs, arrivées au mouillage, départs furieux) : simulées avec
	# les règles du diorama, sans contact (coques ≥ 2 u) et sans interblocage
	var res := _ef_crossings()
	# bouées du croisement balisé : à ≥ 1,5 u de toute coque sur les pilotages et les départs
	var buoy_gap := INF
	var fd2 := _ship_half("feeder")
	var paths: Array = []
	for k in 12:
		for bi in 4:
			paths.append([Layout.ship_path_pilot(k, bi), pm.y if bi >= 2 else fd2.y])
	for bi in 4:
		paths.append([Layout.ship_path_depart(bi, pm.y * 2.0, 3), pm.y if bi >= 2 else fd2.y])
	for w2 in Layout.SHIP_CROSSINGS:
		for bp in w2.get("buoys", []):
			for pp in paths:
				for p in Layout.sample_path(pp[0], 1.0):
					buoy_gap = minf(buoy_gap, Vector2(p.x, p.z).distance_to(bp) - float(pp[1]))
	check(int(res.bad) == 0 and int(res.n) > 20 and int(res.pairs) >= 5 and buoy_gap >= 1.5,
		"E9 : %d croisements de trajets hors du mouillage (%d essais, %d autres entre les places du mouillage) passés avec les règles d'attente — coques à %s u au plus près (≥ 2), %d s au plus long, sans interblocage %s ; bouées du croisement à %s u des coques" % [
		int(res.pairs), int(res.n), int(res.anchorage), Fmt.num(float(res.worst)), int(res.tmax), str(res.list), Fmt.num(buoy_gap)])
	# E10 : avec gate2, guérite sur l'îlot entre la 2ᵉ voie de sortie et l'entrée ; un portique par voie de sortie
	var booth := Layout.lot_rect("gate2")
	var out1 := Layout.road_out_x(true, 1)
	var truck_hw := 1.1
	var isl: Dictionary = Layout.GATE_ISLAND
	var isl_r := Rect2((isl.c as Vector2) - (isl.size as Vector2) * 0.5, isl.size)
	var portals := Layout.portal_rects(["scanner2", "gate2"])
	check(booth.position.x >= out1 + truck_hw and booth.end.x <= Layout.road_in_x(true) - truck_hw and isl_r.encloses(booth.grow(-0.05))
		and portals.size() == 2 and Layout.portal_rects(["scanner2"]).size() == 1,
		"E10 : guérite de gate2 sur son îlot (x %s…%s, entre les camions des voies x %s et %s), %d portiques avec gate2" % [
		Fmt.num(booth.position.x), Fmt.num(booth.end.x), Fmt.num(out1), Fmt.num(Layout.road_in_x(true)), portals.size()])
	# E12 : touchers Douane / barrières / Gate séparés d'au moins 10 u (avec et sans gate2) ; rue des bureaux derrière la tête de
	# file (z ≥ 60) ; gare : la rame coupée à la bouche du tunnel, sous la colline ; passage à niveau signalé sur la liaison
	var tap_min := INF
	for g2 in [false, true]:
		var pts: Array = [["douane", Layout.dept_pos("customs", 2)], ["gate", Layout.dept_pos("gate", 2)]]
		for p in Layout.PROPS:
			if String(p.get("tag", "")).begins_with("barrier") and (String(p.cond) == "" or (g2 and String(p.cond) == "gate2")) \
					and not (g2 and String(p.get("not", "")) == "gate2"):
				var ry := deg_to_rad(float(p.get("ry", 0.0)))
				var s := float(p.get("s", 1.0))
				pts.append(["barrière", Vector3(float(p.p[0]) + 1.9 * s * cos(ry), 0, float(p.p[2]) - 1.9 * s * sin(ry))])
		for i in pts.size():
			for j in range(i + 1, pts.size()):
				if String(pts[i][0]) == "barrière" and String(pts[j][0]) == "barrière":
					continue          # deux barrières : le même geste
				tap_min = minf(tap_min, (pts[i][1] as Vector3).distance_to(pts[j][1]))
	var street_ok := false
	for g in Layout.GROUNDS:
		if String(g.cond) == "t2" and String(g.type) == "road_x" and float(g.r[2]) == float(Layout.ROAD_X[0]) and float(g.r[1]) >= 60.0:
			street_ok = true
	# (lot F2, recalé : plus de colline-tunnel — la voie ferrée entre sous les arbres, et la rame se perd dans l'ombre de la
	# route forestière à la bouche RAIL_TUNNEL_X)
	var hill_ok := false
	for fr in Layout.FOREST_ROADS:
		var vp: Vector3 = fr.vanish
		if absf(vp.x - Layout.RAIL_TUNNEL_X) < 4.0 and absf(vp.z - Layout.RAIL_Z) < 3.0:
			hill_ok = true
	var signs := Layout.PROPS.filter(func(p: Dictionary) -> bool: return String(p.cond) == "rail" and String(p.m) == "sign").size()
	var marks := 0
	for it in Layout.street_props(3, ["rail", "berth3"]):
		if String(it.m) == "crosswalk" and absf((it.p as Vector3).x - float(Layout.RAIL_SHUTTLE.x)) < 3.0:
			marks += 1
	check(tap_min >= 10.0 and street_ok and hill_ok and signs >= 2 and marks >= 2,
		"E12 : touchers Douane / barrières / Gate à %s u au plus près ; rue des bureaux derrière la tête de file ; bouche du tunnel sous les arbres ; passage à niveau signalé (%d panneaux, %d marquages)" % [
		Fmt.num(tap_min), signs, marks])
	# mineurs : GNL à ≥ 4 u du bout du poste 4, IMO à ≥ 4 u du parc RTG ; bureau de pilotage avec un toit ; zone 8 réduite à la
	# voie et aux parkings, discrète ; crique : rien d'autre que la cale et son bateau à moins de 4 u de la cale
	var lng := Layout.lot_rect("lng")
	var b4 := Layout.lot_rect("berth4")
	var gap_lng := lng.position.y - b4.end.y
	var gap_rtg := Layout.lot_rect("imo").position.x - Layout.lot_rect("rtg").end.x
	var roof := Layout.PROPS.filter(func(p: Dictionary) -> bool: return String(p.cond) == "rpilot" and p.has("roof")).size() == 1
	var z8 := Layout.zone_by_id(8)
	var z8_area := absf(_poly_area(z8.poly))
	var sw_to: Vector3 = Layout.SLIPWAY.to
	var creek_bad: Array[String] = []
	var boats: Array = [Layout.lot_rect("tug2")]
	for it in Layout.STAGE_PROPS.harbor:
		if String(it.m) in ["pilot_boat", "tug"]:
			boats.append(Rect2(float(it.p[0]) - 3.0, float(it.p[2]) - 3.0, 6.0, 6.0))
	for r in boats:
		if _rect_dist(r as Rect2, Vector2(sw_to.x, sw_to.z)) < 4.0:
			creek_bad.append(str((r as Rect2).get_center()))
	check(gap_lng >= 4.0 and gap_rtg >= 4.0 and roof and bool(z8.get("discreet", false)) and z8_area < 1500.0 and creek_bad.is_empty(),
		"E mineurs : GNL à %s u du poste 4, IMO à %s u du parc RTG, bureau de pilotage avec un toit, zone 8 réduite (%d u²) et discrète, crique dégagée (%s)" % [
		Fmt.num(gap_lng), Fmt.num(gap_rtg), int(z8_area), str(creek_bad)])


static func _poly_area(poly: Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


## E9 : toutes les paires de trajets de navires qui se croisent, simulées deux à deux avec les règles du diorama
## (ShipRules.holds : suivi, navire qui coupe la route devant soi, croisement balisé ; HOLD_MAX) — un essai par croisement
## (point arrondi à 6 u, courants), départ à 90 u du croisement avec cinq retards ; hors du mouillage (croisements à 30 u d'une place, ou dans les 40 premiers u d'un appareillage).
func _ef_crossings() -> Dictionary:
	var pm := _ship_half("panamax")
	var fd := _ship_half("feeder")
	var P: Array = []
	for k in 12:
		for bi in 4:
			var hp: Vector2 = pm if bi >= 2 else fd
			var pil := Layout.ship_path_pilot(k, bi)
			pil.append(Layout.berth_ship_pos(bi, hp.y * 2.0))          # puis l'accostage
			P.append({"name": "pilotage %d→%d" % [k, bi], "p": pil, "stream": "ew" if bi >= 2 else "ns",
				"h": pm if bi >= 2 else fd, "anchor": k, "berth": bi, "yaw0": 0.35, "leave": 40.0,
				"streams": ShipRules.ship_streams(Ship.State.PILOTING, bi)})
	for bi in 4:
		var h: Vector2 = pm if bi >= 2 else fd
		P.append({"name": "départ %d" % bi, "p": Layout.ship_path_depart(bi, h.y * 2.0, 3), "stream": "ns" if bi < 2 else "", "h": h, "anchor": -1, "berth": bi,
			"streams": ShipRules.ship_streams(Ship.State.DEPARTING, bi)})
	var seen := {}
	var out := {"pairs": 0, "n": 0, "bad": 0, "worst": INF, "tmax": 0.0, "list": [], "anchorage": 0}
	for i in P.size():
		for j in range(i + 1, P.size()):
			var A: Dictionary = P[i]
			var B: Dictionary = P[j]
			if int(A.anchor) >= 0 and int(A.anchor) == int(B.anchor):
				continue          # même place de mouillage : un seul navire à la fois
			if int(A.berth) >= 0 and int(A.berth) == int(B.berth):
				continue          # même poste : le navire suivant n'y est piloté qu'une fois le poste libéré
			var c := _ef_cross(A.p, B.p)
			if c.is_empty():
				continue
			var q: Vector2 = c[0]
			var at_anchor := false
			for kk in 12:
				if Vector2(Layout.anchor_pos(kk).x, Layout.anchor_pos(kk).z).distance_to(q) < 30.0:
					at_anchor = true
			if at_anchor:
				out.anchorage = int(out.anchorage) + 1
				continue          # au mouillage, entre les places : hors de ces règles (voir le journal)
			var key := "%d,%d|%s|%s" % [roundi(q.x / 6.0), roundi(q.y / 6.0), String(A.stream), String(B.stream)]
			if seen.has(key):
				continue
			seen[key] = true
			out.pairs = int(out.pairs) + 1
			for dl in [[0.0, 0.0], [0.0, 2.0], [2.0, 0.0], [0.0, 4.0], [4.0, 0.0]]:          # retards au départ (s)
				var r := _ef_sim(A, B, float(c[1]) - 90.0, float(c[2]) - 90.0, float(c[1]) + 60.0, float(c[2]) + 60.0, q, dl)
				out.n = int(out.n) + 1
				out.worst = minf(float(out.worst), float(r[0]))
				out.tmax = maxf(float(out.tmax), float(r[1]))
				if float(r[0]) < 2.0 or float(r[1]) >= 150.0:
					out.bad = int(out.bad) + 1
					if (out.list as Array).size() < 4:
						(out.list as Array).append("%s × %s (%d, %d) %.1f u" % [A.name, B.name, int(q.x), int(q.y), float(r[0])])
	return out


## Premier croisement de deux polylignes (hors sommets communs) : [point, abscisse sur a, abscisse sur b], [] sinon.
func _ef_cross(a: Array, b: Array) -> Array:
	var sa := 0.0
	for i in a.size() - 1:
		var a0 := Vector2(a[i].x, a[i].z)
		var a1 := Vector2(a[i + 1].x, a[i + 1].z)
		var sb := 0.0
		for j in b.size() - 1:
			var b0 := Vector2(b[j].x, b[j].z)
			var b1 := Vector2(b[j + 1].x, b[j + 1].z)
			var r: Variant = Geometry2D.segment_intersects_segment(a0, a1, b0, b1)
			if r != null:
				var q: Vector2 = r
				if q.distance_to(a0) > 0.5 and q.distance_to(a1) > 0.5 and q.distance_to(b0) > 0.5 and q.distance_to(b1) > 0.5:
					return [q, sa + a0.distance_to(q), sb + b0.distance_to(q)]
			sb += b0.distance_to(b1)
		sa += a0.distance_to(a1)
	return []


func _ef_at(path: Array, len: float, s: float) -> Vector2:
	var q: Vector3 = Layout.polyline_at(path, clampf(s / len, 0.0, 1.0))[0]
	return Vector2(q.x, q.z)


## Deux navires (10 u/s) sur leurs trajets à partir des abscisses sa0, sb0, avec ShipRules.holds et la levée après HOLD_MAX :
## [écart minimal entre les coques, durée].
func _ef_sim(A: Dictionary, B: Dictionary, sa0: float, sb0: float, sa_end: float, sb_end: float, cross: Vector2, delay: Array = [0.0, 0.0]) -> Array:
	var ships := [A, B]
	var lens := [Layout.path_length(A.p), Layout.path_length(B.p)]
	var s := [maxf(0.0, sa0), maxf(0.0, sb0)]
	var ends := [minf(float(lens[0]), sa_end), minf(float(lens[1]), sb_end)]
	var held_t := [0.0, 0.0]
	var was := [false, false]
	var force_t := [0.0, 0.0]
	var gmin := INF
	var t := 0.0
	var dt := 0.1
	while t < 150.0 and (float(s[0]) < float(ends[0]) or float(s[1]) < float(ends[1])):
		var items: Array = []
		var pose: Array = []
		for k in 2:
			var sh: Dictionary = ships[k]
			var hh: Vector2 = sh.h
			var L := float(lens[k])
			var p := _ef_at(sh.p, L, s[k])
			var bow := _ef_at(sh.p, L, s[k] + hh.x)
			var st := _ef_at(sh.p, L, s[k] - hh.x)
			# centre de la coque au milieu de la corde, comme ShipView.hull_center
			p = p.lerp((bow + st) * 0.5, clampf(minf(float(s[k]), L - float(s[k])) / hh.x, 0.0, 1.0))
			var d := (bow - st).normalized() if bow.distance_to(st) > 0.5 else (_ef_at(sh.p, L, s[k] + 1.0) - p).normalized()
			if float(s[k]) < hh.x:          # poupe pas encore sur le trajet : du cap de départ à la corde (ShipView._chord_yaw)
				var yb := lerp_angle(float(sh.get("yaw0", 0.0)), atan2(-d.y, d.x), float(s[k]) / hh.x)
				d = Vector2(cos(yb), -sin(yb))
			pose.append([p, d])
			if float(s[k]) < float(ends[k]) and t >= float(delay[k]):
				var ah: Array[Vector2] = []
				for dd in ShipRules.AHEAD:
					ah.append(_ef_at(sh.p, L, s[k] + dd))
				var hs := ShipRules.hull_and_sweep(sh.p, float(s[k]), hh.x * 2.0, float(sh.get("yaw0", 0.0)))
				items.append({"id": k + 1, "p": p, "dir": d, "len": hh.x * 2.0, "w": hh.y * 2.0, "stream": sh.stream, "streams": sh.get("streams", {}), "ahead": ah, "k": k,
					"body": hs[0], "sweep": hs[1], "was_held": was[k]})
		var p0: Vector2 = pose[0][0]
		var p1: Vector2 = pose[1][0]
		# (coques comparées tant que les deux navires sont en route : un navire encore à sa place de départ — à quai, au
		# mouillage — n'est pas un croisement ; le bassin d'évitage reste celui du lot D)
		var en_route: bool = items.size() == 2 and float(s[0]) > float(A.get("leave", A.h.x)) and float(s[1]) > float(B.get("leave", B.h.x))      # (chacun a quitté sa place : poste, ou manœuvre d'appareillage au mouillage)
		# au croisement : l'un des deux navires à moins d'une demi-longueur (du plus long) du point de croisement — ailleurs,
		# ce sont les voies parallèles du chenal ou de la passe (N10)
		en_route = en_route and minf((pose[0][0] as Vector2).distance_to(cross), (pose[1][0] as Vector2).distance_to(cross)) < maxf(float(A.h.x), float(B.h.x))
		if en_route and p0.distance_to(p1) < A.h.x + B.h.x + 4.0:
			gmin = minf(gmin, _hulls_gap(p0, pose[0][1], A.h.x, A.h.y, p1, pose[1][1], B.h.x, B.h.y))
		var held := ShipRules.holds(items)
		for it in items:
			var k: int = it.k
			was[k] = held.has(it.id) and float(force_t[k]) <= 0.0
			if held.has(it.id) and float(force_t[k]) <= 0.0:
				held_t[k] = float(held_t[k]) + dt
				if float(held_t[k]) > ShipRules.HOLD_MAX:
					force_t[k] = ShipRules.HOLD_FORCE
					held_t[k] = 0.0
			else:
				held_t[k] = 0.0
				s[k] = minf(float(ends[k]), float(s[k]) + 10.0 * dt)
			force_t[k] = maxf(0.0, float(force_t[k]) - dt)
		t += dt
	return [gmin, t]


## Distance d'un point à un polygone (0 s'il est dedans).
func _poly_dist(p: Vector2, poly: PackedVector2Array) -> float:
	if Geometry2D.is_point_in_polygon(p, poly):
		return 0.0
	var best := INF
	for i in poly.size():
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()]).distance_to(p))
	return best


## Lot F2 — le golfe et le départ de rien : plan et données (la scène — départ, chantiers, trafic — est contrôlée par
## ui_smoke, `_f2_checks`).
func test_f2(db: DataDB) -> void:
	print("[lot F2 : golfe, forêt, départ de rien, chantiers, intro]")
	# 1. golfe : la rive d'en face au nord, des deux côtés de l'entrée (les sorties nord passent entre les deux) ; les rives du
	# golfe loin de toutes les voies des navires (arrivée, mouillage jusqu'à 42 places, départs, sorties, barges)
	var fs: Array = Layout.FAR_SHORES
	var west := 0
	var east := 0
	var north := true
	var mouth := Vector2(-INF, INF)
	for f in fs:
		var p: Vector3 = f.p
		north = north and p.z <= -250.0
		if p.x < 0.0:
			west += 1
			mouth.x = maxf(mouth.x, p.x + 130.0)
		else:
			east += 1
			mouth.y = minf(mouth.y, p.x - 130.0)
	var exits_in_mouth := true
	for p in Layout.EXIT_NORTH:
		exits_in_mouth = exits_in_mouth and (p as Vector3).x > mouth.x + 20.0 and (p as Vector3).x < mouth.y - 20.0
	var pts: Array[Vector3] = [Layout.SPAWN, Layout.EXIT]
	pts.append_array(Layout.EXIT_NORTH)
	pts.append_array(Layout.DEPART_EAST)
	pts.append_array(Layout.EAST_APPROACH_E)
	for k in 42:
		pts.append(Layout.anchor_pos(k))
	for k in 12:
		pts.append_array(Layout.sample_path(Layout.ship_path_arrive(k), 4.0))
		pts.append_array(Layout.sample_path(Layout.ship_path_leave(Layout.anchor_pos(k)), 4.0))
	for bi in 4:
		pts.append_array(Layout.sample_path(Layout.ship_path_depart(bi, 8.0, 3), 4.0))
	for i in Layout.RECLAIM_BARGE_X0.size():
		pts.append(Vector3(float(Layout.RECLAIM_BARGE_X0[i]), 0, Layout.RECLAIM_BARGE_LANE_Z))
	var near_ship := INF
	for p in pts:
		for poly in Layout.gulf_polys():
			near_ship = minf(near_ship, _poly_dist(Vector2(p.x, p.z), poly))
	check(west == 1 and east == 1 and north and exits_in_mouth and near_ship >= 40.0,
		"F2 golfe : rive d'en face au nord des deux côtés (entrée x %d…%d, sorties nord dedans) ; rives du golfe à %d u au plus près des voies des navires (≥ 40)" % [
		int(mouth.x), int(mouth.y), int(near_ship)])
	# 2. plus de collines-tunnels ; l'autoroute (ses deux bouts), la rue du village et la voie ferrée entrent sous les arbres,
	# et c'est là que le trafic se perd
	var hills_on_ends := 0
	for p in Layout.PROPS:
		if String(p.m) == "hill":
			var hp := Vector2(float(p.p[0]), float(p.p[2]))
			for e in [Vector2(Layout.HIGHWAY_ENDS[0], 141.0), Vector2(Layout.HIGHWAY_ENDS[1], 141.0), Vector2(Layout.RAIL_TUNNEL_X, Layout.RAIL_Z)]:
				if hp.distance_to(e) < 14.0:
					hills_on_ends += 1
	var ends_ok := 0
	for x_end in Layout.HIGHWAY_ENDS:
		for fr in Layout.FOREST_ROADS:
			var vp: Vector3 = fr.vanish
			if absf(vp.x - float(x_end)) < 0.5 and vp.z > Layout.HIGHWAY_Z0 and vp.z < Layout.HIGHWAY_Z1:
				ends_ok += 1
	var rail_ok := Layout.FOREST_ROADS.any(func(fr: Dictionary) -> bool: return absf((fr.vanish as Vector3).x - Layout.RAIL_TUNNEL_X) < 0.5 and absf((fr.vanish as Vector3).z - Layout.RAIL_Z) < 0.5)
	check(hills_on_ends == 0 and ends_ok == 2 and rail_ok, "F2 : plus de colline-tunnel ; autoroute (deux bouts) et voie ferrée sous les arbres, le trafic s'y perd (%d bouts)" % ends_ok)
	# 3. forêt dense : sur la terre (hors du port : bande au sud de l'autoroute et terres du golfe), jamais au bord de l'eau ni
	# sur l'autoroute ; budget raisonnable pour un téléphone (≤ 450 blocs de ≈ 1 000 triangles, en carrés de 120 u)
	var forest := Layout.forest()
	var f_bad: Array[String] = []
	var coast := PackedVector2Array(Layout.COAST)
	for it in forest:
		var p: Vector3 = it.p
		var p2 := Vector2(p.x, p.z)
		if not Layout._land_ring(p2, 8.5) or (Geometry2D.is_point_in_polygon(p2, coast) and not Layout.FOREST_STRIP.has_point(p2)) \
				or Rect2(-140, 133, 334, 16).has_point(p2):
			f_bad.append("(%d, %d)" % [int(p.x), int(p.z)])
	# (lot F3, recalé : ≤ 700 blocs au lieu de 450 — la forêt profonde a des blocs ×1 au lieu de ×2,2, donc plus serrés ; au zoom
	# le plus large, triangles dessinés mesurés identiques à ±2 % (LOD du modèle, carrés de 120 u ; carrés profonds sans ombre))
	check(forest.size() >= 120 and forest.size() <= 700 and f_bad.is_empty(),
		"F2 forêt : %d blocs, tous sur la terre hors du port, loin de l'eau et de l'autoroute (%s)" % [forest.size(), str(f_bad.slice(0, 4))])
	# 4. la caméra ne montre jamais le bord du monde : au zoom le plus large, aux quatre coins des bornes, à chaque palier,
	# l'écran (portrait) reste dans le monde habillé (forêt, rives, eau)
	var rig := CameraRig.new()
	var edge_bad: Array[String] = []
	var s35 := sin(deg_to_rad(35.0))
	var r_dir := Vector2(0.7071, -0.7071)
	var u_dir := Vector2(-0.7071, -0.7071)
	var widest := 0.0
	for t in [1, 2, 3]:
		rig.set_tier_bounds(t)
		var z: float = rig.zoom_max
		widest = maxf(widest, z)
		var hr := z * 0.5
		var hu := z * CameraRig.REF_H / CameraRig.REF_W * 0.5 / s35
		var b: Rect2 = rig.bounds
		for c in [b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)]:
			for sr in [-1.0, 1.0]:
				for su in [-1.0, 1.0]:
					var q: Vector2 = c + r_dir * hr * sr + u_dir * hu * su
					if not Layout.FOREST_AREA.has_point(q) or q.x < -410.0 or q.x > 490.0 or q.y < -450.0 or q.y > 450.0:
						edge_bad.append("T%d (%d, %d)" % [t, int(q.x), int(q.y)])
	rig.free()
	check(edge_bad.is_empty() and widest <= CameraRig.ZOOM_MAX, "F2 : zoom le plus large %d, aux quatre coins des bornes l'écran reste dans le monde habillé (%s)" % [int(widest), str(edge_bad.slice(0, 3))])
	# 5. départ de rien : quatre pièces dans l'ordre (quai → grue → parc → gate), chacune ses éléments (« grp »), son chantier
	# (lot G2, remplace « F2 départ » : plus de séquence automatique — les pièces du départ sont six bâtiments, en tête de la
	# liste, chantiers de 3 à 6 s ; le décor de chaque pièce porte son bâtiment ; l'estacade ruinée devant le quai n°1, la
	# route d'accès en friche avant la piste, sur la terre)
	var ids: Array = db.buildings.slice(0, 6).map(func(b: Dictionary) -> String: return String(b.id))
	var grps := {}
	for p in Layout.PROPS:
		if p.has("grp"):
			grps[String(p.grp)] = true
	for g in Layout.GROUNDS:
		if g.has("grp"):
			grps[String(g.grp)] = true
	var grp_ok := grps.keys().all(func(k: String) -> bool: return ids.has(k)) and grps.has("quay1") and grps.has("yard") and grps.has("track")
	var dur_ok := ids.all(func(bid: String) -> bool: return float(Layout.site_spec(bid).get("dur", 0.0)) >= 3.0 and float(Layout.site_spec(bid).get("dur", 0.0)) <= 6.0)
	var jetty := Layout.before_state("quay1").filter(func(it: Dictionary) -> bool: return String(it.m) == "jetty_ruin")
	var jetty_ok := jetty.size() == 1 and (jetty[0].p as Vector3).z < Layout.SEA_EDGE_Z and (jetty[0].p as Vector3).x > -36.0 and (jetty[0].p as Vector3).x < -12.0
	var yard_ok := Layout.before_state("track").all(func(it: Dictionary) -> bool: return Layout.on_land(Vector2((it.p as Vector3).x, (it.p as Vector3).z), false)) \
		and Layout.STARTER.is_empty()
	check(ids == PortSim.STARTERS and grp_ok and dur_ok and jetty_ok and yard_ok,
		"G2 départ : %s en tête de la liste, chantiers de 3 à 6 s, estacade ruinée devant le quai n°1, friche de la route sur la terre (groupes %s)" % [str(ids), str(grps.keys())])
	# 6. chantiers de chaque case : 3 s (petite) à 6 s (quais, grande case) ; état d'avant (rochers, broussailles) sur les cases
	# à terre, dans leur empreinte, sur la terre ; rien sur l'eau, un quai ou le terre-plein
	var site_bad: Array[String] = []
	for bid in Layout.LOTS:
		var sp := Layout.site_spec(bid)
		var d := float(sp.get("dur", 0.0))
		if d < 3.0 or d > 6.0 or ((bid.begins_with("berth") or bid == "quay_ext") and d != 6.0):
			site_bad.append("%s %s s" % [bid, Fmt.num(d)])
		var bs := Layout.before_state(bid)
		var l: Dictionary = Layout.LOTS[bid]
		# (lot G2, recalé : la piste a sa friche — rochers sur la route — et le quai n°1 son estacade ruinée, sur l'eau devant lui)
		var wet: bool = bool(l.get("water", false)) or (l.has("on") and not bool(l.get("ground", false))) or bool(l.get("portal", false)) or bid.begins_with("berth") or bid == "quay_ext" \
			or bid == "gate2" or bool(Layout.zone_by_id(int(l.zone)).get("reclaim", false))
		if wet != bs.is_empty():
			site_bad.append("%s état d'avant %d" % [bid, bs.size()])
		for it in bs:
			var ip: Vector3 = it.p
			if bid in ["quay1", "track"]:      # (lot G2 : l'estacade sur l'eau, la palissade de la piste sur la route)
				break
			if not Layout.lot_rect(bid).has_point(Vector2(ip.x, ip.z)) or not Layout.on_land(Vector2(ip.x, ip.z), true):
				site_bad.append("%s hors case" % bid)
				break
	var small := float(Layout.site_spec("customs1").dur)
	check(site_bad.is_empty() and small <= 3.6, "F2 chantiers : 3 s (douane %s s) à 6 s (quais), état d'avant sur les cases à terre seulement (%s)" % [Fmt.num(small), str(site_bad.slice(0, 4))])
	# 7. premier navire du T1 : il naît dans le chenal (voie d'entrée) et va droit au poste n°1, toujours sur l'eau
	var fp := Layout.first_ship_path(0)
	var field := Terrain.distance_field(Layout.land_polys(false))
	var fp_land := 0
	for p in Layout.sample_path(fp, 1.5):
		if Terrain.field_at(field, Vector2(p.x, p.z)) < 2.5:
			fp_land += 1
	check(fp.size() > 4 and fp[0].distance_to(Layout.channel_lane(Layout.FIRST_SHIP_LANE, 1)) < 0.01 and fp[-1].distance_to(Vector3(Layout.berth_center(0), 0, Layout.APPROACH_Z)) < 0.01 and fp_land == 0,
		"F2 : premier navire — du chenal (%d, %d) à la voie d'approche du poste n°1, jamais à moins de 2,5 u de la terre (%d)" % [int(fp[0].x), int(fp[0].z), fp_land])
	# 8. intro : trois cartes de la narratrice (palier 0, « La Crique ») — la lettre du notaire, la crique et les voisins, le
	# vieux quai à rebâtir ; ton de l'univers (Odette, golfe d'Ambre), lisibles (≤ 280 caractères)
	var cards: Array = db.tier_def(0).get("intro", [])
	var all_txt := ""
	var long := 0
	for c in cards:
		all_txt += String(c.title) + " " + String(c.text) + " "
		if String(c.text).length() > 280:
			long += 1
	check(cards.size() == 3 and all_txt.contains("Odette") and all_txt.contains("golfe d'Ambre") and all_txt.contains("notaire") and long == 0
		and String(db.tier_def(0).name) == "La Crique" and not String(db.tier_def(1).story).contains("rouillée"),
		"F2 intro : 3 cartes (%s), Odette et le golfe d'Ambre, palier 0 « La Crique »" % str(cards.map(func(c: Dictionary) -> String: return String(c.title))))


## Lot F3/G1 — chapitre 1 « La Crique » : la pêche (module de la simulation), les cartes à niveaux et les bâtiments, le loyer
## manuel et le bateau qui repart sans payer, Marcel, l'annonce, la Concession et le plafond R₀, le bot (pressé, tranquille),
## la sauvegarde v7 et sa migration, la nouvelle concession, les trajets des bateaux, les nuages, la forêt profonde, le tutoriel.
func test_f3(db: DataDB) -> void:
	print("[lot F3/G1 — chapitre 1 « La Crique »]")
	var fc: Dictionary = db.cfg("fishing")
	# 1. PortSim.new : port ouvert, pas de pêche (tests et parties d'avant F3 ; une partie neuve jouée appelle begin_act0)
	var s0 := PortSim.new(db, 7)
	check(not s0.fishing.act0 and s0.fishing.places == 0 and s0.fishing.rate_estimate() == 0.0, "F3 : PortSim.new — port ouvert, pas de pêche")
	# 2. la Crique : 0 $, port fermé — seule la pêche tourne (horloge du port, navires, aléas, révélations, compteurs figés) ; le
	# loyer est à la main : sans toucher, un bateau rentré attend `rent_wait` s puis repart sans payer (0 $ gagné)
	var s := PortSim.new(db, 7)
	s.begin_act0()
	# (lot G2, recalé : la partie jouée part de la friche — aucun navire avant le quai n°1 ; on vérifie que rien ne bouge)
	var ships0 := s.ships.size()
	var st0: Array = s.ships.map(func(sh: Ship) -> int: return sh.state)
	var money_ok := s.money == 0.0
	var build_blocked := not s.build("quay_ext")
	var first := s.buy_fish_places(1)
	var waited := 0
	for i in 600:
		s.step(0.25)
		for k in s.fishing.boats.size():
			if int(s.fishing.boats[k].phase) == Fishing.Phase.WAIT:
				waited += 1
	var frozen := s.time == 0.0 and s.ships.size() == ships0 and s.ships.map(func(sh: Ship) -> int: return sh.state) == st0 \
		and s.active_event.is_empty() and s.features.is_empty() and s.counter("evp") == 0.0 and s.missions_claimed.is_empty()
	check(money_ok and build_blocked and first and frozen and s.fishing.places == 1 and s.fishing.boats.size() == 2 and s.money == 0.0 \
		and s.fishing.rents_lost >= 2 and waited > 0 and s.fishing.clock >= 149.0 and s.fishing.landings >= 2,
		"G1 Crique : 0 $, rien ne se bâtit au port, ponton gratuit (2 barques) ; 150 s de pêche, port figé (horloge %s) ; sans toucher, les bateaux attendent puis repartent sans payer (%d perdus, %s)" % [
		str(s.time), s.fishing.rents_lost, Fmt.money(s.money)])
	# 3. encaisser à la main : toucher un bateau rentré paie `valeur × ticket` ; Marcel se présente après `after_rents` loyers ;
	# embauché, il encaisse tout (plus rien à toucher), le hors-ligne passe de « figé » à son rythme, les Heures sup se révèlent
	var m := PortSim.new(db, 7)
	m.begin_act0()
	m.buy_fish_places(1)
	var paid := 0.0
	var npaid := 0
	var offered_at := -1
	var bubble_before := false
	for i in 1600:
		m.step(0.25)
		for k in m.fishing.boats.size():
			if m.fishing.can_collect(k):
				bubble_before = true
				var a := m.fish_collect(k)
				if a > 0.0:
					paid += a
					npaid += 1
		if m.fishing.marcel_offered and offered_at < 0:
			offered_at = npaid
			break
	var off_before := m.apply_offline(3600.0)
	var frozen_off := off_before.is_empty() and m.money == paid
	m.money += m.fishing.marcel_cost()
	var hired := m.hire_marcel()
	var auto := 0.0
	var collectable := 0
	var m0 := m.money
	for i in 400:
		m.step(0.25)
		for k in m.fishing.boats.size():
			if m.fishing.can_collect(k):
				collectable += 1
	auto = m.money - m0
	var off_after := m.apply_offline(600.0)
	var value0 := float(fc.boats.dinghy.value)
	check(bubble_before and npaid >= 1 and paid >= value0 * 0.85 * float(npaid) and offered_at == int(fc.marcel.after_rents) and frozen_off \
		and hired and collectable == 0 and auto > 0.0 and m.fishing.rents_lost == 0 and not m.feature("boost") and m.counter("managers") == 1.0 \
		and absf(float(off_after.get("money", 0.0)) - 600.0 * m.fishing.rate_estimate()) < 0.01,
		"G1 loyer à la main : %d loyers encaissés (%s), Marcel se présente au %dᵉ ; avant lui le hors-ligne est figé (%s) ; embauché (%s) : plus rien à toucher, %s encaissés seuls en 100 s, Heures sup pas révélées (lot G1-d), hors-ligne %s pour 10 min" % [
		npaid, Fmt.money(paid), offered_at, frozen_off, hired, Fmt.money(auto), Fmt.money(float(off_after.get("money", 0.0)))])
	# 4. les cartes : Places 8 niveaux (9 barques), coûts croissants ; Services 10 niveaux, paliers nommés ×3 ; bâtiments dans
	# l'ordre ; la Concession dès la marina (pas avant) ; tout au maximum → plafond R₀ dans 4–6 $/s ; après la Concession, les
	# cartes restantes restent achetables jusqu'à leur maximum, la pêche continue (loyers par Marcel)
	var c := PortSim.new(db, 3)
	c.begin_act0()
	c.money = 1.0e5
	c.buy_fish_places(1)
	var pc1 := c.fishing.places_cost()
	c.buy_fish_places(1)
	var costs_up := c.fishing.places_cost() > pc1 and pc1 > 0.0
	var named := c.fishing.services_cost() > 2.5 * float(fc.services.cost)      # niveau 1 = la criée, ×3
	var early := c.fishing.concession_available() or c.buy_fish_building("concession")
	var wrong_order := c.buy_fish_building("pier")
	c.buy_fish_building("trawler")
	c.buy_fish_building("pier")
	var before_marina := c.fishing.concession_available()
	c.buy_fish_building("marina")
	var after_marina := c.fishing.concession_available() and c.fishing.sails() == 6
	var n_pl := 0
	while c.buy_fish_places(1):
		n_pl += 1
	var n_sv := 0
	while c.buy_fish_services(1):
		n_sv += 1
	c.buy_fish_building("marina2")
	c.buy_fish_building("marina3")
	var maxed := c.fishing.maxed() and c.fishing.places == 8 and c.fishing.services == 10 and c.fishing.boat_count("dinghy") == 9 \
		and c.fishing.boat_count("trawler") == 2 and c.fishing.boat_count("tuna") == 1 and c.fishing.sails() == 20
	c.fishing.marcel_offered = true
	c.hire_marcel()
	var r0 := c.fishing.rate_estimate()
	var cap_ok := r0 >= 4.0 and r0 <= 6.0 and absf(c.fishing.cap_rate() - r0) < 0.01
	var conc := c.buy_fish_building("concession")
	var opened := c.act0_ready()      # (la bascule de l'interface finit par open_port)
	c.open_port()
	var m1 := c.money
	for k in 240:
		c.step(0.25)
	var after := c.money - m1
	check(costs_up and named and not early and not wrong_order and not before_marina and after_marina and n_pl == 6 and n_sv == 10 and maxed \
		and cap_ok and conc and opened and c.time >= 59.9 and after > 0.5 * 60.0 * r0 and c.fishing.earned > 0.0 and Info.SOURCE_NAMES.has("fish"),
		"G1 cartes : Places ×1,35 (%s), criée ×3 (%s), Concession dès la marina (avant %s, après %s), bâtiments dans l'ordre (%s %s), niveaux %d/%d, tout au maximum (%s : 9 barques, 2 chalutiers, 1 thonier, 20 voiliers) → R₀ %s/s (4–6, %s) ; Concession (%s %s) = port ouvert (horloge %s), la pêche continue (%s en 60 s)" % [
		costs_up, named, before_marina, after_marina, not early, not wrong_order, n_pl, n_sv, maxed, Fmt.num(r0), cap_ok, conc, opened, Fmt.num(c.time), Fmt.money(after)])
	# après la Concession : les cartes restantes restent achetables (une partie pressée)
	var h := PortSim.new(db, 3)
	h.begin_act0()
	h.money = 1.0e5
	h.buy_fish_places(1)
	for bid in ["trawler", "pier", "marina", "concession"]:
		h.buy_fish_building(bid)
	h.open_port()
	var late_ok := h.buy_fish_places(1) and h.buy_fish_services(1) and h.buy_fish_building("marina2") and not h.fishing.act0 and h.time == 0.0
	check(late_ok, "G1 après la Concession : Places, Services et la marina restent achetables jusqu'à leur maximum")
	# 5. l'annonce du port : à la 8ᵉ minute, la criée faite, à ≥ 45 s de Marcel → « Missions » révélé, la mission « Signer la
	# Concession » en tête, accomplie à la Concession
	var an := PortSim.new(db, 5)
	an.begin_act0()
	an.money = 1.0e4
	an.buy_fish_places(1)
	an.fishing.clock = float(fc.announce_at) + 1.0
	an.step(0.25)
	var not_yet := not an.fishing.announced          # pas de criée
	an.buy_fish_services(1)
	an.fishing.marcel_offered = true
	an.hire_marcel()                                 # une nouveauté à l'instant : l'annonce attend 45 s
	an.step(0.25)
	var gap_wait := not an.fishing.announced
	for k in 200:
		an.step(0.25)
	var vis := Objectives.visible_missions(an)
	var first_m := String(vis[0].id) == "c0" and not Objectives.mission_done(an, vis[0])
	for bid in ["trawler", "pier", "marina", "concession"]:
		an.buy_fish_building(bid)
	check(not_yet and gap_wait and an.fishing.announced and an.feature("missions") and first_m and Objectives.mission_done(an, vis[0]) and an.fishing.has("concession"),
		"G1 annonce : à la 8ᵉ minute, criée faite, 45 s après Marcel (%s, %s) ; Missions révélé, « Signer la Concession » en tête, accomplie à la Concession" % [not_yet, gap_wait])
	# 6. le bot joue la Crique sur les 4 graines : tranquille (plafond puis Concession) 15–20 min, pressé (Concession dès la
	# marina) ≤ 15 min (cible 12 : voir le journal), Marcel embauché, jamais un loyer perdu
	var durs: Array[String] = []
	var dur_ok := true
	for sd in [1, 2, 3, 4]:
		var bs := PortSim.new(db, sd)
		bs.begin_act0()
		var bot := Bot.new(bs)
		var d := bot.run_act0()
		var bs2 := PortSim.new(db, sd)
		bs2.begin_act0()
		var bot2 := Bot.new(bs2)
		bot2.hurry = true
		var d2 := bot2.run_act0()
		durs.append("g%d %s / %s" % [sd, Fmt.duration(d), Fmt.duration(d2)])
		dur_ok = dur_ok and d >= 900.0 and d <= 1200.0 and d2 <= 930.0 and not bs.fishing.act0 and bs.fishing.maxed() and bs.fishing.marcel \
			and bs.fishing.rents_lost == 0 and bs2.fishing.marcel and bs2.fishing.announced and bs.time == 0.0
	check(dur_ok, "G1 durée de la Crique (bot tranquille 15–20 min / pressé ≤ 15 min 30, cible 14 : journal G1-d) : %s" % ", ".join(durs))
	# 7. sauvegarde v7 : aller-retour en pleine Crique (cartes, bateaux, loyers en attente, horloges, tirage, Heures sup sur
	# clock()) ; v6 en cours d'acte 0 → la Crique recommence (0 $) ; v6 au T1 → Crique finie (plafond, Marcel, Concession)
	var sv := PortSim.new(db, 5)
	sv.begin_act0()
	sv.buy_fish_places(1)
	for k in 200:
		sv.step(0.25)
	sv.money += 100.0
	sv.buy_fish_places(2)
	sv.buy_fish_services(1)
	for k in 37:
		sv.step(0.25)
	var dd: Dictionary = JSON.parse_string(JSON.stringify({"sim": sv.to_dict()})).sim
	var sl := PortSim.new(db)
	sl.from_dict(dd)
	var same := sl.fishing.act0 and sl.fishing.places == 3 and sl.fishing.services == 1 and sl.fishing.boats.size() == sv.fishing.boats.size() \
		and is_equal_approx(sl.fishing.clock, sv.fishing.clock) and sl.time == 0.0 and sl.fishing.rents_lost == sv.fishing.rents_lost
	for k in 120:
		sv.step(0.25)
		sl.step(0.25)
	same = same and is_equal_approx(sl.money, sv.money) and sl.fishing.landings == sv.fishing.landings and sl.fishing.rents_lost == sv.fishing.rents_lost
	var vre := RegEx.create_from_string("const VERSION := (\\d+)").search(FileAccess.get_file_as_string("res://autoload/save.gd"))
	var vmap := {"VERSION": int(vre.get_string(1)) if vre != null else 0}
	# v6 en cours d'acte 0 (clé « level », pas « places ») : la Crique recommence
	var v6: Dictionary = JSON.parse_string(JSON.stringify(sv.to_dict()))
	v6.act0 = {"on": true, "replay": false, "level": 3, "boats": [], "clock": 100.0, "act0_time": 100.0, "landings": 4, "helps": 2, "earned": 40.0}
	v6.money = 80.0
	var r6 := PortSim.new(db)
	r6.from_dict(v6)
	var restart := r6.fishing.act0 and r6.fishing.places == 0 and r6.money == 0.0 and r6.fishing.boats.is_empty()
	# v6 au T1 (ou sans clé act0) : Crique finie
	var old_d := s0.to_dict()
	old_d.erase("act0")
	old_d.boost_ready_at = 100.0
	var mg := PortSim.new(db)
	mg.from_dict(old_d)
	var t1d: Dictionary = JSON.parse_string(JSON.stringify(s0.to_dict()))
	t1d.act0 = {"on": false, "replay": false, "level": 5, "boats": [], "clock": 300.0, "act0_time": 220.0, "landings": 20, "helps": 23, "earned": 300.0}
	t1d.boost_ready_at = 100.0
	var mg2 := PortSim.new(db)
	mg2.from_dict(t1d)
	check(int(vmap.get("VERSION", 0)) >= 7 and dd.has("act0") and int(dd.act0.get("v", 0)) == 7 and same and restart \
		and not mg.fishing.act0 and mg.fishing.maxed() and mg.fishing.marcel and mg.fishing.has("concession") and mg.fishing.boats.size() == 12 and not mg.act0_ready() \
		and not mg2.fishing.act0 and mg2.fishing.maxed() and is_equal_approx(mg2.boost_ready_at, 320.0) and mg2.fishing.act0_time == 220.0,
		"G1 sauvegarde v7 : aller-retour en pleine Crique (niveau %d/%d, %d bateaux, même suite) ; v6 en cours d'acte 0 → la Crique recommence (%s) ; v6 au T1 → Crique finie (plafond, Marcel, Concession, Heures sup décalées)" % [
		sl.fishing.places, sl.fishing.services, sl.fishing.boats.size(), restart])
	# 8. nouvelle concession : la pêche est reprise au plafond, la Crique ne se rejoue pas
	var fin := PortSim.new(db, 2)
	fin.fishing.migrate_done()
	fin.tier = 3
	fin.finished = true
	fin.counters["evp"] = 2.6e6
	var nc := PortSim.new(db, 4)
	nc.carry_over(fin)
	check(nc.fishing.maxed() and not nc.fishing.act0 and nc.fishing.marcel and nc.fishing.rate_estimate() > 4.0, "G1 nouvelle concession : la pêche est reprise au plafond, pas de Crique")
	# 9. trajets des bateaux : jamais à terre, jamais sur un ponton, le quai, la jetée ni la marina, loin du chenal et du mouillage
	# des cargos ; vitesse de croisière lente (aucun sprint), glissement latéral à la place ; le caboteur de l'annonce dans le trou
	# des nuages, loin des coins de pêche
	var bad: Array[String] = []
	var spd_max := 0.0
	var spd_at := ""
	var beam := {"dinghy": 0.52, "trawler": 1.1, "tuna": 1.43}
	var rects := Layout.anse_obstacles()
	var min_anchor := INF
	var min_chan := INF
	for cls in Layout.FISH_BERTHS:
		var bd: Dictionary = fc.boats[cls]
		for slot in (Layout.FISH_BERTHS[cls] as Array).size():
			var po: Array = Layout.fish_path_out(cls, slot).pts
			var lead := Vector2((po[-1] as Vector3).x - (po[-2] as Vector3).x, (po[-1] as Vector3).z - (po[-2] as Vector3).z).normalized()
			var kinds := {"out": Layout.fish_path_out(cls, slot), "back": Layout.fish_path_back(cls, slot, Layout.fish_ground(cls, slot), lead),
				"arrivée": Layout.fish_path_back(cls, slot, Layout.fish_sea_entry(cls))}
			for kn in kinds:
				var wp := Layout.fish_weigh(kinds[kn])
				var dur := float(bd.out if kn == "out" else bd.back)
				var v := float(wp.len) / dur
				var vpk := v * (1.0 / (1.0 - minf(0.25, Layout.FISH_RAMP_S / dur)))
				if vpk > spd_max:
					spd_max = vpk
					spd_at = "%s %s %d" % [cls, kn, slot]
				for p in Layout.sample_path(kinds[kn].pts, 0.8):
					var p2 := Vector2(p.x, p.z)
					if Layout.any_land(p2):
						bad.append("%s %s %d à terre (%d, %d)" % [cls, kn, slot, int(p.x), int(p.z)])
					for r in rects:
						if r.grow(float(beam[cls]) - 0.05).has_point(p2) and not (kn != "out" and p2.distance_to(Vector2(Layout.fish_berth(cls, slot).x, Layout.fish_berth(cls, slot).z)) < 2.0):
							bad.append("%s %s %d sur un ouvrage (%d, %d)" % [cls, kn, slot, int(p.x), int(p.z)])
					if not Layout.in_cloud_hole(p2):
						bad.append("%s %s %d sous les nuages (%d, %d)" % [cls, kn, slot, int(p.x), int(p.z)])
					for an2 in Layout.ANCHORS:
						min_anchor = minf(min_anchor, p2.distance_to(Vector2(an2.x, an2.z)))
					for ch in Layout.CHANNEL:
						min_chan = minf(min_chan, p2.distance_to(Vector2(ch.x, ch.z)))
					min_anchor = minf(min_anchor, p2.distance_to(Vector2(Layout.SPAWN.x, Layout.SPAWN.z)))
	var pass_min := INF
	var pass_hole := 0
	var pass_n := 0
	for p in Layout.sample_path(Layout.PASSING_SHIP_PATH, 2.0):
		pass_n += 1
		if Layout.in_cloud_hole(Vector2(p.x, p.z)):
			pass_hole += 1
		for cls in Layout.FISH_GROUNDS:
			for g in Layout.FISH_GROUNDS[cls]:
				pass_min = minf(pass_min, Vector2(p.x, p.z).distance_to(g))
	check(bad.is_empty() and min_anchor >= 40.0 and min_chan >= 60.0 and spd_max <= 6.0 and pass_min >= 14.0 and pass_hole >= pass_n * 0.6,
		"G1 trajets des bateaux (9 barques, 2 chalutiers, thonier à la jetée) : ni terre ni ouvrage ni nuages (%s), ≥ %d u du mouillage, ≥ %d u du chenal, vitesse au plus %s u/s (%s) ; caboteur de l'annonce à ≥ %d u des coins de pêche, visible %d/%d" % [
		str(bad.slice(0, 3)), int(min_anchor), int(min_chan), Fmt.num(spd_max), spd_at, int(pass_min), pass_hole, pass_n])
	# 10. les nuages : le trou contient l'anse (places, bâtiments, cabane, route du mareyeur jusqu'à la forêt, marina, jetée) et
	# rien du port (quai n°1, parc, gate, estacade), ni le pôle nautique du cap ; la couverture va au-delà du rectangle habillé
	var hole_bad: Array[String] = []
	for cls in Layout.FISH_BERTHS:
		for b in Layout.FISH_BERTHS[cls]:
			if not Layout.in_cloud_hole(Vector2(b.x, b.z)):
				hole_bad.append("place %s" % cls)
	for id in Layout.ANSE_BUILDINGS:
		var p: Vector3 = Layout.ANSE_BUILDINGS[id].p
		if not Layout.in_cloud_hole(Vector2(p.x, p.z)):
			hole_bad.append(id)
	for q in [Vector2(Layout.ODETTE_HUT.p.x, Layout.ODETTE_HUT.p.z), Vector2(-99, 95), Vector2(Layout.PIER.p.x, Layout.PIER.p.z), Vector2(-125, 37), Vector2(-113, 37)]:
		if not Layout.in_cloud_hole(q):
			hole_bad.append(str(q))
	for q in [Vector2(-24, -7), Vector2(-20, 10), Vector2(-21, 45), Vector2(-62, -16), Vector2(-30, -60), Vector2(-120, 110), Vector2(-60, 60)]:
		if Layout.in_cloud_hole(q):
			hole_bad.append("port/cap/village visible " + str(q))
	var cover_ok := Layout.CLOUD_COVER.encloses(Rect2(-320, -340, 720, 690))
	# la brume (plan unique) : nulle sur tout le trou de l'anse, dense (≥ 0,45) sur le port, le cap et le village, ≈ 0,72 au cœur
	for r in Layout.CLOUD_HOLE:
		var rr := r as Rect2
		for i in 9:
			for j in 9:
				var q := rr.position + rr.size * Vector2(float(i) / 8.0, float(j) / 8.0)
				if CloudLayer.veil_alpha(q) > 0.0:
					hole_bad.append("brume dans l'anse " + str(q))
	for q in [Vector2(-24, -7), Vector2(-20, 10), Vector2(-21, 45), Vector2(-62, -16), Vector2(-30, -60), Vector2(-120, 110), Vector2(-60, 60)]:
		if CloudLayer.veil_alpha(q) < 0.45:
			hole_bad.append("brume trop claire " + str(q))
	if absf(CloudLayer.veil_alpha(Vector2(200, 200)) - CloudLayer.DENSITY) > 0.001 or CloudLayer.DENSITY < 0.65 or CloudLayer.DENSITY > 0.75:
		hole_bad.append("brume au cœur %.2f" % CloudLayer.veil_alpha(Vector2(200, 200)))
	check(hole_bad.is_empty() and cover_ok, "G1 brume : le trou contient l'anse et rien du port ni du cap, brume nulle dans l'anse et dense ailleurs (%s) ; couverture sur tout le monde habillé (%s)" % [str(hole_bad.slice(0, 4)), cover_ok])
	# 11. forêt profonde ramenée à ≈ 1,3 × les arbres du village (hauteur du plus grand pin d'un bloc / plus grand arbre du village)
	var deep_s := 0.0
	var n_deep := 0
	for it in Layout.forest():
		if bool(it.get("deep", false)):
			deep_s = maxf(deep_s, float(it.s))
			n_deep += 1
	var ratio := Assets.aabb("forest_block").size.y * deep_s / maxf(0.01, Assets.aabb("tree").size.y * 1.3)
	check(n_deep >= 150 and ratio <= 1.45, "F3 forêt profonde : %d blocs, échelle au plus ×%s, pins au plus %s × le plus grand arbre du village (avant ×3,2)" % [n_deep, Fmt.num(deep_s), Fmt.num(ratio)])
	# 12. tutoriel : sept étapes de la Crique en tête, la suite inchangée (une progression enregistrée avant F3 ou G1 se retrouve)
	var steps: Array = DataDB.load_json("res://data/tutorial.json")
	var ids: Array = steps.map(func(x: Dictionary) -> String: return String(x.id))
	var tre := RegEx.create_from_string("const REV5_ORDER := \\[([^\\]]*)\\]").search(FileAccess.get_file_as_string("res://scripts/ui/tutorial.gd"))
	var tsrc := {"REV5_ORDER": JSON.parse_string("[" + tre.get_string(1) + "]") if tre != null else []}
	var sre := RegEx.create_from_string("const TUTO_REV := (\\d+)").search(FileAccess.get_file_as_string("res://autoload/settings.gd"))
	var setc := {"TUTO_REV": int(sre.get_string(1)) if sre != null else 0}
	var a0_ids := ["a0_pontoon", "a0_rent", "a0_places", "a0_hall", "a0_marcel", "a0_mission", "a0_concession"]
	# (lot G2, recalé : après « Bienvenue », le premier navire à la main — terrassement, quai, accoster, cabane, tamponner, piste,
	# laisser passer —, puis la suite d'avant sans « coup de main » ni « barrière express » ; version 8)
	var g2_ids := ["welcome", "t_platform", "t_quay", "ship", "t_hut", "t_stamp", "t_track", "t_pass", "t_crane", "t_yard"]
	var rest: Array = (tsrc.REV5_ORDER as Array).filter(func(x: String) -> bool: return not (x in ["welcome", "ship", "crane", "gate"]))
	# (reprise G2, recalé : la grue mobile et le parc de stockage, deux étapes de plus avant la suite ; version 9)
	check(ids.slice(0, 7) == a0_ids and ids.slice(7, 17) == g2_ids and ids.slice(17) == rest and int(setc.TUTO_REV) == 9,
		"G1/G2 tutoriel : %s en tête, puis le premier navire à la main (grue mobile et parc compris), puis la suite (version 9)" % str(ids.slice(0, 7)))


## Lot G2 — le Terre-plein, le premier navire à la main : la friche nue après la Concession (aucune séquence automatique),
## les six pièces du départ une à une, la grue de bord, tamponner, laisser passer et encaisser, le camion qui repart, la
## plateforme pleine, les responsables après 5 gestes (et le geste remplacé), les cartes des services avec leur responsable
## ou leur bâtiment, les noms de métier, le monde figé sans responsable, la sauvegarde v8, le bot (jalons).
func test_g2(db: DataDB) -> void:
	print("[lot G2 — le Terre-plein à la main]")
	var mc: Dictionary = db.cfg("manual")
	# 1. après la Concession : la friche nue — aucun bâtiment, aucun navire, rien de révélé ; un seul achat (le terrassement)
	var s := PortSim.new(db, 21)
	s.begin_act0()
	s.open_port()
	var nude := s.built.is_empty() and s.ships.is_empty() and s.berths.is_empty() and s.g2 and s.next_starter() == "platform"
	var avail: Array = []
	for b in db.buildings:
		if s.building_state(String(b.id)) == "available":
			avail.append(String(b.id))
	for i in 240:
		s.step(0.25)
	check(nude and avail == ["platform"] and s.ships.is_empty() and s.counter("evp") == 0.0 and String(s.analysis.key) == "starter",
		"G2 friche : après la Concession, rien de bâti ni de navire (aucune séquence automatique), un seul achat possible (%s), conseil « %s »" % [str(avail), String(s.analysis.key)])
	# 2. les pièces une à une ; le quai n°1 amène le caboteur ; il ne s'accoste qu'à la main (pas d'accostage automatique)
	s.money = 1.0e4
	var order_ok := not s.build("quay1") and s.build("platform") and s.build("quay1")
	var ship_in := s.ships.size() == 1
	var waited := 0.0
	for i in 400:
		s.step(0.25)
	var anch: Ship = null
	for sh in s.ships:
		if sh.state == Ship.State.ANCHORED:
			anch = sh
	check(order_ok and ship_in and anch != null and s.berths[0].ship == -1,
		"G2 quai n°1 : dans l'ordre (terrassement d'abord) ; le caboteur se présente en rade et y reste sans geste (100 s)")
	# 3. accoster à la main ; la grue de bord décharge lentement (≈ board_crane_rate), sur la plateforme ; sans cabane, rien
	# n'est dédouané (tout attend le tampon)
	s.prioritize_ship(anch.id)
	var t_un := -1.0
	var evp0 := s.counter("evp")
	var e1 := 0.0
	var rate := 0.0
	for i in 400:
		s.step(0.25)
		if t_un < 0.0 and s.counter("evp") > evp0:
			t_un = s.time
			e1 = s.counter("evp")
		elif t_un > 0.0 and rate == 0.0 and s.time - t_un >= 10.0:
			rate = (s.counter("evp") - e1) / (s.time - t_un)
	check(s.board_crane(0) and t_un > 0.0 and absf(rate - float(mc.board_crane_rate)) < 0.05 and s.pending_total() > 0.5 and s.cleared_total() < 0.01 and int(s.gestures.berth) == 1,
		"G2 grue de bord : accosté à la main (1 geste), déchargement à %s conteneur/s (cible %s), tout attend le tampon (%s)" % [Fmt.num(rate), Fmt.num(float(mc.board_crane_rate)), Fmt.num(s.pending_total())])
	# 4. tamponner : la cabane ; sans elle, pas de tampon
	var no_hut := not s.stamp_ready() and s.stamp() == 0.0
	s.build("hut")
	var st := s.stamp()
	check(no_hut and st > 0.0 and s.pending_total() == 0.0 and s.counter("stamps") == 1.0 and int(s.gestures.stamp) == 1,
		"G2 tamponner : impossible sans cabane, puis toucher la cabane dédouane le lot (%s)" % Fmt.num(st))
	# 5. pas de camion sans piste ; ensuite un camion se présente, toucher la barrière = il charge 2 conteneurs et paie
	for i in 120:
		s.step(0.25)
	var no_truck := s.truck_queue == 0.0 and not s.pass_ready()
	s.build("track")
	var guard := 0
	while not s.pass_ready() and guard < 800:
		s.step(0.25)
		guard += 1
	var m0 := s.money
	var d0 := s._sum(s.delivered)
	var paid := s.pass_truck()
	check(no_truck and paid > 0.0 and s.money - m0 >= paid - 0.01 and is_equal_approx(s._sum(s.delivered) - d0, float(db.cfg("truck_evp"))) and int(s.gestures.pass) == 1,
		"G2 laisser passer : pas de camion sans piste ; un camion se présente, toucher la barrière = 2 conteneurs sortis, %s encaissés" % Fmt.money(paid))
	# 6. un camion qu'on ne laisse pas passer repart au bout de `truck_wait` s, sans rien (bulle rouge avant : truck_wait_left)
	guard = 0
	while not s.pass_ready() and guard < 800:
		s.step(0.25)
		guard += 1
	var lost0 := s.counter("trucks_lost")
	var d1 := s._sum(s.delivered)
	var warn_seen := false
	for i in int((float(mc.truck_wait) + 2.0) / 0.25):
		s.step(0.25)
		warn_seen = warn_seen or s.truck_wait_left() < float(mc.truck_warn)
	check(s.counter("trucks_lost") > lost0 and is_equal_approx(s._sum(s.delivered), d1) and warn_seen,
		"G2 camion non servi : il repart après %d s sans rien charger (perdus %d), avertissement avant" % [int(mc.truck_wait), int(s.counter("trucks_lost"))])
	# 7. plateforme pleine sans sortie : « il faut une sortie » (alerte), le quai se remplit, le déchargement s'arrête
	var f := PortSim.new(db, 22)
	f.begin_act0()
	f.open_port()
	f.money = 1.0e4
	f.build("platform")
	f.build("quay1")
	f.build("hut")
	f.build("crane_mobile")
	f.yard_cleared[0] = f.yard_capacity()
	f.apron[0] = f.apron_capacity()
	for i in 40:
		f.step(0.25)
	check(String(f.shown_analysis().get("alert", "")) == "exit" and f.yard_fill() >= 0.99,
		"G2 plateforme pleine : alerte « il faut une sortie » (%s, remplissage %d %%)" % [String(f.shown_analysis().get("alert", "")), roundi(f.yard_fill() * 100.0)])
	# 8. responsables : après 5 gestes, un à la fois, dans l'ordre, à ≥ 45 s ; l'embauche remplace le geste et ouvre la carte
	var r := PortSim.new(db, 23)
	r.begin_act0()
	r.open_port()
	r.money = 1.0e5
	for b in PortSim.STARTERS:
		r.build(String(b))
	var offers: Array = []
	r.manager_offered.connect(func(d: String) -> void: offers.append([d, r.time]))
	r.gestures = {"berth": 5, "stamp": 5, "pass": 5}
	for i in 800:
		r.step(0.25)
	var gaps_ok := offers.size() == 3 and offers.map(func(o: Array) -> String: return String(o[0])) == ["berths", "customs", "gate"]
	for k in range(1, offers.size()):
		gaps_ok = gaps_ok and float(offers[k][1]) - float(offers[k - 1][1]) >= float(mc.offer_gap) - 0.01
	var cards_before := not r.feature("dept_berths") and not r.feature("dept_gate")
	var h1 := r.hire_manager("berths") and r.hire_manager("customs") and r.hire_manager("gate")
	for i in 40:
		r.step(0.25)
	r.yard_pending[0] = 6.0
	r.truck_queue = 4.0
	var replaced := not r.stamp_ready() and not r.pass_ready() and r.managers_count() == 3
	# (Heures sup : une révélation ordinaire, elle passe à son tour après celles déjà dues — `reveal_gap`)
	var hire_t := r.time
	var g := 0
	while not r.feature("boost") and g < 2400:
		r.step(0.25)
		g += 1
	check(gaps_ok and cards_before and h1 and replaced and r.feature("dept_berths") and r.feature("dept_customs") and r.feature("dept_gate") and r.feature("boost"),
		"G2 responsables : Léon, Paul, Tonio se présentent après 5 gestes, dans l'ordre, à ≥ %d s (%s) ; embauchés, ils remplacent le geste, leur carte apparaît, Heures sup ensuite (%s après)" % [
		int(mc.offer_gap), str(offers.map(func(o: Array) -> String: return "%s %s" % [o[0], Fmt.duration(float(o[1]))])), Fmt.duration(r.time - hire_t)])
	# 9. cartes avec bâtiment : Déchargement avec la grue mobile, Stockage avec le parc, Arrivées avec le quai n°2
	var c := PortSim.new(db, 24)
	c.begin_act0()
	c.open_port()
	c.money = 1.0e6
	var before := not c.feature("dept_cranes") and not c.feature("dept_yard_ops") and not c.feature("dept_harbor")
	for b in PortSim.STARTERS:
		c.build(String(b))
	for i in 400:
		c.step(0.25)
	check(before and c.feature("dept_cranes") and c.feature("dept_yard_ops") and not c.feature("dept_harbor") and not c.buy_dept("harbor", 1),
		"G2 cartes : Déchargement avec la grue mobile, Stockage avec le parc ; Arrivées pas avant le quai n°2")
	# 10. noms de métier (identifiants inchangés)
	var names := ["harbor", "berths", "cranes", "customs", "yard_ops", "gate"].map(func(d: String) -> String: return String(db.dept_by_id[d].name))
	check(names == ["Arrivées", "Accostage", "Déchargement", "Douane", "Stockage", "Sortie camions"],
		"G2 noms de métier : %s" % ", ".join(names))
	# (revue QA de G2) le goulot d'un geste dont le service n'est pas ouvert : le conseil dit le geste (« touche la cabane »),
	# puis d'embaucher le responsable quand il s'est présenté — jamais « améliore la Douane » sans carte Douane
	var gh := PortSim.new(db, 31)
	gh.begin_act0()
	gh.fishing.migrate_done()
	gh.open_port()
	gh.money = 5000.0
	for b in PortSim.STARTERS:
		gh.build(b)
	gh.yard_pending[0] = 20.0
	gh._refresh_analysis()
	var ga1 := gh.shown_analysis()
	var gk1 := String(Advice.hint_action(gh).kind)
	gh.mgr_offered["customs"] = gh.time
	gh._refresh_analysis()
	var gk2 := String(Advice.hint_action(gh).kind)
	check(String(ga1.key) == "gesture" and String(ga1.get("gesture", "")) == "customs" and String(ga1.dept) == "" and gk1 == "gesture" and gk2 == "hire"
		and not gh.feature("dept_customs") and String(ga1.hint).contains("cabane"),
		"G2 (revue) goulot d'un geste : « %s » (%s), puis EMBAUCHER quand Paul s'est présenté (%s)" % [String(ga1.hint), gk1, gk2])
	# (revue QA de G2) revenu affiché après chargement à la friche : la fenêtre d'une minute compte le temps de la Crique
	var gl := PortSim.new(db, 32)
	gl.begin_act0()
	gl.fishing.migrate_done()
	gl.fishing.act0 = true
	for k in 400:
		gl.step(0.25)
	gl.open_port()
	var gl2 := PortSim.new(db)
	gl2.from_dict(JSON.parse_string(JSON.stringify(gl.to_dict())))
	var rr := gl2.real_income_rate()
	check(rr > 0.0 and rr < gl.fishing.offline_rate() * 2.0,
		"G2 (revue) revenu affiché après chargement à la friche : %s/s pour %s/s de pêche (avant : ×70)" % [Fmt.num(rr), Fmt.num(gl.fishing.offline_rate())])
	# 11. le monde figé sans responsable du port (rien gagné, rien perdu ; la pêche de Marcel seule), puis la règle d'avant
	var o := PortSim.new(db, 25)
	o.begin_act0()
	o.open_port()
	o.money = 100.0
	var rep0 := o.apply_offline(3600.0)
	var frozen := rep0.is_empty() and o.money == 100.0
	o.managers["berths"] = true
	var rep1 := o.apply_offline(600.0)
	check(frozen and not rep1.is_empty(), "G2 hors-ligne : sans responsable du port, le port est figé (rien gagné ni perdu) ; avec Léon, la règle d'avant")
	# 12. sauvegarde v8 : régime manuel, gestes, offres, friche ; une partie sans « g2 » au T1 = port complet
	var sv := PortSim.new(db, 26)
	sv.begin_act0()
	sv.open_port()
	sv.money = 1000.0          # (reprise G2, recalé : terrassement 240 $ + quai n°1 310 $ après le calage)
	sv.build("platform")
	sv.build("quay1")
	sv.gestures.berth = 3
	sv.mgr_offered["berths"] = 12.0
	var dd: Dictionary = JSON.parse_string(JSON.stringify(sv.to_dict()))
	var sl := PortSim.new(db)
	sl.from_dict(dd)
	var t1d := PortSim.new(db, 27).to_dict()
	t1d.erase("g2")
	var lg := PortSim.new(db)
	lg.from_dict(t1d)
	var vre := RegEx.create_from_string("const VERSION := (\\d+)").search(FileAccess.get_file_as_string("res://autoload/save.gd"))
	check(sl.g2 and sl.built == ["platform", "quay1"] and int(sl.gestures.berth) == 3 and sl.mgr_offered.has("berths") and sl.berths.size() == 1 \
		and not lg.g2 and lg.built.slice(0, 6) == PortSim.STARTERS and lg.feature("dept_cranes") and vre != null and int(vre.get_string(1)) == 8,
		"G2 sauvegarde v8 : régime manuel rechargé (friche, gestes, offres) ; partie d'avant G2 au T1 = port complet")
	# 13. le bot joue le terre-plein : jalons depuis la Concession (premier camion, responsables, grue mobile, parc), sans perte
	var jal: Array[String] = []
	var bot_ok := true
	for sd in [1, 3]:
		var bs := PortSim.new(db, sd)
		bs.begin_act0()
		var bot := Bot.new(bs)
		bot.run_act0()
		bot.run(600.0)
		var ms := bot.milestones
		jal.append("g%d camion %s, Léon %s, Tonio %s, grue %s, parc %s" % [sd, Fmt.duration(float(ms.get("Premier camion", INF))),
			Fmt.duration(float(ms.get("Responsable embauché : Léon « Gros-Bras » Barbier", INF))), Fmt.duration(float(ms.get("Responsable embauché : Tonio Ferrer", INF))),
			Fmt.duration(float(ms.get("Bâtiment : Grue mobile", INF))), Fmt.duration(float(ms.get("Bâtiment : Parc de stockage", INF)))])
		bot_ok = bot_ok and ms.has("Premier camion") and ms.has("Responsable embauché : Tonio Ferrer") and ms.has("Bâtiment : Parc de stockage") \
			and float(ms["Premier camion"]) < 300.0 and bs.managers_count() >= 3
	check(bot_ok, "G2 bot : le premier navire à la main puis les responsables en 10 min (%s)" % "; ".join(jal))
