class_name Advice
extends RefCounted
## Lot E — Confiance : ce que l'interface conseille, sans dépendance aux autoloads (testable par run_all en --script) :
## - le bouton de la carte Goulot (`hint_action`) : le bâtiment **qui règle** le goulot (table d'après les effets de
##   buildings.json), sinon l'amélioration du service qui le soulage, sinon GESTION ;
## - les « bons achats » (pastille d'Améliorer, ★ MEILLEUR ACHAT, texte vert) : le débit bouge et l'achat se rentabilise en
##   moins de 10 minutes ; un niveau qui ne fait monter que les services facturés est « pas le goulot (+X $/s de services) ».

## Goulots qui se règlent par un bâtiment (voir `Hud.BUILD_KEYS`).
const BUILD_KEYS := ["yard_space", "berth_count", "min_time", "attract"]

## Action proposée par la carte Goulot : quoi, combien, et possible tout de suite ou non (revue D-UI, phase 1).
## {kind : "build" | "dept" | "tier" | "campaign" | "commerce" | "", id, cost, can, label}. Pour un goulot qui se règle
## par un bâtiment, une amélioration abordable du service qui le soulage compte aussi (« parc trop petit » : l'empilage).
static func hint_action(s: PortSim) -> Dictionary:
	var a := s.shown_analysis()
	var key: String = a.get("key", "")
	if key == "tier":
		return {"kind": "tier", "id": "", "cost": 0.0, "can": s.can_tier_up(), "label": "PALIER T%d" % (s.tier + 1)}
	if key == "fog":
		# brouillard : rien à acheter qui aide (le pilotage est suspendu), on attend qu'il se lève
		return {"kind": "", "id": "", "cost": 0.0, "can": false, "label": "PATIENTER"}
	# lot E (E2) : le bâtiment **qui règle ce goulot** (effets de buildings.json), s'il est le prochain de la liste et abordable ;
	# sinon l'amélioration du service qui le soulage ; sinon le bâtiment à viser (gris) ; sinon GESTION. Avant, le bouton
	# proposait le bâtiment suivant de la chaîne, quel qu'il soit (« postes à quai » → GNL, qui n'ajoute aucun poste).
	var bd := {}
	var bid := fix_building(s, key)
	if bid != "" and s.building_state(bid) == "available":
		var bc := float(s.db.building_by_id[bid].cost)
		bd = {"kind": "build", "id": bid, "cost": bc, "can": bc <= s.money, "label": "%s · %s" % [Info.building_short(s, bid), Fmt.money(bc)]}
	if not bd.is_empty() and bool(bd.can):
		return bd
	var dd := {}
	var fd := fix_dept(s, key, String(a.get("dept", "")))
	if fd == "campaign":
		dd = _campaign_action(s)
	elif fd != "" and s.feature("dept_" + fd) and (not key in ["berth_count", "min_time"] or _dept_moves_flow(s, fd)):
		# postes à quai, escales au plancher : le service (Quais, Douane) ne fait que grignoter le plancher — il n'est proposé
		# que s'il fait vraiment bouger le débit (au T3 de la partie de bot, un niveau de Quais ne fait monter que les services
		# facturés : on renvoie à GESTION, où se voit la chaîne jusqu'au quai n°4). L'empilage, lui, agrandit toujours le parc.
		dd = _dept_action(s, fd)
	if not dd.is_empty() and bool(dd.can):
		return dd
	if not bd.is_empty():
		return bd
	if not dd.is_empty():
		return dd
	if key in BUILD_KEYS:
		return {"kind": "manage", "id": "", "cost": 0.0, "can": false, "label": "GESTION"}
	return {"kind": "", "id": "", "cost": 0.0, "can": false, "label": "AMÉLIORER"}


## Effets de buildings.json qui règlent chaque goulot (lot E, E2).
static func fixes(key: String, e: Dictionary, s: PortSim) -> bool:
	var t := String(e.get("type", ""))
	var st := String(e.get("stat", ""))
	match key:
		"berth_count":
			return t == "add_berth"
		"yard_space":
			return t == "yard_cap" and int(e.get("zone", 0)) == 0
		"min_time":
			# plancher d'amarrage ou des formalités (le plus long des deux, comme l'analyse)
			var caps: Dictionary = s.shown_analysis().get("caps", {})
			var kind := "moor" if float(caps.get("moor_share", 0.0)) >= float(caps.get("formal_share", 0.0)) else "formal"
			return t == "time_min" and String(e.get("kind", "")) == kind
		"gate":
			return t == "gate_lanes" or t == "parking" or (t == "stat_mult" and st == "gate_rate")
		"cranes":
			return t == "add_crane" or (t == "stat_mult" and st == "crane_rate")
		"yard_ops":
			return t == "stat_mult" and st == "transfer_rate"
		"inspection":
			return t == "customs_open" or (t == "stat_mult" and st == "inspect_rate")
		"customs":
			return t == "customs_open" or (t == "time_min" and String(e.get("kind", "")) == "formal")
		"pilotage":
			return t == "time_min" and String(e.get("kind", "")) == "pilot"
	return false


## Premier bâtiment (palier atteint, pas encore construit, dans l'ordre de la liste) qui règle le goulot `key`, "" sinon.
## Il n'est achetable que s'il est aussi le prochain de la chaîne (`building_state` == « available »).
static func fix_building(s: PortSim, key: String) -> String:
	if key == "attract" or key == "harbor":
		var tb := String(s.shown_analysis().get("building", ""))
		return tb if tb != "" else s.traffic_building()
	for b in s.db.buildings:
		if s.built.has(String(b.id)) or int(b.tier) > s.tier:
			continue
		for e in b.effects:
			if fixes(key, e, s):
				return String(b.id)
	return ""


## Service (ou « campaign ») qui soulage le goulot `key` quand aucun bâtiment ne le règle tout de suite.
static func fix_dept(s: PortSim, key: String, dept: String) -> String:
	match key:
		"berth_count":
			return "berths"
		"yard_space":
			return "yard_ops"
		"min_time":
			var caps: Dictionary = s.shown_analysis().get("caps", {})
			return "berths" if float(caps.get("moor_share", 0.0)) >= float(caps.get("formal_share", 0.0)) else "customs"
		"attract", "harbor":
			return "campaign" if s.feature("commerce") else ""
	return dept


## Campagne de démarchage abordable (sinon la première prête, en gris ; sinon COMMERCE).
static func _campaign_action(s: PortSim) -> Dictionary:
	var best := {}
	for c in Commerce.campaigns(s):
		if Commerce.campaign_available(s, c) and Commerce.campaign_ready(s, c.id):
			var cc := Commerce.campaign_cost(s, c.id)
			var lab := "%s · %s" % [String(c.name).split(" ")[0].to_upper(), Fmt.money(cc)]
			if cc <= s.money:
				return {"kind": "campaign", "id": String(c.id), "cost": cc, "can": true, "label": lab}
			if best.is_empty():
				best = {"kind": "campaign", "id": String(c.id), "cost": cc, "can": false, "label": lab}
	return best if not best.is_empty() else {"kind": "commerce", "id": "", "cost": 0.0, "can": false, "label": "COMMERCE"}


## Un niveau du service `d` fait-il bouger le débit ? (estimation rejouée au plus une fois par seconde de jeu : la carte
## Goulot et l'anneau du monde la demandent à chaque image)
static var _mf_key := ""
static var _mf_val := false


static func _dept_moves_flow(s: PortSim, d: String) -> bool:
	var k := "%d|%s|%d|%d|%d|%d|%s" % [s.get_instance_id(), d, int(s.levels[d]), s.built.size(), s.tier, int(s.time), String(s.shown_analysis().get("key", ""))]
	if k != _mf_key:
		_mf_key = k
		_mf_val = moves_flow(s.upgrade_gain_parts(d, 1))
	return _mf_val


static func _dept_action(s: PortSim, d: String) -> Dictionary:
	var c := s.dept_cost(d, 1)
	return {"kind": "dept", "id": d, "cost": c, "can": c <= s.money, "label": "AMÉLIORER %s · %s" % [String(Info.DEPT_SHORT.get(d, d.to_upper())), Fmt.money(c)]}



## Achats d'un niveau abordables qui valent le coup (pastille d'Améliorer) — ou qui font avancer le chapitre en cours ;
## jamais un service sous un aléa.
static func worthwhile_count(s: PortSim) -> int:
	var n := 0
	var base := {}
	var goal := String(s.chapter_goal().get("dept", ""))
	for d in PortSim.DEPTS:
		var c := s.dept_cost(d, 1)
		if s.feature("dept_" + d) and c <= s.money:
			if d == goal:
				n += 1
				continue
			if Info.event_hits(s, d):
				continue
			if base.is_empty():
				base = s.income_parts_with("harbor", 0)
			if is_good(s.upgrade_gain_parts(d, 1, -1, base), c):
				n += 1
	for ci in PortSim.NCARGO:
		var lc := s.licence_cost(ci, 1)
		if s.unlocked[ci] == 1 and s.feature("licences") and s.licence_room(ci) > 0 and lc <= s.money:
			if base.is_empty():
				base = s.income_parts_with("harbor", 0)
			if is_good(s.upgrade_gain_parts("", 1, ci, base), lc):
				n += 1
	return n


## Lot E : un achat n'est « bon » (vert, pastille d'Améliorer, ★ MEILLEUR ACHAT) que s'il se rentabilise en moins de
## 10 minutes. Seuil fixe plutôt que « 2 × la médiane du palier » : lisible pour le joueur, stable d'une partie à l'autre, et
## la médiane du meilleur achat est de 2 à 6 minutes sur les trois paliers (sonde), donc 10 min reste au-dessus.
const GOOD_PAYBACK := 600.0


## Bon achat (pastille d'Améliorer, ★) : le débit bouge et l'achat se rentabilise en moins de GOOD_PAYBACK s.
static func is_good(parts: Dictionary, cost: float) -> bool:
	return moves_flow(parts) and cost / maxf(1.0e-9, float(parts.get("total", 0.0))) < GOOD_PAYBACK


## Le débit bouge-t-il vraiment (et pas seulement les services facturés) ? Bruit numérique écarté.
static func moves_flow(parts: Dictionary) -> bool:
	var f := float(parts.get("flow", 0.0))
	return f * 60.0 >= 0.05 and f > 1.0e-4 * absf(float(parts.get("total", 0.0)))


## Rentabilité d'un achat : {"text", "secs", "good"}. Débit qui bouge : « +X $/s · rentabilisé en … » (vert si < 10 min,
## gris au-delà) ; débit immobile : « Portiques +6 % · pas le goulot (+15 $/s de services) » en gris, jamais un
## « rentabilisé en 102 h » en vert (revue du lot D, E1). `label` : nom du service et effet (« Portiques +6 % »).
## `bottleneck` : le service est le goulot affiché, mais ce niveau ne le débloque pas (au plancher, ou il manque un poste à
## quai) — « le débit ne bouge pas » plutôt que « pas le goulot » à côté de la pastille GOULOT.
static func payback(parts: Dictionary, cost: float, label: String = "", bottleneck: bool = false) -> Dictionary:
	var gain := float(parts.get("total", 0.0))
	if not moves_flow(parts):
		var fees := float(parts.get("fees", 0.0))
		var head := (label + " · " if label != "" else "") + ("le débit ne bouge pas" if bottleneck else "pas le goulot")
		if fees * 60.0 >= 0.05:
			return {"text": "%s (+%s/s de services)" % [head, Fmt.money(fees)], "secs": INF, "good": false}
		return {"text": head[0].to_upper() + head.substr(1) + " : pas de gain immédiat", "secs": INF, "good": false}
	var secs := cost / maxf(1.0e-9, gain)
	return {"text": "+%s/s · rentabilisé en %s" % [Fmt.money(gain), Fmt.duration(secs)], "secs": secs, "good": secs < GOOD_PAYBACK}


## « Portiques +6 % » : nom court du service et effet relatif de `n` niveaux de plus sur sa statistique.
static func effect_label(s: PortSim, d: String, n: int) -> String:
	var st := Info.dept_stat_name(d)
	var a := s.stat(st)
	s.levels[d] = int(s.levels[d]) + n
	s.invalidate()
	var b := s.stat(st)
	s.levels[d] = int(s.levels[d]) - n
	s.invalidate()
	var nm := String(s.db.dept_by_id[d].name)
	if a <= 0.0 or b <= a:
		return nm
	return "%s +%d %%" % [nm, maxi(1, roundi((b / a - 1.0) * 100.0))]
