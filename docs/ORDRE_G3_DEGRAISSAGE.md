# Ordre de mission — lot G3 « Dégraisser : trois boutons, moins de systèmes » (15/10/2026)

> Pour le sous-agent **développeur senior Godot**, **après la livraison et la vérification de G2**. Source : `docs/CADRAGE_DEBUT.md`
> § 8 (tableau système par système, validé « reporter / supprimer / fusionner »), § 8.3 (règle des trois boutons) et § 12 Q7.
> Méthode validée : **retirer de l'interface d'abord, nettoyer le code ensuite** (après le test humain), pour pouvoir revenir en arrière.

## Règles (impératives)
Celles de `docs/ORDRE_G1_CRIQUE.md`. Paliers : étape 0 (note : liste de tout ce qui est touché, fichier par fichier, et des contrôles
qui vont tomber), G3-a (interface), G3-b (révélations et HUD), G3-c (captures, APK). **Exception à la règle « aucun contrôle retiré »** :
les contrôles des écrans supprimés sont retirés, **listés au journal avec la raison**, et remplacés par un contrôle « cet écran
n'existe plus / n'apparaît pas avant le T2 ». La sonde ne bouge pas (±2 % : rien ici ne touche l'économie).

## 1. Ce qui sort de l'interface (la simulation garde ses valeurs par défaut)
| Système | Action | Détail |
|---|---|---|
| Politique de douane (4 crans) | **supprimer** | plus d'onglet ; la simulation reste sur « Standard » ; aucune révélation, aucun conseil n'en parle |
| Tarifs (curseur 70–150 %) | **supprimer** | même chose, 100 % |
| Onglet Gestion → Port | **supprimer** | il ne contient plus que les deux ci-dessus |
| Contrats | **fusionner dans MISSIONS** | plus de feuille ni de bouton Contrats ; au T2, la feuille MISSIONS a une seconde section « Demandes des armateurs » (les contrats actuels, mêmes règles : un par armateur, prime + fidélité) |
| Commerce (feuille à 3 volets) | **réduire** | la feuille disparaît ; la **mécanique reste** : les affiches/annonces deviennent une carte à niveaux « Publicité » dans AMÉLIORER (révélée en fin de T1, règle actuelle du chapitre Commerce) ; le démarchage des armateurs et les lignes régulières deviennent un onglet « Armateurs » de la feuille RESPONSABLES, au T2 |
| Aléas | **reporter au T2, garder 3** | brouillard (Arrivées), vent (Déchargement), panne (grue) ; grève, contrôle surprise, pic saisonnier, enchères : données conservées, jamais tirées (`hazards.gd`, indicateur) |
| Licences de cargaison | **reporter au T2, renommer « Cargaisons »** | plus rien au T1 |
| Réputation ★ | **reporter au T2** | masquée sur le HUD avant le T2 (elle ne conditionne que le passage au T3) |
| Statistiques | **reporter au T2, dans Réglages** | plus d'onglet à part |
| Heures sup ×2 | **garder, dès le premier responsable** (fait en G1) | — |
| Ambre, Missions, Paliers, Nouvelle concession | **garder** | la première mission (Concession) explique l'Ambre |

## 2. La règle des trois boutons (§ 8.3)
Barre basse au T1 : **AMÉLIORER · RESPONSABLES · MISSIONS**, plus Réglages (⚙) et Heures sup une fois révélé.
- **AMÉLIORER** : **une seule liste**, ordre du processus (Arrivées · Accostage · Déchargement · Douane · Stockage · Sortie camions,
  puis Publicité, puis Cargaisons au T2), **le prochain bâtiment en tête de liste** (une seule carte de bâtiment visible à la fois,
  comme en G2), la Crique en bas sous son titre. L'onglet Gestion → Bâtiments **disparaît** (tout bâtiment s'achète ici).
- **RESPONSABLES** : la feuille Gestion, renommée, réduite à l'onglet Responsables (+ Armateurs au T2). Plus d'onglet Bâtiments ni Port.
- **MISSIONS** : missions, et au T2 les demandes des armateurs.
- Le bouton Goulot / AGIR existant reste (il mène à AMÉLIORER sur la bonne carte).

## 3. Révélations (`unlocks.json`, § 8.2 du cadrage)
Réécrire la liste pour qu'elle soit, dans l'ordre : encaisser · Places · Services à quai · Marcel · Missions · Concession (G1) ·
accoster · tamponner · laisser passer · Léon · Paul · Tonio · Déchargement · Stockage · Heures sup (G2) · Publicité (fin T1) · puis au
T2 : Arrivées, Cargaisons, Armateurs, Demandes des armateurs, Réputation, Aléas, Statistiques. Jamais deux révélations à moins de
45 s ; chaque texte nomme le geste ou le métier que le joueur vient de faire, jamais un « système ». Supprimer les révélations
« Gestion », « Contrats », « Commerce », « Licences » sous leur forme actuelle.

## 4. HUD
Avant le T2 : argent, revenu/min, pastille de gain, barre de palier (dès la première carte à niveaux du port), bandeau de mission,
trois boutons, ⚙, Heures sup. Rien d'autre : pas d'étoiles, pas de badge Contrats, pas de bouton Commerce, pas d'aléa. Vérifier en
portrait et en paysage.

## 5. Nettoyage différé (ne pas faire dans ce lot)
Lister au journal, pour après le test humain : code mort de `commerce_sheet.gd`, onglet Port de `manage_sheet.gd`, politiques et
tarifs dans `port_sim.gd`, quatre aléas, contrôles associés.

## Fin de lot
Tests verts (nombre avant/après, contrôles retirés listés avec raison, contrôles ajoutés : trois boutons au T1, aucune feuille
supprimée accessible, ordre de la liste AMÉLIORER, Demandes des armateurs dans MISSIONS au T2, onglet Armateurs au T2, aléas
limités à 3 et jamais avant le T2), sonde inchangée (±2 %), captures `docs/captures/g3_*` regardées (HUD T1 portrait et paysage,
AMÉLIORER à 3 moments, RESPONSABLES, MISSIONS au T1 et au T2, Réglages avec Statistiques), journal § « Lot G3 », DECISIONS,
**APK réexporté**, puis `docs/GUIDE_TEST_30MIN.md` (guide du test humain des 30 premières minutes, sur le modèle de
`GUIDE_TEST_10MIN.md`). Rapport : fait / non fait (raison), chiffres, captures.
