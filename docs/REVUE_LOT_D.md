# Revue du lot D (14/10/2026, fin d'après-midi)

> Quatre relecteurs en lecture seule : code Monde + Éco, code UI + audio, contre-revue du layout, contre-revue UI/UX + game feel
> (captures de travail `scratchpad\ux2\x1…x8`). Points principaux vérifiés par le chef de projet dans le code et sur les captures.
> État : run_all 196/196, ui_smoke 131/131, APK du 14/10 15 h 21. Base de comparaison : `REVUE_CRITIQUE_PORT.md`.

## Bilan de la revue précédente
- **Résolus** : douane côté sortie, pôle nautique (tour à 35 u de la passe, atelier + cale), zones Gate / Douane séparées, passe est
  pour Q3–Q4, débordement des cartes au T3, chrome du haut 15 % (21 % avec une carte d'aléa), Améliorer en bas à droite, feuille à
  mi-hauteur sur le port vivant, mini-solde partout, typo ≥ 24 px, barre de palier à ~2 min, 2–4 bandeaux autour du T2, carte Goulot
  rouge 0–10 % du temps, rentabilité T1 2:04–2:24 (au lieu de 4:53–7:46), revenu T2 ×18–35 à +10 min (au lieu de ×234–331).
- **Partiels** : gare (bien placée mais sans aucun flux), unités (effets encore en EVP/min), cérémonie de palier (ne montre pas ce qui
  s'ouvre), pièces d'encaissement (masquent le texte), audio (mieux mixé mais toujours des bips synthétisés, pas de musique).
- **Non tenus** : rentabilité T2 ≤ 3 min (4:51–6:39, limite structurelle), trou d'achat T3 ≤ 90 s (manque de contenu), gate est
  (la simulation n'a qu'une file).

## Nouveaux problèmes

### Importants — « confiance 2 » (régressions et mensonges d'interface)
| # | Problème | Appui |
|---|---|---|
| E1 | Les « services facturés » (D-Éco) donnent un gain > 0 à tout achat : la pastille compte 9 au T3, la mention « pas le goulot » ne s'affiche plus, « +15 $/s · rentabilisé en 102 h 57 min » en vert pour 5,43 M$ | `hud.gd:1010-1016,1080`, capture x4 |
| E2 | Le bouton Goulot propose le **bâtiment suivant de la chaîne**, pas celui qui règle le goulot (« postes à quai » → GNL 280 M$, qui n'ajoute aucun poste) | `hud.gd:1235`, x3 |
| E3 | Coût des aléas calculé sur le débit théorique : « Sécuriser · 116 M$ » pour 41 K$/s de revenu (65 % de la trésorerie) ; « Inf s → Inf s » et « meilleur achat » sous brouillard | `hazards.gd:83`, `info.gd:88`, `port_sim.gd:568`, x2–x3 |
| E4 | Anciens noms courts (« RACK FRIGO », « 2ᵉ VOIE DE GATE ») servis en priorité au bouton Goulot ; « QUAI ALLONGÉ » vs « Allongement du quai » | `info.gd:18` |
| E5 | Fermer la feuille d'un toucher sur le port : le relâchement atteint la caméra (`_press_pos` périmé) → geste, priorité ou réouverture d'Améliorer | `sheet.gd:174-180`, `main.gd:81-84`, `camera_rig.gd:152-160` |
| E6 | Bandeaux « Nouveau » qui s'enchaînent sous une feuille (`_close_banner` sans `_covered()`), caméra déplacée, retour de caméra raté | `hud.gd:1724-1764` |

### Importants — flux du port
| # | Problème | Appui |
|---|---|---|
| E7 | Camions qui pivotent de 180° à l'arrêt de chargement (cap visé 0 au lieu de π depuis la voie B) | `traffic_view.gd:293` |
| E8 | Au T3, chaque camion vide va jusqu'au bout de la boucle (x 146) quel que soit son bloc : 850–960 u par camion | `traffic_view.gd:198` (`_tier`) |
| E9 | Passe est naviguée à gauche (arrivée z −29 au sud, départ z −36) et croisement arrivée/départ vers (190 ; −65) ; la voie au large z −108 coupe l'approche du chenal ouest, sans gestion de croisement | `layout.gd:287-300,396-414` |
| E10 | Avec `gate2`, un camion chargé sur deux contourne le scanner à portique ; test qui ne vérifie que la voie 0 et simule l'ancienne file à deux voies d'entrée | `layout.gd:459`, `run_all.gd:890-906` |
| E11 | Capitainerie : deux bâtiments, un seul toucher au T2 ; pavillons de campagne sur l'ancien bureau | `diorama.gd:1693` |
| E12 | Gare sans flux (tracteur fixe, train invisible si la gare est à l'écran) ; coin gate/douane surchargé (≈ 27 × 25 u, 3 cibles de toucher à 7–11 u, rue des bureaux qui débouche en tête de file) | `traffic_view.gd:598`, capture d_monde_t2_gate_douane |

### Importants — expérience
| # | Problème |
|---|---|
| E13 | Feuille à mi-hauteur : 1,5–2 cartes visibles (ISM 4–5), « i » sur sa propre ligne, Commerce cadré sur une mer vide, moitié haute blanche sous brouillard ; aléas masqués pendant la feuille |
| E14 | Cérémonie qui ne montre pas ce qui s'ouvre (texte générique, pas de VOIR) ; bulle « en rade » au-dessus de la fenêtre ; couche de cérémonie au-dessus des fenêtres (`hud.gd:1816,1849`) |
| E15 | Rythme : T1 dense (un nouveau système presque chaque minute dès 3:30), mur d'épargne de 1–2 min en fin de T1, T2 où le meilleur achat met 5–6 min, T3 avec un seul bâtiment achetable à 280 M$ |
| E16 | Audio : bips carrés répétés toutes les 1–2 s, aucune musique (`assets/audio` vide) |

### Mineurs
`last_tier_t` non sauvegardé ; `reset()` incomplet ; `_ship_cargo0` jamais vidé pour un navire reparti furieux ; douaniers tronqués
par `CROWD_MAX` au T3 ; `rade_anchor` = barycentre (point dans le vide) ; alerte gate/parc avant le chapitre ; barre de palier qui cite
la Réputation avant sa révélation ; « fees » et « services » mélangés dans Stats ; `service_fee_rate()` recalculé à chaque image ;
`_burst_n` jamais remis à zéro (hauteur du son qui dérive) ; onglets 84 px, barre de palier 36 px, « POURQUOI ? » 84 px ; bulles qui
se recouvrent au bord de l'écran, `StyleBoxFlat.new()` par bulle et par image ; écriture disque à chaque cran de volume ; `ui_smoke`
qui réécrit `user://audio.cfg` et trois contrôles qui passent sans rien vérifier ; gyrophares orange sur grues orange ; bureau de
pilotage sans toit ; GNL à 1 u du poste 4 ; zones grises du T1 plus grandes que le port actif.

## Proposition — lot E
1. **E-Confiance** (faible, ~1–1,5 j) : E1–E6 + mineurs UI.
2. **E-Flux** (faible à moyen) : E7–E12 + mineurs monde.
3. **E-Contenu** (moyen à élevé) : achats intermédiaires T2/T3 (paliers de service tous les 25 niveaux visibles dans le monde,
   bâtiments T3 en deux étapes, objectifs courts, ×10 / MAX), feuille compacte (E13), cérémonie qui montre (E14), rythme du T1 (E15).
4. **E-Audio** (moyen) : échantillons CC0 + musique douce (demande l'accord de l'utilisateur pour les téléchargements).
5. **Test humain de 20 min sur l'APK** avant E-Contenu : beaucoup a changé, et le rythme du T1 n'a jamais été joué par un humain.
