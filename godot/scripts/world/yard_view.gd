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
	for b in Layout.BLOCKS:
		if String(b.b) != "" and not sim.built.has(b.b):
			continue
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
		mm.use_custom_data = true
		mm.mesh = Assets.mesh("flatrack" if z == 3 else ("reefer40" if z == 1 else "container40"))
		mm.instance_count = arr.size()
		mm.visible_instance_count = 0
		for i in arr.size():
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, arr[i]))
			mm.set_instance_custom_data(i, _slot_color(sim, z, i, 0.0))
		zone_mm[z].multimesh = mm
	_shown = PackedInt32Array([-1, -1, -1, -1])
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
	am.use_custom_data = true
	am.mesh = Assets.mesh("container40")
	am.instance_count = apron_slots.size()
	am.visible_instance_count = 0
	for i in apron_slots.size():
		am.set_instance_transform(i, Transform3D(Basis.IDENTITY, apron_slots[i]))
		am.set_instance_custom_data(i, ShipView.cargo_color(sim, 0, i * 13 + 5))
	apron_mm.multimesh = am


func _slot_color(sim: PortSim, zone: int, i: int, empty_share: float) -> Color:
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
			_shown[z] = n
			mm.visible_instance_count = n
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
			mm0.set_instance_custom_data(i, base.lerp(Color(1.4, 1.4, 1.4), 0.6) if (k < np and on) else base)
		_pending_n = np
	# tablier
	var am := apron_mm.multimesh
	if am != null and am.instance_count > 0:
		var fa := clampf(sim.apron_stock() / maxf(1.0, sim.apron_capacity()), 0.0, 1.0)
		am.visible_instance_count = roundi(fa * am.instance_count)


## Point de référence d'un bloc (pour les engins).
func random_yard_point(rng: RandomNumberGenerator) -> Vector3:
	var arr: Array = zone_slots[0]
	if arr.is_empty():
		return Layout.YARD_CENTER
	var p: Vector3 = arr[rng.randi_range(0, mini(arr.size(), 200) - 1)]
	return Vector3(p.x, 0, p.z + ROW * 0.5 + 0.8)
