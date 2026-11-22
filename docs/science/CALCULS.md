# Calculs du moteur

Chaque calcul a un **identifiant** (utilisé dans le code, l'API et les explications), ses entrées, sa formule, ses paramètres par défaut, ses sources et son niveau de preuve.

**Convention importante** : un paramètre marqué **[H]** est une **heuristique de départ choisie par nous**, pas un chiffre tiré d'une étude. Ces paramètres sont stockés en configuration versionnée et recalibrés par utilisateur (voir `C-CALIB`).

Niveaux de preuve : **solide** (méta-analyses concordantes) · **bonne** · **modérée** · **faible** · **[H]** heuristique.

Unités internes en SI : kg, m, s, m/s, kcal. L'affichage convertit (km/h, min/km, lb).

Les références complètes sont dans [SOURCES.md](SOURCES.md) (`[S-xx]`).

---

## 1. Performance : `C-PERF`

### C-PERF-1 : reps effectives
```
reps_eff = reps + RIR
```
RIR = répétitions en réserve (0 = échec). Fiable chez les pratiquants entraînés, moins chez les débutants [S-03][S-04]. Les débutants ont une option « échelle simplifiée » (facile, dur, très dur → RIR 4 / 2 / 0).

### C-PERF-2 : 1RM estimé (e1RM)
```
si reps_eff ≤ 10 :  e1RM = charge × 36 / (37 − reps_eff)        (Brzycki)
sinon             :  e1RM = charge × (1 + reps_eff / 30)          (Epley)
si reps_eff > 12  :  confiance = basse (série exclue de la tendance)
```
Sources : [S-01][S-02]. Preuve : **bonne** sous 10 reps, l'erreur augmente au-delà. Brzycki a proposé sa formule sans étude empirique : la preuve vient des études de validation ultérieures (à ajouter dans SOURCES.md).

Pour une séance, on retient la **meilleure série** (e1RM max) par exercice : c'est le point utilisé par la tendance.

### C-PERF-3 : charge cible (calcul inverse)
```
charge = e1RM_récent × (37 − (reps_cible + RIR_cible)) / 36     (si ≤ 10)
arrondi au pas du matériel (ex. 2,5 kg barre, 1,25 kg haltère, pas de la machine)
```
`e1RM_récent` = moyenne mobile exponentielle des 3 dernières séances sur l'exercice.

### C-PERF-4 : ajustement en cours de séance
```
écart = RIR_réel − RIR_cible
si écart ≥ 2  : série suivante +2,5 à +5 %
si écart ≤ −2 : série suivante −5 à −10 %
sinon         : inchangé
```
**[H]**, inspiré de l'autorégulation RPE [S-04].

### C-PERF-5 : volume efficace
```
séries_efficaces(muscle, semaine) = Σ séries avec RIR ≤ 3
   (muscle primaire = 1 ; secondaire = 0,5)
tonnage = Σ charge × reps        (affiché, non utilisé pour le verdict)
```
Repère hypertrophie : **≥ 10 séries efficaces par muscle et par semaine** [S-05] (solide). La méta-analyse n'a pu établir la relation que jusqu'à environ 10 séries : au-delà, les études divergent (gain supplémentaire ou plateau). La plage proposée par défaut, 10–20, est donc **[H]** au-dessus de 10.

### C-PERF-6 : performance cardio
```
efficacité = vitesse moyenne (m/s) / FC moyenne      (à effort et durée comparables)
km/h = m/s × 3,6     allure (min/km) = 60 / km/h
```
Progression cardio = efficacité en hausse, ou même allure à FC plus basse.

### C-PERF-7 : tendance du volume par muscle — v1, **[H]**
```
semaines = séries efficaces du muscle (C-PERF-5), des plus anciennes à la semaine en cours (4 semaines)
moyenne_précédente = moyenne des semaines avant la semaine en cours
écart = semaine en cours − moyenne_précédente
sens = hausse si écart > 1 série, baisse si écart < −1 série, sinon stable
```
Paramètres : 4 semaines, zone morte d'une série **[H]**. Sert à dire, dans « Mon corps », si un muscle reçoit plus ou moins de travail qu'avant ; aucune décision n'en découle. Fonction : `tendanceVolume`.

---

## 2. Charge et fatigue : `C-CHARGE`

### C-CHARGE-1 : charge de séance (sRPE)
```
sRPE = RPE de séance (CR-10) × durée (min)
```
[S-06], preuve **solide**. Saisi 10 à 30 min après la séance.

### C-CHARGE-2 : TRIMP (cardio avec FC)
```
FCr = (FC − FC_repos) / (FC_max − FC_repos)
TRIMP = durée (min) × FCr × 0,64 × e^(1,92 × FCr)     (homme)
TRIMP = durée (min) × FCr × 0,86 × e^(1,67 × FCr)     (femme)
```
[S-08]. Si la FC est absente, on utilise le sRPE.

### C-CHARGE-3 : FC max et zones
```
FC_max = 208 − 0,7 × âge                (Tanaka) [S-09]
FC_cible = FC_repos + %intensité × (FC_max − FC_repos)   (Karvonen) [S-10]
Zones : Z1 50–60 % · Z2 60–70 % · Z3 70–80 % · Z4 80–90 % · Z5 90–100 %
```
Une FC max mesurée remplace l'estimation.

### C-CHARGE-4 : charge aiguë et chronique
```
aiguë    = moyenne mobile exponentielle sur 7 j  de la charge quotidienne
chronique = moyenne mobile exponentielle sur 28 j
ratio = aiguë / chronique
```
Preuve **faible** : le ratio est contesté sur le plan méthodologique [S-11][S-12]. **Affiché comme indicateur, il ne déclenche jamais seul une décision.** Il entre dans `C-FORME` avec un poids faible.

### C-CHARGE-5 : modèle fitness-fatigue (indicatif)
```
forme_physique(t) = Σ charge(i) × e^(−(t−i)/42)
fatigue(t)        = Σ charge(i) × e^(−(t−i)/7)
performance(t) ≈ k1 × forme_physique − k2 × fatigue
```
[S-07]. Utile pour **visualiser**, imprécis pour prédire une personne. Affiché seulement.

### C-CHARGE-6 : calories d'activité
```
kcal = MET × poids (kg) × durée (h)          [S-14]
VO2 tapis (ml/kg/min) = 0,2·v + 0,9·v·pente + 3,5   (v en m/min, pente en fraction) [S-13]
kcal ≈ VO2 × poids × durée(min) / 1000 × 5
```
Les calories d'une montre, si disponibles, sont prioritaires.

---

## 3. Récupération : `C-RECUP`

### C-RECUP-1 : score sommeil (0–100)
```
durée     = min(1, temps_dormi / besoin)            besoin par défaut 8 h [H], plage 7–9 h [S-25]
efficacité = temps_dormi / temps_au_lit              (cible ≥ 0,85)
profond   = % sommeil profond / moyenne perso 14 j  (borné 0–1,2)
régularité = 1 − min(1, écart-type(milieu de nuit sur 7 j) / 90 min)

score_sommeil = 100 × (0,40·durée + 0,20·efficacité + 0,20·min(1,profond) + 0,20·régularité)
```
Pondérations **[H]**. Sources sur l'importance de la durée et de la régularité : [S-21][S-22][S-24]. Les phases (profond, paradoxal) dépendent de la précision de l'appareil : leur poids reste modéré.

### C-RECUP-2 : dette de sommeil
```
dette_7j = Σ max(0, besoin − dormi)   sur 7 jours
```

### C-RECUP-3 : VFC et FC de repos
```
z_VFC   = (ln rMSSD_jour − moyenne(ln rMSSD, 7 j)) / écart-type(ln rMSSD, 30 j)
z_FCrep = −(FC_repos_jour − moyenne(FC_repos, 7 j)) / écart-type(FC_repos, 30 j)
```
Méthode [S-15][S-16], preuve **modérée**. Mesure au réveil, même position. Sans capteur, ces composantes sont retirées et les poids redistribués.

### C-RECUP-4 : récupération par muscle — v1, **[H]**, preuve faible
```
charge(muscle) = Σ séries efficaces récentes (RIR ≤ 3 ; principal 1, secondaire 0,5)
                 × 1,5 si la série est allée à l'échec (RIR 0)
                 × e^(−heures écoulées / 24)
récupération (%) = 100 × (1 − charge / 8), bornée 0–100 ; prêt à partir de 80 %
heures avant prêt = 24 × ln(charge / 1,6) si charge > 1,6, sinon 0
```
Repères : la récupération neuromusculaire après une séance prend de 24 à 48 h, plus longtemps quand les séries vont jusqu'à l'échec [S-53] ; travailler un muscle au moins deux fois par semaine favorise l'hypertrophie [S-54], ce qui suppose une récupération en 2 à 3 jours. La constante de 24 h, le seuil de 8 séries et le facteur 1,5 sont **[H]**. Affiché dans « Mon corps » à titre indicatif : **ne modifie jamais seul une séance**. Fonction : `recuperationMuscles`.

---

## 4. Énergie et nutrition : `C-ENERGIE`

### C-ENERGIE-1 : métabolisme de base (BMR)
```
Mifflin-St Jeor [S-17] :
  homme = 10·poids + 6,25·taille(cm) − 5·âge + 5
  femme = 10·poids + 6,25·taille(cm) − 5·âge − 161
Si masse grasse connue (Katch-McArdle) [S-19] :
  BMR = 370 + 21,6 × masse_maigre(kg)
```
Mifflin-St Jeor est la plus précise des équations courantes [S-18], preuve **solide**.

### C-ENERGIE-2 : TDEE initial (avant historique)
```
TDEE_0 = BMR × NAP
NAP : sédentaire 1,4 · peu actif 1,55 · actif 1,7 · très actif 1,9
```
Valeur de départ, remplacée par `C-ENERGIE-4` dès qu'il y a assez de données.

### C-ENERGIE-3 : poids lissé
```
T(j) = T(j−1) + α × (poids(j) − T(j−1))      α = 0,1 [H]
```
Les jours sans pesée ne mettent pas T à jour.

### C-ENERGIE-4 : TDEE adaptatif (dépense réelle)
```
Fenêtre N = 21 jours [H] (minimum 14 jours avec ≥ 80 % de jours saisis)
TDEE_obs = moyenne(kcal mangées sur N) − (T(fin) − T(début)) × ρ / N
ρ = 7700 kcal/kg (approximation valable sur une fenêtre courte uniquement)
TDEE(t) = 0,8 × TDEE(t−7) + 0,2 × TDEE_obs        (lissage hebdomadaire) [H]
```
Pourquoi la fenêtre glissante : la règle « 7700 kcal = 1 kg » est **fausse sur la durée**, car le corps s'adapte [S-20]. Ici, elle ne sert qu'à convertir une petite variation sur 3 semaines, et le TDEE se recalibre en continu.

Détection de sous-saisie : si `TDEE_obs < BMR` de façon durable, l'app signale une saisie probablement incomplète au lieu de baisser les cibles.

### C-ENERGIE-5 : bilan et verdict énergie
```
bilan_jour = kcal_mangées − TDEE(t)
bilan_moyen_7j = moyenne(bilan_jour sur 7 j)
verdict : déficit   si bilan_moyen < −5 % TDEE
          maintien  si −5 % ≤ bilan_moyen ≤ +5 %
          surplus   si bilan_moyen > +5 %
confiance : haute (≥ 21 j, ≥ 90 % saisis) · moyenne · basse
```
Seuils ±5 % **[H]**. Affichage type : « Déficit estimé −420 kcal/j · confiance moyenne ».

### C-ENERGIE-6 : énergie des macros (Atwater)
```
kcal = 4 × glucides + 4 × protéines + 9 × lipides + 7 × alcool    (g)
```

### C-ENERGIE-7 : cibles de macros
Ordre : kcal cible → protéines → lipides → glucides (le reste).

```
kcal_cible = TDEE × (1 + ajustement_objectif)
   perte : −10 à −25 % (jamais < BMR)  · maintien : 0  · prise : +5 à +10 %   [H]

protéines = 1,6 g/kg (maintien, prise) [S-26]
            2,0–2,2 g/kg en déficit, ou 2,3–3,1 g/kg de masse maigre [S-27]
lipides   = 25–35 % des kcal [H], jamais < 0,5 g/kg
            (repères : AMDR 20–35 % ; ANSES 35–40 % des AET pour la population générale [S-30])
glucides  = (kcal_cible − 4·prot − 9·lip) / 4
            contrôle : muscu 4–7 g/kg [S-29] ; endurance 6–10 g/kg [S-28]
fibres    = 30 g/j [S-30]
sucres ajoutés < 10 % des kcal [S-31]
```

### C-ENERGIE-8 : répartition et modulation
```
protéines par repas ≈ 0,4 g/kg, sur 3–4 repas [S-32]
jour d'entraînement : glucides +10 à +20 % ; jour de repos : −10 à −20 % (kcal totales conservées sur la semaine) [H]
jour de jeûne : cibles suspendues, voir J-REPRISE
```

### C-ENERGIE-9 : recettes (« Mes plats »)
```
nutriment(plat, par 100 g) = Σ (nutriment_ingrédient × masse_ingrédient_crue) / masse_plat_cuit
facteur de cuisson = masse_cuite / masse_crue (pesée, ou par défaut selon le mode de cuisson)
masse d'une portion = masse_plat_cuit / nombre de portions du plat (1 par défaut : le plat entier)
masse servie = masse en grammes, ou nombre de portions × masse d'une portion (100 g si inconnue)
portion = masse servie × nutriment(par 100 g) / 100
```
Fonctions : `nutrimentsPlat` (dont `massePortion`) et `portion`.
Les ingrédients viennent de Ciqual, d'Open Food Facts ou d'une saisie personnelle. L'IA peut créer un plat via MCP, et le moteur recalcule les valeurs (l'IA ne fournit que les ingrédients et les quantités).

---

## 5. Score de forme du jour : `C-FORME`

```
composantes (0–100) :
  sommeil   = score_sommeil
  VFC       = 50 + 15 × z_VFC        (borné 0–100)
  FC_repos  = 50 + 15 × z_FCrep      (borné 0–100)
  ressenti  = (énergie_1à5 − 1) × 25, moins pénalité courbatures
  fatigue   = 100 − 50 × max(0, ratio_aigu_chronique − 1)   (borné 0–100)

forme = 0,35·sommeil + 0,25·VFC + 0,10·FC_repos + 0,20·ressenti + 0,10·fatigue
si jeûne en cours > 16 h : forme −10
composante absente → poids redistribué proportionnellement
```
Toutes les pondérations sont **[H]** et recalibrées par `C-CALIB`.

## 6. Séance ajustée : `C-AJUST`

| Score | Séance |
|---|---|
| ≥ 75 | Plan normal, progression de charge autorisée |
| 50–74 | Volume −20 %, charges et RIR cible maintenus |
| < 50 | Séance légère (technique, mobilité, cardio Z1–Z2) ou repos |
| Jour de repos verrouillé | Rien n'est programmé |

Seuils **[H]**. Les règles jeûne (`J-DECISION`) priment sur ce tableau.

---

## 7. Progression : `C-PROG` et `C-VERDICT`

### C-PROG-1 : tendance par exercice
```
points = (date, e1RM retenu) des 28 derniers jours, ≥ 4 séances
pente = régression linéaire (moindres carrés) de e1RM sur le temps, en kg/semaine
pente_% = pente / moyenne(e1RM) × 100     (% par semaine)
```

### C-PROG-2 : seuils de progression attendue
| Niveau | Seuil pente_% |
|---|---|
| Débutant (< 1 an) | ≥ 1,0 %/semaine |
| Intermédiaire (1–3 ans) | ≥ 0,5 %/semaine |
| Avancé (> 3 ans) | ≥ 0,25 %/semaine |

**[H]** : ordres de grandeur cohérents avec le ralentissement des gains avec l'expérience, à affiner par `C-CALIB`.

### C-PROG-3 : contexte défavorable (semaine)
```
défavorable si au moins une condition :
  sommeil moyen < 6 h 30
  bilan_moyen_7j < −15 % TDEE
  ≥ 2 jours de jeûne (> 16 h)
  maladie ou blessure déclarée
```
**[H]**. Effet du manque de sommeil sur la performance : [S-21][S-22][S-23].

### C-VERDICT : verdict hebdomadaire
```
si pente_% ≥ seuil                         → « Tu progresses »
sinon si contexte défavorable              → « Maintien = réussite » (cause citée)
sinon si pente_% < seuil depuis ≥ 3 semaines → « Stagnation » → proposer deload, variante ou ajustement du volume
sinon                                      → « Patience »
```

Contrôle croisé avec le corps (poids lissé `T` et tour de taille sur 4 semaines) :

| T | e1RM | Taille | Interprétation |
|---|---|---|---|
| ↑ | ↑ | stable | Prise de muscle probable |
| ↓ | stable ou ↑ | ↓ | Perte de gras réussie |
| ↓ | ↓ | — | Déficit trop fort ou protéines insuffisantes |
| ↑ | stable | ↑ | Surplus trop fort |

---

## 8. Calibrage personnel : `C-CALIB`

v1, **[H]**. Après au moins 20 jours de séance où la forme du jour est connue :
```
cible(jour) = moyenne, sur les séries du jour, de (e1RM / e1RM moyen du même exercice sur les 28 jours précédents − 1)
r(composante) = corrélation de Pearson entre la composante de C-FORME (0–100) et la cible, sur ces jours
poids_estimé(composante) ∝ max(0, r)          (moins de 20 jours pour une composante : 0)
nouveaux poids = 0,7 × poids_défaut + 0,3 × poids_estimé, puis normalisés (somme 1)
aucune corrélation positive : poids par défaut
```
La confiance de C-FORME reste calculée sur les poids par défaut (couverture des données). Les poids personnels sont visibles dans l'API (`forme.poids`) et l'utilisateur peut revenir aux poids par défaut (préférence `calibrageForme`). Fonctions : `poidsPersonnels`, `scoreForme` (paramètre `poids`).

## 9. Confiance et données manquantes

Chaque résultat renvoie `confiance ∈ {haute, moyenne, basse}` selon la couverture des données (jours saisis, capteurs présents, nombre de séances). Une confiance basse **n'entraîne jamais** de changement de plan automatique : l'app affiche et explique seulement.

## 10. Démarrage à froid

Pendant les 2 premières semaines : e1RM issu d'une séance test (charge × reps au RIR 2), TDEE_0 par NAP, pondérations par défaut, aucun verdict de stagnation.
