# Vision

## Le problème

Les apps existantes séparent l'entraînement, la nutrition et le sommeil, ou les relient de façon superficielle (un « score du jour » décoratif). Elles affichent la charge soulevée, ce qui est trompeur : la charge varie avec la fatigue, les reps et le contexte. Personne ne répond honnêtement à la question : **« est-ce que je progresse vraiment, compte tenu de ma vie réelle ? »**

Aucune app majeure ne traite non plus le **jeûne spirituel** : elle l'ignore ou le transforme en outil de perte de poids.

## La promesse

1. **Progression réelle** : force estimée (e1RM), volume efficace, composition corporelle, avec un verdict qui tient compte du contexte. Une semaine de maintien pendant un jeûne ou une mauvaise période de sommeil n'est pas un échec.
2. **Séance du jour adaptée** : volume, charges et RIR ajustés au sommeil, à la récupération, à l'énergie et au jeûne.
3. **Jeûne respecté et mesuré** : l'app protège le jeûne et mesure son effet *personnel* (« est-ce que ça me booste, moi ? »).
4. **Données ouvertes** : tout est lisible et modifiable via l'API et le MCP. L'IA de l'utilisateur, ou la nôtre, peut programmer, saisir et analyser.

## Principes

- **Le moteur calcule, l'IA propose et explique.** Aucun chiffre n'est produit par un LLM : il appelle les outils du moteur.
- **Chaque règle cite ses sources** et son niveau de preuve.
- **Saisie minimale** : un tap par série, des imports automatiques, des repas favoris, une saisie par l'IA.
- **Le repos est sacré** : un jour de repos verrouillé ne se remplit jamais.
- **Aucun diagnostic médical.**

## Positionnement

Le marché « tout-en-un avec IA » est déjà occupé en 2026 (ForgeFit, Coachly, QBod, Cora, Strongsplit), avec des références solides par pilier (Fitbod, MacroFactor, Hevy, Whoop). Le MCP existe aussi déjà chez Hevy, Caliber, FitMaxx et Arvo. **Le tout-en-un seul ne suffit donc pas à se démarquer.**

Cresco se démarque par :

| Différenciateur | Pourquoi |
|---|---|
| **Foi et jeûne** | Jeûne chrétien, jeûne de Daniel, Ramadan : aucune app majeure n'adapte l'entraînement au jeûne spirituel ni ne mesure son effet personnel |
| **Francophone, toutes cuisines** | Bases France (Ciqual, Open Food Facts) et « Mes plats » pour toute cuisine (Afrique de l'Ouest, Antilles…), alimentés aussi par l'IA via MCP |
| **Données ouvertes complètes** | API et MCP en lecture-écriture sur l'entraînement, la nutrition, le sommeil et le jeûne |
| **Science traçable** | Chaque décision montre sa règle et ses sources |

Marché de départ : France et francophonie. Le module foi est **optionnel** : le produit reste utilisable par tous.

## Modèle économique

| Offre | Contenu |
|---|---|
| **Gratuit** | Suivi muscu et cardio, lecteur de séance, scan code-barres, sommeil importé |
| **Premium** (6 à 10 €/mois) | IA intégrée, séances adaptées, verdict de progression, analyses du jeûne, photo d'assiette |
| **Mode « ton IA »** (prix réduit) | Accès MCP et API complet, l'utilisateur branche sa propre IA : coût IA nul pour nous |
| **Coachs** (B2B, plus tard) | Suivi de clients via l'API, programmes partagés |

Abonnements via les achats intégrés des stores (RevenueCat).

## Risques

- Marché encombré : il faut tenir la niche foi + jeûne et la qualité scientifique.
- Coût de l'IA : quotas, cache, mode « ton IA ».
- Conformité des données de santé : voir [CONFORMITE.md](CONFORMITE.md).
