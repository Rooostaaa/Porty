extends SceneTree
## Lot H2-0 — contrôles géométriques du plan « darses en peigne » (brouillon tests/h2/layout_h2.gd). Hors run_all.
##   godot --headless --path godot --script res://tests/h2/h2_check.gd

const H := preload("res://tests/h2/layout_h2.gd")
const L := preload("res://scripts/world/layout.gd")

var passed := 0
var failed := 0


func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("  ok   ", label)
	else:
		failed += 1
		print("  ÉCHEC ", label)


func _init() -> void:
	print("=== H2-0 : contrôles du plan des darses ===")
	_darse_depths()
	_moored()
	for t in [1, 2, 3]:
		_maneuvers(t)
	_maneuvers_partial()
	_parcels()
	_trucks_engines()
	print("=== H2-0 : %d ok, %d échecs ===" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _darse_depths() -> void:
	check(H.darse_head(0, ["quay1"]) == 14.0 and H.darse_head(0, ["quay1", "quay_ext"]) == 26.0
		and H.darse_head(0, ["quay1", "quay_ext", "dredge1"]) == 42.0 and H.darse_head(0, []) == -6.0,
		"fond de D1 = 14 / 26 / 42 selon quay1, quay_ext, dredge1 (−6 sans rien)")
	check(H.plugs([]).size() == 3 and H.plugs(H.built_for(3)).size() == 0, "bouchons : 3 sans rien, 0 au T3")
	check(not H.on_land(Vector2(-21, 10), ["quay1"]) and H.on_land(Vector2(-21, 20), ["quay1"]),
		"D1 au quai n°1 : eau en z 10, terre (bouchon) en z 20")


## Chaque poste à pleine profondeur contient son plus grand navire (≥ 1 u au fond, à l'entrée, aux murs).
func _moored() -> void:
	var built := H.built_for(3)
	for bi in 4:
		var sz := H.ship_size(H.berth_class(bi, built))
		var p := H.berth_ship_pos(bi, sz.y, built)
		var k := int(H.BERTHS[bi].darse)
		var r := H.darse_rect(k, built)
		var hull := Rect2(p.x - sz.y * 0.5, p.z - sz.x * 0.5, sz.y, sz.x)
		var m_mouth := hull.position.y - r.position.y
		var m_head := r.end.y - hull.end.y
		var m_wall := minf(hull.position.x - r.position.x, r.end.x - hull.end.x)
		check(m_mouth >= 1.0 and m_head >= 1.0 and m_wall >= 0.5,
			"poste %d (%s %.1f × %.1f) : %.1f u à l'entrée, %.1f u au fond, %.1f u au mur le plus proche" % [bi + 1,
			H.berth_class(bi, built), sz.x, sz.y, m_mouth, m_head, m_wall])
	var pm := H.ship_size("panamax")
	var a := H.berth_ship_pos(2, pm.y, built)
	var b := H.berth_ship_pos(3, pm.y, built)
	var gap := (b.x - pm.y * 0.5) - (a.x + pm.y * 0.5)
	var need := pm.y + 2.0 * 2.2
	check(gap >= need, "D3 : deux panamax à quai laissent %.1f u entre les coques (≥ %.1f = largeur + 2 × SWEEP_SIDE)" % [gap, need])


func _obstacles(bi: int, built: Array) -> Array:
	var obs: Array = []
	obs.append_array(Layout.land_polys(built))
	obs.append_array(H.moored_hulls(bi, built))
	return obs


func _maneuvers(tier: int) -> void:
	var built := H.built_for(tier)
	if tier >= 3:
		built.append("seawall")
	for bi in 4:
		if not H.berth_built(bi, built):
			continue
		_maneuver(bi, built, "T%d" % tier)


## T1 en cours : quai n°1 seul (mini, fond 14), puis l'Allongement (caboteur, fond 26).
func _maneuvers_partial() -> void:
	_maneuver(0, ["quay1"], "T1 quai n°1")
	_maneuver(0, ["quay1", "quay_ext"], "T1 allongement")


## Poses du recul (jeu : ShipView) : cap = sens inverse du trajet sur l'arc, tenu au nord sur le dernier tronçon droit.
func _back_poses(path: Array) -> Array:
	var poses := H.path_poses(path, 1.0, true)
	var straight_from := Layout.path_length(path) - (path[-1] as Vector3).distance_to(path[-2])
	var acc := 0.0
	for i in poses.size():
		if i > 0:
			acc += (poses[i].c as Vector2).distance_to(poses[i - 1].c)
		if acc >= straight_from - 0.01:
			poses[i]["fwd"] = Vector2(0, -1)
	return poses


func _maneuver(bi: int, built: Array, tag: String) -> void:
	var cls := H.berth_class(bi, built)
	var sz := H.ship_size(cls)
	var obs := _obstacles(bi, built)
	var worst := 1e9
	var ks := [0, 1, 4, 7] if bi < 2 else [0, 4, 7]
	for k in ks:
		var path := Layout.ship_path_pilot(k, bi)
		var res := H.min_clearance(H.path_poses(path, 1.0, false), sz, obs)
		worst = minf(worst, float(res.d))
		if float(res.d) < 2.0:
			print("       pilotage mouillage %d → poste %d : %.2f u en %s" % [k + 1, bi + 1, float(res.d), str(res.c)])
	check(worst >= 2.0, "%s poste %d (%s) : arrivée, dégagement min %.2f u (≥ 2)" % [tag, bi + 1, cls, worst])
	var bpath := Layout.ship_path_back_in(bi, built, sz.y)
	var bposes := _back_poses(bpath)
	var back := H.min_clearance(bposes.slice(0, bposes.size() - 4), sz, obs)
	var bend := H.min_clearance(bposes.slice(bposes.size() - 1), sz, obs)
	check(float(back.d) >= 2.0 and float(bend.d) >= 1.0, "%s poste %d : recul, dégagement min %.2f u (≥ 2), %.2f u à l'arrivée (≥ 1)%s" % [tag,
		bi + 1, float(back.d), float(bend.d), "" if float(back.d) >= 2.0 else " en " + str(back.c)])
	var dep := Layout.ship_path_depart(bi, sz.y, 3, built)
	var fwd: Array = dep.slice(1)
	var dres := H.min_clearance(H.path_poses(fwd, 1.0, false).slice(4), sz, obs)
	check(float(dres.d) >= 2.0, "%s poste %d : départ en marche avant, dégagement min %.2f u (≥ 2)%s" % [tag, bi + 1,
		float(dres.d), "" if float(dres.d) >= 2.0 else " en " + str(dres.c)])
	# attente de darse : hors des trajets de départ des postes de la darse (coque au point d'attente contre coque au départ)
	var hold := Layout.pilot_gates(bi)[1]
	var ppath := Layout.ship_path_pilot(0 if bi < 2 else 4, bi)
	var hp := H.path_poses(ppath, 1.0, false)
	var hf := Vector2(0, -1)
	for ps in hp:
		if (ps.c as Vector2).distance_to(Vector2(hold.x, hold.z)) < 1.0:
			hf = ps.fwd
	var hull_hold := H.hull_poly(Vector2(hold.x, hold.z), hf, sz)
	var dmin := 1e9
	for bj in 4:
		if Layout.berth_darse(bj) != Layout.berth_darse(bi) or not H.berth_built(bj, built):
			continue
		var dp := Layout.ship_path_depart(bj, sz.y, 3, built)
		var mr := H.min_clearance(H.path_poses(dp.slice(1), 1.0, false), sz, [hull_hold])
		if float(mr.d) < dmin:
			dmin = float(mr.d)
			print("       attente/départ %d : %.2f en %s, attente cap %s" % [bj + 1, dmin, str(mr.c), str(hf)])
	check(dmin >= 2.0 or Layout.berth_darse(bi) == 0, "%s poste %d : attente de darse (%.0f ; %.0f) à %.2f u des départs de la darse (≥ 2)" % [tag, bi + 1, hold.x, hold.z, dmin])
	print("       recul %.0f u" % Layout.path_length(bpath))


func _parcels() -> void:
	var ok_disjoint := true
	for i in H.PARCELS.size():
		for j in range(i + 1, H.PARCELS.size()):
			var inter := Geometry2D.intersect_polygons(PackedVector2Array(H.PARCELS[i].poly), PackedVector2Array(H.PARCELS[j].poly))
			for poly in inter:
				if absf(_area(poly)) > 0.01:
					ok_disjoint = false
	check(ok_disjoint, "parcelles disjointes")
	for t in [1, 2, 3]:
		var built := H.built_for(t)
		var r := H.ropes(H.parcels_owned(t), built)
		var wet := 0
		for s in r.stakes:
			if not H.on_land(s.p, built):
				wet += 1
		var gold := 0
		for s in r.segs:
			if s.gold:
				gold += 1
		check(wet == 0 and (gold > 0) == (t < 3), "T%d : %d piquets, %d sur l'eau (0 attendu) ; %d segments de corde dorée" % [t, r.stakes.size(), wet, gold])
	# chaque case du front tombe dans exactement une parcelle, du palier de son bâtiment
	var bad: Array = []
	var front := ["platform", "quay1", "quay_ext", "crane_mobile", "crane2", "gravel2", "gravel3", "hut", "customs1", "track",
		"scanner1", "scanner2", "berth2", "asphalt", "reefer", "quickmoor", "berth3", "berth4", "rtg", "vacmoor", "lng", "imo", "oog"]
	for bid in front:
		var p: Vector2 = H.LOT_POS[bid]
		var n := 0
		var tier := 0
		for pc in H.PARCELS:
			if Geometry2D.is_point_in_polygon(p, PackedVector2Array(pc.poly)):
				n += 1
				tier = int(pc.tier)
		var want := 1 if H.BUILT_T1.has(bid) else (2 if H.BUILT_T2.has(bid) else 3)
		if bid in ["scanner2", "sts1"]:
			want = 1          # dans l'enceinte de la douane / sur le quai n°1 : parcelle 1, quel que soit le palier d'achat
		if n != 1 or tier > want:
			bad.append("%s (n=%d, parcelle T%d)" % [bid, n, tier])
	check(bad.is_empty(), "cases du front dans une seule parcelle, jamais d'un palier plus haut que leur bâtiment %s" % str(bad))


func _trucks_engines() -> void:
	for t in [1, 2, 3]:
		var ok := true
		for rg in H.stop_ranges(t):
			for x in [float(rg[0]), float(rg[1])]:
				if H.finger_at(x) < 0:
					ok = false
		check(ok and not H.stop_ranges(t).is_empty(), "T%d : arrêts des camions seulement devant un doigt %s" % [t, str(H.stop_ranges(t))])
	# engins : jamais hors de leur doigt, jamais sur la voie des camions
	var built := H.built_for(3)
	var ok2 := true
	for bi in 4:
		var f: Dictionary = H.FINGERS[H.berth_finger(bi)]
		for b in H.blocks_built(built):
			if H.finger_at(H.block_rect(b).get_center().x) != H.berth_finger(bi):
				continue
			var cp := H.crane_pos(bi, 0, 1, "mobile", built)
			var route := H.engine_route_to_block(bi, cp.z, b, H.block_rect(b).get_center().y)
			route.append_array(H.engine_route_to_truck(b, H.block_rect(b).get_center().y, float(f.xc)))
			for p in route:
				if (p as Vector3).x < float(f.x0) or (p as Vector3).x > float(f.x1) or (p as Vector3).z > H.LANE_BAND[0]:
					ok2 = false
					print("       engin hors de son doigt : poste %d, %s" % [bi + 1, str(p)])
	check(ok2, "engins : routes dans leur doigt, jamais sur la voie des camions")
	# tablier (8 u), allée de tablier, blocs : rien ne se chevauche ; blocs dans leur doigt, hors de l'allée centrale
	var ok3 := true
	for bi in 4:
		var xa := H.apron_lane(bi)
		var qx := H.berth_quay_x(bi)
		var tab := Rect2(minf(qx, qx - H.berth_sea(bi).x * 8.0), -6, 8, 48)
		for b in H.BLOCKS:
			var r := H.block_rect(b)
			if H.finger_at(r.get_center().x) != H.berth_finger(bi):
				continue
			var xc := float(H.FINGERS[H.berth_finger(bi)].xc)
			if (xa > r.position.x - 1.2 and xa < r.end.x + 1.2) or r.intersects(tab) or (xc > r.position.x - 1.2 and xc < r.end.x + 1.2):
				ok3 = false
				print("       bloc %s gêne : poste %d, allée de tablier x %.1f, allée centrale x %.1f" % [str(r), bi + 1, xa, xc])
	check(ok3, "tabliers (8 u), allées de tablier et allées centrales à ≥ 1,2 u des blocs")


func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].x * poly[(i + 1) % poly.size()].y - poly[(i + 1) % poly.size()].x * poly[i].y
	return a * 0.5
