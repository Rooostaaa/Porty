class_name HoldRepeat
extends Node
## Appui long sur un bouton d'achat : après un court délai, l'achat se répète en accélérant (0,35 s → 0,05 s)
## tant que le doigt (ou la souris) reste appuyé et que l'achat réussit. Un appui bref garde son effet normal.
## Le nœud est enfant du bouton : il disparaît avec lui.

signal burst_ended(count: int)     # fin d'une rafale (relâchement ou achat impossible) : un seul effet de fin

const FIRST_DELAY := 0.4           # maintien nécessaire avant la première répétition
const START_INTERVAL := 0.35
const MIN_INTERVAL := 0.05
const ACCEL := 0.8                 # chaque répétition raccourcit l'intervalle

var single: Callable               # appui bref (au relâchement)
var repeat: Callable               # (n: int) -> bool : n-ième répétition ; false = impossible, la rafale s'arrête
var count := 0                     # répétitions de la rafale en cours
var _held := false
var _repeating := false
var _t := 0.0
var _interval := START_INTERVAL


## Branche l'appui bref et l'appui long sur `b` (à la place de `b.pressed.connect(single)`).
static func attach(b: BaseButton, single_cb: Callable, repeat_cb: Callable) -> HoldRepeat:
	var h := HoldRepeat.new()
	h.single = single_cb
	h.repeat = repeat_cb
	b.add_child(h)
	b.button_down.connect(h.press)
	b.button_up.connect(h.release)
	b.pressed.connect(h._on_pressed)
	return h


func press() -> void:
	_held = true
	_repeating = false
	_t = FIRST_DELAY
	_interval = START_INTERVAL
	count = 0


func release() -> void:
	if _repeating and _held:
		burst_ended.emit(count)
	_held = false
	# `pressed` (émis juste avant `button_up`) a déjà été ignoré si la rafale avait commencé
	_repeating = false


func is_repeating() -> bool:
	return _repeating


func _on_pressed() -> void:
	if not _repeating:
		single.call()


## Avance l'horloge de l'appui long (appelé à chaque image ; les tests l'appellent directement).
func tick(delta: float) -> void:
	if not _held:
		return
	_t -= delta
	while _held and _t <= 0.0:
		_repeating = true
		if not bool(repeat.call(count + 1)):
			# plus d'argent : la rafale s'arrête même si le doigt reste posé (le bouton se grise et n'émettra pas `button_up`)
			_held = false
			burst_ended.emit(count)
			return
		count += 1
		_t += _interval
		_interval = maxf(MIN_INTERVAL, _interval * ACCEL)


func _process(delta: float) -> void:
	tick(delta)
