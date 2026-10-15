# Ordre de mission — expert Blender : la Crique complète, la marina, les nuages, le terre-plein (lot G, 15/10/2026)

Projet : `C:\Nadir\tycoon_V2` (ne jamais toucher `C:\Nadir\tycoon`). Contexte : `docs/CADRAGE_DEBUT.md` (lire § 4, 5, 6 et 12).
Sauvegarde faite par le chef de projet (`C:\Nadir\tycoon_backups\V2_avant_lot_G_20261015.zip`). **Aucun commit, aucun push.**
Un développeur travaille **en parallèle** (lot G1) dans `godot/` : ne modifier ni `godot/scripts/`, ni `godot/data/`, ni `godot/scenes/`,
ni les `.glb` existants. Tu n'écris que dans `blender/`, `docs/previews/` et, pour les **nouveaux** modèles seulement, dans
`godot/assets/models/` (+ leurs entrées dans `assets_meta.json`).

## 1. À lire d'abord
`docs/ORDRE_BLENDER_D.md` § 2 (environnement, Start-Process + `WaitForExit(ms)` borné + `Kill()`) et § 3 (règles : palette seulement,
emblème, face principale en −Y, échelle 1 u ≈ 3 m, accessoires ×1,35, budgets, `anchor_y` et `footprint`) ; `blender/lib.py` ;
`blender/parts/crique.py` (barques, pontons, criée, cabane), `chantier.py`, `ships.py` (`ship_coaster`), `buildings.py`.
Registres : B (bois, chaud) pour la crique et la marina ; C (saturé, lisible) pour le terre-plein et les chantiers.

## 2. Modèles à créer
**La Crique (registre B)**
| Asset | Quoi | Emblème | Budget |
|---|---|---|---|
| `fuel_pump` | pompe à carburant de quai : borne rouge, tuyau enroulé, petit auvent | borne rouge + goutte peinte | 600 |
| `wash_bay` | aire de lavage des coques : dalle, portique à jets bleus, flaque, brosses | portique bleu + jets | 2 500 |
| `pier_long` | grande jetée des thoniers : béton sur pieux, ≈ 14 × 2,5 u, défenses pneus, lampadaire, bittes | lampadaire + pneus noirs | 2 500 |
| `marina_pontoon` | ponton flottant de plaisance : module 10 × 1,8 u, 8 anneaux (catways), bornes eau/électricité | bornes bleu-blanc | 600 |
| `sailboat_a`, `sailboat_b` | voiliers de 3,5 et 4,5 u, mât, voile ferlée, coque blanche/bleue puis rouge/crème | mât + voile ferlée | 600 chacun |
| `yacht_small` | petit yacht à moteur 5 u, flybridge | flybridge blanc | 600 |
| `marcel` | patron pêcheur : même gabarit que `docker` (×1,35), ciré jaune, casquette, pipe ; pose debout bras croisés | ciré jaune | 600 |
| `ship_passing` | caboteur de Corsaire & Fils vu de loin (≈ `ship_coaster` simplifié, 1 200 tris) pour le passage au large | pavillon Corsaire (noir et or) | 1 200 |

**Les nuages (verrou visuel, § 5.1 et § 12 Q5)**
| Asset | Quoi | Budget |
|---|---|---|
| `cloud_bank` | banc de nuages épais, module 24 × 12 × 6 u, bords arrondis en grappes, blanc légèrement gris au-dessous ; le jeu en pose plusieurs, les anime (dérive lente) et les dissout par shader (fondu + montée) | 600 |
| `cloud_puff` | nuage isolé 8 × 5 × 4 u, pour les bords et la dissipation | 200 |
Face du dessous plate (la caméra regarde d'en haut à 35°) ; aucune face à l'intérieur. Prévoir une couleur de sommet uniforme pour
que le shader de fondu du développeur n'ait qu'une teinte à gérer.

**Le terre-plein (registre C)**
| Asset | Quoi | Emblème | Budget |
|---|---|---|---|
| `ground_platform` | dalle de terre battue / remblai compacté, module 8 × 8 u, traces de pelleteuse, bords en enrochement bas | — | 200 |
| `quay_small` | quai n°1 court : 16 u, béton neuf, 4 bittes, échelle, pas de rails de grue | bittes jaunes | 2 500 |
| `track_dirt` | piste en terre, module 8 u, ornières, bord herbeux ; variantes droite + virage 90° | — | 200 |
| `barrier_post` | barrière à bascule rouge-blanche sur deux poteaux, nœud nommé `arm` (pivot au poteau) : c'est **la** barrière qu'on touche | bras rouge-blanc | 600 |
| `coaster_crane` | **grue de bord** à poser sur `ship_coaster` : mât + flèche articulée (nœuds `boom`, `hook`), socle qui se cale sur le pont | — | 600 |
| `container_wait` | conteneur 20' « en attente de douane » : même gabarit que `container20`, bandes grises + étiquette orange ; et `container_ok` (étiquette verte) | étiquette | 200 chacun |

## 3. Règles d'intégration
- Nœuds nommés exigés : `barrier_post/arm`, `coaster_crane/boom`, `coaster_crane/hook`, `sailboat_*/mast` (pour un léger roulis).
- `assets_meta.json` : `anchor_y`, `footprint`, nœuds articulés, comme au lot F.
- `far_shore` : rien à faire ici (reste au lot F4).
- Rendus : `docs/previews/g_crique.png` (pompe, lavage, jetée, marina avec 6 voiliers, Marcel), `g_nuages.png` (banc de nuages
  au-dessus de la friche, vu depuis l'anse, caméra du jeu), `g_terreplein.png` (plateforme + quai n°1 + caboteur avec grue de bord +
  cabane de douane existante `customs_hut` + piste + barrière + un camion), `g_budget.png` (tableau des triangles).

## 4. Rapport
Section « Lot G — modèles » dans `docs/DECISIONS.md` : liste exacte des `.glb`, budgets, nœuds nommés, ce qui n'a pas été fait et
pourquoi. Aucune modification en dehors des dossiers autorisés.
