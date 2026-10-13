# Prompt — Port Horizon : corriger les écarts relevés face à Idle Supermarket Tycoon

> À coller tel quel dans une nouvelle session Claude Code ouverte sur `C:\Nadir\tycoon`.
> Rédigé le 12/10/2026 après une session de jeu mesurée sur Idle Supermarket Tycoon (ISM, Google Play Jeux PC)
> et une sonde de rythme sur Port Horizon (`tests/pacing_probe.gd`, graines 1 et 2).

---

## Contexte

Tu travailles sur **Port Horizon**, un idle tycoon portuaire en Godot 4.7 (`C:\Nadir\tycoon\godot`). Lis d'abord
`docs/DECISIONS.md` (état et choix d'équilibrage) et `docs/ANALYSE.md` §10–12 (méthode de prototypage au bot), puis les fichiers cités
plus bas. Le jeu est déjà complet sur la boucle idle : départements, licences, bâtiments, paliers T1→T4, responsables, hors-ligne,
prestige (Renom), missions, commerce, tutoriel, révélation progressive. **Ne refais rien de ce qui existe** : ce chantier corrige des
écarts précis, mesurés, listés ci-dessous.

### Règles du projet (impératives)
- **Pas de git** : avant toute modification du vrai projet, zippe `godot/`, `blender/`, `docs/` dans
  `C:\Nadir\tycoon_backups\port_horizon_avant_ecarts_ism_<date>.zip`.
- **Analyser et prototyper avant de coder** : prototype dans une **copie** du projet (dossier temporaire de la session), mesure avec le
  bot, itère, puis seulement reporte dans le vrai projet. L'utilisateur ne veut pas tout refaire ensuite.
- Godot : `C:\Nadir\Godot\Godot.exe`. En PowerShell, lance-le avec `Start-Process … -RedirectStandardOutput … -PassThru` puis
  `WaitForExit` (les pipes bloquent). Pas de Python sur la machine.
- Tests : `--headless --script res://tests/run_all.gd` ; `ui_smoke.tscn` se lance **comme une scène** (`--headless --path … res://tests/ui_smoke.tscn`).
  Sondes : `tests/pacing_probe.gd -- --seeds=1,2,3,4`, `tests/balance.gd`, `tests/prestige_curve.gd`.
- Après tout nouveau `class_name` : `--headless --import` **avant** toute capture fenêtrée (sinon `main.gd` plante).
- Toutes les valeurs dans `godot/data/*.json` (aucune constante d'équilibrage en dur).
- Si le format de sauvegarde change : version 3 → 4 avec migration dans `PortSim` (comme `_upgrade_legacy_save` / `_upgrade_commerce_save`),
  vérifiée sur une copie de la vraie sauvegarde du joueur. Ne jamais écrire la vraie sauvegarde depuis un test.
- Documentation en français : nouvelle section `ANALYSE.md` §13 (essais et mesures) et `DECISIONS.md` « Écarts ISM » (réglages retenus).
- Avance sans redemander entre les étapes, en vérifiant par tests, sondes et captures. Arrête-toi et demande seulement si une cible
  ci-dessous est impossible à tenir sans casser une autre.

---

## 1. Ce qu'on a mesuré dans Idle Supermarket Tycoon (référence)

### Boucle
Rayons (Fruits, Légumes, puis d'autres débloqués par des tâches) → caisses → sortie. Chaque client passe dans chaque rayon et paie à la
caisse la **somme des prix** (le « gain par client »). Le revenu réel est plafonné par le **flux de clients** (parking, entrée), pas par
les rayons : le HUD affiche le *potentiel* des rayons (527 $/min) alors que le revenu réel mesuré était de **160 $/min** (puis
2 948 affichés pour **569 réels**, soit 19 à 30 %).

### Un rayon = 3 axes d'amélioration aux courbes différentes
| Axe | Coût | Effet | Remarque |
|---|---|---|---|
| **Niveau** | `base × 1,02^(niv−1)` (Fruits 2,50 ; Légumes 10) | prix `base × (1 + 0,07 × (niv−1))` × paliers | achat bon marché, **appui long = achat en rafale qui accélère** (25 → 68 en 4 s) |
| **Employés** | 10 → 50 (Fruits), 30 → 250 (Légumes) : ×5 | capacité ×1 → ×2 → ×3, **max 3** | gros saut discret, visible (un employé apparaît) |
| **Traitement** | 10, 12, 13, 15… (≈ ×1,15) | temps −2,5 % par niveau (2 s → 1,95 → 1,90 → 1,86) | levier secondaire, moins rentable |
| Caisse (formation) | 4 ; 4,80 ; 5,76 ; 6,91 (×1,20) | débit +≈2 %/niveau (12 → 12,7 clients/min) | 2ᵉ caisse 50 $ = débit ×2 |

### Paliers de niveau (popup « i » qui les montre tous d'avance)
Niveau 25 : ×1,25 · 50 : ×1,25 · 75 : ×1,5 · 100 : ×1,5 · 150 : ×2 · 200 : ×2, soit **×14 au total, puis plus rien**.
À chaque palier, le **produit change de nom et d'icône** (Fruits blets → Fruits mûrs → … → Fruits saisonniers → Fruits rafraîchissants),
et **le rayon grandit visuellement** (plus d'étals, plus d'employés à niveau 100). Vérifié : prix niv. 25 = 2,68 × 1,25 = 3,35 ;
niv. 91 = 7,30 × 1,25 × 1,25 × 1,5 = 17,11.

### Rentabilité d'un achat (temps pour se rembourser, sur le potentiel)
| Achat | Coût | Gain | Rentabilisé en |
|---|---|---|---|
| Fruits niv. 1 → 2 | 2,50 | +2,00 $/min | 1,3 min |
| Fruits niv. 10 → 11 | 2,99 | +2,10 $/min | 1,4 min |
| Fruits niv. 68 → 69 | 9,42 | +10,58 $/min | 0,9 min |
| Fruits niv. 102 → 103 | 18,47 | +23,81 $/min | 0,8 min |
| 2ᵉ employé Fruits | 10 | ×2 capacité (+55 $/min) | 0,2 min |
| Section Légumes | 200 | +80 $/min (49 → 129) | 2,5 min |

→ **La rentabilité reste plate sur 100 niveaux** (0,8 à 1,5 min de potentiel, soit 3 à 7 min de revenu réel). La croissance
ne vient pas d'un emballement composé mais du **contenu débloqué** : nouvelles sections (le panier s'allonge), puis nouvelles villes
(Paris, Londres, Tokyo, Hong Kong, New York). Chaque section plafonne (paliers finis, 3 employés au plus).

### Couche joueur
- **Tâches toujours visibles en haut de l'écran** : 2 tâches actives avec barre de progression (« Accueillez 50 clients aux Légumes »,
  « Fruits au niveau 175 »), récompense en argent (120 $ ≈ 1 min de revenu) d'un toucher, et une barre de coffre au-dessus. La chaîne
  de tâches **ouvre les sections suivantes**.
- **Statistiques** : gain par client, clients/min, capacité, remplissage du parking, file et attente à la caisse, et par rayon :
  valeur, profit/min, capacité, avec les étiquettes **« Meilleur rayon »** / **« Moins lucratif »**.
- **Tutoriel** (~4 min) : un personnage récurrent (« Assistant », plusieurs poses), bulles d'une phrase, main qui pointe,
  **tout le reste est verrouillé** pendant l'étape. Il laisse le goulot **se produire à l'écran** (file à la caisse + visage furieux) puis
  demande la correction (2ᵉ caisse) : le joueur comprend le concept en le voyant.
- **Retour immédiat** : le chiffre $/min du HUD bouge au moment de l'achat ; montant flottant au-dessus de la caisse à chaque client.
- Monétisation (à **ne pas** copier) : pubs récompensées, gemmes, accélérateurs de temps, directeur payant qui prolonge le hors-ligne.

---

## 2. Ce qu'on a mesuré dans Port Horizon (sonde actuelle, bot actif, graines 1 et 2)

| Mesure | Graine 1 | Graine 2 | Lecture |
|---|---|---|---|
| T1 → T2 / T2 → T3 / fin | 11 min 17 / 36 min 21 / 1 h 30 | 11 min 38 / 38 min 07 / 1 h 12 | dans les cibles |
| Revenu T2 +0 / +3 / +6 / +10 min | 153 K → 2,29 M → 16,3 M → **113 M $/min** | 77 K → 247 K → 9,6 M → **84 M $/min** | **×740 à ×1 090 en 10 min** (≈ ×2 par minute) |
| Revenu T3 +0 / +3 / +6 / +10 min | 1,24 Md → 528 M → 1,13 Md → 2,69 Md | 1,96 Md → 831 M → 5,68 Md → 2,19 Md | **plat, parfois en baisse** (l'argent part dans les lignes) |
| Bâtiments T3 achetés dans la 1ʳᵉ minute | quai n°3, GNL, IMO, rail (+9 s à +55 s) | quai n°3, GNL, IMO (+12 s à +36 s) | **trop bon marché à l'entrée du T3** |
| Plus long trou d'achat T1 / T2 / T3 | 1 min 29 / 30 s / 2 min 14 | 1 min 30 / 37 s / 2 min 08 | T3 trop long |
| Goulot dominant T2 / T3 | « manque de navires » 60 % / 53 % | 47 % / 51 % | le bot achète tout ; à revoir après la correction des licences |
| Capitainerie | niv. 96–102 en T3 | | niveaux en masse |

Début de partie (ANALYSE §11) : 127 / 1 K / 5,4 K $/min à 1 / 5 / 10 min, 10–12 achats dans les 5 premières minutes. **Ce rythme est bon,
ne le dégrade pas.**

**Cause connue de l'emballement** (`ANALYSE.md` §12, « Limites ») : les **licences de cargaison** valent `+25 %/niveau` et
`×2 tous les 10 niveaux jusqu'au niveau 150` (15 paliers, soit ×32 768) pour un coût `×1,2/niveau` (`config.json` → `licence_per_level`,
`licence_milestones` ; `cargo.json` → `licence_growth` ; `PortSim.licence_mult`). Une hausse de débit ×k devient environ ×k^2,2 de
revenu. Chez ISM, l'axe « valeur » plafonne à ×14 sur 200 niveaux, avec un coût de +2 %/niveau.

---

## 3. Écarts à traiter, par priorité

### É1 — Économie des licences : supprimer l'emballement du T2 (priorité 1, équilibrage)
Modèle ISM : axe « valeur » **bon marché, rentabilité plate, paliers finis et décroissants**, croissance portée par le contenu
(paliers T, bâtiments, nouvelles cargaisons, armateurs).
- Rends le multiplicateur de palier de licence **paramétrable par niveau** (liste `[[niveau, mult], …]` dans `config.json`, gérée par
  `Progression` sans casser `milestone_mult` des départements). Pistes à essayer : paliers ×1,25 / ×1,25 / ×1,5 / ×1,5 / ×2 / ×2 aux
  niveaux 25 / 50 / 75 / 100 / 150 / 200 ; effet linéaire +7 à +10 %/niveau ; croissance du coût 1,04 à 1,08 ; éventuellement un
  **niveau maximal de licence par palier** (ex. 50 / 120 / 200) pour que le palier suivant soit le vrai saut.
- Compense la perte de valeur par le contenu : `tiers.json` → `value_mult` (T2, T3), valeur des cargaisons frigo / IMO / hors-gabarit,
  et le prix des bâtiments.
- Ajoute à `tests/pacing_probe.gd` une mesure de **rentabilité du meilleur achat** (`PortSim.upgrade_gain` ÷ coût, au fil du temps) et le
  **ratio de croissance du revenu par minute**.
- **Cibles** (4 graines) : revenu T2 +3 / +6 / +10 min ≤ ×6 / ×25 / ×80 du revenu d'entrée (contre ×3–17 / ×56–150 / ×740–1 090) ; aucune
  minute à plus de ×1,6 ; rentabilité du meilleur achat entre 20 s et 5 min pendant toute la partie ; T1 12–15 min, T2 25–35 min,
  fin du MVP 1 h 15 – 1 h 30 ; début de partie inchangé (±15 %).
- Interface : la barre « Palier de licence » de `upgrades_sheet.gd` (vers les lignes 239–241) lit les nouveaux paliers ; la ligne
  « Licence niv. N » de `PortSim.breakdown("value")` reste juste.
- Sauvegarde : un joueur au-delà du nouveau maximum garde son niveau, plafonné à l'affichage, ou on lui rembourse l'excédent. Choisis,
  documente et teste.

### É2 — Entrée et rythme du T3 (priorité 1, équilibrage, à faire avec É1)
- Après É1, remesure : si le quai n°3, le GNL, l'IMO et le rail partent encore dans la 1ʳᵉ minute du T3, relève leurs prix ou étale-les
  (un achat marquant toutes les 2–4 min). Cible : premier bâtiment T3 ≥ +1 min, quatrième ≥ +6 min.
- Le revenu T3 doit croître doucement (+0 → +10 min : ×2 à ×5) et ne jamais baisser de plus de 30 % : vérifie le poids des lignes T3
  (`line_cost`, `line_cost_growth`) dans le budget du bot.
- Plus long trou d'achat T3 ≤ 90 s.

### É3 — Paliers nommés, visibles d'avance et dans le monde (priorité 2, sensation)
- Chaque département a un **nom d'étape par palier** (10, 25, 50, 75, 100, 150, 200, 300) et une phrase, dans `departments.json`
  (ex. Portiques : « grue rouillée » → « grue révisée » → « grutiers de jour et de nuit » → …). Idem pour chaque licence (`cargo.json`).
  La carte d'amélioration affiche l'étape actuelle et la suivante.
- Un bouton **« i »** sur chaque carte ouvre la **frise de tous les paliers** (niveau, multiplicateur, nom), le prochain mis en valeur,
  comme la popup de déblocage d'ISM.
- **Le monde change aux paliers** : pour chaque département, un élément visible de plus par palier franchi (dockers et lamaneurs sur le
  quai, vedette de pilotage supplémentaire, engin de parc, aubette et feu de gate, douanier). Pars de ce qui existe
  (`PortSim.agents()`, `TrafficView` ligne ~233 pour les engins du parc, responsables placés devant leur département) et réutilise les
  modèles existants ; pas de nouvel asset Blender sauf nécessité. Au franchissement : petit effet (poussière, son de palier existant)
  à l'endroit concerné.

### É4 — Achat en maintenant le bouton (priorité 2, confort)
Sur les boutons AMÉLIORER (départements et licences), un appui long répète l'achat au multiplicateur courant avec une accélération
(≈ 0,35 s → 0,05 s), s'arrête si l'argent manque ou au relâchement, et limite sons et effets (un son toutes les N répétitions, une gerbe
à la fin, la fanfare seulement sur un palier). Fonctionne à la souris et au toucher. Le mode ×1 / ×10 / ×100 / MAX reste.
Test `ui_smoke` : un appui maintenu achète plusieurs niveaux, puis s'arrête à court d'argent.

### É5 — Missions visibles en permanence (priorité 2, guidage)
- Un **bandeau compact** sous la barre de palier du HUD montre **les 2 missions en cours** avec leur barre de progression. Le toucher
  sur une mission terminée la réclame (avec effet) ; sinon il ouvre l'écran Missions.
- Une **barre de coffre** : toutes les N missions réclamées, un coffre (Ambre + X s de revenu). Paramètres dans `config.json`.
- Le HUD ne doit pas regrossir (l'ANALYSE §3 notait 20 % d'écran) : bandeau repliable, masqué tant que la fonction « missions » n'est pas
  révélée, mise en page portrait et paysage vérifiée par capture.
- Ajoute des missions courtes du T1 qui guident vers la boucle (allonger le quai, 1ʳᵉ campagne, bureau de douane), récompensées en
  argent (≈ 60–120 s de revenu) en plus de l'Ambre, pour qu'il y ait toujours un objectif à moins de 2 minutes.

### É6 — Retour immédiat sur le revenu après un achat (priorité 2, sensation)
Le HUD affiche le revenu **réel** (fenêtre glissante de 60 s, `income_per_min`) : **garde-le**, il est honnête (ISM affiche un potentiel
gonflé à ×3–5, on ne le copie pas). Mais après un achat le chiffre met jusqu'à une minute à bouger. Ajoute à côté du revenu une pastille
flottante « +X $/min » (le gain estimé de l'achat, déjà calculé par la rentabilité de `upgrades_sheet.gd`) qui s'efface en 3 s, et fais
monter le chiffre en douceur vers l'estimation (`income_rate_estimate`) pendant quelques secondes.

### É7 — Tutoriel : un narrateur et un goulot qu'on voit arriver (priorité 3)
- Un **personnage narrateur** (ex. la Capitaine Mathilde Roche, déjà responsable de la Capitainerie) avec un portrait et 3 ou 4 poses
  (accueil, réflexion, inquiétude, bravo) dans la carte du tutoriel (`scripts/ui/tutorial.gd`). Phrases courtes (une ou deux).
- Pendant les 3–4 premières étapes seulement, **assombris et bloque** le reste de l'interface (l'élément ciblé reste actif). « Passer le
  tutoriel » reste visible.
- L'étape « goulot » attend un **vrai goulot visible** (navire qui attend en rade avec sa bulle d'humeur, ou quai plein), cadre la caméra
  dessus, puis désigne l'action. Garde les conditions `when` / `done` en expressions dans `tutorial.json`.

### É8 — Statistiques à la manière d'ISM (priorité 3)
Dans Gestion → Statistiques : « Gain moyen par EVP » (le panier du port, par cargaison), et sur la liste des départements les étiquettes
**« Maillon le plus rentable »** (meilleure rentabilité d'achat) et **« Maillon le plus faible »** (goulot).

### Optionnel — Pli de la capitainerie (sans publicité)
Toutes les 4 à 6 min, une icône apparaît sur le côté (« Pli de la capitainerie ») : un toucher donne 60–90 s de revenu. Elle disparaît
au bout de 60 s si on l'ignore, sans pénalité, et est désactivée hors-ligne. À n'implémenter que si É1–É6 sont terminés et mesurés, et
seulement si elle ne crée pas d'obligation de rester devant l'écran.

### Ne pas copier
HUD au revenu potentiel, publicités, gemmes payantes, achats intégrés, verrouillage long du tutoriel, 3ᵉ axe « employés » par
département (nos bâtiments 2ᵉ grue / STS / voies de gate jouent déjà ce rôle de saut discret).

---

## 4. Ordre de travail

1. **Sauvegarde zip** du projet.
2. **Prototype É1 + É2** dans une copie : sonde enrichie, essais successifs (4 graines). Écris chaque essai dans `ANALYSE.md` §13 (tableau
   « essai / changement / résultat / leçon », comme au §12) et les réglages retenus.
3. **Report dans le vrai projet** : données, `Progression`, `PortSim`, migration de sauvegarde si besoin, bot, tests (`run_all` :
   nouveaux paliers de licence, plafond, migration) ; relance `pacing_probe`, `balance`, `prestige_curve`.
4. **É4, É6** (petits, indépendants), puis **É3**, puis **É5**, puis **É7**, puis **É8**. Après chacun : `run_all`, `ui_smoke`
   (+ contrôles ajoutés), captures portrait 540×960 et paysage 1280×720 (`--capture=… --delay=6`, une capture à la fois).
5. **Docs** : `DECISIONS.md` « Écarts ISM (date) » avec réglages, mesures finales (tableau avant / après / cible) et limites restantes.
6. **Compte rendu final** : ce qui a été fait, mesures avant/après, cibles non tenues et pourquoi, et ce qui reste.
