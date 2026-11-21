# Cartes musculaires de Cresco

[face.png](face.png) et [dos.png](dos.png) représentent le même mannequin athlétique en position anatomique. Chaque PNG mesure **1024 × 2048 px** et possède un fond blanc opaque `#FFFFFF`, conformément au brief.

| Fichier | Groupes cliquables |
| --- | --- |
| `face.png` | Haut des trapèzes, épaules, pectoraux, biceps, avant-bras, abdominaux et obliques, quadriceps, mollets et tibial antérieur |
| `dos.png` | Trapèzes et grands dorsaux, épaules, triceps, avant-bras, lombaires, fessiers, ischio-jambiers, mollets |

Les deux dessins ont été produits avec l’outil intégré de génération d’images. La vue de face a servi de gabarit pour le dos. À l’export, les aplats ont été ramenés aux valeurs RVB du brief et les contours reconstruits sur une largeur nominale de 3 px.

La relecture de tous les pixels confirme **11 couleurs par fichier** : les huit clés musculaires attendues, le blanc du fond, le gris clair `#D9D9D9` des zones neutres et le gris foncé `#3A3A3A` des contours. Les deux silhouettes occupent le même rectangle, de `(36, 40)` à `(986, 1982)` inclus, depuis le coin supérieur gauche.

## Écarts et limites

La posture et le cadrage concordent. Certains contours locaux diffèrent entre les vues, notamment aux épaules, aux genoux et aux pieds. Sur la grille de pixels, les diagonales et les jonctions peuvent paraître plus épaisses que les segments horizontaux ou verticaux de 3 px.

<details>
<summary>Consignes transmises au générateur</summary>

**Face** — Schéma pédagogique de musculation Cresco. Créer uniquement un mannequin sportif adulte androgyne de face, portant une combinaison de sport intégrale à panneaux de couleurs, dessinée comme une carte musculaire cliquable. Vue orthographique, corps entier, pose symétrique détendue comme sur l'image de référence, bras légèrement écartés, paumes ouvertes vers l'avant, pieds à largeur des hanches. Conserver des proportions athlétiques naturelles. Format vertical 1024 × 2048, sujet centré, marge blanche fine en haut et en bas. Style vectoriel plat, trait gris foncé #3A3A3A de 3 px et aplats. Casque de mannequin lisse, cou antérieur, mains, bassin, genoux, pieds, articulations et tendons gris clair #D9D9D9. Les panneaux anatomiques sont bilatéraux : hauts des trapèzes violet #8000FF entre le cou et les épaules, deltoïdes verts #00FF00, pectoraux rouges #FF0000, biceps bleus #0000FF, avant-bras jaunes #FFFF00, abdominaux et obliques magenta #FF00FF, quadriceps cyan #00FFFF, tibial antérieur et mollets orange #FF8000. Fond blanc pur #FFFFFF. Zones de couleurs très lisibles anatomiquement, contours lisses et nets. Aucun texte, légende, interface, accessoire, logo, dégradé, ombre, texture ou anticrénelage coloré.

**Dos** — Générer la vue strictement POSTÉRIEURE du mannequin sportif de l'image fournie. Celle-ci est un gabarit de recalage précis. Reprendre la même silhouette extérieure, tout le corps, proportions, taille, position et pose identiques jusque dans la position des mains et des pieds. Le mannequin est tourné de 180° et porte la même combinaison anatomique intégrale de sport. Montrer l’arrière du crâne, les dos des mains, les talons, les creux poplités. Même schéma vectoriel plat sans texte. Sur cette vue arrière : trapèze entier en losange ET les deux grands dorsaux VIOLET #8000FF (même violet pour ces trois surfaces), épaules/deltoïdes VERT #00FF00, triceps à l’arrière des bras BLEU AZUR #0080FF, avant-bras JAUNE #FFFF00, lombaires au bas du dos ROSE #FF0080, fessiers VERT CITRON #80FF00, ischio-jambiers VERT MENTHE #00FF80, mollets ORANGE #FF8000. Cou, tête, mains, pieds et tendons y compris tendon d’Achille, articulations en gris clair #D9D9D9. Fond blanc #FFFFFF. Chaque forme a un contour constant gris foncé #3A3A3A de 3 px. En pied centré, portrait 1024 × 2048 ; mêmes marges et même échelle que la référence. Aucune nuance, ombre, texture, légende, accessoire ou anticrénelage coloré.

</details>
