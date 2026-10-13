# PROMPT — Port Horizon (idle port tycoon) · Godot 4.7 + Blender 5.2

> **Utilisation :** ouvre une session Claude Code dans `C:\Nadir\tycoon`, puis colle ce fichier
> (ou écris : « Lis PROMPT_PORT_TYCOON.md et exécute-le en commençant par l'étape 0 »).
> Ferme l'éditeur Godot pendant que Claude travaille (il écrase `project.godot`).

---

## 0. Mission

Tu construis **Port Horizon** (nom de travail) : un **idle tycoon de terminal à conteneurs**, en **3D isométrique cartoon**,
au format **portrait façon mobile**. Le joueur dirige un petit quai de pêche décrépit et le transforme en mégaport automatisé.

- **Moteur de jeu :** Godot 4.7 (GDScript typé).
- **Décor et assets 3D :** générés par scripts Python dans **Blender 5.2** (CLI, sans interface), exportés en `.glb`.
- **Méthode :** *tranches verticales*. On n'élargit le contenu qu'une fois la tranche précédente jouable et amusante.
- **Langue :** textes du jeu en français. Identifiants de code en anglais. Commentaires en français.

Le cœur du plaisir est la **boucle du goulot d'étranglement** : le joueur *voit* quel maillon de la chaîne limite le flux,
l'améliore, et le goulot suivant apparaît. Toute mécanique ajoutée doit respecter les 4 règles de la section 3.13.

---

## 1. Environnement machine (vérifié)

| Élément | Chemin |
|---|---|
| Dossier projet | `C:\Nadir\tycoon` (vide au départ) |
| Godot 4.7.1 (console) | `C:\Nadir\Godot\Godot_v4.7.1-stable_win64_console.exe` |
| Godot (éditeur) | `C:\Nadir\Godot\Godot.exe` · `C:\Program Files\Godot\Godot.exe` (version à vérifier avec `--version`) |
| Blender 5.2 | `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` |
| Pipeline Blender existant (à réutiliser) | `C:\Nadir\Rush\blender\lib.py`, `build.py`, `preview.py` |
| Jeu de référence UI (style « jouet ») | `C:\Nadir\Rush\ruche-3d.html` |
| Modèles de cahier des charges | `C:\Users\Bedjaoui Info\Desktop\Game\CDC_JEU_VIERGE.md` |
| Config MCP Godot (à reprendre si utile) | `C:\Users\Bedjaoui Info\Desktop\Game\.mcp.json` (`@coding-solo/godot-mcp`) |

Disposition à créer :

```
C:\Nadir\tycoon\
  PROMPT_PORT_TYCOON.md
  docs\            UNIVERS.md, CDC.md, ref\ (captures de référence)
  blender\         lib.py (copié/adapté), palette.py, build_assets.py, preview.py, parts\*.py
  godot\           project.godot, autoload\, data\, sim\, scenes\, scripts\, assets\{models,fonts,audio}\, tests\
```

Commandes de référence (PowerShell) :

```powershell
$g = 'C:\Nadir\Godot\Godot_v4.7.1-stable_win64_console.exe'
$b = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
& $g --headless --path C:\Nadir\tycoon\godot --import                          # après ajout d'assets
& $g --headless --path C:\Nadir\tycoon\godot --script res://tests/run_all.gd    # tests de la simulation
& $b -b -P C:\Nadir\tycoon\blender\build_assets.py -- --out C:\Nadir\tycoon\godot\assets\models
& $b -b -P C:\Nadir\tycoon\blender\preview.py -- <feuille> <sortie.png>         # planche contact (Workbench)
```

> Si Godot affiche « no resource loaders » après un ajout d'images : l'import n'a pas tourné, relance `--import`.
> Ne suppose pas les noms de paramètres de l'API Blender 5.2 ni de l'exporteur glTF : **introspecte-les** avant usage.

---

## 2. Références de style et de méthode

- **Référence principale : *Idle Supermarket Tycoon* (Codigames, Android)** — observée sur la fiche Uptodown et ses captures (voir section 5 pour le détail).
  Description officielle : on démarre avec quelques rayons et peu de produits, on investit dans des **licences** pour vendre des produits plus chers,
  on ouvre de nouveaux rayons (boulangerie, boucherie, poissonnerie…), tout en gérant **salaires, places de parking et livraisons**, avec des **objectifs** à remplir.
  Le joueur dépose ses captures dans `docs/ref/` ; elles priment sur cette description.
- **Référence secondaire (à étudier plus tard) :** *Pocket Ships Tap Tycoon: Idle* (flotte et port maritime), cité comme alternative sur la même fiche.
- **Habillage de l'interface :** celui de la référence (barre haute saturée, cartes blanches, barres colorées), **pas** celui de *Ruche*. Police ronde, grasse et lisible
  (**Fredoka** ou équivalent libre, **Lilita One** possible pour les gros chiffres). Pas de texte contouré.
- **Méthode de travail de l'utilisateur :** cahier des charges, tranche verticale, périmètre explicite, 3 à 5 retours par lot (capture + ce qu'il faisait).

---

## 3. L'univers (bible à respecter et à faire vivre)

### 3.1 Le monde et le joueur
Archipel fictif de la **Mer d'Ambre**. Le joueur est le·la **directeur·rice du terminal** de *Port Horizon*, qui hérite du vieux quai n°1 d'un village de pêcheurs.
Ton : chaleureux, humoristique, jamais cynique. Aucune marque ni drapeau réel : armateurs, ports d'origine et pavillons sont **fictifs**
(ports : Nordhaven, Sakura Bay, Port Aurore, Cap Zéphyr, Rio Verde).

### 3.2 La vie d'un navire (le fil rouge, du début à la fin)

| # | Étape | Département | Agents | Ce qui limite le flux |
|---|---|---|---|---|
| 1 | Annonce d'escale, attente en rade | Capitainerie | Officier de port, planificateur d'escales | Places de rade, patience du navire |
| 2 | Pilotage, remorquage, accostage | Capitainerie | Pilotes, remorqueurs, lamaneurs | Vitesse de pilotage, météo (vent, brouillard) |
| 3 | À quai | Quais | Chef de quai | Nombre de postes, longueur, **tirant d'eau** |
| 4 | Formalités du navire et des marchandises | Douane et contrôles | Douaniers, inspecteurs sanitaires, officier de sûreté | Capacité d'inspection, politique de contrôle |
| 5 | Déchargement et chargement | Portiques | Grutiers | Mouvements/heure par grue, pannes |
| 6 | Transfert quai → parc | Parc et manutention | Conducteurs d'engins | Débit des engins |
| 7 | Stockage | Parc | Chef de cour, techniciens frigo | Capacité par zone, taux de remplissage |
| 8 | Sortie (camion, rail, barge) | Gate et hinterland | Agents de porte, dispatcheurs | Voies de gate, rendez-vous, rail |
| T | Transverse (T3+) | Maintenance, énergie, IT, HSE, commerce | Techniciens, ingénieurs | Usure, puissance électrique, système de pilotage |

### 3.3 Les cargaisons (code visuel obligatoire)

| Type | Contraintes | Valeur | Visuel |
|---|---|---|---|
| Standard (sec) | Aucune | Base | Conteneurs multicolores |
| Frigorifique | Prise électrique, température surveillée, durée de séjour courte | ×2,5 | Blanc/bleu givré, voyant de prise |
| Dangereux (IMO) | Zone isolée, empilage limité, inspection obligatoire | ×3 | Rouge/orange, losange de danger |
| Hors-gabarit | Aire plate dédiée, grue spécifique | ×4 | Plateau gris/jaune |
| Vide | Dépôt de vides, empilage haut, faible valeur | ×0,3 | Gris désaturé |

### 3.4 Les navires (nombres compressés pour l'idle ; 1 bloc visuel = N EVP)

| Classe | EVP par escale | Tirant d'eau | Poste requis | Palier |
|---|---|---|---|---|
| Caboteur | 120–300 | faible | quai simple | T1 |
| Feeder | 400–1 200 | moyen | quai standard | T1–T2 |
| Panamax | 2 500–4 500 | fort | quai profond + portique STS | T2–T3 |
| Post-Panamax | 6 000–9 000 | très fort | quai long + dragage | T4 |
| Porte-conteneurs géant (ULCV) | 14 000–20 000 | extrême | quai géant, grues super-portée | T5 |

Attributs d'une escale : armateur, mix de cargaison, fenêtre horaire, patience, état de conformité, humeur du capitaine.

### 3.5 Les armateurs (factions fictives)

| Armateur | Profil | Exige | Rémunère | Risque de fraude |
|---|---|---|---|---|
| Nordhaven Lines | Fiable, gros navires | Ponctualité | Bien | Faible |
| Sakura Bay Shipping | Frigo, électronique | Délais et températures | Très bien | Faible |
| Corsaire & Fils | Familial, caboteurs et feeders | Peu | Correctement, fidèle | Faible |
| Grand Large Cargo | Volume, bas coûts | Prix bas | Peu | **Élevé** |
| Chimex Maritime | Chimie, dangereux | Zone IMO, conformité stricte | Très bien | Moyen |

Chaque armateur a une **relation** (0–100) qui débloque des contrats et module la patience de ses capitaines.

### 3.6 Contrôles et conformité (règles)
- **La douane est l'État.** Le joueur finance la *capacité* (poste d'inspection, scanner, effectifs via redevance) et règle une **politique de contrôle** ;
  il ne corrompt, ne juge et ne saisit jamais lui-même. Les issues légales sont décidées par l'autorité.
- Politiques : Minimale, Standard, Renforcée, Totale. Plus on contrôle : moins de risque, plus de retard et de congestion.
- Méthodes (détection indicative) : documentaire ~15 %, scanner ~60 %, fouille physique ~95 %, maître-chien (bonus stupéfiants).
- Issues : conforme · anomalie mineure (retard) · **saisie** (réputation auprès des autorités ↑, relation armateur ↓) · amende · incident non détecté (rare, coûteux).
- Contrôles spéciaux : sanitaire et phytosanitaire (frigo alimentaire), matières dangereuses (IMO), sûreté (ISPS), poids vérifié.
- Les valeurs ci-dessus sont des **points de départ** à équilibrer.

### 3.7 Stockage et manutention (règles)
- Zones : standard, frigo (nombre de prises), IMO, hors-gabarit, vides ; entrepôt de groupage (T3).
- **Taux de remplissage** : rendement 100 % jusqu'à ~65 %, puis il chute (remaniements) : ~60 % à 90 %, ~30 % à 100 %. Jauge colorée dans l'UI.
- **Durée de séjour** : quelques jours gratuits, puis facturation croissante ; au-delà d'un seuil, conteneur « abandonné » → vente aux enchères (événement bonus).
- Engins par palier : grue mobile + chariots élévateurs (T1) → gerbeurs + tracteurs + portiques de cour (T2–T3) → cavaliers (T3) → véhicules automatiques (T4).
- Un jour portuaire = **90 s réelles** (réglable) : c'est ce qui rend la durée de séjour significative.

### 3.8 Agents et responsables
- **Agents** : effectif par département (affiché « 2/5 »), chacun coûte un salaire récurrent ; l'automatisation les remplace progressivement.
- **Responsables** : un par département, embauché une fois ; il **automatise** le département (le jeu tourne même hors-ligne). Personnages nommés, avec portrait :

| Responsable | Département | Palier |
|---|---|---|
| Capitaine Mathilde Roche | Capitainerie | T1 |
| Léon « Gros-Bras » Barbier | Quais | T1 |
| Yasmine Okafor | Portiques | T1 |
| Inspecteur Paul Delmas | Douane et contrôles | T2 |
| Nadia Benali | Parc et manutention | T2 |
| Tonio Ferrer | Gate et hinterland | T2 |
| Dr Inès Lambert | Qualité et sanitaire | T3 |
| Ingénieur Kenji Mori | IT et automatisation | T3 |

### 3.9 Économie
- **Revenus :** droits de port et pilotage (par escale), manutention (par EVP), stockage après jours gratuits, services frigo (par prise et par jour),
  frais d'inspection et de scanner, bonus de contrats.
- **Coûts :** salaires, maintenance, énergie, redevance de concession, amendes, intérêts (T3+).
- **Monnaies :** argent (principale) ; **Ambre** (rare, via missions et paliers : boosts, déblocage immédiat d'un responsable) ;
  réputation (étoiles, sert de condition) ; **Licences** (prestige, T4+).

### 3.10 Qualité et indicateurs (tableau de bord du directeur)
Attente moyenne en rade · occupation des quais · productivité (mouvements/h par grue) · remplissage du parc · durée de séjour moyenne ·
temps de passage d'un camion · taux de conformité · incidents et dommages · satisfaction par armateur · **réputation globale (1–5 étoiles)**.
Chaque indicateur doit avoir un effet *visible* sur le jeu (arrivées de navires, contrats disponibles, patience, amendes).

### 3.11 Aléas
| Événement | Déclencheur | Effet | Réponse du joueur |
|---|---|---|---|
| Vent fort | Météo | Portiques à l'arrêt | Attendre, ou payer pour sécuriser |
| Brouillard | Météo | Pilotage suspendu | Attendre ; la rade se remplit |
| Panne d'équipement | Usure | Un engin ou une grue à l'arrêt | Réparer (coût/temps), maintenance préventive |
| Grève | Moral bas, salaires | Gate ou quais à l'arrêt | Négocier (payer), ou subir |
| Contrôle surprise | Autorités | Audit de conformité | Être à jour |
| Alerte sanitaire | Frigo | Lot bloqué | Capacité d'inspection sanitaire |
| Pic saisonnier | Calendrier | Afflux de navires | Capacité en avance, boost « heures sup » |
| Conteneurs abandonnés | Durée de séjour | Vente aux enchères | Bonus d'argent |

### 3.12 Les paliers de progression (de l'humain vers l'automatisé)

| Palier | Nom | Débloque | Récit | MVP ? |
|---|---|---|---|---|
| T1 | Le Vieux Quai | Caboteurs, feeders, grue mobile, 1 quai, stock sur gravier, douane en cabane | Reprendre un quai à l'abandon | ✅ |
| T2 | Port régional | Quai 2, premier portique STS, parc bitumé, gate, frigo, rendez-vous camions, scanner mobile | Premiers armateurs sérieux | ✅ |
| T3 | Terminal national | Quais 3–4, scanner à portique, zone IMO, rail, portiques de cour, système de pilotage, groupage | Contrats nationaux | ✅ |
| T4 | Hub continental | Géants, automatisation, électricité à quai, port sec, transbordement | Le port tourne presque seul | ❌ |
| T5 | Mégaport mondial | Port intelligent, zone franche, réseau multi-ports, prestige | Concession mondiale | ❌ |

### 3.13 Règles de cohérence (toute nouvelle mécanique doit les respecter)
1. **Une cause réelle** : elle existe dans un vrai terminal (sinon on la rejette).
2. **Un goulot visible** : le joueur peut voir qu'elle limite le flux (jauge, file, couleur, bulle d'humeur).
3. **Un levier** : une amélioration ou une décision précise la débloque.
4. **Un visuel** : elle se voit dans le diorama (navire, engin, bâtiment, personnage, effet).

---

## 4. Boucle idle et mécaniques

- **Boucle courte (secondes)** : amarrer ou prioriser un navire, tapoter une carte, lancer un boost, résoudre un aléa.
- **Boucle moyenne (minutes)** : acheter un niveau d'un département, embaucher un responsable, accepter un contrat, ouvrir une zone.
- **Boucle longue (heures)** : franchir un palier de port, débloquer une infrastructure, construire la réputation avec les armateurs.
- **Cartes de département** : niveau, effet courant, effet suivant, coût, achat ×1 / ×10 / ×100 / max, jauge de palier.
  Coût de départ ~ `base × 1,15^niveau` (à équilibrer). Paliers ×2 aux niveaux 10, 25, 50, 100, puis ×5 aux niveaux 150, 200, 300, 400…
- **Boost « Heures sup »** : temporaire, avec recharge (pas de monétisation).
- **Hors-ligne** : rattrapage borné (ex. 8 h max), rendement réduit sans responsable, écran « Bon retour » avec le détail.
- **Prestige (T4+, hors MVP)** : ouvrir un nouveau port ; gagne des Licences (bonus permanent).
- **Explicabilité** : un registre central de **modificateurs** ; le joueur peut toucher un revenu et voir « pourquoi ×3,2 ».
- **Indicateur de goulot** : le département qui limite le flux est signalé en permanence (pastille rouge + conseil en une phrase).

### Correspondance avec *Idle Supermarket Tycoon* (à respecter à la lettre)

Le moteur de plaisir de ce genre de jeu, c'est **la file et l'attente, toujours visibles**. Ce n'est pas un détail d'interface.

| Supermarché | Port Horizon | Règle de jeu |
|---|---|---|
| Clients qui font la queue aux caisses | Navires en rade, camions devant la gate, lots en attente d'inspection, conteneurs en attente de grue | **Une file visible à chaque étape**, avec sa longueur affichée au-dessus du poste |
| Temps d'attente / patience | Barre de patience au-dessus de chaque navire et camion, 3 humeurs 😊 😐 😠 | Seuil dépassé : humeur ↓, bonus de rapidité perdu, puis départ furieux (réputation ↓) |
| Caisses | Quais, portiques, voies de gate, postes d'inspection | On en ajoute ; chacun a niveau, vitesse et effectif |
| Caissiers, personnel « 2/5 » | Agents par poste | Moins d'agents que de postes = poste ralenti (visible) |
| Rayons et produits : niveau, prix de base, prochain palier ×5 | Types de cargaison : niveau, valeur de base, prochain palier | Carte par type de cargaison, paliers aux niveaux 25/50/100… |
| « Clients servis / min » | « Navires / h » et « EVP / min » | Toujours affichés dans la barre haute et sur chaque carte |
| « Valeur totale du produit » | Valeur de la cargaison traitée | Sur la carte du département |
| Agrandir le magasin | Étendre le terre-plein, nouveaux quais, paliers de port | Acheter une zone fait apparaître de la place dans le diorama |
| Managers | Responsables | Automatisent le département |

**Règle de lisibilité :** l'attente se lit au premier coup d'œil. Jamais un chiffre seul : toujours *file + barre + humeur*.
Un navire qui attend trop longtemps change de couleur, s'agite, puis part ; un camion bloqué klaxonne ; un lot retenu clignote.

### Verbes du joueur (section critique du cahier des charges)

| # | Action | Interaction | Limite / règle |
|---|---|---|---|
| 1 | Acheter un niveau de département | Toucher la carte | ×1/×10/×100/max |
| 2 | Embaucher un responsable | Onglet Responsables | Une fois par département, coût élevé |
| 3 | Choisir le navire à accoster | Toucher un navire en rade | Tant que l'automatisation de la capitainerie n'est pas achetée |
| 4 | Régler la politique de contrôle | Sélecteur à 4 crans | Effets : risque, délai, congestion |
| 5 | Régler les tarifs | Curseur 70–150 % | Plus cher = moins de navires |
| 6 | Lancer « Heures sup » | Bouton | Durée limitée, recharge |
| 7 | Accepter / refuser un contrat | Onglet Contrats | Exige certaines capacités |
| 8 | Répondre à un aléa | Bandeau | Payer ou attendre |
| 9 | Débloquer une infrastructure ou un palier | Onglet Port | Conditions : cumul d'EVP + réputation |
| 10 | Déplacer la caméra | Glisser / pincer | Zone bornée selon le palier |

**Le joueur ne peut PAS :** construire librement (emplacements fixes), piloter un véhicule, perdre la partie (pas de game over : les échecs coûtent de l'argent et de la réputation),
ni trafiquer les contrôles.

---

## 5. Direction artistique et interface

- **Rendu** : 3D low-poly *sans texture*, couleurs par sommet, éclairage doux, ombres douces, légère correction colorimétrique ; palette limitée (~24 couleurs) dans `palette.json`
  partagé entre Blender, la 3D et l'UI. Silhouettes lisibles et proportions « jouet ».
- **Caméra** : orthographique, inclinaison ~35°, rotation 45°, déplacement et zoom bornés, tap sur un bâtiment ou un navire pour centrer et ouvrir son panneau.
- **Diorama** : le port est une tranche flottante (terre en couches, bords chanfreinés) qui s'étend à chaque palier ; eau stylisée avec écume au contact des quais.
- **Vie visuelle** : navires sur des courbes prédéfinies, remorqueurs, grues qui cyclent au rythme des mouvements/heure, conteneurs qui apparaissent et disparaissent,
  camions en boucle, train périodique, personnages avec bulles d'humeur, flottes de véhicules proportionnelles au niveau (plafonnées visuellement).
- **Portrait** : référence 1080×1920, étirement `canvas_items`, mode `expand`, zones de sécurité, cibles tactiles ≥ 96 px.

### Ce qui a été observé dans la référence (à reproduire en esprit, avec une identité maritime propre)

**Direction artistique**
- Vue **isométrique fixe, en portrait**, 3D low-poly en **aplats colorés** (pas de textures, pas de contours), lumière de plein jour, couleurs vives mais douces.
- Bâtiments **en coupe** : murs et toit ouverts pour voir l'intérieur (rayons, caisses, personnel). Transposer : hangars, capitainerie, hall d'inspection, gate montrés en coupe.
- Décor de **vie** autour : parking avec voitures, route avec marquages, lampadaires, pelouse, **sapins low-poly à facettes**. Transposer : camions, routes, grues, balises, rochers, herbe et arbres du littoral.
- Personnages minuscules, simples. **Bulles à anneau de progression** au-dessus du personnel et des clients (icône + jauge circulaire verte).
- Effets : petites icônes de billets qui s'envolent, halo lumineux sur le véhicule qui entre. Rien de chargé.

**Interface (portrait)**
- **Barre haute** bandeau indigo/violet : revenu **par minute** (icône billet verte), argent total, monnaie rare (gemme) avec bouton « + ».
- Pastille **« MANAGER : OFF / ON »** à gauche + 3 boutons carrés à droite : améliorations, statistiques, missions (badge « ! »).
- **Barre basse** : réglages, jeux, boost **×2** ; puis 3 grands boutons carrés (vidéo/boost, gestion, boutique).
- **Écrans plein cadre** en-tête indigo + flèche retour, **cartes blanches** aux grands coins arrondis, titres en violet, bouton gris « BUILD / CLAIM » avec le prix dessous.
- **Format des grands nombres** : `10,000` · `2,500,000` · `1,000B` · `1,000T`.

**Écran Gestion → onglet Bâtiments** : liste verticale ; un bâtiment par ligne (icône ronde, nom, description, bouton de construction avec prix).
Les bâtiments suivants sont **verrouillés** (nom en rouge) avec « construis d'abord le précédent » ; coût qui explose (10 000 → 2,5 M → 1 000 B → 1 000 T).

**Écran Gestion → onglet Statistiques** : barres arrondies colorées (**vert = argent, bleu = information, rouge = problème**) :

| Référence | Port Horizon |
|---|---|
| Gains par client (vert) | Gain moyen par escale |
| Clients en train d'acheter (bleu) | Navires en cours de service |
| Capacité clients /min (bleu) | Capacité de traitement EVP/min |
| **Utilisation du parking 100 % (rouge)** | **Taux de remplissage du parc** et **voies de gate saturées** |
| **File moyenne aux caisses (bleu)** | **File moyenne devant les portiques** |
| **Temps d'attente moyen en caisse, en secondes (rouge)** | **Temps d'attente moyen d'un navire en rade, en secondes** |

Sous les barres : une ligne par département avec **badge de niveau** (ex. « 37 »), nom, valeur, profit par minute, capacité par minute.

**Missions** : carte avec titre, énoncé (« Servir 20 clients du rayon fruits »), barre 3/20, récompense en monnaie rare, bouton **CLAIM** grisé tant que non atteint.
Transposer : « Décharger 200 EVP frigo », « Faire 5 escales sans navire furieux », « Faire passer 50 camions à la gate en 2 jours ».

**Boucle d'investissement observée** : licences (produits plus chers) → nouveaux bâtiments → capacité clients ↑ → **le parking sature** → agrandir → etc.
Le *parking* de la référence est exactement le rôle du **parc à conteneurs et de la gate** : une ressource d'espace qui plafonne tout le reste et qu'il faut afficher en rouge.

### Structure d'écran retenue pour Port Horizon
- **Barre haute** : revenu/min · argent · monnaie rare (**Ambre**, gagnée par missions et paliers, jamais achetée) · réputation en étoiles.
- **Gauche** : pastille « Responsables : OFF/ON » (automatisation globale) ; **droite** : Améliorations · Statistiques · Missions.
- **Vue 3D** au centre ; **barre basse** : réglages · boost ×2 « Heures sup » · Gestion · Contrats.
- **Onglets de Gestion** : Bâtiments (zones, une à la suite de l'autre), Statistiques, Responsables, Port (paliers).
- **Grands nombres** : suffixes K, M, B, T, puis aa, ab… ; flottants 64 bits suffisent, pas de bibliothèque.
- **Son** : placeholders synthétisés (clic, achat, cloche, klaxon, montée de palier) ; interrupteur muet. Pas de musique en MVP.

---

## 6. Architecture Godot

- **Règle d'or : la simulation est séparée de l'affichage.** `sim/` ne touche aucun nœud ; la vue s'abonne à des signaux. Cela rend le jeu testable en mode headless.
- **Données pilotées** : `data/*.json` (navires, cargaisons, armateurs, départements, responsables, paliers, aléas, contrats). Aucune valeur d'équilibrage en dur dans le code.
- **Pas fixe** : tick de simulation à 0,25 s ; le rattrapage hors-ligne utilise un pas agrégé (pas de boucle de 8 h à 4 Hz).
- **Modèle de flux** : navires = objets discrets ; marchandises = quantités (EVP) par étape avec capacité/s ; la vue représente des « blocs » (1 bloc = N EVP).
- **Conteneurs affichés** via `MultiMeshInstance3D` avec couleurs par instance (un seul maillage `container`).
- **Autoloads** : `GameState` (état + signaux), `Sim` (tick), `Save` (JSON versionné dans `user://`, écriture atomique, migration), `Settings`.
- **Sauvegarde** : auto toutes les 15 s, version de schéma, copie de secours.
- **Rendu** : renderer **Mobile** (compatible Android plus tard).
- **Outils de debug (F1)** : +argent, temps ×10/×100, forcer un aléa, forcer un palier, afficher les flux.
- **Tests** (`godot/tests/`, headless) : conservation des EVP (entrées = sorties + stock), aucun stock négatif, déterminisme à graine fixe,
  absence d'impasse (toujours un achat atteignable), et un script d'**équilibrage** qui affiche la chronologie jusqu'à la fin du MVP.
- GDScript **typé**, signaux plutôt que références croisées, scènes petites et composables, pas de « god object ».

---

## 7. Pipeline Blender → Godot

1. **Réutilise l'approche de `C:\Nadir\Rush\blender\lib.py`** (classe `Model` : sphère, ico, cylindre, boîte, tour de révolution, tube, couleurs par sommet via `bmesh`).
   Copie-la dans `blender/lib.py` et **remplace l'export base64 par un export glTF** : un `.glb` par asset dans `godot/assets/models/`.
2. **Palette** : `blender/palette.py` lit/écrit `palette.json`. Aucune couleur écrite à la main dans les modèles.
3. **Couleurs** : attention sRGB/linéaire. Vérifie par un *swatch* comparé entre Blender et Godot (réglage `vertex_color_is_srgb` ou conversion à l'export).
   Sur import, les matériaux doivent utiliser la couleur de sommet comme albédo ; sinon, matériau partagé `vcol_toon.tres` en surcharge.
4. **Échelle et grille** : 1 unité Godot = 1 m « jouet » ; conteneur 40 pieds = 4,0 × 1,3 × 1,3 u ; **module de sol 6 × 6 u** ; quai en segments de 12 u.
5. **Pièces séparées pour animer** (aucun rig, tout est animé dans Godot) : portique = `base`, `flèche`, `chariot`, `spreader` ; camion = `cabine`, `remorque` ; grue mobile = `base`, `flèche`, `crochet`.
6. **Emplacements** : les navires exportent des *empties* `slot_###` (positions de baies) → JSON compagnon lu par Godot pour poser les blocs de conteneurs.
7. **Budgets** : conteneur < 100 tris · véhicule < 600 · grue < 1 500 · navire < 2 500 · bâtiment < 1 200 · personnage < 200 · scène complète < 300 k.
8. **Planches contact** : `preview.py` rend chaque lot en Workbench (comme celui de Rush) ; **tu regardes l'image avant d'importer** et tu corriges.
9. **Scène « galerie »** dans Godot : tous les assets alignés à l'échelle réelle, pour vérifier tailles, couleurs et ombres.

### Liste d'assets du MVP (T1 → T3)

| Famille | Assets |
|---|---|
| Terrain | tranche de diorama (modulaire), segments de quai A/B/coin, bollard, défense de quai, dalle gravier, dalle bitume, marquages, clôture, lampadaire, route droite/virage, voie ferrée, rochers, arbres, phare |
| Bâtiments T1 | capitainerie (cabane + mât radio), cabane de douane, hangar |
| Bâtiments T2 | tour de contrôle, guérite de gate + barrières, rack frigo (prises), bureaux, atelier, bureau de douane |
| Bâtiments T3 | portique scanner, hall d'inspection, zone IMO (clôture + panneaux), terminal rail, poste électrique, centre IT, entrepôt de groupage |
| Engins | grue mobile portuaire, portique STS (4 pièces), gerbeur, tracteur + châssis, portique de cour (RTG), cavalier, chariot de vides, camion (cabine + remorque), locomotive, wagon, remorqueur, pilotine, fourgon |
| Navires | caboteur, feeder, panamax (+ slots) |
| Conteneurs | 20', 40', 40' frigo (groupe), plateau (hors-gabarit) |
| Personnages | docker, grutier, douanier, inspecteur, responsable (costume) — variantes de couleur |
| Accessoires | cônes, barils, palettes, mâts, panneaux |

---

## 8. Plan de travail (jalons, critères de fin, vérifications)

| Jalon | Contenu | Critère de fin |
|---|---|---|
| **0 — Cadrage** | Écris `docs/UNIVERS.md` (≤ 4 pages, à partir de la section 3) et `docs/CDC.md` au format `CDC_JEU_VIERGE.md` adapté à l'idle. Liste **uniquement** les questions bloquantes. | Fichiers écrits ; tu continues sans attendre sauf blocage |
| **1 — Squelette** | Projet Godot (portrait, renderer Mobile, autoloads, dossiers, polices), import headless OK | `--headless --quit` sans erreur ni avertissement |
| **2 — Kit Blender T1** | Palette, `lib.py` adapté, assets T1, planche contact, export `.glb`, scène galerie | Image examinée par toi ; assets visibles dans la galerie avec les bonnes couleurs |
| **3 — Simulation** | `sim/` complet pour la chaîne rade → quai → douane → portique → parc → gate, tests, script d'équilibrage | Tests verts ; chronologie imprimée |
| **4 — Diorama vivant** | Navires, grues, conteneurs, camions, bulles d'humeur reliés à la simulation | Capture montrant un navire déchargé et un goulot visible |
| **5 — Interface** | Barre haute, cartes, responsables, contrats, aléas, indicateur de goulot, tooltips « pourquoi » | Un joueur comprend quoi acheter sans explication |
| **6 — Contenu T2 et T3** | Nouveaux bâtiments/engins/navires, nouvelles règles, sauvegarde, hors-ligne | Parcours T1 → fin T3 jouable ; équilibrage dans les cibles |
| **7 — Finition** | Jus (nombres flottants, secousses, particules), sons placeholders, écran de fin de MVP | Retours de l'utilisateur intégrés |

**Après chaque jalon :** lance réellement le jeu, capture l'écran, lis les journaux, puis rends compte honnêtement (ce qui marche, ce qui échoue, ce qui n'a pas été testé).
**N'annonce jamais « ça marche » sans l'avoir exécuté.** L'utilisateur joue ensuite et renvoie 3 à 5 retours (capture + ce qu'il faisait).

---

## 9. Cibles d'équilibrage (à vérifier par simulation)

| Mesure | Cible |
|---|---|
| Premier achat | < 20 s |
| Prochain achat abordable (début) | toutes les 15–40 s |
| Premier responsable embauché | 3–4 min |
| T1 → T2 | 8–12 min de jeu actif |
| T2 → T3 | 35–50 min |
| Fin du MVP (fin T3) | 1 h – 1 h 30 |
| Rendement hors-ligne | 50 % sans responsable, 100 % avec |
| Impasses | aucune : toujours un achat atteignable |

---

## 10. Hors périmètre (MVP)

Monétisation, publicités, achats intégrés · multijoueur, classements · marques, drapeaux ou entreprises réels · construction libre type city-builder (emplacements fixes uniquement) ·
pilotage manuel des véhicules · pathfinding réaliste des navires (courbes prédéfinies) · musique originale · localisation autre que le français · export Android (rester compatible seulement) ·
paliers T4 et T5, prestige · cycle jour/nuit (bonus).

---

## 11. Priorités (on coupe en partant du bas)

1. **Indispensable** : chaîne complète rade → quai → douane → parc → gate avec goulots visibles, cartes d'amélioration, responsables, sauvegarde, diorama vivant.
2. **Important** : T2 et T3, aléas, contrats, hors-ligne, tableau de bord, politique de contrôle et tarifs.
3. **Bonus** : jus avancé, sons, jour/nuit, prestige, T4.

---

## 12. Règles de collaboration

- Pose **uniquement les questions bloquantes** ; pour le reste, choisis, applique, et dis-le en une ligne.
- Garde les décisions importantes dans `docs/` (court), pas dans la conversation.
- Propose d'initialiser un dépôt git local (un commit par jalon) pour pouvoir revenir en arrière.
- Avant de réécrire un fichier de l'utilisateur, lis-le. Ne touche pas à `C:\Nadir\Rush` ni à `C:\Users\Bedjaoui Info\Desktop\Game` (lecture seule).
- Vérifie les chemins et versions listés en section 1 avant de t'y fier ; signale tout écart.
- Réponds en français, de façon concise : résultat, preuve, prochaine étape.
