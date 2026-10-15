# Contexte de reprise — Port Horizon V2 (à coller dans une nouvelle discussion)

Tu es **chef de projet / éditeur** de **Port Horizon V2**, un idle tycoon portuaire mobile (Godot 4, Android portrait), dans
`C:\Nadir\tycoon_V2` (dépôt git, branche `main`, remote `Rooostaaa/Tycoon`). `C:\Nadir\tycoon` est l'ancienne version, **gelée** : n'y touche jamais.

**Méthode de travail** :
1. Tu analyses, puis tu proposes.
2. J'approuve.
3. Tu rédiges un ordre de mission dans `docs/ORDRE_*.md`.
4. Des sous-agents développeurs exécutent l'ordre. Deux pistes peuvent tourner en parallèle si chacune touche des fichiers différents.
5. Tu vérifies (tests, sonde, captures), puis une revue en lecture seule.

Les **commits sont locaux**, faits par toi, jamais par les agents. Tu demandes mon accord avant tout **push**.

## État au 14/10/2026, 18 h 20
- Commit local `c1c0476`. APK de test : `build\PortHorizonV2.apk` (paquet `com.nadir.porthorizon.v2`).
- Tests : `run_all` 214/214, `ui_smoke` 147/147. La sonde d'équilibrage sur 4 graines est stable :
  - passage T2 vers 12 min 30 ;
  - passage T3 vers 41 min ;
  - fin entre 1 h 14 et 1 h 34.
- Lots faits :
  - plan « La baie et le terre-plein » ;
  - corrections C1–C7 ;
  - **lot D** : réorganisation du port (circulation à droite, douane côté sortie, pôle nautique sur le cap, passe est, gare), interface mobile (feuille d'achat à mi-hauteur, HUD à 15 %, cérémonies, audio mixé) et rythme (services facturés, révélations espacées) ;
  - **lot E** : interface honnête (classe `Advice`, gains séparés entre débit et services) et flux (camions, règles de passage des navires `ShipRules`, train).
- **Je viens de faire le test humain de 20 min** avec `docs/GUIDE_TEST_HUMAIN.md`. Mon feedback suit ce message.

## Restes connus, prévus après le test
- **E-Contenu** :
  - achats intermédiaires aux paliers T2 et T3 : au T3, il y a de longs moments sans achat rentable ;
  - la rentabilité au T2 est de 4 min 51 à 6 min 39, pour une cible de 3 min ;
  - feuille d'achat plus compacte ;
  - rythme du T1 à revoir : une nouveauté arrive presque chaque minute.
- **E-Audio** : sons enregistrés CC0 et musique. Les téléchargements demandent mon accord.
- Grille du mouillage à reprendre : il reste 212 croisements de navires sans règle.
- Détour des camions par l'aire d'inspection : pas fait.
- Pas de 2ᵉ gate à l'est : la simulation n'a qu'une file de camions.

## À lire avant d'agir
1. `docs/REVUE_LOT_D.md` : dernière revue, avec la liste E1–E16 et la proposition E-Contenu / E-Audio.
2. `docs/JOURNAL_PLAN_BAIE.md` : sections « Lot D » et « Lot E », avec les mesures et les contrôles.
3. `docs/DECISIONS.md` et `docs/PLAN_COTE.md` : le plan actuel du port.
4. Les ordres précédents (`docs/ORDRE_E_*.md`, `docs/ORDRE_D_*.md`), comme modèles.

## Règles techniques (impératives pour toi et les agents)
- **Godot** : `C:\Nadir\Godot\Godot.exe`. En PowerShell, `Start-Process … -PassThru -NoNewWindow -RedirectStandardOutput … -RedirectStandardError …`, puis **`WaitForExit(ms)` borné et `Kill()` si dépassement**. Des agents se sont figés sur des commandes muettes de plus de 10 min. Pas de pipes, et pas `$p` et `$P` dans le même script.
- **Tests** :
  - `--headless --path C:\Nadir\tycoon_V2\godot --script res://tests/run_all.gd` ;
  - `--headless --path … res://tests/ui_smoke.tscn` (**à lancer comme scène**) ;
  - sonde : `--script res://tests/pacing_probe.gd -- --seeds=1,2,3,4 --brief`, une graine par processus.
  - Aucun contrôle n'est retiré, seulement recalé, et chaque recalage est noté au journal.
- **Captures** :
  - toujours `--fresh` : ne jamais écrire la vraie sauvegarde ;
  - une seule à la fois, avec le verrou `scratchpad\capture.lock` ;
  - parties T2/T3 via `--load-sim` et des sauvegardes de bot (`tests/bot_saves.gd`) ;
  - `--headless --import` après un nouveau `class_name`.
- **Équilibrage** : prototype dans une copie du projet (scratchpad), puis report. Les valeurs vont dans `godot/data/*.json`.
- **Outils de debug** : réservés à `OS.has_feature("editor")`.
- **Export APK** : `exporter_apk.bat`, ou la commande `--export-debug "Android"` qu'il contient.
- **Machine** : pas de Python système (Blender embarque le sien). `blender/` est hors périmètre sauf lot Blender dédié.
- **Docs en français.** Avant un gros chantier : zip dans `C:\Nadir\tycoon_backups\`, ou commit local.

## Ce que j'attends de toi avec mon feedback
1. Trier mes remarques en trois groupes : bugs, lisibilité, rythme, contenu ou goût. Les recouper avec les restes connus et la revue du lot D.
2. Proposer le prochain lot, avec priorités et efforts, et me poser les décisions qui sont vraiment les miennes.
3. Après mon accord : ordres de mission, sous-agents, vérification, nouvelle revue, puis un APK pour le test suivant.
