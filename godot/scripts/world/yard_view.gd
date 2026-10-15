class_name YardView
extends Node3D
## Parc à conteneurs (MultiMesh par zone, remplissage visible) et tabliers au pied des grues.
## Les lots retenus par la douane clignotent.

const BAY := 4.4
const ROW := 1.5
const TIER := 1.32
const APRON_SLOTS := 8

var zone_mm: Array[MultiMeshInstance3D] = []
var zone_slots: Array = [[], [], [], []]
var apron_mm: MultiMeshInstance3D
var apron_slots: Array = []
var _blink := 0.0
var _shown: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1])
var _empty_share := -1.0
var _pending_n := 0
var _apron_shown := -1
var platform_mode := false            # lot G2 : la plateforme du terre-plein (avant le parc de stockage)
const PENDING_ORANGE := Color(1.0, 0.45, 0.12)


func _ready() -> void:
	for z in 4:
		var mi := MultiMeshInstance3D.new()
		mi.material_override = Assets.tint_material
		add_child(mi)
		zone_mm.append(mi)
	apron_mm = MultiMeshInstance3D.new()
	apron_mm.material_override = Assets.tint_material
	add_child(apron_mm)


func rebuild(sim: PortSim) -> void:
	zone_slots = [[], [], [], []]
	platform_mode = sim.g2 and not sim.built.has("yard")
	for b in Layout.BLOCKS:
		if String(b.b) != "" and not sim.built.has(b.b):
			continue
		if String(b.b) == "" and not sim.built.has("platform"):
			continue          # lot G2 : la friche (pas encore de plateforme)
		var layer: Array = []
		for k in int(b.tiers):
			for i in int(b.bays):
				for j in int(b.rows):
					layer.append(Vector3(float(b.x) + 2.0 + i * BAY, k * TIER, float(b.z) + 0.65 + j * ROW))
		zone_slots[int(b.zone)].append_array(layer)
	# un remplissage « par étages » sur l'ensemble des blocs de la zone
	for z in 4:
		var arr: Array = zone_slots[z]
		arr.sort_custom(func(a: Vector3, c: Vector3) -> bool: return a.y < c.y if not is_equal_approx(a.y, c.y) else (a.x + a.z * 0.37) < (c.x + c.z * 0.37))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true          # (lot G2 : sans couleur d'instance, le rendu de compatibilité OpenGL multiplie la couleur de sommet par 0)
		mm.use_custom_data = true
		var mname := "flatrack" if z == 3 else ("reefer40" if z == 1 else "container40")
		if z == 0 and platform_mode and Assets.exists("container_ok"):
			mname = "container_ok"      # lot G2 : sur la plateforme, des conteneurs de 20' à étiquette (verte : dédouané)
		mm.mesh = Assets.mesh(mname)
		mm.instance_count = arr.size()
		mm.visible_instance_count = 0
		for i in arr.size():
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, arr[i]))
			mm.set_instance_color(i, Color.WHITE)
			mm.set_instance_custom_data(i, _slot_color(sim, z, i, 0.0))
		zone_mm[z].multimesh = mm
	_shown = PackedInt32Array([-1, -1, -1, -1])
	_apron_shown = -1
	_drop_reset()
	_empty_share = -1.0
	# tablier : une rangée de conteneurs derrière chaque poste
	apron_slots = []
	for bi in sim.berths.size():
		var b: Dictionary = Layout.BERTHS[mini(bi, Layout.BERTHS.size() - 1)]
		for k in 2:
			for i in APRON_SLOTS:
				apron_slots.append(Vector3(float(b.x0) + 3.0 + i * 4.3, k * TIER, 0.9))
	var am := MultiMesh.new()
	am.transform_format = MultiMesh.TRANSFORM_3D
	am.use_colors = true
	am.use_custom_data = true
	am.mesh = Assets.mesh("container40")
	am.instance_count = apron_slots.size()
	am.visible_instance_count = 0
	for i in apron_slots.size():
		am.set_instance_transform(i, Transform3D(Basis.IDENTITY, apron_slots[i]))
		am.set_instance_color(i, Color.WHITE)
		am.set_instance_custom_data(i, ShipView.cargo_color(sim, 0, i * 13 + 5))
	apron_mm.multimesh = am


func _slot_color(sim: PortSim, zone: int, i: int, empty_share: float) -> Color:
	if zone == 0 and platform_mode:
		return Color(1, 1, 1)
	if zone == 1:
		return Color(1, 1, 1)
	if zone == 3:
		return Color(1, 1, 1)
	if zone == 2:
		return Assets.color("imo").srgb_to_linear()
	var h := float((i * 2654435761) % 1000) / 1000.0
	if h < empty_share:
		return Assets.color("empty").srgb_to_linear()
	return ShipView.cargo_color(sim, 0, i)


func sync(sim: PortSim, delta: float) -> void:
	_blink += delta
	var zcargo := [[0, 4], [1], [2], [3]]
	for z in 4:
		var mm := zone_mm[z].multimesh
		if mm == null or mm.instance_count == 0:
			continue
		var cap := sim.yard_zone_capacity(z)
		var f := 0.0 if cap <= 0.0 else clampf(sim.yard_stock_zone(z) / cap, 0.0, 1.0)
		var n := roundi(f * mm.instance_count)
		if n != _shown[z]:
			if _shown[z] >= 0 and n > _shown[z]:
				_drop_new(z, mm, zone_slots[z], _shown[z], n)      # lot D : les nouveaux conteneurs se posent
			_shown[z] = n
			mm.visible_instance_count = n
		_drop_step(z, mm, zone_slots[z], delta)
	# part de vides dans la zone standard
	var std_i: int = sim.db.cargo_index["std"]
	var emp_i: int = sim.db.cargo_index["empty"]
	var s_std := sim.yard_pending[std_i] + sim.yard_cleared[std_i]
	var s_emp := sim.yard_pending[emp_i] + sim.yard_cleared[emp_i]
	var share := s_emp / maxf(0.001, s_std + s_emp)
	var mm0 := zone_mm[0].multimesh
	if mm0 != null and absf(share - _empty_share) > 0.05:
		_empty_share = share
		for i in mm0.instance_count:
			mm0.set_instance_custom_data(i, _slot_color(sim, 0, i, share))
	# lots retenus (à inspecter) : les derniers arrivés clignotent
	if mm0 != null and _shown[0] > 0:
		var pend := sim.pending_total() / maxf(0.001, sim.yard_stock())
		var np := mini(_shown[0], ceili(pend * _shown[0]))
		var on := fmod(_blink, 0.8) < 0.4
		for k in maxi(np, _pending_n):
			var i := _shown[0] - 1 - k
			if i < 0:
				break
			var base := _slot_color(sim, 0, i, _empty_share)
			if platform_mode:
				# lot G2 : en attente du tampon — orange (container_wait), dédouané — blanc à étiquette verte (container_ok)
				mm0.set_instance_custom_data(i, PENDING_ORANGE if k < np else base)
				continue
			mm0.set_instance_custom_data(i, base.lerp(Color(1.4, 1.4, 1.4), 0.6) if (k < np and on) else base)
		_pending_n = np
	# tablier
	var am := apron_mm.multimesh
	if am != null and am.instance_count > 0:
		var fa := clampf(sim.apron_stock() / maxf(1.0, sim.apron_capacity()), 0.0, 1.0)
		var na := roundi(fa * am.instance_count)
		if na != _apron_shown:
			if _apron_shown >= 0 and na > _apron_shown:
				_drop_new(4, am, apron_slots, _apron_shown, na)
			_apron_shown = na
			am.visible_instance_count = na
		_drop_step(4, am, apron_slots, delta)


## Emplacements de conteneurs actuellement visibles d'une zone (les engins et les camions vont aux blocs réels).
func visible_slots(z: int) -> Array:
	var arr: Array = zone_slots[z]
	return arr.slice(0, clampi(_shown[z], 0, arr.size()))
## Conteneurs posés (lot D, revue axe 3) : un conteneur qui arrive descend de DROP_H u et glisse de DROP_SLIDE u en
## DROP_TIME s au lieu d'apparaître d'un coup. Au plus DROP_MAX animations à la fois par MultiMesh (un saut de remplissage —
## chargement d'une partie, vitesse ×N — pose le reste d'un coup). Tableaux préalloués : aucune allocation par image.
const DROP_TIME := 0.38
const DROP_H := 2.6
const DROP_SLIDE := 0.9
const DROP_MAX := 12
var _drop_i: Array[PackedInt32Array] = []      # par MultiMesh (4 zones + tablier) : indices en cours de pose (−1 = libre)
var _drop_t: Array[PackedFloat32Array] = []
var drops_started := 0                         # poses animées lancées (tests)


func _drop_reset() -> void:
	_drop_i.clear()
	_drop_t.clear()
	for k in 5:
		var pi := PackedInt32Array()
		pi.resize(DROP_MAX)
		pi.fill(-1)
		var pt := PackedFloat32Array()
		pt.resize(DROP_MAX)
		_drop_i.append(pi)
		_drop_t.append(pt)


## Nouveaux conteneurs visibles [from, to[ du MultiMesh k : les derniers (au plus DROP_MAX) descendent à leur place.
func _drop_new(k: int, mm: MultiMesh, slots: Array, from: int, to: int) -> void:
	if _drop_i.size() != 5:
		_drop_reset()
	for i in range(maxi(from, to - DROP_MAX), to):
		var free := -1
		for s in DROP_MAX:
			if _drop_i[k][s] < 0 or _drop_i[k][s] == i:
				free = s
				break
		if free < 0:
			break
		_drop_i[k][free] = i
		_drop_t[k][free] = 0.0
		drops_started += 1
		var p: Vector3 = slots[i]
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p + Vector3(-DROP_SLIDE, DROP_H, 0)))


func _drop_step(k: int, mm: MultiMesh, slots: Array, delta: float) -> void:
	if _drop_i.size() != 5:
		return
	for s in DROP_MAX:
		var i := _drop_i[k][s]
		if i < 0:
			continue
		if i >= slots.size():
			_drop_i[k][s] = -1
			continue
		var t := minf(1.0, _drop_t[k][s] + delta / DROP_TIME)
		_drop_t[k][s] = t
		var e := 1.0 - (1.0 - t) * (1.0 - t)          # ralentit en se posant
		var p: Vector3 = slots[i]
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p + Vector3(-DROP_SLIDE * (1.0 - e), DROP_H * (1.0 - e), 0)))
		if t >= 1.0:
			_drop_i[k][s] = -1
