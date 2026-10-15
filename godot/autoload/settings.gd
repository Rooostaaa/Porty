extends Node
## Réglages persistants (son, debug).

signal changed()

const PATH := "user://settings.cfg"
const TUTO_REV := 8                # liste d'étapes du tutoriel (data/tutorial.json) : 5 = le parc avant Yasmine (revue C7 B5)
                                   # 6 = lot F3, trois étapes de l'acte 0 en tête (ponton, barque, criée)
                                   # 7 = lot G1, sept étapes de la Crique (ponton, loyer, places, criée, Marcel, mission, Concession)
                                   # 8 = lot G2, le premier navire à la main (terrassement, quai, accoster, cabane, tamponner, piste,
                                   #     laisser passer) ; « crane » et « gate » retirées

var muted: bool = false
var show_flows: bool = false
var intro_seen: bool = false     # le message de bienvenue a déjà été montré
var tuto_step: int = 0
var tuto_rev: int = 0              # version de la liste d'étapes (les index changent quand on en insère une)
var persist_tuto: bool = true


func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		muted = bool(cf.get_value("audio", "muted", false))
		intro_seen = bool(cf.get_value("tuto", "intro_seen", false))
		tuto_step = int(cf.get_value("tuto", "step", 0))
		tuto_rev = int(cf.get_value("tuto", "rev", 1))


func set_intro_seen() -> void:
	intro_seen = true
	if persist_tuto:          # (lot F2 : une partie de test --fresh ne marque pas l'intro comme vue chez le joueur)
		_save()


## Étape courante du tutoriel guidé (0 = pas commencé ; ≥ nombre d'étapes = terminé).
## `persist_tuto` est coupé pour les parties de test (--fresh) afin de ne pas écraser la progression réelle.
func set_tuto_step(i: int) -> void:
	tuto_step = i
	tuto_rev = TUTO_REV
	if persist_tuto:
		_save()


func set_muted(v: bool) -> void:
	muted = v
	_save()
	changed.emit()


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "muted", muted)
	cf.set_value("tuto", "intro_seen", intro_seen)
	cf.set_value("tuto", "step", tuto_step)
	cf.set_value("tuto", "rev", tuto_rev)
	cf.save(PATH)
