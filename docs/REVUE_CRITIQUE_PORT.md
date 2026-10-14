# Revue critique du port — layout, UI/UX, game feel (14/10/2026)

> Revue en lecture seule après le lot C7 (run_all 178, ui_smoke 99). Trois analystes (designer portuaire, UI/UX mobile, game feel)
> recoupés par le chef de projet sur le code et les captures (captures de travail : scratchpad, `ux/u1…u8`).
> **Validée en bloc par l'utilisateur le 14/10 à 9 h (« corrige moi tout »)** → lot D : `ORDRE_D_MONDE.md`, `ORDRE_D_UI.md`, `ORDRE_D_ECO.md`.

## Axe 1 — Layout et logique des infrastructures

Structure saine (bandes mer → quai → tablier → parc → voie camions → gate → route ; croissance ouest → est ; dangereux à la pointe).
Le défaut vient des **annexes** rangées dans le coin sud-ouest « là où il restait de la place ».

| Priorité | Problème | Appui |
|---|---|---|
| Bloquant | Douane collée à la barrière d'**entrée** (camions vides) ; scanner à portique sur la voie d'entrée ; scanner mobile, e-douane, halle hors de l'enceinte | `layout.gd` customs1 (−31;41), scanner2 (−22,5;53), ROAD_IN_X, gate z 43–45 |
| Bloquant | Service Capitainerie qui saute à la tour (−58;38), à 84 u de la passe, hors champ ; atelier naval (−58;52) sans eau ; `rpilot` dans les terres | `dept_pos("harbor")`, CONTROL_TOWER, LOTS repair/rpilot |
| Important | Gate et douane confondues (zone « La Porte » à l'icône douane, ouverte par customs1) ; `gate2` ajoute une entrée alors qu'elle annonce « sortie ×2 » | ZONES[3], buildings.json gate2 |
| Important | Gare (78;89) sans liaison au parc, effet « sortie ×2 » décoratif | LOTS rail, RAIL_Z |
| Important | Postes 3–4 sans abri (brise-lames s'arrête en x 42) ; grands navires par la passe ouest le long de tout le port ; gate unique à l'extrême ouest (camion T3 ≈ 460 u) | layout chenal, DEPART_EAST |
| Cosmétique | Bande d'herbe vide 144×48 u au T3 ; touchers Quais/Portiques à 4 u (rayon 9) ; Colline sans route ; GNL sans appontement ; IMO collée au GNL ; repère du Terminal = portique du quai n°1 | |

Plan retenu (on garde la baie) :
```
z -44   phare  ===PASSE O===  brise-lames         [T3] brise-lames est ===== PASSE E <- navires Q3-Q4
z-30..-6 CAP = PÔLE NAUTIQUE : tour VTS (-62,-16), pilotage, atelier + cale sur la crique
z  -6   Q1 | ext | Q2 | ......... | Q3 | Q4
z 0-29  CAPITAINERIE | halle d'inspection (ex-hangar) | PARC T1 | T2 | FROID | RTG | IMO/OOG | GNL
z30-36  voie camions (aller / retour chargé)
z36-43  ENCEINTE DOUANE : douane + scanner mobile                    [T3] gate est
z43-45  GATE : SORTIE côté douane (circulation à droite) | ENTRÉE
z45-64  BUREAUX DU PORT (ex-Colline) : guichet, e-douane, TOS ; scanner2 sur la sortie
z44-80                         GARE contre le terre-plein, voie z≈56 → tunnel est
z84+    village | parkings | logistique | autoroute
```

## Axe 2 — UI / UX

| Priorité | Problème | Appui |
|---|---|---|
| Bloquant | Cartes d'Améliorations qui débordent à droite au T3 (AMÉLIORER et ×1 coupés) | `upgrades_sheet.gd:126,128,176` (labels sans retour à la ligne), capture u6 |
| Bloquant | « Goulot : parc saturé » à côté de « Parc 28 % » vert (capacité théorique vs remplissage) | `port_sim.gd:1546`, `world_overlay.gd:130-133,288` |
| Bloquant | Bouton de la carte Goulot gris alors que le texte dit « améliore Parc » et 9 achats possibles | `hud.gd:894-902` `hint_actionable` |
| Important | HUD 35–46 % de l'écran dès T2 (ISM ≈ 15 %) ; Améliorer en haut à droite (zone la moins accessible au pouce), Réglages et Heures sup grisé en bas au centre | captures u2, u5, u7 |
| Important | Écrans plein cadre : ni solde ni port visibles (« LANCER 281K $ » gris pour 274K $ en poche) | `sheet.gd:24-37`, u4 |
| Important | Textes < 24 px (missions 15/22 px, barre de palier 20 px, légendes 22 px) ; cibles 56–64 px (« i », ▲, « + », coffre) | `hud.gd:244,272,417-430,506`, `upgrades_sheet.gd:192` |
| Important | Unités mélangées ($/s, $/min, EVP/min) | `hud.gd:620`, `upgrades_sheet.gd:274` |
| Important | Améliorer s'ouvre sans focus (goulot 4ᵉ sous le pli au T3) ; pastille « 9 » comptant les achats sans gain ; Gestion liste d'abord 7 « CONSTRUIT » | `hud.gd:375,784`, `manage_sheet.gd:45-80` |
| Important | « + » de l'Ambre qui ouvre les Missions ; « Terminal » (monde) = « Quai n°2 » (Gestion) ; bouton du goulot « CONSTRUIRE » sans dire quoi ; vert/gris surchargés ; bandeau « Nouveau : … » sans bouton d'action | `hud.gd:272`, `layout.gd:95`, `hud.gd:1205-1258` |
| Important | Bulle « n/n en rade » posée sur le phare ou dans les terres, loin du mouillage ; « +2,9 $ » sur « File : 0 » | captures u5, baie_chapitre3, plan_cote_vue_large_t3 |
| Cosmétique | Icône du bandeau étirée ; icônes réutilisées (ancre ×3, missions) ; textes d'aide relus à chaque ouverture ; « Au poste de la capitainerie : deux services » ; phrase répétée dans Commerce ; coffre sans progression dans Missions | |

## Axe 3 — Game feel

Mesures (sonde g1) : rentabilité médiane du meilleur achat **4 min 53** au T1 (33 % > 5 min, 22 % des instants sans achat rentable),
**7 min 14** au T2 ; revenu T2 ×331 en 10 min contre ×8 au T3, **−27 %** à l'entrée du T3 ; trou d'achat de 2 min 19 au T3.

| Priorité | Problème | Appui |
|---|---|---|
| Bloquant | On achète coupé du port : écran opaque, solde caché, monde masqué et effets en pause | `sheet.gd:23-28`, `hud.gd:89-92,594-597` |
| Bloquant | Achats hors goulot muets (pas de pastille si gain ≤ 0, rien ne bouge) ; rentabilité 10–22 min sur la capture du chapitre 1 | `hud.gd:740`, baie_chapitre1_ameliorer |
| Important | Barre « T1 → T2 » à 15 min 37 pour un T2 à 13 min 15 | `unlocks.json:22` (chaîne commerce → missions → stars → progress) |
| Important | Passage de palier, prestige et fin = simple fenêtre | `hud.gd:1275-1283,1430`, `manage_sheet.gd:477-486` |
| Important | Gains du monde illisibles (pastilles 30 px groupées toutes les 1,2 s, sans lien avec un événement) ; gestes payés en EVP | `hud.gd:609-612,815-834,939`, `world_overlay.gd:232` |
| Important | Sons usés (« tier » ×7 usages, « bell » ×5), pas de variation de hauteur, 6 voix volées par la grue | `sfx.gd:57-67` |
| Important | Port peuplé comme un décor (4 dockers fixes, invisibles au zoom par défaut) ; Heures sup et campagnes invisibles dans le monde | `diorama.gd:454-465` |
| Important | 7 bandeaux en 6 min autour du T2 ; carte Goulot rouge permanente ; T3 anti-climax | `reveal_gap_min` 20 s |
| Cosmétique | Conteneurs qui apparaissent d'un coup ; retour d'absence sans « Encaisser » ; solde qui ne pulse qu'en dépense ; narratrice 2D ; pas de bus audio séparés | `yard_view.gd:103,131`, `hud.gd:1400-1410` |

## Top 5 (ordre d'impact)
1. Les 3 incohérences de confiance (débordement T3, « parc saturé » vs jauge, bouton goulot gris / mal nommé) — faible.
2. Douane / gate / capitainerie réorganisées (circulation à droite, pôle nautique) — moyen.
3. Acheter au-dessus du port vivant (feuille à mi-hauteur, solde, caméra, effet visible) — moyen à élevé.
4. Chaque achat se sent (pastille hors goulot, rentabilité médiane ≤ 3 min T1–T2) — moyen, avec la sonde.
5. Écran respirable (Améliorer en bas à droite, HUD < 20 %, barre de palier dès le début, révélations espacées, cérémonie de palier) — moyen.
