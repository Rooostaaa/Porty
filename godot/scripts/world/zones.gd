class_name Zones
extends RefCounted
## États des zones du plan (Layout.ZONES) et des cases de bâtiments (Layout.LOTS). Pure présentation :
## tout se déduit de sim.built, du palier et de l'ordre strict des bâtiments (PortSim.building_state), rien n'est sauvegardé.
## Une seule zone « prochaine » à la fois : celle dont le bâtiment clé est le premier bâtiment non construit de la liste.

const OPEN := "open"
const NEXT := "next"
const GRAY := "gray"


## La zone est-elle ouverte (en couleurs) ?
static func is_open(sim: PortSim, z: Dictionary) -> bool:
	var o := String(z.open)
	if o == "start":
		return true
	if o.begins_with("t") and o.length() == 2 and o.substr(1).is_valid_int():
		return sim.tier >= int(o.substr(1))
	if o == "customs1" and sim.g2 and sim.built.has("hut"):
		return true          # lot G2 : l'enceinte de la douane s'ouvre avec la cabane
	return sim.built.has(o)


## Cache (revue C7 D : appelé à chaque image par la surcouche) : premier bâtiment non construit et zone prochaine, recalculés
## quand la partie, le nombre de bâtiments ou le palier changent (achat, palier, nouvelle partie).
static var _ck_sim := 0
static var _ck_built := -1
static var _ck_tier := -1
static var _c_first := ""
static var _c_next_zone: Dictionary = {}
static var _c_next_ok := false


static func _cache(sim: PortSim) -> void:
	var id := sim.get_instance_id()
	if id == _ck_sim and sim.built.size() == _ck_built and sim.tier == _ck_tier:
		return
	_ck_sim = id
	_ck_built = sim.built.size()
	_ck_tier = sim.tier
	_c_next_ok = false
	_c_first = ""
	for b in sim.db.buildings:
		if not sim.built.has(String(b.id)):
			_c_first = String(b.id)
			break


## Premier bâtiment non construit dans l'ordre de la liste (le prochain achat de la chaîne), "" s'il n'y en a plus.
static func first_unbuilt(sim: PortSim) -> String:
	_cache(sim)
	return _c_first


## Prochain bâtiment achetable maintenant (palier atteint), "" sinon.
static func next_building(sim: PortSim) -> String:
	var bid := first_unbuilt(sim)
	if bid != "" and sim.building_state(bid) == "available":
		return bid
	return ""


static func state(sim: PortSim, z: Dictionary) -> String:
	if is_open(sim, z):
		return OPEN
	var k := String(z.get("key", ""))
	if k != "" and k == first_unbuilt(sim):
		return NEXT
	return GRAY


## Zone prochaine (au plus une), {} s'il n'y en a pas (le prochain achat est dans une zone déjà ouverte).
static func next_zone(sim: PortSim) -> Dictionary:
	_cache(sim)
	if not _c_next_ok:
		_c_next_ok = true
		_c_next_zone = {}
		for z in Layout.ZONES:
			if state(sim, z) == NEXT:
				_c_next_zone = z
				break
	return _c_next_zone


## L'empreinte d'un bâtiment futur est-elle dessinée ? Seulement dans une zone ouverte ou la zone prochaine (et jamais sur
## l'eau du futur terre-plein ni dans le chenal).
static func lot_shown(sim: PortSim, bid: String) -> bool:
	var z := zone_of(bid)
	if z.is_empty() or on_water(sim, z) or bool(z.get("water", false)):
		return false
	var st := state(sim, z)
	return st == OPEN or st == NEXT


static func zone_of(bid: String) -> Dictionary:
	if not Layout.LOTS.has(bid):
		return {}
	return Layout.zone_by_id(int(Layout.LOTS[bid].zone))


## Le terre-plein existe-t-il (la mer est devenue terre) ?
static func reclaimed(sim: PortSim) -> bool:
	return sim.built.has(Layout.RECLAIM_BUILDING)


## Une zone bâtie sur le terre-plein n'a pas encore de sol : on ne voit que son contour tracé sur l'eau.
static func on_water(sim: PortSim, z: Dictionary) -> bool:
	return bool(z.get("reclaim", false)) and not reclaimed(sim)


## Zone qui contient un point (x, z) du monde (décor apparu avec un palier), {} sinon.
static func zone_at(p: Vector3) -> Dictionary:
	for z in Layout.ZONES:
		var poly := Layout.zone_poly(z)
		if not poly.is_empty() and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), PackedVector2Array(poly)):
			return z
	return {}


## Zone à laquelle appartient un décor conditionné (bâtiment → sa case ; palier → la zone sous lui).
static func zone_for_cond(cond: String, p: Vector3) -> int:
	if Layout.LOTS.has(cond):
		return int(Layout.LOTS[cond].zone)
	if cond == "t2" or cond == "t3" or cond == Layout.RECLAIM_BUILDING:
		var z := zone_at(p)
		return int(z.get("id", 0))
	return 0


## Centre (x, z) d'une zone et largeur visible (zoom) qui la fait tenir dans un écran portrait sous le HUD.
## Repère écran de la caméra (35°, 45°) : « droite » = (x − z)/√2, « haut » au sol = −(x + z)/√2, vu raccourci par sin 35°.
static func focus(z: Dictionary) -> Dictionary:
	var poly := Layout.zone_poly(z)
	if poly.is_empty():
		return {"p": Vector3.ZERO, "zoom": 44.0}
	var r0 := INF
	var r1 := -INF
	var u0 := INF
	var u1 := -INF
	var c := Vector2.ZERO
	for p in poly:
		var v: Vector2 = p
		c += v
		var right := (v.x - v.y) / sqrt(2.0)
		var up := -(v.x + v.y) / sqrt(2.0)
		r0 = minf(r0, right)
		r1 = maxf(r1, right)
		u0 = minf(u0, up)
		u1 = maxf(u1, up)
	c /= float(poly.size())
	var s35 := sin(deg_to_rad(35.0))
	# largeur : 85 % de l'écran ; hauteur : 55 % de l'écran portrait (le HUD couvre le haut et le bas)
	var zoom := maxf((r1 - r0) / 0.85, (u1 - u0) * s35 / (0.55 * CameraRig.REF_H / CameraRig.REF_W))
	zoom = clampf(zoom + 6.0, 36.0, 120.0)
	# la zone est centrée un peu sous le milieu de l'écran (cartes du HUD en haut)
	var mid_r := (r0 + r1) * 0.5
	var mid_u := (u0 + u1) * 0.5 + 0.05 * zoom * CameraRig.REF_H / CameraRig.REF_W / s35
	var x := (mid_r - mid_u) / sqrt(2.0)
	var zz := (-mid_r - mid_u) / sqrt(2.0)
	return {"p": Vector3(x, 0, zz), "zoom": zoom, "center": Vector3(c.x, 0, c.y)}
