# Ordre de mission — lot G2 « Le Terre-plein : le premier navire à la main » (15/10/2026)

> Pour le sous-agent **développeur senior Godot**, **après la livraison et la vérification de G1** (mêmes fichiers). Source :
> `docs/CADRAGE_DEBUT.md` § 4, 6, 7, 11 et 12 (validé). Modèles : `docs/ORDRE_BLENDER_G.md` § 2 « terre-plein » (`ground_platform`,
> `quay_small`, `track_dirt`, `barrier_post`, `coaster_crane`, `container_wait` / `container_ok`) ; `customs_hut` existe déjà.

## Règles (impératives)
Celles de `docs/ORDRE_G1_CRIQUE.md`. Paliers : étape 0 (note de faisabilité : comment la simulation porte le déchargement par grue de
bord, les gestes tamponner / laisser passer, la capacité des responsables, ce qui casse dans le T1 actuel), G2-a (simulation +
sonde), G2-b (monde + interface + narration), G2-c (calage, captures, APK). La sonde mesure **depuis la Concession** (G1) : T2, T3, fin
dans ±5 % en moyenne, ±15 % par graine ; **premier camion 4 à 5 min après la Concession**.

## 1. Fin de la séquence automatique du T1
Aujourd'hui, la Concession lance les chantiers quai → grue → parc → gate (`start_t1_works`). **Supprimé.** Après la Concession, la
friche est nue (rochers, broussailles, `jetty_ruin`) et la liste AMÉLIORER propose **un seul achat** à la fois, dans l'ordre du § 6.1 :

| Ordre | Achat | Prix (à caler) | Chantier | Ce qui se passe |
|---|---|---|---|---|
| 1 | Terrassement | ≈ 150 $ | 6 s (`excavator`, `dust_pile`) | la friche devient `ground_platform` ; rien ne bouge |
| 2 | Quai n°1 | ≈ 200 $ | 6 s | `quay_small` ; le caboteur de Corsaire & Fils (celui du passage au large) se présente en rade |
| 3 | Cabane de douane | ≈ 120 $ | 3 s | `customs_hut`, un `customs_officer` ; les conteneurs posés attendent le tampon |
| 4 | Piste et barrière | ≈ 150 $ | 4 s | `track_dirt` jusqu'à la route de la criée, `barrier_post` ; un camion se présente |

Les bâtiments actuels du T1 (`quay_ext`, `gravel2`, `customs1`, `supply`, `crane2`, `dredge1`, `gravel3`) restent, **après** ces
quatre, aux prix actuels ; `customs1` « Bureau de douane » devient une amélioration de la cabane (même emplacement, remplace le modèle).
Nouveaux : **Grue mobile** (≈ 300 $, `crane_mobile`, remplace la grue de bord) et **Parc de stockage** (≈ 400 $, gravier) deviennent
des achats, entre la barrière et `quay_ext`. Les prix sont calés par la sonde pour tenir le jalon T2.

## 2. FAIRE : le processus à la main (§ 6.1)
Avant tout responsable, **rien n'avance sans le joueur** ; si le joueur tarde, il perd (navire qui perd patience, camion qui repart) ;
s'il quitte, **le monde se fige** (pas de hors-ligne avant le premier responsable du port : § 12 Q2).
- **Accoster** : le geste existe (toucher le navire en rade). Sans Léon, aucun accostage automatique (`auto_berth_delay` inactif).
- **Décharger** : sans grue mobile, le caboteur décharge **avec sa grue de bord** (`coaster_crane`, `boom`/`hook` animés), lentement
  (≈ 1 EVP / 8 s, à caler) ; les conteneurs sont posés sur la plateforme (`container_wait`). Aucun geste ici.
- **Tamponner** : les conteneurs posés attendent la douane ; **toucher la cabane** tamponne le lot présent (étiquettes orange → vertes,
  `container_ok`, son de tampon). Sans tampon, rien ne sort et la plateforme se remplit.
- **Laisser passer et encaisser** : un camion se présente à la barrière ; **toucher la barrière** (`arm` se lève) = il charge 2 EVP
  dédouanés, **paie** (pièce vers le compteur) et part sous les arbres. Un camion non servi repart après ≈ 20 s, sans rien ; bulle
  rouge avant. **Un seul geste** : laisser passer encaisse (§ 11 réponse 1).
- **Plateforme pleine** (avant la barrière ou si on tarde) : bulle « il faut une sortie », pastille de goulot. C'est la première
  apparition du goulot ; le bouton AGIR existant pointe l'achat suivant.
- Les gestes actuels du parc (chariot) et de la gate (barrière) sont **remplacés** par tamponner / laisser passer ; le coup de main
  grue ×1,2 disparaît (§ 12 Q1).

## 3. CONFIER : les responsables, un par geste (§ 6.2)
Après **5 répétitions** d'un geste, son responsable se présente (bulle sur le lieu + une carte de la narratrice), **un à la fois**, dans
l'ordre accoster → tamponner → laisser passer ; jamais deux à moins de 45 s :

| Geste | Responsable | Prix (à caler) | Ce qu'il ouvre |
|---|---|---|---|
| accoster | Léon Barbier | ≈ 150 $ | service **Accostage** |
| tamponner | Paul Delmas (passe du T2 au T1 : § 12 Q8) | ≈ 200 $ | service **Douane** |
| laisser passer | Tonio Ferrer | ≈ 250 $ | service **Sortie camions** |

- Une fois embauché, le responsable **remplace** le geste : plus de bulle, toucher ne fait rien. Il a une **capacité** = le débit du
  service à son niveau ; au-delà, la file grandit et le service devient le goulot (mécanique actuelle). Les **niveaux du service sont son
  personnel et son matériel** (§ 12 Q3) : chaque niveau ajoute un personnage visible au poste (jusqu'à 3 par poste), les paliers nommés
  existants (`stages`) restent.
- **La carte à niveaux d'un service apparaît à l'embauche de son responsable** (Accostage, Douane, Sortie camions), **ou à la
  construction de son bâtiment** : Déchargement avec la grue mobile (Yasmine se présente ensuite au niveau 10, règle actuelle),
  Stockage avec le parc (Nadia idem), **Arrivées avec le Quai n°2** (T2 : la rade ne se gère qu'avec une file ; Mathilde idem).
  Avant cela, aucune de ces cartes n'existe ; l'ordre dans AMÉLIORER est l'ordre du processus : Arrivées · Accostage · Déchargement ·
  Douane · Stockage · Sortie camions, le prochain bâtiment **en tête de liste**.
- Hors-ligne : dès le premier responsable du port, règle actuelle (50 % → 100 % selon les responsables).
- Le premier responsable du port révèle Heures sup si Marcel ne l'a pas déjà fait (G1).

## 4. Noms de métier (§ 7) — `departments.json`, `unlocks.json`, `tutorial.json`, `advice.gd`, textes, tests
| Avant | Après |
|---|---|
| Capitainerie | **Arrivées** (le bâtiment du décor garde « Capitainerie ») |
| Quais | **Accostage** |
| Portiques | **Déchargement** |
| Douane | **Douane** |
| Parc et manutention | **Stockage** |
| Gate | **Sortie camions** |
Les identifiants (`harbor`, `berths`, …) ne changent pas ; seuls les noms, descriptions et conseils. Chasser « gate », « portique »,
« EVP » dans les textes vus avant le T2 (dire « conteneur »). Les révélations de `unlocks.json` qui concernent les chapitres actuels
(« Chapitre 2 : les engins… », « Chapitre 3 : la gate… ») sont réécrites selon § 8.2 du cadrage : chaque révélation est un geste ou un
métier que le joueur vient de faire.

## 5. Narration et tutoriel
Mathilde tient le fil du premier navire, une carte par geste, avec projecteur sur la cible : « Il doit accoster : touche-le. » « Les
conteneurs attendent le tampon de la douane : touche la cabane. » « Un camion vient le chercher : touche la barrière, il paie en
passant. » Puis, à chaque responsable : « X se présente : il fera ça pour toi, même quand tu es parti. » Les cartes du tutoriel actuel
devenues fausses (« un vieux quai, une grue rouillée… », goulot, allongement) sont réécrites ou retirées ; l'étape « goulot » vient
après le premier « il faut une sortie ».

## 6. Sonde et bot
Le bot fait les gestes (avec un délai humain de 1 à 3 s), achète dans l'ordre, embauche chaque responsable dès qu'il se présente.
Mesures depuis la Concession : premier camion (cible 4 à 5 min), Léon / Paul / Tonio (cible 6 à 8 min), grue mobile et parc
(cible 8 à 12 min), T2 (cible inchangée : 12 à 14 min), T3, fin. Tableau avant/après au journal.

## Fin de lot
Tests verts (nombre avant/après ; contrôles ajoutés : plus de séquence automatique, grue de bord, tamponner, laisser passer et
payer, camion qui repart, plateforme pleine, responsable après 5 gestes et remplacement du geste, apparition des cartes avec
bâtiment/responsable, noms, monde figé sans responsable), sonde dans les tolérances, captures `docs/captures/g2_*` regardées
(friche après Concession, chaque achat et chantier, caboteur avec grue de bord, conteneurs orange puis verts, camion à la barrière,
plateforme pleine, chaque responsable, liste AMÉLIORER à 3 moments), `PLAN_COTE.md` (plateforme, quai n°1, piste), `UNIVERS.md`,
journal § « Lot G2 », DECISIONS, **APK réexporté**. Rapport : fait / non fait (raison), chiffres, captures.
