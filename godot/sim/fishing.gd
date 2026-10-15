class_name Fishing
extends RefCounted
## Lot F3 — la pêche de l'anse des pêcheurs. Acte 0 « La Crique » : cinq achats (ponton, deuxième ponton, criée, quai des
## chalutiers, fabrique de glace) ; les bateaux du village louent les places, sortent en mer, rentrent et débarquent ; revenu
## = loyer des places + vente des caisses (×2 à la criée). Après l'acte 0 : un revenu fixe et passif, les bateaux continuent
## de vivre à l'écran. Module léger possédé et sauvegardé par PortSim (clé « act0 », sauvegarde v6) ; données dans
## `config.json` › `fishing`. Les durées des phases sont fixes (aucun achat ne les change) : la vue suit chaque bateau à
## vitesse constante (croisière lente, pas de sprint).

enum Phase { OUT, FISH, BACK, LAND }

var cfg: Dictionary = {}
var act0 := false            # acte 0 en cours : le port à conteneurs est fermé (PortSim.time ne tourne pas)
var replay := false          # nouvelle concession : port fermé le temps de la séquence du T1, bascule sans condition
var level := 0               # achats faits (0 à 5)
var boats: Array[Dictionary] = []    # {cls, slot, phase, t (s restantes), dur (s de la phase), helped}
var clock := 0.0             # horloge de la pêche (s) : acte 0 et après
var act0_time := 0.0         # durée de l'acte 0 jouée (s)
var landings := 0
var helps := 0               # coups de main donnés (toucher une barque qui rentre)
var earned := 0.0            # recettes de la pêche (acte 0 et passif)
var rng := RandomNumberGenerator.new()


func _init(db: DataDB = null, seed_value: int = 1) -> void:
	if db != null:
		cfg = db.cfg("fishing", {})
	rng.seed = seed_value * 7919 + 104729      # tirage à part : le port garde sa suite de nombres (sonde)


func buys() -> Array:
	return cfg.get("buys", [])


func buy_count() -> int:
	return buys().size()


## Achat suivant de l'acte 0 ({} quand les cinq sont faits).
func next_buy() -> Dictionary:
	var b := buys()
	return b[level] if level < b.size() else {}


func next_cost() -> float:
	var nb := next_buy()
	return float(nb.get("cost", INF)) if not nb.is_empty() else INF


func done_all() -> bool:
	return level >= buy_count() and buy_count() > 0


func has_hall() -> bool:
	var b := buys()
	for i in mini(level, b.size()):
		if bool(b[i].get("hall", false)):
			return true
	return false


func boat_def(cls: String) -> Dictionary:
	return cfg.get("boats", {}).get(cls, {})


## Applique l'achat i : ses bateaux arrivent l'un après l'autre (ils rentrent de la pêche vers leur place).
func apply_buy(i: int, staggered: bool = true) -> void:
	var b: Dictionary = buys()[i]
	var add: Dictionary = b.get("boats", {})
	var k := 0
	for cls in add:
		for n in int(add[cls]):
			var slot := 0
			for bt in boats:
				if String(bt.cls) == String(cls):
					slot += 1
			var first := 2.0 + 5.0 * float(k) if staggered else rng.randf_range(0.0, 20.0)
			boats.append({"cls": String(cls), "slot": slot, "phase": Phase.FISH, "t": first, "dur": maxf(first, 0.1), "helped": false})
			k += 1


## Partie d'avant le lot F3 (ou nouvelle concession) : l'acte 0 est fait, les cinq achats aussi, la pêche est passive.
func migrate_done() -> void:
	act0 = false
	boats.clear()
	level = buy_count()
	for i in level:
		apply_buy(i, false)


## Phase suivante du bateau ; renvoie true à la fin d'une débarque.
func _advance(bt: Dictionary) -> bool:
	var d := boat_def(String(bt.cls))
	var ph := int(bt.phase)
	var landed := false
	match ph:
		Phase.OUT:
			ph = Phase.FISH
		Phase.FISH:
			ph = Phase.BACK
		Phase.BACK:
			ph = Phase.LAND
		Phase.LAND:
			ph = Phase.OUT
			landed = true
	bt.phase = ph
	var dur := float(d.get(["out", "fish", "back", "land"][ph], 5.0))
	if ph == Phase.LAND and bool(bt.helped):
		dur = minf(dur, float(cfg.get("help_land", 1.2)))
	bt.dur = maxf(dur, 0.1)
	bt.t = float(bt.t) + float(bt.dur)
	return landed


## Montant d'une débarque (acte 0) : valeur du bateau × criée × coup de main × petit aléa de la pêche.
func landing_value(bt: Dictionary) -> float:
	var v := float(boat_def(String(bt.cls)).get("value", 0.0))
	if has_hall():
		v *= float(cfg.get("hall_mult", 1.0))
	if bool(bt.helped):
		v *= float(cfg.get("help_mult", 1.0))
	var j := float(cfg.get("jitter", 0.0))
	return v * (1.0 + rng.randf_range(-j, j))


## Un pas : chaque bateau avance dans son cycle. Pendant l'acte 0, le loyer des places tombe en continu et chaque débarque
## est vendue ; ensuite, un revenu fixe (`passive`). `earn` reçoit (montant) ; `landed` reçoit (indice du bateau, montant).
func step(dt: float, earn: Callable, landed: Callable = Callable()) -> void:
	if level <= 0:
		return
	clock += dt
	if act0:
		act0_time += dt
		var rent := float(cfg.get("rent", 0.0)) * float(boats.size()) * dt
		if rent > 0.0:
			earned += rent
			earn.call(rent)
	else:
		var p := passive_rate() * dt
		if p > 0.0:
			earned += p
			earn.call(p)
	for i in boats.size():
		var bt: Dictionary = boats[i]
		bt.t = float(bt.t) - dt
		var guard := 0
		while float(bt.t) <= 0.0 and guard < 8:
			guard += 1
			var was_helped := bool(bt.helped)
			if _advance(bt):
				var amount := landing_value(bt) if act0 else 0.0
				bt.helped = false
				landings += 1
				if amount > 0.0:
					earned += amount
					earn.call(amount)
				if landed.is_valid():
					landed.call(i, amount, was_helped)


## Toucher un bateau qui rentre (ou qui débarque) : il débarque tout de suite et sa vente rapporte plus (acte 0 seulement).
func can_help(i: int) -> bool:
	if not act0 or i < 0 or i >= boats.size():
		return false
	var bt: Dictionary = boats[i]
	return not bool(bt.helped) and (int(bt.phase) == Phase.BACK or int(bt.phase) == Phase.LAND)


func help(i: int) -> bool:
	if not can_help(i):
		return false
	var bt: Dictionary = boats[i]
	bt.helped = true
	helps += 1
	if int(bt.phase) == Phase.LAND:
		var hl := float(cfg.get("help_land", 1.2))
		var done := float(bt.dur) - float(bt.t)
		bt.t = maxf(0.0, minf(float(bt.t), hl - done))
		bt.dur = minf(float(bt.dur), hl)
	return true


## Progression (0–1) du bateau i dans sa phase.
func progress(i: int) -> float:
	var bt: Dictionary = boats[i]
	return clampf(1.0 - float(bt.t) / maxf(0.01, float(bt.dur)), 0.0, 1.0)


## Revenu fixe de la pêche après l'acte 0 ($/s), proportionnel aux achats faits.
func passive_rate() -> float:
	if level <= 0 or buy_count() == 0:
		return 0.0
	return float(cfg.get("passive", 0.0)) * float(level) / float(buy_count())


## Revenu estimé de l'acte 0 ($/s, sans coup de main) : débarques moyennes sur un cycle + loyer.
func rate_estimate() -> float:
	if level <= 0:
		return 0.0
	if not act0:
		return passive_rate()
	var r := float(cfg.get("rent", 0.0)) * float(boats.size())
	var hall := float(cfg.get("hall_mult", 1.0)) if has_hall() else 1.0
	for bt in boats:
		var d := boat_def(String(bt.cls))
		var cyc := float(d.get("out", 1)) + float(d.get("fish", 1)) + float(d.get("back", 1)) + float(d.get("land", 1))
		r += float(d.get("value", 0.0)) * hall / maxf(1.0, cyc)
	return r


func boat_count(cls: String) -> int:
	var n := 0
	for bt in boats:
		if String(bt.cls) == cls:
			n += 1
	return n


func to_dict() -> Dictionary:
	var bl: Array = []
	for bt in boats:
		bl.append({"cls": bt.cls, "slot": bt.slot, "phase": bt.phase, "t": bt.t, "dur": bt.dur, "helped": bt.helped})
	return {"on": act0, "replay": replay, "level": level, "boats": bl, "clock": clock, "act0_time": act0_time, "landings": landings,
		"helps": helps, "earned": earned, "rng_state": str(rng.state)}


func from_dict(d: Dictionary) -> void:
	act0 = bool(d.get("on", false))
	replay = bool(d.get("replay", false))
	level =clampi(int(d.get("level", 0)), 0, buy_count())
	clock = float(d.get("clock", 0.0))
	act0_time = float(d.get("act0_time", 0.0))
	landings = int(d.get("landings", 0))
	helps = int(d.get("helps", 0))
	earned = float(d.get("earned", 0.0))
	if d.has("rng_state"):
		rng.state = int(String(d.rng_state))
	boats.clear()
	for b in d.get("boats", []):
		if b is Dictionary and cfg.get("boats", {}).has(String(b.get("cls", ""))):
			boats.append({"cls": String(b.cls), "slot": int(b.get("slot", 0)), "phase": clampi(int(b.get("phase", 0)), 0, 3),
				"t": float(b.get("t", 1.0)), "dur": maxf(0.1, float(b.get("dur", 1.0))), "helped": bool(b.get("helped", false))})
	# sauvegarde incohérente (bateaux perdus) : on les recrée d'après les achats
	if boats.is_empty() and level > 0:
		var keep := act0
		var lv := level
		migrate_done()
		level = lv
		boats.clear()
		for i in level:
			apply_buy(i, false)
		act0 = keep
