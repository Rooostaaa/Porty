extends Node
## Point d'entrée : assemble le diorama 3D et l'interface.
## Arguments utiles (après --) : --fresh, --capture=chemin.png --delay=6, --look=x,z, --zoom=40, --open=upgrades|manage|missions|contracts ;
## depuis le binaire de l'éditeur seulement (DebugArgs.allowed) : --speed=10, --debug-money=1e6, --tier=3, --levels=N, --build-all, --hire-all, --build=…

var diorama: Diorama
var hud: Hud


func _ready() -> void:
	var a := Capture.args()
	if a.has("fresh"):
		Settings.persist_tuto = false
		Settings.tuto_step = 0
		Settings.intro_seen = a.has("skip-intro")      # lot F2 : une partie de test montre les cartes d'intro
		Save.enabled = false
		GameState.new_game()
		GameState.offline_report = {}
	# capture d'une partie de bot réelle (tests/bot_saves.gd) : charge ce fichier, jamais la vraie sauvegarde (avec --fresh,
	# la sauvegarde automatique est coupée)
	if a.has("load-sim") and a.has("fresh") and DebugArgs.allowed():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(a["load-sim"])))
		if d is Dictionary and (d as Dictionary).has("sim"):
			GameState.load_from(d.sim)
	if a.has("tuto-step"):
		Settings.tuto_step = int(a["tuto-step"])
	# triches (--debug-money, --tier, --levels…) : seulement en version de débogage
	var cheats := DebugArgs.apply(a, GameState.sim, GameState.db, DebugArgs.allowed())
	if float(cheats.speed) > 0.0:
		Sim.speed = float(cheats.speed)
	# lot F2 : le départ (cartes d'intro, friche, chantiers du T1) se joue pour une partie neuve ; pas pour une partie trichée
	# (palier, bâtiments), ni pour une capture, sauf si elle le demande (--start)
	if GameState.sim.tier > 1 or not GameState.sim.built.is_empty() or (a.has("capture") and not a.has("start")) or a.has("no-start"):
		GameState.start_pending = false
		# lot F3 : une partie trichée ou une capture sans départ a fait l'acte 0 (la pêche de l'anse tourne, passive)
		if not GameState.sim.fishing.concession_done() and not a.has("load-sim"):
			GameState.sim.fishing.migrate_done()
	# --event=wind [--event-delay=3] : un aléa démarre après quelques secondes (captures, binaire de l'éditeur seulement ; lot E)
	if a.has("event") and DebugArgs.allowed():
		get_tree().create_timer(float(a.get("event-delay", "3"))).timeout.connect(func() -> void:
			if GameState.sim.db.event_by_id.has(String(a.event)):
				Hazards.start(GameState.sim, String(a.event)))
	diorama = Diorama.new()
	add_child(diorama)
	diorama.bind(GameState.sim)
	GameState.sim_replaced.connect(diorama.bind)
	if a.has("look"):
		var xz := String(a.look).split(",")
		diorama.rig.focus(Vector3(float(xz[0]), 0, float(xz[1])))
		diorama.rig.target = diorama.rig.goal
	if a.has("zoom"):
		diorama.rig.zoom_goal = float(a.zoom)
		diorama.rig.zoom = diorama.rig.zoom_goal
	if a.has("capture"):      # capture automatique : la souris ne doit pas pouvoir déplacer la caméra
		diorama.rig.input_enabled = false
		diorama.rig.locked = a.has("look")      # --look fixe le cadrage : les recentrages du jeu sont ignorés
	if a.has("ship-demo") and DebugArgs.allowed():   # captures du lot F1 : --ship-demo=coaster:0:0 (classe, place, poste)
		var sd := String(a["ship-demo"]).split(":")
		diorama.demo_ship(sd[0], int(sd[1]) if sd.size() > 1 else 0, int(sd[2]) if sd.size() > 2 else 0)
	if a.has("open-zone") and DebugArgs.allowed():   # capture d'une ouverture de zone (--open-zone=10 après --build=berth3)
		diorama.opening_queue.append(int(a["open-zone"]))
	if a.has("site") and DebugArgs.allowed():        # capture d'un chantier (lot F2 : --site=berth2 après --build=berth2)
		var sid := String(a["site"])
		get_tree().create_timer(float(a.get("site-delay", "0.5"))).timeout.connect(func() -> void:
			diorama.start_site(sid)
			diorama.rebuild())      # (comme après un achat : les accessoires du bâtiment attendent la fin du chantier)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.diorama = diorama
	layer.add_child(hud)
	# lot G1 (captures, binaire de l'éditeur seulement) : --places=N --services=N --fish-build=trawler,pier,marina --marcel
	# --announce --act0-warm=S (la pêche tourne S s avant le dernier achat : bateaux en place, chantiers finis) --rent (un
	# bateau attend son loyer) --bascule (la Concession est signée : la bascule se joue).
	if DebugArgs.allowed() and GameState.sim.fishing.act0 and (a.has("places") or a.has("services") or a.has("fish-build") 			or a.has("marcel") or a.has("announce") or a.has("bascule") or a.has("act0-warm") or a.has("rent")):
		var s := GameState.sim
		var f := s.fishing
		var warm := float(a.get("act0-warm", "0"))
		var np := int(a.get("places", "1"))
		s.money += f.places_cost(np) if np > 0 else 0.0
		s.buy_fish_places(np)
		var ns := int(a.get("services", "0"))
		if ns > 0:
			s.money += f.services_cost(ns)
			s.buy_fish_services(ns)
		for bid in String(a.get("fish-build", "")).split(",", false):
			s.money += float(f.building_def(bid).get("cost", 0.0))
			s.buy_fish_building(bid)
		if a.has("marcel"):
			f.marcel_offered = true
			if String(a.marcel) != "offer":
				s.money += f.marcel_cost()
				s.hire_marcel()
		if warm > 0.0:
			for i in int(warm / 0.25):
				s.step(0.25)
			diorama.sites.clear()
			diorama.fishing_view.rebuild()
			for v in diorama.fishing_view.boats:
				v.fresh = false
				v.fade = 1.0
		if a.has("rent"):
			var guard := 0
			while guard < 2000 and diorama.fishing_view.collectable().is_empty():
				s.step(0.25)
				guard += 1
				var any := false
				for i in f.boats.size():
					any = any or f.can_collect(i)
				if any:
					break
			for v in diorama.fishing_view.boats:
				v.fresh = false
				v.fade = 1.0
		if a.has("announce"):
			f.clock = maxf(f.clock, float(f.cfg.get("announce_at", 480.0)))
			f.last_reveal = -1.0e9
			s.step(0.25)
		if a.has("bascule"):
			for bid in ["trawler", "pier", "marina"]:
				if not f.has(bid):
					s.money += float(f.building_def(bid).get("cost", 0.0))
					s.buy_fish_building(bid)
			# la Concession une seconde après le départ : les nuages sont posés, on les voit se dissoudre
			get_tree().create_timer(float(a.get("bascule-delay", "1"))).timeout.connect(func() -> void:
				s.money += float(f.concession_def().get("cost", 1000.0))
				s.buy_fish_building(String(f.concession_def().id)))
	if a.has("open"):
		await get_tree().create_timer(float(a.get("open-delay", "1"))).timeout
		match String(a.open):
			"upgrades":
				hud.open_upgrades("")
			"manage":
				hud.open_sheet(ManageSheet.new(int(a.get("tab", "0"))))
			"missions":
				hud.open_sheet(MissionsSheet.new())
			"contracts":
				hud.open_sheet(CommerceSheet.new(CommerceSheet.TAB_CONTRACTS))
			"commerce":
				hud.open_sheet(CommerceSheet.new(int(a.get("tab", "0"))))
			"debug":
				if DebugArgs.allowed():
					hud.toggle_debug()
			"settings":
				hud.open_sheet(SettingsSheet.new())
			"hint":           # carte Goulot dépliée (captures)
				hud.hint_text.visible = true
			"tier":           # cérémonie du palier courant (captures, débogage seulement)
				if DebugArgs.allowed():
					hud._on_tier(GameState.sim.tier)
			"shippaid":       # encaissement d'un navire au poste n°1 (captures, débogage seulement)
				if DebugArgs.allowed() and diorama.has_signal("ship_paid"):
					var amount := GameState.sim.avg_value_per_evp() * 400.0
					diorama.emit_signal("ship_paid", Vector3(Layout.berth_center(0), 8.0, Layout.QUAY_Z), amount)
	Capture.schedule(self)


func _unhandled_input(event: InputEvent) -> void:
	if hud.any_sheet_open():
		return
	diorama.rig.handle_input(event)
