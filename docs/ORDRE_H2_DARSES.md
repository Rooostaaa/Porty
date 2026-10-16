# Ordre de mission — lot H2 « Les darses en peigne et les parcelles » (16/10/2026)

> Rédigé par l'architecte / développeur senior Godot (étape 0 : étude, **aucun code modifié**), d'après les décisions validées
> par l'utilisateur : (1) terminal en **darses en peigne** (bassins creusés dans la terre, perpendiculaires à la rive, quais des
> deux côtés, une darse de plus par palier) ; (2) **parcelles délimitées** par **piquets et corde**, non acquises en **terre
> brun clair** avec **cadenas + prix**, la parcelle de départ délimitée aussi, la prochaine en **corde dorée** ; (3) la Crique
> garde sa **brume animée** (autre agent) : la Concession = la première parcelle du terminal.
> Maquettes jetables (block-out, **à ne pas commiter**) : worktree `agent-ae06c293ed5a1eec5`, `godot/scripts/_maquette_port.gd`,
> `scenes/_maquette_port.tscn` ; images `f1_t1..3.png`, `f1_t3_plan.png`, `parc_b_*.png`, planches `formes.png`, `parcelles.png`.
> Journal : `JOURNAL_PLAN_BAIE.md` § « Lot H2 ». Ce plan remplace, pour le terminal, le terre-plein gagné sur la mer du T3
> (`PLAN_PORT.md` § 1, `PLAN_COTE.md` § 1–3) ; la Crique, le cap, le chenal, la passe ouest et le mouillage ne changent pas.

## Règles (impératives)
1. **Base** : on part de la branche **après la fusion de H1** (H1 modifie `layout.gd`, `world_overlay.gd`, `hud.gd`,
   `fishing*.gd`) et **après la brume de la Crique** (worktree séparé, `cloud_layer.gd`). Aucun travail de H2-a/b ne commence
   sur une base qui n'a pas ces deux lots ; H2-0 (plan seul) peut se faire avant.
2. **La simulation économique ne change pas** : mêmes postes (4), mêmes profondeurs, mêmes bâtiments, mêmes prix, même
   `tier_up()`. Tout H2 est présentation (`scripts/world`, `scripts/ui`, `data/parcels.json`, textes). Seul ajout côté
   `PortSim` : rien (les parcelles se déduisent du palier, voir § 4). La sonde (`pacing_probe`) doit donc rester **identique à
   la graine près** ; un écart signale une fuite de présentation dans la simulation.
3. Règles des lots précédents : aucune rotation sur place, ≤ 6 u/s pour tout navire, coques à ≥ 2 u de la terre et des
   ouvrages, camions à droite, engins jamais sur la voie des camions, chaque bâtiment a sa case (`LOTS`), rien posé « là où il
   reste de la place ». Pas de Blender : modèles existants (`quay`, `bollard`, `crane_mobile`, `crane_sts`, `rtg`, `pontoon`,
   `rocks`, `excavator`, `dust_pile`, `barrier_post`…) ou primitives propres.
4. Tests verts à la fin de chaque palier H2-a, H2-b, H2-c (nombres avant/après au journal). Captures 540 × 960 regardées.

## 1. Le plan (repère du jeu : x vers l'est, z vers le sud, mer en z < 0)

### 1.1 Principe
- **Le front de mer reste à z = −6** de x −48 à x 186 : la baie est disparaît, c'est de la terre dès le départ (le terre-plein
  du T3 et son animation de comblement sont supprimés : `RECLAIM`, `OPENING_RECLAIM`, barges). Le port grandit **vers la
  terre** : on creuse.
- **Trois darses** de 48 u (eau de z −6 au mur de fond z 42), séparées par des **doigts** de terre ; les doigts portent les
  parcs, les quais bordent les darses. Une darse de plus par palier : D1 (T1, creusée en trois fois), D2 (T2), D3 (T3,
  eaux profondes).
- **L'arrière-port recule de Δ = 18 u** (3 dalles) pour laisser la place aux darses : voie des camions, enceinte de la douane,
  gate, file, bureaux, parkings, gare (§ 1.4). L'autoroute (z 138–144), la Crique, le cap, le pôle nautique, le chenal, la
  passe ouest, le brise-lames ouest, le mouillage ne bougent pas.
- **4 postes** (ceux de la simulation) dans 6 bords de darse : 2 bords restent des **quais de service** (remorqueurs,
  avitaillement, barges) — voir la question Q1.

### 1.2 Schéma (vue de dessus, 1 caractère ≈ 4 u en x ; z non à l'échelle)
```
x →  -48 -36        -6           34           66           106          140                    186
 z    |   |          |            |            |            |            |                      |
-44 ~cap~~~~║chenal║~~~══ brise-lames ouest (−18…42) ══╦══════ brise-lames est (42…162, T3) ══╗   passe est
     ~~~~~~~║ ↓  ↑ ║~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ←←← arrivée (186;−36)
-32 ~~ départ D2 ←←←←←←←←←←←←←←←←←←←←←←←←←╮                départ D3 →→→→→→→→→→→→→→→→→→→→→ z −28 → (200;−28)
-26 ~~ évitage ╰→╮(−21;−28)   (50;−26)╭→↑ │                (123;−26)↑╮
-18 ~~          ↑    arrivée D2 →→→→→→╯   │                         ╰←←←←←← arrivée D3 z −16 ←╯
 -6 ━━━┓▒▒▒▒▒▒▒▒▒▒▒▒┏━━━━━━━━━━━━┓▒▒▒▒▒▒▒▒▒▒▒▒┏━━━━━━━━━━━━┓▒▒▒▒▒▒▒▒▒▒▒▒┏━━━━━━━━━━━━━━━━━━━━━━━┓
  F0 ┃ D1  (eau)  ┃ F1         ┃ D2  (eau)  ┃ F2         ┃ D3  (eau)  ┃ F3                    ┃
 serv┃svc   poste1┃ap │ parc   ┃      poste2┃ap │parc│ap ┃poste3 poste4┃ap │ RTG │IMO OOG GNL ┃══ appontement
 cap.┃ponton  ◄►  ┃1  │ T1     ┃svc    ◄►   ┃2  │T2  │3  ┃  ◄►    ◄►  ┃4  │     │           ┃   GNL (x 189)
     ┃            ┃   │        ┃enroch.     ┃   │    │   ┃            ┃   │     │           ┃
 42 ━┻━━━━━━━━━━━━┻━━━━━━━━━━━━┻━━━━━━━━━━━━┻━━━━━━━━━━━━┻━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━━━━┛
 48 ═══ voie des camions (A z 52,6 vers l'est, B z 50,4 vers l'ouest), de x −24 au bout du palier : 29 · 101 · 181 ═══
 54 enceinte douane │route│ parkings              gare (voie z 75, liaison x 161, passage à niveau)
138 ═══════════════════════════════════ autoroute (inchangée) ═══════════════════════════════════════
     ◄ parcelle 1 (T1) ─────────────────►◄─ parcelle 2 (T2) ───────►◄─ parcelle 3 (T3) ──────────────────►
```

### 1.3 Cotes du front de mer
| Élément | x | z | Notes |
|---|---|---|---|
| **F0 — quai de service du vieux port** | −48 … −36 | −6 … 42 | capitainerie (−43 ; 6) et hangar (−42 ; 19) **inchangés** ; berge est = quai de service de D1 : ponton d'avitaillement (`supply`, `pontoon` le long de x −36), remorqueur n°2 (`tug2`) |
| **D1 — darse n°1** | −36 … −6 (30 u, axe −21) | −6 → fond **14** (Quai n°1), **26** (Allongement), **42** (Dragage) | dans l'axe du chenal (sortie (−29 ; −22)) : les départs remontent tout droit |
| **F1 — doigt n°1** (parc du T1) | −6 … 34 | −6 … 42 | poste 1 sur sa berge ouest ; tablier x −6…2 ; parc x 3…25 ; allée centrale x 14 ; berge est (x 26…34) = enrochement de D2, quai de service |
| **D2 — darse n°2** | 34 … 66 (32 u, axe 50) | −6 … 42 | creusée par `berth2` (Quai n°2) |
| **F2 — doigt n°2** (parc du T2) | 66 … 106 | −6 … 42 | poste 2 sur sa berge ouest, poste 3 sur sa berge est ; tabliers 66…74 et 98…106 ; parc 75…97, allée x 86 |
| **D3 — darse profonde n°3** | 106 … 140 (34 u, axe 123) | −6 … 42 | creusée par `berth3` ; postes 3 et 4 face à face (deux panamax : 15,6 u libres entre les coques) |
| **F3 — doigt n°3** (bout du terminal) | 140 … 186 | −6 … 42 | poste 4 ; tablier 140…148 ; RTG x 150…172 (allée x 161) ; IMO, hors-gabarit, GNL x 174…186 ; appontement GNL sur la **face est** (189 ; 32), hors du port |
| Côte | (−48 ; −6) → (186 ; −6) → (186 ; 50) puis `GULF_EAST` | | remplace la baie est ; `LIGHT_RED_E` → (187,5 ; −7,5) |
| Mur de fond, tablier de fond | chaque darse | 42 … 46 | quai sans poste (bollards, lampes) |
| Musoirs | bouts de doigts (x −36, −6, 34, 66, 106, 140) | −6 | modules `quay` + bollards ; enrochement sur une berge sans quai |
| Brise-lames est (T3) | 42 … 162 | −44 | inchangé ; passe est entre sa tête (162 ; −44) et l'angle (186 ; −6) |

Profondeur d'eau et navires (échelles actuelles) : mini 14 u, caboteur 22, feeder 33,8 (×0,94), panamax 45,2 (×0,78). Fond de
D1 selon la profondeur du poste 1 : **1 → 14, 2 → 26, 3 → 42** (`quay1`, `quay_ext`, `dredge1`) — l'allongement et le dragage
**creusent la darse** (chantier : `excavator`, eau qui avance). Centre du navire à quai : z = (−6 + fond) / 2 (4, 10, puis 18) ;
un panamax occupe z −4,6 … 40,6 (1,4 u de marge au fond et à l'entrée).

### 1.4 Arrière-port (recul Δ = +18 en z, x inchangé)
Tout ce qui est au sud de la voie des camions recule de 18 u : `LANE_BAND` 48…54, `LANE_A_Z` 52,6, `LANE_B_Z` 50,4,
`LOAD_STOP_Z` 48,4, `LOAD_EDGE_Z` 46,6, `GATE_IN_Z` 63, `GATE_OUT_Z` 61, `GATE` (−21 ; 62), `QUEUE_Z0` 67, `CUSTOMS_YARD`
Rect2(−42, 48, 21, 14), `CUSTOMS_HUT`/`CUSTOMS_OFFICE` z 58,5, `CUSTOMS_TAP` z 56, `GATE_TAP` z 74, `GATE_ISLAND` z 62,8,
`LOT_ROW0` 78 (parkings z 72…126, l'autoroute reste à 138), `MANAGER_POS` douane/gate, `TRACK_RUNS`, rue des bureaux z 78…84,
zones 3, 4, 8, 12, 13, haies, `PROPS`/`GROUNDS`/`LOTS` de ces zones, exclusions du scatter. **Gare** : voie `RAIL_Z` 75
(x 110…186, tunnel x 181 inchangé), bâtiment (150 ; 70), liaison et passage à niveau sur l'allée de F3 (x 161).
`LANE_END_X` = {1 : 29, 2 : 101, 3 : 181} ; `LANE_X0` −24 inchangé. Méthode conseillée : une constante `BACK_DZ := 18.0`
documentée, appliquée **à la main** aux littéraux (pas de calcul à l'exécution), puis grep de tous les z entre 28 et 140.

### 1.5 Voies des navires (vues seulement ; points clés, congés à calculer comme aujourd'hui)
Règle commune (lot F1 conservé : **évitage à l'arrivée**) : le navire s'aligne sur l'axe de la darse, **étrave vers le large**,
devant l'entrée ; il **recule** dans la darse (remorqueur à la proue, vitesse ≤ `REVERSE_V` 2,4 u/s) jusqu'à la hauteur du
poste, puis **glisse latéralement** vers le quai. Au départ : glissement vers l'axe, **sortie en marche avant**, puis la route
sans demi-tour.
- **D1 (poste 1, passe ouest)** : voie d'entrée du chenal jusqu'à (−33 ; −28), demi-tour à gauche de rayon 6 (point bas
  (−27 ; −22)) jusqu'à (−21 ; −28), cap au nord ; recul sur x −21. Départ : x −21 vers le nord, léger S vers la voie de sortie
  du chenal (x ≈ −23), le chenal, `EXIT_NORTH`.
- **D2 (poste 2, passe ouest)** : sortie du chenal, virage à gauche sur la voie **z −18 vers l'est**, quart de tour à gauche
  (rayon 8) en (42 ; −18) → (50 ; −26), cap au nord ; recul sur x 50. Départ : nord jusqu'à (50 ; −24), virage à gauche
  (rayon 8) sur la voie **z −32 vers l'ouest** (6 u du brise-lames), virage à droite dans la voie de sortie du chenal
  (comme `DEPART_W_TURN`, x −19, rayon 8).
- **D3 (postes 3–4, passe est, inchangé jusqu'à la passe)** : voie d'arrivée z −36 vers l'ouest, descente sur la voie
  **z −16** vers l'ouest à partir de x ≈ 150, quart de tour à droite (rayon 10) de (133 ; −16) à (123 ; −26), cap au nord ;
  recul sur x 123. Départ : nord jusqu'à (123 ; −20), virage à droite (rayon 8) sur la voie **z −28 vers l'est**,
  `DEPART_EAST` = [(200 ; −28), (215 ; −90)], `EXIT`.
- **Croisements** (`SHIP_CROSSINGS`) : « large » et « chenal » inchangés ; « ouest » = Rect2(−42, −40, 100, 34) (entrées de D1
  et D2) ; « est » = Rect2(100, −42, 90, 36) ; **une fenêtre par darse** (« d1 », « d2 », « d3 » = l'eau de la darse) dont les
  deux courants sont **entrée** (pilotage/accostage vers un poste de cette darse) et **sortie** (départ d'un poste de cette
  darse) : un seul navire en mouvement dans une darse. Points d'attente (`pilot_gates`) : avant le demi-tour (D1), sur la voie
  z −18 à x 30 (D2), sur la voie z −36 à x 150 (D3).
- Remorqueur : base (−51 ; −15) et rendez-vous inchangés ; pendant le recul, à la proue (côté large) ; pendant le glissement,
  à l'épaule **côté axe** (plus côté nord) ; au départ, il tire vers l'axe puis lâche à la fin du virage.

## 2. Les postes orientés
Aujourd'hui tout poste est un intervalle `x0…x1` sur la ligne z −6, côté mer au nord (`BERTHS`, `ShipView.SEA`, `QUAY_Z`,
`berth_yaw`, `CRANE_SLOTS`, tabliers en z 0,9, allées des engins en z). H2 introduit **un repère par poste**.

### 2.1 Données (`Layout`)
```gdscript
## Postes à quai (ordre de PortSim.berths). quay : point du bord d'eau à l'entrée de la darse ; axis : le long du quai (vers
## le fond) ; sea : normale vers l'eau (vers l'axe de la darse) ; darse : indice dans DARSES ; z_c : centre des grues/navire.
const BERTHS := [
	{"darse": 0, "quay": Vector2(-6, -6),  "sea": Vector2(-1, 0)},   # poste 1 — D1 berge est (F1)
	{"darse": 1, "quay": Vector2(66, -6),  "sea": Vector2(-1, 0)},   # poste 2 — D2 berge est (F2)
	{"darse": 2, "quay": Vector2(106, -6), "sea": Vector2(1, 0)},    # poste 3 — D3 berge ouest (F2)
	{"darse": 2, "quay": Vector2(140, -6), "sea": Vector2(-1, 0)},   # poste 4 — D3 berge est (F3)
]
const DARSES := [   # x0, x1, fond selon ce qui est bâti
	{"x0": -36.0, "x1": -6.0, "head": {"": -6.0, "quay1": 14.0, "quay_ext": 26.0, "dredge1": 42.0}},
	{"x0": 34.0, "x1": 66.0, "head": {"": -6.0, "berth2": 42.0}},
	{"x0": 106.0, "x1": 140.0, "head": {"": -6.0, "berth3": 42.0}},
]
const FINGERS := [  # doigts : parc, allée centrale, allée de tête (engins), arrêts des camions possibles devant
	{"x0": -6.0, "x1": 34.0, "xc": 14.0}, {"x0": 66.0, "x1": 106.0, "xc": 86.0}, {"x0": 140.0, "x1": 186.0, "xc": 161.0},
]
```
Fonctions (remplacent `berth_center`, `berth_ship_pos`, `berth_yaw`, `crane_x`, `QUAY_Z`, `SEA_EDGE_Z` pour les postes) :
`darse_head(k, built)`, `berth_axis(bi)` (= (0 ; 1)), `berth_sea(bi)`, `berth_mid_z(bi, built)`, `berth_ship_pos(bi, width,
built)` (= quai + sea·(width/2 + 0,6), z = `berth_mid_z`), `berth_yaw(bi)` (= cap au nord pour tous), `berth_gate(bi)` (point
sur l'axe devant l'entrée, cap au nord), `crane_pos(bi, ci, n, kind)` (mobile : 1,6 u en arrière du bord ; STS : 3 u ;
`CRANE_SLOTS[0]` devient des **z** : 4, 14, 26 — grue mobile, deuxième grue, STS), `crane_ry(bi)` (= `atan2(-sea.x, -sea.y)`,
le −z local de la grue vers l'eau), `apron_lane(bi)` (x = quai − sea·3,4), `finger_at(x)`, `land_polys(built)`.
`EAST_BERTH0` (= 2) reste : les postes 3–4 passent par la passe est. `LAND_X` devient le bord est du **domaine** par palier
(34, 106, 186) ; la caméra garde son plafond actuel (centre x ≤ 210) : l'habillage du monde ne change pas.

### 2.2 Ce qui change, fichier par fichier
- **`layout.gd`** : § 1 et § 2.1 ; `COAST` (front droit z −6 de −48 à 186, **darses découpées à leur pleine longueur**) +
  **bouchons** : pour chaque darse, le rectangle non encore creusé (x0…x1 × fond…42) est une terre ajoutée à `land_polys(built)`
  — la côte se lit donc toujours à partir de `built` ; `BLOCKS` avec `"dir": "z"` (baies le long de z, rangées le long de x) et
  nouvelles cases (§ 2.3) ; routes des engins par doigt (§ 2.3) ; chemins des navires (§ 1.5) ; `quay_props` le long de chaque
  quai ; `ZONES` 1, 2, 5, 6, 7, 10, 11 redessinées sur les doigts (jamais sur l'eau d'une darse : un sol posé sur une darse se
  verrait), zones 3, 4, 8, 12, 13 reculées de Δ ; `LOTS`, `PROPS`, `GROUNDS`, `STAGE_PROPS` à reprendre ; G2 : `PLATFORM_RECT`
  (2 ; 0) → (26 ; 40) (3 × 5 dalles), quai n°1 = berge x −6 de z −6 à 14 ; `jetty_ruin` sur la future ligne du quai n°1
  (x −8, axe z, de z −12 à 2), retirée au chantier du quai ; `G2_FRICHE_LOOK` (`hud.gd`) ≈ (−10 ; 22), largeur 84.
- **`terrain.gd` / `diorama.gd`** : la terre = `COAST` + bouchons ; le champ de distance de l'eau est mis en cache **par clé de
  creusement** (fond de D1, D2 creusée, D3 creusée : 6 clés au plus, comme `_water_cache` aujourd'hui) et recalculé au chantier.
  **Animation de creusement** (remplace `OPENING_RECLAIM`) : pelleteuses et poussière sur le bouchon, puis l'eau avance de
  l'entrée vers le fond (le bouchon recule par tranches de 6 u, 0,25 s chacune), écume le long des nouvelles berges, puis les
  quais et les grues (ordre et durées de `OPENING`). Quais : modules `quay` (12 u) tournés selon `sea`, musoirs aux bouts des
  doigts, mur et tablier de fond, `rocks` sur une berge sans quai, bandes d'écume tournées (`_foam_strip` prend une direction).
- **`yard_view.gd`** : blocs `dir = "z"` (conteneurs tournés de 90°, `Basis` en instance) ; tablier : une rangée de 8
  conteneurs **le long du quai** de chaque poste (repère du poste) ; `visible_slots` inchangé (les arrêts des camions lisent
  toujours `x`).
- **Engins** (`traffic_view.gd`, routes dans `Layout`) : par doigt, **allée de tablier** le long de chaque quai (x
  `apron_lane`), **allée de tête** z −1 à travers le doigt (entre les musoirs et les blocs), **allée centrale** x `xc` le long
  de z, **bord de chargement** z 46,6. Tablier → bloc : (xa ; z_grue) → (xa ; −1) → (xc ; −1) → (xc ; z_bloc) → (x_bloc ;
  z_bloc). Bloc → camion : (x_bloc ; z_bloc) → (xc ; z_bloc) → (xc ; 46,6) → (x_arrêt ; 46,6). `engine_route_home` idem. Un
  engin ne quitte jamais son doigt ; un poste est servi par le parc de **son** doigt.
- **Camions** (`traffic_view.gd`) : constantes reculées ; la voie passe derrière les fonds de darse ; `_pick_stop` ne garde que
  des x **devant un doigt** (repli par pas de 4,4 u filtré par `finger_at`) ; `crossover_xs` aux bouts 29 et 101.
- **`ship_view.gd`** : `SEA` constante → `Layout.berth_sea(berth_i)` ; nouvelle phase **`BACK_IN`** entre `INBOUND` et
  `CRAB_IN` (trajet `berth_gate` → point de l'axe à la hauteur du poste ; cap affiché = cap du trajet + π ; sillage masqué ;
  vitesse ≤ `REVERSE_V`) ; `CRAB_IN`/`CRAB_OUT` le long de `sea` ; `CRAB_OUT` → `OUTBOUND` (marche avant sur l'axe puis
  la route) ; positions du remorqueur (§ 1.5) ; `BOARD_CRANE_POS` (repère du navire) inchangé.
- **`crane_view.gd`** : rien dans le script (il travaille dans son repère local, mer en −z) ; c'est le diorama qui pose la grue
  en `crane_pos` avec la rotation `crane_ry`. Foule de dockers, bulles, « +$ » du navire payé (`diorama.gd` 2059, 2590, 2930)
  et `main.gd` (`berth_center`, `QUAY_Z`) : passer par `berth_ship_pos` / `crane_pos`.
- **`ship_rules.gd`** : les fenêtres de darse (§ 1.5) ; `ship_stream(state, berth)` devient `crossing_stream(cid, state,
  berth)` (« large »/« chenal » : règle actuelle ; « ouest »/« est » : arrivée contre départ ; « dk » : entrée contre sortie de
  la darse k). La bande balayée suit le sens du déplacement : en recul, elle part de la **poupe** (rien d'autre à changer : les
  points de coque sont sur le trajet).
- **Simulation** (`port_sim.gd`, `ship.gd`) : **rien**. `PortSim` lit `Layout.LAND_X` seulement comme borne de palier
  (commentaire, l. 2666) : inchangé.

### 2.3 Cases des parcs (`BLOCKS`, coin (x ; z), baies de 4,4 u le long de z, 6 rangées = 9 u le long de x)
| Bâtiment | Doigt | Blocs (x ; z ; baies) | Étages |
|---|---|---|---|
| départ / `yard` (plateforme au G2) | F1 | (3 ; 2 ; 4), (16 ; 2 ; 4) | 3 |
| `gravel2` / `gravel3` | F1 | (3 ; 22 ; 4) / (16 ; 22 ; 4) | 3 |
| `asphalt` | F2 | (75 ; 2 ; 4), (88 ; 2 ; 4), (75 ; 18 ; 4), (88 ; 18 ; 4) | 4 |
| `reefer` (zone 1) | F2 | (75 ; 36 ; 1), (88 ; 36 ; 1) | 2 |
| `rtg` | F3 | (150 ; 2 ; 9), (163 ; 2 ; 9) | 5 |
| `imo` (zone 2) / `oog` (zone 3) | F3 | (174 ; 4 ; 2) / (174 ; 16 ; 2, 3 rangées) | 2 / 1 |
Le nombre de cases visibles change (le remplissage affiché est une **part**, la simulation n'en dépend pas). GNL : sphères
(179 ; 32), appontement (189,5 ; 32) tourné de 90° sur la face est. Grues : poste 1 mobile z 4, deuxième z 14, STS z 26 ;
postes 2–4 : réparties sur 48 u (STS ×2,5 = 2 portiques au poste 4, `berth4`).

## 3. Les parcelles

### 3.1 Choix : **acheter la parcelle suivante = passer le palier** (même prix, mêmes conditions)
- **Parcelle 1 « Le Vieux Quai »** = la **Concession** (500 $, carte de la Crique, sous la brume). **Parcelle 2 « La Darse
  n°2 »** = palier T2 (11 000 $ + 4 500 conteneurs, 3 étoiles, `gravel3`). **Parcelle 3 « La Darse profonde »** = palier T3
  (15 000 000 $ + 540 000 conteneurs, 3,5 étoiles, `scanner1`). Le palier final (Concession nationale) n'a pas de parcelle : il reste dans
  Gestion.
- Pourquoi : (a) **la sonde et le bot ne bougent pas** (le bot appelle `tier_up()` ; aucun coût ajouté qui décalerait T2/T3) ;
  (b) un seul geste, à un seul endroit : le passage de palier devient **physique** (on achète la terre où l'on va creuser) ;
  (c) aucun champ de sauvegarde : **parcelles possédées = palier** (0 avant la Concession), migration nulle ; (d) pas de double
  paiement « parcelle + palier » ni de parcelle achetée sans rien à y construire.
- Écartés : achat séparé (nouvelle ligne de coût, recalage, état à sauver, parcelle possédée mais palier fermé : incohérent) ;
  parcelle simple condition sans achat (on perd le plaisir de l'acheter).
- Le bouton PALIER de Gestion et le conseil « PALIER T2 » (`advice.gd`) **mènent à la fiche de la parcelle** (caméra sur la
  parcelle + fiche) : même fonction, un seul chemin d'achat.

### 3.2 Données — `data/parcels.json` (chargé par `DataDB`)
```json
[
 {"id": 1, "tier": 1, "name": "Le Vieux Quai", "badge": [10, 20], "look": [-10, 22, 84],
  "poly": [[-48,-5.4],[34,-5.4],[34,54],[-18,54],[-18,66],[-42,66],[-42,54],[-48,54]]},
 {"id": 2, "tier": 2, "name": "La Darse n°2", "badge": [70, 20], "look": [70, 22, 96],
  "poly": [[34,-5.4],[106,-5.4],[106,54],[34,54]]},
 {"id": 3, "tier": 3, "name": "La Darse profonde", "badge": [146, 20], "look": [146, 22, 110],
  "poly": [[106,-5.4],[186,-5.4],[186,54],[106,54]]}
]
```
Le prix n'est **pas** dans le fichier : `fishing.concession_def().cost` (parcelle 1), `tiers[t].req.money` (2 et 3).
Helper statique `Parcels` (nouveau, `scripts/world/parcels.gd`) : `owned(sim)` (= 0 avant la Concession, sinon `sim.tier`,
3 si `finished`), `next(sim)`, `price(sim, id)`, `at(p: Vector2)`. Les parcelles couvrent le **front du port** (doigts,
darses, voie des camions) et, pour la parcelle 1, l'enceinte de la douane et la barrière ; les bureaux, parkings, la gare et le
pôle nautique restent des **zones grises** hors parcelle (question Q2). Contrôle : chaque case `LOTS` du front tombe dans
exactement une parcelle de son palier.

### 3.3 Rendu (`scripts/world/parcel_view.gd`, nœud du diorama)
- **Terre brun clair** (`#D2C2AC`, entrée `parcel_earth` de `palette.json`) sur toute parcelle **non acquise** (futures darses
  comprises) ; à l'intérieur : ni zones, ni cases fantômes, ni arbres, ni rochers ; rien que la terre, la corde et le cadenas.
- **Piquets et corde** (style b) : piquets tous les 6 u sur le contour, **uniquement sur la terre** (un segment au-dessus de
  l'eau d'une darse ou de la mer est sauté) ; deux MultiMesh (piquets : cylindre bois 0,5 × 2,6 ; corde : boîte 0,3 étirée
  par instance, couleur par instance). On borne le **domaine** (union des parcelles acquises : pas de corde entre deux
  parcelles à soi) en **blanc**, chaque parcelle non acquise en blanc, et la **prochaine en or** (`#FFC83D`, respiration
  légère comme la zone dorée ; l'arête commune avec le domaine prend l'or).
- **Atténuation au dézoom** (lue sur `CameraRig.size`) : corde blanche opaque jusqu'à 80 u, fondue à 0 à 110 u ; corde
  dorée toujours visible, épaissie ×1,6 de 80 à 130 u ; piquets rangés pairs d'abord : au-delà de 100 u,
  `visible_instance_count` = la moitié (un piquet tous les 12 u).
- **Cadenas + prix** dans la surcouche (`world_overlay.gd`, ancrés au point `badge`, taille fixe à l'écran) : disque ambre
  64 px pour la prochaine, indigo 52 px pour les autres, icône `lock.svg`, prix en dessous (`Fmt.money`). Masqués sur une
  parcelle acquise.
- **Acquisition** : la corde de l'arête commune se replie (piquets qui s'enfoncent, 0,6 s), le brun clair fond vers le sol
  normal (1,5 s), les zones grises de la parcelle apparaissent ; étiquette « Parcelle n ✓ » qui monte et s'efface (2,5 s) ;
  puis la cérémonie de palier actuelle. **Parcelle 1** : à la fin de la dissolution de la brume (Concession), la corde du
  domaine se dresse piquet par piquet autour du Vieux Quai et « Parcelle 1 ✓ » s'affiche — c'est le moment « c'est à moi ».
- Coordination brume : la brume couvre la parcelle 1 tant que la Concession n'est pas signée ; **toucher la brume au-dessus
  du terminal ouvre la carte de la Concession** (si l'agent de la brume ne l'a pas fait) ; `ParcelView` écoute la fin de la
  dissolution (signal à exposer par la brume, sinon `concession_done` + délai de `OPENING`).

### 3.4 Toucher → fiche d'achat
Toucher une parcelle non acquise (point dans le polygone, ou le cadenas) ouvre une **fiche** (`parcel_sheet.gd`, sur le modèle
de `sheet.gd`) : nom, « Parcelle n », ce qu'elle ouvre (`tiers.opens`), les conditions de `tier_check()` cochées (conteneurs,
réputation, bâtiments, coût) et le bouton **ACHETER LA PARCELLE — 11 000 $** (actif si `can_tier_up()` et si c'est la
prochaine ; sinon « Achète d'abord la parcelle n−1 »). Achat = `sim.tier_up()`, fiche fermée, caméra sur `look`. Le bouton de
Gestion et AGIR ouvrent la même fiche. Tutoriel **version 10** : après la Concession, « Voici ta parcelle : tout ce qui est
dans la corde est à toi » ; quand le palier T2 devient atteignable, « La parcelle 2 est à vendre : touche le cadenas doré ».

## 4. Ce qui casse, sauvegardes, risques

### 4.1 Tests (nombre après H1 à relever avant de commencer)
- `run_all` : `test_plan_baie`, `test_trajets`, `test_revue_baie`, `test_revue2_baie`, `test_c7`, `test_d_monde`,
  `test_e_flux` (croisements), `test_f2` (bords du monde, scatter), `test_g2` (quai n°1, plateforme), soit ≈ 29 appels
  directs à `BERTHS`/`berth_*`/`SEA_EDGE_Z`/`LANE_*`/`RECLAIM` : à réécrire **sur les nouvelles fonctions**, sans retirer de
  contrôle (un contrôle du terre-plein devient son équivalent « darse »). `ui_smoke` : touchers navire/grue/barrière/cabane,
  projecteurs du tutoriel, `_truck_ground`, cadrages G2 (ils suivent `Layout`). `plan_view` : à reprendre (captures du plan).
- **Contrôles ajoutés** : chaque poste à pleine profondeur contient son plus grand navire avec ≥ 1 u au fond, à l'entrée et
  aux murs ; deux navires à quai dans D3 laissent ≥ largeur panamax + 2 × `SWEEP_SIDE` ; recul ≤ `REVERSE_V`, aucune vitesse
  de lacet au-dessus du plafond actuel (`max_yaw_rate_seen`) ; trajets de chaque poste hors terre (avec bouchons selon
  `built`) et à ≥ 2 u des ouvrages ; fenêtre de darse : jamais deux navires en mouvement dans une darse ; arrêts des camions
  seulement devant un doigt ; engins jamais hors de leur doigt ni sur la voie ; fond de D1 = 14/26/42 selon `built` ;
  parcelles disjointes, prix = Concession/`req.money`, `owned` = palier, piquets jamais sur l'eau, corde blanche invisible à
  120 u, dorée visible ; toucher une parcelle → fiche → `tier_up` ; brun clair absent après achat.
- **Sonde** : `pacing_probe` (4 graines, une par processus) **identique** à avant H2 (mêmes minutes T2, T3, fin) ; bot
  inchangé.

### 4.2 Sauvegardes
Rien à migrer : le monde se déduit de `sim.built` et `sim.tier` (fond de D1, darses creusées, parcelles), la caméra n'est pas
sauvée. Une partie v9 au T2 s'ouvre directement sur le nouveau plan. Un navire sauvé en mouvement repart de son état
(rade : au mouillage ; en pilotage : depuis le point d'attente ; à quai : à quai dans sa darse). Contrôle : les fixtures
`tests/fixtures` (T1, T2, T3, fin) chargées, aucun navire ni camion sur la terre, bonnes parcelles possédées.

### 4.3 Risques
- **Recul de l'arrière-port** (≈ 60 littéraux) : un oubli = un camion ou une haie à l'ancienne place. Parade : grep des z 28…140
  dans `layout.gd`, `hud.gd`, `bubbles.gd`, `tutorial.json` ; `_truck_ground` et les tests de haies attrapent le reste.
- **Navire qui recule** : nouveau dans `ShipView` (cap, sillage, remorqueur, bande balayée). Un recul de 44 u à 2,4 u/s ≈ 20 s
  allonge l'arrivée à l'écran ; la simulation continue (présentation) : mesurer le retard « accostage simulé → navire à quai »
  avant/après ; s'il dépasse +10 s, raccourcir le recul (point d'attente plus proche) avant de toucher la vitesse.
- **Marges serrées** : D1 30 u (feeder 7,5 u à 3,15 u des coques voisines) ; panamax à 1,4 u du fond. Les contrôles de § 4.1
  tranchent ; si besoin, D3 passe à 36 u (F3 commence à 142).
- **Eau** : recalcul du champ de distance à chaque creusement (256², 6 clés) ; mesurer sur téléphone, le faire pendant le
  chantier (pas pendant l'animation de l'eau).
- **Collisions de lots** : H1 et la brume touchent `layout.gd`, `world_overlay.gd`, `hud.gd`, `cloud_layer.gd` : partir de
  leur fusion (règle 1).
- **Textes** : « terre-plein » du T3 (`tiers.json` opens, zone 10 « la mer devient terre », `unlocks.json`, `PLAN_*`) devient
  « la darse profonde » ; « Concession du terre-plein » (parcelle 1) peut rester.

## 5. Paliers de livraison, effort
| Palier | Contenu | Fin de palier | Effort |
|---|---|---|---|
| **H2-0** | Plan seul : nouvelles constantes et fonctions de `Layout` (§ 1–2.1) **dans une copie** lue par `tests/plan_view` ; captures `h2_plan_t1/t2/t3.png` (vue de dessus, postes, voies des navires, camions, engins, parcelles) ; liste des littéraux à reculer | captures regardées, cotes corrigées au journal ; rien dans le jeu | 0,5 j |
| **H2-a** | Le peigne en jeu : côte et bouchons, eau, creusement (remplace le comblement), quais/musoirs/fonds, postes orientés (grues, tabliers, foule), parcs et engins par doigt, recul de l'arrière-port, camions, navires (recul, glissement, départs, règles, remorqueur), zones et cases | `run_all`/`ui_smoke` verts (réécrits, aucun contrôle retiré), sonde identique | 3 j |
| **H2-b** | Parcelles : `parcels.json`, `Parcels`, `ParcelView` (brun clair, piquets et corde, fondu au zoom, or), cadenas + prix dans la surcouche, fiche et achat = palier, liens Gestion/AGIR, révélation à la Concession (avec la brume), tutoriel v10 | contrôles parcelles verts | 1,5 j |
| **H2-c** | Calage visuel, captures, textes, docs (`PLAN_COTE.md` réécrit § 1–4, `PLAN_PORT.md`, `UNIVERS.md`, DECISIONS, journal), APK si SDK | tout vert, captures regardées | 1 j |
Total ≈ **6 jours** de développement (dont la moitié pour H2-a, le gros risque étant le navire qui recule).

**Captures attendues** (`docs/captures/h2_*`, 540 × 960) : plan T1/T2/T3 vu de dessus ; friche après la Concession (corde du
domaine, parcelle 2 dorée avec cadenas et prix, parcelle 3 indigo) ; même vue au zoom maximal (cordes blanches effacées,
piquets espacés, or visible) ; chantier du quai n°1 (demi-darse creusée) ; dragage (D1 complète) ; fiche d'achat de la
parcelle 2 ; achat (corde qui se replie, brun qui fond) ; creusement de D2 ; feeder qui recule dans D1 avec le remorqueur ;
glissement au poste ; départ de D2 par le chenal ; T3 (trois darses, deux panamax face à face dans D3, portiques) ; camions
derrière les fonds de darse ; engins sur un doigt.

## 6. Questions pour l'utilisateur (le reste est tranché ici)
- **Q1 — Nombre de postes.** La simulation a **4 postes** (1 au T1, 2 au T2, 4 au T3). Le plan les loge dans **3 darses** :
  D1 = poste 1 + quai de service du vieux port, D2 = poste 2 + quai de service, D3 = postes 3 et 4 face à face. *Recommandé* :
  garder 4 postes (rien ne bouge dans l'économie). *Autre choix* : 6 postes (les deux quais de service deviennent des postes,
  ≈ 3 au T2 et 6 au T3 comme sur la maquette) — il faut alors ajouter 2 bâtiments `add_berth`, recaler la sonde
  (T2/T3/fin ±5 %), **+1,5 à 2 jours**.
- **Q2 — Ce qui est borné.** Les parcelles couvrent le **front du port** (doigts, darses, voie des camions ; la parcelle 1
  inclut la douane et la barrière). Les bureaux, les parkings et la gare restent des zones grises hors parcelle. *Recommandé* :
  oui (pas de cordes à travers l'arrière-pays). Sinon, on les rattache aux parcelles 2 et 3 (cordes en plusieurs morceaux).

À valider seulement sur capture (pas de question) : le navire qui **recule** dans la darse (évitage à l'arrivée, règle du lot
F1) ; la teinte du brun clair à côté du violet des parcs ; les seuils de fondu (80/110 u).
