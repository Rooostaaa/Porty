# Ordre de mission — lot E-Confiance (14/10/2026, soir)

> Pour le sous-agent **développeur senior Godot, piste Confiance (interface + sim d'affichage)**. Source : `docs/REVUE_LOT_D.md`
> (E1–E6 + mineurs UI/sim), validée par l'utilisateur (« oui continue et livre moi pour test humain après »).
> Point de reprise : commit local `3d2caae` (tout le lot D). **Une autre piste (E-Flux) travaille en même temps** : voir Coordination.

## Règles (impératives)
- Seul projet : `C:\Nadir\tycoon_V2`. **Aucun commit, aucun push** (le chef de projet commitera). Ne pas toucher `C:\Nadir\tycoon` ni `blender/`.
- Godot : `C:\Nadir\Godot\Godot.exe` via `Start-Process … -PassThru -NoNewWindow -Redirect…`, puis **`WaitForExit(ms)` borné et `Kill()`
  si dépassement** (des sessions se sont figées sur des commandes de plus de 10 min ; une graine de sonde par processus).
- Tests : `run_all` (196), `ui_smoke` (131, comme scène). Aucun contrôle retiré ; recalage noté au journal ; un contrôle par correction.
- Équilibrage : **sonde 4 graines inchangée** (au caractère près sur les temps de palier) sauf E3 (coût des aléas) qui ne doit pas
  bouger les temps de palier de plus de ±2 %.
- Captures `--fresh` uniquement, verrou `C:\Users\BEDJAO~1\AppData\Local\Temp\claude\C--Nadir-tycoon\8da43a4f-210d-4b6d-8673-65d93348718b\scratchpad\capture.lock`.
- Doc : section « Lot E — Confiance » à la suite de `docs/JOURNAL_PLAN_BAIE.md`, entrée dans `docs/DECISIONS.md` si choix de conception.

## Coordination avec E-Flux (en parallèle)
- **À toi** : `scripts/ui/*`, `autoload/sfx.gd`, `scripts/main.gd`, `scripts/world/camera_rig.gd` (E5 seulement), `sim/port_sim.gd`,
  `sim/hazards.gd`, `data/*.json`.
- **À E-Flux** : `scripts/world/*` sauf camera_rig (layout, diorama, traffic_view, ship_view, yard_view, crane_view).
- `tests/run_all.gd` / `ui_smoke.gd` partagés : nouvelles fonctions `test_e_confiance` / `_e_confiance_checks`, relire avant d'éditer.

## À faire
- **E1** Services facturés × interface (`hud.gd:1010-1016,1080`) : séparer dans le gain d'un achat la part « débit » de la part
  « services » (API dans `port_sim.gd` si besoin, sans changer les valeurs). Pastille d'Améliorer et « ★ MEILLEUR ACHAT » réservés aux
  achats qui se rentabilisent en < 10 min (ou < 2× la médiane du palier — choisis et note) ; si le débit ne bouge pas : « Portiques +6 % ·
  pas le goulot (+15 $/s de services) » en gris, jamais en vert « rentabilisé en 102 h ». Contrôle : au T3 (sauvegarde de bot), pastille
  ≤ nombre d'achats rentabilisés en < 10 min.
- **E2** Bouton Goulot (`hud.gd:1235`) : table goulot → bâtiment qui le règle (postes à quai → prochain quai ; parc → extension de parc ;
  gate → voie de gate / parking ; douane → bâtiment de douane ; etc., d'après les effets de `buildings.json`). S'il n'y en a pas
  d'abordable ou de disponible, l'amélioration du service ; sinon « GESTION ». Contrôle : « postes à quai » au T3 ne propose jamais le GNL.
- **E3** Aléas (`hazards.gd:83`) : coût sur le **revenu réel** (`income_per_min` ou équivalent), plafonné à ~25 % de la trésorerie ;
  « Suspendu (brouillard) » au lieu de « Inf s → Inf s » (`info.gd:88`, `port_sim.gd:568`) ; un service sous aléa n'est jamais le
  meilleur achat.
- **E4** Noms courts (`info.gd:18` `BUILDING_SHORT`) : dérivés du nom des bâtiments ou alignés (« PÔLE FROID », « DEUXIÈME VOIE »…),
  plus de « ᵉ » ; un seul nom par achat sur la carte, la pancarte et Gestion (« Allongement du quai » partout, ou l'inverse).
  Contrôle : pour chaque bâtiment, nom court cohérent avec le nom.
- **E5** Toucher de fermeture de feuille (`sheet.gd:174-180`, `main.gd:81-84`, `camera_rig.gd:152-160`) : le relâchement qui suit une
  fermeture ne doit jamais atteindre le monde (avaler le relâchement, et/ou remettre `_press_pos` hors écran quand l'entrée monde est
  coupée). Contrôle ui_smoke : fermeture par toucher sur un service → aucune action monde, aucune réouverture.
- **E6** Bandeaux sous feuille (`hud.gd:1724-1764`) : `_close_banner` respecte `_covered()` ; minuteur du bandeau suspendu quand il est
  masqué ; VOIR ouvre l'écran **avant** d'enchaîner le bandeau suivant ; `_cam_back` mémorise la vue du joueur (aussi quand Améliorer
  s'ouvre depuis le monde, `hud.gd:1381-1383` / `diorama.gd:1872-1874`).
- **Feuille et cérémonie** (rapides) : aléa en cours visible (pastille compacte) pendant une feuille à mi-hauteur ; cérémonie de palier :
  liste de 2–3 icônes « ce qui s'ouvre » + bouton VOIR qui cadre la zone, texte propre à chaque palier ; bulles du monde masquées sous
  les fenêtres ; couche de cérémonie sous `popup_layer` (`hud.gd:1816,1849`) ; pièces d'encaissement qui partent en arc **au-dessus**
  du texte (texte lisible 0,6 s), vraie icône de pièce 64 px.
- **Mineurs** : `last_tier_t` sauvegardé (sans changer de version si possible, sinon +1 avec migration) et `reset()` complet
  (`last_tier_t`, `_alert_*`) ; alerte gate/parc seulement après le chapitre du service ; barre de palier qui ne cite pas un objectif
  encore caché (Réputation) ; « fees » et « services » distingués dans Stats ; `service_fee_rate()` en cache (palier + somme des
  niveaux) ; `_burst_n` remis à zéro à chaque rafale ; cibles ≥ 96 px (onglets des feuilles, barre de palier, « POURQUOI ? »,
  « BÂTIMENTS ») + contrôle ; `bubbles.gd` : placement qui tient compte du rectangle utile, plus de `StyleBoxFlat.new()` par image ;
  volume enregistré au relâchement de la réglette (pas à chaque cran) ; `ui_smoke` n'écrit plus `user://audio.cfg` ; les trois
  contrôles toujours vrais (`ui_smoke.gd:1259,1313,1343`) vérifient réellement.

## Fin de piste
Tests verts, sonde 4 graines, captures `docs/captures/e_conf_*` regardées (T3 Améliorer, T3 HUD avec goulot postes à quai, aléa,
cérémonie), journal. Rapport : fait / non fait (raison), chiffres, captures, demandes à E-Flux.
