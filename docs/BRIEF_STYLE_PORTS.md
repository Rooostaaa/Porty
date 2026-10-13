# Brief — style visuel (référence Idle Supermarket Tycoon) et architecture portuaire

Rédigé le 13/10/2026. Pilotes faits le même jour (capitainerie, douane T1, entrepôt), en version fermée : voir § 3 bis et `docs/previews/style_*.png`.
Captures de référence : `docs/references/ism/01…11_*.png` (portrait, 536×952 ou 607×1080).

## 1. Pipeline existant (rappel)
- Blender 5.2 : `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`, lancé sans interface : `blender --background --python blender/build_assets.py`.
- `blender/lib.py` : classe `Model` (box, boxb, cham, cyl, cylb, ico, prism, tube, beam, hull), couleurs **par sommet** (aplats par face), export `.glb` vers `godot/assets/models/`.
- `blender/palette.json` : seule source des couleurs (`C('nom')`) ; aucune couleur écrite à la main dans les modèles.
- `blender/parts/{terrain,buildings,equipment,ships,cargo,world}.py` ; aperçus dans `docs/previews/*.png`.
- Bâtiments actuels « en coupe » (`_cutaway` dans `parts/buildings.py`) : murs fins (0,2), murs avant à 0,7 de haut, gris/blanc, peu de fenêtres.

## 2. Ce que fait ISM (observé sur les captures)
**Cadrage**
- Iso 45° en lacet, environ 35° de plongée ; caméra **proche** : un bâtiment occupe 70 à 100 % de la largeur d'un écran portrait.
- Port Horizon montre une petite île perdue dans beaucoup d'eau (`docs/captures/cap_world1.png`) : il faut cadrer plus serré.

**Bâtiments en coupe, mais lisibles**
- Murs **épais** (environ 1/12 de la largeur du bâtiment).
- **Chape de mur sombre** gris ardoise `#737594` qui encadre la pièce comme un contour.
- Façade sous la chape :
  - piliers de brique `#9C4931` posés sur un socle sombre `#31344A`, avec un chapiteau crème `#DDCA9C` ;
  - façade ocre `#EDDBAF` ;
  - grandes vitrines bleues `#0793B9` à meneaux.
- Sol intérieur en damier **peu contrasté** (`#D6BAAD` / `#DECBBD`) pour que les personnages et les objets ressortent.

**Accessoires et identité**
- Objets surdimensionnés et produits exagérés (cagettes de bananes énormes).
- Chaque rayon a sa couleur.
- Enseigne en **lettres 3D extrudées** rouges.
- Arbustes cubiques en pot `#009E34` à l'entrée, distributeur de billets, lampadaires, bouche d'incendie, cônes.

**Extérieur**
- Herbe citron vert `#B5E342`, trottoir clair `#D6DBCE`.
- **Asphalte violet** `#5A3E5A`, pas gris.
- Marquages blancs épais `#EFEBEF`, passages piétons.

**Véhicules**
- Formes cubiques, une couleur franche par véhicule, vitres sombres.
- Feux arrière rouges `#D41020` (petites boîtes).
- Toit nettement plus clair que les flancs.

**Lumière**
- Soleil directionnel fort : dessus clairs, flancs à environ 60–75 %.
- Ombres portées **nettes et semi-transparentes** : l'asphalte passe de `#5A3E5A` à `#4E373D` à l'ombre, soit environ −15 %, sans noir.
- Pas de contour dessiné (outline) : c'est la chape sombre qui joue ce rôle.

**Personnages**
- Corps en capsule, grosse tête, t-shirts saturés (`#AB49B7`…), ombre ronde au sol (`#4A4B56`).
- Les **files d'attente** guidées par des barrières rendent le débit visible.

**Retours dans le monde du jeu**
- Minuterie circulaire au-dessus du caissier.
- Nombres verts flottants (« +25 »).
- Pile de billets avec compte à rebours (« 5 000 / 9 s »).
- Totem **P** affichant les places libres : l'information du gameplay est posée sur le décor.

**Progression**
- Un nouveau site repart petit : un rayon, une caisse, beaucoup de sol vide.
- Les sections se débloquent visuellement : Légumes 500, puis Boulangerie 50 000 une fois la précédente construite.
- Chaîne des sites : Ville d'approvisionnement → Marché de la banlieue (avec parking) → Cité commerciale. Les étapes intermédiaires multiplient les profits (×1,25, ×3, ×4).
- Panneau du parking : 6 → 12 places ; « allée » 8 clients/min ; la publicité augmente le nombre de clients par minute.

**Interface**
- En-tête bleu, cartes blanches.
- Boutons verts quand l'achat est possible, gris sinon.
- Une main de tutoriel pointe l'action attendue.

## 3. Règles à appliquer aux modèles de Port Horizon
1. **Bâtiments fermés par défaut** (voir § 3 bis) : toit-terrasse clair cerné d'une **chape-acrotère sombre** débordante (`closed_block`). La coupe à murs épais (`wall_cutaway_thick`) est réservée au cas où le jeu ferait vivre l'intérieur.
2. Façades structurées : socle sombre, piliers avec chapiteau clair, grandes baies vitrées à meneaux ; une couleur d'identité par bâtiment (toit, auvent ou enseigne).
3. Une **silhouette unique** par bâtiment, reconnaissable en petit : tour, mât, auvent, enseigne 3D, objet emblème (scanner, grue).
4. Sol intérieur peu contrasté ; objets et personnages saturés par-dessus.
5. Objets et détails exagérés (×1,3 à ×1,5) : bollards, défenses, panneaux, plots, lampadaires, pots de fleurs.
6. Sols extérieurs : asphalte teinté (violet ou bleu-gris chaud, pas gris neutre), marquages épais, herbe vive.
7. Ombrage par face plus marqué (dessus 100 %, flancs 65–75 %) et ombres nettes non noires dans Godot.
8. Cadrage plus serré et moins d'eau à l'écran.
9. Informations de jeu posées sur le décor : jauges, minuteries, compteurs (places de l'aire camions, file en rade).
10. Ajouter dans `palette.json` les teintes `wall_cap`, `brick`, `plinth`, `capital`, `facade`, `asphalt_violet`, `grass_lime`, `sidewalk`, `tile_a` et `tile_b`, puis ajouter à `lib.py` des pièces réutilisables : `wall_cutaway_thick`, `pilaster`, `window_band`, `awning`, `sign3d`, `planter`.

Méthode : refaire 2 ou 3 bâtiments pilotes (capitainerie, douane, entrepôt), faire le rendu `docs/previews/` en vue avant/après, puis le valider avec l'utilisateur avant de tout généraliser.

## 3 bis. Intérieurs ouverts ou fermés, et cohérence (analyse du 13/10/2026)
**Constat dans le jeu**
- Aucun mouvement de jeu ne se passe dans un bâtiment. Personnages fixes qui oscillent sur place, autour des bâtiments ; inspections douanières dans le parc (lots qui clignotent) ; informations en bulles au-dessus (`world_overlay.gd`) ; marqueur de goulot = anneau de 4 u de rayon au sol, autour du bâtiment.
- Échelle d'affichage : vue de 52 u de large par défaut (28 au plus près). Un bâtiment de 4–5 u occupe 9 % de l'écran (16 % au plus près) : un intérieur y est illisible. Chez ISM l'intérieur EST le jeu (clients, rayons, caisses) et le bâtiment remplit l'écran.
- Rotations du plan (`layout.gd`) : l'entrepôt T3 et le hangar sont posés à 90°. Un modèle en coupe tourné de 90° présente son mur du fond haut à la caméra : la coupe ne montre plus rien.

**Règle** : un bâtiment n'est ouvert que si le jeu y fait se passer quelque chose de visible. Aujourd'hui, aucun. Les typologies naturellement ouvertes (toit sur poteaux, porte de quai ouverte) restent ouvertes.

| Asset | Rôle | Rotation | Décision |
|---|---|---|---|
| `harbor_office` | Capitainerie T1 | 0° | **Fermé — fait.** Belvédère vitré à toit bleu, pavois, bouée |
| `customs_hut` | Bureau de douane T1 | 0° | **Fermé — fait.** Enseigne DOUANE, auvent, table d'inspection |
| `warehouse` | Logistique ×2, T3 | 0° / 90° | **Fermé — fait.** Quai, une porte ouverte sur des cartons, sheds |
| `hangar` | T1 et logistique | 90° | Hangar ouvert : toit sur poteaux, sans murs (lisible sous tous les angles) |
| `office` | Bureaux T2 | 0° | Fermé, 2 niveaux |
| `customs_office` | Douane T2 | 0° | Fermé, même langage que `customs_hut` |
| `workshop` | Atelier engins | 0° | Fermé, grande porte ouverte sur un engin |
| `inspection_hall` | Douane T3 | 0° | Halle à un long côté ouvert, conteneur en cours d'inspection visible |
| `it_center` | Informatique T3 | 0° | Fermé, antennes et parabole en toiture |
| `control_tower`, `gate_booth` | T2, gate | 0° | Déjà fermés : restyler seulement |
| `substation`, `reefer_rack`, `imo_fence`, `rail_terminal`, `scanner`, `barrier` | structures | — | Sans murs : restyler seulement |

**Cohérence à tenir**
- Échelle : conteneur 40' = 4 × 1,3 × 1,3 u (1 u ≈ 3 m) ; personnages exagérés à 1,35 u. Étage 2,5–2,7 u, porte 1 × 1,75 u, porte de quai 2,2 × 2,5 u (camion 2,2 u de large).
- Face principale (porte, enseigne) en **-Y** : visible aux rotations 0° et 90°. Faces ±X traitées, fond +Y nu.
- Une couleur par **département**, partagée par ses bâtiments de tous les paliers : capitainerie bleu, douane marine + jaune, gate orange, parc jaune, zone logistique vert.
- Pas de doublon de silhouette entre les paliers d'un même département : belvédère bas pour la capitainerie T1, la tour haute reste à la T2.
- Laisser libre la place du responsable embauché, à droite devant le bâtiment : `dept_pos + (3, 0, 3)` dans Godot, soit (3, -3) dans Blender. Le douanier est posé devant la table d'inspection (`diorama.gd`).

## 4. Architecture d'un port (pour contextualiser et enrichir)
**Zones, de la mer vers la terre**
1. **Accès maritime** : chenal d'entrée balisé (bouées), brise-lames, phare.
2. **Plan d'eau** :
   - rade ou mouillage où les navires attendent un poste ;
   - chenal intérieur ;
   - **cercle d'évitage** (environ 2 × la longueur du plus grand navire) ;
   - bassin d'accostage dragué.
3. **Quai et postes** : bollards, défenses, profondeur (tirant d'eau). Un quai est parallèle au rivage, une jetée (pier) lui est perpendiculaire.
4. **Terre-plein (apron)** : bande entre le quai et le parc, avec les rails des portiques STS et la circulation des tracteurs.
5. **Parc à conteneurs** : blocs import, export, transbordement, **vides** (empilés en blocs denses), **frigo** (prises électriques, racks), **IMO** (zone séparée, clôturée, surveillée).
6. **Gate** : voies d'entrée et de sortie, pont-bascule, kiosques, bâtiment de contrôle, pré-annonce des camions.
7. **Rail** : faisceau sur le quai, chargé par RMG ou reach stacker, qui travaille en même temps que le navire.
8. **Annexes** :
   - atelier engins, sous-station, informatique, bureaux ;
   - douane avec scanner et halle d'inspection ;
   - **CFS** (groupage et dégroupage des envois de moins d'un conteneur, dits LCL) ;
   - dépôt de vides (réparation, tri).
9. **Interface ville-port** : parking tampon pour camions (évite les bouchons au gate), zone logistique (entrepôts) servant de tampon avec les habitations.

**Engins (ordres de grandeur)**
| Engin | Dimensions | Capacité / usage |
|---|---|---|
| Portique STS | portée 48–65 m, levage 33–41 m, écartement 18–30 m | Panamax : 13 rangées ; post-Panamax : 16 rangées |
| RTG (sur pneus) | 6–7 rangées + 1 voie camion | empile 1 sur 5 ou 6 |
| RMG (sur rails) | portée environ 36 m | rail ou parc, 1 sur 5 |
| Cavalier (straddle carrier) | — | empile 1 sur 3, transporte seul |
| Reach stacker | — | 3 pleins (4–5 vides), environ 500 EVP/ha |
| Tracteur de terminal | — | tire les remorques entre quai et parc |

**Services nautiques**
- **Capitainerie / autorité portuaire** : fixe les règles et attribue les postes.
- **VTS** : tour de surveillance du trafic.
- **Pilotage** : le pilote guide le navire de l'entrée au poste ; il est obligatoire au-delà d'une certaine taille.
- **Remorquage** : les remorqueurs poussent ou tirent le navire.
- **Lamanage** : équipe d'environ 3 personnes aux amarres.
- **Soutage** : avitaillement en carburant, en zone dédiée.

**Autres terminaux (extensions possibles)**
- **RoRo** : rampe ou passerelle mobile (linkspan), parfois à deux niveaux, et grand parking de véhicules.
- **Vrac sec** :
  - chargeur de navire roulant sur rails le long du quai (flèche, goulotte télescopique) ;
  - convoyeur de quai ;
  - tas de stockage repris par stacker/reclaimer ;
  - un terminal est souvent dédié à une seule marchandise (charbon, minerai, céréales).
- **Vrac liquide** :
  - appontement au large ;
  - bras de chargement articulés ;
  - pipelines vers un parc de cuves (8 à 100 cuves).
- **Croisière et ferry**, **port de pêche**, **marina**, **chantier naval avec cale sèche**.

**Évolution d'un port : modèle Anyport (Bird, 1963, puis Notteboom et Rodrigue, 2005)**
1. Établissement : petits quais près du centre du village.
2. Expansion : quais allongés, industries.
3. Spécialisation : terminaux dédiés, plus profonds, plus loin du centre.
4. Régionalisation : arrière-pays, ports secs, rail.

Cela correspond aux paliers T1 → T4 de Port Horizon (Vieux Quai → Port régional → Terminal national → réseau).

**Couleurs des compagnies (indices visuels seulement ; le jeu garde des armateurs fictifs)**
- MSC : jaune ; CMA CGM : bleu foncé ; Hapag-Lloyd : orange ; Evergreen : vert.
- ONE : magenta ; COSCO : bleu et blanc ; Maersk : bleu clair ; HMM : bordeaux.
- Conteneurs loués ou repeints : couleurs variées.

Sources : porteconomicsmanagement.org (« Main Physical Elements of a Port », « Types of Port Terminals », « Container Terminal Design and Equipment », « The Evolution of a Port ») ; transportgeography.org ; Liebherr, d'après porttechnology.org et ajot.com (dimensions STS, RTG, RMG) ; BSI BS 6349-8 (rampes RoRo) ; Bruks-Siwertell (chargeurs de navire) ; EIA de l'EPD de Hong Kong (appontement pétrolier) ; Plymouth VTS et Malta Transport (services nautiques) ; freightcourse.com (couleurs des compagnies).
