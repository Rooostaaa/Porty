class_name DataDB
extends RefCounted
## Charge toutes les données d'équilibrage depuis data/*.json (aucune valeur en dur dans le code).

var config: Dictionary = {}
var departments: Array = []
var cargo: Array = []
var ships: Array = []
var owners: Array = []
var buildings: Array = []
var tiers: Array = []
var events: Array = []
var contracts: Array = []
var missions: Array = []
var unlocks: Array = []             # fonctions révélées au fil de la partie (interface + simulation)

var dept_by_id: Dictionary = {}
var cargo_index: Dictionary = {}   # id -> index
var ship_by_id: Dictionary = {}
var owner_by_id: Dictionary = {}
var building_by_id: Dictionary = {}
var event_by_id: Dictionary = {}
var contract_by_id: Dictionary = {}
var unlock_by_id: Dictionary = {}


static func load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("DataDB : impossible d'ouvrir " + path)
		return null
	var txt := f.get_as_text()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed == null:
		push_error("DataDB : JSON invalide " + path)
	return parsed


func _init(base: String = "res://data/") -> void:
	config = load_json(base + "config.json")
	departments = load_json(base + "departments.json")
	cargo = load_json(base + "cargo.json")
	ships = load_json(base + "ships.json")
	owners = load_json(base + "owners.json")
	buildings = load_json(base + "buildings.json")
	tiers = load_json(base + "tiers.json")
	events = load_json(base + "events.json")
	contracts = load_json(base + "contracts.json")
	missions = load_json(base + "missions.json")
	unlocks = load_json(base + "unlocks.json")
	for d in departments:
		dept_by_id[d.id] = d
	for i in cargo.size():
		cargo_index[cargo[i].id] = i
	for s in ships:
		ship_by_id[s.id] = s
	for o in owners:
		owner_by_id[o.id] = o
	for b in buildings:
		building_by_id[b.id] = b
	for e in events:
		event_by_id[e.id] = e
	for c in contracts:
		contract_by_id[c.id] = c
	for u in unlocks:
		unlock_by_id[u.id] = u


func cfg(key: String, default: Variant = null) -> Variant:
	return config.get(key, default)


func tier_def(tier: int) -> Dictionary:
	for t in tiers:
		if int(t.id) == tier:
			return t
	return {}
