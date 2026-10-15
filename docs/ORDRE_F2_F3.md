# Ordre de mission — lots F2 « Le golfe, partir de rien » et F3 « Acte 0 : la Crique » (14/10/2026, soir)

> Pour le sous-agent **développeur senior Godot**, **après la livraison et la vérification de F1** (mêmes fichiers). Source :
> `docs/PLAN_LOT_F.md` (lire en entier : § 3 décisions F-D1…F-D7 et § 5 acte 0), validé par l'utilisateur. Les modèles de l'expert
> Blender (`docs/ORDRE_BLENDER_F.md`, § 2) sont dans `godot/assets/models/` : la liste exacte et les nœuds nommés sont dans son
> rapport (`DECISIONS.md`, « Lot F — modèles… »). Un modèle absent → primitive Godot provisoire, signalée au rapport.

## Règles (impératives)
Celles de `docs/ORDRE_F1.md` (pas de commit, Start-Process + `WaitForExit(ms)` borné + `Kill()`, `--import` après un nouveau
`class_name`, tests verts sans contrôle retiré, captures `--fresh` regardées, journal + DECISIONS + PLAN_COTE). En plus :
- **Paliers de livraison** : étape 0 (lecture + note de faisabilité au journal, 1 page : comment la simulation porte un palier 0,
  la sauvegarde, le tutoriel, ce qui casse), puis F2, puis F3. Tests verts et captures **à chaque palier**.
- **Économie** : la progression mesurée **depuis l'entrée au T1** reste dans ±5 % en moyenne et ±15 % par graine (base = sonde après
  F1). Acte 0 : de 3 à 5 min sur les 4 graines (la sonde et le bot jouent l'acte 0).
- **Sauvegarde** : nouvelle version avec migration testée. Une partie existante (T1 et au-delà) se charge avec l'acte 0 considéré
  comme fait (pêche passive active) et sans aucun chantier rejoué.

## F2 — Le golfe et le départ de rien
1. **Golfe et forêt** (F-D3) : la rive d'en face (`far_shore`) au large, au nord, des deux côtés, pour qu'on lise un golfe et
   non une île ; une **forêt dense** (`forest_block`, pins) borde toute la terre visible ; l'autoroute, la route d'accès et la voie
   ferrée **entrent sous les arbres** (`forest_road`) au lieu des collines-tunnels, et c'est là que les véhicules apparaissent ou
   disparaissent (fondu ou passage sous la voûte, jamais d'apparition visible en pleine route). La caméra ne peut plus montrer le bord
   du monde (bornes à recaler, au zoom le plus large aussi). Captures : vue de départ, zoom le plus large aux 4 coins.
2. **Départ de rien** : à la première seconde, rien de ce qui s'achète n'existe. Chaque emplacement montre son **état d'avant**
   (rochers et broussailles sur la terre, eau ou estacade ruinée `jetty_ruin` pour les quais, terrain nu) ; les zones et lots
   fantômes actuels restent la règle (une case par bâtiment), mais sans rien de construit dessus. Ce que le T1 fournit aujourd'hui sans
   achat (vieux quai, grue mobile, parc gravier, capitainerie, barrières de gate, entrepôts du village) se construit au passage au T1
   (voir F3) par une **séquence de chantiers** (quai → grue → parc → gate), qu'on voit et qui ne coûte pas de temps de jeu (la
   simulation est prête dès le début du T1 ; les navires et camions arrivent au rythme normal, donc après les chantiers).
3. **Chantiers visibles** (F-D2) : tout achat de bâtiment (y compris les quais, le dragage, le terre-plein du T3) joue un chantier
   de 3 s (petit) à 6 s (grand) : palissade (`site_hoarding`) ou échafaudage (`scaffold`) à l'empreinte, pelleteuse ou petite grue de
   chantier qui bouge, poussière (particules), son de chantier ; puis le bâtiment **monte** (léger dépassement d'échelle) et l'état
   d'avant (rochers, broussailles) disparaît dans la poussière. Le terre-plein : remblai qui avance sur l'eau. Plusieurs chantiers
   peuvent avoir lieu en même temps. Aucune accélération, aucun bouton. Une partie chargée ne rejoue rien. Aucun véhicule n'utilise un
   bâtiment dont le chantier n'est pas fini (contrôle).
4. **Trafic lié à ce qui existe** (F-D6) : pas de camion sans gate, pas de cargo sans quai, pas de camionnette sans criée, pas de
   voitures sur une route qui n'est pas construite ; l'autoroute existe dès le départ (elle va d'une forêt à l'autre), avec un trafic de
   voitures léger. Contrôle par palier et par bâtiment.
5. **Intro** (F-D4) : 3 cartes de la narratrice (qu'on peut passer d'un toucher), avant la première action : la lettre du notaire
   (Odette te lègue sa crique au fond du golfe d'Ambre), la crique et les voisins pêcheurs, « répare le ponton ». Ton chaleureux et
   drôle (`docs/UNIVERS.md`). Mettre à jour `UNIVERS.md` (golfe, Odette, l'anse des pêcheurs, la Crique = palier 0) et `tiers.json`.

## F3 — Acte 0 « La Crique »
Conception : `PLAN_LOT_F.md` § 5 (lieu, achats, bascule, après). À réaliser :
- **Palier 0** dans les données et la simulation (ou un module de pêche léger branché sur la simulation : à toi de choisir à
  l'étape 0, argumenté). Places d'amarrage louées ; bateaux du village qui sortent, rentrent et débarquent ; vente sur le ponton,
  puis à la criée. 5 achats au plus, sur les mêmes cartes AMÉLIORER que le reste (pas d'écran nouveau). Aucun responsable, aucun aléa,
  pas de Commerce pendant l'acte 0.
- **Visuels** : barques, chalutiers, thonier (`boat_*`) qui suivent des voies propres (jamais à travers la terre, les pontons ou le
  chenal des cargos), caisses débarquées, camionnette du mareyeur (`fish_van`) qui part vers la forêt, Odette ou un pêcheur sur le ponton.
- **Bascule** vers le T1 : le caboteur de Corsaire & Fils passe au large, la narratrice, la cérémonie « Palier 1 — Le Vieux Quai »,
  la caméra franchit le cap, la séquence de chantiers du T1 (F2 § 2). Ensuite, le tutoriel actuel reprend (en adaptant la carte
  « Bienvenue » et le texte « un vieux quai, une grue rouillée… » qui deviennent faux ou redondants).
- **Après l'acte 0** : la pêche donne un revenu fixe et passif (affiché dans le revenu, détaillé dans Gestion › Stats), plus aucune
  carte ni pastille ; l'anse reste vivante à tous les paliers (nombre de bateaux plafonné pour les performances).
- **Tutoriel** : nouvelles étapes de l'acte 0 en tête de `tutorial.json` (réparer le ponton, toucher une barque qui rentre pour
  l'aider à débarquer = le geste manuel du jeu, la criée), puis bascule.
- **Sonde et bot** : le bot joue l'acte 0 ; durées 3–5 min ; tableau des jalons depuis l'entrée au T1.

## Fin de lot
Tests verts (nombre avant/après), sonde dans les tolérances, captures `docs/captures/f2_*` et `f3_*` regardées (départ, intro,
chaque achat de l'acte 0, bascule, chantiers du T1, un chantier T2, forêt et route, zoom large), `PLAN_COTE.md` (anse des pêcheurs,
forêt, bornes de caméra), `UNIVERS.md`, journal, DECISIONS, **APK réexporté**. Rapport : fait / non fait (raison), chiffres, captures.

## Acquis de F1 à respecter (15/10)
- **Vue et simulation sont découplées pour les navires** (`ShipView` réécrit, voir `DECISIONS.md` « Navires et défilement (lot F1) ») :
  le monde montre un échantillon des escales, à la vitesse de croisière. Conséquences pour F2/F3 :
  - au passage au T1, **aucun navire à l'écran avant la fin du chantier du quai**. Le caboteur de Corsaire & Fils qui passe au
    large pendant l'acte 0 doit être celui qui vient s'amarrer, et son voyage doit être calé pour qu'il arrive peu après le chantier.
    Le défaut connu « premier navire ≈ 70 s pour venir à quai pendant que la simulation l'a déjà déchargé » ne doit plus se voir
    au début du T1 (contrôle : écart entre l'escale de la simulation et son arrivée à l'écran < 15 s pour le premier navire du T1) ;
  - les bateaux de pêche suivent la même logique de voyage (croisière lente, pas de sprint, pas de pivot sur place).
- Tests : `run_all` se lance en trois parts (`-- --part=1|2|3`, ≈ 100 s chacune, lançables en parallèle) ; `ui_smoke` ≈ 3 min.
- APK : `exporter_apk.bat` finit par `pause` : lancer directement la commande `--export-debug "Android"` qu'il contient.

## Pour F3 : acquis de F2 et corrections demandées (15/10, chef de projet)
Lire d'abord le journal § « Lot F2 », dont la sous-section « Pour F3 » (points d'insertion : `Hud._intro_done()`,
`diorama.start_t1_works()`, `start_flow_active()` / `Hud._sync_start`, `Diorama._spawn_first_ship()`, `_bind`,
`ShipView.dispatch_on`, `start_site` / `sites.start`, `ready_bid`, options `--start`, `--skip-intro`, `--site=`).
- **Choix validé** : la pêche est un **module léger possédé par la simulation** (recommandation de l'étape 0), pas un palier 0 dans la
  simulation. Sauvegarde v6 (clé `act0`) avec migration testée : une partie existante = acte 0 fait, pêche passive active.
- **Plus de temps mort imposé** : aujourd'hui le départ impose ≈ 35 s sans rien pouvoir faire (HUD masqué, simulation gelée).
  Avec F3 : le joueur agit dès la fin de l'intro (réparer le ponton). La séquence de chantiers du T1, à la bascule, dure **≤ 15 s**
  en tout (chantiers qui se chevauchent, caméra qui suit), le HUD reste visible et la pêche continue de rapporter pendant ce temps.
  Contrôle : aucune fenêtre de plus de 15 s sans action possible entre la fin de l'intro et le premier cargo à quai.
- **Arbres de la forêt profonde trop grands** (captures `f2_zoom_large_sud_est.png`, `f2_foret_route_ouest.png` : couronnes 2 à 3 fois
  plus larges qu'une maison) : échelle plafonnée à ≈ 1,3 × celle des arbres du village, densité gardée (plus de blocs si besoin,
  dans le budget de performance : vérifier les images par seconde au zoom le plus large).
- **Bateaux de pêche de décor** : les deux `fishing_boat` posés dans la crique (`cond: "t1"`) et le pêcheur du musoir ne doivent pas
  contredire l'acte 0 (pas de bateaux immobiles « déjà là » si la pêche est dans l'anse ouest) : à intégrer dans la flottille ou à
  retirer, au choix argumenté.
- **3ᵉ carte d'intro** : « répare le ponton » (voir journal F2). La carte « Bienvenue » du T1 arrive après la bascule.
