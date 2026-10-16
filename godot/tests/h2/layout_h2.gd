extends RefCounted
## Lot H2-0 — BROUILLON du plan « darses en peigne » (docs/ORDRE_H2_DARSES.md § 1–2, cotes corrigées au journal).
## Le jeu ne lit pas ce fichier : il est lu par tests/h2/plan_h2.gd (vue de dessus), tests/h2/iso_h2.gd (maquette 3D) et
## tests/h2/h2_check.gd (contrôles). Au lot H2-a, son contenu passe dans Layout (mêmes noms, sans le suffixe).
## Repère du jeu : x vers l'est, z vers le sud, mer en z < 0. Ce qui ne change pas est lu dans Layout.

const L := preload("res://scripts/world/layout.gd")

# ---------------------------------------------------------------------------------------------------------------------
# Front de mer, darses, doigts
# ---------------------------------------------------------------------------------------------------------------------
const FRONT_Z := -6.0
const HEAD_Z := 42.0                 # mur de fond des darses (eau jusqu'à 42, tablier de fond 42…46)
const HEAD_APRON_Z := 46.0
## Recul de l'arrière-port (voie des camions, douane, gate, file, bureaux, parkings) : appliqué à la main aux littéraux.
const BACK_DZ := 18.0
const TERMINAL_X := [-48.0, 186.0]

## Darses : x0…x1, fond selon ce qui est bâti (le plus profond l'emporte ; rien de bâti = pas creusée, fond = FRONT_Z).
const DARSES := [
	{"id": "D1", "x0": -36.0, "x1": -6.0, "head": {"quay1": 14.0, "quay_ext": 26.0, "dredge1": 42.0}},
	{"id": "D2", "x0": 34.0, "x1": 66.0, "head": {"berth2": 42.0}},
	{"id": "D3", "x0": 106.0, "x1": 140.0, "head": {"berth3": 42.0}},
]
## Postes à quai (ordre de PortSim.berths) : darse, point du bord d'eau à l'entrée de la darse, normale vers l'eau.
const BERTHS := [
	{"darse": 0, "quay": Vector2(-6, -6), "sea": Vector2(-1, 0)},     # poste 1 — D1, berge est (doigt F1)
	{"darse": 1, "quay": Vector2(66, -6), "sea": Vector2(-1, 0)},     # poste 2 — D2, berge est (doigt F2)
	{"darse": 2, "quay": Vector2(106, -6), "sea": Vector2(1, 0)},     # poste 3 — D3, berge ouest (doigt F2)
	{"darse": 2, "quay": Vector2(140, -6), "sea": Vector2(-1, 0)},    # poste 4 — D3, berge est (doigt F3)
]
## Clé de chantier de chaque poste (comme Diorama.berth_key).
const BERTH_KEYS := ["quay1", "berth2", "berth3", "berth4"]
## Berges sans poste : quais de service (remorqueur, avitaillement, barges) ou enrochement.
const SERVICE_BANKS := [
	{"darse": 0, "x": -36.0, "sea": Vector2(1, 0), "kind": "service"},     # F0 : ponton d'avitaillement, remorqueur n°2
	{"darse": 1, "x": 34.0, "sea": Vector2(1, 0), "kind": "rocks"},        # F1 côté D2 : enrochement, quai de service
]
## Doigts : parc, allée centrale (engins), palier d'ouverture.
const FINGERS := [
	{"id": "F1", "x0": -6.0, "x1": 34.0, "xc": 16.0, "tier": 1},
	{"id": "F2", "x0": 66.0, "x1": 106.0, "xc": 86.0, "tier": 2},
	{"id": "F3", "x0": 140.0, "x1": 186.0, "xc": 161.5, "tier": 3},
]
const F0 := {"x0": -48.0, "x1": -36.0}     # vieux quai (capitainerie, hangar) : inchangé
## Allée de tête des engins (à travers chaque doigt, entre les musoirs et les blocs) et bord de chargement (camions).
const HEAD_AISLE_Z := -1.0
const LOAD_EDGE_Z := 46.6
## Correction H2-0 : les cotes de l'ordre (grue mobile 1,6, allée 3,4) étaient des z absolus du jeu actuel ; comptées depuis
## le bord d'eau (z −6), elles font 4,4 (grue mobile), 3 (STS), 9,4 (allée de tablier) et 6,9 (conteneurs du tablier).
const APRON_LANE_OFF := 9.4
const APRON_BOX_OFF := 6.9

## Continent : côte de Layout.COAST jusqu'au vieux quai, puis le front droit z −6 découpé des trois darses à pleine longueur
## (les darses pas encore creusées sont rebouchées par land_polys) ; la baie est n'existe plus (terre dès le départ).
const COAST := [
	Vector2(-132, 168), Vector2(-132, 60), Vector2(-112, 52), Vector2(-94, 48),
	Vector2(-92, 24), Vector2(-90, 0), Vector2(-86, -16), Vector2(-80, -30), Vector2(-72, -42), Vector2(-64, -44),
	Vector2(-58, -38), Vector2(-56, -26), Vector2(-56, -14), Vector2(-52, -8), Vector2(-48, -6),
	Vector2(-36, -6), Vector2(-36, 42), Vector2(-6, 42), Vector2(-6, -6),
	Vector2(34, -6), Vector2(34, 42), Vector2(66, 42), Vector2(66, -6),
	Vector2(106, -6), Vector2(106, 42), Vector2(140, 42), Vector2(140, -6),
	Vector2(186, -6), Vector2(186, 168),
]
## Correction H2-0 (voir journal) : **plus de brise-lames est** au T3. Avec lui (z −44), il ne reste que 36 u d'eau devant
## l'entrée des darses : un panamax (45,2 u) ne peut s'y aligner sur l'axe de D3. La passe est s'ouvre en grand entre la
## tête du brise-lames ouest (42 ; −44) et l'angle du doigt F3 (186 ; −6) ; feu rouge à l'angle de F3.
const LIGHT_RED_E := Vector3(187.5, -1, -7.5)


static func darse_head(k: int, built: Array) -> float:
	var h := FRONT_Z
	var heads: Dictionary = DARSES[k].head
	for key in heads:
		if built.has(key):
			h = maxf(h, float(heads[key]))
	return h


static func darse_axis_x(k: int) -> float:
	return (float(DARSES[k].x0) + float(DARSES[k].x1)) * 0.5


static func darse_rect(k: int, built: Array) -> Rect2:
	var d: Dictionary = DARSES[k]
	return Rect2(float(d.x0), FRONT_Z, float(d.x1) - float(d.x0), darse_head(k, built) - FRONT_Z)


static func rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## Bouchons : la partie non creusée de chaque darse (terre).
static func plugs(built: Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for k in DARSES.size():
		var h := darse_head(k, built)
		if h < HEAD_Z:
			var d: Dictionary = DARSES[k]
			out.append(rect_poly(Rect2(float(d.x0), h, float(d.x1) - float(d.x0), HEAD_Z - h)))
	return out


## Terre (continent + bouchons + brise-lames ouest). La côte se lit toujours à partir de `built`.
static func land_polys(built: Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = [PackedVector2Array(COAST), PackedVector2Array(L.BREAKWATER)]
	out.append_array(plugs(built))
	return out


static func on_land(p: Vector2, built: Array) -> bool:
	for poly in land_polys(built):
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


static func finger_at(x: float) -> int:
	for i in FINGERS.size():
		if x >= float(FINGERS[i].x0) and x <= float(FINGERS[i].x1):
			return i
	return -1


## Doigt qui porte le poste bi (son parc le sert).
static func berth_finger(bi: int) -> int:
	var b: Dictionary = BERTHS[bi]
	return finger_at(float((b.quay as Vector2).x) - float((b.sea as Vector2).x) * 2.0)


# ---------------------------------------------------------------------------------------------------------------------
# Postes orientés
# ---------------------------------------------------------------------------------------------------------------------
## Grues du poste 1 (z) : grue mobile, deuxième grue, portique STS. Correction H2-0 : 4/14/26 de l'ordre → −1/9/22 : la
## deuxième grue peut s'acheter avant l'Allongement (fond 14) ; elle doit tenir sur le quai n°1 (z −6…14).
const CRANE_SLOTS := {0: [-1.0, 9.0, 22.0]}
const CRANE_BACK := {"mobile": 4.4, "sts": 3.0}
const SHIP_SCALE := {"mini": 1.0, "coaster": 1.0, "feeder": 0.94, "panamax": 0.78}
const SHIP_MODELS := {"mini": "ship_mini", "coaster": "ship_coaster", "feeder": "ship_feeder", "panamax": "ship_panamax"}
const DEPTH_CLASS := {1: "mini", 2: "coaster", 3: "feeder", 4: "panamax"}
const REVERSE_V := 2.4


static func ship_size(cls: String) -> Vector2:
	var m := Assets.meta(String(SHIP_MODELS.get(cls, "ship_feeder")))
	var s := float(SHIP_SCALE.get(cls, 1.0))
	return Vector2(float(m.get("length", 30.0)) * s, float(m.get("width", 8.0)) * s)


## Profondeur du poste bi selon ce qui est bâti (comme la simulation : quay1 1, quay_ext 2, dredge1 3 ; berth2 3 ; 3–4 : 4).
static func berth_depth(bi: int, built: Array) -> int:
	if bi == 0:
		return 3 if built.has("dredge1") else (2 if built.has("quay_ext") else 1)
	return 3 if bi == 1 else 4


static func berth_class(bi: int, built: Array) -> String:
	return String(DEPTH_CLASS[berth_depth(bi, built)])


static func berth_built(bi: int, built: Array) -> bool:
	return built.has(String(BERTH_KEYS[bi]))


static func berth_sea(bi: int) -> Vector2:
	return BERTHS[bi].sea


static func berth_quay_x(bi: int) -> float:
	return (BERTHS[bi].quay as Vector2).x


static func berth_axis_x(bi: int) -> float:
	return darse_axis_x(int(BERTHS[bi].darse))


static func berth_head(bi: int, built: Array) -> float:
	return darse_head(int(BERTHS[bi].darse), built)


static func berth_mid_z(bi: int, built: Array) -> float:
	return (FRONT_Z + berth_head(bi, built)) * 0.5


## Centre d'un navire amarré (ligne de flottaison).
static func berth_ship_pos(bi: int, width: float, built: Array) -> Vector3:
	var x := berth_quay_x(bi) + berth_sea(bi).x * (width * 0.5 + 0.6)
	return Vector3(x, 0, berth_mid_z(bi, built))


## Cap d'un navire amarré : étrave au nord (vers le large) pour tous (repère des navires : +X à 0, atan2(-dz, dx)).
static func berth_yaw(_bi: int) -> float:
	return PI * 0.5


## Point d'attente final (« gate ») : là où le navire s'arrête avant de reculer. D1, D2 (passe ouest) : sur la voie
## d'arrivée z −20, cap à l'est, REV_R u à l'est de l'axe ; il recule en quart de cercle (la poupe entre dans la darse, le
## remorqueur à la proue fait pivoter l'étrave vers le nord), puis tout droit sur l'axe. D3 (passe est) : sur l'axe, cap au
## nord, après un quart de tour à droite depuis la voie d'arrivée z −26 ; il recule tout droit.
const ARRIVE_W_Z := -20.0
const REV_R := 10.0
const D3_GATE := Vector2(123, -36)


static func berth_gate(bi: int) -> Vector3:
	var dk := int(BERTHS[bi].darse)
	if dk == 2:
		return Vector3(D3_GATE.x, 0, D3_GATE.y)
	return Vector3(darse_axis_x(dk) + REV_R, 0, ARRIVE_W_Z)


## Cap du navire au point d'attente (vecteur x, z).
static func berth_gate_heading(bi: int) -> Vector2:
	return Vector2(0, -1) if int(BERTHS[bi].darse) == 2 else Vector2(1, 0)


static func crane_pos(bi: int, ci: int, n: int, kind: String, built: Array) -> Vector3:
	var z := 0.0
	var slots: Array = CRANE_SLOTS.get(bi, [])
	if ci < slots.size() and n <= slots.size():
		z = float(slots[ci])
	else:
		var h := berth_head(bi, built)
		z = FRONT_Z + (h - FRONT_Z) * (float(ci) + 0.5) / float(n)
	var x := berth_quay_x(bi) - berth_sea(bi).x * float(CRANE_BACK.get(kind, 1.6))
	return Vector3(x, 0, z)


## Rotation Y d'une grue : son −z local vers l'eau.
static func crane_ry(bi: int) -> float:
	var s := berth_sea(bi)
	return atan2(-s.x, -s.y)


static func apron_lane(bi: int) -> float:
	return berth_quay_x(bi) - berth_sea(bi).x * APRON_LANE_OFF


# ---------------------------------------------------------------------------------------------------------------------
# Parcs (blocs « dir z » : baies de 4,4 u le long de z, rangées de 1,5 u le long de x ; coin x, z)
# ---------------------------------------------------------------------------------------------------------------------
const BAY := 4.4
const ROW := 1.5
## Correction H2-0 : l'allée de tablier (9,4 u du bord) passe devant les blocs : F1 x 5…14 et 18…27 (allée centrale x 16) ;
## F2 en blocs de 5 rangées x 77…84,5 et 87,5…95 (allée x 86, entre les deux allées de tablier 75,4 et 96,6) ; F3 x 151…160
## et 163…172 (allée x 161,5).
const BLOCKS := [
	{"b": "", "zone": 0, "x": 5.0, "z": 2.0, "bays": 4, "rows": 6, "tiers": 3},
	{"b": "", "zone": 0, "x": 18.0, "z": 2.0, "bays": 4, "rows": 6, "tiers": 3},
	{"b": "gravel2", "zone": 0, "x": 5.0, "z": 22.0, "bays": 4, "rows": 6, "tiers": 3},
	{"b": "gravel3", "zone": 0, "x": 18.0, "z": 22.0, "bays": 4, "rows": 6, "tiers": 3},
	{"b": "asphalt", "zone": 0, "x": 77.0, "z": 2.0, "bays": 4, "rows": 5, "tiers": 4},
	{"b": "asphalt", "zone": 0, "x": 87.5, "z": 2.0, "bays": 4, "rows": 5, "tiers": 4},
	{"b": "asphalt", "zone": 0, "x": 77.0, "z": 18.0, "bays": 4, "rows": 5, "tiers": 4},
	{"b": "asphalt", "zone": 0, "x": 87.5, "z": 18.0, "bays": 4, "rows": 5, "tiers": 4},
	{"b": "reefer", "zone": 1, "x": 77.0, "z": 36.0, "bays": 1, "rows": 5, "tiers": 2},
	{"b": "reefer", "zone": 1, "x": 87.5, "z": 36.0, "bays": 1, "rows": 5, "tiers": 2},
	{"b": "rtg", "zone": 0, "x": 151.0, "z": 2.0, "bays": 9, "rows": 6, "tiers": 5},
	{"b": "rtg", "zone": 0, "x": 163.0, "z": 2.0, "bays": 9, "rows": 6, "tiers": 5},
	{"b": "imo", "zone": 2, "x": 174.0, "z": 4.0, "bays": 2, "rows": 6, "tiers": 2},
	{"b": "oog", "zone": 3, "x": 174.0, "z": 16.0, "bays": 2, "rows": 3, "tiers": 1},
]


static func block_rect(b: Dictionary) -> Rect2:
	return Rect2(float(b.x), float(b.z), float(b.rows) * ROW, float(b.bays) * BAY)


## Emplacements (x, étage, z) d'un bloc : conteneurs tournés de 90° (longueur le long de z).
static func block_slots(b: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k in int(b.tiers):
		for i in int(b.bays):
			for j in int(b.rows):
				out.append(Vector3(float(b.x) + 0.75 + j * ROW, k * 1.32, float(b.z) + 2.2 + i * BAY))
	return out


static func blocks_built(built: Array) -> Array:
	var out: Array = []
	for b in BLOCKS:
		if String(b.b) == "" or built.has(String(b.b)):
			out.append(b)
	return out


## Engin : du tablier (au pied d'une grue en z_c) au bord de bloc (z_s) par l'allée de tablier, l'allée de tête et l'allée
## centrale de son doigt. Un engin ne quitte jamais son doigt.
static func engine_route_to_block(bi: int, z_c: float, b: Dictionary, z_s: float) -> Array[Vector3]:
	var xa := apron_lane(bi)
	var xc := float(FINGERS[berth_finger(bi)].xc)
	var r := block_rect(b)
	var xe := r.end.x + 0.6 if r.end.x <= xc else r.position.x - 0.6
	return [Vector3(xa, 0, z_c), Vector3(xa, 0, HEAD_AISLE_Z), Vector3(xc, 0, HEAD_AISLE_Z), Vector3(xc, 0, z_s), Vector3(xe, 0, z_s)]


## Engin : du bloc au bord de chargement devant le camion arrêté (x_stop).
static func engine_route_to_truck(b: Dictionary, z_s: float, x_stop: float) -> Array[Vector3]:
	var xc := float(FINGERS[finger_at(block_rect(b).get_center().x)].xc)
	var r := block_rect(b)
	var xe := r.end.x + 0.6 if r.end.x <= xc else r.position.x - 0.6
	return [Vector3(xe, 0, z_s), Vector3(xc, 0, z_s), Vector3(xc, 0, LOAD_EDGE_Z), Vector3(x_stop, 0, LOAD_EDGE_Z)]


# ---------------------------------------------------------------------------------------------------------------------
# Arrière-port reculé de BACK_DZ (valeurs de Layout + 18, à la main)
# ---------------------------------------------------------------------------------------------------------------------
const LANE_BAND := [48.0, 54.0]
const LANE_A_Z := 52.6
const LANE_B_Z := 50.4
const LOAD_STOP_Z := 48.4
const LANE_X0 := -24.0
const LANE_END_X := {1: 29.0, 2: 101.0, 3: 181.0}
const GATE_IN_Z := 63.0
const GATE_OUT_Z := 61.0
const GATE := Vector3(-21.0, 0.0, 62.0)
const QUEUE_Z0 := 67.0
const CUSTOMS_YARD := Rect2(-42, 48, 21, 14)
const LOT_ROW0 := 78.0
const RAIL_Z := 75.0
const RAIL_X := [110.0, 186.0]
const RAIL_STATION := Vector3(150, 0, 70)
const STOP_X0 := 7.0
const STOP_END_MARGIN := 5.0
const LOAD_APPROACH := 4.5


static func lane_end_x(tier: int) -> float:
	return float(LANE_END_X.get(clampi(tier, 1, 3), 29.0))


## Arrêts de chargement possibles au palier : seulement devant un bloc d'un doigt ouvert (pas devant un fond de darse).
static func stop_ranges(tier: int) -> Array:
	var out: Array = []
	for f in FINGERS:
		if int(f.tier) > tier:
			continue
		var x0 := maxf(float(f.x0) + 6.0, LANE_X0 + STOP_X0)
		var x1 := minf(float(f.x1) - 6.0, lane_end_x(tier) - STOP_END_MARGIN)
		if x1 > x0:
			out.append([x0, x1])
	return out


static func truck_route_in(in_x: float, stop_x: float, tier: int) -> Array[Vector3]:
	var end_x := lane_end_x(tier)
	return [Vector3(in_x, 0, GATE_IN_Z + 2.5), Vector3(in_x, 0, LANE_A_Z + 1.5), Vector3(in_x + 1.5, 0, LANE_A_Z),
		Vector3(end_x, 0, LANE_A_Z), Vector3(end_x + 1.5, 0, (LANE_A_Z + LANE_B_Z) * 0.5), Vector3(end_x, 0, LANE_B_Z),
		Vector3(minf(stop_x + LOAD_APPROACH, end_x - 0.5), 0, LANE_B_Z), Vector3(stop_x, 0, LOAD_STOP_Z)]


static func truck_route_out(from_x: float) -> Array[Vector3]:
	var out_x := L.ROAD_OUT_X
	return [Vector3(from_x, 0, LOAD_STOP_Z), Vector3(from_x - LOAD_APPROACH, 0, LANE_B_Z), Vector3(out_x + 1.5, 0, LANE_B_Z),
		Vector3(out_x, 0, LANE_B_Z + 1.5), Vector3(out_x, 0, GATE_OUT_Z), Vector3(out_x, 0, L.HIGHWAY_LANE_W - 2.0),
		Vector3(out_x + 2.0, 0, L.HIGHWAY_LANE_E), Vector3(float(L.HIGHWAY_ENDS[1]), 0, L.HIGHWAY_LANE_E)]


# ---------------------------------------------------------------------------------------------------------------------
# Zones (lot H2 : 1, 2, 6, 7, 10, 11 sur les doigts, jamais sur l'eau d'une darse ; 3, 4, 8, 12, 13 reculées)
# ---------------------------------------------------------------------------------------------------------------------
const ZONE_POLYS := {
	1: [Vector2(-48, -6), Vector2(-36, -6), Vector2(-36, 42), Vector2(-6, 42), Vector2(-6, -6), Vector2(34, -6),
		Vector2(34, 46), Vector2(-48, 46)],
	2: [Vector2(-6, 14), Vector2(2, 14), Vector2(2, 26), Vector2(-6, 26)],
	3: [Vector2(-42, 48), Vector2(-24, 48), Vector2(-24, 54), Vector2(-21, 54), Vector2(-21, 62), Vector2(-42, 62)],
	4: [Vector2(-21, 54), Vector2(-18, 54), Vector2(-18, 68), Vector2(-24, 68), Vector2(-24, 62), Vector2(-21, 62)],
	6: [Vector2(66, -6), Vector2(98, -6), Vector2(98, 34), Vector2(74, 34), Vector2(74, 46), Vector2(66, 46)],
	7: [Vector2(74, 34), Vector2(98, 34), Vector2(98, 46), Vector2(74, 46)],
	8: [Vector2(-18, 54), Vector2(-12, 54), Vector2(-12, 72), Vector2(6, 72), Vector2(6, 126), Vector2(-18, 126)],
	10: [Vector2(98, -6), Vector2(106, -6), Vector2(106, 42), Vector2(140, 42), Vector2(140, -6), Vector2(173, -6),
		Vector2(173, 46), Vector2(98, 46)],
	11: [Vector2(173, -6), Vector2(186, -6), Vector2(186, 46), Vector2(173, 46)],
	12: [Vector2(106, 56), Vector2(186, 56), Vector2(186, 82), Vector2(106, 82)],
	13: [Vector2(-56, 64), Vector2(-24, 64), Vector2(-24, 85), Vector2(-56, 85)],
}


static func zone_poly(id: int) -> Array:
	if ZONE_POLYS.has(id):
		return ZONE_POLYS[id]
	var z := L.zone_by_id(id)
	return L.zone_poly(z) if not z.is_empty() else []


## Cases déplacées (centre x, z) : bâtiments du front et de l'arrière-port. Les autres gardent Layout.LOTS.
const LOT_POS := {
	"platform": Vector2(16, 21), "quay1": Vector2(-2, 4), "quay_ext": Vector2(-2, 20), "crane_mobile": Vector2(-1.6, -1),
	"crane2": Vector2(-1.6, 9), "sts1": Vector2(-3, 22), "yard": Vector2(-42, 19), "gravel2": Vector2(9.5, 30.8),
	"gravel3": Vector2(22.5, 30.8), "supply": Vector2(-34.2, 8), "tug2": Vector2(-33.4, 30), "dredge1": Vector2(-34, -56),
	"hut": Vector2(-28.5, 58.5), "customs1": Vector2(-28.5, 58.5), "track": Vector2(-21, 62), "scanner1": Vector2(-38, 58.5),
	"scanner2": Vector2(-22.5, 57.5), "gate2": Vector2(-17.25, 64.5), "parking1": Vector2(-3, 84), "parking2": Vector2(-3, 111),
	"ewindow": Vector2(-31, 72), "ecustoms": Vector2(-40, 72), "tos": Vector2(-49, 72),
	"berth2": Vector2(70, 18), "asphalt": Vector2(86, 18), "reefer": Vector2(86, 40), "quickmoor": Vector2(66.6, 18),
	"berth3": Vector2(102, 18), "berth4": Vector2(144, 18), "rtg": Vector2(161.5, 21.8), "vacmoor": Vector2(123, 18),
	"lng": Vector2(179, 32), "imo": Vector2(178.5, 8.4), "oog": Vector2(176.3, 20.4), "rail": Vector2(150, 70),
}


# ---------------------------------------------------------------------------------------------------------------------
# Navires : évitage à l'arrivée devant la darse (étrave au large), recul sur l'axe, glissement au quai ; départ : glissement
# vers l'axe, sortie en marche avant, la route sans demi-tour. Cotes corrigées H2-0 : journal.
# ---------------------------------------------------------------------------------------------------------------------
const ARRIVE_TURN_R := 8.0        # D1, D2 : virage à gauche de la voie d'entrée du chenal sur la voie d'arrivée z −20
const D2_OUT_TURN_Z := -18.0       # D2 : début du virage à gauche du départ (la poupe est encore dans l'entrée de la darse)
const D2_OUT_TURN_R := 12.0        # … jusqu'à la voie de départ vers l'ouest z −30
const ARRIVE_E_Z := -26.0          # D3 : voie d'arrivée vers l'ouest (depuis la passe est)
const DEPART_E_Z := -46.0          # D3 : voie de départ vers l'est
const D3_TURN_R := 10.0
const EAST_DESCENT_X := 198.0
const DEPART_EAST := [Vector3(176, 0, -46), Vector3(206, 0, -64), Vector3(215, 0, -90)]


## Du mouillage au point d'attente final (marche avant).
static func ship_path_pilot(k: int, bi: int) -> Array[Vector3]:
	return ship_path_pilot_from(L.anchor_pos(k), bi)


static func ship_path_pilot_from(a: Vector3, bi: int) -> Array[Vector3]:
	var dk := int(BERTHS[bi].darse)
	if dk == 2:
		return _pilot_east(a)
	var out: Array[Vector3] = [a]
	if a.x > float(L.CHANNEL[0].x) + 10.0:
		out.append(L.EAST_APPROACH[0])
	if a.z > L.CHANNEL_ENTRY.z + 4.0 or a.x > float(L.CHANNEL[0].x) + 10.0 or a.x < L.CHANNEL_ENTRY.x - 4.0:
		out.append(L.CHANNEL_ENTRY)
	for i in range(0, L.CHANNEL.size() - 2):
		out.append(L.channel_lane(i, 1))
	out.append(L.pilot_gates(0)[0])
	# sortie du chenal : virage à gauche sur la voie d'arrivée vers l'est (z −20), jusqu'au point d'attente
	var l3 := L.channel_lane(L.CHANNEL.size() - 2, 1)
	var l4 := L.channel_lane(L.CHANNEL.size() - 1, 1)
	var d := Vector2(l4.x - l3.x, l4.z - l3.z).normalized()
	var s := (ARRIVE_W_Z - l3.z) / d.y
	var corner := Vector3(l3.x + d.x * s, 0, ARRIVE_W_Z)
	var g := berth_gate(bi)
	out.append_array(L._fillet(l3, corner, g, ARRIVE_TURN_R, 6))
	out.append(g)
	return out


## D3 : voie au large, le large à l'est, descente à l'est du doigt F3, voie d'arrivée z −26 vers l'ouest, quart de tour à
## droite : cap au nord sur l'axe de D3, la poupe hors de la darse.
static func _pilot_east(a: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = [a]
	if a.x < float(L.EAST_APPROACH_E[0].x) - 10.0 and absf(a.z - L.EAST_LANE_Z) > 1.0:
		var col := a.x + (25.0 if a.x > float(L.CHANNEL[0].x) else -25.0)
		out.append(Vector3(col, 0, a.z))
		out.append(Vector3(col, 0, L.EAST_LANE_Z))
	out.append(Vector3(194, 0, L.EAST_LANE_Z))
	var e0 := Vector3(D3_GATE.x + D3_TURN_R, 0, ARRIVE_E_Z)
	out.append_array(L._fillet(out[-1], Vector3(EAST_DESCENT_X, 0, ARRIVE_E_Z), e0, 12.0, 8))
	out.append(e0)
	out.append_array(L._arc(Vector3(e0.x, 0, ARRIVE_E_Z - D3_TURN_R), D3_TURN_R, PI * 0.5, PI, 8))
	return out


## Recul (marche arrière ≤ REVERSE_V, remorqueur à la proue) : du point d'attente à la hauteur du poste, sur l'axe. D1, D2 :
## quart de cercle (rayon REV_R) de la voie d'arrivée vers l'entrée de la darse, puis l'axe.
static func ship_path_back_in(bi: int, built: Array) -> Array[Vector3]:
	var g := berth_gate(bi)
	var ax := berth_axis_x(bi)
	var out: Array[Vector3] = [g]
	if int(BERTHS[bi].darse) != 2:
		out.append_array(L._arc(Vector3(g.x, 0, g.z + REV_R), REV_R, -PI * 0.5, -PI, 10))
	out.append(Vector3(ax, 0, berth_mid_z(bi, built)))
	return out


## Glissement latéral de l'axe au poste.
static func ship_path_crab_in(bi: int, width: float, built: Array) -> Array[Vector3]:
	var p := berth_ship_pos(bi, width, built)
	return [Vector3(berth_axis_x(bi), 0, p.z), p]


## Départ : glissement vers l'axe, marche avant vers le large, la route (passe ouest pour D1–D2, passe est pour D3).
static func ship_path_depart(bi: int, width: float, built: Array) -> Array[Vector3]:
	var p := berth_ship_pos(bi, width, built)
	var ax := berth_axis_x(bi)
	var out: Array[Vector3] = [p, Vector3(ax, 0, p.z)]
	var dk := int(BERTHS[bi].darse)
	if dk == 0:
		var o4 := L.channel_lane(L.CHANNEL.size() - 1, -1)
		var o3 := L.channel_lane(L.CHANNEL.size() - 2, -1)
		out.append_array(L._fillet(Vector3(ax, 0, p.z), Vector3(ax, 0, -10.0), o4, 10.0, 6))
		out.append_array(L._fillet(Vector3(ax, 0, -10.0), o4, o3, 10.0, 4))
		out.append(o3)
		for i in range(L.CHANNEL.size() - 3, -1, -1):
			out.append(L.channel_lane(i, -1))
		out.append_array(L.EXIT_NORTH)
		return out
	if dk == 1:
		out.append(Vector3(ax, 0, D2_OUT_TURN_Z))
		var r := D2_OUT_TURN_R
		out.append_array(L._arc(Vector3(ax - r, 0, D2_OUT_TURN_Z), r, 0.0, -PI * 0.5, 10))
		var o4 := L.channel_lane(L.CHANNEL.size() - 1, -1)
		var o3 := L.channel_lane(L.CHANNEL.size() - 2, -1)
		var o2 := L.channel_lane(L.CHANNEL.size() - 3, -1)
		var zl := D2_OUT_TURN_Z - r
		var t := (zl - o4.z) / (o3.z - o4.z)
		var corner := o4.lerp(o3, t)
		out.append_array(L._fillet(out[-1], corner, o2, 8.0, 6))
		out.append(o2)
		for i in range(L.CHANNEL.size() - 4, -1, -1):
			out.append(L.channel_lane(i, -1))
		out.append_array(L.EXIT_NORTH)
		return out
	var g := berth_gate(bi)
	out.append(g)
	out.append_array(L._arc(Vector3(g.x + D3_TURN_R, 0, g.z), D3_TURN_R, PI, PI * 1.5, 8))
	out.append_array(DEPART_EAST)
	out.append(L.EXIT)
	return out


## Fenêtres de croisement : « large » et « chenal » inchangées ; « ouest » / « est » (devant les darses) ; une par darse.
const SHIP_CROSSINGS := [
	{"id": "ouest", "rect": Rect2(-42, -40, 100, 34)},
	{"id": "est", "rect": Rect2(100, -46, 106, 40)},
	{"id": "d1", "darse": 0}, {"id": "d2", "darse": 1}, {"id": "d3", "darse": 2},
]


# ---------------------------------------------------------------------------------------------------------------------
# Coques : contrôle de dégagement (tests H2-0)
# ---------------------------------------------------------------------------------------------------------------------
## Points du contour d'une coque (rectangle L × W, coins de proue abattus) centrée en c, étrave vers `fwd`.
static func hull_points(c: Vector2, fwd: Vector2, size: Vector2, step: float = 1.0) -> PackedVector2Array:
	var side := Vector2(-fwd.y, fwd.x)
	var hl := size.x * 0.5
	var hw := size.y * 0.5
	var poly := [c + fwd * hl, c + fwd * (hl - hw) + side * hw, c - fwd * hl + side * hw, c - fwd * hl - side * hw,
		c + fwd * (hl - hw) - side * hw]
	var out := PackedVector2Array()
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var n := maxi(1, ceili(a.distance_to(b) / step))
		for k in n:
			out.append(a.lerp(b, float(k) / float(n)))
	return out


static func hull_poly(c: Vector2, fwd: Vector2, size: Vector2) -> PackedVector2Array:
	var side := Vector2(-fwd.y, fwd.x)
	var hl := size.x * 0.5
	var hw := size.y * 0.5
	return PackedVector2Array([c + fwd * hl, c + fwd * (hl - hw) + side * hw, c - fwd * hl + side * hw,
		c - fwd * hl - side * hw, c + fwd * (hl - hw) - side * hw])


## Distance signée d'un point aux obstacles (négative à l'intérieur).
static func clearance(p: Vector2, obstacles: Array) -> float:
	var best := 1e9
	for poly in obstacles:
		var pts: PackedVector2Array = poly
		var d := 1e9
		for i in pts.size():
			d = minf(d, Geometry2D.get_closest_point_to_segment(p, pts[i], pts[(i + 1) % pts.size()]).distance_to(p))
		if Geometry2D.is_point_in_polygon(p, pts):
			d = -d
		best = minf(best, d)
	return best


## Échantillons d'un trajet : [{c: Vector2, fwd: Vector2}] tous les `step` u ; `reverse` : la coque avance poupe la
## première (cap = −direction) ; `heading` (si non nul) : cap tenu (glissement latéral).
static func path_poses(path: Array, step: float, reverse: bool, heading := Vector2.ZERO) -> Array:
	var out: Array = []
	for p in L.sample_path(path, step):
		out.append({"c": Vector2(p.x, p.z)})
	for i in out.size():
		var a: Vector2 = out[maxi(0, i - 1)].c
		var b: Vector2 = out[mini(out.size() - 1, i + 1)].c
		var d := (b - a).normalized() if b.distance_to(a) > 0.001 else Vector2(0, -1)
		if heading != Vector2.ZERO:
			d = heading
		elif reverse:
			d = -d
		out[i]["fwd"] = d
	return out


## Plus petit dégagement d'une coque le long des poses (et la pose où il est atteint).
static func min_clearance(poses: Array, size: Vector2, obstacles: Array) -> Dictionary:
	var best := {"d": 1e9, "c": Vector2.ZERO}
	for ps in poses:
		for q in hull_points(ps.c, ps.fwd, size):
			var d := clearance(q, obstacles)
			if d < float(best.d):
				best = {"d": d, "c": q}
	return best


## Obstacles d'une manœuvre vers / depuis le poste bi : la terre selon `built` (sans le quai du poste pour le glissement)
## et les navires amarrés aux autres postes de la même darse.
static func moored_hulls(bi: int, built: Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for bj in BERTHS.size():
		if bj == bi or int(BERTHS[bj].darse) != int(BERTHS[bi].darse) or not berth_built(bj, built):
			continue
		var sz := ship_size(berth_class(bj, built))
		var p := berth_ship_pos(bj, sz.y, built)
		out.append(hull_poly(Vector2(p.x, p.z), Vector2(0, -1), sz))
	return out


# ---------------------------------------------------------------------------------------------------------------------
# Parcelles (front du port seulement, décision Q2 = A) — data/parcels.json au lot H2-b
# ---------------------------------------------------------------------------------------------------------------------
const PARCELS := [
	{"id": 1, "tier": 1, "name": "Le Vieux Quai", "badge": Vector2(10, 20), "look": Vector3(-10, 22, 84),
	 "poly": [Vector2(-48, -5.4), Vector2(33.4, -5.4), Vector2(33.4, 54), Vector2(-18, 54), Vector2(-18, 66), Vector2(-42, 66),
		Vector2(-42, 54), Vector2(-48, 54)]},
	{"id": 2, "tier": 2, "name": "La Darse n°2", "badge": Vector2(70, 20), "look": Vector3(70, 22, 96),
	 "poly": [Vector2(33.4, -5.4), Vector2(105.4, -5.4), Vector2(105.4, 54), Vector2(33.4, 54)]},
	{"id": 3, "tier": 3, "name": "La Darse profonde", "badge": Vector2(146, 20), "look": Vector3(146, 22, 110),
	 "poly": [Vector2(105.4, -5.4), Vector2(185.4, -5.4), Vector2(185.4, 54), Vector2(105.4, 54)]},
]
const STAKE_STEP := 6.0


## Parcelles possédées : 0 avant la Concession, sinon le palier.
static func parcels_owned(tier: int, concession: bool = true) -> int:
	return clampi(tier, 0, 3) if concession else 0


## Domaine : union des parcelles possédées.
static func domain_poly(owned: int) -> PackedVector2Array:
	if owned <= 0:
		return PackedVector2Array()
	var acc := PackedVector2Array(PARCELS[0].poly)
	for i in range(1, owned):
		var m := Geometry2D.merge_polygons(acc, PackedVector2Array(PARCELS[i].poly))
		if not m.is_empty():
			acc = m[0]
	return acc


## Cordes : [{a, b, gold}] (segments de STAKE_STEP au plus, seulement sur la terre) ; piquets : [{p, gold}].
## Blanc : le domaine et chaque parcelle non acquise ; or : la prochaine (l'arête commune avec le domaine prend l'or).
static func ropes(owned: int, built: Array) -> Dictionary:
	var segs: Array = []
	var contours: Array = []
	if owned > 0:
		contours.append([domain_poly(owned), false])
	for i in range(owned, PARCELS.size()):
		contours.append([PackedVector2Array(PARCELS[i].poly), i == owned])
	var gold_keys := {}
	for ct in contours:
		var pts: PackedVector2Array = ct[0]
		var gold: bool = ct[1]
		for e in pts.size():
			var a := pts[e]
			var b := pts[(e + 1) % pts.size()]
			for run in _land_runs(a, b, built):
				var r0: Vector2 = run[0]
				var r1: Vector2 = run[1]
				var n := maxi(1, ceili(r0.distance_to(r1) / STAKE_STEP))
				for k in n:
					var p0 := r0.lerp(r1, float(k) / float(n))
					var p1 := r0.lerp(r1, float(k + 1) / float(n))
					var key := _seg_key(p0, p1)
					if gold:
						gold_keys[key] = true
					segs.append({"a": p0, "b": p1, "gold": gold, "key": key})
	# une arête partagée n'est posée qu'une fois ; l'or l'emporte
	var seen := {}
	var out_segs: Array = []
	for s in segs:
		if seen.has(s.key):
			continue
		seen[s.key] = true
		s.gold = gold_keys.has(s.key)
		out_segs.append(s)
	var stakes := {}
	for s in out_segs:
		for p in [s.a, s.b]:
			var k2 := "%d,%d" % [roundi((p as Vector2).x * 10.0), roundi((p as Vector2).y * 10.0)]
			stakes[k2] = {"p": p, "gold": bool(stakes.get(k2, {}).get("gold", false)) or bool(s.gold)}
	return {"segs": out_segs, "stakes": stakes.values()}


## Morceaux à terre d'une arête [[début, fin], …] (échantillons de 0,25 u ; un morceau commence et finit à terre).
static func _land_runs(a: Vector2, b: Vector2, built: Array) -> Array:
	var out: Array = []
	var n := maxi(1, ceili(a.distance_to(b) / 0.25))
	var start := -1
	for i in n + 1:
		var land := on_land(a.lerp(b, float(i) / float(n)), built)
		if land and start < 0:
			start = i
		if (not land or i == n) and start >= 0:
			var last := i if land else i - 1
			if last > start:
				out.append([a.lerp(b, float(start) / float(n)), a.lerp(b, float(last) / float(n))])
			start = -1
	return out


static func _seg_key(a: Vector2, b: Vector2) -> String:
	var p := a if (a.x < b.x or (a.x == b.x and a.y < b.y)) else b
	var q := b if p == a else a
	return "%d,%d|%d,%d" % [roundi(p.x * 10.0), roundi(p.y * 10.0), roundi(q.x * 10.0), roundi(q.y * 10.0)]


# ---------------------------------------------------------------------------------------------------------------------
# Bâtiments typiques d'un palier (captures, contrôles)
# ---------------------------------------------------------------------------------------------------------------------
const BUILT_T1 := ["platform", "quay1", "hut", "track", "crane_mobile", "yard", "quay_ext", "gravel2", "customs1", "supply",
	"crane2", "dredge1", "gravel3"]
const BUILT_T2 := ["berth2", "repair", "asphalt", "gate2", "parking1", "sts1", "tug2", "reefer", "quickmoor", "parking2",
	"ewindow", "scanner1"]
const BUILT_T3 := ["berth3", "lng", "imo", "rail", "rtg", "berth4", "oog", "scanner2", "rpilot", "vacmoor", "ecustoms", "tos"]


static func built_for(tier: int) -> Array:
	var out: Array = BUILT_T1.duplicate()
	if tier >= 2:
		out.append_array(BUILT_T2)
	if tier >= 3:
		out.append_array(BUILT_T3)
	return out


## Grues de chaque poste au palier (comme la simulation) : [[kind, …], …].
static func cranes_for(built: Array) -> Array:
	var b1: Array = ["mobile"]
	if built.has("crane2"):
		b1.append("mobile")
	if built.has("sts1"):
		b1.append("sts")
	var out: Array = [b1]
	if built.has("berth2"):
		out.append(["mobile"])
	if built.has("berth3"):
		out.append(["sts"])
	if built.has("berth4"):
		out.append(["sts", "sts"])
	return out
