class_name Commerce
extends RefCounted
## Développement commercial : démarchage (campagnes temporaires), armateurs à recruter, lignes régulières.
## La demande de navires = trafic des classes accueillies × statut du port × armateurs (et leurs lignes)
## × services × réputation × tarifs × campagnes. La Capitainerie ne fait plus venir de navires : elle les pilote.


# --- campagnes de démarchage --------------------------------------------------

static func campaigns(sim: PortSim) -> Array:
	return sim.db.cfg("campaigns", [])


static func campaign_def(sim: PortSim, id: String) -> Dictionary:
	for c in campaigns(sim):
		if String(c.id) == id:
			return c
	return {}


static func campaign_available(sim: PortSim, c: Dictionary) -> bool:
	if int(c.get("tier", 1)) > sim.tier:
		return false
	var r := String(c.get("require", ""))
	return r == "" or sim.built.has(r)


static func campaign_cost(sim: PortSim, id: String) -> float:
	var c := campaign_def(sim, id)
	return maxf(float(c.get("min_cost", 0.0)), sim.income_rate_estimate() * float(c.income_seconds))


static func campaign_active(sim: PortSim, id: String) -> bool:
	return sim.mods.has("camp_" + id)


static func campaign_ready(sim: PortSim, id: String) -> bool:
	return sim.time >= float(sim.campaign_ready_at.get(id, 0.0)) and not campaign_active(sim, id)


static func start_campaign(sim: PortSim, id: String) -> bool:
	var c := campaign_def(sim, id)
	if c.is_empty() or not sim.feature("commerce") or not campaign_available(sim, c) or not campaign_ready(sim, id):
		return false
	var cost := campaign_cost(sim, id)
	if sim.money < cost:
		return false
	sim.money -= cost
	var until := sim.time + float(c.duration)
	sim.mods.add("camp_" + id, "demand", float(c.mult), String(c.name), until)
	sim.campaign_ready_at[id] = until + float(c.cooldown)
	sim.invalidate()
	sim.add_counter("campaigns")
	sim.purchased.emit("campaign", id)
	sim.notify.emit("%s : trafic ×%s pendant %s." % [c.name, Fmt.mult(float(c.mult)), Fmt.duration(float(c.duration))], "good")
	sim._refresh_analysis()
	return true


# --- armateurs ----------------------------------------------------------------

## L'armateur doit être démarché (salon maritime) avant de venir.
static func needs_recruit(o: Dictionary) -> bool:
	return o.has("recruit")


static func recruit_state(sim: PortSim, oid: String) -> String:
	var o: Dictionary = sim.db.owner_by_id[oid]
	if not needs_recruit(o) or sim.owners_on.has(oid):
		return "present"
	if int(o.tier) > sim.tier:
		return "tier"
	var r := String(o.get("require", ""))
	if r != "" and not sim.built.has(r):
		return "locked"
	return "available"


static func recruit(sim: PortSim, oid: String) -> bool:
	if not sim.feature("commerce") or recruit_state(sim, oid) != "available":
		return false
	var o: Dictionary = sim.db.owner_by_id[oid]
	var cost := float(o.recruit)
	if sim.money < cost:
		return false
	sim.money -= cost
	sim.owners_on[oid] = true
	sim.invalidate()
	sim.add_counter("owners_recruited")
	sim.purchased.emit("owner", oid)
	sim.notify.emit("%s fera escale chez toi !" % o.name, "good")
	if sim.feature("contracts"):
		Objectives.refresh_offers(sim)
	sim._refresh_analysis()
	return true


# --- lignes régulières --------------------------------------------------------

static func max_lines(sim: PortSim) -> int:
	return int(sim.db.cfg("lines_per_owner")[sim.tier_index()])


static func line_cost(sim: PortSim, oid: String) -> float:
	var base := float(sim.db.cfg("line_cost")[sim.tier_index()])
	var c := base * pow(float(sim.db.cfg("line_cost_growth", 2.0)), float(sim.lines.get(oid, 0)))
	if sim.line_offers.has(oid):
		c *= float(sim.db.cfg("line_contract_discount", 0.5))
	return c


## Ligne suivante possible avec cet armateur (présent, sous le maximum du palier).
static func line_available(sim: PortSim, oid: String) -> bool:
	return sim.owner_present(sim.db.owner_by_id[oid]) and int(sim.lines.get(oid, 0)) < max_lines(sim)


## Un contrat réussi rend la prochaine ligne avec cet armateur moins chère (`line_offers` : remise acquise).
static func offer_line(sim: PortSim, oid: String) -> void:
	if not line_available(sim, oid) or sim.line_offers.has(oid):
		return
	sim.line_offers.append(oid)
	sim.notify.emit("%s te fait une offre : sa prochaine ligne régulière à moitié prix (Commerce)." % sim.db.owner_by_id[oid].name, "good")


static func sign_line(sim: PortSim, oid: String) -> bool:
	if not sim.feature("commerce") or not line_available(sim, oid):
		return false
	var cost := line_cost(sim, oid)
	if sim.money < cost:
		return false
	sim.money -= cost
	sim.line_offers.erase(oid)
	sim.lines[oid] = int(sim.lines.get(oid, 0)) + 1
	sim.invalidate()
	sim.add_counter("lines")
	sim.purchased.emit("line", oid)
	sim.notify.emit("Ligne régulière signée avec %s : ses navires viennent plus souvent." % sim.db.owner_by_id[oid].name, "good")
	sim._refresh_analysis()
	return true
