# Ordre de mission — lot G1 « La Crique, un vrai chapitre » (15/10/2026)

> Pour le sous-agent **développeur senior Godot**. Source : `docs/CADRAGE_DEBUT.md`, **à lire en entier** (surtout § 4 principe
> FAIRE → CONFIER → AGRANDIR, § 5 chapitre 1, § 11 et § 12 décisions). Tout ce document est validé par l'utilisateur.
> Les nouveaux modèles de l'expert Blender (`docs/ORDRE_BLENDER_G.md`) arrivent en parallèle dans `godot/assets/models/` ; un modèle
> absent → primitive Godot provisoire, signalée au rapport. Le lot G2 (terre-plein) suivra sur ta base : **ne touche pas** au début du
> T1 (séquence de chantiers du vieux quai), il reste tel quel pour que le jeu soit jouable de bout en bout après G1.

## Règles (impératives)
Celles de `docs/ORDRE_F1.md` (pas de commit, Start-Process + `WaitForExit(ms)` borné + `Kill()`, `--import` après un nouveau
`class_name`, captures `--fresh` regardées, journal + DECISIONS + PLAN_COTE) et les acquis de F1/F2/F3 rappelés dans
`docs/ORDRE_F2_F3.md`. En plus :
- **Paliers de livraison** : étape 0 (note de faisabilité au journal, 1 page), puis G1-a (simulation + sauvegarde + sonde), G1-b
  (monde + interface + nuages), G1-c (calage, captures, APK). Tests verts à chaque palier.
- Tests : `run_all` (233) et `ui_smoke` (171) verts ; **aucun contrôle retiré** sauf ceux de l'acte 0 actuel qui deviennent faux
  (listés au journal avec leur remplaçant).
- **Économie** : la progression mesurée **depuis la Concession** reste dans ±5 % en moyenne et ±15 % par graine par rapport à la sonde
  actuelle mesurée depuis l'entrée au T1 (même événement). La sonde apprend à mesurer depuis la Concession.
- Sauvegarde **v7** avec migration : une partie v6 en cours d'acte 0 **recommence** la Crique (c'est un test) ; une partie au T1 ou
  au-delà se charge avec la Crique considérée finie, pêche au plafond R₀, Concession faite, aucun chantier rejoué.

## 1. La simulation de la pêche (`sim/fishing.gd`, `config.json › fishing`)
Remplace les 5 achats par le modèle du cadrage § 5.2 :
- **Deux cartes à niveaux** (mêmes cartes AMÉLIORER que les services du port, `×1 / ×10 / max`, maintien) :
  - **Places au ponton** : niv. 1 à 8, chaque niveau = une place = une barque de plus (chantier 3 s : le ponton s'allonge d'un module
    `pontoon`). Coût ≈ 15 $ × 1,3^niv.
  - **Services à quai** : niv. 1 à 10, chaque niveau augmente le ticket par escale (+15 %) ; paliers nommés avec chantier : niv. 1 la
    criée (`fish_hall`, la camionnette `fish_van` part vers la forêt), niv. 3 carburant (`fuel_pump`), niv. 6 lavage (`wash_bay`),
    niv. 9 glace (`ice_plant`). Un palier nommé coûte un saut de prix (×3) et montre son bâtiment.
- **Bâtiments** (achats uniques, chantier 4 à 6 s, dans la même liste AMÉLIORER, le prochain en tête) : quai des chalutiers ≈ 80 $
  (2 `boat_trawler`, paient ×3), grande jetée ≈ 150 $ (`pier_long`, 1 `boat_tuna`, paie ×10), marina ≈ 250 $ (`marina_pontoon`,
  6 voiliers, revenu passif), extension 1 ≈ 300 $ (12 voiliers), extension 2 ≈ 400 $ (20 voiliers), **Concession du terre-plein**
  ≈ 1 000 $ (disponible dès la marina, voir § 4).
- **Argent = loyer par escale** (§ 2 décision 3) : un bateau qui rentre paie `valeur(classe) × ticket(services)`. La marina paie un
  loyer continu par voilier (passif).
- **Plafond R₀** : tout au maximum → 4 à 6 $/s, à caler (§ 5.4). Au-delà, plus aucune carte de pêche ; le revenu reste pour toujours.
- Les durées de sortie en mer restent fixes (croisière lente, pas de sprint).

## 2. FAIRE puis CONFIER : encaisser à la main, puis Marcel
- **Encaisser** : un bateau rentré montre une bulle « loyer » (pièce) ; **toucher** = encaisser (pièce qui saute vers le compteur, son).
  S'il n'est pas touché, le bateau attend ≈ 20 s puis **repart sans payer** (bulle qui passe au rouge avant). Avant le premier
  responsable, **le monde se fige quand on quitte** (pas de hors-ligne, rien perdu : § 12 Q2) ; la sonde et le bot encaissent.
- **Marcel** (`marcel`, « patron pêcheur ») se présente après **5 loyers encaissés à la main** (bulle sur le ponton + narratrice :
  « embauche Marcel avant de partir, il travaillera pour toi »). Prix ≈ 40 $. Il apparaît dans la feuille RESPONSABLES (Gestion →
  Responsables, seul onglet accessible pendant la Crique). Une fois embauché : **plus aucune bulle, plus aucun geste** (le toucher d'un
  bateau ne fait plus rien, le coup de main ×1,2 actuel disparaît : § 12 Q1) ; il encaisse tout, il attend sur le ponton ; hors-ligne
  = revenu de la pêche à son rythme (durée max actuelle). Le bouton **Heures sup ×2** se révèle à son embauche (§ 8.1).
- Marcel est un responsable comme les autres pour la sauvegarde, les Stats et l'écran RESPONSABLES ; pas d'Ambre demandé.

## 3. Les nuages et la caméra (§ 5.1, § 12 Q5)
- Pendant la Crique, **tout ce qui n'est pas l'anse est sous des bancs de nuages** (`cloud_bank`, `cloud_puff`) : la friche à l'est du
  cap, le bassin, la terre au sud. Dérive lente. La **caméra est bornée à l'anse** (bornes dans `PLAN_COTE.md`). Au zoom le plus large
  on voit les nuages aux bords, jamais le bord du monde.
- **8ᵉ minute** (ou dès la criée si plus tôt) : `ship_passing` traverse au large, Mathilde le commente (une carte), la mission
  « Signer la concession » apparaît (première mission du jeu, bouton MISSIONS révélé, Ambre expliqué par sa récompense).
- **Concession** : cérémonie « Palier 1 — Le Vieux Quai » existante, mais **d'abord** les nuages se dissolvent (fondu + montée,
  3 à 4 s, shader sur la couleur de sommet), **puis** la caméra passe le cap et les bornes s'élargissent. Les nuages ne reviennent
  jamais ; une partie chargée après la Concession n'en a pas.

## 4. La Concession et le plafond
- Carte « Concession du terre-plein » ≈ 1 000 $ dans AMÉLIORER dès la marina (pas besoin du plafond : un joueur pressé finit en
  12 min, un joueur tranquille en 15 à 20). La mission la désigne. Son achat = fin de la Crique = ce que fait aujourd'hui la bascule
  (`open_port()`, `start_t1_works()`), **sans** autre condition (`switch_money` disparaît).
- Après la Concession, les cartes de pêche restantes **restent achetables jusqu'à leur maximum** (c'est le « on peut revenir la
  voir »), en bas de la liste AMÉLIORER, sous un titre « La Crique ». Le plafond R₀ borne tout.

## 5. Tutoriel et narration (`data/tutorial.json`, `tiers.json`, `scripts/ui/narrator.gd`)
Étapes de la Crique, dans l'ordre, une nouveauté à la fois, jamais deux à moins de 45 s : réparer le ponton (gratuit) → toucher la
barque pour encaisser → acheter Places niv. 2 → la criée → Marcel (objectif de la première session) → annonce du port (8ᵉ min) →
marina → Concession. Les textes de l'intro (3 cartes) restent ; ceux de la bascule sont à réécrire (Odette, la friche, « signe la
concession »). Mettre à jour `UNIVERS.md` (Marcel, la marina, la Concession) et `tiers.json`.

## 6. Sonde et bot (`tests/pacing_probe.gd`, `tests/bot.gd`)
- Le bot joue la Crique : encaisse, achète dans l'ordre de la liste, embauche Marcel, achète la Concession dès qu'il le peut en mode
  « pressé » ou après le plafond en mode « tranquille ». Deux mesures : **pressé ≤ 12 min**, **tranquille 15 à 20 min** (4 graines).
- Jalons depuis la Concession : T2, T3, fin, premiers achats. Tableau avant/après au journal.

## Fin de lot
Tests verts (nombre avant/après, contrôles ajoutés : loyer manuel, bateau qui repart sans payer, Marcel, nuages absents après
Concession, bornes caméra, sauvegarde v7), sonde dans les tolérances, captures `docs/captures/g1_*` regardées (départ sous les
nuages, bulle de loyer, chaque palier nommé, Marcel, passage du caboteur, marina, dissipation, zoom large), `PLAN_COTE.md`
(marina, jetée, bornes), journal § « Lot G1 », DECISIONS, **APK réexporté**. Rapport : fait / non fait (raison), chiffres, captures.
