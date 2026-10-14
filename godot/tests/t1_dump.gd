extends SceneTree
## Achats du bot au palier 1 (temps, quoi, argent restant) et révélations : pour comprendre les trous d'achat.
const Bot := preload("res://tests/bot.gd")

func _init() -> void:
	var seeds := [1]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = []
			for x in a.substr(8).split(","):
				seeds.append(int(x))
	var db := DataDB.new()
	for sd in seeds:
		var sim := PortSim.new(db, sd)
		var bot := Bot.new(sim)
		var rev := []
		sim.feature_unlocked.connect(func(id: String) -> void: rev.append("%s@%s" % [id, Fmt.duration(sim.time)]))
		while sim.tier < 2 and sim.time < 1800.0:
			bot.run(1.0)
		var line := ""
		var last := 0.0
		for p in bot.purchases:
			var gap: float = float(p.t) - last
			line += "%s%s %s:%s\n" % ["  <<< %ds  " % int(gap) if gap > 60.0 else "  ", Fmt.duration(p.t), p.kind, p.id]
			last = float(p.t)
		print("=== graine %d (T2 %s) ===\n%s" % [sd, Fmt.duration(sim.time), line])
		print("révélations : " + " · ".join(rev))
	quit()
