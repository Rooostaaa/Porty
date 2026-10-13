extends SceneTree
## Chronologie d'équilibrage jusqu'à la fin du MVP :
##   godot --headless --path godot --script res://tests/balance.gd

const Bot := preload("res://tests/bot.gd")


func _init() -> void:
	var db := DataDB.new()
	var seeds := [1, 2, 3]
	var results: Array = []
	for sd in seeds:
		var sim := PortSim.new(db, sd)
		var bot := Bot.new(sim)
		var next_report := 60.0
		print("\n=== Partie graine %d ===" % sd)
		while sim.time < 3.0 * 3600.0 and not sim.finished:
			bot.run(10.0)
			if sim.time >= next_report:
				next_report += 300.0 if sim.time > 900.0 else 60.0
				print("%8s  T%d  %s  rev %s/min  %s EVP  %.1f★  goulot=%s  niv=%s" % [
					Fmt.duration(sim.time), sim.tier, Fmt.money(sim.money), Fmt.num(sim.income_per_min()),
					Fmt.num(sim.counter("evp")), sim.stars(), sim.analysis.key, _levels(sim)])
		for l in bot.log_lines:
			print(l)
		var early: Array = []
		for p in bot.purchases:
			if p.t < 300.0:
				early.append(p.t)
		var gaps: Array = []
		for i in range(1, early.size()):
			gaps.append(early[i] - early[i - 1])
		var avg_gap := 0.0
		for g in gaps:
			avg_gap += g
		avg_gap /= maxi(1, gaps.size())
		print("Achats < 5 min : %d, intervalle moyen %.1f s" % [early.size(), avg_gap])
		print("Navires furieux : %d, déroutés : %d, saisies : %d, incidents : %d" % [
			sim.counter("ships_angry"), sim.counter("turned_away"), sim.counter("seizures"), sim.counter("incidents")])
		results.append(bot.milestones)
	print("\n=== Cibles ===")
	print("Premier achat < 20 s · premier responsable 3–4 min · T2 8–12 min · T3 +35–50 min · fin 1 h – 1 h 30")
	for m in results:
		var line := ""
		for k in m:
			if k.begins_with("Premier achat") or k.begins_with("Palier") or k.begins_with("FIN") or k.begins_with("Responsable"):
				line += "%s=%s  " % [k.substr(0, 28), Fmt.duration(m[k])]
		print(line)
	quit()


func _levels(sim: PortSim) -> String:
	var s := ""
	for d in PortSim.DEPTS:
		s += "%s%d " % [d.substr(0, 2), sim.levels[d]]
	return s + "lic%d" % sim.licences[0]
