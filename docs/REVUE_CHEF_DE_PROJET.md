# Revue de direction — Port Horizon V2 (13/10/2026)

Rôle : chef de projet / éditeur. Périmètre : graphisme, gameplay, environnement. Base examinée : `C:\Nadir\tycoon_V2`
(code Godot, scripts Blender, `docs/ANALYSE.md` §1–13, `docs/DECISIONS.md`, `docs/BRIEF_STYLE_PORTS.md`, captures `docs/captures/`,
rendus `docs/previews/`, références `docs/references/ism/`).

Rien n'est lancé tant que les décisions du § 6 ne sont pas validées. Ensuite : un sous-agent **expert Blender** (lot A)
et un sous-agent **développeur Godot** (lots B puis C), avec les ordres de mission du § 5.

---

## 1. Verdict

| Axe | État | Jugement |
|---|---|---|
| Simulation et équilibrage | 124 contrôles `run_all`, 61 `ui_smoke`, 4 graines de bot, courbes dans les cibles | **Solide, au-delà du MVP.** Ne plus y toucher avant un test humain. |
| Graphisme des bâtiments | 3 pilotes ISM faits (capitainerie, douane T1, entrepôt) ; 15 bâtiments restent en ancien style « coupe » | **Pilotes réussis, à généraliser.** Aujourd'hui deux styles cohabitent à l'écran (hangar rouge ouvert à côté de la capitainerie neuve). |
| Rendu dans Godot | Soleil 1,05 + ambiance 0,62 + ombres floues 1,5 ; asphalte gris bleu ; zoom par défaut 52 u | **En retard sur les modèles.** Les bâtiments neufs sont rendus plats et petits. C'est le chantier le moins cher et le plus rentable. |
| Environnement | Terre ferme, village, autoroute, aire d'attente, zone logistique, collines : faits | **Crédible mais vide** : grandes nappes d'herbe à touffes, pas de trottoirs, peu de voitures, personnages fixes. |
| Couche joueur | Tutoriel, narratrice, missions au HUD, révélation progressive, commerce : faits | **Complète sur le papier, jamais jouée par un humain.** Les enseignes sont illisibles, des bulles couvrent les bâtiments. |
| Organisation | Deux dossiers (`tycoon`, `tycoon_V2`) ; V2 = `tycoon` + refonte visuelle, rien de plus récent côté `tycoon` | **V2 doit devenir le seul projet de travail**, `tycoon` gelé comme sauvegarde. |

**Priorité d'éditeur** : rendre le port *beau et lisible à l'échelle de jeu* avant d'ajouter une seule mécanique. La simulation ne
manque de rien pour un test ; l'image, si.

---

## 2. Graphisme

### 2.1 Ce qui marche
- Les rendus avant/après (`docs/previews/style_*.png`) sont convaincants : socle sombre, chape-acrotère, piliers brique, vitrines
  bleues, une couleur d'identité par département. Le vocabulaire `closed_block / facade / awning / sign3d / planter` dans `lib.py`
  est le bon investissement : les 15 bâtiments restants se font avec ces briques.
- La décision « fermé par défaut » est la bonne : rien ne se joue à l'intérieur, et un intérieur de 4 u est illisible à 52 u de large.

### 2.2 Ce qui ne marche pas encore (vérifié sur `docs/captures/v2_*.png` et `ism_*.png`)
1. **Deux styles à l'écran.** Le hangar T1 (murs rouges, toit gris, ouvert) est posé à 10 u de la capitainerie neuve. Tant que la
   généralisation n'est pas faite, le jeu paraît *moins* cohérent qu'avant.
2. **Les enseignes 3D ne servent à rien** : illisibles même au zoom 28. Le texte ne doit plus porter d'information ; l'identité
   passe par l'objet-emblème (belvédère, scanner, portique, grue) et la couleur. Le texte reste un décor facultatif, en lettres
   d'au moins 0,5 u de haut, ou disparaît.
3. **Les sols sont restés gris.** `asphalt #5A616E`, béton `#DCD8CF`, quai gris : en T3 (`cap_t3.png`) tout le terminal est une
   nappe grise où les bâtiments se perdent. ISM pose un asphalte violet `#5A3E5A`, des marquages épais, un trottoir clair. Les
   teintes sont déjà dans `palette.json` ; les dalles `ground_*`, `quay`, `road` ne les utilisent pas.
4. **Échelle des accessoires.** Chariots, personnages, bollards, cônes sont à l'échelle réelle. La règle 5 du brief (×1,3 à ×1,5)
   n'est appliquée à rien. Dans ISM, un client fait un tiers de la hauteur d'un rayon.
5. **Ombrage et lumière Godot inchangés** (`diorama.gd:82–107`, `vcol.gdshader`). Résultat : dessus et flancs presque de la même
   valeur, ombres floues et pâles. ISM : dessus 100 %, flancs 65–75 %, ombres nettes à −15 % sans noir.
6. **Cadrage.** Au démarrage (`ism_hud_portrait.png`), plus de la moitié de l'écran est de l'eau, le HUD couvre le tiers haut, et le
   quai est coincé en bas. Le zoom par défaut de 52 u et le point de départ `START (-26, 0, -13)` sont pensés pour la rade, pas
   pour le port.
7. **Les bulles d'information cachent les bâtiments** (« 0 camion » sur la table de la douane). Chaque modèle doit déclarer la
   hauteur d'ancrage de sa bulle (`assets_meta.json`), et la surcouche doit s'y caler.
8. **Budget de triangles** : capitainerie 1 462, douane 1 720, entrepôt 2 672 contre 80–300 avant. Acceptable sur PC ; à plafonner
   à **2 500 par bâtiment, 600 par accessoire**, sinon la V2 ne tiendra pas sur mobile (cible annoncée dans la fiche jeu).

### 2.3 Ordre de généralisation (par visibilité dans la partie)
1. **T1, vus dès la première minute** : `hangar` (ouvert sur poteaux, lisible à 90°), `gate_booth`, `barrier`, lampadaires, cônes,
   bollards, personnages (`docker`, `manager`, `customs_officer`, `inspector`), `forklift`, `crane_mobile`, dalles `ground_gravel`,
   `ground_grass`, `quay`, `road`.
2. **T2** : `control_tower` (restyle seulement), `office`, `workshop`, `customs_office`, `reefer_rack`, `scanner`, `ground_asphalt`,
   `ground_parking`, `crane_sts`.
3. **T3** : `inspection_hall` (halle ouverte sur un long côté), `it_center`, `substation`, `imo_fence`, `rail_terminal`, `rtg`.
4. **Arrière-pays** : `house_a/b`, `shop`, `silo`, `stack`, voitures, trottoirs, passages piétons.

---

## 3. Gameplay

### 3.1 Position d'éditeur
La boucle est complète : clic manuel → responsables → hors-ligne → prestige (Renom), objectifs de carrière, paliers nommés, missions
sur le HUD, commerce. Les mesures au bot sont dans les cibles. **Aucune nouvelle mécanique avant un test humain de 20 minutes** :
on ne sait pas si le joueur comprend le goulot, trouve le bouton CONSTRUIRE, ni s'il s'ennuie entre 5 et 12 minutes.

### 3.2 Points à corriger avant ce test (petits, tous côté développeur)
- Les outils de débogage (F1, `--debug-money`, `--tier`) restent actifs en version exportée : à couper derrière `OS.is_debug_build()`.
- Les 2 entrepôts du village affichent la couleur de la zone logistique dès le T1 (`layout.gd:180`) : incohérent avec la révélation
  progressive ; les passer en teinte neutre jusqu'au T3 ou les retirer du T1.
- Bulles qui recouvrent les bâtiments (voir § 2.2 point 7).
- Enseignes illisibles : ne rien faire dépendre du texte (voir § 2.2 point 2).

### 3.3 Backlog gameplay, dans l'ordre que je retiens (après le test humain)
1. **Lots fantômes et révélation des bâtiments** : dans ISM, la section suivante apparaît *dans le monde* avec son prix
   (« Boulangerie 50 000 »). C'est le chaînon qui relie la refonte visuelle au gameplay : une empreinte au sol en pointillés,
   un panneau de prix 3D, un toucher qui ouvre la fiche. C'est le lot C.
2. **Glossaire « ? »** : termes EVP, feeder, gate, IMO, rade. Une carte par terme, accessible depuis les fiches.
3. **Pli de la capitainerie** (prime toutes les 4–6 min) : seule raison de rester devant l'écran hors achat ; à calibrer à
   ≤ 30 s de revenu réel, vu la sensibilité du début de partie à l'argent gratuit (mesurée en É5).
4. Puits d'Ambre, aléas à choix, mouillage extensible.
5. Import/export, nouveau port par concession : **V3**, pas avant.

Hors périmètre maintenu : jour/nuit (coût élevé, gain faible tant que les bâtiments ne sont pas tous refaits), musique, T4.

---

## 4. Environnement

- **Structure** : la cible de l'analyse §1 (mer → quais → parc → gate → aire d'attente → route → village / zone logistique / rail →
  collines) est en place. C'est la bonne.
- **Densité** : ISM remplit chaque mètre entre deux bâtiments (trottoir, lampadaire, arbre, voiture garée, borne, bouche d'incendie).
  Port Horizon laisse des nappes d'herbe à touffes. À faire : trottoirs le long des routes, passages piétons à la gate et au village,
  voitures garées devant les maisons, caisses et palettes sur le tablier, bancs de pêcheurs près du vieux quai, mouettes posées
  sur les bollards.
- **Mer** : trop présente et trop plate. Une teinte plus profonde au large, plus claire près des quais, et un bord de plage net
  réduisent l'effet « île perdue » même sans changer le cadrage.
- **Vie** : personnages fixes qui oscillent. Un simple aller-retour sur rail entre deux points (tablier ↔ parc, gate ↔ guérite)
  avec 3 pas d'animation suffit ; pas besoin de pathfinding.
- **Information posée sur le décor** (règle 9 du brief) : totem « P 7/20 » à l'aire d'attente, compteur de file en rade sur une
  bouée-panneau, minuterie au-dessus de la douane. Dépend des modèles (Blender) et de la surcouche (Godot) : à faire après les lots A et B.

---

## 5. Plan proposé — trois lots, deux sous-agents

### Lot A — Expert Blender : généraliser le style ISM (`blender/`)
Entrée : `docs/BRIEF_STYLE_PORTS.md` (règles 1–10 et table du § 3 bis), `lib.py`, les 3 pilotes comme modèles.
Travail, dans l'ordre du § 2.3 :
1. Bâtiments T1 puis T2 puis T3 avec `closed_block` et les pièces existantes ; hangar et halle d'inspection ouverts selon la table.
2. Dalles de sol et quai aux teintes ISM (`asphalt_violet`, `sidewalk`, `grass_lime`, marquages `#EFEBEF` épais), trottoirs et
   passages piétons comme nouvelles dalles.
3. Accessoires et personnages à ×1,35 (bollards, cônes, lampadaires, pots, personnages à 1,35 u), voitures aux couleurs franches
   avec toit plus clair et feux rouges.
4. Nouveaux modèles : `sidewalk`, `crosswalk`, `car_parked` ×2, `sign_p` (totem P), `ghost_lot` (empreinte en pointillés pour le lot C).
Règles non négociables : couleurs uniquement via `palette.json` ; face principale en −Y ; aucune information portée par du texte ;
≤ 2 500 triangles par bâtiment, ≤ 600 par accessoire ; `assets_meta.json` reçoit pour chaque bâtiment `anchor_y` (hauteur de bulle)
et `footprint` (largeur, profondeur).
Livrable : `docs/previews/style_<asset>.png` avant/après pour chaque modèle, `build_assets.py` qui passe sans erreur, `--import` Godot vert.
Durée estimée : 2 sessions (T1 + sols ; puis T2/T3 + accessoires).

### Lot B — Développeur Godot : rendu, cadrage, nettoyage (`godot/`) — parallèle au lot A
1. Lumière (`diorama.gd`) : ambiance 0,62 → ~0,35, soleil 1,05 → ~1,3, `shadow_blur` 1,5 → ~0,4, teinte d'ombre violacée, dessus
   100 % / flancs 65–75 % ; vérifier sur le nuancier `swatch_test.tscn` que les teintes de `palette.json` restent fidèles.
2. Cadrage (`camera_rig.gd`) : zoom par défaut 52 → 40, `START` recentré sur quai + parc, bornes inchangées ; vérifier le portrait
   540×960 et le paysage 1280×720 par captures.
3. Surcouche (`world_overlay.gd`) : ancrage des bulles sur `anchor_y` de `assets_meta.json`, décalage latéral quand deux bulles se
   chevauchent.
4. Débogage coupé en version exportée (`OS.is_debug_build()`), ligne « F1 » retirée des Réglages hors debug.
5. Entrepôts du village neutres jusqu'au T3 (`layout.gd`).
6. Personnages : aller-retour simple entre deux points avec balancement, sur les 4 modèles.
Livrable : `run_all.gd` et `ui_smoke.tscn` verts (124 / 61 contrôles, aucun retiré), jeu de captures `docs/captures/v2b_*.png` aux
mêmes cadrages que `ism_*.png` pour comparer, note dans `DECISIONS.md`, copie zip préalable dans `C:\Nadir\tycoon_backups\`.
Durée estimée : 1 session.

### Lot C — Développeur Godot : lots fantômes et révélation des bâtiments — après A et B
Empreinte `ghost_lot` à l'emplacement du prochain bâtiment constructible, panneau de prix 3D (nombre dessiné par la surcouche, pas
par du texte 3D), toucher → fiche du bâtiment, construction avec nuage de poussière (`_build_stage_props` existe déjà), caméra qui
cadre le nouveau bâtiment 2 s. Le tutoriel pointe l'empreinte au lieu du menu Bâtiments. Tests ajoutés (`run_all` + `ui_smoke`).
Durée estimée : 1 session.

### Puis : test humain
20 minutes de jeu par l'utilisateur, partie neuve, sans aide. Je note : première action, temps avant le premier achat, moment où il
cherche quelque chose sans le trouver, moment d'ennui. C'est ce test qui décide du backlog § 3.3, pas une nouvelle passe de bot.

---

## 6. Décisions à valider avant de lancer

1. **`tycoon_V2` devient le seul projet de travail** ; `tycoon` n'est plus modifié (c'est déjà le cas de fait : V2 = `tycoon` + refonte).
2. **Généraliser le style ISM** aux 15 bâtiments restants, sols et accessoires, selon l'ordre du § 2.3 et la table du brief § 3 bis.
3. **Abandonner le texte 3D comme porteur d'information** (enseignes décoratives ou supprimées ; emblème + couleur à la place).
4. **Budget** : ≤ 2 500 triangles par bâtiment, ≤ 600 par accessoire.
5. **Lots A et B en parallèle, C ensuite, test humain après C.** Aucune nouvelle mécanique avant ce test.
6. Sols : **asphalte violet** comme ISM, ou bleu-gris chaud (règle 6 du brief laisse le choix). Je recommande le violet, plus
   éloigné du bleu de la mer.

Points que je ne tranche pas sans vous : le personnage de la narratrice reste-t-il en portrait dessiné ou passe-t-il en 3D (coût
Blender) ; faut-il garder le hangar T1 à 90° ou le tourner à 0° pour simplifier son modèle.
