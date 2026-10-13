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
		"owners": db.owners, "ships": db.ships, "missions": db.missions}
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
		var keys := {}               # goulot -> secondes, par palier
		var excess := {}             # palier -> secondes où demande > 1,5 × capacité
		var tier_time := {}
		var last_ta := 0.0
		var rows: Array = []
		var samples: Array = []      # [t, palier, revenu/min] toutes les 10 s
		var paybacks := {}           # palier -> [s]
		var pb_what := {}            # palier -> {quoi: n}
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
		while sim.time < 3.0 * 3600.0 and not sim.finished:
			bot.run(10.0)
			var caps: Dictionary = sim.analysis.caps
			var dem := float(caps.traffic)
			var cap := _service_cap(caps)
			var tk := "T%d" % sim.tier
			if sim.tier != last_tier:
				tier_start[sim.tier] = sim.time
				lic_at["T%d" % sim.tier] = sim.licences[0]
				last_tier = sim.tier
			for c in sim.tier_check():
				var ck := "T%d %s" % [sim.tier + 1, c.label]
				if c.ok and not cond_ok.has(ck):
					cond_ok[ck] = sim.time
			var kk := tk + ":" + String(sim.analysis.key)
			keys[kk] = float(keys.get(kk, 0.0)) + 10.0
			tier_time[tk] = float(tier_time.get(tk, 0.0)) + 10.0
			if dem > 1.5 * cap:
				excess[tk] = float(excess.get(tk, 0.0)) + 10.0
			op_hist.append(op[0])
			op[0] = 0.0
			var op_min := 0.0
			for j in range(maxi(0, op_hist.size() - 6), op_hist.size()):
				op_min += float(op_hist[j])
			samples.append([sim.time, sim.tier, op_min * 6.0 / float(mini(6, op_hist.size()))])
			if sim.time >= next_pb and not sim.finished:
				next_pb += PAYBACK_EVERY
				var bp := _best_payback(sim)
				if not paybacks.has(tk):
					paybacks[tk] = []
					pb_what[tk] = {}
				paybacks[tk].append(bp[0])
				pb_what[tk][bp[1]] = int(pb_what[tk].get(bp[1], 0)) + 1
			if int(sim.time) % 60 < 10:
				var ta := sim.counter("turned_away")
				rows.append([sim.time, sim.tier, sim.money, sim.income_per_min(), dem * 60.0, cap * 60.0, ta - last_ta, String(sim.analysis.key), sim.levels.harbor, sim.licences[0]])
				last_ta = ta
		lic_at["fin"] = sim.licences[0]
		if verbose:
			print("\n=== graine %d ===" % sd)
			print("   temps  T  argent      rev/min     demande/min  capacité/min  déroutés  goulot  capit. lic")
			for r in rows:
				print("%8s  %d  %10s  %10s  %12s  %12s  %5d  %-12s %d %d" % [Fmt.duration(r[0]), r[1], Fmt.money(r[2]), Fmt.money(r[3]), Fmt.num(r[4]), Fmt.num(r[5]), int(r[6]), r[7], r[8], r[9]])
			for l in bot.log_lines:
				print(l)
		# trous d'achat par palier
		var gaps := {}
		var last := 0.0
		for p in bot.purchases:
			var t: float = p.t
			var tr := 1
			for k in tier_start:
				if t >= float(tier_start[k]):
					tr = maxi(tr, int(k))
			var key := "T%d" % tr
			gaps[key] = maxf(float(gaps.get(key, 0.0)), t - last)
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
			ratios[trg] = "%s → %s" % [Fmt.money(r0), " / ".join(parts)]
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
			pbs += "%s méd %s max %s (<20 s %d%%, >5 min %d%%, aucun %d%%) · " % [tk, _dur(_median(fin)), _dur(fin.max() if not fin.is_empty() else INF),
				roundi(100.0 * under / paybacks[tk].size()), roundi(100.0 * over / paybacks[tk].size()), roundi(100.0 * n_inf / paybacks[tk].size())]
		var ms := bot.milestones
		table.append("g%d | T2 %s | T3 %s | fin %s | rev 1/5/10 min %s/%s/%s, %d achats<5 min | T2 %s | T3 %s | ×/min max T2 %s T3 %s | pire baisse T3 %d%% | trou T1/T2/T3 %s/%s/%s | bât. T3 1er %s 4e %s | lic %s" % [
			sd, _dur(ms.get("Palier T2 atteint", INF)), _dur(ms.get("Palier T3 atteint", INF)), _dur(ms.get("FIN DU MVP (concession nationale)", INF)),
			Fmt.num(inc_at.call(60.0)), Fmt.num(inc_at.call(300.0)), Fmt.num(inc_at.call(600.0)), early,
			ratios.get(2, "-"), ratios.get(3, "-"),
			Fmt.num(float(max_ratio.get("T2", 0.0))), Fmt.num(float(max_ratio.get("T3", 0.0))), roundi(100.0 * (1.0 - float(worst_drop.get("T3", 1.0)))),
			_dur(float(gaps.get("T1", 0.0))), _dur(float(gaps.get("T2", 0.0))), _dur(float(gaps.get("T3", 0.0))),
			_dur(t3b[0] if t3b.size() > 0 else INF), _dur(t3b[3] if t3b.size() > 3 else INF), str(lic_at)])
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
