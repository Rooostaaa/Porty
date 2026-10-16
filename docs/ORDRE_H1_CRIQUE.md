# Ordre de travail — lot H1 « La Crique : services sur l'eau, anneau de service, pêche et plaisance séparées » (16/10/2026)

> Rédigé par le développeur senior Godot avant le code, d'après le retour de l'utilisateur (points 2, 4 et 5) transmis par le
> chef de projet. Base : lot G2 + corrections de revue (`run_all` 247, `ui_smoke` 181). Journal : `JOURNAL_PLAN_BAIE.md`
> § « Lot H1 ». Pas de Blender : modèles existants ou primitives propres. On ne touche ni aux nuages (`cloud_layer.gd`) ni au
> plan du terminal à conteneurs (autres maquettes en cours).

## Ce que je fais
1. **Point 2 — services sur l'eau.** La pompe à carburant et l'aire de lavage quittent l'herbe : elles sont posées sur un
   **ponton de service flottant** (radeau de 3 modules `pontoon` de large, 30 u de long), amarré le long d'une jetée, à l'ouest de
   l'anse, au bord de la voie ouest par laquelle **tous** les bateaux rentrent. Les bateaux s'y amarrent du côté de la voie.
   La criée reste à terre (inchangée) ; la **fabrique de glace** reste à terre, déplacée au pied du ponton de service (sur la
   plage, au bout de la passerelle) : son poste de glace est le dernier du ponton.
2. **Point 4 — l'anneau du service.** Quand un bateau rentre et qu'au moins une station existe (Services niv. 3 et plus), il
   passe aux stations dans l'ordre carburant → lavage → glace (celles qui sont bâties), s'amarre, un **anneau se remplit
   au-dessus de la station** pendant le service, puis éclate en « +X $ » (pièces vers le compteur, son). Puis il gagne sa
   place (loyer à la criée, comme avant). **Chaque niveau de Services raccourcit le service** (6 s au niveau 3, ×0,88 par
   niveau, ≈ 2,5 s au niveau 10) ; les paliers nommés restent (criée 1, pompe 3, lavage 6, glace 9).
3. **Point 5 — ne pas mélanger.** Côté **pêche** (est de la jetée) : barques, chalutiers, thonier, criée, ponton de service,
   glace. Côté **plaisance** (ouest de la jetée, de l'autre côté de l'anse) : la marina et ses voiliers, qui ne croisent jamais
   la boucle des bateaux de pêche ; la marina reste un revenu passif. La **jetée** (4 segments `breakwater`, sans feu vert)
   sépare les deux.

## Plan des emplacements (x, z ; détails dans `PLAN_COTE.md` § 5 ter)
| Élément | Avant (G1) | H1 |
|---|---|---|
| Jetée de séparation | — | `breakwater` ×4, axe z, centre x −157,2, z −5 → 45 (racine sur la plage ouest) |
| Ponton de service (radeau) | — | x −155,2 … −150,4, z 14 → 44 (3 × 5 modules `pontoon`) ; passerelle x −151,2, z 44,6 → 50,6 |
| Pompe `fuel_pump` | (−107 ; 54), sur l'herbe | sur le radeau, poste carburant z 23 |
| Lavage `wash_bay` | (−118 ; 59,5), sur l'herbe | sur le radeau (axe z), poste lavage z 31 |
| Glace `ice_plant` | (−88,5 ; 28) sur le cap | à terre au pied de la passerelle (−151 ; 58) ; poste glace z 39 |
| Postes des bateaux | — | à l'est du radeau : x −149,7 (barque), −149,1 (chalutier), −148,8 (thonier) |
| Attente (file) | — | même ligne, z 14 (au nord du radeau, hors de la voie) |
| Point de décision | — | voie ouest (−146 ; 14) |
| Marina (3 modules) | x −125/−113, dans la boucle | à l'ouest de la jetée : (−166,1 ; 15), (−166,1 ; 4), (−178,1 ; −6) |
| Voie ouest, places, chalutiers, jetée du thonier, criée | — | inchangés |

## Modèle de simulation du service chronométré (`sim/fishing.gd`, `config.json › fishing.stations`)
- Nouvelles phases : `QUEUE` (attente au poste d'attente), `SERVE` (au poste), `MOVE` (d'un nœud à l'autre), `DOCK` (vers la
  place). Sans station (Services < 3), le cycle est **exactement** celui de G1 (retour direct à la place).
- Avec stations : `BACK` mène au point de décision `g`. Là : première station libre → `MOVE` vers elle ; sinon, poste
  d'attente libre → `MOVE` vers l'attente puis `QUEUE` ; sinon le bateau **passe son tour** (`DOCK` direct, pas de service).
  Une station sert **un bateau à la fois** (occupée ou réservée). Fin de `SERVE` : le service est **payé** (montant =
  `valeur × fee × ticket`, Heures sup comprises), puis station suivante si elle est libre (sinon il garde son poste), ou `DOCK`.
- Durée du service : `max(min, dur × decay^(services − 3))`. Les durées de trajet (`back_g`, `dock`, `approach`, `move`…)
  sont en configuration, vitesse ≤ 6 u/s vérifiée par `run_all`.
- `rate_estimate()` compte le temps passé aux stations et les services payés ; R₀ et la chronologie de la Crique sont recalés
  par `fee` (Marcel 4 min 49–5 min 08, tranquille 15–20 min, pressé ≤ 15 min ; sonde depuis la Concession ±5 %).
- **Sauvegarde v9** (`act0.v` = 9) : état des stations (`occ`, `hold`) et des bateaux (`via`, `at`, `to`, `done`). Une
  sauvegarde v7/v8 se charge sans perte (bateaux dans les anciennes phases, stations libres).

## Risques
- **Économie** : le service allonge le cycle d'un bateau (≈ +14 s au maximum) ; le montant du service doit compenser sans
  sortir R₀ de 4–6 $/s ni bouger la sonde du port. Mesure avant/après, 4 graines.
- **File** : à bas niveau (6 s de service), l'arrivée des barques peut saturer la pompe ; le bateau en trop passe son tour
  (jamais d'embouteillage visible), et l'amélioration réduit les tours passés.
- **Place** : la jetée, le radeau et la marina se partagent la rive ouest de l'anse ; contrôles « ni terre ni ouvrage » étendus
  aux nouveaux trajets, et voiliers sur l'eau.
- Tests `ui_smoke` de l'anse sensibles à la charge : lancés seuls.
