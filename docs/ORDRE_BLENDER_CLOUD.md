# Ordre de mission — expert Blender dans le cloud : phases 2 et 3 de la direction D

Ce dépôt (`Rooostaaa/Tycoon`, branche `main`) contient Port Horizon V2. L'ordre de mission d'origine est `docs/ORDRE_BLENDER_D.md` :
**le lire en entier d'abord**, puis `docs/ETUDE_STYLE.md` § 2–3, `docs/BRIEF_STYLE_PORTS.md` § 3 bis et § 4, `blender/lib.py`,
`blender/parts/*.py`, `blender/build_assets.py`, `blender/preview_style.py`, `godot/scripts/world/layout.gd`, `godot/assets/models/assets_meta.json`.

## État au moment du départ (13/10/2026, 15 h)
- **Phase 1 livrée** (T1, sols, quai, accessoires de quai, personnages, bateau de pêche, mouettes) : modèles exportés dans
  `godot/assets/models/`, planches `docs/previews/d_phase1*.png`, nouveau module `blender/parts/harbour.py`, `blender/montage.py`.
- **Phase 2 commencée mais non exportée** : `blender/parts/equipment.py`, `ships.py`, `world.py`, `buildings.py` ont été modifiés
  (vérifier qu'ils s'exécutent ; terminer ce qui est à moitié fait avant d'ajouter).
- Le lot B côté Godot est livré : le chargeur ignore un modèle absent, lit `anchor_y` et `footprint` dans `assets_meta.json`, et attend encore
  `car_c`. Les positions du plan sont dans `layout.gd` (lecture seule ici).
- La machine locale a planté quand dix processus Blender ont tourné en même temps. **Règle absolue : un seul processus Blender à la fois,
  rendus enchaînés, jamais en parallèle.**

## Environnement cloud (Linux, sans carte graphique)
1. Installer Blender : télécharger l'archive Linux x64 de la série la plus récente disponible sur `https://download.blender.org/release/`
   (5.2 de préférence, sinon la dernière 4.x LTS), l'extraire dans `~/blender/`, utiliser `~/blender/blender --background`. Installer si besoin
   les bibliothèques système minimales (`libxi6 libxxf86vm1 libxfixes3 libxrender1 libgl1 libxkbcommon0 libsm6`).
2. **Pas de GPU** : EEVEE ne fonctionnera probablement pas. Pour les planches, adapter `preview_style.py` et `preview_variants.py` :
   essayer d'abord `BLENDER_WORKBENCH` (rapide, suffisant pour juger formes et couleurs : activer les couleurs de sommet comme couleur
   d'affichage, ombrage « studio », ombres activées), sinon `CYCLES` sur CPU avec 16 échantillons et le débruitage désactivé.
   Résolution des planches : 1 800 × 1 100 maximum.
3. `lib.py` : les polices sont des chemins Windows (`C:\Windows\Fonts\…`). Le texte n'est plus porteur d'information : rendre le chargement de
   police tolérant (police par défaut de Blender si le fichier n'existe pas) sans changer le comportement sous Windows.
4. Construction : `~/blender/blender -b -P blender/build_assets.py -- --out godot/assets/models [--only nom1,nom2]`. L'export écrit aussi
   `assets_meta.json`. Pas de Godot dans le cloud : l'import et les captures du jeu seront faits sur la machine locale après récupération.
5. Pas de Python système requis : tout passe par le Python embarqué de Blender.

## Travail
- **Phase 2** : T2 (`control_tower`, `office`, `workshop`, `customs_office`, `gate_booth`, `reefer_rack`, `scanner`), sols T2
  (`ground_asphalt` violet sombre, `ground_parking`, `yard_marks` alignés sur des travées de 4,4 u : voir « Ce qui reste » du lot B dans
  `docs/DECISIONS.md`), engins et véhicules (`crane_mobile`, `crane_sts`, `rtg`, `straddle`, `reach_stacker`, `truck`, `tractor`, `forklift`,
  `van`, `locomotive`, `wagon`, `tug`, `pilot_boat`, `car_a`, `car_b`, `car_c`). Planche `docs/previews/d_phase2.png`.
- **Phase 3** : T3 (`inspection_hall`, `it_center`, `substation`, `imo_fence`, `rail_terminal`, `warehouse`, `silo`), village
  (`house_a`, `house_b`, `shop`, `tree`, `bush`, `rock`, `hill`), navires (`ship_mini`, `ship_coaster`, `ship_feeder`, `ship_panamax`),
  totem P avec sa face `counter_face`. Planche `docs/previews/d_phase3.png`.
- Registres, emblèmes et couleurs : table § 4 de `ORDRE_BLENDER_D.md`. Règles § 3 (palette seule, −Y, budgets, `anchor_y`, `footprint`,
  ×1,35, pas de texte porteur d'information).
- Regarder chaque planche rendue et corriger ce qui est illisible avant de passer à la suite.

## Livraison
- Après chaque phase : `build_assets.py` complet sans erreur ni dépassement de budget ; **commit** sur une branche `blender-phase2` (puis
  `blender-phase3`) avec les `.glb`, `assets_meta.json`, les sources `blender/`, les planches ; **push** ; ouvrir une pull request vers `main`
  dont la description liste les modèles refaits/créés avec leurs triangles et les chemins des planches.
- Entrée « Lot A — direction D, phases 2 et 3 » dans `docs/DECISIONS.md` ; mise à jour de `docs/BRIEF_STYLE_PORTS.md` § 3.
- Ne pas modifier `godot/scripts/`, `godot/data/`, `godot/scenes/`, `godot/tests/`.
