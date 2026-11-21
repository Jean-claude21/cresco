# ADR-0001 : stack

**Statut** : accepté (21/11/2026)

## Contexte
L'auteur a déjà deux bases éprouvées : **dym** (Flutter, Melos, FVM, Stacked, packages par couche) et **struo** (Node 22 + TypeScript, Postgres, image Docker unique, Coolify, MCP). dym utilisait les fonctions Neon et Firebase ; pour Cresco, on veut un backend maîtrisé et hébergé dans l'UE.

## Décision
- Mobile : **Flutter** avec les conventions de dym (FVM, Melos, Stacked, very_good_analysis, packages par couche, thème depuis tokens).
- Backend : **Node 22 + TypeScript + Postgres**, conventions de struo, une image Docker déployée sur **Coolify** chez un hébergeur UE.
- MCP intégré au backend.

## Conséquences
- Réutilisation des outils et habitudes existants.
- Moteur de calcul en deux langages (Dart et TS) : voir [ADR-0002](0002-moteur-deterministe.md).
- Pas de dépendance aux fonctions Neon ni à Firebase.
