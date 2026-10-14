extends Control
## Plan coté vu de dessus (docs/PLAN_COTE.md) : terrain, zones, cases des bâtiments, voies des camions, chenal,
## mouillage, trajets des navires. Sert à valider le plan d'un coup d'œil (capture).
##   godot --path godot res://tests/plan_view.tscn -- --capture=C:/…/plan.png [--tier=3]

const VIEW := Rect2(-140, -140, 340, 300)     # monde (x, z) dessiné
var scale_px := 1.0
var origin := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	queue_redraw()
	var a := Capture.args()
	if a.has("capture"):
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(String(a.capture))
		print("CAPTURE ", a.capture)
		get_tree().quit()


func w2s(p: Vector2) -> Vector2:
	return origin + (p - VIEW.position) * scale_px


func _poly(pts: Array, col: Color, outline: Color = Color(0, 0, 0, 0), w: float = 2.0) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(w2s(p))
	if col.a > 0.0:
		draw_colored_polygon(arr, col)
	if outline.a > 0.0:
		arr.append(arr[0])
		draw_polyline(arr, outline, w, true)


func _text(p: Vector2, t: String, size: int, col: Color) -> void:
	var f := ThemeDB.fallback_font
	var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(f, w2s(p) - Vector2(tw * 0.5, -size * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _path(pts: Array, col: Color, w: float) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(w2s(Vector2((p as Vector3).x, (p as Vector3).z)))
	draw_polyline(arr, col, w, true)


func _draw() -> void:
	var vs := get_viewport_rect().size
	scale_px = minf(vs.x / VIEW.size.x, vs.y / VIEW.size.y)
	origin = (vs - VIEW.size * scale_px) * 0.5
	draw_rect(Rect2(Vector2.ZERO, vs), Assets.color("water"))
	_poly(Layout.COAST, Assets.color("grass"))
	_poly(Layout.RECLAIM, Color(Assets.color("sand"), 0.45), Color.WHITE, 1.5)
	_poly(Layout.BREAKWATER, Assets.color("concrete_dark"))
	_poly(Layout.BREAKWATER_E, Color(Assets.color("concrete_dark"), 0.7), Color.WHITE, 1.0)      # lot D : palier 3
	# grille de 12 u
	for gx in range(-132, 200, 12):
		draw_line(w2s(Vector2(gx, VIEW.position.y)), w2s(Vector2(gx, VIEW.end.y)), Color(1, 1, 1, 0.07))
	for gz in range(-132, 168, 12):
		draw_line(w2s(Vector2(VIEW.position.x, gz)), w2s(Vector2(VIEW.end.x, gz)), Color(1, 1, 1, 0.07))
	# routes et voie des camions
	for g in Layout.GROUNDS:
		if String(g.type).begins_with("road"):
			var r: Array = g.r
			draw_rect(Rect2(w2s(Vector2(r[0], r[1])), Vector2(float(r[2]) - float(r[0]), float(r[3]) - float(r[1])) * scale_px), Color(Assets.color("asphalt_dark"), 0.85))
	# zones
	for z in Layout.ZONES:
		var poly := Layout.zone_poly(z)
		var col := Assets.color(String(z.ground)) if String(z.ground) != "" else Color(1, 1, 1, 0.0)
		_poly(poly, Color(col, 0.75), Color(1, 0.85, 0.2), 2.0)
		var r := Layout.poly_rect(poly)
		_text(r.get_center() + Vector2(0, -r.size.y * 0.32), "%d %s (T%d)" % [int(z.id), z.name, int(z.tier)], 13, Color(0.1, 0.1, 0.2))
	# quais
	for bi in Layout.BERTHS.size():
		var b: Dictionary = Layout.BERTHS[bi]
		draw_rect(Rect2(w2s(Vector2(b.x0, -6.5)), Vector2(float(b.x1) - float(b.x0), 6.5) * scale_px), Color(0.9, 0.88, 0.8))
		_text(Vector2(Layout.berth_center(bi), -3.2), "quai %d" % (bi + 1), 11, Color(0.2, 0.2, 0.3))
	# cases des bâtiments
	for bid in Layout.LOTS:
		var rr := Layout.lot_rect(bid)
		draw_rect(Rect2(w2s(rr.position), rr.size * scale_px), Color(1, 1, 1, 0.35))
		draw_rect(Rect2(w2s(rr.position), rr.size * scale_px), Color(0.25, 0.2, 0.5), false, 1.5)
		_text(rr.get_center(), bid, 10, Color(0.2, 0.1, 0.4))
	# chenal, mouillage, trajets des navires
	_poly(Layout.channel_poly(), Color(0.1, 0.3, 0.7, 0.25), Color(1, 1, 1, 0.8), 1.5)
	for k in 12:
		var a := Layout.anchor_pos(k)
		draw_circle(w2s(Vector2(a.x, a.z)), 4.0, Color(1, 0.3, 0.3))
		_text(Vector2(a.x, a.z - 4), str(k + 1), 11, Color.WHITE)
	_path(Layout.ship_path_pilot(0, 0), Color(0.1, 0.2, 0.6), 2.0)
	_path(Layout.ship_path_pilot(1, 1), Color(0.1, 0.2, 0.6), 2.0)
	_path(Layout.ship_path_pilot(2, 3), Color(0.1, 0.2, 0.6), 2.0)
	_path(Layout.ship_path_depart(0, 8.0, 1), Color(0.6, 0.1, 0.4), 2.0)
	_path(Layout.ship_path_depart(3, 8.8), Color(0.6, 0.1, 0.4), 2.0)
	_path(Layout.ship_path_pilot(4, 2), Color(0.1, 0.2, 0.6), 2.0)
	_path(Layout.ship_path_depart(1, 8.0, 3), Color(0.6, 0.1, 0.4), 2.0)
	draw_circle(w2s(Vector2(Layout.LIGHT_GREEN_E.x, Layout.LIGHT_GREEN_E.z)), 5.0, Color(0.2, 0.8, 0.3))
	draw_circle(w2s(Vector2(Layout.LIGHT_RED_E.x, Layout.LIGHT_RED_E.z)), 5.0, Color(0.9, 0.2, 0.2))
	var sw_a: Vector3 = Layout.SLIPWAY.from
	var sw_b: Vector3 = Layout.SLIPWAY.to
	draw_line(w2s(Vector2(sw_a.x, sw_a.z)), w2s(Vector2(sw_b.x, sw_b.z)), Color(0.85, 0.85, 0.8), 3.4 * scale_px)
	for j in Layout.JETTIES:
		draw_rect(Rect2(w2s(j.c - j.size * 0.5), j.size * scale_px), Color(0.85, 0.85, 0.8))
	draw_line(w2s(Vector2(Layout.RAIL_X[0], Layout.RAIL_Z)), w2s(Vector2(Layout.RAIL_X[1], Layout.RAIL_Z)), Color(0.35, 0.3, 0.3), 2.0)
	draw_circle(w2s(Vector2(Layout.LIGHT_GREEN.x, Layout.LIGHT_GREEN.z)), 5.0, Color(0.2, 0.8, 0.3))
	draw_circle(w2s(Vector2(Layout.LIGHT_RED.x, Layout.LIGHT_RED.z)), 5.0, Color(0.9, 0.2, 0.2))
	# camions : arrivée, entrée, boucle, sortie
	var tc := Color(1.0, 0.55, 0.1)
	_path(Layout.truck_route_arrive(Layout.ROAD_IN_X[0], Vector3(Layout.ROAD_IN_X[0], 0, Layout.QUEUE_Z0)), tc, 2.0)
	_path(Layout.truck_route_in(Layout.ROAD_IN_X[0], -10.0, 3), tc, 2.0)
	_path(Layout.truck_route_out(-10.0, 3, false), Color(0.9, 0.3, 0.0), 2.0)
	draw_circle(w2s(Vector2(Layout.GATE.x, Layout.GATE.z)), 3.0, Color.WHITE)
	_text(Vector2(-60, 150), "Plan coté « La baie et le terre-plein » — grille 12 u, x vers l'est, z vers le sud (mer en haut)", 14, Color.WHITE)
