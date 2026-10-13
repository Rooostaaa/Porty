class_name DebugPanel
extends PanelContainer
## Outils de debug (F1) : argent, vitesse ×10/×100, aléa forcé, palier forcé, affichage des flux.

var flows: Label


func _ready() -> void:
	add_theme_stylebox_override("panel", UI.card_style(Color(0.12, 0.1, 0.25, 0.92), 28, 20))
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	position = Vector2(30, 1000)
	custom_minimum_size = Vector2(1020, 0)
	var v := UI.vbox(10)
	add_child(v)
	v.add_child(UI.label("DEBUG (F1)", 30, UI.AMBER))
	var r1 := UI.hbox(8)
	v.add_child(r1)
	_btn(r1, "+argent ×10", func() -> void: GameState.sim.money = maxf(1000.0, GameState.sim.money * 10.0))
	_btn(r1, "+10 Ambre", func() -> void: GameState.sim.amber += 10)
	_btn(r1, "×1", func() -> void: Sim.speed = 1.0)
	_btn(r1, "×10", func() -> void: Sim.speed = 10.0)
	_btn(r1, "×100", func() -> void: Sim.speed = 100.0)
	var r2 := UI.hbox(8)
	v.add_child(r2)
	for e in GameState.sim.db.events:
		_btn(r2, String(e.id), func() -> void: Hazards.start(GameState.sim, String(e.id)))
	var r3 := UI.hbox(8)
	v.add_child(r3)
	_btn(r3, "Forcer palier", _force_tier)
	_btn(r3, "Tout construire (palier)", _build_all)
	flows = UI.label("", 22, Color.WHITE)
	v.add_child(flows)


func _btn(row: HBoxContainer, t: String, cb: Callable) -> void:
	var b := UI.button(t, UI.VIOLET, 22, 64)
	b.pressed.connect(cb)
	row.add_child(b)


func _force_tier() -> void:
	force_tier(GameState.sim)


static func force_tier(s: PortSim) -> void:
	DebugArgs.force_tier(s)


func _build_all() -> void:
	build_all(GameState.sim)


static func build_all(s: PortSim) -> void:
	DebugArgs.build_all(s)


func _process(_d: float) -> void:
	var s := GameState.sim
	var caps: Dictionary = s.analysis.get("caps", {})
	var t := "vitesse ×%d · goulot %s · t=%s\n" % [Sim.speed, s.analysis.get("key", ""), Fmt.duration(s.time)]
	for k in ["traffic", "pilotage", "berth_cycle", "transfer", "inspection", "gate", "yard_space"]:
		t += "%s %s/min   " % [k, Fmt.num(float(caps.get(k, 0.0)) * 60.0)]
	t += "\nrade %d · tablier %s/%s · parc %s/%s · à inspecter %s · camions %d" % [s.waiting_ships(), Fmt.num(s.apron_stock()), Fmt.num(s.apron_capacity()),
		Fmt.num(s.yard_stock()), Fmt.num(s.yard_capacity()), Fmt.num(s.pending_total()), s.trucks_waiting()]
	flows.text = t
