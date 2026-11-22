# Corps réaliste pour « Mon corps » (comme la maquette G1-04)

L’app colore chaque muscle selon les séries de la semaine en posant une teinte **par-dessus** ce rendu (mode « multiplier »). Les zones des muscles viennent des cartes à couleurs clés déjà en place (`../corps/face.png` et `../corps/dos.png`, jointes). Ce rendu doit donc **se superposer exactement** à ces cartes.

## Ce qu’il faut produire
Deux images, **PNG 1024 × 2048, portrait** :
1. `face.png` : homme athlétique de face.
2. `dos.png` : le même homme de dos.

## Style (celui de la maquette jointe, image du corps de « Mon corps »)
- Rendu anatomique **réaliste en niveaux de gris**, comme une planche d’anatomie photographique : peau gris clair, musculature nette et lisible (pectoraux, deltoïdes, abdominaux, quadriceps, dorsaux…), éclairage doux de studio venant de face, ombres légères.
- Homme athlétique, cheveux courts, visage neutre et calme, **short de sport gris foncé** uni. Pieds nus.
- **Entièrement en niveaux de gris** : aucune couleur, aucune teinte sur les muscles (l’app ajoute la couleur).
- Fond **blanc pur #FFFFFF**, sans ombre portée au sol, sans texte, sans logo.

## Calage (le plus important)
- **Même pose, même silhouette, même taille, même position** que les cartes jointes : bras légèrement écartés, paumes vers l’avant (de face), pieds à largeur de hanches.
- Le corps occupe le même rectangle que les cartes : de (36, 40) à (986, 1982) en pixels, tête en haut, pieds en bas.
- Chaque muscle doit tomber **à l’endroit de sa zone colorée** sur la carte correspondante (pectoraux sur la zone rouge, quadriceps sur la zone cyan, etc.).
- Le dos est la vue strictement postérieure du même homme, calée sur `../corps/dos.png`.

Termine en écrivant `NOTES.md` : ce que tu as produit, le rectangle exact occupé par chaque silhouette, et tout écart au brief.
