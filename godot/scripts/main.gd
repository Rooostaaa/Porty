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
	if a.has("open-zone") and DebugArgs.allowed():   # capture d'une ouverture de zone (--open-zone=10 après --build=berth3)
		diorama.opening_queue.append(int(a["open-zone"]))
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.diorama = diorama
	layer.add_child(hud)
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
