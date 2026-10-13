# Ordre de mission — expert Blender : direction D sur tout le port (lot A)

Projet : `C:\Nadir\tycoon_V2` (seul projet de travail ; ne jamais toucher `C:\Nadir\tycoon`). Pas de git : une copie zip a déjà été faite
(`C:\Nadir\tycoon_backups\V2_avant_direction_D_20261013.zip`). Un développeur travaille **en parallèle** dans `godot/scripts/` : ne pas
modifier `godot/scripts/`, `godot/data/`, `godot/scenes/`, et **ne pas lancer Godot avant la fin de la phase 3** (voir § 6).

## 1. À lire avant de commencer, dans cet ordre
1. `docs/ETUDE_STYLE.md` § 2–3 : les trois registres et le tableau palier → registre. **C'est la décision à appliquer.**
2. `docs/previews/style_variantes.png` et `blender/preview_variants.py` : les prototypes B (`harbor_office_nordic`) et
   C (`harbor_office_industrial`) y sont déjà codés ; leurs couleurs d'essai (`X`) sont à verser dans `palette.json`.
3. `docs/BRIEF_STYLE_PORTS.md` § 3 bis (échelles, face principale en −Y, place du responsable, table ouvert/fermé) et § 4
   (architecture portuaire : ce qu'un port contient vraiment).
4. `blender/lib.py` (classe `Model`, pièces `closed_block`, `facade`, `pilaster`, `window_band`, `awning`, `planter`, `door`,
   `roll_door`), `blender/parts/*.py`, `blender/build_assets.py` (budgets, export), `blender/preview.py`, `blender/preview_style.py`.
5. `godot/scripts/world/layout.gd` : positions et **rotations** (0° ou 90°) de chaque modèle ; `godot/assets/models/assets_meta.json`.
6. `docs/REVUE_CHEF_DE_PROJET.md` § 2 (constats) et § 5 lot A.

## 2. Environnement machine
- Blender 5.2 : `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`, toujours en `--background`. Pas de Python système :
  tout script passe par Blender.
- Lancer Blender depuis PowerShell avec `Start-Process … -PassThru -NoNewWindow -RedirectStandardOutput/-RedirectStandardError`
  puis `$p.WaitForExit()` : les pipes PowerShell bloquent. Exemple dans l'en-tête de `blender/preview_variants.py`.
- Construire : `blender -b -P blender\build_assets.py -- --out C:\Nadir\tycoon_V2\godot\assets\models [--only nom1,nom2]`.
- Fichiers « com0 », « nul », « aux »… interdits par Windows.

## 3. Règles non négociables
1. **Couleurs uniquement via `palette.json`** (`C('nom')`). Ajouter d'abord les teintes de l'étude : `wood_cream`, `wood_trim`,
   `falun`, `roof_b_blue`, `glass_light`, `apron_warm`, `kerb`, `clad_steel`, `clad_steel_dark`, `roof_light`, `cap_light`, `hazard`,
   `asphalt_dark`, `mark_yellow`, `door_orange` (valeurs dans `X` de `preview_variants.py`), et `asphalt_violet` déjà présent.
   Puis supprimer les hexadécimaux en dur de `preview_variants.py`.
2. **Identifiable sans lire** : chaque bâtiment a un **objet emblème** (table § 4) et **la couleur de son département** sur son toit,
   sa casquette ou son auvent : capitainerie bleu, douane marine + jaune, gate orange, parc et engins jaune, logistique vert,
   informatique teal, énergie gris acier + jaune. `sign3d` n'est plus utilisé pour informer ; retirer « DOUANE » et « ENTREPÔT »
   (ou les garder en pur décor, jamais seuls).
3. **Fermés par défaut**, sauf typologies ouvertes (hangar sur poteaux, halle d'inspection ouverte sur un long côté, atelier à
   grande porte ouverte). Face principale en **−Y** ; faces ±X traitées ; fond +Y nu. Vérifier le rendu à 90° pour `hangar`,
   `warehouse` T3 et tous les modèles tournés dans `layout.gd`.
4. Place du responsable libre : `(3, −3)` devant à droite en coordonnées Blender.
5. Échelle : 1 u ≈ 3 m ; conteneur 40' = 4 × 1,3 × 1,3 ; étage 2,5–2,7 ; porte 1 × 1,75 ; **accessoires et personnages ×1,35**
   (personnage 1,35 u, grosse tête, corps capsule ; bollards, cônes, pots, lampadaires, bouées exagérés).
6. **Budget** : ≤ 2 500 triangles par bâtiment, ≤ 600 par accessoire ou véhicule, ≤ 2 500 par navire et grue. Mettre à jour `BUDGET`
   dans `build_assets.py` ; l'export doit refuser au-delà.
7. `assets_meta.json` : pour chaque bâtiment, écrire en plus `anchor_y` (hauteur, en u, où poser la bulle d'information : sommet du
   toit + 0,4) et `footprint: [w, d]`. Le développeur lit ces champs.
8. Ombrage : rien à faire côté Blender (le shader Godot s'en charge) ; les aperçus utilisent le matériau de `preview_style.py`.
9. Toit plus clair que les flancs sur tous les véhicules ; feux arrière rouges ; une couleur franche par véhicule.

## 4. Table des bâtiments : registre, emblème, couleur
| Asset | Palier | Registre | Emblème (reconnaissable en petit) | Couleur | Rotation |
|---|---|---|---|---|---|
| `harbor_office` | T1 | B (reprendre `harbor_office_nordic`) | belvédère vitré sur le faîte + mât à pavois + bouée couronne | bleu | 0° |
| `customs_hut` | T1 | B | table d'inspection avec valise orange ouverte devant, auvent marine à liseré jaune, barrière à damier | marine + jaune | 0° |
| `hangar` | T1 | B ouvert | toit rouge falun à pente sur poteaux bois, caisses de poisson et filets dessous | rouge falun | 90° |
| `gate_booth` | T1/T2 | B dur | guérite vitrée + feu rouge/vert sur mât + panneau STOP orange | orange | 0° |
| `barrier` | — | — | lisse rouge/blanc, ×1,35 | — | — |
| `control_tower` | T2 | B dur | tour haute à cabine vitrée inclinée + radar | bleu | 0° |
| `office` | T2 | B dur | 2 niveaux, grande horloge ronde en pignon | bleu clair | 0° |
| `workshop` | T2 | B dur ouvert | grande porte ouverte sur un engin, pile de pneus géants, bras de levage | jaune | 0° |
| `customs_office` | T2 | B dur | scanner mobile garé devant (van), rayure marine/jaune sur la casquette | marine + jaune | 0° |
| `reefer_rack` | T2 | C | portiques à prises, conteneurs blancs givrés, groupe froid | blanc/bleu givré | — |
| `scanner` | T3 | C | portique scanner jaune-noir, feu orange tournant | marine + jaune | 90° |
| `inspection_hall` | T3 | C ouvert | halle ouverte sur le long côté, conteneur ouvert en cours d'inspection | marine + jaune | 0° |
| `it_center` | T3 | C | antennes, parabole, baies à LED | teal | 0° |
| `substation` | T3 | C | transformateurs, isolateurs, pylône, bandes jaune-noir | acier + jaune | — |
| `imo_fence` | T3 | C | clôture + losanges rouges géants + extincteur | rouge/orange | — |
| `rail_terminal` | T3 | C | auvent sur rails, butoir, panneau de voie | vert | — |
| `warehouse` | T3 + logistique | C (reprendre `harbor_office_industrial`, allongé) | quai à portes roulantes, une ouverte sur des cartons, sheds en toiture | vert | 0° / 90° |
| `silo` | logistique | C | silo cylindrique à échelle et passerelle | vert | — |
| `lighthouse` | T1 | B | phare rayé rouge/blanc, lanterne vitrée | rouge | — |
| `house_a`, `house_b`, `shop` | village | B | toits de couleurs variées, cheminée, volets | variées | 0°/90°/180° |

## 5. Environnement portuaire : modèles à créer (nouveaux) ou à refaire
**Quai et plan d'eau** : `bollard` (×1,35, noir à chapeau), `fender` (défense pneu noir suspendue), `ladder` (échelle de quai),
`cleat`, `crane_rail` (bande de rails sur le tablier, dalle), `breakwater` (brise-lames en enrochement), `buoy` (rouge et verte, ×1,35),
`fishing_boat` (petit chalutier B, coque colorée, mât), `net_pile` (filets), `crate_fish` (caisses), `gull` (mouette posée, 2 poses),
`life_ring_post` (bouée sur poteau).
**Sols** : `ground_gravel` → sable chaud ; `ground_asphalt` → asphalte violet sombre avec marquages épais clairs ; `ground_parking`
(places marquées) ; `yard_marks` (dalle de marquage de parc : travées numérotées sans chiffres, bandes jaunes) ; `quay` → béton chaud,
bordure sombre, bandes de rails ; `road` → asphalte violet sombre, ligne axiale épaisse ; nouveaux `sidewalk`, `crosswalk`.
**Gate** : `gate_lanes` (dalle de voies entrée/sortie avec flèches), `sign_p` (totem P, face plane pour afficher un nombre depuis Godot),
`ghost_lot` (empreinte en pointillés clairs, dalle plate, pour le futur lot C).
**Engins et véhicules (registre C, saturés)** : `crane_mobile`, `crane_sts`, `rtg`, `straddle`, `reach_stacker`, `truck`, `tractor`,
`forklift`, `van`, `locomotive`, `wagon`, `tug`, `pilot_boat`, `car_a`, `car_b` + `car_c` (nouvelle couleur).
**Navires** : `ship_mini`, `ship_coaster`, `ship_feeder`, `ship_panamax` : coque colorée par armateur (laisser la coque teintable si
`ship_view.gd` la teinte déjà : vérifier `vcol_tint.gdshader` et le code avant), château blanc, cheminée colorée, conteneurs colorés sur
le pont, bouées et canot. Toit clair.
**Personnages** : `docker`, `customs_officer`, `inspector`, `manager` à 1,35 u, grosse tête, gilets saturés.
**Conteneurs** : inchangés (teintés par le jeu).

## 6. Déroulé et livrables
- **Avant tout** : copier `godot/assets/models\*.glb` vers `C:\Nadir\tycoon_V2\docs\previews\_avant\` (sert aux rendus avant/après).
- **Phase 1** : palette, pièces `lib.py` (`wood_block` : corps chanfreiné à bardage, toit à pente, planches d'angle ; `steel_shed` :
  bardage nervuré, casquette claire, bandes jaune-noir ; `emblem_*` utilitaires), bâtiments T1, sols, quai et accessoires de quai,
  personnages. Rendu `docs/previews/d_phase1.png` (avant/après par `preview_style.py`, 3 à 4 bâtiments par planche).
- **Phase 2** : T2, gate, engins et véhicules. Rendu `docs/previews/d_phase2.png`.
- **Phase 3** : T3, logistique, village, navires, environnement (brise-lames, bateaux de pêche, mouettes). Rendu `docs/previews/d_phase3.png`.
- Après chaque phase : `build_assets.py` complet sans erreur, aucun dépassement de budget, `assets_meta.json` enrichi.
- **Fin de phase 3 seulement** : `& C:\Nadir\Godot\Godot.exe --headless --path C:\Nadir\tycoon_V2\godot --import` (même
  méthode Start-Process), puis 4 captures du jeu :
  `& C:\Nadir\Godot\Godot.exe --path C:\Nadir\tycoon_V2\godot -- --fresh --capture=C:/Nadir/tycoon_V2/docs/captures/d_t1.png --delay=6 --zoom=28`
  (ajouter `--look=x,z` pour cadrer, `--tier=2` / `--tier=3` pour les paliers ; ne pas bouger la souris pendant une capture).
  Si `main.gd` plante au démarrage, c'est qu'un `--import` manque.
- Rédiger une entrée « Lot A — direction D » dans `docs/DECISIONS.md` (ce qui a été fait, les choix, les limites) et mettre à jour
  `docs/BRIEF_STYLE_PORTS.md` § 3 (règles) pour refléter la direction D.
- Rapport final : liste des modèles refaits / créés avec leur nombre de triangles, chemins des planches, problèmes rencontrés,
  ce qui reste à faire.
