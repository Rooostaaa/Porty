class_name Ship
extends RefCounted
## Une escale : un navire discret qui traverse la chaîne rade → quai → départ.

enum State { ARRIVING, ANCHORED, PILOTING, MOORING, FORMALITIES, UNLOADING, DEPARTING, LEAVING }
enum Mood { HAPPY, NEUTRAL, ANGRY }

const STATE_NAMES := ["En approche", "En rade", "Pilotage", "Amarrage", "Formalités", "Déchargement", "Départ", "Repart furieux"]

var id: int = 0
var cls: String = ""
var owner: String = ""
var evp_total: float = 0.0
var left: PackedFloat64Array = PackedFloat64Array()   # EVP restants par type de cargaison
var state: int = State.ARRIVING
var timer: float = 0.0          # temps restant dans l'état courant (états minutés)
var patience: float = 60.0
var patience_max: float = 60.0
var berth: int = -1
var wait_time: float = 0.0      # temps passé en rade
var anchor_slot: int = -1
var priority: bool = false      # choisi par le joueur
var mood_at_berth: int = Mood.HAPPY


func evp_left() -> float:
	var s := 0.0
	for v in left:
		s += v
	return s


func patience_ratio() -> float:
	return clampf(patience / maxf(0.001, patience_max), 0.0, 1.0)


func mood() -> int:
	var r := patience_ratio()
	if r > 0.5:
		return Mood.HAPPY
	if r > 0.2:
		return Mood.NEUTRAL
	return Mood.ANGRY


func progress() -> float:
	if evp_total <= 0.0:
		return 1.0
	return 1.0 - evp_left() / evp_total


func to_dict() -> Dictionary:
	return {
		"id": id, "cls": cls, "owner": owner, "evp_total": evp_total, "left": Array(left),
		"state": state, "timer": timer, "patience": patience, "patience_max": patience_max,
		"berth": berth, "wait_time": wait_time, "anchor_slot": anchor_slot, "priority": priority,
		"mood_at_berth": mood_at_berth,
	}


static func from_dict(d: Dictionary) -> Ship:
	var s := Ship.new()
	s.id = int(d.id)
	s.cls = d.cls
	s.owner = d.owner
	s.evp_total = float(d.evp_total)
	s.left = PackedFloat64Array(d.left)
	s.state = int(d.state)
	s.timer = float(d.timer)
	s.patience = float(d.patience)
	s.patience_max = float(d.patience_max)
	s.berth = int(d.berth)
	s.wait_time = float(d.wait_time)
	s.anchor_slot = int(d.get("anchor_slot", -1))
	s.priority = bool(d.get("priority", false))
	s.mood_at_berth = int(d.get("mood_at_berth", 0))
	return s
