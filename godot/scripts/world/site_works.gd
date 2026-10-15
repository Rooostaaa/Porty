class_name SiteWorks
extends Node3D
## Lot F2 — chantiers visibles (F-D2) : présentation seule, la simulation a déjà appliqué l'achat.
## Un chantier par case achetée (ou par pièce de départ du T1, Layout.STARTER) : palissade ou échafaudage à l'empreinte,
## grue de chantier ou pelleteuse qui travaille, poussière, son ; à la fin, le bâtiment monte (léger dépassement d'échelle,
## Diorama) et l'état d'avant disparaît dans la poussière. Durée 3 à 6 s (Layout.site_spec), jamais accélérée, jamais passée ;
## plusieurs chantiers peuvent avancer en même temps. Rien n'est sauvegardé : une partie chargée ne rejoue aucun chantier.

signal risen(key: String)        # le bâtiment monte : le diorama fait surgir ses nœuds et efface l'état d'avant
signal finished(key: String)     # chantier fini : la case sert enfin (Diorama.ready_bid)

const RISE := 0.8                # s : dernière phase du chantier, le bâtiment monte
const OVERSHOOT := 1.08          # léger dépassement d'échelle pendant la montée
const PUFF_EVERY := 0.32         # s entre deux nuages de poussière
const SOUND_EVERY := 1.4         # s entre deux bruits de chantier
const DUST := Color(0.93, 0.88, 0.78)
const SPLASH := Color(0.86, 0.94, 1.0)
const SCAFFOLD_H := 6.0          # hauteur d'un échafaudage (u)

var sites: Dictionary = {}       # clé -> {key, t, dur, spec, props: Array[Node3D], machine, risen, puff, sound, seed}
var paused := false              # un écran couvre le monde : le chantier attend (aucune accélération ensuite)
var dust_fn: Callable            # Diorama._dust(pos, amount, col)
var started := 0                 # (tests) chantiers lancés
var done := 0                    # (tests) chantiers finis
var max_parallel := 0            # (tests) plus grand nombre de chantiers simultanés
var history: Array[Dictionary] = []   # (tests) {key, dur, t0, t1} des chantiers finis (durée réelle mesurée)
var _clock := 0.0


func active(key: String) -> bool:
	return key != "" and sites.has(key)


## Le chantier de la clé est-il en cours sans que le bâtiment ait encore monté ?
func hiding(key: String) -> bool:
	return active(key) and not bool(sites[key].risen)


func progress(key: String) -> float:
	if not sites.has(key):
		return 1.0
	var s: Dictionary = sites[key]
	return clampf(float(s.t) / maxf(0.01, float(s.dur)), 0.0, 1.0)


func any_active() -> bool:
	return not sites.is_empty()


## Lance le chantier `key` (spec : Layout.site_spec / Layout.STARTER). Sans effet s'il est déjà en cours.
func start(key: String, spec: Dictionary) -> void:
	if key == "" or sites.has(key) or spec.is_empty():
		return
	var s := {"key": key, "t": 0.0, "dur": float(spec.get("dur", 4.0)), "spec": spec, "props": [], "machine": null,
		"risen": false, "puff": 0.0, "sound": 0.0, "seed": absi(hash(key)) % 997, "t0": _clock}
	for rk in spec.get("rects", []):
		_enclosure(s, rk[0], String(rk[1]))
	var mname := String(spec.get("machine", ""))
	if mname != "" and Assets.exists(mname):
		var m := Assets.instance(mname)
		m.position = spec.get("machine_p", Vector3.ZERO)
		m.position.y += Layout.ground_y(Vector2(m.position.x, m.position.z))
		m.rotation.y = deg_to_rad(float(int(s.seed) % 4) * 90.0 + 20.0)
		add_child(m)
		s.machine = m
		(s.props as Array).append(m)
	sites[key] = s
	started += 1
	max_parallel = maxi(max_parallel, sites.size())
	Sfx.play("works", 0.3)


## Termine tout de suite (nouvelle partie, partie remplacée) : rien ne monte, les chantiers disparaissent.
func clear() -> void:
	for k in sites:
		for n in sites[k].props:
			if is_instance_valid(n):
				(n as Node).queue_free()
	sites.clear()


## Palissade (modules de 4 u sur le pourtour), échafaudage (étiré à l'empreinte), quai (palissade côté terre ; le reste
## est dans l'eau), « water » / « none » : rien (poussière ou éclaboussures seulement).
func _enclosure(s: Dictionary, r: Rect2, kind: String) -> void:
	match kind:
		"hoarding":
			_hoard_line(s, r.position, Vector2(r.end.x, r.position.y))
			_hoard_line(s, Vector2(r.position.x, r.end.y), r.end)
			_hoard_line(s, r.position, Vector2(r.position.x, r.end.y))
			_hoard_line(s, Vector2(r.end.x, r.position.y), r.end)
		"quay":
			_hoard_line(s, Vector2(r.position.x, r.end.y + 0.6), Vector2(r.end.x, r.end.y + 0.6))
		"scaffold":
			if not Assets.exists("scaffold"):
				return
			var sc := Assets.instance("scaffold")
			var c := r.get_center()
			sc.position = Vector3(c.x, Layout.ground_y(c), c.y)
			sc.scale = Vector3(maxf(r.size.x + 0.6, 2.0) / 4.245, SCAFFOLD_H / 4.08, maxf(r.size.y + 0.6, 2.0) / 4.245)
			add_child(sc)
			(s.props as Array).append(sc)


func _hoard_line(s: Dictionary, a: Vector2, b: Vector2) -> void:
	if not Assets.exists("site_hoarding"):
		return
	var l := a.distance_to(b)
	if l < 1.0:
		return
	var n := maxi(1, roundi(l / 4.0))
	var d := (b - a) / float(n)
	var ry := -atan2(b.y - a.y, b.x - a.x)
	for i in n:
		var c := a + d * (float(i) + 0.5)
		var h := Assets.instance("site_hoarding")
		h.position = Vector3(c.x, Layout.ground_y(c), c.y)
		h.rotation.y = ry
		h.scale = Vector3(d.length() / 4.0, 1.0, 1.0)
		add_child(h)
		(s.props as Array).append(h)


func _process(delta: float) -> void:
	if paused or sites.is_empty():
		return
	_clock += delta
	for k in sites.keys():
		var s: Dictionary = sites[k]
		s.t = float(s.t) + delta
		var t: float = s.t
		_animate(s, t)
		var spec: Dictionary = s.spec
		var rects: Array = spec.get("rects", [])
		# poussière (éclaboussures sur l'eau) au hasard dans l'emprise, jusqu'à la montée
		if not bool(s.risen) and t >= float(s.puff) and not rects.is_empty() and dust_fn.is_valid():
			s.puff = t + PUFF_EVERY
			var rk: Array = rects[int(t / PUFF_EVERY) % rects.size()]
			var r: Rect2 = rk[0]
			var wet := String(rk[1]) == "water" or String(rk[1]) == "quay"
			var p := Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))
			dust_fn.call(Vector3(p.x, Layout.WATER_Y + 0.6 if wet and not Layout.on_land(p, true) else Layout.ground_y(p), p.y), 12, SPLASH if wet else DUST)
		if t >= float(s.sound):
			s.sound = t + SOUND_EVERY
			Sfx.play("works", 0.6)
		if not bool(s.risen) and t >= float(s.dur) - RISE:
			s.risen = true
			_strike(s)
			risen.emit(String(k))
		if t >= float(s.dur):
			for n in s.props:
				if is_instance_valid(n):
					(n as Node).queue_free()
			sites.erase(k)
			done += 1
			history.append({"key": String(k), "dur": float(s.dur), "t0": float(s.t0), "t1": _clock})
			finished.emit(String(k))


## Engins : la pelleteuse tourne sa tourelle, lève la flèche, ouvre le bras ; la grue de chantier fait tourner sa flèche et
## glisser son chariot.
func _animate(s: Dictionary, t: float) -> void:
	var m_v: Variant = s.machine
	if m_v == null or not is_instance_valid(m_v):
		return
	var m: Node3D = m_v
	var ph := float(s.seed) * 0.37
	var turret := Assets.part(m, "turret")
	if turret != null:
		turret.rotation.y = 0.9 * sin(t * 1.25 + ph)
		var boom := Assets.part(m, "boom")
		if boom != null:
			boom.rotation.z = deg_to_rad(-5.0 + 20.0 * sin(t * 2.2 + ph))
		var arm := Assets.part(m, "arm")
		if arm != null:
			arm.rotation.z = deg_to_rad(15.0 + 30.0 * sin(t * 2.2 + ph + 1.1))
	var jib := Assets.part(m, "jib")
	if jib != null:
		jib.rotation.y = ph + t * 0.55
		var hook := Assets.part(m, "hook")
		if hook != null:
			hook.position.x = 5.0 + 3.4 * sin(t * 0.9 + ph)


## Fin des travaux : palissades, échafaudages et engins disparaissent (ils rétrécissent), un grand nuage de poussière.
func _strike(s: Dictionary) -> void:
	for n in s.props:
		if is_instance_valid(n):
			var nd: Node3D = n
			nd.create_tween().tween_property(nd, "scale", nd.scale * Vector3(1.0, 0.02, 1.0), RISE * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if dust_fn.is_valid():
		for rk in (s.spec as Dictionary).get("rects", []):
			var r: Rect2 = rk[0]
			var c := r.get_center()
			dust_fn.call(Vector3(c.x, Layout.ground_y(c), c.y), 26, DUST)
	Sfx.play("build", 0.2)
