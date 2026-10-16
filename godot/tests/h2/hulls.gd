extends RefCounted
## Lot H2 — coques des navires pour les contrôles (run_all, tests/h2/h2_check.gd) : contour d'une coque, dégagement aux
## obstacles le long d'un trajet (marche avant, marche arrière, cap tenu).

const MODELS := {"mini": "ship_mini", "coaster": "ship_coaster", "feeder": "ship_feeder", "panamax": "ship_panamax"}
const DEPTH_CLASS := {1: "mini", 2: "coaster", 3: "feeder", 4: "panamax"}


## Longueur, largeur (échelles du jeu, Layout.SHIP_SCALE).
static func ship_size(cls: String) -> Vector2:
	var m := Assets.meta(String(MODELS.get(cls, "ship_feeder")))
	var s := float(Layout.SHIP_SCALE.get(cls, 1.0))
	return Vector2(float(m.get("length", 30.0)) * s, float(m.get("width", 8.0)) * s)


## Plus grand navire du poste bi selon ce qui est bâti (comme la simulation).
static func berth_class(bi: int, built: Array) -> String:
	var d := 4
	if bi == 0:
		d = 3 if built.has("dredge1") else (2 if built.has("quay_ext") else 1)
	elif bi == 1:
		d = 3
	elif not built.has(Layout.SEAWALL):
		d = 3
	return String(DEPTH_CLASS[d])


static func hull_poly(c: Vector2, fwd: Vector2, size: Vector2) -> PackedVector2Array:
	var side := Vector2(-fwd.y, fwd.x)
	var hl := size.x * 0.5
	var hw := size.y * 0.5
	return PackedVector2Array([c + fwd * hl, c + fwd * (hl - hw) + side * hw, c - fwd * hl + side * hw,
		c - fwd * hl - side * hw, c + fwd * (hl - hw) - side * hw])


static func hull_points(c: Vector2, fwd: Vector2, size: Vector2, step: float = 1.0) -> PackedVector2Array:
	var poly := hull_poly(c, fwd, size)
	var out := PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var n := maxi(1, ceili(a.distance_to(b) / step))
		for k in n:
			out.append(a.lerp(b, float(k) / float(n)))
	return out


## Point dans un polygone (pair-impair, rayon horizontal demi-ouvert : robuste aux sommets sur le rayon).
static func inside(p: Vector2, pts: PackedVector2Array) -> bool:
	var c := false
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		if (a.y > p.y) != (b.y > p.y):
			if p.x < a.x + (p.y - a.y) / (b.y - a.y) * (b.x - a.x):
				c = not c
	return c


## Distance signée d'un point aux obstacles (négative à l'intérieur).
static func clearance(p: Vector2, obstacles: Array) -> float:
	var best := 1e9
	for poly in obstacles:
		var pts: PackedVector2Array = poly
		var d := 1e9
		for i in pts.size():
			d = minf(d, Geometry2D.get_closest_point_to_segment(p, pts[i], pts[(i + 1) % pts.size()]).distance_to(p))
		if inside(p, pts):
			d = -d
		best = minf(best, d)
	return best


## Poses d'un trajet tous les `step` u : [{c, fwd}] ; `reverse` : la poupe va devant ; `held_from` : abscisse à partir de
## laquelle le cap est tenu à `held` (dernier tronçon du recul, Layout.ship_path_back_in).
static func path_poses(path: Array, step: float, reverse: bool, held_from: float = INF, held := Vector2(0, -1)) -> Array:
	var out: Array = []
	for p in Layout.sample_path(path, step):
		out.append({"c": Vector2(p.x, p.z)})
	var acc := 0.0
	for i in out.size():
		if i > 0:
			acc += (out[i].c as Vector2).distance_to(out[i - 1].c)
		var a: Vector2 = out[maxi(0, i - 1)].c
		var b: Vector2 = out[mini(out.size() - 1, i + 1)].c
		var d := (b - a).normalized() if b.distance_to(a) > 0.001 else Vector2(0, -1)
		if reverse:
			d = -d
		if acc >= held_from - 0.01:
			d = held
		out[i]["fwd"] = d
	return out


## Poses du recul (comme ShipView : marche arrière, cap tenu au nord sur le dernier tronçon droit).
static func back_poses(path: Array) -> Array:
	var straight_from := Layout.path_length(path) - (path[-1] as Vector3).distance_to(path[-2])
	return path_poses(path, 1.0, true, straight_from)


static func min_clearance(poses: Array, size: Vector2, obstacles: Array) -> Dictionary:
	var best := {"d": 1e9, "c": Vector2.ZERO}
	for ps in poses:
		for q in hull_points(ps.c, ps.fwd, size):
			var d := clearance(q, obstacles)
			if d < float(best.d):
				best = {"d": d, "c": q}
	return best


## Navires amarrés aux autres postes de la darse du poste bi (obstacles de ses manœuvres).
static func moored_hulls(bi: int, built: Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var keys := ["quay1", "berth2", "berth3", "berth4"]
	for bj in 4:
		if bj == bi or Layout.berth_darse(bj) != Layout.berth_darse(bi) or not built.has(String(keys[bj])):
			continue
		var sz := ship_size(berth_class(bj, built))
		var p := Layout.berth_ship_pos(bj, sz.y, built)
		out.append(hull_poly(Vector2(p.x, p.z), Vector2(0, -1), sz))
	return out
