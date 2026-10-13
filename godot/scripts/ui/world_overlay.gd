class_name WorldOverlay
extends Control
## Surcouche 2D au-dessus du diorama : la file et l'attente se lisent au premier coup d'œil
## (file + barre + humeur), plus les gains qui s'envolent.
## Lot B : chaque bulle de bâtiment est ancrée à `anchor_y` (assets_meta.json, sinon sommet de la boîte englobante + 0,4)
## et posée *au-dessus* de ce point ; deux bulles qui se chevauchent sont décalées latéralement (`Bubbles.settle`).

const MOOD_COL := [Color("#38B76A"), Color("#FFB020"), Color("#EB4D4B")]
const PILL_H := 54.0
const GAP := 6.0            # écart entre le point d'ancrage et le bas de la bulle, et entre deux bulles décalées

var diorama: Diorama
var popups: Array[Dictionary] = []      # {p: Vector3, text, t, col}
var _t := 0.0
var _placed: Array[Rect2] = []          # rectangles déjà dessinés dans l'image courante (anti-chevauchement)
var last_rects: Dictionary = {}         # clé -> Rect2 de la dernière bulle dessinée (tests)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func add_popup(p: Vector3, text: String, col: Color = UI.MONEY) -> void:
	if popups.size() > 14:
		popups.pop_front()
	popups.append({"p": p, "text": text, "t": 0.0, "col": col})


func _process(delta: float) -> void:
	_t += delta
	for p in popups:
		p.t += delta
	popups = popups.filter(func(p: Dictionary) -> bool: return p.t < 1.6)
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
	# rien n'est dessiné sous les cartes du haut (conseil, aléa, bandeau des missions) : un navire caché derrière reste caché
	var top_y := Hud.main.top_cards_bottom() if Hud.main != null else 0.0
	# navires
	for s in sim.ships:
		var v: ShipView = diorama.ship_views.get(s.id)
		if v == null:
			continue
		var sp := _sp(v.bubble_point())
		if sp.y < top_y:
			continue
		if s.state == Ship.State.ANCHORED or s.state == Ship.State.ARRIVING:
			_mood_bubble(sp, s.patience_ratio(), s.mood(), s.priority)
		elif s.state == Ship.State.UNLOADING or s.state == Ship.State.FORMALITIES:
			var prog := s.progress()
			_ring(sp, 30.0, prog, UI.INFO, Color.WHITE)
			_text_c(sp + Vector2(0, 11), "%d%%" % roundi(prog * 100.0) if s.state == Ship.State.UNLOADING else "…", 26, UI.TEXT)
			if s.state == Ship.State.FORMALITIES:
				_pill(sp + Vector2(0, -60), "Formalités", Color("#4B3FB5"), "customs")
		elif s.state == Ship.State.LEAVING:
			_pill(sp + Vector2(0, -10), "Furieux !", UI.BAD, "")
	# gestes manuels disponibles : « Touche ! » sur le prochain navire à accoster, « Coup de main » sur les grues
	if not sim.managers.harbor:
		for s in sim.ships:
			if s.state == Ship.State.ANCHORED and not s.priority:
				var v: ShipView = diorama.ship_views.get(s.id)
				if v != null and _sp(v.bubble_point()).y - 62.0 > top_y:
					_pill(_sp(v.bubble_point()) + Vector2(0, -62), "Touche pour accoster", UI.AMBER, "", UI.TEXT)
				break
	for cv in diorama.crane_views:
		if sim.assist_ready(cv.berth):
			var cm := "crane_sts" if cv.kind == "sts" else "crane_mobile"
			_pill_above(_sp(anchor_point(cm, cv.position)), "Coup de main !", UI.AMBER, "boost", UI.TEXT, "assist")
			break
	# file en rade
	var waiting := sim.waiting_ships()
	var col := UI.INFO if waiting < sim.rade_places() - 1 else UI.BAD
	# l'étiquette suit la rade, mais reste lisible : jamais sous les cartes du haut ni coupée par le bord de l'écran
	var rp := _sp(Layout.anchor_pos(0) + Vector3(-20, 6, 8))
	var vw := get_viewport_rect().size.x
	rp.x = clampf(rp.x, 110.0, vw - 110.0)
	if Hud.main != null:
		rp.y = maxf(rp.y, Hud.main.top_cards_bottom() + 36.0)
	_pill(rp, "%d/%d en rade" % [waiting, sim.rade_places()], col, "ship")
	# douane : au-dessus du toit du bureau (anchor_y), jamais sur la table d'inspection
	var pend := sim.pending_total()
	if pend >= 1.0 or sim.analysis.get("dept", "") == "customs":
		var bad: bool = sim.analysis.get("dept", "") == "customs"
		_pill_above(_sp(anchor_point("customs_hut", Layout.CUSTOMS_HUT)), "À inspecter : %s" % Fmt.num(pend), UI.BAD if bad else UI.INFO, "customs", Color.WHITE, "customs")
	# dézoom fort : parc et gate sont proches à l'écran, on n'affiche que ce qui pose problème
	var far := diorama.rig != null and diorama.rig.zoom > 110.0
	var dept: String = sim.analysis.get("dept", "")
	# parc : jauge de remplissage
	var fill := sim.yard_fill()
	if not far or dept == "yard_ops" or fill > 0.65:
		_gauge(_sp(Layout.YARD_CENTER + Vector3(0, 9, 0)), fill)
	# gate : au-dessus de la guérite (ou de la barrière avant elle), au-dessus des camions en file
	var tw := sim.trucks_waiting()
	var honk := sim.trucks_honking() > 0
	if not far or honk or dept == "gate":
		var gm := "gate_booth" if sim.built.has("gate2") else "barrier"
		var gpos := _sp(Layout.GATE + Vector3(0, maxf(Assets.anchor_y(gm), 3.6), 0))
		gpos.x = clampf(gpos.x, 110.0, vw - 110.0)      # jamais coupée par le bord de l'écran
		var gr := _pill_above(gpos, "%d camion%s" % [tw, "s" if tw > 1 else ""], UI.BAD if honk else UI.INFO, "horn" if honk else "truck", Color.WHITE, "gate")
		if honk and fmod(_t, 0.6) < 0.3:
			_text_c(gr.get_center() + Vector2(70, -46), "Tuut !", 30, UI.BAD)
	# aire d'attente : places occupées / places disponibles
	if sim.parking_slots > 0 and (not far or honk or dept == "gate"):
		var in_lot := clampi(tw - TrafficView.ROAD_SLOTS, 0, sim.parking_slots)
		var full := in_lot >= sim.parking_slots
		_pill(_sp(Vector3(-6, 5, 50)), "Aire d'attente %d/%d" % [in_lot, sim.parking_slots], UI.BAD if full else UI.INFO, "truck")
	# tablier : alerte dessinée après la jauge du parc, qu'elle chevauche en dézoom
	var af := sim.apron_stock() / maxf(1.0, sim.apron_capacity())
	if af > 0.92:
		_pill(_sp(Vector3(-18, 3, 1)), "Tablier plein", UI.BAD, "yard")
	# gains qui s'envolent (jamais décalés : ils bougent)
	for p in popups:
		var a: float = 1.0 - clampf((float(p.t) - 1.0) / 0.6, 0.0, 1.0)
		var sp2 := _sp(p.p) + Vector2(0, -float(p.t) * 70.0)
		var c: Color = p.col
		c.a = a
		_pill(sp2, String(p.text), Color(1, 1, 1, 0.85 * a), "", c, false)


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


func _pill(center: Vector2, t: String, bg: Color, icon_name: String, fg: Color = Color.WHITE, settle_it: bool = true, key: String = "") -> Rect2:
	var size := 28
	var tw := UI.font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var iw := 40.0 if icon_name != "" else 0.0
	var w := tw + iw + 36.0
	var h := PILL_H
	var r := Rect2(center - Vector2(w * 0.5, h * 0.5), Vector2(w, h))
	if settle_it:
		r = Bubbles.settle(r, _placed)
		_placed.append(r)
	if key != "":
		last_rects[key] = r
	center = r.get_center()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(27)
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


func _gauge(center: Vector2, fill: float) -> void:
	var w := 200.0
	var h := 36.0
	var outer := Bubbles.settle(Rect2(center - Vector2(w * 0.5 + 8, h * 0.5 + 8), Vector2(w + 16, h + 16)), _placed)
	_placed.append(outer)
	center = outer.get_center()
	var col := UI.MONEY if fill < 0.65 else (UI.AMBER if fill < 0.9 else UI.BAD)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color.WHITE
	bg.set_corner_radius_all(22)
	bg.shadow_color = Color(0, 0, 0, 0.15)
	bg.shadow_size = 4
	draw_style_box(bg, outer)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("#E3E6F0")
	fg.set_corner_radius_all(18)
	draw_style_box(fg, Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h)))
	fg.bg_color = col
	draw_style_box(fg, Rect2(center - Vector2(w, h) * 0.5, Vector2(maxf(h, w * clampf(fill, 0, 1)), h)))
	_text_c(center + Vector2(0, 10), "Parc %d %%" % roundi(fill * 100.0), 26, UI.TEXT if fill < 0.45 else Color.WHITE)
