class_name Layout
extends RefCounted
## Plan coté du port « La baie et le terre-plein » (docs/PLAN_COTE.md) : terrain polygonal, zones, cases des bâtiments,
## voies des camions, chenal des navires. Le joueur ne construit pas librement : chaque bâtiment a sa case dans sa zone.
## Repère Godot : X vers l'est (droite-bas de l'écran), Z vers le sud (gauche-bas) ; la mer est en Z négatif, le quai
## longe X en z ∈ [-6, 0]. Toutes les cotes du plan sont ici (règle d'or : rien n'est posé « là où il reste de la place »).

const TILE := 6.0
## Couleurs du plan absentes de palette.json (ce fichier est régénéré par la chaîne Blender, qui ne les connaît pas) :
## sol du pôle froid, pointillés des zones à venir. Assets.color les lit à défaut.
const PALETTE_EXTRA := {"zone_ice": "#D4EBF4", "zone_dash": "#FFFFFF"}
## Rayons de toucher (u) : le candidat au plus petit rapport distance / rayon l'emporte (Diorama.pick_tap) ; une empreinte
## touchée compte pour le rapport lot_k (c'est une surface, pas un point).
## Modèles dont les pièces vertes sont rendues grises (balisage : le vert est sur le cap, pas sur le brise-lames).
const DEGREEN_MODELS := ["breakwater"]
## Bouées fantômes du chenal à venir : bleu-gris translucide, réduites, une sur deux (revue N6).
const GHOST_BUOY_COLOR := Color(0.62, 0.7, 0.8, 0.35)
const GHOST_BUOY_SCALE := 0.8
const TAP_RADIUS := {"crane": 8.0, "vehicle": 5.0, "barrier": 7.0, "ship": 14.0, "dept": 9.0, "lot_k": 0.5}
const WATER_Y := -1.0
const QUAY_Z := -3.0
const SEA_EDGE_Z := -6.0
const HIGHWAY_Z0 := 138.0
const HIGHWAY_Z1 := 144.0
const HIGHWAY_LANE_E := 142.0   # voie vers l'est, au sud (circulation à droite, lot D) : les camions y entrent et en sortent
const HIGHWAY_LANE_W := 140.0
const MAINLAND_X := [-132.0, 186.0]
## Bouts de l'autoroute : les véhicules apparaissent et disparaissent dans l'ombre des routes sous les arbres (FOREST_ROADS,
## lot F2 ; avant : sous des collines-tunnels).
const HIGHWAY_ENDS := [-128.0, 183.0]

# ---------------------------------------------------------------------------
# Terrain polygonal (x, z) : continent, brise-lames, terre-plein gagné sur la mer (palier 3)
# ---------------------------------------------------------------------------
## Continent : plage ouest, cap et phare, crique du vieux port, côte droite des quais, baie est (comblée au palier 3).
const COAST := [
	Vector2(-132, 168), Vector2(-132, 60), Vector2(-112, 52), Vector2(-94, 48),
	Vector2(-92, 24), Vector2(-90, 0), Vector2(-86, -16), Vector2(-80, -30), Vector2(-72, -42), Vector2(-64, -44),
	Vector2(-58, -38), Vector2(-56, -26), Vector2(-56, -14), Vector2(-52, -8), Vector2(-48, -6),
	Vector2(48, -6),
	Vector2(48, 32), Vector2(62, 40), Vector2(100, 44), Vector2(136, 42), Vector2(152, 36), Vector2(166, 44), Vector2(186, 50),
	Vector2(186, 168),
]
## Brise-lames détaché à l'est de la passe (cinq segments de 12 u du modèle « breakwater ») : prolongé vers l'ouest
## (revue du 13/10) pour que la passe, entre la pointe du cap et sa tête, ne fasse plus que ≈ 40 u : l'abri se lit.
const BREAKWATER := [Vector2(-18, -46), Vector2(42, -46), Vector2(42, -42), Vector2(-18, -42)]
const BREAKWATER_SEGS := [-12.0, 0.0, 12.0, 24.0, 36.0]
const BREAKWATER_Z := -44.0
## Brise-lames est (lot D, revue I3) : au palier 3, avec le terre-plein, le brise-lames se prolonge jusqu'en x = 162 et abrite
## les postes 3–4 ; la passe est s'ouvre entre sa tête et l'angle nord-est du terre-plein (150, −6).
const BREAKWATER_E := [Vector2(42, -46), Vector2(162, -46), Vector2(162, -42), Vector2(42, -42)]
const BREAKWATER_E_SEGS := [48.0, 60.0, 72.0, 84.0, 96.0, 108.0, 120.0, 132.0, 144.0, 156.0]
## Terre-plein : remplit la baie est quand le quai profond n°3 est construit.
const RECLAIM := [Vector2(48, -6), Vector2(150, -6), Vector2(152, 36), Vector2(136, 42), Vector2(100, 44), Vector2(62, 40), Vector2(48, 32)]
const RECLAIM_BUILDING := "berth3"
## Texture de distance au rivage lue par water.gdshader (rectangle du monde couvert, résolution).
const MASK_RECT := Rect2(-200, -230, 460, 460)
const MASK_N := 256

## Postes à quai (dans l'ordre de PortSim.berths).
const BERTHS := [
	{"x0": -36.0, "x1": 0.0},
	{"x0": 0.0, "x1": 36.0},
	{"x0": 48.0, "x1": 96.0},
	{"x0": 96.0, "x1": 144.0},
]
## Emplacements des grues du quai n°1 (grue de départ, deuxième grue, portique STS) : chacune a sa case.
const CRANE_SLOTS := {0: [-26.0, -16.0, -6.0]}

## Étendue des terres bordées de quais par palier (x0, x1) : musoirs, bornes de la caméra.
const LAND_X := {1: [-48.0, 0.0], 2: [-48.0, 48.0], 3: [-48.0, 150.0]}

## Échelle visuelle des navires (le panamax est réduit pour tenir sur son poste).
## (feeder 0,94 et panamax 0,78 : deux navires à des postes voisins gardent 2 u entre leurs coques, revue N10)
## Distance de suivi entre deux navires qui vont dans le même sens (u, entre étrave et poupe).
const SHIP_FOLLOW_GAP := 4.0
const SHIP_SCALE := {"mini": 1.0, "coaster": 1.0, "feeder": 0.94, "panamax": 0.78}

# ---------------------------------------------------------------------------
# Zones : groupes de bâtiments ; état déduit de sim.built et de l'ordre des bâtiments (voir Zones)
# open : "start" (ouverte au départ), "t2"/"t3" (ouverte avec le palier) ou identifiant du bâtiment qui l'ouvre (= key).
# ground : couleur du sol (palette.json) ; sign : pancarte de zone ; landmark : repère vertical (texte, docs).
# ---------------------------------------------------------------------------
const ZONES := [
	{"id": 1, "name": "Vieux port", "icon": "harbor", "tier": 1, "open": "start", "key": "", "ground": "sand_warm",
	 "poly": [Vector2(-48, -6), Vector2(0, -6), Vector2(0, 30), Vector2(-48, 30)],
	 "sign": Vector3(-30, 0, 2), "landmark": "phare du cap, grue mobile",
	 "desc": "Le quai n°1, sa grue, le parc en gravier et la capitainerie."},
	# lot D : une zone qui s'ouvre par un bâtiment porte **le nom de ce bâtiment** (même achat, même nom : la pancarte du monde
	# et Gestion disent la même chose) ; les zones sans bâtiment clé (départ, palier) gardent un nom de lieu.
	{"id": 2, "name": "Allongement du quai", "icon": "berth", "tier": 1, "open": "quay_ext", "key": "quay_ext", "ground": "apron_warm", "quay": true,
		 "poly": [Vector2(-12, -6.5), Vector2(0, -6.5), Vector2(0, 0), Vector2(-12, 0)],
		 "sign": Vector3(-6, 0.8, -1), "landmark": "grues du quai n°1",
		 "desc": "30 m de quai en plus : les caboteurs peuvent accoster."},
	# lot D (revue B1) : la douane est dans l'enceinte, du côté SORTIE de la gate (circulation à droite) : les camions chargés
	# passent devant elle, puis sous le scanner à portique ; la gate elle-même est une zone ouverte au départ.
	{"id": 3, "name": "Bureau de douane", "icon": "customs", "tier": 1, "open": "customs1", "key": "customs1", "ground": "kerb",
		 "poly": [Vector2(-42, 30), Vector2(-24, 30), Vector2(-24, 36), Vector2(-21, 36), Vector2(-21, 44), Vector2(-42, 44)],
		 "sign": Vector3(-35, 0, 34), "landmark": "bureau de douane au bord de la voie de sortie",
		 "desc": "Les douaniers s'installent dans l'enceinte, à la sortie : chaque camion chargé passe devant eux."},
	{"id": 4, "name": "Gate", "icon": "gate", "tier": 1, "open": "start", "key": "", "ground": "kerb",
		 "poly": [Vector2(-21, 36), Vector2(-18, 36), Vector2(-18, 50), Vector2(-24, 50), Vector2(-24, 44), Vector2(-21, 44)],
		 "sign": Vector3(-21, 0, 47), "landmark": "barrières d'entrée et de sortie",
		 "desc": "L'entrée et la sortie des camions : on entre à droite, on sort à gauche, côté douane."},
	{"id": 5, "name": "Dragage du chenal", "icon": "ship", "tier": 1, "open": "dredge1", "key": "dredge1", "ground": "", "water": true,
		 "poly": [], "sign": Vector3(-20, -1, -40), "landmark": "bouées rouges et vertes",
		 "desc": "Une bande d'eau profonde balisée jusqu'aux quais : les feeders peuvent entrer."},
	{"id": 6, "name": "Quai n°2", "icon": "box", "tier": 2, "open": "berth2", "key": "berth2", "ground": "asphalt_violet",
		 "poly": [Vector2(0, -6), Vector2(48, -6), Vector2(48, 5), Vector2(36, 5), Vector2(36, 30), Vector2(0, 30)],
		 "sign": Vector3(18, 0, 14), "landmark": "grue mobile du quai n°2",
		 "desc": "Le quai n°2, sa grue et le parc bitumé du Terminal."},
	{"id": 7, "name": "Pôle froid", "icon": "reefer", "tier": 2, "open": "reefer", "key": "reefer", "ground": "zone_ice",
		 "poly": [Vector2(36, 5), Vector2(48, 5), Vector2(48, 30), Vector2(36, 30)],
		 "sign": Vector3(42, 0, 17), "landmark": "racks frigorifiques",
		 "desc": "Des prises pour conteneurs frigorifiques : la cargaison Frigo (×2,5)."},
	{"id": 8, "name": "Deuxième voie de gate", "icon": "gate", "tier": 2, "open": "gate2", "key": "gate2", "ground": "concrete_dark", "discreet": true,
		 # lot E-Flux : réduite à la voie élargie (x −18…−12) et aux parkings, grise « discrète » (elle couvrait 24 × 72 u d'herbe)
		 "poly": [Vector2(-18, 36), Vector2(-12, 36), Vector2(-12, 54), Vector2(6, 54), Vector2(6, 108), Vector2(-18, 108)],
		 "sign": Vector3(-9, 0, 57), "landmark": "guérite et totem P",
		 "desc": "Une deuxième voie de sortie à la gate et l'aire d'attente des poids lourds."},
	# lot D (revue B2) : le pôle nautique sur le cap, face à la passe — tour VTS, pilotage, atelier avec sa cale sur la crique.
	# « discreet » : tant qu'elle est grise, elle se distingue à peine du cap (cadrage du tutoriel).
	{"id": 9, "name": "Pôle nautique", "icon": "harbor", "tier": 2, "open": "t2", "key": "", "ground": "grass_lime", "discreet": true,
		 "poly": [Vector2(-77, -31), Vector2(-58.6, -31), Vector2(-57, -24), Vector2(-57, -13), Vector2(-60.5, -5), Vector2(-77, -5)],
		 "sign": Vector3(-69, 0, -23), "landmark": "tour VTS",
		 "desc": "La tour VTS veille sur la passe ; le pilotage et l'atelier de réparation, avec sa cale sur la crique, la rejoignent."},
	{"id": 10, "name": "Quai profond n°3", "icon": "crane", "tier": 3, "open": "berth3", "key": "berth3", "ground": "asphalt_violet", "reclaim": true,
		 "poly": [Vector2(48, -6), Vector2(121, -6), Vector2(121, 42.8), Vector2(100, 44), Vector2(62, 40), Vector2(48, 32)],
		 "sign": Vector3(86, -1, 12), "landmark": "rangée de portiques STS",
		 "desc": "La mer devient terre : le terre-plein, ses quais profonds n°3 et 4 et ses portiques de cour."},
	{"id": 11, "name": "Station de soutage GNL", "icon": "imo", "tier": 3, "open": "lng", "key": "lng", "ground": "falun", "reclaim": true,
		 "poly": [Vector2(121, -6), Vector2(150, -6), Vector2(152, 36), Vector2(136, 42), Vector2(121, 42.8)],
		 "sign": Vector3(136.5, 0, 18), "landmark": "sphères de GNL",
		 "desc": "Au bout du terre-plein, loin du village : GNL (avec son appontement), matières dangereuses, hors-gabarit."},
	# lot D (revue I2) : la gare contre le terre-plein, sa voie reliée au parc, dans la bande d'herbe ; la logistique reste derrière
	{"id": 12, "name": "Terminal rail", "icon": "truck", "tier": 3, "open": "rail", "key": "rail", "ground": "gravel",
		 "poly": [Vector2(56, 44), Vector2(100, 48), Vector2(136, 46), Vector2(150, 41.5), Vector2(150, 70), Vector2(56, 70)],
		 "sign": Vector3(100, 0, 63), "landmark": "locomotive à quai",
		 "desc": "Le train emporte les conteneurs du terre-plein vers l'intérieur des terres."},
	# lot D : l'ancienne Colline devient les bureaux du port, côté public de la gate, reliés à la route d'accès par une rue
	{"id": 13, "name": "Bureaux du port", "icon": "it", "tier": 2, "open": "t2", "key": "", "ground": "kerb",
		 "poly": [Vector2(-66, 46), Vector2(-24, 46), Vector2(-24, 67), Vector2(-66, 67)],
		 "sign": Vector3(-58, 0, 56), "landmark": "centre informatique",
		 "desc": "Guichet numérique, douane dématérialisée et centre informatique, au bout de la rue des bureaux."},
]

## Le pôle nautique (zone 9) est une butte sur le cap : un plateau de BUTTE.h u, flancs en couches de terre ; ce qui est
## posé dessus (tour, bâtiments, arbres, responsable) est relevé d'autant (Layout.ground_y).
const BUTTE := {"zone": 9, "h": 1.4}
## Cale de halage de l'atelier de réparation (bâtiment « repair ») : rampe de béton de la butte jusque sous l'eau, sur la
## crique, construite dans Godot (pas de modèle) ; un bateau y est hissé.
const SLIPWAY := {"cond": "repair", "from": Vector3(-60.2, 1.4, -27.0), "to": Vector3(-54.2, -1.6, -27.0), "w": 3.4}
## Haie : épaisseur et hauteur (u).
const HEDGE_SIZE := [0.9, 1.0]
## Haies entre les quartiers (polylignes x, z ; cond comme GROUNDS) : on lit où finit un quartier et où commence le suivant.
const HEDGES := [
	{"cond": "", "pts": [Vector2(-48.8, 44.6), Vector2(-48.8, 2.0)]},                  # enceinte (vieux port, douane) | cap
	{"cond": "", "pts": [Vector2(-48.2, 44.6), Vector2(-25.4, 44.6)]},                 # enceinte de la douane | bureaux
	{"cond": "", "pts": [Vector2(-66.6, 45.6), Vector2(-66.6, 67.6), Vector2(-25.0, 67.6)]},   # bureaux | arrière-pays (E-Flux : rue z 60…66)
	{"cond": "", "pts": [Vector2(6.6, 54.0), Vector2(6.6, 108.0)]},                    # aire d'attente | arrière-pays (E-Flux)
	{"cond": "", "pts": [Vector2(56.0, 70.6), Vector2(150.0, 70.6)]},                  # gare | arrière-pays
	# terre-plein | herbe, ouverte au droit de la liaison parc → gare
	{"cond": "berth3", "pts": [Vector2(58.0, 39.3), Vector2(62.0, 41.6), Vector2(86.7, 44.2)]},
	{"cond": "berth3", "pts": [Vector2(93.5, 44.9), Vector2(100.0, 45.6), Vector2(136.0, 43.6), Vector2(150.0, 38.0)]},
]


## Hauteur du sol en (x, z) : la butte du pôle nautique, 0 ailleurs.
static func ground_y(p: Vector2) -> float:
	var z := zone_by_id(int(BUTTE.zone))
	if not z.is_empty() and Geometry2D.is_point_in_polygon(p, PackedVector2Array(z.poly)):
		return float(BUTTE.h)
	return 0.0


## Phrase de la narratrice à l'ouverture de chaque zone.
const ZONE_SAY := {
	2: "Le quai s'allonge : les caboteurs vont pouvoir accoster !",
	3: "La douane s'installe à la sortie du port : les armateurs étrangers arrivent.",
	5: "Le chenal est dragué et balisé : les feeders peuvent entrer.",
	6: "Voici le quai n°2 : un deuxième poste, sa grue et le parc bitumé.",
	7: "Le pôle froid est branché : place aux conteneurs frigorifiques.",
	8: "Une deuxième voie de sortie à la gate : les camions chargés ne font plus la queue.",
	9: "Sur le cap, la tour VTS veille sur la passe et sur tout le port.",
	10: "La mer devient terre : voici le terre-plein et ses quais profonds !",
	11: "Au bout du terre-plein, loin du village : le GNL et les matières dangereuses.",
	12: "Le train arrive : les conteneurs partent vers l'intérieur des terres.",
	13: "Les bureaux du port ouvrent, au bout de leur rue.",
}

## Repère vertical de chaque zone (modèle qui surgit en dernier, avec la secousse) ; à défaut, le dernier élément.
const ZONE_LANDMARKS := {1: "lighthouse", 3: "customs_hut", 7: "reefer_rack", 8: "gate_booth", 9: "control_tower", 11: "lng_sphere", 12: "rail_terminal", 13: "it_center"}
## Séquence d'ouverture d'une zone (secondes) : chantier (cônes, nuages de poussière : « works »), pointillés qui
## s'effacent, vague de couleur, dalles (« tiles »), bâtiments qui surgissent, repère vertical (secousse, son grave,
## narratrice), retour au cadrage. Pendant toute la séquence, le HUD est masqué (Hud) : on ne voit que le port.
const OPENING := {"dash_fade": 0.8, "works": [0.1, 1.3], "wave_start": 1.0, "wave": 1.2, "tiles": 1.5,
	"pop_start": 1.7, "pop": 1.4, "landmark": 3.4, "back": 4.2, "total": 4.9}
## Terre-plein : les barges arrivent du large (« barge_in »), déversent leur sable (« pour »), la bande de sable avance
## d'ouest en est (« sand »), les barges repartent ; puis l'asphalte (« asphalt »), les dalles, les quais et les portiques.
## Une séquence d'ouverture ne se passe d'un toucher qu'après ce délai (s).
const OPENING_SKIP_AFTER := 1.5
const OPENING_RECLAIM := {"dash_fade": 0.8, "barge_in": [0.0, 1.8], "pour": [1.5, 3.6], "sand": [1.7, 3.8],
	"barge_out": [3.8, 5.6], "asphalt": [3.8, 4.8], "wave_start": 3.8, "wave": 1.0, "tiles": 4.6,
	"pop_start": 4.9, "pop": 1.3, "landmark": 6.3, "back": 6.9, "total": 7.5}
## Barges du terre-plein : abscisses d'arrivée (devant le futur bord du quai), le long d'un couloir en z = RECLAIM_BARGE_LANE_Z
## qu'elles prennent depuis l'est (abscisses de départ RECLAIM_BARGE_X0, hors du port) : elles ne passent ni sur les places
## de mouillage ni sur la voie de départ du palier 3 (revue C7 C4) ; point d'où avancent le sable puis l'asphalte, et rayon
## final de cette avancée.
const RECLAIM_BARGES := [66.0, 96.0, 126.0]
const RECLAIM_BARGE_X0 := [180.0, 200.0, 220.0]
const RECLAIM_BARGE_LANE_Z := -15.0
const RECLAIM_FROM := Vector2(48, 14)
const RECLAIM_REVEAL_R := 140.0

## Cases des bâtiments : zone, position (centre), rotation Y (degrés), empreinte [largeur X, profondeur Z] avant rotation,
## « on » : posé sur la structure d'un autre bâtiment (grue sur le quai), « water » : à flot, « portal » : on passe dessous.
## L'empreinte reprend la boîte englobante du modèle.
const LOTS := {
	# lot G2 : les six pièces du départ (le terre-plein à la main) — plateforme, quai n°1, cabane de douane (même case que le
	# bureau, qui la remplace), piste et barrière, grue mobile (posée sur le quai), parc de stockage (le hangar)
	"platform": {"zone": 1, "p": Vector3(-18, 0, 9.75), "ry": 0.0, "fp": [36.0, 16.5], "ground": true},
	"quay1": {"zone": 1, "p": Vector3(-24, 0, -3.25), "ry": 0.0, "fp": [24.0, 6.5], "ground": true},
	"hut": {"zone": 3, "p": Vector3(-28.5, 0, 40.5), "ry": 0.0, "fp": [6.8, 5.0], "on": "customs1"},
	"track": {"zone": 4, "p": Vector3(-21, 0, 44), "ry": 0.0, "fp": [5.4, 12.0], "ground": true, "on": "road"},
	"crane_mobile": {"zone": 1, "p": Vector3(-26, 0, -1.6), "ry": 0.0, "fp": [6.0, 6.5], "on": "quay1"},
	"yard": {"zone": 1, "p": Vector3(-42, 0, 19), "ry": 90.0, "fp": [10.2, 7.2]},
	"quay_ext": {"zone": 2, "p": Vector3(-6, 0, -3), "ry": 0.0, "fp": [12.0, 6.5]},
	"gravel2": {"zone": 1, "p": Vector3(-28.6, 0, 23.0), "ry": 0.0, "fp": [13.2, 9.0]},
	"customs1": {"zone": 3, "p": Vector3(-28.5, 0, 40.5), "ry": 0.0, "fp": [6.8, 5.0]},
	"supply": {"zone": 1, "p": Vector3(-43, 0, -10.5), "ry": 0.0, "fp": [6.0, 2.2], "water": true},
	"crane2": {"zone": 1, "p": Vector3(-16, 0, -1.6), "ry": 0.0, "fp": [6.0, 6.5], "on": "quay"},
	"dredge1": {"zone": 5, "p": Vector3(-34, 0, -56), "ry": 0.0, "fp": [14.0, 14.0], "water": true},
	"gravel3": {"zone": 1, "p": Vector3(-9.8, 0, 23.0), "ry": 0.0, "fp": [17.6, 9.0]},
	"berth2": {"zone": 6, "p": Vector3(18, 0, -3), "ry": 0.0, "fp": [36.0, 6.5]},
	"repair": {"zone": 9, "p": Vector3(-63, 0, -27), "ry": 90.0, "fp": [6.1, 5.1]},
	"asphalt": {"zone": 6, "p": Vector3(18, 0, 18), "ry": 0.0, "fp": [34.0, 22.0]},
	# E-Flux (E10) : la guérite de la deuxième voie, sur l'îlot entre la 2ᵉ voie de sortie (x −19,5) et l'entrée (x −15)
	"gate2": {"zone": 8, "p": Vector3(-17.25, 0, 46.5), "ry": 0.0, "fp": [1.9, 1.9]},
	"parking1": {"zone": 8, "p": Vector3(-3, 0, 66), "ry": 0.0, "fp": [18.0, 24.0]},
	"sts1": {"zone": 2, "p": Vector3(-6, 0, -3), "ry": 0.0, "fp": [5.9, 6.5], "on": "quay_ext"},
	# (E-Flux : remorqueur à l'avant-port, hors de la crique où descend la cale de halage)
	"tug2": {"zone": 1, "p": Vector3(-45, 0, -15.5), "ry": 0.0, "fp": [8.0, 3.6], "water": true},
	"reefer": {"zone": 7, "p": Vector3(45, 0, 17), "ry": 90.0, "fp": [11.4, 3.6]},
	"quickmoor": {"zone": 6, "p": Vector3(18, 0, -5.4), "ry": 0.0, "fp": [30.0, 1.0], "on": "berth2"},
	"parking2": {"zone": 8, "p": Vector3(-3, 0, 93), "ry": 0.0, "fp": [18.0, 30.0]},
	# (E-Flux, E12 : bureaux tournés vers leur rue, z 60…66, raccordée derrière la tête de file)
	"ewindow": {"zone": 13, "p": Vector3(-31, 0, 54), "ry": 0.0, "fp": [6.1, 4.1]},
	"scanner1": {"zone": 3, "p": Vector3(-38, 0, 40.5), "ry": 0.0, "fp": [8.0, 4.4]},
	"berth3": {"zone": 10, "p": Vector3(72, 0, -3), "ry": 0.0, "fp": [48.0, 6.5]},
	# (E-Flux : GNL à 4 u du bout du poste 4, IMO à 4 u du parc RTG et 5 u du GNL)
	"lng": {"zone": 11, "p": Vector3(145, 0, 15.5), "ry": 0.0, "fp": [9.4, 22.4]},
	"imo": {"zone": 11, "p": Vector3(129.1, 0, 11.5), "ry": 0.0, "fp": [12.1, 12.2]},
	"rail": {"zone": 12, "p": Vector3(100, 0, 52), "ry": 0.0, "fp": [18.5, 3.7]},
	"rtg": {"zone": 10, "p": Vector3(84, 0, 18), "ry": 0.0, "fp": [70.0, 22.0]},
	"berth4": {"zone": 10, "p": Vector3(120, 0, -3), "ry": 0.0, "fp": [48.0, 6.5]},
	"oog": {"zone": 11, "p": Vector3(129.1, 0, 24), "ry": 0.0, "fp": [12.0, 8.0]},
	"scanner2": {"zone": 3, "p": Vector3(-22.5, 0, 39.5), "ry": 90.0, "fp": [6.5, 2.1], "portal": true},
	"rpilot": {"zone": 9, "p": Vector3(-69, 0, -14), "ry": 0.0, "fp": [6.1, 4.1]},
	"vacmoor": {"zone": 10, "p": Vector3(96, 0, -5.4), "ry": 0.0, "fp": [90.0, 1.0], "on": "berth3"},
	"ecustoms": {"zone": 13, "p": Vector3(-40, 0, 54), "ry": 0.0, "fp": [6.2, 5.3]},
	"tos": {"zone": 13, "p": Vector3(-49, 0, 54), "ry": 0.0, "fp": [6.2, 5.3]},
}


# ---------------------------------------------------------------------------
# Navires : mouillage devant la passe, chenal balisé à deux voies, bassin d'évitage, accostage parallèle ; départ par la
# passe aux paliers 1–2 (voie de sortie du chenal, puis le large au nord), par l'est au palier 3 (avec le terre-plein)
# ---------------------------------------------------------------------------
const SPAWN := Vector3(-170.0, 0.0, -130.0)
const EXIT := Vector3(240.0, 0.0, -150.0)
## Sortie des paliers 1–2 : par la passe et la voie de sortie du chenal, puis droit vers le large (nord), hors écran.
const EXIT_NORTH := [Vector3(-21, 0, -130), Vector3(-16, 0, -200), Vector3(-10, 0, -262)]
## Palier à partir duquel les navires repartent par l'est (le terre-plein ouvre la sortie est).
const EAST_EXIT_TIER := 3
## Navires mouillés à l'est du chenal : ils rejoignent la voie d'entrée par le large, au nord de l'entrée du chenal.
const EAST_APPROACH := [Vector3(-2, 0, -142)]
## Point d'attente devant l'entrée du chenal (au nord de la voie d'entrée) : tous les navires entrent par là.
const CHANNEL_ENTRY := Vector3(-33, 0, -116)
## Chenal (dragage) : de l'entrée au large jusqu'au bassin d'évitage ; bouées rouges à l'est (bâbord en entrant), vertes à l'ouest.
## (axe décalé de 3 u vers l'ouest et chenal élargi à ±14 u, voies à ±5 u : coques à ≥ 1,5 u des bouées et des feux,
## deux feeders qui se croisent à ≥ 2 u, revue N1)
const CHANNEL := [Vector3(-27, 0, -96), Vector3(-33, 0, -72), Vector3(-35, 0, -52), Vector3(-33, 0, -34), Vector3(-29, 0, -22)]
const CHANNEL_HALF := 14.0
## Deux voies dans le chenal, de part et d'autre de l'axe (à tribord en entrant comme en sortant) : on ne se croise pas
## (valeur moyenne ; voir CHANNEL_LANE_IN / OUT).
const CHANNEL_LANE := 5.0
## Décalage de chaque voie : la voie d'entrée (ouest) serre l'axe, les grands navires y prennent les courbes du chenal
## (écart total 10 u : deux feeders qui se croisent gardent 2,5 u entre leurs coques).
const CHANNEL_LANE_IN := 4.0
const CHANNEL_LANE_OUT := 6.0
const BASIN := Vector3(-29, 0, -22)
const PASS_Z := -44.0
## Feux de passe : vert sur le cap (à droite en entrant), rouge à la tête du brise-lames (à gauche).
const LIGHT_GREEN := Vector3(-58, -1, -46)
const LIGHT_RED := Vector3(-21, -1, -44)
## Voie d'arrivée le long des quais (après le pivot au bassin) et voie de départ, au large des postes.
const APPROACH_Z := -21.0
const DEPART_Z := -32.0
## Paliers 1–2 : point où le navire qui part vire vers la voie de sortie du chenal.
const DEPART_TURN_Z := -27.0
const DEPART_EAST := [Vector3(200, 0, -25), Vector3(215, 0, -90)]      # E-Flux (E9) : à l'est de la ligne d'arrivée
## Palier 3 (lot D) : les postes 3–4 (terre-plein) ont leur passe est. Voie de départ est (au large de la voie d'arrivée est),
## voie d'arrivée est, et trajet d'arrivée depuis le mouillage : par une voie au large (z = EAST_LANE_Z, entre les rangées du
## mouillage, au nord du début du chenal : on ne coupe jamais une ligne de bouées), puis le large à l'est, la passe est,
## l'évitage devant le poste (boucle) et la voie d'arrivée des quais.
## Lot E-Flux (E9) : on navigue à droite dans la passe est — en entrant vers l'ouest, la voie d'arrivée est au nord
## (z −36, près du feu vert), la voie de départ vers l'est au sud (z −25 : 11 u d'entraxe, deux panamax qui se croisent y
## gardent 2,4 u entre leurs coques ; à −29, proposé par la revue, elles se chevaucheraient de 1,6 u). Le départ quitte la
## passe à l'est de la ligne d'arrivée : plus aucun croisement arrivée / départ au large.
const DEPART_E_Z := -25.0
const ARRIVE_E_Z := -36.0
const EAST_LANE_Z := -108.0
const EAST_APPROACH_E := [Vector3(194, 0, -108), Vector3(186, 0, ARRIVE_E_Z)]
## Point à l'intérieur de la passe est (voie d'arrivée est).
const EAST_PASS_IN := Vector3(146, 0, ARRIVE_E_Z)
## Croisements des navires (E9) et leur règle d'attente (ShipRules) : un navire qui va entrer dans la fenêtre attend qu'un
## navire de l'autre courant en soit sorti ; à égalité, le plus petit identifiant passe (pas d'interblocage).
## - « large », **balisé** (contour et bouées cardinales) : la voie au large (z −108) coupe l'approche et la sortie du chenal
##   ouest — courant « ew » (arrivée au mouillage, pilotage vers les postes 3–4, départ furieux) contre « ns » (pilotage vers
##   les postes 1–2, départ des postes 1–2) ;
## - « chenal » : devant l'entrée du chenal, un navire mouillé à l'est coupe la sortie nord (pilotage contre départ des
##   postes 1–2) ;
## - « ouest » / « est » : bassins d'évitage devant les postes — l'arrivée (pilotage, accostage) contre le départ des postes
##   du même bassin (avec la circulation à droite, l'arrivée coupe forcément la voie de départ).
const SHIP_CROSSINGS := [
	{"id": "large", "rect": Rect2(-50, -126, 40, 36), "mark": true, "buoys": [Vector2(-30, -128.5), Vector2(-46, -87.5)]},
	{"id": "ouest", "rect": Rect2(-42, -40, 62, 26)},
	{"id": "chenal", "rect": Rect2(-40, -146, 32, 46)},      # entrée du chenal : arrivée par l'est contre départ vers le nord
	{"id": "est", "rect": Rect2(80, -33, 48, 19)},
]
## Feux de la passe est : vert à la tête du brise-lames (à tribord en entrant vers l'ouest), rouge à l'angle du terre-plein.
const LIGHT_GREEN_E := Vector3(164.5, -1, -44)
const LIGHT_RED_E := Vector3(152.5, -1, -7.5)
## Postes de la passe est (indices de PortSim.berths).
const EAST_BERTH0 := 2
## Places de mouillage (une bouée jaune numérotée chacune) : la n°1 au large du cap, visible au cadrage de départ, loin de
## la pointe et du feu rouge ; deux groupes de part et d'autre du chenal ; au-delà, une grille au large (hors des voies).
## (grille de 50 u × 28 u : deux panamax au mouillage gardent 2 u entre leurs coques, revue N10)
const ANCHORS := [
	Vector3(-71, 0, -69), Vector3(16, 0, -66), Vector3(-71, 0, -97), Vector3(16, 0, -94), Vector3(66, 0, -66),
	Vector3(-121, 0, -69), Vector3(66, 0, -94), Vector3(116, 0, -66), Vector3(-121, 0, -97), Vector3(66, 0, -122),
	Vector3(116, 0, -94), Vector3(-71, 0, -125),
]
## Colonnes de la grille au-delà des 12 places (aucune sur la sortie nord, x −40…0).
const ANCHOR_GRID_X := [-171.0, -121.0, 16.0, 66.0, 116.0, 166.0]


## Position d'attente en rade pour l'emplacement k.
static func anchor_pos(k: int) -> Vector3:
	if k >= 0 and k < ANCHORS.size():
		return ANCHORS[k]
	var j := maxi(0, k - ANCHORS.size())
	return Vector3(float(ANCHOR_GRID_X[j % ANCHOR_GRID_X.size()]), 0.0, -153.0 - float(j / ANCHOR_GRID_X.size()) * 28.0)


static func berth_center(bi: int) -> float:
	var b: Dictionary = BERTHS[mini(bi, BERTHS.size() - 1)]
	return (float(b.x0) + float(b.x1)) * 0.5


## Position d'un navire amarré (centre, ligne de flottaison).
static func berth_ship_pos(bi: int, width: float) -> Vector3:
	return Vector3(berth_center(bi), 0.0, SEA_EDGE_Z - width * 0.5 - 0.6)


## Point i de l'axe du chenal décalé sur une voie : side = +1 voie d'entrée (ouest), −1 voie de sortie (est).
static func channel_lane(i: int, side: int) -> Vector3:
	var a: Vector3 = CHANNEL[maxi(0, i - 1)]
	var b: Vector3 = CHANNEL[mini(CHANNEL.size() - 1, i + 1)]
	var d := Vector2(b.x - a.x, b.z - a.z).normalized()
	var n := Vector2(-d.y, d.x) * (CHANNEL_LANE_IN if side > 0 else CHANNEL_LANE_OUT) * float(side)
	var c: Vector3 = CHANNEL[i]
	return Vector3(c.x + n.x, 0, c.z + n.y)


## Lot F1 — manœuvres (vues des navires, ShipView). Partout : évitage à l'arrivée, puis approche déjà parallèle au quai,
## glissement latéral jusqu'au poste ; au départ, glissement inverse, puis la route sans demi-tour.
## - Postes 1–2 (bassin ouest) : le navire sort du chenal, tourne à gauche (arrondi de rayon BASIN_TURN_R) sur la voie
##   d'évitage z −33 vers l'est, dépasse son poste, fait demi-tour à droite côté quai (rayon 6 u, le remorqueur pousse la
##   hanche) et revient vers l'ouest sur la voie d'arrivée z −21 : il est amarré **étrave à l'ouest**, vers la passe. Au départ,
##   glissement vers la voie z −21, cap à l'ouest le long des quais, virage à droite (rayon 8 u) dans la voie de sortie du
##   chenal. (Un départ étrave à l'est demandait un demi-tour au large des postes, puis un virage serré autour de la tête du
##   brise-lames : la coque passait sur le feu rouge.)
## - Postes 3–4 (bassin est, palier 3) : voie d'arrivée est, évitage en demi-cercle (rayon 7,5 u) devant le poste, amarré
##   étrave à l'est ; départ par la voie z −25 et la passe est.
## Points d'attente : le premier (« gate 1 », dans la passe ou sur la voie d'arrivée est) tant qu'un autre navire est en route
## vers le même poste ; le second (« gate 2 », avant l'évitage) tant que le poste n'est pas libre ou que le remorqueur n'est
## pas à poste.
const ANCHOR_YAW := 0.35
const ANCHOR_LEG := 16.0                 # dernier bord de l'arrivée au mouillage, déjà au cap du mouillage (aucune giration sur place)
const BASIN_TURN_R := 12.0
const W_TURN_Z := -33.0                  # voie d'évitage des postes 1–2 (vers l'est), au large de la voie d'arrivée z −21 (demi-tour de rayon 6 u)
const W_TURN_DX := 22.0                  # l'évitage se fait 22 u à l'est du poste : on revient droit, déjà parallèle au quai
const DEPART_W_TURN_X := -19.0           # départ des postes 1–2 : début du virage vers la voie de sortie du chenal
const DEPART_W_TURN_R := 8.0
## Départ des postes 3–4 : du glissement latéral, écart vers la voie de départ est (z −25) sur 16 u.
const DEPART_E_DX := 16.0
## Point d'attente de l'arrivée par la passe est : sur la voie d'arrivée (z −36), 10 u à l'est du poste.
const EAST_GATE_DX := 10.0


## Cap d'un navire amarré au poste bi : étrave à l'ouest aux postes 1–2 (vers la passe ouest), à l'est aux postes 3–4.
static func berth_yaw(bi: int) -> float:
	return 0.0 if bi >= EAST_BERTH0 else PI


## Points d'un arc de cercle (centre c, rayon r) de l'angle a0 à a1 (radians ; point = c + r·(cos a, 0, sin a) : 0 = est,
## π/2 = sud, −π/2 = nord), n segments, sans le premier point.
static func _arc(c: Vector3, r: float, a0: float, a1: float, n: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in range(1, n + 1):
		var a := lerpf(a0, a1, float(i) / float(n))
		out.append(Vector3(c.x + r * cos(a), 0, c.z + r * sin(a)))
	return out


## Coin b d'une polyligne a → b → c arrondi (rayon r, réduit si les bras sont trop courts) : [début de l'arc, …, fin de l'arc].
static func _fillet(a: Vector3, b: Vector3, c: Vector3, r: float, n: int) -> Array[Vector3]:
	var d1 := (b - a).normalized()
	var d2 := (c - b).normalized()
	var theta := acos(clampf(d1.dot(d2), -1.0, 1.0))
	if theta < 0.02:
		return [b]
	var t := minf(r * tan(theta * 0.5), minf(a.distance_to(b), b.distance_to(c)) * 0.9)
	var rr := t / tan(theta * 0.5)
	var p1 := b - d1 * t
	var p2 := b + d2 * t
	var n1 := (d2 - d1 * d1.dot(d2)).normalized()
	var cen := p1 + n1 * rr
	var a1 := atan2(p1.z - cen.z, p1.x - cen.x)
	var a2 := atan2(p2.z - cen.z, p2.x - cen.x)
	var da := wrapf(a2 - a1, -PI, PI)
	var out: Array[Vector3] = [p1]
	out.append_array(_arc(cen, rr, a1, a1 + da, n))
	out[-1] = p2
	return out


## Points d'attente d'un navire piloté vers le poste bi : [gate 1, gate 2] (voir plus haut).
static func pilot_gates(bi: int) -> Array[Vector3]:
	if bi >= EAST_BERTH0:
		var g := Vector3(berth_center(bi) + EAST_GATE_DX, 0, ARRIVE_E_Z)
		return [g, g]
	var l2 := channel_lane(CHANNEL.size() - 3, 1)
	var l3 := channel_lane(CHANNEL.size() - 2, 1)
	return [l2.lerp(l3, 0.3), Vector3(berth_center(bi) + W_TURN_DX, 0, W_TURN_Z)]


## Point d'attente final (avant l'évitage).
static func pilot_gate(bi: int) -> Vector3:
	return pilot_gates(bi)[1]


## Fin de la manœuvre de départ du poste bi (virage dans la voie de sortie du chenal ; écart vers la voie de départ est) :
## au-delà, le navire reprend sa vitesse de croisière et le remorqueur le lâche.
static func depart_maneuver_end(bi: int, width: float) -> Vector3:
	var bx := berth_ship_pos(bi, width).x
	if bi >= EAST_BERTH0:
		return Vector3(bx + DEPART_E_DX, 0, DEPART_E_Z)
	return Vector3(DEPART_W_TURN_X - DEPART_W_TURN_R, 0, APPROACH_Z - DEPART_W_TURN_R)


## Trajets des navires (polylignes au niveau de l'eau, y = 0) : ils ne coupent ni la terre, ni le brise-lames, ni un poste.
## Arrivée au mouillage : le dernier bord (ANCHOR_LEG) est déjà au cap du mouillage.
static func ship_path_arrive(k: int) -> Array[Vector3]:
	var a := anchor_pos(k)
	var leg := Vector3(cos(ANCHOR_YAW), 0, -sin(ANCHOR_YAW)) * ANCHOR_LEG
	return [SPAWN, Vector3(lerpf(SPAWN.x, a.x, 0.6), 0, minf(a.z - 30.0, -100.0)), a - leg, a]


## Du mouillage au poste : vers l'entrée du chenal, la passe, le bassin d'évitage, puis la voie d'arrivée.
static func ship_path_pilot(k: int, bi: int) -> Array[Vector3]:
	return ship_path_pilot_from(anchor_pos(k), bi)


## Même trajet depuis la position actuelle du navire (il a quitté sa place de mouillage), sur la voie d'entrée.
static func ship_path_pilot_from(a: Vector3, bi: int) -> Array[Vector3]:
	if bi >= EAST_BERTH0:
		return _pilot_east(a, bi)
	var out: Array[Vector3] = [a]
	# tout navire entre par l'entrée du chenal (on ne coupe jamais la ligne des bouées) : ceux mouillés à l'est
	# contournent l'entrée par le large (ils croisent la voie de sortie hors du chenal)
	if a.x > float(CHANNEL[0].x) + 10.0:
		out.append(EAST_APPROACH[0])
	if a.z > CHANNEL_ENTRY.z + 4.0 or a.x > float(CHANNEL[0].x) + 10.0 or a.x < CHANNEL_ENTRY.x - 4.0:
		out.append(CHANNEL_ENTRY)
	for i in range(0, CHANNEL.size() - 2):
		out.append(channel_lane(i, 1))
	out.append(pilot_gates(bi)[0])
	# (lot F1) virage arrondi à la sortie du chenal sur la voie d'évitage (vers l'est), demi-tour à droite côté quai à l'est du
	# poste, retour vers l'ouest sur la voie d'arrivée : étrave à l'ouest, déjà parallèle au quai
	var bx := berth_center(bi)
	var e0 := Vector3(bx + W_TURN_DX, 0, W_TURN_Z)
	out.append_array(_fillet(out[-1], channel_lane(CHANNEL.size() - 2, 1), e0, BASIN_TURN_R, 6))
	out.append(e0)
	var r := (APPROACH_Z - W_TURN_Z) * 0.5
	out.append_array(_arc(Vector3(e0.x, 0, W_TURN_Z + r), r, -PI * 0.5, PI * 0.5, 10))
	out.append(Vector3(bx, 0, APPROACH_Z))
	return out


## Départ (lot F1) : glissement latéral du poste jusqu'à la voie d'arrivée (z −21, tiré par le remorqueur), puis la route.
## Postes 1–2 (à tous les paliers, lot D) : cap à l'ouest le long des quais, virage à droite dans la voie de sortie du chenal,
## puis le large au nord. Postes 3–4 (terre-plein, palier 3) : voie de départ est, passe est, hors écran.
## (`tier` : gardé pour les appels existants ; depuis le lot D, c'est le poste qui décide de la passe.)
static func ship_path_depart(bi: int, width: float, _tier: int = EAST_EXIT_TIER) -> Array[Vector3]:
	var b := berth_ship_pos(bi, width)
	var out: Array[Vector3] = [b, Vector3(b.x, 0, APPROACH_Z)]
	if bi >= EAST_BERTH0:
		out.append(Vector3(b.x + DEPART_E_DX, 0, DEPART_E_Z))
		for p in DEPART_EAST:
			out.append(p)
		out.append(EXIT)
		return out
	if b.x > DEPART_W_TURN_X + 0.5:
		out.append(Vector3(DEPART_W_TURN_X, 0, APPROACH_Z))
	out.append_array(_arc(Vector3(DEPART_W_TURN_X, 0, APPROACH_Z - DEPART_W_TURN_R), DEPART_W_TURN_R, PI * 0.5, PI, 6))
	for i in range(CHANNEL.size() - 2, -1, -1):
		out.append(channel_lane(i, -1))
	for p in EXIT_NORTH:
		out.append(p)
	return out


## Pilotage vers un poste du terre-plein (passe est) : du mouillage, voie au large (entre les rangées du mouillage), le large
## à l'est, la passe est, la voie d'arrivée est vers l'ouest, l'évitage devant le poste (le remorqueur fait tourner le navire :
## boucle côté quai), puis la voie d'arrivée des quais vers l'est. Un navire déjà à l'abri du brise-lames va droit à la boucle.
static func _pilot_east(a: Vector3, bi: int) -> Array[Vector3]:
	var bx := berth_center(bi)
	var out: Array[Vector3] = [a]
	var inside := a.z > BREAKWATER_Z + 2.0 and a.x < float(BREAKWATER_E[1].x) - 4.0
	if not inside:
		# entre deux colonnes du mouillage (on ne passe jamais sur une autre place), puis la voie au large, au nord du chenal
		if a.x < float(EAST_APPROACH_E[0].x) - 10.0 and absf(a.z - EAST_LANE_Z) > 1.0:
			var col := a.x + (25.0 if a.x > float(CHANNEL[0].x) else -25.0)
			out.append(Vector3(col, 0, a.z))
			out.append(Vector3(col, 0, EAST_LANE_Z))
		for p in EAST_APPROACH_E:
			out.append(p)
		out.append(EAST_PASS_IN)
	if (out[-1] as Vector3).x > bx + EAST_GATE_DX + 2.0:
		out.append(pilot_gate(bi))
	# (lot F1) évitage : demi-cercle à gauche (rayon 7,5 u) de la voie d'arrivée est à la voie d'arrivée des quais
	var r := (APPROACH_Z - ARRIVE_E_Z) * 0.5
	out.append(Vector3(bx - 16.0, 0, ARRIVE_E_Z))
	out.append_array(_arc(Vector3(bx - 16.0, 0, ARRIVE_E_Z + r), r, -PI * 0.5, -PI * 1.5, 10))
	out.append(Vector3(bx, 0, APPROACH_Z))
	return out


## Départ furieux depuis la rade : vers le large, puis l'est (au large, hors du port).
static func ship_path_leave(from: Vector3) -> Array[Vector3]:
	return [from, Vector3(from.x, 0, minf(from.z - 30.0, -112.0)), Vector3(120, 0, -125), EXIT]


# ---------------------------------------------------------------------------
# Camions : autoroute → voie d'entrée → gate d'entrée → voie des camions (sens unique, boucle) → bloc → gate de sortie
# ---------------------------------------------------------------------------
## Voie des camions : bande de 6 u entre le parc et l'enceinte de la douane (z 30–36), **circulation à droite** (lot D, revue
## B1) : voie A vers l'est, au sud (le camion vide va au bout de la boucle), voie B au retour vers l'ouest, au nord, le long du
## parc : le camion s'y arrête en LOAD_STOP_Z devant son bloc pour être chargé (les autres passent à côté), puis repart chargé
## vers la voie de sortie — côté douane et scanner à portique.
const LANE_BAND := [30.0, 36.0]
const LANE_A_Z := 34.6
const LOAD_STOP_Z := 30.4
const LANE_B_Z := 32.4
const LANE_X0 := -24.0
## Bout de la boucle par palier (prolongée dans le Terminal puis le Terre-plein).
const LANE_END_X := {1: -2.0, 2: 45.0, 3: 146.0}
## Route d'accès (x −24…−18, puis −24…−12 avec la gate à deux voies), circulation à droite : voie d'entrée vers le nord à
## l'est (ROAD_IN_X[0] ; ROAD_IN_X[1] avec gate2, la route élargie vers l'est), voie de sortie vers le sud à l'ouest, côté
## douane ; gate2 ajoute une **deuxième voie de sortie** (ROAD_OUT_X_GATE2), cohérente avec son effet « sortie ×2 ».
const ROAD_IN_X := [-19.5, -15.0]
const ROAD_OUT_X := -22.5
const ROAD_OUT_X_GATE2 := -19.5
const GATE_IN_Z := 45.0
const GATE_OUT_Z := 43.0
const GATE := Vector3(-21.0, 0.0, 44.0)
const ROAD_X := [-24.0, -18.0]
const QUEUE_Z0 := 49.0
const QUEUE_GAP := 7.5
## Bord du parc côté terre : le conteneur passe du parc à la remorque (le camion attend sur la voie B).
const LOAD_EDGE_Z := 28.6
## Enceinte de la douane (rectangle x, z) : entre la voie des camions et la gate, à l'ouest de la route (tests, docs).
const CUSTOMS_YARD := Rect2(-42, 30, 21, 14)


## Voie d'entrée de la route d'accès (une seule : la file des camions attend dessus).
static func road_in_x(gate2: bool) -> float:
	return float(ROAD_IN_X[1]) if gate2 else float(ROAD_IN_X[0])


## Voie de sortie : la voie côté douane ; avec gate2, la deuxième voie de sortie pour un camion sur deux (lane = 1).
static func road_out_x(gate2: bool, lane: int = 1) -> float:
	return ROAD_OUT_X_GATE2 if (gate2 and lane % 2 == 1) else ROAD_OUT_X


## Emprises (x, z) des scanners à portique posés pour ces bâtiments (PROPS « scanner », conditions « cond » et « and ») :
## avec gate2, un portique par voie de sortie (E-Flux, E10). Même empreinte que la case scanner2.
static func portal_rects(built: Array) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var r0 := lot_rect("scanner2")
	for p in PROPS:
		if String(p.m) != "scanner" or not built.has(String(p.cond)) or (p.has("and") and not built.has(String(p["and"]))):
			continue
		out.append(Rect2(Vector2(float(p.p[0]), float(p.p[2])) - r0.size * 0.5, r0.size))
	return out


static func lane_end_x(tier: int) -> float:
	return float(LANE_END_X.get(clampi(tier, 1, 3), LANE_END_X[1]))


## Lot E-Flux (E7) : le camion se range devant son bloc et en repart en biais doux (LOAD_APPROACH u le long de la voie B
## pour 2 u de côté, ≈ 24°) : son cap à l'arrivée, à l'arrêt (vers l'ouest) et au départ reste à moins de 30° — plus de
## pivot sur place. Les arrêts gardent donc STOP_END_MARGIN u avant le bout de leur boucle, et (avec gate2) STOP_X0_GATE2 u
## après le début de la voie, pour que la deuxième voie de sortie se prenne aussi en biais.
const LOAD_APPROACH := 4.5
const STOP_END_MARGIN := 5.0
const STOP_X0 := 7.0
const STOP_X0_GATE2 := 10.0
## Cap d'un camion arrêté au chargement : vers l'ouest (voie B, retour), rotation Y = π (repère des véhicules : +X à 0).
const LOAD_YAW := PI


## Abscisses possibles d'un arrêt de chargement au palier `tier` [x0, x1] (TrafficView._pick_stop, tests).
static func stop_range(tier: int, gate2: bool) -> Array:
	return [LANE_X0 + (STOP_X0_GATE2 if gate2 else STOP_X0), lane_end_x(tier) - STOP_END_MARGIN]


## Plus petit palier dont la boucle passe devant l'arrêt x : c'est là que le camion vide fait demi-tour (lot E-Flux, E8 :
## au T3, un camion servi par un bloc du T1 tourne en x −2, plus au bout du terre-plein).
static func tier_for_stop(x: float) -> int:
	for t in [1, 2, 3]:
		if x <= lane_end_x(t) - STOP_END_MARGIN + 0.01:
			return t
	return 3


## Arrivée : sortie du tunnel ouest, voie vers l'est de l'autoroute (au sud), virage à gauche sur la voie d'entrée de la
## route d'accès, place de file.
static func truck_route_arrive(in_x: float, slot: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = [Vector3(float(HIGHWAY_ENDS[0]), 0, HIGHWAY_LANE_E), Vector3(in_x - 3.0, 0, HIGHWAY_LANE_E),
		Vector3(in_x, 0, HIGHWAY_LANE_E - 3.0)]
	if absf(slot.x - in_x) > 0.5:
		out.append(Vector3(in_x, 0, slot.z))
	out.append(slot)
	return out


## Entrée : de la gate d'entrée, voie A vers l'est jusqu'au demi-tour (palier `tier` ; par défaut — lot E-Flux, E8 — le
## passage du groupe de blocs de l'arrêt, `tier_for_stop`), voie B vers l'ouest jusqu'à l'arrêt devant le bloc, le long du
## parc, en biais doux (LOAD_APPROACH).
static func truck_route_in(in_x: float, stop_x: float, tier: int = 0) -> Array[Vector3]:
	var end_x := lane_end_x(tier if tier > 0 else tier_for_stop(stop_x))
	return [Vector3(in_x, 0, GATE_IN_Z + 2.5), Vector3(in_x, 0, LANE_A_Z + 1.5), Vector3(in_x + 1.5, 0, LANE_A_Z),
		Vector3(end_x, 0, LANE_A_Z), Vector3(end_x + 1.5, 0, (LANE_A_Z + LANE_B_Z) * 0.5), Vector3(end_x, 0, LANE_B_Z),
		Vector3(minf(stop_x + LOAD_APPROACH, end_x - 0.5), 0, LANE_B_Z), Vector3(stop_x, 0, LOAD_STOP_Z)]


## Passages de demi-tour dessinés sur la voie des camions (lot E-Flux, E8) : au bout de chaque boucle intérieure à la
## boucle du palier (x −2 au T2–T3, x 45 au T3) ; le bout de la voie n'en a pas besoin (la route s'arrête).
static func crossover_xs(tier: int) -> Array[float]:
	var out: Array[float] = []
	for t in [1, 2]:
		if t < tier:
			out.append(lane_end_x(t))
	return out


## Après le chargement : voie B vers l'ouest, voie de sortie (devant la douane, sous le scanner à portique), gate de sortie,
## route vers le sud, virage à gauche sur l'autoroute vers l'est, tunnel est. `lane` : voie de sortie (gate2, voir
## road_out_x). `tier` n'est plus utilisé (la boucle est faite à l'aller) : gardé pour les appels existants.
static func truck_route_out(from_x: float, _tier: int, gate2: bool, lane: int = 0) -> Array[Vector3]:
	var out_x := road_out_x(gate2, lane)
	var out: Array[Vector3] = [Vector3(from_x, 0, LOAD_STOP_Z)]
	if from_x - LOAD_APPROACH > out_x + 2.0:
		out.append(Vector3(from_x - LOAD_APPROACH, 0, LANE_B_Z))      # biais doux (E7) : pas de pivot sur place
	out.append_array([Vector3(out_x + 1.5, 0, LANE_B_Z), Vector3(out_x, 0, LANE_B_Z + 1.5), Vector3(out_x, 0, GATE_OUT_Z),
		Vector3(out_x, 0, HIGHWAY_LANE_W - 2.0), Vector3(out_x + 2.0, 0, HIGHWAY_LANE_E), Vector3(float(HIGHWAY_ENDS[1]), 0, HIGHWAY_LANE_E)])
	return out


# ---------------------------------------------------------------------------
# Parc : blocs de conteneurs, allées des engins (côté mer), aire d'attente des camions
# ---------------------------------------------------------------------------
## Blocs de stockage : apparaissent avec un bâtiment ("" = dès le départ). zone : 0 standard/vides, 1 frigo, 2 IMO, 3 hors-gabarit.
## aisle : allée verticale du groupe (x) que prennent les engins entre le tablier et l'allée transversale (YARD_AISLE_Z).
const BLOCKS := [
	{"b": "", "zone": 0, "x": -35.0, "z": 7.0, "bays": 3, "rows": 6, "tiers": 3, "aisle": -20.3},
	{"b": "", "zone": 0, "x": -18.4, "z": 7.0, "bays": 4, "rows": 6, "tiers": 3, "aisle": -20.3},
	{"b": "gravel2", "zone": 0, "x": -35.0, "z": 18.6, "bays": 3, "rows": 6, "tiers": 3, "aisle": -20.3},
	{"b": "gravel3", "zone": 0, "x": -18.4, "z": 18.6, "bays": 4, "rows": 6, "tiers": 3, "aisle": -20.3},
	{"b": "asphalt", "zone": 0, "x": 1.6, "z": 7.0, "bays": 3, "rows": 6, "tiers": 4, "aisle": 16.3},
	{"b": "asphalt", "zone": 0, "x": 18.2, "z": 7.0, "bays": 4, "rows": 6, "tiers": 4, "aisle": 16.3},
	{"b": "asphalt", "zone": 0, "x": 1.6, "z": 18.6, "bays": 3, "rows": 6, "tiers": 4, "aisle": 16.3},
	{"b": "asphalt", "zone": 0, "x": 18.2, "z": 18.6, "bays": 4, "rows": 6, "tiers": 4, "aisle": 16.3},
	{"b": "reefer", "zone": 1, "x": 36.6, "z": 6.6, "bays": 1, "rows": 14, "tiers": 2, "aisle": 0.0},
	{"b": "imo", "zone": 2, "x": 124.7, "z": 7.0, "bays": 2, "rows": 6, "tiers": 2, "aisle": 0.0},
	{"b": "oog", "zone": 3, "x": 124.7, "z": 20.2, "bays": 2, "rows": 3, "tiers": 1, "aisle": 0.0},
	{"b": "rtg", "zone": 0, "x": 49.0, "z": 7.0, "bays": 9, "rows": 6, "tiers": 5, "aisle": 90.1},
	{"b": "rtg", "zone": 0, "x": 92.0, "z": 7.0, "bays": 6, "rows": 6, "tiers": 5, "aisle": 90.1},
	{"b": "rtg", "zone": 0, "x": 49.0, "z": 18.6, "bays": 9, "rows": 6, "tiers": 5, "aisle": 90.1},
	{"b": "rtg", "zone": 0, "x": 92.0, "z": 18.6, "bays": 6, "rows": 6, "tiers": 5, "aisle": 90.1},
]
## Allée du tablier (engins, au pied des grues) et allée transversale entre les deux rangées de blocs.
const APRON_LANE_Z := 3.4
const YARD_AISLE_Z := 17.2
const YARD_CENTER := Vector3(-20.3, 0.0, 17.2)

## Allées verticales des engins par groupe de blocs [x0, x1, x de l'allée] (T1, Terminal, Terre-plein).
const YARD_AISLES := [[-36.0, 0.0, -20.3], [0.0, 48.0, 16.3], [48.0, 150.0, 90.1]]


static func aisle_x(x: float) -> float:
	for a in YARD_AISLES:
		if x >= float(a[0]) and x < float(a[1]):
			return float(a[2])
	return float(YARD_AISLES[0][2])


## Engin : du tablier (au pied d'une grue, x_a) au bloc réel (x_s) par l'allée du tablier, l'allée verticale et l'allée
## transversale. Les engins restent côté mer : ils ne franchissent jamais la voie des camions.
static func engine_route_to_block(xa: float, xs: float) -> Array[Vector3]:
	var ax := aisle_x(xs)
	return [Vector3(xa, 0, APRON_LANE_Z), Vector3(ax, 0, APRON_LANE_Z), Vector3(ax, 0, YARD_AISLE_Z), Vector3(xs, 0, YARD_AISLE_Z)]


## Engin : du bloc au bord du parc devant le camion arrêté sur la voie A (le conteneur passe sur la remorque).
static func engine_route_to_truck(xs: float) -> Array[Vector3]:
	var ax := aisle_x(xs)
	return [Vector3(xs, 0, YARD_AISLE_Z), Vector3(ax, 0, YARD_AISLE_Z), Vector3(ax, 0, LOAD_EDGE_Z), Vector3(xs, 0, LOAD_EDGE_Z)]


## Engin : retour du bord du parc au tablier.
static func engine_route_back(xs: float, xa: float) -> Array[Vector3]:
	var ax := aisle_x(xs)
	return [Vector3(xs, 0, LOAD_EDGE_Z), Vector3(ax, 0, LOAD_EDGE_Z), Vector3(ax, 0, APRON_LANE_Z), Vector3(xa, 0, APRON_LANE_Z)]


## Engin : de sa position du moment (sur une allée : tablier, allée verticale, allée transversale ou bord du parc) au tablier
## en xa, par les allées (revue C7 A7 : un engin rappelé en chemin ne coupe jamais à travers les blocs).
static func engine_route_home(p: Vector3, xa: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if absf(p.z - APRON_LANE_Z) > 0.5:
		var ax := aisle_x(p.x)
		if absf(p.x - ax) > 0.5:
			out.append(Vector3(ax, 0, p.z))
		out.append(Vector3(ax, 0, APRON_LANE_Z))
	out.append(Vector3(xa, 0, APRON_LANE_Z))
	return out

## Emplacements des places de l'aire d'attente (colonnes × rangées de 12 u, façade au nord).
const LOT_COLS := [-9.0, -4.5, 0.0, 4.5]
const LOT_ROW0 := 60.0
const LOT_ROW_GAP := 12.0


static func lot_slot(j: int) -> Vector3:
	return Vector3(LOT_COLS[j % LOT_COLS.size()], 0.0, LOT_ROW0 + float(j / LOT_COLS.size()) * LOT_ROW_GAP)


# ---------------------------------------------------------------------------
# Sols intérieurs (dalles 6 × 6 à marquages) : le socle de terre est polygonal, les zones ont leur couleur.
# cond : "" (toujours), "t2"/"t3" (palier), ou id de bâtiment. Les dalles plus bas dans la liste remplacent les précédentes.
# ---------------------------------------------------------------------------
const GROUNDS := [
	{"cond": "", "type": "ground_gravel", "r": [-36, 0, 0, 18], "grp": "yard"},
	{"cond": "gravel2", "type": "ground_gravel", "r": [-36, 18, -18, 30]},
	{"cond": "gravel3", "type": "ground_gravel", "r": [-18, 18, 0, 30]},
	# (lot F2 : plus de plage au pied du continent à l'ouest : la rive ouest du golfe et sa forêt le prolongent)
	{"cond": "", "type": "road_x", "r": [-132, HIGHWAY_Z0, 186, HIGHWAY_Z1]},
	# route d'accès à la gate (les camions entrent et sortent par elle), élargie par la gate à deux voies
	{"cond": "", "type": "road_z", "r": [-24, 36, -18, HIGHWAY_Z0], "grp": "track"},
	{"cond": "gate2", "type": "road_z", "r": [-18, 36, -12, HIGHWAY_Z0]},
	# voie des camions entre le parc et La Porte, prolongée avec le Terminal puis le Terre-plein
	{"cond": "", "type": "road_x", "r": [-24, 30, 0, 36], "grp": "track"},
	{"cond": "t2", "type": "road_x", "r": [0, 30, 48, 36]},
	{"cond": RECLAIM_BUILDING, "type": "road_x", "r": [48, 30, 150, 36]},
	# village des pêcheurs
	{"cond": "", "type": "road_z", "r": [-78, 66, -72, 138]},
	{"cond": "", "type": "road_x", "r": [-126, 96, -24, 102]},
	{"cond": "", "type": "ground_gravel", "r": [-84, 90, -66, 108]},
	# aire d'attente poids lourds (zone Porte n°2)
	{"cond": "parking1", "type": "ground_parking", "r": [-12, 54, 6, 78]},
	{"cond": "parking2", "type": "ground_parking", "r": [-12, 78, 6, 108]},
	# zone logistique : la route arrive par l'ouest ; asphalte avec le terminal rail
	{"cond": "", "type": "road_x", "r": [-12, 114, 30, 120]},
	{"cond": "rail", "type": "ground_asphalt", "r": [30, 96, 126, 126]},
	{"cond": "asphalt", "type": "ground_asphalt", "r": [-36, 0, 36, 30]},
	{"cond": RECLAIM_BUILDING, "type": "ground_asphalt", "r": [48, 0, 144, 6]},
	{"cond": "rtg", "type": "ground_asphalt", "r": [48, 6, 120, 30]},
	{"cond": "imo", "type": "ground_gravel", "r": [120, 6, 138, 18]},
	{"cond": "oog", "type": "ground_asphalt", "r": [120, 18, 138, 30]},
	# gare (lot D) : quai et voie sur le ballast contre le terre-plein, liaison avec la voie des camions du terre-plein ; rue des
	# bureaux du port reliée à la route d'accès
	{"cond": "rail", "type": "ground_gravel", "r": [60, 48, 150, 60]},
	{"cond": "rail", "type": "road_z", "r": [87.1, 36, 93.1, 48]},      # liaison dans l'axe de l'allée x 90,1 (E-Flux)
	{"cond": "t2", "type": "road_x", "r": [-54, 60, -24, 66]},      # rue des bureaux, derrière la tête de file (E-Flux, E12)
]

## Bâtiments et décors : modèle, position, rotation Y (degrés), condition (voir GROUNDS), « not » : retiré par ce bâtiment,
## « alt » : modèle de repli tant que le modèle n'est pas livré (échelle alt_s).
const PROPS := [
	{"cond": "", "m": "harbor_office", "p": [-43, 0, 6], "grp": "quay1"},
	# lot G2 : la cabane de douane (le tampon), remplacée par le bureau de douane (même case) ; son douanier
	{"cond": "hut", "m": "customs_hut", "p": [-28.5, 0, 40.5], "not": "customs1"},
	{"cond": "customs1", "m": "customs_office", "p": [-28.5, 0, 40.5], "alt": "customs_hut"},
	{"cond": "hut", "m": "customs_officer", "p": [-25.2, 0, 38.6], "ry": 200, "not": "customs1"},
	# hangar du vieux port ; au palier 3, la halle d'inspection de la douane prend sa place (dans l'enceinte, desservie côté
	# mer par les engins : allée du tablier et allée verticale du T1)
	{"cond": "", "m": "hangar", "p": [-42, 0, 19], "ry": 90, "not": "t3", "grp": "yard"},
	{"cond": "t3", "m": "inspection_hall", "p": [-42, 0, 19], "ry": 90},
	{"cond": "", "m": "lighthouse", "p": [-66, 0, -36]},
	{"cond": "", "m": "rock", "p": [-62, -1, -47]},
	{"cond": "", "m": "rock", "p": [-70, -1, -45], "ry": 70},
	{"cond": "", "m": "rock", "p": [-56, -1, -40], "ry": 30},
	{"cond": "", "m": "rock", "p": [-78, -1, -36], "ry": 120},
	{"cond": "", "m": "tree", "p": [-71, 0, -26]}, {"cond": "", "m": "tree", "p": [-80, 0, -12]},
	{"cond": "", "m": "tree", "p": [-66, 0, -1]}, {"cond": "", "m": "bush", "p": [-66.5, 0, -20.5]},
	{"cond": "", "m": "lamp", "p": [-36, 0, 1.5], "grp": "quay1"},
	{"cond": "", "m": "barrel", "p": [-46.5, 0, 11], "grp": "yard"},
	{"cond": "", "m": "pallet", "p": [-46.5, 0, 12.8], "grp": "yard"},
	# feux de passe : vert sur le cap, rouge à la tête du brise-lames (repli : bouées agrandies) ; passe est au palier 3 (lot D) :
	# vert à la tête du brise-lames est, rouge à l'angle du terre-plein
	{"cond": "", "m": "light_green", "p": [-58, -1, -46], "alt": "buoy_green", "alt_s": 1.6, "tag": "pass_light"},
	{"cond": "", "m": "light_red", "p": [-21, -1, -44], "alt": "buoy", "alt_s": 1.6, "tag": "pass_light"},
	{"cond": "berth3", "m": "light_green", "p": [164.5, -1, -44], "alt": "buoy_green", "alt_s": 1.6, "tag": "pass_light"},
	{"cond": "berth3", "m": "light_red", "p": [152.5, -1, -7.5], "alt": "buoy", "alt_s": 1.6, "tag": "pass_light"},
	# vieux quai en T1 : filets d'amarrage ; mouettes sur le toit du hangar. (Lot F3 : plus de bateaux de pêche immobiles
	# ni de caisses de poisson dans la crique — la flottille vit dans l'anse des pêcheurs, à l'ouest du cap, FishingView.)
	{"cond": "t1", "m": "net_pile", "p": [-46.5, 0, -1.2], "grp": "quay1"},
	{"cond": "t1", "m": "net_pile", "p": [-40.5, 0, -0.6], "ry": 40, "grp": "quay1"},
	{"cond": "", "m": "gull", "p": [-44, 0, 16], "on": "hangar", "ry": 30, "not": "t3", "grp": "yard"},
	{"cond": "", "m": "gull", "p": [-40, 0, 22], "on": "hangar", "ry": 160, "not": "t3", "grp": "yard"},
	{"cond": "", "m": "gull", "p": [-42, 0, 19], "on": "hangar", "ry": 250, "not": "t3", "grp": "yard"},
	{"cond": "t3", "m": "gull", "p": [-43, 0, 17], "on": "inspection_hall", "ry": 80},
	# bouées de sauvetage sur poteau : capitainerie, musoir, milieu du quai
	{"cond": "", "m": "life_ring_post", "p": [-39.5, 0, 0.6], "grp": "quay1"},
	{"cond": "", "m": "life_ring_post", "p": [-45, 0, -0.4], "ry": 90, "grp": "quay1"},
	{"cond": "", "m": "life_ring_post", "p": [-12, 0, 0.6], "grp": "quay1"},
	# gate, circulation à droite (lot D) : barrière d'entrée sur la voie est (pivot au bord est de la route), barrière de
	# sortie sur la voie ouest, côté douane (pivot au bord ouest) ; avec gate2 la route s'élargit à l'est : l'entrée passe en
	# x −15, une deuxième barrière de sortie ferme la voie x −19,5 ; marquage des voies retourné (sens de circulation)
	# lot G2 : une barrière à bascule (`barrier_post`, bras `arm`) en travers des deux voies : c'est elle qu'on touche
	{"cond": "", "m": "barrier_post", "p": [-21, 0, 44], "tag": "barrier_post", "grp": "track", "alt": "barrier"},
	{"cond": "gate2", "m": "barrier", "p": [-12, 0, 45], "ry": 180, "tag": "barrier_in"},
	{"cond": "gate2", "m": "barrier", "p": [-17.6, 0, 43], "ry": 180, "tag": "barrier_out", "s": 0.8},
	{"cond": "", "m": "gate_lanes", "p": [-21, 0.02, 40], "ry": 180, "not": "gate2", "grp": "track"},
	{"cond": "gate2", "m": "gate_lanes", "p": [-18, 0.02, 40], "ry": 180},
	{"cond": "gate2", "m": "gate_booth", "p": [-17.25, 0.15, 46.5], "s": 0.85},      # sur son îlot (E10, Layout.GATE_ISLAND)
	{"cond": "parking1", "m": "sign_p", "p": [-10.5, 0, 55]},
	{"cond": "supply", "m": "pilot_boat", "p": [-43, -1, -10.5]},
	{"cond": "tug2", "m": "tug", "p": [-51, -1, -22], "ry": 90},
	# zone sensible : deux sphères de GNL (modèle lng_sphere, ≈ 7 u de diamètre, sommet au-dessus de la poutre des portiques),
	# entraxe 13 u, échelle et escalier côté caméra ; repli : silos. Appontement de soutage (construit dans Godot, Layout.JETTIES)
	# et sa barge de soutage
	{"cond": "lng", "m": "lng_sphere", "p": [145, 0, 9], "alt": "silo", "alt_s": 1.0},
	{"cond": "lng", "m": "lng_sphere", "p": [145, 0, 22], "alt": "silo", "alt_s": 1.0},
	{"cond": "lng", "m": "tug", "p": [157.5, -1, 19.4], "ry": 0},
	{"cond": "dredge1", "m": "sign", "p": [-34, 0.8, -1.2], "ry": 90},
	# pôle nautique (lot D, sur le cap) : la tour VTS (repère du palier 2), le pilotage à son pied, l'atelier et sa cale
	{"cond": "t2", "m": "control_tower", "p": [-62, 0, -16]},
	{"cond": "repair", "m": "workshop", "p": [-63, 0, -27], "ry": 90},
	{"cond": "rpilot", "m": "office", "p": [-69, 0, -14], "roof": "roof_b_blue"},      # avec un toit (E-Flux)
	{"cond": "t2", "m": "lamp", "p": [-59, 0, -20.5]},
	# enceinte de la douane : bureau de douane, scanner mobile (bureau et camion-scanner), scanner à portique sur la voie de
	# sortie ; aire d'inspection (cônes, palette)
	{"cond": "scanner1", "m": "customs_office", "p": [-39.4, 0, 40.5]},
	{"cond": "scanner1", "m": "van", "p": [-35.4, 0, 40.5], "ry": 90},
	{"cond": "scanner2", "m": "scanner", "p": [-22.5, 0, 39.5], "ry": 90},
	# E-Flux (E10) : avec la deuxième voie de sortie (gate2), un second portique sur la voie x −19,5 : tous les camions chargés
	# passent sous un scanner
	{"cond": "scanner2", "and": "gate2", "m": "scanner", "p": [-19.5, 0, 39.5], "ry": 90},
	{"cond": "customs1", "m": "pallet", "p": [-36, 0, 33.5]},
	{"cond": "customs1", "m": "cone", "p": [-38.5, 0, 31.6]}, {"cond": "customs1", "m": "cone", "p": [-33.5, 0, 31.6]},
	# bureaux du port (côté public) : guichet numérique, douane dématérialisée, centre informatique (TOS) au bord de leur rue
	{"cond": "ewindow", "m": "office", "p": [-31, 0, 54]},
	{"cond": "ecustoms", "m": "it_center", "p": [-40, 0, 54]},
	{"cond": "tos", "m": "it_center", "p": [-49, 0, 54]},
	{"cond": "t2", "m": "lamp", "p": [-35.5, 0, 58]}, {"cond": "t2", "m": "lamp", "p": [-44.5, 0, 58]},
	{"cond": "", "m": "tree", "p": [-58, 0, 52]}, {"cond": "", "m": "tree", "p": [-62, 0, 59]},
	{"cond": "", "m": "tree", "p": [-59, 0, 63.5]}, {"cond": "", "m": "bush", "p": [-63, 0, 49]},
	# Terminal, Pôle froid
	{"cond": "reefer", "m": "reefer_rack", "p": [45, 0, 17], "ry": 90},
	{"cond": "", "m": "tree", "p": [24, 0, 44]}, {"cond": "", "m": "tree", "p": [40, 0, 44]},
	{"cond": "", "m": "bush", "p": [12, 0, 42]},
	# Terre-plein et zone sensible (IMO décalée du GNL, lot D)
	{"cond": RECLAIM_BUILDING, "m": "substation", "p": [100, 0, 40]},
	{"cond": "imo", "m": "imo_fence", "p": [129.1, 0, 11.5]},
	{"cond": "oog", "m": "fence", "p": [129.1, 0, 27]},
	{"cond": "rtg", "m": "rtg", "p": [67, 0, 11], "ry": 90},
	{"cond": "rtg", "m": "rtg", "p": [107, 0, 22.8], "ry": 90},
	# gare (lot D) : terminal rail contre le terre-plein (les voies sont posées par rail_props), tracteur de terminal sur la
	# liaison avec le parc, piles de conteneurs à quai
	{"cond": "rail", "m": "rail_terminal", "p": [100, 0, 52]},
	{"cond": "rail", "m": "stack", "p": [74, 0, 51.5]}, {"cond": "rail", "m": "stack", "p": [126, 0, 51]},
	{"cond": "rail", "m": "lamp", "p": [64, 0, 52]}, {"cond": "rail", "m": "lamp", "p": [140, 0, 50]},
	# passage à niveau signalé (E12) : la navette du tracteur (TrafficView) coupe la voie des camions en x 84…90 ; panneaux de
	# part et d'autre, marquage au sol (street_props)
	{"cond": "rail", "m": "sign", "p": [86.4, 0, 37.4], "ry": 90}, {"cond": "rail", "m": "sign", "p": [93.8, 0, 37.4], "ry": 90},
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
	{"cond": "", "m": "tree", "p": [-76, 0, 80]}, {"cond": "", "m": "bush", "p": [-92.5, 0, 92]},
	# voitures garées devant les maisons (modèle « car_c » attendu de Blender)
	{"cond": "", "m": "car_c", "p": [-83, 0, 76], "ry": 90}, {"cond": "", "m": "car_c", "p": [-67, 0, 88], "ry": -90},
	{"cond": "", "m": "car_c", "p": [-106, 0, 93], "ry": 0}, {"cond": "", "m": "car_c", "p": [-48, 0, 105], "ry": 180},
	# --- zone logistique (arrière-plan) : tout reste gris (« neutral ») tant que la gare n'est pas construite ---
	{"cond": "", "m": "warehouse", "p": [48, 0, 103], "neutral": "rail"}, {"cond": "", "m": "warehouse", "p": [72, 0, 103], "neutral": "rail"},
	{"cond": "", "m": "hangar", "p": [104, 0, 104], "neutral": "rail"}, {"cond": "", "m": "silo", "p": [116, 0, 116], "neutral": "rail"},
	{"cond": "", "m": "stack", "p": [44, 0, 116], "neutral": "rail"}, {"cond": "", "m": "stack", "p": [62, 0, 116], "neutral": "rail"},
	{"cond": "", "m": "stack", "p": [80, 0, 116], "neutral": "rail"}, {"cond": "", "m": "stack", "p": [98, 0, 121], "neutral": "rail"},
	{"cond": "", "m": "lamp", "p": [36, 0, 87], "neutral": "rail"}, {"cond": "", "m": "lamp", "p": [120, 0, 87], "neutral": "rail"},
	{"cond": "", "m": "sign", "p": [-25.5, 0, 68], "ry": 90, "grp": "track"},
	# (lot F2 : plus de collines-tunnels ; l'autoroute, la rue du village et la voie ferrée entrent sous les arbres,
	# FOREST_ROADS ; deux buttes boisées gardent du relief dans l'arrière-pays)
	{"cond": "", "m": "hill", "p": [162, 0, 84], "s": 1.2}, {"cond": "", "m": "hill", "p": [-110, 0, 126], "s": 1.0},
]

## Appontements construits dans Godot (dalle de béton sur pieux) : condition, centre (x, z), taille (x, z).
## Lot D : appontement de soutage du GNL, sur la face est du terre-plein.
const JETTIES := [{"cond": "lng", "c": Vector2(156.0, 15.5), "size": Vector2(10.6, 3.0)}]
## Îlot de la guérite de gate2 (E-Flux, E10) : bordure de béton entre la 2ᵉ voie de sortie et la voie d'entrée.
const GATE_ISLAND := {"cond": "gate2", "c": Vector2(-17.25, 44.8), "size": Vector2(2.0, 7.6), "h": 0.15}

## Voie ferrée de la gare (bâtiment « rail ») : de la colline-tunnel est jusqu'au quai de la gare, contre le terre-plein (lot D :
## avant, z = 93 au fond de la zone logistique, sans liaison avec le parc).
const RAIL_Z := 57.0
const RAIL_X := [62.0, 186.0]
## Lot E-Flux (E12) : bouche du tunnel est, sous la colline (184 ; 58) : la rame y est coupée (shader vcol_clip), elle entre
## et sort sous la colline, visible à l'écran le reste du temps ; arrêt au quai, attente à quai.
const RAIL_TUNNEL_X := 181.0
const TRAIN_DWELL := 16.0
## Navette du tracteur de terminal entre le parc RTG et la gare (train à quai) : garage, points d'attente avant le passage à
## niveau (côté gare et côté parc), prise au bord du parc, dépose au quai de la gare ; marquage du passage à niveau.
const RAIL_SHUTTLE := {"park": Vector3(90.1, 0, 45.5), "x": 90.1, "hold": 38.6, "pick_z": 25.5,
	"drop": Vector3(114, 0, 52.6), "lane_z": 48.8, "turn_x": 110.0}
const RAIL_CROSSING_MARKS := [88.9, 91.3]


static func rail_props(built: Array) -> Array:
	var out: Array = []
	if not built.has("rail"):
		return out
	var x := float(RAIL_X[0]) + 3.0
	while x < float(RAIL_X[1]):
		out.append({"m": "rail", "p": Vector3(x, 0.0, RAIL_Z), "ry": 0.0, "s": 1.0})
		x += 6.0
	return out


## Le monde grandit avec les paliers de niveau : un élément de plus par palier franchi d'un département
## (dans l'ordre des paliers 10, 25, 50…). Positions hors des allées des engins, des voies des camions et des cases.
## « walk » : les personnages font l'aller-retour entre leur position et position + walk (Diorama/TrafficView).
## Le mouillage (bouées numérotées) suit le nombre de places en rade, une de plus tous les 10 niveaux (Diorama).
const STAGE_PROPS := {
	"harbor": [
		{"m": "pilot_boat", "p": [-50, -1, -34], "ry": 0}, {"m": "docker", "p": [-39.5, 0, 10.5], "ry": 200, "walk": [0, 2]},
		{"m": "lamp", "p": [-47, 0, 17]}, {"m": "pilot_boat", "p": [-38.5, -1, -15], "ry": 90},
		{"m": "sign", "p": [-47, 0, 25], "ry": 90}, {"m": "tug", "p": [-47, -1, -41], "ry": 60},
		{"m": "lamp", "p": [-37, 0, 26]}, {"m": "pilot_boat", "p": [-44, -1, -30], "ry": 90},
	],
	"berths": [
		{"m": "docker", "p": [-34, 0, -4.6], "ry": 90, "walk": [8, 0]}, {"m": "docker", "p": [-4, 0, -4.6], "ry": 270, "walk": [-8, 0]},
		{"m": "lamp", "p": [-1, 0, 5.5]}, {"m": "docker", "p": [-30, 0, -4.4], "ry": 90, "walk": [6, 0]},
		{"m": "cone", "p": [-3, 0, 1.0]}, {"m": "pallet", "p": [-1, 0, 4.6]},
		{"m": "docker", "p": [-12, 0, -4.4], "ry": 270, "walk": [-6, 0]}, {"m": "lamp", "p": [-44, 0, -1]},
	],
	"customs": [
		# lot D : aire d'inspection de l'enceinte, entre la voie des camions et le bureau de douane (côté sortie)
		{"m": "customs_officer", "p": [-35, 0, 32.4], "ry": 200, "walk": [4, 0]}, {"m": "inspector", "p": [-40.5, 0, 33.5], "walk": [0, 2.5]},
		{"m": "cone", "p": [-25.2, 0, 37.2]}, {"m": "sign", "p": [-41.5, 0, 43], "ry": 90},
		{"m": "customs_officer", "p": [-31, 0, 34.6], "ry": 20, "walk": [-4, 0]}, {"m": "barrel", "p": [-41, 0, 30.8]},
		{"m": "inspector", "p": [-38, 0, 37.5], "ry": 250, "walk": [3, 0]}, {"m": "lamp", "p": [-25, 0, 31]},
	],
	"cranes": [
		{"m": "docker", "p": [-24, 0, -4.8], "ry": 90, "walk": [5, 0]}, {"m": "lamp", "p": [-24, 0, 5.4]},
		{"m": "pallet", "p": [-34.5, 0, 5.4]}, {"m": "docker", "p": [-8, 0, -4.8], "ry": 270, "walk": [-5, 0]},
		{"m": "lamp", "p": [-12, 0, 5.4]}, {"m": "barrel", "p": [-33, 0, 5.6]},
		{"m": "docker", "p": [-18, 0, -4.8], "ry": 90, "walk": [4, 0]}, {"m": "lamp", "p": [-6, 0, 5.4]},
	],
	"yard_ops": [
		{"m": "forklift", "p": [-46, 0, 26], "ry": 90}, {"m": "cone", "p": [-21.6, 0, 16.4]},
		{"m": "reach_stacker", "p": [-46, 0, 2], "ry": 90}, {"m": "lamp", "p": [-0.8, 0, 16.4]},
		{"m": "forklift", "p": [-38.5, 0, 28.8], "ry": 0}, {"m": "straddle", "p": [-45.5, 0, 9.5]},
		{"m": "pallet", "p": [-37, 0, 16.6]}, {"m": "reach_stacker", "p": [-30, 0, 28.8], "ry": 0},
	],
	"gate": [
		{"m": "docker", "p": [-27, 0, 46.2], "ry": 90, "walk": [-6, 0]}, {"m": "cone", "p": [-24.6, 0, 46.5]},
		{"m": "lamp", "p": [-25.2, 0, 69]}, {"m": "sign", "p": [-25.5, 0, 75], "ry": 90},
		{"m": "docker", "p": [-25.6, 0, 76.5], "ry": 90, "walk": [0, 8]}, {"m": "cone", "p": [-24.6, 0, 80]},
		{"m": "lamp", "p": [-25.2, 0, 86]}, {"m": "docker", "p": [-26, 0, 92], "ry": 60, "walk": [-5, 0]},
	],
}


## Végétation de l'arrière-pays et du cap (graine fixe) : [{m, p, ry, s}], sur le continent, hors zones, routes, village et logistique.
## Calculée une fois (graine fixe : le résultat ne change jamais ; revue C7 D) — ne pas modifier la liste rendue.
static var _scatter_cache: Array = []


static func scatter() -> Array:
	if _scatter_cache.is_empty():
		_scatter_cache = _make_scatter()
	return _scatter_cache


static func _make_scatter() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261012
	var out: Array = []
	var coast := PackedVector2Array(COAST)
	var reclaim := PackedVector2Array(RECLAIM)
	var avoid := [
		Rect2(-27, 34, 36, 108),     # route d'accès, gate, aire d'attente
		Rect2(-132, 62, 110, 78),    # village
		Rect2(26, 80, 104, 50),      # zone logistique
		Rect2(-140, 134, 340, 14),   # autoroute
		Rect2(-68, -8, 230, 44),     # port, voie des camions, pôle froid, terre-plein
		Rect2(-49, 29, 25, 17),      # enceinte de la douane
		Rect2(-68, 44, 45, 25),      # bureaux du port (et leur rue)
		Rect2(-82, -34, 30, 34),     # pôle nautique (cap)
		Rect2(52, 36, 104, 36),      # gare (lot D : contre le terre-plein)
		Rect2(148, 49, 52, 16),      # voie ferrée vers le tunnel est
		Rect2(-142, 44, 58, 28),     # lot F3/G1 : l'anse des pêcheurs (ponton, criée, pompe, lavage, cabane, route du mareyeur)
		Rect2(-96, 14, 16, 34),      # lot F3 : fabrique de glace et quai des chalutiers (flanc ouest du cap)
		Rect2(-100, -2, 20, 18),     # lot G1 : grande jetée et sa passerelle
	]
	# en bosquets (revue du 13/10 : plus d'arbres « saupoudrés ») : un centre, puis 3 à 7 arbres serrés autour, des buissons
	# en lisière ; quelques rochers isolés
	var ok := func(p2: Vector2) -> bool:
		if not Geometry2D.is_point_in_polygon(p2, coast) or Geometry2D.is_point_in_polygon(p2, reclaim):
			return false
		for r in avoid:
			if (r as Rect2).has_point(p2):
				return false
		return not _near_coast(p2, 2.5)
	var tries := 0
	while out.size() < 170 and tries < 3000:
		tries += 1
		var c := Vector2(rng.randf_range(-128.0, 182.0), rng.randf_range(-40.0, 164.0))
		if not ok.call(c):
			continue
		if rng.randf() < 0.12:
			out.append({"m": "rock", "p": Vector3(c.x, 0, c.y), "ry": rng.randf_range(0.0, 360.0), "s": rng.randf_range(0.8, 1.25)})
			continue
		var n := rng.randi_range(3, 7)
		for i in n:
			var a := rng.randf_range(0.0, TAU)
			var d := rng.randf_range(0.0, 5.5) if i > 0 else 0.0
			var p := c + Vector2(cos(a), sin(a)) * d
			if not ok.call(p):
				continue
			var edge := d > 4.0
			out.append({"m": "bush" if edge and rng.randf() < 0.6 else "tree", "p": Vector3(p.x, 0, p.y),
				"ry": rng.randf_range(0.0, 360.0), "s": rng.randf_range(0.85, 1.3)})
	return out


static func _near_coast(p: Vector2, d: float) -> bool:
	for i in COAST.size():
		var a: Vector2 = COAST[i]
		var b: Vector2 = COAST[(i + 1) % COAST.size()]
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < d:
			return true
	return false


## Emplacement de chaque département (marqueur de goulot, responsable, centrage caméra).
const HARBOR_OFFICE := Vector3(-43.0, 0.0, 6.0)
const CONTROL_TOWER := Vector3(-62.0, 0.0, -16.0)     # tour VTS du pôle nautique (lot D : ≈ 35 u de la passe)
const CUSTOMS_HUT := Vector3(-28.5, 0.0, 40.5)       # dans l'enceinte, au bord de la voie de sortie (lot D)
const CUSTOMS_OFFICE := Vector3(-39.4, 0.0, 40.5)    # bureau du scanner mobile
## Touchers du coin gate / douane (E-Flux, E12) : Douane sur le parvis du bureau (coin sud-ouest), Gate sur la route au sud
## de la tête de file ; à ≥ 10 u l'un de l'autre et des bras des barrières.
const CUSTOMS_TAP := Vector3(-31.5, 0.0, 38.0)
const GATE_TAP := Vector3(-21.0, 0.0, 56.0)


static func dept_pos(dept: String, tier: int) -> Vector3:
	match dept:
		"harbor":
			return CONTROL_TOWER if tier >= 2 else HARBOR_OFFICE
		"berths":
			return Vector3(-32.0, 0.0, QUAY_Z)      # lot D : à 11 u des Portiques (touchers séparés)
		"customs":
			return CUSTOMS_TAP
		"cranes":
			return Vector3(-21.0, 0.0, QUAY_Z)
		"yard_ops":
			return YARD_CENTER
		"gate":
			return GATE_TAP      # E-Flux (E12) : sur la route, à ≥ 10 u des barrières et de la douane (touchers séparés)
	return YARD_CENTER


## Place du responsable embauché (près de son poste, hors des voies) et son aller-retour.
const MANAGER_POS := {
	"harbor": Vector3(-38.5, 0, 9.5), "berths": Vector3(-28, 0, -4.4), "customs": Vector3(-27, 0, 37),
	"cranes": Vector3(-20, 0, -4.4), "yard_ops": Vector3(-47, 0, 22), "gate": Vector3(-26.4, 0, 47.4),
}
const MANAGER_POS_T2 := {"harbor": Vector3(-58.6, 0, -12.5)}     # au pied de la tour VTS (lot D)
const MANAGER_WALK := {
	"harbor": Vector3(0, 0, 2),      # sur le perron (capitainerie, puis tour)
	"berths": Vector3(7, 0, 0),      # le long du quai
	"customs": Vector3(-5, 0, 0),    # douane ↔ aire d'inspection
	"cranes": Vector3(-7, 0, 0),
	"yard_ops": Vector3(0, 0, -8),   # le long du parc
	"gate": Vector3(0, 0, 6),        # le long de la route, côté bureaux (avant leur rue, E-Flux)
}


static func manager_pos(dept: String, tier: int) -> Vector3:
	if tier >= 2 and MANAGER_POS_T2.has(dept):
		return MANAGER_POS_T2[dept]
	return MANAGER_POS.get(dept, dept_pos(dept, tier) + Vector3(3, 0, 3))


## Modèles de personnages (ils marchent au lieu d'osciller sur place).
const PERSON_MODELS := ["docker", "customs_officer", "inspector", "manager"]


## Accessoires le long des quais existants, en MultiMesh (modèles absents = ignorés) :
## bollards tous les 4 u, défenses entre eux, échelles aux extrémités de chaque poste, rails de portique sur le
## tablier à partir du T2, mouettes posées sur quelques bollards ; taquets d'amarrage rapide (quickmoor, vacmoor).
static func quay_props(nb_berths: int, quay_ext: bool, tier: int, built: Array = []) -> Array:
	var out: Array = []
	var gull_i := 0
	for bi in nb_berths:
		var b: Dictionary = BERTHS[mini(bi, BERTHS.size() - 1)]
		var x0 := float(b.x0)
		var x1 := float(b.x1) - (12.0 if bi == 0 and not quay_ext else 0.0)
		var x := x0 + 2.0
		var cleats := (bi < 2 and built.has("quickmoor")) or (bi >= 2 and built.has("vacmoor"))
		while x < x1 - 1.0:
			out.append({"m": "bollard", "p": Vector3(x, 0, SEA_EDGE_Z + 0.7), "ry": 0.0, "s": 1.0})
			if gull_i % 5 == 2:
				out.append({"m": "gull", "p": Vector3(x, 0, SEA_EDGE_Z + 0.7), "ry": 20.0 + gull_i * 70.0, "s": 1.0, "on": "bollard"})
			gull_i += 1
			if x + 4.0 < x1 - 1.0:
				out.append({"m": "fender", "p": Vector3(x + 2.0, 0, SEA_EDGE_Z), "ry": 0.0, "s": 1.0})
				if cleats:
					out.append({"m": "cleat", "p": Vector3(x + 2.0, 0, SEA_EDGE_Z + 0.6), "ry": 0.0, "s": 1.0})
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


## Mobilier urbain et marquages, en MultiMesh (modèles absents = ignorés) : brise-lames et enrochements,
## trottoirs et passages piétons du village, marquages de parc sur l'asphalte T2+, voie ferrée.
## Dimensions des modèles livrés : brise-lames 12 u selon X ; trottoir 6 × 1,2 (bordure côté -Z local, tournée vers la chaussée) ;
## passage piétons 6 × 2,4 ; dalle de marquage de parc 12 × 6 ; enrochements ≈ 2,5 u.
static func street_props(tier: int, built: Array) -> Array:
	var out: Array = []
	# brise-lames détaché à l'est de la passe, bordé d'enrochements côté large
	for bx in BREAKWATER_SEGS:
		out.append({"m": "breakwater", "p": Vector3(float(bx), -1.0, BREAKWATER_Z), "ry": 0.0, "s": 1.0})
	var rr := ["riprap", "riprap_b", "riprap_c"]
	for i in 21:
		out.append({"m": rr[i % 3], "p": Vector3(-19.0 + i * 2.9, -1.0, BREAKWATER_Z - 2.6 - float(i % 2) * 0.6),
			"ry": float(i * 67 % 360), "s": 0.8 + float(i % 4) * 0.12})
	# enrochements au bord est du terre-plein (interrompus au droit de l'appontement du GNL) ; brise-lames est et ses
	# enrochements côté large (lot D : il abrite les postes 3–4 ; « zone » : il surgit avec le terre-plein)
	if built.has(RECLAIM_BUILDING):
		for i in 10:
			var ez := -4.0 + i * 4.0
			if built.has("lng") and absf(ez - (LOTS.lng.p as Vector3).z) < 3.0:
				continue
			out.append({"m": rr[i % 3], "p": Vector3(151.5 + float(i % 2) * 0.8, -1.0, ez),
				"ry": float(i * 53 % 360), "s": 1.0 + float(i % 3) * 0.12})
		var zr := int(LOTS[RECLAIM_BUILDING].zone)
		for bx in BREAKWATER_E_SEGS:
			out.append({"m": "breakwater", "p": Vector3(float(bx), -1.0, BREAKWATER_Z), "ry": 0.0, "s": 1.0, "zone": zr})
		for i in 41:
			out.append({"m": rr[i % 3], "p": Vector3(43.5 + i * 2.95, -1.0, BREAKWATER_Z - 2.6 - float(i % 2) * 0.6),
				"ry": float(i * 61 % 360), "s": 0.8 + float(i % 4) * 0.12, "zone": zr})
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
		_grid(out, "yard_marks", 48.0, 6.0, 120.0, 30.0, 12.0, 6.0)
	# passage à niveau de la navette rail (E-Flux, E12) : marquage en travers de la voie des camions, au droit de la liaison
	if built.has("rail"):
		for cx in RAIL_CROSSING_MARKS:
			out.append({"m": "crosswalk", "p": Vector3(float(cx), 0.03, (float(LANE_BAND[0]) + float(LANE_BAND[1])) * 0.5), "ry": 90.0, "s": 1.0})
	out.append_array(rail_props(built))
	return out


static func _grid(out: Array, m: String, x0: float, z0: float, x1: float, z1: float, w: float, d: float) -> void:
	var x := x0 + w * 0.5
	while x < x1:
		var z := z0 + d * 0.5
		while z < z1:
			out.append({"m": m, "p": Vector3(x, 0.02, z), "ry": 0.0, "s": 1.0})
			z += d
		x += w


# ---------------------------------------------------------------------------
# Géométrie du plan (pure, testée dans run_all)
# ---------------------------------------------------------------------------

## Polygones de terre selon que le terre-plein existe : continent, brise-lames, terre-plein.
static func land_polys(reclaimed: bool) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = [PackedVector2Array(COAST), PackedVector2Array(BREAKWATER)]
	if reclaimed:
		out.append(PackedVector2Array(RECLAIM))
		out.append(PackedVector2Array(BREAKWATER_E))      # lot D : le brise-lames est vient avec le terre-plein
	return out


static func on_land(p: Vector2, reclaimed: bool) -> bool:
	for poly in land_polys(reclaimed):
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


## Bouées du chenal : rouges à bâbord (est) et vertes à tribord (ouest) en entrant, deux par tronçon, du large jusqu'à la
## passe (à l'abri du brise-lames, le bassin est libre : les navires y évoluent vers les postes).
static func channel_buoys() -> Array:
	var out: Array = []
	for i in CHANNEL.size() - 1:
		var a: Vector3 = CHANNEL[i]
		var b: Vector3 = CHANNEL[i + 1]
		var d := (b - a).normalized()
		var left := Vector3(d.z, 0, -d.x)
		for t in [0.25, 0.75]:
			var p := a.lerp(b, t)
			if p.z > PASS_Z - 6.0:      # la passe est marquée par ses feux : les bouées s'arrêtent au large
				continue
			out.append({"p": p + left * CHANNEL_HALF + Vector3(0, WATER_Y, 0), "red": true})
			out.append({"p": p - left * CHANNEL_HALF + Vector3(0, WATER_Y, 0), "red": false})
	return out



## Bande d'eau du chenal (contour de la zone « Chenal dragué ») : bord gauche puis bord droit.
static func channel_poly() -> Array:
	var left: Array = []
	var right: Array = []
	for i in CHANNEL.size():
		var a: Vector3 = CHANNEL[maxi(0, i - 1)]
		var b: Vector3 = CHANNEL[mini(CHANNEL.size() - 1, i + 1)]
		var d := Vector2(b.x - a.x, b.z - a.z).normalized()
		var n := Vector2(-d.y, d.x) * CHANNEL_HALF
		var c := Vector2((CHANNEL[i] as Vector3).x, (CHANNEL[i] as Vector3).z)
		left.append(c + n)
		right.push_front(c - n)
	return left + right


## Polygone d'une zone (le chenal est calculé).
static func zone_poly(z: Dictionary) -> Array:
	if bool(z.get("water", false)):
		return channel_poly()
	return z.poly


static func zone_by_id(id: int) -> Dictionary:
	for z in ZONES:
		if int(z.id) == id:
			return z
	return {}


static func poly_rect(poly: Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


## Rectangle (x, z) de l'empreinte d'une case, rotation comprise (multiples de 90°).
static func lot_rect(bid: String) -> Rect2:
	var l: Dictionary = LOTS[bid]
	var w := float(l.fp[0])
	var d := float(l.fp[1])
	if int(roundf(float(l.ry))) % 180 != 0:
		var t := w
		w = d
		d = t
	var p: Vector3 = l.p
	return Rect2(p.x - w * 0.5, p.z - d * 0.5, w, d)


## Point d'une polyligne à l'abscisse curviligne relative t (0–1) et cap (rotation Y d'un modèle orienté +X).
static func polyline_at(path: Array, t: float) -> Array:
	if path.size() == 1:
		return [path[0], 0.0]
	var total := 0.0
	for i in path.size() - 1:
		total += (path[i] as Vector3).distance_to(path[i + 1])
	var s := clampf(t, 0.0, 1.0) * total
	for i in path.size() - 1:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var l := a.distance_to(b)
		if s <= l or i == path.size() - 2:
			var d := (b - a) / maxf(l, 0.0001)
			return [a + d * minf(s, l), atan2(-d.z, d.x)]
		s -= l
	return [path[-1], 0.0]


static func path_length(path: Array) -> float:
	var total := 0.0
	for i in path.size() - 1:
		total += (path[i] as Vector3).distance_to(path[i + 1])
	return total


# ---------------------------------------------------------------------------
# Lot F2 — le golfe d'Ambre : rives du golfe, rive d'en face, forêt dense, routes et voie ferrée sous les arbres
# ---------------------------------------------------------------------------
## Terres au-delà du plan (sol vert sombre sous la forêt) : la rive ouest du golfe ferme l'anse des pêcheurs à l'ouest du cap,
## la rive est prolonge la baie est, l'arrière-pays s'étend au sud. Hors du continent (COAST) : ni zones, ni voies, ni
## navires (le large, le mouillage, les sorties nord et est restent à ≥ 60 u). Pas dans `land_polys` (plan coté inchangé) :
## le diorama les ajoute à la texture de l'eau (écume des rives).
const GULF_WEST := [Vector2(-132, 170), Vector2(-132, 60), Vector2(-148, 54), Vector2(-166, 36), Vector2(-182, 8),
	Vector2(-200, -34), Vector2(-222, -86), Vector2(-246, -140), Vector2(-276, -200), Vector2(-320, -262),
	Vector2(-380, -330), Vector2(-560, -330), Vector2(-560, 170)]
const GULF_EAST := [Vector2(186, 50), Vector2(208, 46), Vector2(236, 30), Vector2(262, 2), Vector2(276, -38),
	Vector2(286, -96), Vector2(312, -164), Vector2(350, -236), Vector2(400, -310), Vector2(600, -310), Vector2(600, 170),
	Vector2(186, 170)]
const HINTERLAND := [Vector2(-560, 166), Vector2(600, 166), Vector2(600, 600), Vector2(-560, 600)]
## Rive d'en face (modèle far_shore, 260 × 68, face au port) : deux pans au nord, de part et d'autre de l'entrée du golfe
## (les navires entrent et sortent par x −120…100) ; voilée de brume (Diorama).
const FAR_SHORES := [{"p": Vector3(-250, -1.0, -300), "ry": 0.0}, {"p": Vector3(232, -1.0, -300), "ry": 0.0}]
const FAR_HAZE := Color(0.78, 0.86, 0.93)
## Routes et voie ferrée qui entrent sous les arbres (modèle forest_road : route selon son axe local Z, entrée en +Z, le
## trafic disparaît dans l'ombre 6 u derrière l'origine) : autoroute (les deux bouts, là où les véhicules apparaissent et
## disparaissent, HIGHWAY_ENDS), rue du village vers l'ouest, voie ferrée à l'est (bouche RAIL_TUNNEL_X). « vanish » : point
## où le trafic se perd.
const FOREST_ROADS := [
	{"id": "highway_w", "p": Vector3(-122, 0, 141), "ry": 90.0, "vanish": Vector3(-128, 0, 141)},
	{"id": "highway_e", "p": Vector3(177, 0, 141), "ry": -90.0, "vanish": Vector3(183, 0, 141)},
	{"id": "village_w", "p": Vector3(-126, 0, 99), "ry": 90.0, "vanish": Vector3(-132, 0, 99)},
	{"id": "rail_e", "p": Vector3(175, 0, 57), "ry": -90.0, "vanish": Vector3(181, 0, 57)},
]
const FOREST_BLOCK := 19.0          # pas de la lisière (modèle forest_block ≈ 18,9 × 18,2)
const FOREST_DEEP := 21.0           # pas de la forêt profonde (lot F3 : blocs ×0,92–1,05 au lieu de ×2–2,4, plus serrés)
## Lot F3 : échelle des blocs de la forêt profonde — pins de 5,9 à 6,7 u, ≈ 1,3 × les arbres du village (« tree » ×0,85–1,3 :
## 3,1 à 4,8 u) ; avant : ×2,2, des couronnes deux à trois fois plus larges qu'une maison.
const FOREST_DEEP_SCALE := Vector2(0.92, 1.05)
## Étendue de la forêt : ce que la caméra peut montrer au zoom le plus large (CameraRig.set_tier_bounds), avec une marge.
const FOREST_AREA := Rect2(-345, -345, 770, 710)
const FOREST_CHUNK := 120.0         # un MultiMesh par carré de 120 u (les carrés hors champ ne sont pas dessinés)
## Bande de forêt sur le continent, au sud de l'autoroute (là où étaient les collines-tunnels).
const FOREST_STRIP := Rect2(-132, 152, 318, 16)


## Blocs de forêt [{p, ry, s}] (graine fixe, calculés une fois) : lisière (deux rangs serrés le long du continent et des rives),
## forêt profonde au-delà ; jamais à moins de 9 u de l'eau, d'une route sous les arbres, ni dans la bande de l'autoroute.
static var _forest_cache: Array = []


static func forest() -> Array:
	if _forest_cache.is_empty():
		_forest_cache = _make_forest()
	return _forest_cache


static func gulf_polys() -> Array[PackedVector2Array]:
	return [PackedVector2Array(GULF_WEST), PackedVector2Array(GULF_EAST), PackedVector2Array(HINTERLAND)]


## Terre (continent, rives du golfe, arrière-pays) en p ? (brise-lames et terre-plein exclus : la forêt n'y va pas)
static func any_land(p: Vector2) -> bool:
	if Geometry2D.is_point_in_polygon(p, PackedVector2Array(COAST)):
		return true
	for poly in gulf_polys():
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


## Tout le cercle de rayon r autour de p est-il à terre (8 points) ?
static func _land_ring(p: Vector2, r: float) -> bool:
	for k in 8:
		var a := TAU * float(k) / 8.0
		if not any_land(p + Vector2(cos(a), sin(a)) * r):
			return false
	return any_land(p)


static func _make_forest() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261015
	var out: Array = []
	var avoid: Array[Rect2] = [Rect2(-140, 133, 334, 16)]      # autoroute (et ses deux bouts)
	for fr in FOREST_ROADS:
		var c: Vector3 = fr.p
		avoid.append(Rect2(c.x - 11.0, c.z - 11.0, 22.0, 22.0))
	avoid.append(Rect2(150, 50, 40, 14))                         # voie ferrée jusqu'à la bouche est
	var coast := PackedVector2Array(COAST)
	# lisière (blocs serrés) : la bande au sud de l'autoroute, les quatre premiers rangs de l'arrière-pays, les terres du
	# golfe proches du continent ou de la mer ; forêt profonde (blocs agrandis) au-delà
	for pass_i in 2:
		var step := FOREST_BLOCK if pass_i == 0 else FOREST_DEEP
		var x := FOREST_AREA.position.x
		while x <= FOREST_AREA.end.x:
			var z := FOREST_AREA.position.y
			while z <= FOREST_AREA.end.y:
				var p := Vector2(x, z) + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)) * step
				z += step
				if Geometry2D.is_point_in_polygon(p, coast) and not FOREST_STRIP.has_point(p):
					continue
				var bad := false
				for r in avoid:
					if (r as Rect2).has_point(p):
						bad = true
				if bad or not _land_ring(p, 9.0 if pass_i == 0 else 16.0):
					continue
				var near := (p.y > 150.0 and p.y < 206.0) or (p.x < -132.0 and p.x > -190.0) or (p.x > 186.0 and p.x < 244.0) \
					or not _land_ring(p, 36.0)
				if (pass_i == 0) != near:
					continue
				out.append({"m": "forest_block", "p": Vector3(p.x, 0.0, p.y), "ry": float(rng.randi_range(0, 3)) * 90.0 + rng.randf_range(-12.0, 12.0),
					"s": rng.randf_range(0.95, 1.1) if pass_i == 0 else rng.randf_range(FOREST_DEEP_SCALE.x, FOREST_DEEP_SCALE.y), "deep": pass_i == 1})
			x += step
	return out


## Lot F2 — départ de rien : ce que le T1 fournit sans achat (le vieux quai et sa capitainerie, la grue mobile, le parc gravier et
## le hangar, la route et les barrières de la gate) se bâtit à l'entrée du T1, une pièce après l'autre (quai → grue → parc →
## gate), chacune avec son chantier. « rects » : emprises (palissade « hoarding », échafaudage « scaffold », quai « quay » :
## grue de chantier à terre, « none » : poussière seule) ; « dur » : durée du chantier (s) ; « machine » : engin qui travaille.
## Les éléments de chaque pièce portent « grp » dans PROPS et GROUNDS (quai, grue, musoirs : Diorama).
const STARTER := []      # lot G2 : plus de séquence de chantiers automatique — les pièces du départ sont des bâtiments


static func starter(id: String) -> Dictionary:
	for s in STARTER:
		if String(s.id) == id:
			return s
	return {}


## Lot G2 — plateforme (Terrassement) : dalles `ground_platform` (8 × 8) sur la case, avant le parc de stockage (gravier).
const PLATFORM_RECT := Rect2(-36, 0, 36, 18)
## Piste (Piste et barrière) : modules `track_dirt` (8 u) le long de la route d'accès et de la voie des camions, tant que la
## route n'est pas bitumée (deuxième voie de gate, T2).
const TRACK_RUNS := [[Vector3(-21, 0, 33), Vector3(-1, 0, 33)], [Vector3(-21, 0, 37), Vector3(-21, 0, 69)]]
## Grue de bord du caboteur (`coaster_crane`) : position sur le pont, en repère du navire (méta deck_pos_on_coaster).
const BOARD_CRANE_POS := Vector3(3.6, 0.0, 0.0)


## Chantier d'un bâtiment acheté : emprises, genre, durée (3 s pour une petite case, 6 s pour un quai ou une grande case).
static func site_spec(bid: String) -> Dictionary:
	if not LOTS.has(bid):
		return {}
	var l: Dictionary = LOTS[bid]
	var r := lot_rect(bid)
	var area := r.get_area()
	var dur := clampf(3.0 + 3.0 * (area - 30.0) / (600.0 - 30.0), 3.0, 6.0)
	var kind := "hoarding"
	var machine := "excavator"
	if bid == RECLAIM_BUILDING:
		kind = "water"          # le terre-plein : le remblai avance sur l'eau (ouverture de zone, barges et sable)
		machine = ""
		dur = 6.0
	elif bid.begins_with("berth") or bid == "quay_ext" or bid == "quay1":
		kind = "quay"
		machine = "site_crane"
		dur = 6.0
	elif bool(l.get("water", false)):
		kind = "water"
		machine = ""
		dur = 5.0 if bid == "dredge1" else 3.0
	elif bid == "track":      # lot G2 : la piste et la barrière (un engin aplanit la route)
		kind = "hoarding"
	elif l.has("on") or bool(l.get("portal", false)):
		kind = "scaffold"
		machine = ""
	elif area <= 80.0:
		kind = "scaffold"
		machine = "" if area < 20.0 else "excavator"
	var mp := Vector3(r.end.x + 3.5, 0, r.get_center().y)
	if kind == "quay":
		mp = Vector3(r.get_center().x - r.size.x * 0.25, 0, r.end.y + 4.0)
	return {"id": bid, "dur": dur, "machine": machine, "machine_p": mp, "rects": [[r, kind]], "focus": r.grow(6.0)}


## État d'avant d'une case (lot F2) : rochers et broussailles sur une case à terre, rien sur l'eau, sur un quai ou sur une
## route ; rien non plus sur le terre-plein (sable neuf). [{m, p, ry, s}], graine fixe par case.
static func before_state(bid: String) -> Array:
	if not LOTS.has(bid):
		return []
	var l: Dictionary = LOTS[bid]
	var z := zone_by_id(int(l.zone))
	if bid == "track":      # lot G2 : la route d'accès en friche
		return _rubble(Rect2(-25, 37, 8, 12), 14)
	if bid == "quay1":      # lot G2 : l'estacade ruinée devant le vieux quai
		return [{"m": "jetty_ruin", "p": Vector3(-24.0, 0.0, -7.2), "ry": 0.0, "s": 1.0},
			{"m": "rock", "p": Vector3(-44.0, -1.0, -8.0), "ry": 40.0, "s": 1.0}, {"m": "rock", "p": Vector3(-8.0, -1.0, -7.5), "ry": 200.0, "s": 0.8}]
	if bool(l.get("water", false)) or l.has("on") or bool(l.get("portal", false)) or bool(z.get("reclaim", false)) \
			or bid.begins_with("berth") or bid == "quay_ext" or bid == "gate2":
		return []
	return _rubble(lot_rect(bid), hash(bid))


## Rochers et broussailles dans un rectangle (état d'avant), à 0,8 u des bords.
static func _rubble(r: Rect2, seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := clampi(int(r.get_area() / 45.0), 2, 9)
	var out: Array = []
	var inner := r.grow(-0.8)
	for i in n:
		var p := Vector2(rng.randf_range(inner.position.x, inner.end.x), rng.randf_range(inner.position.y, inner.end.y))
		var m := "rock" if rng.randf() < 0.35 else "bush"
		out.append({"m": m, "p": Vector3(p.x, 0.0, p.y), "ry": rng.randf_range(0.0, 360.0),
			"s": rng.randf_range(0.7, 1.0) if m == "rock" else rng.randf_range(0.8, 1.25)})
	return out


## État d'avant d'une pièce de départ (friche) : l'estacade ruinée devant le vieux quai, des rochers et des broussailles sur
## le parc, devant la capitainerie et à la gate.
static func starter_before(id: String) -> Array:
	match id:
		"quay0":
			var out := _rubble(Rect2(-46.2, 3.4, 6.4, 5.3), 11)
			out.append({"m": "jetty_ruin", "p": Vector3(-24.0, 0.0, -7.2), "ry": 0.0, "s": 1.0})
			out.append({"m": "rock", "p": Vector3(-44.0, -1.0, -8.0), "ry": 40.0, "s": 1.0})
			out.append({"m": "rock", "p": Vector3(-8.0, -1.0, -7.5), "ry": 200.0, "s": 0.8})
			return out
		"yard0":
			var out2 := _rubble(Rect2(-36, 0.5, 36, 17.5), 12)
			out2.append_array(_rubble(Rect2(-45.6, 13.9, 7.2, 10.2), 13))
			return out2
		"gate0":
			return _rubble(Rect2(-25, 37, 8, 12), 14)
	return []


## Lot F2 — premier navire du T1 : il naît hors champ dans le chenal (voie d'entrée, tronçon FIRST_SHIP_LANE) à la fin du
## chantier du quai et file vers son poste, sans passer par le mouillage.
const FIRST_SHIP_LANE := 1


static func first_ship_path(bi: int) -> Array[Vector3]:
	var full := ship_path_pilot_from(CHANNEL_ENTRY + Vector3(0, 0, -6), bi)
	var start := channel_lane(FIRST_SHIP_LANE, 1)
	var out: Array[Vector3] = []
	for p in full:
		if not out.is_empty():
			out.append(p)
		elif (p as Vector3).distance_to(start) < 0.01:
			out.append(p)
	return out


## Échantillons d'une polyligne tous les `step` u (tests de trajets).
static func sample_path(path: Array, step: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in path.size() - 1:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var n := maxi(1, ceili(a.distance_to(b) / step))
		for k in n:
			out.append(a.lerp(b, float(k) / float(n)))
	if not path.is_empty():
		out.append(path[-1])
	return out


# ---------------------------------------------------------------------------
# Lot F3 — l'anse des pêcheurs (acte 0 « La Crique ») : à l'ouest du cap, entre le cap et la rive ouest du golfe, loin du
# chenal et des voies des cargos (arrivée par le nord-ouest au-delà de z −60 : les bateaux de pêche restent au sud de z −35,
# à ≥ 45 u du mouillage). Plan coté : PLAN_COTE.md § 5 ter.
# ---------------------------------------------------------------------------
## Cadrage de la Crique : l'anse, son ponton, la criée, la cabane d'Odette, le flanc du cap (dans les bornes CRIQUE_BOUNDS).
const ANSE_LOOK := Vector3(-117.0, 0.0, 40.0)
const ANSE_ZOOM := 62.0
## Lot G1 — bornes de la caméra pendant la Crique (centre), zoom le plus large : les nuages aux bords, jamais le bord du monde.
const CRIQUE_BOUNDS := Rect2(-128.0, 18.0, 24.0, 28.0)
const CRIQUE_ZOOM_MAX := 72.0
## Lot G1 — le ponton des places (modèle pontoon : module 6 × 1,6 le long de X, plancher à +0,45 au-dessus de la flottaison) :
## un seul ponton le long de la plage, à z 48,4, qui part de x −140 et s'allonge vers l'est ; 9 places (niveau 1 = 2 barques,
## puis une par niveau) au pas de 4 u, à z 46,6 (étrave à l'est). Modules par niveau de Places (2 au départ, 6 au plus : la
## plage fait 36 u) ; passerelle de 2 modules vers la plage en x −130.
const PLACES_PONTOON_Z := 48.4
const PLACES_PONTOON_X0 := -140.0
const PLACES_MODULES := {1: 2, 2: 2, 3: 3, 4: 4, 5: 4, 6: 5, 7: 6, 8: 6}
const PLACES_GANGWAY := [{"c": Vector2(-130, 52.2), "n": 1, "axis": "z"}, {"c": Vector2(-130, 58.2), "n": 1, "axis": "z"}]
## Bâtiments de l'anse (modèle, position, rotation Y en degrés) : les paliers nommés des Services (criée, pompe, lavage, glace),
## la cabane d'Odette (toujours là), l'état d'avant du ponton (ponton pourri), la grande jetée des thoniers (lot G1) et sa
## passerelle, les modules de la marina.
const ANSE_BUILDINGS := {
	"hall": {"m": "fish_hall", "p": Vector3(-99.0, 0.0, 55.5), "ry": 0.0},
	"fuel": {"m": "fuel_pump", "p": Vector3(-107.0, 0.0, 54.0), "ry": 0.0},
	"wash": {"m": "wash_bay", "p": Vector3(-118.0, 0.0, 59.5), "ry": 0.0},
	"ice": {"m": "ice_plant", "p": Vector3(-88.5, 0.0, 28.0), "ry": 90.0},
}
const ODETTE_HUT := {"m": "odette_hut", "p": Vector3(-127.0, 0.0, 62.5), "ry": 0.0}
const ANSE_RUIN := {"m": "pontoon_ruin", "p": Vector3(-134.0, -1.0, 48.4), "ry": 0.0}
## Quai des chalutiers (le long du cap, modules pontoon axe z), grande jetée (béton sur pieux, 14 × 2,5, axe z) et sa passerelle.
const TRAWLER_QUAY := {"c": Vector2(-95.6, 31.0), "n": 5, "axis": "z"}
const PIER := {"m": "pier_long", "p": Vector3(-96.0, 0.0, 7.0), "ry": 90.0, "size": Vector2(2.5, 14.0)}
const PIER_GANGWAY := {"c": Vector2(-92.0, 1.0), "n": 1, "axis": "x"}
## Marina : modules flottants 10 × 1,8 (axe z) dans l'intérieur de la boucle des bateaux (jamais traversé) ; 8 anneaux par
## module, voiliers des deux côtés (longueur le long de x) ; la marina, puis ses deux extensions.
const MARINA_MODULES := {
	"marina": [{"c": Vector2(-125, 36), "n": 1, "axis": "z"}],
	"marina2": [{"c": Vector2(-125, 26), "n": 1, "axis": "z"}],
	"marina3": [{"c": Vector2(-113, 36), "n": 1, "axis": "z"}],
}
const MARINA_MODULE := Vector2(10.0, 1.8)
## Route du mareyeur (construite avec la criée) : de la criée à la rue du village, puis sous les arbres (village_w).
const FISH_ROAD := Rect2(-102, 59, 6, 37)
const FISH_VAN_PARK := Vector3(-97.5, 0.0, 63.5)       # voie montante (à droite vers le nord) ; descente en x −100,5
## Places (centre du bateau, cap en radians : 0 = étrave à l'est, PI/2 = étrave au nord) par classe et numéro de place.
const FISH_BERTHS := {
	"dinghy": [Vector3(-138, 0, 46.6), Vector3(-134, 0, 46.6), Vector3(-130, 0, 46.6), Vector3(-126, 0, 46.6), Vector3(-122, 0, 46.6),
		Vector3(-118, 0, 46.6), Vector3(-114, 0, 46.6), Vector3(-110, 0, 46.6), Vector3(-106, 0, 46.6)],
	"trawler": [Vector3(-98.0, 0, 40.5), Vector3(-98.0, 0, 31.5)],
	"tuna": [Vector3(-99.5, 0, 7.0)],
}
## Coins de pêche (centre du cercle de dérive) par classe et numéro : dans l'anse pour les barques, à son entrée pour les
## chalutiers, au large le long de la rive ouest pour le thonier.
const FISH_GROUNDS := {
	"dinghy": [Vector2(-126, 14), Vector2(-116, 6), Vector2(-130, 2), Vector2(-120, -4), Vector2(-136, 10), Vector2(-112, -2),
		Vector2(-124, -10), Vector2(-134, -6), Vector2(-142, 2)],
	"trawler": [Vector2(-150, -14), Vector2(-138, -22)],
	"tuna": [Vector2(-160, -20)],
}
## Point d'arrivée d'un bateau qui vient pour la première fois, par classe (au nord de l'anse, hors du cadrage de la Crique :
## il y paraît en fondu, puis descend la voie ouest à sa vitesse).
const FISH_SEA_ENTRY := {"dinghy": Vector2(-148, -10), "trawler": Vector2(-152, -20), "tuna": Vector2(-160, -32)}


static func fish_sea_entry(cls: String) -> Vector2:
	return FISH_SEA_ENTRY.get(cls, Vector2(-150, -14))
## Boucle à sens unique (sens inverse des aiguilles d'une montre) : on descend la voie ouest (x −146), on longe la plage
## vers l'est (z 44, au nord des barques amarrées), on remonte la voie est (x −102, le long du quai des chalutiers) ; le thonier
## la remonte jusqu'à sa jetée (z 7) et en sort au nord de z −2.
const FISH_LANE_W := -146.0
const FISH_LANE_BEACH := 44.0
const FISH_LANE_E := -102.0
const FISH_EXIT_Z := 16.0
const FISH_EXIT_Z_TUNA := -2.0
const FISH_TURN_R := 4.0


static func fish_berth(cls: String, slot: int) -> Vector3:
	var a: Array = FISH_BERTHS.get(cls, [])
	return a[clampi(slot, 0, a.size() - 1)] if not a.is_empty() else Vector3(-120, 0, 30)


## Cap d'un bateau à sa place : les barques ont l'étrave à l'est (on longe la plage vers l'est), les autres au nord.
static func fish_berth_yaw(cls: String) -> float:
	return 0.0 if cls == "dinghy" else PI * 0.5


static func fish_ground(cls: String, slot: int) -> Vector2:
	var a: Array = FISH_GROUNDS.get(cls, [])
	return a[slot % a.size()] if not a.is_empty() else Vector2(-125, 5)


static func fish_exit_z(cls: String) -> float:
	return FISH_EXIT_Z_TUNA if cls == "tuna" else FISH_EXIT_Z


## Trajet de sortie {pts, crab} : `crab` = indices i des tronçons i → i+1 parcourus en glissement latéral (cap tenu). Barques :
## glissement vers la voie de la plage, à l'est le long de la plage, voie est vers le nord, puis le coin de pêche. Chalutiers,
## thonier : glissement vers la voie est, puis le nord. Coins arrondis (aucune rotation sur place).
static func fish_path_out(cls: String, slot: int) -> Dictionary:
	var b := fish_berth(cls, slot)
	var g := fish_ground(cls, slot)
	var raw: Array[Vector3] = [b]
	if cls == "dinghy":
		raw.append(Vector3(b.x, 0, FISH_LANE_BEACH))
		raw.append(Vector3(FISH_LANE_E, 0, FISH_LANE_BEACH))
	else:
		raw.append(Vector3(FISH_LANE_E, 0, b.z))
	raw.append(Vector3(FISH_LANE_E, 0, fish_exit_z(cls)))
	raw.append(Vector3(g.x, 0, g.y))
	return {"pts": _round_corners(raw, 2, raw.size() - 1, FISH_TURN_R), "crab": [0]}


## Trajet de retour {pts, crab} depuis `from` (le coin de pêche, ou l'arrivée du large) : voie ouest vers le sud, la plage
## vers l'est ; une barque glisse à sa place depuis la voie de la plage ; un chalutier (ou le thonier) remonte la voie est
## puis glisse à sa place.
static func fish_path_back(cls: String, slot: int, from: Vector2, lead := Vector2.ZERO) -> Dictionary:
	var b := fish_berth(cls, slot)
	var raw: Array[Vector3] = [Vector3(from.x, 0, from.y)]
	# (`lead` : cap de départ — au coin de pêche, celui de la fin de la dérive : le bateau repart en avançant, sans tourner sur place)
	if lead != Vector2.ZERO:
		raw.append(Vector3(from.x + lead.x * 6.0, 0, from.y + lead.y * 6.0))
	raw.append(Vector3(FISH_LANE_W, 0, minf(from.y + 6.0, 10.0)))
	raw.append(Vector3(FISH_LANE_W, 0, FISH_LANE_BEACH))
	if cls == "dinghy":
		raw.append(Vector3(b.x, 0, FISH_LANE_BEACH))
	else:
		raw.append(Vector3(FISH_LANE_E, 0, FISH_LANE_BEACH))
		raw.append(Vector3(FISH_LANE_E, 0, b.z))
	raw.append(b)
	var pts := _round_corners(raw, 1, raw.size() - 2, FISH_TURN_R)
	return {"pts": pts, "crab": [pts.size() - 2]}


## Arrondit les coins d'indices [i0, i1[ d'une polyligne (rayon r) ; les autres coins restent vifs (glissements).
static func _round_corners(raw: Array[Vector3], i0: int, i1: int, r: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in raw.size():
		if i >= i0 and i < i1 and i > 0 and i < raw.size() - 1:
			out.append_array(_fillet(raw[i - 1], raw[i], raw[i + 1], r, 6))
		else:
			out.append(raw[i])
	return _dedup(out)

static func _dedup(pts: Array[Vector3]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in pts:
		if out.is_empty() or (out[-1] as Vector3).distance_to(p) > 0.05:
			out.append(p)
	return out


## Modules du ponton des places au niveau `lv` : [{c, n, axis}] (un seul ponton le long de la plage, plus la passerelle).
static func places_pontoons(lv: int) -> Array:
	if lv <= 0:
		return []
	var n := int(PLACES_MODULES.get(lv, 6))
	var out: Array = [{"c": Vector2(PLACES_PONTOON_X0 + 3.0 * float(n), PLACES_PONTOON_Z), "n": n, "axis": "x"}]
	out.append_array(PLACES_GANGWAY)
	return out


## Pontons d'un élément de l'anse (quai des chalutiers, passerelle de la jetée) : [{c, n, axis}].
static func anse_pontoons(id: String) -> Array:
	match id:
		"trawler":
			return [TRAWLER_QUAY]
		"pier":
			return [PIER_GANGWAY]
	return []


## Rectangle (x, z) d'un ponton (module 6 × 1,6).
static func pontoon_rect(pd: Dictionary) -> Rect2:
	var c: Vector2 = pd.c
	var l := 6.0 * float(pd.n)
	return Rect2(c.x - l * 0.5, c.y - 0.8, l, 1.6) if String(pd.axis) == "x" else Rect2(c.x - 0.8, c.y - l * 0.5, 1.6, l)


## Rectangle (x, z) d'un module de marina (10 × 1,8, axe z) et ses places de voiliers [{p: Vector3, yaw}] (4 de chaque côté).
static func marina_rect(md: Dictionary) -> Rect2:
	var c: Vector2 = md.c
	return Rect2(c.x - MARINA_MODULE.y * 0.5, c.y - MARINA_MODULE.x * 0.5, MARINA_MODULE.y, MARINA_MODULE.x)


static func marina_slots(md: Dictionary) -> Array:
	var c: Vector2 = md.c
	var out: Array = []
	for k in 4:
		var z := c.y - 3.75 + 2.5 * float(k)
		out.append({"p": Vector3(c.x - 3.5, 0, z), "yaw": 0.0})
		out.append({"p": Vector3(c.x + 3.5, 0, z), "yaw": PI})
	return out


## Rectangle (x, z) de la grande jetée.
static func pier_rect() -> Rect2:
	var p: Vector3 = PIER.p
	var sz: Vector2 = PIER.size
	return Rect2(p.x - sz.x * 0.5, p.z - sz.y * 0.5, sz.x, sz.y)


## Tous les rectangles où un bateau ne passe jamais (pontons, quai, jetée, marina), pour les contrôles.
static func anse_obstacles() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for pd in places_pontoons(8):
		out.append(pontoon_rect(pd))
	for id in ["trawler", "pier"]:
		for pd in anse_pontoons(id):
			out.append(pontoon_rect(pd))
	out.append(pier_rect())
	for id in MARINA_MODULES:
		for md in MARINA_MODULES[id]:
			out.append(marina_rect(md).grow_individual(5.4, 0.8, 5.4, 0.8))      # les voiliers des deux côtés (3,5 u, étrave au ponton)
	return out


## Chantier d'un élément de la Crique (SiteWorks) : « places_N » (la place nouvelle et, s'il y en a un, le module de ponton
## nouveau : éclaboussures), « services_N » (le palier nommé : palissade, pelleteuse ; la criée amène la route), « trawler »,
## « pier », « marina* » (sur l'eau). {} s'il n'y a rien à montrer. `cfg` : config.json › fishing.
static func anse_site_spec(key: String, cfg: Dictionary = {}) -> Dictionary:
	var rects: Array = []
	var machine := ""
	var mp := Vector3.ZERO
	var dur := 3.5
	if key.begins_with("places_"):
		var lv := int(key.substr(7))
		var slot := mini(lv, FISH_BERTHS.dinghy.size() - 1)       # la place nouvelle (niveau 1 : les deux premières)
		var b: Vector3 = FISH_BERTHS.dinghy[slot]
		rects.append([Rect2(b.x - 2.0, b.z - 1.0, 4.0, 2.0), "water"])
		var before := int(PLACES_MODULES.get(lv - 1, 2)) if lv > 1 else 0
		var now := int(PLACES_MODULES.get(lv, 6))
		if now > before:
			rects.append([Rect2(PLACES_PONTOON_X0 + 6.0 * float(before), PLACES_PONTOON_Z - 0.8, 6.0 * float(now - before), 1.6), "water"])
		if lv == 1:
			for pd in PLACES_GANGWAY:
				rects.append([pontoon_rect(pd), "water"])
		dur = float(cfg.get("places", {}).get("dur", 3.0))
	elif key.begins_with("services_"):
		var nl: Dictionary = cfg.get("services", {}).get("named", {}).get(key.substr(9), {})
		if nl.is_empty() or not ANSE_BUILDINGS.has(String(nl.id)):
			return {}
		var bd: Dictionary = ANSE_BUILDINGS[String(nl.id)]
		var fp: Array = Assets.meta(String(bd.m)).get("footprint", [6.0, 6.0])
		var w := float(fp[0])
		var d := float(fp[1])
		if absf(float(bd.ry)) > 45.0:
			var tmp := w
			w = d
			d = tmp
		var p: Vector3 = bd.p
		rects.append([Rect2(p.x - w * 0.5, p.z - d * 0.5, w, d), "hoarding"])
		machine = "excavator"
		mp = Vector3(p.x + w * 0.5 + 3.0, 0, p.z + 2.0)
		if String(nl.id) == "hall":
			rects.append([FISH_ROAD, "none"])
		dur = float(nl.get("dur", 4.5))
	elif key == "trawler" or key == "pier":
		for pd in anse_pontoons(key):
			rects.append([pontoon_rect(pd), "water"])
		if key == "pier":
			rects.append([pier_rect(), "water"])
		dur = float(_fish_building(cfg, key).get("dur", 5.0))
	elif MARINA_MODULES.has(key):
		for md in MARINA_MODULES[key]:
			rects.append([marina_rect(md), "water"])
		dur = float(_fish_building(cfg, key).get("dur", 4.0))
	if rects.is_empty():
		return {}
	var all: Rect2 = rects[0][0]
	for rk in rects:
		all = all.merge(rk[0])
	return {"id": "fish_" + key, "dur": dur, "machine": machine, "machine_p": mp, "rects": rects, "focus": all.grow(6.0)}


static func _fish_building(cfg: Dictionary, id: String) -> Dictionary:
	for b in cfg.get("buildings", []):
		if String(b.id) == id:
			return b
	return {}


## Lot G1 — les nuages de la Crique : tout le rectangle habillé du monde est couvert, sauf le trou de l'anse (la plage, le
## ponton, la cabane, la criée et sa route jusqu'à la forêt, la mer au nord où passe le caboteur de l'annonce).
const CLOUD_COVER := Rect2(-330, -350, 740, 710)
const CLOUD_HOLE := [Rect2(-200, 0, 116, 74), Rect2(-236, -80, 152, 80), Rect2(-106, 72, 14, 34)]
const CLOUD_Y := 11.0
const CLOUD_BANK := Vector2(24.0, 12.0)
## Caboteur de l'annonce (8ᵉ minute) : il traverse au large, dans le trou des nuages, vers l'est.
const PASSING_SHIP_PATH := [Vector3(-226, 0, 12), Vector3(-134, 0, -80)]
## Cadrage de l'annonce (dans les bornes de la Crique, zoom le plus large) : le large au nord-ouest, en haut de l'écran.
const ANNOUNCE_LOOK := Vector3(-128.0, 0.0, 18.0)


static func in_cloud_hole(p: Vector2) -> bool:
	for r in CLOUD_HOLE:
		if (r as Rect2).has_point(p):
			return true
	return false


## Lot F3 — bascule : le caboteur de Corsaire & Fils entre dans le golfe au nord-ouest (hors champ), longe le large jusqu'à
## l'entrée du chenal (point d'attente tant que le vieux quai n'est pas debout), puis suit le pilotage du premier navire.
const BASCULE_SHIP_FROM := Vector3(-150.0, 0.0, -118.0)


static func bascule_ship_path(bi: int) -> Array[Vector3]:
	return ship_path_pilot_from(BASCULE_SHIP_FROM, bi)

## Lot F3 — mouvement des bateaux de pêche (FishingView ; pur, testé par run_all) : un mètre de glissement latéral « coûte »
## trois mètres de route (lent) ; rampes d'accélération et de freinage de 2 s en début et fin de trajet.
const FISH_CRAB_WEIGHT := 3.0
const FISH_RAMP_S := 2.0


## Longueurs pondérées d'un trajet (glissement latéral plus lent).
static func fish_weigh(p: Dictionary) -> Dictionary:
	var pts: Array = p.pts
	var crab: Array = p.crab
	var cum: Array[float] = [0.0]
	var w: Array[float] = []
	for i in pts.size() - 1:
		var k := FISH_CRAB_WEIGHT if crab.has(i) else 1.0
		w.append(k)
		cum.append(cum[-1] + (pts[i] as Vector3).distance_to(pts[i + 1]) * k)
	return {"pts": pts, "crab": crab, "cum": cum, "w": w, "len": cum[-1]}


## Profil trapézoïdal (0–1 → 0–1) : rampes de `r` au départ et à l'arrivée, vitesse constante entre les deux.
static func fish_profile(f: float, r: float) -> float:
	f = clampf(f, 0.0, 1.0)
	r = clampf(r, 0.001, 0.5)
	var v := 1.0 / (1.0 - r)
	if f < r:
		return v * f * f / (2.0 * r)
	if f > 1.0 - r:
		return 1.0 - v * (1.0 - f) * (1.0 - f) / (2.0 * r)
	return v * (f - r * 0.5)


## Point d'un trajet pondéré à la fraction `e` de sa longueur : [position, direction, glissement ?].
static func fish_path_at(wp: Dictionary, e: float) -> Array:
	var pts: Array = wp.pts
	var cum: Array = wp.cum
	var target := clampf(e, 0.0, 1.0) * float(wp.len)
	for i in pts.size() - 1:
		if target <= float(cum[i + 1]) or i == pts.size() - 2:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var seg := float(cum[i + 1]) - float(cum[i])
			var f := clampf((target - float(cum[i])) / maxf(0.0001, seg), 0.0, 1.0)
			return [a.lerp(b, f), (b - a).normalized(), (wp.crab as Array).has(i)]
	return [pts[-1], Vector3.RIGHT, false]
