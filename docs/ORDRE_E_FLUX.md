# Ordre de mission — lot E-Flux (14/10/2026, soir)

> Pour le sous-agent **développeur senior Godot, piste Flux (monde)**. Source : `docs/REVUE_LOT_D.md` (E7–E12 + mineurs monde),
> validée par l'utilisateur. Point de reprise : commit local `3d2caae`. **Une autre piste (E-Confiance) travaille en même temps.**

## Règles (impératives)
- Seul projet : `C:\Nadir\tycoon_V2`. **Aucun commit, aucun push.** Ne pas toucher `C:\Nadir\tycoon` ni `blender/` (modèles existants
  ou primitives Godot).
- Godot : `C:\Nadir\Godot\Godot.exe` via `Start-Process … -PassThru -NoNewWindow -Redirect…`, puis **`WaitForExit(ms)` borné et `Kill()`
  si dépassement** (une graine de sonde par processus).
- Tests : `run_all` (196), `ui_smoke` (131). Aucun contrôle retiré ; recalage noté ; un contrôle par correction quand c'est testable.
- **Simulation et équilibrage inchangés** : sonde 4 graines identique. `Layout` / vues = présentation.
- Captures `--fresh` uniquement, verrou `C:\Users\BEDJAO~1\AppData\Local\Temp\claude\C--Nadir-tycoon\8da43a4f-210d-4b6d-8673-65d93348718b\scratchpad\capture.lock`.
- Doc : section « Lot E — Flux » au journal `docs/JOURNAL_PLAN_BAIE.md`, mise à jour de `docs/PLAN_COTE.md`.

## Coordination avec E-Confiance (en parallèle)
- **À toi** : `scripts/world/*` **sauf** `camera_rig.gd` (layout, diorama, traffic_view, ship_view, yard_view, crane_view), shaders.
- **À E-Confiance** : `scripts/ui/*`, `sfx.gd`, `main.gd`, `camera_rig.gd`, `sim/*`, `data/*.json`. Besoin là-bas → rapport final.
- Tests partagés : nouvelles fonctions `test_e_flux` / `_e_flux_checks`, relire avant d'éditer.

## À faire
- **E7** Camions : cap visé π (voie B vers l'ouest) pendant l'attente au chargement (`traffic_view.gd:293`) ; plus aucun pivot sur place
  (contrôle : écart de cap entre arrivée, attente et départ < 30°).
- **E8** Boucle à vide : demi-tour par groupe de blocs (`truck_route_in(in_x, stop_x)` avec le palier du bloc visé, `tier_for_stop`),
  passages dessinés en x ≈ −2 et 45 ; contrôle : au T3, longueur du trajet d'un camion d'un bloc T1 < 450 u.
- **E9** Passe est à droite : ARRIVE_E_Z = −36, DEPART_E_Z = −29, départ décalé à l'est de la ligne d'arrivée (≈ (200 ; −29) →
  (215 ; −90)) ; plus de croisement arrivée/départ. Croisement de la voie au large (z −108) avec l'approche du chenal ouest : point de
  croisement balisé et règle d'attente (un navire attend si un autre est dans la fenêtre x −45…−15), sans interblocage (départage par id).
  Contrôle : aucune paire de trajets qui se croisent sans règle ; coques ≥ 2 u (contrôle N10 étendu aux croisements).
- **E10** Portique sur les deux voies de sortie quand `gate2` est construit (2ᵉ portique en x −19,5, ou portique large) ; guérite de
  `gate2` sur un îlot cohérent (x ≈ −17) ; descriptions `gate2` / `parking2` à corriger → **demande à E-Confiance** (data) ; tests :
  vérifier la voie 1 de sortie (eau, bâtiments, portique) et la vraie file à une voie d'entrée (`run_all.gd:890-906`).
- **E11** Capitainerie : au T2, toucher la maison bleue **et** la tour ouvre le service, retour d'achat sur les deux ; pavillons de
  campagne sur le bâtiment actif du service (`diorama.gd:1693`).
- **E12** Gare vivante : train visible quand la gare est à l'écran (entrée / sortie par le tunnel, arrêt au quai), navette d'un
  tracteur entre le parc RTG et la gare quand le train est à quai, liaison sans croisement à niveau gênant avec les voies A/B (ou
  passage à niveau signalé). Coin gate/douane : rue des bureaux raccordée derrière la tête de file (z ≥ 60), cibles de toucher Douane /
  barrière / Gate séparées d'au moins 10 u ou rayons ajustés. Optionnel si simple : un camion sur N détourné par l'aire d'inspection.
- **Mineurs monde** : `_ship_cargo0` vidé dans `_on_ship_removed` ; douaniers jamais tronqués par `CROWD_MAX` (réserver leurs places) ;
  `rade_anchor` = place occupée la plus proche du centre (pas le barycentre) ; zone 8 réduite à la voie et aux parkings, en gris
  discret ; zones grises du T1 plus discrètes que le port actif ; gyrophares bleus (pas orange sur grues orange) ; bureau de pilotage
  avec un toit ; crique désencombrée ; sphères de GNL à ≥ 4 u du bout du poste 4, IMO à ≥ 4 u du parc RTG.

## Fin de piste
Tests verts, sonde identique, captures `docs/captures/e_flux_*` regardées (camions au chargement, T3 boucle, passe est avec un navire
qui arrive et un qui part, gate avec gate2 et portiques, gare avec train et navette, capitainerie T2), journal + PLAN_COTE. Rapport :
fait / non fait (raison), chiffres, captures, demandes à E-Confiance.
