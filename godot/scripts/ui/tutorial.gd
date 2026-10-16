class_name Tutorial
extends Control
## Tutoriel guidé : une suite d'étapes pilotées par `data/tutorial.json`. Chaque étape attend une condition
## de départ (`when`), montre une phrase avec une flèche sur la cible, et se termine quand la condition `done`
## est vraie (ou quand le joueur appuie sur le bouton). Rien n'est bloquant : le joueur peut tout toucher.

var hud: Hud
var steps: Array = []
var idx: int = 0
var active: bool = false
var _card: PanelContainer
var _title: Label
var _text: Label
var _btn: Button
var _skip: Button
var _t := 0.0
var _check := 0.0
var _shown := ""
var _flash := 0.0
var _narrator: Narrator
var _lock := false                # étape « verrouillée » : le reste de l'interface est assombri et inactif
var _dim: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var raw: Variant = DataDB.load_json("res://data/tutorial.json")
	steps = raw if raw is Array else []
	idx = Settings.tuto_step
	if Settings.tuto_rev < Settings.TUTO_REV and idx > 0:
		idx = _from_old_index(idx, Settings.tuto_rev)
		Settings.set_tuto_step(idx)
	# une partie déjà avancée (sauvegarde d'avant le tutoriel) n'a pas besoin des premiers pas
	if idx == 0 and GameState.sim != null and GameState.sim.time > 300.0 and not Capture.args().has("tuto"):
		idx = steps.size()
		Settings.set_tuto_step(idx)
	active = idx < steps.size() and (not Capture.args().has("capture") or Capture.args().has("tuto"))
	_dim = ColorRect.new()
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = DIM_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_dim.material = mat
	_dim.show_behind_parent = true     # l'anneau et la flèche du tutoriel restent par-dessus le voile
	_dim.visible = false
	add_child(_dim)
	_build_card()
	_card.visible = false


func _build_card() -> void:
	_card = UI.card(Color.WHITE, 22)
	_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_card.offset_left = 24
	_card.offset_right = -24
	_card.offset_bottom = -222
	_card.offset_top = -222
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := UI.card_style(Color.WHITE, 30, 22)
	sb.border_color = UI.AMBER
	sb.set_border_width_all(5)
	_card.add_theme_stylebox_override("panel", sb)
	add_child(_card)
	var hrow := UI.hbox(18)
	_card.add_child(hrow)
	var left := UI.vbox(2)
	_narrator = Narrator.new(132.0)
	left.add_child(_narrator)
	var who := UI.label("Capitaine Roche", 24, UI.MUTED)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(who)
	hrow.add_child(left)
	var v := UI.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(v)
	_title = UI.label("", 38, UI.VIOLET)
	v.add_child(_title)
	_text = UI.wrap_label("", 30, UI.TEXT)
	v.add_child(_text)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	_skip = UI.button("Passer le tutoriel", UI.INDIGO_DARK, 24, 96)
	_skip.pressed.connect(skip_all)
	row.add_child(_skip)
	_btn = UI.button("", UI.MONEY, 30, 96)
	_btn.custom_minimum_size.x = 260
	_btn.pressed.connect(_on_button)
	row.add_child(_btn)


var _card_top := false


## Feuille mi-hauteur ouverte (Améliorer, Commerce) : la carte passe en haut de l'écran, au-dessus de la feuille (lot D-UI) ;
## sinon elle reste en bas, au-dessus des boutons.
func _place_card() -> void:
	var top := hud != null and hud.half_sheet_open()
	if top == _card_top:
		return
	_card_top = top
	if top:
		_card.anchor_top = 0.0
		_card.anchor_bottom = 0.0
		_card.offset_top = 24.0
		_card.offset_bottom = 24.0
		_card.grow_vertical = Control.GROW_DIRECTION_END
	else:
		_card.anchor_top = 1.0
		_card.anchor_bottom = 1.0
		_card.offset_bottom = -222.0
		_card.offset_top = -222.0
		_card.grow_vertical = Control.GROW_DIRECTION_BEGIN

## Colonne centrale de l'interface : la carte de conseil reste dans la colonne.
func set_side(side: float) -> void:
	if _card != null:
		_card.offset_left = 24.0 + side
		_card.offset_right = -24.0 - side


func skip_all() -> void:
	idx = steps.size()
	Settings.set_tuto_step(idx)
	_refresh_card(true)


## Nouvelle partie (réglages) : le tutoriel reprend depuis le début.
func restart() -> void:
	idx = 0
	_shown = ""
	active = not steps.is_empty()
	Settings.set_tuto_step(0)
	_refresh_card(true)


func _eval(expr: String) -> bool:
	if expr == "":
		return false
	var e := Expression.new()
	if e.parse(expr, ["sim"]) != OK:
		push_warning("Tutoriel : expression invalide « %s »" % expr)
		return false
	var r: Variant = e.execute([GameState.sim], null, false)
	return not e.has_execute_failed() and bool(r)


func _advance() -> void:
	idx += 1
	Settings.set_tuto_step(idx)
	_shown = ""
	_flash = 0.6
	Sfx.play("coin")
	if idx >= steps.size():
		active = false


func _on_button() -> void:
	if idx < steps.size():
		_advance()
	_refresh_card(true)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	_place_card()
	# pendant une ouverture de zone, le tutoriel se tait (le HUD est masqué) et reprend à la fin
	var opening := hud != null and hud.diorama != null and hud.diorama.opening_active()
	if not active or GameState.sim == null or opening:
		_card.visible = false
		_set_lock(false)
		queue_redraw()
		return
	_check += delta
	if _check >= 0.25:
		_check = 0.0
		_refresh_card(false)
	_update_lock()
	_update_dim()
	queue_redraw()


func _refresh_card(force: bool) -> void:
	if idx >= steps.size():
		active = false
		_card.visible = false
		return
	var st: Dictionary = steps[idx]
	# « done » d'abord : un joueur qui a déjà fait le geste (ou qui l'a fait avant que l'étape s'affiche) ne doit pas
	# attendre que la condition de départ redevienne vraie pour passer à la suite.
	if String(st.get("done", "")) != "" and _eval(String(st.done)):
		_advance()
		return
	if not _eval(String(st.get("when", "true"))):
		_card.visible = false
		return
	var txt := String(st.text)
	if hud != null and hud.any_sheet_open():
		# dans un menu, seules les étapes qui s'y font gardent leur carte (« Touche le navire » n'a rien à y faire)
		if not st.has("text_sheet"):
			_card.visible = false
			return
		txt = String(st.text_sheet)
	var key := "%d|%s" % [idx, txt]
	if force or key != _shown:
		_shown = key
		_title.text = String(st.get("title", ""))
		_title.visible = _title.text != ""
		_text.text = txt
		_narrator.pose = String(st.get("pose", "hello"))
		var has_btn := String(st.get("button", "")) != ""
		_btn.visible = has_btn
		_btn.text = String(st.get("button", ""))
		_card.visible = true
		_card.scale = Vector2(0.96, 0.96)
		_card.pivot_offset = Vector2(_card.size.x * 0.5, _card.size.y)
		create_tween().tween_property(_card, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)
		_focus_camera(st)
	_card.visible = true


## Amène la caméra sur la cible monde de l'étape (le HUD en haut de l'écran cache la rade au cadrage de départ).
func _focus_camera(st: Dictionary) -> void:
	var t := String(st.get("target", ""))
	if hud == null or hud.diorama == null or (t != "ship" and t != "crane" and t != "ship_waiting" and not t.begins_with("lot:") and t != "vehicle" and t != "barrier" and t != "hut"):
		return
	var d := hud.diorama
	var sim := GameState.sim
	if t == "ship":
		for s in sim.ships:
			if s.state == Ship.State.ANCHORED or s.state == Ship.State.ARRIVING:
				# lot F2 : le premier navire du T1 n'a pas de mouillage — il est déjà en route vers le quai : on le suit
				var fv: ShipView = d.ship_views.get(s.id)
				if fv != null and is_instance_valid(fv) and fv.phase >= ShipView.Phase.INBOUND:
					d.rig.focus(Vector3(fv.position.x - 4.0, 0.0, fv.position.z + 12.0))
					return
				# on vise le mouillage (un navire en approche y arrive), pas sa position du moment
				var a := Layout.anchor_pos(maxi(0, s.anchor_slot))
				d.rig.focus(Vector3(a.x + 14.0, 0.0, a.z + 18.0))
				return
	elif t == "ship_waiting":
		var w := _longest_waiting(sim)
		if w != null:
			var a2 := Layout.anchor_pos(maxi(0, w.anchor_slot))
			d.rig.focus(Vector3(a2.x + 14.0, 0.0, a2.z + 18.0))
	elif t == "crane" and not d.crane_views.is_empty():
		var p := d.crane_views[0].position
		d.rig.focus(Vector3(p.x - 4.0, 0.0, p.z + 10.0))
	elif t == "hut":
		d.rig.focus(Layout.CUSTOMS_HUT + Vector3(2, 0, -10))
	elif t == "vehicle" or t == "barrier":
		d.rig.focus(Layout.GATE + Vector3(2, 0, -14) if t == "barrier" else Layout.YARD_CENTER + Vector3(-4, 0, 4))
	elif t.begins_with("lot:") and Layout.LOTS.has(t.substr(4)):
		var lp: Vector3 = Layout.LOTS[t.substr(4)].p
		d.rig.focus(Vector3(lp.x - 4.0, 0.0, lp.z + 6.0))


# --- étapes verrouillées : le reste de l'interface est assombri et ne répond plus ------------------

func _update_lock() -> void:
	var on := active and idx < steps.size() and _card.visible and bool(steps[idx].get("lock", false)) \
		and hud != null and not hud.any_sheet_open()
	_set_lock(on)


func _set_lock(on: bool) -> void:
	if on == _lock:
		return
	_lock = on
	if _dim != null:
		_dim.visible = on
	# STOP : le tutoriel capte les touches hors de la cible (_has_point), qui n'atteignent donc ni le HUD ni le port
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func is_locked() -> bool:
	return _lock


## Zone laissée active pendant une étape verrouillée (vide : seule la carte du tutoriel répond).
func _hole() -> Rect2:
	if idx >= steps.size():
		return Rect2()
	var tg := _target(steps[idx])
	if tg.has("rect"):
		return (tg.rect as Rect2).grow(14.0)
	if tg.has("pos"):
		var p: Vector2 = tg.pos
		return Rect2(p - Vector2(90, 90), Vector2(180, 180))
	return Rect2()


func _has_point(point: Vector2) -> bool:
	if not _lock:
		return false
	var h := _hole()
	return not (h.has_area() and h.has_point(point))


const DIM_SHADER := """
shader_type canvas_item;
uniform vec4 hole = vec4(0.0);       // centre (x, y) et demi-taille (z, w) en coordonnées locales ; z = 0 : pas de trou
uniform float corner = 30.0;         // rayon des coins (= demi-taille : trou rond)
uniform vec4 dim : source_color = vec4(0.08, 0.06, 0.22, 0.62);
varying vec2 local;
void vertex() { local = VERTEX; }
void fragment() {
	float a = dim.a;
	if (hole.z > 0.0) {
		vec2 q = abs(local - hole.xy) - (hole.zw - vec2(corner));
		float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner;
		a *= smoothstep(-3.0, 3.0, d);
	}
	COLOR = vec4(dim.rgb, a);
}
"""


## Voile sombre avec un trou (rond pour un point du monde, arrondi pour un bouton) sur la cible de l'étape.
func _update_dim() -> void:
	_dim.visible = _lock
	if not _lock:
		return
	_dim.position = Vector2.ZERO
	_dim.size = get_viewport_rect().size
	var h := _hole()
	var mat := _dim.material as ShaderMaterial
	if not h.has_area():
		mat.set_shader_parameter("hole", Vector4.ZERO)
		return
	var c := h.get_center()
	mat.set_shader_parameter("hole", Vector4(c.x, c.y, h.size.x * 0.5, h.size.y * 0.5))
	mat.set_shader_parameter("corner", minf(h.size.x, h.size.y) * 0.5 if _is_world_target() else 30.0)


func _is_world_target() -> bool:
	return idx < steps.size() and not String(steps[idx].get("target", "")).begins_with("ctl:")


# --- repère visuel sur la cible -------------------------------------------------

## Cible de l'étape : {"rect": Rect2} pour un contrôle, {"pos": Vector2} pour un point du monde, {} sinon.
func _target(st: Dictionary) -> Dictionary:
	var t := String(st.get("target", ""))
	# un menu ouvert recouvre le port et les boutons : aucun repère ne doit clignoter par-dessus
	if t == "" or hud == null or hud.any_sheet_open():
		return {}
	if t.begins_with("ctl:"):
		var c: Control = hud.tut_targets.get(t.substr(4))
		if c != null and c.is_visible_in_tree():
			return {"rect": c.get_global_rect()}
		return {}
	var d := hud.diorama
	var sim := GameState.sim
	if t == "ship" and d != null:
		for s in sim.ships:
			if s.state == Ship.State.ANCHORED or s.state == Ship.State.ARRIVING:
				var v: ShipView = d.ship_views.get(s.id)
				if v != null:
					return {"pos": d.to_screen(v.position + Vector3(0, 4, 0))}
	if t == "ship_waiting" and d != null:
		var w := _longest_waiting(sim)
		if w != null and d.ship_views.has(w.id):
			return {"pos": d.to_screen((d.ship_views[w.id] as Node3D).position + Vector3(0, 4, 0))}
	# lot F3/G1 : un bateau rentré dont le loyer attend (bulle « Loyer »)
	if t == "boat" and d != null and d.fishing_view != null:
		var hb := d.fishing_view.collectable()
		if not hb.is_empty():
			return {"pos": d.to_screen(d.fishing_view.boat_pos(hb[0]) + Vector3(0, 1.5, 0))}
	if t == "vehicle" and d != null and not d.traffic.vehicles.is_empty():
		return {"pos": d.to_screen((d.traffic.vehicles[0].node as Node3D).position + Vector3(0, 2, 0))}
	if t == "barrier" and d != null:
		return {"pos": d.to_screen(Layout.GATE + Vector3(-2, 1.5, 1))}
	if t == "hut" and d != null:      # lot G2 : la cabane de douane (tamponner)
		return {"pos": d.to_screen(Layout.CUSTOMS_HUT + Vector3(0, 2.5, 0))}
	if t.begins_with("lot:") and d != null:
		var bid := t.substr(4)
		if sim.built.has(bid) or not Layout.LOTS.has(bid):
			return {}
		var wp: Vector3 = d.lot_sign_point() if Zones.first_unbuilt(sim) == bid else (Layout.LOTS[bid].p as Vector3)
		if wp == Vector3.INF:
			return {}
		return {"pos": d.to_screen(wp)}
	if t == "crane" and d != null:
		for cv in d.crane_views:
			if sim.assist_ready(cv.berth) or cv.berth == 0:
				return {"pos": d.to_screen(cv.position + Vector3(0, 6, 0))}
	return {}


func _draw() -> void:
	if not active or idx >= steps.size() or not _card.visible:
		return
	var tg := _target(steps[idx])
	if tg.is_empty():
		return
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	var col := Color(1.0, 0.69, 0.13, 0.55 + 0.45 * pulse)
	var top: Vector2
	var bottom: Vector2
	if tg.has("rect"):
		var r: Rect2 = (tg.rect as Rect2).grow(8.0 + 4.0 * pulse)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.0)
		sb.border_color = col
		sb.set_border_width_all(7)
		sb.set_corner_radius_all(30)
		draw_style_box(sb, r)
		top = Vector2(r.get_center().x, r.position.y - 10.0)
		bottom = Vector2(r.get_center().x, r.end.y + 10.0)
	else:
		var p: Vector2 = tg.pos
		var rad := 54.0 + 10.0 * pulse
		draw_arc(p, rad, 0.0, TAU, 40, col, 8.0, true)
		draw_circle(p, 40.0, Color(1, 0.69, 0.13, 0.18))
		top = p + Vector2(0, -rad - 6.0)
		bottom = p + Vector2(0, rad + 6.0)
	# flèche qui rebondit : au-dessus de la cible, ou en dessous si le haut de l'écran est pris par le HUD
	var b := 14.0 * sin(_t * 7.0)
	var amber := Color(1.0, 0.69, 0.13)
	if top.y < 250.0:
		var a := bottom + Vector2(0, 14.0 + b)
		draw_colored_polygon(PackedVector2Array([a + Vector2(-26, 34), a + Vector2(26, 34), a + Vector2(0, -8)]), amber)
	else:
		var a2 := top + Vector2(0, -14.0 - b)
		draw_colored_polygon(PackedVector2Array([a2 + Vector2(-26, -34), a2 + Vector2(26, -34), a2 + Vector2(0, 8)]), amber)


## Le navire qui attend en rade depuis le plus longtemps (celui dont la bulle d'humeur s'assombrit).
func _longest_waiting(sim: PortSim) -> Ship:
	var best: Ship = null
	for s in sim.ships:
		if s.state == Ship.State.ANCHORED and (best == null or s.wait_time > best.wait_time):
			best = s
	return best


## Progression enregistrée avec une ancienne liste d'étapes : on retrouve l'étape par son nom.
## Version 1 (avant la narratrice) : l'ancienne étape « goulot » venait avant le quai, elle reprend au quai.
## Version 2 (avant les chapitres) : les étapes « parc » et « gate » n'existaient pas.
## Version 3 (avant le quai en premier) : « buy » venait avant « quay » ; un joueur arrêté sur « buy » reprend au quai
## (l'étape se valide d'elle-même si le quai est déjà construit).
## Version 4 (avant C7) : « manager » venait avant « parc » ; un joueur arrêté sur l'une ou l'autre reprend au parc
## (Yasmine suit ; son étape se valide seule si elle est déjà embauchée).
const OLD_ORDER := ["welcome", "ship", "crane", "quay", "quay", "quay", "manager", "building", "mission", "commerce", "contracts"]
const REV2_ORDER := ["welcome", "ship", "crane", "quay", "quay", "goulot", "goulot_fix", "manager", "building", "mission", "commerce", "contracts"]
const REV3_ORDER := ["welcome", "ship", "crane", "quay", "quay", "goulot", "goulot_fix", "manager", "parc", "building", "gate", "mission", "commerce", "contracts"]
const REV4_ORDER := ["welcome", "ship", "crane", "quay", "buy", "goulot", "goulot_fix", "parc", "parc", "building", "gate", "mission", "commerce", "contracts"]
## Version 5 (avant le lot F3) : pas encore les trois étapes de l'acte 0 en tête ; même suite ensuite.
const REV5_ORDER := ["welcome", "ship", "crane", "quay", "buy", "goulot", "goulot_fix", "parc", "manager", "building", "gate", "mission", "commerce", "contracts"]
## Version 6 (lot F3) : trois étapes de l'acte 0 (ponton, barque à aider, criée) ; lot G1 (version 7) : sept étapes de la Crique
## (ponton, loyer, places, criée, Marcel, mission, Concession). Une partie v6 en cours d'acte 0 recommence la Crique : « a0_boat »
## et « a0_hall » reprennent au loyer.
const REV6_ORDER := ["a0_pontoon", "a0_boat", "a0_hall", "welcome", "ship", "crane", "quay", "buy", "goulot", "goulot_fix", "parc", "manager", "building", "gate", "mission", "commerce", "contracts"]
const REV6_ALIAS := {"a0_boat": "a0_rent", "a0_hall": "a0_rent"}
## Version 7 (lot G1) : sept étapes de la Crique puis la suite d'avant ; lot G2 (version 8) : le premier navire à la main
## (terrassement, quai, accoster, cabane, tamponner, piste, laisser passer) ; « crane » (coup de main) et « gate » (barrière
## express) n'existent plus — un joueur arrêté sur l'une reprend à l'étape suivante.
const REV7_ORDER := ["a0_pontoon", "a0_rent", "a0_places", "a0_hall", "a0_marcel", "a0_mission", "a0_concession", "welcome", "ship", "crane", "quay", "buy", "goulot", "goulot_fix", "parc", "manager", "building", "gate", "mission", "commerce", "contracts"]
const REV7_ALIAS := {"crane": "quay", "gate": "mission"}
## Version 8 (lot G2) : sans la grue mobile ni le parc entre « laisser passer » et la suite (version 9 : « t_crane », « t_yard »).
const REV8_ORDER := ["a0_pontoon", "a0_rent", "a0_places", "a0_hall", "a0_marcel", "a0_mission", "a0_concession", "welcome", "t_platform", "t_quay", "ship", "t_hut", "t_stamp", "t_track", "t_pass", "quay", "buy", "goulot", "goulot_fix", "parc", "manager", "building", "mission", "commerce", "contracts"]


func _from_old_index(old: int, rev: int = 1) -> int:
	var order: Array = REV8_ORDER if rev == 8 else REV7_ORDER if rev == 7 else REV6_ORDER if rev == 6 else (REV5_ORDER if rev == 5 else (REV4_ORDER if rev == 4 else (REV3_ORDER if rev == 3 else (REV2_ORDER if rev == 2 else OLD_ORDER))))
	if old >= order.size():
		return steps.size()
	var want := String(REV6_ALIAS.get(order[old], order[old])) if rev == 6 else (String(REV7_ALIAS.get(order[old], order[old])) if rev == 7 else String(order[old]))
	for i in steps.size():
		if String(steps[i].id) == want:
			return i
	return old
