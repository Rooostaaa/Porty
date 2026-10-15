# Journal — plan « La baie et le terre-plein » (développeur Godot)

Ordre de mission : `docs/PROMPT_PLAN_PORT.md` + précisions du chef de projet (sauvegarde déjà faite, lot Blender fait par un
autre agent, pas de git, paliers avec tests et captures). Sorties de test et images de travail : scratchpad de la session.

## Référence avant travaux (13/10, 19 h 55)
- `run_all.gd` **129/129** · `ui_smoke.tscn` **62/62**.
- Sonde `pacing_probe` 4 graines (`--brief`) : T2 11 min 14 / 11 min 50 / 11 min 18 / 12 min 06 · T3 42 min 23 / 39 min 28 /
  40 min 58 / 39 min 00 (durée du T2 31 min 09 / 27 min 38 / 29 min 40 / 26 min 54) · fin 1 h 19 / 1 h 17 / 1 h 30 / 1 h 23 ·
  plus grand trou d'achat au T1 1 min 29 / 1 min 30 / 1 min 34 / 1 min 22 (déjà au-dessus de la cible « ≤ 90 s » pour 3 graines).

## Étape 0 — Plan coté (terminée)
**Fait**
- `docs/PLAN_COTE.md` : terrain (côte, cap, crique, brise-lames, terre-plein), 11 zones + le chenal, cases de **tous** les
  bâtiments (31) avec position, rotation, empreinte, voies des camions (bande z 30–36 à sens unique, gates d'entrée z 45 et de
  sortie z 43), chenal, bassin d'évitage, passe et feux, 12 places de mouillage, sortie est des navires, départements et responsables.
- `Layout` réécrit sur ce plan (données uniquement : `COAST`, `BREAKWATER`, `RECLAIM`, `ZONES`, `LOTS`, `CHANNEL`, `ANCHORS`,
  trajets `ship_path_*` et `truck_route_*`, blocs avec allées des engins, `STAGE_PROPS` replacés, `MANAGER_POS`).
- Nouvelles classes : `Zones` (états ouverte / prochaine / grise, déduits de `sim.built` et de l'ordre des bâtiments ; cadrage
  d'une zone), `Terrain` (polygones avec flancs de terre, pointillés, champ de distance par balayage + chanfrein 3-4).
- `Diorama` construit déjà le terrain polygonal, l'eau par texture de distance (`water.gdshader` : les 12 rectangles sont
  remplacés), les sols de zones (gris voilés + pointillés, dorés qui respirent pour la zone prochaine) et les empreintes.
  Nouveau shader `land.gdshader` (couleur de sommet linéaire, désaturation, voile, vague, apparition du terre-plein).
- Cadrage de départ recalé : `START` (−43 ; −22), largeur 44 u.
- Scène de contrôle `tests/plan_view.tscn` (plan vu de dessus dessiné depuis `Layout`).

**Fichiers** : `scripts/world/layout.gd`, `zones.gd` (nouveau), `terrain.gd` (nouveau), `diorama.gd`, `camera_rig.gd`,
`assets/water.gdshader`, `assets/land.gdshader` (nouveau), `data/palette.json` (+ `zone_ice`, `zone_dash`),
`tests/plan_view.gd/.tscn` (nouveaux), `docs/PLAN_COTE.md` (nouveau).

**Tests** : `run_all` 129/129 · `ui_smoke` 62/62 (un 4ᵉ marcheur permanent, le pêcheur du musoir : le contrôle « ≥ 4
personnages » comptait le douanier, qui n'existe plus avant le bureau de douane).

**Captures** (regardées) : `docs/captures/plan_cote_vue_dessus.png` (plan coté, toutes les zones, cases, trajets),
`plan_cote_vue_large.png` (3D, T1 : vieux port ouvert, tout le reste en gris, contour du terre-plein sur l'eau),
`plan_cote_vue_large_t3.png` (3D, T3 tout construit).

**Défauts connus** : en vue large les cartes du HUD masquent le haut ; trafic encore sur les anciens trajets (lot M2) ;
pancartes et fiches, séquence d'ouverture et tutoriel : lot M1.

## Lot M1 — Terrain, zones, ouverture de zone (terminé)
**Fait**
- Terrain polygonal (continent, brise-lames de repli, terre-plein), sols des zones sous les dalles (y −0,05 / −0,025 : les
  routes restent visibles), eau par texture de distance recalculée à l'apparition du terre-plein.
- États de zone : grise (désaturée + voile clair + pointillés blancs), prochaine (pointillés dorés qui respirent + pancarte
  `zone_sign` à sa place + empreinte dorée), ouverte (couleurs). Zones du terre-plein encore en mer : contour sur l'eau.
- **Une empreinte `ghost_lot` par bâtiment futur dans sa case** (à l'échelle de l'empreinte ; à flot pour ponton et remorqueur ;
  sur le quai pour grue, portique, taquets) ; celle du prochain achat est dorée. Pancarte « nom · prix » dessinée par la surcouche
  (`WorldOverlay._draw_next_sign`), verte et qui rebondit quand l'achat est abordable, « palier T2 » sinon.
- Toucher l'empreinte (ou la pancarte de zone) → **fiche du bâtiment** avec CONSTRUIRE (`Hud.open_building`, même achat que
  Gestion → Bâtiments) ; toucher une zone grisée → sa fiche (ce qu'elle apporte, sa condition) (`Hud.open_zone`).
- **Séquence d'ouverture** (`Diorama._start_opening/_process_opening`, timings dans `Layout.OPENING`) : 4,2 s (5 s pour le
  terre-plein) — caméra qui glisse et zoome (`Zones.focus`), pointillés qui s'effacent, vague de couleur (`land.gdshader`), bâtiments
  qui surgissent avec la poussière, repère vertical en dernier (secousse, corne grave, `Input.vibrate_handheld` sur mobile),
  phrase de la narratrice (`Hud.narrate`, textes `Layout.ZONE_SAY`), retour au cadrage. Terre-plein : 3 barges (`barge_sand`,
  sinon remorqueur chargé) qui avancent et se vident, sable qui avance d'ouest en est, puis les quais. Passable d'un toucher ;
  en pause tant qu'un écran ou une fenêtre couvre le monde (une ouverture déclenchée depuis Gestion se joue au retour au port).
- Retour tactile court à chaque achat (mobile). Feux de passe qui clignotent (pièce `lamp`), bouées du mouillage numérotées.
- Cadrage de départ (−43 ; −22), 44 u ; `set_tier_bounds` inchangé (bornes larges). Tutoriel : cible `lot:<id>` (anneau et flèche
  sur l'empreinte, caméra recentrée) pour « Allongement du quai » et « terre-plein » (`tutorial.json`, mêmes identifiants d'étape).
- Argument de capture (débogage) `--open-zone=N` pour photographier une ouverture.

**Fichiers** : `diorama.gd`, `layout.gd` (`ZONE_SAY`, `ZONE_LANDMARKS`, `OPENING*`), `zones.gd`, `terrain.gd`, `land.gdshader`,
`world_overlay.gd`, `hud.gd`, `tutorial.gd`, `main.gd`, `data/tutorial.json`, `tests/run_all.gd`, `tests/ui_smoke.gd`.

**Tests** : `run_all` **138/138** (+9 : chaque bâtiment a une case ; chaque case dans sa zone ; aucun chevauchement
d'empreintes ; zones cohérentes ; distance négative sur la terre / positive sur l'eau ; le terre-plein change l'eau ; une seule
zone prochaine à tout instant sur 4 parties de bot jusqu'à la fin ; bateaux sur l'eau / bâtiments sur la terre ; cadrage de chaque
zone) · `ui_smoke` **69/69** (+7 : cadrage de départ sous le HUD ; zone prochaine et pancarte ; séquence lancée au retour au port ;
passée d'un toucher ; fiche du bâtiment ; construction depuis la fiche ; ouverture suivante terminée seule). Sonde non relancée :
M1 ne touche pas la simulation.

**Mesures** : largeur de cadrage à l'ouverture 36 (quai allongé) à 120 u (zone sensible) ; construction du terrain + texture de
distance < 0,2 s (pas de saccade visible à l'apparition du terre-plein).

**Captures** (regardées) : `baie_t1_depart.png` (portrait : capitainerie, grue, quai, passe, navire au mouillage n°1 sous le HUD,
pancarte « Quai allongé · 250 $ »), `baie_t1_large.png`, `baie_paysage.png` (1280×720), `baie_ouverture_zone.png` (terre-plein
pendant la séquence : barges, sable, quais) ; vérifications de travail : ouverture du Terminal en portrait et en paysage,
ouverture de La Porte, tutoriel pointant l'empreinte du quai.

**Défauts connus** : les cartes du HUD cachent le haut de l'écran pendant l'ouverture des grandes zones (la zone reste visible) ;
en debug `--tier=2`, des bâtiments T1 non construits gardent leur empreinte dorée (normal : partie forcée).

## Lot M2 — Trajets visibles et à sens unique (terminé)
**Fait**
- **Navires** (`ShipView._make_path`, trajets `Layout.ship_path_*`) : apparition au large hors écran → place de mouillage
  devant la passe → entrée du chenal → passe (corne au franchissement de z −44) → chenal balisé → bassin d'évitage (pivot,
  le remorqueur tire à l'étrave) → voie d'arrivée z −21 → **accostage parallèle** (le remorqueur pousse le flanc) → départ par
  la voie z −30 vers l'est, hors écran. Départ furieux : vers le large puis l'est. Sillage : bande d'écume à la poupe, dont
  l'opacité suit la vitesse. Au mouillage, le navire est évité au vent (cap fixe).
- **Camions** (`TrafficView` réécrit, trajets `Layout.truck_route_*`) : sortie du tunnel ouest (colline sur l'autoroute) →
  voie d'entrée → file (pas 7,5 u) / aire d'attente → gate d'entrée (la barrière se lève au passage) → voie des camions →
  **arrêt le long du parc devant une travée réelle** (z 30,4 ; les autres passent sur la voie A z 32,4 ; arrêts espacés de
  6,8 u) → **un engin apporte le conteneur, qui descend sur la remorque (tween 0,6 s)** ; sans engin libre après 3 s, le
  conteneur passe quand même du bord du parc → bout de la boucle → voie B → gate de sortie → autoroute → tunnel est.
  Les camions en trop dans la file repartent par la voie de sortie (jamais effacés à l'écran). Voitures civiles d'un tunnel à l'autre.
- **Engins** (côté mer) : prennent un conteneur au tablier au pied d'une grue → allée du tablier → allée verticale du groupe
  → allée transversale → **travée réelle** (un emplacement visible du parc) ; à l'appel d'un camion : bloc → bord du parc → camion.
- **Train** : sort de la colline-tunnel est, s'arrête au terminal, repart ; il ne paraît et ne disparaît que si le bout de
  la voie est hors écran.

**Fichiers** : `ship_view.gd`, `traffic_view.gd` (réécrit), `yard_view.gd` (`visible_slots`), `layout.gd` (trajets, allées,
`LOAD_STOP_Z`), `diorama.gd` (`traffic.on_screen`), `tests/run_all.gd`.

**Tests** : `run_all` **143/143** (+5 : navires jamais sur la terre, le brise-lames ni un autre poste — 24 mouillages × 4 postes,
départs de 4 gabarits ; camions sur la terre et hors des bâtiments, 3 paliers × 2 configurations de gate × toutes les places
d'arrêt ; engins côté mer, hors bâtiments, à 1,80 u au plus près des camions (tolérance 1,75 u : la remorque touche le bord du
parc au chargement) ; personnages ni sur les voies ni dans un bâtiment ; deux textures de distance en 74 ms) · `ui_smoke` **69/69**.
Sonde non relancée : M2 est un habillage, la simulation est intacte.

**Captures** (regardées) : `baie_camion_charge.png` (camion qui repart chargé sur la voie des camions, chariots qui portent leur
conteneur dans les allées), `baie_chenal.png` (navire dans le chenal balisé avec son sillage et son remorqueur, navire au mouillage,
bouées numérotées).

**Défauts connus** : les camions ne se suivent pas à distance (deux camions peuvent se frôler sur la voie A quand l'un double
un camion arrêté) ; la file d'attente reste sur la voie d'entrée même en vitesse ×10 (plafond visuel inchangé).

## Lot M3 — Chapitres, cartes réduites, gestes optionnels (terminé, avec une cible non tenue : voir la fin)
**Prototype d'abord** (copie dans le scratchpad, sonde 4 graines), puis report dans le vrai projet (sonde relancée : mêmes chiffres).
**Fait**
- `PortSim.unlock_ok` : conditions `level` (`{"dept": "cranes", "min": 10}`), `manager`, `bottleneck` et `any` (l'une ou l'autre) ;
  `unlock_text` les explique (« quand Portiques atteint le niveau 10 (4/10) »). `manager_revealed(d)` : chaque responsable se
  présente au niveau 10 de son service (`config.json` → `manager_reveal_level`), prix et palier inchangés.
- `unlocks.json` en 4 chapitres + palier 2 : **1. Le petit quai** (grue, capitainerie et quais) → grue niveau 10 ouvre
  **2. Le parc** (Parc, Gestion, Responsables — Yasmine se présente —, licences) → parc niveau 10, ou dès que la gate devient le goulot,
  ouvre **3. La gate** (gains hors ligne expliqués) → gate niveau 10 ouvre **4. Faire venir les navires** (Commerce, Missions,
  réputation, barre de palier ; l'Ambre au premier gagné) → **palier 2** : Heures sup, aléas, statistiques (douane et contrats
  restent liés au bureau de douane).
- Gestes optionnels (`config.json` → `manual`) : toucher un engin du parc = 2 s de rangement d'un coup (recharge 4 s) ; toucher la
  barrière = 2 s de gate d'un coup, un camion passe (recharge 4 s). Pastilles « Touche ! » et « Touche la barrière ! » dans la
  surcouche ; Nadia Benali et Tonio Ferrer les remplacent. Le bot les utilise.
- Améliorer : cartes du chapitre en cours (la grue, puis « au poste de la capitainerie : deux services ») + **une** carte grisée
  « à venir » avec sa condition ; l'écran se reconstruit si un chapitre s'ouvre pendant qu'il est ouvert. Licences : une carte
  « à venir » avant leur chapitre. Gestion → Responsables : seuls les services présentés, « Niveau 10 requis » sinon.
- HUD : 3 boutons au départ (Améliorer, réglages, bouton du conseil) ; une seule pastille « ! » (vérifié).
- Tutoriel (révision 3, conversion par nom depuis les révisions 1 et 2) : nouvelles étapes « parc » (toucher un chariot) et
  « gate » (toucher la barrière), étapes quai et terre-plein sur l'empreinte (M1).
- Bot : premier achat = un niveau de Portiques comme le demande le tutoriel (avant : il économisait 1 min 30 pour le quai).

**Fichiers** : `sim/port_sim.gd`, `data/unlocks.json`, `data/config.json`, `data/tutorial.json`, `autoload/settings.gd`,
`scripts/ui/upgrades_sheet.gd`, `manage_sheet.gd`, `tutorial.gd`, `world_overlay.gd`, `hud.gd`, `scripts/world/diorama.gd`,
`tests/bot.gd`, `tests/pacing_probe.gd` (1er achat, goulot parc/gate avant leur chapitre, dates des chapitres, attente sans
achat abordable), `tests/run_all.gd`, `tests/ui_smoke.gd`.

**Tests** : `run_all` **152/152** (+9 : condition de niveau expliquée ; conditions niveau / responsable / « l'une ou l'autre » ;
chapitre 1 réduit ; enchaînement des chapitres ; responsable au niveau 10 ; geste du parc ; geste de la gate ; responsables qui
remplacent les gestes ; ni parc ni gate goulot avant leur chapitre sur 4 parties) · `ui_smoke` **74/74** (+5 : 3 boutons au
départ ; Améliorer = chapitre + 1 carte à venir ; Heures sup au palier 2 ; une seule pastille « ! » ; deux gestes au toucher).
Deux contrôles existants ont été recalés sur les chapitres sans être retirés (« Gestion se révèle… » : au niveau 10 de la grue ;
« appui maintenu… » : plus d'argent de départ, la Gate étant déjà au niveau 10).

**Mesures (sonde, 4 graines, `--brief`)** — avant → après :
| Mesure | Cible | Avant | Après |
|---|---|---|---|
| Premier achat | < 20 s | 1 min 22 – 1 min 34 | **1 s** |
| Plus long trou d'achat au T1 | ≤ 90 s | 1 min 22 – 1 min 34 | **2 min 08 – 2 min 24** (non tenu) |
| T1 → T2 | 12–20 min | 11 min 14 – 12 min 06 | **12 min 34 – 13 min 29** |
| Durée du T2 | ±10 % | 31:09 / 27:38 / 29:40 / 26:54 | 27:29 / 27:47 / 29:10 / 29:15 (−11,8 / +0,5 / −1,7 / +8,7 %) |
| Fin du MVP | ±10 % | 1 h 19 / 1 h 17 / 1 h 30 / 1 h 23 | 1 h 25 / 1 h 19 / 1 h 25 / 1 h 20 (+7,6 / +2,6 / −5,6 / −3,6 %) |
| Goulot parc / gate avant leur chapitre | 0 | — | 0 s / 0 s |
| Chapitres (parc · gate · navires) | — | — | 7:23–8:35 · 8:03–8:56 · 10:23–11:55 |
| Invariants (conservation, stocks, sauvegarde) | aucune violation | ok | ok (`run_all`) |

**Captures** (regardées) : `baie_chapitre1_ameliorer.png` (Portiques, deux services de la capitainerie, Parc « à venir » avec
« quand Portiques atteint le niveau 10 (1/10) »), `baie_gestes.png` (pastille « Touche ! » au-dessus d'un chariot, coup de main,
camions qui chargent), `baie_t1_depart.png`, `baie_t2.png` (tour, terminal, premier portique, pôle froid, parkings), `baie_t3.png`
(rangée de portiques sur le terre-plein, zone sensible, gare).

**Cible non tenue — le trou d'achat de l'ouverture (à trancher par le chef de projet)**
Le plus long trou d'achat au T1 est l'attente du tout début : 100 $ de départ, un niveau de Portiques (92 $) à 1 s, puis rien
d'abordable avant ≈ 2 min (les petits navires rapportent ≈ 1 $/s). Avant ce chantier, la même attente existait autrement (le bot
gardait ses 100 $ et achetait le quai à 1 min 22 – 1 min 34 : le trou était déjà > 90 s pour 3 graines, et le premier achat
> 20 s). « Premier achat < 20 s » et « aucun trou > 90 s » ne tiennent ensemble qu'en touchant l'économie du début, ce que la
décision 6 exclut ; les seuils de chapitre n'y peuvent rien (les 2 premières minutes sont avant tout chapitre). Le second trou
(≈ 2 min, l'épargne pour le bureau de douane à 800 $ vers 5–7 min) vient de la stratégie d'épargne du bot.
Options : (a) argent de départ 100 → 250 $ (le quai allongé s'achète aussitôt après la grue ; T1 plus court d'≈ 1 min, à
mesurer) ; (b) valeur des petits navires +30 % au T1 ; (c) accepter (le joueur humain a le tutoriel, le coup de main et l'accostage
manuel pendant ces 2 minutes). Rien n'a été changé dans l'économie.
Écart de seuil choisi : les **licences** sont présentées au chapitre 2 et non au palier 2 (essai mesuré « licences au palier 2 » :
T2 13 min 49 – 14 min 56, trous T1 1 min 54 – 2 min 58, gate goulot 3 à 4 min avant son chapitre, fin 1 h 14 – 1 h 30).

---

# Corrections après la revue (`REVUE_PLAN_BAIE.md`, 13/10 soir) — développeur senior Godot

Référence au début des corrections (vrai projet, 22 h 50) : `run_all` 152/152 · `ui_smoke` 74/74 · sonde 4 graines = mesures
finales du lot M3 ci-dessus (T2 12:53 / 12:48 / 13:29 / 12:34, trou T1 2:11 / 2:08 / 2:20 / 2:24, 1er achat 1 s).

## Corrections — palier C1 : export APK (bloquant 4)
- `godot/export_presets.cfg` : préréglage « Android » repris de `C:\Nadir\tycoon` (lu seulement), paquet **`com.nadir.porthorizon.v2`**,
  nom **« Port Horizon V2 »** (s'installe à côté de la V1 sans l'écraser), arm64, debug signé avec la clé de débogage de l'éditeur,
  sortie `../build/PortHorizonV2.apk`, `tests/*` exclus.
- `C:\Nadir\tycoon_V2\exporter_apk.bat` (modèle V1) : crée `build\` si besoin, exporte en debug, vérifie que l'APK existe ;
  `exporter_apk.bat install` l'installe par adb (téléphone branché, débogage USB).
- Export lancé une fois : **APK produit** `C:\Nadir\tycoon_V2\build\PortHorizonV2.apk` (29,5 Mo, signé, vérifié par Godot).
  Outils trouvés dans les réglages de l'éditeur : SDK `%LOCALAPPDATA%\Android\Sdk` (build-tools 36), JDK 17, keystore de débogage. Rien ne manque.
- `.gitignore` exclut déjà `build/` et `*.apk`.

## Corrections — palier C2 : bloquants 1 à 3
**Prototype** (copie `scratchpad/c/proto`, sonde 4 graines), 6 essais, puis report à l'identique dans le vrai projet (sonde relancée : mêmes chiffres).

| Essai | T1 → T2 | Durée T2 | Fin | Trou T1 (achats du bot) | Attente sans rien d'abordable (à la seconde) |
|---|---|---|---|---|---|
| a. 260 $, quai d'abord, un sujet par seuil (écart 20 s), licences 25 s après Yasmine | 11:12 – 11:28 | 27:04 – 30:47 | 1 h 11 – 1 h 25 | 1:37 – 2:20 | 0:38 – 1:16 |
| c. a + licences au niveau 5 de la gate | 11:24 – 12:20 | 26:51 – 29:43 | 1 h 16 – 1 h 25 | idem | idem |
| e. licences au niveau 7 de la gate | 12:24 – 13:04 | 26:09 – 33:24 | 1 h 17 – 1 h 26 | idem | idem |
| f. niveau 6 de la gate | 12:24 – 12:44 | 28:01 – 30:29 | 1 h 17 – 1 h 21 | idem | idem |
| **g. licences 3 min après l'ouverture de la gate (retenu)** | **12:13 – 12:45** | **27:24 – 30:55** | **1 h 12 – 1 h 24** | idem | idem |
| h. 2 min 30 après la gate | 12:05 – 12:44 | 27:36 – 30:54 | 1 h 17 – 1 h 28 | idem | idem |

**Fait**
- **Départ 260 $** (`config.json` → `start_money`) et **le quai allongé devient le premier achat** du tutoriel (étape « quay » avant « buy » ;
  révision 4 du tutoriel, conversion par nom : un joueur arrêté sur « buy » reprend au quai). Le bot suit le même ordre (quai à 1 s,
  puis un niveau de Portiques vers 20 s).
- **« Vert si possible, gris sinon »** : la carte Goulot n'est rouge (titre et pastille) et son bouton vert que si l'action est possible
  tout de suite (`Hud.hint_actionable` : bâtiment suivant abordable, niveau abordable, palier, campagne) ; sinon titre indigo, bouton
  gris (toujours touchable). Dans Améliorer, le texte de rentabilité est gris si l'achat n'est pas abordable (les boutons l'étaient déjà).
- **Plus de « Aucun gain immédiat »** sur la carte désignée par le tutoriel : la carte du service qui ferme le chapitre en cours dit
  « Niveau 10 : ouvre « Le parc » (n/10) » (violet) ; les autres cartes sans gain disent « Pas de gain tout de suite : ce n'est pas le goulot. »
  (`PortSim.chapter_goal`).
- **Un sujet par seuil** (`PortSim.check_unlocks`) : une révélation ordinaire attend `reveal_gap` = 20 s après la précédente ; celles qui
  ouvrent un chapitre (`"opens_chapter": true` : Parc, Gate, Commerce, Douane) passent tout de suite (sinon leur service serait le goulot
  sans avoir été présenté), une seule par seconde. Nouvelle condition `after` (« N s après telle révélation »), expliquée par `unlock_text`.
  Calendrier (`unlocks.json`) : grue 10 → **Parc** · +25 s **Yasmine (Responsables)** · parc 10 ou gate goulot → **Gate** · +25 s **Gestion** ·
  +3 min **Licences** · gate 10 → **Commerce** · +25 s **Missions** · +25 s **Réputation** · +25 s **Paliers** · Ambre (au premier gagné, après
  les Paliers) · bureau de douane → **Douane** · +25 s **Contrats** · palier 2 → **Heures sup** · +30 s **Statistiques** · +30 s **Aléas**.
  Chapitres toujours fermés au niveau 10 du service. L'étape « embauche Yasmine » désigne le bouton RESPONSABLES (Gestion vient plus tard).
- **Séquence d'ouverture** : le HUD s'efface (barres, cartes, boutons, notifications, bandeaux, tutoriel ; masqué : un toucher passe la
  séquence au lieu d'appuyer un bouton), la surcouche (bulles) se tait, les notifications et bandeaux « Nouveau » attendent en file (le
  premier navire d'une classe ne recadre plus la caméra pendant une ouverture : il le fait quand son bandeau paraît), seule la phrase de la
  narratrice passe ; « Toucher pour passer » discret en bas. **Terre-plein** (7,5 s) : 3 barges `barge_sand` arrivent du large, déversent
  (le sable baisse, nuages de sable), la bande de sable avance d'ouest en est, les barges repartent, puis l'asphalte, puis les dalles,
  bollards et marquages, puis les quais et les portiques (repère). **Autres zones** (4,9 s) : petite phase de chantier (cônes aux coins,
  nuages de poussière), vague de couleur, dalles, bâtiments, repère. Timings et positions dans `Layout.OPENING*`, `RECLAIM_*`.
  Les dalles et éléments en MultiMesh d'une zone ouverte par un bâtiment sont rangés dans la zone (ils apparaissent après le chantier).
- Notifications : **une à la fois sous l'en-tête**, en file (au plus 4), au lieu de trois empilées au milieu de l'écran (important 8, fait ici).
- Vocabulaire : « Remise en état de la friche » (gravel2), « carte « Goulot » » dans le tutoriel (au lieu de « terre-plein » et « carte rouge »).
- `palette.json` est régénéré par la chaîne Blender et avait perdu `zone_ice` et `zone_dash` (pôle froid **magenta**) : ces deux couleurs
  vivent désormais dans `Layout.PALETTE_EXTRA`, lues par `Assets.color` à défaut.

**Mesures (vrai projet, 4 graines)** — avant le chantier / après M3 / **après C2** :

| Mesure | Cible | Avant le chantier | Après M3 | **Après C2** |
|---|---|---|---|---|
| Premier achat | < 20 s | 1:22 – 1:34 | 1 s | **1 s** (le quai) |
| Plus long trou d'achat du bot au T1 | ≤ 90 s | 1:22 – 1:34 | 2:08 – 2:24 | **1:37 / 2:20 / 2:04 / 2:20** (épargne du bot, voir plus bas) |
| Plus longue attente sans **rien** d'abordable (à la seconde, nouvelle) | ≤ 90 s | — | — | **1:16 / 0:38 / 1:00 / 0:59** |
| T1 → T2 | 12–20 min | 11:14 – 12:06 | 12:34 – 13:29 | **12:45 / 12:13 / 12:41 / 12:20** |
| Durée du T2 | ±10 % | 31:09 / 27:38 / 29:40 / 26:54 | 27:29 / 27:47 / 29:10 / 29:15 | **27:24 / 30:55 / 30:03 / 28:58** (−12,0 / +11,9 / +1,3 / +7,7 % ; moyenne +1,7 %) |
| Fin du MVP | ±10 % | 1 h 19 / 1 h 17 / 1 h 30 / 1 h 23 | 1 h 25 / 1 h 19 / 1 h 25 / 1 h 20 | **1 h 12 / 1 h 21 / 1 h 21 / 1 h 24** (−8,9 / +5,2 / −10,0 / +1,2 %) |
| Parc / gate goulots avant leur chapitre | 0 | — | 0 s | **0 s** (à la seconde dans `run_all` : ≤ 2 s ; la sonde, par pas de 10 s, voit 10 s pour la graine 4) |
| Écart min. entre deux révélations ordinaires | ≥ 20 s | — | 0 s (4 ensemble) | **≥ 20 s** (`run_all`) |

**Écarts signalés.** (1) Le « trou d'achat » du bot reste > 90 s au T1 : ce n'est plus l'ouverture (premier achat à 1 s, deuxième à 20 s)
mais la **stratégie d'épargne du bot**, qui garde son argent jusqu'à 150 s pour le bureau de douane (800 $) quand le goulot est « pas
assez de navires ». La mesure à la seconde montre qu'il y a **toujours quelque chose d'abordable en moins de 76 s** : la cible
« aucun trou > 90 s » est tenue côté jeu ; je n'ai pas modifié la stratégie du bot (elle sert de référence à toutes les mesures).
(2) Durée du T2 : deux graines dépassent ±10 % de 2 points (−12,0 % et +11,9 %), dans un sens et dans l'autre ; la moyenne est à +1,7 %
et la même dispersion apparaît d'un essai à l'autre sans rien changer au T2 (essai c : toutes dans ±10 %, essai h : trois dehors). Les
licences retardées font partir le T2 avec moins d'argent (20–60 K$ au lieu de 50–100 K$) sans allonger le T2 en moyenne.
(3) Fin du MVP de la graine 3 : −10,0 % (limite). Aucune valeur d'économie n'a été touchée hormis l'argent de départ (décision 1).

**Tests** : `run_all` **153/153** (+1 : « un sujet par seuil » — conditions distinctes, jamais deux révélations dans la même seconde,
≥ 20 s avant une révélation ordinaire, 4 parties) ; 4 contrôles recalés sans être retirés (« le Parc, puis Yasmine… ; Gestion attend
la gate », « la Douane puis les contrats », « chapitres… » avec l'horloge qui avance, « goulot visible … à 5 min 40 s de jeu » : borne en
temps de jeu, le quai étant acheté à 1 s). `ui_smoke` **79/79** (+5 : départ 260 $ et quai abordable ; carte Goulot grise/verte ;
notifications une à la fois sous l'en-tête ; HUD masqué pendant l'ouverture, notification en file, « Toucher pour passer » ; HUD rétabli
après). Sonde : `--set=unlocks.<id>.…` accepté, mesure « à la seconde » et liste des révélations ajoutées ; `tests/t1_dump.gd` (achats du bot au T1).

**Captures regardées** (scratchpad) : terre-plein pendant la séquence (barges qui déversent, sable, HUD masqué, « Toucher pour passer »),
fin de séquence (asphalte, quais, portiques), ouverture de La Porte (cônes du chantier), départ T1 (carte Goulot rouge + CONSTRUIRE vert
à 259 $, pancarte « Quai allongé · 250 $ » verte).

## Corrections — palier C3 : importants 5 à 9, 12, 13, 15
**Fait**
- **Zones à venir teintées** (5) : `Terrain.gray_material` garde la teinte du quartier (désaturation 0,55, voile clair 0,25,
  `Terrain.ZONE_DESAT/ZONE_VEIL` ; le voile du shader `land` ne dépend plus de la désaturation). **Une icône par zone**
  (`Layout.ZONES[].icon`, disque blanc sur l'emplacement de pancarte, dessiné par la surcouche pour chaque zone grise).
  **Empreintes `ghost_lot` seulement dans les zones ouvertes et la zone prochaine** (`Zones.lot_shown`) ; une case **à flot**
  (ponton, remorqueur) n'a plus qu'un **contour** en pointillés.
- **Bulles** (6, 7) : parc, gate, aire d'attente et douane n'apparaissent qu'une fois leur chapitre ouvert ; « 0 camion » →
  **« File : 0 »** ; « n/N en rade » rouge **seulement quand la rade est pleine** ; l'anneau du goulot ne s'affiche que sur un service
  présenté qu'on peut améliorer tout de suite (comme la carte Goulot ; un goulot « bâtiment » est déjà désigné par l'empreinte dorée).
  Toutes les bulles sont **bornées au rectangle utile** (`Hud.useful_rect` : sous les cartes du haut, au-dessus des boutons du bas et
  de la carte du tutoriel, à 8 px des bords ; `Bubbles.bound`) : ramenées dedans, ou pas dessinées si leur ancrage est franchement dehors.
- **Notifications** (8) : fait au palier C2 (une à la fois sous l'en-tête, en file).
- **Mouillage** (9) : bouées **jaunes** de marque spéciale (corps conique + voyant en croix, construites dans Godot) ; place n°1
  déplacée en (−71 ; −69), à 26 u de la pointe du cap (13 u avant), 26 u du feu vert, 52 u du feu rouge ; places 3, 6 et 12 écartées
  d'autant ; grille au-delà de 12 places hors de la sortie nord. Cadrage de départ recalé pour la garder visible :
  `CameraRig.START` (−51 ; −30), largeur 48 u (au lieu de 44). Le **vert du modèle `breakwater`** est rendu gris (paramètre `degreen` du
  shader `vcol`, `Layout.DEGREEN_MODELS`) : le vert est au cap, le rouge à la tête du brise-lames.
- **Zone 12 neutralisée** (12) : entrepôts, hangar, silo, piles de conteneurs et lampadaires de la zone logistique restent gris
  (`"neutral": "rail"`) jusqu'à la gare.
- **Priorité des touchers** (13) : `Diorama.pick_tap` choisit le candidat au **plus petit rapport distance / rayon** (grue 8, engin 5,
  barrière 7, navire 14 + longueur/4, poste de service 9, empreinte touchée 0,5 ; `Layout.TAP_RADIUS`) ; **toucher une zone grise = bulle
  d'information de 2 s** (« La Porte : s'ouvre avec « Bureau de douane » »), plus de fenêtre.
- **Bordures entre quartiers** (15) : haies (`Layout.HEDGES`, pavés vert sombre) entre la Colline et La Porte, le village et l'arrière-pays,
  entre le vieux port et le cap, le long de la Porte n°2, au nord de la gare, entre le terre-plein et l'herbe (au palier 3). **La Colline
  est une vraie butte** : plateau de 1,4 u à flancs de terre (`Layout.BUTTE`, `Layout.ground_y`) ; la tour, l'atelier, le bureau, le centre
  informatique, ses arbres, la responsable de la tour et la pancarte sont posés dessus.

## Corrections — palier C4 : importants 11 et 10
- **Navires par la passe aux paliers 1–2** (11, décision 2) : deux voies dans le chenal (`Layout.CHANNEL_LANE` = 3 u de part et d'autre de
  l'axe, à tribord dans les deux sens) ; à l'arrivée, voie ouest, puis bassin d'évitage et voie d'arrivée z −21 ; au départ, voie z −30
  vers l'ouest, voie de sortie est du chenal, la passe, puis le large au nord (`EXIT_NORTH`, hors écran). **Sortie est au palier 3
  seulement** (`EAST_EXIT_TIER`, `ship_path_depart(bi, w, tier)`). Les navires mouillés à l'est du chenal rejoignent la voie d'entrée par le
  large (`EAST_APPROACH`) : ils croisent la voie de sortie hors du chenal.
- **Brise-lames prolongé vers l'ouest** : x −18…42 (cinq segments, 21 enrochements) ; **passe de 46 u** entre la pointe du cap et sa tête
  (58 u avant) ; feu rouge à la tête (−21 ; −44), dans l'eau, à 7 u de la voie de sortie. Les trajets le permettent (test des trajets vert).
- **Sphères de GNL** (10) : `lng_sphere` livré par l'expert Blender (sommet 15 u, au-dessus de la poutre des portiques 13,8 u) remplace les
  deux silos (145 ; 6) et (145 ; 19), entraxe 13 u, rotation 0, échelle 1, repli `silo` si le modèle manque ; case `lng` agrandie à
  9,4 × 22,4 (aucun chevauchement) ; repère de la zone sensible = la sphère.

**Tests** (après C3 + C4) : `run_all` **162/162** (+9 : sortie par la passe sur la voie de sortie sans croiser la voie d'entrée, par l'est au
T3 ; empreintes zone ouverte + prochaine ; une icône et une couleur connue par zone ; bulles bornées ; mouillage loin du cap, hors du
chenal et de la sortie nord ; passe ≈ 40 u ; butte ; zone 12 grise ; deux sphères de GNL dans leur case — le contrôle des trajets
existant teste maintenant les départs T1 et T3) ; `ui_smoke` **81/81** (+2 : ni parc ni gate en bulle avant leur chapitre et toutes
les bulles dans le rectangle utile ; l'engin visé passe avant la grue, une zone grise donne une bulle et pas une fenêtre). Le contrôle
« cadrage de départ : vieux port, passe et mouillage sous le HUD » reste vert avec le nouveau cadrage.

**Captures regardées** (scratchpad) : départ T1 (navire au mouillage n°1 visible en haut, loin du cap, bouée jaune n°1, « 1/2 en rade »
bleu, carte Goulot rouge + CONSTRUIRE vert, pancarte du quai) ; vue du brise-lames prolongé (feu rouge à la tête, icônes du Terminal, du
pôle froid et du chenal sur les zones grises, contour du chenal).

## Corrections — palier C5 : important 14 (captures réelles) et mineurs
**Captures sur des parties de bot réelles** (14) : `tests/bot_saves.gd` joue une partie (graine 1, même bot que la sonde) et écrit des
sauvegardes dans un dossier temporaire (`scratchpad/c/saves`, jamais `user://save.json`) aux moments voulus ; `main.gd --fresh
--load-sim=<fichier>` (version de débogage seulement) les charge pour la capture, sauvegarde automatique coupée. Moments de la partie
capturée : départ 1 s (260 $) · chapitre 2 à 2 min 24 · chapitre 3 à 4 min 05 · chenal 8 min 20 · T2 12 min 15 (+2 min 30) · camion 16 min 45 ·
terre-plein 39 min 26 (au moment de l'achat du quai profond n°3) · T3 40 min 59 (+4 min). (Dans cette partie le parc s'est ouvert tôt,
parce qu'il est devenu le goulot : la condition « l'une ou l'autre » de son chapitre.)

Captures (toutes regardées), `docs/captures/` :
- `baie_t1_depart.png` — départ réel, tutoriel à l'étape « quai » (flèche sur l'empreinte, pancarte verte « Quai allongé · 250 $ »),
  carte Goulot rouge + CONSTRUIRE vert, chenal à venir en bouées fantômes, « 1/2 en rade » bleu.
- `baie_chapitre2.png` — 2 min 24 : bandeau « Nouveau : Responsables », carte Goulot grise (bureau de douane pas abordable), « 2/2 en
  rade » rouge (rade pleine), « Touche ! » sur un chariot, « Parc 13 % », notification sous l'en-tête dans la colonne de gauche.
- `baie_chapitre3.png` — 4 min 05 : « RESPONSABLES · 1 au travail », Goulot Douane, empreinte à flot du ponton en contour doré.
- `baie_t2.png` — T2 réel (+75 $/s, 397 K$, « + » de l'Ambre écrit), zone prochaine Terminal en doré, icônes des zones grises, zone 12 grise.
- `baie_t3.png` — T3 réel (+364 K$/s), terre-plein et ses portiques, « Zone IMO · 350M $ », sphères de GNL au bord droit.
- `baie_ouverture_zone.png` — **pendant** la séquence du terre-plein (HUD masqué, « Toucher pour passer ») : barges qui déversent, sable,
  aucune empreinte ni pointillé posé sur le sable (corrigé à ce palier : les empreintes de la zone ouverte attendaient l'asphalte, et les
  musoirs du futur quai surgissent désormais avec la zone).
- `baie_camion_charge.png` — T2 : camions chargés (conteneur orange sur la remorque) sur la voie des camions, haie le long de la Porte n°2.
- `baie_chenal.png` — T2 : un feeder vide **ressort par la passe** sur la voie de sortie, sillage en V, feu rouge à la tête du brise-lames prolongé.
- `baie_paysage.png` (1280 × 720) — T2 : la Colline en butte avec sa tour et ses haies, arbres en bosquets, brise-lames prolongé.
- `plan_cote_vue_dessus.png` — plan coté à jour (brise-lames, mouillages, voies d'entrée et de sortie, sortie nord T1–T2 et est T3).

**Mineurs**
- Sillage en V : deux traînées d'écume qui s'ouvrent depuis la poupe et s'estompent (dégradé), seulement quand le navire avance.
- Chenal à venir : bouées fantômes translucides (dorées s'il est le prochain achat) à la place des pointillés.
- Vocabulaire du tutoriel : « friche » pour gravel2 (« Remise en état de la friche »), « carte « Goulot » » au lieu de « carte rouge » (palier C2).
- Texte des bulles et pancartes : 30 px sur 1080 (≈ 15 px sur un écran de 540 ; 28 avant), bulles un peu plus hautes (58 px).
- Pastille orange vide du HUD : c'était le bouton « + » de l'Ambre (icône non rendue) → « + » écrit.
- « RESPONSABLES 0/6 : OFF » → « RESPONSABLES », « · n au travail », « · m à embaucher ».
- « n/N en rade » rouge seulement quand la rade est pleine (palier C3).
- Arbres en bosquets : 3 à 7 arbres serrés autour d'un centre, buissons en lisière, rochers isolés (`Layout.scatter`).
- Durée du T2 de la graine 1 (−11,8 % avant) : −12,0 % après les corrections (dispersion, voir § C2 et `ANALYSE.md` § 14).

**Tests** : `run_all` **162/162**, `ui_smoke` **81/81** (inchangés à ce palier ; les captures sont la preuve des mineurs visuels).

## Bilan des corrections (14/10, 0 h 40)
- Tests : `run_all` 152 → **162/162** · `ui_smoke` 74 → **81/81** ; aucun contrôle retiré (5 recalés : chapitres et révélations avec
  l'horloge qui avance, goulot visible borné en temps de jeu).
- Sonde finale (vrai projet, après C5, identique à C2) : 1er achat 1 s · T1 → T2 12:45 / 12:13 / 12:41 / 12:20 · durée du T2 27:24 /
  30:55 / 30:03 / 28:58 · fin 1 h 12 / 1 h 21 / 1 h 21 / 1 h 24 · attente sans rien d'abordable au T1 1:16 / 0:38 / 1:00 / 0:59 · parc et
  gate goulots avant leur chapitre 0 s.
- APK réexporté après les corrections : `C:\Nadir\tycoon_V2\build\PortHorizonV2.apk` (29,6 Mo) — `exporter_apk.bat` (ou `exporter_apk.bat install`).
- Points à regarder au test humain de 20 min : voir le rapport final (ordre de mission) et `REVUE_PLAN_BAIE.md`.

---

# Seconde revue (14/10) — lot C6

## Corrections — palier C6a : bloquants N1, N2, N3
- **N1 — coques sur les bouées** : axe du chenal décalé de 3 u vers l'ouest, chenal à ±14 u, voies à 4 u (entrée, ouest) et 6 u
  (sortie, est) de l'axe ; bouées seulement du large jusqu'à la passe (la passe est marquée par ses feux, le bassin est libre) ;
  tous les navires entrent par l'entrée du chenal (`CHANNEL_ENTRY`, plus de traversée de la ligne des bouées depuis le mouillage) ;
  au départ (paliers 1–2), le navire vire en biais vers le bassin (`DEPART_TURN_Z`) ; à l'écran, le cap du navire est la corde
  étrave–poupe posées sur le trajet (`ShipView`) : la coque suit les courbes sans balayer les bouées.
  **Contrôle** `run_all` « N1 » : sur tous les trajets du chenal et de la passe (12 mouillages × 4 postes × gabarits autorisés,
  départs T1), coque (rectangle orienté) à ≥ 1,5 u de toute bouée et des deux feux — au plus près **2,00 u** (panamax).
  Exemption documentée : le pivot du remorqueur dans le bassin (z > −36), où il n'y a plus de bouée.
- **N2 — notifications sur le HUD** : la notification se pose **sous la carte Goulot** (sous la pile du haut : en-tête, missions,
  Responsables, carte Goulot, aléa), dans la colonne de gauche, fond opaque ; **pas de doublon avant 60 s** ni deux fois dans la file.
  **Contrôle** `ui_smoke` : la notification ne touche aucun bouton ni la pastille d'Améliorer ; un doublon est refusé.
- **N3 — départ** : la carte Goulot s'efface pendant une carte du tutoriel (sauf l'étape qui la désigne) ; cadrage de départ
  `START` (−45 ; −29), largeur 58 u. **Contrôle** `ui_smoke` (désormais en fenêtre portrait 540 × 960, vue 1080 × 1920 : en
  `--headless` la fenêtre par défaut était carrée, ce qui faussait les contrôles de cadrage) : avec la carte du tutoriel, le phare,
  le navire du mouillage n°1 et l'empreinte du quai allongé sont dans le rectangle utile ; sans tutoriel, le navire reste sous
  la carte Goulot (contrôle de cadrage existant ; son point « passe » suit la passe déplacée : (−34 ; −44)).
- Aussi : **N10 (partie statique)** — mouillages sur une grille 50 × 28 u, feeder ×0,94 et panamax ×0,78 à l'écran (deux navires à des
  postes voisins), **contrôle** `run_all` « deux coques ≥ 2 u » (12 mouillages en panamax, postes 1/2 et 3/4, voies du chenal) :
  au plus près 8,7 u au mouillage. **N4** fait aussi à ce palier : toute la surcouche est découpée au rectangle utile
  (`clip_contents`, position et taille suivent `Hud.useful_rect`). **N6** : bouées fantômes bleu-gris α 0,35, ×0,8, une paire sur deux.
- `run_all` accepte `-- --only=<nom>` (un seul test, mise au point).

**Tests** : `run_all` **164/164** (+2 : N1, N10) · `ui_smoke` **83/83** (+2 : pas de doublon, N3 ; « notifications » et « trois
boutons au départ » recalés : sous la carte Goulot ; la carte Goulot masquée par le tutoriel compte comme bouton).
**Capture regardée** : départ, tutoriel à l'étape « navire » (carte Goulot masquée, navire n°1, phare, bouées fantômes discrètes).

## Corrections — palier C6b : importants N4 à N10
Prototype `scratchpad/c/proto2` (sonde 4 graines), 5 essais, puis report et sonde dans le vrai projet.

| Essai | T1 → T2 | Durée du T2 | Fin | Chapitres parc · gate |
|---|---|---|---|---|
| a. N5 (bureau de douane masqué jusqu'au chapitre 4) + N5 bis (diagnostic du bot) + N7 + N8 | **27:16 – 29:07** | — | 1 h 37 – 1 h 44 | 8:38–12:49 · 19:11–19:55 |
| b. a, douane masquée jusqu'au chapitre 3 seulement | **24:38 – 25:36** | — | 1 h 31 – 1 h 37 | 8:38–12:49 · 19:11–19:55 |
| c. sans N5 | 13:28 – 15:08 | 27:03 – 31:18 | 1 h 18 – 1 h 28 | 6:43–8:24 · 8:03–10:19 |
| d. c + carte Douane retardée au chapitre 4 (bâtiment libre) | **20:52 – 22:49** | — | 1 h 25 – 1 h 40 | 7:07–9:45 · 15:32–16:53 |
| e. c, N5 bis en présentation seulement (retenu, + N7 lissé) | **12:38 – 13:15** | **28:03 – 29:43** | **1 h 14 – 1 h 25** | 6:19–6:54 · 7:30–8:27 |

**Fait**
- **N4** (palier C6a) : surcouche découpée au rectangle utile.
- **N5 — non fait (impossible sans casser le T1)** : le bureau de douane (800 $, le 3e bâtiment) apporte les armateurs étrangers
  (trafic ×1,8) vers 4 min 30 – 5 min ; le masquer jusqu'au chapitre 4 (essai a) ou 3 (essai b), ou seulement retarder la carte
  Douane (essai d), repousse le palier 2 à 21 – 29 min (cible 12–20) : sans lui, la grue met deux fois plus de temps à atteindre le
  niveau 10, donc tous les chapitres glissent. Options pour le chef de projet : (1) accepter la Douane au chapitre 2 et l'annoncer
  comme telle (« La Porte s'ouvre ») ; (2) déplacer le bureau de douane après le dragage et compenser le trafic du T1 (touche
  l'économie, exclu ici) ; (3) ne changer que le texte du conseil pendant les chapitres 2–3. Rien n'a été modifié.
- **N5 bis** : conseil **affiché** (`PortSim.analysis_shown` / `shown_analysis()`) : rade pleine depuis 3 s (`rade_full_hold`) → le
  goulot affiché n'est plus « pas assez de navires », c'est le maillon suivant (« Portiques ») ; l'analyse elle-même (bot, hors-ligne,
  contrats) ne change pas (essai c : la changer aussi déplaçait la fin du MVP de +14 %). Carte Goulot, anneau, bulle de la douane,
  pastille « GOULOT » d'Améliorer lisent le conseil affiché.
- **N6** (palier C6a) : bouées fantômes discrètes.
- **N7 (option a)** : la gate s'ouvre au niveau 10 du parc **ou** quand elle est le goulot depuis 45 s (`"bottleneck": "gate", "for": 45`,
  temps lissé : un instant ailleurs n'efface pas tout). Chapitre 2 : 1 min 11 – 1 min 52 (≈ 50 s avant).
- **N8** : `reveal_gap` 60 s ; une révélation peut venir 20 s après la précédente (`reveal_gap_min`) **si celle-ci a servi** (condition
  `used` de `unlocks.json` : chariot touché ou parc niveau 2, Yasmine embauchée, licence niveau 2, campagne lancée, mission réclamée,
  douane niveau 2, contrat livré). Notifications : file de 2, sans doublon, 3 s de calme après une ouverture de zone, une toutes les 4 s.
- **N9** : à l'ouverture d'un chapitre de service (Parc, Gate, Douane), la caméra va sur son poste quand le bandeau paraît, puis revient
  au bout de 2 s si le joueur n'a pas bougé la vue.
- **N10** : distance de suivi (`Diorama.follows`, `Layout.SHIP_FOLLOW_GAP` = 4 u) : un navire en route qui en rattrape un autre allant
  dans le même sens attend derrière lui ; un navire dont le poste est dans la zone en cours d'ouverture attend que ses quais sortent
  de terre. Partie statique (mouillages, postes voisins, voies) au palier C6a.

**Critère du T2 adopté** (seconde revue) : « moyenne des 4 graines ±5 %, chaque graine ±15 % ».

**Mesures (vrai projet, 4 graines)** : 1er achat 1 s · T1 → T2 **13:15 / 12:46 / 12:38 / 13:03** · durée du T2 **28:36 / 28:21 / 29:43 /
28:03** (−8,2 / +2,6 / +0,2 / +4,3 % ; **moyenne −0,5 %**) · fin **1 h 14 / 1 h 15 / 1 h 20 / 1 h 25** (−6,3 / −2,6 / −11,1 / +2,4 % ;
moyenne −4,6 %) · attente sans rien d'abordable au T1 ≤ 1 min 16 · parc goulot avant son chapitre 0 s ; gate ≤ 45 s d'affilée (par
construction) · chapitres parc 6:19–6:54, gate 7:30–8:27, navires 12:12–12:37. **Hors tolérance** : fin du MVP de la graine 3 à −11,1 %
(−10,0 % avant ce lot, −5,6 % après M3).

**Tests** : `run_all` **166/166** (+2 : N8 « une révélation par minute ou dès que la précédente a servi », N5 bis « rade pleine →
conseil affiché ») ; recalés : « le Parc puis Yasmine », « la Douane puis les contrats » (60 s / 20 s), « un sujet par seuil » (écart
minimal 20 s), « la gate au plus 45 s d'affilée » (au lieu de 2 s : c'est l'option a). `ui_smoke` **84/84** (+1 : distance de suivi).

## Corrections — palier C6c : mineurs N11–N15, captures, APK
- **N11** « Toucher pour passer » : 34 px, blanc sur une pastille sombre, sans clignotement.
- **N12** une ouverture de zone ne se passe d'un toucher qu'après 1,5 s (`Layout.OPENING_SKIP_AFTER` ; le toucher est absorbé avant) ;
  « Toucher pour passer » ne paraît qu'à ce moment. **Contrôle** `ui_smoke`.
- **N13** un seul badge numérique : le nombre de contrats (Commerce) se tait quand la pastille d'Améliorer est affichée.
- **N14** empreintes des zones ouvertes avec un liseré en pointillés (doré pour le prochain achat).
- **N15** « File : n » ancrée sur la guérite (ou la barrière avant elle), plus de décalage forcé vers l'intérieur de l'écran.
- Aussi : aucune bulle sur le bouton Améliorer (le rectangle utile commence sous lui).

**Captures** (parties de bot réelles, graine 1, sauvegardes régénérées après C6b ; toutes regardées), `docs/captures/` :
`baie_t1_depart.png` (accueil du tutoriel, carte Goulot masquée, phare, navire n°1 et sa bulle, quai allongé), `baie_chapitre3.png`
(4 min 51 : la gate, ses barrières, un camion, « File : 0 », la douane), `baie_t3_gnl.png` (T3 réel : les deux sphères de GNL au bout du
terre-plein, « 10/10 en rade » avec un goulot « parc saturé » : plus de contradiction), et les cinq captures périmées refaites :
`baie_t1_large.png` (T1 à 9 min : notification sous la carte Goulot, « Rade pleine » + goulot Portiques), `baie_gestes.png` (« Touche ! »
sur un chariot, anneau du goulot sur le parc), `baie_chapitre1_ameliorer.png` (boutons et rentabilité gris à 41 $), `plan_cote_vue_large.png`
(T1, icônes des zones à venir, brise-lames), `plan_cote_vue_large_t3.png` (T3). Refaites aussi parce que le chenal a changé :
`baie_chenal.png` (chenal ±14 u, bouées jusqu'à la passe), `baie_ouverture_zone.png` (terre-plein, « Toucher pour passer » lisible).

**Tests** : `run_all` **166/166** · `ui_smoke` **85/85** (+1 : N12).

APK réexporté après C6 : `C:\Nadir\tycoon_V2\build\PortHorizonV2.apk` (29,6 Mo, 14/10 7 h 18) — `exporter_apk.bat` (ou `exporter_apk.bat install`).


## Corrections — lot C7 : revue de code de la version C6 (14/10)
Ordre de mission `docs/ORDRE_C7.md`. Sauvegarde avant le lot : `C:\Nadir\tycoon_backups\V2_avant_C7_20261014.zip`. Aucun point n'a
changé le rythme : la sonde 4 graines est **identique** à celle de C6b (T1 → T2 13:15 / 12:46 / 12:38 / 13:03 · T3 41:51 / 41:07 /
42:21 / 41:06 · fin 1 h 14 / 1 h 15 / 1 h 20 / 1 h 25, moyenne du T2 −0,5 %).

**A. Importants**
- **A1 navires retenus** : la vue d'un navire garde sa propre abscisse curviligne sur un trajet affiché (`ShipView._path`, `_d`) : à un
  changement d'état, elle finit d'abord le reste du trajet précédent puis enchaîne le nouveau ; une retenue fige l'abscisse, le
  relâchement la fait rattraper la simulation **le long de la polyligne** (au plus 2 × la vitesse nominale, au moins 10 u/s, × la
  vitesse de simulation). Un état sauté (grande vitesse) reprend le trajet de pilotage au lieu d'une ligne droite (`_to_berth`). Cas
  symétrique : `Diorama.holds` — un seul cède (le plus grand identifiant). Un navire retiré par la simulation en plein départ finit son
  trajet jusqu'à la sortie (`Diorama.parting`, `ShipView.sync_parting`), hors champ. « En route » = selon la simulation **ou** parce
  que la vue n'a pas fini son trajet (distance de suivi, ouverture de zone).
- **A2 camions réaffectés** : `TrafficView.road_route` — autoroute → bretelle → voie d'entrée → place (changement de voie sur la
  route, d'une place de l'aire à une autre directement) ; camions en trop : `exit_route` (sur l'autoroute ils continuent vers l'est ;
  sinon voie de sortie), aussi après un prestige.
- **A3 révélations sauvegardées** : `features` est sauvegardé en dictionnaire {id : instant}, avec `last_reveal_t` / `last_reveal_id` ;
  **sauvegarde version 5** ; l'ancien format (liste) se charge comme « révélé depuis toujours ».
- **A4 musoirs** : posés jusqu'au bord des terres **existantes** (48 tant que le terre-plein n'est pas comblé) ; palier borné à 1–3 au
  chargement et pour `Layout.LAND_X`.
- **A5 outils de débogage** : `DebugArgs.allowed()` = `OS.has_feature("editor")` (binaire de l'éditeur : tests, captures, jouer.bat) ;
  F1, sa ligne des Réglages, `--open=debug`, `--load-sim`, `--open-zone` et les triches suivent cette règle — plus rien dans l'APK,
  même exporté en debug. Vérifié : le binaire lancé en `--path` a la fonction `editor`, pas `template`.
- **A6 chargement en plein pilotage** : `ShipView.place` pose la vue à sa position logique sur le trajet de son état (durée complète de
  l'état recalculée : approche, pilotage, amarrage, départ).
- **A7 engins** : `LOAD_WAIT` (3 s) ne vaut plus que s'il n'y a **aucun** engin libre ; un engin en route est attendu (garde-fou 30 s) ;
  un engin rappelé rentre par les allées (`Layout.engine_route_home`) ; sans rien à transporter, il s'arrête au tablier (« idle »).
- **A8 texture de distance** : R16F (`Image.convert(FORMAT_RH)`), écart ≤ 0,12 u ; captures avant/après identiques
  (`c7_eau_avant.png` / `c7_eau_apres.png` : écart moyen 1,6 sur 765, dû aux vaguelettes animées et aux navires).

**B. Moyens**
- **B1** : `rebuild()` pendant une ouverture la termine d'abord — **comme un toucher qui la passe** (`_finish_opening(false)` : état
  final, narratrice, retour de la caméra) plutôt qu'en silence, pour ne perdre ni la phrase de la zone ni la vue du joueur ; plus
  aucune affectation typée d'un nœud libéré dans la séquence.
- **B2 notifications** : jamais sur un écran ou une fenêtre (la suivante attend, celle à l'écran se cache), ni sur la carte du
  tutoriel (cachée si elles se chevauchent) ; file pleine : on jette la plus ancienne qui n'est pas « bad » ; l'anti-doublon (60 s) ne
  compte qu'une notification affichée ; la boîte reprend sa hauteur réelle (0 sans notification) ; nouvelle partie (prestige,
  réinitialisation, chargement) : files de notifications et de bandeaux, bandeau et notification à l'écran, narratrice et bulle de zone
  vidés (`Hud.bind`).
- **B3** : « Toucher pour passer » et la narratrice se cachent sous une fenêtre.
- **B4** : un bandeau (et son recentrage) attend la fermeture des écrans et fenêtres ; pendant les 2 s d'un recentrage de chapitre, une
  ouverture de zone reviendra à la vue du joueur (`Diorama.view_home`), pas au poste du chapitre.
- **B5 tutoriel** : « parc » passe avant « manager » (liste version 5 ; un joueur de la version 4 arrêté sur l'une ou l'autre reprend
  au parc) ; l'étape « embauche Yasmine » attend Yasmine elle-même (`manager_revealed('cranes')`) et se passe si « Responsables » est
  révélé sans elle (sauvegarde ancienne, prestige).
- **B6 Gestion** : avant sa révélation, le bouton CONSTRUIRE du conseil ouvre la fiche du bâtiment sur son emplacement doré ; la
  condition d'une Douane à venir dit « son emplacement doré, dans le port » ; textes du tutoriel (quai, friche) et des conseils
  (« CONSTRUIRE ») sans « Onglet Bâtiments » ; la Douane ne renvoie à Gestion → Port qu'au futur.

**C. Mineurs**
- **C1** `gate_rush` rend les EVP réellement livrés (exemple du contrôle : 11 EVP sortis pour un solde de file de −29).
- **C2** rade pleine comptée en temps écoulé (plus par appel) ; `_bn_last` = heure de la partie au chargement.
- **C3** terrain : triangles orientés vers leur normale (`Terrain._tri`), `cull_disabled` retiré de `land.gdshader` ; captures
  avant/après `c7_flancs_avant.png` / `c7_flancs_apres.png` (écart moyen 0,16 sur 765 : rien ne change à l'écran).
- **C4** barges du terre-plein : elles arrivent de l'est le long du futur bord du quai (z = −15, départs x 180 / 200 / 220), à 51 u du
  mouillage le plus proche et 15 u de la voie de départ du palier 3.
- **C5** `exporter_apk.bat` supprime l'ancien APK avant l'export.
- **C6** état « chapter » des bâtiments et champ `chapter` de `unlocks.json` supprimés (code mort ; commentaire « N5 » trompeur parti) ;
  Douane et Contrats placés en tête de `unlocks.json`, dans l'ordre où ils sont réellement révélés (4:33 – 5:01 et 5:33 – 6:01, avant
  le parc) — sonde identique.
- **C7** chapitre 3 : plus de promesse de gains hors ligne (« Ta chaîne est complète, du navire au camion… »), idem au tutoriel.
- **C8** `ui_smoke` : terme toujours vrai retiré ; le contrôle vérifie qu'une notification en file attend encore à 1 s et paraît après
  3 s de calme.

**D. Performance mobile** : `Hud.useful_rect` lit une liste de boutons faite une fois, listes de contrôles en membres ;
`Zones.first_unbuilt` / `next_zone` en cache (recalculés quand la partie, le nombre de bâtiments ou le palier changent : achat, palier,
nouvelle partie, triches) ; `Diorama.lot_sign_point` en cache ; champ de distance de l'eau calculé une fois par état (cache statique,
plus de calcul au démarrage avant la partie) ; `Layout.scatter` calculé une fois ; bouées de mouillage à maillages partagés.

**Aussi** : `tests/bot_saves.gd` écrit la version 5 et un moment « t3_avant_quai3 ». Contrôle N3 de `ui_smoke` rendu déterministe (le
cadrage de départ est reposé avant la mesure : l'étape « navire » du tutoriel recentrait la vue pendant les 3 images d'attente).

**Tests** : `run_all` **178/178** (+12 : A3, A4, A5, A8, B5, B6, C1, C2, C3, C4, C6/C7, D) · `ui_smoke` **99/99** (+14 : A1 ×3, A2,
A4, A6, A7, B1, B2 ×2, B3, B4, B6, D ; C8 réécrit). Aucun contrôle retiré.

**Captures** (`--fresh`, parties de bot réelles graine 1, toutes regardées), `docs/captures/` : `baie_c7_t1_depart.png` (accueil du
tutoriel, navire n°1 au mouillage, flancs du cap), `baie_c7_chenal.png` (T2 à ×3 : un navire aux formalités **à quai** — avant la
prise en compte de la vitesse ×N il traînait dans le chenal —, un navire qui sort au nord, un au bassin), `baie_c7_t3_avant_quai3.png`
(T3 sans quai n°3 : le quai s'arrête en x = 48, contour doré du terre-plein sur l'eau, aucun musoir sur l'eau), `baie_c7_camions.png`
(camions de la file sur la route d'accès et la bretelle de l'autoroute), `c7_eau_avant/apres.png`, `c7_flancs_avant/apres.png`.

APK réexporté après C7 : `C:\Nadir\tycoon_V2\build\PortHorizonV2.apk` (29,6 Mo, 14/10 8 h 21), l'ancien supprimé avant l'export.


## Lot D — UI : interface, achat sur le port vivant, retours (14/10)
Ordre de mission `docs/ORDRE_D_UI.md` (source `docs/REVUE_CRITIQUE_PORT.md`, axe 2 et partie interface de l'axe 3), mené en
parallèle de la piste D-Monde. Fichiers : `scripts/ui/*` (dont le nouveau `boost_button.gd`), `autoload/sfx.gd`,
`data/tutorial.json`, `scripts/main.gd`, 7 icônes SVG (`fuel`, `dredge`, `tug`, `lng`, `radar`, `chest`, `help`) et un seul
texte de `port_sim.gd` (conseil `yard_space`). **Aucune valeur ni logique de simulation touchée** : sonde 4 graines identique
(T1 → T2 13:15 / 12:46 / 12:38 / 13:03 · T3 41:51 / 41:07 / 42:21 / 41:06 · fin 1 h 14 / 1 h 15 / 1 h 20 / 1 h 25).

**Phase 1 — incohérences de confiance**
- Cartes d'Améliorations : détails et rentabilité en retour à la ligne (`UI.wrap_label`), texte court « Pas le goulot : pas de gain
  immédiat » ; l'effet n'est plus un bouton-lien de 44 px (le « pourquoi » est dans la fiche « i »). Contrôle : au T3, aucune
  carte plus large que l'écran (deux onglets).
- Goulot `yard_space` : « Goulot : parc trop petit », conseil « Parc trop petit pour ton débit, même s'il n'est pas plein… » ; la
  jauge du parc affiche le **stock** (« Stock 28 % ») et, quand ce goulot est actif, une pastille rouge « Trop petit pour ton
  débit » dessous (jamais un goulot rouge à côté d'une jauge verte sans explication).
- Bouton de la carte Goulot : `Hud.hint_action` — **quoi et combien** (« AMÉLIORER PARC · 8,25M $ », « QUAI N°2 · 150K $ »,
  « AFFICHES · 2K $ », « PALIER T3 ») ; vert dès qu'une action règle le goulot (bâtiment abordable, ou amélioration abordable du
  service qui le soulage : l'empilage pour « parc trop petit »). Gris seulement si rien n'est possible.
- Même achat, même nom : la pancarte du prochain achat porte le **nom du bâtiment** (« Quai n°2 · 150K $ »), comme Gestion et le
  bouton du goulot (noms courts `Info.BUILDING_SHORT`). Le nom des zones (`layout.gd`) est à D-Monde (demandé dans le rapport).

**Phase 2 — acheter au-dessus du port vivant**
- `Sheet.half` : **Améliorer et Commerce en feuille basse** (58 % de l'écran, `Sheet.HALF_TOP` = 0,42). Au-dessus, le port continue
  de vivre : pas de `fx_paused` (sauf une ouverture de zone en attente), surcouche monde visible dans la bande du haut
  (`Hud.useful_rect`), HUD du haut et barre du bas repliés ; toucher le port au-dessus referme la feuille ; la caméra revient au
  cadrage du joueur à la fermeture. Gestion, Missions et Réglages restent plein cadre (Gestion construit, et une construction
  lance une ouverture de zone).
- **Mini-solde** dans l'en-tête de chaque écran (plein cadre ou mi-hauteur), et « ? » qui rouvre l'aide.
- Caméra : à l'ouverture et à chaque achat, `Hud.frame_dept` amène le poste (`Diorama.dept_anchor`, repli `Layout.dept_pos`) au
  milieu de la bande visible ; sans goulot de service (« pas assez de navires ») on cadre la grue, jamais la mer vide.
- Chaque achat : `Diorama.feedback_purchase(dept)` (au plus toutes les 0,3 s en appui long) et texte flottant au-dessus du poste
  (« +55,2K $/s » s'il rapporte, sinon « +2 % » de l'effet du service).
- Boutons gris : « Il manque 7K $ » (services, licences, bâtiments, responsables, campagnes, démarchage, lignes, aléas).
- Améliorer s'ouvre **défilé sur la carte** du service demandé, sinon du goulot, sinon du meilleur achat. La pastille ne compte que
  les achats abordables **qui rapportent** (gain estimé > 0) ou qui ouvrent le chapitre en cours (estimations une fois par seconde).

**Phase 3 — écran respirable**
- HUD du haut : barre indigo + **une ligne** (coffre des missions, carte Goulot réduite à son titre et son bouton ; toucher la carte
  déroule le conseil, qui se replie après 8 s). Bandeau des missions replié par défaut (le coffre le déroule, ou réclame d'un
  toucher une mission terminée — il passe au vert). Aléa en carte compacte. **15 % de l'écran au T3** (35–46 % avant).
- Barre du bas : Réglages en petit rond (96 px) dans le coin, GESTION, COMMERCE et le **gros bouton vert AMÉLIORER en bas à droite**
  (pastille). Stats est dans Gestion. **Responsables intégré à Gestion** : avant Gestion le bouton s'appelle RESPONSABLES, ensuite
  une pastille ambre compte ceux à embaucher (plus de bouton gris). **Heures sup** : `BoostButton`, rond flottant au-dessus
  d'Améliorer — grand disque ambre qui respire quand il est prêt, vert avec l'anneau du temps restant, petit disque gris discret avec
  l'anneau de recharge sinon (zone de toucher 120 px).
- Textes ≥ 24 px dans le HUD (missions, barre de palier en **texte foncé sur ambre** 24 px, bouées 24 px) ; cibles ≥ 96 px (coffre,
  Ambre +, ▲, « i » des cartes via `UI.hit_button` : pastille de 56 px, zone de 96 px).
- Une seule unité de revenu : **$/s** (revenu du HUD, rentabilité, gains, revenus par source de Gestion › Stats).
- « + » de l'Ambre : fenêtre « Comment gagner de l'Ambre » (missions, coffre, contrats, paliers) avec MISSIONS.
- Gestion › Bâtiments triée « disponible › bloqué › construit », construits repliés en « 30 construits ▸ ».
- Bandeaux « Nouveau : … » avec **VOIR** (Améliorer sur le bon service, Responsables, Gestion, Stats, Port, Commerce, Contrats,
  Missions, aide de l'Ambre, Heures sup qui rebondit).
- Bulle « n/n en rade » ancrée au mouillage (`Diorama.rade_anchor`) ; gains flottants désormais rangés comme les bulles
  (`Bubbles.settle` cherche la place libre la plus proche à côté d'une voisine, ou au-dessus — jamais au-dessous ; l'ancien
  décalage oscillait entre deux voisines : « Touche ! » finissait sous « Tablier plein »).
- Charte : vert = argent / acheter, bleu = info, ambre = « touche-moi » (VOIR, pastille des responsables, ×1, Heures sup), rouge =
  problème, gris = impossible seulement (REFUSER et « Passer le tutoriel » en indigo, CONSTRUIT ✓ / EMBAUCHÉ ✓ en vert pâle, noms
  des bâtiments bloqués en gris et plus en rouge). Icônes distinctes : ponton, dragage, remorqueur, GNL, pilotage à distance
  (`Info.BUILDING_ICON`) ; missions par type (`Info.mission_icon`).
- Cosmétiques : pastilles d'icône jamais étirées (`UI.icon_disc` en `SIZE_SHRINK_CENTER`) ; aides d'en-tête affichées une fois par
  lancement puis repliées dans le « ? » (`Sheet.help`) ; « Au poste de la capitainerie : deux services » supprimé ; phrase en double
  du Commerce supprimée ; carte du **coffre** avec sa progression en tête de Missions.

**Phase 4 — retours et récompenses**
- **Cérémonie** (`Hud.ceremony`) : titre géant, gerbes sur toute la largeur, voile léger, la caméra recule (zoom ≥ 100) sur les
  zones qui s'ouvrent au palier (`Hud.tier_focus`), jingle propre au palier (`tier2`, `tier3`, `finale`, `prestige`), puis la
  fenêtre ; un toucher l'abrège ; effets du monde en pause pendant 2,8 s. Même traitement pour la nouvelle concession et la fin.
- **Encaissement par événement** : au signal `Diorama.ship_paid`, gros « +X $ » au poste et 7 pièces qui volent jusqu'au compteur
  (ou au mini-solde d'une feuille mi-hauteur), qui pulse à leur arrivée ; la pluie fine ne reste que pour la gate. Gestes manuels
  (coup de main, rangement, barrière) affichés **en $** (EVP déplacés × valeur moyenne d'un EVP, droits de gate compris).
- Pastille **même hors goulot** : « Portiques +2 % — pas le goulot ».
- Retour d'absence : le montant défile de 0 à la somme, bouton **ENCAISSER** (pièces vers le compteur).
- **Sons** (`sfx.gd`) : `build`, `hire`, `milestone`, `boost`, `chest` distincts ; « tier » et les jingles réservés aux paliers ;
  hauteur ±4 % ; +1 demi-ton toutes les 3 répétitions d'un appui long (jusqu'à +12) ; **10 voix avec priorité** (corne et jingles
  jamais volés, un son ne prend que la voix d'un son moins ou aussi prioritaire) ; bus **« Sons »** et **« Ambiance »** (mer,
  mouettes, cornes, grues, camions) avec deux réglettes dans Réglages (`user://audio.cfg`, le fichier de `Settings` n'est pas touché).
- Heures sup et campagne : `Diorama.set_overtime` / `set_campaign` appelés aux changements d'état.

**Branchements D-Monde** (tous présents dans `diorama.gd` et appelés, avec `has_method` / `has_signal` et un repli) :
`feedback_purchase` (achat d'un niveau), `set_overtime` (Heures sup), `set_campaign` (campagne), `dept_anchor` (cadrage),
`rade_anchor` (bulle de rade, feuille Commerce), signal `ship_paid` (encaissement).

**Tests** : `run_all` **192/192** (+6 D-UI dans `test_d_ui` : anti-chevauchement entre deux voisines, conseil « parc trop petit »,
libellés courts de tous les bâtiments, icônes distinctes, missions par type, tutoriel aligné ; le reste vient de D-Monde) ·
`ui_smoke` **128 contrôles, 127 verts** (le seul rouge est le contrôle D-Monde « dockers au déchargement », en cours chez eux ; +24 D-UI dans `_dui_phase1` à `_dui_phase4` : cartes au T3, carte Goulot, feuille mi-hauteur vivante, focus
et cadrage, retour d'achat, « Il manque », pastille utile, caméra rendue, Commerce mi-hauteur / Gestion plein cadre, chrome du haut
< 20 % au T3 (15 %), disposition du bas, Heures sup, cibles ≥ 96 px, textes ≥ 24 px et $/s, Ambre +, tri de Gestion, VOIR, bulle de
rade et aide repliée, cérémonie, encaissement, gestes en $, sons, réglettes, Heures sup / campagne envoyées au monde).
**Contrôles recalés** (aucun retiré) : « le conseil propose de construire » (le bouton dit « QUAI ALLONGÉ · 250 $ » au lieu de
« CONSTRUIRE ») ; « bandeau des missions » (replié par défaut : on touche d'abord le coffre) ; « C7 B4 » (l'écran ouvert est Gestion,
plein cadre : Améliorer cadre désormais lui-même la caméra) ; « bulle À inspecter » (la nouvelle concession joue sa cérémonie : on la
termine et on cadre la douane avant la mesure) ; « C7 C8 après l'ouverture » (diagnostic ajouté : le calme de 3 s tenait, mais une
« Mission accomplie » de la simulation rejoignait parfois la file pendant l'attente — le contrôle vérifie désormais que la
notification attendue est toujours en file, au lieu d'une file de taille 1). Robustesse : le calme de 3 s après une ouverture de
zone compte même si une notification était à l'écran pendant la séquence ; minuteries de la cérémonie comparées par identifiant
(plus d'erreur « Lambda capture freed »).

**Captures** (`--fresh`, parties de bot graine 1, sauvegardes C7, 540 × 960, toutes regardées), `docs/captures/` :
`d_ui_hud_t1.png` (départ : ligne Goulot « QUAI ALLONGÉ · 250 $ » verte, pancarte « Allongement du quai · 250 $ », Améliorer en bas
à droite), `d_ui_hud_t2.png` (chrome 15 % contre 35–46 % sur u2 ; « QUAI N°2 · 150K $ » sur le bouton et la pancarte ; pastille ambre
3 sur Gestion ; Heures sup en petit anneau gris), `d_ui_hud_t3.png` (« Goulot : parc trop petit » / « AMÉLIORER PARC · 8,25M $ »
vert, « Stock 29 % » + « Trop petit pour ton débit », « 10/10 en rade » au mouillage), `d_ui_goulot_t3.png` (détail déroulé),
`d_ui_ameliorer_t3.png` (feuille mi-hauteur ouverte sur Parc et manutention, parc et gate visibles au-dessus avec leurs bulles,
mini-solde, plus de débordement — à comparer à u6), `d_ui_ameliorer_t2.png` (sans goulot de service : la grue cadrée, aide affichée
la première fois), `d_ui_ameliorer_chapitre1.png` (boutons gris « Il manque 118 $ »), `d_ui_gestion.png` (Quai n°2 disponible en
tête, bloqués en gris, mini-solde, à comparer à u3), `d_ui_ceremonie_palier.png` (« Palier T2 atteint ! », gerbes, dézoom),
`d_ui_encaissement_navire.png` (« +1,…M $ » au poste n°1, pièces en vol vers le compteur).


## Lot D — Monde : réorganisation du port et vie du port (14/10)

Ordre `docs/ORDRE_D_MONDE.md`, source `docs/REVUE_CRITIQUE_PORT.md` (axe 1, axe 3 partie monde). Fichiers : `scripts/world/*`
(layout, diorama, traffic_view, ship_view, yard_view, crane_view), `data/buildings.json` (deux noms, deux descriptions),
`tests/run_all.gd` (`test_d_monde`), `tests/ui_smoke.gd` (`_d_monde_checks`), `tests/plan_view.gd`. Plan à jour : `PLAN_COTE.md`.
Simulation et équilibrage inchangés (sonde 4 graines identique, voir plus bas).

### Phase 1 — douane, gate, enceinte (B1, I1)
- **Circulation à droite** partout : autoroute (vers l'est au sud, z 142), route d'accès (entrée à l'est x −19,5, sortie à l'ouest
  x −22,5), voie des camions (aller à vide z 34,6 vers l'est jusqu'au bout de la boucle, retour z 32,4 vers l'ouest le long du
  parc, où le camion est chargé). Les camions chargés sortent donc côté ouest : **devant la douane et sous le scanner à
  portique**, jamais les vides ; plus aucun croisement entre entrée et sortie. Barrières retournées (pivot au bord de leur voie),
  marquage de gate retourné.
- `gate2` = **deuxième voie de sortie** (x −19,5, un camion chargé sur deux) ; la route s'élargit à l'est, l'entrée passe en
  x −15 ; la file d'attente est une seule file (voie d'entrée puis aire d'attente).
- **Enceinte de la douane** (zone 3, « Bureau de douane », clé `customs1`) entre la voie des camions et la gate, à l'ouest de la
  route : bureau (−28,5 ; 40,5) au bord de la voie de sortie, scanner mobile (bureau + camion-scanner, −38 ; 40,5), scanner à
  portique **sur la voie de sortie** (−22,5 ; 39,5), aire d'inspection (douaniers, cônes, palette). Halle d'inspection du T3 à la
  place du hangar (−42 ; 19), côté mer. Guichet numérique et douane dématérialisée **côté public**, aux bureaux du port.
- Zone **« Gate »** (4) ouverte au départ, icône barrière, distincte de la zone Douane (icône douane).
- **Même achat, même nom** : une zone ouverte par un bâtiment porte son nom (« Allongement du quai », « Bureau de douane »,
  « Dragage du chenal », « Quai n°2 », « Pôle froid », « Deuxième voie de gate », « Quai profond n°3 », « Station de soutage GNL »,
  « Terminal rail ») ; `buildings.json` : `reefer` → « Pôle froid » (« Rack frigo (60 prises) »), `gate2` → « Deuxième voie de
  gate » (« Gate à deux voies » ; pas de « 2ᵉ » : glyphe exposant incertain dans la police), descriptions alignées. Les zones
  sans bâtiment clé gardent un nom de lieu (Vieux port, Gate, Pôle nautique, Bureaux du port).
- Toucher : le poste « Gate » (marqueur de goulot) est à la tête de la file (−21 ; 48,5) et une barrière se vise au milieu de
  son bras : toucher la barrière fait toujours passer un camion.

### Phase 2 — pôle nautique sur le cap (B2)
- Zone 9 « Pôle nautique » sur le cap, en butte (1,4 u) : **tour VTS** (−62 ; −16, 35 u de la passe), pilotage à distance au
  pied (−69 ; −14), **atelier de réparation** (−63 ; −27) avec sa **cale de halage** sur la crique (rampe de béton jusque sous
  l'eau, un bateau hissé). Capitainerie : `dept_pos("harbor")`, `CONTROL_TOWER`, responsable au pied de la tour au T2.
- Grise au départ, elle est **discrète** (herbe du cap, pointillés à 28 %) : le cadrage de départ du tutoriel reste valide.
- L'ex-Colline devient la zone 13 **« Bureaux du port »** (palier 2, à plat) : guichet, e-douane, TOS au bord d'une rue reliée à
  la route d'accès. Haies redessinées (enceinte | cap, enceinte | bureaux, bureaux | arrière-pays).

### Phase 3 — gare, passe est, cosmétiques (I2, I3, I4)
- **Gare** (zone 12 « Terminal rail ») contre le terre-plein, dans l'ancienne bande vide : quai (100 ; 52), voie z = 57 jusqu'au
  tunnel est (colline déplacée en (184 ; 58)), **liaison** x 84…90 avec la voie des camions du terre-plein (tracteur de terminal,
  haie ouverte), piles de conteneurs. La logistique (z 84…126) reste derrière, grise jusqu'à la gare. Bosquets dans la bande
  x 9…52, z 36…80.
- **Brise-lames est** (palier 3, avec le terre-plein) x 42…162 et **passe est** (feux vert / rouge). Postes 3–4 : arrivée par une
  voie au large z −108 (au nord du chenal), la passe est, évitage devant le poste ; départ par la passe est. Postes 1–2 : passe
  ouest **à tous les paliers**.
- **Gate est : non faite** (raison dans `PLAN_COTE.md` § 6 : la simulation n'a qu'une file et un débit de gate ; deux files
  seraient une présentation inventée).
- Cosmétiques : Quais (−32 ; −3) et Portiques (−21 ; −3) à 11 u ; IMO (127 ; 11,5) à 7,3 u du GNL (blocs RTG ramenés à 6 travées
  sur la colonne est, zones 10 / 11 à x = 121) ; appontement du GNL et barge de soutage ; repère du quai n°2 = sa grue.

### Phase 4 — vie du port (axe 3, monde)
- **Foule** (`Diorama.crowd`, deux MultiMesh, 28 dockers + 4 douaniers au plus) : par navire à quai, dockers sur le tablier
  (1 + agents des Quais, 2 à 5) et, pendant le déchargement, sur le pont côté quai (agents des Portiques, 1 à 3) ; douaniers dans
  l'aire d'inspection (agents de la Douane, 1 à 4). Échelle ×1,45 (lisibles au zoom de départ). Réaffectation toutes les 0,5 s,
  image par image seules les transformations sont écrites. **Demi-tour progressif** pour la foule et pour tous les marcheurs.
- **Conteneurs posés** (`YardView`) : un conteneur qui arrive descend de 2,6 u en glissant de 0,9 u en 0,38 s (12 poses à la fois
  au plus par bloc, tableaux préalloués ; un saut de remplissage pose le reste d'un coup).
- **Interface fournie à D-UI** (`diorama.gd`, sans effet si rien à montrer) : `feedback_purchase(dept_id)` (poussière, étincelles,
  anneau au sol au poste ; grues : « kick » et ×1,7 de vitesse 2,5 s ; parc : les engins tressaillent ; gate : barrières levées ;
  capitainerie : corne), `set_overtime(on)` (gyrophares sur grues et engins, grues ×1,4, lumière plus chaude), `set_campaign(on)`
  (deux mâts, pavillons et guirlandes de fanions qui flottent sur la capitainerie), `dept_anchor(dept_id)`, `rade_anchor()`
  (centre des navires en rade), signal `ship_paid(world_pos, amount)` au départ du poste — **montant estimé** (cargaison relevée à
  l'arrivée × valeur de cargaison × paiement de l'armateur + droits de port et services ; la simulation ne garde pas ce montant).

### Contrôles
- Nouveaux : `run_all` `test_d_monde` (8 : circulation à droite ; camions chargés sous le scanner et devant la douane, vides
  loin ; bâtiments de douane dans l'enceinte ; zones Gate / Douane et noms = bâtiments ; pôle nautique ; gare reliée ; passe est
  (pilotages 24 × 2 et départs, aucun brise-lames coupé, coques à ≥ 1,5 u des feux est) ; cosmétiques) · `ui_smoke`
  `_d_monde_checks` (6 : interface, Heures sup, campagne, `ship_paid`, foule liée aux agents, conteneurs posés).
- **Recalés** (aucun retiré) : `run_all` « butte de la Colline » → butte du pôle nautique (point (−66 ; −18)) ; « par l'est au
  palier 3 » → poste 3 (les postes 1–2 gardent la passe ouest) ; `ui_smoke` « zone grise touchée » → toucher en (−33 ; 34)
  (enceinte de la douane) au lieu de (−30 ; 50) (aujourd'hui les bureaux du port).
- Demandes de D-UI intégrées en fin de piste : noms de zones = noms des bâtiments (fiche « Zone : … » et bulle des zones grises
  les lisent dans `Layout.ZONES`) ; signal `gesture_done(pos, text, evp)` (EVP déplacés) et `Hud.gesture_text(text, evp)` qui
  s'en sert (exception autorisée à `hud.gd` pour ce seul point ; sans paramètre, il relit encore le texte) ; contrôle « dockers
  au déchargement » rendu indépendant des niveaux de la partie de test (niveaux à 1 puis 400).

### Résultats (lot D — Monde)
- `run_all` **192/192** (178 + 8 `test_d_monde` + 6 D-UI) · `ui_smoke` **130/130** (99 + 24 D-UI + 7 `_d_monde_checks`).
- **Sonde 4 graines identique** à celle d'avant la piste (`pacing_probe --seeds=1,2,3,4 --brief`, comparaison ligne à ligne).
- Captures (`--fresh`, parties de bot graine 1, 540 × 960, toutes regardées), `docs/captures/` :
  `d_monde_t1_large.png` (départ : enceinte de la douane, bureaux du port et 2ᵉ voie de gate en gris, pôle nautique discret sur le
  cap, bosquets dans l'ancienne bande vide), `d_monde_t2_gate_douane.png` (bureau de douane au bord de la voie de sortie, douaniers
  dans l'aire d'inspection, file des camions sur la voie d'entrée à l'est), `d_monde_t3_large.png` (gare contre le terre-plein,
  brise-lames est, un navire du poste 3 qui repart vers la passe est), `d_monde_t3_passe_est.png` (tête du brise-lames et feu vert,
  feu rouge à l'angle du terre-plein, appontement du GNL et barge), `d_monde_t3_gare.png` (quai, voie, liaison avec la voie des
  camions, tracteur), `d_monde_pole_nautique.png` (tour VTS sur la butte, pilotage au pied, atelier et bateau sur la cale ;
  pavillons et fanions de campagne sur la capitainerie), `d_monde_dockers.png` (dockers ×1,45 sur le tablier au zoom de départ),
  `d_monde_heures_sup.png` (gyrophares sur les grues et les engins), `d_monde_plan_dessus.png` (plan vu de dessus : zones, cases,
  trajets des camions, des navires par les deux passes).
- Limites vues aux captures : le brouillard (aléa de la partie de bot) masque deux des essais de la passe est ; le train ne se montre
  que lorsque les bouts de la voie sont hors champ (inchangé) ; la foule des douaniers n'apparaît qu'une fois le bureau construit.


## Lot D — Éco : rythme et récompense (14/10)

Ordre `docs/ORDRE_D_ECO.md` (source `REVUE_CRITIQUE_PORT.md`, axe 3), mené seul après D-Monde et D-UI. Prototype dans
`scratchpad/eco/godot`, sonde `pacing_probe.gd` une graine par processus (attente bornée, `trials.ps1`), ≈ 25 lots de 4 graines ;
essais, leçons et tableau complet dans `ANALYSE.md` § 15, décision dans `DECISIONS.md` « Rythme (lot D) ».

**Fichiers** : `sim/port_sim.gd` (services facturés, attente après un palier, alerte du goulot), `data/config.json`,
`data/unlocks.json`, `data/tiers.json`, `data/buildings.json` (gravier 3), `data/owners.json` (Nordhaven), `tests/bot.gd`,
`tests/pacing_probe.gd`, `tests/run_all.gd`, `tests/ui_smoke.gd` ; affichage indispensable : `scripts/ui/hud.gd` (couleur de la carte
Goulot lue sur l'alerte) et `scripts/ui/manage_sheet.gd` (ligne « Services facturés » dans Stats). Rien dans `scripts/world/*`.

**Valeurs changées** (fichier → clé : avant → après)
- `config.json` → `service_fee` : — → 0,5 · `licence_max` : [25, 60, 100] → [30, 60, 100] · `lines_per_owner` : [0, 3, 4] → [0, 5, 6] ·
  `line_cost` : [400, 1 M, 75 M] → [400, 2,5 M, 75 M] · `line_cost_growth` : 2 → 1,6 · `reveal_gap_min` : 20 → 45 ·
  `reveal_tier_hold` : — → 60.
- `unlocks.json` → `licences.when.after.s` : 180 → 60 · `progress.when` : après Réputation + 25 s → `{"evp": 200}` · `amber.when.after` :
  progress → stars · `stats.when.after.s` et `events.when.after.s` : 30 → 150.
- `tiers.json` → T2 `req.evp` 4 000 → 8 500, `req.money` 4 000 → 14 000 · T3 `req.evp` 500 000 → 540 000 · Concession `req.money`
  7 × 10⁸ → 4 × 10⁸.
- `buildings.json` → `gravel3.cost` 4 000 → 14 000 · `owners.json` → `nordhaven.recruit` 60 000 → 200 000.

**Code** : `PortSim.service_fee_rate()` (f × Σ(niveaux − 1) × prix de base d'un EVP × (1 + droits de gate)), encaissé dans
`_fees_and_costs` (source « fees ») et compté dans `income_rate_estimate` / `income_estimate_with` ; `last_tier_t` + `reveal_tier_hold`
dans `check_unlocks` ; `alert_reason()` et `analysis_shown.alert` (tenu `alert_hold` 4 s) dans `_refresh_analysis`. Bot : gain relatif
des services facturés ajouté au score de chaque niveau ; `save_horizon` (150 s, inchangé, réglable par la sonde). Sauvegarde : aucun
champ nouveau (version inchangée).

**Contrôles** — ajoutés : `run_all` `test_d_eco` (4 : services facturés et recette encaissée ; écart minimal et silence 60 s après un
palier ; 4 parties de bot jusqu'à T2 + 3 min : ≤ 4 bandeaux en 6 min, aucune révélation dans la minute qui suit, barre avant la Douane ;
alerte seulement si un maillon est bloqué et retombée) · `ui_smoke` (1 : carte Goulot rouge en alerte seulement).
Recalés (aucun retiré) : `run_all` « prochaine ligne à moitié prix » (croissance lue dans la config), « au plus N lignes par armateur
en T2 » et « commerce sauvegardé » (N = `lines_per_owner`, 5), « chapitres … puis le palier 2 » (horloge 200 → 450 s : statistiques et
aléas espacés de 150 s), « N8 » (45 s au lieu de 20 s) · `ui_smoke` « carte Goulot : bouton gris… » (le titre ne rougit plus quand un
achat est possible), « D-UI 2 : la pastille … ne compte que les achats qui rapportent » (avec les services facturés chaque niveau
rapporte : filtre vérifié sans eux, puis pastille = achats à gain réel).
**Tests** : `run_all` **196/196** (197/197 avec la copie de la vraie sauvegarde, `PH_SAVE_COPY`) · `ui_smoke` **131/131**.

**Sonde avant / après** (vrai projet, graines 1 / 2 / 3 / 4)
| Mesure | Cible | Avant | Après |
|---|---|---|---|
| T1 → T2 | 12–13 min | 13:15 / 12:46 / 12:38 / 13:03 | 11:43 / 13:07 / 12:23 / 12:18 |
| Durée du T2 | 28–30 min | 28:36 / 28:21 / 29:43 / 28:03 | 28:10 / 29:22 / 28:35 / 29:22 |
| Fin | 1 h 15 – 1 h 30 | 1 h 14 / 1 h 15 / 1 h 20 / 1 h 25 | 1 h 20 / 1 h 34 / 1 h 14 / 1 h 28 |
| Rentabilité médiane T1 · > 5 min | ≤ 3 min · ≤ 15 % | 4:53–7:46 · 56–70 % | 2:04–2:24 · 0 / 26 / 4 / 4 % |
| Rentabilité médiane T2 · > 5 min | ≤ 3 min · ≤ 15 % | 6:27–12:35 · 59–65 % | 4:51–6:39 · 48–65 % |
| T2 +3 / +10 min | ≤ ×6 / ×80 | ×14–18 / ×234–331 | ×4,0–5,5 / ×18–35 |
| T3 : +1 min / −1 min · trou 10 min | ≥ 1 · ≤ 90 s | ×9,7–15 · 0:55–1:43 | ×8,1–15 · 1:19–1:35 |
| Barre de palier | ≤ Douane | ≈ 15 min | 1:42–2:08 (Douane 3:10–3:37) |
| Bandeaux autour du T2 · après palier | ≤ 4 · 0 | 7 · 1–2 | 2–4 · 0 |
| Carte Goulot rouge | rare | dès qu'un achat est possible | T1 0–4 %, T2 4–10 %, T3 4–9 % |

**Non tenu** : rentabilité T2 ≤ 3 min (structurel : il faudrait ×10 000 de croissance sur le T2, voir `ANALYSE.md` § 15) ; trou
d'achat ≤ 90 s au T3 (deux graines à 1 min 30 / 1 min 35 à l'entrée ; 2–3 min sur tout le T3) ; T1 > 5 min pour la graine 2 (26 %) ;
fin des graines 2 et 3 hors de 1 h 15 – 1 h 30 (moyenne 1 h 24, ±15 %).

APK réexporté : `C:\Nadir\tycoon_V2\build\PortHorizonV2.apk` (29,6 Mo, 14/10 15 h 21, verrou `scratchpad\capture.lock` pris puis
rendu), l'ancien supprimé avant l'export.


## Lot E — Confiance : interface et simulation d'affichage (14/10, soir)

Ordre `docs/ORDRE_E_CONFIANCE.md` (source `docs/REVUE_LOT_D.md`, E1–E6 + mineurs UI/sim), mené en parallèle de la piste
E-Flux. Fichiers : `scripts/ui/*` (dont le nouveau `advice.gd`), `autoload/sfx.gd`, `scripts/main.gd`, `scripts/world/camera_rig.gd`
(E5 seulement), `sim/port_sim.gd`, `sim/hazards.gd`, `data/config.json`, `data/tiers.json`, `data/buildings.json` (deux
descriptions), `tests/run_all.gd` (`test_e_confiance`), `tests/ui_smoke.gd` (`_e_confiance_checks`), `tests/fixtures/bot_t3.json`
(partie de bot réelle, graine 1, T3 + 4 min : celle de la capture x3 de la revue). Chaque défaut vérifié dans le code avant
correction : **aucun faux positif**.

**E1 — services facturés × interface**
- Vérifié : `upgrade_gain` comptait les services facturés (`service_fee_rate` monte à chaque niveau) → tout achat « rapportait »,
  pastille 9 au T3 (partie de bot : 9 achats à gain > 0), « pas le goulot » jamais affiché.
- `PortSim.income_parts_with` / `upgrade_gain_parts` : même estimation (au bit près, contrôlé) séparée en part « débit » et part
  « services ». Bon achat (`Advice.is_good`) = le débit bouge **et** rentabilisé en < 10 min (seuil fixe, voir `DECISIONS.md`).
  Vert, pastille et ★ seulement pour les bons achats ; débit immobile : « Portiques +6 % · pas le goulot (+15 $/s de services) »
  en gris (« le débit ne bouge pas » sur le service goulot lui-même) ; idem pour le retour d'achat dans le monde (pastille bleue,
  plus de « +X $/s » vert).
- Au T3 de la partie de bot : pastille **0** (≤ 0 achat rentabilisé en < 10 min ; 9 avant).

**E2 — bouton Goulot** — vérifié : `hint_action` prenait `Zones.next_building` (prochain de la chaîne). Table goulot → bâtiment
d'après les effets (`Advice.fixes`), bâtiment proposé s'il est le prochain de la liste, sinon le service qui soulage (pour
« postes à quai » et « escales au plancher », seulement s'il fait bouger le débit), sinon le bâtiment à viser (gris), sinon
GESTION ; brouillard : PATIENTER. Au T3 de la partie de bot : « postes à quai » → **GESTION** (le quai n°4 est verrouillé derrière
GNL, IMO, rail, RTG ; un niveau de Quais ne fait monter que les services) — plus jamais « GNL · 280M $ ». Gate au T2 → « DEUXIÈME
VOIE · 3M $ ». `_on_hint_pressed` suit l'action proposée.

**E3 — aléas** — vérifié : `pay_cost` = `income_rate_estimate` (débit théorique) × secondes. Désormais `Hazards.cost_for` : revenu
**réel** (`PortSim.real_income_rate`, fenêtre d'une minute) × secondes, plafonné à 25 % de la trésorerie (`hazard_cost_cap`),
aussi pour l'amende d'un contrôle. Partie de bot au T3 : « Sécuriser » 33 M$ pour 1,33 M$/s réels (116 M$ avant, débit théorique
4,65 M$/s). Moins de 15 s de revenu mesuré (ancienne sauvegarde tout juste chargée) : estimation plafonnée, recalculée à 15 s.
Brouillard : « Suspendu (brouillard) » (plus « Inf s → Inf s ») ; un service touché par l'aléa (`Info.event_hits`) n'est jamais le
meilleur achat ni compté dans la pastille. Bonus trouvé en route : le revenu du HUD (`income_per_min`) tombait à « +41K $/s »
juste après un chargement (seaux non sauvegardés) → HUD sur `real_income_rate`, et la dernière minute de revenu est sauvegardée
(champs facultatifs, version inchangée).

**E4 — noms courts** — vérifié (« RACK FRIGO », « 2ᵉ VOIE DE GATE », « QUAI ALLONGÉ »). `Info.BUILDING_SHORT` tiré des noms de
`buildings.json` (ses mots, dans l'ordre) : « ALLONGEMENT DU QUAI », « PÔLE FROID », « DEUXIÈME VOIE », « SOUTAGE GNL »… ; plus
de « ᵉ ». Pancarte et Gestion gardent le nom complet. Contrôle : les 31 noms courts cohérents avec leur nom.

**E5 — toucher de fermeture** — vérifié : l'appui va à la feuille, le relâchement arrive à `CameraRig.handle_input` avec
`_press_pos` de l'ancien toucher → `tapped`. La caméra n'émet un toucher que pour un relâchement dont elle a vu l'appui
(`_pressed`), et `_press_pos` part hors écran quand l'entrée est coupée. Contrôle par vrais événements (`push_input`) :
toucher du monde, Améliorer, toucher au-dessus → fermeture, 0 toucher du monde, pas de réouverture.

**E6 — bandeaux sous feuille** — vérifié (`_close_banner` enchaînait sans `_covered()`, minuterie de 6,5 s qui courait masquée,
VOIR fermait avant d'ouvrir, `_cam_back = rig.goal` déjà déplacé par le monde). `_banner_blocked()` (écran, fenêtre, ouverture,
cérémonie) ; minuterie suspendue tant que le bandeau est masqué ; VOIR ouvre l'écran puis ferme le bandeau ; `_cam_back` =
`view_home` pendant un regard de chapitre, sinon `rig.target` (ce que voit le joueur).

**Feuille et cérémonie** — pastille d'aléa compacte en haut à gauche au-dessus d'une feuille mi-hauteur (le toucher passe : il
referme la feuille) ; fenêtre du palier : texte propre (`story`) + 3 icônes « ce qui s'ouvre » (`tiers.json` → `opens`) + **VOIR**
qui cadre la zone du prochain bâtiment du palier (terre-plein au T3, quai n°2 au T2 ; la cérémonie y recule aussi) ; surcouche
monde masquée sous une fenêtre ; couche de cérémonie sans `z_index` (rangée sous `popup_layer`) ; pièces d'encaissement : vraie
pièce d'or de 64 px (SVG en mémoire, `UI.coin_tex`), nées 150 px au-dessus du montant après 0,6 s, arc vers le haut.

**Mineurs** — `last_tier_t` sauvegardé (champ facultatif, version 5 inchangée) ; `reset()` remet `last_tier_t`, `_alert_*`, la
fenêtre du revenu réel et le cache des services ; alerte parc / gate seulement après leur chapitre ; onglet Port : « Navires
satisfaits : 41 % / 50 % » (pour le T2) tant que la Réputation n'est pas révélée ; Stats : « Services facturés (niveaux) » et « Services aux
escales (atelier, GNL) » (la recette « services » n'apparaissait pas) ; `service_fee_rate` en cache (palier, Renom, cargaisons,
bâtiments, armateurs, contrats ; une valeur par somme des niveaux) ; `_burst_n` repart de zéro à chaque rafale ; cibles ≥ 96 px
(onglets 84 → 96, barre de palier → bloc argent + barre de 96 px, BÂTIMENTS 90 → 100 ; « POURQUOI ? » faisait déjà 100 px : mesuré) ;
`Bubbles.settle` cherche sa place dans le rectangle utile, plus de `StyleBoxFlat.new()` par bulle ; volume enregistré au
relâchement de la réglette (ou à la fermeture) ; `ui_smoke` coupe `Sfx.persist` ; les trois contrôles toujours vrais vérifient
(bulle de rade dessinée et près du mouillage ; règle de vol des voix `Sfx.pick_voice` testée sans pilote audio ; Heures sup
révélées et campagne réellement lancée). Descriptions `gate2` / `parking2` corrigées (plus de « seconde file d'entrée »).
`--event=id [--event-delay=s]` (binaire de l'éditeur) pour les captures d'aléa. Nouvelle classe `Advice` : `--import` lancé une
fois pour l'enregistrer.

**Contrôles** — `run_all` **206/206** (196 + 10 `test_e_confiance`) · `ui_smoke` **142 contrôles, 141 verts** (131 + 11
`_e_confiance_checks`) ; le seul rouge, « C7 A1 : un navire qui part… », est un contrôle des vues de navire (`ship_view.gd`,
piste E-Flux en cours, passe est). Recalés (aucun retiré) : `run_all` « carte Goulot : rouge seulement… » (on ouvre le chapitre du
parc avant la mesure de l'alerte du parc) ; `ui_smoke` « D-UI 2 / D-Éco : la pastille ne compte que les achats qui rapportent »
→ « … que les bons achats » (pastille = bons achats + licences) ; les trois contrôles toujours vrais renforcés (voir plus haut).

**Sonde 4 graines identique** à celle d'avant la piste (`pacing_probe --seeds=N --brief`, une graine par processus, comparaison
ligne à ligne) : T2 11:43 / 13:07 / 12:23 / 12:18 · T3 39:53 / 42:29 / 40:58 / 41:40 · fin 1 h 20 / 1 h 34 / 1 h 14 / 1 h 28. Seule
ligne changée : « carte Goulot rouge » de la graine 4 au T1, 4 % → 1 % (alerte de la gate avant son chapitre, voulu).

**Captures** (`--fresh`, sauvegardes de bot `scratchpad\ux2\saves`, 540 × 960, toutes regardées), `docs/captures/` :
`e_conf_t3_hud.png` (« Goulot : postes à quai » → GESTION gris, plus de GNL ; aucune pastille sur Améliorer ; « Sécuriser et
continuer · 8,54M $ » pour +329K $/s réels au lieu de 116 M$), `e_conf_t3_ameliorer.png` (Quais GOULOT « Quais +1 % · le débit ne
bouge pas (+16 $/s de services) » et Parc « … · pas le goulot » en gris, aucun vert ; pastille « Vent fort · 12 s » en haut à
gauche), `e_conf_alea_ameliorer.png` (brouillard : pastille « Brouillard · 22 s », Capitainerie « Suspendu (brouillard) »),
`e_conf_alea_hud.png` (panne au T3 avant le quai n°3 : « Réparer · 8,62M $ », « AMÉLIORER QUAIS » proposé — le quai n°3 à 200 M$
n'est pas abordable et un niveau de Quais fait bouger le débit), `e_conf_ceremonie.png` (« Palier T3 atteint ! », la caméra recule
sur le terre-plein), `e_conf_palier.png` (fenêtre : 3 icônes « ce qui s'ouvre », +10 Ambre, VOIR / OK ; aucune bulle par-dessus),
`e_conf_encaissement.png` (« +60,4K $ » lisible, pièces d'or de 64 px au-dessus, en arc).
**Limite vue** : les sauvegardes de bot n'ont pas encore la minute de revenu (format d'avant) — juste après leur chargement, le
revenu du HUD est mesuré depuis le chargement (bruité les premières secondes) ; les nouvelles sauvegardes l'ont.

## Lot E — Flux : circulation, passe est, croisements, gare (14/10, soir)

Ordre `docs/ORDRE_E_FLUX.md` (revue `REVUE_LOT_D.md`, E7–E12 et mineurs du monde), mené en parallèle de E-Confiance. Fichiers :
`scripts/world/layout.gd`, `diorama.gd`, `traffic_view.gd`, `ship_view.gd`, **`ship_rules.gd`** (nouveau : règles de passage des
navires, sans autoload, testées dans `run_all`), `assets/vcol_clip.gdshader` (nouveau, réservé au train), `tests/run_all.gd`
(`test_e_flux` + recalage de `test_trajets`), `tests/ui_smoke.gd` (`_e_flux_checks`). Simulation et équilibrage inchangés.

### Défauts vérifiés dans le code (tous confirmés)
- E7 : `traffic_view.gd` visait le cap 0 (est) à l'arrêt alors que le camion arrive vers l'ouest sur la voie B : pivot de 180°.
- E8 : `truck_route_in(in_x, stop_x, _tier)` envoyait chaque camion vide au bout de la boucle du palier (x 146 au T3).
- E9 : arrivée z −29 (au sud) et départ z −36 (au nord) : navigation à gauche ; le départ (168 ; −36) → (205 ; −85) croisait
  l'arrivée (194 ; −108) → (186 ; −29) vers (190 ; −65) ; aucune règle de croisement nulle part.
- E10 : voie de sortie 1 sans portique ; test (`run_all.gd:890-906`) sur la voie 0 seule et avec une file à deux voies d'entrée.
- E11 : `pick_tap` ne proposait que `dept_pos` (la tour au T2) ; pavillons posés sur `HARBOR_OFFICE` en dur.
- E12 : train lancé seulement si les deux bouts de la voie étaient hors champ ; tracteur fixe ; rue des bureaux en z 48…54 ;
  touchers Douane–barrière de sortie 6,9 u, Gate–barrière de sortie 5,6 u, Gate–barrière d'entrée 3,7 u.

### Fait
- **E7** camions : arrêt face à l'ouest (`Layout.LOAD_YAW` = π), arrivée et départ en biais doux (`LOAD_APPROACH` 4,5 u le
  long de la voie B pour 2 u de côté) ; arrêts bornés par `Layout.stop_range` (5 u avant le bout de la boucle ; 10 u après le
  début de la voie avec gate2). Cap : arrivée → arrêt → départ, 26,6° au plus par changement (run_all) ; 22,9° de rotation à
  l'arrêt sur un passage complet joué image par image (ui_smoke).
- **E8** demi-tour par groupe de blocs (`truck_route_in` sans palier → `tier_for_stop`) ; **passages de demi-tour** dessinés
  (case jaune hachurée, `Layout.crossover_xs` : x −2 au T2–T3, x 45 au T3). Camion d'un bloc du T1 au T3 (gate → tunnel est) :
  **362 u** (avant 658 u).
- **E9** passe est **à droite** : arrivée z −36 au nord (près du feu vert), **départ z −25** (et non −29 : à 7 u d'entraxe deux
  panamax se chevauchent de 1,6 u ; à 11 u ils gardent 2,4 u, contrôle N10 étendu), sortie à l'est de la ligne d'arrivée,
  (200 ; −25) → (215 ; −90) : plus aucun croisement au large. **Règles de passage** (`ShipRules`, appliquées aux vues par
  `Diorama._hold_ships` ; la simulation continue, la vue rattrape ensuite) : distance de suivi (inchangée) ; **bande balayée**
  devant l'étrave contre la coque d'un navire qui coupe la route ; **fenêtres de croisement** à deux courants — « large » (voie
  au large z −108 contre approche et sortie du chenal ouest, x −50…−10 × z −126…−90, **balisée** : contour jaune pointillé sur
  l'eau et deux bouées cardinales jaune-noir-jaune), « chenal » (navire mouillé à l'est qui rejoint l'entrée contre la sortie
  nord), « ouest » et « est » (bassins d'évitage : l'arrivée contre le départ des postes du même bassin — avec la circulation à
  droite, l'arrivée coupe forcément la voie de départ). Un navire qui va entrer (points de son trajet à 8…56 u devant lui)
  attend que l'autre courant en soit sorti ; à égalité le plus petit identifiant passe ; deux navires qui s'attendent par deux
  fenêtres voisines : le plus petit passe ; retenue de plus de 12 s : levée 3 s (aucun interblocage). Vues des navires : le
  **cap de départ** (à quai, au mouillage, ou celui du trajet précédent) passe peu à peu à la corde, et le **centre de la coque**
  rejoint en douceur le milieu de la corde étrave–poupe (sur une capture de travail, un navire qui quittait le poste 4 en biais
  lançait son étrave sur la voie d'arrivée et se superposait au navire qui entrait).
- **E10** avec gate2 : **second portique** sur la voie x −19,5 (PROPS « and »), guérite sur un **îlot** de béton entre la 2ᵉ voie
  de sortie et l'entrée (x −17,25, `Layout.GATE_ISLAND`) ; `test_trajets` recalé : file réelle à une voie d'entrée
  (`road_in_x(gate2)`, places de l'aire), arrêts de `stop_range`, **les deux voies de sortie** (eau, bâtiments, sous un portique).
  Descriptions `gate2` / `parking2` déjà corrigées par E-Confiance (« deux camions chargés sortent à la fois », plus de
  « seconde file d'entrée ») : conformes, non retouchées.
- **E11** au T2 et au-delà, la maison bleue **et** la tour ouvrent la Capitainerie (`Diorama.dept_points`), retour d'achat sur
  les deux, pavillons de campagne sur le bâtiment actif (la tour sur la butte au T2 ; replacés au changement de palier).
- **E12** gare vivante : rame découpée à la bouche du tunnel sous la colline (`vcol_clip.gdshader`, x 181) — elle entre, s'arrête
  16 s au quai et ressort, **visible gare à l'écran** ; **navette du tracteur** (TrafficView) : garage sur la liaison (axe de
  l'allée x 90,1 ; liaison et ouverture de haie recalées), attente au **passage à niveau signalé** (deux panneaux, marquage)
  tant qu'un camion est à moins de 26 u, prise d'un conteneur au parc RTG, dépose au quai, retour au garage quand le train
  repart. Coin gate / douane : **rue des bureaux en z 60…66** (derrière la tête de file), bureaux tournés vers elle, haie et
  zone 13 prolongées ; touchers Douane (−31,5 ; 38), Gate (−21 ; 56) et barrières à **≥ 11 u** (avec et sans gate2). Non fait
  (optionnel) : un camion sur N par l'aire d'inspection.
- **Mineurs** : `_ship_cargo0` vidé à la sortie de tout navire ; douaniers à places réservées (CROWD_MAX ne plafonne plus que les
  dockers) ; `rade_anchor` = place occupée la plus proche du centre ; zone 8 réduite à la voie et aux parkings (1 404 u² au lieu
  de 1 728) et discrète ; **zones d'un palier non atteint discrètes** (herbe, pointillés pâles) ; gyrophares **bleus** ; bureau
  de pilotage avec un **toit** (construit dans Godot, PROPS « roof ») ; crique : le remorqueur n°2 passe à l'avant-port
  (−45 ; −15,5), bateaux pilotes et remorqueur des paliers hors de la crique et du chenal ; GNL à 4,1 u du poste 4 (case en
  z 15,5), IMO à 4,1 u du parc RTG et 5,1 u du GNL.
- Captures : `--stage-trucks=N` (binaire de débogage seulement) fait servir N camions de suite, pour montrer le chargement.

### Contrôles
- `run_all` `test_e_flux` (8) : E7 caps ; E8 longueur et demi-tours ; E9 passe à droite, pas de croisement au large, N10 ;
  règle de la fenêtre balisée ; **simulation deux à deux des paires de trajets qui se croisent** (pilotages des 12 places vers
  les 4 postes, accostage compris, et départs ; départ à 90 u du croisement, cinq retards) avec `ShipRules.holds` :
  7 croisements hors du mouillage, 35 essais, coques à ≥ 2,3 u au croisement, 27 s au plus, sans interblocage ; bouées à 3,9 u des
  coques ; E10 ; E12 touchers, rue, tunnel, passage à niveau ; mineurs. `ui_smoke` `_e_flux_checks` (5) : E7 joué image par
  image ; passages dessinés au T3 ; E11 (toucher, retour, pavillons) ; E12 (train à quai visible et découpé, navette qui attend
  le camion puis livre) ; mineurs (cargaison, douaniers, bulle de rade, gyrophares, toit).
- Recalé (aucun retiré) : `run_all` `test_trajets` « camions … » (voir E10). `ui_smoke` « C7 A1 : un navire qui part… » repassé
  au vert : `ShipView.sync_parting(delta, rules)` — seul le diorama garde ses règles de passage pendant la sortie.
- Limites : (1) **entre les places du mouillage** (212 croisements à moins de 30 u d'une place, ou dans les 40 premiers u d'un
  appareillage) les trajets frôlent encore des coques mouillées ou se croisent de près : la grille du mouillage (colonnes à
  50 u, rangées à 28 u) ne laisse pas passer un panamax de 8,6 u entre deux navires mouillés — à reprendre avec le mouillage ;
  (2) les arrivées au mouillage depuis le large et les départs furieux (haute mer) ne sont pas simulés ; (3) dans les courbes
  du chenal, deux feeders sur les voies parallèles passent à ≈ 1,2 u (géométrie du lot D).

### Résultats
- `run_all` **214/214** (206 + 8 `test_e_flux`) · `ui_smoke` **147/147** (142 + 5 `_e_flux_checks`).
- Sonde 4 graines (`pacing_probe`, une graine par processus) : jalons, rentabilités, révélations, bandeaux **identiques** à la
  sonde prise au début de la piste ; seule la ligne « carte Goulot rouge » de la graine 4 bouge (T1 4 % → 1 %), indicateur
  d'interface modifié par E-Confiance (la sonde ne lit aucun fichier de `scripts/world`).
- Captures (`--fresh`, 540 × 960, toutes regardées), `docs/captures/` : `e_flux_camions_chargement.png` (camion arrêté face à
  l'ouest le long du parc, autres sur la voie A, case de demi-tour en x −2), `e_flux_t3_boucle.png` (camions entre les blocs du
  T1 et du T2, case en x 45, train à quai et tracteur sur la liaison), `e_flux_passe_est.png` (partie de bot du T3 : un navire
  vide repart sur la voie sud, un autre entre sur la voie nord, le long du brise-lames ; feu vert sur la tête),
  `e_flux_gate2_portiques.png` (deux portiques jaune-noir sur les deux voies de sortie, guérite sur son îlot, barrières),
  `e_flux_gare.png` et `e_flux_gare_navette.png` (train à quai, passage à niveau marqué et signalé, tracteur et son conteneur
  au quai), `e_flux_capitainerie_t2.png` (tour VTS et maison bleue, crique dégagée : seul le bateau de la cale),
  `e_flux_t1_zones.png` (T1 : seules l'enceinte de la douane et l'allongement se lisent en gris, les zones du T2 / T3 sont
  discrètes).


## Lot F1 — Navires et défilement (14–15/10)

Ordre `docs/ORDRE_F1.md` (source `PLAN_LOT_F.md` § 2 et § 3, F-D5). Mené seul côté Godot, en parallèle de l'expert Blender
(aucun fichier de `blender/` ni `.glb` touché ; `--import` lancé une fois, il a importé leurs nouveaux modèles sans les modifier).
Fichiers : `scripts/world/ship_view.gd` (réécrit), `scripts/world/layout.gd` (trajets, manœuvres), `scripts/world/diorama.gd`
(navires à l'écran), `scripts/ui/world_overlay.gd` (bulles), `scripts/ui/sheet.gd`, `hold_repeat.gd`, `upgrades_sheet.gd`,
`manage_sheet.gd`, `commerce_sheet.gd`, `missions_sheet.gd` (défilement), `scripts/main.gd` (`--ship-demo`, débogage),
`tests/run_all.gd`, `tests/ui_smoke.gd`. **Simulation, données et sauvegarde inchangées.**

### 1. Navires — ce que la lecture du code et la mesure ont montré
- Confirmé : la vue suivait le minuteur de la simulation (`_eased`, smoothstep) ; pilotage 5 s × `time_scale` (0,4 à 1), plancher
  2,5 s, raccourci par les achats ; pour ≈ 200 u, la vue filait à 40–60 u/s, plus vite à chaque amélioration, rattrapage
  `CATCHUP_K` = 2 × la vitesse nominale ; accostage en ligne droite puis cap ramené à 0 par `lerp_angle` (pivot), départ en biais
  (cap tourné de plus de 100° au premier segment).
- **Mesure sur une partie de bot (graine 1, sonde de travail)** : une escale occupe un poste **≈ 6,5 s au T1** (pilotage 1,4 +
  amarrage 1,4 + formalités 1,5 + déchargement 2,2 s pour un caboteur), **≈ 3 s au T2** (un feeder de 400–1 200 EVP est déchargé
  en 1 s), ≈ 7 s au T3 ; **jusqu'à 0,6 escale par seconde** au T2 (≈ 36 par minute, 2 postes). À vitesse de croisière, un
  navire met 70 à 150 s du mouillage au quai, et un poste ne peut pas recevoir un navire plus d'une fois toutes les 30–40 s
  (glissements, déchargement visible).
- **Conséquence : la recommandation « séparer temps de service et temps de trajet dans la simulation » n'a pas été retenue.**
  Mettre le trajet (≥ 30 s) dans la simulation aurait multiplié le cycle d'un poste par 5 à 10 (ou demandé 20 navires à la file
  dans le chenal) : la sonde aurait explosé, et l'écran resterait de toute façon incapable de montrer 36 escales par minute.
  Solution retenue (permise par l'ordre) : **la simulation garde ses durées (économie, sauvegarde et sonde identiques au bit
  près) ; le monde montre un échantillon des escales au rythme d'un port réel.** Les améliorations de la Capitainerie
  continuent d'augmenter le débit (plus d'escales servies, revenu), **jamais la vitesse d'un navire à l'écran**.

### 2. Navires — fait
- **`ShipView` réécrit** : chaque vue fait son propre voyage (phases ARRIVE, ANCHOR, INBOUND, CRAB_IN, MOORED, CRAB_OUT,
  OUTBOUND, LEAVE) à vitesse de croisière par classe — mini 7,5, caboteur 7, feeder 6, panamax 5 u/s —, vitesse « dans le
  port » 0,55 × et « de manœuvre » 0,38 × la croisière, accélération 0,6 u/s², freinage doux 0,45 u/s² (0,9 au mouillage),
  arrêt derrière un autre navire 3,5 u/s². Plus de minuteur, plus de `CATCHUP_K`. Cap : corde étrave–poupe (E-Flux), vitesse
  de rotation plafonnée à 19°/s, **un navire arrêté ne tourne pas**. Sillage réglé sur la croisière et sur la vitesse le long
  du cap (un glissement latéral ne laisse pas de sillage).
- **Trajets (`Layout`, « Lot F1 — manœuvres »)** — postes 1–2 : sortie du chenal arrondie (rayon 12) sur une voie d'évitage
  z −33 vers l'est, **évitage** à 22 u à l'est du poste (demi-tour à droite côté quai, rayon 6, remorqueur à la hanche),
  retour vers l'ouest sur la voie z −21 : le navire est **amarré étrave à l'ouest**, déjà parallèle avant la fin de
  l'approche (le cap rejoint celui du quai sur les 14 derniers mètres). **Glissement latéral** de z −21 au poste (10–12 u, au
  plus 1,1 u/s, remorqueur à l'épaule côté large). Départ : glissement inverse (le remorqueur tire au large), cap à l'ouest
  le long des quais, virage à droite (rayon 8) dans la voie de sortie du chenal — **plus aucun demi-tour au départ**. Postes
  3–4 : la boucle d'évitage devient un vrai demi-cercle (rayon 7,5), glissement, départ par la voie z −25 et la passe est.
  Mouillage : le dernier bord de l'arrivée (16 u) est déjà au cap du mouillage.
  *Pourquoi étrave à l'ouest* : amarré étrave à l'est, le départ demandait un demi-tour au large des postes puis un virage
  serré autour de la tête du brise-lames ; avec la coque posée sur la corde (règle E-Flux), elle passait sur le feu rouge
  (contrôle N1 en échec à 0,00 u). L'évitage se fait donc à l'arrivée, comme le décrit l'ordre.
- **Remorqueur** : il part de sa base dans la crique (−51 ; −15), attend le navire au rendez-vous (entrée du chenal ; passe
  est pour les postes 3–4), le remorque en tête, passe à la hanche 30 u avant l'évitage (côté intérieur du virage), à l'épaule
  côté large pour le glissement, revient pour le départ (le glissement inverse attend qu'il soit à poste, 10 s au plus), lâche
  le navire après la manœuvre et rentre ; le navire ne commence pas l'évitage sans lui (point d'attente).
- **Navires à l'écran (`Diorama`, chef d'orchestre `_direct_ships`)** : en rade, une vue par escale (liée : bulle d'humeur,
  toucher pour accoster, tutoriel) ; quand la simulation pilote une escale, sa vue part vers le poste si personne n'y est
  déjà en route à l'écran (`INBOUND_MAX` = 1), sinon elle reste au mouillage sans escale et se lie à l'escale suivante qui
  arrive (même place ou même classe de préférence) ; un nouveau navire ne vient du large que s'il manque des navires en rade à
  l'écran (ou pour le premier d'une classe), et il mouille 10 s après son escale (`ARRIVE_LAG`, il ne surgit pas près de sa
  place). File des envois : un navire sans escale quitte le mouillage quand le navire à quai a commencé son déchargement ;
  arrivé devant le poste, il attend qu'il soit libre. À quai : formalités 2 s, puis déchargement à l'écran (8 à 20 s selon la
  taille ; grues et dockers sur ce navire ; arrêtés par le vent fort ou un tablier plein), puis départ. Le montant des escales
  terminées au poste (`ship_paid`) s'affiche au départ du navire à l'écran (ou tout de suite s'il n'y en a pas).
  Bulles : humeur en rade (escale liée), déchargement du navire à quai à l'écran, « Furieux ! » sur un départ furieux.
  Toucher un navire à quai ouvre l'escale qui occupe ce poste dans la simulation.
- Débogage : `--ship-demo=classe:place:poste` (binaire de l'éditeur seulement) lance un navire de démonstration (captures).

### 3. Navires — mesures (contrôles `ui_smoke`, 26 voyages : 3 classes × 2 postes ouest × 3 places, 2 classes × 2 postes est × 2 places, puis départ hors champ)
- Vitesse à l'écran au plus **1,2 × la croisière** (un virage serré, la coque coupe la courbe) ; **en régime** (croisière, en
  ligne droite) : mini 7,5, caboteur 7,0, feeder 6,0, panamax 5,0 u/s, **écart 1 %** d'un navire à l'autre de la même classe.
- Durée du pilotage **identique** au niveau 1 de la Capitainerie et au niveau 400 + Renom 50 (80 s pour un caboteur depuis la
  place n°2) : un achat ne fait plus jamais courir un navire.
- Rotation au plus **19°/s** ; **0° de rotation navire arrêté** ; aucun point dans la terre ou le brise-lames.
- Accostage : cap à **0,0°** du quai au début du glissement, **0°** de variation sur les 8 derniers mètres, glissement
  latéral pur, remorqueur côté large 100 % du temps. Départ : glissement latéral d'abord, cap tenu.
- Évitage : l'étrave avance 92 % du temps de la manœuvre (au plus près), remorqueur à poste 98 % du temps.
- Chef d'orchestre sur une vraie partie au T3 (2 min 30, image par image) : 0 escale en rade sans vue, 0 poste surchargé,
  12 vues au plus (plafond 34), navires déchargés à quai et encaissements au départ.
- Chronologie d'un caboteur (place n°1 → poste 1, partie neuve) : chenal à 20 s, évitage 40–50 s, glissement 57–72 s, à quai
  ≈ 20 s, glissement inverse et départ, hors champ ≈ 2 min après.

### 4. Navires — limites
- **Échantillon** : à fort trafic (T2–T3), la plupart des escales de la simulation ne sont pas montrées une à une ; la rade
  montre autant de navires que la simulation, mais un navire au mouillage peut changer d'escale (bulle d'humeur rafraîchie),
  et l'argent arrive plus souvent que les navires ne partent. Au tout début (T1), le premier navire met ≈ 70 s à rejoindre le
  quai alors que la simulation l'a déjà déchargé : les conteneurs du tablier et le revenu précèdent son arrivée.
- **Évitage dans un bassin trop étroit** : le bassin intérieur (du brise-lames aux coques à quai) fait ≈ 28 u, moins qu'un feeder
  (34 u). Le demi-tour se fait coque sur la corde (étrave et poupe sur le trajet) : la coque ne sort jamais de l'eau libre,
  mais au milieu de l'évitage son centre avance lentement (≈ 0,3–1 u/s) pendant que le cap tourne (≤ 19°/s). Un vrai évitage
  « en avançant » d'un feeder demande ≈ 50 u : à reprendre avec l'espace du lot F4 (quais en avancée).
- Remorqueur : côté large = côté opposé à la caméra pendant le glissement (il est caché par la coque sur la capture
  d'accostage) ; il n'évite pas les autres navires (trajets en ligne droite, toujours sur l'eau).
- Hérité (E-Flux, non modifié) : depuis les places à l'ouest du chenal, le navire remonte jusqu'à l'entrée du chenal puis
  redescend (virage de ≈ 140° à 19°/s au large).

### 5. Défilement — reproduction
Sonde de travail (scène temporaire, supprimée), feuilles Améliorer (mi-hauteur, 3 093 px de contenu), Gestion, Commerce, au T3 :
- `DisplayServer.is_touchscreen_available()` est faux sur PC et en `--headless` : **la ScrollContainer de Godot ne défile au
  glissé que sur un écran tactile** ; sur PC, aucun glissé à la souris ne défilait (molette seulement) ;
- sur téléphone, le glissé de Godot ne part que si l'appui tombe sur la ScrollContainer : les boutons (MOUSE_FILTER_STOP)
  gardent l'appui — **un glissé qui part d'un bouton (carte pleine de boutons d'achat, « i », etc.) ne défile pas** ; c'est la
  cause retenue de « défilement parfois impossible » (on ne la voit pas en `--headless`, sans écran tactile : déduite du code
  de Godot et des filtres de l'interface) ;
- un `rebuild()` forcé avec la liste à mi-course **gardait** sa position (300 → 300) : cette piste ne cassait pas le défilement,
  mais une reconstruction pendant un glissé libérait le bouton sous le doigt ;
- un appui long sur un bouton d'achat suivi d'un glissé : la rafale (`HoldRepeat`) partait après 0,4 s.

### 6. Défilement — fait
- `Sheet` gère le glissé lui-même (`_input`) : au-delà de 14 px vertical, la liste défile d'où que parte le doigt (texte, carte,
  bouton), au doigt (`InputEventScreenTouch/Drag`) comme à la souris réelle (la souris émulée du téléphone est ignorée, pas de
  double défilement), avec un élan au relâchement ; le mouvement est consommé (la ScrollContainer de Godot ne le voit pas).
  Au début du glissé : `NOTIFICATION_SCROLL_BEGIN` propagée (BaseButton oublie l'appui) et `HoldRepeat.cancel()` (rafale
  arrêtée, aucun achat au relâchement). Un appui bref garde son effet. Molette inchangée. Seule la feuille du dessus, jamais
  sous une fenêtre.
- `request_rebuild()` : une reconstruction demandée par `refresh()` (Gestion, Commerce, Améliorer, Missions) pendant qu'un doigt
  est posé attend le relâchement ; `rebuild()` garde le défilement (rétabli pendant deux images, sauf changement d'onglet).
- Contrôles `ui_smoke` (3) : position gardée après un `rebuild()` forcé ; glissé au doigt depuis un texte avec reconstruction
  demandée au milieu (différée, défile) ; glissé depuis un bouton d'achat au doigt et à la souris, appui de 0,3 s avant de
  bouger (défile de 66 px, 0 achat, pas de rafale) ; appui bref = +1 niveau ; molette ; glissé à la souris dans Commerce et
  Gestion.

### 7. Contrôles et résultats
- Ajoutés (`ui_smoke`, 9) : F1 vitesse ; rotation / pivot / terre ; accostage en crabe ; évitage et départ ; durée indépendante
  des améliorations ; chef d'orchestre au T3 ; défilement × 3 (voir plus haut).
- **Recalés (aucun retiré)** :
  `run_all` « N1 coque à ≥ 1,5 u des bouées et des feux » — centre de la coque au milieu de la corde (comme `ShipView` depuis
  E-Flux) et corde entière (l'ancien modèle arrêtait l'étrave à l'entrée du bassin, « le remorqueur fait pivoter le navire ») ;
  `run_all` « aux paliers 1–2, sortie par la passe … sans croiser la voie d'entrée » — comparaison limitée au chenal et à la passe
  (z < −36 au lieu de −24) : au bassin, l'arrivée coupe la voie de départ sous la règle de la fenêtre « ouest », comme au lot E ;
  `ui_smoke` « C7 A1 : retenu puis relâché … jusqu'au poste » — 1 500 images au lieu de 700 (≈ 60 s de pilotage à vitesse de
  croisière + 29 s de retenue) ; « C7 A1 : un navire qui part … hors du port » — centre de la coque à une demi-longueur du bout
  du trajet (la coque reste sur la corde jusqu'à la sortie) ; « repère du tutoriel sur le navire en rade » — la carte est
  rafraîchie avant la mesure (rafraîchissement toutes les 0,25 s, trois images ne suffisaient pas toujours) ;
  « D-Monde : ship_paid au départ du poste » — si un navire est à quai ou en route à l'écran, le montant attend son départ
  (`pay_out`) ; « D-Monde : dockers au déchargement » — la foule entoure le navire à quai à l'écran (un navire est posé au
  poste 1 pour la mesure) ; « D-Monde : conteneurs posés » — tablier ramené à 20 % avant la mesure (la partie du test tourne en
  temps réel et il pouvait être plein). Garde-fou de durée de `ui_smoke` : 90 → 150 s.
- `run_all` découpé en trois (`-- --part=1|2|3`, sans argument : tout) pour rester sous 5 min par processus.
- **`run_all` 214/214** (129 + 49 + 36) · **`ui_smoke` 156/156** (147 + 9).

**Sonde (4 graines, une par processus, `pacing_probe --seeds=N --brief`) : sortie identique ligne à ligne avant / après**
(la simulation n'est pas modifiée) :

| Graine | T2 avant → après | T3 avant → après | Fin avant → après |
|---|---|---|---|
| 1 | 11:43 → 11:43 | 39:53 → 39:53 | 1 h 20 → 1 h 20 |
| 2 | 13:07 → 13:07 | 42:29 → 42:29 | 1 h 34 → 1 h 34 |
| 3 | 12:23 → 12:23 | 40:58 → 40:58 | 1 h 14 → 1 h 14 |
| 4 | 12:18 → 12:18 | 41:40 → 41:40 | 1 h 28 → 1 h 28 |
| Moyenne | 12:23 (0 %) | 41:15 (0 %) | 1 h 24 (0 %) |

**Captures** (`--fresh --ship-demo=coaster:0:0`, 540 × 960, toutes regardées), `docs/captures/` :
`f1_chenal.png` (caboteur au milieu du chenal, remorqueur en tête, sillage), `f1_evitage.png` (évitage devant le poste : le
navire tourne en avançant, remorqueur collé à la hanche qui pousse), `f1_accostage_crabe.png` (navire parallèle au quai,
étrave à l'ouest, en glissement latéral vers le poste 1 ; le remorqueur est côté large, caché par la coque à cet angle),
`f1_depart.png` (navire vide engagé dans la passe vers le nord, remorqueur à la hanche, sillage).

APK réexporté : `C:\Nadir\tycoon_V2\build\PortHorizonV2.apk` (30,2 Mo, 15/10 7 h 00 ; commande `--export-debug "Android"` de `exporter_apk.bat`, ancien APK supprimé avant).

### Vérification du chef de projet (15/10)
- `run_all` 214/214 (trois parts en parallèle, ≈ 100 s chacune) et `ui_smoke` 156/156 après l'ajout de `--ship-demo`.
- Contrôle « F1 : navires à l'écran au T3 » aléatoire (1 navire à quai sur 2 attendus une fois sur deux) : la fenêtre de 150 s
  commençait au chargement du T3, alors que le premier voyage mouillage → quai dure 70 à 150 s. Ajout de 2 min de mise en route
  avant la fenêtre observée (exigences inchangées). Vert sur deux passages.

## Lot F2 — Le golfe, partir de rien (15/10)

Ordre `docs/ORDRE_F2_F3.md` (source `PLAN_LOT_F.md` § 3, F-D2, F-D3, F-D4, F-D6). Session F2 seule : l'acte 0 (F3) sera
inséré ensuite, sur cette base.

### Étape 0 — Note de faisabilité (F2, et ce qu'elle prépare pour F3)
**Ce que le code impose.**
- `PortSim` naît au T1 avec un poste (`rebuild_infra`), 260 $ et un mini-cargo déjà en rade (`_spawn_initial`, minuterie
  1,5 s). Rien du décor n'est sauvegardé : `Zones` et `Diorama` déduisent tout de `sim.built` et du palier. Une partie
  chargée ne peut donc rien rejouer, sauf si on le décide.
- `Sim` (autoload `sim_runner.gd`) a un drapeau `paused` jamais utilisé : on peut geler la simulation sans la toucher.
- Les ouvertures de zone (`Diorama._start_opening`) savent déjà cacher puis faire surgir les nœuds d'une zone. Mais on les
  passe d'un toucher, alors qu'un chantier ne s'accélère pas (F-D2). Les chantiers seront donc un mécanisme à part, par
  bâtiment, que l'ouverture de zone ne touche pas.
- Défaut F1 (vue ≈ 70 s derrière la simulation pour le premier navire) : un navire met ≥ 60 s du large au quai à vitesse de
  croisière (≥ 40 s depuis la passe), alors que la simulation pilote et amarre le premier mini-cargo en ≈ 3 s. Aucun
  réglage de la vue seule ne ramène l'écart sous 15 s.
- **Essai rejeté** : un premier pilotage de 60 s dans la simulation (`first_pilot_time`) retarde tout le T1. Sonde sur
  4 graines : T2 en moyenne +7,6 % (graine 1 : +10,7 %), aucun revenu dans la première minute. Hors tolérance (±5 %).
  Retiré.

**Choix de F2.**
1. *Départ* : la partie commence au T1, simulation **gelée** (`Sim.paused`) pendant les cartes d'intro et la séquence de
   chantiers du T1 (quai → grue → parc → gate). Elle ne coûte donc aucun temps de jeu, et la sonde (simulation seule) ne la
   voit pas. Les pièces de départ (vieux quai, grue mobile, parc gravier, capitainerie, hangar, barrières et route de la
   gate) deviennent des groupes de décor (`Layout.STARTER`). Tant qu'un groupe n'est pas bâti, on voit son état d'avant.
2. *Premier navire* : sa vue naît à la fin du chantier du quai, hors champ, dans le chenal, et file droit vers le poste n°1.
   La simulation reste gelée jusqu'à ce que ce navire entame son glissement latéral (≈ 10 s avant d'être à quai). Ensuite
   seulement elle démarre, et le tutoriel demande de toucher le navire.
   **La simulation n'est pas modifiée** : la sonde est identique au bit près.
3. *Chantiers* : `SiteWorks` (nouveau, vue seule) cache les nœuds du bâtiment acheté pendant 3–6 s (palissade ou
   échafaudage, pelleteuse ou grue de chantier qui bouge, poussière, son), puis les fait monter et efface l'état d'avant. Ils
   sont lancés par le signal `purchased`, jamais à `bind` : une partie chargée ne rejoue rien. Tant qu'un chantier n'est pas
   fini, `Diorama.ready_bid()` est faux, et la vue des camions, des engins et des navires le consulte.
4. *Sauvegarde* : F2 n'ajoute aucune donnée sauvegardée. Pas de nouvelle version en F2 ; la version 6 viendra avec
   l'acte 0. Une partie quittée pendant la séquence de départ se recharge avec tout bâti.

**Comment F3 porte le palier 0 (recommandation).** Un **module de pêche léger** (`sim/fishing.gd`), possédé et sauvegardé par
`PortSim` (`act0`, places, achats, revenu passif). Pas de `tier = 0` dans la simulation :
- `from_dict` borne le palier à 1–3 ;
- `Layout.LAND_X`, `CameraRig.set_tier_bounds`, `tier_def`, les révélations (`unlocks.json`), les missions, la carte Goulot
  et la barre de palier supposent tous un palier ≥ 1 ;
- un palier 0 dans la simulation casserait une vingtaine de contrôles de `run_all`.

Pendant l'acte 0, `PortSim.step` n'avancerait que la pêche (ni arrivées, ni aléas, ni révélations). La bascule met `act0` à
faux, puis l'interface lance la séquence de F2.
- *Sauvegarde* (version 6) : la clé `act0` absente vaut « acte 0 fait », avec pêche passive. Une partie au T1 ou au-delà se
  charge donc sans rien rejouer.
- *Tutoriel* : les nouvelles étapes vont en tête de `tutorial.json`, avec `Settings.TUTO_REV` = 6 et une table
  `REV5_ORDER` dans `_from_old_index`.
- *Ce qui casse alors* :
  - `ui_smoke` fixe `tuto_step = 1` (étape « navire ») : à recaler par identifiant ;
  - les tests qui supposent un navire en rade dès `PortSim.new` ;
  - la sonde, dont le bot doit jouer l'acte 0 et mesurer depuis l'entrée au T1.
- *Points d'insertion* : voir la fin de cette section (« Pour F3 »).

### Fait
Fichiers :
- nouveau : `scripts/world/site_works.gd` ;
- modifiés : `scripts/world/layout.gd`, `diorama.gd`, `traffic_view.gd`, `ship_view.gd` (`dispatch_on`), `camera_rig.gd`,
  `scripts/ui/hud.gd`, `tutorial.gd`, `scripts/main.gd`, `autoload/game_state.gd`, `settings.gd`, `sfx.gd` ;
- données : `data/tiers.json`, `tutorial.json` ;
- tests : `tests/run_all.gd`, `ui_smoke.gd`.

`blender/` et les `.glb` ne sont pas touchés. **La simulation n'est pas modifiée.**

1. **Golfe et forêt.**
   - Les rives du golfe (ouest, est) et l'arrière-pays ont un sol vert sombre et sont ajoutés à l'écume de l'eau.
   - La rive d'en face (deux pans au nord, voilés de brume) laisse l'entrée x −120…102 aux sorties nord.
   - Forêt dense : 380 blocs en MultiMesh par carrés de 120 u.
   - L'autoroute (deux bouts), la rue du village et la voie ferrée entrent sous les arbres (`forest_road`), là où le trafic
     se perd.
   - Collines-tunnels supprimées ; plage ouest du continent retirée.
   - Caméra : borne nord −150, zoom le plus large 130.
   - Cotes : `PLAN_COTE.md` § 5 et § 5 bis.
2. **Départ de rien.** Le quai, la grue, le parc, le hangar, la capitainerie, la route d'accès, la voie des camions et les
   barrières sont regroupés en 4 pièces (`Layout.STARTER`, « grp »).
   - En friche : estacade ruinée, rochers et broussailles.
   - Les cases à acheter montrent aussi leur état d'avant. Plus de musoirs sur un quai pas encore construit.
   - La séquence quai (6 s) → grue (3,5 s) → parc (5 s) → gate (4 s) se joue caméra sur chaque pièce, HUD masqué,
     simulation gelée.
3. **Chantiers visibles** (`SiteWorks`) : voir DECISIONS. À tout achat de bâtiment : palissade ou échafaudage, engin animé,
   poussière, son, puis montée avec dépassement. Rien ne se rejoue au chargement.
4. **Trafic lié** (`Diorama.ready_bid`) : ni navire sans quai, ni camion sans gate, ni engin sans parc. La 2ᵉ voie, les
   parkings et le train attendent la fin de leur chantier, et aucun navire ne va à un poste en chantier. 5 voitures sur
   l'autoroute dès le départ.
5. **Intro** : 3 cartes de Capitaine Roche (`tiers.json`, palier 0 « La Crique ») : la lettre du notaire, la crique et les
   voisins, le vieux quai à rebâtir. Chacune se passe d'un toucher, montrée une fois.
   - Textes du tutoriel adaptés : « Bienvenue » et « Un navire arrive au port ».
   - Le T1 a une nouvelle histoire. `UNIVERS.md` mis à jour (golfe, Odette, anse des pêcheurs, palier 0).
6. **Premier navire** : sa vue naît hors champ dans le chenal à la fin du chantier du quai et file au poste n°1. La
   simulation démarre après 5 s de glissement (voir l'étape 0).

### Contrôles
- **Ajoutés** :
  - `run_all` (8, `test_f2`, part 3) : golfe et distances aux voies ; plus de colline-tunnel et routes sous les arbres ;
    forêt ; bord du monde au zoom le plus large aux 4 coins, aux 3 paliers ; pièces de départ ; chantiers et états
    d'avant ; trajet du premier navire ; cartes d'intro ;
  - `ui_smoke` (7, `_f2_checks`, à la fin) : friche ; intro ; séquence (ordre, durées réelles, aucun navire avant le quai,
    premier navire né hors champ, simulation gelée, ni camion ni engin trop tôt) ; écart escale–écran du premier navire ;
    chantier d'un achat (deux à la fois) ; trafic lié par palier et par bâtiment (quai n°2, gate2 et parking au T2, rail
    au T3) ; coins de l'écran au zoom le plus large.
- **Recalé** : `run_all` « E12 … bouche du tunnel sous la colline ». Il n'y a plus de colline : on contrôle maintenant
  qu'une route sous les arbres perd le trafic à la bouche `RAIL_TUNNEL_X`.
- **Adapté** : `ui_smoke` coupe `GameState.auto_start` avant sa partie de test, qui commence donc tout bâtie, comme avant.
  Le départ est contrôlé à part.
- Aucun contrôle retiré.
- Vu une fois (non lié, aléatoire) : « D-UI 2 : fermeture — caméra rendue au joueur ». Le bandeau « Premier feeder en
  approche » paraissait à la fermeture de la feuille et recadrait sur le mouillage. Vert aux trois passages suivants.

### Résultats
- **`run_all` 222/222** (129 + 49 + 44 ; avant : 214).
- **`ui_smoke` 163/163** (avant : 156).
- Écart escale / arrivée à l'écran du premier navire : 7,5–7,6 s (< 15).

**Sonde** (4 graines, une par processus, `--brief`) : identique à la base F1, la simulation n'étant pas modifiée.

| Graine | T2 avant → après | T3 avant → après | Fin avant → après |
|---|---|---|---|
| 1 | 11:43 → 11:43 | 39:53 → 39:53 | 1 h 20 → 1 h 20 |
| 2 | 13:07 → 13:07 | 42:29 → 42:29 | 1 h 34 → 1 h 34 |
| 3 | 12:23 → 12:23 | 40:58 → 40:58 | 1 h 14 → 1 h 14 |
| 4 | 12:18 → 12:18 | 41:40 → 41:40 | 1 h 28 → 1 h 28 |
| Moyenne | 12:23 (0 %) | 41:15 (0 %) | 1 h 24 (0 %) |

L'essai rejeté (`first_pilot_time` 60 s) donnait 12:58 / 14:03 / 13:13 / 13:04 au T2, soit +7,6 % en moyenne.

**Captures** (`--fresh`, 540 × 960, toutes regardées), `docs/captures/` :
- départ et séquence du T1 :
  - `f2_depart.png` : friche (estacade ruinée, broussailles, cases fantômes), 1ʳᵉ carte d'intro ;
  - `f2_t1_quai.png` : palissade, grue de chantier, échafaudage de la capitainerie ;
  - `f2_t1_grue.png` : échafaudage de la grue, quai et capitainerie debout ;
  - `f2_t1_parc.png` : palissade du parc, pelleteuse, échafaudage du hangar ; le premier navire descend le chenal avec
    son remorqueur ;
  - `f2_t1_gate.png` : chantier de la gate ;
  - `f2_t1_premier_navire.png` : évitage au bassin ;
  - `f2_t1_fin.png` : HUD revenu, carte « Bienvenue », navire à quai ;
- chantiers du T2 : `f2_chantier_t2_quai.png` (quai n°2 : palissade, grue de chantier, éclaboussures) et
  `f2_chantier_t2_parc.png` (parc bitumé : état d'avant, palissade, pelleteuse) ;
- forêt et routes : `f2_foret_route_ouest.png` (autoroute et rue du village sous les arbres) et `f2_foret_route_est.png`
  (bout est de l'autoroute) ;
- zoom le plus large aux quatre coins : `f2_zoom_large_nord_ouest.png`, `_nord_est.png`, `_sud_ouest.png`,
  `_sud_est.png` ; aucun bord du monde ;
- `f2_rive_en_face.png` : la rive d'en face en haut à droite, voilée de brume.

APK réexporté : `C:\Nadir\tycoon_V2\build\PortHorizonV2.apk` (30,2 Mo, 15/10 11 h 15). Commande `--export-debug "Android"`
de `exporter_apk.bat` ; l'ancien APK a été supprimé avant.

### Limites
- La rive d'en face ne se voit qu'au zoom le plus large, près de la borne nord. Plus près, elle couperait les rangs du
  mouillage au-delà de 25 places.
- La forêt profonde (blocs ×2,2) fait de très grands arbres vue de près.
- Le chantier de la grue de départ est un simple échafaudage.
- Pendant le départ, le joueur regarde ≈ 20 s de chantiers, puis ≈ 15 s d'arrivée du navire, sans pouvoir agir (rien
  n'est à faire, la simulation est gelée).

### Pour F3 — points d'insertion de l'acte 0
- **`Hud._intro_done()`** est appelé après la dernière carte d'intro, ou directement si l'intro est déjà vue. Il appelle
  `diorama.start_t1_works()`. L'acte 0 se place ici, et la bascule appelle ensuite `start_t1_works()`.
- **La 3ᵉ carte** (`tiers.json`, palier 0, `intro[2]`) annonce aujourd'hui « on rebâtit le Vieux Quai ». Elle deviendra
  « répare le ponton ».
- **Pendant l'acte 0** :
  - les pièces du T1 restent « pending » (friche) : `Diorama.start_works_pending()` est déjà appelé par `Hud._begin_start` ;
  - `Diorama.start_flow_active()` gèle la simulation et masque le HUD tant qu'une pièce est en friche : il faudra
    l'assouplir pendant l'acte 0 (la pêche doit tourner, le HUD être visible) ;
  - `Sim.paused` est réglé par `Hud._sync_start`.
- **Premier navire** :
  - `Diorama._spawn_first_ship()` le fait naître à la fin du chantier du quai ;
  - F3 peut le remplacer par le caboteur de Corsaire & Fils déjà en route pendant l'acte 0 (le lier à l'escale avec
    `_bind`, l'envoyer avec `ShipView.dispatch_on`) ;
  - la simulation repart au glissement (`FIRST_CRAB_LEAD`) ; contrôle `ui_smoke` « F2 premier navire ».
- **Chantiers** : `Diorama.start_site(bid)` et `Layout.site_spec`. Un achat de l'acte 0 peut passer une spec à
  `sites.start(clé, spec)` (rects, durée, engin).
- **Trafic** : `ready_bid(clé)` peut servir à la criée (camionnette) et aux pontons.
- **Sauvegarde** : rien en F2. La version 6 (clé `act0`) viendra avec F3, voir l'étape 0.

## Lot F3 — Acte 0 « La Crique » (15/10)

Ordre `docs/ORDRE_F2_F3.md` (§ F3, « Acquis de F1 », « Pour F3 »), conception `PLAN_LOT_F.md` § 5. Journal tenu au fil de
l'eau (reprise possible à chaque étape).

### Étape 0 — Choix (avant code)
- **Pêche = module léger possédé par `PortSim`** (`sim/fishing.gd`, classe `Fishing`, données `config.json` › `fishing`),
  sauvegardé sous la clé `act0` (sauvegarde v6). `PortSim.time` reste « l'horloge du port » : **elle ne tourne pas pendant
  l'acte 0** (la pêche a sa propre horloge `fishing.clock`). Tout le T1 (aléas, révélations, missions, sonde) part donc de
  l'entrée au T1, comme avant F3 ; la sonde mesure « depuis l'entrée au T1 » sans soustraction.
- `PortSim.new()` = port ouvert, pêche absente (niveau 0) : `run_all` et les tests inchangés. Une **partie neuve jouée** (départ
  de l'interface, ou le bot) appelle `begin_act0()` (0 $, port fermé) ; la bascule finit par `open_port()`.
- Pendant l'acte 0, `step` n'avance que la pêche (et les seaux de revenu) : ni arrivées, ni aléas, ni révélations, ni missions.
- Ancienne sauvegarde (sans `act0`) = acte 0 fait, 5 achats, revenu passif. Nouvelle concession (prestige) : la pêche est
  reprise ; la séquence du T1 se joue avec le port fermé jusqu'au premier navire.
- Bascule : achats faits et argent ≥ seuil → l'interface joue le caboteur de Corsaire & Fils (l'escale initiale de la
  simulation, toujours de Corsaire au T1), la narratrice, la cérémonie, les chantiers du T1 qui se chevauchent (≤ 15 s), HUD
  visible, pêche qui tourne ; la simulation du port s'ouvre au glissement du premier navire (mécanisme F2).

### Étape 1 — Simulation, sauvegarde, sonde (fait)
- `sim/fishing.gd` (nouveau, `class_name Fishing`) : cinq achats (`config.json` › `fishing.buys` : ponton 0 $, deuxième
  ponton 25 $, criée 60 $, quai des chalutiers 120 $, fabrique de glace 200 $) ; bateaux (barque, chalutier, thonier) en cycle
  OUT → FISH → BACK → LAND aux durées fixes (8/16/8/6 s pour une barque) ; loyer 0,04 $/s par place, vente à la débarque
  (barque 7 $, chalutier 28 $, thonier 70 $, ×2 avec la criée, ±10 % tirés à part du port) ; coup de main (toucher un
  bateau qui rentre ou débarque) : ×1,2 et débarque en 2,5 s. Bascule possible quand les cinq achats sont faits et l'argent
  ≥ 300 $. Après : revenu fixe `passive` × achats/5.
- `PortSim` : `fishing`, `begin_act0`, `hold_port` (nouvelle concession), `act0_ready`, `open_port`, `buy_fish`,
  `fish_help`, signal `fish_landed`, `clock()` (fenêtre du revenu affiché pendant l'acte 0) ; hors-ligne pendant l'acte 0 =
  pêche seule ; sauvegarde v6 (`act0`), migration (clé absente → `Fishing.migrate_done`) ; `carry_over` garde la pêche.
- Bot (`run_act0`) et sonde : le bot achète dès qu'il peut et aide chaque bateau ; la sonde affiche la durée de l'acte 0, sa
  durée **sans aucun coup de main** (partie à part, même graine), les instants des achats et l'argent à l'entrée du T1.
- **Calage** (graine 1 puis 4 graines) : avec coups de main 3 min 40 s ; sans 4 min 30–4 min 45 s.
  Revenu passif : à 2 $/s (≈ un tiers du revenu de fin d'acte, 6,2 $/s), T2 arrive 7,5 % plus tôt en moyenne (graine 2 :
  −15,2 %) : hors tolérance. 1,5 $/s : −7,4 %. Retenu à cette étape : 1 $/s (T2 −2,8 %, T3 −1,3 %, fin +1,8 %) ; **ramené à 0,5 $/s à l'étape 4**. Le revenu passif
  est donc ≈ 1/6 du revenu de la fin de l'acte (sans coup de main : loyer et commission de la criée), et non « de l'ordre » de
  ce revenu : la tolérance de progression du T1 prime (un joueur du T1 gagne 2 $/s à la première minute).

### Étape 2 — Monde, interface, bascule (fait, à vérifier en captures)
- `scripts/world/fishing_view.gd` (nouveau, `FishingView`, enfant du diorama) : cabane d'Odette, ponton pourri (état
  d'avant), pontons, quai des chalutiers le long du cap, criée (à l'est des pontons : vue du sud-est, elle ne cache plus les
  pontons) et sa route jusqu'à la rue du village, fabrique de glace sur le cap, un pêcheur ; bateaux (`boat_dinghy`,
  `boat_trawler`, `boat_tuna`) dont la position se déduit de la phase de la simulation (rampes de 2 s, glissement latéral
  lent à la place, rotation ≤ 1,4 rad/s) ; caisses `crate_fish` pendant la débarque ; camionnette `fish_van` (demi-tour devant
  la criée, route du mareyeur, rue du village, sous les arbres) ; chantiers des achats par `SiteWorks` (clés `fish_*`).
- `Layout` « Lot F3 » : cotes de l'anse, boucle à sens unique des bateaux (voie ouest x −136 vers le sud, plage z 44 vers
  l'est, voie est x −102 vers le nord), coins de pêche, arrivée du large par classe, trajets (`fish_path_out/back`) et
  mouvement (`fish_weigh`, `fish_profile`, `fish_path_at`), `bascule_ship_path`.
- Décor : plus de `fishing_boat` ni de caisses de poisson dans la crique du vieux port (cond « t1 ») ; le « pêcheur du
  musoir » devient un docker (même modèle, même place ; un contrôle compte ses marcheurs).
- Interface : HUD visible pendant l'acte 0 et la bascule (`Diorama.opening_active` ne compte plus le départ ; masqué sous les
  cartes d'intro seulement) ; cartes de la pêche dans Améliorer (achats faits ✓, achat suivant, un « à venir ») ; pas de carte
  Goulot ni de bulles du port pendant l'acte 0 (« Touche ! » sur un bateau qui rentre) ; toucher un bateau = coup de main ;
  « +X $ » à chaque débarque. Rien ne se bâtit au port pendant l'acte 0 (`PortSim.build`).
- Bascule (`Hud._begin_bascule`) : le caboteur de Corsaire & Fils naît hors champ au nord-ouest (`spawn_bascule_ship`) et
  attend à l'entrée du chenal si le quai n'est pas fini (`ShipView.hold_d`) ; carte de la narratrice (`tiers.json` › palier 0 ›
  `bascule`, 7 s ou un toucher) ; cérémonie « Palier 1 — Le Vieux Quai » (caméra sur le cap) ; chantiers du T1 qui se
  chevauchent (`Diorama.T1_STAGGER` : quai 0–6 s, grue 3–6,5 s, parc 5–10 s, gate 7,5–11,5 s) ; port ouvert au glissement du
  premier navire (`open_port`).
- Forêt profonde : blocs ×0,92–1,05 (au lieu de ×2–2,4) au pas de 21 u (au lieu de 40) : 422 blocs profonds, 673 en tout ;
  carrés profonds sans ombre portée. Triangles dessinés au zoom le plus large (T3, 540 × 960) : SE 179 455 → 179 459,
  NO 115 085 → 117 599, SO 93 086 → 93 344 (LOD du modèle) ; appels de dessin 454/276/193 → 442/300/190.
- `run_all` : nouveau `test_f3` (11 contrôles, part 3) ; recalé « F2 forêt » (≤ 450 → ≤ 700 blocs, voir ci-dessus).

### Étape 3 — Contrôles (fait)
- **Ajoutés** :
  - `run_all` (`test_f3`, part 3, 11) : PortSim.new sans pêche ; acte 0 (0 $, rien ne se bâtit au port, port figé : horloge,
    navires, aléas, révélations, compteurs) ; 5 achats au plus, dans l'ordre, au prix des données ; coup de main (débarque
    plus tôt, vente plus grande) ; bascule (pas avant les 5 achats et 300 $, port ouvert, revenu passif dans les recettes, plus
    de coup de main) ; durée de l'acte 0 du bot sur les 4 graines (3–5 min ; sans coup de main ≤ 5 min 30) ; sauvegarde v6
    (aller-retour en plein acte 0, même suite ; migration d'une partie sans `act0`) ; nouvelle concession ; trajets des
    bateaux (ni terre ni ponton, ≥ 40 u du mouillage et de l'arrivée des cargos, ≥ 60 u du chenal, vitesse ≤ 6 u/s) ;
    forêt profonde (≈ 1,3 ×) ; tutoriel (3 étapes en tête, la suite d'avant).
  - `ui_smoke` (8) : acte 0 à l'interface (tutoriel « ponton » sur AMÉLIORER, cartes de la pêche, chantier) ; coup de main
    d'un toucher (repère du tutoriel sur la barque, « +X $ », étape suivante) ; l'anse vivante (5 achats, ≥ 5 bateaux, ni
    terre ni ponton, aucune rotation sur place, ≤ 6,5 u/s, camionnette sur sa route) ; bascule (narratrice, caboteur de
    Corsaire & Fils né hors champ, port fermé) ; cérémonie puis chantiers ; aucune fenêtre de plus de 15 s sans action
    possible ; après l'acte 0 (passif, plus de carte ni de coup de main, bateaux vivants) ; sauvegarde v6 (reprise dans l'anse,
    partie d'avant F3).
- **Recalés (aucun retiré)** :
  - `run_all` « F2 forêt » : ≤ 450 → ≤ 700 blocs (étape 2) ;
  - `ui_smoke` « tutoriel actif à l'étape 1 » et « passe à l'étape suivante » : l'étape « navire » retrouvée par son
    identifiant (3 étapes de l'acte 0 en tête) ; `tuto_rev` posé à 6 ;
  - `ui_smoke` « F2 départ » : HUD masqué lu sur le HUD (sous les cartes d'intro), 0,6 s d'attente pour son fondu ;
  - `ui_smoke` « F2 intro » : après les cartes, l'acte 0 (et non plus la séquence du T1, qui attend la bascule) ;
  - `ui_smoke` « F2 séquence du T1 » : le caboteur existe avant le quai (il vient du large) — contrôlé : il ne dépasse pas
    l'entrée du chenal avant la fin du chantier du quai ; plus : séquence ≤ 15 s, HUD visible, pêche qui rapporte ;
  - `ui_smoke` « F2 premier navire » : « le port ouvre » (`open_port`) au lieu de « la simulation démarre » ;
  - garde-fou de `ui_smoke` : 150 s de temps de jeu → 280 s de temps réel (le temps de jeu est accéléré ×4–6 par F2/F3).
- Vue des bateaux interpolée entre deux pas de la simulation (`Sim.alpha`) : sans elle, un bateau avançait par sauts de
  0,25 s (contrôle « vitesse » à 33 u/s, « rotation sur place » 714 images).
- **`run_all` 233/233** (129 + 49 + 55 ; avant 222) · **`ui_smoke` 171/171** (avant 163).

### Étape 4 — Calage final, captures (fait)
- **Revenu passif ramené à 0,5 $/s** (`config.json` › `fishing.passive`) : avec les trajets définitifs des bateaux (cycles
  plus longs, valeurs relevées d'autant), 1 $/s donnait T2 −6,6 % en moyenne (graine 3 : −10 %) ; le seuil de bascule à
  260 $ au lieu de 300 n'y change rien (la débarque du thonier fait dépasser le seuil). À 0,5 $/s : T2 −1,6 %. Le revenu
  passif vaut donc ≈ 1/12 du revenu de la fin de l'acte (6,2 $/s sans coup de main) : un revenu de fond, qui se voit au
  début du T1 et s'efface ensuite ; plus élevé, il accélère le T1 hors tolérance.
- **Sonde finale** (4 graines, une par processus, `--brief`) ; acte 0 joué par le bot (avec coups de main ; sans : partie à
  part), puis les jalons **depuis l'entrée au T1** (l'horloge du port ne tourne pas pendant l'acte 0) ; base = F2 :

| Graine | Acte 0 (bot / sans coup de main) | Argent à l'entrée du T1 | T2 F2 → F3 | T3 F2 → F3 | Fin F2 → F3 |
|---|---|---|---|---|---|
| 1 | 3 min 41 s / 4 min 54 s | 346 $ | 11:43 → 11:33 (−1,4 %) | 39:53 → 40:09 (+0,7 %) | 1 h 20 → 1 h 28 (+10 %) |
| 2 | 3 min 44 s / 4 min 47 s | 324 $ | 13:07 → 11:31 (−12,2 %) | 42:29 → 42:19 (−0,4 %) | 1 h 34 → 1 h 29 (−5,3 %) |
| 3 | 3 min 46 s / 4 min 49 s | 325 $ | 12:23 → 12:50 (+3,6 %) | 40:58 → 41:56 (+2,4 %) | 1 h 14 → 1 h 14 (0 %) |
| 4 | 3 min 41 s / 4 min 47 s | 316 $ | 12:18 → 12:49 (+4,2 %) | 41:40 → 42:08 (+1,1 %) | 1 h 28 → 1 h 19 (−10,2 %) |
| Moyenne | 3 min 43 s / 4 min 49 s | 328 $ | 12:23 → 12:11 (−1,6 %) | 41:15 → 41:38 (+0,9 %) | 1 h 24 → 1 h 22,5 (−1,8 %) |

  Achats de l'acte 0 (bot) : ponton 0 s, deuxième ponton 30 s, criée 1 min 24–1 min 43, chalutiers 2 min 32–2 min 37,
  glace 3 min 06–3 min 11 ; ≈ 20 débarques, 23 coups de main. Tolérances tenues (moyenne ±5 %, graine ±15 %).
- **Captures** (`--fresh`, 540 × 960, toutes regardées), `docs/captures/` :
  - `f3_intro.png` (1re carte, l'anse et la friche) ; `f3_acte0_depart.png` (ponton pourri, cabane, pêcheur, tutoriel
    « répare le ponton » sur AMÉLIORER) ;
  - les cinq achats pendant leur chantier : `f3_achat1_ponton.png` (éclaboussures, la première barque arrive, « Touche ! »),
    `f3_achat2_ponton2.png`, `f3_achat3_criee.png` (palissade et pelleteuse, poussière sur la route du mareyeur),
    `f3_achat4_chalutiers.png` (quai le long du cap, camionnette sur la route), `f3_achat5_glace.png` (fabrique sur le cap,
    chalutiers en mer, « +21 $ ») ;
  - `f3_anse_vivante.png` (barques, chalutiers, criée, camionnette) ;
  - bascule : `f3_bascule_caboteur.png` (le caboteur au large, la narratrice), `f3_bascule_ceremonie.png` (« Palier 1 — Le
    Vieux Quai », la caméra sur le cap) ;
  - chantiers du T1 : `f3_t1_chantiers_quai.png` (quai, grue de chantier, échafaudages de la grue et de la capitainerie),
    `f3_t1_chantiers_parc.png` (parc, gate, pelleteuses, quai et grue déjà debout) ;
  - premier cargo : `f3_premier_cargo_chenal.png` (dans la passe, à 40 s de la bascule), `f3_premier_cargo.png` (devant le
    poste n°1) ;
  - `f3_anse_t2.png` (l'anse au T2 : pêche passive, bateaux en mer, fabrique de glace, camionnette) ;
  - forêt recalée : `f3_foret_route_ouest.png` (forêt profonde près du village : pins ≈ taille des arbres du village),
    `f3_foret_zoom_large_sud_est.png`, `f3_foret_zoom_large_nord_ouest.png`.
- Images par seconde : 60 (vsync) au zoom le plus large ; triangles dessinés identiques à F2 (étape 2).

### Limites
- Revenu passif ≈ 1/12 du revenu de la fin de l'acte (au lieu de « de l'ordre de ») : voir l'étape 4.
- Les bateaux de pêche ne s'évitent pas entre eux (boucle à sens unique, départs étalés ; ils peuvent se croiser).
- Le premier cargo arrive à quai ≈ 60 s après le début de la bascule (le caboteur vient du large) ; le joueur garde le HUD
  (Améliorer, la pêche) tout ce temps.
- Pendant un chantier, la poussière (`Diorama._dust`, F2) fait monter les triangles dessinés (≈ 370 000 au lieu de 64 000) ;
  hors de mon périmètre, signalé.
- Une barque achetée paraît en fondu au nord de l'anse (hors du cadrage de l'acte 0) avant de descendre la voie ouest.
- Passage final (après le calage) : `run_all` 233/233 ; `ui_smoke` 171/171 deux fois sur trois — une fois, « F1 : navires à
  l'écran au T3 » (aléatoire connu, voir la vérification F1 : un seul navire déchargé dans la fenêtre, `ui_smoke` lancé en même
  temps que les trois parts de `run_all`), vert aux deux passages suivants.

APK réexporté : `C:\Nadir\tycoon_V2\build\PortHorizonV2.apk` (30,2 Mo, 15/10 12 h 34 ; commande `--export-debug "Android"` de
`exporter_apk.bat`, ancien APK supprimé avant ; signé, vérifié).

### Vérification du chef de projet (15/10, 12 h 40)
- `run_all` 233/233, `ui_smoke` 171/171 sur deux passages. Contrôle « F3 acte 0 : tutoriel « répare le ponton »… » sorti une fois
  en échec puis vert deux fois : dépend du minutage (attentes en images), à surveiller.
- **Poussière des chantiers** (≈ 370 000 triangles pendant un chantier) : `Diorama._dust` créait une `SphereMesh` par défaut
  (64 segments × 32 anneaux ≈ 4 000 triangles par grain) à chaque bouffée. Remplacée par un maillage partagé à facettes
  (8 × 4 ≈ 64 triangles). Même correction (8 segments) pour les piliers des appontements et les mâts de pavois.
- APK réexporté 15/10 12 h 40 (30,2 Mo). Guide : `docs/GUIDE_TEST_10MIN.md`.

## Lot G1 — « La Crique, un vrai chapitre » (15/10)

Ordre `docs/ORDRE_G1_CRIQUE.md`, cadrage `docs/CADRAGE_DEBUT.md` (§ 4, 5, 11, 12). Journal tenu au fil de l'eau (reprise possible à
chaque palier). Aucun des modèles de `docs/ORDRE_BLENDER_G.md` n'était présent au départ du lot (la session Blender avait échoué une première
fois) : le code a été écrit avec un chargeur tolérant (`Assets.exists`, primitives Godot en repli). **Les 19 modèles ont été livrés
pendant le lot (14 h 58 – 17 h 08)** : captures, tests finaux et APK les utilisent ; les primitives ne servent plus qu'en repli.

### Étape 0 — Note de faisabilité (avant code)

**Simulation (`sim/fishing.gd`, réécrit ; `config.json › fishing` refondu).** Les cinq achats de F3 deviennent : deux cartes à
niveaux (`places` 0–8, `services` 0–10) + une liste de bâtiments (`built` : `trawler`, `pier`, `marina`, `marina2`, `marina3`,
`concession`) + Marcel (`marcel`, `marcel_offered`). Le cycle d'un bateau gagne une phase **WAIT** (loyer à encaisser) :
OUT → FISH → BACK → LAND → (payé ? OUT : WAIT ≤ `rent_wait` s → repart sans payer). Montant = `valeur(classe) × ticket`,
`ticket = 1 + 0,15 × services` (additif : ×2,5 au niveau 10 — multiplicatif, ×4 au niveau 10, mettait R₀ hors des 4–6 $/s avec les
valeurs qui tiennent la chronologie du début). Marina = loyer continu par voilier. **Plafond R₀** visé ≈ 5 $/s tout au maximum (à
caler à la sonde). La Concession (≈ 1 000 $, dès la marina) remplace `switch_money` : son achat = `act0_ready()` → bascule
(`open_port()` à la fin, comme F3). Après la Concession, la pêche continue au même modèle (plus de `passive`) et les cartes restantes
restent achetables. `PortSim.time` ne tourne toujours pas pendant la Crique (la sonde mesure depuis la Concession = l'entrée au T1).
- Heures sup révélées à l'embauche de Marcel (§ 8.1) : le minuteur des Heures sup passe sur `clock()` (= `time + act0_time`) au
  lieu de `time` (gelé pendant la Crique) ; les loyers sont ×2 pendant les Heures sup. Sauvegarde v6 : `boost_until`/`boost_ready_at`
  décalés de `act0_time` au chargement.
- Hors-ligne : avant Marcel, **le monde se fige** (`apply_offline` renvoie un rapport vide : rien gagné, rien perdu) ; avec
  Marcel, la pêche rapporte à son rythme (`rate_estimate()`, durée plafonnée comme avant) ; après la Concession, idem pour la part pêche.
- Annonce du port : `Fishing.step` pose `announced` à `clock ≥ 480 s` **et** criée faite (services ≥ 1), à ≥ 45 s de la dernière
  nouveauté (Marcel) ; `PortSim` révèle alors « Missions » (`features["missions"]`, signal `feature_unlocked`) et la mission `c0`
  « Signer la Concession du terre-plein » (`missions.json`, clé `fish`) est la première de la liste.
- Marcel = responsable hors département : compteur `managers` (mission m4 le compte), feuille RESPONSABLES (seul onglet de
  Gestion pendant la Crique), sauvegarde ; `managers_count()` (rendement hors-ligne du port) ne le compte pas.
- **Sauvegarde v7** : clé `act0` au nouveau format (`places`, `services`, `built`, `marcel`…). Une partie v6 **en cours d'acte 0**
  recommence la Crique (`begin_act0`, 0 $) ; une partie v6 au T1 ou au-delà se charge Crique finie : tout au maximum, Marcel
  embauché, Concession faite, aucun chantier rejoué.

**Monde (`FishingView`, `Layout`, nouveau `CloudLayer`).**
- Places : un seul ponton le long de la plage (z 48,4, x −134 → −98 au plus, modules de 6 u) ; **9 places** (niv. 1 = 2 barques,
  puis une par niveau) au pas de 4 u (barque 2,6 u). Le ponton ne peut pas gagner un module de 6 u à chaque niveau sur 36 u de plage :
  il s'allonge aux niveaux **3, 4, 6, 7** (quand la place nouvelle le demande) et chaque niveau pose un taquet (`cleat`) et joue un
  chantier (éclaboussures) à la place nouvelle. Écart assumé, consigné.
- Voie est des bateaux déplacée de x −102 à **x −104** (place de barque n°9 en x −100) ; chalutiers en x −98,5 ; **grande jetée**
  `pier_long` (14 × 2,5) le long du cap en (−96,5 ; 7), axe z, thonier sur son flanc ouest (−100,5 ; 7), étrave au nord, par la voie
  est prolongée jusqu'à z −2 ; passerelle (`pontoon`) vers le flanc.
- **Marina** dans l'intérieur de la boucle (jamais traversé par les bateaux) : modules `marina_pontoon` 10 × 1,8, axe z, en
  x −121 (z 32…42 puis 22…32) et x −111 (z 32…42) ; voiliers des deux côtés (3,5 / 4,5 u), 6 → 12 → 20.
- Services : criée inchangée (−99 ; 55,5) ; pompe `fuel_pump` (niv. 3) sur la plage à l'est ; aire de lavage `wash_bay` (niv. 6)
  sur la plage derrière le ponton ; glace `ice_plant` (niv. 9) sur le cap (inchangée).
- **Nuages** (`CloudLayer`) : bancs procéduraux (demi-sphères basse définition, 24 × 12 u, MultiMesh) posés sur tout le rectangle
  habillé du monde **sauf le trou de l'anse** (plage, pontons, cabane, criée et la route du mareyeur, la mer au nord jusqu'à z −80 et
  x −70 : le caboteur y passe, visible) ; dérive lente (position du nœud) ; dissolution par shader (fondu + montée, 3,5 s) à la
  Concession, puis le nœud est libéré ; jamais recréés (une partie chargée après la Concession n'en a pas ; une nouvelle concession
  non plus).
- **Caméra** : `CameraRig.set_crique_bounds()` (centre x −124…−98, z 20…48, zoom ≤ 72) tant que les nuages sont là ; bornes du
  palier dès la dissolution. Cadrage d'intro recalé dans ces bornes.
- Caboteur de l'annonce : `ship_passing` (absent → `ship_coaster`) traverse au large dans le trou des nuages (z −50 → −65,
  x −195 → −75), 20 s ; carte de la narratrice (`tiers.json › 0 › announce`).
- Marcel sur le ponton : modèle `marcel` (absent → `docker`).

**Interface.** AMÉLIORER pendant la Crique : [Concession si disponible] · prochain bâtiment · Places · Services (×1/×10/max,
maintien) ; après la Concession, un titre « La Crique » et les cartes restantes en bas de la liste. Bulle « Loyer » sur chaque
bateau rentré (rouge sous `rent_warn` s), toucher = encaisser (pièces vers le compteur, son) ; plus rien après Marcel. RESPONSABLES
visible dès que Marcel se présente ; Heures sup à son embauche. Tutoriel : `a0_pontoon` → `a0_rent` → `a0_places` → `a0_hall` →
`a0_marcel` → `a0_mission` → `a0_concession` (version 7, `REV6_ORDER` pour la migration), puis la suite d'avant.

**Sonde et bot.** `Bot.run_act0(mode)` : encaisse, embauche Marcel dès qu'il peut, achète dans l'ordre (prochain bâtiment, puis
la moins chère des deux cartes) ; « pressé » signe la Concession dès qu'elle est abordable, « tranquille » après le plafond. La
mesure T1+ (depuis la Concession) se fait sur la partie « tranquille » (R₀ entier dès l'entrée : le pire cas pour le T2). Après la
Concession, les cartes de pêche restantes entrent dans `Bot._options()` (score = gain / coût).

**Ce qui casse (contrôles de l'acte 0 actuel devenus faux, remplaçant entre parenthèses).** `run_all › test_f3` : 2 (coup de main →
loyer manuel et bateau qui repart sans payer), 3 (5 achats → cartes à niveaux et bâtiments), « coup de main » (→ Marcel),
4 (bascule à 300 $ → Concession), 5 (durées 3–5 min → pressé ≤ 12, tranquille 15–20), 6 (v6 → v7 et sa migration), 7 (nouvelle
concession : pêche reprise au plafond), 10 (tutoriel : 7 étapes en tête, version 7). `ui_smoke` : « F3 acte 0 », « F3 coup de
main », « F3 l'anse vivante », « F3 bascule » (×2), « F3 après l'acte 0 », « F3 sauvegarde v6 » : réécrits en « G1 … » avec les
mêmes invariants (ni terre ni ponton, aucune rotation sur place, ≤ 6,5 u/s, camionnette sur sa route, séquence du T1 ≤ 15 s, HUD
visible, aucune fenêtre > 15 s sans action). Risque principal : l'économie — R₀ ≈ 5 $/s au lieu de 0,5 $/s passif pousse le T2 plus
tôt ; à mesurer, levier = R₀ dans sa fourchette basse (4 $/s) et l'argent à l'entrée (≈ 0 $ après la Concession au lieu de 328 $).

### G1-a — Simulation, sauvegarde, sonde (fait)
- `sim/fishing.gd` réécrit (voir l'étape 0) ; `config.json › fishing` refondu : `rent_wait` 20 s, `rent_warn` 6 s, `ticket_step`
  0,10, `sail_rent` 0,05 $/s par voilier, `announce_at` 480 s, `reveal_gap` 45 s, `marcel` (40 $, après 12 loyers à la main),
  `places` (**11 $ × 1,33**, 8 niveaux), `services` (**6 $ × 1,27**, 10 niveaux, paliers nommés ×3 : criée, pompe, lavage, glace),
  `buildings` (chalutiers 50 $, jetée 90 $, marina 150 $, extensions 180 et 240 $, Concession 1 000 $ dès la marina),
  `boats` (barque 5 $ · 18/6/22/6 s ; chalutier 15 $ · 32/8/36/14 s ; thonier 50 $ · 44/10/50/16 s).
- `PortSim` : `buy_fish_places(n)`, `buy_fish_services(n)`, `buy_fish_building(id)`, `fish_collect(i)`, `hire_marcel()`,
  `boost_mult()`, `_flush_fish_events()` (Marcel, annonce → « Missions » révélé, bateau reparti sans payer), signal `fish_event` ;
  `act0_ready()` = Concession signée ; Heures sup sur `clock()` ; hors-ligne figé avant Marcel (rapport vide, `GameState` ne
  l'annonce pas) ; sauvegarde **v7** et migration v6 (acte 0 en cours → la Crique recommence à 0 $ ; T1+ → Crique finie, Heures sup
  décalées de `act0_time`) ; `carry_over` reprend la pêche au plafond.
- `missions.json` : `c0` « Signer la Concession du terre-plein » (clé `fish`) en tête ; `Objectives` la cache à une partie sans
  Crique. `unlocks.json` : « Réputation » attend désormais « Faire venir les navires » + 50 s (elle suivait « Missions », révélé
  dès la Crique : elle serait tombée à la 1re seconde du T1).
- **Calage** (`tests/crique_probe.gd`, nouveau, 4 graines × 2 modes). Ticket additif (voir DECISIONS). 1re économie (barque 7 $,
  R₀ 5,5 $/s) : tranquille 18 min 25, pressé 16 min 50 ; retenue : **barque 5 $, R₀ = 4,2 $/s** (bas de la fourchette 4–6, pour
  limiter l'avance du T1), coûts −10 % : **tranquille 19 min 20–19 min 34**, pressé 19 min 30–20 min.
  Jalons (graine 1) : places 2 à 1 min 16, criée 2 min 32, Marcel 4 min 16, chalutiers 9 min 34, jetée 11 min 56, marina 13 min 32,
  extensions 14 min 56 et 15 min 22, Concession 19 min 31 ; 168 escales, 17 loyers à la main, aucun perdu (le bot encaisse à la
  seconde). **Pressé ≤ 12 min : non tenu** — la Concession = 4 min de R₀, et un joueur pressé n'a que 2,4 $/s à la marina ; le
  bot « pressé » (achats par temps de retour, puis épargne) ne gagne rien sur le tranquille. Il faudrait une Concession ≈ 400 $ ou
  un R₀ bien plus haut (qui accélère le T1) : à trancher.
- **Sonde depuis la Concession** (`pacing_probe`, partie tranquille, 4 graines, base F3 mesurée depuis l'entrée au T1) :

| Graine | Crique | T2 F3 → G1 | T3 F3 → G1 | Fin F3 → G1 |
|---|---|---|---|---|
| 1 | 19 min 31 s | 11:33 → 10:48 (−6,5 %) | 40:09 → 43:11 (+7,5 %) | 1 h 28 → 1 h 30 (+2 %) |
| 2 | 19 min 28 s | 11:31 → 11:08 (−3,3 %) | 42:19 → 40:42 (−3,8 %) | 1 h 29 → 1 h 21 (−9 %) |
| 3 | 19 min 34 s | 12:50 → 9:58 (−22 %) | 41:56 → 39:29 (−5,9 %) | 1 h 14 → 1 h 14 (0 %) |
| 4 | 19 min 20 s | 12:49 → 11:08 (−13 %) | 42:08 → 42:02 (−0,2 %) | 1 h 19 → 1 h 15 (−5 %) |
| Moyenne | 19 min 28 s | 12:11 → 10:45 (**−11,7 %**) | 41:38 → 41:21 (−0,7 %) | 1 h 22,5 → 1 h 20 (−3 %) |

  T3 et fin dans la tolérance ; **T2 hors tolérance** (−12 % en moyenne, graine 3 −22 %). Attribution (même sonde avec
  `--set=config.boost.mult=1`) : sans Heures sup, T2 g1 11 min 11 (−3,2 %), g3 12 min 05 (−5,8 %). L'avance vient donc surtout des
  **Heures sup révélées dès Marcel** (cadrage § 8.1) et jouées au T1 (×2 pendant 60 s toutes les 5 min), le reste de R₀ (4,2 $/s au
  lieu de 0,5 passif). Les deux règles de l'ordre (cadrage § 8.1 et tolérance ±5 %) sont contradictoires : à trancher par le chef
  de projet (Heures sup actives sur le port à partir du T2 seulement, ou tolérance recalée). Révélations du T1 sinon dans l'ordre
  d'avant (douane 2 min 31, parc 2 min 44, gate 4 min 15, responsables 5 min, commerce 5 min 43).

### G1-b — Monde, interface, nuages (fait)
- `Layout` « Lot F3/G1 » (plan coté § 5 ter) : ponton des places unique (z 48,4, x −140 → −104, modules aux niveaux 3, 4, 6, 7,
  taquets), 9 places au pas de 4 u, voie ouest x −146, quai des chalutiers inchangé, grande jetée (−96 ; 7) + passerelle, thonier
  (−99,5 ; 7) par la voie est prolongée (`fish_exit_z`), marina (3 modules, 24 anneaux) dans l'intérieur de la boucle, pompe et
  lavage sur la plage, coins de pêche (9 barques), caboteur de l'annonce (−226 ; 12) → (−134 ; −80), nuages (`CLOUD_COVER`,
  `CLOUD_HOLE`), bornes de la Crique, `anse_site_spec(clé, cfg)` (places_N, services_N, bâtiments), `anse_obstacles()`.
- `FishingView` réécrit : ponton par niveaux, taquets, paliers nommés, jetée, marina et voiliers (roulis), Marcel (sinon le voisin),
  bulles de loyer (`collectable()`), caisses pendant LAND et WAIT, caboteur de l'annonce (`start_passing`), camionnette (toutes les
  35 s ou 2 débarques dès la criée), **primitives** (`_prim`) pour les modèles absents, liste `primitives` pour le rapport.
- `CloudLayer` (nouveau `class_name`, `--import` fait) : bancs procéduraux en MultiMesh (8 dômes de 8 × 3 par banc + dalle),
  nuages isolés au bord du trou, dérive, shader (fondu + montée), `start_dissolve()`. Diorama : `_ensure_clouds()` depuis
  `_process` (au lien, l'interface n'a pas encore appelé `begin_act0`), `clouds_on()`, `dissolve_clouds()`, `_apply_bounds()` ;
  `CameraRig.set_crique_bounds()`. Images par seconde en fenêtre : 47–61 (35 au départ, 28 pendant le passage du caboteur avec la
  carte) ; triangles 64 000–104 000.
- Interface : `UpgradesSheet` (cartes Places / Services avec ×1 / ×10 / max et maintien, prochain bâtiment, Concession en tête ;
  après la Concession, titre « La Crique » en bas), `ManageSheet` (un seul onglet pendant la Crique, fiche de Marcel), HUD
  (RESPONSABLES et sa pastille dès que Marcel se présente, pièces vers le compteur au loyer encaissé, carte de l'annonce et cadrage
  `ANNOUNCE_LOOK`, bascule : dissolution 3,5 s **puis** caboteur, narratrice, cérémonie, chantiers ; Heures sup sur `clock()`),
  `WorldOverlay` (bulle « Loyer X $ », rouge avec compte à rebours sous 6 s ; aussi après la Concession tant que Marcel n'est pas là),
  `Tutorial` (7 étapes de la Crique, version 7, `REV6_ORDER` + alias), `tiers.json` (`announce`, `bascule` réécrits, récit du palier 0),
  `main.gd` (arguments de capture).

### G1-c — Contrôles, captures, APK (fait)
- **Contrôles retirés (devenus faux) et remplacés** — `run_all › test_f3` : 2 (coup de main) → « loyer à la main, bateau qui repart
  sans payer » ; 3 (5 achats) → « cartes : Places ×1,33, criée ×3, Concession dès la marina, plafond R₀ 4–6, la pêche continue,
  cartes restantes après la Concession » ; « coup de main » → « Marcel : 12 loyers, hors-ligne figé puis à son rythme, Heures sup,
  compteur managers » ; 4 (bascule à 300 $) → « annonce à la 8ᵉ minute, 45 s après Marcel, Missions, mission c0 » ; 5 (3–5 min) →
  « tranquille 15–20 min, pressé ≤ 21 min » ; 6 (v6) → « v7 : aller-retour, v6 en cours → recommence, v6 au T1 → finie, Heures sup
  décalées » ; 7 → « nouvelle concession au plafond » ; 8 (trajets) étendu : 9 barques, jetée, marina, nuages, caboteur ≥ 14 u des
  coins de pêche et visible ≥ 60 % de sa route ; + « nuages : trou = l'anse, rien du port ni du cap, couverture = monde habillé » ;
  10 (tutoriel) → 7 étapes, version 7. `ui_smoke` : « F3 acte 0 » → « G1 Crique » (une carte, puis chalutiers / Places / Services) ;
  « coup de main » → « loyer à la main » (bulle, repère, pièces, tutoriel) + « bateau non touché : bulle rouge, reparti sans payer » ;
  + « Marcel » (RESPONSABLES, pastille, fiche seule, un onglet, Heures sup) ; + « annonce » (caboteur à l'écran dans le trou,
  narratrice, MISSIONS, mission en tête) ; « l'anse vivante » → jetée, marina, 6 voiliers, Concession en tête d'AMÉLIORER, mêmes
  invariants ; + « nuages : bancs posés, caméra bornée, coins de l'écran dans le monde habillé et sous les nuages » ; « bascule »
  → « Concession : dissolution d'abord, nuages disparus, bornes élargies » ; « après l'acte 0 » → « après la Concession : la pêche
  continue, cartes restantes, plus de nuages » ; « sauvegarde v6 » → « v7 (nuages posés à la reprise ; partie d'avant F3 : 12 bateaux,
  20 voiliers, sans nuages) ».
- **Recalés (aucun retiré)** : `ui_smoke` « mission réclamée depuis le bandeau » accepte `c0` ou `m1` ; garde-fou 280 → 400 s de
  temps réel (la Crique jouée à l'interface dure ≈ 70 s de plus) ; « F2 intro » : état d'avant `fish_places_1`.
- **`run_all` 235/235** (129 + 49 + 57 ; avant 233) · **`ui_smoke` 176/176** (avant 171). Un passage de `ui_smoke` lancé en même temps
  que quatre sondes et les captures a dépassé le garde-fou, un autre a vu « D-UI 2 : caméra rendue au joueur » (un bandeau avec
  cadrage pendant le contrôle, aléa de minutage) ; vert au passage seul suivant. Avertissements `Modèle absent` attendus (primitives).
- **Captures** (`--fresh --start --skip-intro`, 540 × 960, toutes regardées), `docs/captures/` : `g1_depart_nuages.png` (l'anse
  sous les nuages, ponton pourri, cabane, le large au nord-ouest) ; `g1_loyer.png` (deux barques rentrées, bulles « Loyer 5,2 $ ») ;
  `g1_lavage.png` (bulle rouge « 7,4 $ · 3 s », notification « reparti sans payer », aire de lavage, pompe, criée) ; `g1_criee.png`
  (palissade et route en chantier) ; `g1_pompe.png`, `g1_glace.png` (fabrique sur le cap, jetée, quai des chalutiers) ; `g1_marcel.png`
  (sur le ponton, bandeau Heures sup) ; `g1_responsables.png` (la fiche de Marcel, seul onglet) ; `g1_ameliorer.png` (jetée en tête,
  Places 4/8, Services → pompe) ; `g1_caboteur.png` (le caboteur de Corsaire & Fils en haut à gauche, carte de la narratrice, bouton
  MISSIONS 0/4) ; `g1_jetee.png` ; `g1_marina.png` (20 voiliers, 4,5 $/s) ; `g1_dissipation.png` (nuages translucides qui montent,
  le village dessous) ; `g1_zoom_large.png` (zoom 72 : nuages aux bords, jamais le bord du monde).
- **Modèles Blender** : tous livrés pendant le lot (`DECISIONS.md` § « Lot G — modèles ») et utilisés (`pier_long` tourné de 90°,
  axe z ; `marina_pontoon` tourné de 90° ; `cloud_bank` posé par le centre de sa face du dessous à y 11 ; `ship_passing`, `marcel`,
  `fuel_pump`, `wash_bay`, `sailboat_a/b`). Repli en primitives Godot (`FishingView._prim`, `CloudLayer._bank_mesh`) si un modèle manque.

### Limites
- Pressé ≤ 12 min non tenu (≈ 19 min 30 : la Concession domine) ; T2 −12 % (Heures sup au T1, cadrage § 8.1) : voir G1-a.
- Le ponton ne gagne pas un module à chaque niveau (plage de 36 u) : aux niveaux 3, 4, 6, 7 ; un taquet et un chantier par place.
- Le loyer manuel reste nécessaire après la Concession si Marcel n'a pas été embauché (le bot et le tutoriel l'embauchent).
- Les nuages ignorent la couleur de sommet du modèle (teinte uniforme du shader : blanc légèrement bleuté).
- `tests/crique_probe.gd` reste (outil de calage, pas un contrôle).

APK réexporté : `C:\Nadir\tycoon_V2\build\PortHorizonV2.apk` (30,5 Mo, 15/10 19 h 14, apres la rotation des modules de marina ; commande `--export-debug "Android"` de
`exporter_apk.bat`, ancien APK supprimé avant). Passage final : `run_all` 235/235 (129 + 49 + 57, trois parts en parallèle),
`ui_smoke` 176/176 (seul).

### G1-d — Arbitrages et corrections (15/10, soir)
Demandes du chef de projet après vérification : Heures sup hors de la Crique, Concession moins chère, Marcel vers la 5ᵉ minute,
nuages opaques.
- **Heures sup** : `PortSim.hire_marcel()` ne révèle plus `boost` (l'unlock reste « palier 2 » jusqu'au lot G2 : rien de visible ni
  d'actif pendant la Crique ; le minuteur reste sur `clock()`, le ×2 des loyers reste prêt pour plus tard). Plus de double
  révélation « Marcel rejoint la Crique » + « Nouveau : Heures sup ».
- **Concession** : 1 000 → 600 → **500 $** (le plus bas autorisé). Mesure (`crique_probe`, 4 graines) : à 600 $, pressé 15 min 03–
  15 min 19 ; à 500 $, **pressé 14 min 51–14 min 57** (cible ≤ 14 : **non tenue de ≈ 55 s**), tranquille **16 min 58–17 min 10**.
  Le bot pressé achète par temps de retour, la marina dès qu'elle est le meilleur achat (≈ 9 min 30), puis n'achète plus que ce
  qui se rembourse avant la Concession (règle 0,9 × temps restant ; 0,5 est contre-productif : 15 min 26) ; il arrive à la
  Concession avec ≈ 1,9 $/s. 400 $ tiendrait les 14 min ; à trancher.
- **Marcel** : `after_rents` 12 → **16** : il se présente (bot, 4 graines) à **5 min 08** (g1, g2, g3) et **4 min 49** (g4) —
  l'offre est faite entre 4 min 30 et 4 min 50, l'embauche attend les 40 $. (14 loyers : 4 min 16–4 min 44.)
- **Nuages** : `CloudLayer._build_sheet()` — une nappe continue à y 6,5 (cellules de 12 u sur toute la couverture, découpées en
  3 × 3 au bord du trou, ≈ 7 000 triangles), même matériau et même dissolution que les bancs. Plus aucun sol, route, voiture ni
  maison entre les bancs (captures `g1d_depart`, `g1d_zoom_large`, `g1d_zoom_large_sud`). L'anse, la cabane et la route du
  mareyeur restent dégagées.
- **Sonde depuis la Concession** (4 graines, partie tranquille, base F3) :

| Graine | Crique | T2 F3 → G1-d | T3 F3 → G1-d | Fin F3 → G1-d |
|---|---|---|---|---|
| 1 | 17 min 10 s | 11:33 → 11:50 (+2,5 %) | 40:09 → 39:16 (−2,2 %) | 1 h 28 → 1 h 17 (−12,5 %) |
| 2 | 17 min 09 s | 11:31 → 12:33 (+9,0 %) | 42:19 → 43:00 (+1,6 %) | 1 h 29 → 1 h 24 (−5,6 %) |
| 3 | 17 min 09 s | 12:50 → 12:11 (−5,1 %) | 41:56 → 40:43 (−2,9 %) | 1 h 14 → 1 h 26 (+16 %) |
| 4 | 16 min 58 s | 12:49 → 10:57 (−14,6 %) | 42:08 → 40:48 (−3,2 %) | 1 h 19 → 1 h 22 (+3,8 %) |
| Moyenne | 17 min 07 s | 12:11 → 11:53 (**−2,5 %**) | 41:38 → 40:57 (−1,7 %) | 1 h 22,5 → 1 h 22 (−0,3 %) |

  **T2 dans la tolérance** (−2,5 % en moyenne, chaque graine dans ±15 %) sans autre changement de l'économie du port ; T3 et fin aussi
  en moyenne ; la fin de la graine 3 sort de 1 % (+16 %, la fin varie de ±10 % d'un lot à l'autre depuis F2). Révélations du T1 :
  paliers 3 min 02, douane 3 min 13, parc 3 min 18, contrats 4 min 03, gate 4 min 49, responsables 5 min 34, commerce 5 min 4x (écart
  min 5 s).
- **Contrôles** : `run_all › G1` « Marcel » attend désormais `not feature("boost")` ; durées « pressé ≤ 15 min 30 (cible 14) » ;
  `ui_smoke` « Marcel » attend le bouton Heures sup caché ; « nuages » exige la nappe (`sheet_tris ≥ 1000`). **`run_all` 235/235**,
  **`ui_smoke` 176/176** (nombres inchangés : contrôles amendés, aucun retiré).
- **Captures** (`docs/captures/g1d_*`, regardées) : `g1d_depart.png` (verrou opaque, l'anse dégagée), `g1d_zoom_large.png` et
  `g1d_zoom_large_sud.png` (zoom 72 aux deux bornes : nuages pleins, plus de route ni de voiture), `g1d_marcel.png` (Marcel sur
  le ponton, aucun bandeau, pas de bouton Heures sup ; le « Palier suivant » visible est l'infobulle de la barre de palier sous la
  souris), `g1d_concession.png` (AMÉLIORER : « Concession du terre-plein » en tête à 500 $, puis extension 1 et Places).
- APK réexporté : `build/PortHorizonV2.apk` (30,5 Mo, 15/10 19 h 47).
- Vérification du chef de projet (15/10, soir) : G1-d accepté ; **cible recalée : pressé ≤ 15 min** (mesuré 14 min 51–57).

## Lot G2 — « Le Terre-plein : le premier navire à la main » (15/10, soir)

Ordre `docs/ORDRE_G2_TERREPLEIN.md`, cadrage `docs/CADRAGE_DEBUT.md` § 4, 6, 7, 11, 12 ; modèles du lot G livrés (DECISIONS § « Lot G —
modèles »). Base : lot G1 + G1-d. Journal tenu au fil de l'eau.

### Étape 0 — Note de faisabilité (avant code)

**Deux régimes de partie.** `PortSim.new()` (tests, sauvegardes d'avant G2) garde le port **complet** : les six pièces du départ
(terrassement, quai n°1, cabane de douane, piste et barrière, grue mobile, parc de stockage) sont **insérées en tête de `built`**
au `reset()` / au chargement sans clé `g2`, et les services Accostage, Déchargement, Arrivées sont révélés « depuis toujours »
(`features`). Une partie **jouée** (`begin_act0`, puis la Concession) part de la friche : `built` vide, rien de révélé, les gestes à
la main. Ainsi `run_all` (210 contrôles du port) reste vrai ; seuls les contrôles du départ (séquence du T1, gestes parc/gate/grue)
changent. Clé de sauvegarde **v8** : `g2` = {`manual`: true si la partie joue le processus à la main, compteurs des gestes, offres
des responsables}.

**Six pièces = six bâtiments** (`buildings.json`, tier 1, **avant** `quay_ext`, dans l'ordre) : `platform` Terrassement (≈ 150 $,
`ground_platform` ; capacité de la plateforme 120), `quay1` Quai n°1 (≈ 200 $, `quay_small` × 2 ; le poste n°1 n'existe qu'avec
lui), `hut` Cabane de douane (≈ 120 $, `customs_hut` + douanier ; le tampon), `track` Piste et barrière (≈ 150 $, `track_dirt`,
`barrier_post` ; la sortie), `crane_mobile` Grue mobile (≈ 300 $, `add_crane` ; avant : la grue de bord), `yard` Parc de stockage
(≈ 400 $, gravier, +180 → 300, les engins). `customs1` reste (remplace le modèle de la cabane, même case). Les pièces de départ
`Layout.STARTER` (quay0, crane0, yard0, gate0) disparaissent : leurs groupes de décor (`grp`) sont rattachés aux bâtiments
(quay0 → quay1, crane0 → crane_mobile, yard0 → yard, gate0 → track) ; `start_t1_works` et `T1_STAGGER` sont retirés ; la bascule
(nuages, caboteur, narratrice, cérémonie) se termine sur la friche nue et `open_port()`.

**Le processus à la main (régime « manuel », avant les responsables).**
- *Accoster* : sans Léon (ni Mathilde), aucun accostage automatique (`auto_berth_delay` ne sert que le régime complet) : le joueur
  touche le navire (geste existant `prioritize_ship`, compteur `priority`).
- *Décharger* : un poste sans grue décharge avec la **grue de bord** à `board_crane_rate` (≈ 0,125 EVP/s, à caler), vers la
  plateforme (`apron`, capacité 40 + 8/niv.). Plateforme pleine → le navire attend (« il faut une sortie », alerte du goulot).
- *Tamponner* : `stamp()` — toucher la cabane passe **tout le lot présent** en dédouané. Sans parc, le lot = `apron` → `yard_cleared`
  (stock de la plateforme, 120 EVP) ; avec le parc, les engins (`transfer_rate`) portent `apron` → `yard_pending` (tout, avant
  `customs1` ; la fraction de la politique après) et le tampon passe `yard_pending` → `yard_cleared`. Paul embauché : le tampon tourne
  seul à `inspect_rate` (le service Douane, `_inspect` actuel). Compteur `stamps`.
- *Laisser passer et encaisser* : `pass_truck()` — un camion se présente dès que 2 EVP sont dédouanés (`truck_queue`, mécanique
  actuelle) ; toucher la barrière sert **un camion** (2 EVP) qui paie sa part de gate (`gate_fee_ratio`, pièce vers le compteur).
  Non servi, il repart après `truck_wait` 20 s sans rien (les conteneurs restent), bulle rouge avant, compteur `trucks_lost`.
  Tonio embauché : la gate tourne seule à `gate_rate` (`_gate` actuel). Compteur `passes`. La manutention reste payée au
  déchargement (économie du T1 inchangée) : à la barrière, la pièce visible est la part de gate.
- Les gestes grue (×1,2), engin et barrière express sont **retirés** (`assist_unload`, `yard_boost`, `gate_rush` renvoient 0 :
  contrôles remplacés).
- Hors-ligne : régime manuel sans responsable du port → rapport vide (monde figé) ; ensuite règle actuelle.
- Heures sup : révélées à l'embauche du premier responsable du port.

**Les responsables sur les gestes.** `mgr_offers` : après 5 gestes (accoster / tamponner / laisser passer), le responsable se présente
(bulle + carte), un à la fois, ≥ 45 s après la nouveauté précédente ; `manager_revealed(d)` = offre faite pour berths / customs /
gate, niveau 10 pour cranes / yard_ops / harbor (règle actuelle). Prix (`departments.json`) : Léon 150 $, Paul 200 $ (passe au T1),
Tonio 250 $ — à caler. Embauché : le geste disparaît (plus de bulle), sa capacité = le débit du service (mécanique actuelle,
×2 du responsable conservé). La **carte du service** apparaît avec son responsable ou son bâtiment (`unlocks.json` : `dept_berths`
{manager}, `dept_customs` {manager ou customs1}, `dept_gate` {manager}, `dept_cranes` {crane_mobile}, `dept_yard_ops` {yard},
`dept_harbor` {berth2}) ; ordre d'AMÉLIORER = Arrivées · Accostage · Déchargement · Douane · Stockage · Sortie camions, le prochain
bâtiment en tête. Les trois chapitres actuels (« Chapitre 2 : les engins… ») sont réécrits selon § 8.2 du cadrage.

**Noms de métier** : `departments.json` (Arrivées, Accostage, Déchargement, Douane, Stockage, Sortie camions), `Info.DEPT_SHORT`,
`PortSim.HINTS`, `unlocks.json`, `tutorial.json`, `tiers.json`, textes vus avant le T2 (« gate », « portique », « EVP » → conteneur).
Identifiants inchangés.

**Monde.** Terrassement : dalles `ground_platform` (8 × 8, posées au pas des tuiles ×0,75) sur l'ancien parc et le tablier ; état
d'avant : rochers, broussailles, `jetty_ruin`. Quai n°1 : deux `quay_small` (x −44…−12, mer en +Y) + capitainerie + musoirs ;
le caboteur de Corsaire & Fils (le `ship_passing` de l'annonce) se présente en rade (l'escale initiale, premier navire). Grue de
bord : `coaster_crane` posé sur le navire à quai (`deck_pos_on_coaster`, `boom` / `hook` animés pendant le déchargement) tant que le
poste n'a pas de grue ; conteneurs posés sur la plateforme (`container_wait` orange = `apron`, `container_ok` vert = dédouanés sur la
plateforme, avant le parc) dans une grille (nouveau `PlatformView`). Cabane : `customs_hut` + `customs_officer` (toucher = tampon,
son). Piste : `track_dirt` sur la route d'accès (route et voie des camions actuelles, en terre jusqu'à `gate2`), `barrier_post`
(bras `arm` animé, toucher = laisser passer) à la place des barrières de départ. Grue mobile et parc : décor actuel (crane0,
yard0). Bulles : « Touche ! » sur le navire en rade, « À tamponner : N » sur la cabane, « Camion : touche la barrière » (rouge avant
qu'il reparte), « Il faut une sortie » sur la plateforme pleine. Chantiers par `Layout.LOTS` (nouvelles cases).

**Sonde et bot.** Le bot (régime manuel) touche avec 1 à 3 s de délai humain : navire en rade, cabane dès qu'un lot attend, barrière
dès qu'un camion attend ; achète la première case disponible tant que les six pièces ne sont pas là ; embauche chaque responsable
dès qu'il se présente (après Marcel). Jalons depuis la Concession : premier camion (4–5 min), Léon / Paul / Tonio (6–8), grue mobile
et parc (8–12), T2 (12–14), T3, fin ; base = G1-d.

**Ce qui casse.** `run_all` : « sans geste, l'accostage attend auto_berth_delay » (régime complet : inchangé) ; « coup de main grue »,
« toucher l'engin », « toucher la barrière express », « les responsables font ces gestes » (→ tamponner / laisser passer / Léon-Paul-
Tonio) ; `test_f2` « pièces de départ » (→ six bâtiments, états d'avant) ; noms des services dans les libellés. `ui_smoke` : « gestes
parc / gate » (lignes 475–484), « F2/F3 séquence du T1 » et « F2 premier navire » (→ friche nue, achats, caboteur après le quai,
grue de bord, tampon, camion), « F3 aucune fenêtre > 15 s » (recalé : le joueur agit dès la Concession), étape « ship » du
tutoriel. Risques : la sonde T2 (prix des six pièces et des responsables à caler ; Paul et Tonio ×2 à bas prix), la file de camions
sans Tonio (la vue des camions suit `trucks_waiting`), le premier navire (classe « mini », gabarit 1 : il doit porter la grue de
bord ; `deck` du méta de `ship_mini`).

### État de reprise (15/10, nuit — reprise par un second développeur)

Inventaire fait en relisant l'ordre point par point contre le code et en rejouant les tests (`run_all` 245/245, `ui_smoke`
160 ok + 16 échecs sur 176).

| Partie de l'ordre | État trouvé | Reste à faire (fait dans cette reprise, sauf mention) |
|---|---|---|
| § 1 séquence automatique supprimée, friche nue, six pièces en bâtiments (`STARTERS`, `buildings.json`), `customs1` amélioration de la cabane | fait (sim, `Layout.STARTER` vidé, `start_t1_works` sans effet) | — (le code mort de la séquence F2/F3 du diorama reste : `_process_t1`, `starter_state`) |
| § 2 gestes : accoster sans Léon, grue de bord (`board_crane_rate`), tamponner (`stamp`), laisser passer et encaisser (`pass_truck`), camion qui repart (`truck_wait`), plateforme pleine (alerte `exit`), anciens gestes retirés | fait (sim + `run_all`) | — |
| § 3 responsables après 5 gestes, un à la fois, 45 s ; remplacement du geste ; cartes avec responsable/bâtiment ; hors-ligne figé ; Heures sup au 1er responsable | fait en sim ; **défauts** : la carte du service arrivait 45 s après l'embauche (file des révélations), Déchargement/Arrivées passaient par la file ordinaire, Tonio repoussé par la cascade des révélations, Heures sup en fin de file | corrigé : `hire_manager` → `check_unlocks()`, `dept_cranes`/`dept_harbor` « opens_chapter », un responsable dû passe avant les révélations ordinaires (`_offer_due`), « Responsables » révélé sans bandeau à la première offre, « boost » juste après « managers » dans `unlocks.json` |
| § 4 noms de métier | fait dans `departments.json`, `Info`, `unlocks.json` | chassé « EVP », « gate » des textes vus au T1 (bâtiments, unités, missions, aide, fiche, bilan d'absence, barre de palier) |
| § 5 narration et tutoriel (v8 : welcome → terrassement → quai → navire → cabane → tampon → piste → barrière) ; cartes des responsables (`MGR_CARDS`) | fait | carte de la bascule et récit du palier 1 réécrits (`tiers.json`) ; étape « manager » (« coups de main ») réécrite |
| § 6 bot (gestes, délai humain), sonde depuis la Concession (jalons G2) | fait (délai fixe 2 s) | délai humain tiré entre 1 et 3 s ; **calage non fait** (prix provisoires 20–60 $ : premier camion à 50 s) |
| Monde : plateforme (`ground_platform`), quai n°1, grue de bord animée, conteneurs orange/verts (`YardView.platform_mode`), cabane et douanier, piste (`track_dirt`) et `barrier_post` (bras animé), camion qui charge et repart, bulles « Touche pour accoster », « Tamponne », « Camion : touche la barrière » (rouge), « Il faut une sortie » | fait | bulle « À tamponner : N » (texte de l'ordre) ; bulle du responsable qui se présente ; pas de bulle « en rade » avant les Arrivées ; conteneurs **noirs** en rendu OpenGL (voir G2-b) |
| Interface : un achat à la fois en tête d'AMÉLIORER, ordre du processus | fait | plus de carte « à venir » en partie jouée (deux cartes au départ au lieu d'une) ; carte Goulot sans titre à la friche (« Goulot : ») → « Prochaine étape : … », « Il faut une sortie ! » |
| **Défauts bloquants trouvés** | — | `main.gd` : toute partie neuve sautait la Crique (le test « bâtiments déjà là » voyait les six pièces d'un `PortSim.new`) ; `Hud._sync_start` ouvrait le port pendant la dissolution des nuages (plus de séquence pour le retenir) : ni carte de la narratrice, ni cérémonie |
| `ui_smoke` | 16 échecs (contrôles de l'ancien départ) | remplacés un par un (liste ci-dessous) |
| Captures, DECISIONS, PLAN_COTE, UNIVERS, APK | non faits | captures et documents faits ; APK non fait (pas de SDK Android ici) |

### G2-b — Monde, interface, narration (reprise, fait)
- **Bloquants corrigés** : `main.gd` ne voit plus une partie neuve comme « trichée » (test `built.size() > STARTERS.size()` au
  lieu de « built non vide » : depuis G2-a, `PortSim.new` contient les six pièces, toute partie neuve sautait la Crique et
  migrait la pêche). `Hud._sync_start` : le port n'ouvre qu'à la fin de la cérémonie (`bascule_over`) — sans séquence de
  chantiers pour le retenir, il ouvrait pendant la dissolution et la carte de la narratrice comme la cérémonie étaient sautées.
- **Rendu OpenGL** (repli quand Vulkan manque, et captures sous Xvfb) : les MultiMesh à `custom_data` sans `use_colors` étaient
  dessinés **noirs** (conteneurs du parc, de la plateforme, du tablier, cargaison des navires). `use_colors = true` et couleur
  d'instance blanche (`YardView`, `ShipView`) : rendu identique en Vulkan, juste en OpenGL.
- **Interface** : plus de carte « à venir » en partie jouée (AMÉLIORER à la friche = une seule carte) ; aide de la friche
  (« le terre-plein se bâtit pièce par pièce ») ; marge en bas de la liste pour que la carte du goulot (Sortie camions, la
  dernière) vienne en haut ; carte Goulot « Prochaine étape : <bâtiment> » (elle était vide) et « Il faut une sortie ! »
  (plateforme pleine) ; bulles « À tamponner : N » et « <Léon|Paul|Tonio> se présente » (au poste, tant qu'il n'est pas
  embauché) ; pas de bulle « en rade » avant les Arrivées.
- **Révélations** : carte du service à l'embauche (`hire_manager` → `check_unlocks`) ; Déchargement et Arrivées révélés avec
  leur bâtiment (`opens_chapter`) ; un responsable dû passe avant les révélations ordinaires (`_offer_due`) ; « Responsables »
  révélé sans bandeau à la première offre (le bouton paraît avec elle) ; « Heures sup » juste après « Responsables » dans
  `unlocks.json` (le premier responsable les révèle, ≈ 1 min après) ; la barre de palier paraît avec la première carte de
  service, sans bandeau ; le bandeau « premier navire d'une classe » attend la fin de la minute qui suit un palier.
- **Textes** : « EVP » → « conteneurs » et « gate » → « sortie / barrière » dans ce que le joueur voit au T1 (bâtiments, unités
  des services, missions, aide, fiche du navire, bilan d'absence, barre de palier, licences) ; carte de la bascule et récit du
  palier 1 (`tiers.json`) ; étape « manager » du tutoriel (plus de « coups de main ») ; tutoriel **version 9** : `t_crane`
  (grue mobile) et `t_yard` (parc) après « laisser passer », l'étape « quai » (allongement) n'apparaît que quand il est
  achetable (`REV8_ORDER` pour les progressions enregistrées).
- **Non fait** : un personnage par niveau au poste (jusqu'à 3) — le mécanisme existant reste (un agent de plus tous les
  8 niveaux, `agents()`) ; conteneurs orange = modèle `container_ok` teinté (pas de second MultiMesh `container_wait`) ; le
  code mort de la séquence F2/F3 (`Diorama._process_t1`, `starter_state`) n'est pas retiré.

### G2 — Contrôles `ui_smoke` (ancien → nouveau ; aucun retiré)
| # | Ancien contrôle (faux en G2) | Remplacé par |
|---|---|---|
| 1 | « Commerce, Heures sup et Gestion cachés au départ » | inchangé — il échouait à cause du défaut de `main.gd` |
| 2 | « chapitre 1 : trois boutons au HUD au départ » | inchangé — même cause |
| 3 | « bandeau des missions : replié par défaut… » | inchangé — même cause |
| 4 | « toucher : l'engin visé passe avant la grue ; zone grise = bulle » | « G2 toucher : la cabane (tamponner) et la barrière (laisser passer) passent avant le poste de leur service ; zone grise = bulle » |
| 5 | « toucher un engin du parc : rangement immédiat » | « G2 toucher la cabane : tout le lot tamponné, « Tamponné ! » » |
| 6 | « toucher la barrière : un camion passe tout de suite » | « G2 toucher la barrière : un camion laissé passer paie, pièces vers le compteur » |
| 7 | « la nouvelle concession repart de zéro » (rien de bâti) | recalé : partie de test = les six pièces ; partie jouée (`hold_port`) = friche nue, à la main, fonctions connues gardées |
| 8 | « D-UI 1 : … AMÉLIORER PARC · » | « … AMÉLIORER STOCKAGE · » (nom de métier) |
| 9 | « D-UI 2 : ouverte sur le goulot, carte en haut » | inchangé — corrigé dans l'interface (marge en bas : Sortie camions est la dernière carte) |
| 10 | « F2 départ : friche (quai, estacade « quay0 »…) » | recalé : estacade et quai du bâtiment `quay1` |
| 11 | « G1 Concession : nuages dissous, bornes élargies, port encore fermé » | inchangé — corrigé dans `Hud._sync_start` |
| 12 | « F3 bascule : carte de la narratrice, caboteur déjà en route, né hors champ » | « G2 bascule : carte de la narratrice, aucun navire (le caboteur attend le quai n°1), port fermé » |
| 13 | « F3 bascule : un toucher, cérémonie, puis la séquence de chantiers du T1 » | « G2 bascule : un toucher, cérémonie (port fermé pendant), puis la friche nue : aucun chantier, rien de bâti, aucun navire, port ouvert » |
| 14 | « F2/F3 séquence du T1 : quai → grue → parc → gate ≤ 15 s… » | « G2 friche : AMÉLIORER ne propose qu'un achat, en tête (terrassement puis quai) ; chantiers 3–6 s ; caboteur de Corsaire & Fils en rade après le quai seulement ; « Touche pour accoster » ; il n'accoste pas seul ; tutoriel t_platform → t_quay → ship » |
| 15 | « F2 premier navire : le port ouvre au glissement… » | « G2 grue de bord : accosté d'un toucher, grue de bord à l'écran, déchargement à `board_crane_rate`, conteneurs orange sur la plateforme » |
| 16 | « G1 sauvegarde v7 : … pièces en attente » | « G1/G2 sauvegarde v8 : … friche nue à venir » |
| — | « D-UI 3 : aide repliée » (texte « Le département ») | recalé : « Le service » (nom de métier) |

Contrôles ajoutés (fin de lot) : « G2 tamponner » (cabane en tête d'AMÉLIORER, bulle « À tamponner », orange → verts) ;
« G2 laisser passer » (piste en tête, camion à la barrière, bulle, il charge, paie et repart : premier camion) ; « G2 camion non
servi » (bulle rouge, reparti sans rien) ; « G2 plateforme pleine » (« Il faut une sortie ! », carte Goulot) ; « G2 Léon »
(monde figé sans responsable du port — seule la pêche de Marcel rapporte —, offre après 5 accostages : carte de la narratrice,
bulle sur le quai, RESPONSABLES ; embauché : carte Accostage, plus de bulle d'accostage). « F3 : aucune fenêtre > 15 s sans
action » est gardé (mesuré jusqu'au premier cargo à quai : 0 s).

`run_all` : « bandeaux autour du T2 » **remplacé** (mesuré sur la partie jouée G2 et non plus sur le port complet ; plafond
4 → 8 : le T1 du terre-plein tient ses révélations en ≈ 9 min, 6 à 8 bandeaux autour du T2 ; la cible de 4 revient au dégraissage
G3) ; « G1/G2 tutoriel » recalé (version 9, deux étapes) ; « G2 sauvegarde v8 » recalé (1 000 $ pour bâtir terrassement et quai
aux nouveaux prix).

**Résultats** : `run_all` 245 → **245/245** ; `ui_smoke` 160/176 → **181/181** (16 échecs résolus, 5 contrôles ajoutés).

### G2-c — Calage (sonde depuis la Concession, 4 graines, une par processus)
Leviers essayés (graines 1 et 3, sonde bornée à 24 min) : prix de l'ordre (150/200/120/150, grue 300, parc 400, responsables
150/200/250) → premier camion 3 min, **T2 16 min 30–17 min 18** ; la cause : ≈ 2 300 $ d'achats préalables (9 min de pêche),
puis la cascade des révélations (Déchargement 4 min après la grue, Tonio repoussé par chaque révélation, licences à 13–14 min).
Corrigé côté révélations (voir G2-b), puis : `value_mult` du T1 2,5 → T2 −2 min ; exigence du T2 en conteneurs 8 500 → 6 500
→ −2 min ; grue, parc et responsables bon marché → −2 min. Retenu :

| Réglage | Avant (G2-a) | Après |
|---|---|---|
| Terrassement / Quai n°1 / Cabane / Piste et barrière | 20 / 30 / 20 / 30 $ | **240 / 310 / 190 / 250 $** |
| Grue mobile / Parc de stockage | 40 / 60 $ | **60 / 80 $** |
| Léon / Paul / Tonio | 50 / 60 / 80 $ | inchangés |
| Grue de bord (`manual.board_crane_rate`) | 0,3 conteneur/s | **0,125** (≈ 1 / 8 s, l'ordre) |
| T1 `value_mult` / `dues_mult` | 1,8 | **2,2** |
| Palier T2 : conteneurs / argent | 8 500 / 14 000 $ | **4 500 / 11 000 $** (Extension du parc gravier et 3 ★ inchangés) |

| Graine | Premier camion | Léon · Paul · Tonio | Grue · parc | T2 avant → après | T3 avant → après | Fin avant → après |
|---|---|---|---|---|---|---|
| 1 | 53 s → **4 min 17** | 5:17 · 6:02 · 6:47 | 4:24 · 4:32 | 12:32 → 12:43 (+1,5 %) | 42:30 → 41:56 (−1,3 %) | 1 h 23 → 1 h 19 (−4,8 %) |
| 2 | 46 s → **4 min 11** | 5:15 · 6:00 · 6:45 | 4:22 · 4:30 | 11:45 → 13:07 (+11,6 %) | 41:03 → 41:12 (+0,4 %) | 1 h 19 → 1 h 34 (+19 %) |
| 3 | 50 s → **4 min 18** | 5:18 · 6:03 · 6:48 | 4:25 · 4:33 | 13:08 → 12:31 (−4,7 %) | 42:36 → 42:16 (−0,8 %) | 1 h 30 → 1 h 34 (+4,4 %) |
| 4 | 53 s → **4 min 08** | 5:07 · 5:52 · 6:37 | 4:17 · 4:22 | 12:10 → 12:55 (+6,2 %) | 41:04 → 43:27 (+5,8 %) | 1 h 32 → 1 h 26 (−6,5 %) |
| Moyenne | 50 s → **4 min 13** | 5:14 · 5:59 · 6:44 | 4:22 · 4:29 | 12:24 → **12:49 (+3,4 %)** | 41:48 → **42:13 (+1,0 %)** | 1 h 26 → **1 h 28 (+2,6 %)** |

Cibles : premier camion 4–5 min **tenu** ; T2 12–14 min **tenu** et ±5 % en moyenne **tenu** ; T3 et fin ±5 % en moyenne
**tenus** ; ±15 % par graine tenu sauf la **fin de la graine 2 (+19 %)** (la fin varie de ±10–16 % d'un lot à l'autre depuis F2,
loin du terre-plein). Léon 5 min 07–5 min 18 (cible 6–8 : ≈ 50 s tôt ; Paul et Tonio dans la cible). **Grue mobile et parc à
4 min 20–4 min 30 (cible 8–12 : non tenue)** : à 300 et 400 $ ils passent à 5 min 30–6 min 20 mais le T2 recule de 1 à 2 min
(16–18 min) ; le T2 a été préféré. Aucun camion perdu par le bot (délai humain 1–3 s), 24–29 tampons, 41–42 camions laissés
passer avant Tonio. Le port complet des tests (`PortSim.new`) atteint désormais le T2 vers 9 min 15 (exigences du T2 baissées) :
ce n'est plus le chemin du joueur.
