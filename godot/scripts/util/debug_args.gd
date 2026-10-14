class_name DebugArgs
extends RefCounted
## Arguments de triche de la ligne de commande (--debug-money, --tier, --levels, --build-all, --hire-all, --build,
## --unlock-all, --speed, --open=debug, --load-sim, --open-zone ; F1 et sa ligne des Réglages) : seulement depuis le binaire de
## l'éditeur (OS.has_feature("editor") : tests headless, captures, jouer.bat). Jamais dans l'APK, même exporté en debug
## (OS.is_debug_build() y est vrai : revue C7 A5).
## Les arguments de capture (--fresh, --capture, --delay, --look, --zoom, --tuto…) restent disponibles partout.

const CHEATS := ["speed", "debug-money", "tier", "build-all", "levels", "hire-all", "build", "unlock-all"]


## Force le passage au palier suivant (conditions satisfaites d'office). Aussi utilisé par le panneau F1.
static func force_tier(s: PortSim) -> void:
	var req := s.tier_requirements(s.tier + 1)
	if req.is_empty():
		return
	s.counters["evp"] = maxf(s.counter("evp"), float(req.evp))
	s.satisfaction = maxf(s.satisfaction, (float(req.stars) - 1.0) / 4.0 + 0.01)
	s.money = maxf(s.money, float(req.money))
	for b in req.get("buildings", []):
		if not s.built.has(b):
			s.built.append(String(b))
	s.rebuild_infra()
	s.tier_up()


## Construit tous les bâtiments du palier courant, sans les payer.
static func build_all(s: PortSim) -> void:
	for b in s.db.buildings:
		if int(b.tier) <= s.tier and not s.built.has(b.id):
			s.built.append(String(b.id))
	s.rebuild_infra()
	s.invalidate()


## Les triches sont-elles autorisées ? (binaire de l'éditeur : oui ; toute version exportée, debug comprise : non)
static func allowed() -> bool:
	return OS.has_feature("editor")


## Applique les triches de `a` à `sim` si `debug` ; renvoie {"applied": [clés appliquées], "speed": vitesse demandée ou -1}.
## Hors debug, rien n'est touché (les clés sont simplement ignorées).
static func apply(a: Dictionary, sim: PortSim, db: DataDB, debug: bool) -> Dictionary:
	var out := {"applied": [], "speed": -1.0}
	if not debug:
		return out
	if a.has("speed"):
		out.speed = float(a.speed)
		out.applied.append("speed")
	if a.has("debug-money"):
		sim.money += float(a["debug-money"])
		out.applied.append("debug-money")
	if a.has("tier"):
		while sim.tier < int(a.tier) and not sim.finished:
			force_tier(sim)
		out.applied.append("tier")
	if a.has("build-all"):
		build_all(sim)
		out.applied.append("build-all")
	if a.has("levels"):       # --levels=60 : tous les départements à ce niveau (captures des éléments gagnés aux paliers)
		for d in PortSim.DEPTS:
			sim.levels[d] = int(a.levels)
		out.applied.append("levels")
	if a.has("hire-all"):
		for d in PortSim.DEPTS:
			sim.managers[d] = true
		out.applied.append("hire-all")
	if a.has("build"):        # --build=quay_ext,gravel2 : construit ces bâtiments (dans l'ordre), sans les payer
		for bid in String(a.build).split(","):
			if db.building_by_id.has(bid) and not sim.built.has(bid):
				sim.built.append(bid)
		sim.rebuild_infra()
		sim.check_unlocks()
		out.applied.append("build")
	if a.has("unlock-all") or a.has("tier") or a.has("build-all"):    # captures d'un port avancé : toute l'interface
		for u in db.unlocks:
			sim.features[String(u.id)] = true
		out.applied.append("unlock-all")
	return out
