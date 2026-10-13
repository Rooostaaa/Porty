extends Node
## Test de fumée de l'interface (scène) : charge la scène principale, ouvre chaque écran, achète, réclame, change de concession.
## Échoue (code 1) si un contrôle attendu manque ; les erreurs de script apparaissent dans la sortie.
##   godot --headless --path godot res://tests/ui_smoke.tscn

var failures := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		failures += 1
		printerr("  ÉCHEC ", label)


## Nombre de fenêtres ouvertes (voiles ColorRect) : la couche contient aussi des effets transitoires (gerbes, textes) qui se détruisent seuls.
func _npop(hud: Hud) -> int:
	var n := 0
	for c in hud.popup_layer.get_children():
		if c is ColorRect:
			n += 1
	return n


func _wait(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func() -> void:
		printerr("  ÉCHEC délai dépassé")
		get_tree().quit(2))
	_run.call_deferred()


func _run() -> void:
	print("=== Test de fumée de l'interface ===")
	var save_node: Node = get_tree().root.get_node("Save")
	var gs: Node = get_tree().root.get_node("GameState")
	var st: Node = get_tree().root.get_node("Settings")
	save_node.set("enabled", false)
	st.set("persist_tuto", false)
	st.set("tuto_step", 1)      # le tutoriel démarre à l'étape « navire en rade »
	gs.call("new_game")
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await _wait(5)
	var hud: Hud = Hud.main
	check(hud != null, "HUD présent")
	var s: PortSim = gs.get("sim")
	# début de partie : seules les commandes de base sont visibles, le conseil désigne l'allongement du quai
	check(not hud.commerce_btn.visible and not hud.feature_ctl.boost[0].visible and not hud.feature_ctl.manage[0].visible,
		"Commerce, Heures sup et Gestion cachés au départ")
	check(s.analysis.key == "attract" and hud.hint_btn.text == "CONSTRUIRE", "le conseil propose de construire (%s)" % hud.hint_btn.text)
	s.money = 5000.0
	await _wait(3)
	check(hud.upgrade_badge.visible, "pastille d'améliorations abordables")
	check(hud.prog_bar.text.contains("T1"), "barre de progression de palier (%s)" % hud.prog_bar.text)

	# tutoriel : étape « navire en rade » puis passage à la suivante quand le joueur touche le navire
	var tu: Tutorial = hud.tutorial
	check(tu != null and tu.active and tu.idx == 1, "tutoriel actif à l'étape 1")
	var anchored: Ship = null
	for _i in 200:
		for sh in s.ships:
			if sh.state == Ship.State.ANCHORED:
				anchored = sh
		if anchored != null:
			break
		s.step(0.25)
	check(anchored != null, "un navire est en rade")
	if anchored != null:
		await _wait(3)
		# un menu ouvert cache le repère « touche le navire » et la carte de cette étape, qui reviennent à la fermeture
		check(not tu._target(tu.steps[tu.idx]).is_empty() and tu._card.visible, "repère du tutoriel sur le navire en rade")
		tu._update_lock()
		var tp: Vector2 = tu._target(tu.steps[tu.idx]).get("pos", Vector2.ZERO)
		check(tu.is_locked() and tu._has_point(Vector2(5, 5)) and not tu._has_point(tp), "tutoriel : interface assombrie et verrouillée, le navire reste touchable")
		check(tu._narrator.pose == "hello", "narratrice : pose d'accueil")
		hud.open_upgrades("")
		tu._refresh_card(false)
		check(tu._target(tu.steps[tu.idx]).is_empty() and not tu._card.visible, "menu ouvert : pas de repère clignotant ni de carte « touche le navire »")
		(hud.sheet_layer.get_child(0) as Sheet).close()
		await _wait(3)
		tu._refresh_card(false)
		check(tu._card.visible, "menu fermé : la carte du tutoriel revient")
		var v: ShipView = hud.diorama.ship_views.get(anchored.id)
		var wp := Vector3(v.position.x, 0.0, v.position.z)
		hud.diorama._on_tapped(wp, Vector2.ZERO)
		check(s.counter("priority") >= 1, "toucher le navire en rade l'accoste en priorité")
		tu._refresh_card(false)
		check(tu.idx >= 2, "le tutoriel passe à l'étape suivante (%d)" % tu.idx)

	# révélation progressive : après quelques escales, les fonctions apparaissent avec un bandeau explicatif
	s.counters["ships"] = 20.0
	s.counters["evp"] = float(s.counters.get("evp", 0.0)) + 200.0
	s.check_unlocks()
	await _wait(3)
	check(hud.feature_ctl.manage[0].visible and hud.feature_ctl.boost[0].visible and hud.feature_ctl.managers[0].visible, "Gestion, Heures sup et Responsables apparaissent")
	check(hud._banner != null and hud._banner_queue.size() >= 3, "bandeaux « Nouveau » en file (%d)" % hud._banner_queue.size())
	check(hud.commerce_btn.visible and not s.feature("contracts"), "le Commerce apparaît, les contrats attendent le bureau de douane (%s, %s, %s)" % [hud.commerce_btn.visible, s.feature("contracts"), str(s.features.keys())])
	# bandeau des missions sous la barre : réclamer d'un toucher, replier
	hud._refresh(s)
	check(hud.mission_strip.is_visible_in_tree() and (hud.strip_items[0].label as Label).text != "", "bandeau des missions : « %s »" % (hud.strip_items[0].label as Label).text)
	s.counters["evp"] = float(s.counters.get("evp", 0.0)) + 300.0
	hud._refresh_strip(s)
	var am0 := s.amber
	hud._on_strip_mission(0)
	check(s.missions_claimed.has("m1") and s.amber > am0, "mission réclamée depuis le bandeau")
	hud.strip_folded = true
	hud._refresh_strip(s)
	check(not (hud.strip_items[0].btn as Button).visible, "bandeau replié")
	hud.strip_folded = false
	hud._refresh_strip(s)
	# améliorations : achat d'un département puis d'une licence
	hud.open_upgrades("")
	await _wait(3)
	var up: UpgradesSheet = hud.sheet_layer.get_child(0)
	var lv0: int = s.levels.cranes
	up._buy_dept("cranes")
	check(s.levels.cranes == lv0 + 1, "achat d'un niveau de Portiques")
	up._buy_licence(0)
	check(s.licences[0] == 2, "achat d'une licence")
	await _wait(2)
	check(hud._lifts.size() > 0 and hud.gain_pill.visible and hud.gain_l.text.begins_with("+"), "pastille de gain après l'achat (%s)" % hud.gain_l.text)
	# appui maintenu : rafale d'achats qui accélère, puis s'arrête à court d'argent
	var cc := up._card_for("dept", "gate")
	var hr: HoldRepeat = null
	for ch in (cc.buy as Node).get_children():
		if ch is HoldRepeat:
			hr = ch
	check(hr != null, "bouton AMÉLIORER : appui long branché")
	if hr != null:
		s.money = 1.0e6
		var g0: int = s.levels.gate
		hr.press()
		for i in 40:
			hr.tick(0.1)
		var g1: int = s.levels.gate
		check(g1 >= g0 + 5 and hr.is_repeating(), "appui maintenu : %d niveaux de Gate en 4 s" % (g1 - g0))
		s.money = 0.0
		var ended := [false]
		hr.burst_ended.connect(func(_n: int) -> void: ended[0] = true)
		hr.tick(0.5)
		hr.tick(0.5)
		check(ended[0] and s.levels.gate == g1, "appui maintenu : s'arrête à court d'argent")
		hr.release()
		s.money = 5000.0
	# étapes nommées et frise « i »
	check((cc.stage as Label).text.begins_with("«"), "carte : étape actuelle et suivante (%s)" % (cc.stage as Label).text)
	var fr := up.show_stages(s.db.dept_by_id["gate"], "gate", -1)
	check(fr != null and fr.is_inside_tree(), "frise des étapes ouverte")
	fr.queue_free()
	up._select_tab(1)
	await _wait(2)
	s.licences[0] = s.licence_cap()
	up.refresh()
	var lc := up._card_for("cargo", 0)
	check((lc.buy as Button).text.begins_with("PLAFOND") and (lc.buy as Button).disabled, "licence au plafond du palier : bouton PLAFOND")
	s.licences[0] = 2
	await _wait(2)
	var best := 0
	for c in up.cards:
		if c.has("best") and (c.best as Label).visible:
			best += 1
	check(best <= 1, "au plus un « meilleur achat » affiché (%d)" % best)
	up.close()
	await _wait(2)
	s.levels["cranes"] = 30
	await _wait(4)
	check(int(hud.diorama._stage_shown.get("cranes", 0)) == 2, "le monde montre les paliers franchis (Portiques : 2 éléments)")

	# gestion : bâtiments, responsables, port
	s.money = 1.0e7
	hud.open_sheet(ManageSheet.new(0))
	await _wait(3)
	var ms: ManageSheet = hud.sheet_layer.get_child(0)
	ms._build("quay_ext")
	check(s.built.has("quay_ext") and s.max_depth() == 2, "allongement du quai : gabarit 2")
	await _wait(2)
	ms = hud.sheet_layer.get_child(0)
	ms._build("gravel2")
	check(s.built.has("gravel2"), "construction d'un bâtiment")
	ms._select_tab(1)
	await _wait(2)
	ms._refresh_tags(s)
	var ntag := 0
	for d in ms.dept_lines:
		if (ms.dept_lines[d].tag as Label).visible:
			ntag += 1
	check(ms.cargo_lines.size() == 5 and (ms.stat_bars.per_evp.val as Label).text.ends_with("$") and ntag <= 2,
		"statistiques : gain par EVP %s, panier du port, %d étiquette(s) de maillon" % [(ms.stat_bars.per_evp.val as Label).text, ntag])
	ms = hud.sheet_layer.get_child(0)
	ms._select_tab(2)
	await _wait(2)
	ms._hire("cranes", false)
	check(s.managers.cranes, "embauche d'un responsable")
	ms._select_tab(3)
	await _wait(2)
	check(not ms.rows.any(func(r: Dictionary) -> bool: return r.has("prestige_btn")), "pas de carte de prestige en T1")
	check(not ms.rows.any(func(r: Dictionary) -> bool: return r.has("policy_desc")), "pas de politique de douane sans bureau de douane")
	# les conditions du palier suivant avancent en direct pendant que l'écran est ouvert
	var chk_rows := ms.rows.filter(func(r: Dictionary) -> bool: return r.has("chk_i"))
	check(chk_rows.size() >= 3, "conditions du palier listées (%d)" % chk_rows.size())
	if chk_rows.size() >= 1:
		var lbl: Label = chk_rows[0].chk_label
		var before := lbl.text
		s.counters["evp"] = float(s.counters.get("evp", 0.0)) + 1234.0
		ms.refresh()
		check(lbl.text != before, "la liste des conditions se met à jour (%s → %s)" % [before, lbl.text])
	ms.close()
	await _wait(2)

	# commerce : campagne de démarchage, puis armateur démarché et ligne régulière en T2
	hud.open_sheet(CommerceSheet.new(CommerceSheet.TAB_TRAFFIC))
	await _wait(3)
	var cs: CommerceSheet = hud.sheet_layer.get_child(0)
	check(cs.traffic_l != null and cs.traffic_l.text.begins_with("Trafic"), "onglet Trafic : %s" % (cs.traffic_l.text if cs.traffic_l else "?"))
	var camp: Array = cs.rows.filter(func(r: Dictionary) -> bool: return r.kind == "campaign" and r.id == "posters")
	check(camp.size() == 1 and not (camp[0].btn as Button).disabled, "affiches : bouton LANCER actif")
	if camp.size() == 1:
		cs._start_campaign("posters", camp[0].btn)
	check(s.counter("campaigns") == 1.0 and s.mods.has("camp_posters"), "campagne lancée depuis l'écran")
	s.tier = 2
	s.invalidate()
	cs._select_tab(CommerceSheet.TAB_OWNERS)
	await _wait(2)
	cs._recruit("nordhaven")
	check(s.owners_on.has("nordhaven"), "Nordhaven démarché depuis l'écran")
	cs._sign("corsaire")
	check(int(s.lines.get("corsaire", 0)) == 1, "ligne régulière signée depuis l'écran")
	cs._select_tab(CommerceSheet.TAB_CONTRACTS)
	await _wait(2)
	check(cs.rows.is_empty() or cs.rows.all(func(r: Dictionary) -> bool: return r.kind == "contract"), "onglet Contrats sans erreur")
	cs.close()
	s.tier = 1
	s.invalidate()
	await _wait(2)
	# ancienne partie (avant le Commerce) : un message l'explique une fois
	var pops0 := _npop(hud)
	s.legacy_notice = "commerce"
	hud.bind(s)
	await _wait(2)
	check(_npop(hud) == pops0 + 1 and s.legacy_notice == "", "ancienne partie : message « Nouveau : le Commerce »")
	s.legacy_notice = "licences:12 $"
	hud.bind(s)
	await _wait(2)
	check(_npop(hud) == pops0 + 2 and s.legacy_notice == "", "ancienne partie : message sur les plafonds de licence")
	for p in hud.popup_layer.get_children():
		p.queue_free()
	await _wait(2)

	# missions de carrière
	for m in s.db.missions:
		s.missions_claimed.append(String(m.id))
	s.counters["evp"] = 1.0e7
	hud.open_sheet(MissionsSheet.new())
	await _wait(3)
	var mi: MissionsSheet = hud.sheet_layer.get_child(0)
	check(mi.rows.size() > 0 and String(mi.rows[0].m.id).begins_with("g"), "objectifs de carrière affichés")
	mi._claim(String(mi.rows[0].m.id))
	check(s.missions_claimed.any(func(i: String) -> bool: return i.begins_with("g")), "objectif de carrière réclamé")
	mi.close()
	await _wait(2)

	# prestige : fin de concession puis nouvelle concession via l'écran Port
	s.tier = 3
	s.finished = true
	s.counters["evp"] = 2.6e6
	hud.open_sheet(ManageSheet.new(3))
	await _wait(3)
	ms = hud.sheet_layer.get_child(0)
	check(ms.rows.any(func(r: Dictionary) -> bool: return r.has("prestige_btn")), "carte de prestige présente en fin de concession")
	ms._prestige()   # 1er appui : confirmation
	check(gs.get("sim") == s, "le premier appui demande confirmation")
	ms._prestige()
	await _wait(3)
	var ns: PortSim = gs.get("sim")
	check(ns != s and ns.renown == 5 and ns.prestiges == 1, "nouvelle concession ouverte (Renom %d)" % ns.renown)
	check(ns.tier == 1 and ns.built.is_empty(), "la nouvelle concession repart de zéro")
	check(hud.diorama.sim == ns, "le diorama suit la nouvelle partie")
	check(hud.diorama.rig.input_enabled, "la caméra reste utilisable")
	# lot B : la bulle de la douane est dessinée au-dessus de son point d'ancrage (anchor_y), jamais sur le bâtiment
	ns.yard_pending[0] = 5.0
	await _wait(3)
	var anchor_sp: Vector2 = hud.diorama.to_screen(Bubbles.anchor_point("customs_hut", Layout.CUSTOMS_HUT))
	var cr: Rect2 = hud.overlay.last_rects.get("customs", Rect2())
	check(cr.size.y > 0.0 and cr.end.y <= anchor_sp.y + 0.5, "bulle « À inspecter » au-dessus de l'anchor_y de la douane (bas %d ≤ ancre %d)" % [int(cr.end.y), int(anchor_sp.y)])
	var gh := Assets.instance("modele_absent_ui")     # un modèle absent : nœud vide, le monde est quand même construit
	check(gh.get_child_count() == 0 and Assets.missing.has("modele_absent_ui") and hud.diorama.traffic.walkers.size() >= 4 and hud.diorama.static_root.get_child_count() > 20,
		"monde construit malgré %d modèle(s) absent(s), %d personnages qui marchent" % [Assets.missing.size(), hud.diorama.traffic.walkers.size()])
	gh.free()
	check(hud.prog_bar.text.contains("Concession 2"), "barre de progression : %s" % hud.prog_bar.text)

	# Heures sup en recharge : l'Ambre n'est jamais dépensé sans confirmation
	ns.amber = 3
	ns.boost_ready_at = ns.time + 200.0
	var pops := _npop(hud)
	hud._on_boost()
	check(ns.amber == 3 and _npop(hud) == pops + 1, "Heures sup : confirmation avant de dépenser de l'Ambre")
	for p in hud.popup_layer.get_children():
		p.queue_free()
	await _wait(2)

	# tutoriel : un geste déjà fait fait passer l'étape, même si sa condition de départ n'est plus vraie
	var mission_idx := -1
	for i in tu.steps.size():
		if String(tu.steps[i].id) == "mission":
			mission_idx = i
	ns.missions_claimed.append("test_deja_reclamee")
	tu.active = true
	tu.idx = mission_idx
	tu._refresh_card(false)
	check(mission_idx >= 0 and tu.idx == mission_idx + 1, "tutoriel : étape « mission » franchie sans mission à réclamer (%d)" % tu.idx)

	# retour de veille : le hors-ligne est crédité et l'interface le montre
	var money0 := ns.money
	var pops2 := _npop(hud)
	gs.call("credit_offline", 7200.0)
	await _wait(2)
	check(ns.money > money0, "le hors-ligne est crédité à la reprise (+%s)" % Fmt.money(ns.money - money0))
	check(_npop(hud) == pops2 + 1, "l'écran « Bon retour » s'affiche")

	print("=== %d échec(s) ===" % failures)
	get_tree().quit(1 if failures > 0 else 0)
