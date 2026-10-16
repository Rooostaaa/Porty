extends Control
## Lot H2-0 — plan coté « darses en peigne » vu de dessus, au palier --tier=1|2|3 (brouillon tests/h2/layout_h2.gd) :
## terre et bouchons, darses, postes et navires à quai, grues, parcs, voies des navires (arrivée, recul, glissement, départ)
## avec les coques échantillonnées, fenêtres de croisement, camions, engins, arrière-port reculé, parcelles (brun clair,
## corde blanche, corde dorée de la prochaine, piquets, cadenas et prix).
##   godot --path godot --resolution 1600x1100 res://tests/h2/plan_h2.tscn -- --tier=2 --capture=/chemin.png

const H := preload("res://tests/h2/layout_h2.gd")
const L := preload("res://scripts/world/layout.gd")

const VIEW := Rect2(-64, -60, 274, 196)
const EARTH := Color("#D2C2AC")
const GOLD := Color("#FFC83D")
const C_ARRIVE := Color(0.12, 0.25, 0.75)
const C_BACK := Color(0.0, 0.75, 0.85)
const C_DEPART := Color(0.75, 0.12, 0.5)
const C_TRUCK := Color(1.0, 0.55, 0.1)
const C_ENGINE := Color(0.95, 0.85, 0.1)

var scale_px := 1.0
var origin := Vector2.ZERO
var tier := 1
var built: Array = []
var prices := {1: 500.0}


func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var a := Capture.args()
	tier = clampi(int(a.get("tier", "1")), 1, 3)
	built = H.built_for(tier)
	var tiers = JSON.parse_string(FileAccess.get_file_as_string("res://data/tiers.json"))
	for t in tiers:
		if t.get("req") != null:
			prices[int(t.id)] = float(t.req.money)
	await get_tree().process_frame
	queue_redraw()
	if a.has("capture"):
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(String(a.capture))
		print("CAPTURE ", a.capture)
		get_tree().quit()


func w2s(p: Vector2) -> Vector2:
	return origin + (p - VIEW.position) * scale_px


func v2(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


func _poly(pts, col: Color, outline: Color = Color(0, 0, 0, 0), w: float = 2.0) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(w2s(p))
	if col.a > 0.0 and arr.size() >= 3:
		draw_colored_polygon(arr, col)
	if outline.a > 0.0:
		arr.append(arr[0])
		draw_polyline(arr, outline, w, true)


func _rect(r: Rect2, col: Color, outline: Color = Color(0, 0, 0, 0), w: float = 1.5) -> void:
	draw_rect(Rect2(w2s(r.position), r.size * scale_px), col)
	if outline.a > 0.0:
		draw_rect(Rect2(w2s(r.position), r.size * scale_px), outline, false, w)


func _text(p: Vector2, t: String, size: int, col: Color, outline := true) -> void:
	var f := ThemeDB.fallback_font
	var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := w2s(p) - Vector2(tw * 0.5, -size * 0.35)
	if outline:
		draw_string_outline(f, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(1, 1, 1, 0.85))
	draw_string(f, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _path(pts: Array, col: Color, w: float) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(w2s(v2(p)))
	if arr.size() >= 2:
		draw_polyline(arr, col, w, true)


func _dashed(pts: Array, col: Color, w: float) -> void:
	for i in pts.size() - 1:
		draw_dashed_line(w2s(v2(pts[i])), w2s(v2(pts[i + 1])), col, w, 6.0)


func _hulls(path: Array, size: Vector2, reverse: bool, every: float, col: Color, heading := Vector2.ZERO, zmin := -1e9) -> void:
	var poses := H.path_poses(path, 1.0, reverse, heading)
	var acc := every
	for i in poses.size():
		if (poses[i].c as Vector2).y < zmin:
			continue
		acc += 1.0
		if acc < every and i != poses.size() - 1:
			continue
		acc = 0.0
		var hp := H.hull_poly(poses[i].c, poses[i].fwd, size)
		_poly(hp, Color(col, 0.07), Color(col, 0.55), 1.0)


func _draw() -> void:
	var vs := get_viewport_rect().size
	scale_px = minf(vs.x / VIEW.size.x, vs.y / VIEW.size.y)
	origin = (vs - VIEW.size * scale_px) * 0.5
	draw_rect(Rect2(Vector2.ZERO, vs), Assets.color("water"))
	for gp in L.gulf_polys():
		_poly(gp, Assets.color("grass").darkened(0.25))
	for lp in H.land_polys(built):
		_poly(lp, Assets.color("grass"))
	_poly(L.BREAKWATER, Assets.color("concrete_dark"))
	for gx in range(-60, 216, 12):
		draw_line(w2s(Vector2(gx, VIEW.position.y)), w2s(Vector2(gx, VIEW.end.y)), Color(1, 1, 1, 0.07))
	for gz in range(-60, 140, 12):
		draw_line(w2s(Vector2(VIEW.position.x, gz)), w2s(Vector2(VIEW.end.x, gz)), Color(1, 1, 1, 0.07))
	var owned := H.parcels_owned(tier)
	_draw_roads()
	_draw_zones(owned)
	# parcelles non acquises : terre brun clair, rien d'autre (le plan y montre quand même, en pointillés, ce qui viendra)
	for i in range(owned, H.PARCELS.size()):
		_poly(H.PARCELS[i].poly, Color(EARTH, 0.92))
	_draw_darses()
	_draw_blocks(owned)
	_draw_quays_cranes()
	_draw_ships()
	_draw_trucks_engines()
	_draw_ropes(owned)
	_draw_village()
	_draw_legend()


func _draw_roads() -> void:
	var asphalt := Color(Assets.color("asphalt_dark"), 0.9)
	_rect(Rect2(-132, L.HIGHWAY_Z0, 330, 6), asphalt)
	_rect(Rect2(-24, 54, 6, L.HIGHWAY_Z0 - 54), asphalt)                          # route d'accès (gate z 62)
	if tier >= 2:
		_rect(Rect2(-18, 54, 6, L.HIGHWAY_Z0 - 54), asphalt)
	var xe := H.lane_end_x(tier) + 3.0
	_rect(Rect2(H.LANE_X0, H.LANE_BAND[0], xe - H.LANE_X0, 6), asphalt)          # voie des camions
	# village et route de la logistique (corrigée H2-0 : z 128…134, sous les parkings reculés)
	_rect(Rect2(-78, 66, 6, 72), asphalt)
	_rect(Rect2(-126, 96, 102, 6), asphalt)
	_rect(Rect2(-12, 128, 56, 6), Color(asphalt, 0.7))
	_text(Vector2(16, 131), "route logistique (z 128…134, corrigée)", 10, Color(0.3, 0.3, 0.3))
	if tier >= 2:
		_rect(Rect2(-54, 78, 30, 6), asphalt)                                    # rue des bureaux
	if tier >= 3:
		draw_line(w2s(Vector2(H.RAIL_X[0], H.RAIL_Z)), w2s(Vector2(H.RAIL_X[1], H.RAIL_Z)), Color(0.3, 0.25, 0.25), 3.0)
		_rect(Rect2(158, 54, 6, 18), Color(asphalt, 0.8))                        # liaison gare ↔ allée de F3
		_text(Vector2(150, 70), "gare", 11, Color(0.2, 0.2, 0.2))
	_text(Vector2(-48, 141), "autoroute (inchangée, z 138–144)", 11, Color(0.95, 0.95, 0.95), false)


func _draw_zones(owned: int) -> void:
	for id in H.ZONE_POLYS:
		var z := L.zone_by_id(int(id))
		var poly: Array = H.zone_poly(int(id))
		var zt := int(z.tier)
		var open := zt <= tier
		var col := Assets.color(String(z.ground)) if String(z.ground) != "" else Color(0.8, 0.8, 0.8)
		if open:
			_poly(poly, Color(col, 0.55), Color(0.35, 0.3, 0.55, 0.8), 1.2)
		else:
			_poly(poly, Color(0, 0, 0, 0), Color(1, 1, 1, 0.6), 1.0)
		var r := L.poly_rect(poly)
		var lp := r.get_center()
		if int(id) in [1]:
			lp = Vector2(-42, 30)
		elif int(id) == 10:
			lp = Vector2(156, 44)
		elif int(id) == 6:
			lp = Vector2(86, 44)
		elif int(id) == 7:
			lp = Vector2(86, 41)
		if int(id) in [1, 6, 10, 7, 11, 2]:
			continue           # (étiquettes des zones du front : les bâtiments et les postes parlent d'eux-mêmes)
		_text(lp, "%d %s" % [int(id), String(z.name)], 13, Color(0.15, 0.12, 0.3))


func _draw_darses() -> void:
	for k in H.DARSES.size():
		var d: Dictionary = H.DARSES[k]
		var head := H.darse_head(k, built)
		var x0 := float(d.x0)
		var x1 := float(d.x1)
		if head > H.FRONT_Z:
			# tablier de fond (quai sans poste), musoirs
			_rect(Rect2(x0, H.HEAD_Z, x1 - x0, 4), Color(0.86, 0.84, 0.78))
		else:
			_poly(H.rect_poly(Rect2(x0, H.FRONT_Z, x1 - x0, H.HEAD_Z - H.FRONT_Z)), Color(0, 0, 0, 0), Color(0.2, 0.4, 0.8, 0.7), 1.5)
		_text(Vector2((x0 + x1) * 0.5, H.HEAD_Z - 6), String(d.id) + ("" if head > H.FRONT_Z else " (à creuser)"), 12, Color(0.1, 0.2, 0.5))
		if k == 0:
			for zh in [14.0, 26.0]:
				draw_dashed_line(w2s(Vector2(x0, zh)), w2s(Vector2(x1, zh)), Color(1, 1, 1, 0.8), 1.2, 4.0)
			_text(Vector2(x0 + 8, 12), "fond 14 (Quai n°1)", 9, Color(0.1, 0.2, 0.5))
			_text(Vector2(x0 + 8, 24), "fond 26 (Allongement)", 9, Color(0.1, 0.2, 0.5))
			_text(Vector2(x0 + 8, 36), "fond 42 (Dragage)", 9, Color(0.1, 0.2, 0.5))


func _draw_blocks(owned: int) -> void:
	for b in H.BLOCKS:
		var r := H.block_rect(b)
		var ok := String(b.b) == "" or built.has(String(b.b))
		var col: Color = [Color(0.55, 0.35, 0.6), Color(0.45, 0.75, 0.9), Color(0.9, 0.35, 0.2), Color(0.5, 0.5, 0.5)][int(b.zone)]
		if ok:
			_rect(r, Color(col, 0.85), Color(1, 1, 1, 0.9), 1.0)
		elif H.finger_at(r.get_center().x) >= 0 and int(H.FINGERS[H.finger_at(r.get_center().x)].tier) <= owned:
			_rect(r, Color(0, 0, 0, 0), Color(1, 1, 1, 0.6), 1.0)
	for f in H.FINGERS:
		if int(f.tier) <= tier:
			draw_dashed_line(w2s(Vector2(float(f.xc), -1)), w2s(Vector2(float(f.xc), H.LOAD_EDGE_Z)), Color(C_ENGINE, 0.6), 1.0, 3.0)
	if built.has("lng"):
		draw_circle(w2s(Vector2(179, 28.5)), 3.7 * scale_px, Color(0.92, 0.92, 0.95))
		draw_circle(w2s(Vector2(179, 37)), 3.7 * scale_px, Color(0.92, 0.92, 0.95))
		_rect(Rect2(186, 30.5, 7, 3), Color(0.85, 0.85, 0.8))
		_text(Vector2(179, 43), "GNL", 10, Color(0.2, 0.2, 0.2))
	# vieux quai (F0) : capitainerie et hangar inchangés
	_rect(Rect2(-46.1, 3.4, 6.2, 5.3), Color(0.95, 0.9, 0.8), Color(0.3, 0.3, 0.3), 1.0)
	_rect(Rect2(-45.6, 13.9, 7.2, 10.2), Color(0.85, 0.8, 0.75), Color(0.3, 0.3, 0.3), 1.0)
	_text(Vector2(-42, 1), "capit.", 9, Color(0.2, 0.2, 0.2))


func _draw_quays_cranes() -> void:
	var quay_col := Color(0.9, 0.88, 0.8)
	for bi in H.BERTHS.size():
		var b: Dictionary = H.BERTHS[bi]
		var qx := H.berth_quay_x(bi)
		var s := H.berth_sea(bi)
		var head := H.berth_head(bi, built)
		var ok := H.berth_built(bi, built)
		var x0 := qx - s.x * 8.0
		var r := Rect2(minf(qx, x0), H.FRONT_Z, 8.0, (head if ok else H.HEAD_Z) - H.FRONT_Z)
		if ok:
			_rect(r, quay_col, Color(0.4, 0.4, 0.4), 1.0)
		else:
			_rect(r, Color(0, 0, 0, 0), Color(1, 1, 1, 0.7), 1.0)
		_text(Vector2(qx - s.x * 4.0, H.FRONT_Z - 2.5), "P%d" % (bi + 1), 14, Color(0.1, 0.1, 0.35))
		if ok:
			var cr: Array = H.cranes_for(built)[bi] if bi < H.cranes_for(built).size() else []
			for ci in cr.size():
				var cp := H.crane_pos(bi, ci, cr.size(), String(cr[ci]), built)
				if String(cr[ci]) == "sts":
					_rect(Rect2(cp.x - 3.5, cp.z - 3.0, 7, 6), Color(0.85, 0.2, 0.15), Color.WHITE, 1.0)
				else:
					draw_circle(w2s(v2(cp)), 2.4 * scale_px, Color(0.95, 0.65, 0.1))
	for sb in H.SERVICE_BANKS:
		var d: Dictionary = H.DARSES[int(sb.darse)]
		var head2 := H.darse_head(int(sb.darse), built)
		if head2 <= H.FRONT_Z:
			continue
		var x := float(sb.x)
		var col := Color(0.6, 0.6, 0.62) if String(sb.kind) == "rocks" else Color(0.82, 0.8, 0.74)
		_rect(Rect2(x - 2.0 if float((sb.sea as Vector2).x) > 0 else x, H.FRONT_Z, 2.0, head2 - H.FRONT_Z), col)
	_text(Vector2(-41.5, 34), "service", 9, Color(0.2, 0.2, 0.2))
	if built.has("berth2"):
		_text(Vector2(30.5, 16), "enroch.", 9, Color(0.2, 0.2, 0.2))
	# musoirs (bouts des doigts)
	for x in [-36.0, -6.0, 34.0, 66.0, 106.0, 140.0]:
		draw_circle(w2s(Vector2(x, -6)), 1.2 * scale_px, Color(0.3, 0.3, 0.3))
	draw_circle(w2s(v2(L.LIGHT_GREEN)), 4.0, Color(0.2, 0.8, 0.3))
	draw_circle(w2s(v2(L.LIGHT_RED)), 4.0, Color(0.9, 0.2, 0.2))
	if tier >= 3:
		draw_circle(w2s(v2(H.LIGHT_RED_E)), 4.0, Color(0.9, 0.2, 0.2))
		_poly(L.BREAKWATER_E, Color(0, 0, 0, 0), Color(1, 0.3, 0.3, 0.8), 1.0)
		_text(Vector2(100, -50), "brise-lames est de l'ordre (retiré, voir journal)", 10, Color(0.75, 0.1, 0.1))


func _draw_ships() -> void:
	# fenêtres de croisement
	for c in H.SHIP_CROSSINGS:
		if c.has("rect"):
			if String(c.id) == "est" and tier < 3:
				continue
			_rect(c.rect, Color(0, 0, 0, 0), Color(1, 1, 1, 0.35), 1.0)
			_text((c.rect as Rect2).position + Vector2(8, 3), String(c.id), 10, Color(1, 1, 1, 0.8), false)
	var shown := {}
	for bi in H.BERTHS.size():
		if not H.berth_built(bi, built):
			continue
		var cls := H.berth_class(bi, built)
		var sz := H.ship_size(cls)
		var p := H.berth_ship_pos(bi, sz.y, built)
		_poly(H.hull_poly(Vector2(p.x, p.z), Vector2(0, -1), sz), Color(0.25, 0.3, 0.4, 0.9), Color.WHITE, 1.0)
		_text(Vector2(p.x, p.z), cls, 9, Color(0.1, 0.1, 0.1))
		var dk := int(H.BERTHS[bi].darse)
		if shown.has(dk):
			continue           # une seule manœuvre dessinée par darse (D3 : poste 4)
		shown[dk] = true
		var bj := bi if dk != 2 else 3
		if not H.berth_built(bj, built):
			bj = bi
		var arr := H.ship_path_pilot(0 if dk < 2 else 4, bj)
		_path(arr.slice(maxi(0, arr.size() - 28)), C_ARRIVE, 2.0)
		var back := H.ship_path_back_in(bj, built)
		_dashed(back, C_BACK, 2.5)
		_hulls(back, sz, true, 7.0, C_BACK)
		_hulls(arr.slice(maxi(0, arr.size() - 12)), sz, false, 8.0 if dk < 2 else 12.0, C_ARRIVE, Vector2.ZERO, -24.0 if dk < 2 else -40.0)
		var dep := H.ship_path_depart(bj, sz.y, built)
		_path(dep.slice(1, mini(dep.size(), 24)), C_DEPART, 2.0)
		_hulls(dep.slice(1, mini(dep.size(), 14)), sz, false, 9.0, C_DEPART, Vector2.ZERO, -36.0 if dk < 2 else -60.0)
		var g := H.berth_gate(bj)
		draw_circle(w2s(v2(g)), 4.0, Color.WHITE)
		_text(v2(g) + Vector2(0, -5.5), "attente P%d" % (bj + 1), 9, Color(0.1, 0.1, 0.3))
	# remorqueur (base inchangée)
	draw_circle(w2s(Vector2(-51, -15)), 3.0, Color(0.95, 0.3, 0.2))


func _draw_trucks_engines() -> void:
	# camions : file, gate, boucle jusqu'au bout du palier, arrêt devant le doigt le plus loin, sortie
	var ranges := H.stop_ranges(tier)
	for rg in ranges:
		draw_line(w2s(Vector2(float(rg[0]), H.LOAD_STOP_Z)), w2s(Vector2(float(rg[1]), H.LOAD_STOP_Z)), Color(C_TRUCK, 0.9), 4.0)
	var last: Array = ranges[-1]
	var sx := (float(last[0]) + float(last[1])) * 0.5
	var r_in := H.truck_route_in(L.ROAD_IN_X[0], sx, tier)
	r_in.push_front(Vector3(L.ROAD_IN_X[0], 0, H.QUEUE_Z0 + 12))
	_path(r_in, C_TRUCK, 1.6)
	_path(H.truck_route_out(sx), Color(0.85, 0.3, 0.0), 1.6)
	draw_circle(w2s(v2(H.GATE)), 3.0, Color.WHITE)
	_text(v2(H.GATE) + Vector2(5, 0), "gate", 10, Color(0.1, 0.1, 0.1))
	# engins : un aller-retour par poste (tablier → bloc → bord de chargement)
	for bi in H.BERTHS.size():
		if not H.berth_built(bi, built):
			continue
		var fi := H.berth_finger(bi)
		var blocks := []
		for b in H.blocks_built(built):
			if H.finger_at(H.block_rect(b).get_center().x) == fi and int(b.zone) == 0:
				blocks.append(b)
		if blocks.is_empty():
			continue
		var b0: Dictionary = blocks[bi % blocks.size()]
		var cp := H.crane_pos(bi, 0, 1, "mobile", built)
		var zs := H.block_rect(b0).get_center().y
		_path(H.engine_route_to_block(bi, cp.z + 4.0, b0, zs), C_ENGINE, 1.6)
		_path(H.engine_route_to_truck(b0, zs, float(H.FINGERS[fi].xc) + 4.0), Color(C_ENGINE, 0.7), 1.2)


func _draw_ropes(owned: int) -> void:
	var r := H.ropes(owned, built)
	for s in r.segs:
		var col: Color = GOLD if s.gold else Color(1, 1, 1, 0.95)
		draw_line(w2s(s.a), w2s(s.b), Color(0.25, 0.2, 0.1, 0.6), 4.5 if s.gold else 3.2)
		draw_line(w2s(s.a), w2s(s.b), col, 2.6 if s.gold else 1.6)
	for st in r.stakes:
		draw_circle(w2s(st.p), 2.6, Color(0.42, 0.28, 0.15))
		draw_circle(w2s(st.p), 1.5, GOLD if st.gold else Color(0.85, 0.75, 0.6))
	for i in H.PARCELS.size():
		var pc: Dictionary = H.PARCELS[i]
		var bp: Vector2 = pc.badge
		if i < owned:
			_text(bp + Vector2(0, 28), "Parcelle %d ✓  %s" % [int(pc.id), String(pc.name)], 11, Color(0.1, 0.35, 0.1))
			continue
		var nxt := i == owned
		var rad := (32.0 if nxt else 26.0)
		var c := w2s(bp)
		draw_circle(c, rad, Color(0.2, 0.15, 0.05, 0.4))
		draw_circle(c, rad - 2.0, Color("#F2A93B") if nxt else Color("#4B4FA8"))
		# cadenas : anse et corps
		draw_arc(c + Vector2(0, -4), 8.0, PI, TAU, 16, Color.WHITE, 3.0, true)
		draw_rect(Rect2(c + Vector2(-11, -4), Vector2(22, 16)), Color.WHITE)
		var price := float(prices.get(int(pc.tier), 0.0)) if int(pc.id) > 1 else 500.0
		_text(bp + Vector2(0, rad / scale_px + 3.5), Fmt.money(price), 18 if nxt else 15, Color("#7A4A00") if nxt else Color("#2B2E70"))
		_text(bp + Vector2(0, rad / scale_px + 8.5), "Parcelle %d — %s" % [int(pc.id), String(pc.name)], 10, Color(0.2, 0.15, 0.1))


func _draw_village() -> void:
	for p in L.PROPS:
		var m := String(p.m)
		if m.begins_with("house") or m == "shop":
			var pp: Array = p.p
			_rect(Rect2(float(pp[0]) - 3.0, float(pp[2]) - 3.0, 6, 6), Color(0.9, 0.75, 0.65), Color(0.4, 0.3, 0.3), 1.0)
	_text(Vector2(-95, 106), "village (inchangé)", 10, Color(0.25, 0.2, 0.2))


func _draw_legend() -> void:
	var f := ThemeDB.fallback_font
	var y := 24.0
	draw_rect(Rect2(6, 4, 820, 162), Color(0, 0, 0, 0.45))
	var lines := [
		["Plan H2-0 « darses en peigne » — palier T%d (brouillon, rien dans le jeu) — grille 12 u, mer en haut" % tier, Color.WHITE],
		["arrivée (marche avant)", C_ARRIVE.lightened(0.45)], ["recul (marche arrière ≤ 2,4 u/s), coques échantillonnées", C_BACK],
		["départ (marche avant)", C_DEPART.lightened(0.4)], ["camions (boucle, arrêts devant les doigts en épais)", C_TRUCK],
		["engins (allée de tablier, allée de tête z −1, allée centrale, bord de chargement)", C_ENGINE],
		["corde blanche : domaine et parcelles à vendre ; corde dorée : la prochaine", GOLD],
	]
	for ln in lines:
		draw_string_outline(f, Vector2(14, y), String(ln[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, Color(0, 0, 0, 0.7))
		draw_string(f, Vector2(14, y), String(ln[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, ln[1])
		y += 22.0
