# Ordre de mission — lot D-Éco : rythme et récompense (14/10/2026)

> Pour le sous-agent **développeur senior Godot, économie / rythme**. Lancé **après** les pistes D-Monde et D-UI (elles ne touchent pas
> à l'équilibrage). Source : `docs/REVUE_CRITIQUE_PORT.md` (axe 3, mesures ; top 4 et top 5), validée en bloc par l'utilisateur.

## Règles (impératives)
- Seul projet : `C:\Nadir\tycoon_V2`. **Aucun commit, aucun push.** Ne pas modifier `blender/`, ni `scripts/world/*` ni `scripts/ui/*`
  sauf un affichage indispensable (le noter).
- **Prototyper dans une copie du projet** (scratchpad) avec `tests/pacing_probe.gd` (`--seeds=1,2,3,4`, `--set` / `--mul` pour des
  essais parallèles sans toucher aux fichiers), puis reporter dans le vrai projet. Valeurs dans `godot/data/*.json`.
- Godot : `C:\Nadir\Godot\Godot.exe` via `Start-Process … -PassThru -NoNewWindow -Redirect…` puis `.WaitForExit()`.
- Tests `run_all` / `ui_smoke` verts, aucun contrôle retiré (recalage noté au journal). Si le format de sauvegarde change : version +1
  avec migration. Le début est très sensible à l'argent gratuit (primes ≤ 45 s de revenu réel).
- Doc : `docs/ANALYSE.md` § 15 (essais et mesures), `docs/DECISIONS.md` entrée « Rythme (lot D) », section au journal.

## Cibles (mesurées sur 4 graines, moyenne ±5 %, chaque graine ±15 % sauf mention)
Garder : 1er achat ≤ 5 s ; T1 → T2 ≈ 12–13 min ; durée du T2 ≈ 28–30 min ; fin du MVP 1 h 15 – 1 h 30 (corriger au passage la graine 3,
aujourd'hui −11,1 %).
Nouveau :
1. **Rentabilité médiane du meilleur achat ≤ 3 min** au T1 et au T2 (aujourd'hui 4 min 53 / 7 min 14) ; ≤ 15 % des instants sans achat
   rentable < 5 min. Piste : un service hors goulot rapporte un minimum (part de revenu de base par niveau) au lieu de 0.
2. **Revenu T2** : à +3 min ≤ ×6, à +10 min ≤ ×80 (aujourd'hui ×14 / ×331).
3. **Entrée du T3** : plus de baisse (revenu à +1 min ≥ revenu à −1 min), trou d'achat ≤ 90 s (aujourd'hui 2 min 19).
4. **Barre de palier visible dès le chapitre 1** (sortir `progress` de la chaîne `unlocks.json:22`, au plus tard avec `dept_customs`).
5. **Révélations espacées** : `reveal_gap_min` 45–60 s, aucune révélation dans les 60 s qui suivent un passage de palier ; contrôle
   « au plus 4 bandeaux en 6 min autour du T2 ».
6. **Carte Goulot pas rouge en permanence** : un goulot « normal » (il y en a toujours un) n'est pas un état d'alerte ; rouge seulement
   si un service est bloqué / saturé. À régler avec la logique d'analyse (`_compute_analysis`) — l'affichage est déjà fait par D-UI.

## Fin du lot
Sonde 4 graines dans les cibles (tableau avant / après au journal), tests verts, APK réexporté (verrou `scratchpad\capture.lock`),
rapport final : cibles tenues / non tenues (raison), valeurs changées, contrôles ajoutés.
