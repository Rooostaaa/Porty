# Fiche jeu — Port Horizon (idle tycoon portuaire)

## 1 Identité
| Champ | Réponse |
|---|---|
| Nom | Port Horizon (nom de travail) |
| Genre | Idle tycoon de terminal à conteneurs |
| Pitch | Un·e directeur·rice de port transforme un vieux quai de pêche en terminal national en débloquant, un par un, les goulots de la chaîne navire → camion. |
| Références | Idle Supermarket Tycoon (Codigames) ; Pocket Ships Tap Tycoon (plus tard) |
| Vue | 3D isométrique orthographique (inclinaison 35°, rotation 45°) |
| Résolution | Portrait 1080×1920, `canvas_items` + `expand` |
| Support | Souris sur PC, tactile (Android plus tard) |

## 2 Verbes du joueur
| # | Action | Interaction | Limite / règle |
|---|---|---|---|
| 1 | Acheter un niveau de département | Toucher la carte (Améliorations) | ×1 / ×10 / ×100 / max |
| 2 | Améliorer un type de cargaison (licence) | Carte cargaison | Débloqué par palier/bâtiment |
| 3 | Embaucher un responsable | Gestion → Responsables | Une fois par département |
| 4 | Choisir le navire à accoster | Toucher un navire en rade | Sans responsable Capitainerie ; sinon automatique |
| 5 | Régler la politique de contrôle | Gestion → Port, 4 crans | risque ↔ délai |
| 6 | Régler les tarifs | Curseur 70–150 % | plus cher = moins de navires |
| 7 | Lancer « Heures sup » | Bouton ×2 | 60 s, recharge 5 min |
| 8 | Accepter un contrat | Contrats | un à la fois par armateur |
| 9 | Répondre à un aléa | Bandeau | payer ou attendre |
| 10 | Construire un bâtiment / franchir un palier | Gestion → Bâtiments / Port | séquentiel ; conditions EVP + réputation |
| 11 | Réclamer une mission | Missions | Ambre |
| 12 | Déplacer / zoomer la caméra | Glisser / molette / pincer | bornée par palier |

**Le joueur ne peut PAS** : construire librement, piloter un véhicule, perdre (pas de game over), trafiquer les contrôles.

## 3 Chiffres clés (points de départ, tous dans `godot/data/*.json`)
| Paramètre | Valeur |
|---|---|
| Jour portuaire | 90 s |
| Tick simulation | 0,25 s |
| Coût d'un niveau | `base × 1,15^niveau` (départements), `× 1,2^niveau` (licences) |
| Effet d'un niveau | département +15 %/niv., ×2 aux niv. 10, 25, 50, 75, 100… ; licence +25 %/niv., ×2 tous les 10 niv. (voir DECISIONS.md) |
| Rendement du parc | 100 % jusqu'à 65 %, 60 % à 90 %, 30 % à 100 % |
| Patience d'un navire | 45–90 s selon armateur, relation, réputation |
| Hors-ligne | 8 h max ; 50 % sans responsable → 100 % avec tous |

## 4 Caméra
Orthographique, glisser pour déplacer, molette/pincement pour zoomer, bornes qui s'élargissent avec le palier.
Toucher un navire ou un bâtiment ouvre son panneau.

## 5 « Ennemis » = goulots et aléas
Le flux est limité par le maillon le plus lent : rade, pilotage, quais, douane, portiques, engins, parc, gate.
Le goulot est signalé en permanence (pastille rouge sur la carte + anneau rouge dans le diorama + conseil d'une phrase).
Aléas : vent fort, brouillard, panne, grève, contrôle surprise, pic saisonnier, conteneurs abandonnés (enchères).

## 6 Ressources
Argent (principal) · Ambre (missions, paliers ; jamais achetée) · Réputation 1–5 ★ · Relations armateurs 0–100.

## 7 Victoire / défaite
Pas de défaite. Fin du MVP : franchir la dernière étape de T3 (« Concession nationale ») → écran de fin, la partie continue.

## 8 Structure
| Palier | Nouveautés | Durée visée (cumul) |
|---|---|---|
| T1 Le Vieux Quai | petits porte-conteneurs, puis caboteurs (quai allongé), douane, feeders (dragage) ; grue mobile, 1 quai, gravier | 0 → 13 min |
| T2 Port régional | quai 2, portique STS, bitume, gate, frigo, scanner mobile | → 45–60 min |
| T3 Terminal national | quais 3–4, scanner portique, IMO, rail, hors-gabarit, panamax | → 1 h – 1 h 30 |

## 10 Apparence
3D low-poly sans texture, couleurs par sommet (`blender/palette.json`), ombres douces. UI : barre haute indigo, cartes blanches arrondies,
barres vert = argent / bleu = info / rouge = problème. Police ronde grasse (Fredoka si présente dans `assets/fonts/`, sinon Segoe UI Black).

## 11 Interface
Barre haute (revenu/min, argent, Ambre, ★) · pastille Responsables · Améliorations / Statistiques / Missions ·
barre basse (Réglages, Heures sup ×2, Gestion, Contrats) · bulles d'humeur à anneau au-dessus des navires et camions · files chiffrées au-dessus de chaque poste.

## 12 Son
Placeholders synthétisés (clic, achat, cloche, klaxon, palier) ; interrupteur muet. Pas de musique.

## 13 Hors périmètre
Monétisation, pubs · multijoueur · marques réelles · construction libre · pilotage manuel · pathfinding réaliste · musique · autres langues · export Android · T4/T5, prestige · jour/nuit.

## 14 Priorités
1. Chaîne complète avec goulots visibles, cartes, responsables, sauvegarde, diorama vivant.
2. T2/T3, aléas, contrats, hors-ligne, tableau de bord, politique et tarifs.
3. Jus, sons, jour/nuit.

## 15 Contraintes
Godot 4.7.1 (`C:\Nadir\Godot\Godot.exe` — l'exécutable *console* fourni ne fonctionne pas seul), Blender 5.2.2, projet `C:\Nadir\tycoon`.

## Décisions techniques
- `godot/sim/` : simulation pure (RefCounted), aucun nœud ; testable en headless.
- Modèle de flux : navires discrets ; EVP en quantités par étape (rade → quai → tablier → parc [à inspecter / dédouané] → gate).
- Douane : formalités du navire à l'accostage (durée) + inspection d'une fraction des EVP dans le parc selon la politique ; seuls les EVP dédouanés sortent.
- Hors-ligne : estimation agrégée (débit du goulot × valeur moyenne × rendement), pas de boucle tick par tick.
- UI construite en code (thème `scripts/ui/theme_builder.gd`), icônes SVG dans `assets/icons/`.
