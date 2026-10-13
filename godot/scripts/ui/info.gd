class_name Info
extends RefCounted
## Textes d'effets des départements et explications « pourquoi ».

const DEPT_ICON := {"harbor": "harbor", "berths": "berth", "customs": "customs", "cranes": "crane", "yard_ops": "yard", "gate": "gate"}
const DEPT_COLOR := {
	"harbor": Color("#3D8BEB"), "berths": Color("#2BAFAA"), "customs": Color("#4B3FB5"),
	"cranes": Color("#FF8A3D"), "yard_ops": Color("#38B76A"), "gate": Color("#E25B4B"),
}
const CARGO_ICON := {"std": "box", "reefer": "reefer", "imo": "imo", "oog": "oog", "empty": "box"}
const CARGO_COLOR := {"std": Color("#E25B4B"), "reefer": Color("#3D8BEB"), "imo": Color("#F0653A"), "oog": Color("#E0A800"), "empty": Color("#A9AFB9")}


static func per_min(v: float) -> String:
	return Fmt.num(v * 60.0) + " EVP/min"


## Effet principal d'un département au niveau courant (ou avec `extra` niveaux de plus).
static func dept_effect(sim: PortSim, dept: String, extra: int = 0) -> String:
	if extra > 0:
		sim.levels[dept] = int(sim.levels[dept]) + extra
		sim.invalidate()
	var s := ""
	match dept:
		"harbor":
			s = "%s s" % ("%.1f" % sim.pilot_duration()).replace(".", ",")
		"berths":
			s = "%s s" % ("%.1f" % sim.moor_duration()).replace(".", ",")
		"customs":
			s = per_min(sim.stat("inspect_rate"))
		"cranes":
			s = per_min(sim.stat("crane_rate"))
		"yard_ops":
			s = per_min(sim.stat("transfer_rate"))
		"gate":
			s = per_min(sim.stat("gate_rate"))
	if extra > 0:
		sim.levels[dept] = int(sim.levels[dept]) - extra
		sim.invalidate()
	return s


static func dept_detail(sim: PortSim, dept: String) -> String:
	match dept:
		"harbor":
			return "Pilotes : %d · Places en rade : %d · plancher %s s" % [sim.pilots(), sim.rade_places(), ("%.1f" % sim.min_time("pilot")).replace(".", ",")]
		"berths":
			return "Tablier : %s EVP · %d poste(s)" % [Fmt.num(sim.apron_capacity()), sim.berths.size()]
		"customs":
			return "Formalités : %s s · %s" % [("%.1f" % sim.formal_duration()).replace(".", ","), String(sim.db.cfg("policies")[sim.policy].name)]
		"cranes":
			var n := 0
			for b in sim.berths:
				n += (b.cranes as Array).size()
			return "%d grue(s) au total" % n
		"yard_ops":
			return "Empilage ×%s · Parc %s EVP" % [("%.2f" % sim.stack_factor()).replace(".", ","), Fmt.num(sim.yard_capacity())]
		"gate":
			return "%d voie(s) · attente camion %s s" % [sim.gate_lanes, ("%.0f" % sim.truck_wait_estimate())]
	return ""


static func dept_stat_name(dept: String) -> String:
	return {"harbor": "pilot_speed", "berths": "moor_speed", "customs": "inspect_rate", "cranes": "crane_rate", "yard_ops": "transfer_rate", "gate": "gate_rate"}[dept]


## Lignes « pourquoi » : [{label, value}] et le produit.
static func explain(sim: PortSim, stat: String, cargo_i: int = 0) -> Array[Dictionary]:
	return sim.breakdown(stat, cargo_i)


static func cargo_value(sim: PortSim, ci: int, extra: int = 0) -> float:
	if extra > 0:
		sim.licences[ci] += extra
		sim.invalidate()
	var v := sim.stat("value", ci)
	if extra > 0:
		sim.licences[ci] -= extra
		sim.invalidate()
	return v


static func building_name_for_cargo(sim: PortSim, cid: String) -> String:
	for b in sim.db.buildings:
		for e in b.effects:
			if e.type == "unlock_cargo" and e.cargo == cid:
				return String(b.name)
	return ""


# --- étapes nommées (paliers de niveau d'un département ou d'une licence) ---------------------------

## Étape atteinte au niveau `lv` : la dernière de `def.stages` dont le niveau est franchi.
static func stage(def: Dictionary, lv: int) -> Dictionary:
	var cur: Dictionary = {}
	for st in def.get("stages", []):
		if int(st.lv) <= lv:
			cur = st
	return cur


## Étape suivante (vide s'il n'y en a plus).
static func next_stage(def: Dictionary, lv: int) -> Dictionary:
	for st in def.get("stages", []):
		if int(st.lv) > lv:
			return st
	return {}


## Multiplicateur apporté par le palier du niveau `lv` (départements : ×2 aux paliers ; licences : liste [[niveau, mult]]).
static func stage_mult(sim: PortSim, cargo_i: int, lv: int) -> float:
	if lv <= 1:
		return 1.0
	if cargo_i >= 0:
		for st in sim.db.cfg("licence_milestones"):
			if int(st[0]) == lv:
				return float(st[1])
		return 1.0
	return float(sim.db.cfg("dept_milestone_mult")) if sim.db.cfg("dept_milestones").has(float(lv)) or sim.db.cfg("dept_milestones").has(lv) else 1.0
