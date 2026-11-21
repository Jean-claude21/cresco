// Moteur de calcul Cresco. Chaque fonction correspond à une règle de docs/science/CALCULS.md ou
// JEUNE.md (identifiant dans le commentaire). Aucune IA ici : entrées → sorties, testées par
// engine-spec/cases.json, identiques côté Dart (packages/cresco_engine).

export type Confiance = 'haute' | 'moyenne' | 'basse';
export type Sexe = 'homme' | 'femme';
export type Decision = 'NORMALE' | 'ADAPTEE' | 'LEGERE' | 'REPOS_ACTIF' | 'REPOS' | 'ARRET';
export type TypeJeune = 'intermittent' | 'eau' | 'sec' | 'partiel';
export type Niveau = 'debutant' | 'intermediaire' | 'avance';

const borne = (x: number, min: number, max: number) => Math.min(max, Math.max(min, x));
const moyenne = (xs: readonly number[]) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0);

// ---------------------------------------------------------------- C-PERF

/** C-PERF-1 */
export const repsEffectives = (reps: number, rir: number) => reps + rir;

/** C-PERF-2 : Brzycki jusqu'à 10 reps effectives, Epley au-delà. */
export function e1rm(e: { charge: number; reps: number; rir: number }) {
  const r = repsEffectives(e.reps, e.rir);
  const brzycki = r <= 10;
  const valeur = brzycki ? (e.charge * 36) / (37 - r) : e.charge * (1 + r / 30);
  const confiance: Confiance = r <= 10 ? 'haute' : r <= 12 ? 'moyenne' : 'basse';
  return { valeur, confiance, formule: brzycki ? 'brzycki' : 'epley' } as const;
}

/** C-PERF-3 : charge pour reps + RIR cibles, arrondie au pas du matériel. */
export function chargeCible(e: { e1rm: number; reps: number; rir: number; pas: number }) {
  const r = repsEffectives(e.reps, e.rir);
  const brute = r <= 10 ? (e.e1rm * (37 - r)) / 36 : e.e1rm / (1 + r / 30);
  const pas = e.pas > 0 ? e.pas : 0.5;
  return { valeur: Math.round(brute / pas) * pas };
}

/** C-PERF-4 [H] */
export function ajustementSerie(e: { rirReel: number; rirCible: number }) {
  const ecart = e.rirReel - e.rirCible;
  return { facteur: ecart >= 2 ? 1.025 : ecart <= -2 ? 0.95 : 1 };
}

/** C-PERF-5 : séries avec RIR ≤ 3 ; primaire 1, secondaire 0,5. */
export function seriesEfficaces(e: { series: readonly { rir: number; primaires: readonly string[]; secondaires: readonly string[] }[] }) {
  const total: Record<string, number> = {};
  for (const s of e.series) {
    if (s.rir > 3) continue;
    for (const m of s.primaires) total[m] = (total[m] ?? 0) + 1;
    for (const m of s.secondaires) total[m] = (total[m] ?? 0) + 0.5;
  }
  return total;
}

/** C-PERF-5 guideline: at least 10 effective sets per muscle per week for hypertrophy [S-05]. */
export const EFFECTIVE_SETS_GUIDELINE = 10;

/** C-PERF-6 */
export const efficaciteCardio = (vitesseMs: number, fcMoyenne: number) => (fcMoyenne > 0 ? vitesseMs / fcMoyenne : 0);

// ---------------------------------------------------------------- C-CHARGE

/** C-CHARGE-1 */
export const srpe = (e: { rpe: number; minutes: number }) => ({ valeur: e.rpe * e.minutes });

/** C-CHARGE-2 */
export function trimp(e: { minutes: number; fc: number; fcRepos: number; fcMax: number; sexe: Sexe }) {
  const fcr = borne((e.fc - e.fcRepos) / (e.fcMax - e.fcRepos), 0, 1);
  const [a, b] = e.sexe === 'homme' ? [0.64, 1.92] : [0.86, 1.67];
  return { valeur: e.minutes * fcr * a * Math.exp(b * fcr) };
}

/** C-CHARGE-3 */
export const fcMax = (e: { age: number }) => ({ valeur: 208 - 0.7 * e.age });
export const fcCible = (e: { fcRepos: number; fcMax: number; intensite: number }) => ({
  valeur: e.fcRepos + e.intensite * (e.fcMax - e.fcRepos),
});

/** Moyenne mobile exponentielle sur n jours (α = 2 / (n + 1)), amorcée sur la première valeur. */
export function ewma(valeurs: readonly number[], jours: number) {
  if (!valeurs.length) return 0;
  const alpha = 2 / (jours + 1);
  let m = valeurs[0]!;
  for (const v of valeurs.slice(1)) m = m + alpha * (v - m);
  return m;
}

/** C-CHARGE-4 (indicatif) */
export function ratioAiguChronique(e: { charges: readonly number[] }) {
  const aigue = ewma(e.charges, 7);
  const chronique = ewma(e.charges, 28);
  return { aigue, chronique, ratio: chronique > 0 ? aigue / chronique : 1 };
}

/** C-CHARGE-6 */
export const kcalMet = (e: { met: number; poids: number; heures: number }) => ({ valeur: e.met * e.poids * e.heures });

// ---------------------------------------------------------------- C-RECUP

/** C-RECUP-1 [H] */
export function scoreSommeil(e: {
  dormiMin: number;
  auLitMin: number;
  besoinMin?: number;
  profondPct?: number;
  profondMoyenPct?: number;
  ecartTypeMilieuMin?: number;
}) {
  const besoin = e.besoinMin ?? 480;
  const duree = Math.min(1, e.dormiMin / besoin);
  const efficacite = e.auLitMin > 0 ? Math.min(1, e.dormiMin / e.auLitMin) : 0;
  const profond =
    e.profondPct != null && e.profondMoyenPct ? Math.min(1, borne(e.profondPct / e.profondMoyenPct, 0, 1.2)) : duree;
  const regularite = e.ecartTypeMilieuMin != null ? 1 - Math.min(1, e.ecartTypeMilieuMin / 90) : 0.5;
  return { valeur: 100 * (0.4 * duree + 0.2 * efficacite + 0.2 * profond + 0.2 * regularite) };
}

/** C-RECUP-2 */
export const detteSommeil = (dormisMin: readonly number[], besoinMin = 480) =>
  dormisMin.slice(-7).reduce((d, x) => d + Math.max(0, besoinMin - x), 0);

/** C-RECUP-3 */
export const zScore = (e: { valeur: number; moyenne: number; ecartType: number }) => ({
  valeur: e.ecartType > 0 ? (e.valeur - e.moyenne) / e.ecartType : 0,
});

// ---------------------------------------------------------------- C-ENERGIE

/** C-ENERGIE-1 */
export function bmr(e: { sexe: Sexe; poids: number; taille: number; age: number; masseMaigre?: number }) {
  if (e.masseMaigre) return { valeur: 370 + 21.6 * e.masseMaigre, formule: 'katch' } as const;
  const base = 10 * e.poids + 6.25 * e.taille - 5 * e.age;
  return { valeur: base + (e.sexe === 'homme' ? 5 : -161), formule: 'mifflin' } as const;
}

export const NAP = { sedentaire: 1.4, peu_actif: 1.55, actif: 1.7, tres_actif: 1.9 } as const;
/** C-ENERGIE-2 */
export const tdeeInitial = (e: { bmr: number; activite: keyof typeof NAP }) => ({ valeur: e.bmr * NAP[e.activite] });

/** C-ENERGIE-3 [H] α = 0,1 */
export function poidsLisse(e: { pesees: readonly number[]; alpha?: number }) {
  const alpha = e.alpha ?? 0.1;
  const serie: number[] = [];
  for (const p of e.pesees) serie.push(serie.length ? serie.at(-1)! + alpha * (p - serie.at(-1)!) : p);
  return { serie };
}

/** C-ENERGIE-4 : ne baisse jamais sous le BMR (sous-saisie probable). */
export function tdeeAdaptatif(e: {
  apportMoyen: number;
  tendanceDebut: number;
  tendanceFin: number;
  jours: number;
  tdeePrecedent: number;
  bmr: number;
}) {
  const observe = e.apportMoyen - ((e.tendanceFin - e.tendanceDebut) * 7700) / e.jours;
  const sousSaisie = observe < e.bmr;
  const valeur = sousSaisie ? e.tdeePrecedent : 0.8 * e.tdeePrecedent + 0.2 * observe;
  return { observe, valeur, sousSaisie };
}

/** C-ENERGIE-5 [H] ±5 % */
export function verdictEnergie(e: { bilanMoyen: number; tdee: number; joursSaisis: number; joursFenetre: number }) {
  const pct = e.tdee > 0 ? e.bilanMoyen / e.tdee : 0;
  const verdict = pct < -0.05 ? 'deficit' : pct > 0.05 ? 'surplus' : 'maintien';
  const couverture = e.joursFenetre > 0 ? e.joursSaisis / e.joursFenetre : 0;
  const confiance: Confiance =
    e.joursFenetre >= 21 && couverture >= 0.9 ? 'haute' : e.joursFenetre >= 14 && couverture >= 0.8 ? 'moyenne' : 'basse';
  return { verdict, confiance, pct } as const;
}

/** C-ENERGIE-6 (Atwater) */
export const kcalMacros = (e: { glucides: number; proteines: number; lipides: number; alcool?: number }) => ({
  valeur: 4 * e.glucides + 4 * e.proteines + 9 * e.lipides + 7 * (e.alcool ?? 0),
});

export type Objectif = 'perte' | 'maintien' | 'prise';
/** C-ENERGIE-7 : kcal → protéines → lipides → glucides. Jamais sous le BMR. */
export function ciblesMacros(e: {
  tdee: number;
  bmr: number;
  poids: number;
  objectif: Objectif;
  ajustement?: number;
  partLipides?: number;
}) {
  const defaut = e.objectif === 'perte' ? -0.15 : e.objectif === 'prise' ? 0.075 : 0;
  const ajustement =
    e.objectif === 'perte' ? borne(e.ajustement ?? defaut, -0.25, -0.1) : e.objectif === 'prise' ? borne(e.ajustement ?? defaut, 0.05, 0.1) : 0;
  const kcal = Math.max(e.bmr, e.tdee * (1 + ajustement));
  const proteines = (e.objectif === 'perte' ? 2.2 : 1.6) * e.poids;
  const lipides = Math.max(0.5 * e.poids, (kcal * borne(e.partLipides ?? 0.3, 0.25, 0.35)) / 9);
  const glucides = Math.max(0, (kcal - 4 * proteines - 9 * lipides) / 4);
  return { kcal, proteines, lipides, glucides };
}

/** C-ENERGIE-8 */
export const proteinesParRepas = (poids: number) => 0.4 * poids;

/** C-ENERGIE-9 */
export function nutrimentsPlat(e: {
  ingredients: readonly { masse: number; kcal100: number; proteines100?: number; glucides100?: number; lipides100?: number }[];
  masseCuite?: number;
}) {
  const crue = e.ingredients.reduce((s, i) => s + i.masse, 0);
  const masse = e.masseCuite && e.masseCuite > 0 ? e.masseCuite : crue;
  const somme = (k: 'kcal100' | 'proteines100' | 'glucides100' | 'lipides100') =>
    e.ingredients.reduce((s, i) => s + ((i[k] ?? 0) * i.masse) / 100, 0);
  const par100 = (x: number) => (masse > 0 ? (x / masse) * 100 : 0);
  return {
    kcal100: par100(somme('kcal100')),
    proteines100: par100(somme('proteines100')),
    glucides100: par100(somme('glucides100')),
    lipides100: par100(somme('lipides100')),
    masse,
  };
}

// ---------------------------------------------------------------- C-FORME, C-AJUST

/** C-FORME [H] : composantes absentes → poids redistribués. */
export function scoreForme(e: {
  sommeil?: number;
  zVfc?: number;
  zFcRepos?: number;
  energie?: number;
  courbatures?: number;
  ratioAiguChronique?: number;
  heuresJeune?: number;
}) {
  const composantes: [number, number | undefined][] = [
    [0.35, e.sommeil],
    [0.25, e.zVfc == null ? undefined : borne(50 + 15 * e.zVfc, 0, 100)],
    [0.1, e.zFcRepos == null ? undefined : borne(50 + 15 * e.zFcRepos, 0, 100)],
    [0.2, e.energie == null ? undefined : borne((e.energie - 1) * 25 - 10 * (e.courbatures ?? 0), 0, 100)],
    [0.1, e.ratioAiguChronique == null ? undefined : borne(100 - 50 * Math.max(0, e.ratioAiguChronique - 1), 0, 100)],
  ];
  const presentes = composantes.filter(([, v]) => v != null) as [number, number][];
  const poids = presentes.reduce((s, [w]) => s + w, 0);
  let valeur = poids > 0 ? presentes.reduce((s, [w, v]) => s + w * v, 0) / poids : 50;
  if ((e.heuresJeune ?? 0) > 16) valeur -= 10;
  return { valeur: borne(valeur, 0, 100), confiance: (poids >= 0.9 ? 'haute' : poids >= 0.55 ? 'moyenne' : 'basse') as Confiance };
}

const VOLUME: Record<Decision, number> = { NORMALE: 0, ADAPTEE: -0.2, LEGERE: -0.5, REPOS_ACTIF: -1, REPOS: -1, ARRET: -1 };
const PRUDENCE: Decision[] = ['NORMALE', 'ADAPTEE', 'LEGERE', 'REPOS_ACTIF', 'REPOS', 'ARRET'];

/** C-AJUST [H] */
export function ajustementSeance(e: { forme: number; reposVerrouille: boolean }): { decision: Decision; volume: number } {
  const decision: Decision = e.reposVerrouille ? 'REPOS' : e.forme >= 75 ? 'NORMALE' : e.forme >= 50 ? 'ADAPTEE' : 'LEGERE';
  return { decision, volume: VOLUME[decision] };
}

// ---------------------------------------------------------------- C-PROG, C-VERDICT

/** C-PROG-1 : régression linéaire des e1RM (jours) → kg et % par semaine. */
export function penteE1rm(e: { points: readonly { jour: number; e1rm: number }[] }) {
  const n = e.points.length;
  if (n < 2) return { kgParSemaine: 0, pctParSemaine: 0, suffisant: false };
  const mx = moyenne(e.points.map((p) => p.jour));
  const my = moyenne(e.points.map((p) => p.e1rm));
  let num = 0;
  let den = 0;
  for (const p of e.points) {
    num += (p.jour - mx) * (p.e1rm - my);
    den += (p.jour - mx) ** 2;
  }
  const parJour = den > 0 ? num / den : 0;
  const kgParSemaine = parJour * 7;
  return { kgParSemaine, pctParSemaine: my > 0 ? (kgParSemaine / my) * 100 : 0, suffisant: n >= 4 };
}

/** C-PROG-2 [H] */
export const SEUILS_PROGRESSION: Record<Niveau, number> = { debutant: 1, intermediaire: 0.5, avance: 0.25 };

/** C-PROG-3 [H] */
export function contexteDefavorable(e: { sommeilMoyenMin: number; bilanPct: number; joursJeune: number; maladie: boolean }) {
  const causes: string[] = [];
  if (e.sommeilMoyenMin < 390) causes.push('sommeil');
  if (e.bilanPct < -0.15) causes.push('deficit');
  if (e.joursJeune >= 2) causes.push('jeune');
  if (e.maladie) causes.push('maladie');
  return { defavorable: causes.length > 0, causes };
}

/** C-VERDICT */
export function verdictProgression(e: {
  pctParSemaine: number;
  niveau: Niveau;
  contexteDefavorable: boolean;
  semainesSousSeuil: number;
}) {
  const seuil = SEUILS_PROGRESSION[e.niveau];
  const verdict =
    e.pctParSemaine >= seuil
      ? 'progression'
      : e.contexteDefavorable
        ? 'maintien_reussite'
        : e.semainesSousSeuil >= 3
          ? 'stagnation'
          : 'patience';
  return { verdict, seuil } as const;
}

// ---------------------------------------------------------------- Jeûne (JEUNE.md)

export type Phase = 'post_repas' | 'glycogene' | 'bascule' | 'cetose' | 'prolonge';
/** J-PHASE */
export function phaseJeune(e: { heures: number }) {
  const h = e.heures;
  const phase: Phase = h < 12 ? 'post_repas' : h < 16 ? 'glycogene' : h < 24 ? 'bascule' : h < 72 ? 'cetose' : 'prolonge';
  return { phase };
}

const plusPrudente = (a: Decision, b: Decision) => (PRUDENCE.indexOf(a) >= PRUDENCE.indexOf(b) ? a : b);

/** J-DECISION [H] — ordre : symptôme > repos verrouillé > limites > phase > priorité spirituelle. */
export function decisionJeune(e: {
  type: TypeJeune;
  heures: number;
  symptomes: readonly string[];
  reposVerrouille: boolean;
  prioriteSpirituelle: boolean;
}): { decision: Decision; volume: number; alerte: string | null } {
  if (e.symptomes.length > 0) return { decision: 'ARRET', volume: -1, alerte: 'symptome' };
  if (e.reposVerrouille) return { decision: 'REPOS', volume: -1, alerte: null };
  if (e.type === 'sec' && e.heures > 24) return { decision: 'ARRET', volume: -1, alerte: 'limite_jeune_sec' };
  let decision: Decision;
  let alerte: string | null = null;
  if (e.type === 'partiel') decision = 'NORMALE';
  else {
    // Jeûne sec : on recule d'une phase (16 h de plus de prudence sur les 24 premières heures).
    const h = e.type === 'sec' ? Math.max(e.heures, 16) : e.heures;
    if (h <= 16 && !(e.type === 'sec')) decision = 'NORMALE';
    else if (h < 24) decision = 'ADAPTEE';
    else if (h <= 72) decision = 'LEGERE';
    else {
      decision = 'REPOS_ACTIF';
      alerte = 'avis_medical';
    }
  }
  if (e.prioriteSpirituelle && decision !== 'REPOS_ACTIF') {
    decision = PRUDENCE[Math.min(PRUDENCE.indexOf(decision) + 1, PRUDENCE.indexOf('REPOS_ACTIF'))]!;
  }
  const volume = decision === 'ADAPTEE' ? -0.25 : VOLUME[decision];
  return { decision, volume, alerte };
}

/** J-DECISION (5) : la plus prudente des deux ; à décision égale, la plus forte réduction. */
export function combinerDecisions(e: { a: { decision: Decision; volume: number }; b: { decision: Decision; volume: number } }) {
  const decision = plusPrudente(e.a.decision, e.b.decision);
  const volumes = [e.a, e.b].filter((x) => x.decision === decision).map((x) => x.volume);
  return { decision, volume: Math.min(...volumes) };
}

/** J-REPRISE */
export function repriseJeune(e: { type: TypeJeune; heures: number; poids: number }) {
  const mode =
    e.type === 'sec' ? 'rehydratation' : e.type === 'partiel' || e.heures < 24 ? 'normale' : e.heures > 120 ? 'tres_progressive' : 'progressive';
  return { mode, proteinesRepas: proteinesParRepas(e.poids) } as const;
}

/** J-EFFET : différence des moyennes, intervalle à 80 % par approximation normale (déterministe). */
export function effetJeune(e: { pendant: readonly number[]; hors: readonly number[] }) {
  const effet = moyenne(e.pendant) - moyenne(e.hors);
  const variance = (xs: readonly number[]) => {
    if (xs.length < 2) return 0;
    const m = moyenne(xs);
    return xs.reduce((s, x) => s + (x - m) ** 2, 0) / (xs.length - 1);
  };
  const se = Math.sqrt(
    (e.pendant.length ? variance(e.pendant) / e.pendant.length : 0) + (e.hors.length ? variance(e.hors) / e.hors.length : 0),
  );
  return { effet, ic80: [effet - 1.2816 * se, effet + 1.2816 * se] as [number, number], suffisant: e.pendant.length >= 6 };
}

// ---------------------------------------------------------------- Catalogue des règles

export const REGLES = [
  { id: 'C-PERF-2', version: 1, nom: '1RM estimé', preuve: 'bonne', sources: ['S-01', 'S-02'] },
  { id: 'C-PERF-3', version: 1, nom: 'Charge cible', preuve: 'bonne', sources: ['S-02'] },
  { id: 'C-PERF-4', version: 1, nom: 'Ajustement en séance', preuve: 'H', sources: ['S-04'] },
  { id: 'C-PERF-5', version: 1, nom: 'Volume efficace', preuve: 'solide', sources: ['S-05'] },
  { id: 'C-CHARGE-1', version: 1, nom: 'Charge de séance (sRPE)', preuve: 'solide', sources: ['S-06'] },
  { id: 'C-CHARGE-2', version: 1, nom: 'TRIMP', preuve: 'modérée', sources: ['S-08'] },
  { id: 'C-CHARGE-3', version: 1, nom: 'FC max et zones', preuve: 'bonne', sources: ['S-09', 'S-10'] },
  { id: 'C-CHARGE-4', version: 1, nom: 'Ratio aigu/chronique (indicatif)', preuve: 'faible', sources: ['S-11', 'S-12'] },
  { id: 'C-RECUP-1', version: 1, nom: 'Score sommeil', preuve: 'H', sources: ['S-21', 'S-22', 'S-24'] },
  { id: 'C-ENERGIE-1', version: 1, nom: 'Métabolisme de base', preuve: 'solide', sources: ['S-17', 'S-18', 'S-19'] },
  { id: 'C-ENERGIE-4', version: 1, nom: 'TDEE adaptatif', preuve: 'H', sources: ['S-20'] },
  { id: 'C-ENERGIE-5', version: 1, nom: 'Verdict énergie', preuve: 'H', sources: [] },
  { id: 'C-ENERGIE-7', version: 1, nom: 'Cibles de macros', preuve: 'bonne', sources: ['S-26', 'S-27', 'S-28', 'S-29', 'S-30', 'S-31'] },
  { id: 'C-FORME', version: 1, nom: 'Score de forme', preuve: 'H', sources: ['S-15', 'S-16', 'S-21'] },
  { id: 'C-AJUST', version: 1, nom: 'Séance ajustée', preuve: 'H', sources: ['S-21', 'S-22'] },
  { id: 'C-PROG-1', version: 1, nom: 'Tendance e1RM', preuve: 'bonne', sources: [] },
  { id: 'C-VERDICT', version: 1, nom: 'Verdict hebdomadaire', preuve: 'H', sources: ['S-21', 'S-22', 'S-23'] },
  { id: 'J-DECISION', version: 1, nom: 'Décision séance pendant un jeûne', preuve: 'H', sources: ['S-46', 'S-47', 'S-49', 'S-50'] },
  { id: 'J-REPRISE', version: 1, nom: 'Reprise alimentaire', preuve: 'modérée', sources: ['S-52'] },
  { id: 'J-EFFET', version: 1, nom: 'Effet personnel du jeûne', preuve: 'H', sources: [] },
] as const;

/** Fonctions exposées par nom (API `/v1/calculs/{fonction}`, outil MCP `calculer`, engine-spec). */
export const FONCTIONS = {
  e1rm,
  chargeCible,
  ajustementSerie,
  seriesEfficaces,
  srpe,
  trimp,
  fcMax,
  fcCible,
  ratioAiguChronique,
  kcalMet,
  scoreSommeil,
  zScore,
  bmr,
  tdeeInitial,
  poidsLisse,
  tdeeAdaptatif,
  verdictEnergie,
  kcalMacros,
  ciblesMacros,
  nutrimentsPlat,
  scoreForme,
  ajustementSeance,
  penteE1rm,
  verdictProgression,
  contexteDefavorable,
  phaseJeune,
  decisionJeune,
  combinerDecisions,
  repriseJeune,
  effetJeune,
} as const;
export type NomFonction = keyof typeof FONCTIONS;
