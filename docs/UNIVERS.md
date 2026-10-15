# Port Horizon — Bible de l'univers

## Le monde
**Mer d'Ambre**, fictive. Le port est **au fond du golfe d'Ambre** (lot F, 14/10) : ce n'est pas une île. La rive d'en face
se devine au large, au nord, dans la brume : des collines et un phare. Une forêt de pins borde toute la terre, et l'autoroute,
la route du village et la voie ferrée s'enfoncent sous les arbres.

Le joueur hérite de **la crique de sa grand-tante Odette**, pêcheuse. Il y trouve un ponton pourri, une cabane, des voisins
pêcheurs et, de l'autre côté du cap, une friche et une estacade en ruine. Il veut en faire une affaire rentable. Devenu·e
**directeur·rice du terminal** de *Port Horizon*, il·elle transforme la friche, palier après palier, en terminal national.
Ton : chaleureux, humoristique, jamais cynique. Aucune marque, aucun drapeau réel.
Ports d'origine fictifs : Nordhaven, Sakura Bay, Port Aurore, Cap Zéphyr, Rio Verde.

### Odette, la crique et l'anse des pêcheurs
- **Odette** : la grand-tante, pêcheuse, disparue. Sa lettre passe par le notaire : « Fais-en quelque chose de bien. Et nourris
  les goélands. » Sa cabane (`odette_hut`) reste au bord de l'anse, à côté de son ponton.
- **L'anse des pêcheurs** : à l'ouest du cap, entre le cap et la rive ouest du golfe (plage ouest). Les voisins y ont leurs
  barques. C'est le lieu du **chapitre 1 « La Crique »** (lot G1, 15 à 20 min) : on répare le ponton d'Odette, les barques du
  village louent ses places et **paient leur loyer à chaque retour** ; au début on l'encaisse à la main (toucher le bateau ; s'il
  attend trop, il repart sans payer), puis **Marcel**, patron pêcheur en ciré jaune, s'en charge (premier responsable du jeu, et
  l'objectif de la première session : avant lui, le monde se fige quand on part). On agrandit : des **places au ponton** (une
  barque par place, le ponton s'allonge), des **services à quai** (criée au niveau 1 — le mareyeur vient en camionnette —, pompe
  à carburant, aire de lavage, fabrique de glace : l'escale coûte plus cher), le **quai des chalutiers** (deux chalutiers, ×3),
  la **grande jetée** (le thonier du large, ×10), la **marina** et ses deux extensions (6, 12, 20 voiliers qui paient leur
  anneau sans qu'on y touche). Tout au maximum, la pêche plafonne (≈ 4,2 $/s) et continue pour toujours ; on peut revenir la voir.
- **Les nuages** : pendant la Crique, tout le reste du golfe est sous des bancs de nuages épais et opaques (la friche, le bassin, le
  village, le large au-delà du passage des caboteurs). Ils se dissolvent à la signature de la Concession.
- **Corsaire & Fils** annonce le port : à la 8ᵉ minute, un de leurs caboteurs passe au large, cherche un quai, « et il
  repassera » ; la première mission du jeu, « Signer la Concession du terre-plein », désigne l'achat (500 $, dès la marina : de loin l'achat
  le plus cher de la Crique).
- **La Concession du terre-plein** : l'acte de l'État qui livre la friche d'Odette, de l'autre côté du cap. Sa signature lève les
  nuages, la caméra passe le cap, et les chantiers du vieux quai commencent (chapitre 2, lot G2).
- **La narratrice** : Capitaine Mathilde Roche. Elle tenait la capitainerie « du temps où il y avait un quai ». Elle lit la
  lettre, présente les voisins, puis lance les chantiers.
- **Le départ** (lots F2, F3, G1) : trois cartes d'intro (`tiers.json`, palier 0 : la lettre, l'anse, « répare le ponton »),
  la Crique dans l'anse (15 à 20 min, 12 à 17 pour un joueur pressé), l'annonce du port à la 8ᵉ minute, puis la bascule à la
  Concession : les nuages se dissolvent, le caboteur de Corsaire & Fils revient du large, la cérémonie « Palier 1 — Le Vieux
  Quai », et la friche se bâtit sous nos yeux en une douzaine de secondes (le vieux quai et sa capitainerie, la grue mobile, le
  parc et son hangar, la route et la gate, chantiers qui se chevauchent). Le caboteur entre au port.

## La vie d'un navire (fil rouge)
1. **Rade** (Capitainerie) — le navire annonce son escale et attend. Patience limitée. 😊 → 😐 → 😠 → départ furieux.
2. **Pilotage et accostage** (Capitainerie) — pilote, remorqueur, lamaneurs. Le brouillard suspend le pilotage.
3. **À quai** (Quais) — nombre de postes, tirant d'eau (un panamax exige un quai profond).
4. **Formalités** (Douane) — l'État contrôle ; le joueur finance la *capacité* et choisit la *politique*.
5. **Déchargement** (Portiques) — mouvements par heure par grue ; le vent fort arrête les grues.
6. **Transfert quai → parc** (Parc et manutention) — engins.
7. **Stockage** (Parc) — au-delà de 65 % de remplissage, le rendement chute (remaniements).
8. **Sortie** (Gate) — camions ; un camion bloqué klaxonne.

## Cargaisons (code visuel)
| Type | Valeur | Visuel |
|---|---|---|
| Standard | ×1 | conteneurs multicolores |
| Frigorifique | ×2,5 | blanc/bleu givré |
| Dangereux (IMO) | ×3 | rouge/orange, losange |
| Hors-gabarit | ×4 | plateau gris/jaune |
| Vide | ×0,3 | gris désaturé |

## Navires
Caboteur (T1) · Feeder (T1–T2) · Panamax (T2–T3, quai profond + portique STS). Post-Panamax et ULCV : hors MVP.

## Armateurs (fictifs)
| Armateur | Profil | Exige | Paye | Fraude |
|---|---|---|---|---|
| Corsaire & Fils | familial, caboteurs | peu | correct, fidèle | faible |
| Nordhaven Lines | fiable, gros navires | ponctualité | bien | faible |
| Sakura Bay Shipping | frigo, électronique | délais, températures | très bien | faible |
| Grand Large Cargo | volume, bas coûts | prix bas | peu | **élevé** |
| Chimex Maritime | chimie, IMO | conformité stricte | très bien | moyen |

Chaque armateur a une **relation 0–100** : elle module la patience de ses capitaines et ouvre ses contrats.

## La douane est l'État
Le joueur ne corrompt, ne juge, ne saisit jamais. Il finance la capacité d'inspection et règle une politique
(Minimale · Standard · Renforcée · Totale) : plus de contrôle = moins de risque, plus de retard.

## Responsables (automatisent un département)
| Responsable | Département | Palier |
|---|---|---|
| Marcel, patron pêcheur | La Crique (loyers de la pêche) | T0 |
| Capitaine Mathilde Roche | Capitainerie | T1 |
| Léon « Gros-Bras » Barbier | Quais | T1 |
| Yasmine Okafor | Portiques | T1 |
| Inspecteur Paul Delmas | Douane | T2 |
| Nadia Benali | Parc et manutention | T2 |
| Tonio Ferrer | Gate | T2 |

(Dr Inès Lambert — qualité/sanitaire, Ingénieur Kenji Mori — IT : réservés T3+/T4.)

## Paliers
| Palier | Nom | Récit |
|---|---|---|
| T0 | La Crique | l'anse des pêcheurs sous un ciel bouché partout ailleurs : loyers à la main puis Marcel, places, services, chalutiers, jetée, marina ; la Concession du terre-plein lève les nuages (chapitre 1, lot G1) |
| T1 | Le Vieux Quai | rebâtir la friche derrière le cap : vieux quai, grue mobile, parc en gravier, gate ; douane en cabane |
| T2 | Port régional | quai 2, premier portique STS, parc bitumé, gate, frigo |
| T3 | Terminal national | quais 3–4, scanner, zone IMO, rail, contrats nationaux |

## Règles de cohérence (toute mécanique)
1. Une cause réelle · 2. Un goulot visible · 3. Un levier · 4. Un visuel dans le diorama.

## Le port sur la carte : la baie et le terre-plein (13/10)
Un petit port de pêche abrité derrière un cap devient, palier après palier, un terminal gagné sur la mer, d'ouest en est.
Plan coté : `docs/PLAN_COTE.md`. Dix quartiers (l'anse des pêcheurs depuis le lot F3), chacun avec son sol, sa couleur et son repère vertical :

| Quartier | Où | Sol | Repère | Ambiance |
|---|---|---|---|---|
| **Anse des pêcheurs** | à l'ouest du cap (lots F3, G1) | plage, ponton de bois, jetée de béton, pontons flottants | criée rayée bleu et blanc, cabane d'Odette, Marcel en ciré jaune | barques, chalutiers, thonier, voiliers, caisses de poisson, camionnette du mareyeur |
| **Vieux port** | crique derrière le cap | planches, gravier beige | phare rouge et blanc, grue mobile | mouettes, cordages (les bateaux de pêche sont dans l'anse) |
| **La Porte** | entre le parc et la route | béton clair, bandes jaunes et noires | barrières, portique scanner | bips, moteurs au ralenti |
| **Colline du port** | butte derrière le vieux port | herbe vive | tour de contrôle (T2) | calme, drapeaux |
| **Terminal** | au centre, côte droite | asphalte violet | premier portique bleu | engins, signaux de recul |
| **Pôle froid** | au bout du Terminal | béton bleu glacier | racks frigorifiques | ronronnement des groupes froids |
| **Terre-plein** | gagné sur la mer à l'est (T3) | asphalte violet, enrochements | rangée de grands portiques | grandeur, activité dense |
| **Zone sensible** | pointe du terre-plein | sol brique, clôtures | sphères de GNL | sirènes lointaines |
| **Gare et logistique** | arrière-pays, à l'est | ballast, entrepôts | locomotive, silo | klaxon de train |
| **Village** | colline ouest, derrière les arbres | rues, trottoirs | boutique | vie civile |

Les navires mouillent devant la passe, entrent entre le feu vert du cap et le feu rouge du brise-lames, suivent le chenal
balisé, pivotent au bassin d'évitage et accostent le long du quai ; ils repartent par l'est. Les camions sortent de la forêt
à l'ouest (l'autoroute passe sous les arbres), passent la gate, chargent le long du parc et repartent dans la forêt à l'est.
Rien ne roule ni ne navigue sans le bâtiment qui le crée : pas de cargo sans quai, pas de camion sans gate. Seules quelques
voitures passent sur l'autoroute dès le départ. Le palier 1 se raconte en quatre chapitres : le petit quai, le parc, la
gate, faire venir les navires.
