# Cresco sur iPhone

Les cinq vues répondent à trois questions successives. Que prévoit ma journée ? Que dois-je faire maintenant ? Sur plusieurs semaines, est-ce que je progresse ? L’accueil associe chaque décision à sa cause. Pendant l’effort, la charge ou le temps restant prend la première place. Au bilan, le contexte revient au premier plan.

## Direction artistique

Le **vert pin** évoque à la fois la croissance et la solidité. Il sert aux commandes et aux décisions du moteur, y compris lorsque la séance est allégée. Le vert garde ainsi le même sens quel que soit le score. Le monogramme à deux feuilles et les fines lignes de croissance sur les cartes foncées donnent à Cresco une signature discrète.

| Couleur | Code hex | Emploi |
| --- | --- | --- |
| Fond calcaire | `#F4F5EF` | Fond général, séparation douce entre les cartes |
| Blanc | `#FFFFFF` | Surfaces de lecture et de saisie |
| Encre | `#182C24` | Titres, chiffres et pictogrammes système |
| Pin | `#184D3B` | Actions, sélection, courbes et arcs actifs |
| Pin sombre | `#123E31` | Décision de séance, minuteur et verdict |
| Pousse | `#D8EEA1` | Action ou repère ponctuel sur pin sombre |
| Sauge / eucalyptus | `#E3EDDB` / `#427F77` | Pistes de jauge, protéines et historique de FC |
| Texte secondaire / filet | `#56695E` / `#DCE3D8` | Unités, légendes, séparateurs |
| Sable / terre | `#F3EDDE` / `#694F2E` | Fond et texte du niveau de confiance |

**Typographie.** Georgia donne aux grands titres et à l’intention privée le caractère d’un carnet personnel. Arial porte les consignes, les unités et les données. Les titres de page font 39 à 43 pt, les mesures principales 28 à 48 pt et le compte à rebours cardio 81 pt. Les unités restent sur la ligne de base du nombre. Les minutes et secondes occupent une largeur fixe pour que le minuteur reste stable.

**Gabarit.** Les PNG représentent une surface de 402 × 874 pt à l’échelle 3×, soit 1 206 × 2 622 px. Les cartes occupent 366 pt, avec des marges de 18 pt et des gouttières verticales de 12 à 14 pt. Le rayon courant est de 22 pt, réduit à 18 pt sur les petites cartes. Un filet de 0,7 pt et une ombre courte décalée de 2 pt (`#E9EDE4`) soulèvent légèrement les surfaces blanches. Les barres système restent dégagées.

**Commandes.** Les pictogrammes au trait arrondi mesurent 16 à 24 pt. Leurs zones tactiles s’étendent à au moins 44 × 44 pt. La barre flottante conserve quatre destinations nommées et une action « + » indépendante pour consigner une donnée. Les séances en cours réservent cette zone au pouce pour l’action immédiate. En grande taille de texte, les cartes s’allongent et défilent. VoiceOver lit chaque valeur avec son unité, son contexte et son état. L’animation respecte le réglage de réduction des animations.

## 1. Aujourd’hui

[Ouvrir la maquette Aujourd’hui](01-aujourdhui.png)

L’anneau situe la forme à **68 sur 100**. À droite, la nuit de 6 h 05, la VFC de 42 ms et le ressenti de 3 sur 5 restent dans leurs unités d’origine. Toucher le bouton d’information ouvre les composantes utilisées, dont la FC au repos et la fatigue lorsqu’elles sont disponibles, ainsi que la référence personnelle de VFC.

La carte pin traduit ce score en une décision pour le haut du corps. La nuit courte explique le volume réduit de 20 %. Les charges et le RIR cible sont maintenus. « Ouvrir la séance » donne accès au détail avant de démarrer.

La carte énergie montre **640 kcal restantes** sur une cible de 2 150 kcal et **94 g de protéines** sur 150 g. Les deux barres représentent les quantités déjà consommées. Hors jeûne, la ligne « Suivi du jeûne » ouvre le module. Pendant le jeûne illustré à l’écran 4, cette ligne devient **« Jeûne en cours · 17 h 30 »**, la décision de séance reprend le volume réduit de 25 % et la carte énergie affiche « Cibles suspendues pendant le jeûne ». Les compteurs restants et les relances alimentaires disparaissent.

Règles mobilisées dans cette vue : `C-FORME`, `C-AJUST`, `C-ENERGIE-7/8` et `J-DECISION`. [Calculs du moteur](../../science/CALCULS.md) · [Liens entre les données](../../science/LIENS.md)

## 2. Séance en cours

[Ouvrir la maquette Séance](02-seance.png)

L’écran saisit le moment juste après la deuxième série de développé couché. Une image clé originale montre le mouvement. La commande « Animation » permet de mettre la boucle en pause. « Ma vidéo » ouvre le lien personnel associé à l’exercice. Cette commande apparaît dès qu’un lien est renseigné.

La carte de série rassemble la prescription **72,5 kg × 8**, la cible de **2 répétitions en réserve** et le contrôle du RIR réel. Une pression enregistre une valeur. La sélection peut être corrigée pendant le repos. Le dernier bouton « 4+ » ouvre le choix des valeurs supérieures pour conserver une saisie précise.

Dans l’état présenté, le RIR réel est de 2. Le moteur maintient la charge de **72,5 kg** pour la troisième série et la carte en donne la raison. Le minuteur indique **1 min 14 s de repos restant**. L’action « Démarrer la série 3 » reste au même endroit lorsque le compte à rebours arrive à zéro.

La charge vient de `C-PERF-3` et la proposition suivante de `C-PERF-4`. [Calculs du moteur](../../science/CALCULS.md) · [Liens vidéo personnels](../../product/CONFORMITE.md)

## 3. Intervalles cardio

[Ouvrir la maquette Intervalles](03-intervalles.png)

Sur le tapis, l’athlète doit pouvoir lire d’un coup d’œil **ce qui reste de l’effort actuel**. Le cadran principal affiche donc 00:15 avant la fin du quatrième passage rapide, avec la vitesse actuelle à viser, 12 km/h. Le bloc sauge annonce séparément la consigne suivante : passer à 9 km/h dans 15 s pour une minute de récupération. L’annonce vocale reprend cette consigne.

La frise contient six paires de segments. Le segment haut figure l’effort rapide, le segment bas la récupération. Un repère triangulaire indique la position courante, également écrite « Rapide 4/6 ». Les paires sont de largeur constante pour faciliter le comptage. La frise représente l’ordre des phases.

La FC actuelle de **154 bpm** et son historique sur 30 secondes viennent du capteur. En l’absence de mesure récente, la carte affiche « FC indisponible » et interrompt la courbe. La grande commande de pause reste accessible indépendamment de la connexion au capteur. [Données cardio et unités d’affichage](../../science/CALCULS.md)

## 4. Jeûne

[Ouvrir la maquette Jeûne](04-jeune.png)

À 13:30, le cadran de 24 heures relie le début du jeûne, la veille à 20:00, à l’instant présent. Le point plein marque le départ, le point cerclé la position actuelle et le petit trait la fin prévue à 14:00. **17 h 30 écoulées** reste lisible au centre. « Phase estimée · Bascule métabolique » présente un repère temporel, qui varie selon la personne. Le libellé suit la phase renvoyée par le moteur, dont glycogène ou cétose lorsque le contexte s’y prête.

Le sélecteur affiche **Intermittent · 18/6**. Il donne accès aux quatre types du produit : intermittent, à l’eau, sec et partiel (Daniel). Pour Daniel, le suivi présente la durée de la pratique et le repère de protéines végétales. Le cadran métabolique est réservé aux fenêtres sans calories.

La décision en pin indique **volume −25 % et RIR de 2 ou plus** pour la fenêtre illustrée. Un tap consigne 250 ml d’eau. « Signaler » ouvre les symptômes et reste accessible pendant tout le jeûne. En jeûne sec, le raccourci eau disparaît. Un symptôme d’alerte remplace la carte d’entraînement par l’arrêt de la séance et le conseil de rompre le jeûne. « Terminer le jeûne » enregistre la fin réelle et ouvre la reprise adaptée.

L’intention appartient à la personne. Le verset de Matthieu 6,18, en extrait Louis Segond, apparaît ici avec le module foi activé. Le motif spirituel et l’option « priorité spirituelle » sont deux choix distincts. Cette dernière est inactive dans la maquette. Lorsqu’elle est activée, l’app propose la version la plus légère ou un temps de prière. L’accès à l’intention reste privé.

La sécurité et le repos verrouillé gardent la priorité. La décision combine ensuite les règles du jeûne et la forme du jour en retenant la séance la plus prudente. [Jeûne et reprise](../../science/JEUNE.md) · [Module foi](../../science/FOI.md) · [Garde-fous](../../product/CONFORMITE.md)

## 5. Progrès

[Ouvrir la maquette Progrès](05-progres.png)

La semaine du 12 au 18 janvier s’ouvre sur **« Maintien = réussite »**. La force est restée stable dans une semaine où le sommeil moyen était de **6 h 12**. Cette phrase met en regard deux observations. Elle évite d’attribuer à une seule nuit la variation d’une série.

Le sélecteur d’exercice commande toute la carte de force. Pour le développé couché, le dernier e1RM est de **96,7 kg**. Les points figurent les meilleures séries retenues de huit séances sur 28 jours. Le trait fin les relie dans l’ordre et le pointillé représente la tendance du moteur. Les dates, les graduations en kg et la légende restent visibles. Avec moins de quatre séances exploitables, la carte conserve les points disponibles et indique combien de séances manquent pour une tendance.

Le bilan énergie porte sur sept jours, avec un **déficit estimé de −260 kcal/j** et une confiance moyenne. Toucher le niveau de confiance donne accès à la couverture du journal. Les deux cartes du bas présentent le dernier poids lissé, **73,8 kg**, et le sommeil moyen de la semaine. Les fenêtres de 7 et 28 jours restent explicites pour distinguer le contexte récent de la tendance de force.

Les valeurs des cinq maquettes illustrent des états fictifs. En production, le moteur fournit les décisions, les mesures dérivées et leur confiance. La vue affiche aussi l’explication lorsqu’une donnée manque. [Progression et verdict](../../science/CALCULS.md) · [Parcours du verdict](../../science/LIENS.md)
