class_name Progression
extends RefCounted
## Formules de coût et d'effet (idle classique : coût exponentiel, effet linéaire × paliers).


## Multiplicateur de palier : ×2 aux niveaux 10, 25, 50, 100 puis ×5 aux niveaux 150, 200…
static func milestone_mult(level: int, x2: Array, x5: Array) -> float:
	var m := 1.0
	for l in x2:
		if level >= int(l):
			m *= 2.0
	for l in x5:
		if level >= int(l):
			m *= 5.0
	return m


## Prochain niveau donnant un palier (0 si aucun).
static func next_milestone(level: int, x2: Array, x5: Array) -> int:
	var best := 0
	for l in x2 + x5:
		var li := int(l)
		if li > level and (best == 0 or li < best):
			best = li
	return best


## Coût pour passer du niveau `level` au niveau `level + n`.
static func bulk_cost(base: float, growth: float, level: int, n: int) -> float:
	if n <= 0:
		return 0.0
	var first := base * pow(growth, level)
	return first * (pow(growth, n) - 1.0) / (growth - 1.0)


## Nombre maximal de niveaux achetables avec `money`.
static func max_affordable(base: float, growth: float, level: int, money: float) -> int:
	var first := base * pow(growth, level)
	if money < first:
		return 0
	var n := int(floor(log(money * (growth - 1.0) / first + 1.0) / log(growth)))
	# corrige les erreurs d'arrondi
	while n > 0 and bulk_cost(base, growth, level, n) > money:
		n -= 1
	return n


## Interpolation linéaire par morceaux sur une courbe [[x, y], ...].
static func curve(points: Array, x: float) -> float:
	if points.is_empty():
		return 1.0
	if x <= float(points[0][0]):
		return float(points[0][1])
	for i in range(1, points.size()):
		var a: Array = points[i - 1]
		var b: Array = points[i]
		if x <= float(b[0]):
			var t := (x - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0]))
			return lerpf(float(a[1]), float(b[1]), t)
	return float(points[-1][1])


## Multiplicateur de paliers donné par une liste [[niveau, mult], …] (licences : paliers finis et décroissants).
static func step_mult(level: int, steps: Array) -> float:
	var m := 1.0
	for st in steps:
		if level >= int(st[0]):
			m *= float(st[1])
	return m


## Prochain palier [niveau, mult] au-delà de `level` (vide s'il n'y en a plus).
static func next_step(level: int, steps: Array) -> Array:
	for st in steps:
		if int(st[0]) > level:
			return st
	return []
