# Design de Cresco

Ce document fixe le design validé le 21 novembre 2026. Il remplace la proposition « vert pin » de [propositions/](propositions/DESIGN.md), gardée pour l’historique. Les maquettes animées et interactives sont sur le canevas : https://claude.ai/artifact/9pddHy1muXQf24ezMDtdUw (privé, à partager depuis le menu Partager).

## Principe

Cresco doit **donner envie d’y aller** et **montrer le progrès réel**. Une carte = une idée. Le chiffre qui compte est grand, sa cause est écrite juste en dessous, et « Comment c’est calculé » est toujours à un toucher.

## Couleurs

| Rôle | Clair | Sombre | Emploi |
| --- | --- | --- | --- |
| Fond | `#F2F3EE` | `#0B0D0B` | Fond général |
| Surface | `#FFFFFF` | `#1A1D19` | Cartes, barre de navigation |
| Encre | `#111311` | `#F2F3EE` | Texte, pictogrammes |
| Texte secondaire | `#5B6158` | `#A8AEA2` | Unités, légendes |
| Filet / piste | `#ECEDE6` | `#2A2D27` | Séparateurs, fonds de jauge |
| Action | `#111311` | `#CDEB5A` | Bouton principal, onglet actif |
| Citron vert | `#CDEB5A` | `#CDEB5A` | Séance du jour, progrès, accent |
| Jeûne (lavande) | `#DAD5FF` / texte `#2B2269` | `#26214F` / texte `#DAD5FF` | Jeûne, sommeil |
| Nuit | `#15122E` | `#15122E` | Écran de jeûne, module foi |
| Rose | `#FFD9DF` / texte `#5E1426` | idem | Muscle ciblé, erreur |
| Pêche | `#FFE7C2` / texte `#6B4300` | idem | Attente, récupération partielle |
| Corail | `#F05A3C` | idem | Série en cours, alerte ponctuelle |

**Contraste.** Le citron vert n’est **jamais** du texte sur fond clair (ratio 1,3:1). Il sert de fond sous du texte noir (15:1) ou de texte sur noir (14:1). Le texte secondaire `#5B6158` sur `#F2F3EE` est à 5,9:1.

## Typographie

- **Inter Tight** 800–900 pour les titres et les chiffres (titres de page 34 pt, chiffres clés 22–40 pt, interlettrage négatif).
- **Inter** 400–700 pour le texte courant (12–15 pt).
- Les unités restent sur la ligne du nombre, en plus petit et en gris (`94 / 150 g`).
- **Texte agrandi** : toutes les tailles suivent le réglage du système. À 130 %, les grilles de deux cartes passent sur une colonne et la page défile ; rien n’est tronqué.

## Formes et mise en page

- Écran de référence 390 × 844 pt, marges 20 pt, espacement vertical 12–14 pt.
- Rayons : 26 pt (cartes principales), 22 pt (cartes), 16–20 pt (pastilles), boutons en pilule.
- Zones tactiles d’au moins 44 × 44 pt ; bouton principal de 56 pt de haut.
- Navigation : pilule blanche flottante (Aujourd’hui, Entraînement, Nutrition, Progrès) et bouton rond « + » séparé.

## Mouvement

- Entrée des cartes : montée de 18 pt et fondu, 0,6 s, décalées de 60–80 ms.
- Jauges et anneaux qui se remplissent, barres qui poussent, sélection qui « rebondit » légèrement.
- Démonstration d’exercice : boucle au tempo réel (ex. pousser 1 s, revenir 2 s) avec la phase affichée.
- Transitions d’étape : glissement horizontal de 28 pt, 0,45 s.
- **Réduction des animations** respectée partout : tout devient statique.

## États obligatoires

Chaque écran qui charge des données prévoit quatre états (maquette « États ») :

1. **Vide** : une illustration, une phrase qui dit quoi faire, une action principale.
2. **Chargement** : squelettes à la forme des cartes, jamais d’écran blanc.
3. **Erreur** : ce qui s’est passé, que rien n’est perdu, « Réessayer », et une sortie utile.
4. **Hors ligne** : bandeau discret, la séance reste possible, les séries partent au retour du réseau.

## Écrans

| Rangée | Écrans |
| --- | --- |
| Entrer, être motivé, s’entraîner | Bienvenue, Aujourd’hui, Mes séances, Séance en cours, **Mon corps** |
| Ma salle, mon jeûne, mon assiette | Fiche exercice (animation), Ma salle, Jeûne, Nutrition |
| Comprendre et progresser ensemble | Progrès, Comment c’est calculé, Mon club, Récupération |
| Démarrer, attendre, voir la nuit | Démarrage (5 étapes), États, Sombre et grand texte |

### Mon corps

Silhouette de face et de dos ; on touche un muscle sur le corps ou dans la liste de pastilles. Trois lectures :

- **Volume** : séries efficaces de la semaine (RIR ≤ 3, muscle principal 1, secondaire 0,5) rapportées à l’objectif du muscle (`C-PERF-5`).
- **Progression** : tendance de l’e1RM des exercices qui travaillent ce muscle, sur 4 semaines.
- **Récupération** : temps écoulé depuis la dernière sollicitation, pondéré par l’effort et le sommeil. **[H]**

La progression par muscle et la récupération ne sont pas encore des règles du moteur : elles doivent être spécifiées dans [CALCULS.md](../science/CALCULS.md), avec leurs cas dans `engine-spec/`, avant d’être affichées. La silhouette des maquettes est un tracé simple ; en production, une illustration anatomique (homme et femme) avec les mêmes zones cliquables.

## Hors du design actuel

- Animations réelles pour chaque exercice de la bibliothèque (la maquette en montre une).
- Silhouette anatomique définitive, versions homme et femme.
- Icône d’application et écran de lancement.
