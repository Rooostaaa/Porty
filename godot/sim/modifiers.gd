class_name Modifiers
extends RefCounted
## Registre central des modificateurs temporaires (aléas, boost…).
## Les modificateurs permanents (niveaux, bâtiments, responsables) sont calculés par PortSim.breakdown().

var entries: Array[Dictionary] = []   # {id, stat, mult, label, until}


func add(id: String, stat: String, mult: float, label: String, until: float) -> void:
	remove_stat(id, stat)
	entries.append({"id": id, "stat": stat, "mult": mult, "label": label, "until": until})


func remove(id: String) -> void:
	entries = entries.filter(func(e: Dictionary) -> bool: return e.id != id)


func remove_stat(id: String, stat: String) -> void:
	entries = entries.filter(func(e: Dictionary) -> bool: return not (e.id == id and e.stat == stat))


func has(id: String) -> bool:
	for e in entries:
		if e.id == id:
			return true
	return false


## Retire les modificateurs expirés ; renvoie les identifiants retirés.
func purge(now: float) -> Array[String]:
	var gone: Array[String] = []
	var keep: Array[Dictionary] = []
	for e in entries:
		if float(e.until) <= now:
			if not gone.has(e.id):
				gone.append(e.id)
		else:
			keep.append(e)
	entries = keep
	return gone


func factors(stat: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in entries:
		if e.stat == stat:
			out.append({"label": e.label, "value": float(e.mult)})
	return out


func to_array() -> Array:
	return entries.duplicate(true)


func from_array(arr: Array) -> void:
	entries.clear()
	for e in arr:
		entries.append(e)
