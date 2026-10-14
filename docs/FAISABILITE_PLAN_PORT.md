# Faisabilité du plan « La baie et le terre-plein » (13/10/2026, soir)

Suite de `PLAN_PORT.md` et `ETUDE_CARTE.md`. Question posée : le plan est-il faisable, bon, et que faut-il y améliorer, en
améliorant au passage les sensations de jeu ? Réponse appuyée sur le code actuel (`layout.gd`, `diorama.gd`, `traffic_view.gd`,
`ship_view.gd`, `port_sim.gd`) et sur un **prototype Godot autonome** construit ce soir, qui n'a touché ni au jeu ni aux modèles.

## 1. Verdict

**Faisable, et moins cher que prévu.** Les deux points que le plan jugeait coûteux (la côte découpée et la mer qui devient terre)
se font dans Godot, sans nouveau modèle Blender : le prototype les fait en 330 lignes de GDScript. Le mécanisme « une seule zone
prochaine » existe déjà dans la simulation (ordre strict des bâtiments) : les zones sont une **présentation** de ce qui existe,
pas une mécanique nouvelle, donc sans effet sur l'équilibrage ni sur les sauvegardes.

Deux points de l'étude doivent être corrigés avant d'écrire les ordres de mission : les chapitres « responsable embauché »
(§ 3.5) et la position de la rade (§ 3.3). Un point est à déconseiller : la fusion Capitainerie + Quais (§ 3.7).

## 2. Ce que le prototype a prouvé

Captures dans `docs/captures/` : `proto_baie_t1.png` (cadrage de départ, zoom 40), `proto_baie_t1_large.png` (vue large),
`proto_baie_t2.png` (le Terminal est la zone prochaine), `proto_baie_t3.png` (terre-plein gagné sur la mer, quais 3 et 4).
Sources : `docs/proto_baie/` (le projet complet tourne avec une copie de `godot/assets/models/`).

| Élément du plan | Comment c'est fait dans le prototype | Coût réel |
|---|---|---|
| Côte quelconque (cap, crique, baie) | Un polygone de côte ; dessus coloré + flancs en couches de terre (même look que les dalles Blender), triangulé par `Geometry2D.triangulate_polygon` | 60 lignes, 0 modèle |
| Eau qui suit la côte | Les polygones de terre sont rastérisés une fois dans une texture de distance (256 × 256, transformée de chanfrein) lue par le shader de l'eau à la place des 12 rectangles actuels | 70 lignes, calcul < 0,3 s au démarrage |
| Terre-plein « la mer devient terre » | Un second polygone ajouté au palier 3 ; la texture de distance est recalculée ; contour en pointillés blancs tracé sur l'eau avant | 15 lignes |
| Zone grisée / prochaine / ouverte | Dessus de zone désaturé par le shader (`desat`, déjà dans `vcol.gdshader`) + pointillés blancs ; zone prochaine : pointillés dorés, empreinte `ghost_lot` (modèle déjà livré) et pancarte `Label3D` | 60 lignes |
| Chenal balisé, passe, mouillage | Bouées rouges à bâbord et vertes à tribord le long d'une polyligne (`buoy`, `buoy_green` livrés), feux de passe, navire et remorqueur qui suivent la polyligne | 50 lignes |
| Brise-lames, phare sur le cap, village, logistique | Modèles existants, posés sur le nouveau plan | 0 |

Ce qui n'a pas été prototypé (mais ne présente pas d'inconnue technique) : l'animation de chantier, le circuit des camions,
le cadrage caméra par zone, les chapitres.

## 3. Point par point : faisable, bien, à améliorer

### 3.1 Terrain et quartiers — faisable, à faire dans Godot plutôt qu'en Blender
Le plan prévoyait « côte découpée et bord du terre-plein » côté Blender. **Recommandation : terrain polygonal dans Godot**
(`Layout` décrit des polygones, `Diorama` les construit), et Blender ne livre que les objets posés dessus : enrochements
(le `rock` actuel suffit en attendant), barges à sable, feux de passe (deux bouées agrandies font l'affaire au début),
pancarte de zone. Les dalles 6 × 6 restent utiles **à l'intérieur** des zones (marquages, parking, routes).
Gain : le lot Blender du plan tombe d'environ une session à une demi-session, et le plan coté se règle dans un seul fichier.

### 3.2 Les 12 zones — faisable, sans toucher à l'économie ni aux sauvegardes
`PortSim.building_state` rend déjà un bâtiment `locked` tant que **tous les bâtiments précédents de la liste** ne sont pas
construits : le jeu impose déjà un ordre unique, c'est exactement « une seule zone prochaine ». Une zone = un groupe de bâtiments
consécutifs de `buildings.json` ; son état se déduit de `sim.built`. Rien à sauvegarder, rien à migrer, le bot joue la même partie.

À améliorer dans la liste du plan :
- **Zone 4 « Mouillage »** n'a pas de bâtiment : les places de rade viennent des niveaux de Capitainerie (`rade_places`,
  +1 tous les 10 niveaux). La traiter comme un **élément de palier** (une bouée numérotée de plus tous les 10 niveaux,
  `STAGE_PROPS` le fait déjà pour d'autres objets), pas comme une zone à acheter.
- **Agrandissements « dans leur zone »** (gravel2, gravel3, supply, crane2, repair, tug2, quickmoor, ewindow, scanner2…) :
  chacun a besoin d'une case dessinée dès le départ dans sa zone (empreinte `ghost_lot` + pancarte quand il devient le prochain
  achat). C'est le lot C « lots fantômes » : il se fond dans ce chantier.
- **La voie des camions** (§ 5 de l'étude) n'est pas cotée dans le plan : réserver une bande de 6 u entre le parc et La Porte
  dans les zones Vieux port et Terminal.

### 3.3 Chenal et rade — faisable, mais la rade doit rester visible
Les trajets de `ship_view.gd` sont des courbes directes ; les remplacer par une polyligne par état (rade → passe → bassin
d'évitage → quai → sortie est) est simple et purement visuel. **Problème** : avec le cap à l'ouest et la passe au nord, la rade
passe à z ≈ −100, hors de l'écran de départ. Or le tutoriel commence par « touche le navire en rade », et le geste manuel
« accoster en priorité » suppose de le voir. **Correction** : mouillage **juste devant la passe** (z −55 à −70), à un glissement
du quai, et cadrage de départ un peu plus haut (cible (−30, −14), zoom 46) pour que le vieux port, la passe et un navire au
mouillage tiennent sous le HUD. La pastille « n/N en rade » (existante) reste le rappel quand la rade est hors champ.

### 3.4 Circuit des camions — faisable, une session
`TrafficView` connaît déjà la file, l'aire d'attente et la barrière. Il manque : la voie à sens unique dans le port, l'arrêt
devant le bloc du parc, le chargement visible (le conteneur descend du cavalier sur la remorque : un tween), la sortie par la
gate de sortie, et la règle « apparition et disparition hors écran seulement » (aujourd'hui le camion vide disparaît à z = 24).
Aucune dépendance à la simulation : l'animation se cale sur `truck_served` comme aujourd'hui.

### 3.5 Chapitres — à corriger : « responsable embauché » n'est pas tenable au palier 1
L'étude ferme le chapitre 2 (Parc) et le chapitre 3 (Gate) par l'embauche de leur responsable. Or Nadia Benali (Parc) et
Tonio Ferrer (Gate) sont des **responsables de palier 2** à 250 K$ et 900 K$ (`departments.json`) : au palier 1, le joueur gagne
quelques milliers de dollars. Tels quels, les chapitres 2 et 3 ne se terminent jamais.

Deux issues :
1. **Fermer un chapitre au palier 10 du service** (recommandé). Le palier 10 existe déjà (étape nommée, ×2, élément de décor
   qui surgit) : « Parc au niveau 10 » coûte ≈ 2 000 $ et arrive en 2 à 3 minutes. Les responsables gardent leur palier et
   leur prix, l'économie mesurée (T1 → T2 en 11–12 min) ne bouge pas, seule la **présentation** change. À mesurer avec
   `pacing_probe.gd` quand même, parce que l'ordre imposé des cartes « Améliorer » peut décaler les premiers achats.
2. Descendre Nadia et Tonio au palier 1 avec un prix de palier 1 : ils doublent leur service, donc toute la courbe T1 est à
   remesurer. Déconseillé.

`unlock_ok` accepte aujourd'hui `ships`, `evp`, `building`, `amber`, `tier` : ajouter `level` (« service X au niveau N ») et
`manager` est une dizaine de lignes, et `unlocks.json` porte le reste.

### 3.6 Nouveaux gestes manuels (parc, gate, douane) — faisables, à rendre optionnels
Le « coup de main » (toucher la grue, 2 s de gain, recharge 2 s, remplacé par la cheffe des grutiers) est le modèle à copier.
Mais sans responsable de palier 1 pour le parc et la gate (§ 3.5), ces gestes resteraient « à faire » pendant 12 minutes :
les présenter comme des **accélérateurs à recharge** (comme le coup de main), jamais comme une obligation pour que la chaîne
tourne. Le geste douane attend le palier 2 et son inspecteur, comme prévu.

### 3.7 Fusionner Capitainerie et Quais au palier 1 — à déconseiller
Cela touche `PortSim`, les coûts, les responsables, 129 contrôles et 4 graines de bot, pour un gain de lisibilité qu'on obtient
autrement : les deux services ont **le même poste sur la carte** (la capitainerie du vieux port) et la carte « Améliorer »
du palier 1 ne montre que les cartes du chapitre en cours. Le joueur ne voit qu'un endroit ; la simulation ne change pas.

### 3.8 Caméra, portrait, paysage — vérifié
Au zoom 40 (largeur visible 40 u, hauteur au sol ≈ 120 u en portrait), le vieux port (48 × 30 u) tient sous le HUD ; au zoom 60,
le Terminal (48 × 36 u) tient. `CameraRig.focus` et `zoom_goal` suffisent pour cadrer une zone à son ouverture. En paysage,
la colonne de 1080 px (`Hud._apply_column`) montre plus de côtés : rien à changer.

### 3.9 Sauvegardes, tests, performance — sans risque identifié
Bâtiments enregistrés par identifiant : aucune migration. Les contrôles qui citent des positions (`Layout.CUSTOMS_HUT`,
`GATE`, ancrage des bulles) sont à rejouer après le nouveau plan coté, pas à réécrire. Le terrain polygonal fait quelques
milliers de triangles de plus que les dalles, négligeable face aux 90 000 des modèles.

## 4. Sensations de jeu : ce que ce chantier doit apporter en plus du plan

Chaque point est peu coûteux parce qu'il s'appuie sur ce qui existe (pop + poussière de `_build_stage_props`, `CameraRig.shake`,
narratrice, gerbes de `fx.gd`, sons synthétisés de `sfx.gd`).

1. **Ouverture de zone = la récompense du jeu.** Séquence de 3 à 5 s, passable d'un toucher : la caméra glisse et zoome sur la
   zone, les pointillés dorés s'effacent, le sol prend sa couleur par une vague (un `tint` animé), les bâtiments surgissent avec la
   poussière, le repère vertical en dernier (la tour, le portique) avec une secousse courte, un son grave, une phrase de la
   narratrice, puis retour au cadrage. Pour le terre-plein : barges qui déversent, bande de sable qui avance, puis les quais.
2. **La zone prochaine respire.** Contour doré qui pulse lentement, pancarte qui rebondit quand l'achat devient abordable
   (la pastille « achats abordables » existe déjà : même signal, dans le monde). Un seul objet animé de ce genre à la fois.
3. **Le chemin du conteneur se voit en entier** : grue → tablier → cavalier → bloc → camion → barrière qui se lève → autoroute.
   C'est ce qui rend un idle « vivant » sans mécanique nouvelle. Corne à la passe, remorqueur qui pivote au bassin d'évitage,
   sillage sous les navires en mouvement (un quad d'écume qui suit).
4. **La silhouette grandit avec le joueur** : au palier 1 tout est bas ; la tour (T2) puis la rangée de portiques (T3) changent
   l'horizon. Le joueur « voit » sa progression sans lire un chiffre.
5. **Retour tactile** : `Input.vibrate_handheld` court sur achat et ouverture de zone (mobile), rien sur PC.
6. **Rien ne bloque** : chantier passable, pancarte touchable qui ouvre la fiche de la zone (ce qu'elle apporte, sa condition),
   une seule pastille « ! » à l'écran (règle de l'étude).

## 5. Coût révisé

| Lot | Contenu | Sessions |
|---|---|---|
| M1 Terrain et zones (Godot) | `Layout` en polygones et zones, texture de distance, états, pancartes, cadrage par zone, chantier animé | 1,5 |
| M2 Trajets (Godot) | Chenal, mouillage devant la passe, circuit des camions, chargement visible, test « aucun trajet ne traverse rien » | 1 |
| M3 Chapitres (Godot) | `unlocks.json` par niveau de service, cartes « Améliorer » du chapitre, gestes optionnels parc/gate, mesure à la sonde | 1 + 0,5 de mesure |
| Blender | Barges, feux de passe, pancarte, enrochements (les modèles des phases 2 et 3 continuent dans le cloud) | 0,5 |
| **Total** | | **≈ 4,5** (le plan annonçait 1,5 × le plan A ≈ 4,5 : tenu, mais la part Blender passe de 1 à 0,5) |

## 6. Plan coté de départ (celui du prototype, à valider ou corriger)

Repère du jeu : x vers l'est, z vers le sud (la caméra), mer en z négatif, quais à z = −6.

- **Côte** : plage ouest (−132, 60) → (−94, 48) ; **cap** (−92, 24) → (−86, −16) → pointe (−70, −42) → (−56, −30) ; **crique**
  (−56, −14) → (−48, −6) ; **quais** z = −6 de x = −48 à 48 ; **baie est** (48, 32) → (100, 44) → (152, 36) → (186, 50).
- **Brise-lames** x 0 → 38, z −46 → −42 ; **passe** entre la pointe du cap et le brise-lames, feux à (−56, −44) et (−4, −48).
- **Chenal** (−16, −110) → (−30, −70) → (−34, −52) → (−30, −32) → bassin d'évitage (−24, −18) → quai. **Mouillage** à déplacer
  devant la passe (§ 3.3).
- **Zones** : 1 Vieux port x −48…0, z −6…24 · 2 Quai allongé x −12…0 · 3 La Porte x −30…−6, z 24…48 · 6 Terminal x 0…48,
  z −6…30 · 7 Pôle froid x 12…48, z 30…44 · 8 Porte n° 2 et parkings x −24…6, z 48…84 · 9 Colline du port x −48…−30, z 24…48 ·
  10 Terre-plein x 48…126, z −6…30 · 11 Zone sensible x 126…150, z −6…30 · 12 Gare et logistique x 30…126, z 84…126.
- **Routes** : accès x −24…−18 de z 30 à 138 ; autoroute z 138…144 ; village inchangé.

## 7. Décisions à prendre (réduites à quatre)

1. Le prototype devient la base du plan coté (§ 6), terrain polygonal dans Godot (§ 3.1) ?
2. Chapitres fermés au **niveau 10 du service** et non à l'embauche (§ 3.5) ?
3. Mouillage **devant la passe**, visible d'un glissement (§ 3.3) ?
4. Gestes parc et gate **optionnels** à recharge, et pas de fusion Capitainerie + Quais (§ 3.6, 3.7) ?

Après validation : plan coté définitif (une page, toutes les cases), puis ordres de mission M1 et M2 en parallèle, M3 ensuite,
test humain sur APK.
