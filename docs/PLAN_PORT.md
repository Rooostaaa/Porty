# Plan du port — « La baie et le terre-plein » (proposition de design, 13/10/2026)

Ce plan remplace les plans A et B du § 2 de `ETUDE_CARTE.md`. Les §§ 3 à 5 de cette étude restent valables : un poste par service, des
chapitres, des trajets à sens unique. **Rien n'est modifié dans le jeu tant que ce plan n'est pas validé.**

## 1. L'idée en une phrase

**Un petit port de pêche abrité derrière un cap devient, palier après palier, un grand terminal gagné sur la mer.** La carte raconte
cette histoire d'ouest en est. Le joueur voit dès le départ, en gris, tout ce qu'il pourra construire.

Pourquoi cette idée :
- **la géographie justifie le port** : un cap avec son phare et une digue abritent une crique. C'est là que les premiers bateaux
  accostent, comme dans les vrais ports anciens ;
- **le port grandit comme les vrais ports** (Rotterdam, Tanger Med) : vers le large, sur des terres gagnées sur la mer, là où l'eau est
  profonde pour les grands navires. Au palier 3, le joueur **voit la mer devenir terre**. C'est un moment fort, que le décor rend
  évident sans explication ;
- **la sécurité organise le plan** : ce qui est dangereux (matières dangereuses, gaz) est au bout du terre-plein, loin du village ;
  le village est derrière une ceinture verte ; l'administration est sur une butte qui voit tout.

## 2. Les quartiers

Chaque quartier a **son sol, sa couleur, son repère vertical et son ambiance**. On reconnaît le quartier sans lire un mot (règle de
la direction D).

| Quartier | Où | Sol et couleur | Repère vertical | Registre | Ambiance |
|---|---|---|---|---|---|
| **Vieux port** | Crique à l'ouest, derrière le cap | Planches de bois, gravier beige | Phare rouge et blanc, grue mobile | Nordique, bois | Mouettes, cordages, bateaux de pêche |
| **La Porte** | Entre le port et la route | Béton clair, bandes jaunes et noires | Barrières, portique de contrôle | Industriel | Bips, barrières, moteurs au ralenti |
| **Colline du port** | Butte derrière le vieux port | Herbe, allées | **Tour de contrôle** (palier 2) | Nordique moderne | Calme, drapeaux |
| **Terminal** | Au centre, côte rectiligne | Asphalte violet, marquages blancs | Premier portique bleu | Industriel pop | Engins, signaux de recul |
| **Pôle froid** | Derrière le terminal | Béton bleu glacier | Racks frigorifiques | Industriel | Ronronnement des groupes froids |
| **Terre-plein** | Gagné sur la mer à l'est | Asphalte violet, enrochements | **Rangée de grands portiques** | Industriel pop | Grandeur, activité dense |
| **Zone sensible** | Pointe du terre-plein | Sol rouge brique, clôtures orange | **Sphères de GNL** | Industriel, danger | Sirènes lointaines |
| **Gare et logistique** | Arrière-pays, vers l'est | Ballast, toits d'entrepôts | Locomotive, silo | Industriel | Klaxon de train |
| **Village** | Colline ouest, derrière une ceinture verte | Rues, trottoirs, jardins | Clocher ou boutique | Nordique, maisons | Vie civile, voitures |

**Silhouette par palier** (la récompense visuelle) :
- **palier 1** : une ligne basse et chaleureuse (le phare, une grue mobile) ;
- **palier 2** : la tour de contrôle et le premier portique donnent de la hauteur ;
- **palier 3** : la rangée de grands portiques et les sphères de GNL forment une vraie ligne d'horizon industrielle.

## 3. Les zones à débloquer (12 zones)

| # | Zone | Palier | Contenu (identifiants du jeu) | Ce qui change à l'écran |
|---|---|---|---|---|
| 1 | Vieux port | 1, départ | Quai n° 1 court, grue, parc en gravier, capitainerie | Tout le reste est visible mais gris |
| 2 | Quai allongé | 1 | `quay_ext` | Les planches s'allongent et les caboteurs arrivent |
| 3 | La Porte | 1 | gate, `customs1` | La barrière s'allume et la douane ouvre son poste |
| 4 | Mouillage | 1 | bouées de rade | Les bouées numérotées apparaissent au large |
| 5 | Chenal dragué | 1 | `dredge1` | Une bande d'eau profonde se dessine jusqu'aux quais : les feeders arrivent |
| 6 | Terminal | 2 | `berth2`, `sts1`, `asphalt` | L'herbe devient asphalte, le premier portique se dresse |
| 7 | Pôle froid | 2 | `reefer` | Le sol bleu glacier et les racks |
| 8 | Porte n° 2 et parkings | 2 | `gate2`, `parking1`, `parking2`, `scanner1` | Seconde voie de gate, parkings poids lourds |
| 9 | Colline du port | 2 | tour de contrôle, bureau, `repair` (centre informatique `tos` au palier 3) | La tour domine le port |
| 10 | Terre-plein | 3 | `berth3`, `berth4`, `rtg`, sous-station | La mer devient terre : barges, sable, puis quais |
| 11 | Zone sensible | 3 | `imo`, `oog`, `lng` | Clôtures orange, sphères de GNL |
| 12 | Gare et logistique | 3 | `rail`, entrepôts | Le train arrive par l'est |

Les agrandissements sans zone propre se font **dans leur zone** : la halle d'inspection et le scanner n° 2 à La Porte ; le pilotage à
distance et l'amarrage par ventouses sur les quais. On ne les place jamais « là où il reste de la place ».

## 4. Les quatre états d'une zone

1. **Grisée** (à venir) : on voit sa forme, désaturée et voilée, avec un contour en pointillés. Pour le terre-plein, on voit la mer
   avec le contour des futurs quais tracé sur l'eau. Toucher la zone ouvre sa fiche : nom, ce qu'elle apporte, condition.
2. **Prochaine** : **une seule à la fois** sur toute la carte. Son contour est doré et animé, et une pancarte porte une icône et un prix.
   C'est la réponse au point 3 : le joueur sait toujours quelle est la prochaine étape, et il n'y en a qu'une.
3. **Chantier** (3 à 5 s, au moment de l'achat) : la caméra se cale sur la zone, puis on voit de la poussière, des engins et des
   éléments qui montent du sol. Pour le terre-plein, des barges déversent du sable. Un son, puis une phrase de la narratrice.
4. **Ouverte** : la zone prend ses couleurs, et ses personnages et engins commencent à travailler.

## 5. Règles de beauté (pour l'expert Blender et le développeur)

1. **Cadre naturel** : le cap et le phare à gauche, des collines boisées au fond, des plages aux bords. **Le diorama ne s'arrête jamais sur
   un bord droit** : des arbres, des rochers et l'écume adoucissent toutes les limites.
2. **Trois hauteurs** : le sol et les accessoires en bas, les bâtiments au milieu, les grues et les repères en haut. Il y a toujours un repère vertical
   par quartier.
3. **Une couleur de sol par quartier** (table du § 2). Les teintes viennent de `palette.json` : les quartiers se lisent par leurs couleurs.
4. **La densité décroît de la mer vers la terre** : l'activité est forte au quai et le calme revient en arrière-pays. Pas de grande surface vide :
   chaque parc reçoit sa trame de marquages et ses conteneurs.
5. **Chaque zone tient dans un écran en portrait** au zoom par défaut. Quand une zone s'ouvre, la caméra la cadre entière.
6. **Bordures nettes entre les quartiers** : un trottoir, une clôture, une haie ou une ligne peinte. Deux sols ne se touchent jamais sans transition.
7. **La vie suit les chemins** : les camions, engins, personnages et navires ne circulent que sur leurs voies (§ 5 de `ETUDE_CARTE.md`).
   Aucun objet n'apparaît ni ne disparaît à l'écran.
8. **Les trajets dessinent aussi le décor** : les passages piétons, les flèches au sol, les bouées du chenal et les feux de passe
   (rouge à gauche, vert à droite en entrant) font partie du joli.

## 6. Ce que ça coûte (par rapport au plan A)

- **Terrain** (expert Blender) : il faut une côte découpée (le cap, la crique, la côte droite du terminal) et le bord du terre-plein
  avec ses enrochements. Il faut aussi les sols par quartier, les clôtures, les pancartes de zone, des barges à sable et des feux de passe.
  Les sphères de GNL réutilisent la pièce du silo. **Les modèles des phases 2 et 3 (bâtiments, engins, navires) restent tous utiles.**
- **Jeu** (développeur) :
  - la carte devient une liste de zones (forme, état, contenu, condition) ;
  - l'eau doit accepter une côte non rectangulaire (aujourd'hui, la terre est faite de rectangles) ;
  - les zones grisées réutilisent la désaturation du shader `vcol` ;
  - il faut une animation de chantier, et un cadrage caméra par zone.
- **Total** : environ 1,5 fois le plan A, mais le plan B (bassin) coûtait le double. C'est le meilleur rapport entre beauté et coût.

## 7. Ordre de travail proposé

1. **Plan coté** (chef de projet) : contour exact de chaque zone en coordonnées du jeu, routes, chenal, emplacements de chaque bâtiment.
   **Tu le valides.**
2. **Terrain et zones** (Blender et développeur en parallèle) : côte, sols, états des zones, et mer qui devient terre.
3. **Trajets** (développeur) : circuit des camions, chenal, trajet visible des conteneurs.
4. **Chapitres et postes** (développeur) : `ETUDE_CARTE.md` § 3 et 4.
5. **Test humain** sur APK.

## 8. Décisions à valider

1. L'histoire « **crique → terminal → terre-plein gagné sur la mer** » et les 9 quartiers ?
2. Les **12 zones** et leur ordre ?
3. Une **seule zone « prochaine »** à la fois, toutes les autres grisées mais visibles ?
4. Le **chantier animé** à chaque ouverture (3 à 5 s, que le joueur peut passer d'un toucher) ?
