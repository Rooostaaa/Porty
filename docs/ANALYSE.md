# Analyse de Port Horizon — points d'amélioration (12/10/2026)

Méthode : lecture de tout le code (`sim/`, `scripts/`, `data/`), relecture des docs, exécution des 26 tests et du script d'équilibrage,
captures du jeu en partie neuve (portrait 540×960, paysage 1280×720, vue dézoomée T1 et T3, zone de la gate).

## Verdict en une phrase
La **simulation est solide** (26 tests verts, équilibrage dans les cibles, aucune impasse) mais la **couche « joueur »** est inachevée :
le monde est une île sans arrière-pays, personne n'accompagne le joueur, et au-delà de ~15 min il a peu de décisions à prendre.

---

## 1. Le monde : un port posé sur la mer

### Constats (vérifiés sur captures)
- **C'est une île.** Les terres (`Layout.LAND_X`, `GROUNDS`) forment un rectangle de 150 × 48 u entouré d'eau. Le plan d'eau fait 900 × 900 u.
- **La chaussée de la gate ne mène nulle part.** `CAUSEWAY_Z1 = 204` : la route s'arrête en pleine mer, hors de la zone de caméra (`bounds` plafonne à z = 60).
  Les camions apparaissent au bout de la file (`TrafficView._spawn_queue_truck`) et disparaissent à z > 200 (`traffic_view.gd:106`).
- **Aucune zone qui précède la gate** : pas de parking poids lourds, pas d'aire d'attente, pas de pré-gate. La « file » est une rangée de 9 camions sur une route de 6 u.
  Or le prompt d'origine dit que le parking de la référence est *exactement* le rôle de la gate/parc : ici il n'existe pas.
- **Aucun arrière-pays** : pas de village (le récit parle d'un « village de pêcheurs »), pas de route nationale, pas de collines, pas de zone logistique.
  Le terminal rail (T3) est une bande de gravier de 6 u de large ; le train surgit à x = 10 et disparaît à x = 200.
- **Pas de vie ambiante** : personnages statiques (ils « rebondissent » seulement), pas de voitures, de bateaux de pêche, d'oiseaux, pas de jour/nuit.
  Au dézoom, plus de la moitié de l'écran est de l'eau vide.
- **Les paliers se révèlent d'un bloc** (`Diorama.rebuild()` détruit et recrée tout) : pas d'animation, pas de caméra, pas d'aperçu de ce qui vient.

### Cible proposée

```
                 MER  (rade, balises, phare)
   ┌──────────────── quais ─────────────────────┐
   │ tablier │ parc │ parc │ frigo │ IMO │ OOG   │   zone portuaire clôturée
   │                                              │
   │   GATE ═╗     douane / bureaux / atelier     │
   └─────────║────────────────────────────────────┘
             ║   ◄ ZONE D'ATTENTE (parking PL : 8 → 40 places selon le niveau Gate)
        ═════╩══════ route d'accès ═══════ ► autoroute / ville
   [village]   [zone logistique]   [terminal rail ──► horizon]
            TERRE FERME  (collines, forêt, étang)
```

Pour respecter les 4 règles de cohérence du prompt, le **parking devient une vraie mécanique** :
1. cause réelle : les camions attendent avant d'entrer dans l'enceinte ;
2. goulot visible : parking plein → camions débordent sur la route et klaxonnent (le `trucks_honking()` existe déjà) ;
3. levier : bâtiments « Aire d'attente » (T1 : gravier 6 places, T2 : bitume 20, T3 : 40 + système de rendez-vous) ;
4. visuel : places qui se remplissent dans le diorama + pastille « 7/20 places ».

Effet de bord utile : le **plateau T2** (voir §4) reçoit de nouveaux achats.

### Assets à ajouter (Blender, `parts/terrain.py` + `buildings.py`)
`ground_parking` (marquage de places) · `car` / `pickup` · `house` ×2 · `shop` · `silo` · `hill` / `cliff` · `road_curve` · `highway` + `overpass` ·
`sign_gate` · `fishing_boat` · `gull` (billboard). Les dalles existantes (`ground_grass`, `road`) suffisent pour un premier « faux continent » en 1 h.

---

## 2. Premier contact : aucun tutoriel

### Constats
- **Rien** n'accompagne le joueur : `grep` « tuto / onboarding / first_run » ne donne que le conseil de goulot. Seule trace : « Comment jouer »
  (5 lignes) enterré dans Réglages (`settings_sheet.gd:39-47`).
- **L'écran de départ** (capture) : revenu **−12/min** en vert-sombre (les salaires tombent avant la 1ʳᵉ recette) → première impression « je perds de l'argent » ;
  le **premier navire est caché sous la carte « Goulot »** et sa bulle d'humeur sous la pastille « Responsables » ; aucun geste n'est demandé.
- **Jargon jamais défini** : EVP, rade, tablier, gate, palier, licence, formalités, Ambre, « Responsables OFF ».
- **Icônes sans légende** (colonne de droite : flèche, histogramme, document).
- **Systèmes enfouis** : Contrats (badge seulement si actif), Politique et Tarifs (Gestion → Port, 4ᵉ onglet), usage de l'Ambre (expliqué uniquement dans Missions).
- **« Bon retour »** s'affiche dès 60 s d'absence (`Save.load_game`, `hud.gd:629`) — on l'a vu pour « +77 $ / 76 EVP ». Du bruit, et rien pour un tout premier lancement.
- **Aucun feedback de réussite** à la 1ʳᵉ amélioration, au 1ᵉʳ navire déchargé, au 1ᵉʳ responsable.

### Proposition : tutoriel guidé de ~3 min, piloté par données
Étapes (chacune attend l'action réelle du joueur, avec projecteur + flèche + une phrase, « Passer » toujours visible, rejouable depuis Réglages) :

| # | Moment | Message | Action attendue |
|---|---|---|---|
| 0 | Lancement | Plan-séquence mer → port, 2 phrases d'histoire | Toucher |
| 1 | Navire en rade | « Voici ton 1ᵉʳ navire. Touche-le pour le faire accoster. » (caméra dessus) | Toucher le navire |
| 2 | Accostage | Caméra suit le navire ; « La grue décharge : chaque conteneur rapporte » | Regarder (≈10 s) |
| 3 | Argent ≥ coût | « Tu as 100 $ : améliore les Portiques » (flèche sur Améliorations) | Acheter |
| 4 | Nouveau goulot | « Le maillon le plus lent limite tout » (zoom sur l'anneau rouge) | Toucher AGIR |
| 5 | ~2 min | « Embauche un responsable : il travaille pour toi, même hors-ligne » | Embaucher |
| 6 | 1ᵉʳ bâtiment dispo | Gestion → Bâtiments, caméra sur l'emplacement | Construire |
| 7 | Mission prête | Réclamer l'Ambre, dire à quoi il sert | Réclamer |
| 8 | T2 / 1ᵉʳ aléa / 1ᵉʳ contrat | Astuces contextuelles uniques (toast + « ? ») | — |

Complément : **glossaire** accessible par « ? » sur chaque terme, et « EVP » renommé « conteneurs (EVP) » à la première occurrence.
Technique : `data/tutorial.json` + nœud `Tutorial` ; drapeaux dans `Settings` (pas dans la sauvegarde de partie) ; le HUD expose les rectangles à éclairer ;
`CameraRig` gagne `follow(node)`.

---

## 3. Lisibilité et interface

- **Le HUD mange ~20 % de l'écran** (barre + pastille + carte goulot + toasts) et couvre justement la rade. Carte goulot repliable en une ligne après le tutoriel,
  toasts déplacés vers le bas, cadrage initial décalé pour que la rade reste visible.
- **Paysage / PC** (capture 1280×720) : la caméra garde la *largeur* (`KEEP_WIDTH`), donc la grue remplit l'écran ; la carte goulot s'étire sur toute la largeur ;
  la barre basse flotte au milieu. Le jeu se joue sur PC : prévoir `KEEP_HEIGHT` en paysage + colonne HUD plafonnée (≈ 560 px).
- **Pas de lien liste → carte** : dans Bâtiments, rien ne montre *où* ça se construira ; après achat la caméra ne bouge pas. Ajouter « Voir » (focus + halo),
  un « pop-in » à la construction (poussière, secousse locale), et des **lots fantômes** translucides avec leur prix (le moteur d'envie des tycoons).
- **Fenêtre modale pour un tap sur navire** : bloque toute la vue. Préférer une bulle / feuille basse.
- **Noms rouges pour « verrouillé »** (Bâtiments) : le rouge signifie « problème » partout ailleurs ; utiliser le gris + cadenas.
- **Pas de bouton « recentrer »**, pas de minicarte ; au dézoom, la surcouche cache des jauges selon des seuils (`zoom > 110`), c'est opaque pour le joueur.
- **Police** : `assets/fonts/` est vide → repli Segoe UI (déjà noté dans DECISIONS).

---

## 4. Profondeur de jeu et progression

- **Les décisions disparaissent vite.** Dès le 1ᵉʳ responsable, « choisir le navire » devient inutile ; Politique et Tarifs n'ont aucune incitation à être touchés
  (le défaut convient). Après ~15 min, le verbe dominant est « acheter quand c'est vert ».
- **Plateau T2** (mesuré par le script d'équilibrage) : dernier bâtiment T2 à 24 min, palier T3 à 48 min — **~25 min sans aucun nouveau bâtiment** (seulement niveaux et licences).
  L'absence d'impasse est vérifiée parce que les niveaux comptent comme achat. Le parking + bâtiments de §1 comblent ce trou.
- **Fin de partie** : de 58 min (TOS) à 1 h 26, le seul objectif est d'accumuler 5 Md$ ; l'écran de fin dit « la partie continue » mais rien ne suit (T4/T5 et prestige hors périmètre).
- **Rade pleine silencieuse** : 7 425 navires déroutés dans une partie complète (`turned_away`, `port_sim.gd:574-587`), une seule notification toutes les 30 s,
  pas de bâtiment pour agrandir le mouillage → un levier manque.
- **Ambre sans débouché** : après les 6 responsables il ne sert plus qu'à relancer les Heures sup (1 Ambre). Il s'accumule (15 en T3). Ajouter des puits : bonus permanents,
  accélérer un contrat, cosmétiques du port.
- **Missions** : 17 au total, puis « Toutes accomplies ». Prévoir des missions générées et des objectifs récurrents.
- **Écarts avec la bible (UNIVERS.md / prompt)** : pas de **chargement/export** (les navires ne font que décharger, les camions ne rentrent jamais), pas de fenêtres horaires,
  pas de maintenance/énergie/HSE (T3 « transverse »), responsables Lambert et Mori inutilisés, durée de séjour facturée absente (seulement l'enchère).
  Le flux **import + export** est le plus gros gain de vie visuelle (camions qui entrent chargés, navires qui repartent pleins) et justifie le parking.
- **Aléas** : un seul levier (payer ou attendre). Idées : choix entre deux réponses, prévention (digue, pare-feu météo) achetable.

---

## 5. Sensations (« jus »), audio

- `assets/audio/` est **vide** : 7 bips synthétisés, aucune ambiance (mer, mouettes, corne de brume), aucune musique.
- Pas de sillage ni d'écume derrière les navires, pas de fumée, pas de poussière au gerbage, pas de pluie, pas de nuit.
- Les gains sont des pastilles 2D ; pas de particules dans le monde ; les personnages ne marchent pas.
- Sons manquants à forte valeur : cloche d'arrivée, impact de conteneur, moteur de camion, corne de navire à l'amarrage.

---

## 6. Technique et qualité

- **Layout en constantes GDScript** (`layout.gd`, ~150 lignes de tableaux) : pour ajouter un continent, un parking et un village, passer à `data/layout.json`
  (déjà l'esprit « aucune valeur en dur » du prompt) et réutiliser `GROUNDS`/`PROPS`.
- **Caméra** : `bounds` et `LAND_X` sont codés par palier ; il faudra les dériver du layout.
- **Aucune couche de test pour la vue** : les 26 tests couvrent la simulation. Ajouter un test de fumée (charger `main.tscn` en headless 10 s, zéro erreur) et des
  captures de référence par palier.
- **Outil de capture** : un clic parasite a déplacé la caméra pendant mon premier essai (cible x = 34, z = 89 → écran 100 % eau, non reproduit ensuite).
  Ajouter `--no-input` quand `--capture` est présent.
- **Pas de git (choix assumé)** : prévoir un `sauvegarde.bat` qui zippe `godot/`, `blender/`, `docs/` avec la date, avant les grosses réécritures (Layout, Diorama).
- **Sauvegarde** : `VERSION = 1` et `_migrate` vide ; les drapeaux du tutoriel iront dans `Settings` pour ne pas toucher au format de partie.

---

## 7. Feuille de route proposée

| Phase | Contenu | Effort | Pourquoi d'abord |
|---|---|---|---|
| **0 — Gains rapides** | Cadrage initial hors HUD · revenu masqué tant que ≤ 0 · « Bon retour » seulement si > 5 min · « Comment jouer » au 1ᵉʳ lancement · légendes des icônes · caméra auto sur construction · faux continent en dalles existantes | ½ journée | Corrige l'impression « île vide » en quelques heures |
| **A — Premier contact** | Tutoriel guidé, glossaire, astuces contextuelles | 1–2 j | Retient le joueur dans les 3 premières minutes |
| **B — Le monde** | Terre ferme, route, village, zone d'attente/parking jouable, trafic entrant, caméra et bornes | 2–3 j | Répond à la remarque principale et remplit le plateau T2 |
| **C — Profondeur** | Lots fantômes + révélation des paliers, puits d'Ambre, missions générées, mouillage extensible, aléas à choix | 2 j | Redonne des décisions après 15 min |
| **D — Finition** | Ambiances sonores, jour/nuit, sillages, personnages qui marchent, mise en page paysage | 2 j | Qualité perçue |
| **E — Après-MVP** | Import/export complet, maintenance, prestige / T4 | 4 j+ | Durée de vie |

### Ce que je recommande de faire en premier
**Phase 0 puis B** : c'est ce que tu as relevé (port au milieu de l'eau, pas de zone d'accueil) et c'est ce qui change le plus l'image du jeu. Le tutoriel (A)
vient juste après, car il doit expliquer le monde *final* (parking compris) et non l'île actuelle.

---

## 8. Lecture selon les principes du genre idle tycoon (ajout)

Principe : *clic manuel → machine automatique → revenus hors-ligne → prestige → gestion fine des améliorations.*

| Pilier | État | Écart |
|---|---|---|
| Clic manuel puis automatisation | **Faible** | Sans responsable, un navire accoste seul après 4 s (`auto_berth_delay`, `_assign_berths`) : le geste manuel est quasi inutile. Les responsables de Quais, Portiques, Douane, Parc, Gate ne font que ×2 (`manager_mult`) : ils ne suppriment aucune corvée. |
| Revenus hors-ligne | Bon | 8 h max, 50 % → 100 % selon les responsables. |
| Courbe exponentielle, paliers ×2, achat ×1/×10/×100/max | Bon | Testé et équilibré. |
| Prestige / renaissance | **Absent** | Hors périmètre MVP : la partie s'arrête à ~1 h 26 et rien ne la relance. |
| Optimisation des améliorations | À nuancer | Le conseil de goulot donne la réponse ; pas de lecture de rentabilité. |

### Actions ajoutées à la feuille de route
1. **Phase A (tutoriel) + 0** — rendre le début actif : accostage manuel obligatoire avant la Capitainerie, « coup de main » en touchant la grue,
   libération manuelle d'un camion à la gate. Chaque responsable *retire* une de ces corvées (et garde son ×2).
2. **Phase C** — carte d'amélioration : « +X $/min pour Y $, rentabilisé en Z min » et tag « meilleur achat ».
3. **Prestige remonté de la phase E à la phase C/D** — « nouvelle concession » : nouveau port de la Mer d'Ambre (cargaisons et armateurs propres),
   remise à zéro contre des **Licences** (bonus permanents), comme prévu dans la bible. Nécessite une 2ᵉ carte/Layout, donc après la phase B.
4. **Tutoriel** — il doit montrer la boucle complète (manuel → automatique → prestige), pas seulement l'achat de la grue.

---

## 9. État d'avancement (12/10/2026, fin de tranche 3)

| Chantier de l'analyse | État |
|---|---|
| §1 Monde : terre ferme, route, village, relief, zone logistique | **Fait** (`Layout`, `blender/parts/world.py`) |
| §1 Zone qui précède la gate : aire d'attente poids lourds jouable | **Fait** (bâtiments `parking1/2`, camions par l'autoroute) |
| §1 Vie ambiante | Partiel : voitures sur l'autoroute, mouettes sonores ; reste personnages qui marchent, jour/nuit |
| §2 Tutoriel guidé + glossaire | Tutoriel **fait** (9 étapes) ; glossaire « ? » **reste à faire** |
| §3 Mise en page paysage / PC | **Fait** (colonne centrée + caméra à hauteur constante) |
| §3 Lots fantômes, « voir sur la carte », pop-in de construction | **Reste à faire** |
| §4 Plateau T2 de ~25 min | **Corrigé en grande partie** : 3 leviers + aire d'attente ; T2→T3 ≈ 32 min |
| §4 Boucle clic → automatisation | **Fait** (accostage + coup de main, remplacés par les responsables) |
| §4 Prestige, objectifs de carrière, rentabilité des achats | **Fait** (tranche 2) |
| §4 Puits d'Ambre, aléas à choix, mouillage extensible | **Reste à faire** |
| §10–11 Début de partie doux (petits navires, gabarits, douane à construire, révélation progressive) | **Fait** (A + B) |
| §12 Chantier C : commerce (démarchage, armateurs, lignes, services), plancher assoupli, prix T3 | **Fait** (DECISIONS.md « Chantier C ») |
| §5 Ambiances sonores | **Fait** (synthétisées) ; reste la musique et la météo visible |
| §8 Import/export, maintenance, nouveau port par concession | **Reste à faire** |

---

## 10. Début de partie : ce que font les tycoons, et ce qu'on en tire (12/10/2026)

### Constat mesuré (partie neuve, sans action du joueur)
| Mesure | Valeur | Ce que ça donne à l'écran |
|---|---|---|
| Plus petit navire | Caboteur 120–300 EVP, modèle de 22 m avec 3 baies | on démarre avec un « vrai » cargo |
| Demande / capacité | 6,5 EVP/s arrivent, la grue en décharge 3 | 2 à 4 navires en rade en permanence, rade pleine vers 7 min |
| Premier déchargement | ~70 s pour 213 EVP | la première récompense arrive tard |
| Camions | ~40 camions affichés par navire | défilé continu dès la 1ʳᵉ minute |
| Systèmes visibles à 90 s | responsables 0/6, Heures sup, Ambre, ★, contrats, 8 achats, amende de douane | tout est montré d'un coup |
| Faire venir des navires | un niveau abstrait (« Capitainerie ») et le dragage | aucun geste concret de développement commercial |

### Principes du genre (sources en fin de section)
1. **Une boucle lisible sur un seul écran, avec des goulots entre les étapes** (Idle Miner : miner → transporter → vendre). Port Horizon l'a déjà.
2. **Commencer minuscule, première récompense en quelques secondes** : la première boucle de satisfaction décide si le joueur reste
   (Kolibri vise 70 % de rétention J1).
3. **Le manuel d'abord, l'automatisation ensuite** : Idle Miner fait taper à la main jusqu'au niveau 5 avant de proposer un responsable. Port Horizon le fait déjà.
4. **Alterner demande et capacité** : la publicité, le parking ou l'affichage font venir des clients, et le joueur doit ensuite agrandir pour les servir
   (Idle Supermarket, Idle Theme Park et son onglet « Marketing »). C'est exactement l'idée « campagne de pub ».
5. **Le thème réel remplace le tutoriel** : un quai plus long accueille des bateaux plus longs, un chenal dragué des bateaux plus profonds.
   On comprend sans explication.
6. **Les gros déblocages sont soutenus par la présentation** : chaque nouvelle attraction a sa séquence dans Theme Park Tycoon, et un nouveau puits est l'étape clé d'Idle Miner.
7. **Introduire les systèmes progressivement, mais laisser voir ce qui vient** : il ne faut pas tout enseigner d'un coup. AdVenture Capitalist montre
   pourtant tout dès la 1ʳᵉ session. Le compromis : les éléments verrouillés sont visibles, grisés, avec leur condition.
8. **Un guidage en contexte, au moment où le joueur bloque**, plutôt qu'un long tutoriel au départ (Kolibri). Les boosters et la publicité doivent être expliqués au moment où ils apparaissent
   (c'est la critique faite à Theme Park).
9. **Le rythme suit l'engagement** : la 1ʳᵉ session dure 15 à 60 min avec des déblocages fréquents, puis le joueur revient toutes les heures, puis tous les jours.
   Au début, la production dépasse les coûts, puis l'écart se resserre.
10. **Développer le port par les contrats et les équipements** : Port City fait construire des docks plus grands pour accueillir plus de navires,
    et ce sont les contrats qui font grandir la ville. Port Royale et Cities Skylines II débloquent selon la réputation ou le volume traité.

### Plan retenu

**A. Rythme du départ** (données + simulation)
- Nouvelle classe **« Petit porte-conteneurs »**, 15–30 EVP, avec un modèle Blender à une seule baie. C'est le seul navire au départ.
- Nouvelle notion de **longueur de quai**. Le quai n°1 est court au départ. Le bâtiment **« Allongement du quai »** (~600 $) fait venir les caboteurs,
  dont la taille est ramenée à 60–150 EVP. Le **dragage** fait ensuite venir les feeders, comme aujourd'hui.
- **Demande de départ inférieure à la capacité** : un petit navire toutes les ~40 s, déchargé en ~10 s. Le port « attend », et le premier désir
  du joueur est de faire venir plus de navires.
- **Rade de 2 places** au départ. Chaque **bouée de mouillage** en ajoute une (bâtiment).
- **Camions à l'échelle** : 1 camion affiché = 1 à 2 conteneurs au départ, une seule voie, donc une dizaine de camions par petit navire.
- Rééquilibrer T1→T2 avec le bot d'équilibrage. Cible : T1 en 12–15 min (contre ~10 aujourd'hui), le début étant plus doux.

**B. Révélation progressive** (interface)
- Fichier de données `unlocks.json` : un élément d'interface ou un système, une condition. On réutilise l'évaluateur d'expressions du tutoriel.
- Minute 0 : argent, navire, grue, « Améliorer » avec Portiques et Quais seulement.
- Ensuite, au fil des conditions : responsables (au premier qui devient abordable), Gestion, Missions, puis Heures sup (expliquées au moment où elles apparaissent),
  Ambre (au premier gagné), contrats et aléas (après ~10 navires), et la **douane** avec le bâtiment « Bureau de douane » : pas d'amende avant ce bâtiment.
- Chaque déblocage a son moment : le bouton apparaît avec une animation, un bandeau « Nouveau : … » et une phrase d'explication.
- Dans les écrans, les cartes encore verrouillées restent visibles, grisées, avec leur condition (« au 5ᵉ navire », « palier 2 »).
- Moments marquants : premier caboteur, premier feeder, nouveau quai. La caméra se cale dessus, un bandeau s'affiche et un son est joué.

**C. Faire venir des navires par des leviers concrets** (gros chantier, après A et B)
- **Commercial** : un onglet *Démarchage* avec des campagnes temporaires (affiche au port, annonce dans le journal maritime, salon maritime).
  Elles coûtent de l'argent et ont un temps de recharge. Le salon fait venir un **nouvel armateur**.
- **Lignes régulières** : un contrat signé avec un armateur = un navire d'une classe donnée à intervalle fixe. C'est une demande garantie, qui donne du sens aux contrats.
- **Services aux navires** : avitaillement (patience et relations), remorqueur, atelier de réparation (revenu).
- **Infrastructure** : longueur et profondeur de quai, bouées de mouillage, postes à quai.
- La demande devient le produit de ces sources : base × démarchage × lignes × réputation × tarifs. La « Capitainerie » garde le pilotage
  et l'accostage, mais n'est plus le seul robinet à navires.

### Sources
- [Kolibri Games — 8 leçons (GameAnalytics)](https://www.gameanalytics.com/blog/making-a-hit-idle-game-eight-lessons-from-kolibri-games)
- [Kolibri — du MVP à 70 M d'installations (PocketGamer.biz)](https://www.pocketgamer.biz/feature/70431/how-kolibri-went-from-minimal-viable-product-to-70-million-installs-for-its-idle-games/)
- [Kolibri — étude de cas PlaytestCloud](https://start.playtestcloud.com/blog/kolibri-games-case-study)
- [AdVenture Capitalist — leçons de design (Global Games Forum)](https://www.globalgamesforum.com/ctv/idle-game-design-lessons-from-developing-adventure-capitalist)
- [Eric Guan — Idle Game Design Principles](https://ericguan.substack.com/p/idle-game-design-principles)
- [900 secondes avec Idle Theme Park Tycoon](https://martinjurasek.substack.com/p/900-seconds-with-idle-theme-park)
- [Idle Miner Tycoon — guide débutant (BlueStacks)](https://www.bluestacks.com/blog/game-guides/idle-miner-tycoon/idt-beginner-guide-en.html)
- [Idle Supermarket Tycoon — guide (AppGamer)](https://www.appgamer.com/idle-supermarket-tycoon/strategy-guide/how-to-play-idle-supermarket-tycoon)
- [Idle Theme Park Tycoon — guide (SuperCheats)](https://www.supercheats.com/idle-theme-park-tycoon-walkthrough-guide)
- [Port City: Ship Tycoon — guide débutant (LevelWinner)](https://www.levelwinner.com/port-city-ship-tycoon-beginners-guide-tips-tricks-strategies/)
- [Cities: Skylines II — journal de développement des ports (Paradox)](https://www.paradoxinteractive.com/games/cities-skylines-ii/news/bridges-and-ports-dev-diary-ports)

---

## 11. Équilibrage du nouveau début : prototype mesuré (12/10/2026)

Méthode : copie du projet (dans le dossier temporaire de la session, le vrai projet n'est **pas modifié**), modifications des données et de la simulation,
puis bot d'équilibrage `tests/balance.gd` (joueur actif, 3 graines) jusqu'à la fin du MVP. Cinq itérations.

### Ce que les essais ont appris
| Essai | Changement | Résultat | Leçon |
|---|---|---|---|
| 1 | Petits navires, demande ÷10, rade 2, douane à construire | T1 = 18 min, goulot « trafic » 13 min d'affilée | Si la Capitainerie (+15 %/niveau) est le seul levier de demande, le début est monotone |
| 2 | **Demande = somme du trafic des classes accueillies × armateurs** | Le quai allongé fait ×4 de trafic d'un coup, les goulots alternent ; T1 = 12 min | Agrandir le quai *doit* amener du trafic, sinon le geste n'a pas de sens (idée validée) |
| 3 | Allongement à 150 $ | Quai à 1 min, T1 = 8 min, revenus qui explosent | La phase « petits navires » doit durer 2–3 min ; valeur T1 trop haute |
| 4 | Valeur T1 1,8, allongement 250 $ | Le bot n'économise jamais pour le quai (12 min) | Un joueur non guidé dépense tout en petits niveaux : le **conseil et le tutoriel doivent désigner l'équipement** |
| 5 | Le joueur économise pour l'équipement désigné | **Toutes les cibles atteintes** | — |

### Réglages retenus (à reporter dans le projet)
| Élément | Avant | Après |
|---|---|---|
| Classes (`ships.json`) | caboteur 120–300 (gabarit 1), feeder (2), panamax (3) | **petit porte-conteneurs 16–30 (gabarit 1)**, caboteur **60–150** (2), feeder (3), panamax (4) |
| Trafic par classe et palier (EVP/s) | poids de tirage | `traffic` : petit [0,7 / 0,02 / 0] · caboteur [2 / 0,15 / 0,03] · feeder [2 / 2 / 0,6] · panamax [0 / 0 / 1] |
| Durée d'escale (pilotage, amarrage, formalités) | identique pour tous | ×0,4 petit, ×0,7 caboteur (`time_scale`) |
| Demande | Capitainerie (base 6) × réputation × tarifs | Capitainerie (×1 → +15 %/niv.) × **trafic des classes accueillies** × **armateurs présents** × réputation × tarifs |
| Bâtiments T1 (ordre) | terre-plein, 2ᵉ grue, dragage, gravier | **Allongement du quai 250 $** (gabarit 2), terre-plein, **Bureau de douane 800 $**, 2ᵉ grue, dragage (gabarit 3), gravier |
| Bâtiments de quai T2/T3 | quai n°2 gabarit 2, quais 3–4 gabarit 3 | gabarits 3 et 4 (même rôle) |
| Douane | active dès la 1ʳᵉ seconde | pas d'inspection ni d'amende avant le **Bureau de douane** ; il fait venir **Grand Large Cargo** (`require`) |
| Rade | 4 places | 2 places (+1 tous les 10 niveaux de Capitainerie, inchangé) |
| Valeur T1 | ×1,3 | ×1,8 (revenus et droits de port) |

### Mesures (moyenne de 3 parties, bot actif)
| Mesure | Avant | Après | Cible |
|---|---|---|---|
| Revenu à 1 min / 5 min / 10 min | 445 / 996 / 7,4K $/min | **127 / 1K / 5,4K $/min** | départ doux, rattrapage vers 10 min |
| Achats dans les 5 premières minutes | 23 (un toutes les 13 s) | **10–12 (un toutes les 26–31 s)** | une décision toutes les 15–40 s |
| Navires des 3 premières minutes | caboteurs de 213 EVP, 2–4 en rade | **7 petits navires, 0–1 en rade** | « on commence petit » |
| Premier caboteur | 0 s | **2 min 45** (allongement du quai) | 2–3 min |
| Premier responsable | 2 min 20 – 4 min 45 | 5 min | 4–6 min (le début est plus long) |
| Douane et premières amendes | 90 s | **~7 min** (Bureau de douane) | quand le joueur maîtrise la base |
| Premier feeder | ~10 min | 10–11 min | inchangé |
| T1 → T2 | 9 min 30 – 10 min 45 | **11 min 40 – 12 min 37** | 12–15 min |
| T2 → T3 | 31–33 min | **35–37 min** | 35–50 min |
| Fin du MVP | 1 h 11 – 1 h 16 | **1 h 20 – 1 h 22** | 1 h – 1 h 30 |
| Goulots successifs en T1 | Portiques presque tout le temps | **trafic → grue → parc → grue → trafic → douane → quais → parc…** | alternance demande / capacité |
| Camions par navire au début | ~40 | **~4** (petit navire), ~19 (caboteur) | flux lisible |

### Problèmes du milieu de partie (existaient déjà, mesurés, à traiter avec le chantier C)
1. **Demande en excès permanent à partir de ~20 min** : 2 400 EVP/s demandés pour 275 traités, 9 000 navires déroutés par partie (5 900 avant).
   Cause : les niveaux de Capitainerie multiplient la demande sans limite (niveau 80 → ×12 + paliers ×2). Conséquence : les leviers commerciaux
   du chantier C seraient inutiles en T2/T3. **Décision à prendre avec C** : la Capitainerie garde les pilotes, la rade et l'accostage,
   et la demande ne grandit plus que par les classes, les armateurs, le démarchage et les lignes.
2. **Explosion des revenus en début de T2** : ×330 en 7 min 30 (42K → 13,7M $/min), les départements passent du niveau 14 au niveau 63.
   À corriger avec C : valeur T2 et coûts des bâtiments T2.
3. **Plateau « goulot = palier » de 20 à 45 min en T2** : les escales sont au plancher, le seul quai T2 est construit, et on attend le compteur
   d'EVP. Pistes : un 3ᵉ quai en T2, les lignes régulières, le démarchage.
4. **Bâtiments T3 tous achetés dans les 2 min qui suivent le palier** : ils sont trop bon marché face aux revenus T3 (×10 à prévoir).

### Ce qu'il faut savoir pour l'implémentation (pour ne rien refaire)
- **Sauvegardes existantes** (dont la partie en cours du joueur) : version 1 → 2. On ajoute `quay_ext` et `customs1` aux bâtiments déjà construits
  (le joueur avait déjà des caboteurs et une douane), et on recalcule la profondeur des quais. Sans cela, les caboteurs en rade ne pourraient plus accoster.
- **Conseil du goulot « trafic »** : quand un équipement qui attire du trafic est disponible (allongement, bureau de douane, dragage),
  le conseil le désigne avec un bouton CONSTRUIRE, et non plus la Capitainerie. C'est ce qui rend le résultat de l'essai 5 vrai pour un humain.
- **Tutoriel** : nouvelle étape « Le port attend des navires : allonge le quai » après l'achat de Portiques, puis le moment « premier caboteur ».
  L'étape « responsable » passe après le quai.
- **Modèle 3D** : un petit porte-conteneurs (une baie, ~14 m) dans `blender/parts/ships.py`. Le caboteur garde son modèle.
- **Le bot** apprend à économiser pour l'équipement que le conseil désigne (comme un joueur guidé).
- **Tests à adapter** : `ui_smoke` (premier navire), `run_all` (gabarits, demande, douane fermée puis ouverte, migration de sauvegarde).
- **Écran Améliorations** : la carte Capitainerie affiche « Trafic : X EVP/min » avec le détail (navires accueillis, armateurs, réputation, tarifs),
  pour que le joueur comprenne pourquoi le quai et la douane font venir du monde.

---

## 12. Chantier C : faire venir les navires, et le milieu de partie (12/10/2026)

Même méthode qu'au §11 : copie du projet dans le dossier temporaire de la session (le vrai projet **n'est pas modifié**), puis bot
d'équilibrage (joueur actif) avec une sonde `c_probe.gd`. Toutes les 10 s, la sonde relève la demande, la capacité de service (le plus faible
des maillons hors trafic), le goulot, les navires déroutés, les achats et le moment où chaque condition de palier est remplie.
Onze essais, de 2 à 4 graines chacun.

### Constat mesuré (jeu actuel, 3 graines)
| Mesure | T1 | T2 | T3 |
|---|---|---|---|
| Temps où la demande dépasse 1,5 × la capacité | 13–24 % | **100 %** | **100 %** |
| Goulot « au plancher / attendre le palier » (`min_time` + `tier`) | 0 % | **69–84 %** | **84–88 %** |
| Bâtiments achetés dans les 90 s qui suivent le palier | — | 1 sur 11 | **6 sur 8** |
| Revenu 3 min / 6 min après l'entrée dans le palier | — | **×100–115 / ×350–610** | ×1–9 / ×6–12 |
| Niveau de Capitainerie | 1 → 14 | 14 → **63 en 6 min** | 92 → 126 |
| Navires déroutés par partie | | **9 100 – 9 400** | |
| Contrats réussis, hors Corsaire & Fils | | **0 %** | |

### Causes
1. **La Capitainerie est le seul robinet à navires, et il ne se ferme jamais.** Chaque niveau donne +15 %, avec des paliers ×2 et le
   responsable ×2. En fin de partie, la demande est multipliée par environ 600. Un navire dérouté ne coûte rien : rien n'incite à s'arrêter.
   Démarcher, signer des lignes ou proposer des services ne servirait à rien.
2. **Le plancher d'escale est un mur.** Une fois que le pilotage, l'amarrage et les formalités sont à leur temps minimal, plus aucun achat
   n'augmente le débit. Le joueur attend alors que le compteur d'EVP atteigne le palier suivant : 25 min en T2, 30 min en T3.
3. **Les prix du T3 sont calibrés pour un revenu 10 fois plus faible** : quais, rail et zone IMO coûtent 6 à 20 s de revenu.
4. **Les contrats sont presque impossibles (défaut existant).** L'objectif est calculé sur le débit de tout le port. Par exemple,
   « 150 s de débit en 2 jours (180 s) » exige qu'un seul armateur fournisse 83 % du trafic. Seul Corsaire, qui domine le T1, y arrivait parfois.

### Les essais
| Essai | Changement | Résultat | Leçon |
|---|---|---|---|
| 1 | La Capitainerie ne fait plus venir de navires (elle pilote). Demande = classes accueillies × statut du port × armateurs et lignes × services × réputation × tarifs × campagnes. Une ligne s'obtient en réussissant un contrat. | Demande en excès en T2 : 15 % du temps (contre 100 %) | L'idée tient, mais seules des lignes Corsaire se signent |
| 2 | Objectif d'un contrat = **part réelle de l'armateur** (contrat compris), bornée par la capacité, × 60 % | 70 % de contrats réussis ; toutes les lignes signées | Corrige le défaut existant. Il reste un plateau « attendre le palier » sur 51 à 74 % du temps |
| 3 | **Plancher assoupli** : chaque niveau de Capitainerie, Quais ou Douane réduit de 2 % le temps minimal correspondant | Plateau « attendre le palier » à 0 %, capacité en hausse continue ; fin à 1 h 04 – 1 h 09 | Le mur disparaît ; il faut rallonger T2 et T3 |
| 4 | Statut du port ×2,5 en T2 et ×20 en T3 (au lieu de ×6 et ×55), pas de lignes en T1 | Revenu au début du T2 : ×120 en 6 min (contre ×550 en 4 min) | La demande freine 75 % du temps ; les bâtiments T3 partent tous en 1 min |
| 5 | Prix T3 ×10, coût final ×8 | Fin à **2 h 35** | En T3 le revenu reste vers 2–4 Md$/min : les prix doivent suivre ce plateau, pas une croissance |
| 6 | Prix T3 intermédiaires, statut T3 ×35, contrat ×2 au lieu de ×3 | Fin entre 1 h 28 et 1 h 55 | Les lignes avancent au rythme des contrats (une toutes les 2–3 min) : la demande est rationnée |
| 7 | **Lignes achetables** à tout moment, plafonnées par palier ; un contrat réussi donne −50 % sur la ligne suivante | Fin entre 1 h 23 et 1 h 46 | Les lignes T3 (×2,5 par ligne) absorbent tout l'argent |
| 8 | Lignes ×2 par ligne, 4 au plus en T3 | Fin entre 1 h 23 et 1 h 41 | La dernière condition remplie est l'argent (le Système de pilotage arrive en dernier dans la liste) |
| 9 | Fin du T3 allégée (Scanner à portique → Système de pilotage : 3 à 8 Md$, coût final 8 Md$) | **Fin entre 1 h 15 et 1 h 29** | Retenu |
| 10 | Coût des niveaux ×20 en T2 et ×400 en T3 (contre l'emballement) | Emballement inchangé ; en T3, les grues bloquent 37–44 % du temps | **Rejeté** : l'emballement vient des licences, et les niveaux restent le levier continu |
| 11 | Allongement du quai 300 $ au lieu de 250 $ | Quai à 3 min 50, T1 = 14 min | **Rejeté** : on garde 250 $ |

### Réglages retenus
| Élément | Avant | Après |
|---|---|---|
| Capitainerie | « Trafic » +15 %/niveau, paliers ×2, responsable ×2 | **Pilotage** : vitesse du pilote, pilotes et places en rade (inchangé), et elle abaisse le plancher de pilotage. Responsable : accostage auto + pilotage ×2 |
| Demande | Capitainerie × classes × armateurs × réputation × tarifs | classes accueillies × **statut du port** (T1 ×1, T2 ×3, T3 ×35) × **armateurs (poids × (1 + 1,5 × lignes), ×2 si un contrat est en cours)** × **services** × réputation × tarifs × **campagnes** × Renom |
| Armateurs T2/T3 | arrivent seuls au palier | **à démarcher** (salon maritime) : Nordhaven 60 K$, Sakura Bay 400 K$, Chimex 500 M$ |
| Lignes régulières | — | aucune en T1 ; au plus 3 par armateur en T2, 4 en T3. Coût 200 K$ (T2) ou 500 M$ (T3), ×2 à chaque ligne, −50 % après un contrat réussi avec cet armateur |
| Campagnes de démarchage | — | **Affiches sur le port** (trafic ×1,5 pendant 2 min 30, recharge 5 min, prix = 20 s de revenu, au moins 40 $) ; **Annonce au journal maritime** (après le bureau de douane : ×2 pendant 4 min, recharge 10 min, prix = 60 s de revenu, au moins 300 $) |
| Services aux navires (bâtiments) | — | **Ponton d'avitaillement** T1 1 000 $ (trafic +20 %, patience +30 %) ; **Atelier de réparation navale** T2 400 K$ (trafic +20 %, +50 % de droits par escale) ; **Station de soutage GNL** T3 400 M$ (trafic +25 %, +50 % de droits) |
| Plancher d'escale | mur fixe (÷ bâtiments, ÷ Renom) | et ÷ (1 + 2 % × (niveau − 1)) du service concerné : Capitainerie (pilotage), Quais (amarrage), Douane (formalités) |
| Nouveaux bâtiments T3 | — | **Pilotage à distance** 4 Md$, **Amarrage automatique** 5 Md$, **Douane dématérialisée** 6 Md$ (temps minimal ×0,6 chacun) |
| Prix T3 | quai n°3 30 M$ … TOS 3 Md$ | quai n°3 200 M$, GNL 400 M$, IMO 600 M$, rail 1 Md$, RTG 1,5 Md$, quai n°4 2,2 Md$, hors-gabarit 3 Md$, scanner 3 Md$, … TOS 8 Md$ ; Concession nationale 8 Md$ (au lieu de 5) |
| Contrats | objectif = n s × débit de tout le port ; armateur ×3 au tirage seulement | objectif = 50 % de ce que l'armateur apportera pendant le contrat ; le contrat **ajoute** ses navires (armateur ×2 dans la demande) ; nouveau contrat Chimex sans cargaison imposée |
| Révélation | — | « Commerce » après 10 escales (avant la douane) |

### Mesures finales (4 graines, joueur actif)
| Mesure | Avant | Après | Cible |
|---|---|---|---|
| T1 → T2 | 12 min 40 – 13 min 42 | **11 min 17 – 13 min 02** | 12–15 min |
| T2 → T3 | 35–36 min | **24–28 min** | 35–50 min (ancienne cible) : le T2 est plus court, mais sans attente |
| Durée du T3 | 33–35 min | **38–50 min** | — (le temps gagné en T2 passe en T3) |
| Fin du MVP | 1 h 21 – 1 h 24 | **1 h 15 – 1 h 29** | 1 h – 1 h 30 |
| Demande > 1,5 × capacité (T2 / T3) | 100 % / 100 % | **10–17 % / 16–23 %** | des pics, pas un état permanent |
| « Attendre le palier » (T2 / T3) | 26–34 % / 84–88 % | **0 % / 0 %** | 0 % |
| Goulots du T2 | plancher 43–57 %, palier 26–34 % | **navires 50–65 %**, grues, gate, quais, douane, parc… | alternance |
| Goulots du T3 | palier 84–88 % | **navires 46–57 %, plancher 20 %, parc 7–17 %**, grues, quais | alternance |
| Bâtiments T3 | 6 sur 8 en 90 s | **étalés de +0 à +30 min** | un achat marquant toutes les 2–4 min |
| Revenu 3 / 6 min après l'entrée en T2 | ×100–115 / ×350–610 | **×3–17 / ×56–150** | montée forte mais étalée |
| Navires déroutés | 9 100 – 9 400 | **4 900 – 6 100** (pics de contrats et de campagnes) | rares |
| Contrats réussis | Corsaire seulement | **≈ 70 %** (Chimex : 0–1 sur 4–5) | la plupart |

### Limites qui restent (non corrigées, mesurées)
- **L'emballement au début du T2 est atténué, pas supprimé.** La cause profonde, ce sont les licences : leur valeur augmente d'environ 10 %
  par niveau et leur coût de 20 %. Chaque hausse de débit ×k devient donc une hausse de revenu d'environ ×k^2,2. Changer cela toucherait toute
  la courbe des prix : c'est un autre chantier (« économie des licences »), à faire seulement si le jeu réel le montre gênant.
- **Avec le bot, la demande est le goulot la moitié du temps en T2 et T3**, parce qu'il achète chaque niveau de capacité abordable.
  Un joueur humain achète moins de niveaux et verra plus souvent des goulots de capacité.
- **En T3, le revenu progresse peu** (de 1 à 5 Md$/min) : l'argent part dans les lignes et les bâtiments. Les prix sont calibrés pour cela.
- **Les relations avec les armateurs plafonnent vite à 100** (+2 par escale réussie). Elles ne servent donc pas encore de levier.
- **Chimex** n'a presque que des cargaisons IMO : ses contrats échouent souvent.

### Implémentation (dans cet ordre, pour ne rien refaire)
1. **Simulation et données** : `sim/commerce.gd` (campagnes, démarchage, lignes), demande et plancher dans `port_sim.gd`, objectif des contrats
   dans `objectives.gd`, effets `patience` et `ship_fee`, données ci-dessus. Le bot apprend les campagnes, le démarchage et les lignes.
2. **Sauvegardes (version 3)** : une partie d'avant garde ses armateurs déjà présents (marqués « démarchés ») et reçoit le Commerce tout de
   suite. Ses niveaux de Capitainerie deviennent du pilotage. Sa demande baisse donc fortement : un message l'explique et désigne le Commerce.
3. **Interface** : le bouton Contrats devient **Commerce**, avec trois onglets. *Trafic* : la demande et son détail, plus les campagnes.
   *Armateurs* : présence, démarchage, lignes. *Contrats* : inchangé. La carte Capitainerie affiche le pilotage. Le conseil « Pas assez de
   navires » ouvre le Commerce (ou les Bâtiments s'il désigne un équipement).
4. **Tutoriel et révélations** : la révélation « Commerce » explique les affiches. L'étape « contrats » devient « Commerce ».
5. **3D** : les nouveaux bâtiments réutilisent des modèles existants (ponton, atelier, cuve GNL, tour), posés dans `Layout.PROPS`.
6. **Tests** : `run_all` (demande sans Capitainerie, campagne, démarchage, ligne, remise de contrat, objectif atteignable, plancher assoupli,
   migration) ; `ui_smoke` (ouvrir le Commerce, lancer une campagne, signer une ligne) ; `balance.gd` et `prestige_curve.gd` à relancer.

---

## 13. Écarts relevés face à Idle Supermarket Tycoon : essais et mesures (13/10/2026)

Point de départ : `docs/PROMPT_ECARTS_ISM.md` (session mesurée sur Idle Supermarket Tycoon). Même méthode qu'aux §11–12 :
copie du projet dans le dossier temporaire de la session, puis sonde `tests/pacing_probe.gd` (bot « joueur actif », 4 graines).
La sonde accepte maintenant des réglages en mémoire (`--set=config.licence_max=[25,60,100]`, `--mul=buildings.?tier:3.cost=0.2`,
`--set=missions.t1.income_seconds=30`…), ce qui a permis de lancer 4 à 6 essais en parallèle sans toucher aux fichiers.

### Ce que la sonde mesure en plus
- **Revenu d'exploitation** (hors primes de contrat et d'enchères, qui faussaient la minute isolée) ; croissance et baisses sur une
  **moyenne glissante de 3 min** (un Panamax ou un brouillard fait varier une minute isolée de ×3).
- **Rentabilité du meilleur achat** toutes les 30 s : coût ÷ gain de revenu estimé, pour les niveaux, les licences **et le contenu**
  (bâtiments, lignes, armateurs ; état modifié puis rétabli).
- Rapport T2 / T3 à +3 / +6 / +10 min, plus forte croissance par minute, 1ᵉʳ et 4ᵉ bâtiments du T3, niveau de licence à chaque palier.

### Constat de départ (4 graines, revenu d'exploitation)
| Mesure | Mesuré | Lecture |
|---|---|---|
| T2 +3 / +6 / +10 min | ×3,9–12 / ×65–128 / ×379–954 | emballement |
| Licence Standard à l'entrée du T2 / du T3 / à la fin | 21–23 / 74–75 / 89–91 | ×25 → ×2 500 → ×12 000 de valeur |
| Lignes régulières T2 | les 12 signées en 4 min 30 après l'entrée du T2 | demande ×5 d'un coup : **second moteur** de l'emballement |
| Bâtiments T3 | 1ᵉʳ à +0–20 s, 4ᵉ à +44 s – 1 min 27 | trop bon marché |
| Rentabilité du meilleur achat (médiane) T2 | 5–12 min | la demande limite 40–60 % du temps : les niveaux ne rapportent rien |

### Les essais
| Essai | Changement | Résultat | Leçon |
|---|---|---|---|
| 1 | Modèle ISM strict : +8 %/niveau, paliers ×1,25 / ×1,25 / ×1,5 / ×1,5 / ×2 / ×2 aux niveaux 25…200, coût ×1,06, plafonds 50/120/200 | T2 à 14–18 min, revenu à 10 min divisé par 5, T3 jamais atteint en 3 h | En T1 la licence porte une bonne part de la valeur : ses 20 premiers niveaux doivent rester |
| 2 | +25 %/niveau gardé, **paliers finis et décroissants** ×2 (10, 20), ×1,5 (30, 50, 75, 100), ×2 (150, 200), coût ×1,2 | T1 identique au niveau près ; T2 +10 min ×120–230 ; T3 à 51–64 min, fin > 3 h | Il reste l'emballement des lignes ; les prix T2/T3 suivaient l'ancien revenu |
| 3 | Essai 2 + coût ×1,1, plafonds 30/100/200 | Les licences sautent au plafond dès l'entrée du T2 : +3 min ×30–45 | Licence bon marché + plafond = saut instantané, pas une montée |
| 4 | Lignes T2 : coût ×3 à ×5, croissance ×3 ou ×4, gain par ligne 1,0 | Coût 1 M$ : T2 +10 min ×45–90 | Les lignes s'étalent sur 10–15 min ; 1 M$ retenu |
| 5 | Fin du T2 ×0,5, T3 ×0,12–0,2 | T3 à 40 min mais fin à 2 h 35 : 4 bâtiments T3 en 3 min, les 5 derniers en 80 min | L'échelle géométrique héritée ne convient plus : il faut une échelle T3 resserrée |
| 6 | Échelle T3 resserrée (60 M$ → 750 M$), valeur T3 ×10 ou ×15 | ×15 : fin 1 h 21 – 1 h 54 | Quand tout le reste est prêt, le bot n'économisait pas pour l'argent du palier final (il le gagnait par hasard) |
| 7 | **Le bot économise pour le palier quand le reste est prêt** ; début de T3 plus cher | Fin 1 h 28 – 1 h 39 ; 1ᵉʳ bâtiment T3 à +1–2 min 30 | La fin est réglée par le volume d'EVP exigé |
| 8 | Volume final 2,6 M → 2,2 M EVP, valeur T3 ×18, plafonds de licence | Fin 1 h 13 – 1 h 33 ; des plafonds 30/70/120 ne sont jamais atteints | Plafonds 25/60/100 : atteints en fin de palier, sans gêner |
| 9 | **Retenu** : plafonds 25/60/100, début du T3 à 200–500 M$ | Fin 1 h 17 – 1 h 27, 4ᵉ bâtiment T3 à +7–10 min | — |
| 10 | Report dans le projet, avec les missions de guidage (prime de 60–120 s du revenu **estimé**) | T2 à 8–9 min, 30–58 achats en 5 min | L'estimation vaut 3–4× le revenu réel au début, et le début est très sensible : 220 $ à 2 min avancent tout |
| 11 | Primes de 30–45 s du **revenu réel**, coffre toutes les 4 missions (30 s) | T2 à 11 min 14 – 12 min 06 | Retenu (60 s de revenu réel avançait encore le T2 de 1 à 2 min) |

### Réglages retenus
| Élément | Avant | Après |
|---|---|---|
| Paliers de licence (`licence_milestones`) | ×2 tous les 10 niveaux jusqu'à 150 (×32 768) | `[[10,2],[20,2],[30,1.5],[50,1.5],[75,1.5],[100,1.5],[150,2],[200,2]]` : ×81 au total, puis plus rien |
| Plafond de licence par palier (`licence_max`) | aucun | 25 / 60 / 100 (T1 / T2 / T3) |
| Effet et coût par niveau | +25 %, ×1,2 | inchangés (les 20 premiers niveaux du T1 sont identiques) |
| Lignes régulières T2 / T3 (`line_cost`) | 200 K$ / 500 M$ | 1 M$ / 75 M$ (toujours ×2 par ligne) |
| Fin du T2 | remorqueur 12 M$ … scanner mobile 50 M$ | 9 M$, 10 M$, 15 M$, 20 M$, 22,5 M$, 25 M$ |
| Bâtiments T3 | 200 M$ → 8 Md$ (×40) | 200, 280, 350, 420, 460, 500, 500, 500, 550, 600, 650, 700 M$ (×3,5) |
| Chimex | 500 M$ | 75 M$ |
| Valeur T3 (`value_mult`) | ×10 | ×18 (droits de port inchangés) |
| Concession nationale | 2,6 M EVP, 8 Md$ | 2,2 M EVP, 700 M$ |
| Missions | 17 missions en Ambre | + 3 missions de guidage du T1 (quai, affiches, douane) : Ambre + 30–45 s de revenu réel ; coffre toutes les 4 missions (+2 Ambre, +30 s) |
| Bot | économisait seulement à 30 s du but | économise aussi pour le palier quand toutes les autres conditions sont remplies |

### Mesures finales (vrai projet, 4 graines)
Voir `DECISIONS.md` « Écarts ISM ». En résumé : fin 1 h 17 – 1 h 30, T2 identique à avant, emballement du T2 divisé par 6 à 10,
bâtiments T3 étalés ; restent hors cible la croissance des 3 premières minutes du T2 (le saut de palier lui-même), la rentabilité
en T2 et les trous d'achat du T3.

### Pourquoi certaines cibles ne sont pas tenues
- **+3 min ≤ ×6 et « aucune minute > ×1,6 »** : l'entrée en T2 multiplie d'un coup la valeur (×1,67) et le trafic (×3), et Nordhaven
  arrive dans la minute. C'est le saut voulu du palier (« le palier suivant est le vrai saut ») ; l'essai « trafic T2 ×2,5 » le
  réduit (+3 min ×4–8) mais allonge la fin (1 h 32 – 1 h 47).
- **Rentabilité ≤ 5 min en T2** : un joueur qui réinvestit tout avec une rentabilité P voit son revenu croître comme e^(t/P).
  Tenir ×80 en 10 min impose P ≥ 2,3 min en moyenne, et la demande limite le port 40–50 % du T2 (les niveaux ne rapportent alors rien).
  Le meilleur achat est souvent une ligne ou un bâtiment à 5–15 min de rentabilité : c'est voulu pour étaler le contenu.
- **Baisse ≤ 30 % et trou ≤ 90 s en T3** : les Panamax déchargent par à-coups et le brouillard arrête le pilotage ; le bot économise
  2–3 min pour un bâtiment T3 ou pour l'argent du palier final.
