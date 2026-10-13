# Ordre de mission — développeur Godot : rendu, cadrage, nettoyage, environnement (lot B)

Projet : `C:\Nadir\tycoon_V2` (seul projet de travail ; ne jamais toucher `C:\Nadir\tycoon`). Pas de git : copie zip déjà faite
(`C:\Nadir\tycoon_backups\V2_avant_direction_D_20261013.zip`). Un expert Blender travaille **en parallèle** dans `blender/` et livrera de
nouveaux `.glb` dans `godot/assets/models/` à la fin : **ne pas modifier** `blender/`, `godot/assets/models/`, `assets_meta.json`
(lecture seule). Tout ce lot se fait avec les modèles actuels.

## 1. À lire avant de commencer
1. `docs/REVUE_CHEF_DE_PROJET.md` § 2.2, § 3.2 et § 5 lot B ; `docs/ETUDE_STYLE.md` § 3 (règles communes) ; `docs/DECISIONS.md`
   (entrée « Direction visuelle D » et les précédentes pour les conventions) ; `docs/BRIEF_STYLE_PORTS.md` § 2 « Lumière » et § 3 règles 7–9.
2. `godot/scripts/world/diorama.gd` (lumière, environnement, construction du monde), `camera_rig.gd`, `layout.gd`, `assets.gd`,
   `scripts/ui/world_overlay.gd`, `scripts/ui/hud.gd`, `scripts/ui/settings_sheet.gd`, `scripts/main.gd`, `autoload/save.gd`,
   `godot/assets/vcol.gdshader`, `water.gdshader`, `foam.gdshader`, `tests/run_all.gd`, `tests/ui_smoke.gd`, `tests/swatch_test.tscn`,
   `scripts/util/capture.gd`.

## 2. Environnement machine
- Godot 4.7.1 : `C:\Nadir\Godot\Godot.exe`. Lancer depuis PowerShell avec `Start-Process … -PassThru -NoNewWindow` +
  `-RedirectStandardOutput` / `-RedirectStandardError` puis `$p.WaitForExit()` (les pipes PowerShell bloquent).
- Tests : `--headless --path C:\Nadir\tycoon_V2\godot --script res://tests/run_all.gd` (124 contrôles) et
  `--headless --path C:\Nadir\tycoon_V2\godot res://tests/ui_smoke.tscn` (61 contrôles ; **comme scène**, pas en `--script`).
- Après tout nouveau `class_name` : `--headless --import` **avant** toute capture, sinon `main.gd` plante.
- Captures : `--path C:\Nadir\tycoon_V2\godot -- --fresh --capture=C:/…/x.png --delay=6 [--zoom=28] [--look=x,z] [--tier=2] [--levels=N]`
  (portrait 540×960 par défaut ; voir `capture.gd` pour le paysage). Ne pas bouger la souris pendant une capture. Toujours `--fresh`
  pour ne pas toucher la vraie sauvegarde du joueur.
- Pas de Python système. Fichiers « com0 », « nul »… interdits par Windows.

## 3. Travail, dans cet ordre
1. **Lumière et ombres** (`diorama.gd`, `vcol.gdshader`) — règle 7 du brief : dessus 100 %, flancs 65–75 %, ombres portées **nettes**
   et non noires (environ −15 %, teinte légèrement violacée). Points de départ : ambiance 0,62 → ≈ 0,35, soleil 1,05 → ≈ 1,3,
   `shadow_blur` 1,5 → ≈ 0,4, `shadow_opacity`/couleur d'ombre si disponible, `ROUGHNESS`/`SPECULAR` du shader pour supprimer tout brillant.
   Vérifier sur `swatch_test.tscn` que les teintes de `palette.json` restent fidèles (pas de dérive de couleur), puis sur une capture
   du T1 et une du T3. Garder la correction linéaire (`TONE_MAPPER_LINEAR`).
2. **Cadrage** (`camera_rig.gd`) : zoom par défaut 52 → 40 u ; `START` recentré pour que le quai n°1, le parc et la capitainerie soient
   visibles sous le HUD au démarrage (le haut de l'écran est couvert par les cartes : tenir compte de cette zone morte) ; bornes et
   zoom minimal inchangés. Vérifier par captures en portrait 540×960 et en paysage 1280×720, partie neuve et T3.
3. **Eau** (`water.gdshader`, `diorama.gd`) : teinte plus profonde au large, plus claire près des quais et des plages (dégradé selon la
   distance au rivage ou profondeur simulée), écume existante conservée. Objectif : moins d'effet « île perdue dans un aplat bleu ».
4. **Surcouche** (`world_overlay.gd`) : ancrer chaque bulle à `anchor_y` lu dans `assets_meta.json` si présent, sinon à la hauteur de la
   boîte englobante du modèle + 0,4 ; décaler latéralement deux bulles qui se chevauchent ; ne jamais couvrir le bâtiment lui-même.
5. **Débogage coupé en export** : F1, `--debug-money`, `--tier`, `--levels` et les autres arguments de triche actifs seulement si
   `OS.is_debug_build()` ; la ligne « F1 : outils de débogage » de l'écran Réglages n'apparaît qu'en debug. Les arguments de capture et
   `--fresh` restent disponibles en debug (les tests et captures en ont besoin).
6. **Entrepôts du village** (`layout.gd:180` environ) : ils affichent la couleur de la zone logistique dès le T1. Les rendre neutres
   (teinte grise via le matériau `tint`) jusqu'au T3, ou les conditionner à `t3` si c'est plus simple et cohérent avec la révélation
   progressive. Justifier le choix dans `DECISIONS.md`.
7. **Personnages qui marchent** (`diorama.gd`) : remplacer l'oscillation sur place par un aller-retour entre deux points proches
   (tablier ↔ parc pour le docker, douane ↔ table pour le douanier, gate ↔ guérite pour l'agent, capitainerie ↔ quai pour le
   responsable), balancement vertical léger, demi-tour instantané acceptable ; pas de pathfinding. En pause quand un écran couvre le
   monde (`fx_paused`).
8. **Préparer l'environnement portuaire** (`layout.gd`, `assets.gd`, `diorama.gd`) : l'expert Blender livrera les modèles
   `bollard`, `fender`, `ladder`, `crane_rail`, `breakwater`, `fishing_boat`, `net_pile`, `crate_fish`, `gull`, `life_ring_post`,
   `sidewalk`, `crosswalk`, `gate_lanes`, `yard_marks`, `sign_p`, `ghost_lot`, `car_c`. Ajouter dès maintenant leurs emplacements dans
   `PROPS` / `GROUNDS` / `scatter()` (bollards tous les 4 u le long des quais, défenses entre eux, échelles aux extrémités, rails de
   portique sur le tablier T2+, brise-lames devant la rade, 2 bateaux de pêche et filets près du vieux quai en T1, mouettes sur les
   bollards et le toit du hangar, trottoirs et passages piétons dans le village, voies de gate, marquages de parc sur l'asphalte T2+,
   totem P à l'aire d'attente), et rendre le chargeur **tolérant** : un modèle absent est ignoré avec un avertissement unique dans
   la console, sans planter. Ainsi la livraison Blender s'insère sans nouvelle modification de code.
9. **Tests** : `run_all.gd` et `ui_smoke.tscn` restent verts, aucun contrôle retiré ; ajouter au moins : « un modèle absent n'arrête pas
   la construction du monde », « la bulle d'un bâtiment est au-dessus de son `anchor_y` », « hors debug, `--debug-money` est ignoré ».

## 4. Livrables
- Captures `docs/captures/v2b_portrait_t1.png`, `v2b_paysage_t1.png`, `v2b_portrait_t3.png`, `v2b_zoom_capitainerie.png` (zoom 28,
  look sur la capitainerie), avant/après lumière si possible (`v2b_lumiere_avant.png` / `_apres.png`).
- Entrée « Lot B — rendu, cadrage, environnement » dans `docs/DECISIONS.md` : valeurs retenues, choix, limites, nombre de contrôles.
- Rapport final : ce qui a été fait, valeurs finales de lumière et de caméra, chemins des captures, tests (nombre de contrôles verts),
  ce qui reste.
