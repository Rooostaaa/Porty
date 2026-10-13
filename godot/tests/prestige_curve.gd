extends SceneTree
## Courbe de prestige : durée de chaque concession successive avec le joueur automatique.
##   godot --headless --path godot --script res://tests/prestige_curve.gd

const Bot := preload("res://tests/bot.gd")


func _init() -> void:
	var db := DataDB.new()
	var sim := PortSim.new(db, 2024)
	print("Concession  Renom  durée   T2       T3       gain suivant")
	for n in 5:
		var bot := Bot.new(sim)
		bot.run(4.0 * 3600.0)
		var t2: float = bot.milestones.get("Palier T2 atteint", -1.0)
		var t3: float = bot.milestones.get("Palier T3 atteint", -1.0)
		print("%5d       %3d    %s  %s  %s  +%d" % [n + 1, sim.renown, Fmt.duration(sim.time),
			Fmt.duration(t2), Fmt.duration(t3), sim.prestige_gain()])
		var nxt := PortSim.new(db, 100 + n)
		nxt.carry_over(sim)
		sim = nxt
	quit()
