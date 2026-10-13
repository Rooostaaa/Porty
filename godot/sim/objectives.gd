class_name Objectives
extends RefCounted
## Contrats d'armateurs et missions (Ambre).


static func update(sim: PortSim) -> void:
	_update_contracts(sim)
	if sim.feature("contracts") and sim.time >= sim.next_contract_refresh:
		sim.next_contract_refresh = sim.time + float(sim.db.cfg("day_seconds"))
		if sim.contract_offers.size() >= int(sim.db.cfg("contract_slots")):
			sim.contract_offers.pop_front()
		rescale_offers(sim)
		refresh_offers(sim)
	sim.counters["stars_x10"] = floorf(sim.stars() * 10.0)
	if not sim.feature("missions"):
		return
	for m in visible_missions(sim):
		if mission_done(sim, m) and not sim.mission_flags.has(m.id):
			sim.mission_flags[m.id] = true
			sim.mission_ready.emit(String(m.id))


# --- contrats ------------------------------------------------------------

static func _nice(v: float) -> float:
	if v <= 0.0:
		return 0.0
	var p := pow(10.0, floorf(log(v) / log(10.0)))
	return ceilf(v / p * 2.0) / 2.0 * p


## `skip` : modèle à ne pas reproposer tout de suite (l'offre que le joueur vient de refuser).
static func refresh_offers(sim: PortSim, skip: String = "") -> void:
	var slots := int(sim.db.cfg("contract_slots"))
	var taken := {}
	for c in sim.contract_offers + sim.contracts_active:
		taken[c.tpl] = true
	var pool: Array = []
	for t in sim.db.contracts:
		if int(t.tier) > sim.tier or taken.has(t.id) or t.id == skip:
			continue
		var od: Dictionary = sim.db.owner_by_id[t.owner]
		if int(od.tier) > sim.tier or not sim.owner_ok(od):
			continue
		if String(t.cargo) != "" and sim.unlocked[int(sim.db.cargo_index[t.cargo])] == 0:
			continue
		pool.append(t)
	while sim.contract_offers.size() < slots and not pool.is_empty():
		var i := sim.rng.randi_range(0, pool.size() - 1)
		sim.contract_offers.append(make_offer(sim, pool[i]))
		pool.remove_at(i)
	sim.contracts_changed.emit()


static func make_offer(sim: PortSim, t: Dictionary) -> Dictionary:
	var rate := maxf(owner_rate(sim, String(t.owner), String(t.cargo)), 0.05)
	var n := _nice(rate * float(t.days) * float(sim.db.cfg("day_seconds")) * float(sim.db.cfg("contract_fill", 0.6)))
	var reward := _nice(float(t.reward_income_seconds) * maxf(sim.income_rate_estimate(), 2.0))
	var od: Dictionary = sim.db.owner_by_id[t.owner]
	return {
		"tpl": t.id, "owner": t.owner, "owner_name": od.name, "cargo": t.cargo, "title": t.title,
		"text": String(t.text).format({"n": Fmt.num(n), "d": int(t.days)}),
		"target": n, "progress": 0.0, "days": int(t.days), "deadline": 0.0,
		"reward": reward, "amber": int(t.amber), "relation": float(t.relation),
	}


## Débit (EVP/s) que cet armateur apporterait avec un contrat en cours : sa part de la demande (contrat compris),
## bornée par ce que le port peut traiter, et la part de la cargaison demandée dans ses navires.
static func owner_rate(sim: PortSim, owner: String, cargo: String) -> float:
	var service := sim.service_capacity()
	var od: Dictionary = sim.db.owner_by_id[owner]
	var f := sim.owner_factor(od)
	var total := sim.owners_traffic()
	var active := false
	for ct in sim.contracts_active:
		if ct.owner == owner:
			active = true
	var boost := f * (float(sim.db.cfg("contract_traffic", 3.0)) - 1.0) if not active else 0.0
	var f2 := f + boost
	var demand := sim.stat("demand") * (total + boost) / maxf(0.0001, total)
	var share := f2 / maxf(0.0001, total + boost)
	var r := minf(service, demand) * share
	if cargo != "":
		r *= sim.cargo_mix(owner)[int(sim.db.cargo_index[cargo])]
	return r


## Les offres en attente suivent la croissance du port (une offre peut rester 3 jours affichée,
## pendant lesquels le revenu peut être multiplié par 100) ; on ne les revoit jamais à la baisse.
static func rescale_offers(sim: PortSim) -> void:
	for c in sim.contract_offers:
		var t: Dictionary = sim.db.contract_by_id.get(String(c.tpl), {})
		if t.is_empty():
			continue
		var fresh := make_offer(sim, t)
		if float(fresh.reward) > float(c.reward):
			c.reward = fresh.reward
		if float(fresh.target) > float(c.target):
			c.target = fresh.target
			c.text = fresh.text


static func accept(sim: PortSim, index: int) -> bool:
	if index < 0 or index >= sim.contract_offers.size():
		return false
	if sim.contracts_active.size() >= int(sim.db.cfg("contract_active_max")):
		return false
	var c: Dictionary = sim.contract_offers[index]
	sim.contract_offers.remove_at(index)
	c.deadline = sim.time + float(c.days) * float(sim.db.cfg("day_seconds"))
	sim.contracts_active.append(c)
	sim.contracts_changed.emit()
	return true


static func decline(sim: PortSim, index: int) -> void:
	if index >= 0 and index < sim.contract_offers.size():
		var tpl := String(sim.contract_offers[index].tpl)
		sim.contract_offers.remove_at(index)
		refresh_offers(sim, tpl)   # sinon l'offre refusée peut revenir aussitôt


static func on_unloaded(sim: PortSim, owner: String, cargo: String, amount: float) -> void:
	for c in sim.contracts_active:
		if c.owner == owner and (String(c.cargo) == "" or c.cargo == cargo):
			c.progress = float(c.progress) + amount


static func _update_contracts(sim: PortSim) -> void:
	var keep: Array[Dictionary] = []
	var changed := false
	for c in sim.contracts_active:
		if float(c.progress) >= float(c.target):
			sim._earn(float(c.reward), "contract")
			sim.amber += int(c.amber)
			sim.relations[c.owner] = clampf(float(sim.relations[c.owner]) + float(c.relation), 0.0, 100.0)
			sim.add_counter("contracts_done")
			sim.notify.emit("Contrat réussi : %s ! +%s, +%d Ambre" % [c.title, Fmt.money(float(c.reward)), int(c.amber)], "good")
			Commerce.offer_line(sim, String(c.owner))
			changed = true
		elif sim.time >= float(c.deadline):
			sim.relations[c.owner] = clampf(float(sim.relations[c.owner]) - float(c.relation), 0.0, 100.0)
			sim.notify.emit("Contrat échoué : %s. %s est déçu." % [c.title, c.owner_name], "bad")
			sim.add_counter("contracts_failed")
			changed = true
		else:
			keep.append(c)
	if changed:
		sim.contracts_active = keep
		refresh_offers(sim)


# --- missions -------------------------------------------------------------

static func mission_progress(sim: PortSim, m: Dictionary) -> float:
	if m.has("level"):
		return float(sim.levels.get(m.level, 0))
	if m.has("building"):
		return 1.0 if sim.built.has(String(m.building)) else 0.0
	return sim.counter_total(String(m.counter))


## Objectifs de carrière : quand les missions écrites sont épuisées, une suite sans fin, de plus en plus ambitieuse.
## Famille (i % 4) : EVP traités, escales, camions, contrats. Le palier de difficulté croît avec i / 4.
static func generated_mission(i: int) -> Dictionary:
	var k := floori(i / 4.0)
	var amber := 3 + k
	match i % 4:
		0:
			var n := 5.0e6 * pow(2.2, k)
			return {"id": "g%d" % i, "text": "Décharger %s EVP au total" % Fmt.num(n), "counter": "evp", "target": n, "amber": amber, "career": true}
		1:
			var n1 := 150.0 * pow(1.9, k)
			return {"id": "g%d" % i, "text": "Accueillir %s escales au total" % Fmt.num(n1), "counter": "ships", "target": n1, "amber": amber, "career": true}
		2:
			var n2 := 5000.0 * pow(2.0, k)
			return {"id": "g%d" % i, "text": "Faire sortir %s camions par la gate" % Fmt.num(n2), "counter": "trucks", "target": n2, "amber": amber, "career": true}
	var n3 := 5.0 + 4.0 * float(k)
	return {"id": "g%d" % i, "text": "Réussir %d contrats au total" % int(n3), "counter": "contracts_done", "target": n3, "amber": amber, "career": true}


static func mission_done(sim: PortSim, m: Dictionary) -> bool:
	return mission_progress(sim, m) >= float(m.target)


static func visible_missions(sim: PortSim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n := int(sim.db.cfg("mission_visible"))
	for m in sim.db.missions:
		if sim.missions_claimed.has(m.id):
			continue
		out.append(m)
		if out.size() >= n:
			return out
	var i := 0
	while out.size() < n and i < 4000:
		var g := generated_mission(i)
		i += 1
		if not sim.missions_claimed.has(String(g.id)):
			out.append(g)
	return out


static func claimable_count(sim: PortSim) -> int:
	var n := 0
	for m in visible_missions(sim):
		if mission_done(sim, m):
			n += 1
	return n


static func claim(sim: PortSim, id: String) -> bool:
	if not sim.feature("missions"):
		return false
	for m in visible_missions(sim):
		if m.id == id and mission_done(sim, m):
			sim.missions_claimed.append(id)
			sim.amber += int(m.amber)
			# missions de guidage du début : une prime en argent (quelques dizaines de secondes de revenu)
			var cash := maxf(float(m.get("income_seconds", 0.0)) * maxf(0.0, sim.income_per_min() / 60.0), float(m.get("min_cash", 0.0)))
			sim.money += cash
			sim.last_claim = {"amber": int(m.amber), "money": cash, "chest": false}
			var txt := "Mission accomplie : +%d Ambre" % int(m.amber) + (" et +%s" % Fmt.money(cash) if cash > 0.0 else "")
			# coffre : toutes les N missions réclamées
			var ch: Dictionary = sim.db.cfg("mission_chest", {})
			if not ch.is_empty() and sim.missions_claimed.size() % int(ch.every) == 0:
				var c_cash := float(ch.income_seconds) * maxf(1.0, sim.income_per_min() / 60.0)
				sim.amber += int(ch.amber)
				sim.money += c_cash
				sim.last_claim = {"amber": int(m.amber) + int(ch.amber), "money": cash + c_cash, "chest": true}
				txt = "Coffre de missions : +%d Ambre et +%s !" % [int(m.amber) + int(ch.amber), Fmt.money(cash + c_cash)]
			sim.notify.emit(txt, "good")
			return true
	return false


## Coffre de missions : missions réclamées depuis le dernier coffre, et nombre requis.
static func chest_progress(sim: PortSim) -> Vector2i:
	var ch: Dictionary = sim.db.cfg("mission_chest", {})
	if ch.is_empty():
		return Vector2i(0, 0)
	return Vector2i(sim.missions_claimed.size() % int(ch.every), int(ch.every))
