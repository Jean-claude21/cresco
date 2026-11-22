# API publique et MCP

## API REST

- Contrat **OpenAPI**, versionné (`/v1`), JSON, unités SI
- Authentification : jetons `cr_…` à permissions (app mobile, jetons personnels créés dans Profil) et **OAuth 2.1** pour les tiers et les assistants IA (`src/oauth.ts`) :
  - découverte : `/.well-known/oauth-authorization-server` et `/.well-known/oauth-protected-resource` (ressource `/mcp`) ; `/mcp` sans jeton répond 401 avec `WWW-Authenticate` qui pointe vers ces métadonnées ;
  - enregistrement dynamique des clients publics (`POST /oauth/register`, redirections https ou boucle locale) ;
  - code d'autorisation avec **PKCE S256 obligatoire** (`/oauth/authorize` : page de consentement, `foi:*`, `jeune:*` et `export` jamais cochés par défaut), `POST /oauth/token` (`authorization_code`, `refresh_token` avec rotation), `POST /oauth/revoke` ;
  - le jeton d'accès est un jeton Cresco ordinaire : il apparaît dans Profil et s'y révoque
- Pagination par curseur, `updated_since` pour la synchronisation
- **Webhooks** : `seance.terminee`, `repas.ajoute`, `jeune.demarre`, `jeune.termine`, `verdict.hebdo`
- Export complet : `GET /v1/export` (JSON), CSV par domaine

### Ressources

| Ressource | Opérations |
|---|---|
| `/aujourdhui` | résumé du jour (forme, séance du jour, énergie, jeûne) ; `?tz=<minutes>` (décalage UTC du téléphone) pour `streakDays` : jours locaux consécutifs avec au moins une saisie (séance, repas, réveil, début de jeûne, ressenti), aujourd’hui ou hier compris |
| `/exercices` | lire (`?gym=1` : seulement ce que la salle permet, champ `availableAtGym`), liens vidéo perso |
| `/gym` | `GET` salle principale, équipement coché, catalogue et listes proposées par chaîne ; `PUT` enregistre la salle et son équipement |
| `/modeles-seance` | lire, créer, `PUT /:id`, `DELETE /:id`, `POST /modeles-seance/valider` (contrôles de sécurité) ; la réponse liste `unavailableAtGym` |
| `/seances` | lire, créer (séance réalisée), `GET /seances/du-jour` (séance ajustée ; `?modele=<id>` pour une séance choisie) |
| `/aliments`, `/plats` | rechercher (texte, code-barres), créer un plat à partir d'ingrédients (étiquettes facultatives `tags`, nombre de portions `portions`), `PUT /plats/:id/tags`, `PUT /plats/:id/portions` ; chaque plat donne `massePortion` (C-ENERGIE-9) |
| `/repas` | CRUD |
| `/nuits`, `/mesures`, `/ressentis` | lire, créer (import ou saisie) ; mesures : poids, tour de taille, masse grasse, VFC, FC de repos, pas |
| `/sante/import` | `POST` nuits et mesures lues dans Health Connect ou Apple Santé (`source`) ; ce qui a déjà été importé de la même source est ignoré |
| `/jeunes` | démarrer, terminer, ajouter un événement, `GET /jeunes/en-cours/decision` |
| `/calculs/{regle}` | exécuter une règle sur des entrées (ex. `C-PERF-2`) : le moteur en libre-service |
| `/progression` | tendances, verdict hebdo, séances de la semaine (`seancesSemaine`) et objectif (`objectifSeancesSemaine`, préférence `seancesParSemaine`, 3 par défaut), dernier record (`record`), bilan énergie |
| `/muscles?jours=7` | séries efficaces par muscle (C-PERF-5) et repère hebdomadaire de 10 séries |
| `/ia` | `GET` : l’IA intégrée est-elle configurée (`ANTHROPIC_API_KEY` sur le serveur, modèle `claude-opus-5-5`) ; `POST /ia/repas-texte` et `/ia/repas-photo` : aliments et grammes **proposés**, rapprochés de la base (Ciqual, Open Food Facts), à confirmer dans l’app ; `GET /ia/bilan` : bilan de la semaine rédigé à partir des chiffres du moteur. Sans clé : 503 |
| `/regles`, `/sources` | lire le catalogue des règles (version, paramètres, sources) et la bibliothèque de sources |

### Permissions (scopes)

`entrainement:lecture` · `entrainement:ecriture` · `nutrition:lecture` · `nutrition:ecriture` · `sommeil:lecture` · `sommeil:ecriture` · `jeune:lecture` · `jeune:ecriture` · `corps:lecture` · `corps:ecriture` · `foi:lecture` · `foi:ecriture` · `export`

Les scopes `foi:*` et `jeune:*` sont séparés et jamais accordés par défaut.

## Serveur MCP

Exposé par le backend, avec les mêmes permissions OAuth. Chaque outil appelle l'API, jamais la base directement.

| Outil | Rôle |
|---|---|
| `obtenir_profil` | Profil, objectifs, préférences, salle |
| `obtenir_seance_du_jour` | Séance ajustée avec explication et sources |
| `programmer_seance` | Crée un modèle de séance (validé par le moteur avant enregistrement) |
| `lister_seances`, `obtenir_progression` | Historique, tendances e1RM, verdict |
| `muscle_volume` | Séries efficaces par muscle sur 7 jours (C-PERF-5) |
| `get_gym`, `set_gym` | Lire et enregistrer « Ma salle » : l’IA ne programme que le matériel disponible |
| `chercher_aliment`, `creer_plat`, `ajouter_repas` | Nutrition, y compris « Mes plats » : l'IA fournit les ingrédients et les masses, le moteur calcule |
| `tag_dish` | Étiquettes d’un plat pour les filtres (proteines, rapide, vegetarien, daniel) |
| `obtenir_bilan_energie` | Déficit, maintien ou surplus avec confiance |
| `obtenir_sommeil`, `obtenir_forme` | Nuits, score de forme et composantes |
| `demarrer_jeune`, `terminer_jeune`, `noter_jeune`, `decision_jeune` | Module jeûne |
| `effet_jeune` | Mesure personnelle (`J-EFFET`) |
| `calculer` | Exécute une règle du moteur (`C-…`, `J-…`) |
| `expliquer_regle` | Formule, paramètres, sources, niveau de preuve |

Ressources MCP : `regles://catalogue`, `sources://bibliotheque`.

### Garde-fous côté MCP
- Écritures limitées aux scopes accordés ; journal de chaque appel
- `programmer_seance` refuse une séance hors bornes (progression, volume, blessures)
- Aucun outil ne peut désactiver une règle de sécurité ni un jour de repos verrouillé
