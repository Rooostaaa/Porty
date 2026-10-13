extends Node
## Possède la simulation courante. La vue s'abonne à `sim` (signaux) et à `sim_replaced`.

signal sim_replaced(sim: PortSim)
signal offline_applied(report: Dictionary)   # le jeu reprend après une absence (veille, arrière-plan) : voir `credit_offline`

var db: DataDB
var sim: PortSim
var offline_report: Dictionary = {}          # absence constatée au chargement, que l'interface montre à son ouverture


func _ready() -> void:
	db = DataDB.new()
	sim = PortSim.new(db, randi() % 1000000)
	Objectives.refresh_offers(sim)


func new_game() -> void:
	sim = PortSim.new(db, randi() % 1000000)
	Objectives.refresh_offers(sim)
	sim_replaced.emit(sim)


## Nouvelle concession : repart de zéro en gardant le Renom, l'Ambre et les missions réclamées.
func prestige() -> bool:
	if sim == null or not sim.can_prestige():
		return false
	var fresh := PortSim.new(db, randi() % 1000000)
	fresh.carry_over(sim)
	sim = fresh
	Objectives.refresh_offers(sim)
	sim_replaced.emit(sim)
	Save.save_game()
	return true


## Crédite une absence constatée pendant la partie (l'application était suspendue) et prévient l'interface.
func credit_offline(seconds: float) -> void:
	if sim == null:
		return
	offline_applied.emit(sim.apply_offline(seconds))


func load_from(d: Dictionary) -> void:
	sim = PortSim.new(db)
	sim.from_dict(d)
	if sim.contract_offers.is_empty():
		Objectives.refresh_offers(sim)
	sim_replaced.emit(sim)
