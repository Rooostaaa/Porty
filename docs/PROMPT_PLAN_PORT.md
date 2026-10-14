# Prompt — Port Horizon V2 : le plan « La baie et le terre-plein » (zones, trajets, chapitres)

> À coller tel quel dans une nouvelle session Claude Code ouverte sur `C:\Nadir\tycoon_V2`.
> Rédigé le 13/10/2026 après le test de l'APK par le joueur, l'étude `docs/ETUDE_CARTE.md`, le plan `docs/PLAN_PORT.md`
> et l'étude de faisabilité `docs/FAISABILITE_PLAN_PORT.md` (prototype `docs/proto_baie/`, captures `docs/captures/proto_baie_*.png`).

---

## Contexte

Tu es **chef de projet et développeur principal** de **Port Horizon V2**, un idle tycoon portuaire en Godot 4.7 (`C:\Nadir\tycoon_V2\godot`).
Le jeu est complet sur la boucle idle (départements, bâtiments, paliers T1→T4, responsables, hors-ligne, prestige, missions, commerce,
tutoriel, révélation progressive) et équilibré au bot (4 graines, cibles tenues : T1→T2 en 11–12 min, fin du MVP en 1 h 17 – 1 h 30).
Le joueur a testé l'APK et a relevé quatre défauts : **carte anarchique sans plan ni zones à venir, services mélangés (on ne suit pas
« je clique → j'embauche → c'est automatique »), trop de choses dès le départ, camions qui apparaissent et disparaissent et navires qui
traversent la terre.** Ce chantier corrige ces quatre points avec le plan validé ci-dessous. **Ne refais rien de ce qui existe.**

### Lis d'abord, dans cet ordre
1. `docs/FAISABILITE_PLAN_PORT.md` en entier (verdict, corrections, sensations, coût, **plan coté § 6**, décisions § 7 — toutes prises, voir plus bas).
2. `docs/PLAN_PORT.md` (quartiers, 12 zones, états d'une zone, règles de beauté) et `docs/ETUDE_CARTE.md` § 3 à 5 (postes, chapitres, trajets).
3. `docs/proto_baie/main.gd` : le prototype qui prouve le terrain polygonal, la texture de distance de l'eau, les états de zone, le chenal.
   **Réutilise ses techniques** (pas son code tel quel : il est autonome et sans simulation).
4. `docs/DECISIONS.md` (toutes les entrées, surtout « Lot B », « Écarts ISM », « Début de partie doux ») et `docs/UNIVERS.md`.
5. Code : `godot/scripts/world/layout.gd`, `diorama.gd`, `traffic_view.gd`, `ship_view.gd`, `camera_rig.gd`, `yard_view.gd`, `assets.gd`,
   `scripts/ui/world_overlay.gd`, `hud.gd`, `tutorial.gd`, `upgrades_sheet.gd`, `manage_sheet.gd`, `sim/port_sim.gd` (`building_state`,
   `build`, `unlock_ok`, `check_unlocks`, `dept_stage`, `rade_places`, `assist_unload`), `data/buildings.json`, `unlocks.json`,
   `tutorial.json`, `departments.json`, `config.json` (clé `manual`), `tests/run_all.gd`, `tests/ui_smoke.gd`, `tests/pacing_probe.gd`, `tests/bot.gd`.

### Règles du projet (impératives)
- **Seul projet de travail : `C:\Nadir\tycoon_V2`.** Ne jamais toucher `C:\Nadir\tycoon`.
- Avant toute modification : zip de `godot/`, `blender/`, `docs/` dans `C:\Nadir\tycoon_backups\V2_avant_plan_baie_<date>.zip`.
  Le dossier est un dépôt git (`origin` = `Rooostaaa/Tycoon`, branche `main`) : des commits locaux à chaque jalon sont bienvenus,
  **mais demande l'autorisation avant tout `push`**.
- Une session cloud livre peut-être les phases 2 et 3 des modèles Blender sur des branches `blender-phase2` / `blender-phase3` :
  **ne modifie pas `blender/parts/*.py` existants ni `lib.py`**. Les quelques modèles nouveaux de ce chantier vont dans un nouveau fichier
  `blender/parts/baie.py` (voir lot Blender). Le chargeur Godot est tolérant : un modèle absent est ignoré, le travail Godot n'attend pas Blender.
- **Analyser et prototyper avant de coder dans le vrai projet** quand l'équilibrage est en jeu (lot M3) : copie du projet dans le scratchpad,
  mesure avec `tests/pacing_probe.gd`, puis report.
- Godot : `C:\Nadir\Godot\Godot.exe`. En PowerShell, lance-le avec `Start-Process … -PassThru -NoNewWindow -RedirectStandardOutput … -RedirectStandardError …`
  puis `$proc.WaitForExit()` (les pipes bloquent ; **n'utilise pas `$p` et `$P` dans le même script : PowerShell ne distingue pas la casse**).
  Pas de Python sur la machine (Blender embarque le sien). Fichiers « com0 », « nul », « aux » interdits par Windows.
- Tests : `--headless --path C:\Nadir\tycoon_V2\godot --script res://tests/run_all.gd` (129 contrôles) ;
  `--headless --path C:\Nadir\tycoon_V2\godot res://tests/ui_smoke.tscn` (62 contrôles, **comme scène**, pas en `--script`) ;
  sonde : `--script res://tests/pacing_probe.gd -- --seeds=1,2,3,4 [--brief]`. **Aucun contrôle retiré** ; tu en ajoutes.
- Après tout nouveau `class_name` : `--headless --import` **avant** toute capture fenêtrée (sinon `main.gd` plante).
- Captures : `--path C:\Nadir\tycoon_V2\godot -- --fresh --capture=C:/…/x.png --delay=6 [--zoom=40] [--look=x,z] [--tier=2|3] [--levels=N]`.
  Toujours `--fresh` (ne jamais écrire la vraie sauvegarde du joueur) ; ne pas bouger la souris pendant une capture ; une capture à la fois.
- Toutes les valeurs d'équilibrage et de plan dans `godot/data/*.json` ou dans `Layout` (données, pas de constantes éparpillées).
- Si le format de sauvegarde change : version 4 → 5 avec migration dans `PortSim`, vérifiée sur une copie de la vraie sauvegarde (`PH_SAVE_COPY`).
  **Ce chantier ne devrait pas en avoir besoin** : les bâtiments sont enregistrés par identifiant.
- Aucune information portée par du texte 3D : les prix et noms des pancartes sont dessinés par la surcouche (`world_overlay.gd`).
- Documentation en français : `docs/PLAN_COTE.md` (le plan définitif), `ANALYSE.md` § 14 (essais et mesures du lot M3), `DECISIONS.md` entrée « Plan de la baie ».
- Avance sans redemander entre les étapes, en vérifiant par tests, sondes et captures. Arrête-toi et demande seulement si une cible
  ci-dessous est impossible à tenir sans en casser une autre.

---

## Décisions prises (ne pas rouvrir)

1. **Plan « La baie et le terre-plein »** : un port de pêche abrité derrière un cap devient un terminal gagné sur la mer, d'ouest en est.
   **Terrain polygonal construit dans Godot** (pas de côte Blender) ; le plan coté de `FAISABILITE_PLAN_PORT.md` § 6 est la base, à affiner.
2. **Zones = groupes de bâtiments consécutifs** de `buildings.json` ; l'état d'une zone se déduit de `sim.built` et de `building_state`.
   **Une seule zone « prochaine » à la fois**, toutes les autres visibles en gris. « Mouillage » n'est pas une zone : une bouée numérotée
   de plus tous les 10 niveaux de Capitainerie (`STAGE_PROPS`).
3. **Chapitres fermés au niveau 10 du service**, jamais à l'embauche d'un responsable (Parc et Gate sont de palier 2). Les responsables
   gardent palier et prix.
4. **Mouillage devant la passe** (z ≈ −55 à −70), visible d'un glissement depuis le quai ; cadrage de départ ajusté pour que vieux port,
   passe et un navire au mouillage tiennent sous le HUD.
5. **Gestes manuels parc et gate : accélérateurs optionnels à recharge** (modèle : le « coup de main » de la grue), jamais une obligation.
   Geste douane au palier 2 avec l'inspecteur. **Pas de fusion** Capitainerie + Quais : un seul poste visuel (la capitainerie), deux services.
6. **Aucune nouvelle mécanique économique** : les trajets, zones et chapitres sont de la présentation ; la simulation et ses courbes restent celles mesurées.

---

## Travail, dans cet ordre

### Étape 0 — Plan coté (1 page, `docs/PLAN_COTE.md`) puis continue sans attendre
Pars du § 6 de la faisabilité. Pour chaque zone : polygone, sol et couleur (`palette.json`), repère vertical, liste ordonnée des bâtiments
qu'elle contient et **la case de chacun** (position, rotation, empreinte `footprint` de `assets_meta.json`), y compris les agrandissements
« dans leur zone » (gravel2, gravel3, supply, crane2, repair, tug2, quickmoor, ewindow, scanner1/2, rpilot, vacmoor, ecustoms, tos, lng…).
Ajoute : la **voie des camions** (bande de 6 u à sens unique entre le parc et La Porte, prolongée dans le Terminal puis le Terre-plein),
la gate d'entrée et la gate de sortie, le chenal (polyligne), le bassin d'évitage, la passe et ses feux, le mouillage (positions `anchor_pos`),
la sortie des navires par l'est, l'emplacement de chaque département (`dept_pos`) et de son responsable. Règle d'or : **rien n'est posé
« là où il reste de la place »**. Produis une capture vue large du plan avec toutes les zones (grises ou ouvertes) pour le valider visuellement.

### Lot M1 — Terrain, zones, ouverture de zone (Godot)
- `Layout` : polygones (côte, brise-lames, terre-plein), zones (id, palier, polygone, sol, bâtiments, repère), cases de bâtiments, routes.
  Les dalles 6 × 6 restent pour les sols intérieurs à marquages (asphalte, parking, routes) ; le socle de terre est polygonal.
- `Diorama` : terrain polygonal (dessus + flancs en couches, comme le prototype), **texture de distance** pour `water.gdshader`
  (remplace les 12 rectangles ; recalculée quand le terre-plein apparaît), états de zone (grisée : `desat` + pointillés ; prochaine : pointillés
  dorés qui pulsent + empreinte `ghost_lot` + pancarte ; ouverte : couleurs), **une empreinte `ghost_lot` par bâtiment futur dans sa case** avec
  pancarte (nom + prix via la surcouche) quand il est le prochain achat disponible, toucher → fiche du bâtiment (celle de Gestion → Bâtiments).
- **Séquence d'ouverture** (3 à 5 s, passable d'un toucher, `fx_paused` respecté) : la caméra glisse et zoome sur la zone (`CameraRig.focus`,
  `zoom_goal`), les pointillés s'effacent, le sol prend sa couleur par une vague (`tint` animé), les bâtiments surgissent avec la poussière
  (`_build_stage_props` / `_dust` existent), le repère vertical en dernier avec une secousse courte (`rig.shake`) et un son grave (`Sfx`), phrase
  de la narratrice (`Narrator`), retour au cadrage. Terre-plein : barges qui déversent (modèle `barge_sand` si livré, sinon `tug` chargé), bande
  de sable qui avance, puis les quais. `Input.vibrate_handheld` court sur mobile.
- Le cadrage de départ (`CameraRig.START`, `ZOOM_START`) est recalé (décision 4) ; `set_tier_bounds` suit le nouveau plan ; chaque zone tient
  dans un écran portrait au zoom où elle s'ouvre (vérifie par capture : portrait 540×960 et paysage 1280×720).
- `dept_pos`, `MANAGER_WALK`, `STAGE_PROPS`, les bulles de la surcouche (`anchor_point`, « n/N en rade », parc, gate, aire d'attente) suivent le plan.
- Le tutoriel pointe l'**empreinte dans le monde** pour « Allongement du quai » et « terre-plein » (cible `lot:<id>` à ajouter dans `tutorial.gd`),
  et non plus seulement le bouton Gestion.
- Tests : états de zone cohérents avec `building_state` (une seule « prochaine » à tout instant, sur 4 graines de bot jusqu'à la fin) ;
  chaque bâtiment a une case ; aucun chevauchement d'empreintes ; texture de distance négative sur la terre, positive sur l'eau ; la séquence
  d'ouverture se termine et se passe d'un toucher ; cadrage de départ sous le HUD.

### Lot M2 — Trajets visibles et à sens unique (Godot)
- **Navires** (`ship_view.gd`) : polyligne par état définie dans `Layout` (apparition hors écran → mouillage → passe → chenal → bassin
  d'évitage, pivot avec le remorqueur → accostage **parallèle** au quai → départ par l'est hors écran). Corne à la passe, sillage (quad d'écume
  qui suit un navire en mouvement). Les navires ne traversent jamais la terre, le brise-lames, le phare ni un autre poste.
- **Camions** (`traffic_view.gd`) : arrivée par l'autoroute → voie d'entrée → aire d'attente si besoin → gate d'entrée (barrière) → voie des
  camions → arrêt devant le bloc qui le sert → **chargement visible** (le conteneur descend du cavalier sur la remorque, tween ; le camion
  repart chargé) → gate de sortie → voie de sortie → autoroute. **Apparition et disparition hors écran seulement.** Côté mer = engins, côté
  terre = camions, trajets qui ne se croisent pas. Calé sur `truck_served` comme aujourd'hui (habillage, pas de simulation).
- **Conteneur visible de bout en bout** : grue → tablier → cavalier → bloc → camion (les engins du parc vont au bloc réel, pas à un point aléatoire).
- **Test automatique** : échantillonne tous les trajets (navires, camions, engins, personnages) et vérifie qu'aucun point ne tombe sur la
  terre (navires), sur l'eau (véhicules), dans l'empreinte d'un bâtiment ou sur le trajet d'un autre type ; tolérance documentée.

### Lot M3 — Chapitres, cartes réduites, gestes optionnels (Godot, **prototyper dans une copie d'abord**)
- `unlock_ok` : nouvelles conditions `level` (`{"level": {"dept": "cranes", "min": 10}}`) et `manager` ; `unlock_text` les explique.
- Palier 1 en 4 chapitres (`unlocks.json`) : **1. Le petit quai** (argent, navire, grue, « Améliorer » avec deux cartes : Portiques et
  Capitainerie/Quais présentés au même poste) → fermé par Portiques niveau 10 ; **2. Le parc** (le Parc s'allume, geste optionnel, sa carte)
  → Parc niveau 10 ; **3. La gate** (chaîne complète, gains hors ligne expliqués) → Gate niveau 10 ; **4. Faire venir les navires**
  (allongement du quai, Commerce, Missions, Ambre, étoiles) → conditions du palier 2. Douane, contrats, licences, Heures sup, aléas,
  statistiques, Gestion complète : palier 2 (inchangé pour l'essentiel). Responsables : révélés quand leur service est au niveau 10, un par un.
- Règles d'interface : au départ **3 boutons** au HUD ; **une seule pastille « ! »** à l'écran ; « Améliorer » montre les cartes du chapitre
  en cours plus **une** carte grisée « à venir » avec sa condition ; un bandeau « Nouveau : … » par révélation (existant).
- Gestes optionnels parc et gate (`config.json` → `manual`) : toucher le cavalier (rangement ×2 pendant 2 s, recharge) ; toucher la barrière
  (un camion passe tout de suite, recharge). Pastilles « Touche ! » dans la surcouche, comme le coup de main. Le bot peut les utiliser.
- Avant un service présenté, il **tourne seul au minimum** sans jamais bloquer la chaîne : vérifie à la sonde qu'aucun goulot « parc » ou
  « gate » n'apparaît avant son chapitre.
- Tutoriel (`tutorial.json`) recalé sur les chapitres ; narratrice ; les étapes existantes gardent leur conversion par nom (`Settings.tuto_rev`).
- **Mesures** (sonde, 4 graines, avant/après, dans `ANALYSE.md` § 14) : premier achat < 20 s ; aucun trou d'achat > 90 s au palier 1 ;
  **T1 → T2 entre 12 et 20 min** (un allongement modéré est accepté, voir `ETUDE_CARTE.md` § 4) ; durée du T2 et fin du MVP inchangées
  à ±10 % ; aucune violation des invariants du fuzzer. Si une cible ne tient pas, règle d'abord les seuils des chapitres, pas l'économie.

### Lot Blender (petit, en parallèle, nouveau fichier `blender/parts/baie.py`)
`barge_sand` (barge chargée de sable, registre C), `light_red` / `light_green` (feux de passe sur poteau, ×1,35), `zone_sign` (pancarte de zone
avec `counter_face` pour la surcouche, comme `sign_p`), `riprap` (bloc d'enrochement, 3 variantes). Couleurs via `palette.json` ; budgets
≤ 600 triangles ; `assets_meta.json` enrichi (`footprint`, `anchor_y`, `counter_face`) ; planche `docs/previews/baie.png`. Un seul processus
Blender à la fois (`C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` en `--background`, via `Start-Process`).

---

## Sensations de jeu à livrer (vérifiées par captures et par `ui_smoke`)
1. L'ouverture de zone est **la** récompense : séquence complète, passable, jamais bloquante.
2. La zone prochaine respire (pulsation lente) et sa pancarte rebondit quand l'achat devient abordable (même signal que la pastille existante).
3. Le chemin du conteneur se voit en entier, sans apparition ni disparition à l'écran.
4. La silhouette grandit : bas et chaleureux au palier 1, la tour au palier 2, la rangée de portiques et les sphères au palier 3.
5. Retour tactile court sur achat et ouverture (mobile seulement).
6. Un seul sujet nouveau à la fois, une seule pastille « ! », trois boutons au départ.

## Livrables
- `docs/PLAN_COTE.md` + capture vue large ; `docs/captures/baie_t1_depart.png`, `baie_t1_large.png`, `baie_t2.png`, `baie_t3.png`,
  `baie_paysage.png` (1280×720), `baie_ouverture_zone.png` (pendant la séquence), `baie_camion_charge.png`, `baie_chenal.png`.
- `run_all.gd` et `ui_smoke.tscn` verts, aucun contrôle retiré, nouveaux contrôles listés ; `pacing_probe` 4 graines avant/après.
- `ANALYSE.md` § 14 (essais, mesures, ce qui n'a pas marché), `DECISIONS.md` « Plan de la baie » (choix, valeurs, limites), `UNIVERS.md`
  (les 9 quartiers), `BRIEF_STYLE_PORTS.md` si une règle de beauté change.
- Rapport final : ce qui est fait, ce qui reste, mesures, chemins des captures, et la liste des points à regarder pendant le **test humain de
  20 minutes sur APK** qui suit (exporter avec `exporter_apk.bat` si présent, sinon décrire la commande).
