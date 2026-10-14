# Étude — plan de la carte, progression et circulation (13/10/2026)

Proposition du chef de projet après le test de l'APK. **Rien n'est encore modifié** : ce document attend une validation.

## 0. Les quatre reproches, et leur vraie cause

| # | Ce que le joueur voit | Cause dans le projet |
|---|---|---|
| 1 | Carte anarchique, pas de plan, on ne voit pas ce qui viendra | La carte a été remplie au fil des besoins, sans plan d'ensemble. Exemples : la tour de contrôle est à l'est (x = 42), la capitainerie à l'ouest (x = −43), le centre informatique tout au bout (x = 138), la halle d'inspection derrière la douane. Les parcs du T2 et du T3 sont intercalés. Aucun emplacement futur n'est dessiné (le lot C des « lots fantômes » n'est pas fait). |
| 2 | Tout est mélangé, on ne suit pas « je clique → j'embauche un responsable → c'est automatique » | Les 6 services (Capitainerie, Quais, Portiques, Parc, Gate, Douane) n'ont pas chacun leur **place** sur la carte. Il n'y a que deux gestes manuels (toucher un navire, coup de main à la grue). Les responsables s'ouvrent tous ensemble au 9ᵉ navire, au lieu d'arriver service par service. |
| 3 | Trop de choses à améliorer et à construire dès le départ | `unlocks.json` ouvre les systèmes **au nombre de navires** : environ 11 systèmes avant le 16ᵉ navire (Gestion au 2ᵉ, Parc et Gate au 4ᵉ, étoiles au 5ᵉ, licences au 6ᵉ, statistiques au 8ᵉ, responsables au 9ᵉ, Commerce au 10ᵉ, Heures sup au 12ᵉ…). Le joueur reçoit un nouveau sujet avant d'avoir compris le précédent. |
| 4 | Camions qui apparaissent et disparaissent, routes mélangées, navires qui entrent dans la terre | **Camions** (`traffic_view.gd`) : le camion vide disparaît juste après la barrière, et un camion chargé apparaît à sa place. Il n'y a ni trajet jusqu'au parc ni chargement. **Routes** : la route d'accès traverse la terre du port, et il n'y a pas de circuit. **Navires** (`ship_view.gd`) : les trajets sont des courbes directes entre des points (apparition, rade, approche, quai, sortie). Aucun chenal n'est défini, si bien qu'un navire peut passer sur le phare, le brise-lames, la terre ou un autre navire. |

Les points 1 et 4 ont la même cause : **il n'y a pas de plan de masse**. Les points 2 et 3 ont aussi une cause commune : **les services ne sont pas présentés un par un**.

## 1. Principe directeur : « une chaîne, une bande par maillon »

Un port est une chaîne : **navire → quai et grue → parc → (douane) → gate → camion**. ISM marche parce que la chaîne se lit sur l'écran : entrée → rayons → caisses → sortie. Chaque poste y a son comptoir et sa chaise de gérant, et les rayons à venir sont déjà dessinés en gris avec leur prix.

On applique la même idée au port :
- **la carte se lit de la mer vers la route**, toujours dans le même ordre, en bandes parallèles au quai ;
- **chaque maillon a sa bande et son poste** : un sol délimité, la couleur de son service, son geste manuel, et la place de son responsable, visible et vide tant que personne n'est embauché ;
- **le port grandit par travées identiques vers l'est** : une travée = un poste à quai, sa part de parc et sa part de voie camions. Une nouvelle travée est l'équivalent d'un nouveau puits dans Idle Miner ;
- **tout ce qui viendra est dessiné dès le départ**, en gris, avec sa condition. Le joueur voit la carte complète de son futur port.

## 2. Solution au point 1 — un plan de masse

### Plan A recommandé : bandes et travées (on garde la géométrie actuelle, quai le long de X)

Du large vers la terre :

| Bande | Profondeur (z) | Contenu |
|---|---|---|
| Mer | z < −6 | Rade (bouées de mouillage numérotées) au nord-ouest, **chenal balisé** (bouées rouges et vertes), bassin d'évitage devant les quais |
| Quai et tablier | −6 → 8 | Postes à quai, grues puis portiques sur leurs rails, bollards |
| Parc | 8 → 34 | Blocs de conteneurs alignés sur des travées de 4,4 u ; engins **côté mer uniquement** |
| Voie camions | 34 → 40 | Voie à **sens unique** le long du parc ; les camions chargent **côté terre** des blocs |
| Contrôle | 40 → 52 | Douane, scanner, halle d'inspection, gate (entrée et sortie séparées) |
| Accès | 52 → 138 | Route d'accès à deux voies, aire d'attente, puis terre ferme (village à l'ouest, logistique et rail à l'est) |
| Autoroute | 138 → 144 | Inchangée |

Dans la largeur, d'ouest en est :

| Zone | Étendue (x) | Palier | Contenu |
|---|---|---|---|
| Îlot administratif | −84 → −36 | T1 → T3 | Vieux port de pêche, phare, capitainerie (T1) ; la tour de contrôle et le bureau la rejoignent au T2, le centre informatique au T3. **Tout le pilotage au même endroit.** |
| Travée 1 | −36 → 12 | T1 | Quai n° 1 (puis son allongement), grue, petit parc, gate et douane |
| Travée 2 | 12 → 60 | T2 | Quai n° 2, portique, parc asphalté avec la zone frigo |
| Travées 3 et 4 | 60 → 156 | T3 | Quais 3 et 4, parcs RTG, zones IMO et hors-gabarit ; rail et logistique derrière |

**Règle d'or** : ce qui est construit plus tard se place **dans la case déjà prévue** pour lui, jamais « là où il reste de la place ».

**Lots réservés** (ancien lot C) : chaque futur bâtiment, parc ou travée est dessiné dès le départ (contour en pointillés, petite pancarte avec l'icône du service et sa condition, par exemple « Palier 2 »). Les travées verrouillées sont des terrains vagues clôturés. Toucher un lot ouvre sa fiche (ce que c'est, ce qu'il faut pour l'obtenir).

### Plan B : port en bassin (darse)
Les quais entourent un bassin sur trois côtés. Le plan est plus compact, tient mieux en portrait et donne un rendu plus spectaculaire. Mais il faut des angles de quai, des manœuvres de navires plus difficiles et un nouveau modèle de terrain, et l'agrandissement se lit moins bien (où va la travée suivante ?). **Coût environ deux fois celui du plan A.** Je le déconseille pour l'instant.

## 3. Solution au point 2 — chaque service devient un poste, présenté un par un

Chaque service suit le même cycle, que le joueur reconnaît dès le deuxième :

1. **Il s'allume** : sa zone passe du gris à la couleur de son service. La caméra se cale dessus et la narratrice dit une phrase.
2. **Geste manuel** : le joueur fait le travail à la main.
   - Navire : toucher pour l'accoster (existe déjà).
   - Grue : maintenir pour décharger (existe déjà).
   - Parc : toucher le cavalier pour qu'il range plus vite (**nouveau**).
   - Gate : toucher la barrière pour faire passer un camion (**nouveau**).
   - Douane : toucher un conteneur pour l'inspecter (**nouveau**, au T2).
3. **Améliorer** : le joueur monte le niveau de ce service.
4. **Responsable** : au niveau 10 du service, **sa** chaise vide se débloque. Embaucher remplace le geste, et le service tourne seul, même quand le joueur est absent.
5. **Le service suivant s'allume**, parce que la demande a grandi et qu'il devient le goulot.

Avant d'être présenté, un service **fonctionne seul au minimum** (sa zone est grise et il ne demande rien). Son débit doit être réglé pour ne jamais bloquer la chaîne avant son tour. On vérifiera ce réglage avec la sonde d'équilibrage (`tests/pacing_probe.gd`).

**Simplification proposée** : la Capitainerie et les Quais font la même chose aux yeux d'un débutant (« faire accoster »). Au T1, on les présenterait comme un seul poste « Accostage », et ils se sépareraient au T2. (Ce point est à valider, il touche la simulation.)

## 4. Solution au point 3 — on débloque quand le joueur a compris, pas au nombre de navires

On remplace les conditions « au N-ième navire » par des conditions de **maîtrise** (« responsable de la grue embauché », « grue au niveau 10 »). Le palier 1 est découpé en chapitres :

| Chapitre | Ce qui est visible | Débloque le chapitre suivant |
|---|---|---|
| 1. Le petit quai | Argent, navire, grue, « Améliorer » avec **deux** cartes | Grue au niveau 10, puis 1ᵉʳ responsable (la grue) |
| 2. Le parc | Le Parc s'allume, avec son geste et son responsable | Responsable du parc embauché |
| 3. La gate | La Gate s'allume ; la chaîne complète tourne seule ; **gains hors ligne** expliqués | Responsable de la gate embauché |
| 4. Faire venir les navires | Allongement du quai, Commerce, Missions, Ambre, étoiles | Conditions de palier 2 |
| Palier 2 | Douane, contrats, licences, Heures sup, aléas, statistiques, Gestion complète | (inchangé) |

Règles d'interface :
- **un seul sujet nouveau à la fois** ;
- au plus **une** pastille « ! » à l'écran ;
- « Améliorer » montre les cartes du chapitre en cours, plus **une** carte grisée « à venir » ;
- au départ, le HUD n'a que **3 boutons**.

Le palier 1 durera probablement plus longtemps qu'aujourd'hui (15 à 20 min au lieu de 12 à 15). La sonde mesurera cette durée avant qu'on la règle.

## 5. Solution au point 4 — des trajets physiques et lisibles

**Le conteneur suit un seul trajet visible** : navire → grue → tablier → cavalier → bloc du parc → camion → gate → autoroute. Les mouvements restent un **habillage visuel** : la simulation ne change pas, l'animation se cale sur ses comptes.

**Camions — un circuit à sens unique** :
1. Ils arrivent par l'autoroute, prennent la voie d'entrée de la route d'accès et attendent sur l'aire si besoin.
2. Ils passent la gate d'entrée.
3. Ils suivent la voie camions jusqu'au bloc qui les sert, où un conteneur est posé sur la remorque (le camion repart **visiblement chargé**).
4. Ils continuent la boucle jusqu'à la gate de sortie, puis prennent la voie de sortie vers l'autoroute.
- Les camions n'apparaissent et ne disparaissent qu'**hors de l'écran**, au bout de l'autoroute.
- Deux règles de vrai port : **côté mer = engins, côté terre = camions**, et leurs trajets ne se croisent jamais. Le village a ses propres rues, qui ne sont pas reliées au port.

**Navires — un chenal** :
1. Ils apparaissent au loin, hors de l'écran.
2. Ils jettent l'ancre en rade, sur une bouée numérotée, hors du chenal.
3. Ils entrent par la passe ouest du brise-lames, en suivant les bouées rouges et vertes.
4. Ils pivotent dans le bassin d'évitage avec le remorqueur, puis accostent **parallèlement** au quai.
5. Ils repartent par la passe est.
- Les trajets sont des suites de points fixes, définies une fois dans `Layout`.
- **Un test automatique** vérifiera qu'aucun trajet (navire, camion, engin) ne traverse la terre, un bâtiment ou un autre trajet.

## 6. Organisation proposée

| Étape | Qui | Contenu |
|---|---|---|
| 0 | Chef de projet | Plan de masse détaillé coté (vue de dessus, toutes les cases réservées) : **ta validation** |
| M1 | Développeur | Nouvelle `Layout` construite à partir du plan (zones, cases, chemins) ; lots réservés et services gris ; caméra |
| M2 | Développeur | Circuit des camions, chenal des navires, trajet visible du conteneur, test « aucun trajet ne traverse rien » |
| M3 | Développeur | Chapitres : `unlocks.json` par maîtrise, responsables service par service, 3 nouveaux gestes, Améliorer réduit ; réglages à la sonde |
| Blender | Expert Blender | Les modèles des phases 2 et 3 continuent (ils servent quel que soit le plan). **On sort de la phase 2 les sols et marquages** (asphalte, parking, marquages de parc), à refaire aux cotes du nouveau plan. Nouveaux modèles : bouées de chenal rouge/verte, feux de passe, contour de lot réservé, pancarte « à venir », clôture de terrain vague, flèches et voies peintes, chaise ou kiosque de responsable |
| Test | Toi | Nouvel APK, test humain de 20 min |

Ordre : 0 → M1 → (M2 et M3 en parallèle) → test. La sauvegarde reste compatible : les bâtiments sont enregistrés par identifiant, pas par position. Seuls les nouveaux chapitres demandent une conversion (un joueur déjà avancé voit tout allumé).

## 7. Décisions à valider

1. **Plan A** (bandes et travées), ou plan B (bassin) ?
2. **Les services à venir sont visibles en gris**, plutôt que cachés ?
3. **Déblocage par maîtrise** (chapitres), en acceptant un palier 1 un peu plus long ?
4. **Trois nouveaux gestes manuels** (parc, gate, douane) et **un responsable par service** au niveau 10. C'est une nouvelle mécanique, alors qu'on avait dit « aucune nouvelle mécanique avant le test ». Ton test justifie l'exception.
5. **Fusionner Capitainerie et Quais au T1** en un poste « Accostage » (oui / non / plus tard) ?
6. **Prévenir la session cloud** de ne pas faire les sols et marquages de la phase 2.
