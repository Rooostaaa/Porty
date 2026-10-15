# Historique des versions

Détails et mesures : `docs/DECISIONS.md` et `docs/JOURNAL_PLAN_BAIE.md`.

## [2.1.0] — 15/10/2026
Première version livrable.
- **Lot G2 « Le Terre-plein : le premier navire à la main »** : après la Concession, la friche s'équipe achat par achat
  (terrassement, quai n°1, cabane de douane, piste et barrière, grue mobile, parc) ; on accoste, tamponne et laisse passer
  les camions à la main, puis Léon, Paul et Tonio prennent le relais après 5 gestes ; noms de métier (Arrivées, Accostage,
  Déchargement, Douane, Stockage, Sortie camions) ; tutoriel réécrit. Premier camion 4 min après la Concession, T2 vers 13 min.
- Correctifs : une partie neuve sautait la Crique ; le port ouvrait pendant la dissolution des nuages ; conteneurs noirs
  avec le rendu OpenGL ; plantage au démarrage d'une capture.
- Version 2.1.0 (nom du projet et dossier de sauvegarde PC inchangés : `Port Horizon V2`).
- Presets d'export : Android debug, **Android release** (keystore fourni par l'utilisateur), **Windows** (exe autonome),
  **Linux** ; tests, galerie et nuancier exclus des builds.
- Scripts `exporter_apk.bat [release] [install]`, `exporter_windows.bat`, `exporter_release.sh`.
- Documentation : `README.md`, `docs/RELEASE.md`, ce fichier.

## Lots de développement (V2, 12–15/10/2026)
- **Tranches 1 à 3** : boucle idle complète (départements, licences, paliers, prestige « Nouvelle concession », missions),
  monde 3D (terre ferme, gestes manuels, tutoriel, ambiance) ; début de partie doux (petits navires, révélation progressive).
- **Chantier C et écarts ISM** : commerce et armateurs, Capitainerie qui pilote, licences plafonnées par palier, paliers nommés,
  statistiques.
- **Lot A** (Blender) : direction visuelle D sur tout le port (équipements de quai, bateaux de pêche, bouées, mobilier).
- **Lot B** (Godot) : rendu, cadrage, environnement.
- **Plan de la baie, C1–C7** : zones, trajets et chapitres ; corrections des revues (coques, bouées, feux, rade pleine) et de
  la revue de code.
- **Lot D** : port réorganisé (circulation à droite, douane côté sortie, pôle nautique, passe est, gare), interface mobile
  (feuille d'achat, HUD, cérémonies, audio mixé), rythme (services facturés, révélations espacées).
- **Lot E** : interface honnête (conseils `Advice`, gains débit / services séparés) ; flux (camions, règles de passage des
  navires, train). Premier APK de test humain.
- **Lot F** : modèles de la crique, des chantiers et de la forêt ; navires et défilement (F1) ; le golfe et le départ de rien
  avec chantiers (F2) ; acte 0 de pêche (F3).
- **Lot G** : modèles de la Crique complète, de la marina, des nuages et du terre-plein ; chapitre 1 « La Crique » (G1 :
  places, services, Marcel, Concession à 500 $, nuages dissous à la bascule) .
