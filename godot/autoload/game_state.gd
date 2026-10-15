extends Node
## Possède la simulation courante. La vue s'abonne à `sim` (signaux) et à `sim_replaced`.

signal sim_replaced(sim: PortSim)
signal offline_applied(report: Dictionary)   # le jeu reprend après une absence (veille, arrière-plan) : voir `credit_offline`

var db: DataDB
var sim: PortSim
var offline_report: Dictionary = {}          # absence constatée au chargement, que l'interface montre à son ouverture
## Lot F2 : partie neuve pas encore commencée — l'interface joue le départ (cartes d'intro, friche, séquence de chantiers du
## T1) au prochain lien (`Hud.bind`) ; une partie chargée ne rejoue rien.
var start_pending := false
var auto_start := true                       # (tests) coupé : la partie neuve commence tout bâti, comme avant le lot F2


func _ready() -> void:
	db = DataDB.new()
	sim = PortSim.new(db, randi() % 1000000)
	start_pending = true          # premier lancement sans sauvegarde (Save.load_game la remet à faux)
	Objectives.refresh_offers(sim)


func new_game() -> void:
	sim = PortSim.new(db, randi() % 1000000)
	start_pending = true
	Objectives.refresh_offers(sim)
	sim_replaced.emit(sim)


## Le départ est-il à jouer pour la partie qui vient d'être liée ? (une seule fois)
func consume_start() -> bool:
	var r := start_pending and auto_start
	start_pending = false
	return r


## Nouvelle concession : repart de zéro en gardant le Renom, l'Ambre et les missions réclamées.
func prestige() -> bool:
	if sim == null or not sim.can_prestige():
		return false
	var fresh := PortSim.new(db, randi() % 1000000)
	fresh.carry_over(sim)
	sim = fresh
	start_pending = true          # lot F2 : la nouvelle concession repart de la friche (sans les cartes d'intro)
	Objectives.refresh_offers(sim)
	sim_replaced.emit(sim)
	Save.save_game()
	return true


## Crédite une absence constatée pendant la partie (l'application était suspendue) et prévient l'interface.
func credit_offline(seconds: float) -> void:
	if sim == null:
		return
	var rep := sim.apply_offline(seconds)
	if not rep.is_empty():          # (lot G1 : avant Marcel, le monde se fige — rien à dire)
		offline_applied.emit(rep)


func load_from(d: Dictionary) -> void:
	sim = PortSim.new(db)
	sim.from_dict(d)
	start_pending = false
	if sim.contract_offers.is_empty():
		Objectives.refresh_offers(sim)
	sim_replaced.emit(sim)
