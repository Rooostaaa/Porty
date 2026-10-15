# Ordre de mission — expert Blender : la crique, les chantiers et la forêt (lot F, 14/10/2026 soir)

Projet : `C:\Nadir\tycoon_V2` (ne jamais toucher `C:\Nadir\tycoon`). Contexte : `docs/PLAN_LOT_F.md` (lire § 3 et § 5).
Sauvegarde déjà faite (`V2_avant_lot_F_20261014.zip`). **Aucun commit, aucun push.**
Un développeur travaille **en parallèle** (lot F1 : navires, défilement) dans `godot/` : ne modifier ni `godot/scripts/`, ni
`godot/data/`, ni `godot/scenes/`, ni les `.glb` existants. Tu n'écris que dans `blender/`, `docs/previews/` et, pour les
**nouveaux** modèles seulement, dans `godot/assets/models/` (+ leurs entrées dans `assets_meta.json`).

## 1. À lire d'abord
`docs/ORDRE_BLENDER_D.md` § 2 (environnement, Start-Process + `WaitForExit(ms)` borné + `Kill()`) et § 3 (règles : palette
seulement, emblème, face principale en −Y, échelle 1 u ≈ 3 m, accessoires ×1,35, budgets, `anchor_y` et `footprint`) ; `blender/lib.py` ;
`blender/parts/harbour.py` (`fishing_boat`), `terrain.py` (`tree`), `buildings.py` (la règle des saillies en tête) ;
`docs/ETUDE_STYLE.md` (registre B, nordique-bois, pour la crique).

## 2. Modèles à créer
**Acte 0 — la crique (registre B, bois, couleurs chaudes)**
| Asset | Quoi | Emblème | Budget |
|---|---|---|---|
| `boat_dinghy` | barque de pêche à moteur hors-bord, 2,2 × 0,9 u | coque bicolore vive, caisse de poisson à bord | 600 |
| `boat_trawler` | chalutier ≈ 5 u, portique arrière et filet | portique de chalut | 2 500 |
| `boat_tuna` | thonier-senneur ≈ 8 u, mât de vigie, skiff à l'arrière | nid-de-pie + skiff | 2 500 |
| `pontoon` | ponton flottant en planches, module de 6 × 1,6 u, taquets | — | 600 |
| `pontoon_ruin` | même ponton pourri : planches manquantes, penché, algues | — | 600 |
| `fish_hall` | la criée : halle ouverte sous un grand toit, bacs bleus, tableau d'enchères | toit à deux pentes bleu et blanc + tableau | 2 500 |
| `ice_plant` | fabrique de glace : petit bloc blanc, goulotte vers le quai, givre | goulotte inclinée + flocon peint | 2 500 |
| `odette_hut` | cabane de pêcheuse : bardage usé, filets qui sèchent, banc, bouées | filets suspendus + bouées colorées | 2 500 |
| `jetty_ruin` | vieille estacade sur pieux, effondrée par endroits (l'emplacement du futur quai T1) | pieux qui dépassent | 2 500 |
| `fish_van` | camionnette frigorifique du mareyeur | caisson blanc, poisson peint | 600 |

**Chantiers (registre C, saturé, lisible en petit)**
| Asset | Quoi | Budget |
|---|---|---|
| `site_hoarding` | palissade de chantier, module 4 u, bandes jaune-noir | 600 |
| `scaffold` | échafaudage + bâche, module 4 × 4 × 4 u, que le jeu étire | 600 |
| `site_crane` | petite grue de chantier à tour, flèche orientable (pivot nommé `jib` au sommet) | 2 500 |
| `excavator` | pelleteuse jaune, bras articulé (nœuds `boom`, `arm`) | 600 |
| `dust_pile` | tas de gravats et de sable | 600 |

**Forêt et golfe**
| Asset | Quoi | Budget |
|---|---|---|
| `tree_pine`, `tree_pine_b` | pins maritimes (2 silhouettes) | 600 |
| `tree_oak` | feuillu rond (complète `tree`) | 600 |
| `forest_block` | massif dense d'environ 20 × 20 u (une dizaine d'arbres fusionnés), bord irrégulier, pour la lisière | 2 500 |
| `forest_road` | entrée de route sous les arbres : deux rangées de troncs, une voûte de feuillage sombre où la route disparaît (largeur de route 6 u, longueur 14 u) | 2 500 |
| `far_shore` | silhouette de la rive d'en face (collines basses, un petit phare, quelques toits), très simple, à poser à 300 u et plus | 2 500 |

## 3. Livrables
- Rendus `docs/previews/f_crique.png`, `f_chantier.png`, `f_foret.png` (avec `preview_style.py`) : regarde-les avant de livrer
  (lisibilité en petit, l'emblème qui se voit, aucune couleur hors palette).
- `build_assets.py --only …` sans erreur, budgets respectés (ajouter les préfixes à `BUDGET` si besoin), entrées complètes dans
  `assets_meta.json` (`anchor_y`, `footprint`, et pour les modèles articulés le nom des nœuds).
- **Pas de lancement de Godot** (le développeur s'en sert) : il branchera ces modèles au lot F2/F3.
- `docs/DECISIONS.md` est partagé avec le développeur : relis-le juste avant d'y ajouter ton entrée, à la fin seulement, et en une seule modification.
- Entrée « Lot F — modèles de la crique, des chantiers et de la forêt » dans `docs/DECISIONS.md`. Rapport : modèles faits, triangles, rendus, limites.
