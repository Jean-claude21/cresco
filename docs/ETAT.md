# État du projet

Mis à jour le 21/11/2026.

## En ligne

| Élément | Adresse |
|---|---|
| **Production** (API et MCP) | https://cresco.kete.digital — santé : `/api/health`, API : `/v1`, MCP : `/mcp`, OAuth : `/.well-known/oauth-authorization-server` |
| Test (staging) | https://cresco-staging.kete.digital (mêmes chemins) |
| Base | Neon, projet `cresco` (Francfort, PostgreSQL 17) : branche `main` pour la production, `dev` pour le test |
| Hébergement | Coolify (serveur kete-contabo, domaine générique `kete.digital`), projet « Cresco », environnements `production` et `staging`, construits depuis `main` (Dockerfile) |
| IA intégrée | OpenAI, `OPENAI_API_KEY` transmise par le script de déploiement ; modèle `gpt-5.5` (`OPENAI_MODEL`) |
| App Android | `dist/cresco-1.0.0.apk` (non versionné), signée avec la clé d’envoi `../.secrets/keystores/cresco-upload.jks` (mot de passe dans `../.secrets/cresco.env`, `android/key.properties` non versionné) ; pointe sur la production |

Redéployer : `pnpm deploy:staging` (lit `../.secrets/.admin.env`, écrit `../.secrets/cresco.env`, n'affiche aucun secret). Production : `pnpm deploy:production` (branche Neon `main`). APK : `fvm flutter build apk --release` dans `apps/cresco_app`. Le parcours de test sur téléphone se construit contre le staging, avec l’outil Flutter (pas Gradle seul, qui reprendrait la liste de plugins d’une version de production, sans `integration_test`) : `fvm flutter build apk --debug --target=integration_test/parcours_test.dart --dart-define=CRESCO_API=https://cresco-staging.kete.digital`, puis `node scripts/browserstack.mjs`. Ainsi aucun compte de test n’est créé en production.

## Fait et vérifié

| Bloc | Vérification |
|---|---|
| Moteur TypeScript (`packages/engine-ts`) | 69 cas `engine-spec` |
| Moteur Dart (`packages/cresco_engine`) | les mêmes 69 cas : les deux moteurs donnent les mêmes résultats |
| API `/v1` + RLS Postgres + jetons à permissions | 17 tests de bout en bout sur un vrai Postgres (isolation entre utilisateurs, garde-fous, jeûne, confiance basse, séries par muscle, Ma salle, Mes séances, MCP, export, suppression) |
| Serveur MCP (27 outils, OAuth 2.1) | appel réel `tools/list` et `tools/call` dans les tests |
| App Flutter : Bienvenue, connexion, Démarrage (coach, objectif, rythme, salle, foi), Aujourd'hui, Entraînement (Mes séances, éditeur, ajout d’exercice en cours de séance), Séance, Intervalles, Jeûne, Nutrition (scan, Mes plats), Progrès, Profil (dont Mon coach), Mon corps, Ma salle | analyse `--fatal-infos` sans remarque, 61 tests dont 28 « écrans étroits » (360 pt, texte normal et × 1,3), 19 captures de contrôle dont 6 en sombre ; toucher de « Mon corps » vérifié sur les vrais masques |
| Design G « Net et braise » ([DESIGN.md](design/DESIGN.md), [ADR-0004](architecture/decisions/0004-design-net-et-braise.md)) | palette claire et sombre (braise pour l’effort, glacier pour le repos), formes de Picnic partout (`CrescoShape`), deux coachs illustrés (accueil, démarrage, états vides, choix dans Profil), corps complet généré et découpé en masques, icônes et photos ; médias générés avec ChatGPT ([medias](design/medias/README.md)) |
| **Parcours complet sur vrais téléphones** (BrowserStack) | vert sur Galaxy S23 (Android 13), Pixel 8 (14), Galaxy S25 (15), Moto G71 (11), contre le staging : inscription → séance complète → intervalles → jeûne → nutrition → progrès → profil → déconnexion |
| Design G sur vrai téléphone (22/11/2026) | parcours complet vert sur Galaxy S23 contre le staging : Bienvenue → inscription → choix du coach → démarrage → séance → Mon corps (valeurs réelles) → Ma salle → intervalles → jeûne → nutrition → progrès → profil → déconnexion. L’échec intermittent sur « Décris ta salle » venait du test (élément amené sous la barre d’état) : corrigé le 22/11/2026 en centrant l’élément avant de le toucher |
| Coach en mouvement (22/11/2026) | Karim montre les 71 exercices faisables aux machines et aux postes (45 machines, pec deck, poulies, vis-à-vis, Smith, chaise romaine, banc à lombaires, GHD, traîneau, pupitre, banc à abdos), en trois poses dessinées avec ChatGPT et jouées en boucle ; bouton « Mouvement » de Ma salle (une puce par exercice pour un poste), et en séance à la place de la démonstration. 13 exercices de poulie et de Smith ajoutés au catalogue (migration 0012). Tests de l’app (captures 14 et 15) et de l’API verts ; pas encore vu sur téléphone |
| Design G, seconde passe (22/11/2026) | Aujourd’hui (série de jours actifs, calculée par le serveur dans le fuseau du téléphone), Séance, Mon corps (exercices et « Ajouter des séries ») et Mes séances comparés côte à côte avec les maquettes G1 et G2 ; pictogrammes Phosphor et barre d’onglets G2 ; parcours complet vert sur Galaxy S23 contre le staging (le parcours ne dépend plus du jour de la semaine) |
| Fonctionnalités du 22/11/2026 | objectif de séances par semaine (démarrage, Profil, Progrès) ; Intervalles au style G, minuteur et annonces **écran éteint** (service au premier plan Android, audio iOS), **capteur cardio Bluetooth** (service Heart Rate) ; repos de séance écran éteint avec annonce vocale ; **portions par plat** (moteur C-ENERGIE-9) ; **import Health Connect / Apple Santé** (sommeil, VFC, FC de repos, pas, poids) ; **base Ciqual 2020** (2 298 aliments) ; **IA intégrée** (repas en mots, photo d’assiette, bilan du coach) ; **récupération et tendance par muscle** (C-RECUP-4, C-PERF-7) et **poids personnels de la forme** (C-CALIB) ; lectures hors ligne pour tous les écrans ; **OAuth 2.1** pour les tiers et les assistants IA | 68 tests Flutter, 96 tests serveur et moteur, parcours complet vert sur Galaxy S23 |
| Déploiement staging | santé vérifiée depuis Internet ; découverte OAuth vérifiée en ligne |

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
| IA intégrée : crédits OpenAI | la clé `OPENAI_API_KEY` est en place (Coolify), mais le compte OpenAI n’a plus de crédit : à recharger sur platform.openai.com ; en attendant, l’app affiche « assistant indisponible » |
| App iPhone sur appareil réel (le .ipa se construit uniquement sur un Mac) | même parcours `integration_test` ; HealthKit demande d’activer la capacité dans Xcode (`Runner.entitlements` est prêt) |
| Base locale complète (Drift) | aujourd’hui : toutes les lectures en cache et les saisies en file d’attente ; il manque la création de séances et de plats hors ligne |
| Abonnements (RevenueCat) | comptes Apple, Google et RevenueCat à créer ; après la phase 5 |
| Langues | décidé pour plus tard |
| Noms des coachs (Maya, Karim : proposés) | `packages/cresco_ui/lib/src/media.dart` |
| 14 sources non vérifiées, 4 partielles | `docs/science/SOURCES.md` |
| Domaine définitif et compte de démonstration | `DOMAIN_STAGING` dans `../.secrets/cresco.env` |
