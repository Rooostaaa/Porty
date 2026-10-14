# Ordre de mission — lot D-UI : interface, achat sur le port vivant, retours (14/10/2026)

> Pour le sous-agent **développeur senior Godot, piste UI**. Source : `docs/REVUE_CRITIQUE_PORT.md` (axe 2 et partie « interface » de
> l'axe 3), validée en bloc par l'utilisateur. Sauvegarde faite : `tycoon_backups\V2_avant_lot_D_20261014.zip`.
> **Une autre piste (D-Monde) travaille en même temps** sur le monde : lis la section « Coordination ».
> Captures de référence de la revue : `C:\Users\BEDJAO~1\AppData\Local\Temp\claude\C--Nadir-tycoon\8da43a4f-210d-4b6d-8673-65d93348718b\scratchpad\ux\u1…u8_*.png`.

## Règles (impératives)
- Seul projet : `C:\Nadir\tycoon_V2`. Ne jamais toucher `C:\Nadir\tycoon`. **Aucun commit, aucun push.** Ne pas modifier `blender/`.
- Godot : `C:\Nadir\Godot\Godot.exe`, PowerShell `Start-Process … -PassThru -NoNewWindow -RedirectStandardOutput … -RedirectStandardError …`
  puis `.WaitForExit()` (pas de pipes ; pas `$p` et `$P` dans le même script).
- Tests : `run_all` (178, `--script res://tests/run_all.gd`), `ui_smoke` (99, scène `res://tests/ui_smoke.tscn`). **Aucun contrôle
  retiré** ; recaler un contrôle se note au journal ; ajoute des contrôles.
- **Pas de changement d'équilibrage** dans cette piste (une autre piste D-Éco le fera après). Tu peux changer des **textes** de
  `port_sim.gd` / `data/*.json` (libellés, conseils), pas des valeurs ni la logique de simulation.
- Captures `--fresh` uniquement, une à la fois ; sauvegardes de bot via `--load-sim` pour T2/T3. Après un nouveau `class_name` :
  `--headless --import` avant une capture fenêtrée.
- Mobile portrait 1080 px de large de référence : **texte ≥ 24 px** (26 pour ce qui se lit souvent), **cibles tactiles ≥ 96 px**
  (110–126 pour les actions fréquentes ; on peut agrandir la zone de clic invisible).
- Doc en français : section « Lot D — UI » à la suite de `docs/JOURNAL_PLAN_BAIE.md`, entrée « Interface (lot D) » dans `docs/DECISIONS.md`.

## Coordination avec la piste D-Monde (en parallèle)
- **À toi seule** : `scripts/ui/*` (hud, world_overlay, upgrades_sheet, manage_sheet, commerce_sheet, missions_sheet, sheet, tutorial,
  narrator, fx, ui, bubbles, info…), `autoload/sfx.gd`, `data/tutorial.json`, `scripts/main.gd`.
- **À D-Monde seule** : `scripts/world/*`, shaders. Si tu as besoin d'un changement là-bas, mets-le dans ton rapport final.
- D-Monde fournit dans `diorama.gd` (peut-être pas encore là quand tu commences : appelle-les **avec `has_method` / `has_signal`** et
  garde un repli) : `feedback_purchase(dept_id)`, `set_overtime(on)`, `set_campaign(on)`, `dept_anchor(dept_id) -> Vector3`,
  `rade_anchor() -> Vector3`, signal `ship_paid(world_pos: Vector3, amount: float)`.
- `tests/run_all.gd` et `tests/ui_smoke.gd` sont partagés : tes contrôles **dans de nouvelles fonctions**, relis le fichier juste avant
  chaque modification, ne réordonne rien.
- Captures fenêtrées et export APK : verrou `…\scratchpad\capture.lock` (crée-le avant, attends s'il existe, supprime-le après).

## Phase 1 — Les incohérences de confiance (top 1, bloquants)
- **Débordement des cartes au T3** (`upgrades_sheet.gd:126,128,176`) : retour à la ligne (`UI.wrap_label`) et textes courts
  (« Pas le goulot : pas de gain immédiat »). Contrôle : aucune carte plus large que l'écran au T3 (sauvegarde de bot).
- **« Goulot : parc saturé » vs jauge verte** : renommer le goulot `yard_space` (« Parc trop petit pour ton débit »), étiquette de la
  jauge « Stock 28 % » ; jamais un goulot rouge à côté d'une jauge verte du même service sans explication.
- **Bouton de la carte Goulot** (`hud.gd:894-902`) : actif dès qu'une action résout le goulot (amélioration abordable du service OU
  bâtiment) ; son libellé dit **quoi et combien** (« AMÉLIORER PARC · 12K », « QUAI N°2 · 150K »).
- Même achat, même nom partout (« Terminal » dans le monde = « Quai n°2 » en Gestion) : le nom de zone vient de `layout.gd:95` →
  D-Monde s'en charge ; toi, aligne les textes côté UI et signale le libellé voulu dans ton rapport.

## Phase 2 — Acheter au-dessus du port vivant (top 3, bloquant game feel)
- Améliorer (et si possible Gestion / Commerce) en **feuille basse à mi-hauteur** (55–60 % de l'écran) au-dessus du monde **qui continue
  de vivre** : pas de `fx_paused` pour ces feuilles, surcouche monde utile visible au-dessus, **solde visible** en permanence.
- À l'ouverture et à chaque achat, la caméra cadre le service concerné dans la moitié haute (`dept_anchor`, `rig.focus`) ; à chaque
  achat : `feedback_purchase(dept)` + texte flottant dans le monde (« +6 % » / « +12 $/s »).
- Boutons gris : « Il manque 7K $ ». Mini-solde dans l'en-tête de chaque écran restant plein cadre.
- Améliorer s'ouvre **défilé sur le goulot** (ou le meilleur achat) ; la pastille de comptage ne compte que les achats à gain > 0.

## Phase 3 — Écran respirable (top 5, partie UI)
- **Améliorer = gros bouton en bas à droite** (pastille), Réglages en petit rond dans un coin, Heures sup en bouton rond flottant qui
  n'apparaît que lorsqu'il est prêt (recharge en anneau discret sinon).
- HUD du haut **< 20 % de l'écran** : carte Goulot réduite à une ligne (titre + bouton ; détail au toucher), bandeau missions replié
  par défaut, Responsables intégré à Gestion (pastille). Contrôle ui_smoke : hauteur du chrome du haut au T3 < 20 %.
- Typo ≥ 24 px, cibles ≥ 96 px (« i », ▲, « + », coffre, barre de palier en texte foncé sur ambre).
- **Une seule unité de revenu : $/s** partout (rentabilité convertie).
- « + » de l'Ambre : ouvre une explication « Comment gagner de l'Ambre » (ou retiré).
- Gestion › Bâtiments triée « disponible › bloqué › construit », les construits repliés en « 7 construits ▸ ».
- Bandeaux « Nouveau : … » avec un bouton **VOIR** qui ouvre le bon écran / cadre le bon poste.
- Bulle « n/n en rade » ancrée au mouillage (`rade_anchor()`), « +X $ » qui ne recouvre plus « File : n » (anti-chevauchement des bulles).
- Charte couleur : vert = argent / acheter, bleu = info, ambre = « touche-moi », rouge = problème, gris = impossible seulement
  (RESPONSABLES « à embaucher » n'est plus gris). Icônes distinctes (Capitainerie / Ponton / Dragage ; missions par type).
- Cosmétiques : icône du bandeau non étirée (`SIZE_SHRINK_CENTER`), textes d'aide d'en-tête affichés une fois puis repliés, suppression
  de « Au poste de la capitainerie : deux services », phrase en double de Commerce, progression du coffre dans Missions.

## Phase 4 — Retours et récompenses (axe 3, partie interface et son)
- **Cérémonie de palier** : gerbe plein écran, dézoom sur ce qui s'ouvre, jingle propre au palier, puis la fenêtre. Même traitement
  (adapté) pour le prestige et la fin de partie.
- **Encaissement par événement** : au signal `ship_paid`, gros « +X $ » au poste avec pièces qui volent jusqu'au compteur (le compteur
  pulse en encaissant) ; garder la pluie fine pour la gate seulement. Gestes manuels affichés **en $** (gain calculé avant/après).
- **Pastille après achat même hors goulot** (« Grue +6 % — pas le goulot »).
- Retour d'absence : bouton « Encaisser » avec compteur qui défile.
- **Audio** (`sfx.gd`) : sons distincts build / hire / milestone, « tier » réservé au palier ; `pitch_scale` aléatoire ±4 % ; montée
  d'un demi-ton toutes les 3 répétitions en appui long ; 10 voix avec priorité (corne et palier jamais volés) ; bus « Sons » et
  « Ambiance » avec deux réglages dans Réglages.
- Heures sup / campagne : appeler `set_overtime` / `set_campaign`.

## Fin de piste
1. `run_all` et `ui_smoke` verts (≥ 178 / 99 + les tiens) ; sonde 4 graines inchangée (aucune valeur touchée).
2. Captures regardées (`docs/captures/`, préfixe `d_ui_`) : HUD T1, T2, T3 ; Améliorer à mi-hauteur sur le port ; carte Goulot
   T3 ; Gestion ; cérémonie de palier ; encaissement d'un navire. Compare avec `scratchpad\ux\u*.png`.
3. Journal, DECISIONS. Rapport final : points faits / non faits (raison), chiffres, captures, demandes à D-Monde.
