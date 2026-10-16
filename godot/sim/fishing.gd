class_name Fishing
extends RefCounted
## Lot G1 — la pêche de l'anse des pêcheurs, chapitre 1 « La Crique » (cadrage `docs/CADRAGE_DEBUT.md` § 5), puis revenu de fond.
## Deux cartes à niveaux (`places` 0–8 : une barque par place ; `services` 0–10 : le ticket d'escale, avec des paliers nommés qui
## bâtissent la criée, la pompe, le lavage, la glace), des bâtiments (`built` : quai des chalutiers, grande jetée, marina et ses
## deux extensions, la Concession du terre-plein) et un responsable, Marcel. **Argent = loyer par escale** : un bateau rentré paie
## `valeur(classe) × ticket` ; sans Marcel, le joueur l'encaisse à la main (bulle), sinon le bateau attend `rent_wait` s et
## repart sans payer ; avec Marcel, tout est encaissé. La marina paie un loyer continu par voilier. Plafond R₀ : tout au maximum.
## Module léger possédé et sauvegardé par PortSim (clé « act0 », sauvegarde v9) ; données dans `config.json` › `fishing`.
## Les durées des phases sont fixes (croisière lente, pas de sprint) : la vue suit chaque bateau à vitesse constante.
## Lot H1 — le service chronométré : dès la pompe (Services niv. 3), un bateau qui rentre passe aux stations du ponton de service
## (carburant, lavage, glace : celles qui sont bâties), une à la fois ; chaque station sert un bateau à la fois (sinon le poste
## d'attente, sinon le bateau passe son tour) ; le service dure `stations.dur × decay^(niveau − 3)` et se paie à la fin (l'anneau).

enum Phase { OUT, FISH, BACK, LAND, WAIT, QUEUE, SERVE, MOVE, DOCK }

var cfg: Dictionary = {}
var act0 := false            # la Crique en cours : le port à conteneurs est fermé (PortSim.time ne tourne pas)
var replay := false          # nouvelle concession : port fermé le temps de la séquence du T1, bascule sans condition
var places := 0              # niveau Places au ponton (0 = ponton pas réparé)
var services := 0            # niveau Services à quai
var built: Array[String] = []        # bâtiments faits (ids de cfg.buildings, Concession comprise)
var marcel := false          # Marcel embauché : il encaisse tout
var marcel_offered := false  # Marcel s'est présenté (après `marcel.after_rents` loyers encaissés à la main)
var rents_manual := 0        # loyers encaissés à la main
var rents_lost := 0          # bateaux repartis sans payer
var announced := false       # annonce du port (8ᵉ minute) faite
var last_reveal := -1.0e9    # horloge de la dernière nouveauté (Marcel, annonce) : jamais deux à moins de `reveal_gap` s
var boats: Array[Dictionary] = []    # {cls, slot, phase, t (s restantes), dur (s de la phase), paid, amount, via, at, to, done}
## Lot H1 — stations du ponton de service : id -> indice du bateau qui l'occupe ou l'a réservée (-1 libre) ; poste d'attente.
var occ: Dictionary = {}
var hold := -1
var served := 0                      # services rendus (stations)
var skipped := 0                     # bateaux qui ont passé leur tour (stations et attente prises)
var clock := 0.0             # horloge de la pêche (s) : Crique et après
var act0_time := 0.0         # durée de la Crique jouée (s)
var landings := 0
var earned := 0.0            # recettes de la pêche (Crique et après)
var events: Array[String] = []       # événements à relever par PortSim (« marcel_offer », « announce », « rent_lost »)
var restarted := false       # chargement d'une sauvegarde v6 en cours d'acte 0 : la Crique recommence (PortSim remet l'argent à 0)
var rng := RandomNumberGenerator.new()


func _init(db: DataDB = null, seed_value: int = 1) -> void:
	if db != null:
		cfg = db.cfg("fishing", {})
	rng.seed = seed_value * 7919 + 104729      # tirage à part : le port garde sa suite de nombres (sonde)


# --- cartes --------------------------------------------------------------------------------------------------------

func places_max() -> int:
	return int(cfg.get("places", {}).get("max", 8))


func services_max() -> int:
	return int(cfg.get("services", {}).get("max", 10))


## Coût du niveau suivant de Places (0 $ pour la réparation du ponton = niveau 1 ; INF au maximum).
func places_cost(n: int = 1) -> float:
	if places >= places_max():
		return INF
	if places == 0:
		return 0.0
	var p: Dictionary = cfg.get("places", {})
	return Progression.bulk_cost(float(p.get("cost", 15.0)), float(p.get("growth", 1.3)), places - 1, mini(n, places_max() - places))


## Niveaux de Places achetables d'un coup avec `money` (au moins 1 si le prochain est abordable).
func places_affordable(money: float) -> int:
	if places >= places_max():
		return 0
	if places == 0:
		return 1
	var p: Dictionary = cfg.get("places", {})
	return mini(places_max() - places, Progression.max_affordable(float(p.get("cost", 15.0)), float(p.get("growth", 1.3)), places - 1, money))


## Palier nommé d'un niveau de Services ({} sinon) : la criée au 1, la pompe au 3, le lavage au 6, la glace au 9.
func named_level(lv: int) -> Dictionary:
	return cfg.get("services", {}).get("named", {}).get(str(lv), {})


func _service_level_cost(lv: int) -> float:
	var sv: Dictionary = cfg.get("services", {})
	var c := float(sv.get("cost", 10.0)) * pow(float(sv.get("growth", 1.35)), float(lv - 1))
	if not named_level(lv).is_empty():
		c *= float(sv.get("named_mult", 3.0))
	return c


## Coût des `n` niveaux suivants de Services (INF au maximum).
func services_cost(n: int = 1) -> float:
	if services >= services_max():
		return INF
	var c := 0.0
	for k in mini(n, services_max() - services):
		c += _service_level_cost(services + 1 + k)
	return c


func services_affordable(money: float) -> int:
	var n := 0
	var c := 0.0
	while services + n < services_max():
		c += _service_level_cost(services + n + 1)
		if c > money + 1e-6:
			break
		n += 1
	return n


## Ticket d'escale : ce qu'un bateau paie en plus de sa valeur (+15 % par niveau de Services).
func ticket() -> float:
	return 1.0 + float(cfg.get("ticket_step", 0.15)) * float(services)


func buildings() -> Array:
	return cfg.get("buildings", [])


func building_def(id: String) -> Dictionary:
	for b in buildings():
		if String(b.id) == id:
			return b
	return {}


func has(id: String) -> bool:
	return built.has(id)


## Prochain bâtiment de la liste (hors Concession), {} quand tout est bâti.
func next_building() -> Dictionary:
	for b in buildings():
		if bool(b.get("concession", false)) or built.has(String(b.id)):
			continue
		return b
	return {}


func concession_def() -> Dictionary:
	for b in buildings():
		if bool(b.get("concession", false)):
			return b
	return {}


## La Concession est achetable dès la marina (pas besoin du plafond).
func concession_available() -> bool:
	var c := concession_def()
	if c.is_empty() or built.has(String(c.id)):
		return false
	var after := String(c.get("after", ""))
	return after == "" or built.has(after)


func concession_done() -> bool:
	var c := concession_def()
	return not c.is_empty() and built.has(String(c.id))


## Un bâtiment est achetable : le prochain de la liste, ou la Concession dès la marina.
func can_build(id: String) -> bool:
	if built.has(id):
		return false
	var b := building_def(id)
	if b.is_empty():
		return false
	if bool(b.get("concession", false)):
		return concession_available()
	return String(next_building().get("id", "")) == id


## Tout au maximum (hors Concession) : le plafond R₀, plus aucune carte de pêche.
func maxed() -> bool:
	return places >= places_max() and services >= services_max() and next_building().is_empty()


## Voiliers de la marina (revenu passif).
func sails() -> int:
	var n := 0
	for b in buildings():
		if built.has(String(b.id)):
			n = maxi(n, int(b.get("sail", 0)))
	return n


func boat_def(cls: String) -> Dictionary:
	return cfg.get("boats", {}).get(cls, {})


func boat_count(cls: String) -> int:
	var n := 0
	for bt in boats:
		if String(bt.cls) == cls:
			n += 1
	return n


static func _new_boat(cls: String, slot: int, phase: int, t: float, dur: float) -> Dictionary:
	return {"cls": cls, "slot": slot, "phase": phase, "t": t, "dur": dur, "paid": false, "amount": 0.0, "via": false, "at": "", "to": "", "done": false}


## Ajoute des bateaux (ils rentrent de la pêche vers leur place, l'un après l'autre).
func _add_boats(add: Dictionary, staggered: bool = true) -> void:
	var k := 0
	for cls in add:
		for n in int(add[cls]):
			var slot := boat_count(String(cls))
			var first := 2.0 + 5.0 * float(k) if staggered else rng.randf_range(0.0, 20.0)
			boats.append(_new_boat(String(cls), slot, Phase.FISH, first, maxf(first, 0.1)))
			k += 1


## Achats (la monnaie est vérifiée par PortSim). Renvoie le nombre de niveaux pris.
func buy_places(n: int, staggered: bool = true) -> int:
	n = mini(n, places_max() - places)
	if n <= 0:
		return 0
	var before := places
	places += n
	var add := int(cfg.get("places", {}).get("start_boats", 2)) if before == 0 else 0
	add += n - (1 if before == 0 else 0)
	_add_boats({"dinghy": add}, staggered)
	return n


func buy_services(n: int) -> int:
	n = mini(n, services_max() - services)
	if n <= 0:
		return 0
	services += n
	return n


func build(id: String, staggered: bool = true) -> bool:
	if not can_build(id):
		return false
	built.append(id)
	_add_boats(building_def(id).get("boats", {}), staggered)
	return true


func hire_marcel() -> bool:
	if marcel or not marcel_offered:
		return false
	marcel = true
	last_reveal = clock
	# il encaisse tout de suite les loyers en attente
	for bt in boats:
		if (int(bt.phase) == Phase.LAND or int(bt.phase) == Phase.WAIT) and not bool(bt.paid):
			bt.paid = true
			bt.amount = 0.0
	return true


func marcel_cost() -> float:
	return float(cfg.get("marcel", {}).get("cost", 40.0))


## Partie d'avant le lot G1 au T1 ou au-delà (ou nouvelle concession) : la Crique est finie, tout au maximum, Marcel embauché,
## Concession signée, la pêche au plafond R₀.
func migrate_done() -> void:
	act0 = false
	replay = false
	boats.clear()
	occ.clear()
	hold = -1
	places = 0
	services = 0
	built.clear()
	buy_places(places_max(), false)
	buy_services(services_max())
	for b in buildings():
		built.append(String(b.id))
		_add_boats(b.get("boats", {}), false)
	marcel_offered = true
	marcel = true
	announced = true


# --- cycle des bateaux ----------------------------------------------------------------------------------------------

## Montant du loyer d'un bateau (valeur × ticket × petit aléa, tiré à part du port).
func rent_of(bt: Dictionary) -> float:
	var v := float(boat_def(String(bt.cls)).get("value", 0.0)) * ticket()
	var j := float(cfg.get("jitter", 0.0))
	return v * (1.0 + rng.randf_range(-j, j))


# --- lot H1 : stations du ponton de service ---------------------------------------------------------------------------

func st_cfg() -> Dictionary:
	return cfg.get("stations", {})


## Stations bâties, dans l'ordre de visite (carburant, lavage, glace) : les paliers nommés marqués « station » atteints.
func stations() -> Array[String]:
	var out: Array[String] = []
	var named: Dictionary = cfg.get("services", {}).get("named", {})
	var lvs: Array = named.keys().map(func(k: String) -> int: return int(k))
	lvs.sort()
	for lv in lvs:
		var nl: Dictionary = named[str(lv)]
		if bool(nl.get("station", false)) and services >= int(lv):
			out.append(String(nl.id))
	return out


## Niveau de Services qui bâtit la première station (la pompe).
func first_station_level() -> int:
	var named: Dictionary = cfg.get("services", {}).get("named", {})
	var best := 99
	for k in named:
		if bool(named[k].get("station", false)):
			best = mini(best, int(k))
	return best


## Durée d'un service (s) : elle baisse à chaque niveau de Services (×`decay`), bornée à `min`.
func service_dur(lv: int = -1) -> float:
	var sc := st_cfg()
	if lv < 0:
		lv = services
	var k := maxi(0, lv - first_station_level())
	return maxf(float(sc.get("min", 2.0)), float(sc.get("dur", 6.0)) * pow(float(sc.get("decay", 0.88)), float(k)))


## Ce que paie un service (avant Heures sup) : valeur du bateau × `fee` (le ticket des Services s'applique au loyer ; ici,
## l'amélioration paie par la vitesse du service).
func service_fee(cls: String) -> float:
	return float(boat_def(cls).get("value", 0.0)) * float(st_cfg().get("fee", 0.2))


func station_free(id: String) -> bool:
	return int(occ.get(id, -1)) < 0


## Indice du bateau servi (ou qui arrive) à une station, -1 sinon.
func station_boat(id: String) -> int:
	return int(occ.get(id, -1))


## Place dans la file du ponton de service pour un bateau de plus (bateaux en route vers le point de décision, au poste
## d'attente, vers la première station ou à la première station : moins de `engaged`, 2 par défaut).
func _room_for_one() -> bool:
	var st := stations()
	if st.is_empty():
		return false
	var n := 0
	for bt in boats:
		var ph := int(bt.phase)
		if (ph == Phase.BACK and bool(bt.via)) or ph == Phase.QUEUE or (ph == Phase.MOVE and (String(bt.to) == "h" or String(bt.to) == st[0])):
			n += 1
		elif ph == Phase.SERVE and String(bt.at) == st[0]:
			n += 1
	return n < int(st_cfg().get("engaged", 2))


func _next_station(cur: String) -> String:
	var st := stations()
	var k := st.find(cur)
	return st[k + 1] if k >= 0 and k + 1 < st.size() else ""


## Durées des trajets (s) : `back_g` (coin de pêche → point de décision), `dock` (station ou point de décision → place).
func _leg(bt: Dictionary, kind: String) -> float:
	var d := boat_def(String(bt.cls))
	var sc := st_cfg()
	match kind:
		"back_g":
			return float(d.get("back_g", float(d.get("back", 20.0)) * 0.5))
		"dock":
			return float(d.get("dock", float(d.get("back", 20.0)) * 0.5))
		"approach":
			return float(sc.get("approach", 5.0))
		"hold_in":
			return float(sc.get("hold_in", 3.0))
		"hold_out":
			return float(sc.get("hold_out", 3.0))
		"move":
			return float(sc.get("move", 3.0))
	return 3.0


func _set_phase(bt: Dictionary, ph: int, dur: float) -> void:
	bt.phase = ph
	bt.dur = maxf(dur, 0.1)
	bt.t = float(bt.t) + float(bt.dur)


func _enter_land(bt: Dictionary) -> void:
	bt.paid = false
	bt.amount = rent_of(bt)
	bt.via = false
	bt.at = "b"
	bt.done = false
	_set_phase(bt, Phase.LAND, float(boat_def(String(bt.cls)).get("land", 5.0)))


## Au point de décision : la première station libre, sinon le poste d'attente, sinon le bateau passe son tour (vers sa place).
func _at_gate(i: int, bt: Dictionary) -> void:
	var st := stations()
	bt.at = "g"
	bt.done = false
	if st.is_empty():
		bt.to = "b"
		_set_phase(bt, Phase.DOCK, _leg(bt, "dock"))
		return
	if station_free(st[0]):
		occ[st[0]] = i
		bt.to = st[0]
		_set_phase(bt, Phase.MOVE, _leg(bt, "approach"))
	elif hold < 0:
		hold = i
		bt.to = "h"
		_set_phase(bt, Phase.MOVE, _leg(bt, "hold_in"))
	else:
		skipped += 1
		bt.to = "b"
		_set_phase(bt, Phase.DOCK, _leg(bt, "dock"))


## Fin d'un service (ou attente de la station suivante) : la station suivante si elle est libre, la place sinon. Renvoie false
## si le bateau garde son poste (station suivante occupée).
func _after_serve(i: int, bt: Dictionary) -> bool:
	var cur := String(bt.at)
	var nx := _next_station(cur)
	if nx != "":
		if not station_free(nx):
			return false
		occ[nx] = i
		occ[cur] = -1
		bt.to = nx
		bt.done = false
		_set_phase(bt, Phase.MOVE, _leg(bt, "move"))
		return true
	occ[cur] = -1
	bt.to = "b"
	bt.done = false
	_set_phase(bt, Phase.DOCK, _leg(bt, "dock"))
	return true


## Phase suivante du bateau ; renvoie true quand il repart (fin de LAND payé, ou de WAIT).
func _advance(i: int, bt: Dictionary) -> bool:
	var d := boat_def(String(bt.cls))
	var ph := int(bt.phase)
	match ph:
		Phase.OUT:
			bt.at = "sea"
			_set_phase(bt, Phase.FISH, float(d.get("fish", 5.0)))
		Phase.FISH:
			# lot H1 : avec une station au moins, le retour passe par le point de décision du ponton de service — sauf si la
			# file est déjà pleine (un bateau en route, au poste d'attente ou à la première station : au plus `engaged`) ; il
			# rentre alors droit à sa place, sans détour
			bt.via = _room_for_one()
			bt.at = "sea"
			bt.to = "g" if bool(bt.via) else "b"
			_set_phase(bt, Phase.BACK, _leg(bt, "back_g") if bool(bt.via) else float(d.get("back", 20.0)))
		Phase.BACK:
			if bool(bt.via):
				_at_gate(i, bt)
			else:
				_enter_land(bt)
		Phase.MOVE:
			bt.at = String(bt.to)
			if String(bt.at) == "h":
				bt.phase = Phase.QUEUE
				bt.dur = 0.25
				bt.t = 0.0
			else:
				_set_phase(bt, Phase.SERVE, service_dur())
		Phase.SERVE:
			# (le paiement du service est fait par `step`, qui connaît le multiplicateur et les rappels)
			if not _after_serve(i, bt):
				bt.done = true
				bt.t = 0.0
		Phase.DOCK:
			_enter_land(bt)
		Phase.LAND:
			if marcel or bool(bt.paid):
				bt.at = "sea"
				_set_phase(bt, Phase.OUT, float(d.get("out", 5.0)))
				return true
			_set_phase(bt, Phase.WAIT, float(cfg.get("rent_wait", 20.0)))
		Phase.WAIT:
			bt.at = "sea"
			_set_phase(bt, Phase.OUT, float(d.get("out", 5.0)))
			return true
	return false


## Un pas : chaque bateau avance dans son cycle ; la marina paie en continu. `mult` : Heures sup. `earn` reçoit (montant) ;
## `landed` reçoit (indice du bateau, montant, encaissé à la main ?). Les loyers encaissés par Marcel tombent à la fin de la
## débarque ; ceux encaissés à la main tombent au toucher (`collect`). Lot H1 : `served_cb` reçoit (indice du bateau, station,
## montant) à la fin de chaque service (l'anneau).
func step(dt: float, earn: Callable, landed: Callable = Callable(), mult: float = 1.0, served_cb: Callable = Callable()) -> void:
	if places <= 0:
		return
	clock += dt
	if act0:
		act0_time += dt
	var sail := float(cfg.get("sail_rent", 0.0)) * float(sails()) * dt * mult
	if sail > 0.0:
		earned += sail
		earn.call(sail)
	var st := stations()
	for i in boats.size():
		var bt: Dictionary = boats[i]
		var ph := int(bt.phase)
		# lot H1 : attentes (poste d'attente, station suivante occupée) — on regarde à chaque pas
		if ph == Phase.QUEUE:
			if not st.is_empty() and station_free(st[0]):
				occ[st[0]] = i
				hold = -1
				bt.to = st[0]
				bt.t = 0.0
				_set_phase(bt, Phase.MOVE, _leg(bt, "hold_out"))
			continue
		if ph == Phase.SERVE and bool(bt.done):
			bt.t = 0.0
			_after_serve(i, bt)
			continue
		bt.t = float(bt.t) - dt
		var guard := 0
		while float(bt.t) <= 0.0 and guard < 8:
			guard += 1
			var ph0 := int(bt.phase)
			var paid0 := bool(bt.paid)
			if ph0 == Phase.SERVE and not bool(bt.done):
				var fee := service_fee(String(bt.cls)) * mult
				served += 1
				earned += fee
				earn.call(fee)
				if served_cb.is_valid():
					served_cb.call(i, String(bt.at), fee)
			if _advance(i, bt):
				landings += 1
				var amount := 0.0
				if ph0 == Phase.LAND and marcel and not paid0:
					amount = float(bt.amount) * mult
					bt.paid = true
					earned += amount
					earn.call(amount)
				elif ph0 == Phase.WAIT and not paid0:
					rents_lost += 1
					events.append("rent_lost")
				bt.amount = 0.0
				if landed.is_valid():
					landed.call(i, amount, false)
			if int(bt.phase) == Phase.QUEUE or (int(bt.phase) == Phase.SERVE and bool(bt.done)):
				break
	# l'annonce du port : à la 8ᵉ minute, la criée faite, à distance de la dernière nouveauté
	if act0 and not announced and services >= 1 and clock >= float(cfg.get("announce_at", 480.0)) \
			and clock - last_reveal >= float(cfg.get("reveal_gap", 45.0)):
		announced = true
		last_reveal = clock
		events.append("announce")


## Un bateau rentré dont le loyer attend (bulle « Loyer »), tant que Marcel n'est pas là.
func can_collect(i: int) -> bool:
	if marcel or i < 0 or i >= boats.size():
		return false
	var bt: Dictionary = boats[i]
	return not bool(bt.paid) and (int(bt.phase) == Phase.LAND or int(bt.phase) == Phase.WAIT)


## Toucher un bateau rentré : son loyer est encaissé (montant renvoyé, 0 si rien) ; s'il attendait, il repart tout de suite.
func collect(i: int, mult: float = 1.0) -> float:
	if not can_collect(i):
		return 0.0
	var bt: Dictionary = boats[i]
	var amount := float(bt.amount) * mult
	bt.paid = true
	bt.amount = 0.0
	rents_manual += 1
	earned += amount
	if int(bt.phase) == Phase.WAIT:
		bt.t = 0.0      # il repart au pas suivant
	if not marcel_offered and rents_manual >= int(cfg.get("marcel", {}).get("after_rents", 5)):
		marcel_offered = true
		last_reveal = clock
		events.append("marcel_offer")
	return amount


## Secondes avant qu'un bateau qui attend son loyer reparte sans payer (INF s'il n'attend pas).
func wait_left(i: int) -> float:
	if i < 0 or i >= boats.size():
		return INF
	var bt: Dictionary = boats[i]
	return float(bt.t) if int(bt.phase) == Phase.WAIT else INF


## Progression (0–1) du bateau i dans sa phase.
func progress(i: int) -> float:
	var bt: Dictionary = boats[i]
	return clampf(1.0 - float(bt.t) / maxf(0.01, float(bt.dur)), 0.0, 1.0)


# --- revenus --------------------------------------------------------------------------------------------------------

## Revenu estimé de la pêche ($/s) : loyers moyens sur un cycle (loyers encaissés sans attente) + marina. Lot H1 : avec des
## stations, le cycle compte les services (durée, trajets entre stations) et leur prix (sans file : estimation).
func rate_estimate() -> float:
	if places <= 0:
		return 0.0
	var r := float(cfg.get("sail_rent", 0.0)) * float(sails())
	for bt in boats:
		r += boat_rate(String(bt.cls))
	return r


## Revenu moyen d'un bateau de la classe ($/s) au niveau actuel (sans file d'attente).
func boat_rate(cls: String, sv: int = -1) -> float:
	var keep := services
	if sv >= 0:
		services = sv
	var d := boat_def(cls)
	var cyc := float(d.get("out", 1)) + float(d.get("fish", 1)) + float(d.get("back", 1)) + float(d.get("land", 1))
	var gain := float(d.get("value", 0.0)) * ticket()
	var n := stations().size()
	if n > 0:
		cyc += float(d.get("back_g", float(d.get("back", 20.0)) * 0.5)) + float(d.get("dock", float(d.get("back", 20.0)) * 0.5)) \
			- float(d.get("back", 1)) + float(st_cfg().get("approach", 5.0)) + float(n) * service_dur() + float(n - 1) * float(st_cfg().get("move", 3.0))
		gain += float(n) * service_fee(cls)
	services = keep
	return gain / maxf(1.0, cyc)


## Revenu hors-ligne ($/s) : Marcel encaisse à son rythme ; sans lui, rien (le monde se fige).
func offline_rate() -> float:
	return rate_estimate() if marcel else 0.0


## Plafond R₀ : le revenu estimé une fois tout au maximum (pour les cartes et la sonde).
func cap_rate() -> float:
	var f := Fishing.new()
	f.cfg = cfg
	f.migrate_done()
	return f.rate_estimate()


# --- sauvegarde (v9 ; v7/v8 lues sans perte : pas de stations en cours) -------------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var bl: Array = []
	for bt in boats:
		bl.append({"cls": bt.cls, "slot": bt.slot, "phase": bt.phase, "t": bt.t, "dur": bt.dur, "paid": bt.paid, "amount": bt.amount,
			"via": bt.via, "at": bt.at, "to": bt.to, "done": bt.done})
	# lot H1 (v9) : stations du ponton de service (occupées ou réservées), poste d'attente, compteurs
	return {"v": 9, "occ": occ.duplicate(), "hold": hold, "served": served, "skipped": skipped, "on": act0, "replay": replay, "places": places, "services": services, "built": built.duplicate(), "marcel": marcel,
		"marcel_offered": marcel_offered, "rents_manual": rents_manual, "rents_lost": rents_lost, "announced": announced,
		"last_reveal": last_reveal, "boats": bl, "clock": clock, "act0_time": act0_time, "landings": landings, "earned": earned,
		"rng_state": str(rng.state)}


func from_dict(d: Dictionary) -> void:
	restarted = false
	if not d.has("places"):
		# sauvegarde v6 (lot F3) : en cours d'acte 0, la Crique recommence ; sinon, elle est finie (plafond R₀)
		if bool(d.get("on", false)) and not bool(d.get("replay", false)):
			act0 = true
			replay = false
			restarted = true
		else:
			migrate_done()
			act0 = bool(d.get("on", false)) and bool(d.get("replay", false))
			replay = act0
			act0_time = float(d.get("act0_time", 0.0))
			clock = float(d.get("clock", 0.0))
			earned = float(d.get("earned", 0.0))
			landings = int(d.get("landings", 0))
		return
	act0 = bool(d.get("on", false))
	replay = bool(d.get("replay", false))
	places = clampi(int(d.get("places", 0)), 0, places_max())
	services = clampi(int(d.get("services", 0)), 0, services_max())
	built.clear()
	for b in d.get("built", []):
		if not building_def(String(b)).is_empty():
			built.append(String(b))
	marcel = bool(d.get("marcel", false))
	marcel_offered = bool(d.get("marcel_offered", false)) or marcel
	rents_manual = int(d.get("rents_manual", 0))
	rents_lost = int(d.get("rents_lost", 0))
	announced = bool(d.get("announced", false))
	last_reveal = float(d.get("last_reveal", -1.0e9))
	clock = float(d.get("clock", 0.0))
	act0_time = float(d.get("act0_time", 0.0))
	landings = int(d.get("landings", 0))
	earned = float(d.get("earned", 0.0))
	if d.has("rng_state"):
		rng.state = int(String(d.rng_state))
	boats.clear()
	for b in d.get("boats", []):
		if b is Dictionary and cfg.get("boats", {}).has(String(b.get("cls", ""))):
			var nb := _new_boat(String(b.cls), int(b.get("slot", 0)), clampi(int(b.get("phase", 0)), 0, Phase.DOCK),
				float(b.get("t", 1.0)), maxf(0.1, float(b.get("dur", 1.0))))
			nb.paid = bool(b.get("paid", false))
			nb.amount = float(b.get("amount", 0.0))
			nb.via = bool(b.get("via", false))
			nb.at = String(b.get("at", ""))
			nb.to = String(b.get("to", ""))
			nb.done = bool(b.get("done", false))
			boats.append(nb)
	# lot H1 : stations (v9) ; une sauvegarde v7/v8 n'en a pas (aucun bateau n'y est engagé : phases 0–4)
	occ.clear()
	var od: Dictionary = d.get("occ", {}) if d.get("occ") is Dictionary else {}
	for k in od:
		var bi := int(od[k])
		occ[String(k)] = bi if bi >= 0 and bi < boats.size() else -1
	hold = int(d.get("hold", -1))
	if hold >= boats.size():
		hold = -1
	served = int(d.get("served", 0))
	skipped = int(d.get("skipped", 0))
	# sauvegarde incohérente (bateaux perdus) : on les recrée d'après les achats
	if boats.is_empty() and places > 0:
		_add_boats({"dinghy": int(cfg.get("places", {}).get("start_boats", 2)) + places - 1}, false)
		for id in built:
			_add_boats(building_def(id).get("boats", {}), false)
