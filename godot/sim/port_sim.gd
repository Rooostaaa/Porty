class_name PortSim
extends RefCounted
## Simulation complète du terminal. Aucune dépendance aux nœuds : la vue s'abonne aux signaux.
## Flux : rade → pilotage → quai (amarrage, formalités, déchargement) → tablier → parc (à inspecter / dédouané) → gate.

signal ship_spawned(ship: Ship)
signal ship_state_changed(ship: Ship)
signal ship_removed(ship: Ship)
signal revenue(amount: float, source: String)
signal notify(text: String, kind: String)
signal purchased(kind: String, id: String)
signal truck_served(wait: float)
signal inspection_result(outcome: String, owner: String)
signal tier_changed(tier: int)
signal event_started(ev: Dictionary)
signal event_ended(id: String)
signal contracts_changed()
signal mission_ready(id: String)
signal feature_unlocked(id: String)          # une fonction de jeu se révèle (data/unlocks.json)
signal ship_class_first(ship: Ship)          # premier navire d'une nouvelle classe : moment marquant
signal fish_landed(boat_i: int, amount: float, manual: bool)   # lot F3/G1 : un bateau de pêche repart (vue : caisses) ; montant encaissé par Marcel
signal fish_event(kind: String)
signal fish_served(boat_i: int, station: String, amount: float)   # lot H1 : fin d'un service au ponton de service (l'anneau)
signal manager_offered(dept: String)         # lot G2 : un responsable du port se présente (après 5 gestes)
signal gesture_done(kind: String, amount: float)   # lot G2 : tampon (« stamp ») ou camion servi (« pass ») d'un toucher              # lot G1 : « marcel_offer », « announce », « rent_lost », « rent_paid »

const NCARGO := 5
const NZONE := 4
const DEPTS := ["harbor", "berths", "customs", "cranes", "yard_ops", "gate"]

var db: DataDB
var rng := RandomNumberGenerator.new()
var mods := Modifiers.new()
## Lot F3 — la pêche de l'anse (acte 0, puis revenu passif). Pendant l'acte 0 (`fishing.act0`), le port à conteneurs est
## fermé : `step` n'avance que la pêche et `time` (l'horloge du port, depuis l'entrée au T1) ne tourne pas.
var fishing: Fishing
## Lot G2 — le Terre-plein. `g2` : la partie joue le processus à la main (partie neuve depuis la Crique, nouvelle concession) :
## la friche est nue, les six pièces du départ (STARTERS) s'achètent une à une, rien n'avance sans le joueur tant que les
## responsables des gestes (Léon, Paul, Tonio) ne sont pas embauchés. Faux : port complet (tests, parties d'avant G2), les
## six pièces sont bâties d'office et les règles d'avant (`legacy` de unlocks.json, prix d'avant des responsables) s'appliquent.
const STARTERS := ["platform", "quay1", "hut", "track", "crane_mobile", "yard"]
const GESTURE_OF := {"berths": "berth", "customs": "stamp", "gate": "pass"}
const OFFER_ORDER := ["berths", "customs", "gate"]
var g2 := false
var gestures: Dictionary = {"berth": 0, "stamp": 0, "pass": 0}
var mgr_offered: Dictionary = {}       # responsable des gestes -> instant où il s'est présenté
var has_hut := false
var has_gate := false
var truck_wait_t := 0.0                # s d'attente du camion en tête (régime manuel, sans Tonio)
var _class_first_wait: Array[Ship] = []   # premiers navires d'une classe arrivés pendant la minute qui suit un palier (non sauvegardé)
var _fish_earn_cb: Callable
var _fish_land_cb: Callable
var _fish_serve_cb: Callable

# --- état du joueur ---
var time: float = 0.0
var money: float = 0.0
var amber: int = 0
var tier: int = 1
var finished: bool = false
var satisfaction: float = 0.55
var levels: Dictionary = {}
var managers: Dictionary = {}
var licences: PackedInt32Array = PackedInt32Array()
var built: Array[String] = []
var policy: int = 1
var tariff: float = 1.0
var boost_until: float = -1.0
var boost_ready_at: float = 0.0
var relations: Dictionary = {}
var counters: Dictionary = {}
var missions_claimed: Array[String] = []
var mission_flags: Dictionary = {}     # missions déjà signalées (non sauvegardé)
var renown: int = 0                    # prestige : points de Renom (bonus permanent de revenus)
var prestiges: int = 0                 # nombre de concessions déjà menées à terme
var lifetime: Dictionary = {}          # compteurs cumulés des concessions précédentes
var features: Dictionary = {}          # fonctions déjà révélées (id -> instant de la révélation, ou true si chargée) ; voir `feature()`
var last_reveal_t: float = -1.0e9      # dernière révélation (un sujet à la fois, voir check_unlocks ; sauvegardée depuis C7)
var _rade_full_t: float = 0.0          # secondes (lissées) de rade pleine : le goulot n'est pas « navires » (non sauvegardé)
var _bn_time: Dictionary = {}          # secondes « lissées » où chaque service est le goulot (condition « bottleneck » + « for »)
var _bn_last: float = 0.0
var last_reveal_id: String = ""         # dernière fonction révélée : sa condition « used » raccourcit l'attente
var last_tier_t: float = -1.0e9         # dernier passage de palier : aucune révélation pendant `reveal_tier_hold` s (sauvegardé depuis le lot E)
var _live_t: float = 0.0                # secondes simulées depuis la création ou le chargement (fenêtre du revenu réel ; non sauvegardé)
var owners_on: Dictionary = {}         # armateurs démarchés (salon maritime) : id -> true
var lines: Dictionary = {}             # lignes régulières signées : armateur -> nombre
var line_offers: Array[String] = []    # armateurs qui proposent une ligne (après un contrat réussi)
var campaign_ready_at: Dictionary = {} # campagne de démarchage -> fin de recharge
var legacy_notice: String = ""         # sauvegarde ancienne mise à niveau : l'interface l'explique une fois (non sauvegardé)
var last_claim: Dictionary = {}          # dernière mission réclamée : Ambre, argent, coffre (pour les effets d'interface ; non sauvegardé)

# --- flux ---
var ships: Array[Ship] = []
var next_ship_id: int = 1
var arrival_accum: float = 0.0
var pending_arrival: Dictionary = {}
var apron: PackedFloat64Array = PackedFloat64Array()
var yard_pending: PackedFloat64Array = PackedFloat64Array()
var yard_cleared: PackedFloat64Array = PackedFloat64Array()
var delivered: PackedFloat64Array = PackedFloat64Array()
var arrived_total: float = 0.0
var sailed_away: float = 0.0       # EVP repartis avec un navire furieux
var truck_queue: float = 0.0        # EVP de camions en attente à la gate
var truck_visual_accum: float = 0.0

# --- infrastructure (dérivée des bâtiments) ---
var berths: Array[Dictionary] = []     # {depth, cranes:[{factor, kind}], ship:int}
var yard_cap: PackedFloat64Array = PackedFloat64Array()
var gate_lanes: int = 1
var customs_open: bool = false
var parking_slots: int = 0              # places de l'aire d'attente poids lourds
var patience_mult: float = 1.0          # services aux navires (avitaillement…)
var ship_fee: float = 0.0               # services facturés à chaque escale (part des droits de port)
var time_min_mults: Dictionary = {}     # "pilot" | "moor" | "formal" -> multiplicateur du temps minimal
var unlocked: PackedByteArray = PackedByteArray()
var building_mults: Array[Dictionary] = []

# --- aléas, contrats ---
var active_event: Dictionary = {}
var next_event_at: float = 0.0
var contract_offers: Array[Dictionary] = []
var contracts_active: Array[Dictionary] = []
var next_contract_refresh: float = 0.0

# --- indicateurs ---
var stat_rade_wait: float = 0.0
var stat_truck_wait: float = 0.0
var stat_berth_busy: float = 0.0
var income_buckets: PackedFloat64Array = PackedFloat64Array()
var evp_buckets: PackedFloat64Array = PackedFloat64Array()
var ship_buckets: PackedFloat64Array = PackedFloat64Array()
var bucket_index: int = 0
var bucket_time: float = 0.0
var analysis: Dictionary = {}
var analysis_shown: Dictionary = {}     # conseil affiché (rade pleine : jamais « pas assez de navires », revue N5 bis)
var _analysis_timer: float = 0.0
var _second_timer: float = 0.0
var _last_full_notice: float = -100.0
var last_income: Dictionary = {}       # source -> montant sur la dernière minute (pour l'explicabilité)


func _init(data: DataDB = null, seed_value: int = -1) -> void:
	db = data if data != null else DataDB.new()
	rng.seed = seed_value if seed_value >= 0 else int(db.cfg("seed", 1))
	_fish_earn_cb = func(a: float) -> void: _earn(a, "fish")
	_fish_land_cb = func(i: int, a: float, h: bool) -> void: fish_landed.emit(i, a, h)
	_fish_serve_cb = func(i: int, st: String, a: float) -> void: fish_served.emit(i, st, a)
	reset()
	_spawn_initial()


## Nouvelle partie : un premier navire est déjà en vue du port.
func _spawn_initial() -> void:
	pending_arrival = _roll_arrival()
	arrival_accum = float(pending_arrival.evp)
	_arrivals(0.0)
	if not ships.is_empty():
		ships[0].timer = 1.5


func reset() -> void:
	time = 0.0
	money = float(db.cfg("start_money", 0))
	amber = int(db.cfg("start_amber", 0))
	tier = 1
	finished = false
	satisfaction = float(db.cfg("start_satisfaction", 0.5))
	levels.clear()
	managers.clear()
	for d in db.departments:
		levels[d.id] = 1
		managers[d.id] = false
	licences = PackedInt32Array()
	licences.resize(NCARGO)
	for i in NCARGO:
		licences[i] = 1
	built.clear()
	g2 = false
	for b in STARTERS:          # lot G2 : port complet (les six pièces du départ sont là)
		built.append(String(b))
	gestures = {"berth": 0, "stamp": 0, "pass": 0}
	mgr_offered.clear()
	truck_wait_t = 0.0
	policy = 1
	tariff = 1.0
	boost_until = -1.0
	boost_ready_at = 0.0
	relations.clear()
	for o in db.owners:
		relations[o.id] = 50.0
	counters.clear()
	missions_claimed.clear()
	mission_flags.clear()
	features.clear()
	_legacy_features()
	last_reveal_t = -1.0e9
	last_reveal_id = ""
	last_tier_t = -1.0e9          # lot E : `reset()` complet (palier, alerte de la carte Goulot, fenêtre du revenu réel)
	_alert_why = ""
	_alert_left = 0.0
	_live_t = 0.0
	_fee_key = -1
	_fee_vals.clear()
	_rade_full_t = 0.0
	_bn_time.clear()
	_bn_last = 0.0
	_class_first_wait.clear()
	owners_on.clear()
	lines.clear()
	line_offers.clear()
	campaign_ready_at.clear()
	legacy_notice = ""
	ships.clear()
	next_ship_id = 1
	arrival_accum = 0.0
	pending_arrival = {}
	apron = _zeros(NCARGO)
	yard_pending = _zeros(NCARGO)
	yard_cleared = _zeros(NCARGO)
	delivered = _zeros(NCARGO)
	arrived_total = 0.0
	sailed_away = 0.0
	truck_queue = 0.0
	truck_visual_accum = 0.0
	active_event = {}
	next_event_at = float(db.cfg("first_event_after", 240))
	contract_offers.clear()
	contracts_active.clear()
	next_contract_refresh = 0.0
	income_buckets = _zeros(60)
	evp_buckets = _zeros(60)
	ship_buckets = _zeros(60)
	bucket_index = 0
	bucket_time = 0.0
	# état temporaire et prestige : `from_dict` sur une instance déjà utilisée ne doit rien garder de l'ancienne partie
	renown = 0
	prestiges = 0
	lifetime = {}
	last_income.clear()
	stat_rade_wait = 0.0
	stat_truck_wait = 0.0
	stat_berth_busy = 0.0
	truck_wait_t = 0.0
	_last_full_notice = -100.0
	_second_timer = 0.0
	_analysis_timer = 0.0
	_cache.clear()
	fishing = Fishing.new(db, int(rng.seed % 1000003))
	rebuild_infra()
	_refresh_analysis()


static func _zeros(n: int) -> PackedFloat64Array:
	var a := PackedFloat64Array()
	a.resize(n)
	a.fill(0.0)
	return a


# =====================================================================
# Infrastructure
# =====================================================================

func rebuild_infra() -> void:
	# lot G2 : le quai n°1, sa grue et la plateforme sont des bâtiments (quay1, crane_mobile, platform, yard)
	berths = []
	yard_cap = _zeros(NZONE)
	has_hut = false
	has_gate = false
	gate_lanes = 1
	parking_slots = 0
	patience_mult = 1.0
	ship_fee = 0.0
	customs_open = false
	time_min_mults.clear()
	unlocked = PackedByteArray()
	unlocked.resize(NCARGO)
	for i in NCARGO:
		unlocked[i] = 1 if bool(db.cargo[i].unlocked) else 0
	building_mults.clear()
	for bid in built:
		var b: Dictionary = db.building_by_id.get(bid, {})
		for e in b.get("effects", []):
			_apply_effect(e)
	# réassocie les navires déjà à quai
	for s in ships:
		if s.berth >= 0 and s.berth < berths.size() and s.state >= Ship.State.PILOTING and s.state <= Ship.State.UNLOADING:
			berths[s.berth].ship = s.id


func _apply_effect(e: Dictionary) -> void:
	match String(e.type):
		"yard_cap":
			yard_cap[int(e.zone)] += float(e.amount)
		"add_crane":
			var bi := int(e.berth)
			if bi < berths.size():
				berths[bi].cranes.append({"factor": float(e.factor), "kind": String(e.get("kind", "mobile"))})
		"berth_depth":
			var bj := int(e.berth)
			if bj < berths.size():
				berths[bj].depth = maxi(int(berths[bj].depth), int(e.depth))
		"add_berth":
			var cr: Array = []
			for c in e.cranes:
				cr.append({"factor": float(c.factor), "kind": String(c.get("kind", "mobile"))})
			berths.append({"depth": int(e.depth), "cranes": cr, "ship": -1})
		"gate_lanes":
			gate_lanes += int(e.amount)
		"unlock_cargo":
			unlocked[int(db.cargo_index[e.cargo])] = 1
		"stat_mult":
			building_mults.append({"stat": String(e.stat), "mult": float(e.mult), "label": String(e.get("label", "Bâtiment"))})
		"customs_open":
			customs_open = true
		"parking":
			parking_slots += int(e.amount)
		"patience":
			patience_mult *= float(e.mult)
		"ship_fee":
			ship_fee += float(e.amount)
		"customs_hut":
			has_hut = true
		"gate_open":
			has_gate = true
		"time_min":
			# raccourcit le temps minimal de pilotage / amarrage / formalités (le plancher qui plafonne le débit)
			var k := String(e.kind)
			time_min_mults[k] = float(time_min_mults.get(k, 1.0)) * float(e.mult)


func max_depth() -> int:
	var d := 1
	for b in berths:
		d = maxi(d, int(b.depth))
	return d


func apron_capacity() -> float:
	var per := float(db.cfg("apron_per_berth", 40)) + float(db.cfg("apron_per_level", 8)) * float(levels.berths)
	if managers.berths:
		per *= 1.5
	return per * berths.size()


## Lot G2 : fonctions déjà révélées « depuis toujours » d'un port complet (avant G2, ces services n'étaient pas au registre).
func _legacy_features() -> void:
	for f in ["dept_berths", "dept_cranes", "dept_harbor"]:
		features[f] = true


## Lot G2 : la partie joue le processus à la main — la friche nue (aucun bâtiment, aucun navire), rien de révélé.
func _enter_manual(keep_features: bool = false) -> void:
	g2 = true
	built.clear()
	if not keep_features:
		features.clear()
	ships.clear()
	next_ship_id = 1
	pending_arrival = {}
	arrival_accum = 0.0
	gestures = {"berth": 0, "stamp": 0, "pass": 0}
	mgr_offered.clear()
	truck_wait_t = 0.0
	for c in NCARGO:
		apron[c] = 0.0
		yard_pending[c] = 0.0
		yard_cleared[c] = 0.0
	truck_queue = 0.0
	rebuild_infra()
	invalidate()


func rade_places() -> int:
	# lot G2 : les Arrivées (la rade) n'apparaissent qu'avec le quai n°2 ; au T1, la rade a d'emblée ce que la Capitainerie lui
	# donnait avant (`rade_places_g2`), sinon le port perd ses navires et le T2 recule de 2 à 3 min (sonde)
	var base := int(db.cfg("rade_places_g2", 7)) if g2 else int(db.cfg("rade_places", 4))
	return base + floori(float(levels.harbor) / 10.0) * int(db.cfg("rade_places_per_10_levels", 1))


func pilots() -> int:
	return 1 + floori(float(levels.harbor) / 10.0)


func agents(dept: String) -> int:
	var cap: int = int(db.cfg("agents_max")[tier_index()])
	return mini(cap, 1 + floori(float(levels[dept]) / float(db.cfg("agents_per_levels", 8))))


func agents_max() -> int:
	return int(db.cfg("agents_max")[tier_index()])


func tier_index() -> int:
	return clampi(tier - 1, 0, 2)


func stars() -> float:
	return 1.0 + 4.0 * clampf(satisfaction, 0.0, 1.0)


func yard_stock_zone(z: int) -> float:
	var s := 0.0
	for c in NCARGO:
		if int(db.cargo[c].zone) == z:
			s += yard_pending[c] + yard_cleared[c]
	return s


func yard_stock() -> float:
	var s := 0.0
	for c in NCARGO:
		s += yard_pending[c] + yard_cleared[c]
	return s


## Empilage : plus le Parc et manutention progresse, plus on empile haut (gerbeurs, puis portiques de cour).
func stack_factor() -> float:
	return 1.0 + float(db.cfg("yard_stack_per_level", 0.15)) * float(int(levels.yard_ops) - 1)


func yard_zone_capacity(z: int) -> float:
	return yard_cap[z] * stack_factor()


func yard_capacity() -> float:
	var s := 0.0
	for v in yard_cap:
		s += v
	return s * stack_factor()


func yard_fill() -> float:
	return yard_stock() / maxf(1.0, yard_capacity())


func apron_stock() -> float:
	var s := 0.0
	for v in apron:
		s += v
	return s


## (Lot G1 : les Heures sup se comptent sur `clock()`, l'horloge qui tourne aussi pendant la Crique — `time` y est gelé.)
func boost_active() -> bool:
	return clock() < boost_until


## Multiplicateur des Heures sup (×2), 1 sinon : les loyers de la pêche le suivent aussi.
func boost_mult() -> float:
	return float(db.cfg("boost").mult) if boost_active() else 1.0


## Lot G1 : événements de la pêche relevés après chaque pas (Marcel se présente, annonce du port, bateau reparti sans payer).
func _flush_fish_events() -> void:
	if fishing.events.is_empty():
		return
	var evs := fishing.events.duplicate()
	fishing.events.clear()
	for e in evs:
		var k := String(e)
		if k == "announce":
			# l'annonce du port révèle les Missions (la mission « Signer la concession » est la première de la liste)
			if not features.has("missions"):
				features["missions"] = true
				feature_unlocked.emit("missions")      # (la narratrice commente le caboteur : pas de notification en plus)
		elif k == "marcel_offer":
			notify.emit("%s se présente : embauche-le (Responsables), il encaissera pour toi." % String(fishing.cfg.get("marcel", {}).get("name", "Marcel")), "info")
		fish_event.emit(k)


# =====================================================================
# Statistiques et explicabilité
# =====================================================================

## Services facturés (lot D-Éco, `service_fee`) : chaque niveau de service au-delà du premier facture aux armateurs
## l'équivalent de `service_fee` EVP/s (pilotage, amarrage, stockage…) au prix de base d'un EVP (cargaison × palier ×
## Renom, sans les licences). Un niveau hors goulot rapporte donc toujours un minimum ; la part de ces recettes fond
## quand le trafic grandit (paliers 2 et 3).
func service_fee_rate() -> float:
	var f := float(db.cfg("service_fee", 0.0))
	if f <= 0.0:
		return 0.0
	var n := 0
	for d in DEPTS:
		n += int(levels[d]) - 1
	# lot E : en cache (il était recalculé à chaque pas et à chaque estimation) — clé : palier, Renom, cargaisons débloquées,
	# bâtiments, armateurs démarchés, contrats en cours (le « panier » du port) ; une valeur par somme des niveaux
	var k := _fee_cache_key(f)
	if k != _fee_key:
		_fee_key = k
		_fee_vals.clear()
	if _fee_vals.has(n):
		return float(_fee_vals[n])
	var mix := cargo_shares()
	var v := 0.0
	for c in NCARGO:
		v += mix[c] * float(db.cargo[c].value)
	v *= float(db.tier_def(tier).get("value_mult", 1.0)) * renown_mult()
	var r := f * float(n) * v * (1.0 + float(db.cfg("gate_fee_ratio")))
	_fee_vals[n] = r
	return r


var _fee_key := -1
var _fee_vals: Dictionary = {}       # somme des niveaux -> services facturés ($/s), pour la clé `_fee_key`


## Tout ce dont dépend le prix de base d'un EVP des services facturés, hors niveaux (voir `cargo_shares`).
func _fee_cache_key(f: float) -> int:
	var ub := 0
	for c in unlocked.size():
		if unlocked[c] != 0:
			ub |= 1 << c
	var ck := 0
	for ct in contracts_active:
		ck = ck * 31 + hash(String(ct.get("owner", ""))) + hash(String(ct.get("cargo", ""))) * 7
	return hash([tier, renown, ub, built.size(), owners_on.size(), contracts_active.size(), ck, f])


## Bonus permanent de prestige : +10 % de revenus par point de Renom.
func renown_mult() -> float:
	return 1.0 + float(db.cfg("renown").per_point) * float(renown)


## Effet d'un niveau de département : +x % par niveau (le débit physique reste lisible).
func level_mult(lv: int) -> float:
	return 1.0 + float(db.cfg("dept_per_level")) * float(lv - 1)


func dept_milestone_mult(lv: int) -> float:
	var m := 1.0
	for l in db.cfg("dept_milestones"):
		if lv >= int(l):
			m *= float(db.cfg("dept_milestone_mult"))
	return m


## Nombre de paliers de niveau franchis par un département (le monde montre un élément de plus à chacun).
func dept_stage(dept: String) -> int:
	var n := 0
	for l in db.cfg("dept_milestones"):
		if int(levels[dept]) >= int(l):
			n += 1
	return n


func next_dept_milestone(lv: int) -> int:
	for l in db.cfg("dept_milestones"):
		if int(l) > lv:
			return int(l)
	return 0


## Effet d'une licence : +x % par niveau et des paliers finis (`licence_milestones` : [[niveau, mult], …]).
func licence_mult(lv: int) -> float:
	return (1.0 + float(db.cfg("licence_per_level")) * float(lv - 1)) * Progression.step_mult(lv, db.cfg("licence_milestones"))


## Niveau maximal des licences au palier courant (`licence_max` par palier ; le palier suivant est le vrai saut).
func licence_cap() -> int:
	var caps: Array = db.cfg("licence_max", [])
	if caps.is_empty():
		return 1 << 30
	return int(caps[clampi(tier - 1, 0, caps.size() - 1)])


## Niveaux de licence encore achetables avant le plafond du palier.
func licence_room(ci: int) -> int:
	return maxi(0, licence_cap() - int(licences[ci]))


func _dept_terms(dept: String, out: Array[Dictionary], sqrt_mode: bool = false) -> void:
	var d: Dictionary = db.dept_by_id[dept]
	var lv: int = levels[dept]
	var lm := level_mult(lv)
	var m := dept_milestone_mult(lv)
	if sqrt_mode:
		out.append({"label": "Niveau %d" % lv, "value": sqrt(lm * m)})
	else:
		out.append({"label": "Base", "value": float(d.base)})
		if lv > 1:
			out.append({"label": "Niveau %d" % lv, "value": lm})
		if m > 1.0:
			out.append({"label": "Paliers de niveau", "value": m})
	if managers[dept]:
		out.append({"label": "Responsable", "value": float(db.cfg("manager_mult", 2.0))})


## Statistiques de débit que le Renom améliore (le terminal est mieux rodé, la réputation attire les navires).
const RENOWN_THROUGHPUT_STATS := ["demand", "crane_rate", "transfer_rate", "inspect_rate", "gate_rate"]


func renown_throughput_mult() -> float:
	return 1.0 + float(db.cfg("renown").throughput_per_point) * float(renown)


func _common_terms(stat: String, out: Array[Dictionary], boosted: bool) -> void:
	for bm in building_mults:
		if bm.stat == stat:
			out.append({"label": bm.label, "value": bm.mult})
	if renown > 0 and RENOWN_THROUGHPUT_STATS.has(stat):
		out.append({"label": "Renom ✦ %d" % renown, "value": renown_throughput_mult()})
	if boosted and boost_active():
		out.append({"label": "Heures sup", "value": float(db.cfg("boost").mult)})
	out.append_array(mods.factors(stat))


## Liste des facteurs d'une statistique (le joueur voit « pourquoi ×3,2 »).
func breakdown(stat: String, cargo_i: int = 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match stat:
		"demand":
			# base : ce que les navires que les quais peuvent recevoir apportent (EVP/s) — quai allongé, chenal dragué…
			out.append({"label": "Navires accueillis (gabarit %d)" % max_depth(), "value": class_traffic()})
			var tm := float(db.tier_def(tier).get("traffic_mult", 1.0))
			if tm != 1.0:
				out.append({"label": "Statut : %s" % db.tier_def(tier).name, "value": tm})
			var n_own := 0
			var n_lines := 0
			for o in db.owners:
				if owner_present(o):
					n_own += 1
					n_lines += int(lines.get(o.id, 0))
			out.append({"label": "Armateurs (%d) et lignes (%d)" % [n_own, n_lines], "value": owners_traffic()})
			out.append({"label": "Réputation %.1f ★" % stars(), "value": lerpf(float(db.cfg("rep_demand_min")), float(db.cfg("rep_demand_max")), satisfaction)})
			if not is_equal_approx(tariff, 1.0):
				out.append({"label": "Tarifs %d %%" % roundi(tariff * 100.0), "value": pow(1.0 / tariff, float(db.cfg("tariff_demand_exp")))})
			_common_terms(stat, out, false)
		"crane_rate":
			_dept_terms("cranes", out)
			_common_terms(stat, out, true)
		"transfer_rate":
			_dept_terms("yard_ops", out)
			var eff := Progression.curve(db.cfg("fill_curve"), yard_fill())
			if eff < 0.999:
				out.append({"label": "Parc rempli à %d %%" % roundi(yard_fill() * 100.0), "value": eff})
			_common_terms(stat, out, true)
		"inspect_rate":
			_dept_terms("customs", out)
			_common_terms(stat, out, true)
		"gate_rate":
			_dept_terms("gate", out)
			if gate_lanes > 1:
				out.append({"label": "%d voies" % gate_lanes, "value": float(gate_lanes)})
			_common_terms(stat, out, true)
		"moor_speed":
			_dept_terms("berths", out, true)
			_common_terms(stat, out, true)
		"formal_speed":
			_dept_terms("customs", out, true)
			_common_terms(stat, out, false)
		"pilot_speed":
			_dept_terms("harbor", out, true)
			_common_terms(stat, out, false)
		"value":
			var c: Dictionary = db.cargo[cargo_i]
			out.append({"label": "Valeur " + String(c.short), "value": float(c.value)})
			var lv: int = licences[cargo_i]
			if lv > 1:
				out.append({"label": "Licence niv. %d" % lv, "value": 1.0 + float(db.cfg("licence_per_level", 0.25)) * float(lv - 1)})
			var m := Progression.step_mult(lv, db.cfg("licence_milestones"))
			if m > 1.0:
				out.append({"label": "Paliers de licence", "value": m})
			var tv := float(db.tier_def(tier).get("value_mult", 1.0))
			if tv > 1.0:
				out.append({"label": "Palier T%d" % tier, "value": tv})
			if renown > 0:
				out.append({"label": "Renom ✦ %d" % renown, "value": renown_mult()})
			if not is_equal_approx(tariff, 1.0):
				out.append({"label": "Tarifs", "value": tariff})
			_common_terms(stat, out, false)
	return out


var _cache: Dictionary = {}


## Vide le cache des statistiques (appelé à chaque pas et après chaque décision).
func invalidate() -> void:
	_cache.clear()


func stat(name: String, cargo_i: int = 0) -> float:
	var key := name + ":" + str(cargo_i)
	if _cache.has(key):
		return _cache[key]
	var v := 1.0
	for f in breakdown(name, cargo_i):
		v *= float(f.value)
	_cache[key] = v
	return v


func pilot_duration() -> float:
	var sp := stat("pilot_speed")
	return INF if sp <= 0.0 else maxf(min_time("pilot"), float(db.cfg("pilot_time")) / sp / renown_throughput_mult())


## Temps plancher d'une étape d'escale (« pilot », « moor », « formal ») : c'est lui qui plafonne le débit en fin de palier.
## Il baisse avec les bâtiments (remorqueur, bollards, guichet) et avec le Renom.
func min_time(kind: String) -> float:
	var lv := int(levels[FLOOR_DEPT[kind]])
	var soft := 1.0 + float(db.cfg("floor_per_level", 0.0)) * float(lv - 1)
	return float(db.cfg(kind + "_time_min")) * float(time_min_mults.get(kind, 1.0)) / renown_throughput_mult() / soft


## Le service qui raccourcit chaque temps plancher (un peu à chaque niveau : le plancher n'est plus un mur).
const FLOOR_DEPT := {"pilot": "harbor", "moor": "berths", "formal": "customs"}


func moor_duration() -> float:
	return maxf(min_time("moor"), float(db.cfg("moor_time")) / maxf(0.001, stat("moor_speed")) / renown_throughput_mult())


func formal_duration() -> float:
	return maxf(min_time("formal"), float(db.cfg("formal_time")) / maxf(0.001, stat("formal_speed")) / renown_throughput_mult())


func berth_crane_factor(bi: int) -> float:
	var f := 0.0
	if bi < 0 or bi >= berths.size():
		return f
	for c in berths[bi].cranes:
		f += float(c.factor)
	return f


## Lot G2 : un poste sans grue décharge avec la grue de bord du navire (lent, aucun niveau ne l'accélère).
func board_crane(bi: int) -> bool:
	return bi >= 0 and bi < berths.size() and (berths[bi].cranes as Array).is_empty()


func inspect_fraction(c: int) -> float:
	if not customs_open:
		return 1.0 if g2 else 0.0      # lot G2 : avant le bureau de douane, chaque conteneur attend le tampon de la cabane
	var f := float(db.cfg("policies")[policy].fraction)
	if db.cargo[c].id == "imo" and bool(db.cfg("imo_always_inspected", true)):
		return 1.0
	if db.cargo[c].id == "reefer":
		f += float(db.cfg("reefer_extra_fraction", 0.0))
	return clampf(f, 0.0, 1.0)


# =====================================================================
# Pas de simulation
# =====================================================================

func step(dt: float) -> void:
	if dt <= 0.0:
		return
	# lot F3/G1 : pendant la Crique, seule la pêche tourne (le port est fermé, son horloge arrêtée)
	if fishing.act0:
		_live_t += dt
		fishing.step(dt, _fish_earn_cb, _fish_land_cb, boost_mult(), _fish_serve_cb)
		_flush_fish_events()
		_buckets(dt)
		return
	time += dt
	_live_t += dt
	invalidate()
	Hazards.update(self, dt)
	_arrivals(dt)
	_update_ships(dt)
	_assign_berths()
	_unload(dt)
	_transfer(dt)
	_inspect(dt)
	_gate(dt)
	_fees_and_costs(dt)
	fishing.step(dt, _fish_earn_cb, _fish_land_cb, boost_mult(), _fish_serve_cb)      # lot G1 : la pêche continue (loyers par Marcel, marina)
	_flush_fish_events()
	_buckets(dt)
	_second_timer += dt
	if _second_timer >= 1.0:
		_second_timer -= 1.0
		check_unlocks()
		_check_offers()
		Objectives.update(self)
	_analysis_timer += dt
	if _analysis_timer >= 0.5:
		_analysis_timer = 0.0
		_refresh_analysis()


func _earn(amount: float, source: String) -> void:
	if amount == 0.0:
		return
	money += amount
	income_buckets[bucket_index] += amount
	last_income[source] = float(last_income.get(source, 0.0)) + amount
	revenue.emit(amount, source)


func add_counter(key: String, v: float = 1.0) -> void:
	counters[key] = float(counters.get(key, 0.0)) + v


func counter(key: String) -> float:
	return float(counters.get(key, 0.0))


## Compteurs qui ne s'additionnent pas d'une concession à l'autre (série en cours, étoiles).
const RUN_ONLY_COUNTERS := ["happy_streak", "stars_x10"]


## Compteur cumulé sur toutes les concessions (missions long terme) ; la partie en cours seule : `counter`.
func counter_total(key: String) -> float:
	if RUN_ONLY_COUNTERS.has(key):
		return counter(key)
	return counter(key) + float(lifetime.get(key, 0.0))


# --- arrivées ---------------------------------------------------------

func _roll_arrival() -> Dictionary:
	# armateur
	var ow_ids: Array = []
	var ow_w: Array = []
	for o in db.owners:
		if int(o.tier) <= tier and owner_ok(o):
			var w := owner_factor(o) * (0.5 + float(relations[o.id]) / 100.0)
			ow_ids.append(o.id)
			ow_w.append(w)
	var owner: String = ow_ids[_pick(ow_w)]
	# classe de navire (limitée par le tirant d'eau disponible)
	var cl_ids: Array = []
	var cl_w: Array = []
	var md := max_depth()
	for s in db.ships:
		var w2 := class_freq(s)
		if int(s.depth) <= md and w2 > 0.0:
			cl_ids.append(s.id)
			cl_w.append(w2)
	var cls: String = cl_ids[_pick(cl_w)]
	var sd: Dictionary = db.ship_by_id[cls]
	var evp := float(rng.randi_range(int(sd.evp[0]), int(sd.evp[1])))
	return {"owner": owner, "cls": cls, "evp": evp}


func _pick(weights: Array) -> int:
	var tot := 0.0
	for w in weights:
		tot += float(w)
	var r := rng.randf() * tot
	for i in weights.size():
		r -= float(weights[i])
		if r <= 0.0:
			return i
	return weights.size() - 1


func cargo_mix(owner: String) -> PackedFloat64Array:
	var od: Dictionary = db.owner_by_id[owner]
	var w := _zeros(NCARGO)
	var tot := 0.0
	for c in NCARGO:
		if unlocked[c] == 0:
			continue
		var cid: String = db.cargo[c].id
		var v := float(db.cargo[c].weight) * float(od.bias.get(cid, 1.0))
		for ct in contracts_active:
			if ct.owner == owner and ct.cargo == cid:
				v *= 2.0
		w[c] = v
		tot += v
	for c in NCARGO:
		w[c] = w[c] / maxf(0.0001, tot)
	return w


## Plus longue attente en rade (s) : le tutoriel attend un vrai bouchon visible avant de parler du goulot.
func longest_wait() -> float:
	var w := 0.0
	for s in ships:
		if s.state == Ship.State.ANCHORED:
			w = maxf(w, s.wait_time)
	return w


func waiting_ships() -> int:
	var n := 0
	for s in ships:
		if s.state == Ship.State.ARRIVING or s.state == Ship.State.ANCHORED:
			n += 1
	return n


func _arrivals(dt: float) -> void:
	if berths.is_empty():
		return          # lot G2 : pas de navire tant que le quai n°1 n'est pas construit
	if pending_arrival.is_empty():
		pending_arrival = _roll_arrival()
	var need := float(pending_arrival.evp)
	arrival_accum = minf(arrival_accum + stat("demand") * dt, need * 1.5)
	if arrival_accum < need:
		return
	arrival_accum -= need
	if waiting_ships() >= rade_places():
		add_counter("turned_away")
		if time - _last_full_notice > 30.0:
			_last_full_notice = time
			notify.emit("Rade pleine : des navires sont déroutés vers d'autres ports.", "bad")
		pending_arrival = {}
		return
	var s := Ship.new()
	s.id = next_ship_id
	next_ship_id += 1
	s.cls = pending_arrival.cls
	s.owner = pending_arrival.owner
	s.evp_total = need
	var mix := cargo_mix(s.owner)
	s.left = _zeros(NCARGO)
	for c in NCARGO:
		s.left[c] = need * mix[c]
	var od: Dictionary = db.owner_by_id[s.owner]
	var sd: Dictionary = db.ship_by_id[s.cls]
	s.patience_max = float(db.cfg("patience_base")) * float(sd.patience) * float(od.patience) \
		* (0.7 + 0.6 * float(relations[s.owner]) / 100.0) * patience_mult
	s.patience = s.patience_max
	s.state = Ship.State.ARRIVING
	s.timer = float(db.cfg("arrive_time"))
	s.anchor_slot = _free_anchor_slot()
	ships.append(s)
	arrived_total += need
	pending_arrival = {}
	ship_spawned.emit(s)
	if counter("arrived_" + s.cls) == 0.0 and s.cls != String(db.ships[0].id):
		# (reprise G2 : pas de bandeau pendant la minute qui suit un palier — il attend la fin de `reveal_tier_hold`)
		if time - last_tier_t < float(db.cfg("reveal_tier_hold", 0.0)):
			_class_first_wait.append(s)
		else:
			ship_class_first.emit(s)
	add_counter("arrived_" + s.cls)


func _free_anchor_slot() -> int:
	var used := {}
	for s in ships:
		if s.anchor_slot >= 0 and (s.state == Ship.State.ARRIVING or s.state == Ship.State.ANCHORED):
			used[s.anchor_slot] = true
	var i := 0
	while used.has(i):
		i += 1
	return i


# --- navires ----------------------------------------------------------

func _set_state(s: Ship, st: int, timer: float = 0.0) -> void:
	s.state = st
	s.timer = timer
	ship_state_changed.emit(s)


func _update_ships(dt: float) -> void:
	var removed: Array[Ship] = []
	for s in ships:
		match s.state:
			Ship.State.ARRIVING:
				s.timer -= dt
				if s.timer <= 0.0:
					_set_state(s, Ship.State.ANCHORED)
			Ship.State.ANCHORED:
				s.wait_time += dt
				s.patience -= dt
				if s.patience <= 0.0:
					_ship_leaves_angry(s)
			Ship.State.PILOTING:
				s.timer -= dt
				if s.timer <= 0.0:
					_set_state(s, Ship.State.MOORING, moor_duration() * time_scale(s.cls))
			Ship.State.MOORING:
				s.timer -= dt
				if s.timer <= 0.0:
					var dues := float(db.ship_by_id[s.cls].dues) * float(db.tier_def(tier).get("dues_mult", 1.0)) * tariff \
						* float(db.owner_by_id[s.owner].pay) * renown_mult()
					_earn(dues, "dues")
					if ship_fee > 0.0:
						_earn(dues * ship_fee, "services")
					_set_state(s, Ship.State.FORMALITIES, formal_duration() * time_scale(s.cls))
			Ship.State.FORMALITIES:
				s.timer -= dt
				if s.timer <= 0.0:
					_set_state(s, Ship.State.UNLOADING)
			Ship.State.UNLOADING:
				if s.evp_left() <= 0.0001:
					_ship_done(s)
			Ship.State.DEPARTING, Ship.State.LEAVING:
				s.timer -= dt
				if s.timer <= 0.0:
					removed.append(s)
	for s in removed:
		ships.erase(s)
		ship_removed.emit(s)


func _record_satisfaction(score: float) -> void:
	satisfaction = lerpf(satisfaction, score, float(db.cfg("rep_alpha")))


func _ship_leaves_angry(s: Ship) -> void:
	sailed_away += s.evp_left()
	_record_satisfaction(0.0)
	relations[s.owner] = clampf(float(relations[s.owner]) - 6.0, 0.0, 100.0)
	counters["happy_streak"] = 0.0
	add_counter("ships_angry")
	notify.emit("Un %s de %s repart furieux !" % [String(db.ship_by_id[s.cls].name).to_lower(), db.owner_by_id[s.owner].name], "bad")
	_set_state(s, Ship.State.LEAVING, float(db.cfg("depart_time")))


func _ship_done(s: Ship) -> void:
	berths[s.berth].ship = -1
	var mood := s.mood_at_berth
	var score: float = [1.0, 0.6, 0.25][mood]
	_record_satisfaction(score)
	relations[s.owner] = clampf(float(relations[s.owner]) + [2.0, 0.5, -3.0][mood], 0.0, 100.0)
	if mood == Ship.Mood.ANGRY:
		counters["happy_streak"] = 0.0
	else:
		add_counter("happy_streak")
	add_counter("ships")
	add_counter("ships_" + s.cls)
	ship_buckets[bucket_index] += 1.0
	_compliance_roll(s)
	_set_state(s, Ship.State.DEPARTING, float(db.cfg("depart_time")))


## Conformité : la douane (l'État) inspecte selon la politique ; le joueur ne décide pas des issues.
func _compliance_roll(s: Ship) -> void:
	if not customs_open:
		return
	var od: Dictionary = db.owner_by_id[s.owner]
	var pol: Dictionary = db.cfg("policies")[policy]
	var fraud := float(od.fraud)
	var detect_eff := clampf(float(pol.detect) * minf(1.0, float(pol.fraction) * 3.0), 0.0, 0.99)
	if rng.randf() < fraud:
		if rng.randf() < detect_eff:
			add_counter("seizures")
			relations[s.owner] = clampf(float(relations[s.owner]) - 5.0, 0.0, 100.0)
			_record_satisfaction(0.9)   # les autorités apprécient
			inspection_result.emit("saisie", s.owner)
			notify.emit("Saisie ! La douane a intercepté une marchandise illicite chez %s." % od.name, "info")
		else:
			add_counter("incidents")
			var fine := avg_value_per_evp() * float(db.cfg("incident_fine_per_value", 40))
			money = maxf(0.0, money - fine)
			_record_satisfaction(0.1)
			inspection_result.emit("incident", s.owner)
			notify.emit("Incident non détecté (%s) : amende de %s." % [od.name, Fmt.money(fine)], "bad")
	else:
		add_counter("compliant")
		inspection_result.emit("conforme", s.owner)


func _assign_berths() -> void:
	if stat("pilot_speed") <= 0.0:
		return   # brouillard : pas de nouveau pilotage
	var busy := 0
	for s in ships:
		if s.state == Ship.State.PILOTING:
			busy += 1
	if busy >= pilots():
		return
	var cands: Array[Ship] = []
	# lot G2 : régime manuel — sans Léon (ni Mathilde), aucun accostage automatique : le joueur touche le navire
	var auto := bool(managers.harbor) or (g2 and bool(managers.berths))
	for s in ships:
		if s.state == Ship.State.ANCHORED and (auto or s.priority or (not g2 and s.wait_time >= float(db.cfg("auto_berth_delay")))):
			cands.append(s)
	cands.sort_custom(_ship_order)
	for s in cands:
		if busy >= pilots():
			return
		var need := int(db.ship_by_id[s.cls].depth)
		var best := -1
		for bi in berths.size():
			if int(berths[bi].ship) == -1 and int(berths[bi].depth) >= need:
				if best == -1 or int(berths[bi].depth) < int(berths[best].depth):
					best = bi
		if best == -1:
			continue
		berths[best].ship = s.id
		s.berth = best
		s.mood_at_berth = s.mood()
		stat_rade_wait = lerpf(stat_rade_wait, s.wait_time, 0.2)
		busy += 1
		# lot G2 : un accostage fait à la main compte pour Léon (un geste = un navire accosté, pas un toucher)
		if g2 and s.priority and not auto:
			gestures.berth = int(gestures.berth) + 1
		# accostage « en priorité » demandé par le joueur : le pilote file plus vite
		var pd := pilot_duration() * time_scale(s.cls)
		if s.priority and not auto:
			pd *= float(db.cfg("manual").express_pilot)
		_set_state(s, Ship.State.PILOTING, pd)


static func _ship_order(a: Ship, b: Ship) -> bool:
	if a.priority != b.priority:
		return a.priority
	return a.id < b.id


## Le joueur choisit le prochain navire à accoster.
func prioritize_ship(ship_id: int) -> bool:
	for s in ships:
		if s.id == ship_id and s.state == Ship.State.ANCHORED:
			for o in ships:
				o.priority = false
			s.priority = true
			add_counter("priority")
			return true
	return false


func ship_by_id(ship_id: int) -> Ship:
	for s in ships:
		if s.id == ship_id:
			return s
	return null


# --- déchargement -----------------------------------------------------

func berth_unload_rate(bi: int) -> float:
	if board_crane(bi):
		return float(db.cfg("manual").get("board_crane_rate", 0.125))
	return stat("crane_rate") * berth_crane_factor(bi)


func _unload(dt: float) -> void:
	var crane := stat("crane_rate")
	for s in ships:
		if s.state != Ship.State.UNLOADING:
			continue
		if apron_capacity() - apron_stock() <= 0.0:
			return
		_unload_ship(s, (berth_unload_rate(s.berth) if board_crane(s.berth) else crane * berth_crane_factor(s.berth)) * dt)


## Décharge jusqu'à `want` EVP du navire vers le tablier (borné par le reste du navire et la place disponible).
## Renvoie les EVP réellement déchargés.
func _unload_ship(s: Ship, want: float) -> float:
	var free := apron_capacity() - apron_stock()
	var tot := s.evp_left()
	var amount := minf(minf(want, tot), free)
	if amount <= 0.0:
		return 0.0
	var pay := float(db.owner_by_id[s.owner].pay)
	var earned := 0.0
	for c in NCARGO:
		if s.left[c] <= 0.0:
			continue
		var a := amount * s.left[c] / tot
		a = minf(a, s.left[c])
		s.left[c] -= a
		apron[c] += a
		earned += a * stat("value", c) * pay
		add_counter("evp_" + String(db.cargo[c].id), a)
		Objectives.on_unloaded(self, s.owner, String(db.cargo[c].id), a)
	add_counter("evp", amount)
	evp_buckets[bucket_index] += amount
	_earn(earned, "handling")
	return amount


# --- gestes manuels (lot G2) : accoster, tamponner, laisser passer et encaisser -------------------------------
# Les gestes d'avant G2 (coup de main à la grue ×1,2, engin du parc, barrière express) sont retirés (cadrage § 12 Q1) : un
# responsable remplace le geste. Les fonctions restent (toujours « pas prêtes ») pour les appels anciens.

func assist_ready(_bi: int) -> bool:
	return false


func assist_unload(_bi: int) -> float:
	return 0.0


func yard_boost_ready() -> bool:
	return false


func yard_boost() -> float:
	return 0.0


func gate_rush_ready() -> bool:
	return false


func gate_rush() -> float:
	return 0.0


## Tamponner : la cabane est là, Paul n'est pas embauché, des conteneurs attendent. Toucher la cabane les dédouane tous.
func stamp_ready() -> bool:
	return g2 and has_hut and not managers.customs and pending_total() >= 0.5


func stamp() -> float:
	if not stamp_ready():
		return 0.0
	var tot := pending_total()
	var fee := 0.0
	for c in NCARGO:
		var x := yard_pending[c]
		yard_pending[c] = 0.0
		yard_cleared[c] += x
		fee += x * float(db.cfg("inspection_fee")) * float(db.tier_def(tier).get("value_mult", 1.0)) * renown_mult()
	add_counter("inspected", tot)
	add_counter("stamps")
	gestures.stamp = int(gestures.stamp) + 1
	_earn(fee, "inspection")
	gesture_done.emit("stamp", tot)
	return tot


## Laisser passer et encaisser : un camion attend à la barrière (piste construite, Tonio pas embauché).
func pass_ready() -> bool:
	return g2 and has_gate and not managers.gate and truck_queue >= float(db.cfg("truck_evp")) - 0.001 \
		and cleared_total() >= float(db.cfg("truck_evp")) - 0.001


## Toucher la barrière : le camion charge, paie sa part (pièce vers le compteur) et part. Renvoie le montant payé.
func pass_truck() -> float:
	if not pass_ready():
		return 0.0
	var lot := float(db.cfg("truck_evp"))
	truck_queue -= lot
	truck_wait_t = 0.0
	var fee := _serve(lot)
	add_counter("passes")
	gestures.pass = int(gestures.pass) + 1
	truck_served.emit(0.0)
	gesture_done.emit("pass", fee)
	return fee


## Secondes avant que le camion en tête reparte sans rien (INF s'il n'y en a pas, ou si Tonio est là).
func truck_wait_left() -> float:
	if not g2 or managers.gate or truck_queue < float(db.cfg("truck_evp")) - 0.001:
		return INF
	return maxf(0.0, float(db.cfg("manual").get("truck_wait", 20.0)) - truck_wait_t)


## Le responsable d'un geste se présente après `gesture_offers` gestes (5), un à la fois, dans l'ordre accoster → tamponner →
## laisser passer, jamais à moins de `offer_gap` s (45) d'une autre nouveauté.
func _check_offers() -> void:
	if not g2:
		return
	var m: Dictionary = db.cfg("manual")
	var last := last_reveal_t
	for d in mgr_offered:
		last = maxf(last, float(mgr_offered[d]))
	if time - last < float(m.get("offer_gap", 45.0)):
		return
	for d in OFFER_ORDER:
		if mgr_offered.has(d):
			continue
		if int(gestures.get(GESTURE_OF[d], 0)) >= int(m.get("gesture_offers", 5)) and not managers[d]:
			mgr_offered[d] = time
			last_reveal_t = time
			# (le bouton RESPONSABLES paraît avec le premier qui se présente : la révélation « Responsables » est faite, sans bandeau)
			if not features.has("managers"):
				features["managers"] = time
			manager_offered.emit(d)
			notify.emit("%s se présente : embauche-le (Responsables), il le fera pour toi." % String(db.dept_by_id[d].manager.name), "info")
		return


## Lot G2 : un responsable des gestes a mérité de se présenter (5 gestes) mais attend son tour (`offer_gap`).
func _offer_due() -> bool:
	if not g2:
		return false
	var m: Dictionary = db.cfg("manual")
	for d in OFFER_ORDER:
		if not mgr_offered.has(d) and not managers[d] and int(gestures.get(GESTURE_OF[d], 0)) >= int(m.get("gesture_offers", 5)):
			return true
	return false


func missions_claimable() -> int:
	return Objectives.claimable_count(self)


# --- révélation progressive (data/unlocks.json) ------------------------------
# Les fonctions du jeu apparaissent une à une. La simulation les respecte aussi (achat, aléas, contrats) :
# ce que le joueur ne voit pas encore n'agit pas encore, et le bot d'équilibrage vit la même partie.

## Une fonction absente du registre est toujours disponible.
func feature(id: String) -> bool:
	return features.has(id) or not db.unlock_by_id.has(id)


## Lot G2 : condition d'une révélation — celle d'avant G2 (`legacy`) pour un port complet, la nouvelle pour une partie jouée.
func unlock_when(u: Dictionary) -> Dictionary:
	if not g2 and u.has("legacy"):
		return u.legacy
	return u.get("when", {})


func unlock_ok(when: Dictionary) -> bool:
	# « any » : l'une des conditions suffit (ex. le service atteint le niveau 10, ou le suivant devient le goulot)
	if when.has("any"):
		for w in when.any:
			if unlock_ok(w):
				return true
		return false
	# « for » : le service doit être le goulot depuis au moins N secondes (revue N7 : la gate ne s'ouvre pas sur un pic)
	if when.has("bottleneck") and (String(analysis.get("dept", "")) != String(when.bottleneck)
			or float(_bn_time.get(String(when.bottleneck), 0.0)) < float(when.get("for", 0.0))):
		return false
	if when.has("ships") and counter("ships") < float(when.ships):
		return false
	if when.has("evp") and counter("evp") < float(when.evp):
		return false
	if when.has("building") and not built.has(String(when.building)):
		return false
	if when.has("amber") and amber < int(when.amber):
		return false
	if when.has("tier") and tier < int(when.tier):
		return false
	if when.has("level"):
		var lw: Dictionary = when.level
		if int(levels.get(String(lw.dept), 1)) < int(lw.min):
			return false
	if when.has("manager") and not bool(managers.get(String(when.manager), false)):
		return false
	# conditions « used » (le joueur s'est servi d'une fonction révélée) : responsables embauchés, compteur, licence, mission
	if when.has("hired") and managers_count() < int(when.hired):
		return false
	if when.has("hired_port") and managers_count() < int(when.hired_port):
		return false
	if when.has("counter") and counter(String(when.counter.id)) < float(when.counter.min):
		return false
	if when.has("licence"):
		var best_lv := 0
		for ci in NCARGO:
			best_lv = maxi(best_lv, int(licences[ci]))
		if best_lv < int(when.licence):
			return false
	if when.has("claimed") and missions_claimed.size() < int(when.claimed):
		return false
	# « after » : quelques secondes après une autre révélation (les sujets d'un chapitre arrivent un par un)
	if when.has("after"):
		var aw: Dictionary = when.after
		var aid := String(aw.id)
		if not features.has(aid) or time - feature_time(aid) < float(aw.get("s", 0.0)):
			return false
	return true


## Prochain chapitre fermé par le niveau d'un service : {dept, min, name} (le service à monter, le niveau, ce qu'il ouvre),
## {} s'il n'y en a plus. Sert aux cartes d'Améliorer : un niveau sans gain immédiat rapproche quand même du chapitre suivant.
func chapter_goal() -> Dictionary:
	for u in db.unlocks:
		if features.has(String(u.id)) or not bool(u.get("opens_chapter", false)):
			continue
		var w: Dictionary = unlock_when(u)
		var subs: Array = w.any if w.has("any") else [w]
		for sub in subs:
			if (sub as Dictionary).has("level"):
				return {"dept": String(sub.level.dept), "min": int(sub.level.min), "name": String(u.name)}
	return {}


## Instant de la révélation d'une fonction (−1e9 si elle vient d'une sauvegarde ou d'une concession précédente).
func feature_time(id: String) -> float:
	var v: Variant = features.get(id, null)
	if (v is float or v is int) and not (v is bool) and float(v) <= time:
		return float(v)
	return -1.0e9


## Condition lisible d'une fonction encore cachée (« après 4 escales (2/4) »), pour les cartes verrouillées.
func unlock_text(id: String) -> String:
	var u: Dictionary = db.unlock_by_id.get(id, {})
	var w: Dictionary = unlock_when(u)
	if w.has("any"):
		var pick: Dictionary = {}
		for k in ["level", "manager", "building"]:      # (lot G2 : un responsable ou un bâtiment, faute de niveau)
			for sub in w.any:
				if pick.is_empty() and (sub as Dictionary).has(k):
					pick = sub
		if not pick.is_empty():
			w = pick
	if w.has("level"):
		var lw: Dictionary = w.level
		var dn := String(db.dept_by_id[String(lw.dept)].name)
		return "quand %s atteint le niveau %d (%d/%d)" % [dn, int(lw.min), mini(int(levels.get(String(lw.dept), 1)), int(lw.min)), int(lw.min)]
	if w.has("manager"):
		return "avec %s" % String(db.dept_by_id[String(w.manager)].manager.name)
	if w.has("building"):
		# Gestion n'existe qu'à partir du chapitre 3 : avant, on désigne l'emplacement doré du port (revue C7 B6)
		var where := "Gestion → Bâtiments" if feature("manage") else "son emplacement doré, dans le port"
		return "avec « %s » (%s)" % [db.building_by_id[String(w.building)].name, where]
	if w.has("ships"):
		return "après %d escales (%d/%d)" % [int(w.ships), mini(int(counter("ships")), int(w.ships)), int(w.ships)]
	if w.has("evp"):
		return "après %s conteneurs déchargés" % Fmt.num(float(w.evp))
	if w.has("tier"):
		return "au palier T%d" % int(w.tier)
	if w.has("amber"):
		return "au premier Ambre gagné"
	if w.has("after"):
		var au: Dictionary = db.unlock_by_id.get(String(w.after.id), {})
		var s := float(w.after.get("s", 0.0))
		var lead := "peu" if s < 60.0 else Fmt.duration(s)
		return "%s après « %s »" % [lead, String(au.get("name", w.after.id))]
	return ""


## Révèle les fonctions dont la condition est remplie, **un sujet à la fois** : une révélation ordinaire attend
## `reveal_gap` secondes après la précédente (config.json) ; celles qui ouvrent un chapitre (« opens_chapter ») passent
## tout de suite (leur service ne doit pas devenir le goulot sans avoir été présenté), mais une seule par passage.
## Rien n'est révélé pendant `reveal_tier_hold` s après un passage de palier (la cérémonie passe seule, lot D-Éco).
func check_unlocks() -> void:
	if time - last_tier_t < float(db.cfg("reveal_tier_hold", 0.0)):
		return
	if not _class_first_wait.is_empty():
		for w in _class_first_wait:
			if ships.has(w):
				ship_class_first.emit(w)
		_class_first_wait.clear()
	var pick := ""
	for pass_i in 2:
		for u in db.unlocks:
			var id := String(u.id)
			if features.has(id) or bool(u.get("opens_chapter", false)) != (pass_i == 0):
				continue
			if pass_i == 1 and not _reveal_gap_over():
				return
			if pass_i == 1 and _offer_due():
				return          # lot G2 : un responsable des gestes attend de se présenter — il passe avant les révélations ordinaires
			if unlock_ok(unlock_when(u)):
				pick = id
				break
		if pick != "":
			break
	if pick == "":
		return
	last_reveal_t = time
	last_reveal_id = pick
	features[pick] = time
	# lot G2 : la barre de palier paraît avec la première carte de service du port (cadrage § 8.1), sans bandeau à elle
	if g2 and pick.begins_with("dept_") and not features.has("progress"):
		features["progress"] = time
	if pick == "events":
		next_event_at = maxf(next_event_at, time + 60.0)   # le premier aléa laisse une minute de répit
	elif pick == "contracts":
		next_contract_refresh = time
	feature_unlocked.emit(pick)


## Sauvegarde d'avant la révélation progressive : le joueur connaissait déjà tout, et ses caboteurs
## accostaient au vieux quai et passaient la douane. On lui donne l'allongement du quai et le bureau de douane.
func _upgrade_legacy_save() -> void:
	for u in db.unlocks:
		features[String(u.id)] = true
	for bid in ["customs1", "quay_ext"]:      # insérés après les pièces du départ (lot G2), dans l'ordre de la liste des bâtiments
		if db.building_by_id.has(bid) and not built.has(bid):
			var at := 0
			while at < built.size() and STARTERS.has(built[at]):
				at += 1
			built.insert(at, bid)


## Sauvegarde d'avant le Commerce (version 2) : la Capitainerie faisait venir les navires. Les armateurs déjà présents
## restent (marqués « démarchés »), le Commerce est révélé tout de suite et l'interface explique la baisse de trafic.
func _upgrade_commerce_save() -> void:
	for o in db.owners:
		if Commerce.needs_recruit(o) and int(o.tier) <= tier:
			owners_on[String(o.id)] = true
	features["commerce"] = true
	legacy_notice = "commerce"


## Licences au-delà du plafond du palier (sauvegarde d'avant les plafonds, version 3) : le niveau est ramené au plafond
## et l'excédent remboursé au prix d'achat. Sans effet sur une partie déjà conforme (appelé à chaque chargement).
func _clamp_licences() -> float:
	var refund := 0.0
	for ci in NCARGO:
		var extra := int(licences[ci]) - licence_cap()
		if extra > 0:
			var c: Dictionary = db.cargo[ci]
			refund += Progression.bulk_cost(float(c.licence_cost), float(c.licence_growth), licence_cap() - 1, extra)
			licences[ci] = licence_cap()
	if refund > 0.0:
		money += refund
		legacy_notice = "licences:%s" % Fmt.money(refund)
	return refund


# --- transfert quai → parc --------------------------------------------

func _transfer(dt: float) -> void:
	var tot := apron_stock()
	if tot <= 0.0:
		return
	# lot G2 : avant le parc de stockage, la plateforme reçoit directement (pas d'engins : rien à ranger)
	var budget := tot if (g2 and not built.has("yard")) else minf(stat("transfer_rate") * dt, tot)
	var zone_free := _zeros(NZONE)
	for z in NZONE:
		zone_free[z] = maxf(0.0, yard_zone_capacity(z) - yard_stock_zone(z))
	for c in NCARGO:
		if apron[c] <= 0.0:
			continue
		var z: int = int(db.cargo[c].zone)
		var a := minf(minf(budget * apron[c] / tot, apron[c]), zone_free[z])
		if a <= 0.0:
			continue
		zone_free[z] -= a
		apron[c] -= a
		var f := inspect_fraction(c)
		yard_pending[c] += a * f
		yard_cleared[c] += a * (1.0 - f)


# --- inspection --------------------------------------------------------

func pending_total() -> float:
	var s := 0.0
	for v in yard_pending:
		s += v
	return s


func _inspect(dt: float) -> void:
	var tot := pending_total()
	if tot <= 0.0:
		return
	if g2 and not managers.customs:
		return          # lot G2 : sans Paul, c'est le joueur qui tamponne (toucher la cabane)
	var a := minf(stat("inspect_rate") * dt, tot)
	var fee := 0.0
	for c in NCARGO:
		if yard_pending[c] <= 0.0:
			continue
		var x := minf(a * yard_pending[c] / tot, yard_pending[c])
		yard_pending[c] -= x
		yard_cleared[c] += x
		fee += x * float(db.cfg("inspection_fee")) * float(db.tier_def(tier).get("value_mult", 1.0)) * renown_mult()
	add_counter("inspected", a)
	_earn(fee, "inspection")


# --- gate -------------------------------------------------------------

func cleared_total() -> float:
	var s := 0.0
	for v in yard_cleared:
		s += v
	return s


## Un camion affiché représente « une seconde de débit de gate » (au moins truck_evp EVP).
func truck_lot() -> float:
	if g2 and not managers.gate:
		return float(db.cfg("truck_evp"))      # lot G2 : à la main, un camion = 2 conteneurs
	return maxf(float(db.cfg("truck_evp")), stat("gate_rate"))


func trucks_waiting() -> int:
	return mini(int(db.cfg("truck_queue_max")), ceili(truck_queue / truck_lot() - 0.001))


func truck_wait_estimate() -> float:
	return truck_queue / maxf(0.001, stat("gate_rate"))


func _gate(dt: float) -> void:
	if not has_gate:
		truck_queue = 0.0          # lot G2 : pas de camion sans piste ni barrière
		return
	var qmax := float(db.cfg("truck_queue_max")) * truck_lot()
	var ready := cleared_total() - truck_queue
	if ready > 0.0:
		truck_queue = minf(truck_queue + minf(ready, ready / float(db.cfg("dwell_target")) * dt), maxf(qmax, truck_queue))
	if g2 and not managers.gate:
		# lot G2 : à la main — le camion en tête attend `truck_wait` s qu'on le laisse passer, puis repart sans rien
		if truck_queue >= float(db.cfg("truck_evp")) - 0.001:
			truck_wait_t += dt
			if truck_wait_t >= float(db.cfg("manual").get("truck_wait", 20.0)):
				truck_queue = maxf(0.0, truck_queue - float(db.cfg("truck_evp")))
				truck_wait_t = 0.0
				add_counter("trucks_lost")
				gesture_done.emit("truck_lost", 0.0)
		else:
			truck_wait_t = 0.0
		return
	var served := minf(minf(truck_queue, stat("gate_rate") * dt), cleared_total())
	if served <= 0.0:
		return
	truck_queue -= served
	_serve(served)


## Sortie de `served` conteneurs dédouanés (gate ou camion laissé passer) : livrés, part de gate encaissée. Renvoie le montant.
func _serve(served: float) -> float:
	var tot := cleared_total()
	var fee := 0.0
	for c in NCARGO:
		if yard_cleared[c] <= 0.0:
			continue
		var x := minf(served * yard_cleared[c] / tot, yard_cleared[c])
		yard_cleared[c] -= x
		delivered[c] += x
		fee += x * stat("value", c) * float(db.cfg("gate_fee_ratio"))
	add_counter("trucks", served / float(db.cfg("truck_evp")))
	stat_truck_wait = lerpf(stat_truck_wait, truck_wait_estimate(), 0.02)
	truck_visual_accum += served
	var lot := truck_lot()
	var n := 0
	if g2 and not managers.gate:
		truck_visual_accum = 0.0      # (le camion laissé passer est montré par pass_truck)
	while truck_visual_accum >= lot and n < 4:
		truck_visual_accum -= lot
		n += 1
		truck_served.emit(truck_wait_estimate())
	truck_visual_accum = minf(truck_visual_accum, lot)
	_earn(fee, "gate")
	return fee


func trucks_honking() -> int:
	return trucks_waiting() if truck_wait_estimate() > float(db.cfg("truck_honk_after")) else 0


# --- frais et coûts ----------------------------------------------------

func salaries_per_day() -> float:
	var n := 0
	for d in DEPTS:
		n += agents(d)
	return float(n) * float(db.cfg("salary_per_agent_day")[tier_index()])


func _fees_and_costs(dt: float) -> void:
	var day := float(db.cfg("day_seconds"))
	var ri: int = db.cargo_index["reefer"]
	var reefer := yard_pending[ri] + yard_cleared[ri]
	if reefer > 0.0:
		_earn(reefer * float(db.cfg("reefer_fee_per_day")) * float(db.tier_def(tier).get("value_mult", 1.0)) * renown_mult() * dt / day, "reefer")
	var fees := service_fee_rate()
	if fees > 0.0:
		_earn(fees * dt, "fees")
	var cost := salaries_per_day() * dt / day
	money = maxf(0.0, money - cost)
	income_buckets[bucket_index] -= cost
	last_income["salaries"] = float(last_income.get("salaries", 0.0)) - cost


func _buckets(dt: float) -> void:
	bucket_time += dt
	var busy := 0.0
	for b in berths:
		if int(b.ship) != -1:
			busy += 1.0
	stat_berth_busy = lerpf(stat_berth_busy, busy / float(maxi(1, berths.size())), dt * 0.05)
	while bucket_time >= 1.0:
		bucket_time -= 1.0
		bucket_index = (bucket_index + 1) % 60
		income_buckets[bucket_index] = 0.0
		evp_buckets[bucket_index] = 0.0
		ship_buckets[bucket_index] = 0.0
		if bucket_index == 0:
			last_income.clear()


func _sum(a: PackedFloat64Array) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s


## Revenu net sur la dernière minute (fenêtre glissante).
func income_per_min() -> float:
	return _sum(income_buckets) * 60.0 / clampf(clock(), 1.0, 60.0)


## Lot F3 : secondes simulées depuis la partie neuve, acte 0 compris (`time` ne compte que le port, depuis l'entrée au T1).
func clock() -> float:
	return time + fishing.act0_time


## Revenu net **réel** par seconde (fenêtre glissante d'une minute) : comme `income_per_min`, mais la fenêtre ne compte que le
## temps réellement mesuré (partie chargée d'une sauvegarde sans seaux : depuis le chargement). Lot E : revenu du HUD et coût
## des aléas (qui suivait le débit théorique, 3 à 4 fois le revenu réel au T3 de la partie de bot).
func real_income_rate() -> float:
	return _sum(income_buckets) / clampf(real_income_window(), 1.0, 60.0)


## Secondes de revenu réellement mesurées dans les seaux (au plus 60).
func real_income_window() -> float:
	return minf(60.0, minf(clock(), _live_t))


func evp_per_min() -> float:
	return _sum(evp_buckets) * 60.0 / clampf(time, 1.0, 60.0)


func ships_per_hour() -> float:
	return _sum(ship_buckets) * 3600.0 / clampf(time, 1.0, 60.0)


func day() -> int:
	return 1 + floori(time / float(db.cfg("day_seconds")))


# =====================================================================
# Analyse du goulot
# =====================================================================

func avg_ship_evp() -> float:
	var md := max_depth()
	var tw := 0.0
	var te := 0.0
	for s in db.ships:
		var w := class_freq(s)
		if int(s.depth) <= md and w > 0.0:
			tw += w
			te += w * (float(s.evp[0]) + float(s.evp[1])) * 0.5
	return te / maxf(0.001, tw)


## Trafic (EVP/s) qu'une classe de navire apporte au palier courant.
func class_flow(s: Dictionary) -> float:
	return float(s.traffic[tier_index()])


## Fréquence relative des escales d'une classe (trafic ÷ taille moyenne).
func class_freq(s: Dictionary) -> float:
	return class_flow(s) / ((float(s.evp[0]) + float(s.evp[1])) * 0.5)


## Somme du trafic des classes que les quais peuvent recevoir.
func class_traffic() -> float:
	var md := max_depth()
	var t := 0.0
	for s in db.ships:
		if int(s.depth) <= md:
			t += class_flow(s)
	return t


## Somme des poids des armateurs qui fréquentent le port.
func owners_traffic() -> float:
	var t := 0.0
	for o in db.owners:
		if owner_present(o):
			t += owner_factor(o)
	return t


## Poids d'un armateur dans la demande : ses lignes régulières et son contrat en cours le font venir plus souvent.
func owner_factor(o: Dictionary) -> float:
	var f := float(o.weight) * (1.0 + float(db.cfg("line_gain", 1.0)) * float(lines.get(o.id, 0)))
	for ct in contracts_active:
		if ct.owner == o.id:
			f *= float(db.cfg("contract_traffic", 3.0))
			break
	return f


func owner_present(o: Dictionary) -> bool:
	return int(o.tier) <= tier and owner_ok(o)


func time_scale(cls: String) -> float:
	return float(db.ship_by_id[cls].get("time_scale", 1.0))


func owner_ok(o: Dictionary) -> bool:
	var r := String(o.get("require", ""))
	if r != "" and not built.has(r):
		return false
	return not Commerce.needs_recruit(o) or owners_on.has(o.id)


func avg_time_scale() -> float:
	var md := max_depth()
	var tw := 0.0
	var te := 0.0
	for s in db.ships:
		var w := class_freq(s)
		if int(s.depth) <= md and w > 0.0:
			tw += w
			te += w * float(s.get("time_scale", 1.0))
	return te / maxf(0.001, tw)


## Part de chaque cargaison dans les EVP déchargés (moyenne des armateurs présents) : le « panier » du port.
func cargo_shares() -> PackedFloat64Array:
	var mix := _zeros(NCARGO)
	var n := 0
	for o in db.owners:
		if int(o.tier) <= tier and owner_ok(o):
			var m := cargo_mix(o.id)
			for c in NCARGO:
				mix[c] += m[c]
			n += 1
	for c in NCARGO:
		mix[c] /= maxi(1, n)
	return mix


func avg_value_per_evp() -> float:
	var mix := cargo_shares()
	var v := 0.0
	for c in NCARGO:
		v += mix[c] * stat("value", c)
	return v


func _avg_inspect_fraction() -> float:
	var f := 0.0
	var n := 0
	for o in db.owners:
		if int(o.tier) <= tier and owner_ok(o):
			var m := cargo_mix(o.id)
			for c in NCARGO:
				f += m[c] * inspect_fraction(c)
			n += 1
	return f / maxi(1, n)


## Capacité de chaque maillon en EVP/s et identification du goulot.
func capacities() -> Dictionary:
	var avg := avg_ship_evp()
	var caps := {}
	caps["traffic"] = stat("demand")
	var ts := avg_time_scale()
	var pd := pilot_duration() * ts
	caps["pilotage"] = 0.0 if pd == INF else float(pilots()) * avg / maxf(0.01, pd)
	var crane := stat("crane_rate")
	var t_moor := moor_duration() * ts
	var t_form := formal_duration() * ts
	var berth_cap := 0.0
	var t_unload_sum := 0.0
	for bi in berths.size():
		var tu := avg / maxf(0.0001, berth_unload_rate(bi))
		t_unload_sum += tu
		berth_cap += avg / (tu + t_moor + t_form + (0.0 if pd == INF else pd))
	caps["berth_cycle"] = berth_cap
	caps["unload_share"] = t_unload_sum / float(maxi(1, berths.size()))
	caps["moor_share"] = t_moor
	caps["formal_share"] = t_form
	caps["transfer"] = stat("transfer_rate")
	caps["inspection"] = stat("inspect_rate") / maxf(0.001, _avg_inspect_fraction())
	caps["gate"] = stat("gate_rate")
	caps["yard_space"] = yard_capacity() * 0.65 / float(db.cfg("dwell_target"))
	return caps


## Ce que le port sait traiter (EVP/s) : le plus faible des maillons, trafic exclu.
func service_capacity() -> float:
	if analysis.is_empty():
		_refresh_analysis()
	var caps: Dictionary = analysis.caps
	var v := INF
	for k in ["pilotage", "berth_cycle", "transfer", "inspection", "gate", "yard_space"]:
		v = minf(v, float(caps.get(k, INF)))
	return v


## Part du trafic (EVP/s) qu'apporte un armateur présent.
func owner_traffic(oid: String) -> float:
	var o: Dictionary = db.owner_by_id[oid]
	if not owner_present(o):
		return 0.0
	return stat("demand") * owner_factor(o) / maxf(0.0001, owners_traffic())


const HINTS := {
	"harbor": "Pas assez de navires : démarche des armateurs, signe des lignes ou lance une campagne (Commerce).",
	"fog": "Brouillard : le pilotage est suspendu, la rade se remplit.",
	"pilotage": "Les pilotes sont débordés : améliore les Arrivées.",
	"cranes": "Les navires attendent la grue : améliore le Déchargement.",
	"berths": "L'amarrage est trop lent : améliore l'Accostage.",
	"berth_count": "Tous les postes à quai sont occupés : construis un nouveau quai.",
	"customs": "Les formalités traînent : améliore la Douane.",
	"inspection": "Les conteneurs attendent le tampon : améliore la Douane.",
	"yard_ops": "Le quai déborde : améliore le Stockage.",
	"yard_space": "Parc trop petit pour ton débit, même s'il n'est pas plein : agrandis-le (CONSTRUIRE) ou améliore l'empilage (Stockage).",
	"gate": "Les camions font la queue : améliore la Sortie camions ou construis une aire d'attente.",
	"min_time": "Les escales sont au plancher : un remorqueur, des bollards rapides ou un guichet numérique les raccourcissent (CONSTRUIRE).",
	"tier": "Les quais tournent à plein régime : vise le palier suivant pour de plus gros navires.",
}

## Lot G2 (revue) : conseil d'un goulot qui se règle d'un geste (service pas encore ouvert).
const GESTURE_HINTS := {
	"berths": ["Les navires attendent en rade : touche-les pour qu'ils accostent. Léon se présentera bientôt.",
		"Léon s'est présenté : embauche-le (RESPONSABLES), il accostera les navires pour toi."],
	"customs": ["Les conteneurs attendent le tampon : touche la cabane. Paul se présentera bientôt.",
		"Paul s'est présenté : embauche-le (RESPONSABLES), il tamponnera pour toi."],
	"gate": ["Les camions attendent à la barrière : touche-la pour les laisser passer. Tonio se présentera bientôt.",
		"Tonio s'est présenté : embauche-le (RESPONSABLES), il laissera passer les camions pour toi."],
}


func gesture_hint(d: String) -> String:
	var h: Array = GESTURE_HINTS.get(d, ["", ""])
	return String(h[1] if mgr_offered.has(d) else h[0])


## Lot G2 : conseils de la friche (une pièce du départ à la fois).
const STARTER_HINTS := {
	"platform": "La friche est nue : terrasse-la pour poser les conteneurs (AMÉLIORER).",
	"quay1": "Il faut un quai pour qu'un navire accoste : construis le quai n°1.",
	"hut": "Les conteneurs posés attendent la douane : construis la cabane de douane.",
	"track": "Il faut une sortie : une piste et une barrière, et les camions viendront.",
	"crane_mobile": "La grue de bord est lente : une grue mobile décharge bien plus vite.",
	"yard": "La plateforme se remplit : un parc de stockage, avec des engins qui rangent.",
}


## Prochaine pièce du départ à construire (régime manuel), "" quand elles sont toutes là.
func next_starter() -> String:
	if not g2:
		return ""
	for b in STARTERS:
		if not built.has(b):
			return String(b)
	return ""


const HINT_DEPT := {
	"harbor": "", "attract": "", "starter": "", "fog": "harbor", "pilotage": "harbor", "cranes": "cranes", "berths": "berths",
	"berth_count": "berths", "customs": "customs", "inspection": "customs", "yard_ops": "yard_ops",
	"yard_space": "yard_ops", "gate": "gate", "tier": "berths", "min_time": "berths",
}


func _refresh_analysis() -> void:
	var a := _compute_analysis()
	analysis = a
	# conseil affiché au joueur (`analysis_shown`) : rade pleine depuis quelques secondes, des navires sont déroutés, le goulot
	# affiché n'est donc pas « pas assez de navires » (revue N5 bis) ; on désigne le maillon suivant. Présentation seulement :
	# `analysis` (débit soutenable, hors-ligne, contrats, bot d'équilibrage) est inchangée.
	# temps écoulé depuis le passage précédent (appelé toutes les 0,5 s, mais aussi après chaque achat : revue C7 C2)
	var dtb := clampf(time - _bn_last, 0.0, 2.0)
	_bn_last = time
	var full := waiting_ships() >= rade_places()
	_rade_full_t = clampf(_rade_full_t + (dtb if full else -dtb), 0.0, float(db.cfg("rade_full_hold", 3.0)) * 2.0)
	analysis_shown = a
	if (String(a.key) == "harbor" or String(a.key) == "attract") and _rade_full_t >= float(db.cfg("rade_full_hold", 3.0)):
		var b := _compute_analysis(true)
		b.flow = a.flow
		b.caps = a.caps
		b.rade_full = true
		analysis_shown = b
	# alerte (lot D-Éco) : un goulot normal n'est pas une alerte ; la carte ne passe au rouge que si un maillon est bloqué
	# (`alert_reason`), et le reste `alert_hold` s pour ne pas clignoter
	var why := alert_reason(analysis_shown)
	if why != "":
		_alert_why = why
		_alert_left = float(db.cfg("alert_hold", 4.0))
	else:
		_alert_left = maxf(0.0, _alert_left - dtb)
	analysis_shown.alert = _alert_why if _alert_left > 0.0 else ""
	if not is_same(analysis_shown, analysis):
		analysis.alert = analysis_shown.alert
	# depuis quand ce service est-il le goulot (condition « bottleneck » + « for » des chapitres)
	var bd := String(analysis.get("dept", ""))
	for d in _bn_time.keys():
		if d != bd:
			_bn_time[d] = maxf(0.0, float(_bn_time[d]) - dtb)      # un instant ailleurs n'efface pas tout
	_bn_time[bd] = float(_bn_time.get(bd, 0.0)) + dtb


var _alert_why := ""        # dernière raison d'alerte (non sauvegardé)
var _alert_left := 0.0      # secondes d'alerte restantes


## Raison d'alerte de la carte Goulot (lot D-Éco) : "" pour un goulot normal — il y en a toujours un, et une rade pleine
## est l'état ordinaire d'un port saturé ; sinon le maillon bloqué : brouillard (pilotage suspendu), navire sur le point
## de repartir furieux, parc presque plein, camions bloqués à la gate.
func alert_reason(a: Dictionary) -> String:
	if String(a.get("key", "")) == "fog":
		return "fog"
	for s in ships:
		if s.state == Ship.State.ANCHORED and s.patience < float(db.cfg("alert_patience", 0.3)) * s.patience_max:
			return "patience"
	# parc et gate : seulement une fois leur chapitre ouvert (lot E : la carte ne rougit pas pour un service que le joueur
	# ne voit pas encore)
	if feature("dept_yard_ops") and yard_fill() >= float(db.cfg("alert_yard_fill", 0.9)):
		return "yard"
	if g2 and built.has("platform") and yard_fill() >= float(db.cfg("alert_yard_fill", 0.9)):
		return "exit"          # lot G2 : la plateforme est pleine — il faut une sortie
	if feature("dept_gate") and trucks_honking() > 0:
		return "gate"
	return ""


func _compute_analysis(exclude_harbor: bool = false) -> Dictionary:
	invalidate()
	var caps := capacities()
	var cands := {
		"harbor": caps.traffic,
		"pilotage": caps.pilotage,
		"berth_cycle": caps.berth_cycle,
		"yard_ops": caps.transfer,
		"inspection": caps.inspection,
		"gate": caps.gate,
		"yard_space": caps.yard_space,
	}
	if exclude_harbor:
		cands.erase("harbor")
	var best := "harbor"
	var bv := INF
	for k in cands:
		if float(cands[k]) < bv:
			bv = float(cands[k])
			best = k
	var key: String = best
	if best == "pilotage" and caps.pilotage <= 0.0:
		key = "fog"
	elif best == "berth_cycle":
		var u: float = caps.unload_share
		var mo: float = caps.moor_share
		var fo: float = caps.formal_share
		if u >= mo and u >= fo:
			key = "cranes"
		elif mo >= fo:
			key = "berths"
		else:
			key = "customs"
		# amarrage/formalités déjà au minimum : seul un nouveau quai (ou un palier) aide
		var ts := avg_time_scale()      # les petits navires ont des escales plus courtes, plancher compris
		var at_min := (key == "berths" and mo <= min_time("moor") * ts + 0.01) \
			or (key == "customs" and fo <= min_time("formal") * ts + 0.01)
		if (at_min or waiting_ships() >= 2) and _next_building_with("add_berth") != "":
			key = "berth_count"
		elif at_min and _next_building_with("time_min") != "":
			key = "min_time"
		# sinon : chaque niveau du service (Quais, Douane) abaisse encore un peu le plancher
		# pas encore de bureau de douane : les formalités ne s'améliorent pas, on désigne le maillon suivant
		if key == "customs" and not feature("dept_customs"):
			key = "cranes" if u >= mo else "berths"
	var hint: String = HINTS.get(key, "")
	var bid := ""
	# lot G2 : tant que les six pièces du départ ne sont pas là, le conseil désigne la suivante
	var st := next_starter()
	if st != "":
		return {"key": "starter", "dept": "", "hint": String(STARTER_HINTS.get(st, "")), "caps": caps, "flow": bv, "building": st}
	# lot G2 (revue) : le goulot est un geste dont le service n'est pas encore ouvert (pas de carte à améliorer) — le conseil
	# dit le geste à faire, puis d'embaucher son responsable quand il s'est présenté
	var gd := String(HINT_DEPT.get(key, ""))
	if g2 and key in ["berths", "customs", "inspection", "gate"] and OFFER_ORDER.has(gd) and not feature("dept_" + gd) and not managers[gd]:
		return {"key": "gesture", "dept": "", "gesture": gd, "hint": gesture_hint(gd), "caps": caps, "flow": bv, "building": ""}
	# … ou un geste en souffrance, quel que soit le goulot théorique (la capacité d'un service sans responsable, c'est le joueur) :
	# des conteneurs attendent le tampon, un camion attend à la barrière, un navire attend en rade
	if g2:
		var waiting := ""
		if not managers.customs and has_hut and pending_total() >= float(db.cfg("manual").get("hint_pending", 10.0)):
			waiting = "customs"
		elif not managers.gate and pass_ready() and truck_wait_t >= float(db.cfg("manual").get("hint_wait", 6.0)):
			waiting = "gate"
		elif not managers.berths and not managers.harbor:
			for sh in ships:
				if sh.state == Ship.State.ANCHORED and not sh.priority and sh.wait_time >= float(db.cfg("manual").get("hint_wait", 6.0)) * 2.0:
					waiting = "berths"
					break
		if waiting != "":
			return {"key": "gesture", "dept": "", "gesture": waiting, "hint": gesture_hint(waiting), "caps": caps, "flow": bv, "building": ""}
	# manque de navires : l'équipement qui en attire (quai plus long, douane, chenal…) passe avant la Capitainerie
	if key == "harbor":
		bid = traffic_building()
		if bid != "":
			key = "attract"
			var bdef: Dictionary = db.building_by_id[bid]
			hint = String(bdef.get("hint", "Construis « %s » pour attirer plus de navires." % bdef.name))
			if building_state(bid) == "locked":
				var first := _first_available_building()
				if first != "":
					hint += " Construis d'abord « %s »." % db.building_by_id[first].name
	return {"key": key, "dept": HINT_DEPT.get(key, "harbor"), "hint": hint, "caps": caps, "flow": bv, "building": bid}


## Prochain bâtiment du palier qui fait venir plus de navires : plus grands (quai, chenal), ou d'autres armateurs (douane).
func traffic_building() -> String:
	var md := max_depth()
	for b in db.buildings:
		if built.has(b.id) or int(b.tier) > tier:
			continue
		for e in b.effects:
			var t := String(e.type)
			if (t == "berth_depth" or t == "add_berth") and int(e.depth) > md:
				return b.id
			if t == "customs_open" and not customs_open:
				return b.id
			if t == "stat_mult" and String(e.stat) == "demand":
				return b.id
	return ""


func _first_available_building() -> String:
	for b in db.buildings:
		if building_state(b.id) == "available":
			return b.id
	return ""


func _next_building_with(effect_type: String) -> String:
	for b in db.buildings:
		if built.has(b.id) or int(b.tier) > tier:
			continue
		for e in b.effects:
			if e.type == effect_type:
				return b.id
	return ""


## Débit soutenable estimé (EVP/s) : sert au hors-ligne et au dimensionnement des contrats.
func sustainable_flow() -> float:
	if analysis.is_empty():
		_refresh_analysis()
	return float(analysis.get("flow", 0.0))


func income_rate_estimate() -> float:
	var flow := sustainable_flow()
	var v := avg_value_per_evp() * (1.0 + float(db.cfg("gate_fee_ratio")))
	return maxf(0.0, flow * v + service_fee_rate() - salaries_per_day() / float(db.cfg("day_seconds")))


## Revenu net estimé (par seconde) si `n` niveaux de plus étaient achetés : un département (`dept`)
## ou une licence de cargaison (`cargo_i` >= 0). Ne modifie pas l'état (niveaux rétablis, cache vidé).
func income_estimate_with(dept: String, n: int, cargo_i: int = -1) -> float:
	if cargo_i >= 0:
		licences[cargo_i] += n
	else:
		levels[dept] = int(levels[dept]) + n
	invalidate()
	var flow := float(_compute_analysis().flow)
	var v := avg_value_per_evp() * (1.0 + float(db.cfg("gate_fee_ratio")))
	var r := maxf(0.0, flow * v + service_fee_rate() - salaries_per_day() / float(db.cfg("day_seconds")))
	if cargo_i >= 0:
		licences[cargo_i] -= n
	else:
		levels[dept] = int(levels[dept]) - n
	invalidate()
	return r


## Gain de revenu (par seconde) d'un achat de `n` niveaux (département ou licence).
## `base` : revenu estimé sans achat (`income_estimate_with(dept, 0)`), à fournir quand on évalue plusieurs achats d'affilée.
func upgrade_gain(dept: String, n: int, cargo_i: int = -1, base: float = -1.0) -> float:
	var b := base if base >= 0.0 else income_estimate_with(dept, 0, cargo_i)
	return income_estimate_with(dept, n, cargo_i) - b


## Lot E (affichage) : même estimation que `income_estimate_with` (mêmes valeurs, au bit près), avec la part des services
## facturés : {"total": revenu net estimé, "fees": services facturés} ($/s).
func income_parts_with(dept: String, n: int, cargo_i: int = -1) -> Dictionary:
	if cargo_i >= 0:
		licences[cargo_i] += n
	else:
		levels[dept] = int(levels[dept]) + n
	invalidate()
	var flow := float(_compute_analysis().flow)
	var v := avg_value_per_evp() * (1.0 + float(db.cfg("gate_fee_ratio")))
	var fee := service_fee_rate()
	var r := maxf(0.0, flow * v + fee - salaries_per_day() / float(db.cfg("day_seconds")))
	if cargo_i >= 0:
		licences[cargo_i] -= n
	else:
		levels[dept] = int(levels[dept]) - n
	invalidate()
	return {"total": r, "fees": fee}


## Lot E (affichage) : gain d'un achat séparé en part « débit » (le port traite et vend plus : goulot, licences) et part
## « services » (services facturés, qui montent à chaque niveau, goulot ou non). {"total", "flow", "fees"} ($/s) ;
## `base` : `income_parts_with("harbor", 0)`, à fournir quand on évalue plusieurs achats d'affilée.
func upgrade_gain_parts(dept: String, n: int, cargo_i: int = -1, base: Dictionary = {}) -> Dictionary:
	var b := base if not base.is_empty() else income_parts_with(dept, 0, cargo_i)
	var a := income_parts_with(dept, n, cargo_i)
	var total := float(a.total) - float(b.total)
	var fees := float(a.fees) - float(b.fees)
	return {"total": total, "fees": fees, "flow": total - fees}


# =====================================================================
# Achats
# =====================================================================

func dept_cost(dept: String, n: int) -> float:
	var d: Dictionary = db.dept_by_id[dept]
	return Progression.bulk_cost(float(d.cost), float(d.growth), int(levels[dept]) - 1, n)


func dept_max_affordable(dept: String) -> int:
	var d: Dictionary = db.dept_by_id[dept]
	return Progression.max_affordable(float(d.cost), float(d.growth), int(levels[dept]) - 1, money)


func buy_dept(dept: String, n: int) -> bool:
	if not feature("dept_" + dept):
		return false
	if n < 0:
		n = dept_max_affordable(dept)
	if n <= 0:
		return false
	var c := dept_cost(dept, n)
	if c > money:
		return false
	money -= c
	levels[dept] = int(levels[dept]) + n
	purchased.emit("dept", dept)
	_refresh_analysis()
	return true


func licence_cost(ci: int, n: int) -> float:
	var c: Dictionary = db.cargo[ci]
	return Progression.bulk_cost(float(c.licence_cost), float(c.licence_growth), licences[ci] - 1, n)


func licence_max_affordable(ci: int) -> int:
	var c: Dictionary = db.cargo[ci]
	return mini(licence_room(ci), Progression.max_affordable(float(c.licence_cost), float(c.licence_growth), licences[ci] - 1, money))


func buy_licence(ci: int, n: int) -> bool:
	if unlocked[ci] == 0 or not feature("licences"):
		return false
	if n < 0:
		n = licence_max_affordable(ci)
	n = mini(n, licence_room(ci))
	if n <= 0:
		return false
	var cost := licence_cost(ci, n)
	if cost > money:
		return false
	money -= cost
	licences[ci] += n
	invalidate()      # la valeur par EVP change tout de suite (sinon l'écran affiche l'ancienne jusqu'au prochain pas)
	purchased.emit("licence", db.cargo[ci].id)
	return true


## Lot G2 : prix et palier d'un responsable (ceux d'avant G2, `legacy_cost` / `legacy_tier`, pour un port complet).
func manager_cost(dept: String) -> float:
	var m: Dictionary = db.dept_by_id[dept].manager
	return float(m.get("legacy_cost", m.cost)) if not g2 else float(m.cost)


func manager_tier(dept: String) -> int:
	var m: Dictionary = db.dept_by_id[dept].manager
	return int(m.get("legacy_tier", m.tier)) if not g2 else int(m.tier)


func manager_available(dept: String) -> bool:
	return manager_tier(dept) <= tier


## Le responsable d'un service se présente quand ce service atteint le niveau `manager_reveal_level` (10), un par un.
func manager_revealed(dept: String) -> bool:
	if g2 and GESTURE_OF.has(dept):
		return mgr_offered.has(dept)      # lot G2 : il s'est présenté après 5 gestes
	return feature("managers") and int(levels[dept]) >= int(db.cfg("manager_reveal_level", 10))


func hire_manager(dept: String, with_amber: bool = false) -> bool:
	if managers[dept] or not manager_revealed(dept):
		return false
	var m: Dictionary = db.dept_by_id[dept].manager
	if with_amber:
		if amber < int(m.amber):
			return false
		amber -= int(m.amber)
	else:
		if not manager_available(dept) or money < manager_cost(dept):
			return false
		money -= manager_cost(dept)
	managers[dept] = true
	add_counter("managers")
	purchased.emit("manager", dept)
	notify.emit("%s rejoint le port !" % m.name, "good")
	check_unlocks()          # lot G2 : la carte de son service apparaît à l'embauche (Accostage, Douane, Sortie camions)
	_refresh_analysis()
	return true


func managers_count() -> int:
	var n := 0
	for d in managers:
		if managers[d]:
			n += 1
	return n


## Prochain bâtiment constructible (liste séquentielle, comme dans la référence).
func building_state(bid: String) -> String:
	if built.has(bid):
		return "built"
	var b: Dictionary = db.building_by_id[bid]
	if int(b.tier) > tier:
		return "tier"
	for o in db.buildings:
		if o.id == bid:
			break
		if int(o.tier) <= tier and not built.has(o.id):
			return "locked"
	return "available"


func build(bid: String) -> bool:
	if building_state(bid) != "available" or fishing.act0:      # (lot F3 : rien ne se bâtit au port pendant l'acte 0)
		return false
	var b: Dictionary = db.building_by_id[bid]
	if money < float(b.cost):
		return false
	money -= float(b.cost)
	built.append(bid)
	rebuild_infra()
	if g2 and bid == "quay1" and ships.is_empty():
		_spawn_initial()          # lot G2 : le caboteur de Corsaire & Fils se présente en rade
	add_counter("buildings")
	purchased.emit("building", bid)
	notify.emit("Construit : %s" % b.name, "good")
	check_unlocks()
	_refresh_analysis()
	return true


func tier_requirements(t: int) -> Dictionary:
	return db.tier_def(t).get("req", {})


## Renvoie la liste des conditions et leur état pour le palier suivant.
func tier_check() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var req := tier_requirements(tier + 1)
	if req.is_empty():
		return out
	out.append({"label": "Conteneurs traités", "have": counter("evp"), "need": float(req.evp), "ok": counter("evp") >= float(req.evp)})
	out.append({"label": "Réputation", "have": stars(), "need": float(req.stars), "ok": stars() >= float(req.stars)})
	for bid in req.get("buildings", []):
		out.append({"label": String(db.building_by_id[bid].name), "have": 1.0 if built.has(bid) else 0.0, "need": 1.0, "ok": built.has(bid), "building": true})
	out.append({"label": "Coût", "have": money, "need": float(req.money), "ok": money >= float(req.money), "money": true})
	return out


## Avancement (0–1) vers le palier suivant : moyenne des conditions.
func tier_progress() -> float:
	if finished:
		return 1.0
	var chk := tier_check()
	if chk.is_empty():
		return 1.0
	var tot := 0.0
	for c in chk:
		tot += clampf(float(c.have) / maxf(0.0001, float(c.need)), 0.0, 1.0)
	return tot / float(chk.size())


# --- lot F3/G1 : chapitre 1 « La Crique » (la pêche de l'anse) -------------------------

## Partie neuve jouée (départ de l'interface, bot) : l'acte 0 commence — 0 $, le port à conteneurs est fermé.
func begin_act0() -> void:
	fishing = Fishing.new(db, int(rng.seed % 1000003))
	fishing.act0 = true
	money = 0.0
	_enter_manual()          # lot G2 : après la Concession, la friche est nue ; le processus se fait à la main


## Nouvelle concession : la pêche est reprise telle quelle ; le port reste fermé le temps de la séquence du T1 (la bascule
## se joue tout de suite, sans condition d'argent).
func hold_port() -> void:
	fishing.act0 = true
	fishing.replay = true
	_enter_manual(true)      # lot G2 : la nouvelle concession repart de la friche (les fonctions déjà connues restent)


## Bascule vers le T1 : la Concession du terre-plein est signée (ou nouvelle concession).
func act0_ready() -> bool:
	if not fishing.act0:
		return false
	return fishing.replay or fishing.concession_done()


## Fin de la Crique : le port ouvre (l'horloge du port démarre ; la pêche continue, Marcel encaisse).
func open_port() -> void:
	if not fishing.act0:
		return
	fishing.act0 = false
	fishing.replay = false
	invalidate()
	_refresh_analysis()


## Lot G1 — cartes de la pêche (AMÉLIORER, pendant la Crique et après : elles restent achetables jusqu'à leur maximum).
func buy_fish_places(n: int = 1) -> bool:
	if n < 0:
		n = fishing.places_affordable(money)
	n = mini(n, fishing.places_max() - fishing.places)
	if n <= 0:
		return false
	var c := fishing.places_cost(n)
	if money < c:
		return false
	money -= c
	fishing.buy_places(n)
	purchased.emit("fish", "places")
	return true


func buy_fish_services(n: int = 1) -> bool:
	if n < 0:
		n = fishing.services_affordable(money)
	n = mini(n, fishing.services_max() - fishing.services)
	if n <= 0:
		return false
	var c := fishing.services_cost(n)
	if money < c:
		return false
	money -= c
	fishing.buy_services(n)
	purchased.emit("fish", "services")
	return true


## Bâtiment de la Crique (quai des chalutiers, jetée, marina…) ; la Concession = fin de la Crique (la bascule se joue).
func buy_fish_building(id: String) -> bool:
	if not fishing.can_build(id):
		return false
	var c := float(fishing.building_def(id).get("cost", 0.0))
	if money < c:
		return false
	money -= c
	fishing.build(id)
	purchased.emit("fish", id)
	if fishing.concession_done() and fishing.act0:
		notify.emit("Concession signée : la friche est à toi !", "good")
	return true


## Toucher un bateau rentré (sans Marcel) : son loyer est encaissé. Renvoie le montant (0 si rien).
func fish_collect(i: int) -> float:
	var a := fishing.collect(i, boost_mult())
	if a > 0.0:
		_earn(a, "fish")
		fish_event.emit("rent_paid")
		_flush_fish_events()
	return a


func fish_collectable(i: int) -> bool:
	return fishing.can_collect(i)


## Marcel, patron pêcheur : un responsable hors département. (Lot G1-d : il ne révèle plus les Heures sup — ce sera le premier
## responsable du port, lot G2 ; rien de visible ni d'actif avant le port.)
func hire_marcel() -> bool:
	if not fishing.marcel_offered or fishing.marcel:
		return false
	var c := fishing.marcel_cost()
	if money < c:
		return false
	money -= c
	fishing.hire_marcel()
	add_counter("managers")
	purchased.emit("manager", "marcel")
	notify.emit("%s rejoint la Crique !" % String(fishing.cfg.get("marcel", {}).get("name", "Marcel")), "good")
	_refresh_analysis()
	return true


# --- prestige : nouvelle concession ------------------------------------------

## Points de Renom gagnés si on repart maintenant (racine des EVP traités dans cette concession).
func prestige_gain() -> int:
	var r: Dictionary = db.cfg("renown")
	return floori(sqrt(counter("evp") / float(r.evp_scale)))


func can_prestige() -> bool:
	return finished and prestige_gain() >= 1


## Reprend d'une concession terminée ce qui est permanent : Renom, Ambre, missions réclamées, compteurs cumulés.
## À appeler sur une partie neuve (`PortSim.new`) ; l'ancienne partie n'est pas modifiée.
func carry_over(old: PortSim) -> void:
	var r: Dictionary = db.cfg("renown")
	renown = old.renown + old.prestige_gain()
	prestiges = old.prestiges + 1
	amber = old.amber + int(r.amber)
	missions_claimed.clear()
	for m in old.missions_claimed:
		missions_claimed.append(m)
	lifetime = old.lifetime.duplicate()
	for f in old.features:
		features[f] = true
	for k in old.counters:
		if not RUN_ONLY_COUNTERS.has(k):
			lifetime[k] = float(lifetime.get(k, 0.0)) + float(old.counters[k])
	# lot F3/G1 : la crique reste à toi — la pêche continue au plafond, la Crique ne se rejoue pas
	if old.fishing.places > 0:
		fishing.migrate_done()
		fishing.earned = old.fishing.earned
	invalidate()
	_refresh_analysis()


func can_tier_up() -> bool:
	if finished:
		return false
	var chk := tier_check()
	if chk.is_empty():
		return false
	for c in chk:
		if not c.ok:
			return false
	return true


func tier_up() -> bool:
	if not can_tier_up():
		return false
	var nt := db.tier_def(tier + 1)
	money -= float(nt.req.money)
	tier += 1
	amber += int(nt.get("amber", 0))
	last_tier_t = time      # la cérémonie du palier passe seule : aucune révélation pendant `reveal_tier_hold` s
	check_unlocks()
	if bool(nt.get("final", false)):
		finished = true
		tier = 3
		notify.emit("Concession nationale obtenue !", "good")
		tier_changed.emit(4)
	else:
		notify.emit("Nouveau palier : %s" % nt.name, "good")
		tier_changed.emit(tier)
	Objectives.rescale_offers(self)
	if feature("contracts"):
		Objectives.refresh_offers(self)
	_refresh_analysis()
	return true


func set_policy(p: int) -> void:
	policy = clampi(p, 0, db.cfg("policies").size() - 1)
	_refresh_analysis()


func set_tariff(t: float) -> void:
	tariff = clampf(t, float(db.cfg("tariff_min")), float(db.cfg("tariff_max")))
	_refresh_analysis()


func boost_ready() -> bool:
	return clock() >= boost_ready_at


func start_boost() -> bool:
	if not boost_ready() or not feature("boost"):
		return false
	var b: Dictionary = db.cfg("boost")
	boost_until = clock() + float(b.duration)
	boost_ready_at = boost_until + float(b.cooldown)
	invalidate()
	purchased.emit("boost", "")
	return true


func skip_boost_cooldown() -> bool:
	var cost := int(db.cfg("boost").amber_skip)
	if boost_ready() or boost_active() or amber < cost:
		return false
	amber -= cost
	boost_ready_at = clock()
	return true


# =====================================================================
# Hors-ligne
# =====================================================================

## Rattrapage agrégé (pas de boucle tick par tick). Renvoie le détail pour l'écran « Bon retour ».
func apply_offline(seconds: float) -> Dictionary:
	var cap := float(db.cfg("offline_max_hours")) * 3600.0
	var t := clampf(seconds, 0.0, cap)
	var base := float(db.cfg("offline_base_yield"))
	if fishing.act0:
		# lot G1 : pendant la Crique, avant Marcel le monde se fige (rien gagné, rien perdu : rapport vide) ; avec Marcel, la
		# pêche rapporte à son rythme
		if not fishing.marcel:
			return {}
		var fg := fishing.offline_rate() * t
		money += fg
		fishing.earned += fg
		return {"seconds": t, "capped": seconds > cap, "yield": 1.0, "money": fg, "evp": 0.0, "managers": 1}
	if g2 and managers_count() == 0:
		# lot G2 : avant le premier responsable du port, le port se fige (seule Marcel encaisse les loyers de la Crique)
		var fz := fishing.offline_rate() * t
		if fz <= 0.0:
			return {}
		money += fz
		fishing.earned += fz
		return {"seconds": t, "capped": seconds > cap, "yield": 0.0, "money": fz, "evp": 0.0, "managers": 0}
	var yield_ratio := base + (1.0 - base) * float(managers_count()) / float(DEPTS.size())
	var flow := sustainable_flow()
	var gain := income_rate_estimate() * t * yield_ratio
	var evp := flow * t * yield_ratio
	var fg2 := fishing.offline_rate() * t      # lot G1 : Marcel encaisse pendant l'absence
	gain += fg2
	fishing.earned += fg2
	money += gain
	add_counter("evp", evp)
	add_counter("offline_evp", evp)
	return {"seconds": t, "capped": seconds > cap, "yield": yield_ratio, "money": gain, "evp": evp, "managers": managers_count()}


# =====================================================================
# Sauvegarde
# =====================================================================

func to_dict() -> Dictionary:
	var sh: Array = []
	for s in ships:
		sh.append(s.to_dict())
	return {
		"time": time, "money": money, "amber": amber, "tier": tier, "finished": finished,
		"satisfaction": satisfaction, "levels": levels.duplicate(), "managers": managers.duplicate(),
		"licences": Array(licences), "built": built.duplicate(), "policy": policy, "tariff": tariff,
		"boost_until": boost_until, "boost_ready_at": boost_ready_at, "relations": relations.duplicate(),
		"counters": counters.duplicate(), "missions_claimed": missions_claimed.duplicate(),
		"renown": renown, "prestiges": prestiges, "lifetime": lifetime.duplicate(), "features": features.duplicate(), "last_reveal_t": last_reveal_t, "last_reveal_id": last_reveal_id, "last_tier_t": last_tier_t, "owners_on": owners_on.keys(), "lines": lines.duplicate(),
		"line_offers": line_offers.duplicate(), "campaign_ready_at": campaign_ready_at.duplicate(),
		"ships": sh, "next_ship_id": next_ship_id, "arrival_accum": arrival_accum,
		"apron": Array(apron), "yard_pending": Array(yard_pending), "yard_cleared": Array(yard_cleared),
		"delivered": Array(delivered), "arrived_total": arrived_total, "sailed_away": sailed_away,
		"truck_queue": truck_queue, "truck_visual_accum": truck_visual_accum,
		"active_event": active_event.duplicate(true), "next_event_at": next_event_at,
		"contract_offers": contract_offers.duplicate(true), "contracts_active": contracts_active.duplicate(true),
		"next_contract_refresh": next_contract_refresh, "mods": mods.to_array(),
		"stat_rade_wait": stat_rade_wait, "stat_truck_wait": stat_truck_wait,
		"rng_state": str(rng.state), "pending_arrival": pending_arrival.duplicate(),
		"t_second": _second_timer, "t_analysis": _analysis_timer, "bucket_time": bucket_time, "bucket_index": bucket_index,
		# lot E (champs facultatifs, version inchangée) : la dernière minute de revenu, pour que le revenu affiché et le coût
		# des aléas restent justes juste après un chargement
		"income_buckets": Array(income_buckets), "evp_buckets": Array(evp_buckets), "ship_buckets": Array(ship_buckets),
		# lot F3/G1 (sauvegarde v7) : la pêche de l'anse et la Crique ; absente = partie d'avant F3 (Crique finie)
		"act0": fishing.to_dict(),
		# lot G2 (sauvegarde v8) : le régime manuel (friche, gestes, offres des responsables) ; absente = port complet
		"g2": {"manual": g2, "gestures": gestures.duplicate(), "offered": mgr_offered.duplicate(), "truck_wait_t": truck_wait_t},
	}


func from_dict(d: Dictionary) -> void:
	reset()
	# lot G2 : régime manuel (clé « g2 ») ; une partie v7 en pleine Crique (pas de « g2 ») le prend aussi : son port partira de la
	# friche ; sinon (T1 et au-delà) le port est complet
	var g2d: Dictionary = d.get("g2", {}) if d.get("g2") is Dictionary else {}
	var a0: Dictionary = d.get("act0", {}) if d.get("act0") is Dictionary else {}
	var manual := bool(g2d.get("manual", false)) if not g2d.is_empty() else (bool(a0.get("on", false)) and not bool(a0.get("replay", false)))
	if manual:
		g2 = true
		features.clear()
	time = float(d.get("time", 0.0))
	money = float(d.get("money", 0.0))
	amber = int(d.get("amber", 0))
	tier = clampi(int(d.get("tier", 1)), 1, 3)     # palier borné (Layout.LAND_X, tier_def…)
	finished = bool(d.get("finished", false))
	satisfaction = float(d.get("satisfaction", 0.55))
	for k in d.get("levels", {}):
		if levels.has(k):
			levels[k] = int(d.levels[k])
	for k in d.get("managers", {}):
		if managers.has(k):
			managers[k] = bool(d.managers[k])
	var li: Array = d.get("licences", [])
	for i in mini(li.size(), NCARGO):
		licences[i] = int(li[i])
	built.clear()
	if not g2:
		for b in STARTERS:      # lot G2 : un port complet a ses six pièces du départ (en tête, dans l'ordre de la liste)
			built.append(String(b))
	for b in d.get("built", []):
		if db.building_by_id.has(b) and not built.has(String(b)):
			built.append(String(b))
	if not g2d.is_empty():
		var gg: Dictionary = g2d.get("gestures", {})
		for k in gestures:
			gestures[k] = int(gg.get(k, 0))
		var off: Dictionary = g2d.get("offered", {})
		for k in off:
			mgr_offered[String(k)] = float(off[k])
		truck_wait_t = float(g2d.get("truck_wait_t", 0.0))
	policy = int(d.get("policy", 1))
	tariff = float(d.get("tariff", 1.0))
	boost_until = float(d.get("boost_until", -1.0))
	boost_ready_at = float(d.get("boost_ready_at", 0.0))
	for k in d.get("relations", {}):
		relations[k] = float(d.relations[k])
	counters = d.get("counters", {}).duplicate()
	renown = int(d.get("renown", 0))
	prestiges = int(d.get("prestiges", 0))
	lifetime = d.get("lifetime", {}).duplicate()
	# fonctions révélées : {id: instant de la révélation} depuis la version 5 de la sauvegarde (revue C7 A3 : une chaîne
	# « after » garde son délai au rechargement) ; liste d'identifiants avant (révélées « depuis toujours »)
	var fd: Variant = d.get("features", [])
	if fd is Dictionary:
		for f in fd:
			var fv: Variant = fd[f]
			if (fv is float or fv is int) and not (fv is bool):
				features[String(f)] = float(fv)
			else:
				features[String(f)] = true
	elif fd is Array:
		for f in fd:
			features[String(f)] = true
	last_reveal_t = float(d.get("last_reveal_t", -1.0e9))
	last_reveal_id = String(d.get("last_reveal_id", ""))
	# lot E : champ facultatif (version de sauvegarde inchangée) ; une partie plus ancienne n'a plus d'attente de palier
	last_tier_t = float(d.get("last_tier_t", -1.0e9))
	for o in d.get("owners_on", []):
		owners_on[String(o)] = true
	for k in d.get("lines", {}):
		lines[String(k)] = int(d.lines[k])
	for o in d.get("line_offers", []):
		line_offers.append(String(o))
	for k in d.get("campaign_ready_at", {}):
		campaign_ready_at[String(k)] = float(d.campaign_ready_at[k])
	missions_claimed.clear()
	for m in d.get("missions_claimed", []):
		missions_claimed.append(String(m))
	ships.clear()
	for sd in d.get("ships", []):
		ships.append(Ship.from_dict(sd))
	next_ship_id = int(d.get("next_ship_id", 1))
	arrival_accum = float(d.get("arrival_accum", 0.0))
	apron = PackedFloat64Array(d.get("apron", Array(_zeros(NCARGO))))
	yard_pending = PackedFloat64Array(d.get("yard_pending", Array(_zeros(NCARGO))))
	yard_cleared = PackedFloat64Array(d.get("yard_cleared", Array(_zeros(NCARGO))))
	delivered = PackedFloat64Array(d.get("delivered", Array(_zeros(NCARGO))))
	arrived_total = float(d.get("arrived_total", 0.0))
	sailed_away = float(d.get("sailed_away", 0.0))
	truck_queue = 0.0
	truck_queue = float(d.get("truck_queue", 0.0))
	truck_visual_accum = float(d.get("truck_visual_accum", 0.0))
	active_event = d.get("active_event", {})
	next_event_at = float(d.get("next_event_at", time + 120.0))
	contract_offers.clear()
	for c in d.get("contract_offers", []):
		contract_offers.append(c)
	contracts_active.clear()
	for c in d.get("contracts_active", []):
		contracts_active.append(c)
	next_contract_refresh = float(d.get("next_contract_refresh", 0.0))
	mods.from_array(d.get("mods", []))
	stat_rade_wait = float(d.get("stat_rade_wait", 0.0))
	stat_truck_wait = float(d.get("stat_truck_wait", 0.0))
	if d.has("rng_state"):
		rng.state = int(String(d.rng_state))
	pending_arrival = d.get("pending_arrival", {})
	_second_timer = float(d.get("t_second", 0.0))
	_analysis_timer = float(d.get("t_analysis", 0.0))
	bucket_time = float(d.get("bucket_time", 0.0))
	bucket_index = int(d.get("bucket_index", 0))
	var ib: Array = d.get("income_buckets", [])
	if ib.size() == 60:
		income_buckets = PackedFloat64Array(ib)
		var eb: Array = d.get("evp_buckets", [])
		var sb: Array = d.get("ship_buckets", [])
		if eb.size() == 60:
			evp_buckets = PackedFloat64Array(eb)
		if sb.size() == 60:
			ship_buckets = PackedFloat64Array(sb)
		# la fenêtre d'une minute est pleine (seaux sauvegardés). Lot G2 (revue) : sur l'horloge de toute la partie — les seaux
		# tournent aussi pendant la Crique ; avec `time` (horloge du port, ≈ 0 à la friche) le revenu affiché était gonflé ×70
		_live_t = 60.0          # (borné ci-dessous, une fois la Crique chargée : clock() en dépend)
	if not d.has("features"):
		_upgrade_legacy_save()
	if not d.has("owners_on"):
		_upgrade_commerce_save()
	# lot F3 (v6) : une partie d'avant l'acte 0 se charge avec la Crique finie ; lot G1 (v7) : une partie v6 en cours d'acte 0
	# recommence la Crique (0 $), une partie v6 au T1 ou au-delà se charge Crique finie (plafond R₀, Marcel, Concession)
	var old_fish := not (d.get("act0") is Dictionary) or not (d.act0 as Dictionary).has("places")
	if d.get("act0") is Dictionary:
		fishing.from_dict(d.act0)
	else:
		fishing.migrate_done()
	if fishing.restarted:
		money = 0.0
		_enter_manual()
	elif old_fish:
		# les Heures sup se comptent sur clock() (= time + act0_time) depuis G1
		if boost_until > 0.0:
			boost_until += fishing.act0_time
		if boost_ready_at > 0.0:
			boost_ready_at += fishing.act0_time
	if ib.size() == 60:
		_live_t = minf(clock(), 60.0)
	_clamp_licences()
	rebuild_infra()
	_bn_last = time          # pas de « temps de goulot » fantôme entre 0 et l'heure de la partie chargée (revue C7 C2)
	_refresh_analysis()


## La dernière fonction révélée a-t-elle déjà servi (condition « used » de unlocks.json) ? Si oui, la suivante n'attend
## pas la fin de `reveal_gap` (revue N8 : une révélation par minute, ou dès que la précédente est utilisée).
func _last_reveal_used() -> bool:
	if last_reveal_id == "":
		return false
	var u: Dictionary = db.unlock_by_id.get(last_reveal_id, {})
	return u.has("used") and unlock_ok(u.used)


## Une révélation ordinaire attend `reveal_gap` s (60) après la précédente, ou seulement `reveal_gap_min` s (20) si la
## précédente a déjà servi.
func _reveal_gap_over() -> bool:
	var dt := time - last_reveal_t
	if dt >= float(db.cfg("reveal_gap", 0.0)):
		return true
	return dt >= float(db.cfg("reveal_gap_min", 0.0)) and _last_reveal_used()


## Conseil de goulot affiché au joueur (voir `_refresh_analysis`).
func shown_analysis() -> Dictionary:
	return analysis_shown if not analysis_shown.is_empty() else analysis
