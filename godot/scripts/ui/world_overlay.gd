class_name WorldOverlay
extends Control
## Surcouche 2D au-dessus du diorama : la file et l'attente se lisent au premier coup d'œil
## (file + barre + humeur), plus les gains qui s'envolent.
## Lot B : chaque bulle de bâtiment est ancrée à `anchor_y` (assets_meta.json, sinon sommet de la boîte englobante + 0,4)
## et posée *au-dessus* de ce point ; deux bulles qui se chevauchent sont décalées latéralement (`Bubbles.settle`).

const OFFER_NAMES := {"berths": "Léon", "customs": "Paul", "gate": "Tonio"}      # lot G2 : bulle du responsable qui se présente
const MOOD_COL := [Color("#38B76A"), Color("#FFB020"), Color("#EB4D4B")]
const PILL_H := 58.0        # texte des bulles et pancartes : 30 px sur 1080 (≈ 15 px sur un écran de 540, revue du 13/10)
const GAP := 6.0            # écart entre le point d'ancrage et le bas de la bulle, et entre deux bulles décalées

var diorama: Diorama
var popups: Array[Dictionary] = []      # {p: Vector3, text, t, col}
var _t := 0.0
var obstacles: Array[Rect2] = []        # lot G2 (revue) : contrôles du HUD posés sur le monde (bouton Heures sup)
var _placed: Array[Rect2] = []          # rectangles déjà dessinés dans l'image courante (anti-chevauchement)
var last_rects: Dictionary = {}         # clé -> Rect2 de la dernière bulle dessinée (tests)
var frame_rects: Dictionary = {}        # idem, pour l'image courante seulement (tests : tout ce qui vient d'être dessiné)
var useful := Rect2()                   # rectangle utile de l'écran (sous le HUD du haut, au-dessus des boutons du bas)
var zone_info: Dictionary = {}          # bulle d'information d'une zone grise touchée : {p, text, t} (2 s)
var popups_added := 0                   # gains ajoutés depuis le lancement (tests)
## Boîtes de style réutilisées d'une bulle à l'autre (`draw_style_box` dessine tout de suite : on peut les modifier ensuite).
var _sb_pill := StyleBoxFlat.new()
var _sb_bar := StyleBoxFlat.new()
const ZONE_INFO_TIME := 2.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# toute la surcouche (bulles, minuteries, gains, pastilles) est découpée au rectangle utile : rien sur le HUD ni hors
	# de l'écran (revue N4) ; la position et la taille suivent Hud.useful_rect, on dessine en coordonnées écran
	clip_contents = true


## Gain qui s'envole au-dessus d'un point du monde. `big` : encaissement d'un navire, retour d'achat, geste (texte plus gros,
## plus long à l'écran).
func add_popup(p: Vector3, text: String, col: Color = UI.MONEY, big: bool = false) -> void:
	if popups.size() > 14:
		popups.pop_front()
	popups.append({"p": p, "text": text, "t": 0.0, "col": col, "big": big})
	popups_added += 1


func _process(delta: float) -> void:
	_t += delta
	if Hud.main != null:
		useful = Hud.main.useful_rect()
		position = useful.position
		size = useful.size
		# lot G2 (revue) : le bouton rond Heures sup flotte dans le rectangle utile — les bulles l'évitent
		obstacles.clear()
		var bb: Control = Hud.main.boost_btn
		if bb != null and bb.is_visible_in_tree():
			obstacles.append(bb.get_global_rect().grow(4.0))
	for p in popups:
		p.t += delta
	popups = popups.filter(func(p: Dictionary) -> bool: return p.t < (2.4 if bool(p.get("big", false)) else 1.6))
	if not zone_info.is_empty():
		zone_info.t = float(zone_info.t) + delta
	queue_redraw()


func _sp(p: Vector3) -> Vector2:
	return diorama.to_screen(p)


## Ancrage et anti-chevauchement : voir Bubbles (classe pure, testée dans run_all).
static func anchor_point(model: String, base: Vector3) -> Vector3:
	return Bubbles.anchor_point(model, base)


func _draw() -> void:
	if diorama == null or diorama.sim == null:
		return
	var sim := diorama.sim
	_placed.clear()
	_placed.append_array(obstacles)
	frame_rects.clear()
	# rien n'est dessiné sous les cartes du haut (conseil, aléa, bandeau des missions) : un navire caché derrière reste caché
	if Hud.main == null:
		useful = Rect2()
	draw_set_transform(-position)       # coordonnées écran (le contrôle est posé sur le rectangle utile)
	var top_y := useful.position.y if useful.has_area() else 0.0
	# lot F3/G1 : pendant la Crique (bascule comprise), le port à conteneurs est fermé : seules les bulles de loyer de la pêche et
	# les gains s'affichent ; après, les bulles de loyer restent (tant que Marcel n'est pas là)
	if sim.fishing.act0:
		_draw_fishing(top_y)
		_draw_lock()
		_draw_popups()
		return
	_draw_fishing(top_y)
	# navires (lot F1) : en rade, la bulle d'humeur de l'escale liée ; à quai, le déchargement du navire à l'écran ; furieux
	for s in sim.ships:
		if s.state != Ship.State.ANCHORED and s.state != Ship.State.ARRIVING:
			continue
		var v: ShipView = diorama.ship_views.get(s.id)
		if v == null or not is_instance_valid(v):
			continue
		var sp := _sp(v.bubble_point())
		if sp.y < top_y or (useful.has_area() and not useful.grow(10.0).has_point(sp)):
			continue
		_mood_bubble(sp, s.patience_ratio(), s.mood(), s.priority)
	for mv in diorama.moored_views():
		var sp2 := _sp(mv.bubble_point())
		if sp2.y < top_y or (useful.has_area() and not useful.grow(10.0).has_point(sp2)):
			continue
		var prog := mv.progress()
		_ring(sp2, 30.0, prog, UI.INFO, Color.WHITE)
		_text_c(sp2 + Vector2(0, 11), "…" if mv.in_formalities() else "%d%%" % roundi(prog * 100.0), 26, UI.TEXT)
		if mv.in_formalities():
			_pill(sp2 + Vector2(0, -60), "Formalités", Color("#4B3FB5"), "customs")
	for pv in diorama.parting:
		if is_instance_valid(pv) and pv.angry:
			var sp3 := _sp(pv.bubble_point())
			if sp3.y >= top_y and (not useful.has_area() or useful.grow(10.0).has_point(sp3)):
				_pill(sp3 + Vector2(0, -10), "Furieux !", UI.BAD, "")
	# gestes manuels disponibles : « Touche ! » sur le prochain navire à accoster (lot G2 : jusqu'à Léon)
	if not sim.managers.harbor and not (sim.g2 and sim.managers.berths):
		for s in sim.ships:
			if s.state == Ship.State.ANCHORED and not s.priority:
				var v: ShipView = diorama.ship_views.get(s.id)
				if v != null and _sp(v.bubble_point()).y - 62.0 > top_y:
					_pill(_sp(v.bubble_point()) + Vector2(0, -62), "Touche pour accoster", UI.AMBER, "", UI.TEXT, true, "berth_gesture")
				break
	# lot G2 — tamponner (la cabane), laisser passer et encaisser (la barrière : rouge avant que le camion reparte), et la
	# plateforme pleine (« il faut une sortie »)
	if sim.stamp_ready() and diorama.ready_bid("hut"):
		var hp := _sp(anchor_point("customs_hut", Layout.CUSTOMS_HUT))
		if hp.y > top_y + 30.0:
			_pill_above(hp, "À tamponner : %d" % roundi(sim.pending_total()), UI.AMBER, "customs", UI.TEXT, "stamp_gesture")
	if sim.pass_ready() and diorama.ready_bid("track"):
		var bp2 := _sp(Layout.GATE + Vector3(-1.0, 3.0, 2.0))
		var left := sim.truck_wait_left()
		var late := left < float(sim.db.cfg("manual").get("truck_warn", 6.0))
		if bp2.y > top_y + 30.0:
			_pill_above(bp2, ("Camion : touche la barrière · %d s" % ceili(left)) if late else "Camion : touche la barrière", UI.BAD if late else UI.AMBER, "gate", Color.WHITE if late else UI.TEXT, "gate_gesture")
	# lot G2 — un responsable des gestes s'est présenté (après 5 gestes) : une bulle à son poste tant qu'il n'est pas embauché
	if sim.g2:
		for d in PortSim.OFFER_ORDER:
			if sim.mgr_offered.has(d) and not sim.managers[d]:
				var op := _sp(Layout.manager_pos(d, sim.tier) + Vector3(0, 3.5, 0))
				if op.y > top_y + 30.0:
					_pill_above(op, "%s se présente" % String(OFFER_NAMES.get(d, "")), UI.MONEY, "people", Color.WHITE, "offer_" + d)
	if sim.g2 and String(sim.shown_analysis().get("alert", "")) == "exit":
		var ep := _sp(Layout.YARD_CENTER + Vector3(0, 6, 0))
		if ep.y > top_y + 30.0:
			_pill_above(ep, "Il faut une sortie !", UI.BAD, "gate", Color.WHITE, "exit")
	# file en rade
	var waiting := sim.waiting_ships()
	var col := UI.INFO if waiting < sim.rade_places() else UI.BAD      # rouge seulement quand la rade est pleine
	# l'étiquette suit la rade, mais reste lisible : jamais sous les cartes du haut ni coupée par le bord de l'écran
	# ancrée au mouillage lui-même (D-Monde : `rade_anchor`, centre des navires en rade), plus sur le phare ou dans les terres
	var ra: Vector3 = diorama.call("rade_anchor") if diorama.has_method("rade_anchor") else Layout.anchor_pos(0) + Vector3(0, 4, 0)
	var rp := _sp(ra + Vector3(0, 6, 0))
	var vw := get_viewport_rect().size.x
	if useful.has_area():
		rp = rp.clamp(useful.position + Vector2(110, 30), useful.end - Vector2(110, 30))
	# (lot G2 : la file en rade est le métier des Arrivées, qui n'apparaissent qu'avec le quai n°2)
	if not sim.g2 or sim.feature("dept_harbor"):
		_pill(rp, "%d/%d en rade" % [waiting, sim.rade_places()], col, "ship", Color.WHITE, true, "rade")
	# douane : au-dessus du toit du bureau (anchor_y), jamais sur la table d'inspection
	var pend := sim.pending_total()
	if sim.feature("dept_customs") and (pend >= 1.0 or sim.shown_analysis().get("dept", "") == "customs"):
		var bad: bool = sim.shown_analysis().get("dept", "") == "customs"
		_pill_above(_sp(anchor_point("customs_hut", Layout.CUSTOMS_HUT)), "À inspecter : %s" % Fmt.num(pend), UI.BAD if bad else UI.INFO, "customs", Color.WHITE, "customs")
	# dézoom fort : parc et gate sont proches à l'écran, on n'affiche que ce qui pose problème
	var far := diorama.rig != null and diorama.rig.zoom > 110.0
	var dept: String = sim.shown_analysis().get("dept", "")
	# parc : jauge de remplissage
	var fill := sim.yard_fill()
	# bulles d'un service seulement une fois son chapitre ouvert (revue du 13/10)
	var small_yard: bool = sim.shown_analysis().get("key", "") == "yard_space"
	if sim.feature("dept_yard_ops") and (not far or dept == "yard_ops" or fill > 0.65):
		_gauge(_sp(Layout.YARD_CENTER + Vector3(0, 9, 0)), fill, small_yard)
	# gate : au-dessus de la guérite (ou de la barrière avant elle), au-dessus des camions en file
	var tw := sim.trucks_waiting()
	var honk := sim.trucks_honking() > 0
	if sim.feature("dept_gate") and (not far or honk or dept == "gate"):
		var gm := "gate_booth" if sim.built.has("gate2") else "barrier"
		var gbase: Vector3 = Layout.LOTS.gate2.p if sim.built.has("gate2") else Layout.GATE
		var gpos := _sp(gbase + Vector3(0, maxf(Assets.anchor_y(gm), 3.6), 0))
		# ancrée sur la guérite (ou la barrière) : la bulle reste au-dessus d'elle, bornée au rectangle utile (revue N15)
		var gr := _pill_above(gpos, "File : %d" % tw, UI.BAD if honk else UI.INFO, "horn" if honk else "truck", Color.WHITE, "gate")
		if honk and fmod(_t, 0.6) < 0.3:
			_text_c(gr.get_center() + Vector2(70, -46), "Tuut !", 30, UI.BAD)
	# aire d'attente : places occupées / places disponibles
	if sim.parking_slots > 0 and sim.feature("dept_gate") and (not far or honk or dept == "gate"):
		var in_lot := clampi(tw - TrafficView.ROAD_SLOTS, 0, sim.parking_slots)
		var full := in_lot >= sim.parking_slots
		_pill(_sp(PARKING_PILL), "Aire d'attente %d/%d" % [in_lot, sim.parking_slots], UI.BAD if full else UI.INFO, "truck")
	# tablier : alerte dessinée après la jauge du parc, qu'elle chevauche en dézoom
	var af := sim.apron_stock() / maxf(1.0, sim.apron_capacity())
	if af > 0.92:
		_pill(_sp(Vector3(-18, 3, 1)), "Tablier plein", UI.BAD, "yard")
	# pancarte du prochain achat : sur la pancarte de la zone prochaine, ou au-dessus de l'empreinte dans sa case ;
	# elle rebondit quand l'achat devient abordable (même signal que la pastille d'achats abordables)
	_draw_next_sign(sim, top_y)
	# une icône par zone à venir (sur son emplacement de pancarte) : on reconnaît ce qui viendra sans lire de texte
	if not diorama.opening_active():
		for z in Layout.ZONES:
			if Zones.state(sim, z) != Zones.GRAY:
				continue
			var zp := _sp((z.sign as Vector3) + Vector3(0, 1.5, 0))
			if useful.size.x > 80.0 and useful.size.y > 80.0 and useful.grow(-30.0).has_point(zp):
				draw_circle(zp + Vector2(0, 3), 30.0, Color(0, 0, 0, 0.12))
				draw_circle(zp, 30.0, Color(1, 1, 1, 0.88))
				draw_texture_rect(UI.icon_tex(String(z.get("icon", "info"))), Rect2(zp - Vector2(19, 19), Vector2(38, 38)), false, UI.MUTED)
				last_rects["zone_icon_%d" % int(z.id)] = Rect2(zp - Vector2(30, 30), Vector2(60, 60))
				frame_rects["zone_icon_%d" % int(z.id)] = Rect2(zp - Vector2(30, 30), Vector2(60, 60))
	# bulle d'information d'une zone grise touchée (2 s), au lieu d'une fenêtre
	if not zone_info.is_empty():
		if float(zone_info.t) > ZONE_INFO_TIME:
			zone_info = {}
		else:
			_pill_above(_sp(zone_info.p), String(zone_info.text), Color(1, 1, 1, 0.96), "lock", UI.TEXT, "zone_info")
	# numéros des bouées du mouillage (vue rapprochée seulement)
	if diorama.rig != null and diorama.rig.zoom < 70.0:
		for k in sim.rade_places():
			var bp := _sp(Diorama.anchor_buoy(k) + Vector3(0, 3.6, 0))
			if bp.y > top_y + 20.0:
				draw_circle(bp, 15.0, Color(1, 1, 1, 0.9))
				_text_c(bp + Vector2(0, 9), str(k + 1), 24, UI.TEXT)
	_draw_popups()


## Lot G1 : bulle « Loyer » (pièce) sur chaque bateau rentré dont le loyer attend ; elle passe au rouge quand il va repartir
## sans payer (`rent_warn` s). Plus aucune bulle avec Marcel.
func _draw_fishing(top_y: float) -> void:
	var fv: FishingView = diorama.fishing_view
	var sim := diorama.sim
	var warn := float(sim.fishing.cfg.get("rent_warn", 6.0))
	for i in fv.collectable():
		var sp := _sp(fv.boat_pos(i) + Vector3(0, 2.5, 0))
		if sp.y > top_y + 30.0 and (not useful.has_area() or useful.grow(10.0).has_point(sp)):
			var left := sim.fishing.wait_left(i)
			var late := left < warn
			var txt := "Loyer %s" % Fmt.money(float(sim.fishing.boats[i].amount))
			if late:
				txt += " · %d s" % ceili(left)
			_pill_above(sp, txt, UI.BAD if late else UI.AMBER, "money", Color.WHITE if late else UI.TEXT, "fish_rent_%d" % i)


## Gains qui s'envolent : décalés s'ils chevauchent une bulle (« +2,9 $ » ne recouvre plus « File : 0 », revue D-UI).
func _draw_popups() -> void:
	for pi in popups.size():
		var p: Dictionary = popups[pi]
		var big := bool(p.get("big", false))
		var life := 2.4 if big else 1.6
		var a: float = 1.0 - clampf((float(p.t) - (life - 0.6)) / 0.6, 0.0, 1.0)
		var sp2 := _sp(p.p) + Vector2(0, -float(p.t) * (55.0 if big else 70.0))
		var c: Color = p.col
		c.a = a
		if big:
			var sc := 1.0 + 0.25 * (1.0 - clampf(float(p.t) / 0.25, 0.0, 1.0))
			_pill(sp2, String(p.text), Color(1, 1, 1, 0.94 * a), "", c, true, "pop%d" % pi, int(44.0 * sc))
		else:
			_pill(sp2, String(p.text), Color(1, 1, 1, 0.85 * a), "", c, true, "pop%d" % pi)


func _mood_bubble(sp: Vector2, ratio: float, mood: int, priority: bool) -> void:
	var col: Color = MOOD_COL[mood]
	_placed.append(Rect2(sp - Vector2(36, 36), Vector2(72, 72)))
	draw_circle(sp + Vector2(0, 4), 36.0, Color(0, 0, 0, 0.15))
	draw_circle(sp, 36.0, Color.WHITE)
	draw_arc(sp, 30.0, -PI / 2, -PI / 2 + TAU * ratio, 40, col, 8.0, true)
	# visage
	var eye := Color("#2B2D42")
	draw_circle(sp + Vector2(-8, -5), 3.6, eye)
	draw_circle(sp + Vector2(8, -5), 3.6, eye)
	match mood:
		0:
			draw_arc(sp + Vector2(0, 2), 10.0, 0.25, PI - 0.25, 12, eye, 3.5, true)
		1:
			draw_line(sp + Vector2(-9, 9), sp + Vector2(9, 9), eye, 3.5, true)
		_:
			draw_arc(sp + Vector2(0, 17), 9.0, PI + 0.35, TAU - 0.35, 12, eye, 3.5, true)
			draw_line(sp + Vector2(-13, -13), sp + Vector2(-4, -9), eye, 3.0, true)
			draw_line(sp + Vector2(13, -13), sp + Vector2(4, -9), eye, 3.0, true)
	if priority:
		draw_texture_rect(UI.icon_tex("star"), Rect2(sp + Vector2(18, -44), Vector2(30, 30)), false)


func _ring(sp: Vector2, r: float, v: float, col: Color, bg: Color) -> void:
	_placed.append(Rect2(sp - Vector2(r + 6, r + 6), Vector2(r + 6, r + 6) * 2.0))
	draw_circle(sp + Vector2(0, 4), r + 6, Color(0, 0, 0, 0.15))
	draw_circle(sp, r + 6, bg)
	draw_arc(sp, r, -PI / 2, -PI / 2 + TAU * clampf(v, 0.0, 1.0), 40, col, 8.0, true)


func _text_c(p: Vector2, t: String, size: int, col: Color) -> void:
	var w := UI.font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(UI.font, p - Vector2(w * 0.5, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Bulle dont le bas est posé sur le point d'ancrage `anchor` (écran) : elle ne couvre jamais ce qui est dessous.
func _pill_above(anchor: Vector2, t: String, bg: Color, icon_name: String, fg: Color = Color.WHITE, key: String = "") -> Rect2:
	return _pill(anchor - Vector2(0, PILL_H * 0.5 + GAP), t, bg, icon_name, fg, true, key)


func _pill(center: Vector2, t: String, bg: Color, icon_name: String, fg: Color = Color.WHITE, settle_it: bool = true, key: String = "", size: int = 30) -> Rect2:
	var tw := UI.font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var iw := 40.0 if icon_name != "" else 0.0
	var w := tw + iw + 36.0
	var h := PILL_H * float(size) / 30.0
	var r := Rect2(center - Vector2(w * 0.5, h * 0.5), Vector2(w, h))
	if settle_it:
		# bornée au rectangle utile (jamais sur le HUD ni coupée par le bord), puis décalée si elle en chevauche une autre
		r = Bubbles.bound(r, useful)
		if not r.has_area():
			return r
		r = Bubbles.bound(Bubbles.settle(r, _placed, useful), useful)
		_placed.append(r)
	if key != "":
		last_rects[key] = r
		frame_rects[key] = r
	center = r.get_center()
	var sb := _sb_pill          # lot E : une seule boîte réutilisée (plus de StyleBoxFlat.new() par bulle et par image)
	sb.bg_color = bg
	sb.set_corner_radius_all(int(h * 0.5))
	sb.shadow_color = Color(0, 0, 0, 0.15 * bg.a)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 3)
	draw_style_box(sb, r)
	var x := r.position.x + 18.0
	if icon_name != "":
		draw_texture_rect(UI.icon_tex(icon_name), Rect2(Vector2(x, center.y - 18), Vector2(36, 36)), false, fg)
		x += iw
	draw_string(UI.font, Vector2(x, center.y + size * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fg)
	return r


## Jauge du parc : le **stock** (remplissage). Quand le goulot est « parc trop petit » (capacité théorique, pas le
## remplissage), la jauge le dit en rouge sous le stock : jamais un goulot rouge à côté d'une jauge verte sans explication.
func _gauge(center: Vector2, fill: float, small_yard: bool = false) -> void:
	var w := 200.0
	var h := 36.0
	var outer := Bubbles.bound(Rect2(center - Vector2(w * 0.5 + 8, h * 0.5 + 8), Vector2(w + 16, h + 16)), useful)
	if not outer.has_area():
		return
	outer = Bubbles.bound(Bubbles.settle(outer, _placed, useful), useful)
	last_rects["yard"] = outer
	frame_rects["yard"] = outer
	_placed.append(outer)
	center = outer.get_center()
	var col := UI.MONEY if fill < 0.65 else (UI.AMBER if fill < 0.9 else UI.BAD)
	var bg := _sb_pill
	bg.bg_color = Color.WHITE
	bg.set_corner_radius_all(22)
	bg.shadow_color = Color(0, 0, 0, 0.15)
	bg.shadow_size = 4
	bg.shadow_offset = Vector2.ZERO
	draw_style_box(bg, outer)
	var fg := _sb_bar
	fg.bg_color = Color("#E3E6F0")
	fg.set_corner_radius_all(18)
	draw_style_box(fg, Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h)))
	fg.bg_color = col
	draw_style_box(fg, Rect2(center - Vector2(w, h) * 0.5, Vector2(maxf(h, w * clampf(fill, 0, 1)), h)))
	_text_c(center + Vector2(0, 10), "Stock %d %%" % roundi(fill * 100.0), 26, UI.TEXT if fill < 0.45 else Color.WHITE)
	if small_yard:
		var tag := _pill(Vector2(center.x, outer.end.y + PILL_H * 0.5 + GAP), "Trop petit pour ton débit", UI.BAD, "yard", Color.WHITE, true, "yard_small")
		if tag.has_area():
			last_rects["yard_small"] = tag


## Pastille de l'aire d'attente (centre du parking poids lourds).
const PARKING_PILL := Vector3(-3, 5, 64)


## Pancarte du prochain achat (nom et prix dessinés ici, jamais en texte 3D) ; elle rebondit quand l'achat est abordable.
## Pendant une ouverture de zone, rien n'est dessiné.
func _draw_next_sign(sim: PortSim, top_y: float) -> void:
	if diorama.opening_active():
		return
	var bid := Zones.first_unbuilt(sim)
	if bid == "" or not Layout.LOTS.has(bid):
		return
	var wp := diorama.lot_sign_point()
	if wp == Vector3.INF:
		return
	var sp := _sp(wp)
	var vs := get_viewport_rect().size
	if sp.y < top_y + 40.0 or sp.y > vs.y - 120.0 or sp.x < 0.0 or sp.x > vs.x:
		return
	var b: Dictionary = sim.db.building_by_id[bid]
	var st := sim.building_state(bid)
	var cost := float(b.cost)
	# même achat, même nom partout (revue D-UI) : la pancarte porte le nom du bâtiment, comme Gestion et la carte Goulot
	var name := String(b.name)
	var txt := "%s · %s" % [name, Fmt.money(cost)] if st == "available" else "%s · palier T%d" % [name, int(b.tier)]
	var ok := st == "available" and sim.money >= cost
	var bounce := -absf(sin(_t * 5.0)) * 12.0 if ok else 0.0
	_pill_above(sp + Vector2(0, bounce), txt, UI.MONEY if ok else Color(1, 1, 1, 0.95), Info.building_icon(b), Color.WHITE if ok else UI.TEXT, "lot")


## Zone grise touchée : une bulle d'information (son nom, ce qui l'ouvre) pendant 2 s, pas une fenêtre.
func show_zone_info(zone_id: int, wp: Vector3) -> void:
	var z := Layout.zone_by_id(zone_id)
	if z.is_empty() or diorama == null or diorama.sim == null:
		return
	var sim := diorama.sim
	var key := String(z.get("key", ""))
	var cond := ""
	if key != "" and sim.db.building_by_id.has(key):
		cond = "avec « %s »" % String(sim.db.building_by_id[key].name)
	elif String(z.open).begins_with("t"):
		cond = "au palier T%s" % String(z.open).substr(1)
	zone_info = {"p": Vector3(wp.x, 2.0, wp.z), "text": "%s : s'ouvre %s" % [String(z.name), cond], "t": 0.0, "id": zone_id}


# ---------------------------------------------------------------------------
# Brume de la Crique : le cadenas « Concession · prix » sur la zone verrouillée (CloudLayer ; toucher → AMÉLIORER)
# ---------------------------------------------------------------------------
var _lock_w := Vector3.INF      # point du sol sous le cadenas (lissé : il suit la caméra sans sauter)
var _lock_goal := Vector3.INF
var _lock_t := -1.0


## Où poser le cadenas : la parcelle de la Concession si elle est à l'écran, sinon le barycentre (au sol) de la brume dense
## visible ; Vector3.INF quand presque rien de verrouillé n'est à l'écran.
func _lock_target() -> Vector3:
	var u := useful if useful.has_area() else get_viewport_rect()
	if u.grow(-90.0).has_point(_sp(CloudLayer.CONCESSION_AT)):
		return CloudLayer.CONCESSION_AT
	var acc := Vector3.ZERO
	var n := 0
	var ui := u.grow(-60.0)
	for i in 10:
		for j in 16:
			var g := diorama.rig.screen_to_ground(ui.position + ui.size * Vector2((float(i) + 0.5) / 10.0, (float(j) + 0.5) / 16.0))
			if CloudLayer.veil_alpha(Vector2(g.x, g.z)) >= 0.4:
				acc += g
				n += 1
	return acc / float(n) if n >= 4 else Vector3.INF


func _draw_lock() -> void:
	var cl := diorama.clouds
	if cl == null or not is_instance_valid(cl) or not diorama.clouds_on():
		_lock_w = Vector3.INF
		return
	cl.lock_rect = Rect2()
	if _t - _lock_t > 0.25:
		_lock_t = _t
		_lock_goal = _lock_target()
	if _lock_goal == Vector3.INF:
		_lock_w = Vector3.INF
		return
	_lock_w = _lock_goal if _lock_w == Vector3.INF else _lock_w.lerp(_lock_goal, 0.12)
	var sp := _sp(_lock_w)
	var r := 46.0
	var disc := Rect2(sp - Vector2(r, r), Vector2(r, r) * 2.0)
	if useful.has_area() and not useful.grow(-8.0).encloses(disc):
		return
	draw_circle(sp + Vector2(0, 5), r, Color(0, 0, 0, 0.18))
	draw_circle(sp, r, Color(1, 1, 1, 0.96))
	draw_arc(sp, r - 3.0, 0.0, TAU, 48, UI.AMBER, 5.0, true)
	draw_texture_rect(UI.icon_tex("lock"), Rect2(sp - Vector2(28, 30), Vector2(56, 56)), false, UI.TEXT)
	_placed.append(disc)
	var price := Fmt.money(float(diorama.sim.fishing.concession_def().cost))
	var pr := _pill(sp + Vector2(0, r + PILL_H * 0.5 + GAP), "Concession · " + price, Color("#2B2D42", 0.92), "", Color.WHITE, true, "lock")
	cl.lock_rect = disc.merge(pr)
	frame_rects["lock_disc"] = disc

