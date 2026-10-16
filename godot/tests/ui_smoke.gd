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
## Indice d'une étape du tutoriel par son identifiant (data/tutorial.json).
func _tuto_index(id: String) -> int:
	var steps: Variant = DataDB.load_json("res://data/tutorial.json")
	for i in (steps as Array).size():
		if String(steps[i].id) == id:
			return i
	return -1


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
	# (lot F3, recalé : garde-fou en temps réel, 280 s — il comptait le temps de jeu, accéléré ×4–6 par les contrôles F2/F3 ;
	# lot G1 : 400 s, la Crique jouée à l'interface dure ≈ 70 s de plus)
	get_tree().create_timer(400.0, true, false, true).timeout.connect(func() -> void:
		printerr("  ÉCHEC délai dépassé")
		get_tree().quit(2))
	_run.call_deferred()


func _run() -> void:
	print("=== Test de fumée de l'interface ===")
	# écran portrait du téléphone (en --headless la fenêtre par défaut est carrée : les contrôles de cadrage seraient faux)
	get_window().size = Vector2i(540, 960)
	await _wait(2)
	print("  (fenêtre %s, vue %s)" % [str(get_window().size), str(get_viewport().get_visible_rect().size)])
	var save_node: Node = get_tree().root.get_node("Save")
	var gs: Node = get_tree().root.get_node("GameState")
	var st: Node = get_tree().root.get_node("Settings")
	save_node.set("enabled", false)
	st.set("persist_tuto", false)
	get_tree().root.get_node("Sfx").set("persist", false)      # lot E : jamais d'écriture dans user://audio.cfg du joueur
	# le tutoriel démarre à l'étape « navire en rade » (lot F3, recalé : retrouvée par son identifiant — trois étapes de l'acte 0
	# sont en tête de la liste depuis la version 6)
	var ship_idx := _tuto_index("ship")
	st.set("tuto_step", ship_idx)
	st.set("tuto_rev", int((st.get_script() as GDScript).get_script_constant_map()["TUTO_REV"]))
	gs.set("auto_start", false)      # lot F2 : la partie de test commence tout bâti (le départ est contrôlé à part, _f2_checks)
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
	# (lot D-UI : le bouton dit quoi et combien — « QUAI ALLONGÉ · 250 $ » — au lieu de « CONSTRUIRE » ; contrôle recalé)
	check(s.analysis.key == "attract" and String(Hud.hint_action(s).kind) == "build" and hud.hint_btn.text == String(Hud.hint_action(s).label) and hud.hint_btn.text.contains(Fmt.money(250.0)),
		"le conseil propose de construire (%s)" % hud.hint_btn.text)
	# revue du 13/10 : départ à 260 $ (le quai à 250 $ s'achète tout de suite) ; carte Goulot rouge et bouton vert
	# seulement si une action est possible (« vert si possible, gris sinon »)
	var m_save := s.money
	check(m_save >= 250.0 and Hud.hint_actionable(s), "départ : %s, le quai allongé est abordable et la carte Goulot propose de le construire" % Fmt.money(m_save))
	s.money = 0.0
	hud._refresh(s)
	var grey_ok := not hud._hint_can
	s.money = 1000.0
	hud._refresh(s)
	# (lot D-Éco, recalé : le titre ne passe plus au rouge parce qu'un achat est possible, seulement en alerte)
	check(grey_ok and hud._hint_can and not hud._hint_alert, "carte Goulot : bouton gris sans argent, vert quand l'achat est possible, titre neutre hors alerte")
	# lot D-Éco : un goulot normal n'est pas une alerte ; un maillon bloqué (ici le brouillard) passe la carte au rouge
	s._alert_why = "fog"
	s._alert_left = 4.0
	s._refresh_analysis()
	hud._refresh(s)
	var red_on := hud._hint_alert and hud.hint_title.get_theme_color("font_color") == UI.BAD
	s._alert_left = 0.0
	s._refresh_analysis()
	hud._refresh(s)
	check(red_on and not hud._hint_alert and hud.hint_title.get_theme_color("font_color") == UI.INDIGO,
		"carte Goulot rouge en alerte seulement (brouillard), neutre sinon")
	s.money = m_save
	hud._refresh(s)
	# notifications : une à la fois, sous l'en-tête, les suivantes en file
	for tx in ["essai 1", "essai 2", "essai 3"]:
		hud.toast(tx)
	await _wait(2)
	# revue N2 : sous la carte Goulot, dans la colonne de gauche, jamais sur un bouton ni une puce du HUD
	var trect := (hud.toast_box.get_child(0) as Control).get_global_rect() if hud.toast_box.get_child_count() > 0 else Rect2()
	var on_btn: Array[String] = []
	for b in hud.find_children("*", "Button", true, false):
		var bb := b as Button
		if bb.is_visible_in_tree() and not hud.sheet_layer.is_ancestor_of(bb) and not hud.popup_layer.is_ancestor_of(bb) \
				and not hud.tutorial.is_ancestor_of(bb) and trect.intersects(bb.get_global_rect()):
			on_btn.append(bb.text if bb.text != "" else str(bb.get_global_rect()))
	if trect.intersects(hud.upgrade_badge.get_global_rect()) and hud.upgrade_badge.is_visible_in_tree():
		on_btn.append("pastille Améliorer")
	check(hud.toast_box.get_child_count() == 1 and hud._toast_queue.size() == 2 and trect.has_area()
		and trect.position.y >= hud._toast_anchor_y() - 11.0 and on_btn.is_empty(),
		"notifications : une à la fois sous la carte Goulot, deux en file, sur aucun bouton ni puce (%s)" % str(on_btn))
	hud.toast("essai 2")
	check(hud._toast_queue.size() == 2, "notifications : pas de doublon dans la file ni avant 60 s")
	for c in hud.toast_box.get_children():
		c.queue_free()
	hud._toast_queue.clear()
	await _wait(2)
	await _b2_b6_checks(hud, s)
	# bulles des services pas encore présentés : ni parc ni gate au départ ; toutes les bulles dans le rectangle utile
	var ov := hud.overlay
	ov.last_rects.clear()
	await _wait(3)
	var ur := ov.useful          # le rectangle utile avec lequel la surcouche vient de dessiner
	var outside: Array[String] = []
	for k in ov.frame_rects:
		var rr: Rect2 = ov.frame_rects[k]
		if rr.has_area() and not ur.grow(1.0).encloses(rr):
			outside.append(String(k))
	check(not ov.last_rects.has("gate") and not ov.last_rects.has("yard") and outside.is_empty() and ov.last_rects.has("rade"),
		"bulles : ni parc ni gate avant leur chapitre, toutes dans le rectangle utile (%s ; hors cadre : %s)" % [str(ov.last_rects.keys()), str(outside)])
	# priorité des touchers (lot G2, remplace « l'engin touché passe avant la grue » : le coup de main à la grue et l'engin du
	# parc n'existent plus) — la cabane qui attend son tampon et la barrière où un camion attend passent avant le poste de leur
	# service, touchés au même endroit ; une zone grise reste une bulle
	var dio0 := hud.diorama
	var g2_0 := s.g2
	var had_f := {"dept_customs": s.features.has("dept_customs"), "dept_gate": s.features.has("dept_gate")}
	var st_save := [s.yard_pending[0], s.yard_cleared[0], s.truck_queue]
	s.g2 = true
	s.features["dept_customs"] = s.time
	s.features["dept_gate"] = s.time
	s.yard_pending[0] = maxf(s.yard_pending[0], 6.0)
	s.yard_cleared[0] = maxf(s.yard_cleared[0], 6.0)
	s.truck_queue = maxf(s.truck_queue, 4.0)
	var pick_k := "%s / %s (tampon %s, camion %s)" % [String(dio0.pick_tap(Layout.CUSTOMS_HUT + Vector3(0.6, 0, 0.4)).get("kind", "")),
		String(dio0.pick_tap(Layout.GATE + Vector3(0.6, 0, 0.4)).get("kind", "")), s.stamp_ready(), s.pass_ready()]
	s.g2 = g2_0
	for fk in had_f:
		if not bool(had_f[fk]):
			s.features.erase(fk)
	s.yard_pending[0] = float(st_save[0])
	s.yard_cleared[0] = float(st_save[1])
	s.truck_queue = float(st_save[2])
	# revue N10 : un navire qui en rattrape un autre allant dans le même sens attend derrière lui (pas l'inverse, ni en croisant)
	var up2 := Vector2(0, 1)
	var f_follow := Diorama.follows(Vector2(-33, -80), up2, 22.0, Vector2(-33, -62), up2, 22.0)
	var f_lead := Diorama.follows(Vector2(-33, -62), up2, 22.0, Vector2(-33, -80), up2, 22.0)
	var f_cross := Diorama.follows(Vector2(-37, -80), up2, 34.0, Vector2(-27, -70), -up2, 34.0)
	check(f_follow and not f_lead and not f_cross, "N10 : distance de suivi — le second attend, le premier avance, deux navires qui se croisent passent (%s %s %s)" % [f_follow, f_lead, f_cross])
	_ship_view_checks(hud, s)
	_traffic_checks(s.db)
	var pops_z := _npop(hud)
	dio0._on_tapped(Vector3(-33, 0, 34), Vector2.ZERO)        # enceinte de la douane, grise au départ (lot D : recalé, ex-« La Porte » en (-30, 50))
	await _wait(2)
	check(pick_k.begins_with("hut / barrier (tampon true, camion true") and _npop(hud) == pops_z and int(ov.zone_info.get("id", 0)) == 3,
		"G2 toucher : la cabane (tamponner) et la barrière (laisser passer) passent avant le poste de leur service (%s) ; une zone grise montre une bulle de 2 s, pas une fenêtre" % pick_k)
	ov.zone_info = {}
	# plan de la baie : cadrage de départ — capitainerie, grue, quai n°1 et la première place du mouillage sous le HUD
	var rg := hud.diorama.rig
	var saved_t := rg.target
	var saved_z := rg.zoom
	rg.target = CameraRig.START
	rg.zoom = CameraRig.ZOOM_START
	rg._apply()
	var vsz := hud.get_viewport_rect().size
	var top_hud := hud.top_cards_bottom()
	var frame_bad: Array[String] = []
	var frame_pts := {"capitainerie": Layout.HARBOR_OFFICE + Vector3(0, 4, 0), "grue": Vector3(Diorama.crane_x(0, 0, 1), 6, -1.6),
		"quai": Vector3(-24, 0.8, -3), "mouillage": Layout.anchor_pos(0), "passe": Vector3(-34, 0, -44)}
	for k in frame_pts:
		var spf: Vector2 = hud.diorama.to_screen(frame_pts[k])
		if spf.y < top_hud or spf.y > vsz.y - 230.0 or spf.x < 0.0 or spf.x > vsz.x:
			frame_bad.append("%s (%d, %d)" % [k, int(spf.x), int(spf.y)])
	check(frame_bad.is_empty(), "cadrage de départ : vieux port, passe et mouillage sous le HUD (haut %d ; hors cadre : %s)" % [int(top_hud), str(frame_bad)])
	# revue N3 : au départ, carte du tutoriel affichée (la carte Goulot s'efface), le phare, le navire au mouillage n°1 et
	# l'empreinte du quai allongé sont dans le rectangle utile
	hud.tutorial._refresh_card(true)
	hud._refresh(s)
	await _wait(3)
	# cadrage de départ figé pour la mesure : l'étape « navire » recentre la vue sur le mouillage, et le contrôle ne doit pas
	# dépendre du nombre d'images écoulées (revue C7 : contrôle rendu déterministe, même critère)
	rg.goal = CameraRig.START
	rg.target = CameraRig.START
	rg.zoom = CameraRig.ZOOM_START
	rg._apply()
	var ur3 := hud.useful_rect()
	var n3_bad: Array[String] = []
	var n3_pts := {"phare": Vector3(-66, 7, -36), "navire n°1": Layout.anchor_pos(0) + Vector3(0, 2, 0), "quai allongé": Vector3(-6, 1, -3)}
	for k in n3_pts:
		var sp3: Vector2 = hud.diorama.to_screen(n3_pts[k])
		if not ur3.has_point(sp3):
			n3_bad.append("%s (%d, %d)" % [k, int(sp3.x), int(sp3.y)])
	check(n3_bad.is_empty() and hud.tutorial._card.visible and not hud.hint_card.visible,
		"N3 : départ avec la carte du tutoriel — carte Goulot masquée ; phare, navire n°1 et quai allongé dans le rectangle utile %s de %s (hors : %s)" % [str(ur3), str(vsz), str(n3_bad)])
	rg.target = saved_t
	rg.zoom = saved_z
	# une seule zone prochaine (le quai allongé) et la pancarte du prochain achat dans le monde
	check(Zones.next_zone(s).get("id", 0) == 2 and hud.diorama.next_lot == "quay_ext" and hud.diorama.lot_sign_point() != Vector3.INF,
		"zone prochaine : le quai allongé, pancarte sur son empreinte")
	# chapitres : trois boutons au départ, une seule pastille « ! », Améliorer montre le chapitre en cours plus une carte « à venir »
	var nbtn := 0
	for b in hud.find_children("*", "Button", true, false):
		var bb := b as Button
		if bb.is_visible_in_tree() and not hud.sheet_layer.is_ancestor_of(bb) and not hud.popup_layer.is_ancestor_of(bb) and not hud.tutorial.is_ancestor_of(bb):
			nbtn += 1
	# (la carte Goulot, et son bouton, s'effacent pendant une carte du tutoriel : revue N3 — on la compte quand même)
	if not hud.hint_card.visible:
		nbtn += 1
	check(nbtn == 3, "chapitre 1 : trois boutons au HUD au départ (%d)" % nbtn)
	hud.open_upgrades("")
	await _wait(3)
	var up0: UpgradesSheet = hud.sheet_layer.get_child(0)
	var locked_n := up0.cards.filter(func(c: Dictionary) -> bool: return (c.root as Control).modulate.a < 0.9).size()
	var depts0 := up0.cards.map(func(c: Dictionary) -> String: return String(c.get("dept", "")))
	check(depts0.has("cranes") and depts0.has("harbor") and depts0.has("berths") and locked_n == 1 and up0.cards.size() == 4,
		"Améliorer : grue et capitainerie (deux services) + une carte « à venir » (%s)" % str(depts0))
	up0.close()
	await _wait(2)
	s.money = 5000.0
	await _wait(3)
	check(hud.upgrade_badge.visible, "pastille d'améliorations abordables")
	check(hud.prog_bar.text.contains("T1"), "barre de progression de palier (%s)" % hud.prog_bar.text)

	# tutoriel : étape « navire en rade » puis passage à la suivante quand le joueur touche le navire
	var tu: Tutorial = hud.tutorial
	check(tu != null and tu.active and tu.idx == ship_idx, "tutoriel actif à l'étape « navire » (%d)" % ship_idx)
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
		# (lot F1, recalé) la carte se rafraîchit toutes les 0,25 s : trois images peuvent ne pas suffire après la fermeture
		# d'Améliorer (plus haut) — on la rafraîchit comme le font les contrôles suivants
		tu._refresh_card(false)
		# un menu ouvert cache le repère « touche le navire » et la carte de cette étape, qui reviennent à la fermeture
		check(not tu._target(tu.steps[tu.idx]).is_empty() and tu._card.visible, "repère du tutoriel sur le navire en rade (%s %s %s %s %s %s)" % [tu._target(tu.steps[tu.idx]), tu._card.visible, hud.any_sheet_open(), tu.idx, hud.diorama.opening_active(), str(hud.diorama.opening_queue)])
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
		check(tu.idx >= ship_idx + 1, "le tutoriel passe à l'étape suivante (%d)" % tu.idx)

	# chapitres : la grue, le parc puis la gate au niveau 10 ouvrent le chapitre suivant, avec un bandeau explicatif
	s.counters["evp"] = float(s.counters.get("evp", 0.0)) + 200.0
	for dd in ["cranes", "yard_ops", "gate"]:
		s.levels[dd] = maxi(10, int(s.levels[dd]))
		for _k in 200:      # un sujet à la fois : les révélations ordinaires sont espacées (reveal_gap), on fait avancer l'horloge
			s.time += 1.0
			s.check_unlocks()
	await _wait(3)
	check(hud.feature_ctl.manage[0].visible and hud.feature_ctl.managers[0].visible and not hud.feature_ctl.boost[0].visible,
		"Gestion et Responsables apparaissent avec les chapitres, Heures sup attend le palier 2")
	var bangs := 0
	for bd in hud.find_children("*", "Label", true, false):
		if (bd as Label).text == "!" and (bd as Label).is_visible_in_tree():
			bangs += 1
	check(bangs <= 1, "une seule pastille « ! » à l'écran (%d)" % bangs)
	check(hud._banner != null and hud._banner_queue.size() >= 3, "bandeaux « Nouveau » en file (%d)" % hud._banner_queue.size())
	check(hud.commerce_btn.visible and not s.feature("contracts"), "le Commerce apparaît, les contrats attendent le bureau de douane (%s, %s, %s)" % [hud.commerce_btn.visible, s.feature("contracts"), str(s.features.keys())])
	# bandeau des missions sous la barre : réclamer d'un toucher, replier
	hud._refresh(s)
	# (lot D-UI : bandeau replié par défaut, le coffre le déroule — contrôle recalé : on touche d'abord le coffre)
	var folded0 := not hud.strip_box.visible and hud.chest_btn.is_visible_in_tree()
	hud._on_chest()
	check(folded0 and hud.mission_strip.is_visible_in_tree() and (hud.strip_items[0].label as Label).text != "", "bandeau des missions : replié par défaut, le coffre le déroule : « %s »" % (hud.strip_items[0].label as Label).text)
	s.counters["evp"] = float(s.counters.get("evp", 0.0)) + 300.0
	hud._refresh_strip(s)
	var am0 := s.amber
	hud._on_strip_mission(0)
	check((s.missions_claimed.has("m1") or s.missions_claimed.has("c0")) and s.amber > am0, "mission réclamée depuis le bandeau (%s)" % str(s.missions_claimed))      # (lot G1 : « c0 » en tête)
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
		s.money = 1.0e12
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
		check(ended[0] and s.levels.gate == g1, "appui maintenu : s'arrête à court d'argent (fin %s, niveau %d → %d, valide %s)" % [ended[0], g1, int(s.levels.gate), is_instance_valid(hr)])
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
	# plan de la baie : l'allongement construit pendant que l'écran était ouvert s'ouvre en séquence au retour au port,
	# un toucher la passe ; la suivante (La Porte) se termine seule
	var dio := hud.diorama
	for _i in 10:
		if dio.opening_active():
			break
		await _wait(1)
	check(dio.opening_active() and int(dio.opening.id) == 2, "ouverture de zone : séquence du quai allongé lancée au retour au port")
	# pendant la séquence : HUD masqué, surcouche et tutoriel muets, notifications en file, « Toucher pour passer »
	hud._sync_opening(1.0)
	await _wait(2)
	var tq0 := hud._toast_queue.size()
	hud.toast("pendant l'ouverture")
	check(hud.hud_fade == 0.0 and not hud.top_box.visible and not hud.bottom_box.visible and not hud.overlay.visible
		and hud.skip_hint.visible == dio.opening_skippable() and not hud.tutorial._card.visible and not hud._toast_queue.is_empty() and String(hud._toast_queue.back()[0]) == "pendant l'ouverture",
		"ouverture de zone : HUD masqué, bulles et tutoriel muets, notification mise en file, « Toucher pour passer » (%s %s %s %s %s %s)" % [hud.hud_fade, hud.top_box.visible, hud.overlay.visible, hud.skip_hint.visible, hud.tutorial._card.visible, hud._toast_queue.size() - tq0])
	# revue N12 : un toucher avant 1,5 s ne passe pas la séquence ; « Toucher pour passer » paraît ensuite
	dio.opening.t = 0.2
	dio._on_tapped(Vector3(200, 0, 200), Vector2.ZERO)
	var still := dio.opening_active()
	hud._sync_opening(0.1)
	var hint_early := hud.skip_hint.visible
	dio.opening.t = Layout.OPENING_SKIP_AFTER + 0.05
	hud._sync_opening(0.1)
	check(still and not hint_early and hud.skip_hint.visible, "N12 : un toucher avant 1,5 s ne passe pas l'ouverture ; « Toucher pour passer » paraît ensuite")
	var od0 := dio.openings_done
	dio._on_tapped(Vector3(200, 0, 200), Vector2.ZERO)
	check(not dio.opening_active() and dio.openings_done == od0 + 1, "ouverture de zone : un toucher la passe")
	hud._sync_opening(1.0)
	await _wait(3)
	# revue C7 C8 : la notification en file attend vraiment 3 s de calme après l'ouverture, puis s'affiche
	for c in hud.toast_box.get_children():
		c.queue_free()
	hud._toast_cur = null
	hud._toast_queue.clear()
	hud._next_toast_at = 0.0
	hud.toast("après l'ouverture")
	var t_toast := Time.get_ticks_msec() / 1000.0
	var calm_left := hud._calm_until - t_toast
	await get_tree().create_timer(1.0).timeout
	# (lot D-UI, contrôle recalé : la notification est toujours en file — une autre, « Mission accomplie », peut l'y rejoindre
	# pendant l'attente ; avant, la file devait n'en contenir qu'une)
	var calm_wait := not _toast_shown(hud, "après l'ouverture") and hud._toast_queue.any(func(it: Array) -> bool: return String(it[0]) == "après l'ouverture")
	# (lot D-UI : diagnostic seulement — calme restant au dépôt, temps réel écoulé, file à 1 s)
	var calm_diag := "calme restant %.1f s, %.1f s réelles, file %s" % [calm_left, Time.get_ticks_msec() / 1000.0 - t_toast,
		str(hud._toast_queue.map(func(it: Array) -> String: return String(it[0])))]
	await get_tree().create_timer(2.6).timeout
	var shown_after := _toast_shown(hud, "après l'ouverture") and hud.toast_box.is_visible_in_tree()
	check(hud.hud_fade == 1.0 and hud.top_box.visible and not hud.skip_hint.visible and calm_wait and shown_after,
		"après l'ouverture : le HUD revient, la notification en file attend 3 s de calme (à 1 s : en file %s — %s) puis s'affiche (%s)" % [calm_wait, calm_diag, shown_after])
	var pops_b := _npop(hud)
	var fiche := hud.open_building("customs1")
	check(fiche != null and _npop(hud) == pops_b + 1, "toucher l'empreinte : fiche du bâtiment")
	fiche.queue_free()
	await _wait(2)
	check(hud.build_from_world("customs1") and s.built.has("customs1"), "construction depuis la fiche du monde")
	await get_tree().create_timer(float(Layout.OPENING.total) + 1.5).timeout
	var all_up := true
	for n in (dio.zone_nodes.get(3, {}).get("nodes", []) as Array):
		if is_instance_valid(n) and (n as Node3D).scale.x < 0.5:
			all_up = false
	check(dio.openings_done == od0 + 2 and not dio.opening_active() and all_up, "ouverture de La Porte terminée seule, bâtiments en place")
	await _b1_b3_b4_checks(hud, s)
	# gestes du terre-plein (lot G2, remplacent « toucher un engin du parc : rangement immédiat » et « toucher la barrière : un
	# camion passe tout de suite », gestes retirés) — régime manuel le temps du contrôle : toucher la cabane tamponne tout le lot
	# (« Tamponné ! »), toucher la barrière laisse passer un camion qui paie (pièces vers le compteur)
	var g2_1 := s.g2
	s.g2 = true
	s.yard_pending[0] = maxf(s.yard_pending[0], 8.0)
	var st_n0 := s.counter("stamps")
	var sh_n0 := dio.stamps_shown
	var pend0 := s.pending_total()
	dio._on_tapped(Layout.CUSTOMS_HUT + Vector3(0.4, 0, 0.3), Vector2.ZERO)
	await _wait(2)
	check(s.counter("stamps") == st_n0 + 1.0 and dio.stamps_shown == sh_n0 + 1 and s.pending_total() < 0.5 and pend0 >= 8.0,
		"G2 toucher la cabane : tout le lot tamponné (%s conteneurs), « Tamponné ! »" % Fmt.num(pend0))
	s.yard_cleared[0] = maxf(s.yard_cleared[0], 30.0)
	s.truck_queue = maxf(s.truck_queue, 4.0)
	var ps_n0 := s.counter("passes")
	var pv0 := dio.passes_shown
	var m_p0 := s.money
	dio._on_tapped(Layout.GATE + Vector3(0.4, 0, 0.3), Vector2.ZERO)
	await _wait(2)
	check(s.counter("passes") == ps_n0 + 1.0 and dio.passes_shown == pv0 + 1 and s.money > m_p0,
		"G2 toucher la barrière : un camion laissé passer paie (+%s), pièces vers le compteur" % Fmt.money(s.money - m_p0))
	s.g2 = g2_1

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
	# revue C7 A4 : au palier 3 sans le quai n°3, aucun musoir sur l'eau du futur terre-plein (x > 48)
	s.tier = 3
	hud.diorama.rebuild()
	var qe_n := 0
	var qe_far := 0
	for qc in hud.diorama.static_root.get_children():
		if (qc as Node).has_meta("quay_end") and not qc.is_queued_for_deletion():
			qe_n += 1
			if (qc as Node3D).position.x > 48.0:
				qe_far += 1
	check(qe_n > 0 and qe_far == 0 and not s.built.has("berth3"), "C7 A4 : au T3 sans le quai n°3, %d musoirs, aucun en x > 48 (%d)" % [qe_n, qe_far])
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
	# (lot G2, recalé : sans départ joué — partie de test — la nouvelle concession a ses six pièces du départ ; jouée, elle
	# repart de la friche nue, régime manuel, en gardant les fonctions déjà connues)
	var hp := PortSim.new(ns.db, 77)
	hp.carry_over(s)
	hp.hold_port()
	check(ns.tier == 1 and ns.built == PortSim.STARTERS and hp.built.is_empty() and hp.g2 and hp.ships.is_empty() and hp.features.size() == s.features.size(),
		"la nouvelle concession repart de zéro (test : %s ; jouée : friche nue, à la main, fonctions connues gardées)" % str(ns.built))
	check(hud.diorama.sim == ns, "le diorama suit la nouvelle partie")
	check(hud.diorama.rig.input_enabled, "la caméra reste utilisable")
	# lot B : la bulle de la douane est dessinée au-dessus de son point d'ancrage (anchor_y), jamais sur le bâtiment
	# (lot D-UI : la nouvelle concession joue sa cérémonie — caméra reculée, surcouche masquée ; contrôle recalé : on la
	# termine et on pose la caméra sur la douane avant la mesure)
	hud._finish_ceremony()
	for p in hud.popup_layer.get_children():
		p.queue_free()
	hud.diorama.rig.focus(Layout.CUSTOMS_HUT)
	hud.diorama.rig.target = hud.diorama.rig.goal
	hud.diorama.rig.zoom = hud.diorama.rig.zoom_goal
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
	# revue C7 D : champ de distance de l'eau calculé une fois par état (plusieurs parties et reconstructions ici) ; bouées de
	# mouillage à maillages partagés ; boutons du bas relevés une fois pour le rectangle utile
	var bmeshes := {}
	var nbuoy := 0
	for c in hud.diorama.static_root.get_children():
		if (c as Node).has_meta("special_buoy") and not c.is_queued_for_deletion():
			nbuoy += 1
			bmeshes[((c as Node).get_child(0) as MeshInstance3D).mesh.get_instance_id()] = true
	hud.useful_rect()
	check(Diorama.water_fields_built <= 2 and nbuoy >= 2 and bmeshes.size() == 1 and hud._bottom_buttons.size() == 4,
		"C7 D : %d champ(s) de distance calculé(s), %d bouées de mouillage pour %d maillage, %d boutons du bas en cache" % [Diorama.water_fields_built, nbuoy, bmeshes.size(), hud._bottom_buttons.size()])
	# lot D-UI (contrôles ajoutés dans leurs propres fonctions)
	await _dui_phase1(hud, ns)
	await _dui_phase2(hud, ns)
	await _dui_phase3(hud, ns)
	await _dui_phase4(hud, ns)
	# lot D-Monde (contrôles dans leur propre fonction)
	await _d_monde_checks(hud, ns)
	# lot E — Confiance (contrôles dans leur propre fonction ; la partie de bot du T3 y est chargée puis rendue)
	await _e_confiance_checks(hud, ns)
	# lot E-Flux (contrôles dans leur propre fonction)
	await _e_flux_checks(hud)
	# lot F1 — navires à l'écran (la partie est au T3 depuis les contrôles E-Flux) ; défilement des feuilles
	await _f1_ship_checks(hud)
	await _f1_scroll_checks(hud)
	# lot F2 — départ de rien, chantiers, trafic lié à ce qui existe, bord du monde (nouvelle partie à la fin : elle remplace tout)
	await _f2_checks(hud)

	print("=== %d échec(s) ===" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Revue C7 B2 (file des notifications) et B6 (bouton du conseil avant Gestion).
func _b2_b6_checks(hud: Hud, s: PortSim) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	hud._calm_until = now + 100.0          # rien ne s'affiche pendant ce contrôle de la file
	hud.toast("C7 grave", "bad")
	hud.toast("C7 info 1")
	hud.toast("C7 info 2")
	var q1 := hud._toast_queue.map(func(it: Array) -> String: return String(it[0]))
	hud.toast("C7 info 1")             # jamais affichée : l'anti-doublon ne la connaît pas encore
	var q2 := hud._toast_queue.map(func(it: Array) -> String: return String(it[0]))
	var never_recent := not hud._toasts_recent.has("C7 grave") and not hud._toasts_recent.has("C7 info 1")
	check(str(q1) == str(["C7 grave", "C7 info 2"]) and str(q2) == str(["C7 grave", "C7 info 1"]) and never_recent,
		"C7 B2 : file pleine — la plus ancienne qui n'est pas « bad » cède, jamais la « bad » (%s puis %s) ; l'anti-doublon ne compte qu'une notification affichée" % [str(q1), str(q2)])
	# un écran ouvert : la notification attend (et la boîte se cache) ; elle paraît à la fermeture
	hud._toast_queue.clear()
	hud.toast("C7 sous un écran", "bad")
	hud.open_upgrades("")
	hud._calm_until = 0.0
	hud._next_toast_at = 0.0
	await _wait(3)
	var waited := not _toast_shown(hud, "C7 sous un écran") and hud._toast_queue.size() == 1 and not hud.toast_box.visible
	(hud.sheet_layer.get_child(0) as Sheet).close()
	await _wait(4)
	var shown := _toast_shown(hud, "C7 sous un écran") and hud.toast_box.visible and hud._toasts_recent.has("C7 sous un écran")
	for c in hud.toast_box.get_children():
		c.queue_free()
	hud._toast_cur = null
	await _wait(2)
	var bottom_ok := hud.toast_box.size.y < 1.0 and hud.top_cards_bottom() < hud.toast_box.position.y
	check(waited and shown and bottom_ok,
		"C7 B2 : pas de notification sur un écran ouvert (en attente %s), elle paraît à la fermeture (%s) ; sans notification, la boîte reprend sa hauteur (%s)" % [waited, shown, bottom_ok])
	# B6 : avant Gestion, le bouton CONSTRUIRE du conseil ouvre la fiche du bâtiment (pas l'écran Gestion, encore invisible)
	var pops := _npop(hud)
	var had_manage := s.feature("manage")
	var goal0 := hud.diorama.rig.goal
	hud._on_hint_pressed()
	await _wait(2)
	hud.diorama.rig.goal = goal0         # (le bouton recentre la vue sur l'emplacement : les contrôles de cadrage suivent)
	var fiche_ok := _npop(hud) == pops + 1 and not hud.any_sheet_open()
	for p in hud.popup_layer.get_children():
		p.queue_free()
	s.counters.erase("hint_used")
	var txt := s.unlock_text("dept_customs")
	check(not had_manage and fiche_ok and not txt.contains("Gestion") and txt.contains("emplacement doré"),
		"C7 B6 : avant Gestion, le conseil ouvre la fiche du bâtiment (%s) ; la Douane à venir ne renvoie pas à Gestion (« %s »)" % [fiche_ok, txt])
	await _wait(2)


func _start_zone_opening(dio: Diorama, zid: int) -> bool:
	dio.opening_queue.append(zid)
	for _i in 20:
		if dio.opening_active():
			return true
		await _wait(1)
	return dio.opening_active()


## Revue C7 B1 (reconstruction pendant une ouverture), B3 (« Toucher pour passer » et narratrice sous une fenêtre),
## B4 (bandeau et recentrage après la fermeture des écrans ; ouverture pendant le recentrage d'un chapitre).
func _b1_b3_b4_checks(hud: Hud, s: PortSim) -> void:
	var dio := hud.diorama
	# B1 : le décor est reconstruit au milieu d'une ouverture : elle se termine d'abord, rien ne reste à l'échelle 0
	var started := await _start_zone_opening(dio, 3)
	dio.opening.t = 2.0
	var od := dio.openings_done
	dio.rebuild()
	await _wait(3)
	var up_ok := true
	for n in (dio.zone_nodes.get(3, {}).get("nodes", []) as Array):
		if is_instance_valid(n) and (n as Node3D).scale.x < 0.5:
			up_ok = false
	check(started and not dio.opening_active() and dio.openings_done == od + 1 and up_ok,
		"C7 B1 : reconstruction du décor pendant une ouverture — elle est d'abord terminée, bâtiments en place (%s %s)" % [started, up_ok])
	await get_tree().create_timer(0.3).timeout
	# B3 : une fenêtre ouverte pendant une ouverture passable : ni « Toucher pour passer » ni narratrice par-dessus
	started = await _start_zone_opening(dio, 3)
	dio.opening.t = Layout.OPENING_SKIP_AFTER + 0.1
	var pop := hud.show_popup("C7", [UI.label("fenêtre", 30)])
	hud.narrate("C7 narratrice")
	hud._sync_opening(0.1)
	var hidden_ok := not hud.skip_hint.visible and hud._narration != null and not hud._narration.visible
	pop.queue_free()
	await _wait(2)
	hud._sync_opening(0.1)
	var back_ok := hud.skip_hint.visible == dio.opening_skippable() and hud._narration.visible
	dio.skip_opening()
	check(started and hidden_ok and back_ok, "C7 B3 : sous une fenêtre, ni « Toucher pour passer » ni narratrice ; ils reviennent à sa fermeture (%s %s)" % [hidden_ok, back_ok])
	await _wait(3)
	# B4 : bandeau d'un chapitre pendant qu'un écran est ouvert : rien (ni bandeau ni caméra) avant la fermeture
	var rg := dio.rig
	var player := Vector3(-30, 0, 10)
	rg.focus(player)
	var post := Layout.dept_pos("gate", s.tier)
	hud._banner_queue.clear()
	if hud._banner != null and is_instance_valid(hud._banner):
		hud._banner.queue_free()
	hud._banner = null
	# (lot D-UI : Améliorer est une feuille mi-hauteur qui cadre elle-même le service acheté ; le contrôle, qui porte sur
	# l'attente du bandeau et du recentrage, prend un écran plein cadre — contrôle recalé)
	hud.open_sheet(ManageSheet.new(0))
	await _wait(2)
	hud._queue_banner("C7 chapitre", "", "gate", UI.VIOLET, post, true)
	await _wait(3)
	var waited := hud._banner == null and rg.goal.distance_to(player) < 0.5
	(hud.sheet_layer.get_child(0) as Sheet).close()
	await _wait(4)
	var shown := hud._banner != null and rg.goal.distance_to(player) > 1.0 and dio.view_home.distance_to(player) < 0.5
	# une ouverture de zone pendant ce recentrage revient à la vue du joueur, pas au poste du chapitre
	started = await _start_zone_opening(dio, 3)
	var home_ok := started and Vector3(dio.opening.prev_goal).distance_to(player) < 0.5
	dio.opening.t = Layout.OPENING_SKIP_AFTER + 0.1
	dio.skip_opening()
	var cam_back := rg.goal.distance_to(player) < 0.5
	check(waited and shown and home_ok and cam_back,
		"C7 B4 : bandeau et recentrage attendent la fermeture de l'écran (%s, puis %s) ; une ouverture pendant le recentrage revient à la vue du joueur (%s %s)" % [waited, shown, home_ok, cam_back])
	hud._close_banner(hud._banner)
	await _wait(2)


## Une notification portant ce texte est-elle à l'écran ?
func _toast_shown(hud: Hud, text: String) -> bool:
	for p in hud.toast_box.get_children():
		if (p as Node).is_queued_for_deletion():
			continue
		for l in (p as Node).find_children("*", "Label", true, false):
			if (l as Label).text == text:
				return true
	return false


## Points d'un trajet affiché (positions successives de la vue, segments échantillonnés) qui entrent dans la terre ou le
## brise-lames (sans terre-plein).
func _trail_on_land(trail: Array) -> int:
	var n := 0
	for i in trail.size() - 1:
		var a: Vector3 = trail[i]
		var b: Vector3 = trail[i + 1]
		var k := maxi(1, ceili(Vector2(a.x - b.x, a.z - b.z).length() / 0.5))
		for j in k + 1:
			var p := a.lerp(b, float(j) / float(k))
			if Layout.on_land(Vector2(p.x, p.z), false):
				n += 1
	return n


func _dist_to_path(p: Vector3, path: Array) -> float:
	var best := INF
	for i in path.size() - 1:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), Vector2(a.x, a.z), Vector2(b.x, b.z))
		best = minf(best, q.distance_to(Vector2(p.x, p.z)))
	return best


func _fake_ship(s: PortSim, id: int, state: int, slot: int, berth: int, timer: float) -> Ship:
	var sh := Ship.new()
	sh.id = id
	sh.cls = String(s.db.ships[0].id)
	sh.owner = String(s.db.owners[0].id)
	sh.evp_total = 10.0
	sh.left = PackedFloat64Array()
	sh.left.resize(PortSim.NCARGO)
	sh.left[0] = 10.0
	sh.anchor_slot = slot
	sh.berth = berth
	sh.state = state
	sh.timer = timer
	return sh


## Revue C7 A1 / A6 : la vue d'un navire reste sur les polylignes du plan — retenue puis relâchée (la simulation a changé
## d'état entre-temps), état sauté, départ terminé dans la simulation, chargement d'une partie en plein pilotage.
func _ship_view_checks(hud: Hud, s: PortSim) -> void:
	var dio := hud.diorama
	var dt := 0.1
	# A1 : mouillé à l'est du chenal (place n°2), retenu dès le début du pilotage ; la simulation passe à l'amarrage puis aux
	# formalités pendant la retenue. Avant C7, il coupait en ligne droite à travers le brise-lames au relâchement.
	var sh := _fake_ship(s, 9001, Ship.State.ANCHORED, 1, 0, 0.0)
	var v := ShipView.new()
	dio.ships_root.add_child(v)
	v.setup(sh, s)
	v.place(sh, s)
	var trail: Array = [v.position]
	sh.state = Ship.State.PILOTING
	sh.timer = 20.0
	var still := true
	# (lot F1, recalé : 1 500 images au lieu de 700 — à vitesse de croisière, le pilotage depuis la place n°2 prend ≈ 60 s, plus
	# 29 s de retenue ; avant, la vue suivait le minuteur de la simulation et pouvait filer à 50 u/s)
	for i in 1500:
		v.hold = i >= 10 and i < 300
		sh.timer -= dt
		if sh.state == Ship.State.PILOTING and sh.timer <= 0.0:
			sh.state = Ship.State.MOORING
			sh.timer = 4.0
		elif sh.state == Ship.State.MOORING and sh.timer <= 0.0:
			sh.state = Ship.State.FORMALITIES
			sh.timer = 500.0
		var before := v.position
		v.sync(sh, s, dt)
		if i > 11 and i < 300 and Vector2(before.x - v.position.x, before.z - v.position.z).length() > 0.001:
			still = false
		trail.append(v.position)
	var at_berth := Vector2(v.position.x, v.position.z).distance_to(Vector2(Layout.berth_center(0), Layout.berth_ship_pos(0, v.width).z)) < 1.0
	var land1 := _trail_on_land(trail)
	# état sauté (grande vitesse de simulation) : de la rade directement aux formalités → il reprend le trajet de pilotage
	var sh2 := _fake_ship(s, 9002, Ship.State.ANCHORED, 2, 0, 0.0)
	var v2 := ShipView.new()
	dio.ships_root.add_child(v2)
	v2.setup(sh2, s)
	v2.place(sh2, s)
	var trail2: Array = [v2.position]
	sh2.state = Ship.State.FORMALITIES
	sh2.timer = 500.0
	for i in 400:
		v2.sync(sh2, s, dt)
		trail2.append(v2.position)
	var land2 := _trail_on_land(trail2)
	check(land1 == 0 and land2 == 0 and still and at_berth,
		"C7 A1 : retenu puis relâché, le navire reprend le long de son trajet jusqu'au poste (immobile pendant la retenue %s, au poste %s ; points dans la terre ou le brise-lames : %d, état sauté : %d)" % [still, at_berth, land1, land2])
	v2.queue_free()
	# A1 : départ retenu, puis supprimé par la simulation → la vue finit son trajet jusqu'à la sortie (hors champ)
	sh.state = Ship.State.DEPARTING
	sh.timer = 6.0
	var trail3: Array = [v.position]
	for i in 30:
		v.hold = i >= 5
		sh.timer -= dt
		v.sync(sh, s, dt)
		trail3.append(v.position)
	dio.ship_views[sh.id] = v
	sh.timer = 0.0
	dio._on_ship_removed(sh)
	var kept := is_instance_valid(v) and dio.parting.has(v) and not dio.ship_views.has(sh.id)
	var done := false
	for i in 4000:
		if v.sync_parting(dt):
			done = true
			break
		trail3.append(v.position)
	var end_p: Vector3 = v.shown_path().back()
	# (lot F1, recalé : 0,5 u → une demi-longueur + 0,5 u) à la sortie, la coque reste sur la corde étrave–poupe : son centre
	# finit une demi-longueur derrière le bout du trajet (avant, il revenait d'un coup sur le dernier point)
	var far := Vector2(v.position.x, v.position.z).distance_to(Vector2(end_p.x, end_p.z)) < v.length * 0.5 + 0.5 and v.position.z < -150.0
	check(kept and done and far and _trail_on_land(trail3) == 0,
		"C7 A1 : un navire qui part n'est pas effacé en pleine vue — il finit son trajet jusqu'à la sortie (gardé %s, au bout %s, hors du port %s)" % [kept, done, far])
	# A1 : cas symétrique — chacun « suit » l'autre : un seul cède (le plus grand identifiant)
	var mutual := Diorama.follows(Vector2(0, 0), Vector2(0, 1), 20.0, Vector2(5, 1), Vector2(-0.6, 0.8), 20.0) \
		and Diorama.follows(Vector2(5, 1), Vector2(-0.6, 0.8), 20.0, Vector2(0, 0), Vector2(0, 1), 20.0)
	var held := Diorama.holds([{"id": 4, "p": Vector2(0, 0), "dir": Vector2(0, 1), "len": 20.0},
		{"id": 7, "p": Vector2(5, 1), "dir": Vector2(-0.6, 0.8), "len": 20.0}])
	check(mutual and held.size() == 1 and held.has(7), "C7 A1 : deux navires qui se « suivent » l'un l'autre — un seul cède (%s)" % str(held.keys()))
	# A6 : chargement d'une partie avec un navire en plein pilotage → posé sur son trajet de pilotage, jamais au poste
	var sh4 := _fake_ship(s, 9004, Ship.State.PILOTING, 0, 0, 1.0)
	var v4 := ShipView.new()
	dio.ships_root.add_child(v4)
	v4.setup(sh4, s)
	var full := s.pilot_duration() * s.time_scale(sh4.cls)
	sh4.timer = full * 0.5
	v4.place(sh4, s)
	var pilot := Layout.ship_path_pilot(0, 0)
	var on_path := _dist_to_path(v4.position, pilot) < 0.5
	var not_berth := v4.position.distance_to(Layout.berth_ship_pos(0, v4.width)) > 30.0
	var trail4: Array = [v4.position]
	for i in 300:
		sh4.timer -= dt
		if sh4.timer <= 0.0:
			sh4.state = Ship.State.MOORING
			sh4.timer = 3.0
		v4.sync(sh4, s, dt)
		trail4.append(v4.position)
	check(on_path and not_berth and _trail_on_land(trail4) == 0,
		"C7 A6 : chargement en plein pilotage — navire posé sur son trajet (sur le trajet %s, loin du poste %s), aucun point dans la terre" % [on_path, not_berth])
	v4.queue_free()
## Sol d'un camion : autoroute, route d'accès (élargie avec la 2e voie), voie des camions, aire d'attente.
func _truck_ground(p: Vector3, gate2: bool, lots: bool) -> bool:
	var q := Vector2(p.x, p.z)
	var rects: Array[Rect2] = [Rect2(-132, Layout.HIGHWAY_Z0, 318, 6), Rect2(-24, 36, 12.0 if gate2 else 6.0, 102), Rect2(-24, 30, 174, 6)]
	if lots:
		rects.append(Rect2(-12, 54, 18, 54))
	for r in rects:
		if r.grow(0.6).has_point(q):
			return true
	return false


## Fait rouler un camion jusqu'au bout de sa route ; renvoie le nombre de points hors des routes et des aires.
func _drive_off_road(tv: TrafficView, n: Node3D, route: Array, gate2: bool, lots: bool) -> int:
	var bad := 0
	for i in 4000:
		if tv._drive(n, route, TrafficView.SPEED, 0.05):
			break
		if not _truck_ground(n.position, gate2, lots):
			bad += 1
	return bad


## Revue C7 A2 / A7 : camions réaffectés ou en trop, engins du parc (TrafficView n'est pas utilisable sans les autoloads).
func _traffic_checks(db: DataDB) -> void:
	# A2 : camion réaffecté à une autre place de la file : il garde la route (autoroute → bretelle → voie d'entrée)
	var tv := TrafficView.new()
	add_child(tv)
	tv._gate2 = true
	tv._lot_slots = 8
	var bads: Array[String] = []
	var cases := [
		["autoroute → place 2 (même voie)", Vector3(-100, 0, Layout.HIGHWAY_LANE_E), tv.slot_pos(4), tv.slot_pos(2)],
		["autoroute → place 1 (autre voie)", Vector3(-60, 0, Layout.HIGHWAY_LANE_E), tv.slot_pos(4), tv.slot_pos(1)],
		["aire d'attente → route", Layout.lot_slot(3), Layout.lot_slot(3), tv.slot_pos(0)],
		["route → aire d'attente", tv.slot_pos(4), tv.slot_pos(4), Layout.lot_slot(1)],
		["aire → aire", Layout.lot_slot(6), Layout.lot_slot(6), Layout.lot_slot(0)],
	]
	for c in cases:
		var n := Node3D.new()
		tv.add_child(n)
		n.position = c[1]
		n.set_meta("target", c[2])
		n.set_meta("route", [c[2]])
		tv._assign(n, c[3])
		var r: Array = n.get_meta("route")
		var off := _drive_off_road(tv, n, r, true, true)
		if off > 0 or n.position.distance_to(c[3]) > 0.1:
			bads.append("%s : %d" % [c[0], off])
	# camions en trop (la gate a rattrapé, nouvelle concession où l'aire disparaît) : ils repartent par les routes
	for c in [["en trop sur l'autoroute", Vector3(-80, 0, Layout.HIGHWAY_LANE_E), true],
			["en trop sur la route", tv.slot_pos(6), true], ["en trop dans l'aire", Layout.lot_slot(5), true],
			["après un prestige (aire et 2e voie disparues)", Layout.lot_slot(2), false]]:
		tv._gate2 = bool(c[2])
		var n2 := Node3D.new()
		tv.add_child(n2)
		n2.position = c[1]
		var off2 := _drive_off_road(tv, n2, tv.exit_route(n2.position), true, true)
		if off2 > 0 or n2.position.x < 180.0:
			bads.append("%s : %d" % [c[0], off2])
	tv._gate2 = false
	tv._lot_slots = 0
	var n3 := Node3D.new()
	tv.add_child(n3)
	n3.position = Layout.lot_slot(2)
	n3.set_meta("target", Layout.lot_slot(2))
	tv._assign(n3, tv.slot_pos(0))
	var off3 := _drive_off_road(tv, n3, n3.get_meta("route"), true, true)
	if off3 > 0:
		bads.append("après un prestige, vers la route : %d" % off3)
	check(bads.is_empty(), "C7 A2 : camions réaffectés ou en trop — aucun segment hors des routes et des aires (%s)" % str(bads))
	tv.queue_free()
	# A7 : l'engin appelé est attendu (trajet de plus de 3 s) ; il repart par les allées ; à l'arrêt quand rien n'est à transporter
	var ys := PortSim.new(db, 35)
	var tv2 := TrafficView.new()
	add_child(tv2)
	tv2._sync_vehicles(ys, 0.0)
	var veh: Dictionary = tv2.vehicles[0]
	(veh.node as Node3D).position = Vector3(-34.0, 0, Layout.APRON_LANE_Z)
	veh.route = []
	veh.task = "idle"
	var tn := Node3D.new()
	tv2.add_child(tn)
	tn.position = Vector3(-6.0, 0, Layout.LOAD_STOP_Z)
	tv2.trucks = [{"node": tn, "route": [], "phase": "wait", "stop_x": -6.0, "t": 0.0, "container": null, "loader": -1}]
	var waited := false
	var diag := 0
	var from_veh := false
	var prev := (veh.node as Node3D).position
	for i in 800:
		var ph := String(tv2.trucks[0].phase) if not tv2.trucks.is_empty() else "parti"
		tv2._sync_trucks(ys, 0.05)
		if ph == "wait" and not tv2.trucks.is_empty() and String(tv2.trucks[0].phase) == "loading":
			from_veh = veh.carry == null and String(veh.task) == "back"
		if i == 100 and not tv2.trucks.is_empty() and String(tv2.trucks[0].phase) == "wait" and int(tv2.trucks[0].loader) == 0:
			waited = true          # 5 s après l'arrivée du camion, l'engin en route est toujours attendu
		tv2._sync_vehicles(ys, 0.05)
		var cur := (veh.node as Node3D).position
		if absf(cur.x - prev.x) > 0.02 and absf(cur.z - prev.z) > 0.02:
			diag += 1
		prev = cur
	var rest := (veh.node as Node3D).position
	for i in 40:
		tv2._sync_vehicles(ys, 0.05)
	var idle_ok := String(veh.task) == "idle" and (veh.node as Node3D).position.distance_to(rest) < 0.01 and absf(rest.z - Layout.APRON_LANE_Z) < 0.1
	check(waited and from_veh and diag == 0 and idle_ok,
		"C7 A7 : engin attendu au-delà de 3 s (%s), le conteneur vient de lui (%s), aucun déplacement en diagonale (%d), à l'arrêt au tablier quand rien n'est à transporter (%s)" % [waited, from_veh, diag, idle_ok])
	tv2.queue_free()


# ---------------------------------------------------------------------------
# Lot D-UI (docs/ORDRE_D_UI.md)
# ---------------------------------------------------------------------------

## Phase 1 : cartes d'Améliorations jamais plus larges que l'écran au T3 ; carte Goulot « parc trop petit » dont le bouton dit
## quoi et combien et passe au vert dès qu'une action (bâtiment ou amélioration du service) règle le goulot.
func _dui_phase1(hud: Hud, s: PortSim) -> void:
	DebugArgs.apply({"tier": "3", "build-all": "", "levels": "83", "hire-all": ""}, s, s.db, true)
	# (le passage de palier joue sa cérémonie : on l'abrège et on ferme ses fenêtres)
	hud._finish_ceremony()
	for p in hud.popup_layer.get_children():
		p.queue_free()
	s.money = 5.0e9
	await _wait(3)
	hud.open_upgrades("")
	await _wait(4)
	var up: UpgradesSheet = hud.sheet_layer.get_child(0)
	var vw := hud.get_viewport_rect().size.x
	var wide: Array[String] = []
	for tb in [0, 1]:
		up._select_tab(tb)
		await _wait(3)
		up.refresh()
		await _wait(2)
		for c in up.cards:
			var r := (c.root as Control).get_global_rect()
			if r.end.x > vw + 0.5 or r.position.x < -0.5:
				wide.append("%s (%d → %d)" % [str(c.get("dept", c.get("cargo", "?"))), int(r.position.x), int(r.end.x)])
	check(up.cards.size() >= 5 and wide.is_empty(), "D-UI 1 : au T3, aucune carte d'Améliorations plus large que l'écran (%d px ; trop larges : %s)" % [int(vw), str(wide)])
	up.close()
	await _wait(2)
	# goulot « parc trop petit » (capacité, pas remplissage) : titre et bouton
	var saved := s.analysis_shown
	s.analysis_shown = {"key": "yard_space", "dept": "yard_ops", "hint": "x", "flow": 1.0, "caps": {}}
	s.money = 0.0
	var a0 := Hud.hint_action(s)
	s.money = s.dept_cost("yard_ops", 1) + 1.0
	var a1 := Hud.hint_action(s)
	hud._refresh(s)
	var title1 := hud.hint_title.text
	var btn1 := hud.hint_btn.text
	check(not bool(a0.can) and bool(a1.can) and String(a1.kind) == "dept" and btn1.begins_with("AMÉLIORER STOCKAGE · ") and btn1.ends_with("$")
		and title1.contains("trop petit") and not title1.contains("saturé") and Hud.hint_actionable(s),
		"D-UI 1 : goulot « %s » — sans argent bouton gris, avec de quoi améliorer le parc : « %s » vert" % [title1, btn1])
	s.analysis_shown = saved
	s.money = 5.0e9
	hud._refresh(s)


## Phase 2 : Améliorer en feuille mi-hauteur au-dessus du port qui vit (surcouche visible, effets non suspendus, HUD replié,
## solde dans l'en-tête), ouverte sur le goulot et cadrée sur son poste ; achat → retour dans le monde ; boutons gris
## « Il manque … » ; pastille d'Améliorer qui ne compte que les achats qui rapportent ; Gestion reste plein cadre.
func _dui_phase2(hud: Hud, s: PortSim) -> void:
	await _dui_skip_openings(hud)
	for p in hud.popup_layer.get_children():
		p.queue_free()
	await _wait(2)
	var rg := hud.diorama.rig
	var player := Vector3(-20, 0, 10)
	rg.focus(player)
	rg.target = rg.goal
	rg._apply()
	var saved := s.analysis_shown
	s.analysis_shown = {"key": "gate", "dept": "gate", "hint": "x", "flow": 1.0, "caps": {}}
	s.money = 5.0e9
	hud.open_upgrades("")
	await _wait(5)
	var up: UpgradesSheet = hud.sheet_layer.get_child(0)
	var vs := hud.get_viewport_rect().size
	var live := up.half and hud.half_sheet_open() and hud.overlay.visible and not hud.diorama.fx_paused and not hud.top_box.visible \
		and up.money_l != null and up.money_l.text.ends_with("$")
	check(live, "D-UI 2 : Améliorer en feuille mi-hauteur — port vivant au-dessus (surcouche %s, effets en pause %s), HUD replié, solde dans l'en-tête (%s)" % [
		hud.overlay.visible, hud.diorama.fx_paused, up.money_l.text if up.money_l else "?"])
	# ouverte sur le goulot, sa carte en haut de la feuille ; la caméra cadre son poste dans la moitié haute
	rg.target = rg.goal
	rg._apply()
	var gc := up._card_for("dept", "gate")
	var cr: Rect2 = (gc.root as Control).get_global_rect() if not gc.is_empty() else Rect2()
	var sp := hud.diorama.to_screen(hud.dept_anchor("gate"))
	check(up.shown_dept == "gate" and cr.position.y >= vs.y * Sheet.HALF_TOP and cr.position.y < vs.y * Sheet.HALF_TOP + 420.0
		and sp.y > 0.0 and sp.y < vs.y * Sheet.HALF_TOP and sp.x > 0.0 and sp.x < vs.x,
		"D-UI 2 : ouverte sur le goulot (%s, carte à y %d) ; son poste cadré au-dessus de la feuille (%d, %d)" % [up.shown_dept, int(cr.position.y), int(sp.x), int(sp.y)])
	# un achat : effet dans le monde (D-Monde), texte flottant au-dessus du poste, pastille (même hors goulot)
	var fb0 := int(hud.diorama.get("purchase_feedbacks")) if hud.diorama.get("purchase_feedbacks") != null else -1
	var pop0 := hud.overlay.popups_added
	up._buy_dept("cranes")
	for i in 30:
		await _wait(1)
		if hud.overlay.popups_added > pop0 and hud._buy_fx.is_empty():
			break
	var fb1 := int(hud.diorama.get("purchase_feedbacks")) if fb0 >= 0 else -1
	var pill := hud.gain_l.text
	check((fb0 < 0 or fb1 == fb0 + 1) and hud.overlay.popups_added > pop0 and hud.gain_pill.visible and (pill.ends_with("$/s") or pill.contains("pas le goulot")),
		"D-UI 2 : achat — effet dans le monde (%d → %d), texte flottant, pastille « %s »" % [fb0, fb1, pill])
	# bouton gris : « Il manque … »
	s.money = 1.0
	up.refresh()
	var bt := (up._card_for("dept", "gate").buy as Button)
	check(bt.disabled and bt.text.begins_with("Il manque"), "D-UI 2 : bouton gris « %s »" % bt.text.replace("\n", " "))
	# pastille : seulement les achats abordables qui rapportent
	# (lot D-Éco, recalé : avec les services facturés, chaque niveau rapporte un minimum ; le filtre se vérifie donc
	# sans eux — `service_fee` à 0 le temps du contrôle — puis on vérifie que la pastille suit le gain réel)
	s.money = 5.0e9
	var raw := 0
	for d in PortSim.DEPTS:
		if s.feature("dept_" + d) and s.dept_cost(d, 1) <= s.money:
			raw += 1
	var fee0 = s.db.config.get("service_fee", 0.0)
	s.db.config["service_fee"] = 0.0
	s.invalidate()
	hud._aff_t = -10.0
	var n_nofee := 0
	var base0 := s.income_estimate_with("harbor", 0)
	for d in PortSim.DEPTS:
		if s.feature("dept_" + d) and s.dept_cost(d, 1) <= s.money and s.upgrade_gain(d, 1, -1, base0) > 0.0:
			n_nofee += 1
	s.db.config["service_fee"] = fee0
	s.invalidate()
	hud._aff_t = -10.0
	var n_aff := hud._affordable_count(s)
	var n_dept := 0
	var n_good := 0
	var base1 := s.income_estimate_with("harbor", 0)
	var goal1 := String(s.chapter_goal().get("dept", ""))
	for d in PortSim.DEPTS:
		var c1 := s.dept_cost(d, 1)
		if s.feature("dept_" + d) and c1 <= s.money:
			var g1 := s.upgrade_gain(d, 1, -1, base1)
			if g1 > 0.0:
				n_dept += 1
			if d == goal1 or (not Info.event_hits(s, d) and UpgradesSheet.is_good(s.upgrade_gain_parts(d, 1), c1)):
				n_good += 1
	var n_lic_good := 0
	for ci in PortSim.NCARGO:
		var lc1 := s.licence_cost(ci, 1)
		if s.unlocked[ci] == 1 and s.feature("licences") and s.licence_room(ci) > 0 and lc1 <= s.money \
				and UpgradesSheet.is_good(s.upgrade_gain_parts("", 1, ci), lc1):
			n_lic_good += 1
	# (lot E, recalé : la pastille ne compte plus « tout ce qui rapporte » — avec les services facturés, c'est tout — mais
	# les achats qui valent le coup : le débit bouge et l'achat se rentabilise en moins de 10 min)
	check(n_nofee < raw and n_dept == raw and n_aff == n_good + n_lic_good and n_aff <= n_dept + n_lic_good,
		"D-UI 2 / D-Éco / E1 : la pastille ne compte que les bons achats (sans services facturés %d sur %d rapportent ; avec : %d ; bons achats %d + %d licences = pastille %d)" % [n_nofee, raw, n_dept, n_good, n_lic_good, n_aff])
	# fermeture : la caméra revient au cadrage du joueur
	up.close()
	await _wait(3)
	check(rg.goal.distance_to(player) < 0.5 and hud.top_box.visible, "D-UI 2 : fermeture — caméra rendue au joueur (%s), HUD revenu" % str(rg.goal))
	s.analysis_shown = saved
	# Commerce aussi en mi-hauteur ; Gestion reste plein cadre (le port est en pause derrière) avec le mini-solde
	hud.open_sheet(CommerceSheet.new(CommerceSheet.TAB_TRAFFIC))
	await _wait(3)
	var com_half := hud.half_sheet_open()
	hud.open_sheet(ManageSheet.new(0))
	await _wait(3)
	var ms := hud.current_sheet() as ManageSheet
	check(com_half and not ms.half and hud.diorama.fx_paused and not hud.overlay.visible and ms.money_l.text != "",
		"D-UI 2 : Commerce en mi-hauteur (%s) ; Gestion plein cadre, port en pause, mini-solde « %s »" % [com_half, ms.money_l.text])
	ms.close()
	await _wait(3)


## Phase 3 : HUD du haut < 20 % de l'écran au T3 ; Améliorer en gros bouton en bas à droite, Réglages en petit rond dans le
## coin, Heures sup en rond flottant ; cibles ≥ 96 px et textes ≥ 24 px ; revenu en $/s ; « + » de l'Ambre = explication ;
## Gestion triée, construits repliés ; bandeau « Nouveau » avec VOIR ; bulle de rade au mouillage ; aide repliée après lecture.
func _dui_phase3(hud: Hud, s: PortSim) -> void:
	await _dui_skip_openings(hud)
	var vs := hud.get_viewport_rect().size
	s.active_event = {}
	hud.strip_folded = true
	hud.hint_text.visible = false
	hud.tutorial.active = false
	hud._refresh(s)
	await _wait(3)
	var chrome := hud.top_chrome_bottom() / vs.y
	check(chrome < 0.20, "D-UI 3 : chrome du haut au T3 : %d %% de l'écran (< 20 %%)" % roundi(chrome * 100.0))
	var ur := hud.upgrade_btn.get_global_rect()
	var sr := hud.settings_btn.get_global_rect()
	check(ur.get_center().x > vs.x * 0.6 and ur.get_center().y > vs.y * 0.85 and ur.size.x >= 260.0
		and sr.size.x <= 100.0 and sr.position.x < vs.x * 0.1 and sr.end.y > vs.y * 0.9,
		"D-UI 3 : AMÉLIORER en gros bouton en bas à droite (%s), Réglages en petit rond dans le coin (%s)" % [str(ur), str(sr)])
	# Heures sup : rond flottant, grand quand il est prêt, discret en recharge
	s.boost_ready_at = s.time + 100.0
	s.boost_until = s.time - 1.0
	hud._refresh(s)
	var st_rech := hud.boost_btn.state
	s.boost_ready_at = s.time - 1.0
	hud._refresh(s)
	await _wait(2)
	check(st_rech == "recharge" and hud.boost_btn.state == "pret" and hud.boost_btn.visible and not hud.bottom_box.is_ancestor_of(hud.boost_btn)
		and hud.boost_btn.get_global_rect().end.y <= hud.upgrade_btn.get_global_rect().position.y + 1.0,
		"D-UI 3 : Heures sup en rond flottant au-dessus d'AMÉLIORER (recharge → prêt : %s → %s)" % [st_rech, hud.boost_btn.state])
	# cibles tactiles ≥ 96 px
	var small: Array[String] = []
	var targets := {"coffre": hud.chest_btn, "Ambre +": hud.amber_btn, "Réglages": hud.settings_btn, "▲": hud.strip_fold,
		"goulot": hud.hint_btn, "Améliorer": hud.upgrade_btn, "Gestion": hud.manage_btn, "Commerce": hud.commerce_btn, "Heures sup": hud.boost_btn}
	hud.strip_folded = false
	hud._refresh(s)
	await _wait(2)
	for k in targets:
		var c: Control = targets[k]
		var r := c.get_global_rect()
		r.size = c.size        # taille au repos (un bouton qui vient d'apparaître rebondit : son échelle n'est pas encore 1)
		if c.is_visible_in_tree() and (r.size.x < 95.5 or r.size.y < 95.5):
			small.append("%s %dx%d" % [k, int(r.size.x), int(r.size.y)])
	Sheet.help_seen.clear()          # l'aide d'Améliorer est relue comme la première fois
	hud.open_upgrades("")
	await _wait(4)
	var up: UpgradesSheet = hud.sheet_layer.get_child(0)
	for c in up.cards:
		for b in (c.root as Node).find_children("*", "Button", true, false):
			var r2 := (b as Control).get_global_rect()
			if (b as Control).is_visible_in_tree() and (r2.size.x < 95.5 or r2.size.y < 95.5):
				small.append("carte %s %dx%d" % [str(c.get("dept", "")), int(r2.size.x), int(r2.size.y)])
	# aide d'en-tête : lue une fois, ensuite repliée dans le « ? »
	var help_now := false
	for l in up.content.get_children():
		# (lot G2, recalé : « service », nom de métier, au lieu de « département »)
		if l is Label and (l as Label).text.begins_with("Le service"):
			help_now = true
	var help_btn_ok := up.help_btn.visible
	up.close()
	await _wait(2)
	check(small.is_empty(), "D-UI 3 : cibles tactiles ≥ 96 px (trop petites : %s)" % str(small))
	# textes ≥ 24 px dans le HUD (libellés et barres)
	var tiny: Array[String] = []
	for box in [hud.top_box, hud.bottom_box]:
		for l in (box as Node).find_children("*", "Label", true, false):
			var lb := l as Label
			if lb.is_visible_in_tree() and lb.text != "" and lb.get_theme_font_size("font_size") < 24:
				tiny.append("%s (%d)" % [lb.text, lb.get_theme_font_size("font_size")])
		for rb in (box as Node).find_children("*", "RoundBar", true, false):
			if (rb as Control).is_visible_in_tree() and (rb as RoundBar).text != "" and (rb as RoundBar).font_size < 24:
				tiny.append("barre « %s » (%d)" % [(rb as RoundBar).text, (rb as RoundBar).font_size])
	check(tiny.is_empty() and hud.income_l.text.ends_with("$/s"), "D-UI 3 : textes du HUD ≥ 24 px (trop petits : %s) ; revenu en $/s (%s)" % [str(tiny), hud.income_l.text])
	hud.strip_folded = true
	# « + » de l'Ambre : comment en gagner
	var np0 := _npop(hud)
	hud.amber_btn.pressed.emit()
	await _wait(2)
	var amber_ok := _npop(hud) == np0 + 1
	for p in hud.popup_layer.get_children():
		p.queue_free()
	await _wait(2)
	check(amber_ok, "D-UI 3 : le « + » de l'Ambre ouvre « Comment gagner de l'Ambre »")
	# Gestion › Bâtiments : disponible › bloqué › construit, construits repliés ; (au T3 tout est construit : on en retire un)
	var last_b := String(s.db.buildings.back().id)
	s.built.erase(last_b)
	hud.open_sheet(ManageSheet.new(0))
	await _wait(3)
	var ms := hud.current_sheet() as ManageSheet
	var first_id := String(ms.rows[0].id) if not ms.rows.is_empty() else ""
	var fold_txt := ms.built_fold_btn.text if ms.built_fold_btn != null else "?"
	var fold_ok := ms.built_fold_btn != null and fold_txt.contains("construit") and ms.rows.size() == 1
	ms.close()
	s.built.append(last_b)
	await _wait(3)
	await _dui_skip_openings(hud)
	check(first_id == last_b and fold_ok, "D-UI 3 : Gestion › Bâtiments — le disponible d'abord (%s), les construits repliés (« %s »)" % [first_id, fold_txt])
	# bandeau « Nouveau : … » avec VOIR qui ouvre le bon écran
	hud._banner_queue.clear()
	if hud._banner != null and is_instance_valid(hud._banner):
		hud._banner.queue_free()
	hud._banner = null
	hud._queue_banner("Nouveau : Responsables", "", "people", UI.VIOLET, Vector3.INF, false, "managers")
	await _wait(2)
	var has_voir := hud.banner_voir != null and hud.banner_voir.is_visible_in_tree()
	if has_voir:
		hud.banner_voir.pressed.emit()
	await _wait(3)
	var cs := hud.current_sheet()
	check(has_voir and cs is ManageSheet and cs.tab == 2, "D-UI 3 : bandeau « Nouveau » avec VOIR → Gestion › Responsables (%s)" % str(cs))
	if cs != null:
		cs.close()
	await _wait(3)
	# bulle « n/n en rade » au mouillage (D-Monde : rade_anchor), aide repliée à la 2e ouverture
	hud.overlay.frame_rects.clear()
	await _wait(3)
	var rr: Rect2 = hud.overlay.frame_rects.get("rade", Rect2())
	var ra: Vector3 = hud.diorama.call("rade_anchor") if hud.diorama.has_method("rade_anchor") else Layout.anchor_pos(0)
	var ras := hud.diorama.to_screen(ra)
	# (lot E : le contrôle vérifie vraiment — la bulle doit être dessinée, et près du mouillage ramené dans le rectangle utile ;
	# avant, il passait sans bulle ou avec un mouillage près du bord)
	var uf := hud.overlay.useful
	var near := rr.has_area() and rr.get_center().distance_to(ras.clamp(uf.position, uf.end)) < 260.0
	hud.open_upgrades("")
	await _wait(4)
	var up2: UpgradesSheet = hud.sheet_layer.get_child(0)
	var help_again := false
	for l in up2.content.get_children():
		# (lot G2, recalé : « service », nom de métier, au lieu de « département »)
		if l is Label and (l as Label).text.begins_with("Le service"):
			help_again = true
	up2.close()
	await _wait(3)
	check(near and help_btn_ok and help_now and not help_again, "D-UI 3 : bulle de rade près du mouillage (%s / %s) ; aide d'Améliorer repliée dans le « ? » après lecture (1re fois %s, 2e %s)" % [
		str(rr.get_center()), str(ras), help_now, help_again])


## Phase 4 : cérémonie de palier (gerbe, jingle, puis la fenêtre) ; encaissement d'un navire ; gestes en $ ; sons (10 voix,
## priorités, bus Sons et Ambiance réglables) ; Heures sup et campagne envoyées au monde.
func _dui_phase4(hud: Hud, s: PortSim) -> void:
	for p in hud.popup_layer.get_children():
		p.queue_free()
	await _wait(2)
	var np0 := _npop(hud)
	var c0 := hud.ceremonies
	hud._on_tier(2)
	await _wait(2)
	var during := hud.ceremony_active() and hud.diorama.fx_paused and _npop(hud) == np0
	hud._finish_ceremony()
	await _wait(2)
	check(hud.ceremonies == c0 + 1 and during and not hud.ceremony_active() and _npop(hud) == np0 + 1,
		"D-UI 4 : cérémonie de palier puis la fenêtre (pendant : %s ; fenêtres %d → %d)" % [during, np0, _npop(hud)])
	for p in hud.popup_layer.get_children():
		p.queue_free()
	await _wait(2)
	# encaissement par événement : « +X $ » au poste, pièces vers le compteur
	var pop0 := hud.overlay.popups_added
	var sh0 := hud.ships_paid_shown
	if hud.diorama.has_signal("ship_paid"):
		hud.diorama.emit_signal("ship_paid", Vector3(Layout.berth_center(0), 8.0, Layout.QUAY_Z), 1234.0)
	await _wait(2)
	check(not hud.diorama.has_signal("ship_paid") or (hud.overlay.popups_added == pop0 + 1 and hud.ships_paid_shown == sh0 + 1),
		"D-UI 4 : un navire payé → « +1,23K $ » au poste et pièces vers le compteur (%d)" % (hud.ships_paid_shown - sh0))
	# gestes manuels affichés en $
	var gt := Hud.gesture_text("Rangé ! +12 EVP")
	check(gt.begins_with("Rangé ! +") and gt.ends_with("$") and not gt.contains("EVP"), "D-UI 4 : geste affiché en $ (« %s »)" % gt)
	# sons : 10 voix, bus « Sons » et « Ambiance », hauteur variable ; la corne n'est jamais volée
	var sfx: Node = get_tree().root.get_node("Sfx")
	var buses := AudioServer.get_bus_index("Sons") >= 0 and AudioServer.get_bus_index("Ambiance") >= 0
	var voices: int = (sfx.get("_players") as Array).size()
	var st: Node = get_tree().root.get_node("Settings")
	var was_muted: bool = st.get("muted")
	st.set("muted", false)
	for i in voices:
		sfx.call("play", "ship_horn", 0.0)
	var all_busy := true
	for i in voices:
		if int(sfx.call("voice_priority", i)) < 0:
			all_busy = false
	var d0: int = sfx.get("dropped")
	sfx.call("play", "clank", 0.0)
	var kept_live: bool = int(sfx.get("dropped")) == d0 + 1 or not all_busy
	# (lot E : la règle est vérifiée sans dépendre du pilote audio — en --headless les voix ne restent pas toujours
	# « en lecture », et l'ancien contrôle passait alors sans rien vérifier)
	var p3: Array[int] = []
	var b_all: Array[bool] = []
	for i in 10:
		p3.append(3)
		b_all.append(true)
	var p_mix := p3.duplicate()
	p_mix[4] = 1
	p_mix[7] = 0
	var b_free := b_all.duplicate()
	b_free[6] = false
	var rule := int(sfx.call("pick_voice", p3, b_all, 0)) == -1 and int(sfx.call("pick_voice", p3, b_all, 3)) == -1 \
		and int(sfx.call("pick_voice", p_mix, b_all, 1)) == 7 and int(sfx.call("pick_voice", p_mix, b_all, 0)) == 7 \
		and int(sfx.call("pick_voice", p_mix, b_free, 0)) == 6 and int(sfx.call("pick_voice", [2, 2] as Array[int], [true, true] as Array[bool], 1)) == -1
	var kept: bool = kept_live and rule
	var pitches := {}
	for p in (sfx.get("_players") as Array):
		pitches[snappedf((p as AudioStreamPlayer).pitch_scale, 0.0001)] = true
	st.set("muted", was_muted)
	for p in (sfx.get("_players") as Array):
		(p as AudioStreamPlayer).stop()
	check(buses and voices == 10 and kept and pitches.size() > 1, "D-UI 4 : sons — bus Sons et Ambiance (%s), %d voix, corne jamais volée (toutes occupées : %s), hauteurs variées (%d)" % [buses, voices, all_busy, pitches.size()])
	# Réglages : deux réglettes de volume
	hud.open_sheet(SettingsSheet.new())
	await _wait(3)
	var ss := hud.current_sheet() as SettingsSheet
	var v0: float = sfx.call("get_volume", "Ambiance")
	(ss.sliders["Ambiance"] as HSlider).value = 35.0
	var v1: float = sfx.call("get_volume", "Ambiance")
	sfx.call("set_volume", "Ambiance", v0)
	var n_sl := ss.sliders.size()
	ss.close()
	await _wait(2)
	check(n_sl == 2 and is_equal_approx(v1, 0.35), "D-UI 4 : Réglages — volumes Sons et Ambiance (Ambiance 35 %% → %s)" % str(v1))
	# Heures sup et campagne visibles dans le monde (D-Monde) : set_overtime / set_campaign appelés
	# (lot E : contrôle rendu réel — les Heures sup sont révélées et une campagne est vraiment lancée ; avant, une propriété
	# absente ou aucune campagne disponible le faisait passer)
	s.features["boost"] = s.time
	s.boost_ready_at = s.time - 1.0
	s.boost_until = s.time - 1.0
	hud._on_boost()
	hud._refresh(s)
	var ot: Variant = hud.diorama.get("overtime_on")
	var camp_ok := false
	var camp_id := ""
	s.features["commerce"] = s.time
	for c in Commerce.campaigns(s):
		if Commerce.campaign_available(s, c) and not Commerce.campaign_active(s, String(c.id)):
			camp_id = String(c.id)
			s.campaign_ready_at.erase(camp_id)
			s.money = maxf(s.money, Commerce.campaign_cost(s, camp_id) + 1.0)
			var started: bool = Commerce.start_campaign(s, camp_id)
			hud._refresh(s)
			var co: Variant = hud.diorama.get("campaign_on")
			camp_ok = started and co != null and bool(co)
			break
	check(ot != null and bool(ot) and camp_ok, "D-UI 4 : Heures sup et campagne envoyées au monde (heures sup %s, campagne « %s » %s)" % [str(ot), camp_id, str(hud.diorama.get("campaign_on"))])


## Ouvertures de zone en attente (le passage au T3 en a mis en file) : jouées et passées, pour que le HUD soit à l'écran.
func _dui_skip_openings(hud: Hud) -> void:
	var dio := hud.diorama
	for _i in 40:
		if dio.opening_active():
			dio.opening.t = Layout.OPENING_SKIP_AFTER + 0.1
			dio.skip_opening()
		elif dio.opening_queue.is_empty():
			break
		await _wait(2)
	hud._sync_opening(1.0)
	await _wait(2)


## Lot D — Monde : interface fournie à l'UI (retour d'achat, Heures sup, campagne, ancrages, encaissement par navire),
## foule de dockers liée aux agents, conteneurs posés.
func _d_monde_checks(hud: Hud, s: PortSim) -> void:
	var dio := hud.diorama
	var api := dio.has_method("feedback_purchase") and dio.has_method("set_overtime") and dio.has_method("set_campaign") \
		and dio.has_method("dept_anchor") and dio.has_method("rade_anchor") and dio.has_signal("ship_paid")
	var fb0 := dio.purchase_feedbacks
	dio.feedback_purchase("cranes")
	dio.feedback_purchase("inconnu")          # sans effet, sans erreur
	var anchors_ok := dio.dept_anchor("harbor").is_equal_approx(Layout.dept_pos("harbor", s.tier)) \
		and not Layout.on_land(Vector2(dio.rade_anchor().x, dio.rade_anchor().z), true) and dio.rade_anchor().y > 0.0
	check(api and dio.purchase_feedbacks == fb0 + 1 and anchors_ok,
		"D-Monde : interface fournie à l'UI (feedback_purchase, set_overtime, set_campaign, dept_anchor, rade_anchor, ship_paid)")
	# Heures sup : un gyrophare par grue et par engin, lumière plus chaude ; retour à la normale ensuite
	var was_ot := dio.overtime_on
	var was_camp := dio.campaign_on
	var sun0 := dio._sun_base
	dio.set_overtime(true)
	await get_tree().create_timer(1.2).timeout
	var beacons := 0
	for b in dio._beacons:
		if is_instance_valid(b):
			beacons += 1
	var veh_b := 0
	for v in dio.traffic.vehicles:
		var vn: Node3D = v.node
		if is_instance_valid(vn) and vn.has_node("beacon") and (vn.get_node("beacon") as Node3D).visible:
			veh_b += 1
	var warm := dio.sun.light_color.b < sun0.b - 0.01
	dio.set_overtime(false)
	await get_tree().create_timer(1.6).timeout
	var back := dio._beacons.is_empty() and absf(dio.sun.light_color.b - sun0.b) < 0.005
	check(beacons == dio.crane_views.size() and beacons > 0 and veh_b == dio.traffic.vehicles.size() and warm and back,
		"D-Monde : Heures sup visibles — %d gyrophares sur les grues, %d sur les engins, lumière plus chaude (%s), retour à la normale (%s)" % [beacons, veh_b, warm, back])
	dio.set_campaign(true)
	await _wait(2)
	var flags := dio.flags_shown
	dio.set_campaign(false)
	await _wait(2)
	check(flags >= 10 and dio.flags_shown == 0, "D-Monde : campagne — %d fanions sur la capitainerie, retirés à la fin" % flags)
	dio.set_overtime(was_ot)
	dio.set_campaign(was_camp)
	# encaissement par navire : signal ship_paid au départ du poste, montant estimé > 0, au-dessus du navire
	var got: Array = []
	var cb := func(p: Vector3, amount: float) -> void: got.append([p, amount])
	dio.ship_paid.connect(cb)
	var sh := _fake_ship(s, 99001, Ship.State.UNLOADING, 0, 0, 0.0)
	dio._ship_cargo0[sh.id] = sh.left.duplicate()
	sh.left[0] = 0.0
	sh.state = Ship.State.DEPARTING
	# (lot F1, recalé) si un navire est à quai ou en route vers le poste à l'écran, le montant attend son départ (pay_out)
	var bv0 := dio.berth_view(0)
	dio._on_ship_state(sh)
	if bv0 != null and got.is_empty():
		dio.pay_out(0, bv0.position)
	dio.ship_paid.disconnect(cb)
	check(got.size() == 1 and float(got[0][1]) > 0.0 and (got[0][0] as Vector3).y > 2.0,
		"D-Monde : ship_paid au départ du poste (%s)" % (Fmt.money(float(got[0][1])) if got.size() == 1 else "rien"))
	# foule : dockers sur le tablier et sur le pont pendant le déchargement, en nombre lié aux agents (plafonné)
	if not s.ships.is_empty():
		var sh0: Ship = s.ships[0]
		var st0 := sh0.state
		var b0 := sh0.berth
		var bs0 := int(s.berths[0].ship)
		sh0.state = Ship.State.UNLOADING
		sh0.berth = 0
		s.berths[0].ship = sh0.id
		# (lot F1, recalé) la foule entoure le navire à quai à l'écran : un navire posé au poste 1, en plein déchargement
		var mv0 := ShipView.new()
		dio.ships_root.add_child(mv0)
		mv0.setup(_fake_ship(s, 99002, Ship.State.UNLOADING, 0, 0, 0.0), s)
		mv0.moor_now(0, 0.3)
		dio.fleet.push_front(mv0)
		var lv0: int = s.levels.berths
		var lc0: int = s.levels.cranes
		s.levels.berths = 1
		s.levels.cranes = 1
		dio._refresh_crowd()
		var n_low := dio.crowd.size()
		var deck_low := dio.crowd.filter(func(c: Dictionary) -> bool: return String(c.kind) == "deck").size()
		s.levels.berths = 400
		s.levels.cranes = 400
		dio._refresh_crowd()
		var n_high := dio.crowd.size()
		await _wait(3)
		var shown := dio.crowd_mm.multimesh.visible_instance_count if dio.crowd_mm != null else -1
		s.levels.berths = lv0
		s.levels.cranes = lc0
		sh0.state = st0
		sh0.berth = b0
		s.berths[0].ship = bs0
		dio.fleet.erase(mv0)
		mv0.queue_free()
		check(deck_low >= 1 and n_high > n_low and n_high <= Diorama.CROWD_MAX and shown > 0 and shown <= Diorama.CROWD_MAX,
			"D-Monde : dockers au déchargement — %d puis %d avec plus d'agents (plafond %d), dont %d sur le pont, %d affichés" % [n_low, n_high, Diorama.CROWD_MAX, deck_low, shown])
	# conteneurs posés : un conteneur qui arrive sur le tablier descend à sa place au lieu d'apparaître d'un coup
	# (lot F1, recalé) tablier ramené à 20 % d'abord : plein (la partie du test tourne en temps réel), aucun conteneur de plus ne
	# pouvait s'y poser
	for ci in s.apron.size():
		s.apron[ci] = 0.0
	s.apron[0] = s.apron_capacity() * 0.2
	await _wait(2)
	var d0 := dio.yard.drops_started
	s.apron[0] = s.apron[0] + maxf(20.0, s.apron_capacity() * 0.3)
	await get_tree().create_timer(0.3).timeout
	check(dio.yard.drops_started > d0, "D-Monde : conteneurs posés (%d poses animées)" % (dio.yard.drops_started - d0))
	# gestes : le signal gesture_done porte le nombre d'EVP déplacés ; l'UI s'en sert pour le montant en $
	var g_args := 0
	for sg in dio.get_signal_list():
		if String(sg.name) == "gesture_done":
			g_args = (sg.args as Array).size()
	check(g_args == 3 and Hud.gesture_text("Rangé ! +12 EVP", 12.0) == Hud.gesture_text("Rangé ! +12 EVP")
		and Hud.gesture_text("Rangé ! +12 EVP", 24.0) != Hud.gesture_text("Rangé ! +12 EVP"),
		"D-Monde : gesture_done porte les EVP (%d paramètres), le montant en $ vient du paramètre" % g_args)


## Lot E — Confiance : toucher de fermeture d'une feuille (E5), bandeaux sous une feuille et caméra rendue (E6), Améliorer
## et carte Goulot sur une vraie partie de bot du T3 (E1, E2), aléa pendant la feuille (E3), cérémonie qui montre, pièces,
## cibles ≥ 96 px, volume enregistré au relâchement, rafale d'achats.
func _e_confiance_checks(hud: Hud, s: PortSim) -> void:
	var gs: Node = get_tree().root.get_node("GameState")
	var dio := hud.diorama
	var rg := dio.rig
	await _dui_skip_openings(hud)
	hud._finish_ceremony()
	for p in hud.popup_layer.get_children():
		p.queue_free()
	for c in hud.sheet_layer.get_children():
		c.queue_free()
	hud.tutorial.active = false
	hud._banner_queue.clear()
	if hud._banner != null and is_instance_valid(hud._banner):
		hud._banner.queue_free()
	hud._banner = null
	s.active_event = {}
	await _wait(3)
	var vs := hud.get_viewport_rect().size
	# --- E5 : un toucher sur le port referme la feuille ; son relâchement n'atteint jamais le monde -------------------------
	var tp := Vector2(vs.x * 0.5, vs.y * 0.3)
	var ev_p := InputEventMouseButton.new()
	ev_p.button_index = MOUSE_BUTTON_LEFT
	ev_p.pressed = true
	ev_p.position = tp
	ev_p.global_position = tp
	var ev_r := ev_p.duplicate() as InputEventMouseButton
	ev_r.pressed = false
	rg.input_enabled = true
	# un toucher du monde au même endroit (c'est lui qui ouvrait le service : `_press_pos` restait là)
	get_viewport().push_input(ev_p, true)
	get_viewport().push_input(ev_r, true)
	await _wait(2)
	for p in hud.popup_layer.get_children():
		p.queue_free()
	hud.overlay.zone_info = {}
	if not hud.any_sheet_open():
		hud.open_upgrades("cranes")
	await _wait(3)
	var taps := [0]
	var on_tap := func(_w: Vector3, _p: Vector2) -> void: taps[0] += 1
	rg.tapped.connect(on_tap)
	var pops0 := _npop(hud)
	get_viewport().push_input(ev_p, true)       # appui au-dessus de la feuille : elle se ferme
	await _wait(2)
	var closed := not hud.any_sheet_open()
	get_viewport().push_input(ev_r, true)       # relâchement : rien dans le monde
	await _wait(3)
	rg.tapped.disconnect(on_tap)
	check(closed and taps[0] == 0 and not hud.any_sheet_open() and _npop(hud) == pops0,
		"E5 : toucher le port au-dessus d'Améliorer la referme ; le relâchement n'atteint pas le monde (touchers du monde %d, réouverture %s, fenêtres %d → %d)" % [taps[0], hud.any_sheet_open(), pops0, _npop(hud)])
	for c in hud.sheet_layer.get_children():
		c.queue_free()
	await _wait(2)
	# --- E6 : bandeaux sous une feuille, minuterie suspendue, VOIR avant le suivant, caméra rendue au joueur ----------------
	hud.open_upgrades("")
	await _wait(3)
	# (la partie tourne pendant le test : un bandeau du jeu peut s'intercaler — on ne regarde que les nôtres)
	hud._banner_queue.clear()
	if hud._banner != null and is_instance_valid(hud._banner):
		hud._banner.queue_free()
	hud._banner = null
	hud._queue_banner("E6 un", "", "info", UI.VIOLET)
	hud._queue_banner("E6 deux", "", "info", UI.VIOLET)
	await _wait(2)
	var none_under := hud._banner == null
	hud.current_sheet().close()
	await _wait(3)
	var first_shown := hud._banner != null and hud._banner.visible
	hud.open_upgrades("")
	await _wait(3)
	var btw: Variant = hud._banner.get_meta("tween", null) if hud._banner != null else null
	var paused := hud._banner != null and not hud._banner.visible and btw is Tween and not (btw as Tween).is_running()
	hud._close_banner(hud._banner)
	var no_chain := hud._banner == null and hud._banner_queue.any(func(b: Dictionary) -> bool: return String(b.title) == "E6 deux")
	hud._banner_queue.assign(hud._banner_queue.filter(func(b: Dictionary) -> bool: return String(b.title) == "E6 deux"))
	hud.current_sheet().close()
	await _wait(3)
	var second := hud._banner != null and hud._banner.visible
	check(none_under and first_shown and paused and no_chain and second,
		"E6 : bandeaux — aucun sous une feuille (%s), minuterie suspendue quand il est masqué (%s), fermé sous la feuille sans enchaîner (%s), le suivant au retour (%s)" % [none_under, paused, no_chain, second])
	if hud._banner != null and is_instance_valid(hud._banner):
		hud._banner.queue_free()
	hud._banner = null
	hud._banner_queue.clear()
	hud._queue_banner("Nouveau : Responsables", "", "people", UI.VIOLET, Vector3.INF, false, "managers")
	hud._queue_banner("E6 suivant", "", "info", UI.VIOLET, Layout.anchor_pos(0))
	await _wait(2)
	var goal_v := rg.goal
	if hud.banner_voir != null:
		hud.banner_voir.pressed.emit()
	await _wait(2)
	var voir_ok := hud.current_sheet() is ManageSheet and hud._banner == null and hud._banner_queue.any(func(b: Dictionary) -> bool: return String(b.title) == "E6 suivant") and rg.goal.distance_to(goal_v) < 0.5
	if hud.current_sheet() != null:
		hud.current_sheet().close()
	await _wait(2)
	hud._banner_queue.clear()
	if hud._banner != null and is_instance_valid(hud._banner):
		hud._banner.queue_free()
	hud._banner = null
	# Améliorer ouvert d'un toucher sur un poste (le monde vise le poste avant d'ouvrir) : la caméra revient à la vue du joueur
	var player := Vector3(-12, 0, 18)
	rg.focus(player)
	rg.target = rg.goal
	rg._apply()
	rg.focus(Layout.dept_pos("cranes", s.tier))        # comme Diorama._on_tapped (« dept »)
	dio.place_tapped.emit("cranes")
	await _wait(3)
	if hud.current_sheet() != null:
		hud.current_sheet().close()
	await _wait(3)
	var back1 := rg.goal.distance_to(player) < 0.5
	# pendant le regard de 2 s d'un chapitre (`view_home`) : la vue d'avant
	rg.focus(player)
	rg.target = rg.goal
	dio.view_home = player
	rg.focus(Vector3(30, 0, 30))
	rg.target = rg.goal
	hud.open_upgrades("")
	await _wait(3)
	if hud.current_sheet() != null:
		hud.current_sheet().close()
	await _wait(3)
	var back2 := rg.goal.distance_to(player) < 0.5
	dio.view_home = Vector3.INF
	check(voir_ok and back1 and back2, "E6 : VOIR ouvre l'écran avant le bandeau suivant (%s) ; caméra rendue au joueur après Améliorer ouvert depuis le monde (%s) et pendant un regard de chapitre (%s)" % [voir_ok, back1, back2])
	# --- E1 / E2 / E3 sur une vraie partie de bot du T3 (goulot « postes à quai ») ----------------------------------------
	var saved := s.to_dict()
	var fx: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/bot_t3.json"))
	s.from_dict(fx.sim)
	for i in 40:          # 10 s de jeu (comme run_all) : la rade pleine depuis 3 s désigne le maillon suivant
		s.step(0.25)
	gs.emit_signal("sim_replaced", s)
	s._refresh_analysis()
	hud._aff_t = -10.0
	hud._refresh(s)
	var key := String(s.shown_analysis().get("key", ""))
	var hb := hud.hint_btn.text
	var badge := hud._aff_n
	var worth := Hud.worthwhile_count(s)
	check(key == "berth_count" and not hb.contains("GNL") and hb == String(Hud.hint_action(s).label) and badge == worth and hud.upgrade_badge.visible == (badge > 0),
		"E1/E2 : partie de bot au T3 — « %s » → « %s » (jamais le GNL) ; pastille %d = bons achats %d" % [hud.hint_title.text, hb, badge, worth])
	await _wait(2)
	await _dui_skip_openings(hud)
	hud._finish_ceremony()
	for p in hud.popup_layer.get_children():
		p.queue_free()
	UpgradesSheet.mult_index = 0
	s.money = 4.0e8
	hud.open_upgrades("")
	await _wait(4)
	var up := hud.current_sheet() as UpgradesSheet
	up._gain_at = 0
	up.refresh()
	var green_bad: Array[String] = []
	var fee_only := 0
	var best_bad := false
	for c in up.cards:
		if not c.has("dept"):
			continue
		var d := String(c.dept)
		var cost := s.dept_cost(d, 1)
		var parts := s.upgrade_gain_parts(d, 1)
		var col := (c.pay as Label).get_theme_color("font_color")
		var txt := (c.pay as Label).text
		if col == UI.MONEY and not UpgradesSheet.is_good(parts, cost):
			green_bad.append("%s « %s »" % [d, txt])
		if txt.contains("pas le goulot (+"):
			fee_only += 1
		if (c.best as Label).visible and not UpgradesSheet.is_good(parts, cost):
			best_bad = true
	check(green_bad.is_empty() and fee_only >= 1 and not best_bad,
		"E1 : Améliorer au T3 — aucun « rentabilisé » en vert au-delà de 10 min (%s) ; %d carte(s) « pas le goulot (+… de services) » en gris ; ★ seulement sur un bon achat" % [str(green_bad), fee_only])
	# E3 : vent fort pendant la feuille — aléa visible en pastille, Portiques « Suspendu », jamais le meilleur achat ; coût
	# plafonné à 25 % de la trésorerie
	Hazards.start(s, "wind")
	hud._refresh(s)
	up._gain_at = 0
	up.refresh()
	await _wait(2)
	var cc := up._card_for("dept", "cranes")
	var eff_txt := (cc.eff as Label).text if not cc.is_empty() else "?"
	var pill_ok := hud.ev_pill.visible and hud.ev_pill.get_global_rect().end.y < vs.y * Sheet.HALF_TOP and hud.ev_pill_l.text.begins_with(String(s.active_event.name))
	var cost_ok := float(s.active_event.get("pay_cost", INF)) <= 0.25 * s.money + 0.01
	check(pill_ok and eff_txt.begins_with("Suspendu (vent fort)") and not (cc.best as Label).visible and up.best_dept != "cranes" and cost_ok,
		"E3 : aléa pendant la feuille — pastille « %s », Portiques « %s », pas le meilleur achat, « Sécuriser » %s (≤ 25 %% de %s)" % [hud.ev_pill_l.text, eff_txt, Fmt.money(float(s.active_event.get("pay_cost", 0.0))), Fmt.money(s.money)])
	Hazards.end_event(s)
	# rafale : `_burst_n` repart de zéro à chaque rafale
	up._burst_n = 7
	var hr: HoldRepeat = null
	for ch in (up._card_for("dept", "gate").buy as Node).get_children():
		if ch is HoldRepeat:
			hr = ch
	s.money = 1.0e12
	if hr != null:
		hr.repeat.call(1)
	var burst_ok := hr != null and up._burst_n == 1
	# cibles ≥ 96 px : onglets des feuilles, barre de palier, « POURQUOI ? », « BÂTIMENTS »
	var small: Array[String] = []
	for b in up.tab_buttons:
		if b.size.y < 95.5:
			small.append("onglet %d" % int(b.size.y))
	var fr := up.show_stages(s.db.dept_by_id["gate"], "gate", -1)
	await _wait(2)
	for b in fr.find_children("*", "Button", true, false):
		if (b as Button).text == "POURQUOI ?" and (b as Control).size.y < 95.5:
			small.append("POURQUOI ? %d" % int((b as Control).size.y))
	fr.queue_free()
	up.close()
	await _wait(2)
	hud._refresh(s)
	await _wait(1)
	if hud.prog_btn.is_visible_in_tree() and (hud.prog_btn.size.y < 95.5 or hud.prog_btn.size.x < 95.5):
		small.append("barre de palier %dx%d" % [int(hud.prog_btn.size.x), int(hud.prog_btn.size.y)])
	s.features["commerce"] = s.time
	hud.open_sheet(CommerceSheet.new(CommerceSheet.TAB_TRAFFIC))
	await _wait(3)
	var cs := hud.current_sheet()
	var bat := 0
	for b in cs.find_children("*", "Button", true, false):
		if (b as Button).text == "BÂTIMENTS":
			bat += 1
			if (b as Control).size.y < 95.5:
				small.append("BÂTIMENTS %d" % int((b as Control).size.y))
	cs.close()
	await _wait(2)
	check(burst_ok and small.is_empty() and bat == 1 and hud.prog_btn.is_visible_in_tree(),
		"mineurs : rafale repartie de zéro (%s) ; cibles ≥ 96 px — onglets, barre de palier, POURQUOI ?, BÂTIMENTS (trop petites : %s)" % [burst_ok, str(small)])
	# cérémonie : sous les fenêtres, ce qui s'ouvre (icônes), VOIR qui cadre ; bulles masquées sous la fenêtre
	hud._on_tier(3)
	await _wait(2)
	var cer := hud._ceremony
	var under := cer != null and cer.z_index == 0 and cer.get_index() < hud.popup_layer.get_index()
	hud._finish_ceremony()
	await _wait(3)
	var opens: Array = s.db.tier_def(3).get("opens", [])
	var no_bubbles := not hud.overlay.visible and _npop(hud) >= 1
	var view := Hud.tier_view(s, 3)
	var voir := hud.tier_voir
	var has_voir := voir != null and is_instance_valid(voir)
	if has_voir:
		voir.pressed.emit()
	await _wait(2)
	var framed := not view.is_empty() and rg.goal.distance_to(Vector3(view.p.x, 0, view.p.z)) < 0.5 and _npop(hud) == 0
	check(under and opens.size() >= 2 and has_voir and no_bubbles and framed,
		"cérémonie : couche sous les fenêtres (%s), %d choses qui s'ouvrent au T3, bulles masquées sous la fenêtre (%s), VOIR cadre la zone (%s)" % [under, opens.size(), no_bubbles, framed])
	for p in hud.popup_layer.get_children():
		p.queue_free()
	await _wait(2)
	# pièces d'encaissement : vraies pièces de 64 px, nées au-dessus du montant et après 0,6 s
	var paid_at := Vector3(Layout.berth_center(0), 8.0, Layout.QUAY_Z)
	rg.focus(paid_at)
	rg.target = rg.goal
	rg._apply()
	await _wait(1)
	var from := dio.to_screen(paid_at)
	if dio.has_signal("ship_paid"):
		dio.emit_signal("ship_paid", paid_at, 5000.0)
	await _wait(1)
	var coins_n := 0
	var coins_ok := true
	for c in hud.popup_layer.get_children():
		if c is TextureRect and (c as Node).has_meta("coin"):
			coins_n += 1
			var tr := c as TextureRect
			coins_ok = coins_ok and tr.size.x >= 63.0 and tr.get_global_rect().end.y < from.y - 60.0 and tr.modulate.a < 0.01
	check(coins_n > 0 and coins_ok and Hud.COIN_DELAY >= 0.6, "encaissement : %d pièces de 64 px, au-dessus du « +X $ », parties après %s s" % [coins_n, Fmt.num(Hud.COIN_DELAY)])
	# volume : appliqué à chaque cran, enregistré au relâchement seulement (jamais dans le fichier du joueur pendant le test)
	var sfx: Node = get_tree().root.get_node("Sfx")
	hud.open_sheet(SettingsSheet.new())
	await _wait(3)
	var ss := hud.current_sheet() as SettingsSheet
	var v0: float = sfx.call("get_volume", "Sons")
	var n0: int = sfx.get("saves")
	var sl := ss.sliders["Sons"] as HSlider
	sl.value = 40.0
	sl.value = 45.0
	sl.value = 50.0
	var during: int = int(sfx.get("saves")) - n0
	sl.drag_ended.emit(true)
	var after_rel: int = int(sfx.get("saves")) - n0
	sl.value = v0 * 100.0
	ss.close()
	await _wait(2)
	check(during == 0 and after_rel == 1 and not bool(sfx.get("persist")), "mineurs : volume enregistré au relâchement de la réglette (%d enregistrement pendant le glissé, %d au relâchement), rien d'écrit pendant le test" % [during, after_rel])
	# barre de palier → onglet Port : la Réputation n'est pas citée avant sa révélation
	var had_stars := s.features.has("stars")
	var st_t: Variant = s.features.get("stars", null)
	s.features.erase("stars")
	hud.open_sheet(ManageSheet.new(3))
	await _wait(3)
	var cited_before := false
	var sat_line := false
	for l in hud.current_sheet().find_children("*", "Label", true, false):
		cited_before = cited_before or (l as Label).text.contains("Réputation")
		sat_line = sat_line or (l as Label).text.begins_with("Navires satisfaits")
	hud.current_sheet().close()
	await _wait(2)
	if had_stars:
		s.features["stars"] = st_t
	check(not cited_before and sat_line, "mineurs : palier suivant — pas de « Réputation » avant sa révélation (« Navires satisfaits » : %s)" % sat_line)
	# la partie du test reprend son cours
	s.from_dict(saved)
	gs.emit_signal("sim_replaced", s)
	await _wait(3)
	hud._finish_ceremony()
	for p in hud.popup_layer.get_children():
		p.queue_free()
	await _wait(2)

# ---------------------------------------------------------------------------
# Lot E-Flux (docs/ORDRE_E_FLUX.md) : camions, gare, capitainerie, mineurs du monde (les contrôles sans scène sont dans
# run_all, `test_e_flux`)
# ---------------------------------------------------------------------------

func _e_flux_checks(hud: Hud) -> void:
	var gs: Node = get_tree().root.get_node("GameState")
	var s: PortSim = gs.get("sim")
	var dio := hud.diorama
	DebugArgs.apply({"tier": "3", "build-all": "", "levels": "83", "hire-all": ""}, s, s.db, true)
	await _wait(4)
	dio.skip_opening()
	# E7 : un camion qui se range devant son bloc, attend son conteneur et repart : il ne tourne presque pas à l'arrêt
	var tv := TrafficView.new()
	add_child(tv)
	tv._tier = 3
	var tn := Node3D.new()
	tv.add_child(tn)
	var r_in := Layout.truck_route_in(Layout.road_in_x(false), -12.0)
	tn.position = r_in[0]
	tn.rotation.y = deg_to_rad(TrafficView.HEAD_NORTH)
	tv.trucks = [{"node": tn, "route": r_in.slice(1), "phase": "in", "stop_x": -12.0, "t": 0.0, "container": null, "loader": -1}]
	var pivot := 0.0
	var phases := {}
	var prev_p := tn.position
	var prev_y := tn.rotation.y
	for i in 260:
		if tv.trucks.is_empty():
			break
		phases[String(tv.trucks[0].phase)] = true
		tv._sync_trucks(s, 0.05)
		if not is_instance_valid(tn):
			break
		if tn.position.distance_to(prev_p) < 0.02:
			pivot += absf(angle_difference(prev_y, tn.rotation.y))
		prev_p = tn.position
		prev_y = tn.rotation.y
	check(phases.has("wait") and phases.has("loading") and phases.has("out") and rad_to_deg(pivot) < 30.0,
		"E-Flux E7 : camion au chargement — %.1f° de rotation à l'arrêt (arrivée, attente face à l'ouest, départ), phases %s" % [rad_to_deg(pivot), str(phases.keys())])
	tv.queue_free()
	# E8 : passages de demi-tour dessinés sur la voie des camions au T3
	check(dio.crossovers_shown == Layout.crossover_xs(s.tier).size() and dio.crossovers_shown == 2,
		"E-Flux E8 : %d passages de demi-tour dessinés au T%d (x %s)" % [dio.crossovers_shown, s.tier, str(Layout.crossover_xs(s.tier))])
	# E11 : au T2 et au-delà, la maison bleue et la tour ouvrent la Capitainerie ; retour d'achat sur les deux ; pavillons de
	# campagne sur la tour (bâtiment actif)
	var p_off := dio.pick_tap(Layout.HARBOR_OFFICE)
	var p_tow := dio.pick_tap(Layout.CONTROL_TOWER)
	dio.feedback_purchase("harbor")
	var fb := dio.feedback_points.size()
	var camp0 := dio.campaign_on
	dio.set_campaign(true)
	var at := dio.campaign_at
	dio.set_campaign(camp0)
	check(String(p_off.get("kind", "")) == "dept" and String(p_off.get("id", "")) == "harbor" and String(p_tow.get("kind", "")) == "dept"
		and String(p_tow.get("id", "")) == "harbor" and fb == 2 and Vector2(at.x, at.z).distance_to(Vector2(Layout.CONTROL_TOWER.x, Layout.CONTROL_TOWER.z)) < 0.1,
		"E-Flux E11 : capitainerie au T%d — maison bleue %s, tour %s ; retour d'achat sur %d bâtiments ; pavillons sur la tour (%s)" % [
		s.tier, str(p_off.get("id", "")), str(p_tow.get("id", "")), fb, str(at)])
	# E12 : gare vivante — le train entre par le tunnel, s'arrête au quai (visible, gare à l'écran ou non) ; la navette du
	# tracteur attend au passage à niveau tant qu'un camion en approche, puis porte un conteneur du parc à la gare
	var tv2 := TrafficView.new()
	add_child(tv2)
	tv2.on_screen = func(_p: Vector3) -> bool: return true
	var block := Node3D.new()
	tv2.add_child(block)
	block.position = Vector3(float(Layout.RAIL_SHUTTLE.x) + 2.0, 0, Layout.LOAD_STOP_Z)
	tv2.trucks = [{"node": block, "route": [], "phase": "wait", "stop_x": block.position.x, "t": 0.0, "container": null, "loader": -1}]
	var seen_quay := false
	var in_band_blocked := 0
	var crossed := false
	var max_x := -INF
	for i in 420:
		if i == 170:
			tv2.trucks.clear()          # le camion repart : le passage se libère
			block.queue_free()
		tv2._sync_train(s, 0.1)
		tv2._sync_shuttle(s, 0.1)
		if tv2.train_at_quay() and tv2.train.visible and absf(tv2.train.position.x - TrafficView.train_x_stop()) < 0.01:
			seen_quay = true
		if tv2.train != null and tv2.train.visible:
			max_x = maxf(max_x, tv2.train.position.x)
		if tv2.tractor != null:
			var tp := tv2.tractor.position
			var in_band := tp.z > float(Layout.LANE_BAND[0]) - 2.5 and tp.z < float(Layout.LANE_BAND[1]) + 2.5
			if in_band and not tv2.trucks.is_empty():
				in_band_blocked += 1
			if in_band and tv2.trucks.is_empty():
				crossed = true
	var clip_ok := tv2._clip_mat != null and is_equal_approx(float(tv2._clip_mat.get_shader_parameter("clip_x")), Layout.RAIL_TUNNEL_X)
	check(seen_quay and tv2.trains_run >= 1 and clip_ok and max_x <= TrafficView.train_x_hidden() and tv2.shuttle_waits >= 1
		and in_band_blocked == 0 and crossed and tv2.shuttles_done >= 1,
		"E-Flux E12 : train à quai et visible (%s), coupé à la bouche du tunnel (x %s) ; navette : %d attente(s) au passage à niveau, jamais sur la voie avec un camion (%d), %d conteneur(s) déposé(s) à la gare" % [
		seen_quay, Fmt.num(Layout.RAIL_TUNNEL_X), tv2.shuttle_waits, in_band_blocked, tv2.shuttles_done])
	tv2.queue_free()
	# mineurs : cargaison relevée oubliée au départ d'un navire (même furieux) ; douaniers jamais tronqués par CROWD_MAX ; bulle
	# de rade sur une place occupée ; gyrophares bleus ; toit du bureau de pilotage
	var sh := _fake_ship(s, 99777, Ship.State.LEAVING, 0, -1, 0.0)
	dio._ship_cargo0[sh.id] = sh.left.duplicate()
	dio._on_ship_removed(sh)
	var lv := [s.levels.berths, s.levels.cranes]
	s.levels.berths = 400
	s.levels.cranes = 400
	var plan := dio.crowd_plan()
	s.levels.berths = lv[0]
	s.levels.cranes = lv[1]
	var customs := plan.filter(func(c: Dictionary) -> bool: return String(c.kind) == "customs").size()
	var dockers := plan.size() - customs
	var ra := dio.rade_anchor()
	var ra_ok := true
	var any_anch := false
	for shp in s.ships:
		if shp.state == Ship.State.ANCHORED and shp.anchor_slot >= 0:
			any_anch = true
	if any_anch:
		ra_ok = false
		for shp in s.ships:
			if shp.state == Ship.State.ANCHORED and shp.anchor_slot >= 0 and Vector2(ra.x, ra.z).distance_to(Vector2(Layout.anchor_pos(shp.anchor_slot).x, Layout.anchor_pos(shp.anchor_slot).z)) < 0.01:
				ra_ok = true
	var bc: Color = (Diorama.beacon_parts()[1] as StandardMaterial3D).albedo_color
	var roofs := 0
	for c in dio.static_root.get_children():
		for g in (c as Node).get_children():
			if (g as Node).has_meta("roof"):
				roofs += 1
	check(not dio._ship_cargo0.has(99777) and customs == clampi(s.agents("customs"), 1, Diorama.CROWD_CUSTOMS) and dockers <= Diorama.CROWD_MAX
		and ra_ok and bc.b > bc.r and roofs >= 1,
		"E-Flux mineurs : cargaison oubliée au départ (%s), %d douaniers réservés (%d dockers, plafond %d), bulle de rade sur une place (%s), gyrophares bleus, %d toit(s)" % [
		not dio._ship_cargo0.has(99777), customs, dockers, Diorama.CROWD_MAX, ra_ok, roofs])


# ---------------------------------------------------------------------------
# Lot F1 — navires à l'écran
# ---------------------------------------------------------------------------

## Un voyage complet d'une vue (mouillage → poste → départ hors champ), image par image (0,1 s), seule sur l'eau : mesures.
func _f1_voyage(dio: Diorama, s: PortSim, cls: String, slot: int, bi: int, id: int) -> Dictionary:
	var sh := _fake_ship(s, id, Ship.State.ANCHORED, slot, bi, 0.0)
	sh.cls = cls
	var v := ShipView.new()
	dio.ships_root.add_child(v)
	v.setup(sh, s)
	v.place(sh, s)
	v.dispatch(bi)
	v.gate_level = 2
	var dt := 0.1
	var cruise := v.cruise_speed()
	var by := Layout.berth_yaw(bi)
	var reclaim := bi >= Layout.EAST_BERTH0
	var r := {"ratio": 0.0, "steady": 0.0, "steady_n": 0, "pivot": 0.0, "crab_yaw0": -1.0, "crab_lat": 1.0, "last8": 0.0,
		"tug_man": 0, "man": 0, "bow": 0, "tug_sea": 0, "crab": 0, "out_lat": 1.0, "out_dyaw": 0.0, "land": 0, "t_in": 0.0, "t": 0.0,
		"done": false, "yaw_rate": 0.0}
	var crab_pts: Array = []
	for i in 9000:
		var ph := v.phase
		if ph == ShipView.Phase.MOORED:
			r.t_in = r.t
			v.depart()
			continue
		var p0 := v.position
		var y0 := v.yaw()
		v.step(dt)
		r.t = float(r.t) + dt
		var dp := Vector2(v.position.x - p0.x, v.position.z - p0.z)
		r.ratio = maxf(float(r.ratio), dp.length() / dt / cruise)
		var dy := absf(angle_difference(y0, v.yaw()))
		# en régime : à la vitesse de croisière, en ligne droite (dans un virage, la coque coupe la courbe)
		if ph == ShipView.Phase.INBOUND and v.speed() >= cruise * 0.999 and dy < 0.002:
			r.steady = float(r.steady) + dp.length() / dt
			r.steady_n = int(r.steady_n) + 1
		if v.speed() < 0.05 and ph != ShipView.Phase.ANCHOR:
			r.pivot = float(r.pivot) + dy          # rotation navire arrêté (pivot sur place)
		var fw0 := Vector2(cos(y0), -sin(y0)) * v.length * 0.5
		var fw1 := Vector2(cos(v.yaw()), -sin(v.yaw())) * v.length * 0.5
		if v.in_maneuver() and (Vector2(v.position.x, v.position.z) + fw1).distance_to(Vector2(p0.x, p0.z) + fw0) >= 0.3 * v.maneuver_speed() * dt:
			r.bow = int(r.bow) + 1
		var side := Vector2(sin(v.yaw()), cos(v.yaw()))
		if ph == ShipView.Phase.CRAB_IN:
			if float(r.crab_yaw0) < 0.0:
				r.crab_yaw0 = absf(angle_difference(y0, by))
			crab_pts.append([v.position, v.yaw()])
			if dp.length() > 0.03:
				r.crab_lat = minf(float(r.crab_lat), absf(dp.normalized().dot(side)))
			r.crab = int(r.crab) + 1
			if v.tug != null and v.tug.position.z < v.position.z - v.width * 0.5:
				r.tug_sea = int(r.tug_sea) + 1
		if v.in_maneuver():
			r.man = int(r.man) + 1
			if v.tug_attached() and v.tug.position.distance_to(v.position) < v.length * 0.5 + v.width + 4.0:
				r.tug_man = int(r.tug_man) + 1
		if ph == ShipView.Phase.CRAB_OUT:
			if dp.length() > 0.03:
				r.out_lat = minf(float(r.out_lat), absf(dp.normalized().dot(side)))
			r.out_dyaw = maxf(float(r.out_dyaw), absf(angle_difference(v.yaw(), by)))
		if Layout.on_land(Vector2(v.position.x, v.position.z), reclaim):
			r.land = int(r.land) + 1
		if v.phase == ShipView.Phase.DONE:
			r.done = true
			break
	# cap sur les 8 derniers mètres avant le poste
	var acc := 0.0
	for k in range(crab_pts.size() - 1, 0, -1):
		acc += (crab_pts[k][0] as Vector3).distance_to(crab_pts[k - 1][0])
		if acc > 8.0:
			break
		r.last8 = maxf(float(r.last8), absf(angle_difference(float(crab_pts[k][1]), by)))
	r.yaw_rate = v.max_yaw_rate_seen
	r.steady = float(r.steady) / maxf(1.0, float(r.steady_n))
	v.queue_free()
	return r


func _f1_ship_checks(hud: Hud) -> void:
	var gs: Node = get_tree().root.get_node("GameState")
	var s: PortSim = gs.get("sim")
	var dio := hud.diorama
	var t0 := Time.get_ticks_msec()
	# 1. voyages : chaque classe vers ses postes, depuis plusieurs places de mouillage
	var cases := []
	for bi in 2:
		for cls in ["mini", "coaster", "feeder"]:
			for slot in [0, 1, 4]:
				cases.append([cls, slot, bi])
	for bi in [2, 3]:
		for cls in ["feeder", "panamax"]:
			for slot in [0, 7]:
				cases.append([cls, slot, bi])
	var by_cls := {}
	var worst := {"ratio": 0.0, "yaw_rate": 0.0, "pivot": 0.0, "crab_yaw0": 0.0, "last8": 0.0, "crab_lat": 1.0, "out_lat": 1.0,
		"out_dyaw": 0.0, "land": 0, "tug_man": 1.0, "tug_sea": 1.0, "bow": 1.0}
	var not_done: Array[String] = []
	var id := 98000
	for c in cases:
		id += 1
		var r := _f1_voyage(dio, s, String(c[0]), int(c[1]), int(c[2]), id)
		if not bool(r.done):
			not_done.append("%s %d→%d" % [c[0], c[1], c[2]])
		if not by_cls.has(c[0]):
			by_cls[c[0]] = []
		(by_cls[c[0]] as Array).append(float(r.steady))
		worst.ratio = maxf(float(worst.ratio), float(r.ratio))
		worst.yaw_rate = maxf(float(worst.yaw_rate), float(r.yaw_rate))
		worst.pivot = maxf(float(worst.pivot), float(r.pivot))
		worst.crab_yaw0 = maxf(float(worst.crab_yaw0), float(r.crab_yaw0))
		worst.last8 = maxf(float(worst.last8), float(r.last8))
		worst.crab_lat = minf(float(worst.crab_lat), float(r.crab_lat))
		worst.out_lat = minf(float(worst.out_lat), float(r.out_lat))
		worst.out_dyaw = maxf(float(worst.out_dyaw), float(r.out_dyaw))
		worst.land = int(worst.land) + int(r.land)
		worst.tug_man = minf(float(worst.tug_man), float(r.tug_man) / maxf(1.0, float(r.man)))
		worst.tug_sea = minf(float(worst.tug_sea), float(r.tug_sea) / maxf(1.0, float(r.crab)))
		worst.bow = minf(float(worst.bow), float(r.bow) / maxf(1.0, float(r.man)))
	var spread := 0.0
	var spread_txt := []
	for k in by_cls:
		var a: Array = by_cls[k]
		var lo := INF
		var hi := 0.0
		for x in a:
			lo = minf(lo, float(x))
			hi = maxf(hi, float(x))
		spread = maxf(spread, hi / maxf(0.01, lo) - 1.0)
		spread_txt.append("%s %s–%s" % [k, Fmt.num(lo), Fmt.num(hi)])
	check(not_done.is_empty() and float(worst.ratio) <= 1.3 and spread < 0.15,
		"F1 : vitesse — au plus %s × la croisière (≤ 1,3), écart en régime d'un navire à l'autre de la même classe %d %% (< 15 %% ; u/s : %s), %d voyages complets %s" % [
		Fmt.num(float(worst.ratio)), roundi(spread * 100.0), ", ".join(spread_txt), cases.size(), str(not_done)])
	check(rad_to_deg(float(worst.yaw_rate)) < 25.0 and rad_to_deg(float(worst.pivot)) < 1.0 and int(worst.land) == 0,
		"F1 : rotation au plus %s°/s (< 25), %s° de rotation à l'arrêt au plus sur un voyage (pas de pivot sur place), aucun point dans la terre (%d)" % [
		Fmt.num(rad_to_deg(float(worst.yaw_rate))), Fmt.num(rad_to_deg(float(worst.pivot))), int(worst.land)])
	check(rad_to_deg(float(worst.crab_yaw0)) < 3.0 and rad_to_deg(float(worst.last8)) < 5.0 and float(worst.crab_lat) > 0.98 and float(worst.tug_sea) > 0.9,
		"F1 : accostage en crabe — cap à %s° du quai au début du glissement, %s° au plus sur les 8 derniers mètres (< 5), glissement latéral (%s), remorqueur côté large %d %% du temps" % [
		Fmt.num(rad_to_deg(float(worst.crab_yaw0))), Fmt.num(rad_to_deg(float(worst.last8))), Fmt.num(float(worst.crab_lat)), roundi(float(worst.tug_sea) * 100.0)])
	check(float(worst.tug_man) > 0.85 and float(worst.bow) > 0.9 and float(worst.out_lat) > 0.98 and rad_to_deg(float(worst.out_dyaw)) < 1.0,
		"F1 : évitage en avançant (l'étrave avance %d %% du temps de la manœuvre), remorqueur à poste %d %% du temps (au plus près) ; départ : glissement latéral d'abord (%s, cap tenu à %s°)" % [
		roundi(float(worst.bow) * 100.0), roundi(float(worst.tug_man) * 100.0), Fmt.num(float(worst.out_lat)), Fmt.num(rad_to_deg(float(worst.out_dyaw)))])
	# 2. jamais plus vite parce que le port s'est amélioré : même voyage, Capitainerie et Renom au plus bas puis au plus haut
	var lv_h: int = s.levels.harbor
	var ren: int = s.renown
	s.levels.harbor = 1
	s.renown = 0
	s.invalidate()
	var slow := _f1_voyage(dio, s, "coaster", 1, 0, 98900)
	s.levels.harbor = 400
	s.renown = 50
	s.invalidate()
	var fast := _f1_voyage(dio, s, "coaster", 1, 0, 98901)
	s.levels.harbor = lv_h
	s.renown = ren
	s.invalidate()
	check(absf(float(slow.t_in) - float(fast.t_in)) < 0.2 and float(slow.t_in) > 40.0,
		"F1 : durée du pilotage indépendante des améliorations (%s s au niveau 1, %s s au niveau 400 et Renom 50)" % [Fmt.num(float(slow.t_in)), Fmt.num(float(fast.t_in))])
	# 3. chef d'orchestre du diorama sur une vraie partie au T3 (2 min 30 de jeu, image par image) : chaque escale en rade a
	# sa vue, un navire au plus en route et à quai par poste, nombre de vues borné, navires déchargés à l'écran
	var dt := 0.1
	var missing := 0
	var too_many := 0
	var max_views := 0
	var moored_seen := {}
	var paid0 := dio.ships_paid
	var reps0 := dio.berth_reps
	var cap := s.rade_places() + 4 * s.berths.size() + 8
	# (lot H1, corrigé : aléas suspendus pendant la mesure — brouillard (pilotage à 0, 30 s) et vent fort (grues à 0, 25 s)
	# tombaient au hasard dans la fenêtre de 150 s et vidaient à eux seuls le débit à quai ; on mesure ici la chorégraphie du
	# diorama, pas les aléas. Ils reprennent ensuite.)
	if not s.active_event.is_empty():
		Hazards.end_event(s)
	var nea0 := s.next_event_at
	s.next_event_at = s.time + 1.0e6
	# mise en route (2 min) : le premier voyage mouillage → quai dure 70 à 150 s, la fenêtre observée commence port rempli
	for i in 1200:
		s.step(dt)
		dio.step_ships(dt)
	paid0 = dio.ships_paid
	reps0 = dio.berth_reps
	for i in 1500:
		s.step(dt)
		dio.step_ships(dt)
		for sh in s.ships:
			if (sh.state == Ship.State.ARRIVING or sh.state == Ship.State.ANCHORED) and not dio.ship_views.has(sh.id):
				missing += 1
		for bi in s.berths.size():
			var n_in := 0
			var n_at := 0
			for v in dio.fleet:
				if v.berth_i == bi and v.phase == ShipView.Phase.INBOUND:
					n_in += 1
				if v.berth_i == bi and (v.phase == ShipView.Phase.CRAB_IN or v.phase == ShipView.Phase.MOORED):
					n_at += 1
					if v.phase == ShipView.Phase.MOORED:
						moored_seen[v.vid] = true
			if n_in > Diorama.INBOUND_MAX or n_at > 1:
				too_many += 1
		max_views = maxi(max_views, dio.fleet.size() + dio.parting.size())
	s.next_event_at = maxf(nea0, s.time + 60.0)
	check(missing == 0 and too_many == 0 and max_views <= cap and moored_seen.size() >= 2 and dio.ships_paid > paid0,
		"F1 : navires à l'écran au T3 — escales en rade sans vue %d, postes surchargés %d, %d vues au plus (≤ %d), %d navires déchargés à quai, %d encaissements, %d envois de la file" % [
		missing, too_many, max_views, cap, moored_seen.size(), dio.ships_paid - paid0, dio.berth_reps - reps0])
	print("  (F1 navires : %d ms)" % (Time.get_ticks_msec() - t0))
	await _wait(2)


## Lot F1 — défilement : un glissé (doigt : ScreenTouch/ScreenDrag ; souris : survol, appui, mouvements) de `dy` px en `steps`
## pas depuis p ; `mid` est appelé au milieu du glissé, `before_move` juste après l'appui.
func _f1_swipe(p: Vector2, dy: float, steps: int, mouse: bool, mid: Callable = Callable(), before_move: Callable = Callable()) -> void:
	var vp := get_viewport()
	if mouse:
		var hv := InputEventMouseMotion.new()
		hv.position = p
		hv.global_position = p
		vp.push_input(hv, true)
		await _wait(1)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = true
		mb.button_mask = MOUSE_BUTTON_MASK_LEFT
		mb.position = p
		mb.global_position = p
		vp.push_input(mb, true)
	else:
		var st := InputEventScreenTouch.new()
		st.pressed = true
		st.position = p
		vp.push_input(st, true)
	await _wait(1)
	if before_move.is_valid():
		before_move.call()
	var q := p
	for i in steps:
		var rel := Vector2(0, dy / float(steps))
		q += rel
		if mouse:
			var mm := InputEventMouseMotion.new()
			mm.position = q
			mm.global_position = q
			mm.relative = rel
			mm.button_mask = MOUSE_BUTTON_MASK_LEFT
			vp.push_input(mm, true)
		else:
			var sd := InputEventScreenDrag.new()
			sd.position = q
			sd.relative = rel
			vp.push_input(sd, true)
		await _wait(1)
		if i == steps / 2 and mid.is_valid():
			mid.call()
	if mouse:
		var mr := InputEventMouseButton.new()
		mr.button_index = MOUSE_BUTTON_LEFT
		mr.pressed = false
		mr.position = q
		mr.global_position = q
		vp.push_input(mr, true)
	else:
		var sr := InputEventScreenTouch.new()
		sr.pressed = false
		sr.position = q
		vp.push_input(sr, true)
	await _wait(2)


func _f1_find(n: Node, want_hold: bool, sh: Sheet) -> Control:
	var r := sh.scroll.get_global_rect().grow(-60)
	for c in n.get_children():
		if c is Control and (c as Control).is_visible_in_tree() and r.has_point((c as Control).get_global_rect().get_center()):
			if want_hold and c is BaseButton and not (c as BaseButton).disabled:
				for k in c.get_children():
					if k is HoldRepeat:
						return c
			if not want_hold and c is Label:
				return c
		var f := _f1_find(c, want_hold, sh)
		if f != null:
			return f
	return null


func _f1_levels(s: PortSim) -> int:
	var n := 0
	for d in PortSim.DEPTS:
		n += int(s.levels[d])
	return n


func _f1_scroll_checks(hud: Hud) -> void:
	var gs: Node = get_tree().root.get_node("GameState")
	var s: PortSim = gs.get("sim")
	hud.tutorial.active = false
	for c in hud.sheet_layer.get_children():
		c.queue_free()
	for p in hud.popup_layer.get_children():
		p.queue_free()
	s.money = maxf(s.money, 1e15)
	await _wait(2)
	hud.open_upgrades("")
	await _wait(6)
	var sh := hud.current_sheet()
	var vbar := sh.scroll.get_v_scroll_bar()
	var room := vbar.max_value - vbar.page
	# reconstruction forcée avec la liste à mi-course : le défilement est gardé
	sh.scroll.scroll_vertical = 300
	await _wait(2)
	sh.rebuild()
	await _wait(4)
	var kept := sh.scroll.scroll_vertical
	# glissé au doigt depuis un texte, une reconstruction demandée au milieu (différée au relâchement)
	sh.scroll.scroll_vertical = 200
	await _wait(2)
	var lab := _f1_find(sh.content, false, sh)
	var found := lab != null
	var d0 := sh.rebuilds_deferred
	var b0 := sh.scroll.scroll_vertical
	if lab != null:
		await _f1_swipe(lab.get_global_rect().get_center(), -200.0, 10, false, func() -> void: sh.request_rebuild())
	sh._fling = 0.0
	await _wait(4)
	var b1 := sh.scroll.scroll_vertical
	check(room > 400.0 and kept == 300 and found and b1 - b0 > 150 and sh.rebuilds_deferred == d0 + 1 and not sh.touching(),
		"F1 défilement : Améliorer garde sa position à travers une reconstruction (%d) ; un glissé au doigt depuis un texte fait défiler (%d → %d), la reconstruction demandée pendant le glissé attend le relâchement (%d ; doigt levé %s, marge %d px)" % [
		kept, b0, b1, sh.rebuilds_deferred - d0, not sh.touching(), roundi(room)])
	# glissé depuis un bouton d'achat (doigt, puis souris), appui maintenu 0,3 s avant de bouger : défile, n'achète pas
	var res := []
	for mouse in [false, true]:
		sh.scroll.scroll_vertical = 250
		await _wait(3)
		var btn := _f1_find(sh.content, true, sh)
		if btn == null:
			res.append("aucun bouton")
			continue
		var hr: HoldRepeat = null
		for k in btn.get_children():
			if k is HoldRepeat:
				hr = k
		var lv0 := _f1_levels(s)
		var c0 := sh.scroll.scroll_vertical
		await _f1_swipe(btn.get_global_rect().get_center(), -60.0, 6, mouse, Callable(), func() -> void: hr.tick(0.3))
		hr.tick(1.0)
		sh._fling = 0.0
		await _wait(3)
		res.append([mouse, sh.scroll.scroll_vertical - c0, _f1_levels(s) - lv0, hr.is_repeating()])
	var ok_btn := res.size() == 2
	for r in res:
		if not (r is Array) or int(r[1]) < 30 or int(r[2]) != 0 or bool(r[3]):
			ok_btn = false
	# appui bref à la souris sur le même genre de bouton : achète
	sh.scroll.scroll_vertical = 250
	await _wait(3)
	var btn2 := _f1_find(sh.content, true, sh)
	var lv1 := _f1_levels(s)
	if btn2 != null:
		await _f1_swipe(btn2.get_global_rect().get_center(), 0.0, 1, true)
	var tap := _f1_levels(s) - lv1
	check(ok_btn and tap >= 1,
		"F1 défilement : glissé depuis un bouton d'achat (doigt, souris ; appui de 0,3 s avant de bouger) — défile sans acheter %s ; un appui bref achète (+%d niveau)" % [str(res), tap])
	# molette (PC)
	sh.scroll.scroll_vertical = 0
	await _wait(2)
	var wp := sh.scroll.get_global_rect().get_center()
	for i in 2:
		var w := InputEventMouseButton.new()
		w.button_index = MOUSE_BUTTON_WHEEL_DOWN
		w.pressed = true
		w.factor = 1.0
		w.position = wp
		w.global_position = wp
		get_viewport().push_input(w, true)
		await _wait(1)
	var wheel := sh.scroll.scroll_vertical
	sh.close()
	await _wait(3)
	# Commerce et Gestion (onglet le plus long) : glissé à la souris depuis un texte
	var other := []
	for kind in ["commerce", "manage"]:
		var best_sh: Sheet = null
		for tb in 4:
			for c in hud.sheet_layer.get_children():
				c.queue_free()
			await _wait(2)
			hud.open_sheet(CommerceSheet.new(tb) if kind == "commerce" else ManageSheet.new(tb))
			await _wait(5)
			var cand := hud.current_sheet()
			var vb := cand.scroll.get_v_scroll_bar()
			if vb.max_value - vb.page > 300.0:
				best_sh = cand
				break
			if kind == "commerce" and tb >= 2:
				break
		if best_sh == null:
			other.append([kind, "liste courte"])
			continue
		best_sh.scroll.scroll_vertical = 100
		await _wait(2)
		var l2 := _f1_find(best_sh.content, false, best_sh)
		var e0 := best_sh.scroll.scroll_vertical
		if l2 != null:
			await _f1_swipe(l2.get_global_rect().get_center(), -150.0, 8, true)
		best_sh._fling = 0.0
		other.append([kind, best_sh.tab, best_sh.scroll.scroll_vertical - e0])
	for c in hud.sheet_layer.get_children():
		c.queue_free()
	var ok_other := true
	for o in other:
		if o.size() == 3 and int(o[2]) < 100:
			ok_other = false
	check(wheel > 100 and ok_other,
		"F1 défilement : molette (0 → %d) ; glissé à la souris dans Commerce et Gestion %s" % [wheel, str(other)])
	await _wait(2)


## Lot F2 : achat d'un bâtiment sans passer par l'ordre de la liste (la simulation applique, le monde lance le chantier).
func _f2_build(s: PortSim, bid: String) -> void:
	if not s.built.has(bid):
		s.built.append(bid)
		s.rebuild_infra()
		s.purchased.emit("building", bid)


## Lot F2 : attend (temps accéléré) que le chantier `key` finisse ; renvoie le nombre d'images où `bad` a été vrai pendant
## le chantier.
func _f2_wait_site(dio: Diorama, key: String, bad: Callable = Callable()) -> int:
	var n := 0
	var guard := Time.get_ticks_msec()
	while dio.sites.active(key) and Time.get_ticks_msec() - guard < 20000:
		await get_tree().process_frame
		if bad.is_valid() and bool(bad.call()):
			n += 1
	await _wait(3)
	return n


## Lot F2 — départ de rien (friche, cartes d'intro, séquence de chantiers du T1, premier navire), chantiers d'un achat, trafic
## lié à ce qui existe (par palier et par bâtiment), bord du monde. Nouvelle partie avec son départ ; temps accéléré
## (Engine.time_scale) : les durées se lisent sur les horloges du monde (chantiers, diorama), elles-mêmes accélérées.
func _f2_checks(hud: Hud) -> void:
	var t_start := Time.get_ticks_msec()
	var gs: Node = get_tree().root.get_node("GameState")
	var st: Node = get_tree().root.get_node("Settings")
	var sim_r: Node = get_tree().root.get_node("Sim")
	var dio := hud.diorama
	for c in hud.sheet_layer.get_children():
		c.queue_free()
	for p in hud.popup_layer.get_children():
		p.queue_free()
	hud.tutorial.active = false
	st.set("intro_seen", false)
	gs.set("auto_start", true)
	gs.call("new_game")
	await _wait(4)
	var s: PortSim = gs.get("sim")
	_f3_gap = {"max": 0.0, "cur": 0.0, "last": -1.0, "on": false, "worst_at": ""}
	# 1. la friche : rien de ce qui s'achète n'existe (ni quai, ni grue, ni barrières, ni navire, camion ou engin), l'estacade
	# ruinée et les broussailles à la place ; l'autoroute a déjà son trafic léger de voitures ; la simulation est gelée et la
	# première carte d'intro est à l'écran. (Lot F3, recalé : « HUD masqué » se lit sur le HUD lui-même — il s'efface sous les
	# cartes d'intro — et non plus sur le départ, pendant lequel il reste visible ; 24 images d'attente pour son fondu.)
	await get_tree().create_timer(0.6).timeout
	var quay_nodes := 0
	var ruin := 0
	for c in dio.static_root.get_children():
		if c.is_queued_for_deletion():
			continue
		if String(c.get_meta("site", "")) == "quay1":      # (lot G2, recalé : le quai n°1 est un bâtiment, plus la pièce « quay0 »)
			quay_nodes += 1
		if String(c.get_meta("before", "")) == "quay1":
			ruin += 1
	var cars_ok := dio.traffic.cars.size() >= 3 and dio.traffic.cars.size() <= 5
	for cr in dio.traffic.cars:
		var cp: Vector3 = (cr.node as Node3D).position
		if cp.z < Layout.HIGHWAY_Z0 or cp.z > Layout.HIGHWAY_Z1 or cp.x < float(Layout.HIGHWAY_ENDS[0]) - 0.5 or cp.x > float(Layout.HIGHWAY_ENDS[1]) + 0.5:
			cars_ok = false
	var friche := quay_nodes == 0 and ruin >= 1 and dio.crane_views.is_empty() and dio.traffic.barriers.is_empty() and dio.fleet.is_empty() \
		and dio.traffic.vehicles.is_empty() and dio.traffic.trucks.is_empty() and dio.traffic.queue.is_empty()
	var gel := bool(sim_r.get("paused")) and s.time == 0.0
	check(friche and cars_ok and hud.intro_active() and hud.intro_shown == 1 and gel and not hud.top_box.visible,
		"F2 départ : friche (quai %d, estacade %d, grues %d, barrières %d, navires %d, engins %d, camions %d), %d voitures sur l'autoroute (%s), 1re carte d'intro (%s, %d), simulation gelée (%s), HUD masqué (%s)" % [
		quay_nodes, ruin, dio.crane_views.size(), dio.traffic.barriers.size(), dio.fleet.size(), dio.traffic.vehicles.size(), dio.traffic.trucks.size() + dio.traffic.queue.size(), dio.traffic.cars.size(),
		cars_ok, hud.intro_active(), hud.intro_shown, gel, not hud.top_box.visible])
	# 2. trois cartes de la narratrice, chacune passée d'un toucher ; ensuite l'acte 0 (lot F3, recalé : la séquence de chantiers
	# du T1 attend la bascule) — port fermé, 0 $, HUD visible, la pêche tourne, le ponton pourri d'Odette, aucun bateau
	var t1_before := dio.t1_works_active()
	for i in 3:
		if hud.intro_active():
			(hud.intro_layer as Button).pressed.emit()
		await _wait(2)
	_f3_gap.on = true
	await _wait(24)
	var anse_ruin := 0
	for c in dio.fishing_view._static.get_children():
		if not c.is_queued_for_deletion() and String(c.get_meta("before", "")) == "fish_places_1":
			anse_ruin += 1
	check(not t1_before and not hud.intro_active() and hud.intro_shown == 3 and bool(st.get("intro_seen")) and not dio.t1_works_active()
		and s.fishing.act0 and s.money == 0.0 and not bool(sim_r.get("paused")) and hud.top_box.visible and anse_ruin == 1 and dio.fishing_view.boats.is_empty(),
		"F2/F3 intro : 3 cartes passées d'un toucher (%d), puis l'acte 0 — port fermé (%s), 0 $, HUD visible (%s), simulation en marche, ponton pourri (%d), aucun bateau" % [
		hud.intro_shown, s.fishing.act0, hud.top_box.visible, anse_ruin])
	# lot F3 — l'acte 0 « La Crique » (tutoriel, cartes, bateaux, coup de main, achats, camionnette)
	await _f3_act0(hud, s)
	# 3. la bascule (lot G1 ; lot G2 recalé) : la Concession signée — d'abord les nuages se dissolvent (3,5 s, caméra encore
	# bornée), puis les bornes s'élargissent, la narratrice parle ; un toucher, la cérémonie « Palier 1 — Le Vieux Quai », puis la
	# friche nue : plus de séquence de chantiers automatique (le caboteur attend le quai n°1)
	s.money += float(s.fishing.concession_def().cost)
	s.buy_fish_building("concession")
	for k in 6:
		await get_tree().process_frame
		_f3_track(hud)
	var dissolving := dio.clouds != null and is_instance_valid(dio.clouds) and dio.clouds.dissolving and not hud.story_active() and dio.first_view == null
	var guard0 := Time.get_ticks_msec()
	while ((dio.clouds != null and is_instance_valid(dio.clouds)) or not hud.story_active()) and Time.get_ticks_msec() - guard0 < 8000:
		await get_tree().process_frame
		_f3_track(hud)
	var no_clouds := dio.clouds == null or not is_instance_valid(dio.clouds)
	var widened := not dio.rig.crique and dio.rig.bounds != Layout.CRIQUE_BOUNDS
	check(dissolving and no_clouds and widened and s.fishing.act0, "G1 Concession : les nuages se dissolvent d'abord (%s), puis disparaissent (%s) et les bornes de la caméra s'élargissent (%s), port encore fermé" % [dissolving, no_clouds, widened])
	for k in 6:
		await get_tree().process_frame
		_f3_track(hud)
	# (lot G2, remplace « F3 bascule : carte de la narratrice, le caboteur de Corsaire & Fils déjà en route, né hors champ »)
	check(hud.bascule_on and hud.story_active() and s.ships.is_empty() and dio.fleet.is_empty() and dio.first_view == null and s.fishing.act0 and s.time == 0.0,
		"G2 bascule : carte de la narratrice (%s), aucun navire — le caboteur attend le quai n°1 (%d), port encore fermé" % [hud.story_active(), s.ships.size() + dio.fleet.size()])
	if hud.story_active():
		(hud.story_layer as Button).pressed.emit()
	await _wait(2)
	var cer := hud.ceremony_active() and hud.ceremonies >= 1 and s.fishing.act0
	for k in 4:
		await get_tree().process_frame
		_f3_track(hud)
	hud._finish_ceremony()
	await _wait(3)
	# (lot G2, remplace « F3 bascule : … puis la séquence de chantiers du T1 »)
	check(cer and not hud.story_active() and not s.fishing.act0 and not hud.start_flow and s.g2 and s.built.is_empty() and s.ships.is_empty()
		and dio.sites.sites.is_empty() and not dio.t1_works_active() and dio.crane_views.is_empty(),
		"G2 bascule : un toucher passe la carte, cérémonie « Palier 1 — Le Vieux Quai » (port fermé pendant : %s), puis la friche nue — aucun chantier lancé (%d), rien de bâti, aucun navire, le port ouvert" % [cer, dio.sites.sites.size()])
	# 4. lot G2 — le premier navire à la main (remplace « F2/F3 séquence du T1 » et « F2 premier navire ») : AMÉLIORER propose un
	# seul achat, en tête ; chaque achat a son chantier (temps ×6) ; le caboteur de Corsaire & Fils se présente en rade après le
	# quai n°1 ; on le touche, il accoste et décharge avec sa grue de bord ; les conteneurs posés sur la plateforme attendent le
	# tampon (orange) ; la cabane les tamponne (verts) ; la barrière laisse passer le camion, qui paie
	var order: Array[String] = []
	var heads: Array[String] = []
	var durs: Array[String] = []
	var dur_ok := true
	var lone_ok := true
	var ship_early := 0
	var hist0 := dio.sites.history.size()
	var tu := hud.tutorial
	tu.active = true
	var tuto_seen: Array[String] = []
	for bid in ["platform", "quay1"]:
		tu._refresh_card(true)
		if tu.idx < tu.steps.size() and String(tu.steps[tu.idx].id) == "welcome":
			tu._on_button()          # « C'EST PARTI »
			tu._refresh_card(true)
		if tu.idx < tu.steps.size():
			tuto_seen.append(String(tu.steps[tu.idx].id))
		s.money = maxf(s.money, float(s.db.building_by_id[bid].cost))
		hud.open_upgrades("")
		await _wait(4)
		_f3_track(hud)
		var upb: UpgradesSheet = hud.sheet_layer.get_child(0)
		var bcards := upb.cards.filter(func(c: Dictionary) -> bool: return c.has("build"))
		var dcards := upb.cards.filter(func(c: Dictionary) -> bool: return c.has("dept"))
		heads.append(String(upb.cards[0].get("build", "?")) if not upb.cards.is_empty() else "?")
		if bcards.size() != 1 or not dcards.is_empty():
			lone_ok = false
		if not bcards.is_empty():
			(bcards[0].buy as Button).pressed.emit()
		await _wait(2)
		upb.close()
		await _wait(2)
		if s.built.has(bid):
			order.append(bid)
		Engine.time_scale = 6.0
		await _f2_wait_site(dio, bid, func() -> bool: return not s.ships.is_empty())
		Engine.time_scale = 1.0
		_f3_track(hud)
		if bid == "platform" and not s.ships.is_empty():
			ship_early += 1
	for h in dio.sites.history.slice(hist0):
		var real := float(h.t1) - float(h.t0)
		durs.append("%s %s s" % [h.key, Fmt.num(real)])
		if absf(real - float(h.dur)) > 0.3 or float(h.dur) < 3.0 or float(h.dur) > 6.0:
			dur_ok = false
	# le caboteur se présente (temps ×4) : en rade, bulle « Touche pour accoster »
	var fsh: Ship = s.ships[0] if not s.ships.is_empty() else null
	var corsaire := fsh != null and fsh.owner == "corsaire"
	var guard := Time.get_ticks_msec()
	Engine.time_scale = 4.0
	var berth_pill := false
	while fsh != null and (fsh.state != Ship.State.ANCHORED or not dio.ship_views.has(fsh.id) or not berth_pill) and Time.get_ticks_msec() - guard < 30000:
		await get_tree().process_frame
		_f3_track(hud)
		var fv0: ShipView = dio.ship_views.get(fsh.id)
		if fv0 != null:
			hud.diorama.rig.focus(fv0.position)
		berth_pill = hud.overlay.frame_rects.has("berth_gesture")
	Engine.time_scale = 1.0
	tu._refresh_card(true)
	if tu.idx < tu.steps.size():
		tuto_seen.append(String(tu.steps[tu.idx].id))
	var anchored := fsh != null and fsh.state == Ship.State.ANCHORED
	# sans geste, il reste en rade (monde figé sans Léon : il attend qu'on le touche, il n'accoste jamais seul)
	var still := true
	for k in 20:
		await get_tree().process_frame
		_f3_track(hud)
		if fsh != null and fsh.state != Ship.State.ANCHORED:
			still = false
	check(order == ["platform", "quay1"] and heads == ["platform", "quay1"] and lone_ok and dur_ok and ship_early == 0 and corsaire and anchored and berth_pill and still
		and tuto_seen == ["t_platform", "t_quay", "ship"],
		"G2 friche : AMÉLIORER ne propose qu'un achat, en tête (%s, seul : %s), chantiers %s (3 à 6 s) ; le caboteur de Corsaire & Fils en rade après le quai seulement (%s, avant %d), bulle « Touche pour accoster » (%s), il n'accoste pas seul (%s) ; tutoriel %s" % [
		str(heads), lone_ok, str(durs), corsaire, ship_early, berth_pill, still, str(tuto_seen)])
	# accoster d'un toucher ; grue de bord ; conteneurs orange sur la plateforme
	var bc_seen := 0
	var orange := 0
	if fsh != null and dio.ship_views.has(fsh.id):
		dio._on_tapped((dio.ship_views[fsh.id] as ShipView).position, Vector2.ZERO)
	var gb0 := int(s.gestures.berth)
	guard = Time.get_ticks_msec()
	Engine.time_scale = 4.0
	while (bc_seen == 0 or orange == 0) and Time.get_ticks_msec() - guard < 30000:
		await get_tree().process_frame
		_f3_track(hud)
		bc_seen = maxi(bc_seen, dio.board_cranes)
		orange = maxi(orange, dio.yard._pending_n)
	Engine.time_scale = 1.0
	check(fsh != null and int(s.gestures.berth) >= 1 and s.board_crane(0) and bc_seen >= 1 and orange >= 1 and dio.yard.platform_mode
		and is_equal_approx(s.berth_unload_rate(0), float(s.db.cfg("manual").board_crane_rate)),
		"G2 grue de bord : accosté d'un toucher (%d geste), le caboteur décharge avec sa grue de bord (%d à l'écran, %s conteneur/s), conteneurs orange posés sur la plateforme (%d)" % [
		int(s.gestures.berth) - gb0 + 1, bc_seen, Fmt.num(s.berth_unload_rate(0)), orange])
	_f3_gap.on = false
	check(float(_f3_gap.max) <= 15.0,
		"F3 : aucune fenêtre de plus de 15 s sans action possible de la fin de l'intro au premier cargo à quai (plus longue : %s s %s)" % [Fmt.num(float(_f3_gap.max)), String(_f3_gap.worst_at)])
	# la cabane : un achat ; toucher la cabane tamponne le lot (orange → verts)
	for bid in ["hut"]:
		s.money = maxf(s.money, float(s.db.building_by_id[bid].cost))
		hud.open_upgrades("")
		await _wait(4)
		var upc: UpgradesSheet = hud.sheet_layer.get_child(0)
		heads.append(String(upc.cards[0].get("build", "?")) if not upc.cards.is_empty() else "?")
		if not upc.cards.is_empty() and upc.cards[0].has("build"):
			(upc.cards[0].buy as Button).pressed.emit()
		await _wait(2)
		upc.close()
		Engine.time_scale = 6.0
		await _f2_wait_site(dio, bid)
		Engine.time_scale = 1.0
	guard = Time.get_ticks_msec()
	var stamp_pill := false
	hud.diorama.rig.focus(Layout.CUSTOMS_HUT)
	while not stamp_pill and Time.get_ticks_msec() - guard < 8000:
		await get_tree().process_frame
		stamp_pill = hud.overlay.frame_rects.has("stamp_gesture") and s.stamp_ready()
	var pend_s := s.pending_total()
	var st0 := dio.stamps_shown
	dio._on_tapped(Layout.CUSTOMS_HUT, Vector2.ZERO)
	await _wait(3)
	var green := dio.yard._shown[0] - dio.yard._pending_n
	check(heads[-1] == "hut" and s.built.has("hut") and stamp_pill and pend_s >= 1.0 and dio.stamps_shown == st0 + 1 and s.pending_total() < pend_s and green >= 1,
		"G2 tamponner : la cabane en tête d'AMÉLIORER (%s), bulle « À tamponner » (%s, %s conteneurs), toucher la cabane : tamponnés, %d verts sur la plateforme" % [
		heads[-1], stamp_pill, Fmt.num(pend_s), green])
	# la piste et la barrière : un camion se présente ; toucher la barrière, il charge, paie et part
	s.money = maxf(s.money, float(s.db.building_by_id.track.cost))
	hud.open_upgrades("")
	await _wait(4)
	var upt: UpgradesSheet = hud.sheet_layer.get_child(0)
	heads.append(String(upt.cards[0].get("build", "?")) if not upt.cards.is_empty() else "?")
	if not upt.cards.is_empty() and upt.cards[0].has("build"):
		(upt.cards[0].buy as Button).pressed.emit()
	await _wait(2)
	upt.close()
	Engine.time_scale = 6.0
	await _f2_wait_site(dio, "track")
	var gate_pill := false
	var trucks_before_pass := 0
	guard = Time.get_ticks_msec()
	hud.diorama.rig.focus(Layout.GATE)
	while not (gate_pill and s.pass_ready()) and Time.get_ticks_msec() - guard < 30000:
		await get_tree().process_frame
		if s.stamp_ready():
			s.stamp()
		gate_pill = hud.overlay.frame_rects.has("gate_gesture")
		trucks_before_pass = maxi(trucks_before_pass, dio.traffic.queue.size())
	Engine.time_scale = 1.0
	var m_pass := s.money
	var pv := dio.passes_shown
	var leaving0 := dio.traffic.trucks.size()
	dio._on_tapped(Layout.GATE, Vector2.ZERO)
	await _wait(3)
	var paid := s.money - m_pass
	check(heads[-1] == "track" and gate_pill and trucks_before_pass >= 1 and dio.passes_shown == pv + 1 and s.counter("passes") >= 1.0 and paid > 0.0
		and dio.traffic.trucks.size() > leaving0,
		"G2 laisser passer : la piste en tête (%s), un camion à la barrière (%d), bulle « Camion : touche la barrière » (%s) ; toucher la barrière : il charge, paie (+%s) et repart (%d) — premier camion" % [
		heads[-1], trucks_before_pass, gate_pill, Fmt.money(paid), dio.traffic.trucks.size() - leaving0])
	# un camion qu'on ne sert pas : bulle rouge (compte à rebours), puis il repart sans rien
	var lost0 := s.counter("trucks_lost")
	var red_t := false
	guard = Time.get_ticks_msec()
	Engine.time_scale = 6.0
	s.yard_cleared[0] = maxf(s.yard_cleared[0], 4.0)
	while s.counter("trucks_lost") == lost0 and Time.get_ticks_msec() - guard < 25000:
		await get_tree().process_frame
		if s.pass_ready() and s.truck_wait_left() < float(s.db.cfg("manual").truck_warn) and hud.overlay.frame_rects.has("gate_gesture"):
			red_t = true
	Engine.time_scale = 1.0
	check(s.counter("trucks_lost") > lost0 and red_t, "G2 camion non servi : bulle rouge avant (%s), il repart sans rien (%d perdu)" % [red_t, int(s.counter("trucks_lost") - lost0)])
	# la plateforme pleine : « Il faut une sortie ! » (la première apparition du goulot)
	s.yard_cleared[0] = s.yard_capacity()
	for shp in s.ships:
		shp.patience = shp.patience_max
	s._alert_left = 0.0
	s._refresh_analysis()
	guard = Time.get_ticks_msec()
	var exit_pill := false
	hud.diorama.rig.focus(Layout.YARD_CENTER)
	while not exit_pill and Time.get_ticks_msec() - guard < 6000:
		await get_tree().process_frame
		exit_pill = hud.overlay.frame_rects.has("exit")
	hud._refresh(s)
	check(exit_pill and String(s.shown_analysis().get("alert", "")) == "exit" and hud.hint_title.text == "Il faut une sortie !",
		"G2 plateforme pleine : bulle « Il faut une sortie ! » (%s), carte Goulot (%s)" % [exit_pill, hud.hint_title.text])
	s.yard_cleared[0] = 4.0
	# monde figé sans responsable du port : une absence ne fait rien avancer au port (ni conteneur, ni navire, ni argent du port) ;
	# seul Marcel encaisse les loyers de la Crique
	var m_off := s.money
	var evp_off := s.counter("evp")
	var states_off := s.ships.map(func(x: Ship) -> int: return x.state)
	var fish_off := s.fishing.offline_rate() * minf(1800.0, float(s.db.cfg("offline_max_hours")) * 3600.0)
	gs.call("credit_offline", 1800.0)
	var frozen := is_equal_approx(s.money - m_off, fish_off) and s.counter("evp") == evp_off and s.ships.map(func(x: Ship) -> int: return x.state) == states_off
	var frozen_txt := "%s, +%s pour %s de pêche" % [frozen, Fmt.money(s.money - m_off), Fmt.money(fish_off)]
	await _wait(2)
	for p in hud.popup_layer.get_children():
		p.queue_free()
	await _wait(2)
	# Léon après 5 accostages : bulle + carte de la narratrice, RESPONSABLES ; embauché, il remplace le geste et la carte
	# Accostage apparaît dans AMÉLIORER
	var cards0 := hud.mgr_cards_shown
	s.gestures.berth = int(s.db.cfg("manual").gesture_offers)
	s.last_reveal_t = -1.0e9
	guard = Time.get_ticks_msec()
	while not s.mgr_offered.has("berths") and Time.get_ticks_msec() - guard < 5000:
		await get_tree().process_frame
	await _wait(3)
	var offer_card := hud.mgr_cards_shown == cards0 + 1 and hud.story_active() and not hud.overlay.visible      # (revue : aucune bulle par-dessus la carte)
	if hud.story_active():
		(hud.story_layer as Button).pressed.emit()
	await _wait(2)
	hud.diorama.rig.focus(Layout.manager_pos("berths", s.tier))
	hud.diorama.rig.target = hud.diorama.rig.goal
	await _wait(4)
	var offer_pill := hud.overlay.frame_rects.has("offer_berths")
	hud._refresh(s)
	var mbtn := hud.manage_btn.visible and hud.mgr_pill.visible
	hud._on_manage_btn()
	await _wait(4)
	var msh: ManageSheet = hud.sheet_layer.get_child(0)
	var leon_row := msh.rows.any(func(r: Dictionary) -> bool: return String(r.get("dept", "")) == "berths")
	s.money += s.manager_cost("berths")
	msh._hire("berths", false)
	await _wait(3)
	msh.close()
	await _wait(2)
	hud.open_upgrades("")
	await _wait(4)
	var upl: UpgradesSheet = hud.sheet_layer.get_child(0)
	var acc_card := not upl._card_for("dept", "berths").is_empty()
	var dept_ids := upl.cards.filter(func(c: Dictionary) -> bool: return c.has("dept")).map(func(c: Dictionary) -> String: return String(c.dept))
	upl.close()
	await _wait(3)
	# plus de geste : un navire en rade n'a plus de bulle ; le toucher n'accoste plus « à la main »
	var pill_after := false
	for k in 30:
		await get_tree().process_frame
		if hud.overlay.frame_rects.has("berth_gesture"):
			pill_after = true
	check(frozen and offer_card and offer_pill and mbtn and leon_row and s.managers.berths and acc_card and not pill_after,
		"G2 Léon : monde figé sans responsable du port (%s) ; après 5 accostages il se présente (carte sans bulle par-dessus %s, bulle sur le quai %s, RESPONSABLES %s, fiche %s) ; embauché : carte Accostage dans AMÉLIORER (%s), plus de bulle d'accostage, Heures sup révélées (%s)" % [
		frozen_txt, offer_card, offer_pill, mbtn, leon_row, str(dept_ids), s.feature("boost")])
	# l'anse après l'acte 0 : la pêche est passive (revenu fixe), plus de carte ni de pastille, les bateaux vivent toujours
	hud.open_upgrades("")
	await _wait(4)
	var up_after: UpgradesSheet = hud.sheet_layer.get_child(0)
	var fish_after := up_after.cards.filter(func(c: Dictionary) -> bool: return c.has("fish")).size()
	up_after.close()
	await _wait(2)
	var vis_boats := 0
	for v in dio.fishing_view.boats:
		if (v.node as Node3D).visible:
			vis_boats += 1
	check(fish_after >= 2 and s.fishing.rate_estimate() > 0.0 and dio.fishing_view.collectable().is_empty() and vis_boats >= 3 and Hud.worthwhile_count(s) >= 0 and not Hud.fishing_cards(s) 		and dio.clouds == null and not dio.rig.crique,
		"G1 après la Concession : la pêche continue (%s/s, Marcel encaisse), les cartes de la Crique restantes en bas d'AMÉLIORER (%d), %d bateaux vivent dans l'anse, plus de nuages" % [Fmt.num(s.fishing.rate_estimate()), fish_after, vis_boats])
	# (lot G2 : le reste des pièces du départ — grue mobile et parc de stockage — avant les contrôles des chantiers et du trafic,
	# écrits pour un port qui les a)
	s.money = 1.0e7
	_f2_build(s, "crane_mobile")
	_f2_build(s, "yard")
	Engine.time_scale = 6.0
	await _f2_wait_site(dio, "crane_mobile")
	await _f2_wait_site(dio, "yard")
	Engine.time_scale = 1.0
	# 5. chantier d'un achat : palissade et engin, bâtiment caché puis monté, état d'avant effacé ; deux chantiers en même temps
	s.money = 1.0e7
	var par0 := dio.sites.max_parallel
	_f2_build(s, "gravel2")
	_f2_build(s, "customs1")
	await _wait(3)
	var props := 0
	var machine := false
	if dio.sites.sites.has("gravel2"):
		props = (dio.sites.sites["gravel2"].props as Array).size()
		machine = dio.sites.sites["gravel2"].machine != null
	var hidden_ok := true
	var before_n := 0
	for c in dio.static_root.get_children():
		if c.is_queued_for_deletion():
			continue
		if String(c.get_meta("site", "")) == "customs1" and (c as Node3D).scale.x > 0.05:
			hidden_ok = false
		if String(c.get_meta("before", "")) == "gravel2":
			before_n += 1
	var during := dio.sites.active("gravel2") and dio.sites.active("customs1") and not dio.ready_bid("gravel2") and dio.sites.sites.size() >= 2
	Engine.time_scale = 6.0
	await _f2_wait_site(dio, "gravel2")
	await _f2_wait_site(dio, "customs1")
	# (l'ouverture de la zone de la douane tient ses nœuds : le décor est reconstruit à sa fin)
	var og := Time.get_ticks_msec()
	while dio.opening_active() and Time.get_ticks_msec() - og < 10000:
		await get_tree().process_frame
	await _wait(3)
	Engine.time_scale = 1.0
	var after_scale := 0.0
	var before_left := 0
	for c in dio.static_root.get_children():
		if c.is_queued_for_deletion():
			continue
		if String(c.get_meta("site", "")) == "customs1":
			after_scale = maxf(after_scale, (c as Node3D).scale.x)
		if String(c.get_meta("before", "")) == "gravel2":
			before_left += 1
	check(during and props >= 4 and machine and hidden_ok and before_n >= 2 and dio.ready_bid("gravel2") and dio.ready_bid("customs1") and after_scale > 0.95 and before_left == 0,
		"F2 chantier d'un achat : deux à la fois (%s), palissade %d modules, engin %s, bâtiment caché pendant (%s) puis monté (×%s), état d'avant %d → %d" % [
		during, props, machine, hidden_ok, Fmt.num(after_scale), before_n, before_left])
	# 6. trafic lié à ce qui existe, par palier et par bâtiment : pendant son chantier, un bâtiment ne sert pas encore
	s.tier = 2
	s.levels["harbor"] = maxi(20, int(s.levels["harbor"]))
	Engine.time_scale = 4.0
	var tv := dio.traffic
	var rows: Array[String] = []
	var all_ok := true
	# T2 : quai n°2 — aucun navire vers le poste 2 pendant son chantier
	_f2_build(s, "berth2")
	await _wait(2)
	var to_b2 := await _f2_wait_site(dio, "berth2", func() -> bool:
		for v in dio.fleet:
			if is_instance_valid(v) and v.berth_i == 1 and (v.phase == ShipView.Phase.INBOUND or v.phase == ShipView.Phase.CRAB_IN or v.phase == ShipView.Phase.MOORED):
				return true
		return false)
	rows.append("quai n°2 : %d" % to_b2)
	all_ok = all_ok and to_b2 == 0 and dio.ready_bid("berth2")
	# T2 : deuxième voie de gate et aire d'attente — ni voie ni places avant la fin de leur chantier
	_f2_build(s, "gate2")
	_f2_build(s, "parking1")
	await _wait(2)
	var g2_early := await _f2_wait_site(dio, "gate2", func() -> bool: return tv._gate2 or tv._lot_slots > 0)
	await _f2_wait_site(dio, "parking1")
	rows.append("gate2/parking : %d (après : voie %s, %d places)" % [g2_early, tv._gate2, tv._lot_slots])
	all_ok = all_ok and g2_early == 0 and tv._gate2 and tv._lot_slots > 0
	# T3 : terminal rail — pas de train avant la fin de son chantier
	s.tier = 3
	_f2_build(s, "berth3")
	_f2_build(s, "rail")
	await _wait(2)
	var train_early := await _f2_wait_site(dio, "rail", func() -> bool: return tv.train != null and is_instance_valid(tv.train) and tv.train.visible and tv._train_t >= 0.0)
	await _f2_wait_site(dio, "berth3")
	rows.append("rail : %d" % train_early)
	all_ok = all_ok and train_early == 0 and dio.ready_bid("rail")
	Engine.time_scale = 1.0
	check(all_ok, "F2 trafic lié à ce qui existe (pendant le chantier, images où le bâtiment sert déjà) : %s" % str(rows))
	# 7. la caméra ne montre jamais le bord du monde : zoom le plus large, aux quatre coins des bornes, les coins de l'écran
	# tombent dans le monde habillé (forêt, rives, eau)
	var rg := dio.rig
	rg.set_tier_bounds(3)
	var b: Rect2 = rg.bounds
	var vsz := hud.get_viewport_rect().size
	var edge_bad: Array[String] = []
	for c in [b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)]:
		rg.target = Vector3(c.x, 0, c.y)
		rg.zoom = rg.zoom_max
		rg._apply()
		for sp in [Vector2.ZERO, Vector2(vsz.x, 0), Vector2(0, vsz.y), vsz]:
			var g := rg.screen_to_ground(sp)
			if not Layout.FOREST_AREA.has_point(Vector2(g.x, g.z)):
				edge_bad.append("(%d, %d)" % [int(g.x), int(g.z)])
	rg.target = CameraRig.START
	rg.goal = CameraRig.START
	rg.zoom = CameraRig.ZOOM_START
	check(edge_bad.is_empty() and rg.zoom_max <= CameraRig.ZOOM_MAX, "F2 : au zoom le plus large (%d), coins de l'écran dans le monde habillé aux quatre coins des bornes (%s)" % [int(rg.zoom_max), str(edge_bad.slice(0, 3))])
	# lot F3 — sauvegarde v6 : une partie enregistrée pendant l'acte 0 reprend dans l'anse (ni carte d'intro, ni chantier rejoué,
	# port fermé) ; une partie d'avant F3 (sans « act0 ») se charge acte 0 fait, pêche passive, sans départ ni chantier
	var a0 := PortSim.new(s.db, 11)
	a0.begin_act0()
	a0.buy_fish_places(1)
	for k in 120:
		a0.step(0.25)
	a0.money += 25.0
	a0.buy_fish_places(1)
	var d0: Dictionary = JSON.parse_string(JSON.stringify(a0.to_dict()))
	var intro0 := hud.intro_shown
	gs.call("load_from", d0)
	await _wait(4)
	var ls: PortSim = gs.get("sim")
	var resumed := hud.start_flow and not hud.intro_active() and hud.intro_shown == intro0 and ls.fishing.act0 and ls.fishing.places == 2 		and not dio.t1_works_active() and dio.sites.sites.is_empty() and ls.g2 and ls.built.is_empty() and dio.fishing_view.boats.size() == 3 		and dio.clouds_on() and dio.rig.crique
	var t1d := PortSim.new(s.db, 12).to_dict()
	t1d.erase("act0")
	gs.call("load_from", t1d)
	await _wait(4)
	var l2: PortSim = gs.get("sim")
	check(resumed and not hud.start_flow and not l2.fishing.act0 and l2.fishing.maxed() and dio.sites.sites.is_empty() and not dio.start_flow_active() 		and dio.fishing_view.boats.size() == 12 and dio.clouds == null and not dio.rig.crique,
		"G1/G2 sauvegarde v8 : partie de la Crique rechargée dans l'anse (%s : sans intro ni chantier rejoué, port fermé, friche nue à venir, nuages posés) ; partie d'avant F3 chargée Crique finie (%d bateaux, 20 voiliers), sans nuages ni départ" % [
		resumed, dio.fishing_view.boats.size()])
	gs.set("auto_start", false)
	Engine.time_scale = 1.0
	print("  (F2 : %d ms)" % (Time.get_ticks_msec() - t_start))
	await _wait(2)


# ---------------------------------------------------------------------------------------------------------------------
# Lot F3 — l'acte 0 « La Crique »
# ---------------------------------------------------------------------------------------------------------------------
var _f3_gap: Dictionary = {"max": 0.0, "cur": 0.0, "last": -1.0, "on": false, "worst_at": ""}


## Fenêtre sans action possible (de la fin de l'intro au premier cargo à quai) : une image compte si le joueur ne peut rien
## faire — ni HUD (boutons, Améliorer), ni feuille ouverte, ni carte de la narratrice ou cérémonie à passer d'un toucher.
func _f3_track(hud: Hud) -> void:
	if not bool(_f3_gap.on):
		_f3_gap.last = -1.0
		return
	var t := hud.diorama._t
	var can := hud.hud_fade > 0.02 or hud.any_sheet_open() or hud.story_active() or hud.ceremony_active() or hud.intro_active()
	if float(_f3_gap.last) >= 0.0 and not can:
		_f3_gap.cur = float(_f3_gap.cur) + (t - float(_f3_gap.last))
		if float(_f3_gap.cur) > float(_f3_gap.max):
			_f3_gap.max = _f3_gap.cur
			_f3_gap.worst_at = "(bascule %s, chantiers %s)" % [hud.bascule_on, hud.diorama.t1_works_active()]
	elif can:
		_f3_gap.cur = 0.0
	_f3_gap.last = t


## Bateaux de pêche à l'écran, une image : à terre ? sur un ponton ? rotation sans avancer (pivot) ?
func _f3_observe(fv: FishingView, obs: Dictionary, rects: Array, delta: float) -> void:
	obs.frames = int(obs.frames) + 1
	var vis := 0
	for i in fv.boats.size():
		var n: Node3D = fv.boats[i].node
		if not n.visible:
			continue
		vis += 1
		var p := Vector2(n.position.x, n.position.z)
		if Layout.any_land(p):
			obs.land = int(obs.land) + 1
		for r in rects:
			if (r as Rect2).has_point(p):
				obs.pontoon = int(obs.pontoon) + 1
		var last: Dictionary = obs.last
		if last.has(i) and delta > 0.0:
			var lp: Array = last[i]
			var moved := p.distance_to(lp[0]) / delta
			var turn := absf(angle_difference(float(lp[1]), n.rotation.y)) / delta
			if moved < 0.25 and turn > 0.15:      # (rotation de plus de 8,6°/s sans avancer)
				obs.pivot = int(obs.pivot) + 1
		last[i] = [p, n.rotation.y]
	obs.max_vis = maxi(int(obs.max_vis), vis)
	# camionnette du mareyeur : visible seulement sur la route du mareyeur, la rue du village ou devant la criée
	if fv.van != null and is_instance_valid(fv.van) and fv.van.visible:
		var vp := Vector2(fv.van.position.x, fv.van.position.z)
		if not (Layout.FISH_ROAD.grow(1.0).has_point(vp) or Rect2(-133.5, 95.5, 110, 7).has_point(vp)):
			obs.van_off = int(obs.van_off) + 1
		obs.van_seen = true


## La Crique jouée par l'interface (lot G1) : tutoriel « répare le ponton » sur AMÉLIORER, les cartes de la Crique (Places,
## Services, le prochain bâtiment), le chantier ; les bateaux qui arrivent du large et suivent leur boucle (jamais à terre, jamais
## sur un ouvrage, aucun sprint, aucune rotation sur place) ; la bulle « Loyer » sur un bateau rentré, toucher = encaisser
## (pièces, « +X $ », tutoriel suivant) ; un bateau qu'on ne touche pas passe au rouge puis repart sans payer ; Marcel se
## présente (RESPONSABLES), embauché : plus aucune bulle, Heures sup ; l'annonce (caboteur au large, narratrice, MISSIONS) ;
## la camionnette ; les nuages et les bornes de la caméra.
func _f3_act0(hud: Hud, s: PortSim) -> void:
	var dio := hud.diorama
	var fv := dio.fishing_view
	var tu := hud.tutorial
	var f := s.fishing
	fv.speed_seen = {}          # (vitesses mesurées par la vue : celles des contrôles précédents, simulation pas à pas, ne comptent pas)
	tu.idx = 0
	tu.active = true
	tu._shown = ""
	tu._refresh_card(true)
	await _wait(3)
	_f3_track(hud)
	# les nuages sont posés, la caméra bornée à l'anse ; au zoom le plus large, depuis chaque coin des bornes, les coins de l'écran
	# tombent dans le monde habillé et au moins deux sur quatre sous les nuages
	var rg := dio.rig
	var clouds_on := dio.clouds_on() and dio.clouds.bank_count >= 100 and dio.clouds.sheet_tris >= 1000 and rg.crique and rg.bounds == Layout.CRIQUE_BOUNDS and rg.zoom_max <= Layout.CRIQUE_ZOOM_MAX
	var vsz := hud.get_viewport_rect().size
	var cam0 := [rg.target, rg.goal, rg.zoom, rg.zoom_goal]
	var edge_bad := 0
	var under := 0
	for c in [rg.bounds.position, Vector2(rg.bounds.end.x, rg.bounds.position.y), rg.bounds.end, Vector2(rg.bounds.position.x, rg.bounds.end.y)]:
		rg.target = Vector3(c.x, 0, c.y)
		rg.zoom = rg.zoom_max
		rg._apply()
		var n_under := 0
		for sp in [Vector2.ZERO, Vector2(vsz.x, 0), Vector2(0, vsz.y), vsz]:
			var g := rg.screen_to_ground(sp)
			if not Layout.CLOUD_COVER.has_point(Vector2(g.x, g.z)):
				edge_bad += 1
			if not Layout.in_cloud_hole(Vector2(g.x, g.z)):
				n_under += 1
		under = mini(under, n_under) if under > 0 else n_under
	rg.target = cam0[0]
	rg.goal = cam0[1]
	rg.zoom = float(cam0[2])
	rg.zoom_goal = float(cam0[3])
	check(clouds_on and edge_bad == 0 and under >= 2 and s.fishing.act0,
		"G1 nuages : %d bancs posés et une nappe continue dessous, caméra bornée à l'anse (zoom ≤ %d) ; au zoom le plus large, coins de l'écran dans le monde habillé (%d hors), au moins deux sous les nuages (%d)" % [
		dio.clouds.bank_count if dio.clouds != null else 0, int(rg.zoom_max), edge_bad, under])
	var t_pont := tu.idx == _tuto_index("a0_pontoon") and tu._card.visible and String(tu.steps[tu.idx].get("target", "")) == "ctl:upgrade"
	hud.open_upgrades("")
	await _wait(4)
	_f3_track(hud)
	var up: UpgradesSheet = hud.sheet_layer.get_child(0)
	var fish_cards := up.cards.filter(func(c: Dictionary) -> bool: return c.has("fish")).size()
	var dept_cards := up.cards.filter(func(c: Dictionary) -> bool: return c.has("dept")).size()
	var c0 := up._card_for("fish", "places")
	var free_txt := (c0.buy as Button).text if not c0.is_empty() else ""
	var worth := Hud.worthwhile_count(s)
	up._buy_fish("places")
	await _wait(3)
	var site_on := dio.sites.active("fish_places_1")
	up.rebuild()
	await _wait(2)
	var cards2 := up.cards.filter(func(c: Dictionary) -> bool: return c.has("fish")).map(func(c: Dictionary) -> String: return String(c.fish))
	up.close()
	await _wait(3)
	tu._refresh_card(false)
	check(t_pont and fish_cards == 1 and dept_cards == 0 and free_txt.begins_with("RÉPARER") and worth == 1 and f.places == 1 and site_on \
		and s.money == 0.0 and tu.idx == _tuto_index("a0_rent") and cards2 == ["trawler", "places", "services"],
		"G1 Crique : tutoriel « répare le ponton » sur AMÉLIORER (%s), une carte (%d, %d de service, « %s »), ponton réparé (chantier %s), puis les cartes %s ; étape suivante « loyer » (%d)" % [
		t_pont, fish_cards, dept_cards, free_txt.replace("\n", " "), site_on, str(cards2), tu.idx])
	# bateaux : ils arrivent du large et suivent leur boucle (temps ×6) ; le premier rentré attend son loyer (bulle « Loyer »)
	var rects: Array = Layout.anse_obstacles()
	var obs := {"land": 0, "pontoon": 0, "pivot": 0, "frames": 0, "last": {}, "max_vis": 0, "van_off": 0, "van_seen": false}
	Engine.time_scale = 6.0
	var target := -1
	var guard := Time.get_ticks_msec()
	var vr := Rect2(Vector2.ZERO, hud.get_viewport_rect().size)
	var bubble := false
	while target < 0 and Time.get_ticks_msec() - guard < 20000:
		await get_tree().process_frame
		_f3_track(hud)
		_f3_observe(fv, obs, rects, get_process_delta_time())
		for i in fv.collectable():
			if vr.grow(-40.0).has_point(dio.to_screen(fv.boat_pos(i))):
				target = i
				bubble = hud.overlay.frame_rects.has("fish_rent_%d" % i)
				break
	# toucher le bateau rentré : son loyer est encaissé, pièces vers le compteur, « +X $ » ; le tutoriel passe à l'étape suivante
	var rents0 := f.rents_manual
	var pops0 := hud.fish_popups
	var money0 := s.money
	var tp := tu._target(tu.steps[tu.idx]) if tu.idx < tu.steps.size() else {}
	if target >= 0:
		dio._on_tapped(fv.boat_pos(target), Vector2.ZERO)
	await _wait(3)
	_f3_track(hud)
	tu._refresh_card(false)
	check(target >= 0 and bubble and not tp.is_empty() and f.rents_manual == rents0 + 1 and dio.fish_rents_shown >= 1 and hud.fish_popups > pops0 \
		and s.money > money0 and tu.idx > _tuto_index("a0_rent"),
		"G1 loyer à la main : bulle « Loyer » sur le bateau rentré (%s), repère du tutoriel (%s), toucher = encaissé (%d, +%s), « +X $ » (%d), tutoriel suivant (%d)" % [
		bubble, not tp.is_empty(), f.rents_manual - rents0, Fmt.money(s.money - money0), hud.fish_popups - pops0, tu.idx])
	# un bateau qu'on ne touche pas : sa bulle passe au rouge, puis il repart sans payer
	var lost0 := f.rents_lost
	var red := false
	guard = Time.get_ticks_msec()
	while f.rents_lost == lost0 and Time.get_ticks_msec() - guard < 20000:
		await get_tree().process_frame
		_f3_track(hud)
		_f3_observe(fv, obs, rects, get_process_delta_time())
		for i in fv.collectable():
			if f.wait_left(i) < float(f.cfg.rent_warn):
				red = true
	check(f.rents_lost > lost0 and red, "G1 bateau non touché : bulle rouge avant le départ (%s), reparti sans payer (%d)" % [red, f.rents_lost - lost0])
	# Places 2 et la criée (chantiers : la place nouvelle, la criée et sa route) ; Marcel se présente après les loyers à la main ;
	# RESPONSABLES apparaît, sa feuille montre Marcel seul, embauché : plus aucune bulle, Heures sup révélées
	var st0 := dio.sites.started
	s.money += f.places_cost() + f.services_cost()
	s.buy_fish_places(1)
	s.buy_fish_services(1)
	await _wait(2)
	var sites_n := dio.sites.started - st0
	f.rents_manual = int(f.cfg.marcel.after_rents) - 1
	guard = Time.get_ticks_msec()
	while not f.marcel_offered and Time.get_ticks_msec() - guard < 20000:
		await get_tree().process_frame
		_f3_track(hud)
		_f3_observe(fv, obs, rects, get_process_delta_time())
		for i in fv.collectable():
			dio._on_tapped(fv.boat_pos(i), Vector2.ZERO)
	await _wait(3)
	hud._refresh(s)
	tu._refresh_card(false)
	var btn_on := hud.manage_btn.visible and (hud.manage_btn.get_meta("label") as Label).text == "RESPONSABLES" and hud.mgr_pill.visible
	var t_marcel := tu.idx == _tuto_index("a0_marcel")
	hud._on_manage_btn()
	await _wait(4)
	var ms: ManageSheet = hud.sheet_layer.get_child(0)
	var marcel_rows := ms.rows.filter(func(r: Dictionary) -> bool: return r.has("marcel")).size()
	var dept_rows := ms.rows.filter(func(r: Dictionary) -> bool: return r.has("dept")).size()
	var tabs_n := ms.tabs.size() if "tabs" in ms else 1
	s.money += f.marcel_cost()
	ms._hire("marcel", false)
	await _wait(3)
	ms.close()
	await _wait(3)
	hud._refresh(s)
	var boost_off := not s.feature("boost") and not hud.boost_btn.visible      # (lot G1-d : rien de visible avant le port)
	check(sites_n == 2 and f.marcel_offered and btn_on and t_marcel and marcel_rows == 1 and dept_rows == 0 and tabs_n <= 1 and f.marcel \
		and fv.collectable().is_empty() and boost_off and dio.fishing_view.marcel_node != null,
		"G1 Marcel : chantiers de la place et de la criée (%d), il se présente (%s), RESPONSABLES et sa pastille (%s), tutoriel (%s), sa fiche seule (%d, %d de service, %d onglet), embauché : plus de bulle, Heures sup cachées (%s)" % [
		sites_n, f.marcel_offered, btn_on, t_marcel, marcel_rows, dept_rows, tabs_n, boost_off])
	# l'annonce du port (8ᵉ minute, criée faite) : le caboteur traverse au large, la narratrice, MISSIONS et la mission en bandeau
	f.clock = maxf(f.clock, float(f.cfg.announce_at))
	f.last_reveal = -1.0e9
	guard = Time.get_ticks_msec()
	while not f.announced and Time.get_ticks_msec() - guard < 5000:
		await get_tree().process_frame
	await _wait(4)
	var story := hud.story_active()
	var pass_on := fv.passing_active()
	var pass_vis := false
	var pass_hole := 0
	var pass_n := 0
	for k in 240:
		await get_tree().process_frame
		if fv.passing_active():
			var pp := fv.passing.position
			pass_n += 1
			if Layout.in_cloud_hole(Vector2(pp.x, pp.z)):
				pass_hole += 1
			if vr.has_point(dio.to_screen(pp)):
				pass_vis = true
		if pass_vis and pass_n > 30:
			break
	if hud.story_active():
		(hud.story_layer as Button).pressed.emit()
	await _wait(2)
	hud._refresh(s)
	var strip := s.feature("missions") and hud.chest_btn.is_visible_in_tree()
	var first_m: Dictionary = Objectives.visible_missions(s)[0]
	check(f.announced and story and pass_on and pass_vis and pass_hole >= 1 and strip and String(first_m.id) == "c0" and not hud.story_active(),
		"G1 annonce : caboteur au large (%s, à l'écran %s, dans le trou des nuages %d/%d), narratrice (%s), MISSIONS (%s), mission « %s » en tête" % [
		pass_on, pass_vis, pass_hole, pass_n, story, strip, String(first_m.text)])
	# les bâtiments jusqu'à la marina (la camionnette part avec la criée) ; la Concession n'est pas encore signée
	st0 = dio.sites.started
	for bid in ["trawler", "pier", "marina"]:
		s.money += float(f.building_def(bid).cost)
		s.buy_fish_building(bid)
	await _wait(2)
	var sites_b := dio.sites.started - st0
	guard = Time.get_ticks_msec()
	var t_obs := dio._t
	while (dio._t - t_obs < 40.0 or fv.van_trips < 1) and Time.get_ticks_msec() - guard < 25000 and not s.act0_ready():
		await get_tree().process_frame
		_f3_track(hud)
		_f3_observe(fv, obs, rects, get_process_delta_time())
	Engine.time_scale = 1.0
	var spd := 0.0
	for k in fv.speed_seen:
		spd = maxf(spd, float(fv.speed_seen[k]))
	hud.open_upgrades("")
	await _wait(4)
	var up2: UpgradesSheet = hud.sheet_layer.get_child(0)
	var conc_card := not up2._card_for("fish", "concession").is_empty()
	var conc_txt := (up2._card_for("fish", "concession").buy as Button).text if conc_card else ""
	up2.close()
	await _wait(2)
	check(sites_b == 3 and f.sails() == 6 and fv.sailboats.size() == 6 and f.concession_available() and conc_card and not s.act0_ready() \
		and int(obs.land) == 0 and int(obs.pontoon) == 0 and int(obs.pivot) == 0 and spd <= 6.5 \
		and int(obs.max_vis) >= 4 and fv.van_trips >= 1 and bool(obs.van_seen) and int(obs.van_off) == 0,
		"G1 l'anse vivante : chalutiers, jetée, marina (%d chantiers, %d voiliers), la Concession en tête d'AMÉLIORER (« %s ») ; jusqu'à %d bateaux à l'écran, à terre %d, sur un ouvrage %d, rotation sur place %d, vitesse au plus %s u/s ; camionnette partie %d fois, hors de sa route %d" % [
		sites_b, fv.sailboats.size(), conc_txt.replace("\n", " "), int(obs.max_vis), int(obs.land), int(obs.pontoon), int(obs.pivot), Fmt.num(spd), fv.van_trips, int(obs.van_off)])
	# lot H1 — le ponton de service : la pompe et le lavage (Services 6) sur le radeau flottant amarré à la jetée ; un bateau
	# rentré s'y amarre, l'anneau se remplit au-dessus de la station (lisible : ≥ 80 px de diamètre sur 1080), puis éclate en
	# « +X $ » (pièces vers le compteur) ; la marina à l'ouest de la jetée ; mêmes invariants de trajet (ni terre ni ouvrage,
	# aucune rotation sur place, ≤ 6,5 u/s)
	st0 = dio.sites.started
	var add_sv := 6 - f.services
	s.money += f.services_cost(add_sv)
	s.buy_fish_services(add_sv)
	await _wait(2)
	var sites_h := dio.sites.started - st0
	var floating := 0
	var jetty_n := 0
	var raft_n := 0
	for c in fv._static.get_children():
		if c.is_queued_for_deletion() or not String(c.get_meta("site", "")).begins_with("fish_services_") or bool(c.get_meta("cleat", false)):
			continue
		var cp: Vector3 = (c as Node3D).position
		if bool(c.get_meta("jetty", false)):
			jetty_n += 1
		elif bool(c.get_meta("raft", false)):
			raft_n += 1
		elif Layout.raft_rect().has_point(Vector2(cp.x, cp.z)) and cp.y > Layout.WATER_Y and cp.y < 0.0 and not Layout.any_land(Vector2(cp.x, cp.z)):
			floating += 1
	var sails_w := fv.sailboats.all(func(sb: Node3D) -> bool: return sb.position.x < Layout.jetty_rect().position.x and not Layout.any_land(Vector2(sb.position.x, sb.position.z)))
	dio.rig.goal = Vector3(-140.0, 0.0, 28.0)
	dio.rig.target = dio.rig.goal
	dio.rig.zoom_goal = 50.0
	dio.rig.zoom = 50.0
	fv.speed_seen = {}
	obs = {"land": 0, "pontoon": 0, "pivot": 0, "frames": 0, "last": {}, "max_vis": 0, "van_off": 0, "van_seen": false}
	rects = Layout.anse_obstacles()
	Engine.time_scale = 6.0
	var ring_r := Rect2()
	var ring_st := ""
	var served0 := hud.fish_served_n
	var pops1 := hud.overlay.popups_added
	var shown0 := fv.services_shown
	guard = Time.get_ticks_msec()
	while (ring_st == "" or hud.fish_served_n <= served0) and Time.get_ticks_msec() - guard < 30000:
		await get_tree().process_frame
		_f3_track(hud)
		_f3_observe(fv, obs, rects, get_process_delta_time())
		for key in ["ring_fuel", "ring_wash"]:
			if ring_st == "" and hud.overlay.frame_rects.has(key):
				ring_r = hud.overlay.frame_rects[key]
				ring_st = key
	Engine.time_scale = 1.0
	var spd2 := 0.0
	for k in fv.speed_seen:
		spd2 = maxf(spd2, float(fv.speed_seen[k]))
	var vr2 := Rect2(Vector2.ZERO, hud.get_viewport_rect().size)
	check(sites_h >= 2 and jetty_n == 4 and raft_n == 15 and floating == 2 and sails_w and ring_st != "" and ring_r.size.x >= 80.0 \
		and vr2.encloses(ring_r) and hud.fish_served_n > served0 and fv.services_shown > shown0 and hud.overlay.popups_added > pops1 and f.served > 0 \
		and int(obs.land) == 0 and int(obs.pontoon) == 0 and int(obs.pivot) == 0 and spd2 <= 6.5,
		"H1 ponton de service : chantiers %d, jetée %d segments, radeau %d modules, pompe et lavage flottants (%d), voiliers à l'ouest de la jetée (%s) ; anneau « %s » à l'écran (%d px), service payé « +X $ » (%d, pièces %d) ; à terre %d, sur un ouvrage %d, rotation sur place %d, vitesse au plus %s u/s" % [
		sites_h, jetty_n, raft_n, floating, sails_w, ring_st, int(ring_r.size.x), hud.fish_served_n - served0, hud.fish_served_coins, int(obs.land), int(obs.pontoon), int(obs.pivot), Fmt.num(spd2)])
