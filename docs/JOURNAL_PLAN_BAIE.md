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
