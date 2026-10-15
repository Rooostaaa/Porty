# Livraison d'une version — Port Horizon

Procédure pour publier une version (ici **2.1.0**). Chemins Windows : dépôt `C:\Nadir\tycoon_V2`, Godot `C:\Nadir\Godot\Godot.exe`.
Sous Linux : `G=/opt/godot/Godot_v4.7.1-stable_linux.x86_64`.

## 1. Checklist
- [ ] **Branche propre** : tout est commité, rien d'attendu en cours (`git status` vide).
- [ ] **Import** : `Godot --headless --path godot --import` sans erreur de script.
- [ ] **Tests verts** : `run_all.gd` (0 échec) et `ui_smoke.tscn` (0 échec). Aucun contrôle retiré pour passer.
- [ ] **Sonde d'équilibrage** sur 4 graines (`pacing_probe.gd -- --seeds=N --brief`, une graine par processus) : T2, T3 et fin
      dans la tolérance de `docs/JOURNAL_PLAN_BAIE.md`.
- [ ] **Captures** de contrôle (`--fresh --capture=… --delay=6`) : début de partie, T2, T3 (via `--load-sim`, binaire de l'éditeur).
- [ ] **Version** cohérente partout (voir § 2).
- [ ] **Exports** faits (§ 4) et lancés au moins une fois chacun : l'APK sur un vrai téléphone, l'exe Windows, le binaire Linux.
- [ ] **Débogage absent** des builds : F1 sans effet, pas de ligne « F1 » dans les Réglages, `--debug-money=1e9 --tier=3` ignorés.
- [ ] **Test sur appareil** (§ 5) fait.
- [ ] **CHANGELOG.md** à jour, puis **tag** (§ 6).

## 2. Version
| Où | Clé | 2.1.0 |
|---|---|---|
| `godot/project.godot` | `application/config/version` | `2.1.0` |
| `godot/export_presets.cfg` (Android, Android Release) | `version/name` | `2.1.0` |
| idem | `version/code` | `2` — **à augmenter à chaque APK publié** (Android refuse une mise à jour de code inférieur ou égal) |
| idem (Windows Desktop) | `application/file_version`, `application/product_version` | `2.1.0.0` |
| `CHANGELOG.md` | section | `## [2.1.0]` |

## 3. Keystore Android (release)
L'APK de debug est signé par la clé de debug de Godot. L'APK de **release** doit être signé par **votre** clé, qui ne doit
**jamais** entrer dans le dépôt (`*.keystore`, `*.jks` et `export_credentials.cfg` sont ignorés par git).

Créer la clé une fois (outil `keytool` du JDK, livré avec Android Studio) et la ranger hors du dépôt, avec une copie de secours :
```
keytool -genkeypair -v -keystore C:\Nadir\cles\porthorizon.keystore -alias porthorizon -keyalg RSA -keysize 2048 -validity 10000
```
**Perdre cette clé = ne plus jamais pouvoir mettre à jour l'application** chez les joueurs (et sur le Play Store). Noter le mot
de passe dans un gestionnaire de mots de passe.

Donner la clé à Godot, au choix :
- **variables d'environnement** (rien n'est écrit sur disque), avant `exporter_apk.bat release` :
  ```
  set GODOT_ANDROID_KEYSTORE_RELEASE_PATH=C:\Nadir\cles\porthorizon.keystore
  set GODOT_ANDROID_KEYSTORE_RELEASE_USER=porthorizon
  set GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=********
  ```
- **éditeur** : *Projet > Exporter > Android Release > Keystore > Release / Release User / Release Password*. Godot range ces
  valeurs dans `godot/.godot/export_credentials.cfg` (hors dépôt), jamais dans `export_presets.cfg`.

Le SDK Android est aussi nécessaire (*Éditeur > Paramètres de l'éditeur > Export > Android > Android SDK Path*, p. ex.
`%LOCALAPPDATA%\Android\Sdk`, avec `platform-tools` et `build-tools`).

Debug et release portent le même paquet (`com.nadir.porthorizon.v2`) mais **pas la même signature** : pour passer de l'un à
l'autre sur un téléphone, désinstaller d'abord (la partie locale est perdue).

Play Store : il exige un **AAB** (`gradle_build/export_format=1`), qui demande le gabarit de build Gradle
(*Projet > Installer le modèle de build Android*). Pas configuré dans cette version : l'APK release suffit pour une distribution directe.

## 4. Exports
Fermer l'éditeur Godot. Les modèles d'export 4.7.1 doivent être installés (*Éditeur > Gérer les modèles d'export*, ou l'archive
`Godot_v4.7.1-stable_export_templates.tpz` décompressée dans `%APPDATA%\Godot\export_templates\4.7.1.stable\`, sous Linux
`~/.local/share/godot/export_templates/4.7.1.stable/`).

| Preset | Commande | Sortie |
|---|---|---|
| `Android` (debug, test humain) | `exporter_apk.bat` | `build\PortHorizonV2.apk` |
| `Android Release` | `exporter_apk.bat release` (`install` en plus pour adb) | `build\android\PortHorizon.apk` |
| `Windows Desktop` | `exporter_windows.bat` | `build\windows\PortHorizon.exe` (PCK embarqué) |
| `Linux` | `./exporter_release.sh` (fait aussi Windows ; `android` en argument pour l'APK release) | `build/linux/PortHorizon.x86_64` |

Ce qui est exclu des exports (`exclude_filter` des quatre presets) : `tests/*`, la galerie d'assets (`scenes/gallery.tscn`,
`scripts/world/gallery.gd`) et le modèle du nuancier (`assets/models/swatch.glb`), qui ne servent qu'aux vérifications.

Sous Linux, contrôle rapide d'une build sans écran :
```
xvfb-run -a -s "-screen 0 1280x1024x24" ./build/linux/PortHorizon.x86_64 --rendering-driver opengl3 -- --fresh --capture=/tmp/x.png --delay=6
```
(`--fresh` et `--capture` restent disponibles dans les builds : ils n'écrivent pas la sauvegarde et ne trichent pas.)

## 5. Test sur appareil
- Installer l'APK release sur un téléphone réel (`exporter_apk.bat release install`, ou copier l'APK).
- Partie neuve : intro, Crique, Concession, premiers achats du terre-plein ; quitter (bouton accueil), revenir : la partie est
  reprise et les gains hors ligne sont crédités.
- Vérifier le portrait plein écran (mode immersif), la lisibilité du HUD, le son, la fluidité au T2.
- Windows : lancer l'exe sur une machine sans Godot ; redimensionner la fenêtre (le jeu reste en portrait, l'interface s'étire).
- Sauvegarde PC : `%APPDATA%\Godot\app_userdata\Port Horizon V2\save.json` (même dossier que `jouer.bat` : la partie en cours
  est retrouvée). Ne pas renommer `config/name` dans `project.godot` sans prévoir de migration : le dossier en dépend.

## 6. Tag
Après le commit de version (accord du propriétaire avant tout push) :
```
git tag -a v2.1.0 -m "Port Horizon 2.1.0"
git push origin v2.1.0
```
Joindre à la publication l'APK release, l'exe Windows et le binaire Linux (ils restent hors dépôt, dans `build/`).
