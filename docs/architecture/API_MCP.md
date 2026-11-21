# API publique et MCP

## API REST

- Contrat **OpenAPI**, versionné (`/v1`), JSON, unités SI
- Authentification **OAuth2** : PKCE pour l'app, clients enregistrés pour les tiers, jetons personnels pour l'usage avec sa propre IA
- Pagination par curseur, `updated_since` pour la synchronisation
- **Webhooks** : `seance.terminee`, `repas.ajoute`, `jeune.demarre`, `jeune.termine`, `verdict.hebdo`
- Export complet : `GET /v1/export` (JSON), CSV par domaine

### Ressources

| Ressource | Opérations |
|---|---|
| `/exercices`, `/salle` | lire, créer, modifier (liens vidéo perso) |
| `/modeles-seance` | CRUD, `POST /modeles-seance/valider` (contrôles de sécurité) |
| `/seances` | lire, créer (séance réalisée), `GET /seances/du-jour` (séance ajustée) |
| `/aliments`, `/plats` | rechercher (texte, code-barres), créer un plat à partir d'ingrédients |
| `/repas` | CRUD |
| `/nuits`, `/mesures`, `/ressentis` | lire, créer (import ou saisie) |
| `/jeunes` | démarrer, terminer, ajouter un événement, `GET /jeunes/en-cours/decision` |
| `/calculs/{regle}` | exécuter une règle sur des entrées (ex. `C-PERF-2`) : le moteur en libre-service |
| `/progression` | tendances, verdict hebdo, bilan énergie |
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
| `chercher_aliment`, `creer_plat`, `ajouter_repas` | Nutrition, y compris « Mes plats » : l'IA fournit les ingrédients et les masses, le moteur calcule |
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
