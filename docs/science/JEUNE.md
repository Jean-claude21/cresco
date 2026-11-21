# Module jeûne

Le jeûne est au cœur de Cresco. Il est d'abord **spirituel** : l'app le protège et s'y adapte, sans le transformer en outil de performance. Elle s'appuie sur la science pour répondre à deux questions :

1. **Est-ce que je m'entraîne aujourd'hui, et comment ?**
2. **Est-ce que le jeûne me fait du bien, à moi ?** (mesure personnelle)

## 1. Types de jeûne (v1)

| Type | Définition | Particularités |
|---|---|---|
| `intermittent` | Fenêtre sans calories (ex. 16/8, 18/6, 20/4) | Eau, café et thé sans sucre autorisés |
| `eau` | Aucune calorie, eau à volonté, durée ≥ 24 h | Électrolytes conseillés au-delà de 24 h |
| `sec` | Ni nourriture ni eau (ex. jeûne de type Ramadan, jeûne biblique d'Esther 4:16) | Limité à 24 h dans l'app ; rupture souvent le soir |
| `partiel` | Restriction d'aliments, pas de calories (ex. jeûne de Daniel : végétal, sans viande, sans sucreries, sans vin, Daniel 1:12 et 10:3 ; la version étudiée [S-51] exclut aussi les produits transformés, la caféine et l'alcool) | Entraînement normal ; vigilance sur les protéines ; l'apport baisse souvent (≈ −20 % dans [S-51]) |

Chaque jeûne a un **motif** : `spirituel | sante | autre`, et une **intention** libre (texte, optionnel, privé).

## 2. Ce qui se passe dans le corps

| Phase | Heures | Physiologie dominante | Sources |
|---|---|---|---|
| Post-repas | 0–12 h | Glucose et insuline issus du repas | [S-40] |
| Glycogène | 12–16 h | Insuline basse, glycogène hépatique mobilisé | [S-40][S-41] |
| Bascule métabolique | 16–24 h | Graisses mobilisées, cétones qui montent (bascule vers 12–36 h selon la personne) | [S-41] |
| Cétose | 24–72 h | Cétose installée ; hormone de croissance nettement augmentée (≈ ×5 à 2 jours), noradrénaline en hausse | [S-42][S-40] |
| Prolongé | > 72 h | Économie protéique progressive ; enjeu des électrolytes | [S-40] |

L'« autophagie » est démontrée chez l'animal ; **chez l'humain, les preuves sont faibles**. Cresco n'en fait pas un argument.

## 3. Ce que dit la science sur l'entraînement

| Question | Réponse | Preuve | Sources |
|---|---|---|---|
| Muscu à jeun (après la nuit) vs nourri | Effets similaires sur force, hypertrophie, composition | Bonne | [S-46] |
| Jeûne intermittent + muscu : perte de muscle ? | Masse maigre maintenue, masse grasse en baisse, si protéines ≥ 1,6 g/kg | Bonne | [S-43][S-44][S-45][S-48] |
| Le jeûne améliore-t-il la performance ? | Pas clairement ; il aide au poids et au gras | Bonne | [S-47] |
| Endurance à jeun | Aucune différence sur les efforts courts ; manger avant améliore les efforts aérobies prolongés (46 études) | Modérée | [S-49] |
| Jeûne sec (type Ramadan) | Force et anaérobie plutôt maintenues ; aérobie et puissance en baisse, surtout le matin | Modérée, mixte | [S-50] |
| Jeûne de Daniel | Bien toléré, profil métabolique amélioré | Modérée | [S-51] |

**Conclusion pour le produit** : en moyenne, le jeûne ne « booste » pas la performance physique, mais il ne l'abîme pas tant qu'il est court, hydraté et accompagné d'assez de protéines. L'effet réel varie selon la personne : d'où `J-EFFET`.

## 4. Décision d'entraînement : `J-DECISION`

### Entrées
- `type`, `heures_ecoulees`, `jour_n` (pour les jeûnes de plusieurs jours)
- `score_forme` (`C-FORME`)
- `symptomes` : vertiges, faiblesse marquée, palpitations, confusion, nausées, malaise
- `hydratation` (sauf jeûne sec) et électrolytes
- préférence `priorite_spirituelle` (booléen)

### Règles (par ordre de priorité)
```
1. symptôme d'alerte                           → ARRÊT : pas de séance, conseil de rompre le jeûne
2. jour de repos verrouillé                    → REPOS
3. priorite_spirituelle = vrai                 → proposer la version la plus légère ou un temps de prière à la place
4. selon type et phase :
   intermittent ≤ 16 h                         → NORMALE (muscu idéale en fin de fenêtre, repas protéiné ensuite)
   16–24 h (intermittent ou eau)               → ADAPTÉE : volume −25 %, RIR ≥ 2, pas d'échec, cardio Z2 ≤ 45 min, pas de HIIT long
   eau 24–72 h                                 → LÉGÈRE : technique à charges modérées (jour 1), marche et mobilité (jours 2–3)
   eau > 72 h                                  → REPOS ACTIF : marche, étirements ; alerte « avis médical recommandé »
   sec                                         → reculer d'une phase ; aucun effort intense ; si rupture le soir, séance après la rupture (1 à 2 h après le repas) ou séance très légère juste avant
   partiel (Daniel)                            → NORMALE ; cible protéines végétales renforcée
5. combiner avec C-AJUST : on prend la plus prudente des deux décisions
```
Les seuils et réductions sont des **[H]** construits sur les études ci-dessus. Ils sont versionnés et recalibrés par `J-EFFET`.

### Sorties
`NORMALE | ADAPTÉE | LÉGÈRE | REPOS_ACTIF | REPOS | ARRÊT`, accompagnée de la règle appliquée et de ses sources.

## 5. Reprise alimentaire : `J-REPRISE`

| Durée du jeûne | Reprise |
|---|---|
| < 24 h | Repas normal, riche en protéines (≈ 0,4 g/kg) |
| 24–72 h | Progressive : un premier repas léger (protéines + glucides modérés), un repas complet 2–3 h après |
| > 5 jours | Très progressive sur plusieurs jours ; **risque de syndrome de renutrition** [S-52] ; avis médical recommandé |
| Sec | Réhydratation d'abord (eau, électrolytes), puis repas |

Les jours de jeûne, les cibles de `C-ENERGIE-7` sont **suspendues** : aucune invitation à manger pendant un jeûne spirituel.

## 6. Effet personnel du jeûne : `J-EFFET`

```
pour chaque indicateur X ∈ {e1RM vs tendance, écart RIR, score forme, VFC, sommeil, clarté mentale 1–5, ressenti spirituel 1–5 (optionnel)} :
  effet(X) = moyenne(X | jours de jeûne de même type et phase) − moyenne(X | jours sans jeûne, mêmes jours de semaine)
  incertitude = intervalle à 80 % par approximation normale : effet ± 1,2816 × √(var_pendant/n + var_hors/m)
                (déterministe, pour que les moteurs Dart et TypeScript donnent le même résultat)
verdict affiché si ≥ 6 jeûnes comparables, sinon « encore N jeûnes pour conclure »
```
Exemple : « Pendant tes jeûnes de 16 à 24 h : force stable (−1 %), clarté mentale +0,8, sommeil −15 min. »

L'effet mesuré peut ajuster **chez toi** les réductions de `J-DECISION` (par exemple −15 % au lieu de −25 % si ta force est stable), dans des bornes de sécurité fixes.

## 7. Données saisies pendant un jeûne

| Donnée | Saisie |
|---|---|
| Début, fin prévue, fin réelle | Minuteur |
| Type, motif, intention | Au démarrage |
| Eau, électrolytes | Tap (sauf jeûne sec) |
| Symptômes | Tap, à tout moment (déclenche `J-DECISION`) |
| Clarté mentale, énergie (1–5) | Matin et soir |
| Ressenti spirituel (1–5) | Optionnel, module foi |
| Poids | Optionnel (attention : la perte d'eau fausse la lecture) |

Le poids pendant un jeûne est **exclu** de `C-ENERGIE-4` (variation d'eau et de glycogène).

## 8. Sécurité

Voir [CONFORMITE.md](../product/CONFORMITE.md) : questionnaire avant le premier jeûne long, limites (sec ≤ 24 h, alerte > 72 h), mineurs exclus, arrêt sur symptôme.
