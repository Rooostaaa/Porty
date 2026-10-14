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
	# écran portrait du téléphone (en --headless la fenêtre par défaut est carrée : les contrôles de cadrage seraient faux)
	get_window().size = Vector2i(540, 960)
	await _wait(2)
	print("  (fenêtre %s, vue %s)" % [str(get_window().size), str(get_viewport().get_visible_rect().size)])
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
	# priorité des touchers : l'engin touché passe avant la grue (plus petit rapport distance / rayon) ; zone grise = bulle
	var dio0 := hud.diorama
	s.features["dept_yard_ops"] = s.time
	s.apron[0] = maxf(s.apron[0], 10.0)
	var cv0: CraneView = dio0.crane_views[0]
	var veh0: Node3D = dio0.traffic.vehicles[0].node if not dio0.traffic.vehicles.is_empty() else null
	var pick_k := ""
	if veh0 != null and not s.ships.is_empty():
		# un navire en déchargement au poste 1 (la grue peut recevoir un coup de main), le temps du contrôle
		var sh0: Ship = s.ships[0]
		var st0 := sh0.state
		var bs0 := int(s.berths[0].ship)
		sh0.state = Ship.State.UNLOADING
		s.berths[0].ship = sh0.id
		veh0.position = cv0.position + Vector3(4.0, 0, 5.0)        # à 6,4 u de la grue (rayon 8), à 0,5 u du point touché
		var tap := veh0.position + Vector3(0.3, 0, 0.4)
		pick_k = "%s (grue %s, engin %s)" % [String(dio0.pick_tap(tap).get("kind", "")), s.assist_ready(cv0.berth), s.yard_boost_ready()]
		sh0.state = st0
		s.berths[0].ship = bs0
	s.features.erase("dept_yard_ops")
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
	check(pick_k.begins_with("vehicle (grue true") and _npop(hud) == pops_z and int(ov.zone_info.get("id", 0)) == 3,
		"toucher : l'engin visé passe avant la grue (%s) ; une zone grise montre une bulle de 2 s, pas une fenêtre" % pick_k)
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
		check(tu.idx >= 2, "le tutoriel passe à l'étape suivante (%d)" % tu.idx)

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
	# gestes optionnels : toucher un engin du parc (il range tout de suite), toucher la barrière (un camion passe)
	s.apron[0] = maxf(s.apron[0], 20.0)
	await _wait(3)
	var veh: Node3D = dio.traffic.vehicles[0].node if not dio.traffic.vehicles.is_empty() else null
	var yb0 := s.counter("yard_boosts")
	if veh != null:
		veh.position = Vector3(-20.3, 0, 17.2)
		dio._on_tapped(veh.position, Vector2.ZERO)
	check(veh != null and s.counter("yard_boosts") == yb0 + 1.0, "toucher un engin du parc : rangement immédiat")
	s.yard_cleared[0] = maxf(s.yard_cleared[0], 30.0)
	s.truck_queue = maxf(s.truck_queue, 10.0)
	var gr0 := s.counter("gate_rushes")
	dio._on_tapped(Vector3(-23.0, 0, 45.0), Vector2.ZERO)
	check(s.counter("gate_rushes") == gr0 + 1.0, "toucher la barrière : un camion passe tout de suite")

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
	check(ns.tier == 1 and ns.built.is_empty(), "la nouvelle concession repart de zéro")
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
	for i in 700:
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
	var far := Vector2(v.position.x, v.position.z).distance_to(Vector2(end_p.x, end_p.z)) < 0.5 and v.position.z < -150.0
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
	check(not bool(a0.can) and bool(a1.can) and String(a1.kind) == "dept" and btn1.begins_with("AMÉLIORER PARC · ") and btn1.ends_with("$")
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
	var base1 := s.income_estimate_with("harbor", 0)
	for d in PortSim.DEPTS:
		if s.feature("dept_" + d) and s.dept_cost(d, 1) <= s.money and s.upgrade_gain(d, 1, -1, base1) > 0.0:
			n_dept += 1
	check(n_nofee < raw and n_dept == raw and n_aff >= n_dept,
		"D-UI 2 / D-Éco : la pastille ne compte que les achats qui rapportent (sans services facturés %d sur %d services abordables ; avec : %d, pastille %d)" % [n_nofee, raw, n_dept, n_aff])
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
		if l is Label and (l as Label).text.begins_with("Le département"):
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
	var near := not rr.has_area() or not hud.overlay.useful.grow(-120.0).has_point(ras) or rr.get_center().distance_to(ras) < 260.0
	hud.open_upgrades("")
	await _wait(4)
	var up2: UpgradesSheet = hud.sheet_layer.get_child(0)
	var help_again := false
	for l in up2.content.get_children():
		if l is Label and (l as Label).text.begins_with("Le département"):
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
	var kept: bool = int(sfx.get("dropped")) == d0 + 1 or not all_busy
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
	s.boost_ready_at = s.time - 1.0
	s.boost_until = s.time - 1.0
	hud._on_boost()
	hud._refresh(s)
	var ot: Variant = hud.diorama.get("overtime_on")
	var camp_ok := true
	for c in Commerce.campaigns(s):
		if Commerce.campaign_available(s, c) and Commerce.campaign_ready(s, String(c.id)):
			s.money = maxf(s.money, Commerce.campaign_cost(s, String(c.id)) + 1.0)
			Commerce.start_campaign(s, String(c.id))
			hud._refresh(s)
			var co: Variant = hud.diorama.get("campaign_on")
			camp_ok = co == null or bool(co)
			break
	check((ot == null or bool(ot)) and camp_ok, "D-UI 4 : Heures sup et campagne envoyées au monde (heures sup %s, campagne %s)" % [str(ot), str(hud.diorama.get("campaign_on"))])


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
	dio._on_ship_state(sh)
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
		check(deck_low >= 1 and n_high > n_low and n_high <= Diorama.CROWD_MAX and shown > 0 and shown <= Diorama.CROWD_MAX,
			"D-Monde : dockers au déchargement — %d puis %d avec plus d'agents (plafond %d), dont %d sur le pont, %d affichés" % [n_low, n_high, Diorama.CROWD_MAX, deck_low, shown])
	# conteneurs posés : un conteneur qui arrive sur le tablier descend à sa place au lieu d'apparaître d'un coup
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
