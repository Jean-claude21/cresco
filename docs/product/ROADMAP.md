# Roadmap

L'ordre est choisi pour que chaque étape soit utilisable seule, et pour piloter l'app depuis Claude Code (MCP) très tôt.

## Phase 0 : fondations
- **Vérifier les sources** de [SOURCES.md](../science/SOURCES.md) (DOI, pages, études plus récentes) avant de coder le moteur
- Écrire les cas de test partagés du moteur (`engine-spec/`) à partir de [CALCULS.md](../science/CALCULS.md)
- Monorepo Flutter (Melos + FVM), packages par couche, comme dym
- Backend TypeScript (Node 22, pnpm) + Postgres, image Docker unique déployée sur Coolify, comme struo
- Modèle de données et contrat API (OpenAPI), voir [MODELE_DONNEES.md](../architecture/MODELE_DONNEES.md)
- Authentification OAuth2 (PKCE pour l'app, permissions fines pour l'API)

## Phase 1 : entraînement
- Bibliothèque d'exercices (muscles, matériel, animation par défaut, liens vidéo personnels)
- Profil « Ma salle » (machines disponibles)
- Lecteur de séance muscu : un tap par série, RIR, charge suivante calculée, minuteur de repos
- Lecteur cardio par intervalles : annonces vocales, préavis, fonctionne écran éteint
- Moteur : e1RM, volume efficace, sRPE

## Phase 2 : MCP et API publique
- Serveur MCP : lire et écrire les séances, programmer une séance, consulter la progression
- Export JSON et CSV, webhooks

## Phase 3 : récupération et jeûne
- Import du sommeil (HealthKit, Health Connect) et ressenti du matin
- Score de forme du jour et séance ajustée
- **Module jeûne** : types, minuteur, symptômes, règles d'entraînement, reprise, mesure de l'effet personnel
- Module foi (optionnel)

## Phase 4 : nutrition
- Scan code-barres (Open Food Facts), base Ciqual
- « Mes plats » : recettes calculées à partir des ingrédients, saisie par l'IA via MCP
- Cibles de macros, bilan du jour, TDEE adaptatif, verdict déficit / maintien / surplus

## Phase 5 : intelligence
- Verdict hebdomadaire de progression
- IA intégrée : programmation, saisie en langage naturel, photo d'assiette, bilans
- Recalibrage personnel des poids du score de forme
- Abonnements

## Plus tard
- Espace coachs (B2B), montres (export des séances), partenariats salles
