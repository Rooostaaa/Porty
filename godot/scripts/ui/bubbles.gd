class_name Bubbles
extends RefCounted
## Géométrie des bulles de la surcouche monde, sans dépendance à l'interface (testable en --script) :
## point d'ancrage au-dessus d'un modèle (anchor_y) et décalage latéral anti-chevauchement.

const GAP := 6.0            # écart entre deux bulles décalées


## Point d'ancrage d'une bulle au-dessus d'un modèle posé en `base` : hauteur `anchor_y` du modèle
## (assets_meta.json, sinon sommet de la boîte englobante + 0,4).
static func anchor_point(model: String, base: Vector3) -> Vector3:
	return Vector3(base.x, base.y + Assets.anchor_y(model), base.z)


## Décale `r` latéralement tant qu'il chevauche un rectangle déjà placé (vers le côté le plus proche de la sortie),
## pour qu'aucune bulle n'en couvre une autre. Au plus 8 décalages.
static func settle(r: Rect2, placed: Array) -> Rect2:
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
