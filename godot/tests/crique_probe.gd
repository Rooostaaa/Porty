extends SceneTree
## Lot G1 — sonde de la Crique : le bot joue le chapitre 1 sur 4 graines, « tranquille » (plafond R₀ puis Concession) et
## « pressé » (Concession dès la marina) ; chronologie des achats, loyers, revenu R₀.
##   godot --headless --path godot --script res://tests/crique_probe.gd [-- --seeds=1,2,3,4 --verbose]


func _init() -> void:
	var seeds := [1, 2, 3, 4]
	var verbose := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = []
			for x in a.substr(8).split(","):
				seeds.append(int(x))
		if a == "--verbose":
			verbose = true
	var db := DataDB.new()
	var f0 := Fishing.new(db)
	print("Plafond R₀ (tout au maximum) : %s $/s · ticket max ×%s · voiliers %d" % [Fmt.num(f0.cap_rate()), Fmt.num(1.0 + float(f0.cfg.ticket_step) * float(f0.services_max())), 20])
	var tot := {"calm": 0.0, "hurry": 0.0}
	for sd in seeds:
		for mode in ["calm", "hurry"]:
			var sim := PortSim.new(db, sd)
			sim.begin_act0()
			var bot := preload("res://tests/bot.gd").new(sim)
			bot.hurry = mode == "hurry"
			var d := bot.run_act0()
			tot[mode] = float(tot[mode]) + d
			var f := sim.fishing
			print("g%d %-8s %s · revenu à la Concession %s/s · argent %s · places %d, services %d, bâtiments %s · Marcel %s · %d escales, %d loyers à la main, %d perdus · annonce %s" % [
				sd, mode, Fmt.duration(d), Fmt.num(bot.act0_end_rate), Fmt.money(sim.money), f.places, f.services, str(f.built), f.marcel,
				f.landings, f.rents_manual, f.rents_lost, f.announced])
			print("     ponton de service (lot H1) : %d services rendus, %d tours passés, service %s s" % [f.served, f.skipped, Fmt.num(f.service_dur())])
			if verbose or true:
				print("     " + " · ".join(bot.act0_buys))
	print("moyenne tranquille %s · pressé %s" % [Fmt.duration(float(tot.calm) / float(seeds.size())), Fmt.duration(float(tot.hurry) / float(seeds.size()))])
	quit()
