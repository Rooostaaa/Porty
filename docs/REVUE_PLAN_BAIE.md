# Revue du chantier « La baie et le terre-plein » — chef de projet + designer

> 13/10/2026, après la livraison des paliers 0, M1, M2, M3 (`JOURNAL_PLAN_BAIE.md`) et du lot Blender (`previews/baie.png`).
> Critique croisée : designer (lecture des 13 captures, des docs et de `unlocks.json`, `tutorial.json`, `diorama.gd`, `layout.gd`)
> et chef de projet (captures `baie_t1_depart`, `plan_cote_vue_large`, `baie_t3`, `baie_ouverture_zone`, `baie_camion_charge`, `baie_chenal`).

## Verdict

L'**ingénierie est solide** : plan coté complet en données, une case par bâtiment, terrain polygonal et eau par texture de distance,
trajets testés (navires sur l'eau, camions entrant et sortant sous les tunnels), `run_all` 152/152, `ui_smoke` 74/74.
Côté **joueur**, la structure existe mais **ne se lit pas encore** : trois des quatre défauts relevés au test APK ne sont que partiellement corrigés.

| Défaut du joueur | État |
|---|---|
| Carte anarchique, zones à venir invisibles | **Partiel** : toutes les zones à venir ont le même gris + pointillés blancs ; ~60 % de la terre au T1 est un « chantier de pointillés » |
| Services mélangés | **Partiel** : bulles « Parc 0 % » et « 0 camion » visibles dès le départ ; 4 révélations simultanées au niveau 10 des Portiques |
| Trop de choses au départ | **Partiel** : 3 boutons OK, mais ~12 empreintes, 2 contours sur l'eau, 3 bulles, un anneau orange, la carte « Goulot » rouge |
| Camions qui surgissent, navires sur la terre | **Corrigé** pour l'essentiel (restent : conteneur qui part du bord du parc sans engin libre, pas de distance de suivi entre camions) |

## Défauts, par gravité

### Bloquants
1. **Première minute contradictoire.** Le tutoriel fait acheter un niveau de Portiques, la carte dit « Aucun gain immédiat », la carte Goulot
   réclame le quai à 250 $ avec un bouton **vert** alors qu'on a 99 $ ; puis ~2 min sans achat (cible ≤ 90 s non tenue). → **décision 1**.
2. **L'ouverture de zone est noyée sous le HUD** (`baie_ouverture_zone.png`) : missions, carte Goulot, bandeau, aucune vague de sable visible,
   barges déjà amarrées. → masquer le HUD et mettre toasts/bulles en file pendant la séquence ; terre-plein : sable d'abord, puis asphalte, puis quais.
3. **Révélations groupées** : `managers`, `manage`, `dept_yard_ops`, `licences` au même seuil ; `commerce`, `missions`, `stars`, `progress` au même seuil.
   → un sujet par seuil, étalés (voir **décision 3**).
4. **Pas d'export Android** dans `tycoon_V2` (ni `export_presets.cfg` ni `exporter_apk.bat`) : le test humain de 20 min est impossible.
   → reprendre le préréglage de `C:\Nadir\tycoon` (lecture seule) et créer `exporter_apk.bat`.

### Importants
5. Zones à venir indistinctes → garder la teinte du quartier (désaturée ~0,55, voile ~0,25), une icône par zone, empreintes `ghost_lot` seulement
   pour la zone ouverte et la prochaine, contours seuls pour les empreintes à flot.
6. Bulles des services pas encore présentés → conditionnées au chapitre ; « 0 camion » → « File : 0 » ; anneau orange expliqué ou masqué.
7. Bulles qui passent sur le HUD ou sortent de l'écran (`baie_gestes`, `baie_chenal`) → bornées au rectangle utile.
8. Notifications au centre de l'écran, sur le navire → toast sous l'en-tête, un à la fois, en file.
9. Bouées de mouillage rouges (confusion avec le balisage) → jaunes (marque spéciale) ; mouillage n°1 trop près du cap (on croit à un échouage).
10. **Pas de sphères GNL** au T3 (deux `silo`) → modèle `lng_sphere` dans `blender/parts/baie.py`.
11. Abri peu crédible : les navires ressortent par l'est en mer ouverte → **décision 2**.
12. Zone 12 grisée mais conteneurs colorés → neutraliser ou sortir les entrepôts du village de la zone.
13. Priorité des touchers : la grue (rayon 8) passe avant l'engin (5) → choisir le candidat au plus petit rapport distance/rayon ;
    toucher une zone grise = bulle d'info, pas une fiche.
14. Captures non représentatives (`--tier`/`--levels` : Heures sup au T1, −11 $/s et 0 $ au T3) → captures prises sur des parties de bot réelles.
15. Bordures entre quartiers absentes (Colline, terre-plein contre l'herbe) → haies / bordures + vraie butte pour la Colline.

### Mineurs
Sillage en bande droite (→ V qui s'estompe) ; chenal grisé en pointillés (→ bouées fantômes) ; « terre-plein » employé pour gravel2 dans le tutoriel ;
« carte rouge » alors qu'elle est blanche ; texte des pancartes ~12 px (→ 14–15) ; pastille orange vide dans le HUD ; « RESPONSABLES 0/6 : OFF » ;
« 1/2 en rade » rouge au départ ; arbres saupoudrés (→ bosquets/haies) ; T2 de la graine 1 à −11,8 % (hors ±10 %).

## Ajouts du chef de projet
- Le trou de 2 min n'est pas nouveau (avant : 1 min 22 – 1 min 34 avant le premier achat) ; il s'est allongé de ~40 s parce que le premier achat
  « à 1 s » dépense l'argent qui aurait servi au quai. Le problème est l'**ordre** du tutoriel autant que le montant de départ.
- La carte « Goulot » rouge dès la seconde 0 est anxiogène pour un joueur qui ne peut rien faire : en rouge seulement si une action est possible.
- Les captures `baie_t3` / `baie_ouverture_zone` (−11 $/s) ne permettent pas de juger l'équilibre du T3 : ne pas s'y fier.

## Décisions retenues (13/10, l'utilisateur a répondu « corrige » : le chef de projet tranche selon ses recommandations)
1. **(a')** départ 260 $ (valeur dans `config.json`) + le quai allongé devient le premier achat du tutoriel ; remesurer à la sonde.
2. **Navires par la passe aux paliers 1–2** (entrée et sortie, deux voies du chenal) ; la sortie est s'ouvre au palier 3 avec le terre-plein.
3. **Chapitres fermés au niveau 10** (décision 3 maintenue) ; révélations étalées, un sujet par seuil.
4. **Lot : bloquants + importants**, puis mineurs ; export APK en premier ; `lng_sphere` côté Blender. Nouvelle revue designer + chef de projet ensuite.

## Décisions proposées (historique)
1. **Début de partie** : (a') départ 260 $ + le quai devient le 1er achat du tutoriel ; (b) +30 % de valeur aux petits navires au T1 ; (c) accepter.
2. **Sortie des navires** : par la passe aux paliers 1–2 (sortie est ouverte au T3 avec le terre-plein) ou garder la sortie est dès le départ.
3. **Durée des chapitres** : garder la fermeture au niveau 10 (chapitre 1 ≈ 7–8 min, chapitres 2–3 très courts) ou abaisser le chapitre 1 (≈ niveau 6).
4. **Lot de corrections** : bloquants + importants maintenant (dev + Blender pour `lng_sphere`), mineurs ensuite.

---

# Seconde revue (14/10, après les corrections C1–C5)

**Verdict commun designer + chef de projet : prêt pour le test humain de 20 min sur APK sous réserve de N1–N3.**
Corrigés et vérifiés sur capture : 1, 2, 4, 6, 9, 12, 15 et la plupart des mineurs. Partiels : 3, 5, 7, 8, 10, 11, 14, 16.
Cibles hors tolérance acceptées : attente réelle sans achat abordable ≤ 76 s (le trou du bot vient de sa règle d'épargne) ;
T2 graines 1–2 à ±12 % (moyenne +1,7 %, même dispersion sans rien toucher : critère à passer à « moyenne ±5 %, chaque graine ±15 % ») ;
fin du MVP graine 3 à −10,0 %.

## Nouveaux défauts
- **N1 (bloquant)** navires sur les bouées rouges du chenal (voies ±3 u, bouées ±7 u) → bouées à ±9,5 u ou voies ±2,5 u + contrôle « coque ≥ 1,5 u de toute bouée et de tout feu ».
- **N2 (bloquant)** notifications du haut sur la puce RESPONSABLES et le bouton Améliorer → sous la carte Goulot, colonne gauche, fond opaque, pas de doublon avant 60 s.
- **N3 (bloquant)** départ : phare et navire au mouillage hors cadre ou sous la carte Goulot → carte Goulot masquée pendant une carte du tutoriel, `START` ≈ 6 u vers le large, contrôle ui_smoke (phare, navire n°1, empreinte du quai dans `useful_rect`).
- **N4** « 39 % » coupé au-dessus de l'en-tête (`baie_t3`) ; textes de gain hors écran ou sur le HUD → toute la surcouche bornée (minuteries, gains, pastilles).
- **N5** la Douane s'impose aux chapitres 2–3 (goulot « ouvre un bureau de douane » à 2 min 24) → conseil du chapitre en cours, empreinte `customs1` masquée jusqu'au chapitre 4 ; mesurer à la sonde.
- **N5 bis (chef de projet)** contradiction : « Rade pleine : navires déroutés » et « Goulot : pas assez de navires » en même temps (`baie_chapitre2`) → le goulot ne peut pas être « navires » quand la rade est pleine ; corriger le diagnostic ou son texte.
- **N6** bouées fantômes du chenal trop présentes → alpha 0,35, bleu-gris, ×0,8, une sur deux.
- **N7** chapitre 2 ≈ 50 s → option (a) retenue : condition « gate goulot pendant au moins 45 s » (présentation, pas d'économie).
- **N8** rafales de révélations → 60 s minimum ou dès que la précédente est utilisée ; file de notifications ≤ 2 sans doublon ; 3 s de calme après une ouverture de zone puis une toutes les 4 s.
- **N9** chapitre 3 ne montre pas la gate → cadrage de 2 s sur le poste à l'ouverture d'un chapitre de service.
- **N10** navires qui se recouvrent / collés au brise-lames → distance de suivi et d'attente, contrôle « deux coques ≥ 2 u », pas de poste sur un quai pas encore construit.
- **Mineurs** N11 « Toucher pour passer » lisible ; N12 séquence passable après 1,5 s seulement ; N13 un seul badge numérique ; N14 empreintes des zones ouvertes avec liseré ; N15 « File : 0 » ancrée sur la guérite.
- **Captures périmées** à refaire ou supprimer : `baie_t1_large`, `baie_gestes`, `baie_chapitre1_ameliorer`, `plan_cote_vue_large`, `plan_cote_vue_large_t3` ; ajouter une capture T3 qui montre les sphères GNL.

## Bilan du lot C6 (14/10, 7 h 20) — chef de projet
N1–N4, N5 bis, N6–N15 corrigés ; `run_all` 166/166, `ui_smoke` 85/85 (désormais en fenêtre portrait 540×960) ; APK réexporté.
Vérifié sur capture : `baie_t1_depart` (phare, navire n°1 et empreinte du quai visibles sous le HUD), `baie_t3_gnl` (sphères dans la silhouette),
`baie_chenal` (navires dans les voies, bouées dégagées).
**Restent ouverts, à juger pendant le test humain :**
- **N5** (Douane aux chapitres 2–3) non fait : la masquer repousse le T2 à 21–29 min. Proposition : ne changer que le texte du conseil (option 3) après le test, si le joueur la ressent comme un sujet de trop.
- Fin du MVP graine 3 à −11,1 % (moyenne −4,6 %) : même bruit que le T2, accepté, à surveiller.
- La séquence de 2 s sur le poste à l'ouverture d'un chapitre (N9) n'est pas couverte par un test : à observer.
