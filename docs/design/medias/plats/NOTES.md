# Photos des familles de plats

Neuf photos générées avec ChatGPT le 22 novembre 2026 à partir de [BRIEF.md](BRIEF.md), avec la maquette G « Mes plats » en référence. Elles respectent toutes la consigne : format 1200 × 800, bol ou assiette blanche, plan de travail en pierre claire, lumière venant de la gauche.

ChatGPT a atteint sa limite d’usage juste après la dernière image. Cette note a donc été rédigée après coup, à partir des fichiers produits.

L’app choisit la photo d’un plat selon les mots de son nom (`DishFamily` dans `packages/cresco_ui/lib/src/media.dart`). Par exemple, « Riz sauce arachide » prend la famille riz et poulet, et « Dal » la famille des légumineuses. Un plat sans mot reconnu prend l’assiette équilibrée.

| Famille | Mots reconnus dans le nom |
| --- | --- |
| `riz-poulet` | jollof, yassa, mafé, riz, poulet, thiéboudienne |
| `poisson` | saumon, poisson, thon, cabillaud, sardine, crevette |
| `oeufs` | omelette, œuf |
| `legumineuses` | lentille, dal, haricot, pois chiche, niébé, houmous, arachide |
| `bowl` | bowl, salade, quinoa |
| `yaourt-fruits` | skyr, yaourt, fromage blanc, fruit, porridge, avoine, granola |
| `pates` | pâtes, spaghetti, penne, lasagne, nouilles |
| `soupe` | soupe, velouté, bouillon, potage |
| `assiette` | tous les autres plats |

Les fichiers de l’app sont dans `packages/cresco_ui/assets/dishes/` (900 px, JPEG). Ce dossier en garde une version réduite (600 px).
