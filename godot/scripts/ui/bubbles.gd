class_name Bubbles
extends RefCounted
## Géométrie des bulles de la surcouche monde, sans dépendance à l'interface (testable en --script) :
## point d'ancrage au-dessus d'un modèle (anchor_y) et décalage latéral anti-chevauchement.

const GAP := 6.0            # écart entre deux bulles décalées


## Point d'ancrage d'une bulle au-dessus d'un modèle posé en `base` : hauteur `anchor_y` du modèle
## (assets_meta.json, sinon sommet de la boîte englobante + 0,4).
static func anchor_point(model: String, base: Vector3) -> Vector3:
	return Vector3(base.x, base.y + Assets.anchor_y(model), base.z)


## Décale `r` pour qu'il ne chevauche aucun rectangle déjà placé : la position libre la plus proche à côté d'une bulle
## (à droite ou à gauche, même hauteur), sinon au-dessus (jamais au-dessous : elle couvrirait ce qu'elle désigne) ; à défaut, décalages successifs (au plus 8).
## Lot D-UI : avec deux voisines, l'ancien décalage pouvait osciller entre elles et finir par-dessus l'une (« Touche ! » sous
## « Tablier plein », « +2,9 $ » sur « File : 0 »).
static func settle(r: Rect2, placed: Array) -> Rect2:
	if not _hits(r, placed):
		return r
	var best := Rect2()
	var best_d := INF
	for q in placed:
		var qr: Rect2 = q
		for x in [qr.end.x + GAP, qr.position.x - r.size.x - GAP]:
			var c := Rect2(Vector2(x, r.position.y), r.size)
			var d := absf(x - r.position.x)
			if d < best_d and not _hits(c, placed):
				best = c
				best_d = d
	if best_d < INF:
		return best
	for q in placed:
		var qr2: Rect2 = q
		# vers le haut seulement : une bulle posée au-dessus de son ancrage ne descend jamais sur ce qu'elle désigne
		for y in [qr2.position.y - r.size.y - GAP]:
			if y > r.position.y:
				continue
			var c2 := Rect2(Vector2(r.position.x, y), r.size)
			var d2 := absf(y - r.position.y) * 1.5
			if d2 < best_d and not _hits(c2, placed):
				best = c2
				best_d = d2
	if best_d < INF:
		return best
	return _settle_steps(r, placed)


static func _hits(r: Rect2, placed: Array) -> bool:
	for q in placed:
		if r.intersects(q as Rect2):
			return true
	return false


static func _settle_steps(r: Rect2, placed: Array) -> Rect2:
	for _i in 8:
		var hit := Rect2()
		var found := false
		for q in placed:
			if r.intersects(q as Rect2):
				hit = q
				found = true
				break
		if not found:
			return r
		var right := hit.end.x + GAP
		var left := hit.position.x - r.size.x - GAP
		if absf(right - r.position.x) <= absf(r.position.x - left):
			r.position.x = right
		else:
			r.position.x = left
	return r


## Rectangle utile de la surcouche : sous les cartes du haut, au-dessus des boutons du bas, dans l'écran (revue du 13/10 :
## aucune bulle sur le HUD ni coupée par le bord). Une bulle dont l'ancrage sort de ce rectangle (plus d'une demi-bulle)
## n'est pas dessinée ; sinon elle est ramenée dedans.
static func bound(r: Rect2, useful: Rect2) -> Rect2:
	if not useful.has_area():
		return r
	var c := r.get_center()
	if c.x < useful.position.x - r.size.x * 0.5 or c.x > useful.end.x + r.size.x * 0.5 \
			or c.y < useful.position.y - r.size.y * 0.5 or c.y > useful.end.y + r.size.y * 0.5:
		return Rect2()
	r.position.x = clampf(r.position.x, useful.position.x, maxf(useful.position.x, useful.end.x - r.size.x))
	r.position.y = clampf(r.position.y, useful.position.y, maxf(useful.position.y, useful.end.y - r.size.y))
	return r
