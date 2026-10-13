class_name Hazards
extends RefCounted
## Aléas : vent, brouillard, pannes, grèves, audits, pics saisonniers, enchères.

const TARGET_STAT := {"cranes": "crane_rate", "yard_ops": "transfer_rate", "gate": "gate_rate", "customs": "inspect_rate"}


static func update(sim: PortSim, _dt: float) -> void:
	sim.mods.purge(sim.time)
	if not sim.active_event.is_empty() and sim.time >= float(sim.active_event.until):
		end_event(sim)
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
			var fine := sim.income_rate_estimate() * 60.0
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
		ev.pay_cost = sim.income_rate_estimate() * float(e.pay.income_seconds)
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
