class_name Hazards
extends RefCounted
## Aléas : vent, brouillard, pannes, grèves, audits, pics saisonniers, enchères.

## Secondes de revenu réel mesurées en dessous desquelles le coût d'un aléa est provisoire (partie tout juste chargée).
const MIN_WINDOW := 15.0
const TARGET_STAT := {"cranes": "crane_rate", "yard_ops": "transfer_rate", "gate": "gate_rate", "customs": "inspect_rate"}


static func update(sim: PortSim, _dt: float) -> void:
	sim.mods.purge(sim.time)
	if not sim.active_event.is_empty() and sim.time >= float(sim.active_event.until):
		end_event(sim)
	var ev := sim.active_event
	if not ev.is_empty() and bool(ev.get("cost_pending", false)) and sim.real_income_window() >= MIN_WINDOW:
		ev.erase("cost_pending")
		var e: Dictionary = sim.db.event_by_id.get(String(ev.id), {})
		if e.has("pay") and not bool(ev.get("paid", false)):
			ev.pay_cost = cost_for(sim, float(e.pay.income_seconds))
	# pas de nouvel aléa tant que le joueur n'a pas découvert cette mécanique (un aléa en cours se termine quand même)
	if sim.feature("events") and sim.active_event.is_empty() and sim.time >= sim.next_event_at:
		var id := _pick_event(sim)
		_schedule_next(sim)
		if id != "":
			start(sim, id)


static func _schedule_next(sim: PortSim) -> void:
	var iv: Array = sim.db.cfg("event_interval")
	sim.next_event_at = sim.time + sim.rng.randf_range(float(iv[0]), float(iv[1]))


static func eligible(sim: PortSim, e: Dictionary) -> bool:
	if int(e.get("tier", 1)) > sim.tier:
		return false
	if e.has("require_building") and not sim.built.has(String(e.require_building)):
		return false
	if e.has("require_cargo") and sim.unlocked[int(sim.db.cargo_index[e.require_cargo])] == 0:
		return false
	if e.has("require_fill") and sim.yard_fill() < float(e.require_fill):
		return false
	return true


static func _pick_event(sim: PortSim) -> String:
	var ids: Array = []
	var w: Array = []
	for e in sim.db.events:
		if eligible(sim, e):
			ids.append(e.id)
			w.append(float(e.weight))
	if ids.is_empty():
		return ""
	return ids[sim._pick(w)]


## Coût d'un aléa (« Sécuriser », « Réparer », amende d'un contrôle) : `secs` secondes du revenu **réel** (lot E — le débit
## théorique donnait « Sécuriser · 116 M$ » pour 41 K$/s de revenu), plafonné à `hazard_cost_cap` (25 %) de la trésorerie.
static func cost_for(sim: PortSim, secs: float) -> float:
	# (moins de MIN_WINDOW s de revenu mesuré — partie chargée sans les seaux du revenu : l'estimation, toujours plafonnée)
	var rate := sim.real_income_rate() if sim.real_income_window() >= MIN_WINDOW else sim.income_rate_estimate()
	var c := maxf(0.0, rate) * secs
	return minf(c, float(sim.db.cfg("hazard_cost_cap", 0.25)) * maxf(0.0, sim.money))


## Statistiques touchées par l'aléa en cours (avant ou après « Sécuriser »), [] sans aléa.
static func hit_stats(sim: PortSim) -> Array[String]:
	var out: Array[String] = []
	if sim.active_event.is_empty() or not sim.db.event_by_id.has(String(sim.active_event.get("id", ""))):
		return out
	var e: Dictionary = sim.db.event_by_id[String(sim.active_event.id)]
	var mods: Array = e.get("mods", [])
	if bool(sim.active_event.get("paid", false)) and e.has("pay"):
		mods = e.pay.get("mods", [])
	for m in mods:
		if float(m.mult) < 1.0:
			out.append(_stat_for(sim, String(m.stat)))
	return out


static func _stat_for(sim: PortSim, raw: String) -> String:
	if raw == "$target":
		return TARGET_STAT.get(String(sim.active_event.get("target", "cranes")), "crane_rate")
	return raw


static func start(sim: PortSim, id: String) -> void:
	if not sim.active_event.is_empty():
		end_event(sim)
	var e: Dictionary = sim.db.event_by_id[id]
	var kind := String(e.get("kind", "mods"))
	if kind == "audit":
		if sim.policy >= 1:
			sim.amber += 1
			sim.satisfaction = lerpf(sim.satisfaction, 1.0, 0.1)
			sim.notify.emit("Contrôle surprise : le terminal est en règle. +1 Ambre", "good")
		else:
			var fine := cost_for(sim, 60.0)
			sim.money = maxf(0.0, sim.money - fine)
			sim.notify.emit("Contrôle surprise : politique trop laxiste, amende de %s." % Fmt.money(fine), "bad")
		return
	var ev := {
		"id": id, "name": e.name, "text": e.text, "icon": e.get("icon", ""),
		"until": sim.time + float(e.duration), "start": sim.time, "paid": false, "kind": kind,
	}
	if e.has("target_choices"):
		var ch: Array = e.target_choices
		ev.target = ch[sim.rng.randi_range(0, ch.size() - 1)]
		ev.text = "%s (%s à 50 %%)" % [e.text, sim.db.dept_by_id[ev.target].name]
	if kind == "auction":
		ev.reward = sim.income_rate_estimate() * float(e.get("reward_income_seconds", 30))
		ev.pay_label = "Organiser l'enchère"
	elif e.has("pay"):
		ev.pay_label = e.pay.label
		ev.pay_cost = cost_for(sim, float(e.pay.income_seconds))
		if sim.real_income_window() < MIN_WINDOW:
			ev.cost_pending = true        # recalculé dès que MIN_WINDOW s de revenu réel sont mesurées (partie tout juste chargée)
	sim.active_event = ev
	for m in e.get("mods", []):
		sim.mods.add("event", _stat_for(sim, m.stat), float(m.mult), String(e.name), float(ev.until))
	sim.invalidate()
	sim.event_started.emit(ev)
	sim.add_counter("events")


static func end_event(sim: PortSim) -> void:
	if sim.active_event.is_empty():
		return
	var id := String(sim.active_event.id)
	sim.mods.remove("event")
	sim.active_event = {}
	sim.invalidate()
	sim.event_ended.emit(id)


## Le joueur paye (ou encaisse l'enchère).
static func pay(sim: PortSim) -> bool:
	var ev := sim.active_event
	if ev.is_empty() or bool(ev.paid):
		return false
	var e: Dictionary = sim.db.event_by_id[ev.id]
	if ev.kind == "auction":
		sim._earn(float(ev.reward), "auction")
		sim.notify.emit("Enchère réussie : +%s" % Fmt.money(float(ev.reward)), "good")
		end_event(sim)
		return true
	if not e.has("pay"):
		return false
	var cost := float(ev.get("pay_cost", 0.0))
	if sim.money < cost:
		return false
	sim.money -= cost
	sim.invalidate()
	if bool(e.pay.get("end", false)):
		end_event(sim)
	else:
		ev.paid = true
		sim.mods.remove("event")
		for m in e.pay.get("mods", []):
			sim.mods.add("event", _stat_for(sim, m.stat), float(m.mult), String(e.name) + " (sécurisé)", float(ev.until))
	return true
