# Ordre de mission — lot D-Monde : réorganisation du port et vie du port (14/10/2026)

> Pour le sous-agent **développeur senior Godot, piste Monde**. Source : `docs/REVUE_CRITIQUE_PORT.md` (axe 1 et partie « monde » de
> l'axe 3), validée en bloc par l'utilisateur. Sauvegarde faite : `tycoon_backups\V2_avant_lot_D_20261014.zip`.
> **Une autre piste (D-UI) travaille en même temps** sur l'interface : lis la section « Coordination ».

## Règles (impératives)
- Seul projet : `C:\Nadir\tycoon_V2`. Ne jamais toucher `C:\Nadir\tycoon`. **Aucun commit, aucun push.** Ne pas modifier `blender/`
  (le chargeur est tolérant : utilise les modèles existants ; une cale de halage peut être faite de primitives ou d'un `quay_end`/`ramp`).
- Godot : `C:\Nadir\Godot\Godot.exe`, PowerShell `Start-Process … -PassThru -NoNewWindow -RedirectStandardOutput … -RedirectStandardError …`
  puis `.WaitForExit()` (pas de pipes ; pas `$p` et `$P` dans le même script).
- Tests : `run_all` (178 aujourd'hui, `--script res://tests/run_all.gd`), `ui_smoke` (99, scène `res://tests/ui_smoke.tscn`). **Aucun
  contrôle retiré** ; un contrôle peut être recalé (nouvelles coordonnées) en le notant au journal ; ajoute des contrôles.
- La simulation et l'équilibrage **ne changent pas** dans cette piste (`Layout` est de la présentation). Sonde 4 graines inchangée à la fin.
- Captures toujours avec `--fresh` (jamais la vraie sauvegarde), une à la fois, sans bouger la souris ; les sauvegardes de bot
  (`tests/bot_saves.gd`, `--load-sim`) servent aux paliers 2–3.
- Après un nouveau `class_name` : `--headless --import` avant une capture fenêtrée.
- Doc en français : section « Lot D — Monde » à la suite de `docs/JOURNAL_PLAN_BAIE.md`, mise à jour de `docs/PLAN_COTE.md`, entrée
  « Réorganisation du port (lot D) » dans `docs/DECISIONS.md`.

## Coordination avec la piste D-UI (qui travaille en parallèle)
- **À toi seul** : `scripts/world/*` (layout, diorama, terrain, zones, traffic_view, ship_view, yard_view, crane_view), `assets/*.gdshader`.
- **À D-UI seule** : `scripts/ui/*`, `autoload/sfx.gd`, `scripts/ui/sheet.gd`, `data/tutorial.json`. Si tu as besoin d'un changement
  là-bas (par ex. une bulle à re-ancrer), écris-le dans ton rapport final au lieu de le faire.
- **Interface que tu fournis à D-UI** (dans `diorama.gd`, méthodes publiques documentées, sans effet si rien à montrer) :
  - `feedback_purchase(dept_id: String) -> void` : effet visible dans le monde quand le joueur achète un niveau du service
    (grue qui « kick » et accélère brièvement, engins qui s'animent, poussière / étincelle sur le bâtiment acheté, etc.) ;
  - `set_overtime(on: bool) -> void` : Heures sup ×2 visibles (gyrophares sur les grues et engins, grues plus rapides, léger
    étalonnage chaud) ; `set_campaign(on: bool) -> void` : pavillons / guirlandes sur la Capitainerie ;
  - `dept_anchor(dept_id: String) -> Vector3` : point monde où cadrer la caméra pour un service (après réorganisation) ;
  - `rade_anchor() -> Vector3` : point du mouillage où poser la bulle « n/n en rade » (D-UI l'utilisera).
  - Signal `ship_paid(world_pos: Vector3, amount: float)` émis quand un navire termine (départ du poste) si la simulation expose le
    montant ; sinon émets-le avec le montant estimé du navire et note-le. D-UI s'en sert pour « +X $ » par événement.
- `tests/run_all.gd` et `tests/ui_smoke.gd` sont partagés : ajoute tes contrôles **dans de nouvelles fonctions**, relis le fichier juste
  avant chaque modification, ne réordonne rien.
- Captures fenêtrées : avant d'en lancer une, crée le fichier verrou
  `C:\Users\BEDJAO~1\AppData\Local\Temp\claude\C--Nadir-tycoon\8da43a4f-210d-4b6d-8673-65d93348718b\scratchpad\capture.lock`
  (s'il existe déjà, attends qu'il disparaisse) et supprime-le après. Même règle pour l'export APK.

## Phase 1 — Douane, gate, enceinte (bloquant B1, important I1)
- **Circulation à droite** : inverser `ROAD_IN_X` / `ROAD_OUT_X`, les voies de l'autoroute, les barrières, `truck_route_*`, la boucle des
  camions (aller / retour chargé) pour que la **douane et `scanner2` soient du côté SORTIE**, avec les camions chargés.
- Scanner mobile **dans l'enceinte** (z 36–43, près de la douane) ; guichet `ewindow` côté public (bureaux) ; e-douane avec les bureaux.
- Halle d'inspection du T3 : dans l'enceinte, à la place du hangar (−42 ; 19) ou adjacente, desservie côté mer par les engins.
- Séparer une zone **« Gate »** (ouverte au départ, icône barrière) d'une zone **« Douane »** (clé `customs1`, icône douane). Renommer
  « La Porte » / « Porte n°2 » en noms clairs (« Gate », « 2ᵉ voie de gate »). `gate2` = **2ᵉ voie de sortie** (cohérent avec son effet).
  Les noms visibles de zones viennent de `Layout` ; si un texte est dans `buildings.json`, tu peux le modifier (données de présentation).
- Contrôles : les camions chargés passent devant/sous la douane et le scanner ; aucun bâtiment de douane hors de l'enceinte ; trajets
  camions toujours sur routes (le contrôle C7 A2 doit rester vert).

## Phase 2 — Pôle nautique sur le cap (bloquant B2)
- Zone 9 déplacée sur le cap : **tour VTS** vers (−62 ; −16) (≈ 35 u de la passe), `rpilot` au pied, **atelier de réparation avec cale
  sur la crique** (≈ −61 ; −27). La capitainerie du T1 reste en (−43 ; 6). Butte/terrain adaptés (`terrain.gd`, `BUTTE`, `ZONES[9]`).
- `dept_pos("harbor")` / `MANAGER_POS_T2` / `CONTROL_TOWER` mis à jour ; tous les navires restent ≥ 2,5 u de la terre (contrôle existant).
- L'ex-Colline devient **« Bureaux du port »** (TOS, guichet, e-douane), reliée à la route d'accès par une petite rue.
- Risque : au départ, la zone grise du cap entre dans le cadrage du tutoriel → gris très discret, cadrage de départ toujours valide
  (contrôle ui_smoke existant).

## Phase 3 — Gare, palier 3, cosmétiques (importants I2–I4, cosmétiques)
- **Gare contre le terre-plein** (zone 12 ≈ x 54…150, z 44…80, `RAIL_Z` ≈ 56), voie reliée au parc ; elle remplit la bande vide.
  La zone logistique reste en arrière-plan.
- **Brise-lames est + passe est au T3** (condition `berth3`) : les navires des postes 3–4 arrivent et repartent par l'est ; postes 1–2
  gardent la passe ouest. Mouillages : vérifie qu'aucun trajet ne coupe un brise-lames (contrôle existant + nouveau).
- **Gate est au T3** (élevé) : seulement si `traffic_view` peut gérer deux files sans toucher à la simulation ; sinon, ne la fais pas et
  explique pourquoi dans le rapport (pas de bricolage).
- Cosmétiques : touchers Quais / Portiques séparés (≥ 9 u ou rayons ajustés) ; GNL avec un petit appontement ; IMO décalée du GNL ;
  repère du Terminal cohérent avec sa zone ; plus de bande d'herbe vide au T3 (arbres / logistique / gare).
- **Même achat, même nom** : la zone affichée « Terminal · 150K $ » (`layout.gd:95`) se vend en Gestion sous le nom « Quai n°2 » →
  la pancarte de zone porte le nom du bâtiment qui l'ouvre (ou l'inverse, mais un seul nom), idem pour toutes les zones.

## Phase 4 — Vie du port (axe 3, partie monde)
- Dockers / personnages : nombre lié aux agents de chaque service (plafonné pour le mobile), dockers au tablier et sur le pont pendant
  le déchargement, demi-tour progressif ; visibles au zoom par défaut.
- Conteneurs du parc et du tablier **posés** (petite descente / glissement) au lieu d'apparaître d'un coup (`yard_view.gd:103,131`).
- Interface `feedback_purchase`, `set_overtime`, `set_campaign`, `dept_anchor`, `rade_anchor`, signal `ship_paid` (voir Coordination).
- Budget mobile : pas d'allocation par image ; maillages partagés / MultiMesh pour les foules.

## Fin de piste
1. `run_all` et `ui_smoke` verts (≥ 178 / 99 + les tiens), sonde 4 graines identique.
2. Captures regardées (dans `docs/captures/`, préfixe `d_monde_`) : vue large T1, T2 (gate + douane + camions chargés côté sortie),
   T3 (gare, brise-lames est, navire par la passe est), zoom pôle nautique, dockers au déchargement, Heures sup visibles.
3. Journal, PLAN_COTE, DECISIONS. Rapport final : points faits / non faits (raison), chiffres, captures, demandes à D-UI.
