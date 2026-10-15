# Port Horizon

**Idle tycoon portuaire** en 3D low-poly, conçu pour mobile en portrait (Android), jouable aussi sur PC (Windows, Linux).
On commence par une petite crique de pêcheurs, on signe la Concession du terre-plein, puis on fait grandir un terminal à
conteneurs : quais, grues, parc, gate, douane, rail. Chaque amélioration accélère un maillon de la chaîne ; le plus lent
(le **goulot**) est signalé en rouge. Les responsables font tourner le port en votre absence (gains hors ligne).

Version : **2.1.0** (Godot **4.7.1**, rendu *Mobile*). Jeu et documentation en français.

## Jouer
- **Android** : installer l'APK (`build/PortHorizonV2.apk` en debug, `build/android/PortHorizon.apk` en release).
- **Windows** : lancer `build\windows\PortHorizon.exe` (exe autonome, rien à installer), ou `jouer.bat` depuis les sources.
- **Linux** : `./build/linux/PortHorizon.x86_64`.
- Depuis les sources : `Godot --path godot` (ajouter `-- --fresh` pour une partie neuve qui n'écrit pas la sauvegarde).

Commandes : toucher / cliquer pour acheter et encaisser, glisser pour déplacer la caméra, pincer / molette pour zoomer.
La sauvegarde est automatique (toutes les 15 s et à la fermeture) : `%APPDATA%\Godot\app_userdata\Port Horizon V2\` sous Windows,
`~/.local/share/godot/app_userdata/Port Horizon V2/` sous Linux, stockage interne de l'application sous Android.

## Tests
Avec le binaire de l'**éditeur** Godot 4.7.1 (`G` = `C:\Nadir\Godot\Godot.exe` ou `/opt/godot/Godot_v4.7.1-stable_linux.x86_64`) :
```
G --headless --path godot --import                                    # après un clonage ou un nouveau class_name
G --headless --path godot --script res://tests/run_all.gd             # simulation et monde
G --headless --path godot res://tests/ui_smoke.tscn                   # interface (à lancer comme scène)
G --headless --path godot --script res://tests/pacing_probe.gd -- --seeds=1 --brief   # sonde d'équilibrage, une graine par processus
```
Les outils de débogage (F1, `--debug-money`, `--tier`, `--build-all`, `--event`, `--load-sim`…) n'existent que dans le binaire de
l'éditeur ; ils sont ignorés par toute version exportée. Liste complète : `docs/DECISIONS.md` § « Lancer / vérifier ».

## Exporter
Modèles d'export Godot 4.7.1 requis (éditeur : *Éditeur > Gérer les modèles d'export*). Fermer l'éditeur avant d'exporter.

| Cible | Windows | Linux | Sortie |
|---|---|---|---|
| Android debug (test) | `exporter_apk.bat` | `G --headless --path godot --export-debug "Android" ../build/PortHorizonV2.apk` | `build/PortHorizonV2.apk` |
| Android release | `exporter_apk.bat release` | `./exporter_release.sh android` | `build/android/PortHorizon.apk` |
| Windows | `exporter_windows.bat` | `./exporter_release.sh` | `build/windows/PortHorizon.exe` |
| Linux | — | `./exporter_release.sh` | `build/linux/PortHorizon.x86_64` |

Android demande le SDK Android (chemin dans *Éditeur > Paramètres > Export > Android*) et, en release, **votre keystore**
(jamais dans le dépôt). Procédure complète et checklist de livraison : [`docs/RELEASE.md`](docs/RELEASE.md).

## Structure du dépôt
```
godot/                 projet Godot
  project.godot          réglages (version, fenêtre portrait, autoloads)
  export_presets.cfg     Android (debug), Android Release, Windows Desktop, Linux
  autoload/              Settings, GameState, Sim (pas fixe), Save (JSON versionné), Sfx
  sim/                   simulation pure (économie, flux, paliers, pêche) : testable sans rendu
  scripts/world/         diorama 3D, caméra, navires, camions, chantiers
  scripts/ui/            HUD, feuilles d'achat, tutoriel, panneau de débogage
  scripts/util/          arguments de ligne de commande (captures, triches de l'éditeur)
  data/                  équilibrage et contenu (*.json)
  assets/                modèles .glb (générés par blender/), icônes SVG, shaders
  tests/                 run_all, ui_smoke, sonde d'équilibrage, bots (exclus des exports)
blender/               génération des modèles 3D (scripts Python pour Blender)
docs/                  décisions, plans, ordres de mission, revues, journal, RELEASE.md
build/                 sorties d'export (ignoré par git)
jouer.bat              lancer le jeu depuis les sources (Windows)
exporter_*.bat/.sh     exports
```
Historique : [`CHANGELOG.md`](CHANGELOG.md). Décisions de conception : [`docs/DECISIONS.md`](docs/DECISIONS.md).
