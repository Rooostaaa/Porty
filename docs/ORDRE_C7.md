# Ordre de mission — lot C7 : corrections de la revue de code C6 (14/10/2026)

> Pour le sous-agent **développeur senior Godot**. Rédigé par le chef de projet après la revue de code de la version C6
> (4 relecteurs : simulation, monde, véhicules, interface). L'utilisateur a demandé : « corrige tout ça ».
> Sauvegarde faite : `C:\Nadir\tycoon_backups\V2_avant_C7_20261014.zip`.

## Règles (impératives, reprises de `docs/PROMPT_PLAN_PORT.md`)
- Seul projet : `C:\Nadir\tycoon_V2`. Ne jamais toucher `C:\Nadir\tycoon`. **Aucun commit, aucun push.**
- Ne pas modifier `blender/` (aucun point de ce lot ne l'exige).
- Godot : `C:\Nadir\Godot\Godot.exe`. En PowerShell : `Start-Process … -PassThru -NoNewWindow -RedirectStandardOutput … -RedirectStandardError …`
  puis `.WaitForExit()` (les pipes bloquent ; ne pas utiliser `$p` et `$P` dans le même script).
- Tests : `--headless --path C:\Nadir\tycoon_V2\godot --script res://tests/run_all.gd` (**166** contrôles aujourd'hui) ;
  `--headless --path C:\Nadir\tycoon_V2\godot res://tests/ui_smoke.tscn` (**85**, comme scène). **Aucun contrôle retiré** ; ajoute un
  contrôle par correction quand c'est testable.
- Équilibrage : la sonde `--script res://tests/pacing_probe.gd -- --seeds=1,2,3,4 --brief` doit rester dans les tolérances du journal
  (T2 : moyenne des 4 graines ±5 %, chaque graine ±15 %). Aucun point de ce lot ne doit changer le rythme ; vérifie-le à la fin.
- Après un nouveau `class_name` : `--headless --import` avant toute capture fenêtrée. Captures toujours avec `--fresh`, une à la fois,
  sans bouger la souris.
- Si le format de sauvegarde change (point A3) : version de sauvegarde +1 avec migration, l'ancien format (liste) doit se charger.
- Documentation en français : journal à la suite de `docs/JOURNAL_PLAN_BAIE.md` (section « Corrections — lot C7 »), entrée dans
  `docs/DECISIONS.md` si un choix de conception est fait. Réexporter l'APK à la fin avec `exporter_apk.bat` (sans `pause` bloquant :
  lance directement la commande Godot `--export-debug` qu'il contient).

## A. Importants (tous à faire)

**A1. Navires retenus (`diorama.gd` ~1397-1426 `_hold_ships`/`follows`, `ship_view.gd` ~129-162).**
`hold` fige la vue mais la simulation avance : au relâchement le navire rejoint sa position en ligne droite (lerp 12/s) à travers le
brise-lames ; un navire DEPARTING retenu disparaît en pleine vue quand la sim le supprime ; `follows` peut être vrai dans les deux sens
(blocage mutuel, cap figé car `mv = 0`). À obtenir :
- jamais de trajet en ligne droite à travers la terre ou le brise-lames après une retenue : le navire reprend **le long de sa polyligne**
  (par ex. la vue garde sa propre abscisse curviligne et la rattrape à vitesse bornée, ou la retenue ralentit l'avance de la vue au lieu
  de figer la position) ;
- départage des cas symétriques (un seul des deux cède, ex. l'id le plus grand) ;
- un navire qui part n'est jamais supprimé à l'écran avant d'avoir atteint la sortie (ou disparaît hors champ / en fondu) ;
- contrôle ajouté : après une retenue, aucun point du trajet affiché n'entre dans la terre ni dans le brise-lames.

**A2. Camions réaffectés (`traffic_view.gd` ~117-130 `_assign`).** La boucle `pop_back` retire aussi le point d'entrée sur la voie
(même abscisse que la place) : les camions sur l'autoroute coupent en diagonale. Conserver l'itinéraire jusqu'au point d'entrée sur la
voie, puis la nouvelle place. Même problème pour les camions en trop (~218-223) et après un prestige quand `parking_slots` retombe à 0 :
toujours repartir par la route. Contrôle : aucun segment de trajet camion hors des routes/aires.

**A3. Instants de révélation non sauvegardés (`port_sim.gd` ~2045 `to_dict`, ~2091 `from_dict`).** Sauvegarder `features` avec ses
instants, plus `last_reveal_t` / `last_reveal_id` ; accepter l'ancien format liste (→ `true`). Contrôle : sauvegarde/rechargement au
milieu d'une chaîne « after » → la révélation suivante attend toujours son délai.

**A4. Musoirs sur l'eau au palier 3 (`diorama.gd` ~367-380).** Ne poser les `quay_end` que sur la terre existante (borner par
`Zones.reclaimed`/sol réel, ou 48 tant que le terre-plein n'existe pas). Au même endroit, `Layout.LAND_X[sim.tier]` : borner le palier
(et borner `tier` au chargement dans `from_dict`). Contrôle : au T3 sans berth3, aucun musoir en x > 48.

**A5. Outils de debug dans l'APK (`scripts/util/debug_args.gd:36`).** `OS.is_debug_build()` est vrai dans l'export debug. Remplacer par
`OS.has_feature("editor")` (ou une feature personnalisée « dev » absente du preset Android) ; vérifier que la ligne « F1 : outils de
débogage » des Réglages, F1, `--open=debug`, `--load-sim`, `--open-zone` suivent la même règle. Les tests headless et les captures
lancés depuis l'éditeur doivent continuer à fonctionner (vérifie : le binaire Godot lancé en `--path` a la feature `editor`).

**A6. Navire en pilotage au chargement (`diorama.gd` ~1124, `ship_view.gd` ~128, `layout.gd` ~318).** Au `bind()`, un navire en PILOTING
est placé au poste puis son trajet repart du quai vers l'entrée du chenal. Le placer à sa position logique sur le trajet de pilotage
(ou au mouillage/à l'entrée du chenal). Contrôle : rechargement avec un navire en pilotage → aucun point dans la terre.

**A7. Engins du parc (`traffic_view.gd` ~259-267 et ~327-331, `layout.gd` ~463).** `LOAD_WAIT` (3 s) court depuis l'arrivée du camion et
coupe un engin déjà en route (trajet 4–15 s) ; l'engin renvoyé fonce en diagonale à travers les blocs. Le délai ne doit s'appliquer
qu'au cas « aucun engin libre » (intention du journal) ; un engin rappelé repart par les allées. Aussi (mineur) : un engin à l'arrêt
quand le port n'a rien à transporter (tâche « idle » jamais atteinte, ~448-461).

**A8. Texture de distance (`terrain.gd:188`, `water.gdshader:11`).** `FORMAT_RF` (R32F) filtré en linéaire n'est pas garanti sur
Android : passer en `FORMAT_RH` (R16F) — vérifier que le dégradé reste identique (capture avant/après).

## B. Moyens (tous à faire)

- **B1** `diorama.gd` ~296 : `rebuild()` pendant une ouverture → appeler `_finish_opening(true)` en tête si une ouverture est active ;
  `is_instance_valid` avant toute affectation typée dans `_process_opening` (~1025, ~1033).
- **B2** Notifications (`hud.gd` ~345, ~975-1013) : ne pas s'afficher au-dessus d'un écran, d'une popup ou de la carte du tutoriel
  (masquer ou attendre) ; la file ne jette jamais une notification « bad » au profit d'une « info » ; l'anti-doublon n'est enregistré
  qu'à l'affichage ; `toast_box` reprend sa hauteur réelle (pas de rectangle utile figé) ; files de toasts et de bandeaux, bandeau en
  cours, narration et `overlay.zone_info` vidés sur `sim_replaced` (prestige, réinitialisation, chargement).
- **B3** `skip_hint` / narratrice (`hud.gd` ~1068) : cachés quand une popup est ouverte.
- **B4** Recentrage caméra N9 (`hud.gd` ~1105-1154, `diorama.gd` ~862) : attendre la fermeture des écrans avant de lancer bandeau +
  focus ; si une ouverture de zone intervient, revenir à la vue du joueur d'avant le chapitre, pas au cadrage du chapitre.
- **B5** Tutoriel (`data/tutorial.json` ~25-29) : l'étape « parc » ne doit pas attendre l'étape « manager » ; sauvegardes v4 où
  « managers » est révélé avec une grue < 10 : la carte « embauche-la » ne doit pas rester bloquée (texte adapté ou étape sautée).
- **B6** Renvois à « Gestion » avant qu'elle existe (`port_sim.gd` ~1151 `unlock_text("dept_customs")`, `hud.gd` ~897 bouton du conseil
  qui ouvre `ManageSheet`, `tutorial.json` étape « quay » « Onglet Bâtiments ») : texte et bouton cohérents avec ce qui est visible.

## C. Mineurs (tous à faire)

- **C1** `gate_rush` (`port_sim.gd` ~1040-1048) : mesurer l'écart de `delivered`, pas le solde de la file.
- **C2** `_rade_full_t` (`port_sim.gd` ~1596) : avancer selon le temps écoulé (comme `_bn_time`), pas par appel ; restaurer/neutraliser
  `_bn_last` au chargement (~1605).
- **C3** Flancs du terrain (`terrain.gd` ~46-65, `land.gdshader`) : sommets dans le bon ordre, retirer `cull_disabled`, éclairage des
  flancs conforme aux dalles Blender (capture avant/après).
- **C4** Barges du terre-plein (`layout.gd` ~180) : ne plus passer sur les places de mouillage ni sur la voie de départ T3.
- **C5** `exporter_apk.bat` : supprimer l'ancien APK avant l'export.
- **C6** Code mort : état « chapter » des bâtiments (`port_sim.gd` ~1853-1858, 1679, 1701) et champ `chapter` de `unlocks.json` —
  supprimer, ou le faire réellement servir si c'est plus simple ; corriger le commentaire « N5 » trompeur. Ordre des chapitres
  Douane/Contrats vs données (`unlocks.json` ~22-24) : rendre les données cohérentes avec l'ordre réel.
- **C7** Texte du chapitre 3 (`unlocks.json:6`) qui promet les gains hors ligne « à partir de la gate » alors que `apply_offline`
  crédite dès la première minute : corriger le texte (ne pas changer l'équilibrage).
- **C8** Test `ui_smoke.gd:392` : supprimer le terme toujours vrai `hud._calm_until > now` et vérifier réellement qu'une notification en
  file s'affiche après 3 s de calme.

## D. Performance mobile

- `Hud.useful_rect()` : mettre en cache la liste des boutons du bas (plus de `find_children` par image) ; tableaux constants en membres.
- `Zones.first_unbuilt` / `next_zone` / `lot_sign_point` : résultat en cache, recalculé sur `purchased` / `tier_changed` / `sim_replaced`.
- Champ de distance de l'eau (`terrain.gd` ~123-172) : calculé une seule fois par état (cache), plus de double calcul au chargement.
- `Layout.scatter()` : cache (graine fixe). Bouées de mouillage : maillages partagés.

## Fin du lot
1. `run_all` et `ui_smoke` verts (nombre de contrôles ≥ 166 / 85, plus les nouveaux), sonde 4 graines dans les tolérances.
2. Captures regardées : départ T1, chenal avec navires, terre-plein au T3 avant berth3, file de camions sur l'autoroute.
3. Journal + APK réexporté. Rapport final : liste des points faits / non faits avec la raison, chiffres des tests et de la sonde.
