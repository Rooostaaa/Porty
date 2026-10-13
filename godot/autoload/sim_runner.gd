extends Node
## Fait avancer la simulation à pas fixe (0,25 s), avec accélération de debug.

var speed: float = 1.0
var paused: bool = false
var _acc: float = 0.0


func _process(delta: float) -> void:
	if paused or GameState.sim == null:
		return
	var tick := float(GameState.db.cfg("tick"))
	_acc += minf(delta, 0.25) * speed
	var guard := 0
	while _acc >= tick and guard < 2000:
		_acc -= tick
		GameState.sim.step(tick)
		guard += 1


## Fraction du pas courant (interpolation visuelle).
func alpha() -> float:
	return _acc / float(GameState.db.cfg("tick"))
