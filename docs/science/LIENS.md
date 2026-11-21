# Liens entre les données

Ce document montre **comment chaque donnée saisie ou importée influence les calculs**, et donc la séance du jour et le verdict de progression. Les formules sont dans [CALCULS.md](CALCULS.md), et chaque bloc renvoie à son identifiant (`C-…`).

## 1. Vue d'ensemble

```mermaid
flowchart TB
  subgraph Sources["Ce que tu fais ou importes"]
    M[Muscu<br/>séries, reps, charge, RIR]
    K[Cardio<br/>vitesse, durée, FC]
    N[Nutrition<br/>scan, plats, macros]
    S[Sommeil<br/>durée, phases, horaires]
    J[Jeûne<br/>type, début, fin, symptômes]
    R[Ressenti<br/>énergie, courbatures]
    B[Corps<br/>poids, tour de taille]
  end
  subgraph Calculs["Moteur de calcul"]
    CH[Charge<br/>C-CHARGE]
    PE[Performance<br/>C-PERF]
    EN[Énergie<br/>C-ENERGIE]
    RE[Récupération<br/>C-RECUP]
  end
  M --> CH & PE
  K --> CH & PE
  N --> EN
  B --> EN
  J --> EN & RE
  S --> RE
  R --> RE
  CH --> FO[Score de forme du jour<br/>C-FORME]
  RE --> FO
  EN --> FO
  PE --> PR[Tendance de progression<br/>C-PROG]
  EN --> PR
  CH --> PR
  B --> PR
  FO --> SE[Séance du jour ajustée<br/>C-AJUST]
  J --> SE
  PR --> VE[Verdict hebdo : j'évolue ?<br/>C-VERDICT]
  SE -. la séance réalisée redevient une donnée .-> M
```

## 2. Une journée type

| Moment | Ce que tu fais | Ce que l'app calcule |
|---|---|---|
| Réveil | Rien (import auto) + ressenti en 1 tap | Score sommeil, VFC et FC repos vs ta référence, **score de forme** |
| Avant séance | Tu ouvres la séance | **Séance ajustée** (volume, charges, RIR cible), règles jeûne si un jeûne est en cours |
| Pendant | Tu valides chaque série et son RIR | **Charge de la série suivante**, e1RM en direct |
| Après | RPE de la séance | **sRPE**, e1RM retenu par exercice, volume efficace |
| Repas | Scan, plat favori ou dictée à l'IA | Kcal et macros vs cibles, protéines par repas |
| Soir | Rien | **Bilan énergie** du jour ; nuit suivante → score du lendemain |
| Dimanche | Rien (pesée et tour de taille conseillés) | **Verdict hebdomadaire**, TDEE adaptatif recalculé |

## 3. Le verdict « est-ce que j'évolue ? »

```mermaid
flowchart TB
  A[Tendance e1RM par exercice<br/>pente sur 4 semaines] --> B{Pente ≥ seuil<br/>selon ton niveau ?}
  B -- oui --> P[Tu progresses<br/>on continue le plan]
  B -- non --> C{Contexte défavorable ?<br/>sommeil, déficit, jeûne}
  C -- oui --> M[Maintien = réussite<br/>cause expliquée]
  C -- non --> D{Stagnation ≥ 3 semaines<br/>sans cause ?}
  D -- oui --> X[Ajuster le plan<br/>deload ou variante]
  D -- non --> W[Patience<br/>réévalué la semaine suivante]
```

Le verdict est croisé avec la composition corporelle (voir `C-VERDICT`). La force seule ne dit pas tout.

## 4. Le jeûne dans le système

```mermaid
flowchart LR
  J[Jeûne en cours<br/>type + heures écoulées] --> PH[Phase<br/>0–12 / 12–16 / 16–24 / 24–72 / 72+ h]
  SY[Symptômes] --> STOP{Symptôme d'alerte ?}
  STOP -- oui --> ARRET[Arrêt séance<br/>conseil de rompre]
  STOP -- non --> DEC
  PH --> DEC[Décision séance<br/>J-DECISION]
  FO[Score de forme] --> DEC
  PRI[Priorité spirituelle ?] --> DEC
  DEC --> SE[Normale / adaptée / légère / repos actif]
  J --> RP[Plan de reprise<br/>J-REPRISE]
  J --> EF[Effet personnel du jeûne<br/>J-EFFET]
```

Détail dans [JEUNE.md](JEUNE.md).

## 5. Qui dépend de quoi

| Calcul | Dépend de | Influence |
|---|---|---|
| `C-PERF` (e1RM, volume) | Séries muscu | `C-PROG`, `C-AJUST` (charges cibles) |
| `C-CHARGE` (sRPE, TRIMP, aigu/chronique) | Muscu, cardio | `C-FORME`, `C-PROG` (contexte) |
| `C-RECUP` (sommeil, VFC, FC repos) | Sommeil, capteurs, jeûne | `C-FORME`, `C-VERDICT` (contexte) |
| `C-ENERGIE` (bilan, TDEE, macros) | Nutrition, poids, jeûne | `C-FORME`, `C-VERDICT` (contexte) |
| `C-FORME` | Récupération, charge, énergie, ressenti, jeûne | `C-AJUST` |
| `C-PROG` | Performance + contexte | `C-VERDICT` |
| `J-DECISION` | Jeûne, forme, symptômes, préférence | Séance du jour (prioritaire sur `C-AJUST`) |
| `J-EFFET` | Jours de jeûne vs jours normaux | Rapport personnel, recalibrage |

**Ordre de priorité des règles** : sécurité (symptômes) > jour de repos verrouillé > jeûne (`J-DECISION`) > score de forme (`C-AJUST`) > plan.
