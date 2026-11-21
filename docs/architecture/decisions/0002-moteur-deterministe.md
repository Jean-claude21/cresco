# ADR-0002 : le moteur calcule, l'IA propose

**Statut** : accepté (21/11/2026)

## Contexte
Un LLM peut se tromper sur un calcul (e1RM, calories, seuils) et produire des séances dangereuses. L'app doit aussi pouvoir justifier chaque décision.

## Décision
- Toutes les formules de [CALCULS.md](../../science/CALCULS.md) et [JEUNE.md](../../science/JEUNE.md) vivent dans un **moteur déterministe**, sans IA.
- Chaque règle a un identifiant, une version, des paramètres, des sources et un niveau de preuve.
- L'IA (intégrée ou celle de l'utilisateur via MCP) **appelle** le moteur, propose et explique. Toute séance qu'elle crée passe par une validation.
- Le moteur existe en Dart (hors ligne, dans l'app) et en TS (serveur, référence). Un jeu de cas de test partagé (`engine-spec/`) garantit qu'ils donnent les mêmes résultats.

## Conséquences
- Résultats reproductibles et testables.
- Coût de maintenance de deux implémentations, compensé par les tests partagés.
