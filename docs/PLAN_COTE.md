# Plan coté définitif — « La baie et le terre-plein » (13/10/2026, réorganisé au lot D le 14/10)

Source unique des cotes : `godot/scripts/world/layout.gd` (constantes citées entre parenthèses). Repère du jeu : **x vers l'est**
(droite-bas de l'écran), **z vers le sud** (gauche-bas), mer en z négatif, bord des quais à **z = −6**. Captures de validation :
`docs/captures/plan_cote_vue_dessus.png` (plan vu de dessus, avant le lot D), `docs/captures/d_monde_*.png` (lot D, dont
`d_monde_plan_dessus.png`, le plan vu de dessus après réorganisation).
**Règle d'or : rien n'est posé « là où il reste de la place » ; chaque bâtiment a sa case, dessinée dès le départ (empreinte
`ghost_lot`).** Lot D (revue `REVUE_CRITIQUE_PORT.md`, axe 1) : circulation à droite, douane côté sortie dans une enceinte, pôle
nautique sur le cap, bureaux du port côté public, gare contre le terre-plein, brise-lames et passe est au palier 3.

## 1. Terrain (polygones construits dans Godot, `COAST`, `BREAKWATER`, `BREAKWATER_E`, `RECLAIM`)
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
| 8 | Deuxième voie de gate | `gate2` | −18…6 × 36…108 | gate2 (guérite −10,5 ; 44 : **2ᵉ voie de sortie**) · parking1 · parking2 |
| 9 | **Pôle nautique** (butte, grise « discrète ») | palier 2 | cap : (−77,−31) (−58,6,−31) (−57,−24) (−57,−13) (−60,5,−5) (−77,−5) | **tour VTS** (−62 ; −16, ≈ 35 u de la passe) · rpilot (−69 ; −14, au pied) · repair (−63 ; −27 · 90°, atelier + cale sur la crique) |
| 10 | Quai profond n°3 (terre-plein) | `berth3` | 48…121 × −6…44 | berth3 · rtg (84 ; 18 · 70×22) · berth4 · vacmoor ; sous-station |
| 11 | Station de soutage GNL | `lng` | 121…152 × −6…42 | lng (145 ; 12,5) + appontement · imo (127 ; 11,5 : **7,3 u du GNL**) · oog (127 ; 24) |
| 12 | **Terminal rail** (gare) | `rail` | contre le terre-plein : (56,44)…(150,41,5) → z 70 | rail (100 ; 52 · 18,5×3,7, quai) ; voie z = 57 de x 62 au tunnel est (184 ; 58) ; liaison x 84…90, z 36…48 avec la voie des camions du terre-plein |
| 13 | **Bureaux du port** (ex-Colline) | palier 2 | −66…−24 × 46…64 | ewindow (−30 ; 57,5) · ecustoms (−39 ; 57,5) · tos (−48 ; 57,5), au bord de la **rue des bureaux** (z 48…54) reliée à la route d'accès |

La zone logistique (z 84…126) reste en arrière-plan, grise jusqu'à la gare. Plus de bande d'herbe vide : bosquets entre
x 9 et 52, z 36…80 (végétation `scatter`), gare dans la bande x 56…150.

## 3. Voies et trajets
- **Camions — circulation à droite** (`LANE_*`, `ROAD_*`, `truck_route_*`) : tunnel ouest (x −128) → autoroute, voie vers l'est
  **au sud** (z 142, `HIGHWAY_LANE_E` ; vers l'ouest z 140) → virage à gauche sur la **voie d'entrée à l'est** de la route
  (x −19,5 ; −15 avec gate2) → file depuis z 49, aire d'attente x −12…6 → **barrière d'entrée** (pivot −18, z 45) → voie A
  (aller, à vide) **z 34,6 vers l'est** jusqu'au bout de la boucle (x −2 / 45 / 146) → demi-tour → voie B (retour) **z 32,4 vers
  l'ouest, le long du parc** : arrêt devant le bloc (z 30,4), chargement → **voie de sortie à l'ouest** (x −22,5, et −19,5 une
  fois sur deux avec gate2) : devant la douane, **sous le scanner à portique**, barrière de sortie (pivot −24, z 43) → route vers
  le sud → virage à gauche sur l'autoroute vers l'est → tunnel est (x 183). Aucun croisement entre entrée et sortie.
- **Engins** : inchangés (côté mer, allées z 3,4 / 17,2, allées verticales −20,3 / 16,3 / 90,1).
- **Navires** : mouillage, chenal, passe ouest, bassin d'évitage inchangés. **Postes 1–2** : arrivée et départ par la passe ouest
  **à tous les paliers**. **Postes 3–4** (palier 3) : du mouillage, entre deux colonnes de places puis voie au large z = −108
  (au nord du début du chenal : jamais à travers une ligne de bouées), le large à l'est (194 ; −108) → (186 ; −29), **passe
  est**, voie d'arrivée est z −29 vers l'ouest, **évitage devant le poste** (boucle côté quai), voie d'arrivée z −21 vers l'est,
  accostage ; départ par la voie z −36, la passe est (168 ; −36), (205 ; −85), hors écran.
- **Haies** : enceinte | cap (x −48,8, z 2…44,6), enceinte | bureaux (z 44,6), bureaux | arrière-pays, 2ᵉ voie de gate |
  arrière-pays (x 6,6), gare | arrière-pays (z 70,6), terre-plein | herbe (ouverte au droit de la liaison avec la gare).
- **Personnages** : dockers fixes du quai, douaniers dans l'aire d'inspection, responsables à leur poste ; **foule du lot D**
  (MultiMesh, 28 au plus) : dockers sur le tablier (1 + agents des Quais, 2 à 5 par navire à quai) et sur le pont pendant le
  déchargement (agents des Portiques, 1 à 3), douaniers (agents de la Douane, 1 à 4) ; demi-tour progressif pour tous.

## 4. Départements et responsables (`dept_pos`, `MANAGER_POS`)
Capitainerie (−43 ; 6), puis **tour VTS (−62 ; −16)** au palier 2 · Quais (**−32** ; −3) · Portiques (**−21** ; −3) (11 u :
touchers séparés) · Parc (−20,3 ; 17,2) · Gate (**−21 ; 48,5**, tête de la file : toucher une barrière reste possible) · Douane
(**−28,5 ; 40,5**). Responsables : capitainerie (−38,5 ; 9,5) / **pied de la tour (−58,6 ; −12,5)**, quai (−28 ; −4,4), grues
(−20 ; −4,4), parc (−47 ; 22), gate (−26,2 ; 55), douane (−27 ; 37).

## 5. Cadrage
Départ `CameraRig.START` = (−45 ; −29), largeur 58 u : vieux port, passe, cap (la zone grise du pôle nautique y est « discrète » :
herbe du cap, pointillés très pâles) et un navire au mouillage n°1. À l'ouverture d'une zone, `Zones.focus` cadre la zone entière.

## 6. Non fait (lot D)
**Gate est au palier 3** : non faite. La simulation n'a qu'une file de camions et un débit de gate ; `TrafficView` ne montre
qu'une file (celle de la simulation) sur une route d'accès. Une seconde gate demanderait de couper cette file en deux au hasard
(aucune information de la simulation pour décider), une seconde route d'accès depuis l'autoroute à travers la gare et sa voie
ferrée (passage à niveau), de nouveaux contrôles de route (`_truck_ground` de `ui_smoke`) : de la présentation qui mentirait sur
la simulation. À reprendre si la simulation gagne une seconde gate.
