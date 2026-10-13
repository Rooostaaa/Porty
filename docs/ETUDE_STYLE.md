# Étude de style — Port Horizon V2 (13/10/2026)

Suite à la revue (`REVUE_CHEF_DE_PROJET.md`) : avant de généraliser un style à tout le port, choisir ce style sur image.
Rendu comparatif : `docs/previews/style_variantes.png` (script `blender/preview_variants.py`). Même scène dans les trois cas :
capitainerie, deux conteneurs, chariot, docker, quai avec bollards, route, eau. Même caméra, même lumière.

---

## 0. Deux points de la revue réexpliqués

**« Abandonner le texte 3D comme porteur d'information »**
Aujourd'hui la douane porte une enseigne « DOUANE » et l'entrepôt une enseigne « ENTREPÔT » en lettres 3D. Dans le jeu, même
au zoom le plus proche, ces lettres font 3 ou 4 pixels de haut : on ne peut pas les lire (`docs/captures/v2_warehouse.png`).
La proposition : le joueur doit reconnaître un bâtiment **sans lire**, comme on reconnaît une pharmacie à sa croix verte.
Chaque bâtiment reçoit donc un **objet emblème** (belvédère pour la capitainerie, table d'inspection et valise pour la douane,
porte de quai ouverte sur des cartons pour l'entrepôt) et **une couleur de département** (bleu capitainerie, marine + jaune douane,
orange gate, vert logistique). Le texte peut rester comme décor, mais rien d'important ne doit dépendre de lui.

**« Budget de 2 500 triangles par bâtiment, 600 par accessoire »**
Un modèle 3D est fait de petites faces triangulaires. Plus il en a, plus il est détaillé, et plus la carte graphique travaille.
L'ancien entrepôt en avait 144 ; le nouveau en a 2 672, soit 18 fois plus. Avec une centaine d'objets à l'écran, un PC ne le
sent pas, un téléphone d'entrée de gamme oui. Le « budget » est simplement une **limite par modèle**, vérifiée automatiquement
à l'export (`build_assets.py` la fait déjà : il refuse un modèle trop lourd). 2 500 pour un bâtiment et 600 pour un accessoire
permettent le niveau de détail des pilotes sans fermer la porte au mobile. Ce n'est pas une contrainte artistique : c'est un garde-fou.

---

## 1. Les familles visuelles du genre

| Famille | Jeux | Technique | Atteignable avec notre chaîne Blender → Godot ? |
|---|---|---|---|
| 3D low-poly saturée, bâtiments en coupe, caméra proche | Idle Supermarket Tycoon, Idle Theme Park, Idle Airport Tycoon (Codigames) | 3D, couleurs plates, lumière forte | **Oui**, c'est exactement notre pipeline |
| 2D plate pastel, vue du dessus | Overcrowded: Tycoon (ZeptoLab) | 2D dessinée | Non, tout serait à refaire |
| Peinture réaliste, bateaux détaillés | Port City, Seaport (Pixel Federation) | 2D pré-rendue | Non |
| Cartoon 2D | Pocket Ships Tap Tycoon, Idle Pirate Tycoon | 2D dessinée | Non |
| 3D low-poly générique | Idle Mega Harbor Tycoon | 3D, textures | Oui, mais c'est la famille la moins identifiable |

Conclusion : on reste dans la **3D low-poly en aplats**. La question n'est pas la technique, c'est le **langage** : quelles formes,
quelles matières, quelles couleurs de sol. Trois directions ont été construites et rendues.

---

## 2. Les trois directions (voir `style_variantes.png`)

### A — Commercial ISM (le pilote actuel)
Brique, socle sombre, chape-acrotère grise, grandes vitrines bleues, asphalte violet, herbe citron.
- **Pour** : fidèle à la référence, très lisible, le vocabulaire est déjà codé (`closed_block`, `facade`, `pilaster`).
- **Contre** : ça ressemble à un **magasin**. Posé au bord de l'eau, le bâtiment ne dit pas « port ». La brique et les vitrines
  conviennent à une rue commerçante, pas à un quai. Appliqué à 18 bâtiments, le port devient un centre commercial avec des grues.
- Cohérence avec l'existant : navires, grues, conteneurs actuels jurent avec la brique (rien de maritime dans le vocabulaire).

### B — Port nordique jouet
Corps blanc crème à bardage horizontal, planches d'angle blanches, bandeau marine en bas, toit à deux pentes **bleu** (couleur
du département), belvédère sur le faîte, porte rouge, auvent rayé. Sol : béton chaud, asphalte bleu-gris, herbe moyenne.
- **Pour** : dit immédiatement « bord de mer » ; silhouette forte (toit, belvédère, mât) reconnaissable en petit ; les arêtes
  chanfreinées donnent le côté **jouet** ; la couleur du département se pose naturellement sur le toit. Se marie avec les
  maisons du village, le phare, les bateaux. Coût de modélisation comparable à A.
- **Contre** : moins contrasté que A (pas de chape sombre) ; demande un ombrage Godot plus marqué pour ne pas paraître pâle ;
  risque « carte postale » si tout le port est blanc et bleu : les hangars, le terminal T3, la zone IMO ont besoin d'un autre registre.

### C — Industriel pop
Bardage métallique nervuré bleu acier, bande jaune et noire au sol, casquette claire, porte roulante orange, clim et antenne en
toiture, bloc-emblème coloré à la place d'une enseigne. Sol : asphalte sombre, marquages jaunes, herbe plus foncée.
- **Pour** : c'est ce qu'est un terminal à conteneurs ; le langage conteneur (bloc, couleur franche, nervures) unifie
  bâtiments, conteneurs et engins ; parfait pour T2 et T3.
- **Contre** : plus **gris et froid** ; en T1 (« village de pêcheurs ») il arrive trop tôt ; moins chaleureux que le ton voulu
  par la bible (« chaleureux, humoristique »). Les petits bâtiments de service (douane, capitainerie) y perdent leur personnalité.

---

## 3. Recommandation : direction D = B + C, qui raconte la progression

Un port, dans le jeu, passe du **vieux quai d'un village** au **terminal national**. Le style peut raconter ça tout seul :

| Palier / zone | Langage | Exemples |
|---|---|---|
| T1 Le Vieux Quai, village, services (capitainerie, douane T1, ponton, phare, maisons) | **B** : bois blanc crème, toits colorés à pente, chanfreins, bandeau marine | capitainerie B du rendu |
| T2 Port régional : bureaux, tour, atelier, gate, douane T2 | **B en dur** : façades claires, toit plat à casquette **claire**, grandes baies, couleur du département sur la casquette | tour de contrôle, bureaux |
| T3 Terminal national : halle d'inspection, informatique, sous-station, rail, IMO, entrepôts | **C** : bardage nervuré, portes roulantes, toits techniques, bandes jaune-noir | capitainerie C du rendu, en entrepôt |
| Sols | **communs** : asphalte **violet sombre** (A) pour le terminal, béton chaud pour les terre-pleins, gravier sable en T1, herbe moyenne (B) | — |
| Engins, navires, conteneurs | **C** : couleurs franches, toit plus clair que les flancs, feux rouges | existants, à saturer |

Règles communes aux deux registres (elles viennent de A, et c'est ce qu'il faut garder d'ISM) :
1. socle sombre sous chaque bâtiment ; 2. un objet emblème et une couleur de département par bâtiment ; 3. accessoires et
personnages exagérés ×1,35 ; 4. ombrage marqué (dessus 100 %, flancs 65–75 %) et ombres nettes non noires ; 5. information de jeu
posée sur le décor (totem P, compteur de rade) ; 6. aucun texte porteur d'information.

Pourquoi pas A seul : il transforme un port en galerie marchande. Pourquoi pas B seul : le T3 deviendrait une station balnéaire.
Pourquoi pas C seul : le début de partie, qui doit séduire en une minute, serait gris.

Ce que D coûte de plus que A : deux jeux de pièces dans `lib.py` au lieu d'un (`wood_block` avec toit à pente et chanfreins ;
`steel_shed` avec bardage et casquette), soit environ une demi-session Blender supplémentaire. Les trois pilotes actuels seraient
refaits une seconde fois (capitainerie et douane en B, entrepôt en C).

---

## 4. Ce qu'il faut décider

1. **Direction** : A, B, C ou **D (recommandée)**.
2. Si D : valider le **tableau du § 3** (quel registre pour quel palier).
3. **Sol du terminal** : violet sombre (A) ou bleu-gris (B). Je recommande le violet sombre : il se détache de l'eau et de l'herbe.
4. Si vous hésitez entre deux directions, je rends une **deuxième planche** : les trois pilotes (capitainerie, douane, entrepôt)
   dans la direction choisie, avant d'écrire l'ordre de mission de l'expert Blender.

Ce qui ne bouge pas, quelle que soit la direction : bâtiments fermés, face principale en −Y, couleurs uniquement via `palette.json`,
budget de triangles, lot B côté Godot (lumière, cadrage, bulles, débogage).
