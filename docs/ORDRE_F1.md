# Ordre de mission — lot F1 « Navires et défilement » (14/10/2026, soir)

> Pour le sous-agent **développeur senior Godot**. Source : `docs/PLAN_LOT_F.md` (§ 2 causes, § 3 décisions F-D5), validé par
> l'utilisateur après son premier test humain. Point de reprise : commit local `c1c0476` + sauvegarde `V2_avant_lot_F_20261014.zip`.
> **Un expert Blender travaille en même temps** dans `blender/` (nouveaux modèles de la crique, de la forêt et des chantiers).

## Règles (impératives)
- Seul projet : `C:\Nadir\tycoon_V2`. **Aucun commit, aucun push.** Ne pas toucher `C:\Nadir\tycoon`, `blender/`, ni les `.glb`
  existants. Les nouveaux `.glb` qui apparaissent dans `godot/assets/models/` sont ceux de l'expert Blender : ne pas les retoucher.
- Godot : `C:\Nadir\Godot\Godot.exe` via `Start-Process … -PassThru -NoNewWindow -Redirect…`, puis **`WaitForExit(ms)` borné et
  `Kill()` si dépassement** (une graine de sonde par processus, ≤ 8 min par commande). `--import` après tout nouveau `class_name`.
- Tests : `run_all` (214) et `ui_smoke` (147) verts. Aucun contrôle retiré ; tout recalage est noté au journal ; un contrôle par
  correction quand c'est testable.
- **Économie** : la sonde (4 graines) reste dans ±5 % sur la moyenne des jalons (T1, T2, T3, fin) et ±15 % par graine, par rapport
  à la mesure du lot D-Éco/E (à refaire d'abord sur le code actuel, comme base).
- Captures `--fresh` uniquement ; ne pas bouger la souris pendant une capture.
- Doc : section « Lot F1 » dans `docs/JOURNAL_PLAN_BAIE.md`, décisions dans `docs/DECISIONS.md`, `PLAN_COTE.md` § 3 si les trajets changent.

## 1. Navires : un vrai pilotage
Constat (`PLAN_LOT_F.md` § 2) : le pilotage dure 5 s (plancher 2,5 s) pour ≈ 200 u, et l'accostage se fait en ligne droite puis par
un pivot sur place.
Le résultat attendu, à l'écran :
- **Vitesse lisible et constante** : un navire ne dépasse jamais une vitesse de croisière par classe (ordre d'idée : caboteur 7 u/s,
  feeder 6, panamax 5, à caler à l'œil), il ralentit en douceur avant le bassin et avant le poste, et ne va **jamais plus vite parce
  que le port a été amélioré**. Écart de vitesse sur le trajet en régime < 15 % d'un navire à l'autre de la même classe, quels que
  soient la place de mouillage, le poste et les niveaux. Le rattrapage (`CATCHUP_K`) ne doit plus produire de sprint visible
  (plafond absolu ≈ 1,3 × la croisière).
- **Évitage dans le bassin** : le navire tourne pendant qu'il avance lentement (rayon de giration plausible, pas sur son centre),
  le remorqueur bien visible, collé à la hanche, qui pousse pendant la rotation.
- **Accostage en crabe** : le cap est **déjà parallèle au quai** avant la dernière approche ; les 6 à 10 dernières unités se font en
  glissement latéral lent, remorqueur à l'épaule côté large. Plus aucun pivot sur place (contrôle : variation de cap < 5° sur les
  8 derniers mètres, vitesse de rotation < 25°/s partout).
- Même exigence au **départ** : le remorqueur décolle le navire latéralement, puis le navire prend sa route.
- Le **remorquage depuis le mouillage** (le remorqueur va chercher le navire au large et l'accompagne) : oui si c'est simple avec
  `_ensure_tug` ; sinon le remorqueur le rejoint à l'entrée du chenal.

Côté simulation, recommandation du chef de projet (à confirmer par ta lecture) : **séparer le temps de service de la capitainerie
(ce que les améliorations raccourcissent : pilotes, remorqueurs, bollards) du temps de trajet** (fixé par la distance et la vitesse
de croisière, jamais raccourci par un achat). Les améliorations de la capitainerie servent alors **plus de navires en même temps**
(pilotes en parallèle) au lieu de les faire courir. Comme le poste est réservé dès `PILOTING`, le trajet plus long coûte du débit :
compense-le (par exemple le poste n'est réservé qu'à l'entrée du bassin, ou les planchers `pilot`/`moor` sont recalés) pour tenir la
sonde. Garde la sauvegarde compatible (version inchangée si possible ; sinon migration testée).
Si une autre solution tient mieux les deux contraintes (visuel juste + sonde), prends-la et explique-la au journal.

## 2. Défilement des listes
Constat probable : `refresh()` (0,2 s) appelle `rebuild()` dès que `_signature()` (Gestion, Commerce) ou `_card_features()`
(Améliorer) change. Les enfants sont libérés, le glissé en cours est perdu, et la hauteur du contenu retombe : le défilement revient en haut.
- **Reproduire d'abord** (ui_smoke) : glissé (`InputEventScreenDrag` et souris émulée) qui part d'un texte, d'une carte et d'un
  bouton d'achat (`HoldRepeat`), dans les 3 feuilles, à mi-hauteur et en plein écran, pendant qu'un `rebuild()` survient. Note au
  journal ce qui casse réellement.
- **Corriger** : conserver `scroll_vertical` à travers un `rebuild()` (et ne pas le rebâtir pendant qu'un doigt est posé, en le
  différant au relâchement) ; un glissé qui part d'un bouton défile et n'achète pas (seuil de glissé, annulation de `HoldRepeat` dès
  que le doigt bouge de plus de quelques pixels) ; un appui bref achète toujours. Vérifier aussi la molette et le glissé à la souris sur PC.
- Contrôles ui_smoke : défilement conservé après un `rebuild()` forcé ; glissé depuis un bouton = défilement sans achat ; appui bref =
  achat.

## Fin de lot
Tests verts, sonde dans les tolérances (tableau avant/après au journal), captures `docs/captures/f1_*` regardées (un navire au
milieu du chenal, l'évitage avec le remorqueur, l'accostage en crabe, un départ), **APK réexporté** (`exporter_apk.bat`). Rapport :
fait / non fait (raison), chiffres, captures, ce que l'expert Blender t'a éventuellement laissé à brancher.
