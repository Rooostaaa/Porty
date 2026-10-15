# Plan coté définitif — « La baie et le terre-plein » (13/10/2026, réorganisé au lot D le 14/10, flux du lot E le 14/10 au soir, anse des pêcheurs au lot F3 le 15/10)

Source unique des cotes : `godot/scripts/world/layout.gd` (constantes citées entre parenthèses). Repère du jeu : **x vers l'est**
(droite-bas de l'écran), **z vers le sud** (gauche-bas), mer en z négatif, bord des quais à **z = −6**. Captures de validation :
`docs/captures/plan_cote_vue_dessus.png` (plan vu de dessus, avant le lot D), `docs/captures/d_monde_*.png` (lot D, dont
`d_monde_plan_dessus.png`, le plan vu de dessus après réorganisation), `docs/captures/e_flux_*.png` (lot E).
**Règle d'or : rien n'est posé « là où il reste de la place » ; chaque bâtiment a sa case, dessinée dès le départ (empreinte
`ghost_lot`).** Lot D (revue `REVUE_CRITIQUE_PORT.md`, axe 1) : circulation à droite, douane côté sortie dans une enceinte, pôle
nautique sur le cap, bureaux du port côté public, gare contre le terre-plein, brise-lames et passe est au palier 3.

## 1. Terrain (polygones construits dans Godot, `COAST`, `BREAKWATER`, `BREAKWATER_E`, `RECLAIM` ; lot F2 : rives du golfe et forêt, § 5 bis)
- **Continent** : plage ouest (−132, 60) → (−94, 48) ; **cap** (−92, 24) → (−86, −16) → (−72, −42) → pointe (−64, −44) → (−58, −38) ;
  **crique** (−56, −26) → (−56, −14) → (−52, −8) → (−48, −6) ; **côte des quais** z = −6 de x = −48 à 48 ; **baie est**
  (48, 32) → (62, 40) → (100, 44) → (136, 42) → (152, 36) → (186, 50). Dessus herbe, flancs en deux couches de terre (2,4 u).
- **Butte** (1,4 u, `BUTTE`) : le **pôle nautique** sur le cap (zone 9) — l'ancienne Colline du port est aplanie (bureaux du port).
- **Brise-lames** x −18…42, z −46…−42 (5 segments, enrochements côté large) ; passe ouest de 46 u entre la pointe du cap et sa tête.
- **Brise-lames est** (palier 3, avec `berth3`, `BREAKWATER_E`) : x 42…162, 10 segments, 41 enrochements ; il surgit avec le
  terre-plein. **Passe est** entre sa tête (162, −44) et l'angle nord-est du terre-plein (150, −6) : feu **vert** sur la tête
  (164,5 ; −44), feu **rouge** à l'angle (152,5 ; −7,5) (on entre vers l'ouest : rouge à bâbord).
- **Terre-plein** (palier 3) : (48, −6) → (150, −6) → (152, 36) → (136, 42) → (100, 44) → (62, 40) → (48, 32).
- Ouvrages construits dans Godot : **cale de halage** de l'atelier (`SLIPWAY`, rampe de béton de (−60,2 ; −27) sur la butte à
  (−54,2 ; −27) sous l'eau de la crique, un bateau hissé) ; **appontement** du GNL (`JETTIES`, 10,6 × 3 u en (156 ; 12,5), barge
  de soutage).

## 2. Zones (`ZONES`) — une zone ouverte par un bâtiment porte le nom de ce bâtiment (même achat, même nom)
| # | Zone | Ouvre | Polygone (x, z) | Bâtiments (case : centre x, z · rotation · empreinte) |
|---|---|---|---|---|
| 1 | Vieux port | départ | −48…0 × −6…30 | gravel2, supply, crane2, gravel3, tug2 (inchangés) ; hangar (−42 ; 19), remplacé au T3 par la **halle d'inspection** |
| 2 | Allongement du quai | `quay_ext` | −12…0 × −6,5…0 | quay_ext · sts1 |
| 3 | **Bureau de douane** (enceinte) | `customs1` | −42…−24 × 30…44 + voie de sortie −24…−21 × 36…44 | customs1 (−28,5 ; 40,5 · 6,8×5) · scanner1 (−38 ; 40,5 · 8×4,4 : bureau + camion-scanner) · scanner2 (−22,5 ; 39,5 · 90° · portique **sur la voie de sortie**) ; aire d'inspection z 31…37 |
| 4 | **Gate** | départ | la route x −24…−18, de l'enceinte à z 50 | barrières (aucun bâtiment à acheter) |
| 5 | Dragage du chenal | `dredge1` | bande de 14 u le long du chenal | dredge1 |
| 6 | Quai n°2 | `berth2` | L : 0…48 × −6…5 et 0…36 × 5…30 | berth2 · asphalt · quickmoor (repère : grue mobile du quai n°2) |
| 7 | Pôle froid | `reefer` | 36…48 × 5…30 | reefer (bâtiment renommé « Pôle froid ») |
| 8 | Deuxième voie de gate (grise « discrète ») | `gate2` | voie x −18…−12 × 36…54 et parkings −18…6 × 54…108 (lot E) | gate2 (guérite **−17,25 ; 46,5 sur un îlot** entre la 2ᵉ voie de sortie et l'entrée : **2ᵉ voie de sortie**, second portique sur x −19,5 si scanner2) · parking1 · parking2 |
| 9 | **Pôle nautique** (butte, grise « discrète ») | palier 2 | cap : (−77,−31) (−58,6,−31) (−57,−24) (−57,−13) (−60,5,−5) (−77,−5) | **tour VTS** (−62 ; −16, ≈ 35 u de la passe) · rpilot (−69 ; −14, au pied) · repair (−63 ; −27 · 90°, atelier + cale sur la crique) |
| 10 | Quai profond n°3 (terre-plein) | `berth3` | 48…121 × −6…44 | berth3 · rtg (84 ; 18 · 70×22) · berth4 · vacmoor ; sous-station |
| 11 | Station de soutage GNL | `lng` | 121…152 × −6…42 | lng (145 ; **15,5** : 4,1 u du poste 4) + appontement (156 ; 15,5) · imo (**129,1** ; 11,5 : 4,1 u du parc RTG, 5,1 u du GNL) · oog (129,1 ; 24) |
| 12 | **Terminal rail** (gare) | `rail` | contre le terre-plein : (56,44)…(150,41,5) → z 70 | rail (100 ; 52 · 18,5×3,7, quai) ; voie z = 57 de x 62 au tunnel est (184 ; 58) ; liaison x 87…93 (axe de l'allée x 90,1), z 36…48 avec la voie des camions du terre-plein, **passage à niveau signalé** (lot E) |
| 13 | **Bureaux du port** (ex-Colline) | palier 2 | −66…−24 × 46…67 | ewindow (−31 ; 54) · ecustoms (−40 ; 54) · tos (−49 ; 54), tournés vers la **rue des bureaux** (x −54…−24, **z 60…66**, lot E : derrière la tête de file) reliée à la route d'accès |

La zone logistique (z 84…126) reste en arrière-plan, grise jusqu'à la gare. Plus de bande d'herbe vide : bosquets entre
x 9 et 52, z 36…80 (végétation `scatter`), gare dans la bande x 56…150.

## 3. Voies et trajets
- **Camions — circulation à droite** (`LANE_*`, `ROAD_*`, `truck_route_*`) : route sous les arbres à l’ouest (x −128, lot F2 ; tunnel avant) → autoroute, voie vers l'est
  **au sud** (z 142, `HIGHWAY_LANE_E` ; vers l'ouest z 140) → virage à gauche sur la **voie d'entrée à l'est** de la route
  (x −19,5 ; −15 avec gate2) → file depuis z 49, aire d'attente x −12…6 → **barrière d'entrée** (pivot −18, z 45) → voie A
  (aller, à vide) **z 34,6 vers l'est** jusqu'au **bout du groupe de blocs de son arrêt** (x −2 / 45 / 146, `tier_for_stop` ;
  lot E : cases de demi-tour dessinées en x −2 et 45) → demi-tour → voie B (retour) **z 32,4 vers l'ouest, le long du parc** :
  arrêt devant le bloc (z 30,4), **face à l'ouest**, arrivée et départ en biais doux (4,5 u pour 2 u, `LOAD_APPROACH`),
  chargement → **voie de sortie à l'ouest** (x −22,5, et −19,5 une
  fois sur deux avec gate2) : devant la douane, **sous un scanner à portique** (un par voie de sortie), barrière de sortie (pivot −24, z 43) → route vers
  le sud → virage à gauche sur l'autoroute vers l'est → route sous les arbres à l’est (x 183). Aucun croisement entre entrée et sortie.
- **Engins** : inchangés (côté mer, allées z 3,4 / 17,2, allées verticales −20,3 / 16,3 / 90,1).
- **Navires** : mouillage, chenal, passe ouest, bassin d'évitage inchangés. **Postes 1–2** : arrivée et départ par la passe ouest
  **à tous les paliers**. **Postes 3–4** (palier 3) : du mouillage, entre deux colonnes de places puis voie au large z = −108
  (au nord du début du chenal : jamais à travers une ligne de bouées), le large à l'est (194 ; −108) → (186 ; −36), **passe
  est à droite** (lot E) : voie d'arrivée **z −36 au nord** vers l'ouest, **évitage devant le poste** (boucle côté quai), voie
  d'arrivée z −21 vers l'est, accostage ; départ par la voie **z −25 au sud** (11 u d'entraxe : deux panamax à 2,4 u), sortie à
  l'est de la ligne d'arrivée (200 ; −25) → (215 ; −90), hors écran.
- **Manœuvres (lot F1, `Layout` « Lot F1 — manœuvres »)** : partout, évitage à l'arrivée, approche déjà parallèle au quai,
  **glissement latéral** de la voie z −21 au poste (remorqueur à l'épaule côté large) ; au départ, glissement inverse puis la
  route sans demi-tour. **Postes 1–2 : amarrés étrave à l'ouest** — sortie du chenal arrondie (rayon 12) sur la voie d'évitage
  **z −33** vers l'est, demi-tour à droite 22 u à l'est du poste (rayon 6), retour vers l'ouest sur z −21 ; départ le long des
  quais vers l'ouest, virage à droite (rayon 8, début en x −19) dans la voie de sortie du chenal. **Postes 3–4 : amarrés étrave à
  l'est**, évitage en demi-cercle (rayon 7,5) de z −36 à z −21, départ par (x + 16 ; −25). Points d'attente : dans la passe
  (voie d'entrée, 30 % de la voie 2 à la voie 3) et avant l'évitage (postes 1–2), sur z −36 10 u à l'est du poste (postes 3–4).
  Mouillage : dernier bord de l'arrivée (16 u) au cap du mouillage (0,35 rad). Remorqueur : base (−51 ; −15), rendez-vous à
  l'entrée du chenal (−31 ; −97) ou dans la passe est (152 ; −31).
- **Règles de passage des navires** (lot E, `ShipRules`, vues seulement) : distance de suivi ; on cède au navire qui coupe la
  route devant l'étrave ; **croisements** (`SHIP_CROSSINGS`) : « large » (voie z −108 × chenal ouest, x −50…−10 × z −126…−90,
  **balisé** : contour jaune et bouées cardinales en (−30 ; −128,5) et (−46 ; −87,5)), « chenal » (entrée du chenal, x −40…−8 ×
  z −146…−100), bassins « ouest » (x −42…20 × z −40…−14) et « est » (x 80…128 × z −33…−14) : l'autre courant attend, à égalité
  le plus petit identifiant, retenue levée après 12 s.
- **Haies** : enceinte | cap (x −48,8, z 2…44,6), enceinte | bureaux (z 44,6), bureaux | arrière-pays (z 67,6), aire
  d'attente | arrière-pays (x 6,6, z 54…108), gare | arrière-pays (z 70,6), terre-plein | herbe (ouverte au droit de la liaison avec la gare).
- **Personnages** : dockers fixes du quai, douaniers dans l'aire d'inspection, responsables à leur poste ; **foule du lot D**
  (MultiMesh, 28 au plus) : dockers sur le tablier (1 + agents des Quais, 2 à 5 par navire à quai) et sur le pont pendant le
  déchargement (agents des Portiques, 1 à 3), douaniers (agents de la Douane, 1 à 4, places réservées) ; demi-tour progressif.
- **Gare** (lot E) : la rame sort du tunnel (coupée en x 181, sous la colline), attend 16 s au quai, repart ; un tracteur fait la
  navette parc RTG ↔ quai tant que le train est à quai et attend au passage à niveau qu'aucun camion n'approche (26 u).

## 4. Départements et responsables (`dept_pos`, `MANAGER_POS`)
Capitainerie (−43 ; 6), puis **tour VTS (−62 ; −16)** au palier 2 · Quais (**−32** ; −3) · Portiques (**−21** ; −3) (11 u :
touchers séparés) · Parc (−20,3 ; 17,2) · Gate (**−21 ; 56**, lot E : sur la route au sud de la tête de file) · Douane
(**−31,5 ; 38**, lot E : parvis du bureau) — Douane, Gate et bras des barrières à ≥ 11 u l'un de l'autre. Au palier 2, la
maison bleue de la capitainerie et la tour ouvrent toutes deux la Capitainerie. Responsables : capitainerie (−38,5 ; 9,5) /
**pied de la tour (−58,6 ; −12,5)**, quai (−28 ; −4,4), grues (−20 ; −4,4), parc (−47 ; 22), gate (−26,4 ; 47,4), douane
(−27 ; 37).

## 5. Cadrage
Départ `CameraRig.START` = (−45 ; −29), largeur 58 u : vieux port, passe, cap (la zone grise du pôle nautique y est « discrète » :
herbe du cap, pointillés très pâles) et un navire au mouillage n°1. À l'ouverture d'une zone, `Zones.focus` cadre la zone entière.

**Bornes (lot F2, `CameraRig.set_tier_bounds`)** :
- centre de la caméra dans x −130…(bord des quais du palier + 60), z **−150**…160 (−90 avant : la rive d'en face paraît en
  haut de l'écran) ;
- zoom le plus large **130 u** (`ZOOM_MAX` ; 190 avant).
- À ce zoom, aux quatre coins des bornes, l'écran reste dans x −320…400, z −340…350. Tout ce rectangle est habillé (eau,
  rives et forêt dans `Layout.FOREST_AREA`) : on ne voit jamais le bord du monde (contrôlé dans `run_all` et `ui_smoke`).
- Cadrage des cartes d'intro (lot G1) : (−116 ; 30), largeur 72 u ; la Crique : `Layout.ANSE_LOOK` (−117 ; 40), largeur 62 u ;
  pendant la Crique la caméra est bornée à l'anse (§ 5 ter), les bornes du palier reviennent à la Concession.

## 5 bis. Le golfe d'Ambre, la forêt, le départ (lot F2)
- **Rives du golfe** (`GULF_WEST`, `GULF_EAST`, `HINTERLAND` ; sol vert sombre, hors du plan coté et de `land_polys`, ajoutées
  à la texture de l'eau pour l'écume) :
  - la rive ouest part de la plage ouest (−132 ; 60) et remonte vers le nord-ouest jusqu'à (−380 ; −330). Elle ferme
    **l'anse des pêcheurs** à l'ouest du cap (l'anse fait ≈ 80–110 u de large) ;
  - la rive est part de (186 ; 50) et remonte vers le nord-est jusqu'à (400 ; −310) ;
  - au sud, l'arrière-pays.
  - Toutes sont à ≥ 40 u des voies des navires (arrivée, 42 places de mouillage, départs, sorties nord et est, barges du
    terre-plein).
- **Rive d'en face** (`FAR_SHORES`, modèle `far_shore` 260 × 68, voilé de brume) : deux pans au nord, centrés en
  (−250 ; −300) et (232 ; −300). L'entrée du golfe, x −120…102, laisse passer les sorties nord.
- **Forêt dense** (`Layout.forest()`, ≈ 400 blocs `forest_block`, un MultiMesh par carré de 120 u) :
  - lisière serrée (pas de 19 u) : bande du continent au sud de l'autoroute (z 152…168, ex-collines), quatre rangs de
    l'arrière-pays, terres du golfe proches du continent ou de la mer ;
  - forêt profonde au-delà (lot F3 : pas de 21 u, blocs ×0,92–1,05 — ≈ 1,3 × les arbres du village ; avant : 40 u, ×2–2,4) ;
  - jamais à moins de 9 u de l'eau, sur l'autoroute ni sur une route forestière.
- **Routes sous les arbres** (`FOREST_ROADS`, modèle `forest_road`), là où le trafic apparaît et disparaît :
  - autoroute ouest, origine (−122 ; 141), trafic perdu en x −128 = `HIGHWAY_ENDS[0]` ;
  - autoroute est, origine (177 ; 141), perdu en x 183 ;
  - rue du village, origine (−126 ; 99), perdue en x −132 ;
  - voie ferrée, origine (175 ; 57), perdue en x 181 = `RAIL_TUNNEL_X`.
  - Plus de collines-tunnels (deux buttes boisées restent, en (162 ; 84) et (−110 ; 126)).
- **Départ de rien** :
  - pièces de départ (`STARTER`, éléments marqués « grp ») :
    - `quay0`, 6 s : le quai n°1 x −36…−12, les musoirs ouest, la capitainerie, lampes, bouées, filets et caisses ;
    - `crane0`, 3,5 s : la grue mobile ;
    - `yard0`, 5 s : le parc gravier x −36…0 × z 0…18, le hangar, les tonneaux ;
    - `gate0`, 4 s : la route d'accès x −24…−18, la voie des camions z 30…36, les barrières, le marquage, le panneau.
  - État d'avant de la friche : l'estacade ruinée `jetty_ruin` en (−24 ; −7,2), devant le quai ; des rochers et des
    broussailles sur le parc, la capitainerie et la gate.
  - Cases à acheter : rochers et broussailles dans l'empreinte (`Layout.before_state`) ; rien sur l'eau, un quai, une route
    ou le terre-plein.
  - Pas de musoir sur la case d'un quai pas encore construit (allongement x −12…0, quai n°2 x 0…36) : la berge nue.
- **Premier navire du T1** : il naît dans le chenal, voie d'entrée, tronçon 1 (≈ (−36 ; −72), hors champ), et file vers le
  poste n°1 (`first_ship_path`) sans passer par le mouillage.
- **Anse des pêcheurs** : cotes de l'acte 0 au § 5 ter (lot F3).

## 5 ter. L'anse des pêcheurs (lots F3 et G1, `Layout` « Lot F3/G1 », `FishingView`, `CloudLayer`)
À l'ouest du cap, entre la plage ouest (−132 ; 60) → (−94 ; 48), le flanc ouest du cap (−94 ; 48) → (−90 ; 0) et la rive ouest
du golfe (`GULF_WEST` : (−132 ; 60) → (−148 ; 54) → (−166 ; 36) → (−182 ; 8)). Hors du bassin des conteneurs ; les bateaux
restent au sud de z −35 : **≥ 40 u du mouillage et de l'arrivée des cargos**, **≥ 60 u du chenal** (contrôlé dans `run_all`).
- **Le ponton des places** (lot G1, modèle `pontoon`, module 6 × 1,6, plancher à −0,55) : un seul ponton le long de la plage à
  **z 48,4**, de x −140 vers l'est, 2 modules au départ (réparation, 0 $), 6 au plus (x −140…−104) : il s'allonge aux niveaux
  de Places **3, 4, 6, 7** (`PLACES_MODULES`), un taquet (`cleat`) par place ; passerelle de 2 modules vers la plage en x −130 ;
  état d'avant : `pontoon_ruin` en (−134 ; 48,4). **9 places de barques** (étrave à l'est) à z 46,6, x −138 … −106 au pas de 4 u
  (niveau 1 = 2 barques, puis une par niveau).
- **Quai des chalutiers** (50 $) : le long du cap, x −95,6, z 16…46 ; chalutiers (étrave au nord) en (−98 ; 40,5) et (−98 ; 31,5).
- **Grande jetée** (90 $, `pier_long` 14 × 2,5, béton sur pieux) : axe z en (−96 ; 7), z 0…14 ; passerelle (`pontoon`) vers le
  flanc en (−92 ; 1) ; **thonier** sur son flanc ouest en (−99,5 ; 7), étrave au nord.
- **Marina** (150 / 180 / 240 $, modules `marina_pontoon` 10 × 1,8, axe z, 8 anneaux) dans l'intérieur de la boucle des bateaux
  (jamais traversé) : (−125 ; 36), puis (−125 ; 26), puis (−113 ; 36) ; voiliers (`sailboat_a` 3,5 u, `sailboat_b` 4,5 u) des deux
  côtés, étrave au ponton (x ±3,5), 6 → 12 → 20.
- **Services à quai** (paliers nommés) : criée `fish_hall` en (−99 ; 55,5) (niveau 1) et sa **route du mareyeur** x −102…−96,
  z 59…96 jusqu'à la rue du village ; pompe `fuel_pump` en (−107 ; 54) (niveau 3) ; aire de lavage `wash_bay` en (−118 ; 59,5)
  (niveau 6) ; fabrique de glace `ice_plant` en (−88,5 ; 28), tournée de 90° (niveau 9). Cabane d'Odette `odette_hut` en
  (−127 ; 62,5) (toujours là). Marcel (`marcel`, sinon `docker`) sur le ponton en (−133 ; 48,4). Camionnette `fish_van` garée en
  (−97,5 ; 63,5).
- **Boucle des bateaux, à sens unique** (sens inverse des aiguilles d'une montre) : voie ouest **x −146** vers le sud, voie de la
  plage z 44 vers l'est (au nord des barques amarrées, ≥ 2 u), voie est x −102 vers le nord (le long des chalutiers), sortie au
  nord de z 16 (le thonier remonte la voie est jusqu'à z 7, sort au nord de z −2). Glissement latéral à la place, coins arrondis
  (rayon 4), aucune rotation sur place, ≤ 6 u/s.
- **Coins de pêche** (cercle de dérive de 1,6 u) : barques (−126 ; 14), (−116 ; 6), (−130 ; 2), (−120 ; −4), (−136 ; 10),
  (−112 ; −2), (−124 ; −10), (−134 ; −6), (−142 ; 2) ; chalutiers (−150 ; −14), (−138 ; −22) ; thonier (−160 ; −20). Arrivée d'un
  bateau neuf (en fondu, hors du cadrage) : barques (−148 ; −10), chalutiers (−152 ; −20), thonier (−160 ; −32).
- **Caboteur de l'annonce** (8ᵉ minute, `ship_passing`, sinon `ship_coaster`) : traverse au large de (−226 ; 12) à (−134 ; −80)
  à 7 u/s, dans le trou des nuages, et s'y efface.
- **Caboteur de la bascule** : naît en (−150 ; −118), au large au nord-ouest, rejoint l'entrée du chenal (−33 ; −116) (point
  d'attente tant que le vieux quai n'est pas fini), puis le pilotage du premier navire (poste n°1).
- **Nuages de la Crique** (`CLOUD_COVER` x −330…410, z −350…360 ; bancs 24 × 12 à y 11, dérive ±3 u) : tout est couvert sauf le
  **trou** `CLOUD_HOLE` : la plage et l'anse x −200…−84, z 0…74 ; le large x −215…−84, z −80…0 ; la route du mareyeur x −106…−92,
  z 72…106. Sous les bancs, une **nappe continue** à y 6,5 (cellules de 12 u, découpées en 3 × 3 au bord du trou) : rien ne se
  voit entre les bancs à aucun zoom. Dissolution à la Concession (3,5 s, nappe comprise), jamais recréés.
- **Caméra pendant la Crique** (`CameraRig.set_crique_bounds`) : centre x −128…−104, z 18…46 ; zoom ≤ 72. Cadrage d'intro
  (−116 ; 30), largeur 72 ; cadrage de la Crique `ANSE_LOOK` (−117 ; 40), largeur 62 ; annonce (−128 ; 18), largeur 72.
- Scatter (bosquets) : rien dans x −142…−84 × z 44…72, x −96…−80 × z 14…48 ni x −100…−80 × z −2…16.

## 6. Non fait (lot D)
**Gate est au palier 3** : non faite. La simulation n'a qu'une file de camions et un débit de gate ; `TrafficView` ne montre
qu'une file (celle de la simulation) sur une route d'accès. Une seconde gate demanderait de couper cette file en deux au hasard
(aucune information de la simulation pour décider), une seconde route d'accès depuis l'autoroute à travers la gare et sa voie
ferrée (passage à niveau), de nouveaux contrôles de route (`_truck_ground` de `ui_smoke`) : de la présentation qui mentirait sur
la simulation. À reprendre si la simulation gagne une seconde gate.
