class_name Layout
extends RefCounted
## Emplacements fixes du diorama (le joueur ne construit pas librement).
## Repère Godot : X vers la droite, Z vers la caméra ; la mer est en Z négatif, le quai longe X en z ∈ [-6, 0].

const TILE := 6.0
const WATER_Y := -1.0
const QUAY_Z := -3.0
const SEA_EDGE_Z := -6.0
const LAND_Z1 := 48.0
const HIGHWAY_Z0 := 138.0
const HIGHWAY_Z1 := 144.0
const HIGHWAY_LANE_E := 140.0   # voie vers l'est (les camions y entrent et en sortent)
const HIGHWAY_LANE_W := 142.0
const MAINLAND_X := [-132.0, 186.0]

## Postes à quai (dans l'ordre de PortSim.berths). seg = nombre de segments de quai de 12 u.
const BERTHS := [
	{"x0": -36.0, "x1": 0.0},
	{"x0": 0.0, "x1": 36.0},
	{"x0": 48.0, "x1": 96.0},
	{"x0": 96.0, "x1": 144.0},
]

## Étendue des terres par palier (x0, x1).
const LAND_X := {1: [-48.0, 0.0], 2: [-48.0, 48.0], 3: [-48.0, 150.0]}

## Échelle visuelle des navires (le panamax est réduit pour tenir sur son poste).
const SHIP_SCALE := {"mini": 1.0, "coaster": 1.0, "feeder": 1.0, "panamax": 0.8}

const SPAWN := Vector3(-170.0, 0.0, -120.0)
const EXIT := Vector3(230.0, 0.0, -140.0)

const GATE := Vector3(-21.0, 0.0, 33.0)
const ROAD_X := [-21.0, -15.0]
const HARBOR_OFFICE := Vector3(-43.0, 0.0, 6.0)
const CONTROL_TOWER := Vector3(42.0, 0.0, 8.0)
const CUSTOMS_HUT := Vector3(-31.0, 0.0, 37.0)
const CUSTOMS_OFFICE := Vector3(-38.0, 0.0, 30.0)
const YARD_CENTER := Vector3(-20.0, 0.0, 14.0)


## Position d'attente en rade pour l'emplacement k.
static func anchor_pos(k: int) -> Vector3:
	var row := floori(k / 6.0)
	var col := k % 6
	return Vector3(-56.0 + col * 30.0 + (row % 2) * 15.0, 0.0, -36.0 - row * 22.0)


static func berth_center(bi: int) -> float:
	var b: Dictionary = BERTHS[mini(bi, BERTHS.size() - 1)]
	return (float(b.x0) + float(b.x1)) * 0.5


## Position d'un navire amarré (centre, ligne de flottaison).
static func berth_ship_pos(bi: int, width: float) -> Vector3:
	return Vector3(berth_center(bi), 0.0, SEA_EDGE_Z - width * 0.5 - 0.6)


## Blocs de stockage : apparaissent avec un bâtiment ("" = dès le départ).
## zone : 0 standard/vides, 1 frigo, 2 IMO, 3 hors-gabarit.
const BLOCKS := [
	{"b": "", "zone": 0, "x": -35.0, "z": 7.0, "bays": 7, "rows": 6, "tiers": 3},
	{"b": "gravel2", "zone": 0, "x": -35.0, "z": 18.0, "bays": 3, "rows": 7, "tiers": 3},
	{"b": "gravel3", "zone": 0, "x": -11.0, "z": 29.0, "bays": 2, "rows": 10, "tiers": 3},
	{"b": "asphalt", "zone": 0, "x": 2.0, "z": 7.0, "bays": 7, "rows": 6, "tiers": 4},
	{"b": "asphalt", "zone": 0, "x": 2.0, "z": 18.0, "bays": 7, "rows": 5, "tiers": 4},
	{"b": "reefer", "zone": 1, "x": 15.0, "z": 30.0, "bays": 4, "rows": 4, "tiers": 2},
	{"b": "imo", "zone": 2, "x": 55.0, "z": 30.0, "bays": 2, "rows": 6, "tiers": 2},
	{"b": "oog", "zone": 3, "x": 72.0, "z": 30.0, "bays": 3, "rows": 4, "tiers": 1},
	{"b": "rtg", "zone": 0, "x": 52.0, "z": 7.0, "bays": 9, "rows": 6, "tiers": 5},
	{"b": "rtg", "zone": 0, "x": 96.0, "z": 7.0, "bays": 9, "rows": 6, "tiers": 5},
	{"b": "rtg", "zone": 0, "x": 96.0, "z": 18.0, "bays": 9, "rows": 5, "tiers": 5},
]

## Sols : rectangles de dalles (x0, z0, x1, z1) avec leur type et leur condition d'apparition.
## cond : "" (toujours), "t2"/"t3" (palier), ou id de bâtiment. Les dalles plus bas dans la liste remplacent les précédentes.
const GROUNDS := [
	{"cond": "", "type": "ground_grass", "r": [-48, 0, 0, 48]},
	{"cond": "", "type": "ground_gravel", "r": [-36, 0, 0, 18]},
	{"cond": "gravel2", "type": "ground_gravel", "r": [-36, 18, -24, 30]},
	{"cond": "gravel3", "type": "ground_gravel", "r": [-12, 24, 0, 48]},
	# --- terre ferme : bandes d'herbe, plages, autoroute, village, aire d'attente, zone logistique ---
	{"cond": "", "type": "ground_grass", "r": [-120, 48, 174, 66]},
	{"cond": "", "type": "ground_grass", "r": [-132, 66, 186, 150]},
	{"cond": "", "type": "ground_grass", "r": [-114, 150, 168, 168]},
	{"cond": "", "type": "ground_sand", "r": [-120, 48, -48, 54]},
	{"cond": "", "type": "ground_sand", "r": [150, 48, 174, 54]},
	{"cond": "", "type": "ground_sand", "r": [-132, 66, -126, 150]},
	{"cond": "", "type": "ground_sand", "r": [180, 66, 186, 150]},
	{"cond": "", "type": "ground_sand", "r": [-114, 162, 168, 168]},
	{"cond": "", "type": "road_x", "r": [-132, HIGHWAY_Z0, 186, HIGHWAY_Z1]},
	# route d'accès à la gate : les camions en file et sortants roulent dessus
	{"cond": "", "type": "road_z", "r": [-24, 30, -18, HIGHWAY_Z0]},
	{"cond": "gate2", "type": "road_z", "r": [-18, 30, -12, HIGHWAY_Z0]},
	# village des pêcheurs
	{"cond": "", "type": "road_z", "r": [-78, 66, -72, 138]},
	{"cond": "", "type": "road_x", "r": [-126, 96, -24, 102]},
	{"cond": "", "type": "ground_gravel", "r": [-84, 90, -66, 108]},
	# aire d'attente poids lourds : friche tant qu'elle n'est pas construite
	{"cond": "", "type": "ground_gravel", "r": [-18, 54, 6, 84]},
	{"cond": "parking1", "type": "ground_parking", "r": [-18, 54, 6, 84]},
	{"cond": "parking2", "type": "ground_parking", "r": [-18, 84, 6, 108]},
	# zone logistique
	{"cond": "", "type": "road_x", "r": [-18, 114, 30, 120]},
	{"cond": "", "type": "ground_asphalt", "r": [30, 84, 126, 126]},
	{"cond": "t2", "type": "ground_grass", "r": [0, 0, 48, 48]},
	{"cond": "asphalt", "type": "ground_asphalt", "r": [-36, 0, 36, 30]},
	{"cond": "reefer", "type": "ground_asphalt", "r": [12, 30, 36, 42]},
	{"cond": "t3", "type": "ground_grass", "r": [48, 0, 150, 48]},
	{"cond": "t3", "type": "ground_asphalt", "r": [48, 0, 144, 6]},
	{"cond": "rtg", "type": "ground_asphalt", "r": [48, 6, 144, 30]},
	{"cond": "imo", "type": "ground_gravel", "r": [48, 24, 66, 42]},
	{"cond": "oog", "type": "ground_asphalt", "r": [66, 30, 90, 42]},
	{"cond": "rail", "type": "ground_gravel", "r": [48, 42, 150, 48]},
]

## Bâtiments et décors : modèle, position, rotation Y (degrés), condition.
const PROPS := [
	{"cond": "", "m": "harbor_office", "p": [-43, 0, 6]},
	{"cond": "", "m": "customs_hut", "p": [-31, 0, 37]},
	{"cond": "", "m": "hangar", "p": [-41, 0, 22], "ry": 90},
	{"cond": "", "m": "barrier", "p": [-23.6, 0, 33], "tag": "barrier0"},
	{"cond": "", "m": "lighthouse", "p": [-62, -1, -16]},
	{"cond": "", "m": "rock", "p": [-58, -1, -10]},
	{"cond": "", "m": "rock", "p": [-66, -1, -20], "ry": 70},
	{"cond": "", "m": "tree", "p": [-46, 0, 46]},
	{"cond": "", "m": "tree", "p": [-40, 0, 44]},
	{"cond": "", "m": "tree", "p": [-44, 0, 32]},
	{"cond": "", "m": "bush", "p": [-34, 0, 45]},
	{"cond": "", "m": "tree", "p": [-6, 0, 46], "not": "gravel3"},
	{"cond": "", "m": "rock", "p": [-4, 0, 38], "not": "gravel3"},
	{"cond": "", "m": "lamp", "p": [-24.8, 0, 31]},
	{"cond": "", "m": "lamp", "p": [-36, 0, 1.5]},
	{"cond": "", "m": "cone", "p": [-25, 0, 29]},
	{"cond": "", "m": "barrel", "p": [-45, 0, 12]},
	{"cond": "", "m": "pallet", "p": [-45, 0, 14]},
	{"cond": "", "m": "buoy", "p": [-40, -1, -40]},
	{"cond": "", "m": "buoy", "p": [10, -1, -44]},
	# --- accessoires portuaires (livraison Blender attendue : modèles absents ignorés par le chargeur, voir Assets.scene) ---
	# vieux quai en T1 : deux bateaux de pêche, filets et caisses de poisson ; mouettes sur le toit du hangar
	{"cond": "t1", "m": "fishing_boat", "p": [-50, -1, -9.5], "ry": 70},
	{"cond": "t1", "m": "fishing_boat", "p": [-55, -1, -14], "ry": 105},
	{"cond": "t1", "m": "net_pile", "p": [-46.5, 0, -1.2]},
	{"cond": "t1", "m": "net_pile", "p": [-40.5, 0, -0.6], "ry": 40},
	{"cond": "t1", "m": "crate_fish", "p": [-42, 0, 1.4]},
	{"cond": "t1", "m": "crate_fish", "p": [-41, 0, 1.4], "ry": 90},
	{"cond": "", "m": "gull", "p": [-43, 0, 20], "on": "hangar", "ry": 30},
	{"cond": "", "m": "gull", "p": [-39, 0, 24], "on": "hangar", "ry": 160},
	{"cond": "", "m": "gull", "p": [-41, 0, 18], "on": "hangar", "ry": 250},
	# bouées de sauvetage sur poteau : capitainerie, musoir, milieu du quai
	{"cond": "", "m": "life_ring_post", "p": [-39.5, 0, 0.6]},
	{"cond": "", "m": "life_ring_post", "p": [-45, 0, -0.4], "ry": 90},
	{"cond": "", "m": "life_ring_post", "p": [-12, 0, 0.6]},
	# voies de gate (marquage au sol sur la route d'accès), totem « P » à l'aire d'attente
	# (dalle 12 × 6 : centrée sur la route d'accès de 6 u, puis sur la route élargie à 12 u avec la 2e voie de gate)
	{"cond": "", "m": "gate_lanes", "p": [-21, 0.02, 39], "not": "gate2"},
	{"cond": "", "m": "gate_lanes", "p": [-21, 0.02, 45], "not": "gate2"},
	{"cond": "gate2", "m": "gate_lanes", "p": [-18, 0.02, 39]},
	{"cond": "gate2", "m": "gate_lanes", "p": [-18, 0.02, 45]},
	{"cond": "parking1", "m": "sign_p", "p": [-19.5, 0, 55]},
	{"cond": "supply", "m": "pilot_boat", "p": [-44, -1, -10], "ry": 90},
	{"cond": "lng", "m": "silo", "p": [96, 0, 33]},
	{"cond": "lng", "m": "silo", "p": [102, 0, 33]},
	{"cond": "dredge1", "m": "buoy", "p": [-30, -1, -24]},
	{"cond": "dredge1", "m": "buoy", "p": [-6, -1, -24]},
	{"cond": "dredge1", "m": "sign", "p": [-34, 0, -1.2], "ry": 90},
	{"cond": "t2", "m": "control_tower", "p": [42, 0, 8]},
	{"cond": "t2", "m": "office", "p": [42, 0, 22]},
	{"cond": "t2", "m": "workshop", "p": [42, 0, 40]},
	{"cond": "t2", "m": "tree", "p": [4, 0, 46]},
	{"cond": "t2", "m": "tree", "p": [30, 0, 46]},
	{"cond": "gate2", "m": "gate_booth", "p": [-18, 0, 31]},
	{"cond": "gate2", "m": "barrier", "p": [-17.6, 0, 33], "tag": "barrier1"},
	{"cond": "reefer", "m": "reefer_rack", "p": [24, 0, 39]},
	{"cond": "scanner1", "m": "van", "p": [-28, 0, 42], "ry": 90},
	{"cond": "scanner1", "m": "customs_office", "p": [-38, 0, 30]},
	{"cond": "t3", "m": "substation", "p": [120, 0, 36]},
	{"cond": "t3", "m": "inspection_hall", "p": [-40, 0, 41]},
	{"cond": "t3", "m": "warehouse", "p": [138, 0, 22], "ry": 90},
	{"cond": "t3", "m": "tree", "p": [146, 0, 44]},
	{"cond": "t3", "m": "tree", "p": [110, 0, 30]},
	{"cond": "imo", "m": "imo_fence", "p": [59, 0, 34]},
	{"cond": "oog", "m": "fence", "p": [78, 0, 41.5]},
	{"cond": "rail", "m": "rail_terminal", "p": [100, 0, 40]},
	{"cond": "scanner2", "m": "scanner", "p": [-18, 0, 40], "ry": 90},
	{"cond": "tos", "m": "it_center", "p": [138, 0, 36]},
	{"cond": "rtg", "m": "rtg", "p": [67, 0, 11], "ry": 90},
	{"cond": "rtg", "m": "rtg", "p": [111, 0, 18], "ry": 90},
	# --- village (façades tournées vers les rues) ---
	{"cond": "", "m": "house_a", "p": [-88, 0, 72], "ry": 90}, {"cond": "", "m": "house_b", "p": [-88, 0, 84], "ry": 90},
	{"cond": "", "m": "house_a", "p": [-88, 0, 110], "ry": 90}, {"cond": "", "m": "house_a", "p": [-88, 0, 124], "ry": 90},
	{"cond": "", "m": "house_b", "p": [-62, 0, 72], "ry": -90}, {"cond": "", "m": "house_a", "p": [-62, 0, 84], "ry": -90},
	{"cond": "", "m": "shop", "p": [-62, 0, 110], "ry": -90}, {"cond": "", "m": "house_a", "p": [-62, 0, 124], "ry": -90},
	{"cond": "", "m": "house_a", "p": [-120, 0, 88]}, {"cond": "", "m": "house_b", "p": [-106, 0, 88]},
	{"cond": "", "m": "house_a", "p": [-48, 0, 88]}, {"cond": "", "m": "house_a", "p": [-36, 0, 88]},
	{"cond": "", "m": "house_b", "p": [-120, 0, 112], "ry": 180}, {"cond": "", "m": "house_a", "p": [-106, 0, 112], "ry": 180},
	{"cond": "", "m": "house_a", "p": [-48, 0, 112], "ry": 180},
	{"cond": "", "m": "lamp", "p": [-70.5, 0, 94]}, {"cond": "", "m": "lamp", "p": [-70.5, 0, 104]},
	{"cond": "", "m": "tree", "p": [-76, 0, 80]}, {"cond": "", "m": "bush", "p": [-100, 0, 94]},
	# voitures garées devant les maisons (modèle « car_c » attendu de Blender)
	{"cond": "", "m": "car_c", "p": [-83, 0, 76], "ry": 90}, {"cond": "", "m": "car_c", "p": [-67, 0, 88], "ry": -90},
	{"cond": "", "m": "car_c", "p": [-106, 0, 93], "ry": 0}, {"cond": "", "m": "car_c", "p": [-48, 0, 105], "ry": 180},
	# --- zone logistique (les entrepôts restent gris tant que le département logistique n'existe pas : T3) ---
	{"cond": "", "m": "warehouse", "p": [48, 0, 98], "neutral": "t3"}, {"cond": "", "m": "warehouse", "p": [72, 0, 98], "neutral": "t3"},
	{"cond": "", "m": "hangar", "p": [100, 0, 98]}, {"cond": "", "m": "silo", "p": [116, 0, 112]},
	{"cond": "", "m": "stack", "p": [44, 0, 114]}, {"cond": "", "m": "stack", "p": [62, 0, 114]},
	{"cond": "", "m": "stack", "p": [80, 0, 114]}, {"cond": "", "m": "stack", "p": [98, 0, 118]},
	{"cond": "", "m": "lamp", "p": [36, 0, 87]}, {"cond": "", "m": "lamp", "p": [120, 0, 87]},
	{"cond": "", "m": "sign", "p": [-16.5, 0, 56], "ry": 90},
	# --- relief ---
	{"cond": "", "m": "hill", "p": [-100, 0, 156], "s": 1.5}, {"cond": "", "m": "hill", "p": [-30, 0, 156], "s": 1.0},
	{"cond": "", "m": "hill", "p": [60, 0, 154], "s": 1.3}, {"cond": "", "m": "hill", "p": [140, 0, 150], "s": 1.6},
	{"cond": "", "m": "hill", "p": [156, 0, 84], "s": 1.2}, {"cond": "", "m": "hill", "p": [-110, 0, 130], "s": 1.0},
]

## Le monde grandit avec les paliers de niveau : un élément de plus par palier franchi d'un département
## (dans l'ordre des paliers 10, 25, 50…). Positions choisies hors des allées des engins et des camions.
## « walk » : les personnages font l'aller-retour entre leur position et position + walk (Diorama/TrafficView).
const STAGE_PROPS := {
	"harbor": [
		{"m": "pilot_boat", "p": [-50, -1, -16], "ry": 90}, {"m": "docker", "p": [-46, 0, 2], "ry": 200, "walk": [0, 7]},
		{"m": "buoy", "p": [-48, -1, -26]}, {"m": "pilot_boat", "p": [-54, -1, -4], "ry": 60},
		{"m": "lamp", "p": [-47, 0, 10]}, {"m": "tug", "p": [-72, -1, -6], "ry": 30},
		{"m": "sign", "p": [-47, 0, 16], "ry": 90}, {"m": "pilot_boat", "p": [-76, -1, -14], "ry": 110},
	],
	"berths": [
		{"m": "docker", "p": [-34, 0, 2.4], "ry": 220, "walk": [8, 0]}, {"m": "docker", "p": [-2, 0, 2.4], "ry": 140, "walk": [-8, 0]},
		{"m": "lamp", "p": [-1, 0, 4]}, {"m": "docker", "p": [-35, 0, 4], "ry": 250, "walk": [0, 6]},
		{"m": "cone", "p": [-3, 0, 0.6]}, {"m": "pallet", "p": [-1, 0, 6]},
		{"m": "docker", "p": [-3, 0, 4.2], "ry": 120, "walk": [-6, 4]}, {"m": "lamp", "p": [-44, 0, -1]},
	],
	"customs": [
		{"m": "customs_officer", "p": [-26, 0, 38.5], "ry": 200, "walk": [0, 5]}, {"m": "inspector", "p": [-33, 0, 45], "walk": [5, 0]},
		{"m": "cone", "p": [-26.5, 0, 36]}, {"m": "sign", "p": [-26, 0, 44], "ry": 90},
		{"m": "customs_officer", "p": [-29, 0, 46], "ry": 20, "walk": [-4, -3]}, {"m": "barrel", "p": [-34, 0, 47]},
		{"m": "inspector", "p": [-33.5, 0, 40.5], "ry": 250, "walk": [0, -4]}, {"m": "lamp", "p": [-31, 0, 47.5]},
	],
	"cranes": [
		{"m": "docker", "p": [-24, 0, 1.0], "ry": 180, "walk": [0, 9]}, {"m": "lamp", "p": [-24, 0, 5.5]},
		{"m": "pallet", "p": [-30, 0, 5.5]}, {"m": "docker", "p": [-8, 0, 1.0], "ry": 160, "walk": [-6, 0]},
		{"m": "lamp", "p": [-12, 0, 5.5]}, {"m": "barrel", "p": [-29, 0, 5.2]},
		{"m": "docker", "p": [-15, 0, 1.2], "ry": 200, "walk": [0, 10]}, {"m": "lamp", "p": [-6, 0, 5.5]},
	],
	"yard_ops": [
		{"m": "forklift", "p": [-2, 0, 9], "ry": 90}, {"m": "cone", "p": [-1, 0, 13]},
		{"m": "reach_stacker", "p": [-2, 0, 17], "ry": 90}, {"m": "lamp", "p": [-1, 0, 21]},
		{"m": "forklift", "p": [-2, 0, 24], "ry": 270}, {"m": "straddle", "p": [-14, 0, 24]},
		{"m": "pallet", "p": [-16, 0, 20]}, {"m": "reach_stacker", "p": [-17, 0, 26]},
	],
	"gate": [
		{"m": "docker", "p": [-25.5, 0, 36], "ry": 90, "walk": [0, -6]}, {"m": "cone", "p": [-25, 0, 48]},
		{"m": "lamp", "p": [-25, 0, 52]}, {"m": "sign", "p": [-26, 0, 56], "ry": 90},
		{"m": "docker", "p": [-25.5, 0, 40], "ry": 90, "walk": [0, 8]}, {"m": "cone", "p": [-25, 0, 60]},
		{"m": "lamp", "p": [-25, 0, 64]}, {"m": "docker", "p": [-26, 0, 44], "ry": 60, "walk": [-5, 0]},
	],
}


## Emplacements des places de l'aire d'attente (colonnes × rangées de 12 u, façade au nord).
const LOT_COLS := [-15.0, -10.0, -5.0, 0.0]
const LOT_ROW0 := 62.0
const LOT_ROW_GAP := 12.0


static func lot_slot(j: int) -> Vector3:
	return Vector3(LOT_COLS[j % LOT_COLS.size()], 0.0, LOT_ROW0 + float(j / LOT_COLS.size()) * LOT_ROW_GAP)


## Végétation du littoral et des collines (graine fixe) : [{m, p, ry, s}], hors routes, village, aire d'attente et logistique.
static func scatter() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261012
	var out: Array = []
	var avoid := [
		Rect2(-27, 48, 15, 100),     # route d'accès
		Rect2(-22, 50, 32, 62),      # aire d'attente
		Rect2(-132, 62, 110, 78),    # village
		Rect2(26, 80, 104, 50),      # zone logistique
		Rect2(-132, 134, 320, 14),   # autoroute
		Rect2(-60, 0, 230, 54),      # port
	]
	var tries := 0
	while out.size() < 150 and tries < 1200:
		tries += 1
		var x := rng.randf_range(-128.0, 182.0)
		var z := rng.randf_range(56.0, 164.0)
		var blocked := false
		for r in avoid:
			if (r as Rect2).has_point(Vector2(x, z)):
				blocked = true
				break
		if blocked:
			continue
		var pick := rng.randf()
		out.append({"m": "tree" if pick < 0.62 else ("bush" if pick < 0.88 else "rock"), "p": Vector3(x, 0, z),
			"ry": rng.randf_range(0.0, 360.0), "s": rng.randf_range(0.8, 1.25)})
	return out

## Emplacement de chaque département (marqueur de goulot, responsable, centrage caméra).
static func dept_pos(dept: String, tier: int) -> Vector3:
	match dept:
		"harbor":
			return CONTROL_TOWER if tier >= 2 else HARBOR_OFFICE
		"berths":
			return Vector3(-18.0, 0.0, QUAY_Z)
		"customs":
			return CUSTOMS_HUT
		"cranes":
			return Vector3(-22.0, 0.0, QUAY_Z)
		"yard_ops":
			return YARD_CENTER
		"gate":
			return GATE
	return YARD_CENTER


## Aller-retour du responsable embauché (depuis sa place `dept_pos + (3, 0, 3)`) : capitainerie ↔ quai, etc.
const MANAGER_WALK := {
	"harbor": Vector3(0, 0, -8),     # capitainerie ↔ quai
	"berths": Vector3(7, 0, 0),      # le long du quai
	"customs": Vector3(-5, 0, 0),    # douane ↔ table d'inspection
	"cranes": Vector3(-7, 0, 0),
	"yard_ops": Vector3(0, 0, -6),   # parc ↔ tablier
	"gate": Vector3(0, 0, -5),       # gate ↔ guérite
}
## Modèles de personnages (ils marchent au lieu d'osciller sur place).
const PERSON_MODELS := ["docker", "customs_officer", "inspector", "manager"]


## Accessoires le long des quais existants, en MultiMesh (modèles attendus de Blender ; absents = ignorés) :
## bollards tous les 4 u, défenses entre eux, échelles aux extrémités de chaque poste, rails de portique sur le
## tablier à partir du T2, mouettes posées sur quelques bollards. Hypothèses de modélisation : bollard et échelle
## posés sur le quai (y = 0) au bord de l'eau ; défense accrochée au mur du quai (face -Z) ; rail = segment de 6 u selon X.
static func quay_props(nb_berths: int, quay_ext: bool, tier: int) -> Array:
	var out: Array = []
	var gull_i := 0
	for bi in nb_berths:
		var b: Dictionary = BERTHS[mini(bi, BERTHS.size() - 1)]
		var x0 := float(b.x0)
		var x1 := float(b.x1) - (12.0 if bi == 0 and not quay_ext else 0.0)
		var x := x0 + 2.0
		while x < x1 - 1.0:
			out.append({"m": "bollard", "p": Vector3(x, 0, SEA_EDGE_Z + 0.7), "ry": 0.0, "s": 1.0})
			if gull_i % 5 == 2:
				out.append({"m": "gull", "p": Vector3(x, 0, SEA_EDGE_Z + 0.7), "ry": 20.0 + gull_i * 70.0, "s": 1.0, "on": "bollard"})
			gull_i += 1
			if x + 4.0 < x1 - 1.0:
				out.append({"m": "fender", "p": Vector3(x + 2.0, 0, SEA_EDGE_Z), "ry": 0.0, "s": 1.0})
			x += 4.0
		out.append({"m": "ladder", "p": Vector3(x0 + 0.8, 0, SEA_EDGE_Z), "ry": 0.0, "s": 1.0})
		out.append({"m": "ladder", "p": Vector3(x1 - 0.8, 0, SEA_EDGE_Z), "ry": 0.0, "s": 1.0})
		if tier >= 2:
			var rx := x0
			while rx < x1 - 0.1:
				for rz in [QUAY_Z - 1.6, QUAY_Z + 1.6]:
					out.append({"m": "crane_rail", "p": Vector3(rx + 6.0, 0.02, rz), "ry": 0.0, "s": 1.0})
				rx += 12.0
	return out


## Mobilier urbain et marquages, en MultiMesh (modèles attendus de Blender ; absents = ignorés) :
## brise-lames à l'ouest de la rade, trottoirs et passages piétons du village, marquages de parc sur l'asphalte T2+.
## Dimensions des modèles livrés : brise-lames 12 u selon X ; trottoir 6 × 1,2 (bordure côté -Z local, tournée vers la chaussée) ;
## passage piétons 6 × 2,4 ; dalle de marquage de parc 12 × 6.
static func street_props(tier: int, built: Array) -> Array:
	var out: Array = []
	# brise-lames : bras ouest, de la côte vers le large (les navires entrent par le sud-ouest et sortent par l'est)
	for bz in [-16.0, -28.0, -40.0]:
		out.append({"m": "breakwater", "p": Vector3(-84.0, -1.0, bz), "ry": 90.0, "s": 1.0})
	# village : trottoirs de chaque côté de la rue nord-sud (x ∈ [-78, -72]) et de la rue est-ouest (z ∈ [96, 102])
	var z := 69.0
	while z < 136.0:
		if z < 93.0 or z > 105.0:     # pas de trottoir dans le carrefour
			out.append({"m": "sidewalk", "p": Vector3(-78.6, 0.02, z), "ry": 90.0, "s": 1.0})    # bordure vers +X (la rue)
			out.append({"m": "sidewalk", "p": Vector3(-71.4, 0.02, z), "ry": -90.0, "s": 1.0})
		z += 6.0
	var x := -123.0
	while x < -24.0:
		if x < -81.0 or x > -69.0:
			out.append({"m": "sidewalk", "p": Vector3(x, 0.02, 95.4), "ry": 0.0, "s": 1.0})       # bordure vers +Z (la rue)
			out.append({"m": "sidewalk", "p": Vector3(x, 0.02, 102.6), "ry": 180.0, "s": 1.0})
		x += 6.0
	# passages piétons aux quatre branches du carrefour, et devant la boutique
	for cz in [93.5, 104.5]:
		out.append({"m": "crosswalk", "p": Vector3(-75.0, 0.03, cz), "ry": 0.0, "s": 1.0})
	for cx in [-80.5, -69.5]:
		out.append({"m": "crosswalk", "p": Vector3(cx, 0.03, 99.0), "ry": 90.0, "s": 1.0})
	out.append({"m": "crosswalk", "p": Vector3(-75.0, 0.03, 111.0), "ry": 0.0, "s": 1.0})
	# marquages de parc sur l'asphalte (blocs du T2, puis blocs RTG du T3) : dalles de 12 × 6
	if built.has("asphalt"):
		_grid(out, "yard_marks", 0.0, 6.0, 36.0, 30.0, 12.0, 6.0)
	if built.has("rtg") and tier >= 3:
		_grid(out, "yard_marks", 48.0, 6.0, 144.0, 30.0, 12.0, 6.0)
	return out


static func _grid(out: Array, m: String, x0: float, z0: float, x1: float, z1: float, w: float, d: float) -> void:
	var x := x0 + w * 0.5
	while x < x1:
		var z := z0 + d * 0.5
		while z < z1:
			out.append({"m": m, "p": Vector3(x, 0.02, z), "ry": 0.0, "s": 1.0})
			z += d
		x += w
