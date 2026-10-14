class_name ShipRules
extends RefCounted
## Règles de passage des navires à l'écran (présentation seule, lot E-Flux E9 ; sans autoload : testées dans run_all).
## Le diorama (Diorama._hold_ships) retient la vue d'un navire — elle attend sur son trajet, la simulation continue — quand :
## il rattrape un navire qui va dans le même sens (distance de suivi, revue N10) ; la bande qu'il va balayer devant son
## étrave (sur son propre trajet) touche la coque d'un navire qui coupe sa route (`sweep_hits`) ; il va entrer dans un
## croisement balisé où passe un navire de l'autre courant (`crossing_holds`). Cas symétriques : celui qui était déjà retenu
## continue de céder, sinon le plus grand identifiant ; une vue retenue plus de HOLD_MAX s passe pendant HOLD_FORCE s (jamais
## d'interblocage).

const HOLD_MAX := 12.0
const HOLD_FORCE := 3.0
## Points du trajet devant le navire (u) qui annoncent son entrée dans une fenêtre de croisement : il s'arrête assez tôt pour
## que l'étrave d'un navire qui en sort en biais (poupe encore sur sa première branche) ne touche pas sa coque.
const AHEAD := [8.0, 16.0, 24.0, 32.0, 40.0, 48.0, 56.0]
## Coque d'un navire : points de son trajet sous la coque (l'étrave et la poupe sont posées sur le trajet, ShipView._chord_yaw),
## tous les HULL_STEP u ; bande balayée : SWEEP u devant l'étrave. Deux coques doivent garder SWEEP_SIDE u (+ marge des coins).
const HULL_STEP := 2.5
const SWEEP := 24.0
const SWEEP_SIDE := 2.2
## Caps à moins de ≈ 30° : même sens, c'est la distance de suivi qui s'applique (pas la bande balayée).
const SAME_DIR := 0.85
## Repli sans trajet (anciens appels) : couloir devant l'étrave.
const CUT_GAP := 6.0
const CUT_SIDE := 2.0


## Courant d'un navire au croisement balisé du large (Layout.SHIP_CROSSINGS) : « ew » voie au large (arrivée au mouillage,
## pilotage vers les postes 3–4, départ furieux), « ns » chenal ouest (pilotage vers les postes 1–2, départ des postes 1–2).
static func ship_stream(state: int, berth: int) -> String:
	match state:
		Ship.State.ARRIVING, Ship.State.LEAVING:
			return "ew"
		Ship.State.PILOTING, Ship.State.MOORING:
			return "ew" if berth >= Layout.EAST_BERTH0 else "ns"
		Ship.State.DEPARTING:
			return "ns" if berth >= 0 and berth < Layout.EAST_BERTH0 else ""
	return ""


## Points d'une polyligne (x, z) entre les abscisses s0 et s1, tous les `step` u ; au-delà des bouts, dans le prolongement du
## premier ou du dernier segment — ou, avant le début, selon `back` (cap du navire au départ : la poupe d'un navire à quai).
static func path_points(path: Array, s0: float, s1: float, step: float, back := Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	if path.size() < 2:
		if path.size() == 1:
			out.append(Vector2((path[0] as Vector3).x, (path[0] as Vector3).z))
		return out
	var cum: Array[float] = [0.0]
	for i in path.size() - 1:
		cum.append(cum[-1] + (path[i] as Vector3).distance_to(path[i + 1]))
	var total: float = cum[-1]
	var s := s0
	var seg := 0
	while s <= s1 + 0.001:
		var a: Vector3
		var b: Vector3
		var t: float
		if s < 0.0 and back != Vector2.ZERO:
			var p0: Vector3 = path[0]
			out.append(Vector2(p0.x, p0.z) + back * s)
			s += step
			continue
		if s < 0.0:
			a = path[0]
			b = path[1]
			t = s / maxf(0.01, a.distance_to(b))
		elif s > total:
			a = path[-2]
			b = path[-1]
			t = 1.0 + (s - total) / maxf(0.01, a.distance_to(b))
		else:
			while seg < path.size() - 2 and cum[seg + 1] < s:
				seg += 1
			a = path[seg]
			b = path[seg + 1]
			t = (s - cum[seg]) / maxf(0.0001, cum[seg + 1] - cum[seg])
		var q := a.lerp(b, t)
		out.append(Vector2(q.x, q.z))
		s += step
	return out


## Coque (points sous la coque) et bande balayée devant l'étrave d'un navire d'abscisse s et de longueur len sur son trajet ;
## yaw0 : cap au début du trajet (la poupe qui n'y est pas encore est dans son prolongement).
static func hull_and_sweep(path: Array, s: float, len: float, yaw0: float = NAN) -> Array:
	var hl := len * 0.5
	var back := Vector2.ZERO if is_nan(yaw0) else Vector2(cos(yaw0), -sin(yaw0))
	return [path_points(path, s - hl, s + hl, HULL_STEP, back), path_points(path, s + hl + 1.0, s + hl + SWEEP, HULL_STEP)]


## Navires qui doivent attendre parmi `items` [{id, p, dir, len, w, stream, ahead, body, sweep, was_held}] : {id: true} —
## distance de suivi, bande balayée qui touche la coque d'un navire qui coupe la route, croisement balisé. Cas symétrique
## (chacun suit l'autre, ou chacun touche l'autre) : celui qui était déjà retenu cède encore (l'autre est engagé), sinon le
## plus grand identifiant (revue C7 A1 : plus de blocage mutuel).
static func holds(items: Array) -> Dictionary:
	var held := {}
	var win := windows(items)
	var gov := governed(win)
	for a in items:
		for b in items:
			if a == b:
				continue
			if gov.has("%d|%d" % [int(a.id), int(b.id)]):
				continue          # réglés par une fenêtre de croisement (courants différents : ni suivi, ni bande balayée)
			var f := follows(a.p, a.dir, a.len, b.p, b.dir, b.len)
			if not f and not conflict(a, b):
				continue
			var back := follows(b.p, b.dir, b.len, a.p, a.dir, a.len) or conflict(b, a)
			if back:
				var ha := bool(a.get("was_held", false))
				var hb := bool(b.get("was_held", false))
				if hb and not ha:
					continue          # b attendait déjà : a est engagé, il continue
				if ha == hb and int(a.id) < int(b.id):
					continue
			held[a.id] = true
			break
	held.merge(crossing_holds(items, win))
	return held


## A doit-il céder à B, qui coupe sa route ? Bande balayée devant l'étrave de A contre la coque de B (même sens : non, c'est la
## distance de suivi) ; sans trajet, repli sur le couloir devant l'étrave (`cuts_ahead`).
static func conflict(a: Dictionary, b: Dictionary) -> bool:
	if not a.has("sweep") or not b.has("body"):
		return cuts_ahead(a, b)
	if (a.dir as Vector2).dot(b.dir) > SAME_DIR:
		return false
	return sweep_hits(a.sweep, b.body, (float(a.get("w", 8.0)) + float(b.get("w", 8.0))) * 0.5 + SWEEP_SIDE)


static func sweep_hits(sweep: PackedVector2Array, body: PackedVector2Array, dmin: float) -> bool:
	var d2 := dmin * dmin
	for p in sweep:
		for q in body:
			if p.distance_squared_to(q) < d2:
				return true
	return false


## Le navire B (coque orientée) est-il dans le couloir que le navire A va balayer devant lui (demi-longueur + CUT_GAP devant
## l'étrave, demi-largeurs + CUT_SIDE sur le côté) ? (Repli des appels sans trajet.)
static func cuts_ahead(a: Dictionary, b: Dictionary) -> bool:
	var da: Vector2 = a.dir
	var db: Vector2 = b.dir
	var rel: Vector2 = (b.p as Vector2) - (a.p as Vector2)
	var fwd := rel.dot(da)
	if fwd <= 0.0:
		return false
	var nrm := Vector2(-da.y, da.x)
	var co := absf(db.dot(da))
	var si := absf(db.dot(nrm))
	var hl := float(b.len) * 0.5
	var hw := float(b.get("w", 8.0)) * 0.5
	return fwd < float(a.len) * 0.5 + hl * co + hw * si + CUT_GAP \
		and absf(rel.dot(nrm)) < float(a.get("w", 8.0)) * 0.5 + hl * si + hw * co + CUT_SIDE


## Croisement balisé (Layout.SHIP_CROSSINGS) : un navire qui va entrer dans la fenêtre (un de ses points « ahead » y est) attend
## qu'aucun navire de l'autre courant n'y soit ; deux navires qui y arrivent ensemble : le plus petit identifiant passe.
## Fenêtres de croisement (Layout.SHIP_CROSSINGS) : pour chacune, les navires de l'un des deux courants qui y sont, ou qui
## vont y entrer (un de leurs points « ahead » y est). {id de fenêtre: [dedans, arrivants]}.
static func windows(items: Array) -> Dictionary:
	var out := {}
	for w in Layout.SHIP_CROSSINGS:
		var r: Rect2 = w.rect
		var inside: Array = []
		var coming: Array = []
		for it in items:
			if _stream_in(it, String(w.id)) == "":
				continue
			if r.has_point(it.p):
				inside.append(it)
				continue
			for q in it.get("ahead", []):
				if r.has_point(q):
					coming.append(it)
					break
		out[String(w.id)] = [inside, coming]
	return out


## Courant d'un navire pour une fenêtre (« streams » {fenêtre: courant} ; à défaut « stream », celui du large).
static func _stream_in(it: Dictionary, wid: String) -> String:
	if it.has("streams"):
		return String((it.streams as Dictionary).get(wid, ""))
	return String(it.get("stream", "")) if wid == "large" else ""


## Courants d'un navire pour chaque fenêtre : le large (voir ship_stream), le bassin ouest et le bassin est (« in » : pilotage
## et accostage vers un poste de ce bassin ; « out » : départ d'un poste de ce bassin).
static func ship_streams(state: int, berth: int) -> Dictionary:
	var west := berth >= 0 and berth < Layout.EAST_BERTH0
	var east := berth >= Layout.EAST_BERTH0
	var arr := state == Ship.State.PILOTING or state == Ship.State.MOORING
	var dep := state == Ship.State.DEPARTING
	return {"large": ship_stream(state, berth),
		"ouest": ("in" if arr else ("out" if dep else "")) if west else "",
		"chenal": ("in" if arr else ("out" if dep else "")) if west else "",
		"est": ("in" if arr else ("out" if dep else "")) if east else ""}


## Croisements (Layout.SHIP_CROSSINGS) : un navire qui va entrer dans une fenêtre attend qu'aucun navire de l'autre courant
## n'y soit ; deux navires qui y arrivent ensemble : le plus petit identifiant passe. `win` : résultat de `windows`.
static func crossing_holds(items: Array, win: Dictionary = {}) -> Dictionary:
	if win.is_empty():
		win = windows(items)
	# qui attend qui (c attend o) ; deux navires qui s'attendent l'un l'autre par deux fenêtres voisines (chacun est dans la
	# fenêtre où l'autre va entrer) : le plus petit identifiant passe
	var waits := {}
	for wid in win:
		var inside: Array = win[wid][0]
		var coming: Array = win[wid][1]
		for c in coming:
			for o in inside + coming:
				if o == c or _stream_in(o, wid) == _stream_in(c, wid):
					continue
				if inside.has(o) or int(o.id) < int(c.id):
					waits["%d|%d" % [int(c.id), int(o.id)]] = [int(c.id), int(o.id)]
	var held := {}
	for k in waits:
		var c_id: int = waits[k][0]
		var o_id: int = waits[k][1]
		if waits.has("%d|%d" % [o_id, c_id]) and c_id < o_id:
			continue
		held[c_id] = true
	return held


## Paires de navires réglées par une fenêtre (tous deux dedans ou y arrivant, courants différents) : la bande balayée ne
## s'applique pas entre eux (la règle de la fenêtre décide, sans aller-retour).
static func governed(win: Dictionary) -> Dictionary:
	var out := {}
	for wid in win:
		var all: Array = (win[wid][0] as Array) + (win[wid][1] as Array)
		for a in all:
			for b in all:
				if a != b and _stream_in(a, wid) != _stream_in(b, wid):
					out["%d|%d" % [int(a.id), int(b.id)]] = true
	return out


## Le navire A (position, cap unitaire, longueur) rattrape-t-il B, qui va dans le même sens juste devant lui ?
static func follows(pa: Vector2, da: Vector2, la: float, pb: Vector2, db: Vector2, lb: float) -> bool:
	var rel := pb - pa
	return rel.dot(da) > 0.0 and da.dot(db) > 0.5 and rel.length() < (la + lb) * 0.5 + Layout.SHIP_FOLLOW_GAP
