# Consignes pour les agents

## Projet
Cresco : app Flutter de musculation, cardio, nutrition, sommeil et jeûne, avec API publique et serveur MCP. Lire d'abord [README.md](README.md), puis [docs/science/LIENS.md](docs/science/LIENS.md) et [docs/science/CALCULS.md](docs/science/CALCULS.md).

## Règles
- **Le moteur calcule, l'IA propose** ([ADR-0002](docs/architecture/decisions/0002-moteur-deterministe.md)). Aucune formule ne doit être écrite hors du moteur.
- Toute nouvelle règle ou formule : identifiant (`C-…`, `J-…`), version, paramètres, sources (`S-xx` dans [SOURCES.md](docs/science/SOURCES.md)), niveau de preuve. Une heuristique est marquée **[H]**.
- Toute modification d'une formule met à jour **en même temps** CALCULS.md (ou JEUNE.md), les cas de `engine-spec/` et les deux implémentations du moteur.
- Les règles de sécurité ([CONFORMITE.md](docs/product/CONFORMITE.md)) ne sont jamais contournables : ni par l'IA, ni par le MCP, ni par un paramètre utilisateur.
- Unités internes SI ; conversions uniquement à l'affichage.
- Stack : conventions de **dym** pour Flutter (FVM, Melos, Stacked, very_good_analysis), de **struo** pour le backend (Node 22, TypeScript, pnpm, Postgres, Docker, Coolify). Voir [ADR-0001](docs/architecture/decisions/0001-stack.md).
- Langue : documentation et textes de l'app en français ; code (identifiants, commentaires) en anglais.
- Design : [docs/design/DESIGN.md](docs/design/DESIGN.md) fait référence. Couleurs et formes uniquement via `CrescoPalette` (`context.palette`) et `CrescoShape` ; aucune couleur fixe dans un écran. Les médias se génèrent avec ChatGPT selon [docs/design/medias/README.md](docs/design/medias/README.md).
