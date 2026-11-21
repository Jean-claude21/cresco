# ADR-0004 : design « Net et braise », coachs illustrés, formes de Picnic

**Statut** : accepté (21/11/2026). Remplace le design « noir et citron vert » du même jour.

## Contexte

Le premier design validé (noir et citron vert, cartes très arrondies) a été jugé à améliorer. Sept directions ont été explorées avec des maquettes générées par ChatGPT ([propositions-v2](../../design/propositions-v2/README.md)). Les inspirations venaient de Welmi, Cal AI, Uber et Picnic, en principes seulement.

## Décision

- **Direction G**, en quatre points :
  - écrans du quotidien en noir et blanc (Cal AI, Uber) ;
  - **orange braise** réservé à l’effort ;
  - **bleu glacier** pour le repos et le jeûne ;
  - écran de séance toujours sombre.
- **Formes de Picnic** : coins de 4 pt et contour de 1,5 pt sur les boutons, cartes, champs, pastilles, sélecteurs, listes et panneaux. Elles sont définies une seule fois dans `CrescoShape`.
- **Deux coachs illustrés** (une femme, un homme) :
  - le duo à l’accueil, le choix au démarrage, enregistré dans `preferences.coach` ;
  - jamais pendant l’effort.
- **Médias générés avec ChatGPT**, avec leurs consignes et leurs scripts versionnés ([medias](../../design/medias/README.md)). Le corps de « Mon corps » est découpé en masques par muscle, à partir de couleurs clés exactes.
- **Texte noir sur braise**, pour respecter le contraste AA.

## Conséquences

- Les couleurs et les formes passent toutes par `CrescoPalette` et `CrescoShape` ; plus aucune couleur fixe dans les écrans. Le mode sombre suit le téléphone.
- La carte du corps ne dépend plus d’un dessin vectoriel fait à la main : le toucher se lit dans une carte des zones générée.
- Les médias pèsent 1,4 Mo dans l’app.
- Les mises en page de Jeûne, Nutrition et Progrès restent à aligner sur les maquettes G.
- Aucune police condensée n’est embarquée pour les chiffres.
