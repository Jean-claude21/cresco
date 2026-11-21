Tu es designer produit mobile senior. Propose le design de 5 écrans de l'app mobile **Cresco** (iPhone, en français).

## Le produit
Cresco est une app de musculation, cardio, nutrition, sommeil et jeûne qui propose la séance du jour et montre la **progression réelle** en tenant compte du contexte (sommeil, alimentation, jeûne). Le jeûne est souvent spirituel (module foi optionnel, sobre, jamais ostentatoire). Les données de référence sont dans `docs/science/LIENS.md`, `docs/science/CALCULS.md` et `docs/science/JEUNE.md` de ce dépôt : lis-les pour que les chiffres et libellés soient cohérents.

## Style de référence (inspiration, pas copie)
Les deux images jointes sont des captures de l'app Welmi. Inspire-toi seulement de ses **principes** : fond très clair, cartes blanches très arrondies, gros chiffres lisibles, jauge en anneau, mini-barres de macros, barre d'onglets flottante en pilule avec un bouton « + » rond, cadran circulaire pour le jeûne, beaucoup d'air. **Ne copie ni la marque, ni le logo, ni les textes, ni la couleur d'accent corail.** Cresco doit avoir sa propre identité : propose une couleur d'accent qui évoque la croissance et la force (par exemple un vert profond ou un bleu nuit, à toi de choisir et de justifier), et une typographie.

## Les 5 écrans
1. **Aujourd'hui** : score de forme du jour (0–100) en anneau avec ses composantes (sommeil, VFC, ressenti), la séance du jour ajustée (ex. « Haut du corps · volume −20 % » et pourquoi), bilan énergie du jour (kcal restantes, protéines), carte jeûne en cours si applicable. Barre d'onglets : Aujourd'hui, Entraînement, Nutrition, Progrès, + bouton « + ».
2. **Séance en cours (muscu)** : exercice courant avec animation, série 2/3, charge calculée (ex. 72,5 kg × 8, RIR cible 2), saisie du RIR réel en un tap, minuteur de repos, charge suivante proposée, lien vidéo de l'exercice.
3. **Intervalles cardio (tapis)** : grand minuteur, vitesse cible en km/h, étape courante (ex. « Rapide 4/6 »), préavis « Dans 15 s : 9 km/h », frise des intervalles, FC actuelle.
4. **Jeûne** : cadran circulaire du jeûne (heures écoulées, phase actuelle : glycogène, bascule métabolique, cétose), type de jeûne (intermittent, eau, sec, Daniel), décision du jour (« Séance adaptée : volume −25 % »), saisie rapide eau et symptômes, intention du jeûne et un verset discret (module foi).
5. **Progrès** : verdict de la semaine (« Tu progresses » / « Maintien = réussite » avec la cause), courbe de tendance e1RM par exercice, bilan énergie (déficit estimé avec niveau de confiance), poids lissé, sommeil moyen.

## Livrables (dans ce dossier `docs/design/propositions/`)
- Une image PNG par écran, au format portrait de téléphone : `01-aujourdhui.png`, `02-seance.png`, `03-intervalles.png`, `04-jeune.png`, `05-progres.png`. Les 5 écrans doivent partager le même système visuel.
- Un fichier `DESIGN.md` en français : la direction artistique (couleurs avec codes hex, typographie, rayons, ombres, iconographie), puis pour chaque écran sa structure, ses composants et les choix faits.

Ne modifie aucun autre fichier du dépôt.
