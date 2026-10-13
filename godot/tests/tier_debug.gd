extends SceneTree
## Diagnostic : état des conditions du palier suivant au fil du temps (T2 → T3).

const Bot := preload("res://tests/bot.gd")


func _init() -> void:
	var db := DataDB.new()
	var sim := PortSim.new(db, 2024)
	var bot := Bot.new(sim)
	var next := 120.0
	while sim.time < 3000.0 and not sim.finished:
		bot.run(10.0)
		if sim.time >= next:
			next += 180.0
			var s := "%8s T%d $%s " % [Fmt.duration(sim.time), sim.tier, Fmt.money(sim.money)]
			for c in sim.tier_check():
				s += " | %s %s/%s %s" % [String(c.label).left(10), Fmt.num(float(c.have)), Fmt.num(float(c.need)), "OK" if c.ok else "--"]
			s += " | flow %s/min goulot=%s" % [Fmt.num(sim.sustainable_flow() * 60.0), sim.analysis.key]
			print(s)
	quit()
