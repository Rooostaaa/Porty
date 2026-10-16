# Décisions et état du projet

## Lancer / vérifier
Double-clic sur `C:\Nadir\tycoon\jouer.bat` pour jouer. Dans PowerShell, un chemin entre guillemets doit être précédé de `&` : `& "C:\Nadir\Godot\Godot.exe" --path "C:\Nadir\tycoon\godot"`.
```
$g = 'C:\Nadir\Godot\Godot.exe'          # l'exe « console » fourni ne marche pas seul (il cherche Godot_v4.7.1-stable_win64.exe)
$b = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
& $g --path C:\Nadir\tycoon\godot                                              # jouer
& $g --headless --path C:\Nadir\tycoon\godot --script res://tests/run_all.gd   # 124 contrôles
& $g --headless --path C:\Nadir\tycoon\godot res://tests/ui_smoke.tscn         # interface (scène, 60 contrôles)
& $g --headless --path C:\Nadir\tycoon\godot --script res://tests/pacing_probe.gd -- --seeds=1,2,3,4 [--brief] [--set=config.licence_max=[25,60,100]]
& $g --headless --path C:\Nadir\tycoon\godot --script res://tests/balance.gd   # chronologie d'équilibrage
& $g --path C:\Nadir\tycoon\godot res://scenes/gallery.tscn                    # galerie d'assets
& $g --path C:\Nadir\tycoon\godot res://tests/swatch_test.tscn                 # test sRGB/linéaire
& $b -b -P C:\Nadir\tycoon\blender\build_assets.py [-- --only nom1,nom2]
& $b -b -P C:\Nadir\tycoon\blender\preview.py -- equipment C:\Nadir\tycoon\docs\previews\equipment.png
```
Arguments de jeu (après `--`) : `--fresh` (partie neuve, pas de sauvegarde), `--speed=10`, `--tier=3`, `--build-all`, `--hire-all`,
`--debug-money=1e6`, `--look=x,z`, `--zoom=80`, `--build=quay_ext,gravel2`, `--unlock-all`, `--levels=60`, `--tuto --tuto-step=N`, `--open=upgrades|manage|missions|contracts|debug`, `--tab=0..3`, `--capture=img.png --delay=6`.
F1 en jeu : outils de debug.

## Couleurs
- Blender écrit les couleurs de sommet en **linéaire** (attribut FLOAT_COLOR « Color », palette sRGB convertie).
- Test du nuancier (`tests/swatch_test.tscn`) : rendu non éclairé = palette à ±1/255 avec `vertex_is_srgb = 0`
  (erreur totale 0,067 contre 5,78 en mode sRGB). Matériau partagé : `assets/vcol.gdshader` ; MultiMesh : `vcol_tint.gdshader` (teinte par instance via INSTANCE_CUSTOM).

## Économie (écarts assumés par rapport au prompt)
- **Débit physique lisible, valeur exponentielle** (comme les produits de la référence) :
  un niveau de département = +15 % de débit, paliers ×2 aux niveaux 10, 25, 50, 75, 100… ; coût `base × 1,15^niveau`.
  Le moteur exponentiel est la **licence de cargaison** : +25 %/niveau, ×2 tous les 10 niveaux, coût ×1,2/niveau.
  *(Remplacé le 13/10, voir « Écarts ISM » : paliers finis, ×81 au total, et niveau maximal par palier.)*
  Raison : avec ×niveau sur le débit, les navires défilaient plusieurs fois par seconde et la courbe faisait « explosion puis plateau ».
- Durées minimales d'escale (pilotage 2,5 s, amarrage 1,5 s, formalités 1,5 s) : à haut niveau, le goulot devient le **nombre de postes à quai** → construire un quai ou changer de palier.
- Empilage du parc proportionnel au niveau de Parc et manutention (capacité = surface × empilage).
- La gate est un flux continu (1 camion affiché ≈ 1 s de débit de gate).
- Navires déroutés quand la rade est pleine : manque à gagner, pas de pénalité de réputation (seuls les navires qui attendent puis repartent furieux en coûtent).

## Équilibrage mesuré (bot « actif raisonnable », 3 graines)
| Mesure | Cible | Mesuré |
|---|---|---|
| Premier achat | < 20 s | 1 s (argent de départ) |
| Achat abordable (5 premières minutes) | 15–40 s | 14–18 s (limite basse) |
| Premier responsable | 3–4 min | 2 min 18 – 4 min 59 |
| T1 → T2 | 8–12 min | 9 min 51 – 10 min 38 |
| T2 → T3 | 35–50 min | 37–38 min |
| Fin du MVP | 1 h – 1 h 30 | 1 h 19 – 1 h 26 |
| Impasse | aucune | plus long intervalle sans achat : 1 min 01 |
| Hors-ligne | 50 % → 100 % | 50 % + 50 % × responsables/6, plafond 8 h |

## Non fait / limites connues
- Pas de police Fredoka sur la machine : repli sur Segoe UI (SystemFont). Déposer `Fredoka-Bold.ttf` dans `godot/assets/fonts/` suffit.
- T4/T5, prestige, jour/nuit : hors MVP. Responsables T3 (Dr Lambert, Ing. Mori) non utilisés.
- Personnages : silhouettes statiques (pas de marche), quelques dockers, douanier, responsables embauchés devant leur département.
- Le clic/tap n'a été testé que par le code (pas de session de jeu humaine) ; captures automatiques uniquement.

## Réglages du 12/10
- T1 trop long (11 min 30 – 15 min) : la cause était le plateau de revenu entre 5 et 11 min (tous les maillons à 6–9 EVP/s).
  Correctifs : T1 `value_mult`/`dues_mult` 1,0 → 1,3 ; coût du palier T2 6 000 → 4 000 $ ; Extension gravier 6 000 → 4 000 $ ;
  Dragage 3 000 → 2 000 $ ; Deuxième grue 1 500 → 1 200 $. Baisser les EVP ou les étoiles requis n'avait aucun effet.
- Diorama : une chaussée (route sur digue, `Layout.CAUSEWAY_Z1`) relie la gate au continent ; avant, la file et les camions sortants
  roulaient sur l'eau. Camions sortants affichés : un toutes les 0,7 s au plus, 16 maximum (en ×10 ils formaient un mur).
- Caméra : le recul dépend du zoom (`CameraRig.dist()`), sinon le bas de l'écran partait sous l'eau en dézoom et montrait le fond.
- Surcouche : en fort dézoom, la jauge du parc et la pastille de la gate ne s'affichent que si elles signalent un problème.
- Pas de git pour ce projet (choix de l'utilisateur).
- Contrats : les offres en attente sont revalorisées chaque jour portuaire et à chaque palier (`Objectives.rescale_offers`, jamais à la baisse) ;
  avant, une offre affichée 4 min 30 en T2 pouvait valoir 100× moins que le revenu courant. Test ajouté (26 tests).
- Surcouche : l'alerte « Tablier plein » est dessinée après la jauge du parc (elle était masquée en dézoom).
- `Capture` affiche aussi la position de la caméra (`CAMERA target=…`). Ne pas lancer plusieurs captures en parallèle :
  les fenêtres se gênent (clics parasites, caméra déplacée).

## Tranche 2 (12/10) — boucle idle complète : prestige, objectifs, retours visuels
Copie de sécurité avant la tranche : `C:\Nadir\tycoon_backups\port_horizon_avant_tranche2_*.zip` (pas de git).
- **Prestige « Nouvelle concession »** (Gestion → Port) : disponible après la Concession nationale, gain `floor(√(EVP de la concession / 100 000))` points de **Renom ✦**
  (≈ 5 à la fin d'une 1ʳᵉ partie). Chaque point : revenus +10 %, débit +8 % (demande, grues, engins, inspection, gate) **et** temps minimaux
  de pilotage/amarrage/formalités ÷ (1 + 0,08 × Renom). Conservés : Renom, Ambre (+10), missions réclamées, compteurs cumulés. Tout le reste repart de zéro.
  Réglages dans `config.json` → `renown`. Code : `PortSim.carry_over`, `GameState.prestige`.
- **Pourquoi le Renom touche aussi le débit et les temps minimaux** (mesuré avec `tests/prestige_curve.gd`) : un simple bonus de revenus ne change presque rien
  (20 points de Renom → seulement −10 min), parce que le coût est exponentiel et l'effet linéaire, et que la fin de partie est limitée par les EVP à traiter.
  Courbe actuelle (bot) : 1 h 23 → 1 h 07 → 1 h 02 → 55 min → 51 min.
- **Constat d'équilibrage (non corrigé)** : en T2 le débit plafonne à ~13,4 K EVP/min de 23 à 47 min (« goulot = palier ») car les temps minimaux d'escale fixent
  un plafond que seul le palier suivant relève, et le palier T3 exige 500 K EVP. Il n'y a rien à acheter pendant ~25 min. Pistes : bâtiments qui abaissent ces
  temps minimaux (remorqueur, amarrage rapide, guichet numérique), parking/aire d'attente, 3ᵉ quai en T2.
- **Objectifs de carrière** : une fois les 17 missions écrites épuisées, `Objectives.generated_mission(i)` fournit une suite sans fin (EVP, escales, camions, contrats),
  comptée sur toutes les concessions (`PortSim.counter_total`).
- **Rentabilité** : chaque carte affiche « +X $/min · rentabilisé en … » (`PortSim.upgrade_gain`, sans modifier l'état) et la carte la plus rentable porte « ★ MEILLEUR ACHAT ».
- **Interface** : revenu net par seconde (masqué tant que rien n'est déchargé) · barre de progression du palier sous l'argent (touche : onglet Port) ·
  pastille du nombre d'améliorations abordables · légendes sous les icônes · compteur d'argent animé · gerbes de particules, « pop » de carte et texte flottant
  à l'achat (`scripts/ui/fx.gd`), fanfare + secousse aux paliers ×2.
- **Premier contact** : message de bienvenue unique (drapeau `intro_seen` dans `settings.cfg`, forçable par `--intro`) ; « Bon retour » en fenêtre seulement
  au-delà de 5 min d'absence (sinon un toast) ; cadrage de départ décalé vers la rade (`CameraRig.START`).
- **Tests** : `run_all.gd` (43 contrôles, dont prestige, rentabilité, objectifs) · `ui_smoke.tscn` (scène, 17 contrôles : achats, bâtiments, responsables, missions,
  prestige complet) · `prestige_curve.gd` · `tier_debug.gd`. Le test d'interface se lance comme une scène :
  `& $g --headless --path C:\Nadir\tycoon\godot res://tests/ui_smoke.tscn` (en `--script`, les autoloads n'existent pas à la compilation).
- Après l'ajout d'une classe (`class_name`), lancer `--headless --import` pour mettre à jour le cache des classes.
- **Reste à faire** (voir `ANALYSE.md`) : terre ferme + aire d'attente poids lourds, tutoriel guidé, corvées manuelles du début, mise en page paysage, ambiances sonores.

## Tranche 3 (12/10) — le monde, les gestes manuels, le tutoriel, le paysage, l'ambiance
- **Terre ferme** : un continent au sud du port (`Layout.GROUNDS`/`PROPS`/`scatter`) — plages, autoroute (`HIGHWAY_*`), village de pêcheurs, zone logistique,
  collines et ~150 arbres/rochers en MultiMesh. Le modèle `road` est orienté selon X ; `road_z` est le même tourné de 90° (types de sol `road_x` / `road_z`).
  Nouveaux modèles Blender dans `blender/parts/world.py` : `ground_parking`, `house_a/b`, `shop`, `silo`, `hill`, `car_a/b`, `stack`
  (planche : `docs/previews/world.png`, commande `preview.py -- world …`).
- **Aire d'attente poids lourds** (bâtiments `parking1` 5 M$, `parking2` 40 M$) : 8 places chacune, gate ×1,4 puis ×1,3. Les camions arrivent par l'autoroute,
  attendent sur la route (5 places) puis dans l'aire, la gate les appelle, ils repartent chargés vers l'autoroute (`TrafficView`, itinéraires par la route d'accès).
  Pastille « Aire d'attente n/N ». Des voitures civiles circulent sur l'autoroute.
- **Leviers sur le plafond d'escale** (le plateau T2 de la tranche 2) : `tug2` (pilotage min ×0,7), `quickmoor` (amarrage ×0,7), `ewindow` (formalités ×0,7),
  effet `time_min` ; `PortSim.min_time(kind)`. Nouvelle clé de goulot `min_time` (« Les escales sont au plancher… », bouton CONSTRUIRE).
  Résultat mesuré : T2→T3 ≈ 31–33 min (cible 35–50, légèrement en dessous), fin du MVP 1 h 11 – 1 h 16, 1ʳᵉ→5ᵉ concession 1 h 12 → 47 min.
- **Gestes manuels du début** (`config.json` → `manual`, `auto_berth_delay` 4 → 12 s) :
  1. toucher un navire en rade l'accoste en priorité (pilotage ×0,6) ; sans geste il attend 12 s ;
  2. toucher la grue qui décharge = « coup de main » (2 s de déchargement, recharge 2 s) tant que la cheffe des grutiers n'est pas embauchée.
  Les responsables remplacent ces gestes (Capitainerie : accostage automatique ; Portiques : coup de main automatique en plus du ×2).
  Le joueur automatique les exécute (`Bot.use_manual`) : l'équilibrage reste mesuré sur un joueur actif.
- **Tutoriel guidé** (`data/tutorial.json`, `scripts/ui/tutorial.gd`) : 9 étapes, conditions `when`/`done` en expressions sur `sim`, flèche + anneau sur la cible,
  caméra recentrée sur le navire/la grue, bouton « Passer le tutoriel », progression dans `settings.cfg` (`tuto/step`). Une partie déjà avancée (> 5 min) ne le voit pas.
  Arguments de test : `--tuto` (actif même en capture), `--tuto-step=N`. Les parties `--fresh` ne l'enregistrent pas.
- **Paysage / PC** : l'interface est une colonne centrée de 1080 px (`Hud._apply_column`), le monde reste visible de chaque côté ; la caméra garde la hauteur
  visible (`KEEP_HEIGHT`) sur les fenêtres plus larges que le portrait. La surcouche monde et le tutoriel sont `top_level` (coordonnées écran) ;
  la surcouche est masquée quand un écran est ouvert.
- **Ambiance sonore** (toujours synthétisée, aucun fichier) : mer en boucle, mouettes, corne de navire à chaque arrivée, claquement de grue, klaxon de camion.
- **Tests** : `run_all.gd` 59 contrôles (gestes manuels, leviers, tutoriel) · `ui_smoke.tscn` 21 contrôles (tutoriel, toucher un navire, achats, prestige).
- **Reste à faire** : jour/nuit, personnages qui marchent, météo visible (pluie), import/export (chargement des navires), maintenance/énergie (T3), nouveau port à
  chaque concession, mise en page tactile réelle (non testée sur appareil), musique.

## Revue de code (12/10) — correctifs
Relecture complète (simulation, autoloads, interface, vue 3D) + fuzzer d'invariants (5 parties de 40–90 min : achats aléatoires, aléas forcés, sauvegarde/rechargement
en cours de route, hors-ligne, prestige) : **aucune violation** (conservation des EVP, quais ↔ navires, stocks, NaN). Les défauts trouvés étaient dans la périphérie :
- **Sauvegarde** : les tests `--headless` chargeaient la vraie sauvegarde par l'autoload `Save` puis la réécrivaient à la sortie (hors-ligne crédité au passage).
  `Save` ne lit ni n'écrit plus rien en headless. `load_game` vérifie que `sim` est un dictionnaire (sinon copie de secours).
- **Hors-ligne à la reprise** : une application suspendue (veille, arrière-plan mobile) ne rattrapait pas le temps — le pas de simulation est plafonné à 0,25 s.
  `Save._process` détecte un trou d'horloge > 60 s entre deux images et appelle `GameState.credit_offline` (signal `offline_applied`, l'interface montre « Bon retour »).
- **Heures sup** : un toucher en recharge dépensait de l'Ambre sans demander ; il ouvre maintenant une confirmation (`show_popup(..., ok_text)`).
- **Contrats** : un contrat refusé pouvait être reproposé aussitôt (`refresh_offers(sim, skip)`) ; la fiche d'une offre revalorisée en place n'était pas rafraîchie.
- **Tutoriel** : `done` est évalué avant `when` (un geste déjà fait fait passer l'étape) ; l'étape « coup de main » se termine aussi si la cheffe des grutiers est
  embauchée (sinon impossible à franchir) ; « Nouvelle partie » relance le tutoriel.
- **Écran Port** : la liste des conditions du palier suivant ne bougeait plus après l'ouverture (bouton actif, liste « en attente ») : mise à jour en direct.
- **Licences** : la barre de palier supposait « tous les 10 niveaux » (faux après le dernier palier) : lue dans `licence_milestones`. `buy_licence` vide le cache.
- **Formatage** : `999,7` → « 1K » (et non « 1000 »), `999 700` → « 1M » (et non « 1000K »), `119,7 s` → « 2 min 00 s » (et non « 1 min 00 s »).
- **Performance** : l'écran Améliorations rejouait 22 analyses de goulot 5 fois par seconde (≈ 4,7 ms par rafraîchissement sur PC) : une estimation de référence
  partagée, recalculée une fois par seconde et après un achat (`PortSim.upgrade_gain(..., base)`). Le HUD ne recrée plus les styles de boutons à chaque rafraîchissement.
- **Vue** : le train restait figé sur la voie après une nouvelle concession ; la caméra restait « accrochée » si un écran s'ouvrait pendant un glissement ;
  `PortSim.reset()` oubliait Renom / compteurs temporaires ; table anti-doublon des notifications sans purge ; tween de notification lié à la notification.
- **Tests** : `run_all.gd` 72 contrôles (+13) · `ui_smoke.tscn` 27 contrôles (+6).
- **À savoir, non modifié** : F1 (outils de débogage) et les arguments `--debug-money`, `--tier`… restent actifs en version exportée — à couper (`OS.is_debug_build()`)
  avant toute publication ; la ligne « F1 : outils de débogage » de l'écran Réglages est affichée aux joueurs.

## Début de partie doux (12/10) — petits navires, gabarits de quai, révélation progressive
Copie de sécurité : `C:\Nadir\tycoon_backups\port_horizon_avant_debut_doux_20261012_1703.zip`. Analyse et mesures du prototype : `ANALYSE.md` §10–11.
- **Échelle des navires** (`ships.json`) : petit porte-conteneurs 16–30 EVP (gabarit 1, nouveau modèle `ship_mini`) → caboteur 60–150 (gabarit 2,
  **Allongement du quai** 250 $) → feeder (gabarit 3, dragage) → Panamax (gabarit 4, quais profonds). Escales plus courtes pour les petits
  navires (`time_scale` ×0,4 / ×0,7). Au départ, le quai n°1 est plus court d'un segment, que l'allongement ajoute (`Diorama.rebuild`).
- **Demande** = trafic des classes que les quais peuvent recevoir (`traffic` par palier, EVP/s) × armateurs présents (somme des poids)
  × Capitainerie (+15 %/niveau) × réputation × tarifs. Agrandir le quai ou ouvrir la douane **fait venir du monde** (×4, puis ×1,8) :
  c'est ce qui crée l'alternance « manque de navires → manque de capacité ». Le détail « Pourquoi ? » du trafic le montre ligne par ligne.
- **Bureau de douane** (800 $, effet `customs_open`) : avant lui, ni inspection, ni amende, ni contrôle surprise (`require_building`) ;
  il fait venir Grand Large Cargo (`owners.json` → `require`), ses contrats et la politique de contrôle.
- **Rade** : 2 places au départ. **Valeur T1** ×1,8 (au lieu de ×1,3) pour garder le rythme d'achat avec de petits volumes.
- **Conseil « pas assez de navires »** (clé `attract`) : quand un équipement peut attirer du trafic (quai, douane, chenal, quai profond),
  le conseil le nomme (champ `hint` du bâtiment) et son bouton CONSTRUIRE ouvre les Bâtiments. Sans cela, le joueur (et le bot) dépensait
  tout en petits niveaux et n'allongeait le quai qu'à 12 min.
- **Révélation progressive** (`data/unlocks.json`, `PortSim.feature/check_unlocks`) : 14 fonctions apparaissent une à une (Gestion après
  2 escales, Missions, Parc et Gate, réputation, licences, barre de palier, stats, responsables après 9 escales, Heures sup après 12,
  Douane et Contrats avec le bureau de douane, aléas après 16 escales, Ambre). La simulation les respecte aussi (achats, aléas, contrats,
  missions) : le bot vit la même partie que le joueur. Chaque révélation : rebond du bouton + bandeau « Nouveau : … » non bloquant
  (file d'attente, toucher pour fermer). Cartes encore verrouillées visibles, grisées, avec leur condition (« après 9 escales (4/9) »).
  Carte de prestige seulement à partir de T3. Une nouvelle concession garde ce qui a été révélé.
- **Moments marquants** : premier navire d'une nouvelle classe (`ship_class_first`) → corne, caméra sur la rade, bandeau (`arrival` du navire).
- **Sauvegardes** : version 2. Une partie d'avant (sans `features`) reçoit tout ce qui a été révélé + l'allongement du quai et le bureau de douane
  (`PortSim._upgrade_legacy_save`) ; vérifié sur une copie de la partie réelle du joueur (19 min, T1) : ses caboteurs accostent normalement.
- **Tutoriel** : nouvelle étape « Allongement du quai » (après le goulot), étapes responsable / mission / contrats calées sur les révélations.
- **Bot** : respecte les révélations et économise pour l'équipement que le conseil désigne.
- **Mesures (bot, 3 graines)** : quai allongé 2 min 46 – 3 min 08 · 1ᵉʳ responsable 5 min 41 – 6 min 29 · douane 7 min 14 – 8 min 07 ·
  T2 12 min 40 – 13 min 42 · T3 47–49 min · fin 1 h 21 – 1 h 24 · 9–12 achats dans les 5 premières minutes.
- **Tests** : `run_all.gd` 90 contrôles (+18 : début doux, gabarits, douane, révélations, ancienne sauvegarde) · `ui_smoke.tscn` 35 contrôles.
- **Reste (chantier C, `ANALYSE.md` §11)** : demande en excès en T2/T3 (Capitainerie qui multiplie sans limite), explosion de revenus au début
  de T2, plateau de 25 min en T2, bâtiments T3 trop bon marché ; démarchage, lignes régulières, services aux navires.

## Chantier C (12/10) — faire venir les navires : commerce, plancher assoupli, milieu de partie
Copie de sécurité : `C:\Nadir\tycoon_backups\port_horizon_avant_chantier_c_20261012_2044.zip`. Analyse, essais et mesures : `ANALYSE.md` §12.
- **La Capitainerie ne fait plus venir de navires** : elle pilote (vitesse du pilote, pilotes, places en rade, plancher de pilotage).
  Responsable : accostage automatique + pilotage ×2. Carte Améliorations : « Pilotage X s », détail « plancher ».
- **Demande** (`PortSim.breakdown("demand")`) = navires accueillis × **statut du port** (`tiers.json` → `traffic_mult` : 1 / 3 / 35)
  × **armateurs** (`owner_factor` : poids × (1 + 1,5 × lignes), ×2 pendant un contrat) × **services** (bâtiments `stat_mult demand`)
  × réputation × tarifs × **campagnes** (modificateurs `camp_*`) × Renom.
- **Commerce** (`sim/commerce.gd`, écran `CommerceSheet`, bouton COMMERCE à la place de CONTRATS, révélé après 10 escales) :
  - *Trafic* : demande et capacité de service (`PortSim.service_capacity`), « Pourquoi ? », campagnes (`config.json` → `campaigns` :
    Affiches ×1,5 / 2 min 30 / recharge 5 min ; Annonce au journal ×2 / 4 min / recharge 10 min, après le bureau de douane ; prix en secondes
    de revenu), équipements qui attirent ;
  - *Armateurs* : Nordhaven 60 K$, Sakura 400 K$, Chimex 500 M$ à démarcher (`owners.json` → `recruit`) ; **lignes régulières** à partir du
    T2 (`lines_per_owner` 0/3/4, `line_cost` 200 K$ / 500 M$, ×2 par ligne, −50 % après un contrat réussi : `line_offers`) ; relation ;
  - *Contrats* : l'objectif vaut 50 % de ce que l'armateur apportera pendant le contrat (`Objectives.owner_rate`) au lieu de « n s du débit de
    tout le port » (seul Corsaire y arrivait) ; le champ `evp_seconds` des modèles a disparu. Nouveau contrat Chimex sans cargaison imposée.
- **Services aux navires** (bâtiments) : Ponton d'avitaillement T1 1 000 $ (trafic +20 %, patience +30 %, effet `patience`) ; Atelier de
  réparation T2 400 K$ (trafic +20 %, +50 % de droits par escale, effet `ship_fee`) ; Station GNL T3 400 M$ (+25 %, +50 %).
- **Plancher assoupli** : `PortSim.min_time` ÷ (1 + `floor_per_level` 0,02 × (niveau − 1)) du service concerné (`FLOOR_DEPT` : Capitainerie,
  Quais, Douane). Le goulot « attendre le palier » (`tier`) n'est plus produit par l'analyse.
- **T3** : Pilotage à distance, Amarrage automatique, Douane dématérialisée (temps minimal ×0,6) ; prix T3 de 200 M$ à 8 Md$ ;
  Concession nationale 8 Md$.
- **Conseil** : « Pas assez de navires » ouvre le Commerce (`HINT_DEPT` → "" pour `harbor`/`attract`) ; « attirer » désigne aussi les services.
- **Sauvegarde version 3** : une partie sans `owners_on` garde ses armateurs (marqués démarchés), reçoit le Commerce et un message unique
  (`legacy_notice` → `Hud._commerce_notice`). Sur la partie réelle (T1, 21 min) : trafic 1 305 → 246 EVP/min (12 niveaux de Capitainerie
  qui ne comptent plus), avec 87 K$ en caisse pour l'avitaillement, le dragage et les campagnes.
- **Incident pendant le chantier** : une capture lancée avant la réimportation de la nouvelle classe a fait échouer `main.gd`. Or c'est lui qui
  désactivait la sauvegarde pour `--fresh` : la vraie partie a été chargée, a tourné environ 2 minutes et a été réenregistrée (déjà migrée en
  version 3, donc sans le message). Correctif : `Save._ready` lit lui-même `--fresh`.
- **3D** : vedette d'avitaillement près du quai (`supply`), deux cuves GNL près du terminal rail (`lng`). Les autres nouveaux bâtiments
  n'ont pas d'objet, comme le remorqueur ou les bollards.
- **Bot** : campagnes quand les navires manquent, démarchage, lignes ; il économise aussi pour les lignes et les armateurs.
  **Sonde** `tests/pacing_probe.gd` : demande/capacité, goulots, achats, conditions de palier, revenu après chaque palier.
- **Mesures (bot, 4 graines, vrai projet)** : T2 11 min 17 – 13 min 02 · T3 36 min 21 – 39 min 47 · fin **1 h 12 – 1 h 30** · demande
  > 1,5 × capacité 8–17 % du temps en T2 (100 % avant) · « attendre le palier » 0 % (T2 26–34 %, T3 84–88 % avant) · bâtiments T3 étalés
  sur 20–30 min · contrats réussis ≈ 70 %. Prestige : 1 h 25 → 1 h 00 → 51 min → 51 min → 43 min.
- **Tests** : `run_all.gd` 108 contrôles (+18 : commerce, plancher, contrat atteignable, migration) · `ui_smoke.tscn` 45 contrôles
  (+7 : écran Commerce, campagne, démarchage, ligne, message d'ancienne partie). Correctif au passage : la confirmation de « Nouvelle
  concession » pouvait s'effacer si une fonction se révélait entre les deux appuis.
- **Limites connues** (`ANALYSE.md` §12) : l'emballement des revenus au début du T2 est atténué, pas supprimé (licences) ; avec le bot, la
  demande est le goulot la moitié du temps en T2/T3 ; les relations plafonnent vite à 100 ; Chimex échoue souvent ses contrats IMO.

## Écarts ISM (13/10) — licences, entrée du T3, paliers nommés, achat maintenu, missions sur le HUD, tutoriel, statistiques
Copie de sécurité : `C:\Nadir\tycoon_backups\port_horizon_avant_ecarts_ism_20261012_2211.zip`. Cahier des charges :
`docs/PROMPT_ECARTS_ISM.md`. Essais, leçons et réglages : `ANALYSE.md` §13.
- **É1 Licences** : paliers lus dans `config.json` → `licence_milestones` (`[[niveau, mult], …]`, `Progression.step_mult/next_step` ;
  `milestone_mult` reste celui des départements) : ×2 aux niveaux 10 et 20, ×1,5 à 30, 50, 75, 100, ×2 à 150 et 200, soit ×81 puis
  plus rien. **Niveau maximal par palier** `licence_max` 25 / 60 / 100 (`PortSim.licence_cap/licence_room`) : achat, MAX et bot s'y
  arrêtent ; la carte affiche « PLAFOND » et le palier suivant le relève. +25 %/niveau et coût ×1,2 inchangés : le T1 est identique.
  Le second moteur de l'emballement était les **lignes régulières** (les 12 lignes du T2 signées en 4 min 30) : 1 M$ au lieu de 200 K$.
- **É2 Entrée et rythme du T3** : prix de fin du T2 ÷2 environ ; bâtiments T3 de 200 à 700 M$ (au lieu de 200 M$ → 8 Md$) ;
  valeur T3 ×18 ; lignes T3 75 M$ ; Chimex 75 M$ ; Concession nationale 2,2 M EVP et 700 M$.
- **Sauvegarde version 4** : une licence au-delà du plafond de son palier est ramenée au plafond et l'excédent **remboursé** au prix
  d'achat (`PortSim._clamp_licences`, à chaque chargement, sans effet sur une partie conforme) ; message unique « Licences : nouveaux
  plafonds ». Choix : rembourser plutôt que plafonner l'affichage, pour qu'aucun bonus caché ne survive. La vraie partie du joueur
  (T1, 21 min, licences au niveau 1) n'est pas concernée ; une copie s'en charge et tourne 10 min dans `run_all` (variable `PH_SAVE_COPY`).
- **É3 Paliers nommés** : `departments.json` et `cargo.json` → `stages` (une étape par palier, ex. Portiques « Grue rouillée » →
  « Grue révisée » → « Grutiers de jour et de nuit »…). La carte montre l'étape actuelle et la suivante ; le bouton **« i »** ouvre la
  frise de toutes les étapes (niveau, multiplicateur, nom, phrase ; actuelle et suivante surlignées). **Le monde change** :
  `Layout.STAGE_PROPS`, un élément de plus par palier franchi et par département (vedettes et remorqueur, lamaneurs, douaniers,
  grutiers et lampadaires, engins de parc, agents de gate), qui surgit avec un nuage de poussière quand on revient au port
  (`Diorama._build_stage_props`, `fx_paused` tant qu'un écran couvre le monde). Argument de capture `--levels=N`.
- **É4 Achat maintenu** : `scripts/ui/hold_repeat.gd` (`HoldRepeat.attach`) sur AMÉLIORER et LICENCE : après 0,4 s, l'achat se répète
  de 0,35 s à 0,05 s d'intervalle et s'arrête au relâchement ou à court d'argent ; un son sur 3, pas de gerbe pendant la rafale, une
  gerbe « +N niveaux » à la fin, fanfare seulement sur un palier. Souris et toucher (signaux du bouton). Mode ×1/×10/×100/MAX inchangé.
- **É5 Missions visibles** : bandeau compact sous la barre du haut (coffre n/4, les 2 missions en cours avec leur barre, bouton ▲/▼
  pour le replier), masqué tant que les missions ne sont pas révélées ; toucher une mission terminée la réclame, sinon ouvre Missions.
  Missions de guidage `t1` quai, `t2` affiches, `t3` douane (type `building`) : Ambre + **30–45 s de revenu réel** ; coffre toutes les
  4 missions (+2 Ambre, +30 s ; `config.json` → `mission_chest`). Les 60–120 s du prompt avançaient le T2 de 1 à 3 min (essai mesuré).
- **É6 Retour immédiat** : le HUD garde le revenu réel ; après un achat, une pastille « +X/s » (gain estimé avant/après, cumulé pendant
  une rafale) s'efface en 3 s, et le chiffre rejoint le nouveau rythme en 3 s (le complément s'efface à mesure que la fenêtre de 60 s
  se remplit : il reste honnête).
- **É7 Tutoriel** : narratrice Capitaine Mathilde Roche (portrait dessiné, `scripts/ui/narrator.gd`, poses accueil / réflexion /
  inquiétude / bravo, champ `pose`) ; les 4 premières étapes (`lock`) assombrissent et bloquent le reste de l'interface, la cible reste
  touchable (voile en shader, trou rond ou arrondi), « Passer le tutoriel » reste actif. L'étape **goulot** vient après l'allongement
  du quai et attend un navire qui patiente en rade depuis 6 s (`PortSim.longest_wait`), cadre la caméra dessus (pose inquiète), puis
  « appuie sur le bouton de la carte rouge » (compteur `hint_used`). Mesuré : ce bouchon apparaît 2 min 45 après le quai.
  La progression enregistrée avec l'ancienne liste d'étapes est convertie par nom (`Settings.tuto_rev`).
- **É8 Statistiques** : « Gain moyen par EVP », carte **Panier du port** (valeur et part de chaque cargaison, `PortSim.cargo_shares`),
  étiquettes « ★ Maillon le plus rentable » (le niveau qui se rembourse le plus vite) et « ▼ Maillon le plus faible » (le goulot).
- **Surcouche** : rien n'est plus dessiné sous les cartes du haut (un navire caché derrière la carte du goulot ne montre pas sa bulle).
- **Bot** : économise pour le palier quand toutes les autres conditions sont remplies (avant, il gagnait l'argent du palier par hasard).
- **Optionnel non fait** : le « Pli de la capitainerie » (prime toutes les 4–6 min). Il crée une raison de rester devant l'écran, et les
  primes de mission ont montré combien le début de partie est sensible à l'argent gratuit.

### Mesures (bot, 4 graines, vrai projet)
| Mesure | Avant | Après | Cible |
|---|---|---|---|
| T1 → T2 | 11 min 17 – 13 min 02 | 11 min 14 – 12 min 06 | 12–15 min (rythme d'avant conservé) |
| Durée du T2 | 24–28 min | 27–31 min | 25–35 min |
| Fin du MVP | 1 h 12 – 1 h 30 | **1 h 17 – 1 h 30** | 1 h 15 – 1 h 30 |
| Revenu à 1 / 5 / 10 min (moyenne) | 111 / 776 / 8,8 K$ par min | 117 / 837 / 10,5 K$ | ±15 % (+5 / +8 / +19 %) |
| T2 +3 / +6 / +10 min (revenu d'exploitation) | ×3,9–12 / ×65–128 / ×379–954 | ×4,1–16 / ×18–67 / ×62–152 | ≤ ×6 / ×25 / ×80 |
| Plus forte croissance par minute en T2 (moyenne 3 min) | ×2,5–3,3 | ×2,0–2,9 | ≤ ×1,6 |
| Licence Standard fin T2 / fin (multiplicateur) | 74 / 90 (×2 460 / ×11 900) | 60 / 75 (×142 / ×263) | — |
| T3 +10 min | ×2,5–7,3 | ×7,3–8,6 | ×2–5 |
| 1ᵉʳ / 4ᵉ bâtiment du T3 | +0–20 s / +44 s – 1 min 27 | **+1 min 22 – 4 min 04 / +5 min 39 – 7 min 19** | ≥ +1 / ≥ +6 min |
| Plus long trou d'achat en T3 | 2 min 08 – 3 min 28 | 2 min 18 – 3 min 02 | ≤ 90 s |
| Pire baisse du revenu en T3 (moyenne 3 min) | 42–69 % | 30–61 % | ≤ 30 % |
| Rentabilité du meilleur achat (médiane) T1 / T2 / T3 | ≈ 2 min / 5–12 min / 2–3,5 min | 1,5 min / 7–12,5 min / 3–4,5 min | 20 s – 5 min |
| Prestige (1ʳᵉ → 5ᵉ concession) | 1 h 25 → 1 h 00 → 51 → 51 → 43 min | 1 h 22 → 1 h 04 → 59 → 52 → 50 min | — |

- **Tests** : `run_all.gd` 124 contrôles (+16 : paliers finis, plafond, remboursement unique, missions de guidage et coffre, étapes
  cohérentes avec la config, éléments du monde, bouchon visible pour le tutoriel, copie de la vraie sauvegarde) ; `ui_smoke.tscn`
  60 contrôles (+15 : voile du tutoriel, narratrice, pastille de gain, appui maintenu jusqu'à court d'argent, étapes et frise,
  PLAFOND, bandeau de missions, éléments du monde, statistiques, message sur les plafonds). Correctif : le test « l'aléa se termine »
  pouvait tomber sur un nouvel aléa tiré au hasard.
- **Captures** : `docs/captures/ism_*.png` (tutoriel verrouillé, HUD avec bandeau en portrait et en paysage, Améliorations,
  Statistiques, monde au niveau 300).
- **Limites qui restent** (détail `ANALYSE.md` §13) : le saut d'entrée du T2 dépasse ×6 en 3 min (c'est le palier lui-même) ; la
  rentabilité en T2 reste à 7–12 min (la demande limite le port la moitié du temps, et une rentabilité courte relancerait
  l'emballement) ; à-coups du revenu en T3 (Panamax, brouillard) ; rien n'a été joué par un humain ; l'appui long n'a pas été essayé
  sur un écran tactile réel.

## Direction visuelle D (13/10) — décision de direction de projet
Copie de sécurité : `C:\Nadir\tycoon_backups\V2_avant_direction_D_20261013.zip`. Revue : `docs/REVUE_CHEF_DE_PROJET.md` ; étude : `docs/ETUDE_STYLE.md`
et `docs/previews/style_variantes.png` (script `blender/preview_variants.py`).
- **`tycoon_V2` est le seul projet de travail** ; `C:\Nadir\tycoon` est gelé (validé par l'utilisateur).
- **Direction D = B + C** (tranchée par le chef de projet sur délégation de l'utilisateur) : registre « port nordique jouet » (bois clair,
  toits colorés à pente, chanfreins, bandeau marine) pour le village, le T1 et les bâtiments de service ; « B en dur » (façades claires,
  toit plat à casquette claire, grandes baies) pour le T2 ; registre « industriel pop » (bardage nervuré, portes roulantes, toits
  techniques, bandes jaune-noir) pour le T3, les hangars, les engins, les conteneurs et les navires. Sol du terminal : asphalte violet sombre.
- **Chaque bâtiment est identifiable sans lire** : un objet emblème + la couleur de son département. Le texte 3D n'est plus porteur
  d'information (enseignes décoratives ou supprimées).
- **L'environnement doit être vraiment portuaire** : bollards, défenses, échelles de quai, rails de portique, bouées, brise-lames,
  bateaux de pêche, filets, caisses, mouettes, marquages de parc, voies de gate, trottoirs et passages piétons côté village.
- Règles communes (héritées d'ISM) : socle sombre, accessoires et personnages ×1,35, ombrage marqué et ombres nettes non noires,
  information de jeu posée sur le décor, bâtiments fermés par défaut, face principale en −Y, couleurs via `palette.json` uniquement,
  budget ≤ 2 500 triangles par bâtiment et ≤ 600 par accessoire.
- Exécution : lot A (expert Blender, `docs/ORDRE_BLENDER_D.md`) et lot B (développeur Godot, `docs/ORDRE_GODOT_B.md`) en parallèle ;
  lot C (lots fantômes) ensuite ; puis test humain de 20 min avant toute nouvelle mécanique.

## Lot B (13/10) — rendu, cadrage, environnement (développeur Godot, `docs/ORDRE_GODOT_B.md`)
Copie de sécurité préalable : `C:\Nadir\tycoon_backups\V2_avant_direction_D_20261013.zip`. Fait avec les modèles livrés par la phase 1 du lot A
(bollard, défense, échelle, rails, brise-lames, bateaux de pêche, filets, caisses, mouettes, bouées sur poteau, trottoirs, passages piétons,
voies de gate, marquages de parc, totem P) ; `blender/`, `godot/assets/models/` et `assets_meta.json` n'ont pas été touchés.
- **Lumière** (`Diorama.make_environment / make_sun`, partagés avec `tests/swatch_test.tscn`) : ambiance **0,67** teinte (0,96 ; 0,94 ; 1,0),
  soleil dirigé selon (−0,243 ; −0,85 ; 0,467) — en haut à droite derrière la caméra, les ombres tombent en bas à gauche comme dans ISM —,
  énergie et couleur du soleil **calculées** pour que ambiance + soleil = blanc exact sur un dessus (≈ 0,44, teinte linéaire (0,96 ; 1 ; 0,89)) :
  un toit au soleil rend la teinte de `palette.json` **sans dérive** (nuancier éclairé = nuancier non éclairé à ±1/255 ; à savoir : Godot
  convertit `light_color` et `ambient_light_color` de sRGB en linéaire, les valeurs linéaires voulues lui sont donc passées via `linear_to_srgb`) ; flanc +X ≈ 75 %, flanc +Z ≈ 65 % (ambiance seule), ombres portées
  `shadow_opacity` 0,5 → −18 % légèrement bleu-violet, `shadow_blur` 1,5 → **0,4** (nettes). Correction linéaire conservée ;
  saturation/contraste ajoutés (1,08 / 1,04) **retirés**. Shaders `vcol` / `vcol_tint` / `water` sans brillant (rugosité 1, spéculaire 0).
  Pourquoi pas « ambiance 0,35 / soleil 1,3 » : avec ces valeurs dessus et flancs dépassent 1,0 et sont écrêtés, ce qui donnait
  justement le rendu plat constaté (`v2b_lumiere_avant.png`) ; la règle « dessus 100 %, flancs 65–75 % » se tient sans écrêtage.
- **Cadrage** (`CameraRig`) : zoom par défaut 52 → **40 u**, `START` (−26, −13) → **(−34,5 ; −5,5)** : en portrait 540×960, capitainerie,
  quai n°1, parc et navire en rade tiennent sous les cartes du HUD ; bornes et zoom minimal inchangés. En capture, la souris ne peut plus
  déplacer la caméra (`input_enabled` coupé) et `--look` verrouille le cadrage (`rig.locked`) contre les recentrages du jeu.
- **Eau** (`water.gdshader`) : dégradé selon la **distance au rivage** (rectangles de terre transmis par `Diorama._update_water_land`,
  mis à jour avec le palier) : liseré clair au contact, eau côtière sur 7 u, puis teinte du large de 14 à 70 u ; écume des quais conservée.
- **Surcouche** (`world_overlay.gd`, classe pure `Bubbles`) : bulles de bâtiment posées **au-dessus** de `anchor_y` (lu dans
  `assets_meta.json`, sinon sommet de la boîte englobante + 0,4 — `Assets.anchor_y`), douane, gate (guérite ou barrière), grues ;
  deux bulles qui se chevauchent sont décalées latéralement (`Bubbles.settle`), la pastille de la gate n'est plus coupée par le bord.
- **Débogage coupé en export** (`scripts/util/debug_args.gd`) : `--speed`, `--debug-money`, `--tier`, `--levels`, `--build-all`,
  `--hire-all`, `--build`, `--unlock-all`, `--open=debug` et F1 seulement si `OS.is_debug_build()` ; la ligne « F1 » des Réglages aussi.
  `--fresh`, `--capture`, `--delay`, `--look`, `--zoom`, `--tuto` restent disponibles partout.
- **Entrepôts du village** : gardés dès le T1 (la zone logistique est un vrai tampon entre le port et les maisons, et le continent
  resterait vide sans eux) mais **gris neutre** (`desat` 0,85 du shader `vcol`, clé `neutral: "t3"` dans `Layout.PROPS`) tant que le
  département logistique n'existe pas ; au T3 ils prennent la couleur du département. Choix : la révélation progressive porte sur la
  couleur (ce qui identifie un département), pas sur la présence du bâtiment.
- **Personnages** (`TrafficView.add_walker`) : aller-retour en ligne droite entre deux points (dockers tablier ↔ parc, douanier
  table ↔ porte du bureau, responsables selon `Layout.MANAGER_WALK` : capitainerie ↔ quai, gate ↔ guérite…, personnages des paliers
  avec la clé `walk`), 1,7 u/s, pause 1,2 s à chaque bout, demi-tour instantané, balancement vertical de 7 cm ; en pause quand un
  écran couvre le monde (`walk_paused` = `fx_paused`). Pas de pathfinding.
- **Environnement portuaire** : `Layout.quay_props` (bollards tous les 4 u, défenses entre eux, échelles aux extrémités de chaque poste,
  rails de portique 12 × 1,2 sur le tablier T2+, mouettes sur un bollard sur cinq), `Layout.street_props` (brise-lames de 3 segments de
  12 u à l'ouest de la rade, trottoirs et passages piétons du village, marquages de parc 12 × 6 sur l'asphalte T2+ / RTG T3),
  `PROPS` (bateaux de pêche, filets et caisses en T1 seulement — nouvelle condition `t1` —, mouettes sur le toit du hangar via la clé
  `on`, bouées sur poteau, voies de gate, totem P avec `parking1`, voitures garées `car_c`). Chargeur **tolérant** (`Assets.scene`) :
  un modèle absent donne un nœud vide, un seul avertissement par nom, les MultiMesh l'ignorent ; `car_c` est le seul encore absent.
- **Tests** : `run_all.gd` **129 contrôles** (+6 : modèle absent, emplacements préparés, bulle au-dessus de `anchor_y`, décalage
  latéral, triches ignorées hors debug, appliquées en debug ; 130 avec `PH_SAVE_COPY`) · `ui_smoke.tscn` **62 contrôles** (+2 : bulle
  « À inspecter » au-dessus de l'ancre dans la vraie scène, monde construit malgré un modèle absent avec des personnages qui marchent).
  Correctif de fiabilité : les contrôles qui comptent les fenêtres ouvertes ne comptent plus les effets transitoires (gerbes, textes)
  de la même couche, dont la durée de vie dépendait de la vitesse de la machine. `swatch_test.tscn` mesure aussi un dessus au soleil.
- **Captures** : `docs/captures/v2b_lumiere_avant.png` / `v2b_lumiere_apres.png` (même cadrage 52 u), `v2b_portrait_t1.png`,
  `v2b_paysage_t1.png` (1280×720), `v2b_portrait_t3.png`, `v2b_zoom_capitainerie.png` (zoom 28).
- **Limites** : les ombres en T3 sur les portiques sont nettes mais longues de 0,6 × la hauteur ; le dégradé de l'eau ignore les îlots (rochers du phare approchés
  par un rectangle) ; les marquages de parc ne sont pas alignés sur les travées de 4,4 u des conteneurs (dalle de 12 u) ; `ghost_lot`
  attend le lot C.

## Plan de la baie (13/10) — zones, trajets, chapitres (`docs/PROMPT_PLAN_PORT.md`, journal `docs/JOURNAL_PLAN_BAIE.md`)
Sauvegarde préalable : `C:\Nadir\tycoon_backups\V2_avant_plan_baie_20261013_1950.zip`. Plan coté : `docs/PLAN_COTE.md`.
Aucune migration de sauvegarde (les bâtiments sont enregistrés par identifiant ; les zones se déduisent de `sim.built`).
- **Terrain polygonal construit dans Godot** (`Layout.COAST/BREAKWATER/RECLAIM`, `Terrain`) : continent avec cap, crique et baie,
  dessus coloré et flancs de terre ; dessus à y −0,05 et sols de zone à −0,025 pour rester sous les dalles (routes, parcs).
  Eau : **texture de distance** 256 × 256 (balayage + chanfrein 3-4, ≈ 40 ms) au lieu des 12 rectangles, recalculée quand le
  terre-plein (bâtiment `berth3`) apparaît.
- **Zones** (`Layout.ZONES`, `Zones`) : ouverte au départ, au palier (Colline) ou par son bâtiment clé ; **une seule prochaine** :
  celle dont le bâtiment clé est le premier non construit de la liste (y compris au-delà du palier : la pancarte dit « palier T2 »).
  « Mouillage » n'est pas une zone : une bouée numérotée par place en rade. Toutes les autres zones sont visibles en gris.
- **Cases** (`Layout.LOTS`) : chaque bâtiment a la sienne, son empreinte `ghost_lot` est dessinée dès le départ (dorée pour le
  prochain achat) ; ce qui n'avait pas d'objet en a un (atelier, bureau du pilotage, centre informatique, guichet numérique,
  remorqueur, taquets d'amarrage). Toucher l'empreinte ouvre la fiche du bâtiment (CONSTRUIRE), toucher une zone grise sa fiche.
- **Ouverture de zone** (4,2 s ; 5 s pour le terre-plein, `Layout.OPENING*`) : passable d'un toucher, en pause sous un écran ou une
  fenêtre, phrase de la narratrice (`Layout.ZONE_SAY`), vibration courte sur mobile (aussi à chaque achat).
- **Trajets** : navires sur polylignes (mouillage devant la passe, chenal, bassin d'évitage, accostage parallèle, sortie est) ;
  camions en boucle à sens unique (tunnel ouest → gate d'entrée → voie des camions → arrêt devant une travée réelle → gate de
  sortie → tunnel est) ; engins côté mer vers des travées réelles, qui apportent le conteneur au camion. Tolérances du test
  `test_trajets` : navire à ≥ 2,5 u de toute terre hors de son poste ; véhicules sur la terre et hors des bâtiments (allées des
  parcs, portique scanner exceptés) ; engins à ≥ 1,75 u des camions (au chargement, la remorque touche le bord du parc) ;
  personnages à ≥ 2,5 u des camions et 1,2 u des engins.
- **Chapitres** (`unlocks.json`, conditions `level`, `manager`, `bottleneck`, `any`) : petit quai → (grue 10) parc + Gestion +
  responsables + licences → (parc 10, ou la gate devient le goulot) gate → (gate 10) navires (Commerce, Missions, réputation, barre
  de palier) → palier 2 (Heures sup, aléas, statistiques). Les responsables se présentent au niveau 10 de leur service.
  **Écarts au prompt** : licences au chapitre 2 (au palier 2, le T1 dure 14–15 min et la gate bloque 3–4 min avant son chapitre) ;
  la gate s'ouvre aussi quand elle devient le goulot (« le service suivant s'allume parce qu'il devient le goulot », `ETUDE_CARTE`
  § 3) ; l'allongement du quai reste le premier achat (zone prochaine dès le départ, tutoriel sur son empreinte) au lieu d'attendre
  le chapitre 4 : le retarder aurait cassé le début doux.
- **Gestes optionnels** : engin du parc (2 s de rangement, recharge 4 s), barrière de la gate (2 s de gate, recharge 4 s) ;
  jamais nécessaires, remplacés par Nadia Benali et Tonio Ferrer. Le bot les utilise et suit le tutoriel pour son premier achat.
- **Mesures** (4 graines) : premier achat 1 s ; T1 → T2 12 min 34 – 13 min 29 ; durée du T2 −11,8 à +8,7 % ; fin 1 h 19 – 1 h 25
  (±8 %) ; parc et gate jamais goulots avant leur chapitre. **Non tenu** : trou d'achat ≤ 90 s au T1 (2 min 08 – 2 min 24, déjà
  1 min 22 – 1 min 34 avant) — voir le journal, options à trancher.
- **Tests** : `run_all` 152 contrôles (+23), `ui_smoke` 74 (+12). Captures `docs/captures/plan_cote_*.png`, `baie_*.png`.
- **Limites** : camions sans distance de suivi entre eux ; les cartes du HUD masquent le haut des grandes zones pendant leur
  ouverture ; pas de modèle pour la « butte » de la Colline (sol vert vif plat) ; pas de projet d'export Android dans `tycoon_V2`.

## Plan de la baie — corrections (13–14/10) après la revue (`docs/REVUE_PLAN_BAIE.md`, journal `JOURNAL_PLAN_BAIE.md` § « Corrections »)
Décisions retenues par le chef de projet appliquées sans les rouvrir : départ 260 $ et quai en premier ; navires par la passe aux paliers 1–2 ;
chapitres fermés au niveau 10 ; un sujet par seuil. Sauvegarde : format v4 inchangé (les révélations sont enregistrées par identifiant ;
leur instant ne l'est pas : une fonction chargée compte comme révélée « depuis longtemps »).
- **Export Android** : `godot/export_presets.cfg` (paquet `com.nadir.porthorizon.v2`, « Port Horizon V2 », installable à côté de la V1),
  `exporter_apk.bat` → `build\PortHorizonV2.apk` (debug signé). Lancé : APK de 29,5 Mo produit.
- **Début** : `start_money` 260 ; tutoriel révision 4 (« quay » avant « buy », conversion par nom) ; le bot suit le même ordre.
- **« Vert si possible, gris sinon »** : carte Goulot rouge et bouton vert seulement si l'action est possible tout de suite (`Hud.hint_actionable`) ;
  texte de rentabilité gris si l'achat n'est pas abordable ; la carte du service qui ferme le chapitre dit « Niveau 10 : ouvre « … » (n/10) »
  au lieu de « Aucun gain immédiat » (`PortSim.chapter_goal`).
- **Un sujet par seuil** : `config.json` → `reveal_gap` = 20 s entre deux révélations ordinaires ; `"opens_chapter": true` (Parc, Gate,
  Commerce, Douane) passe tout de suite, une par seconde ; condition `after` (N s après une autre révélation). Calendrier : grue 10 → Parc ·
  +25 s Responsables · parc 10 (ou gate goulot) → Gate · +25 s Gestion · +3 min Licences · gate 10 → Commerce · +25 s Missions · +25 s Réputation
  · +25 s Paliers · Ambre · bureau de douane → Douane · +25 s Contrats · T2 → Heures sup · +30 s Statistiques · +30 s Aléas.
  **Écart assumé** : les licences arrivent 3 min après la gate (≈ 9 min 30 – 10 min) et non plus avec le parc : c'est ce seuil qui ramène le
  T1 dans 12–20 min avec 260 $ de départ (essais a → h, `ANALYSE.md` § 14).
- **Ouverture de zone** : HUD masqué (fondu, boutons inactifs), bulles, tutoriel, notifications et bandeaux en file, seule la phrase de la
  narratrice ; « Toucher pour passer ». Terre-plein en 7,5 s (barges `barge_sand` qui déversent, sable, asphalte, dalles, quais, portiques) ;
  autres zones en 4,9 s avec un chantier (cônes, poussière). Dalles, bollards, marquages et musoirs d'une zone surgissent avec elle.
- **Notifications** : une à la fois sous l'en-tête, dans la colonne de gauche, en file (4 au plus).
- **Zones à venir** : teinte du quartier gardée (désaturation 0,55, voile 0,25), une icône par zone, empreintes seulement pour les zones
  ouvertes et la prochaine, contour seul pour les cases à flot ; chenal à venir en **bouées fantômes** ; zone 12 grise jusqu'à la gare.
- **Bulles** : parc, gate, aire d'attente, douane après leur chapitre ; « File : n » ; « n/N en rade » rouge seulement si la rade est pleine ;
  anneau du goulot seulement si une amélioration est possible ; toutes bornées au rectangle utile (`Hud.useful_rect`, `Bubbles.bound`) ;
  texte des bulles et pancartes 30 px sur 1080 (≈ 15 px sur un écran de 540).
- **Touchers** : plus petit rapport distance / rayon (`Diorama.pick_tap`, `Layout.TAP_RADIUS`) ; zone grise = bulle d'information de 2 s.
- **Mouillage et passe** : bouées jaunes de marque spéciale ; place n°1 en (−71 ; −69) (26 u de la pointe du cap) ; cadrage de départ
  (−51 ; −30), 48 u ; brise-lames prolongé à x −18 (passe de 46 u, feu rouge en (−21 ; −44)) ; le vert du modèle `breakwater` rendu gris.
  **Navires** : deux voies dans le chenal (3 u de part et d'autre de l'axe) ; départ par la passe et le large au nord aux paliers 1–2,
  par l'est au palier 3 ; les navires mouillés à l'est du chenal rejoignent la voie d'entrée par le large.
- **GNL** : deux `lng_sphere` (modèle livré par l'expert Blender) en (145 ; 6) et (145 ; 19), repli `silo` ; case `lng` 9,4 × 22,4.
- **Quartiers** : haies (`Layout.HEDGES`) ; la Colline est une butte de 1,4 u (`Layout.BUTTE`, `Layout.ground_y`) ; arbres en bosquets.
- **Divers** : « + » de l'Ambre écrit (plus de pastille orange vide) ; « RESPONSABLES · n au travail · m à embaucher » ; sillage en V qui
  s'estompe ; « Remise en état de la friche » (gravel2) ; `zone_ice` et `zone_dash` dans `Layout.PALETTE_EXTRA` (palette.json est
  régénéré par la chaîne Blender et les avait perdus).
- **Captures** sur des parties de bot réelles : `tests/bot_saves.gd` écrit des sauvegardes dans un dossier temporaire ; `--load-sim=…`
  (avec `--fresh`, version de débogage) les charge pour la capture.
- **Mesures** (4 graines) : premier achat 1 s ; T1 → T2 12:13 – 12:45 ; durée du T2 −12,0 / +11,9 / +1,3 / +7,7 % (moyenne +1,7 %) ;
  fin 1 h 12 – 1 h 24 (−8,9 à +5,2 %) ; attente sans rien d'abordable au T1 ≤ 1 min 16 ; parc et gate jamais goulots avant leur chapitre ;
  ≥ 20 s entre deux révélations ordinaires. **Limites** : le trou d'achat du bot reste > 90 s (épargne du bot pour le bureau de douane) ;
  deux graines à ±12 % sur la durée du T2.
- **Tests** : `run_all` 162 contrôles (+10), `ui_smoke` 81 (+7) ; aucun retiré (5 recalés, voir le journal).

## Plan de la baie — seconde revue (14/10), lot C6 (journal `JOURNAL_PLAN_BAIE.md` § C6a–C6c)
- **Chenal** : axe décalé de 3 u vers l'ouest, ±14 u, voie d'entrée à 4 u (ouest) et de sortie à 6 u (est) de l'axe ; bouées du large
  jusqu'à la passe seulement ; tout navire entre par `CHANNEL_ENTRY` ; cap à l'écran = corde étrave–poupe sur le trajet. Contrôle :
  coque ≥ 1,5 u de toute bouée et des feux (2,0 u au plus près). Mouillages sur une grille 50 × 28 u ; feeder ×0,94, panamax ×0,78 ;
  contrôle « deux coques ≥ 2 u ». Distance de suivi 4 u entre deux navires qui vont dans le même sens.
- **Départ** : `START` (−45 ; −29), 58 u ; carte Goulot masquée pendant une carte du tutoriel ; `ui_smoke` en fenêtre portrait.
- **Notifications** : sous la carte Goulot, colonne de gauche, fond opaque, 60 s sans doublon, file de 2, une toutes les 4 s, 3 s de
  calme après une ouverture de zone. **Surcouche** découpée au rectangle utile.
- **Révélations** : `reveal_gap` 60 s, ou 20 s (`reveal_gap_min`) si la précédente a servi (`used` dans `unlocks.json`) ; gate ouverte
  au niveau 10 du parc ou quand elle est le goulot depuis 45 s (option a) ; caméra 2 s sur le poste d'un service dont le chapitre s'ouvre.
- **Conseil affiché** (`analysis_shown`) : jamais « pas assez de navires » quand la rade est pleine depuis 3 s (présentation seulement).
- **Douane au T1 (N5)** : **non changé** — la masquer ou la retarder repousse le palier 2 à 21–29 min ; décision à prendre (options au journal).
- **Mineurs** : « Toucher pour passer » lisible et seulement après 1,5 s (séquence non passable avant) ; un seul badge numérique ;
  empreintes avec liseré ; « File : n » ancrée sur la guérite (ou la barrière).
- **Critère du T2** : moyenne des 4 graines ±5 %, chaque graine ±15 % (adopté) — tenu (moyenne −0,5 %).


## Lot C7 — corrections de la revue de code C6 (14/10, journal `JOURNAL_PLAN_BAIE.md` § C7)
- **Navires à l'écran** : la vue suit toujours une polyligne du plan (abscisse curviligne propre) ; retenue = abscisse figée ;
  rattrapage borné (2 × nominale, ≥ 10 u/s, × vitesse de simulation) ; un départ terminé dans la simulation finit à l'écran.
- **Sauvegarde version 5** : `features` = {id : instant} (+ dernière révélation) ; l'ancien format liste reste lisible.
- **Outils de débogage** : réservés au binaire de l'éditeur (`OS.has_feature("editor")`), jamais dans un APK, même debug.
- **Ouverture interrompue par une reconstruction** : terminée comme un toucher (narratrice et retour de la caméra gardés).
- **Notifications** : file de 2, on jette la plus ancienne non « bad » ; rien sur un écran ou une fenêtre ; anti-doublon à l'affichage.
- **Avant Gestion** (chapitre 3) : le conseil « CONSTRUIRE » ouvre la fiche du bâtiment ; aucun texte ne renvoie à Gestion.
- **Tutoriel** (liste v5) : parc avant Yasmine ; « embauche-la » sautée si Yasmine n'est pas là.
- **Barges du terre-plein** : couloir est–ouest devant le futur quai (z −15).
- `unlocks.json` : plus de champ `chapter` ; Douane et Contrats en tête (ordre réel des révélations).


## Interface (lot D) — 14/10 (journal `JOURNAL_PLAN_BAIE.md` § « Lot D — UI », ordre `docs/ORDRE_D_UI.md`)
- **Acheter au-dessus du port vivant** : Améliorer et Commerce sont des feuilles basses à mi-hauteur (58 % de l'écran) ; le port
  continue de vivre au-dessus (effets, bulles), la caméra y cadre le service acheté, le solde est dans l'en-tête. Gestion, Missions et
  Réglages restent plein cadre (avec un mini-solde) : Gestion construit, et une construction lance une ouverture de zone.
- **HUD du haut sous 20 %** (15 % au T3) : barre indigo + une ligne (coffre des missions, carte Goulot réduite à titre + bouton,
  détail au toucher) ; bandeau des missions replié par défaut. En bas : Réglages en petit rond, Gestion (Responsables y est
  intégré : pastille ambre), Commerce, gros AMÉLIORER vert à droite ; Heures sup en rond flottant, grand seulement quand il est prêt.
- **Carte Goulot** : le bouton dit quoi et combien et passe au vert dès qu'une action règle le goulot ; « parc trop petit » =
  capacité (place × rotation), la jauge montre le stock. Même achat, même nom partout (nom du bâtiment).
- **Charte** : vert = argent / acheter, bleu = info, ambre = « touche-moi », rouge = problème, gris = impossible seulement.
  Unités : revenu toujours en **$/s** ; gestes manuels en $. Textes ≥ 24 px, cibles ≥ 96 px (zones de toucher élargies).
- **Retours** : achat → effet dans le monde + « +X $/s » ou « +n % — pas le goulot » ; navire payé → « +X $ » et pièces vers le
  compteur ; palier, nouvelle concession et fin → cérémonie (gerbes, dézoom, jingle) puis la fenêtre ; retour d'absence → ENCAISSER.
- **Sons** : un son par moment (construction, embauche, palier de niveau, Heures sup, coffre ; « tier » et jingles réservés aux
  paliers), ±4 % de hauteur, demi-ton qui monte en appui long, 10 voix à priorité (corne et jingles jamais volés), bus « Sons » et
  « Ambiance » réglables (`user://audio.cfg`).
- Interface monde fournie par D-Monde et utilisée : `feedback_purchase`, `set_overtime`, `set_campaign`, `dept_anchor`,
  `rade_anchor`, signal `ship_paid` (toujours appelés via `has_method` / `has_signal`).
- Non fait / limites : Gestion pas en mi-hauteur (voir plus haut) ; les aides d'en-tête se replient après une lecture **par
  lancement** (pas de mémoire sur disque) ; la valeur en $ des gestes est une estimation (EVP × valeur moyenne d'un EVP).
- Captures : `--open=hint` (carte Goulot dépliée), `--open=settings`, et en version de débogage `--open=tier` (cérémonie du palier courant), `--open=shippaid` (encaissement au poste n°1).


## Réorganisation du port (lot D) — 14/10 (journal `JOURNAL_PLAN_BAIE.md` § « Lot D — Monde », ordre `docs/ORDRE_D_MONDE.md`)
- **Circulation à droite** (autoroute, route d'accès, voie des camions) : on entre à l'est, on sort à l'ouest ; la boucle se fait
  à vide, le chargement au retour le long du parc. Conséquence voulue : les camions **chargés** sortent devant la douane et sous
  le scanner à portique ; entrée et sortie ne se croisent plus. `gate2` est une **deuxième voie de sortie**.
- **Douane dans une enceinte côté sortie** (bureau, scanner mobile, scanner à portique, halle au T3 à la place du hangar) ;
  guichet numérique et douane dématérialisée **côté public**, aux **Bureaux du port** (ex-Colline, zone 13, palier 2, à plat).
  Zone **Gate** (ouverte au départ) séparée de la zone **Bureau de douane**.
- **Pôle nautique sur le cap** (zone 9, butte) : tour VTS face à la passe (35 u), pilotage au pied, atelier avec cale de halage
  sur la crique ; la Capitainerie passe à la tour au T2. Zone grise « discrète » tant qu'elle est fermée (cadrage du tutoriel).
- **Même achat, même nom** : une zone ouverte par un bâtiment porte le nom de ce bâtiment ; deux bâtiments renommés pour être
  aussi des noms de lieu (`reefer` « Pôle froid », `gate2` « Deuxième voie de gate »).
- **Gare contre le terre-plein**, reliée à sa voie des camions ; logistique en arrière-plan. **Brise-lames et passe est au T3** :
  postes 3–4 par l'est, postes 1–2 par la passe ouest à tous les paliers ; voie au large du mouillage au nord du chenal.
- **Pas de gate est** : la simulation n'a qu'une file et un débit de gate ; une seconde file serait une présentation inventée.
- **Vie du port** : foule de dockers et douaniers en MultiMesh, nombre lié aux agents (plafond 28 + 4), dockers sur le pont
  pendant le déchargement, demi-tour progressif ; conteneurs posés (descente + glissement) ; Heures sup visibles (gyrophares,
  grues plus rapides, lumière plus chaude) ; campagne visible (pavillons, fanions) ; retour d'achat au poste.
- `ship_paid` porte un **montant estimé** (la simulation ne mémorise pas le montant d'une escale) : manutention de la cargaison
  relevée à l'arrivée aux valeurs du moment + droits de port et services, même formule que `PortSim`, en lecture seule.


## Rythme (lot D) — 14/10 (ordre `docs/ORDRE_D_ECO.md`, essais `ANALYSE.md` § 15, journal `JOURNAL_PLAN_BAIE.md` § « Lot D — Éco »)
- **Services facturés** (`service_fee` 0,5) : chaque niveau de service au-delà du premier facture l'équivalent de 0,5 EVP/s au
  prix de base d'un EVP (sans licences) — un achat hors goulot rapporte toujours un peu ; la part fond aux paliers 2 et 3
  (`PortSim.service_fee_rate`, recette « fees », comptée dans les estimations de revenu, du hors-ligne et des gains d'achat).
  Écarté : un bonus multiplicatif (« qualité de service ») qui gonflait le T2 de ×8 de plus.
- **Licences 60 s après la gate** (180 avant) et plafond T1 30 : le stock de licences ne part plus d'un coup au passage du T2.
- **Palier 2 tenu par l'argent** : 8 500 EVP, 14 000 $, Extension du parc gravier 14 000 $ (le T1 reste à 12 min 30 malgré les
  services). Palier 3 : 540 000 EVP. Concession : 4 × 10⁸ $.
- **Entrée du T2 étalée** : Nordhaven 200 K$, lignes T2 2,5 M$ (×1,6 par ligne, 5 par armateur ; T3 6).
- **Révélations** : écart minimal 45 s ; rien pendant 60 s après un palier (`reveal_tier_hold`, la cérémonie passe seule) ; barre de
  palier à 200 EVP (≈ 2 min, avant la Douane) ; Ambre après Réputation ; statistiques et aléas 150 s après les Heures sup.
- **Carte Goulot** : rouge seulement en alerte (`PortSim.alert_reason` : brouillard, navire à < 30 % de patience, parc ≥ 90 %,
  camions bloqués ; tenue 4 s) ; un goulot normal reste neutre (titre indigo, pastille bleue), le bouton garde « vert si possible ».
  Seul changement d'interface avec la ligne « Services facturés » de Gestion › Stats.
- **Mesures** (4 graines) : T1 12:23 en moyenne, T2 28:52, fin 1 h 24 ; rentabilité T1 2 min 04 – 2 min 24 (avant 4 min 53 – 7 min 46) ;
  T2 +3 / +10 min ×4,0–5,5 / ×18–35 (avant ×14–18 / ×234–331) ; 2–4 bandeaux autour du T2 (avant 7) ; barre de palier à ≈ 2 min.
- **Non tenu** : rentabilité T2 ≤ 3 min (4 min 51 – 6 min 39 ; il faudrait ×10 000 de croissance sur le T2 et tout le T3 ×10) ;
  trou d'achat ≤ 90 s au T3 (1 min 19 – 1 min 35 à l'entrée, 2 – 3 min sur le palier : les bâtiments T3 valent 1,5–3 min de revenu).
- Chapitres du T1 plus tôt (Douane ≈ 3 min 30, gate ≈ 6 min, Commerce ≈ 7 min). Format de sauvegarde inchangé.
- Sonde : `--curve`, `--maxh=`, `--bot-save=` ; bot : valorise les services facturés (`fee_rel`), épargne réglable (`save_horizon`, 150 s).


## Confiance (lot E) — 14/10 (ordre `docs/ORDRE_E_CONFIANCE.md`, journal `JOURNAL_PLAN_BAIE.md` § « Lot E — Confiance »)
- **Bon achat = débit qui bouge et rentabilisé en moins de 10 min** (`Advice.GOOD_PAYBACK` = 600 s). Seuil fixe plutôt que
  « 2 × la médiane du palier » : lisible, stable d'une partie à l'autre, et la médiane du meilleur achat reste entre 2 et 6 min
  (sonde). Seuls les bons achats passent au vert, comptent dans la pastille d'Améliorer et portent ★ MEILLEUR ACHAT.
- **Les services facturés ne sont pas un gain du port** pour l'interface : le gain d'un achat est séparé en part « débit » et
  part « services » (`PortSim.upgrade_gain_parts`, mêmes valeurs que `upgrade_gain` au bit près). Un niveau qui ne fait monter
  que les services s'affiche « Portiques +6 % · pas le goulot (+15 $/s de services) » en gris (« le débit ne bouge pas » sur le
  service goulot lui-même), jamais « rentabilisé en 102 h » en vert. Le revenu, lui, les compte (ils sont encaissés).
- **Bouton Goulot = ce qui règle le goulot** : table goulot → effets de `buildings.json` (postes à quai → `add_berth`, parc trop
  petit → `yard_cap` du parc, gate → voies / aire / débit de gate, grue → grues, douane → bureau / scanners / formalités…).
  Le bâtiment n'est proposé que s'il est le prochain de la liste (ordre strict inchangé) ; sinon l'amélioration du service qui
  le soulage — pour « postes à quai » et « escales au plancher », seulement si elle fait bouger le débit — ; sinon le bâtiment
  à viser (gris) ; sinon GESTION. Brouillard : PATIENTER. Logique dans `scripts/ui/advice.gd` (testable par run_all).
- **Coût des aléas sur le revenu réel** (fenêtre d'une minute, `PortSim.real_income_rate`), plafonné à 25 % de la trésorerie
  (`hazard_cost_cap`) ; moins de 15 s mesurées (partie tout juste chargée d'une ancienne sauvegarde) : estimation plafonnée,
  recalculée dès que 15 s sont mesurées. Sauvegarde : la dernière minute de revenu et `last_tier_t` sont enregistrées (champs
  facultatifs, **version inchangée**) — le revenu affiché ne tombe plus à « +41K $/s » juste après un chargement.
- **Noms courts tirés du nom du bâtiment** (ses mots, dans l'ordre, sans « ᵉ ») : pancarte et Gestion gardent le nom complet,
  le bouton un extrait (« ALLONGEMENT DU QUAI », « PÔLE FROID », « DEUXIÈME VOIE »).
- Feuille : l'aléa en cours reste visible en pastille au-dessus d'une feuille mi-hauteur. Cérémonie de palier : la fenêtre dit
  ce qui s'ouvre (`tiers.json` → `opens`, 3 icônes par palier) et VOIR cadre la zone du prochain bâtiment du palier ; la couche
  de cérémonie passe sous les fenêtres ; la surcouche monde est masquée sous une fenêtre.
- Volume enregistré au relâchement de la réglette (ou à la fermeture de Réglages) ; `Sfx.persist` faux pendant les tests.

## Lot F — modèles de la crique, des chantiers et de la forêt — 14/10 (ordre `docs/ORDRE_BLENDER_F.md`, expert Blender)
- **21 nouveaux modèles**, aucun `.glb` existant modifié, palette inchangée (aucune teinte ajoutée) : `blender/parts/crique.py`,
  `chantier.py`, `foret.py`, branchés dans `build_assets.py` (budgets fixés nom par nom dans `EXACT`, tous respectés).
  Rendus : `docs/previews/f_crique.png`, `f_chantier.png`, `f_foret.png`.
- **Conventions** : bateaux étrave en +X, origine sur la ligne de flottaison (à poser à `WATER_Y`, comme `fishing_boat`) ;
  pontons idem, plancher à z = 0,45 (`deck_z`), module 6 × 1,6 sur X qui se raccorde bout à bout ; bâtiments, estacade et forêt
  origine au sol, face principale −Y. `ice_plant.chute_end` (repère Godot) = point où la goulotte déverse, à aligner sur le quai.
  `jetty_ruin` : 24 × 3,2 sur X, plancher à 0,25, pieux jusqu'à −2,85, partie effondrée x ∈ [−3, 3] (`collapsed_x`).
  `forest_road` : route sur Y, entrée ouverte en −Y, le trafic disparaît vers y = +6 (fond noir). `far_shore` : 260 × 50, face −Y.
- **Modèles articulés** (pièces nommées, aucun rig ; axes en repère Godot dans `assets_meta.json` → `nodes`) :
  `site_crane` = `base` + `jib` (pivot (0, 10, 0), `rotation.y`) dont l'enfant `hook` (chariot + crochet, glisser `position.x`
  entre 1,5 et 8,5) ; `excavator` = `base` + `turret` (`rotation.y`) > `boom` (`rotation.z`, > 0 lève) > `arm` (`rotation.z`,
  > 0 ouvre vers l'avant).
- `scaffold` (4 × 4 × 4) et `site_hoarding` (module 4 u) sont faits pour être étirés / répétés par le jeu ; le centre de
  l'échafaudage est vide (le bâtiment en chantier se voit dedans).
- `build_assets.py` ne réécrit plus `godot/data/palette.json` quand son contenu est identique.
- Limites : aperçus sur sol vert (pas d'eau : coques et flotteurs coupés à z = 0) ; `far_shore` jamais vu à 300 u dans le jeu
  (à vérifier en F2, éventuellement brume) ; les nouveaux `.glb` n'ont pas encore de `.import` (premier lancement de Godot).

## Navires et défilement (lot F1) — 14–15/10 (ordre `docs/ORDRE_F1.md`, journal `JOURNAL_PLAN_BAIE.md` § « Lot F1 »)
- **Simulation inchangée, le monde montre un échantillon des escales.** Mesuré : une escale occupe un poste ≈ 6,5 s au T1, 3 s
  au T2, 7 s au T3 (jusqu'à 36 escales par minute) ; un navire à vitesse de croisière met 70 à 150 s du mouillage au quai. Mettre
  le trajet dans la simulation (recommandation de l'ordre) aurait multiplié le cycle d'un poste par 5 à 10 : rejeté. Les vues
  des navires font leur propre voyage (`ShipView`) ; en rade, une vue par escale (liée) ; vers chaque poste, un navire en route
  à la fois ; à quai, déchargement à l'écran (8–20 s), puis départ ; l'argent des escales du poste s'affiche au départ du
  navire à l'écran. Sonde, sauvegarde et économie identiques au bit près.
- **Vitesse de croisière par classe** (mini 7,5 · caboteur 7 · feeder 6 · panamax 5 u/s ; 0,55 × dans le port, 0,38 × en
  manœuvre), **jamais liée aux achats** ; rotation ≤ 19°/s, aucune rotation navire arrêté ; plus de rattrapage (`CATCHUP_K`).
- **Postes 1–2 amarrés étrave à l'ouest** (évitage à l'arrivée devant le poste, départ droit vers la passe) ; postes 3–4
  étrave à l'est (inchangé). Accostage et départ en **glissement latéral** de 10–12 u avec le remorqueur (épaule côté large).
- **Remorqueur** de la crique (−51 ; −15) : rendez-vous à l'entrée du chenal (ou passe est), remorque en tête, hanche pendant
  l'évitage, épaule pour le glissement ; un navire n'entame pas l'évitage ni ne quitte le quai sans lui.
- **Défilement géré par la feuille** (`Sheet._input`) : un glissé de plus de 14 px défile d'où qu'il parte (bouton compris),
  au doigt et à la souris ; le bouton sous le doigt n'agit pas (`NOTIFICATION_SCROLL_BEGIN`, `HoldRepeat.cancel`) ; appui bref
  inchangé ; reconstructions de `refresh()` différées au relâchement (`request_rebuild`), position gardée.
- Limite connue : le bassin intérieur (≈ 28 u) est plus étroit qu'un feeder (34 u) : son évitage se fait coque sur la corde,
  centre lent au milieu de la manœuvre — à revoir avec l'espace du lot F4. `run_all` se lance aussi en trois parts
  (`-- --part=1|2|3`).

## Le golfe, partir de rien (lot F2) — 15/10 (ordre `docs/ORDRE_F2_F3.md`, journal `JOURNAL_PLAN_BAIE.md` § « Lot F2 »)
- **La simulation n'est pas modifiée** : sonde identique au bit près, pas de nouvelle version de sauvegarde.
  - Le départ se joue **simulation gelée** (`Sim.paused`, piloté par `Hud`) : cartes d'intro, friche, séquence de chantiers
    du T1, arrivée du premier navire. Il ne coûte aucun temps de jeu.
  - *Rejeté* : un premier pilotage de 60 s dans la simulation pour caler le premier navire. T2 +7,6 % en moyenne et aucun
    revenu la première minute, hors tolérance.
- **Premier navire du T1** :
  - sa vue naît hors champ dans le chenal à la fin du chantier du quai (`Diorama._spawn_first_ship`, `Layout.first_ship_path`)
    et file au poste n°1 sans mouiller ;
  - la simulation démarre quand il glisse vers le quai depuis 5 s (`FIRST_CRAB_LEAD`) ;
  - mesuré : escale et arrivée à l'écran à 7,5 s d'écart (< 15), le joueur l'ayant touché aussitôt ;
  - le tutoriel « touche le navire » le suit au lieu de viser le mouillage.
- **Chantiers** (`SiteWorks`, présentation seule) :
  - lancés par `purchased` (bâtiments seulement) et par la séquence du T1, jamais au chargement ;
  - 3 s (petite case) à 6 s (quais, grandes cases), jamais accélérés ni passés ; en pause sous un écran plein ;
  - palissade, échafaudage ou rien sur l'eau ; pelleteuse ou grue de chantier animées ; poussière ou éclaboussures ; son
    `works` ;
  - montée avec dépassement de 8 % ; l'état d'avant rétrécit dans la poussière ;
  - le terre-plein garde son remblai (ouverture de zone).
  - Les nœuds portent `site` (bâtiment ou pièce de départ) et `before` (état d'avant). Les accessoires en MultiMesh
    attendent la fin du chantier, sauf pour les bâtiments clés d'une zone (`_SITE_ZONE_KEYS`) : leur ouverture de zone les
    montre déjà.
- **Trafic lié à ce qui existe** (`Diorama.ready_bid`, `TrafficView.ready_fn`). Pendant le chantier d'un bâtiment, rien ne
  s'en sert :
  - pas de navire à l'écran avant le quai (ni vers un poste en chantier) ;
  - pas de camion avant la gate ; pas d'engin avant le parc ;
  - ni deuxième voie ni places de parking avant leurs chantiers ; pas de train avant la gare.
  - Voitures : 5, sur l'autoroute seulement, dès le départ.
- **Départ de rien** : quatre pièces (`Layout.STARTER`), quai → grue → parc → gate.
  - Leurs éléments sont marqués `grp` dans PROPS et GROUNDS. Tant qu'une pièce est en friche, rien d'elle n'est créé : on
    voit l'estacade ruinée, des rochers et des broussailles.
  - Toute case à terre pas encore achetée montre son état d'avant (`Layout.before_state`).
  - Pas de musoir sur un quai pas encore construit.
  - Une partie chargée, de test ou de capture commence tout bâtie. Le départ ne se joue que pour une partie neuve
    (`GameState.start_pending` ; `auto_start` coupé par `ui_smoke` ; captures : `--start`, `--skip-intro`).
- **Golfe et forêt** :
  - rives du golfe et arrière-pays hors du plan coté (`Layout.gulf_polys`, pas dans `land_polys`) ;
  - rive d'en face voilée de brume (matériau vcol + `flash`) ;
  - forêt ≈ 400 blocs en MultiMesh par carrés de 120 u ;
  - routes sous les arbres aux points où le trafic se perd ;
  - collines-tunnels supprimées ;
  - bornes de la caméra : z −150 au nord, zoom le plus large 130 (190 avant).
- **Intro** : trois cartes de la narratrice dans `tiers.json`, palier 0 « La Crique » (`intro`), passées d'un toucher.
  Montrées une fois (`Settings.intro_seen`, jamais écrit par une partie `--fresh`).
- Limites :
  - la rive d'en face ne se voit qu'au zoom le plus large, près de la borne nord. Plus près, elle couperait les places
    du mouillage au-delà de 25 places ;
  - les blocs de forêt profonde, agrandis ×2,2, font de très grands arbres de près (corrigé au lot F3) ;
  - le remorqueur du premier navire part de sa base au moment où le navire naît.

## Acte 0 « La Crique » (lot F3) — 15/10 (ordre `docs/ORDRE_F2_F3.md`, journal `JOURNAL_PLAN_BAIE.md` § « Lot F3 »)
- **La pêche est un module léger possédé par la simulation** (`sim/fishing.gd`, `PortSim.fishing`, données
  `config.json` › `fishing`), pas un palier 0 : `PortSim.tier` reste borné à 1–3.
  - Pendant l'acte 0 (`fishing.act0`), le port à conteneurs est fermé : `step` n'avance que la pêche et les seaux de revenu ;
    `PortSim.time` (l'horloge du port) ne tourne pas — tout le T1 et la sonde se mesurent depuis l'entrée au T1.
  - `PortSim.new()` : port ouvert, pas de pêche (tests). Une partie neuve jouée appelle `begin_act0()` (0 $), la bascule finit
    par `open_port()`. Rien ne se bâtit au port pendant l'acte 0.
- **Cinq achats** sur la carte AMÉLIORER (pas d'écran nouveau) : réparer le ponton (0 $), deuxième ponton (25 $), criée (60 $,
  ventes ×2), quai des chalutiers (120 $, 2 chalutiers ×4), fabrique de glace (200 $, un thonier ×10). Loyer 0,04 $/s par
  place + vente à chaque débarque (±10 %, tirage à part du port). **Geste manuel** : toucher un bateau qui rentre (ou qui
  débarque) — il débarque tout de suite, vente ×1,2. Aucun responsable, aucun aléa, pas de Commerce pendant l'acte 0.
- **Bascule** quand les cinq achats sont faits et l'argent ≥ 300 $ (`act0_ready`) : le caboteur de Corsaire & Fils (l'escale
  initiale de la simulation, toujours de Corsaire au T1) naît au large, hors champ, et attend à l'entrée du chenal si le quai
  n'est pas fini (`ShipView.hold_d`) ; narratrice (`tiers.json` › palier 0 › `bascule`), cérémonie « Palier 1 — Le Vieux
  Quai », chantiers du T1 **qui se chevauchent** (`Diorama.T1_STAGGER`, ≈ 12 s en tout), **HUD visible et pêche qui rapporte**
  ; le port ouvre au glissement du premier navire (mécanisme F2). Mesuré : séquence 12 s, escale/écran 7,4 s, aucune fenêtre
  sans action possible.
- **Après l'acte 0** : revenu fixe **0,5 $/s** (≈ 1/12 du revenu de la fin de l'acte, 6,2 $/s : 1 $/s et plus accéléraient le
  T1 hors tolérance), dans le revenu du HUD et Gestion › Stats (« Pêche de l'anse ») ; plus de carte ni de coup de main ; les
  bateaux vivent dans l'anse à tous les paliers (7 au plus). Hors-ligne : la pêche continue (acte 0 : rendement de base).
- **Durée** (bot) : 3 min 41–3 min 46 sur les 4 graines ; sans aucun coup de main 4 min 47–4 min 54. Progression depuis l'entrée
  au T1 : T2 −1,6 %, T3 +0,9 %, fin −1,8 % en moyenne (chaque graine dans ±15 %).
- **Sauvegarde v6** : clé `act0` (`Fishing.to_dict`). Absente = partie d'avant F3 : acte 0 fait, cinq achats, pêche passive,
  aucun chantier rejoué. Une partie enregistrée pendant l'acte 0 reprend dans l'anse (sans cartes d'intro). Nouvelle concession :
  la pêche est reprise, pas d'acte 0, la bascule se joue port fermé (`hold_port`).
- **L'anse des pêcheurs** (`FishingView`, `Layout` « Lot F3 », `PLAN_COTE.md` § 5 ter) : cabane d'Odette, ponton pourri (état
  d'avant), pontons le long de la plage, quai des chalutiers le long du cap, criée à l'est des pontons (vue du sud-est, elle ne
  les cache pas) et sa route jusqu'à la rue du village, fabrique de glace sur le cap. Bateaux sur une **boucle à sens
  unique** (voie ouest → plage → voie est), position déduite de la phase de la simulation et interpolée entre deux pas,
  rampes de 2 s, glissement latéral lent à la place, jamais de rotation sur place, ≤ 6 u/s ; ≥ 40 u du mouillage et de
  l'arrivée des cargos, ≥ 60 u du chenal. Caisses `crate_fish` à la débarque ; camionnette du mareyeur qui part sous les arbres.
- **Bateaux de décor** : les deux `fishing_boat` de la crique du vieux port et ses caisses de poisson sont **retirés** (ils
  contredisaient l'acte 0 : la flottille vit dans l'anse) ; le « pêcheur du musoir » devient un docker (même modèle).
- **Tutoriel** (version 6) : trois étapes en tête (réparer le ponton sur AMÉLIORER, toucher une barque qui rentre, la criée),
  puis « Bienvenue » à l'ouverture du port ; une progression enregistrée avant F3 se retrouve (`REV5_ORDER`).
- **Forêt profonde** : blocs ×0,92–1,05 (au lieu de ×2–2,4) au pas de 21 u, ≈ 1,3 × les arbres du village ; 673 blocs ;
  carrés profonds sans ombre ; triangles dessinés au zoom le plus large identiques à F2 (LOD du modèle).
- Captures de débogage (binaire de l'éditeur) : `--start --skip-intro --act0=N [--act0-warm=S] [--bascule]`.

## Lot G — modèles de la Crique complète, de la marina, des nuages et du terre-plein — 15/10 (ordre `docs/ORDRE_BLENDER_G.md`, expert Blender)
- **19 nouveaux modèles**, aucun `.glb` existant modifié, palette inchangée, rien touché hors `blender/`, `docs/previews/`,
  `godot/assets/models/` (nouveaux `.glb` + leurs entrées dans `assets_meta.json`) et cette section. Code : `blender/parts/marina.py`
  (crique et marina, registre B), `nuages.py`, `terreplein.py` (registre C), branchés dans `build_assets.py` (`MODULES`, budgets nom
  par nom dans `EXACT`, tous respectés, 9 346 triangles en tout). Planches : `docs/previews/g_crique.png`, `g_nuages.png`,
  `g_terreplein.png`, `g_budget.png` (tableau des triangles), faites par le nouveau `blender/preview_g.py` (scènes avec eau, sable,
  friche, caméra du jeu à 35°) sur `preview_lib.py` (matériau ISM de `preview_style.py`, chargement, cadrage) ;
  `build_assets_budget.py` relit les budgets sans construire.
- **Crique (B)** : `fuel_pump` 344 tris (borne rouge à goutte blanche, tuyau enroulé, auvent rouge-blanc), `wash_bay` 1 120
  (dalle 6 × 4,2, portique bleu à 4 jets, flaque, brosses bleu / jaune), `pier_long` 1 452 (14 × 2,5 sur X, tablier à `deck_z` 0,9
  sur pieux béton, origine à la flottaison ; pneus et bittes à chapeau jaune côté **+Y** = `moor_side`, garde-corps côté −Y,
  lampadaire ×1,35 en bout +X, `lamp` en repère Godot), `marina_pontoon` 576 (10 × 1,8 sur X, plancher à 0,45, 4 catways par côté
  en `catway_x` / `catway_y`, 6 places `berths` entre les catways, bateau perpendiculaire au ponton ; bornes eau / électricité
  bleu-blanc), `sailboat_a` 496 (3,5 u, blanc à liston bleu) et `sailboat_b` 496 (4,5 u, rouge falun), `yacht_small` 576 (5 u,
  flybridge), `marcel` 384 (gabarit `docker` 1,35 u, ciré jaune, bras croisés, casquette, pipe, face +X), `ship_passing` 524 (coque
  de `ship_coaster` simplifiée, 9 conteneurs fixes sur le pont, pavillon noir et or de Corsaire à la poupe ; même origine et étrave
  +X, pas de slots : le jeu ne pose rien dessus). Bateaux : origine à la flottaison, étrave +X, comme au lot F.
- **Nuages** : `cloud_bank` 504 tris (exactement 24 × 12 × 6, origine au centre de la face du dessous) et `cloud_puff` 162
  (8 × 5 × 4). Un seul maillage fermé par nuage : champ de hauteur en grappe de dômes, bord rabattu à z = 0 sur le contour, **une
  face plate dessous, aucune face intérieure** ; **couleur de sommet uniforme** `white` (le grisé du dessous vient de l'ombrage par
  face du shader, pas de la couleur). Le fondu / la montée sont à faire par le shader du développeur ; `vcol` noté dans le méta.
- **Terre-plein (C)** : `ground_platform` 184 tris (8 × 8, dessus en z = 0 comme les dalles de `terrain.py`, deux couches de
  remblai sur les bords, ornières de chenilles, quatre rochers dans l'emprise), `quay_small` 1 120 (16 × 6, dessus en z = 0, mer en
  +Y, béton neuf à joints, 4 bittes ×1,35 à chapeau jaune, 4 défenses, échelle, bande jaune-noir côté terre, **pas de rails**),
  `track_dirt` 152 (plaque 8 × 4 sur X, 0,04 d'épaisseur, posée sur n'importe quel sol ; bords herbeux) et `track_dirt_turn` 172
  (8 × 8, entre par −X, sort par +Y ; les autres virages par rotation), `barrier_post` 364, `coaster_crane` 408,
  `container_wait` / `container_ok` 156 chacun (gabarit `container20`, corps blanc à montants et nervures gris, étiquette orange /
  verte sur le dessus, la face −Y et la face +X ; couleurs fixes, pas de teinte par le jeu).
- **Nœuds nommés** (axes en repère Godot dans `assets_meta.json` → `nodes`, comme au lot F) :
  `barrier_post` = `base` + **`arm`** (pivot (−2,4 ; 1,1 ; 0), bras de 5 u vers +X, `rotation.z` > 0 lève, 0 → 80°) ; la piste passe
  sous le bras selon Y (`gate_x` = ±2,1) ; `coaster_crane` = `base` (socle 2 × 2 + mât, origine = dessous du socle, à poser sur le
  pont : `deck_pos_on_coaster` = (7,4 ; 1,65 ; 0) en repère Godot, à l'avant de la cale) > **`boom`** (pivot (0 ; 3,4 ; 0), flèche de 8 u
  vers +X local, **exportée relevée de 30°** : `rotation.z` lève, `rotation.y` oriente autour du mât) > **`hook`** (en bout de flèche,
  exporté avec la rotation inverse pour garder le câble vertical ; descendre = `position.y` locale, câble de 3 u) ;
  `sailboat_a` / `sailboat_b` = `<nom>_hull` + **`mast`** (pivot au pied du mât, `mast_foot` ; bôme, voile ferlée, étais et girouette
  suivent le mât : `rotation.z` ±3° pour le roulis). Les planches montrent la grue tournée vers le quai, conteneur au crochet.
- **Non fait / limites** : `far_shore` laissé au lot F4 comme demandé. Les planches sont des mises en scène Blender (eau plate,
  terre à +0,5), pas des captures du jeu : Godot n'a pas été lancé (pas de `.import` pour les 19 `.glb`, premier lancement à faire
  côté développeur). Les sols `ground_platform` et `track_*` n'ont pas de raccord en pente entre la plateforme (z = 0) et la friche
  plus basse : à régler par le placement (ou une rampe si besoin). `ship_passing` est fixe (conteneurs modelés) : ne pas le teinter
  par armateur. `marina_pontoon` est au ras de son budget (576 / 600) : plus d'anneaux ou de taquets n'y tiennent pas.

## Chapitre 1 « La Crique » (lot G1) — 15/10 (ordre `docs/ORDRE_G1_CRIQUE.md`, cadrage `docs/CADRAGE_DEBUT.md`, journal `JOURNAL_PLAN_BAIE.md` § « Lot G1 »)
- **La pêche reste un module léger de la simulation** (`sim/fishing.gd`, `config.json › fishing`), réécrit : deux cartes à niveaux
  (**Places au ponton** 0–8 : une barque par place, niveau 1 = la réparation gratuite et 2 barques ; **Services à quai** 0–10 :
  `ticket = 1 + 0,10 × niveau`, paliers nommés aux niveaux 1 criée, 3 pompe, 6 lavage, 9 glace, qui coûtent ×3 et bâtissent),
  des bâtiments dans l'ordre (quai des chalutiers 50 $, grande jetée 90 $, marina 150 $, extensions 180 et 240 $) et la
  **Concession du terre-plein** (1 000 $ au lot G1, **500 $ depuis G1-d**, dès la marina) qui remplace le seuil d'argent de F3
  (`switch_money` disparaît).
- **Argent = loyer par escale** : un bateau rentré paie `valeur(classe) × ticket` (barque 5 $, chalutier ×3, thonier ×10, ±10 %).
  Sans Marcel, le joueur **touche** le bateau (bulle « Loyer », pièces vers le compteur) ; sinon il attend 20 s (bulle rouge sous
  6 s) et **repart sans payer**. La marina paie 0,05 $/s par voilier (6 → 12 → 20). Le coup de main ×1,2 de F3 disparaît.
- **Marcel** (patron pêcheur, 40 $) se présente après 16 loyers encaissés à la main (12 au lot G1) ; embauché, plus aucun geste ni
  bulle, il encaisse tout. **G1-d : il ne révèle plus les Heures sup** (ce sera le premier responsable du port, lot G2 ; rien de
  visible ni d'actif avant le port ; le minuteur des Heures sup reste sur `PortSim.clock()`, les loyers suivraient le ×2). Responsable hors département : compteur `managers` (mission « premier responsable »),
  feuille RESPONSABLES (seul onglet de Gestion pendant la Crique), sauvegarde ; `managers_count()` du rendement hors-ligne ne le
  compte pas.
- **Hors-ligne** : avant Marcel, le monde se fige (rapport vide, rien gagné, rien perdu) ; avec Marcel, la pêche rapporte à son
  rythme estimé ; après la Concession, idem pour la part pêche (le port garde son rendement de base + responsables).
- **Plafond R₀ = 4,2 $/s** (bas de la fourchette 4–6 du cadrage, pour limiter l'avance du T1) tout au maximum (9 barques, 2 chalutiers, 1 thonier, 20 voiliers, ticket ×2) ; ticket additif (+10 %)
  et non multiplicatif (+15 % composé aurait mis R₀ hors de 4–6 avec les valeurs qui tiennent le début) ; la pêche continue
  pour toujours, les cartes restantes restent achetables en bas d'AMÉLIORER (titre « La Crique »).
- **Chronologie mesurée** (bot, 4 graines) : tranquille **19 min 20–19 min 34** (plafond puis Concession) ; **pressé 19 min 30–20 min
  (cible ≤ 12 non tenue)** : la Concession vaut 4 min de R₀, mais un joueur pressé n'a que ≈ 2,4 $/s à la marina (≈ 12 min au plus
  tôt) ; 12 min demanderait une Concession ≈ 400 $ ou un R₀ bien plus haut (qui accélère le T1). À trancher par le chef de projet.
- **Progression depuis la Concession** (4 graines, base F3 mesurée depuis l'entrée au T1) : T2 **−12 %** en moyenne (g3 −22 %),
  T3 −0,7 %, fin −3 %. L'avance du T2 vient surtout des **Heures sup révélées dès Marcel** (cadrage § 8.1), donc jouées au T1 par le
  bot : sans Heures sup, T2 −3,2 % (g1) et −5,8 % (g3) ; le reste vient de R₀ (4,2 $/s au lieu de 0,5 $/s passif). Hors tolérance
  ±5 % : à trancher (Heures sup actives sur le port dès le T2 seulement, ou tolérance recalée).
- **Annonce du port** : `clock ≥ 480 s`, criée faite, ≥ 45 s après Marcel → le caboteur `ship_passing` traverse au large (trou des
  nuages), carte de la narratrice (`tiers.json › 0 › announce`), **Missions** révélé, mission `c0` « Signer la Concession du
  terre-plein » (clé `fish` de `missions.json`) en tête de liste, accomplie à la Concession. Une partie sans Crique (tests,
  parties d'avant F3) ne montre pas cette mission.
- **Nuages** (`CloudLayer`, modèles `cloud_bank` / `cloud_puff` en MultiMesh ; repli procédural — demi-sphères sur dalle — si absents) sur tout le rectangle habillé sauf le trou de l'anse (`Layout.CLOUD_HOLE`), dérive lente, **dissolution par shader**
  (fondu + montée 3,5 s) **avant** la bascule : puis les bornes de la caméra s'élargissent, le caboteur revient, narratrice,
  cérémonie, chantiers du T1 (inchangés : lot G2). Jamais recréés ; posés dès que la Crique commence (`Diorama._ensure_clouds`).
- **Caméra** bornée à l'anse pendant la Crique (`CameraRig.set_crique_bounds`, zoom ≤ 72) ; cadrage d'intro recalé.
- **Monde** : un seul ponton des places qui s'allonge (modules aux niveaux 3, 4, 6, 7 : la plage fait 36 u, un module de 6 u par
  niveau n'y tient pas — un taquet et un chantier par place), 9 places au pas de 4 u, voie ouest en x −146 ; grande jetée le
  long du cap (thonier étrave au nord, voie est prolongée) ; marina dans l'intérieur de la boucle. Plan coté § 5 ter.
- **Sauvegarde v7** (`act0` au nouveau format) : v6 en cours d'acte 0 → la Crique recommence (0 $) ; v6 au T1+ → Crique finie
  (plafond, Marcel, Concession, Heures sup décalées de `act0_time`). Nouvelle concession : pêche reprise au plafond.
- **Tutoriel version 7** : ponton → loyer → places → criée → Marcel → mission → Concession, puis la suite d'avant (`REV6_ORDER`).
- **Modèles** : les 19 modèles du lot G ont été livrés pendant le lot et sont utilisés ; chargeur tolérant (`FishingView._model`,
  `CloudLayer._build`) avec primitives Godot en repli (`_prim`) si un modèle manque.
- Captures de débogage (binaire de l'éditeur) : `--places=N --services=N --fish-build=a,b --marcel[=offer] --announce --act0-warm=S
  --rent --bascule`.

## Chapitre 1 « La Crique » — corrections G1-d — 15/10 (arbitrages du chef de projet, journal § « Lot G1 › G1-d »)
- **Heures sup** : plus révélées par Marcel ; elles le seront par le premier responsable du port (Léon, lot G2). Rien de visible ni
  d'actif pendant la Crique (l'unlock reste « palier 2 » jusqu'à G2 ; minuteur sur `clock()` conservé). Une seule révélation à la fois.
- **Concession du terre-plein : 500 $** (1 000 au lot G1 ; 600 ne suffisait pas : pressé 15 min 10). Mesure : pressé 14 min 51–57
  (cible recalée par le chef de projet : **pressé ≤ 15 min** ; 400 $ tiendrait 14 min), tranquille 16 min 58–17 min 10 (cible 15–20). La Concession reste de
  loin l'achat le plus cher de la Crique (extension 2 : 240 $).
- **Marcel** se présente après **16 loyers** à la main : 4 min 49–5 min 08 sur les 4 graines (objectif de la première session).
- **Nuages opaques** : nappe blanche continue à y 6,5 sous les bancs (`CloudLayer._build_sheet`), découpée au bord du trou,
  dissoute avec les bancs. Plus rien ne se voit entre les nuages, à tous les zooms.
- **Sonde depuis la Concession** (4 graines) : T2 **−2,5 %** en moyenne (g4 −14,6 %, g2 +9 %), T3 −1,7 %, fin −0,3 % (g3 +16 %) :
  dans la tolérance sans autre changement de l'économie du port — l'avance du T2 du lot G1 venait bien des Heures sup jouées au T1.

## Chapitre 2 « Le Terre-plein » (lot G2) — 15/10 (ordre `docs/ORDRE_G2_TERREPLEIN.md`, cadrage `docs/CADRAGE_DEBUT.md` § 4, 6, 7, 11, 12, journal § « Lot G2 »)
- **Deux régimes** : `PortSim.new` = port complet (tests, parties d'avant G2 : les six pièces du départ bâties d'office, règles
  `legacy` de `unlocks.json`) ; partie jouée (Crique puis Concession, nouvelle concession) = `g2` : la friche nue, le processus
  à la main. Sauvegarde **v8** (clé `g2`).
- **Plus de séquence de chantiers** à la Concession : six bâtiments, un seul achat proposé à la fois en tête d'AMÉLIORER —
  Terrassement **240 $**, Quai n°1 **310 $**, Cabane de douane **190 $**, Piste et barrière **250 $**, Grue mobile **60 $**,
  Parc de stockage **80 $** —, puis les bâtiments du T1 d'avant (le Bureau de douane remplace la cabane). La bascule : nuages,
  narratrice, cérémonie, **puis** le port ouvre (jamais pendant la dissolution).
- **Gestes** (un responsable **remplace** le geste) : accoster (toucher le navire ; aucun accostage automatique sans Léon ni
  Mathilde), décharger avec la **grue de bord** du caboteur (0,125 conteneur/s) tant qu'il n'y a pas de grue mobile, tamponner
  (toucher la cabane dédouane tout le lot), laisser passer **et encaisser** (toucher la barrière : un camion de 2 conteneurs
  charge, paie sa part et part ; non servi, il repart à vide après 20 s, bulle rouge 6 s avant). Coup de main grue, engin et
  barrière express retirés.
- **Responsables** Léon (50 $), Paul (60 $, passé du T2 au T1), Tonio (80 $) : après 5 gestes, un à la fois, à ≥ 45 s de toute
  nouveauté, et **avant** les révélations ordinaires. Bulle à leur poste + carte de la narratrice. Embauche = carte du service.
  Le premier révèle Heures sup (≈ 1 min après, file des révélations). Avant le premier responsable du port, le port se fige
  hors-ligne (seule la pêche de Marcel rapporte).
- **Cartes de service** : Accostage, Douane, Sortie camions à l'embauche ; Déchargement avec la grue mobile, Stockage avec le
  parc, Arrivées avec le quai n°2 (sans carte « à venir »). Ordre : Arrivées · Accostage · Déchargement · Douane · Stockage ·
  Sortie camions. Noms de métier ; « EVP » et « gate » chassés des textes du T1. La barre de palier paraît avec la première
  carte de service (sans bandeau).
- **Économie du T1 recalée** pour tenir le T2 malgré ≈ 4 min de processus à la main : `value_mult`/`dues_mult` du T1 1,8 → 2,2 ;
  palier T2 : 4 500 conteneurs (8 500) et 11 000 $ (14 000). Mesure (4 graines, depuis la Concession) : premier camion 4 min 08–
  4 min 18, T2 12:49 en moyenne (+3,4 %), T3 +1,0 %, fin +2,6 % (graine 2 +19 %). Grue mobile et parc à ≈ 4 min 25 (cible
  8–12 non tenue : plus chers, ils repoussent le T2 de 1 à 2 min).
- **Rendu** : MultiMesh teintés avec `use_colors` (blanc) en plus de `custom_data` — en OpenGL (repli sans Vulkan) ils étaient
  noirs.
- Tutoriel **version 9** (bienvenue, terrassement, quai, accoster, cabane, tamponner, piste, laisser passer, grue mobile, parc,
  puis la suite). Contrôle « bandeaux autour du T2 » mesuré sur la partie jouée, plafond 8 (le dégraissage G3 doit le ramener à 4).

## Lot H1 « La Crique : services sur l'eau, anneau de service, pêche et plaisance séparées » — 16/10 (ordre `docs/ORDRE_H1_CRIQUE.md`, retour de l'utilisateur points 2, 4, 5, journal § « Lot H1 »)
- **Services sur l'eau** (point 2) : la pompe à carburant et l'aire de lavage sont posées sur un **ponton de service flottant**
  (radeau de 3 × 5 modules `pontoon`, 4,8 × 30 u), amarré au flanc est d'une jetée, à l'ouest de l'anse, au bord de la voie
  ouest par laquelle tous les bateaux rentrent ; plus rien sur l'herbe. La criée reste à terre (inchangée) ; la fabrique de
  glace reste à terre, déplacée **au pied de la passerelle** du ponton de service (le cap n'en a plus). Le palier nommé niv. 3
  s'appelle « Ponton carburant » et bâtit la jetée, le radeau et la pompe.
- **L'anneau du service** (point 4) : dès la pompe, un bateau qui rentre passe aux stations bâties dans l'ordre carburant →
  lavage → glace, s'amarre (glissement latéral, étrave au sud), un **anneau** coloré (icône carburant, bulles, flocon) se remplit
  au-dessus de la station, puis éclate en « +X $ » (pièces vers le compteur, son) : le service est **payé à la fin** (valeur du
  bateau × 0,2 : 1 $ par barque, 3 $ par chalutier, 10 $ par thonier ; Heures sup comprises), puis le bateau gagne sa place (loyer
  à la criée, inchangé). **Chaque niveau de Services raccourcit le service** : 5 s au niveau 3, ×0,88 par niveau, 2 s au plus
  court (niveau 10) ; la carte Services l'affiche (« service 5 s → 4,4 s »). Les paliers nommés restent (1, 3, 6, 9).
- **File simple** : une station sert un bateau à la fois (occupée ou réservée) ; au point de décision (−146 ; 14), première
  station libre, sinon le **poste d'attente** (un bateau, au nord du radeau), sinon le bateau passe son tour et rentre à sa
  place ; un bateau ne quitte son coin de pêche vers le ponton que si la file a de la place (au plus 3 bateaux engagés), sinon
  il rentre droit (aucun détour). Pas de 2ᵉ poste : la vitesse du service suffit (Crique tranquille : 143–159 services, 0 à 2
  tours passés ; pire cas du contrôle, pleine flotte au niveau 3 : 6 tours passés pour 61 services en 10 min). Sans station (Services < 3), le cycle est exactement celui de G1.
- **Pêche et plaisance séparées** (point 5) : la **jetée de séparation** (4 segments `breakwater`, sans feu vert, x −157,2,
  z −4 → 46) coupe l'anse ; à l'est la pêche (barques, chalutiers, thonier, criée, ponton de service, glace), à l'ouest la
  **marina** (3 modules déplacés : (−166,1 ; 15), (−166,1 ; 4), (−178,1 ; −6)), que la boucle de pêche ne croise jamais ; elle
  reste un revenu passif.
- **Caméra de la Crique** : bornes élargies vers l'ouest et le nord (centre x −146…−104, z 10…46).
- **Économie** : le service allonge le cycle d'un bateau ; son prix le compense (`stations.fee` 0,2, durées de trajet en
  configuration). Crique (4 graines) : Marcel inchangé (5 min 08, 4 min 49), tranquille 17 min 32–17 min 44 (avant 16 min 58–
  17 min 10), pressé 14 min 51–14 min 59 (avant 14 min 51–14 min 57) ; R₀ estimé 4,3 $/s (4,2). Sonde depuis la Concession :
  T2 −3,7 %, T3 −2,2 %, fin +3,1 % en moyenne (chaque graine dans ±15 %).
- **Sauvegarde v9** (`act0.v` = 9 : stations occupées, poste d'attente, état des bateaux aux stations, compteurs) ; une partie
  v7/v8 se charge sans perte (stations libres).
- Modèles : aucun nouveau (Blender exclu) ; la jetée réutilise `breakwater` (matériau sans vert), le radeau `pontoon` ; nouvelle
  icône `wash.svg` (bulles) pour l'anneau du lavage.
