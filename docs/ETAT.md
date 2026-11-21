# État du projet

Mis à jour le 21/11/2026.

## En ligne

| Élément | Adresse |
|---|---|
| API et MCP (staging) | https://cresco-staging.169.58.86.123.sslip.io — santé : `/api/health`, API : `/v1`, MCP : `/mcp` |
| Base | Neon, projet `cresco` (Francfort, PostgreSQL 17), branche `dev` pour le staging |
| Hébergement | Coolify, projet « Cresco », environnement `staging`, construit depuis `main` (Dockerfile) |

Redéployer : `pnpm deploy:staging` (lit `../.secrets/.admin.env`, écrit `../.secrets/cresco.env`, n'affiche aucun secret). Production : `pnpm deploy:production` (branche Neon `main`).

## Fait et vérifié

| Bloc | Vérification |
|---|---|
| Moteur TypeScript (`packages/engine-ts`) | 59 cas `engine-spec` |
| Moteur Dart (`packages/cresco_engine`) | les mêmes 59 cas : les deux moteurs donnent les mêmes résultats |
| API `/v1` + RLS Postgres + jetons à permissions | 13 tests de bout en bout sur un vrai Postgres (isolation entre utilisateurs, garde-fous, jeûne, MCP, export, suppression) |
| Serveur MCP (22 outils) | appel réel `tools/list` et `tools/call` dans les tests |
| App Flutter : connexion, Aujourd'hui, Entraînement, Séance, Intervalles, Jeûne, Nutrition (scan, Mes plats), Progrès, Profil | analyse `--fatal-infos` sans remarque, 12 tests, 9 captures de contrôle (`apps/cresco_app/test/golden/captures`) |
| Déploiement staging | santé vérifiée depuis Internet |

## Pas encore fait

| Sujet | Où ça se branche |
|---|---|
| Import automatique du sommeil, de la VFC et des pas (HealthKit, Health Connect) | `cresco_data` + permissions natives ; aujourd'hui saisie manuelle par le bouton « + » |
| Capteur cardio Bluetooth pendant les intervalles | écran Intervalles (affiche « FC indisponible ») |
| Minuteur et annonces vocales écran éteint (service au premier plan Android, session audio iOS) | `features/intervalles` ; aujourd'hui l'écran reste allumé pendant la séance |
| Base locale complète hors ligne (Drift) | ADR-0003 ; aujourd'hui cache des lectures et file d'attente des écritures |
| OAuth2 complet pour les tiers (comme struo avec better-auth) | `apps/server/src/auth.ts` ; aujourd'hui jetons personnels à permissions |
| IA intégrée (programmation, photo d'assiette, bilans) | à brancher sur les outils MCP existants |
| Animations d'exercices (Rive ou Lottie) | `features/seance` ; aujourd'hui pictogramme et lien vidéo personnel |
| Abonnements (RevenueCat) | après la phase 5 de la roadmap |
| Base Ciqual | aujourd'hui Open Food Facts et aliments personnels |
| 14 sources non vérifiées, 4 partielles | `docs/science/SOURCES.md` |
| Domaine définitif et compte de démonstration | `DOMAIN_STAGING` dans `../.secrets/cresco.env` |
