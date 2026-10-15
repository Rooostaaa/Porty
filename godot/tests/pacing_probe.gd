extends SceneTree
## Sonde de rythme : demande et capacité, goulots, achats, conditions de palier, revenu après chaque palier,
## croissance du revenu minute par minute et rentabilité du meilleur achat (écarts ISM).
##   godot --headless --path godot --script res://tests/pacing_probe.gd [-- --seeds=1,2,3 --verbose --brief]

const Bot := preload("res://tests/bot.gd")
const PAYBACK_EVERY := 30.0      # secondes de jeu entre deux mesures de rentabilité


func _service_cap(caps: Dictionary) -> float:
	var v := INF
	for k in ["pilotage", "berth_cycle", "transfer", "inspection", "gate", "yard_space"]:
		v = minf(v, float(caps.get(k, INF)))
	return v


## Temps de retour (s) du meilleur achat de niveau (départements et licences) : coût ÷ gain de revenu par seconde.
func _best_payback(sim: PortSim) -> Array:
	var base := sim.income_estimate_with("harbor", 0)
	var best := INF
	var what := "-"
	for d in PortSim.DEPTS:
		if not sim.feature("dept_" + d):
			continue
		var g := sim.upgrade_gain(d, 1, -1, base)
		if g > 0.0:
			var p := sim.dept_cost(d, 1) / g
			if p < best:
				best = p
				what = d
	if sim.feature("licences"):
		for ci in PortSim.NCARGO:
			if sim.unlocked[ci] == 1 and sim.licence_room(ci) > 0:
				var g2 := sim.upgrade_gain("", 1, ci, base)
				if g2 > 0.0:
					var p2 := sim.licence_cost(ci, 1) / g2
					if p2 < best:
						best = p2
						what = "lic_" + String(sim.db.cargo[ci].short)
	# contenu : bâtiments disponibles, lignes, armateurs (état modifié puis rétabli ; les postes à quai sont recopiés :
	# reconstruire l'infrastructure désassocierait les navires qui appareillent)
	var saved_berths := sim.berths.duplicate(true)
	for b in sim.db.buildings:
		if sim.building_state(b.id) != "available":
			continue
		sim.built.append(b.id)
		sim.rebuild_infra()
		var g3 := sim.income_estimate_with("harbor", 0) - base
		sim.built.pop_back()
		sim.rebuild_infra()
		sim.berths = saved_berths.duplicate(true)
		if g3 > 0.0 and float(b.cost) / g3 < best:
			best = float(b.cost) / g3
			what = "bât_" + String(b.id)
	if sim.feature("commerce"):
		for o in sim.db.owners:
			if Commerce.line_available(sim, o.id):
				sim.lines[o.id] = int(sim.lines.get(o.id, 0)) + 1
				var g4 := sim.income_estimate_with("harbor", 0) - base
				sim.lines[o.id] = int(sim.lines[o.id]) - 1
				if int(sim.lines[o.id]) == 0:
					sim.lines.erase(o.id)
				if g4 > 0.0 and Commerce.line_cost(sim, o.id) / g4 < best:
					best = Commerce.line_cost(sim, o.id) / g4
					what = "ligne_" + String(o.id)
			if Commerce.recruit_state(sim, o.id) == "available":
				sim.owners_on[o.id] = true
				var g5 := sim.income_estimate_with("harbor", 0) - base
				sim.owners_on.erase(o.id)
				if g5 > 0.0 and float(o.recruit) / g5 < best:
					best = float(o.recruit) / g5
					what = "armateur_" + String(o.id)
	sim.income_estimate_with("harbor", 0)
	return [best, what]


func _patch(db: DataDB, path: PackedStringArray, value: Variant, mul: bool = false) -> void:
	var roots := {"config": db.config, "cargo": db.cargo, "tiers": db.tiers, "buildings": db.buildings, "departments": db.departments,
		"owners": db.owners, "ships": db.ships, "missions": db.missions, "unlocks": db.unlocks}
	var nodes: Array = [roots[path[0]]]
	for i in range(1, path.size() - 1):
		var nxt: Array = []
		for n in nodes:
			var seg := path[i]
			if n is Array:
				if seg == "*":
					nxt.append_array(n)
				elif seg.is_valid_int():
					nxt.append(n[int(seg)])
				elif seg.begins_with("?"):
					var f := seg.substr(1).split(":")
					for e in n:
						if e is Dictionary and e.has(f[0]) and (float(e[f[0]]) == float(f[1]) if f[1].is_valid_float() else str(e[f[0]]) == f[1]):
							nxt.append(e)
				else:
					for e in n:
						if e is Dictionary and String(e.get("id", "")) == seg:
							nxt.append(e)
			else:
				nxt.append(n[seg])
		nodes = nxt
	for n in nodes:
		var k: Variant = int(path[-1]) if n is Array else path[-1]
		n[k] = float(n[k]) * float(value) if mul else value
	print("réglage %s %s %s (%d)" % [".".join(path), "×" if mul else "=", str(value), nodes.size()])


func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


func _dur(v: float) -> String:
	return "∞" if is_inf(v) else Fmt.duration(v)


func _init() -> void:
	var seeds := [1, 2, 3]
	var verbose := false
	var brief := false
	var curve := OS.get_cmdline_user_args().has("--curve")   # revenu toutes les 30 s (moyenne sur 60 s), goulot, argent
	var max_t := 3.0 * 3600.0                                 # --maxh=2 : arrêt après 2 h de jeu (essais)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--maxh="):
			max_t = float(a.substr(7)) * 3600.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = []
			for x in a.substr(8).split(","):
				seeds.append(int(x))
		if a == "--verbose":
			verbose = true
		if a == "--brief":
			brief = true
	var db := DataDB.new()
	# essais sans toucher aux fichiers : --set=config.licence_per_level=0.1 · --set=tiers.1.value_mult=4
	# · --set=cargo.*.licence_growth=1.08 · --set=buildings.berth3.cost=4e8 (un segment non numérique désigne l'élément de cet id)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--set="):
			var kv := a.substr(6).split("=", true, 1)
			_patch(db, kv[0].split("."), JSON.parse_string(kv[1]))
		if a.begins_with("--mul="):
			var kv2 := a.substr(6).split("=", true, 1)
			_patch(db, kv2[0].split("."), float(kv2[1]), true)
	var table: Array[String] = []
	for sd in seeds:
		var sim := PortSim.new(db, sd)
		var bot := Bot.new(sim)
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--bot-save="):
				bot.save_horizon = float(a.substr(11))
		# lot F3 : le bot joue l'acte 0 (pêche), puis tout se mesure depuis l'entrée au T1 (l'horloge du port, `sim.time`,
		# ne tourne pas pendant l'acte 0) ; durée sans coup de main sur une partie à part, même graine (--no-act0 : base F2)
		var a0_line := ""
		if not OS.get_cmdline_user_args().has("--no-act0"):
			sim.begin_act0()
			var a0 := bot.run_act0()
			var m_t1 := sim.money
			var sim2 := PortSim.new(db, sd)
			sim2.begin_act0()
			var bot2 := Bot.new(sim2)
			bot2.use_manual = false
			var a0n := bot2.run_act0()
			a0_line = "     acte 0 : %s (sans coup de main %s) · achats %s · %d débarques, %d coups de main · argent à l'entrée du T1 %s · revenu de fin %s/s, passif %s/s" % [
				Fmt.duration(a0), Fmt.duration(a0n), " / ".join(bot.act0_buys.map(func(x: float) -> String: return Fmt.duration(x))),
				sim.fishing.landings, sim.fishing.helps, Fmt.money(m_t1), Fmt.num(bot.act0_end_rate), Fmt.num(sim.fishing.passive_rate())]
			print("g%d %s" % [sd, a0_line.strip_edges()])
		var keys := {}               # goulot -> secondes, par palier
		var excess := {}             # palier -> secondes où demande > 1,5 × capacité
		var alert_t := {}            # palier -> secondes où la carte Goulot est en alerte (rouge)
		var alert_why_t := {}        # « T2:rade » -> nombre de relevés
		var tier_time := {}
		var last_ta := 0.0
		var rows: Array = []
		var samples: Array = []      # [t, palier, revenu/min] toutes les 10 s
		var paybacks := {}           # palier -> [s]
		var pb_what := {}            # palier -> {quoi: n}
		var pb_log: Array = []       # [t, rentabilité, quoi] (--curve)
		var next_pb := 0.0
		var tier_start := {1: 0.0}
		var cond_ok := {}
		var last_tier := 1
		var lic_at := {}             # repère -> niveau de la licence Standard
		var op := [0.0]              # revenu d'exploitation des 10 dernières secondes (hors primes de contrat et enchères)
		sim.revenue.connect(func(amount: float, source: String) -> void:
			if source != "contract" and source != "auction":
				op[0] += amount)
		var op_hist: Array = []      # revenu d'exploitation par tranche de 10 s
		var dry := [0.0, 0.0]        # T1 : début de la période sans rien d'abordable, plus longue période
		var pre_chapter := {"yard_ops": 0.0, "gate": 0.0}   # secondes où le parc / la gate sont le goulot avant leur chapitre
		var reveal := {}             # fonction révélée -> instant
		sim.feature_unlocked.connect(func(id: String) -> void: reveal[id] = sim.time)
		var tier_at := {}            # palier -> instant exact du passage
		sim.tier_changed.connect(func(t: int) -> void: tier_at[t] = sim.time)
		var banners: Array = []      # instants des bandeaux (révélations et « premier navire d'une classe »)
		var banner_ids: Array = []
		sim.feature_unlocked.connect(func(id: String) -> void:
			banners.append(sim.time)
			banner_ids.append(id))
		sim.ship_class_first.connect(func(s: Ship) -> void:
			banners.append(sim.time)
			banner_ids.append("navire " + String(s.cls)))
		while sim.time < max_t and not sim.finished:
			bot.run(10.0)
			var caps: Dictionary = sim.analysis.caps
			var dem := float(caps.traffic)
			var cap := _service_cap(caps)
			var tk := "T%d" % sim.tier
			if sim.tier != last_tier:
				tier_start[sim.tier] = float(tier_at.get(sim.tier, sim.time))
				lic_at["T%d" % sim.tier] = sim.licences[0]
				lic_at["niv T%d" % sim.tier] = PortSim.DEPTS.map(func(d): return int(sim.levels[d]))
				last_tier = sim.tier
			for c in sim.tier_check():
				var ck := "T%d %s" % [sim.tier + 1, c.label]
				if c.ok and not cond_ok.has(ck):
					cond_ok[ck] = sim.time
			if sim.tier == 1:
				var aff := false
				for d2 in PortSim.DEPTS:
					if sim.feature("dept_" + d2) and sim.dept_cost(d2, 1) <= sim.money:
						aff = true
				for b2 in sim.db.buildings:
					if sim.building_state(b2.id) == "available" and float(b2.cost) <= sim.money:
						aff = true
				if aff:
					dry[0] = sim.time
				dry[1] = maxf(float(dry[1]), sim.time - float(dry[0]))
			for dd in pre_chapter:
				if String(sim.analysis.get("dept", "")) == dd and not sim.feature("dept_" + dd):
					pre_chapter[dd] = float(pre_chapter[dd]) + 10.0
			var kk := tk + ":" + String(sim.analysis.key)
			keys[kk] = float(keys.get(kk, 0.0)) + 10.0
			tier_time[tk] = float(tier_time.get(tk, 0.0)) + 10.0
			if String(sim.shown_analysis().get("alert", "")) != "":
				alert_t[tk] = float(alert_t.get(tk, 0.0)) + 10.0
				var akey := tk + ":" + String(sim.shown_analysis().alert)
				alert_why_t[akey] = int(alert_why_t.get(akey, 0)) + 1
			if dem > 1.5 * cap:
				excess[tk] = float(excess.get(tk, 0.0)) + 10.0
			op_hist.append(op[0])
			op[0] = 0.0
			var op_min := 0.0
			for j in range(maxi(0, op_hist.size() - 6), op_hist.size()):
				op_min += float(op_hist[j])
			samples.append([sim.time, sim.tier, op_min * 6.0 / float(mini(6, op_hist.size())), String(sim.analysis.key), sim.money])
			if sim.time >= next_pb and not sim.finished:
				next_pb += PAYBACK_EVERY
				var bp := _best_payback(sim)
				if not paybacks.has(tk):
					paybacks[tk] = []
					pb_what[tk] = {}
				paybacks[tk].append(bp[0])
				pb_log.append([sim.time, bp[0], bp[1]])
				pb_what[tk][bp[1]] = int(pb_what[tk].get(bp[1], 0)) + 1
			if int(sim.time) % 60 < 10:
				var ta := sim.counter("turned_away")
				rows.append([sim.time, sim.tier, sim.money, sim.income_per_min(), dem * 60.0, cap * 60.0, ta - last_ta, String(sim.analysis.key), sim.levels.harbor, sim.licences[0]])
				last_ta = ta
		lic_at["fin"] = sim.licences[0]
		lic_at["niv fin"] = PortSim.DEPTS.map(func(d): return int(sim.levels[d]))
		if verbose:
			print("\n=== graine %d ===" % sd)
			print("   temps  T  argent      rev/min     demande/min  capacité/min  déroutés  goulot  capit. lic")
			for r in rows:
				print("%8s  %d  %10s  %10s  %12s  %12s  %5d  %-12s %d %d" % [Fmt.duration(r[0]), r[1], Fmt.money(r[2]), Fmt.money(r[3]), Fmt.num(r[4]), Fmt.num(r[5]), int(r[6]), r[7], r[8], r[9]])
			for l in bot.log_lines:
				print(l)
		if curve:
			for q in pb_log:
				print("renta g%d %s %s %s" % [sd, Fmt.duration(float(q[0])), _dur(float(q[1])), String(q[2])])
			for i in range(0, samples.size(), 3):
				var s0: Array = samples[i]
				print("courbe g%d %s T%d %s/min %s %s" % [sd, Fmt.duration(float(s0[0])), int(s0[1]), Fmt.money(float(s0[2])), String(s0[3]), Fmt.money(float(s0[4]))])
		# trous d'achat par palier
		var gaps := {}
		var gap_at := {}             # palier -> « début→fin achat » du plus long trou
		var last := 0.0
		for p in bot.purchases:
			var t: float = p.t
			var tr := 1
			for k in tier_start:
				if t >= float(tier_start[k]):
					tr = maxi(tr, int(k))
			var key := "T%d" % tr
			if t - last > float(gaps.get(key, 0.0)):
				gaps[key] = t - last
				gap_at[key] = "%s→%s %s" % [Fmt.duration(last), Fmt.duration(t), String(p.kind) + ":" + String(p.id)]
			last = t
		# croissance du revenu minute par minute (hors 2 premières minutes d'un palier) et pire baisse depuis le pic,
		# sur une moyenne glissante de 3 min (un Panamax ou un brouillard fait varier la minute isolée de ×3)
		var avg3 := func(i: int) -> float:
			var a := 0.0
			for j in [i, i - 6, i - 12]:
				a += float(samples[maxi(0, j)][2])
			return a / 3.0
		var max_ratio := {}
		var worst_drop := {}
		var peak := {}
		for i in samples.size():
			var s: Array = samples[i]
			var tr2 := "T%d" % int(s[1])
			if float(s[0]) < float(tier_start.get(int(s[1]), 0.0)) + 180.0:
				continue
			var a3: float = avg3.call(i)
			var a3p: float = avg3.call(i - 6)
			if i >= 18 and int(samples[i - 18][1]) == int(s[1]) and a3p > 0.0:
				max_ratio[tr2] = maxf(float(max_ratio.get(tr2, 0.0)), a3 / a3p)
			peak[tr2] = maxf(float(peak.get(tr2, 0.0)), a3)
			worst_drop[tr2] = minf(float(worst_drop.get(tr2, 1.0)), a3 / maxf(1.0, float(peak[tr2])))
		var early := 0
		for p in bot.purchases:
			if p.t < 300.0:
				early += 1
		var inc_at := func(t: float) -> float:
			for s in samples:
				if float(s[0]) >= t:
					return float(s[2])
			return 0.0
		var ratios := {}
		for trg in [2, 3]:
			if not tier_start.has(trg):
				continue
			var t0: float = tier_start[trg]
			var r0: float = inc_at.call(t0 + 10.0)
			var parts: Array[String] = []
			for dtm in [3, 6, 10]:
				parts.append("×%s" % Fmt.num(float(inc_at.call(t0 + 60.0 * dtm)) / maxf(1.0, r0)))
			# fin du palier : moyenne des 3 dernières minutes avant le palier suivant (ou la fin)
			var t_end: float = float(tier_start.get(trg + 1, samples[-1][0]))
			var r_end := (float(inc_at.call(t_end - 60.0)) + float(inc_at.call(t_end - 120.0)) + float(inc_at.call(t_end - 180.0))) / 3.0
			# variante lissée (moyenne de 3 fenêtres d'une minute) : la minute isolée varie de ×2–3 avec les gros navires
			var avg_at := func(t: float) -> float:
				return (float(inc_at.call(t - 60.0)) + float(inc_at.call(t)) + float(inc_at.call(t + 60.0))) / 3.0
			var r0s: float = (float(inc_at.call(t0 + 10.0)) + float(inc_at.call(t0 - 50.0)) + float(inc_at.call(t0 - 110.0))) / 3.0
			ratios[trg] = "%s → %s · fin ×%s (lissé ×%s / ×%s)" % [Fmt.money(r0), " / ".join(parts), Fmt.num(r_end / maxf(1.0, r0)),
				Fmt.num(float(avg_at.call(t0 + 180.0)) / maxf(1.0, r0s)), Fmt.num(float(avg_at.call(t0 + 600.0)) / maxf(1.0, r0s))]
		# entrée des paliers 2 et 3 : revenu d'exploitation sur la minute glissante à −1 min et à +1 min du palier ; trou
		# d'achat des 10 premières minutes du palier
		var entries := {}
		for trg3 in [2, 3]:
			if not tier_start.has(trg3):
				continue
			var t3: float = tier_start[trg3]
			var r_m1: float = inc_at.call(t3 - 60.0)
			var r_p1: float = inc_at.call(t3 + 60.0)
			var r_p2: float = inc_at.call(t3 + 120.0)
			var lastp := t3
			var gap3 := 0.0
			var gap3_at := ""
			for p in bot.purchases:
				if p.t < t3 or p.t > t3 + 600.0:
					continue
				if p.t - lastp > gap3:
					gap3 = p.t - lastp
					gap3_at = "%s→%s %s:%s" % [Fmt.duration(lastp), Fmt.duration(p.t), String(p.kind), String(p.id)]
				lastp = p.t
			entries[trg3] = "−1 min %s · +1 min %s (×%.2f) · +2 min %s · trou 10 min %s (%s)" % [Fmt.money(r_m1), Fmt.money(r_p1), r_p1 / maxf(1.0, r_m1), Fmt.money(r_p2), _dur(gap3), gap3_at]
		# bandeaux : le plus grand nombre dans une fenêtre de 6 min qui contient le passage au T2
		var b6 := 0
		var b6_list := ""
		var b6c := 0                 # fenêtre centrée [T2 − 3 min, T2 + 3 min] (mesure de la revue)
		if tier_start.has(2):
			var t2: float = tier_start[2]
			for w0 in range(int(t2) - 360, int(t2) + 1, 5):
				var nb := 0
				var lst := ""
				for bi in banners.size():
					var bt: float = banners[bi]
					if bt >= float(w0) and bt < float(w0) + 360.0:
						nb += 1
						lst += "%s %s, " % [banner_ids[bi], Fmt.duration(bt)]
				if w0 == int(t2) - 180:
					b6c = nb
				if nb > b6:
					b6 = nb
					b6_list = lst
		var after_tier := ""
		for trg2 in tier_start:
			if int(trg2) == 1:
				continue
			for rid in reveal:
				var dtr := float(reveal[rid]) - float(tier_start[trg2])
				if dtr >= 0.0 and dtr < 60.0:
					after_tier += "%s T%d+%ds " % [rid, int(trg2), int(dtr)]
		# bâtiments T3 : 1er et 4e
		var t3b: Array = []
		for p in bot.purchases:
			if p.kind == "building" and int(db.building_by_id[p.id].tier) == 3:
				t3b.append(p.t - float(tier_start.get(3, 0.0)))
		var pbs := ""
		for tk in ["T1", "T2", "T3"]:
			if not paybacks.has(tk):
				continue
			var fin: Array = paybacks[tk].filter(func(v): return not is_inf(v))
			var n_inf: int = paybacks[tk].size() - fin.size()
			var over: int = fin.filter(func(v): return v > 300.0).size()
			var under: int = fin.filter(func(v): return v < 20.0).size()
			pbs += "%s méd %s max %s (<20 s %d%%, >5 min %d%%, aucun %d%% ; sans achat < 5 min %d%%) · " % [tk, _dur(_median(fin)), _dur(fin.max() if not fin.is_empty() else INF),
				roundi(100.0 * under / paybacks[tk].size()), roundi(100.0 * over / paybacks[tk].size()), roundi(100.0 * n_inf / paybacks[tk].size()),
				roundi(100.0 * (over + n_inf) / paybacks[tk].size())]
		var ms := bot.milestones
		table.append("g%d | T2 %s | T3 %s | fin %s | rev 1/5/10 min %s/%s/%s, %d achats<5 min | T2 %s | T3 %s | ×/min max T2 %s T3 %s | pire baisse T3 %d%% | trou T1/T2/T3 %s/%s/%s | bât. T3 1er %s 4e %s | lic %s" % [
			sd, _dur(ms.get("Palier T2 atteint", INF)), _dur(ms.get("Palier T3 atteint", INF)), _dur(ms.get("FIN DU MVP (concession nationale)", INF)),
			Fmt.num(inc_at.call(60.0)), Fmt.num(inc_at.call(300.0)), Fmt.num(inc_at.call(600.0)), early,
			ratios.get(2, "-"), ratios.get(3, "-"),
			Fmt.num(float(max_ratio.get("T2", 0.0))), Fmt.num(float(max_ratio.get("T3", 0.0))), roundi(100.0 * (1.0 - float(worst_drop.get("T3", 1.0)))),
			_dur(float(gaps.get("T1", 0.0))), _dur(float(gaps.get("T2", 0.0))), _dur(float(gaps.get("T3", 0.0))),
			_dur(t3b[0] if t3b.size() > 0 else INF), _dur(t3b[3] if t3b.size() > 3 else INF), str(lic_at)])
		if a0_line != "":
			table.append(a0_line)
		var first_buy := INF
		if not bot.purchases.is_empty():
			first_buy = float(bot.purchases[0].t)
		table.append("     T1 : plus longue attente sans aucun achat abordable %s (mesure à la seconde : %s)" % [_dur(float(dry[1])), _dur(bot.dry_t1)])
		table.append("     1er achat %s · goulot parc / gate avant leur chapitre %d s / %d s · chapitres : parc %s, gate %s, navires %s, licences %s" % [
			_dur(first_buy), int(pre_chapter.yard_ops), int(pre_chapter.gate), _dur(float(reveal.get("dept_yard_ops", INF))),
			_dur(float(reveal.get("dept_gate", INF))), _dur(float(reveal.get("commerce", INF))), _dur(float(reveal.get("licences", INF)))])
		# révélations dans l'ordre (un sujet par seuil) et plus petit écart entre deux d'entre elles
		var rv: Array = reveal.keys()
		rv.sort_custom(func(a, b): return float(reveal[a]) < float(reveal[b]))
		var rl := ""
		var min_gap := INF
		for i in rv.size():
			rl += "%s %s · " % [rv[i], Fmt.duration(float(reveal[rv[i]]))]
			if i > 0:
				min_gap = minf(min_gap, float(reveal[rv[i]]) - float(reveal[rv[i - 1]]))
		table.append("     révélations (écart min %s) : %s" % [_dur(min_gap), rl])
		table.append("     bandeaux en 6 min autour du T2 (max) %s · révélations < 60 s après un palier : %s · barre de palier %s (douane %s)" % [
			"%d centrée, %d au pire [%s]" % [b6c, b6, b6_list], after_tier if after_tier != "" else "aucune", _dur(float(reveal.get("progress", INF))), _dur(float(reveal.get("dept_customs", INF)))])
		var al := ""
		for tk2 in ["T1", "T2", "T3"]:
			al += "%s %d%% " % [tk2, roundi(100.0 * float(alert_t.get(tk2, 0.0)) / maxf(1.0, float(tier_time.get(tk2, 1.0))))]
		table.append("     carte Goulot rouge : " + al + str(alert_why_t))
		table.append("     plus longs trous : %s" % str(gap_at))
		table.append("     entrée T2 : %s | entrée T3 : %s" % [entries.get(2, "-"), entries.get(3, "-")])
		table.append("     rentabilité du meilleur achat : " + pbs)
		var wl := ""
		for tk in pb_what:
			wl += "%s %s · " % [tk, str(pb_what[tk])]
		table.append("     meilleur achat : " + wl)
		if brief:
			continue
		print("\n--- graine %d ---" % sd)
		print("Paliers : %s" % str(bot.milestones.keys().filter(func(k): return k.begins_with("Palier") or k.begins_with("FIN")).map(func(k): return "%s %s" % [k, Fmt.duration(bot.milestones[k])])))
		for tk in tier_time:
			var kl: Array = []
			for kk in keys:
				if kk.begins_with(tk + ":"):
					kl.append([kk.substr(3), keys[kk]])
			kl.sort_custom(func(a, b): return a[1] > b[1])
			var s := ""
			for x in kl:
				s += "%s %d%% " % [x[0], roundi(100.0 * x[1] / tier_time[tk])]
			print("%s  durée %s  demande>1,5×capacité %d%%  plus long trou d'achat %s  goulots: %s" % [tk, Fmt.duration(tier_time[tk]), roundi(100.0 * float(excess.get(tk, 0.0)) / tier_time[tk]), Fmt.duration(float(gaps.get(tk, 0.0))), s])
		# bâtiments par palier : temps d'achat relatif au début du palier
		var bl := ""
		for p in bot.purchases:
			if p.kind == "building":
				var b: Dictionary = db.building_by_id[p.id]
				bl += "%s@+%s " % [p.id, Fmt.duration(p.t - float(tier_start.get(int(b.tier), 0.0)))]
		print("Bâtiments (temps depuis début du palier) : " + bl)
		print("Navires déroutés %d, furieux %d" % [sim.counter("turned_away"), sim.counter("ships_angry")])
		for trg in [2, 3]:
			var t0 := -1.0
			var line := "Début T%d :" % trg
			for r in rows:
				if t0 < 0.0 and int(r[1]) == trg:
					t0 = float(r[0])
				if t0 >= 0.0:
					var dtm := roundi((float(r[0]) - t0) / 60.0)
					if dtm in [0, 3, 6, 10] and not line.contains("+%d min" % dtm):
						line += "  +%d min %s/min capit.%d lic.%d" % [dtm, Fmt.money(float(r[3])), int(r[8]), int(r[9])]
			print(line)
		var cl := ""
		for k in cond_ok:
			cl += "%s@%s · " % [k, Fmt.duration(cond_ok[k])]
		print("Conditions remplies : " + cl)
		var cs := ""
		for o in db.owners:
			cs += "%s lignes %d · " % [o.id, int(sim.lines.get(o.id, 0))]
		print("Lignes : " + cs + " contrats réussis %d, échoués %d, campagnes %d" % [sim.counter("contracts_done"), sim.counter("contracts_failed"), sim.counter("campaigns")])
	print("\n=== Synthèse ===")
	print("Cibles : T2 12–15 min · fin 1 h 15 – 1 h 30 · début 127/1K/5,4K ±15 % · T2 +3/+6/+10 ≤ ×6/×25/×80 · aucune minute > ×1,6 · rentabilité 20 s – 5 min")
	print("         T3 +10 min ×2–5, baisse ≤ 30 % · 1er bâtiment T3 ≥ +1 min, 4e ≥ +6 min · trou T3 ≤ 90 s")
	for l in table:
		print(l)
	quit()
