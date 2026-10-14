extends SceneTree
## Parties de bot réelles pour les captures (revue du 13/10, important 14 : plus de captures forcées par --tier / --levels).
## Joue une partie avec le bot d'équilibrage et écrit des sauvegardes (format de Save, version courante) aux moments
## voulus, dans un dossier temporaire — jamais la vraie sauvegarde du joueur. Une capture les charge ensuite :
##   godot --headless --path godot --script res://tests/bot_saves.gd -- --out=C:/tmp/saves [--seed=1]
##   godot --path godot -- --fresh --load-sim=C:/tmp/saves/t2.json --capture=… (version de débogage)
const Bot := preload("res://tests/bot.gd")


func _init() -> void:
	var out := ""
	var seed_v := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		if a.begins_with("--seed="):
			seed_v = int(a.substr(7))
	if out == "":
		printerr("--out=dossier requis")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var db := DataDB.new()
	var sim := PortSim.new(db, seed_v)
	Objectives.refresh_offers(sim)
	var bot := Bot.new(sim)
	var reveal := {}
	sim.feature_unlocked.connect(func(id: String) -> void: reveal[id] = sim.time)
	var built_at := {}
	sim.purchased.connect(func(kind: String, id: String) -> void:
		if kind == "building":
			built_at[id] = sim.time)
	var tier_at := {}
	# moments : nom -> condition (évaluée chaque seconde) ; chaque sauvegarde est écrite une fois
	var due := {
		"t1_depart": func() -> bool: return sim.time >= 0.5,
		"chapitre1": func() -> bool: return sim.time >= 100.0,
		"chapitre2": func() -> bool: return reveal.has("dept_yard_ops") and sim.time >= float(reveal.dept_yard_ops) + 20.0,
		"chapitre3": func() -> bool: return reveal.has("dept_gate") and sim.time >= float(reveal.dept_gate) + 20.0,
		"chenal": func() -> bool: return built_at.has("dredge1") and sim.time >= float(built_at.dredge1) + 45.0,
		"t2": func() -> bool: return tier_at.has(2) and sim.time >= float(tier_at[2]) + 150.0,
		"camion": func() -> bool: return tier_at.has(2) and sim.time >= float(tier_at[2]) + 420.0,
		"t3_avant_quai3": func() -> bool: return tier_at.has(3) and not built_at.has("berth3") and sim.time >= float(tier_at[3]) + 20.0,
		"ouverture_terre_plein": func() -> bool: return built_at.has("berth3"),
		"t3": func() -> bool: return tier_at.has(3) and sim.time >= float(tier_at[3]) + 240.0,
	}
	var written := {}
	var tick := float(db.cfg("tick"))
	var acc := 0.0
	while sim.time < 3.0 * 3600.0 and written.size() < due.size() and not sim.finished:
		if sim.time >= 1.0 or written.has("t1_depart"):
			sim.step(tick)
			acc += tick
			if acc >= 1.0:
				acc -= 1.0
				bot.think()
		else:
			sim.step(tick)
		if not tier_at.has(sim.tier):
			tier_at[sim.tier] = sim.time
		for k in due:
			if not written.has(k) and bool((due[k] as Callable).call()):
				var d := {"version": 5, "saved_at": 0, "sim": sim.to_dict()}      # (Save.VERSION : l'autoload n'existe pas ici)
				var f := FileAccess.open(out.path_join(k + ".json"), FileAccess.WRITE)
				f.store_string(JSON.stringify(d))
				f.close()
				written[k] = sim.time
				print("sauvegarde %s à %s (palier %d, %s)" % [k, Fmt.duration(sim.time), sim.tier, Fmt.money(sim.money)])
	quit()
