# Lot F — « Le golfe et la crique » (14/10/2026, soir)

Source : premier test humain sur téléphone (APK lot E, 14/10 18 h 17). Analyse et décisions du chef de projet, validées par
l'utilisateur le 14/10 au soir. Sauvegarde : `C:\Nadir\tycoon_backups\V2_avant_lot_F_20261014.zip` (point de reprise : commit local `c1c0476`).

## 1. Retour du test (résumé)
1. Navires qui accélèrent au pilotage, puis vont droit sur le quai et pivotent sur place.
2. Le port est déjà plein et vivant au départ ; on veut partir de rien et **voir** chaque construction remplacer le terrain.
3. Commencer par la pêche (barque → chalutier → thonier, location de places), puis passer aux conteneurs.
4. Donner du contexte : on hérite d'une terre et on veut en faire une affaire rentable.
5. Routes, camions et voitures qui sortent et rentrent « de nulle part » (collines-tunnels).
6. Défilement des listes parfois impossible (écran non précisé).
7. Port étroit et condensé : avancer les quais dans la mer plutôt que tout tasser sur la terre.

## 2. Causes trouvées dans le code
- **Navires** : `pilot_time` = 5 s (plancher 2,5 s, et moins encore avec les améliorations), pour un trajet mouillage → chenal →
  bassin → poste d'environ 200 u : la vue (`ship_view.gd`, `_eased` en smoothstep) doit foncer, d'autant plus que le port s'améliore.
  L'accostage (`MOORING`, 5 s) part du point (centre du poste ; `APPROACH_Z`) en ligne droite, puis le cap revient à 0 par
  `lerp_angle` : c'est le pivot sur place. Le pilote (`pilots()`) **et** le poste (`berth` réservé dès `PILOTING`) sont occupés pendant
  le trajet : ralentir les navires coûte du débit, il faut le compenser.
- **Défilement** : les feuilles appellent `refresh()` toutes les 0,2 s, et `refresh()` refait toute la liste (`rebuild()`) dès que
  `_signature()` (Gestion, Commerce) ou `_card_features()` (Améliorer) change. Les enfants sont libérés : un glissé en cours est perdu,
  et la hauteur du contenu tombe un instant, si bien que le défilement est ramené en haut. C'est la cause la plus probable (à confirmer
  en reproduisant le bug). Autre piste : un glissé qui commence sur un bouton d'achat (`HoldRepeat`).
- **Île** : le terrain est déjà une côte continentale (`COAST`), mais les bords de la carte (eau, vide, collines-tunnels) font lire une île.
- **Départ chargé** : au T1, quai, grue, entrepôts, route, gate et cargo existent déjà à la première seconde (`docs/captures/baie_c7_t1_depart.png`).

## 3. Décisions (validées le 14/10 au soir)
| # | Sujet | Décision |
|---|---|---|
| F-D1 | Pêche | **Acte d'ouverture** de 3 à 5 min (palier 0, « La Crique »), puis on passe au palier des conteneurs. Ensuite la pêche **tourne seule** : petit revenu passif, plus aucune carte, toujours visible et vivante. |
| F-D2 | Chantiers | **Visuels uniquement** : la simulation applique l'achat tout de suite. Durée de 3 s (petit) à 6 s (grand), **pas d'accélération, ni payante ni gratuite**. Une partie chargée ne rejoue pas les chantiers. Les améliorations de niveau (services) ne lancent pas de chantier. |
| F-D3 | Géographie | **Pas une île : le fond d'un golfe** (« golfe d'Ambre »). La rive d'en face est visible au large (silhouette de collines, un phare). La carte s'arrête sur une **forêt dense** : la route, l'autoroute et la voie ferrée entrent sous les arbres, et c'est là que le trafic apparaît et disparaît. La caméra s'arrête avant la lisière. Les collines-tunnels sont supprimées. |
| F-D4 | Récit | On hérite de la crique de sa grand-tante **Odette**, pêcheuse : un ponton pourri, une cabane, des voisins pêcheurs. On veut en faire une affaire rentable. 3 cartes d'intro de la narratrice, qu'on peut passer. Corsaire & Fils déclenche le passage aux conteneurs. |
| F-D5 | Défilement | L'utilisateur ne sait pas dans quel écran : le développeur reproduit le bug (glissé pendant un `rebuild`, glissé qui part d'un bouton, feuille à mi-hauteur) et le corrige partout. |
| F-D6 | Trafic | Rien ne roule ni ne navigue sans le bâtiment qui le crée : pas de camion avant la gate, pas de camionnette avant la criée, pas de cargo avant le quai. |
| F-D7 | Espace (point 7) | Reporté au lot F4 (quais en avancée sur la mer, quartiers aérés), après un nouveau test des 10 premières minutes. |

## 4. Les lots
| Lot | Contenu | Qui | Ordre |
|---|---|---|---|
| **F1** | Navires (vitesse constante, évitage avec remorqueur, accostage en crabe) + défilement | développeur | `docs/ORDRE_F1.md`, maintenant |
| **F-Blender** | Modèles de la crique, des chantiers et de la forêt | expert Blender | `docs/ORDRE_BLENDER_F.md`, en même temps que F1 (`blender/` et les nouveaux `.glb` seulement) |
| **F2** | Golfe et forêt, départ de rien, chantiers visibles, trafic lié, intro | développeur | `docs/ORDRE_F2_F3.md`, après F1 |
| **F3** | Acte 0 : la pêche, puis bascule vers les conteneurs | développeur | même ordre, palier suivant |
| F4 | Quais en avancée, espace | — | après le test humain des 10 premières minutes |

**Ne pas faire** : une pêche gérée en détail (espèces, flotte, responsables), une deuxième monnaie, des minuteurs de construction
longs ou à accélérer contre paiement.

## 5. Acte 0 « La Crique » (cible de conception, chiffres à caler à la sonde)
- **Lieu** : l'**anse des pêcheurs**, à l'ouest du cap, hors du bassin des conteneurs (plage ouest, x ≈ −130…−94). Le port de
  conteneurs s'ouvre « de l'autre côté du cap ». La crique et le cap restent au pôle nautique (palier 2). Le développeur fixe les cotes
  dans `PLAN_COTE.md` (nouveau § « Anse des pêcheurs »), sans croiser les trajets des cargos (arrivée par le nord-ouest).
- **Départ** : 0 $. Visible : le golfe, l'anse avec le ponton pourri, la cabane d'Odette, les maisons du village, le phare du cap.
  À l'est du cap, la friche : rochers, broussailles, une vieille estacade ruinée. Aucun camion, aucun cargo.
- **Achats** (5 au plus, mêmes gestes que le reste : carte AMÉLIORER, chantier visible) :
  1. **Réparer le ponton** — gratuit (tutoriel) — 2 places : des barques du village viennent s'y amarrer, sortent en mer (≈ 40 s),
     rentrent et débarquent leurs caisses. Revenu = loyer des places + vente sur le ponton.
  2. **Deuxième ponton** — ≈ 25 $ — +2 places de barques.
  3. **La criée** (halle à marée) — ≈ 60 $ — vente aux enchères : chaque débarque rapporte ×2. La **camionnette du mareyeur** part
     par la route jusque dans la forêt : premier trafic routier, et la route se construit avec la criée.
  4. **Quai des chalutiers** — ≈ 120 $ — chalutiers (×4 par débarque).
  5. **Fabrique de glace** — ≈ 200 $ — un thonier (×10) vient du large.
- **Bascule** : au premier débarquement du thonier (ou dès qu'on a ≈ 300 $ et les 5 achats), un caboteur de **Corsaire & Fils**
  passe au large ; la narratrice : « Il cherche un quai… de l'autre côté du cap, il y a l'ancienne estacade. » → cérémonie
  « Palier 1 — Le Vieux Quai », la caméra passe le cap. La première carte du T1 reconstruit le vieux quai (chantier), puis la grue,
  le parc et la gate, chacun avec son chantier. Le premier cargo n'arrive qu'une fois le quai debout, et le premier camion qu'une fois
  la gate debout.
- **Après** : la pêche rapporte un revenu fixe (de l'ordre de ce qu'elle rapportait à la fin de l'acte 0). Plus de carte ni de
  pastille ; on la voit vivre (barques, chalutiers, thonier, camionnette).
- **Durée** : acte 0 en 3 à 5 min sur les 4 graines de la sonde. Le reste de la progression, mesuré **depuis l'entrée au T1**, reste
  dans les cibles actuelles (±5 %).
