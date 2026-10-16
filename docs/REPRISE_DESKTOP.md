# Reprise sur Desktop — état au 16/10/2026

## Où récupérer
- Dépôt : https://github.com/Rooostaaa/port-Tycoon — branche `claude/jolly-meitner-1h4twd` (copie aussi dans `Rooostaaa/Porty`, branche `v3-en-cours`).
- `git clone -b claude/jolly-meitner-1h4twd https://github.com/Rooostaaa/port-Tycoon.git C:\Nadir\tycoon_V3`

## Points stables
- `1002c80` : release 2.1.0 + lot H1 (Crique : services sur l'eau, anneau de service, pêche/plaisance séparées) + brume animée. Tests : run_all 254/254, ui_smoke 183/183.
- `0b9800f` : idem + plan H2 sur papier (`godot/tests/h2/`, rien dans le jeu).

## En cours (dernier commit de la branche, NON STABLE)
- Lot H2-a « darses en peigne » interrompu en plein travail (crédit cloud). Le jeu peut être cassé sur ce commit : relancer les tests.
- À lire pour reprendre : `docs/ORDRE_H2_DARSES.md` (ordre + décisions de l'utilisateur), `docs/JOURNAL_PLAN_BAIE.md` § « Lot H2 » (où on en est).
- Décisions validées : 4 postes ; parcelles sur le front du port seulement (option A) ; piquets et corde (corde dorée pour la prochaine) ; navires en marche arrière avec remorqueur ; brise-lames est reculé au large et devenu l'achat T3 « Digue du large » (prérequis des panamax en D3, réduit les aléas météo) ; deux boutons caméra « Vue du port » et « Parcelles » au lieu d'élargir le dézoom.
- Reste : H2-a (darses en jeu), H2-b (parcelles), H2-c (calage, captures, docs), puis APK.

## Outils
- Tests : `run_all.gd` et `ui_smoke.tscn` (un à la fois), sonde `pacing_probe.gd -- --seeds=N --brief` (4 graines).
- Exports : `exporter_apk.bat [release]`, `exporter_windows.bat`.
