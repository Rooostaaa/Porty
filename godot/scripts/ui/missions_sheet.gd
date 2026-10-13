class_name MissionsSheet
extends Sheet
## Missions : objectifs courts récompensés en Ambre (bouton RÉCLAMER grisé tant que non atteint).

var rows: Array[Dictionary] = []
var _sig := ""


func _init() -> void:
	super._init("Missions")


func build() -> void:
	rows.clear()
	var s := sim()
	_sig = ",".join(s.missions_claimed)
	content.add_child(UI.wrap_label("L'Ambre sert à embaucher un responsable en avance ou à relancer les Heures sup. " \
		+ "Les objectifs de carrière ★ comptent toutes tes concessions et ne s'arrêtent jamais.", 28))
	var vis := Objectives.visible_missions(s)
	if vis.is_empty():
		content.add_child(UI.label("Toutes les missions sont accomplies !", 34, UI.MONEY))
	for m in vis:
		var c := UI.card()
		content.add_child(c)
		var v := UI.vbox(10)
		c.add_child(v)
		var h := UI.hbox(14)
		v.add_child(h)
		h.add_child(UI.icon_disc("missions", UI.VIOLET, 90))
		var t := UI.wrap_label(("★ " if m.get("career", false) else "") + String(m.text), 34, UI.TEXT)
		h.add_child(t)
		var rw := UI.hbox(6)
		rw.add_child(UI.icon("amber", 48, Color.WHITE))
		rw.add_child(UI.label("+%d" % int(m.amber), 34, UI.AMBER, true))
		h.add_child(rw)
		var h2 := UI.hbox(14)
		v.add_child(h2)
		var bar := RoundBar.new(44)
		bar.color = UI.INFO
		h2.add_child(bar)
		var b := UI.button("RÉCLAMER", UI.MONEY, 30, 96)
		b.custom_minimum_size.x = 230
		b.pressed.connect(_claim.bind(String(m.id)))
		h2.add_child(b)
		rows.append({"m": m, "bar": bar, "btn": b})


func _claim(id: String) -> void:
	var btn: Button = null
	for r in rows:
		if String(r.m.id) == id:
			btn = r.btn
	var amber := 0
	for r in rows:
		if String(r.m.id) == id:
			amber = int(r.m.amber)
	if Objectives.claim(sim(), id):
		Sfx.play("coin")
		if btn != null:
			Fx.reward(btn, "+%d Ambre" % amber, UI.AMBER, true)
	rebuild()


func refresh() -> void:
	var s := sim()
	if ",".join(s.missions_claimed) != _sig:
		rebuild()
		return
	for r in rows:
		var p := Objectives.mission_progress(s, r.m)
		var t := float(r.m.target)
		(r.bar as RoundBar).value = p / t
		(r.bar as RoundBar).text = "%s / %s" % [Fmt.num(minf(p, t)), Fmt.num(t)]
		(r.btn as Button).disabled = p < t
