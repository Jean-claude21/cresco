# Corps réaliste pour « Mon corps »

Les deux PNG montrent le même homme athlétique de face et de dos, pieds nus, en short de sport gris foncé. Ils sont entièrement en niveaux de gris, sur fond blanc pur et opaque (`#FFFFFF`).

| Fichier | Dimensions | Coin supérieur gauche | Coin inférieur droit |
| --- | --- | --- | --- |
| `face.png` | 1024 × 2048 px | (36, 40) | (986, 1982) |
| `dos.png` | 1024 × 2048 px | (36, 40) | (986, 1982) |

Les coordonnées sont inclusives, mesurées depuis le coin supérieur gauche sur tous les pixels différents du blanc pur. Les deux silhouettes occupent chacune 951 × 1943 px.

## Génération et calage

- **Face.** L’outil de génération d’images de ChatGPT a reçu la carte de face comme gabarit de pose et la maquette G1-04 comme référence de rendu. La consigne demandait un visage calme, des cheveux courts, les paumes vers l’avant, une musculature lisible et un éclairage frontal doux.
- **Dos.** La carte de dos a servi de gabarit, et le rendu de face a servi de référence pour le personnage, le short et la lumière.
- Les deux rendus ont ensuite été recalés sur les repères des cartes, puis détourés selon leurs contours. La vérification pixel par pixel confirme que tout le fond extérieur est blanc, que chaque pixel intérieur appartient à la silhouette et que les trois canaux RVB sont égaux partout.

## Écarts au brief

Le contour extérieur coïncide avec chaque carte. À l’intérieur, la superposition montre de légers décalages entre certains sillons naturels et les séparations schématiques, notamment sur les abdominaux et les dorsaux. Le short recouvre les fessiers et le haut des cuisses, comme sur la maquette. Dans ces zones, la teinte appliquée par l’app apparaîtra sur le tissu.
