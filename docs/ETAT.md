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
| API `/v1` + RLS Postgres + jetons à permissions | 17 tests de bout en bout sur un vrai Postgres (isolation entre utilisateurs, garde-fous, jeûne, confiance basse, séries par muscle, Ma salle, Mes séances, MCP, export, suppression) |
| Serveur MCP (25 outils) | appel réel `tools/list` et `tools/call` dans les tests |
| App Flutter : Bienvenue, connexion, Démarrage (coach, objectif, rythme, salle, foi), Aujourd'hui, Entraînement (Mes séances, éditeur, ajout d’exercice en cours de séance), Séance, Intervalles, Jeûne, Nutrition (scan, Mes plats), Progrès, Profil (dont Mon coach), Mon corps, Ma salle | analyse `--fatal-infos` sans remarque, 61 tests dont 28 « écrans étroits » (360 pt, texte normal et × 1,3), 19 captures de contrôle dont 6 en sombre ; toucher de « Mon corps » vérifié sur les vrais masques |
| Design G « Net et braise » ([DESIGN.md](design/DESIGN.md), [ADR-0004](architecture/decisions/0004-design-net-et-braise.md)) | palette claire et sombre (braise pour l’effort, glacier pour le repos), formes de Picnic partout (`CrescoShape`), deux coachs illustrés (accueil, démarrage, états vides, choix dans Profil), corps complet généré et découpé en masques, icônes et photos ; médias générés avec ChatGPT ([medias](design/medias/README.md)) |
| **Parcours complet sur vrais téléphones** (BrowserStack) | vert sur Galaxy S23 (Android 13), Pixel 8 (14), Galaxy S25 (15), Moto G71 (11), contre le staging : inscription → séance complète → intervalles → jeûne → nutrition → progrès → profil → déconnexion |
| Déploiement staging | santé vérifiée depuis Internet |

### Relancer les tests sur téléphones

```
cd apps/cresco_app/android
gradlew app:assembleAndroidTest
gradlew app:assembleDebug -Ptarget=integration_test/parcours_test.dart
cd ../../..
node scripts/browserstack.mjs
```

Le script lit les clés BrowserStack dans `../.secrets/.admin.env` (jamais affichées) et écrit le résumé dans `.local/browserstack.json`. En cas d'échec, il affiche l'erreur et tout le texte à l'écran au moment de l'arrêt.

### Défauts trouvés et corrigés grâce aux vrais téléphones

| Défaut | Correction |
|---|---|
| Fin de séance bloquée sur « Séance terminée » | `back()` de GetX fermait la barre de message au lieu de l'écran : barres de message Flutter (ScaffoldMessenger) |
| « Volume −50 % » après une toute première séance | le serveur respecte « confiance basse = plan normal » et ignore le ratio aigu/chronique avant 21 jours |
| Bouton « Créer le compte » absent sous le clavier Samsung | formulaire de connexion entièrement construit |
| Débordement sur écran étroit (Galaxy S25) | composant `IconeLibelle`, ligne de charge en texte composé |
| Onglets affichant des données périmées | chaque onglet recharge ses données à chaque visite |

## Pas encore fait

| Sujet | Où ça se branche |
|---|---|
| Import automatique du sommeil, de la VFC et des pas (HealthKit, Health Connect) | `cresco_data` + permissions natives ; aujourd'hui saisie manuelle par le bouton « + » |
| Capteur cardio Bluetooth pendant les intervalles | écran Intervalles (affiche « FC indisponible ») |
| App iPhone sur appareil réel (le .ipa se construit uniquement sur un Mac ; BrowserStack a les iPhone) | même parcours `integration_test`, à construire depuis un Mac ou une CI macOS |
| Minuteur et annonces vocales écran éteint (service au premier plan Android, session audio iOS) | `features/intervalles` ; aujourd'hui l'écran reste allumé pendant la séance |
| Base locale complète hors ligne (Drift) | ADR-0003 ; aujourd'hui cache des lectures et file d'attente des écritures |
| OAuth2 complet pour les tiers (comme struo avec better-auth) | `apps/server/src/auth.ts` ; aujourd'hui jetons personnels à permissions |
| IA intégrée (programmation, photo d'assiette, bilans) | à brancher sur les outils MCP existants |
| Animations d'exercices (Rive ou Lottie) | `features/seance` ; aujourd'hui photo noir et blanc par famille d’exercice et lien vidéo personnel |
| Mise en page des maquettes G pour Jeûne, Nutrition (grille de plats en photos) et Progrès (palette, formes et mode sombre déjà faits) | maquettes : `docs/design/propositions-v2/G2-final` |
| Police condensée pour les chiffres d’affiche (Barlow Condensed, OFL) | `packages/cresco_ui/fonts` ; aujourd’hui Inter 900 serrée |
| Noms des coachs (Maya, Karim : proposés) | `packages/cresco_ui/lib/src/media.dart` |
| Mon corps : progression et récupération par muscle | règles à écrire dans CALCULS.md, avec cas `engine-spec`, avant affichage |
| Abonnements (RevenueCat) | après la phase 5 de la roadmap |
| Base Ciqual | aujourd'hui Open Food Facts et aliments personnels |
| 14 sources non vérifiées, 4 partielles | `docs/science/SOURCES.md` |
| Domaine définitif et compte de démonstration | `DOMAIN_STAGING` dans `../.secrets/cresco.env` |
