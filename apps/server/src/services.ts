// Services métier : lisent les données de l'utilisateur (RLS) et appellent le moteur.
// L'API REST et le serveur MCP passent tous les deux par ici : une seule logique.
import * as moteur from '@cresco/engine';
import { z } from 'zod';
import type { Tx } from './db.ts';

const JOUR = 86_400_000;
const moyenne = (xs: number[]) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0);
const ecartType = (xs: number[]) => {
  if (xs.length < 2) return 0;
  const m = moyenne(xs);
  return Math.sqrt(xs.reduce((s, x) => s + (x - m) ** 2, 0) / (xs.length - 1));
};
const age = (naissance: string | null) =>
  naissance ? Math.floor((Date.now() - new Date(naissance).getTime()) / (365.25 * JOUR)) : 30;

export class Refus extends Error {
  constructor(
    readonly status: 400 | 403 | 404 | 409 | 422,
    message: string,
  ) {
    super(message);
  }
}

// ---------------------------------------------------------------- Profil

export interface Profil {
  id: string;
  email: string;
  nom: string;
  sexe: moteur.Sexe | null;
  naissance: string | null;
  taille_cm: number | null;
  niveau: moteur.Niveau;
  objectif: moteur.Objectif;
  activite: keyof typeof moteur.NAP;
  preferences: {
    moduleFoi: boolean;
    prioriteSpirituelle: boolean;
    joursReposVerrouilles: number[];
    besoinSommeilMin: number;
  };
}

export async function profil(tx: Tx, userId: string): Promise<Profil> {
  const { rows } = await tx.query<Profil>(
    `select id, email, nom, sexe, naissance::text, taille_cm, niveau, objectif, activite, preferences
     from utilisateur where id = $1`,
    [userId],
  );
  if (!rows[0]) throw new Refus(404, 'Utilisateur introuvable');
  return rows[0];
}

export const ProfilPatch = z.object({
  nom: z.string().max(120).optional(),
  sexe: z.enum(['homme', 'femme']).optional(),
  naissance: z.string().regex(/^\d{4}-\d{2}-\d{2}$/u).optional(),
  taille_cm: z.number().min(100).max(250).optional(),
  niveau: z.enum(['debutant', 'intermediaire', 'avance']).optional(),
  objectif: z.enum(['perte', 'maintien', 'prise']).optional(),
  activite: z.enum(['sedentaire', 'peu_actif', 'actif', 'tres_actif']).optional(),
  preferences: z
    .object({
      moduleFoi: z.boolean().optional(),
      prioriteSpirituelle: z.boolean().optional(),
      joursReposVerrouilles: z.array(z.number().int().min(0).max(6)).optional(),
      besoinSommeilMin: z.number().min(360).max(600).optional(),
    })
    .optional(),
});

export async function modifierProfil(tx: Tx, userId: string, patch: z.infer<typeof ProfilPatch>) {
  const actuel = await profil(tx, userId);
  const preferences = { ...actuel.preferences, ...(patch.preferences ?? {}) };
  await tx.query(
    `update utilisateur set nom = coalesce($2, nom), sexe = coalesce($3, sexe), naissance = coalesce($4::date, naissance),
       taille_cm = coalesce($5, taille_cm), niveau = coalesce($6, niveau), objectif = coalesce($7, objectif),
       activite = coalesce($8, activite), preferences = $9 where id = $1`,
    [userId, patch.nom, patch.sexe, patch.naissance, patch.taille_cm, patch.niveau, patch.objectif, patch.activite, preferences],
  );
  return profil(tx, userId);
}

// ---------------------------------------------------------------- Mesures, sommeil, ressenti

export const MesureEntree = z.object({
  type: z.enum(['poids', 'tour_taille', 'masse_grasse', 'vfc', 'fc_repos']),
  valeur: z.number().positive(),
  le: z.string().datetime().optional(),
  source: z.string().max(40).optional(),
});
export async function ajouterMesure(tx: Tx, userId: string, m: z.infer<typeof MesureEntree>) {
  const { rows } = await tx.query(
    `insert into mesure (user_id, type, valeur, le, source) values ($1, $2, $3, coalesce($4::timestamptz, now()), coalesce($5, 'saisie')) returning *`,
    [userId, m.type, m.valeur, m.le, m.source],
  );
  return rows[0];
}
export async function mesures(tx: Tx, type: string, jours = 90) {
  const { rows } = await tx.query<{ le: Date; valeur: number }>(
    `select le, valeur from mesure where type = $1 and le > now() - make_interval(days => $2) order by le`,
    [type, jours],
  );
  return rows;
}

export const NuitEntree = z.object({
  coucher: z.string().datetime(),
  lever: z.string().datetime(),
  dormiMin: z.number().min(0).max(1440),
  auLitMin: z.number().min(0).max(1440).optional(),
  profondPct: z.number().min(0).max(100).optional(),
  source: z.string().max(40).optional(),
});
export async function ajouterNuit(tx: Tx, userId: string, n: z.infer<typeof NuitEntree>) {
  const auLit = n.auLitMin ?? (new Date(n.lever).getTime() - new Date(n.coucher).getTime()) / 60_000;
  const { rows } = await tx.query(
    `insert into nuit (user_id, coucher, lever, dormi_min, au_lit_min, profond_pct, source)
     values ($1, $2, $3, $4, $5, $6, coalesce($7, 'saisie')) returning *`,
    [userId, n.coucher, n.lever, n.dormiMin, auLit, n.profondPct ?? null, n.source],
  );
  return rows[0];
}
export async function nuits(tx: Tx, jours = 30) {
  const { rows } = await tx.query<{ coucher: Date; lever: Date; dormi_min: number; au_lit_min: number; profond_pct: number | null }>(
    `select coucher, lever, dormi_min, au_lit_min, profond_pct from nuit where lever > now() - make_interval(days => $1) order by lever`,
    [jours],
  );
  return rows;
}

export const RessentiEntree = z.object({
  energie: z.number().int().min(1).max(5).optional(),
  courbatures: z.number().int().min(0).max(3).optional(),
  clarte: z.number().int().min(1).max(5).optional(),
  spirituel: z.number().int().min(1).max(5).optional(),
  maladie: z.boolean().optional(),
  notes: z.string().max(2000).optional(),
});
export async function ajouterRessenti(tx: Tx, userId: string, r: z.infer<typeof RessentiEntree>) {
  const { rows } = await tx.query(
    `insert into ressenti (user_id, energie, courbatures, clarte, spirituel, maladie, notes)
     values ($1, $2, $3, $4, $5, coalesce($6, false), coalesce($7, '')) returning *`,
    [userId, r.energie, r.courbatures, r.clarte, r.spirituel, r.maladie, r.notes],
  );
  return rows[0];
}

// ---------------------------------------------------------------- Entraînement

const Etape = z.object({
  exercice_id: z.string().optional(),
  libelle: z.string().max(80).optional(),
  duree: z.object({ temps_s: z.number().positive().optional(), reps: z.number().int().positive().optional(), distance_m: z.number().positive().optional() }),
  cible: z
    .object({
      vitesse_ms: z.number().positive().max(12).optional(),
      rir: z.number().min(0).max(6).optional(),
      rpe: z.number().min(1).max(10).optional(),
      charge_kg: z.union([z.number().min(0), z.literal('auto')]).optional(),
      zone_fc: z.number().int().min(1).max(5).optional(),
    })
    .default({}),
  repos_s: z.number().min(0).max(900).optional(),
});
export const ModeleEntree = z.object({
  nom: z.string().min(1).max(120),
  type: z.enum(['muscu', 'course_tapis', 'velo', 'rameur', 'hiit', 'autre']),
  blocs: z.array(z.object({ repeter: z.number().int().min(1).max(30), etapes: z.array(Etape).min(1).max(20) })).min(1).max(20),
  annonces: z.object({ preavis_s: z.number().min(0).max(60).default(15), voix: z.boolean().default(true), vibration: z.boolean().default(true) }).optional(),
});
export type Modele = z.infer<typeof ModeleEntree>;

/** Garde-fous (CONFORMITE.md) : aucune séance hors bornes n'est enregistrée, même proposée par une IA. */
export function validerModele(m: Modele) {
  const problemes: string[] = [];
  let series = 0;
  let secondes = 0;
  for (const b of m.blocs) {
    for (const e of b.etapes) {
      if (e.duree.reps) series += b.repeter;
      secondes += b.repeter * ((e.duree.temps_s ?? 0) + (e.repos_s ?? 0));
      if (e.cible.rir != null && e.cible.rir < 0) problemes.push('RIR négatif');
    }
  }
  if (series > 40) problemes.push(`Trop de séries (${series} > 40)`);
  if (secondes > 3 * 3600) problemes.push('Séance de plus de 3 heures');
  return { valide: problemes.length === 0, problemes, series, dureeMin: Math.round(secondes / 60) };
}

export async function creerModele(tx: Tx, userId: string, m: Modele, creePar = 'utilisateur') {
  const v = validerModele(m);
  if (!v.valide) throw new Refus(422, `Séance refusée : ${v.problemes.join(', ')}`);
  const { rows } = await tx.query(
    `insert into modele_seance (user_id, nom, type, contenu, cree_par) values ($1, $2, $3, $4, $5) returning *`,
    [userId, m.nom, m.type, { blocs: m.blocs, annonces: m.annonces }, creePar],
  );
  return rows[0];
}

export const SeanceEntree = z.object({
  type: z.string().max(40),
  modeleId: z.string().uuid().optional(),
  le: z.string().datetime().optional(),
  rpe: z.number().min(1).max(10).optional(),
  dureeMin: z.number().min(0).max(600).optional(),
  notes: z.string().max(2000).optional(),
  decision: z.record(z.unknown()).optional(),
  series: z
    .array(
      z.object({
        exerciceId: z.string().optional(),
        reps: z.number().int().min(0).max(100).optional(),
        chargeKg: z.number().min(0).max(1000).optional(),
        rir: z.number().min(0).max(10).optional(),
        vitesseMs: z.number().min(0).max(12).optional(),
        fc: z.number().min(30).max(240).optional(),
        dureeS: z.number().min(0).max(36000).optional(),
      }),
    )
    .max(200)
    .default([]),
});
export async function enregistrerSeance(tx: Tx, userId: string, s: z.infer<typeof SeanceEntree>) {
  const srpe = s.rpe && s.dureeMin ? moteur.srpe({ rpe: s.rpe, minutes: s.dureeMin }).valeur : null;
  const { rows } = await tx.query<{ id: string }>(
    `insert into seance (user_id, type, modele_id, le, rpe, duree_min, srpe, notes, decision)
     values ($1, $2, $3, coalesce($4::timestamptz, now()), $5, $6, $7, coalesce($8, ''), $9) returning id`,
    [userId, s.type, s.modeleId ?? null, s.le, s.rpe ?? null, s.dureeMin ?? null, srpe, s.notes, s.decision ?? null],
  );
  const seanceId = rows[0]!.id;
  for (const [ordre, x] of s.series.entries()) {
    const e1rm = x.chargeKg && x.reps ? moteur.e1rm({ charge: x.chargeKg, reps: x.reps, rir: x.rir ?? 0 }).valeur : null;
    await tx.query(
      `insert into serie (user_id, seance_id, exercice_id, ordre, reps, charge_kg, rir, vitesse_ms, fc, duree_s, e1rm)
       values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
      [userId, seanceId, x.exerciceId ?? null, ordre, x.reps ?? null, x.chargeKg ?? null, x.rir ?? null, x.vitesseMs ?? null, x.fc ?? null, x.dureeS ?? null, e1rm],
    );
  }
  return { id: seanceId, srpe };
}

export async function seances(tx: Tx, jours = 30) {
  const { rows } = await tx.query(
    `select s.*, coalesce(json_agg(x order by x.ordre) filter (where x.id is not null), '[]') as series
     from seance s left join serie x on x.seance_id = s.id
     where s.le > now() - make_interval(days => $1) group by s.id order by s.le desc`,
    [jours],
  );
  return rows;
}

/** Meilleur e1RM par séance et par exercice (point de la tendance). */
async function pointsE1rm(tx: Tx, jours: number) {
  const { rows } = await tx.query<{ exercice_id: string; le: Date; e1rm: number; reps: number; rir: number | null }>(
    `select distinct on (x.seance_id, x.exercice_id) x.exercice_id, s.le, x.e1rm, x.reps, x.rir
     from serie x join seance s on s.id = x.seance_id
     where x.e1rm is not null and s.le > now() - make_interval(days => $1)
     order by x.seance_id, x.exercice_id, x.e1rm desc`,
    [jours],
  );
  // Les séries de plus de 12 reps effectives (confiance basse) sont exclues de la tendance.
  return rows.filter((r) => r.reps + (r.rir ?? 0) <= 12);
}

const SEANCE_PAR_DEFAUT: Modele = {
  nom: 'Haut du corps',
  type: 'muscu',
  blocs: [
    { repeter: 3, etapes: [{ exercice_id: 'developpe-couche-barre', duree: { reps: 8 }, cible: { rir: 2, charge_kg: 'auto' }, repos_s: 150 }] },
    { repeter: 3, etapes: [{ exercice_id: 'rowing-barre', duree: { reps: 10 }, cible: { rir: 2, charge_kg: 'auto' }, repos_s: 120 }] },
    { repeter: 3, etapes: [{ exercice_id: 'developpe-militaire', duree: { reps: 8 }, cible: { rir: 2, charge_kg: 'auto' }, repos_s: 120 }] },
    { repeter: 3, etapes: [{ exercice_id: 'tirage-vertical', duree: { reps: 10 }, cible: { rir: 2, charge_kg: 'auto' }, repos_s: 90 }] },
  ],
  annonces: { preavis_s: 15, voix: true, vibration: true },
};

// ---------------------------------------------------------------- Jeûne

export const JeuneEntree = z.object({
  type: z.enum(['intermittent', 'eau', 'sec', 'partiel']),
  motif: z.enum(['spirituel', 'sante', 'autre']).default('spirituel'),
  intention: z.string().max(500).default(''),
  debut: z.string().datetime().optional(),
  finPrevue: z.string().datetime().optional(),
});
export async function demarrerJeune(tx: Tx, userId: string, j: z.infer<typeof JeuneEntree>) {
  const enCours = await jeuneEnCours(tx);
  if (enCours) throw new Refus(409, 'Un jeûne est déjà en cours');
  if (j.type === 'sec' && j.finPrevue && j.debut) {
    const h = (new Date(j.finPrevue).getTime() - new Date(j.debut).getTime()) / 3_600_000;
    if (h > 24) throw new Refus(422, 'Le jeûne sec est limité à 24 h dans Cresco (CONFORMITE.md)');
  }
  const { rows } = await tx.query(
    `insert into jeune (user_id, type, motif, intention, debut, fin_prevue) values ($1, $2, $3, $4, coalesce($5::timestamptz, now()), $6) returning *`,
    [userId, j.type, j.motif, j.intention, j.debut, j.finPrevue ?? null],
  );
  return rows[0];
}
export async function jeuneEnCours(tx: Tx) {
  const { rows } = await tx.query<{ id: string; type: moteur.TypeJeune; motif: string; intention: string; debut: Date; fin_prevue: Date | null }>(
    `select id, type, motif, intention, debut, fin_prevue from jeune where fin_reelle is null order by debut desc limit 1`,
  );
  return rows[0] ?? null;
}
export async function terminerJeune(tx: Tx, jeuneId: string) {
  const { rows } = await tx.query(`update jeune set fin_reelle = now() where id = $1 and fin_reelle is null returning *`, [jeuneId]);
  if (!rows[0]) throw new Refus(404, 'Jeûne introuvable ou déjà terminé');
  return rows[0];
}
export const EvenementJeuneEntree = z.object({
  type: z.enum(['eau', 'electrolytes', 'symptome', 'clarte', 'energie', 'spirituel', 'poids']),
  valeur: z.string().max(200),
});
export async function noterJeune(tx: Tx, userId: string, jeuneId: string, e: z.infer<typeof EvenementJeuneEntree>) {
  const { rows } = await tx.query(
    `insert into evenement_jeune (user_id, jeune_id, type, valeur) values ($1, $2, $3, $4) returning *`,
    [userId, jeuneId, e.type, e.valeur],
  );
  return rows[0];
}

export async function decisionJeuneEnCours(tx: Tx, userId: string) {
  const p = await profil(tx, userId);
  const j = await jeuneEnCours(tx);
  if (!j) return null;
  const heures = (Date.now() - new Date(j.debut).getTime()) / 3_600_000;
  const { rows } = await tx.query<{ valeur: string }>(
    `select valeur from evenement_jeune where jeune_id = $1 and type = 'symptome' and le > now() - interval '6 hours'`,
    [j.id],
  );
  const decision = moteur.decisionJeune({
    type: j.type,
    heures,
    symptomes: rows.map((r) => r.valeur),
    reposVerrouille: p.preferences.joursReposVerrouilles.includes(new Date().getDay()),
    prioriteSpirituelle: j.motif === 'spirituel' && p.preferences.prioriteSpirituelle,
  });
  const poids = (await mesures(tx, 'poids', 60)).at(-1)?.valeur ?? 75;
  return {
    jeune: { ...j, heures, phase: moteur.phaseJeune({ heures }).phase },
    decision,
    reprise: moteur.repriseJeune({ type: j.type, heures, poids }),
    regle: 'J-DECISION',
    sources: ['S-46', 'S-47', 'S-49', 'S-50'],
  };
}

// ---------------------------------------------------------------- Forme et séance du jour

export async function forme(tx: Tx, userId: string) {
  const p = await profil(tx, userId);
  const n = await nuits(tx, 30);
  const derniere = n.at(-1);
  let sommeil: number | undefined;
  if (derniere && Date.now() - new Date(derniere.lever).getTime() < 20 * 3_600_000) {
    const profonds = n.slice(-14).map((x) => x.profond_pct).filter((x): x is number => x != null);
    const milieux = n.slice(-7).map((x) => {
      const m = (new Date(x.coucher).getTime() + new Date(x.lever).getTime()) / 2;
      return ((new Date(m).getUTCHours() * 60 + new Date(m).getUTCMinutes() + 720) % 1440);
    });
    sommeil = moteur.scoreSommeil({
      dormiMin: derniere.dormi_min,
      auLitMin: derniere.au_lit_min,
      besoinMin: p.preferences.besoinSommeilMin,
      ...(derniere.profond_pct != null && profonds.length ? { profondPct: derniere.profond_pct, profondMoyenPct: moyenne(profonds) } : {}),
      ...(milieux.length >= 3 ? { ecartTypeMilieuMin: ecartType(milieux) } : {}),
    }).valeur;
  }
  const z = async (type: 'vfc' | 'fc_repos', inverse: boolean) => {
    const m = await mesures(tx, type, 30);
    const jour = m.at(-1);
    if (!jour || Date.now() - new Date(jour.le).getTime() > 20 * 3_600_000 || m.length < 5) return undefined;
    const vals = m.map((x) => (type === 'vfc' ? Math.log(x.valeur) : x.valeur));
    const zz = moteur.zScore({ valeur: vals.at(-1)!, moyenne: moyenne(vals.slice(-8, -1)), ecartType: ecartType(vals) }).valeur;
    return inverse ? -zz : zz;
  };
  const { rows: ress } = await tx.query<{ energie: number | null; courbatures: number | null }>(
    `select energie, courbatures from ressenti where le > now() - interval '20 hours' order by le desc limit 1`,
  );
  const { rows: charges } = await tx.query<{ jour: string; charge: number }>(
    `select d::date::text as jour, coalesce(sum(s.srpe), 0) as charge
     from generate_series(now() - interval '27 days', now(), interval '1 day') d
     left join seance s on s.le::date = d::date group by d order by d`,
  );
  const j = await jeuneEnCours(tx);
  const entree = {
    sommeil,
    zVfc: await z('vfc', false),
    zFcRepos: await z('fc_repos', true),
    energie: ress[0]?.energie ?? undefined,
    courbatures: ress[0]?.courbatures ?? undefined,
    ratioAiguChronique: charges.some((c) => c.charge > 0) ? moteur.ratioAiguChronique({ charges: charges.map((c) => c.charge) }).ratio : undefined,
    heuresJeune: j ? (Date.now() - new Date(j.debut).getTime()) / 3_600_000 : 0,
  };
  const score = moteur.scoreForme(entree);
  return {
    valeur: Math.round(score.valeur),
    confiance: score.confiance,
    composantes: {
      sommeil: sommeil == null ? null : Math.round(sommeil),
      dormiMin: derniere?.dormi_min ?? null,
      vfc: (await mesures(tx, 'vfc', 2)).at(-1)?.valeur ?? null,
      fcRepos: (await mesures(tx, 'fc_repos', 2)).at(-1)?.valeur ?? null,
      energie: entree.energie ?? null,
      ratioAiguChronique: entree.ratioAiguChronique ?? null,
    },
    regle: 'C-FORME',
  };
}

export async function seanceDuJour(tx: Tx, userId: string) {
  const p = await profil(tx, userId);
  const f = await forme(tx, userId);
  const reposVerrouille = p.preferences.joursReposVerrouilles.includes(new Date().getDay());
  let decision = moteur.ajustementSeance({ forme: f.valeur, reposVerrouille });
  let raison = reposVerrouille
    ? 'Jour de repos verrouillé'
    : f.valeur >= 75
      ? 'Bonne forme : plan normal'
      : f.composantes.sommeil != null && f.composantes.sommeil < 70
        ? 'Volume réduit après une nuit courte'
        : 'Volume réduit : récupération incomplète';
  const dj = await decisionJeuneEnCours(tx, userId);
  if (dj) {
    const combinee = moteur.combinerDecisions({ a: decision, b: dj.decision });
    if (combinee.decision !== decision.decision || combinee.volume !== decision.volume) {
      raison = `Jeûne en cours (${Math.round(dj.jeune.heures)} h) : séance ${combinee.decision === 'ARRET' ? 'arrêtée' : 'adaptée'}`;
    }
    decision = combinee;
  }
  const { rows: modeles } = await tx.query<{ id: string; nom: string; type: string; contenu: { blocs: Modele['blocs']; annonces?: Modele['annonces'] } }>(
    `select id, nom, type, contenu from modele_seance order by cree_le desc limit 1`,
  );
  const modele = modeles[0]
    ? { id: modeles[0].id, nom: modeles[0].nom, type: modeles[0].type, blocs: modeles[0].contenu.blocs, annonces: modeles[0].contenu.annonces }
    : { id: null, ...SEANCE_PAR_DEFAUT };
  const points = await pointsE1rm(tx, 60);
  const { rows: exos } = await tx.query<{ id: string; nom: string; pas_kg: number }>(`select id, nom, pas_kg from exercice`);
  const pas = new Map(exos.map((e) => [e.id, e]));
  const facteurVolume = 1 + decision.volume;
  const blocs = ['ARRET', 'REPOS', 'REPOS_ACTIF'].includes(decision.decision)
    ? []
    : modele.blocs.map((b) => ({
        repeter: b.etapes.some((e) => e.duree.reps) ? Math.max(1, Math.round(b.repeter * facteurVolume)) : b.repeter,
        etapes: b.etapes.map((e) => {
          const exo = e.exercice_id ? pas.get(e.exercice_id) : undefined;
          let charge = e.cible.charge_kg;
          if (charge === 'auto' && e.exercice_id && e.duree.reps) {
            const historique = points.filter((x) => x.exercice_id === e.exercice_id).slice(-3).map((x) => x.e1rm);
            charge = historique.length
              ? moteur.chargeCible({ e1rm: moteur.ewma(historique, 3), reps: e.duree.reps, rir: e.cible.rir ?? 2, pas: exo?.pas_kg ?? 2.5 }).valeur
              : undefined;
          }
          return { ...e, nom: exo?.nom, cible: { ...e.cible, charge_kg: charge } };
        }),
      }));
  return { decision, raison, forme: f, modele: { ...modele, blocs }, jeune: dj, regles: ['C-AJUST', 'C-PERF-3', ...(dj ? ['J-DECISION'] : [])] };
}

// ---------------------------------------------------------------- Nutrition

export const AlimentEntree = z.object({
  nom: z.string().min(1).max(160),
  kcal100: z.number().min(0).max(900),
  proteines100: z.number().min(0).max(100).default(0),
  glucides100: z.number().min(0).max(100).default(0),
  lipides100: z.number().min(0).max(100).default(0),
  fibres100: z.number().min(0).max(100).default(0),
  codeBarres: z.string().max(32).optional(),
});
export async function creerAliment(tx: Tx, userId: string, a: z.infer<typeof AlimentEntree>) {
  const { rows } = await tx.query(
    `insert into aliment (user_id, source, code_barres, nom, kcal100, proteines100, glucides100, lipides100, fibres100)
     values ($1, 'perso', $2, $3, $4, $5, $6, $7, $8) returning *`,
    [userId, a.codeBarres ?? null, a.nom, a.kcal100, a.proteines100, a.glucides100, a.lipides100, a.fibres100],
  );
  return rows[0];
}
export async function chercherAliments(tx: Tx, q: string) {
  const { rows } = await tx.query(`select * from aliment where nom ilike $1 order by user_id nulls last, nom limit 30`, [`%${q}%`]);
  return rows;
}

/** Code-barres : base locale, sinon Open Food Facts (ODbL, source citée), mis en cache. */
export async function alimentParCode(tx: Tx, code: string) {
  if (!/^\d{6,14}$/u.test(code)) throw new Refus(400, 'Code-barres invalide');
  const { rows } = await tx.query(`select * from aliment where code_barres = $1 limit 1`, [code]);
  if (rows[0]) return rows[0];
  const res = await fetch(`https://world.openfoodfacts.org/api/v2/product/${code}.json?fields=product_name,product_name_fr,nutriments`, {
    headers: { 'User-Agent': 'Cresco/0.1 (app de sport ; contact via GitHub)' },
    signal: AbortSignal.timeout(8000),
  }).catch(() => null);
  if (!res?.ok) throw new Refus(404, 'Produit introuvable');
  const data = (await res.json()) as { status?: number; product?: { product_name?: string; product_name_fr?: string; nutriments?: Record<string, number> } };
  const n = data.product?.nutriments;
  if (data.status !== 1 || !n || n['energy-kcal_100g'] == null) throw new Refus(404, 'Produit introuvable ou sans valeurs nutritionnelles');
  const { rows: inseres } = await tx.query(
    `insert into aliment (source, code_barres, nom, kcal100, proteines100, glucides100, lipides100, fibres100)
     values ('off', $1, $2, $3, $4, $5, $6, $7) on conflict do nothing returning *`,
    [code, data.product?.product_name_fr || data.product?.product_name || code, n['energy-kcal_100g'], n.proteins_100g ?? 0, n.carbohydrates_100g ?? 0, n.fat_100g ?? 0, n.fiber_100g ?? 0],
  );
  return { ...(inseres[0] ?? (await tx.query(`select * from aliment where code_barres = $1`, [code])).rows[0]), source_attribution: 'Open Food Facts (ODbL)' };
}

export const PlatEntree = z.object({
  nom: z.string().min(1).max(160),
  ingredients: z
    .array(z.object({ alimentId: z.string().uuid(), masse: z.number().positive().max(10_000) }))
    .min(1)
    .max(60),
  masseCuite: z.number().positive().max(20_000).optional(),
});
/** C-ENERGIE-9 : l'IA ou l'utilisateur donnent ingrédients et masses, le moteur calcule. */
export async function creerPlat(tx: Tx, userId: string, p: z.infer<typeof PlatEntree>, creePar = 'utilisateur') {
  const ids = p.ingredients.map((i) => i.alimentId);
  const { rows } = await tx.query<{ id: string; nom: string; kcal100: number; proteines100: number; glucides100: number; lipides100: number }>(
    `select id, nom, kcal100, proteines100, glucides100, lipides100 from aliment where id = any($1)`,
    [ids],
  );
  const parId = new Map(rows.map((r) => [r.id, r]));
  const manquants = ids.filter((id) => !parId.has(id));
  if (manquants.length) throw new Refus(422, `Aliments inconnus : ${manquants.join(', ')}`);
  const nutriments = moteur.nutrimentsPlat({
    ingredients: p.ingredients.map((i) => ({ masse: i.masse, ...parId.get(i.alimentId)! })),
    ...(p.masseCuite ? { masseCuite: p.masseCuite } : {}),
  });
  const { rows: plat } = await tx.query(
    `insert into plat (user_id, nom, ingredients, masse_cuite, nutriments, cree_par) values ($1, $2, $3, $4, $5, $6) returning *`,
    [userId, p.nom, JSON.stringify(p.ingredients.map((i) => ({ ...i, nom: parId.get(i.alimentId)!.nom }))), p.masseCuite ?? null, nutriments, creePar],
  );
  return plat[0];
}
export async function plats(tx: Tx) {
  return (await tx.query(`select * from plat order by cree_le desc`)).rows;
}

export const RepasEntree = z.object({
  type: z.enum(['petit_dejeuner', 'dejeuner', 'diner', 'collation', 'repas']).default('repas'),
  le: z.string().datetime().optional(),
  portions: z
    .array(z.object({ alimentId: z.string().uuid().optional(), platId: z.string().uuid().optional(), masse: z.number().positive().max(5000) }))
    .min(1)
    .max(40),
});
export async function ajouterRepas(tx: Tx, userId: string, r: z.infer<typeof RepasEntree>) {
  const total = { kcal: 0, proteines: 0, glucides: 0, lipides: 0 };
  const detail = [];
  for (const portion of r.portions) {
    let n: { nom: string; kcal100: number; proteines100: number; glucides100: number; lipides100: number } | undefined;
    if (portion.alimentId) n = (await tx.query(`select nom, kcal100, proteines100, glucides100, lipides100 from aliment where id = $1`, [portion.alimentId])).rows[0];
    else if (portion.platId) {
      const plat = (await tx.query<{ nom: string; nutriments: { kcal100: number; proteines100: number; glucides100: number; lipides100: number } }>(`select nom, nutriments from plat where id = $1`, [portion.platId])).rows[0];
      if (plat) n = { nom: plat.nom, ...plat.nutriments };
    }
    if (!n) throw new Refus(422, 'Portion sans aliment ni plat connu');
    const f = portion.masse / 100;
    total.kcal += n.kcal100 * f;
    total.proteines += n.proteines100 * f;
    total.glucides += n.glucides100 * f;
    total.lipides += n.lipides100 * f;
    detail.push({ ...portion, nom: n.nom });
  }
  const { rows } = await tx.query(
    `insert into repas (user_id, type, le, portions, kcal, proteines, glucides, lipides)
     values ($1, $2, coalesce($3::timestamptz, now()), $4, $5, $6, $7, $8) returning *`,
    [userId, r.type, r.le, JSON.stringify(detail), total.kcal, total.proteines, total.glucides, total.lipides],
  );
  return rows[0];
}

async function apportsParJour(tx: Tx, jours: number) {
  const { rows } = await tx.query<{ jour: string; kcal: number; proteines: number }>(
    `select le::date::text as jour, sum(kcal) as kcal, sum(proteines) as proteines from repas
     where le > now() - make_interval(days => $1) group by 1 order by 1`,
    [jours],
  );
  return rows;
}

/** C-ENERGIE : BMR, TDEE (adaptatif si assez de données), cibles et bilan du jour. */
export async function energie(tx: Tx, userId: string) {
  const p = await profil(tx, userId);
  const pesees = await mesures(tx, 'poids', 60);
  const poids = pesees.at(-1)?.valeur ?? 75;
  const masseGrasse = (await mesures(tx, 'masse_grasse', 60)).at(-1)?.valeur;
  const b = moteur.bmr({
    sexe: p.sexe ?? 'homme',
    poids,
    taille: p.taille_cm ?? 175,
    age: age(p.naissance),
    ...(masseGrasse ? { masseMaigre: poids * (1 - masseGrasse / 100) } : {}),
  }).valeur;
  let tdee = moteur.tdeeInitial({ bmr: b, activite: p.activite }).valeur;
  let source: 'initial' | 'adaptatif' = 'initial';
  let sousSaisie = false;
  const apports = await apportsParJour(tx, 21);
  // Les jours de jeûne sont exclus (eau et glycogène faussent le poids) : JEUNE.md §7.
  const { rows: joursJeune } = await tx.query<{ jour: string }>(
    `select distinct d::date::text as jour from jeune j, generate_series(j.debut, coalesce(j.fin_reelle, now()), interval '1 day') d
     where j.debut > now() - interval '21 days' and j.type <> 'partiel'`,
  );
  const exclus = new Set(joursJeune.map((r) => r.jour));
  const apportsValides = apports.filter((a) => !exclus.has(a.jour));
  const fenetre = pesees.filter((x) => Date.now() - new Date(x.le).getTime() < 21 * JOUR);
  if (apportsValides.length >= 14 && fenetre.length >= 2) {
    const lisse = moteur.poidsLisse({ pesees: fenetre.map((x) => x.valeur) }).serie;
    const jours = Math.max(1, (new Date(fenetre.at(-1)!.le).getTime() - new Date(fenetre[0]!.le).getTime()) / JOUR);
    const t = moteur.tdeeAdaptatif({
      apportMoyen: moyenne(apportsValides.map((a) => a.kcal)),
      tendanceDebut: lisse[0]!,
      tendanceFin: lisse.at(-1)!,
      jours,
      tdeePrecedent: tdee,
      bmr: b,
    });
    tdee = t.valeur;
    sousSaisie = t.sousSaisie;
    source = 'adaptatif';
  }
  const cibles = moteur.ciblesMacros({ tdee, bmr: b, poids, objectif: p.objectif });
  const aujourdhui = new Date().toISOString().slice(0, 10);
  const jour = apports.find((a) => a.jour === aujourdhui);
  const sept = apportsValides.filter((a) => Date.now() - new Date(a.jour).getTime() < 7 * JOUR);
  const bilanMoyen = sept.length ? moyenne(sept.map((a) => a.kcal)) - tdee : 0;
  const verdict = moteur.verdictEnergie({ bilanMoyen, tdee, joursSaisis: apportsValides.length, joursFenetre: 21 });
  const j = await jeuneEnCours(tx);
  return {
    bmr: Math.round(b),
    tdee: Math.round(tdee),
    source,
    sousSaisie,
    cibles: j && j.type !== 'partiel' ? null : cibles,
    ciblesSuspendues: Boolean(j && j.type !== 'partiel'),
    jour: { kcal: Math.round(jour?.kcal ?? 0), proteines: Math.round(jour?.proteines ?? 0) },
    bilan: { moyen7j: Math.round(bilanMoyen), ...verdict },
    poidsLisse: pesees.length ? moteur.poidsLisse({ pesees: pesees.map((x) => x.valeur) }).serie.at(-1) : null,
    regles: ['C-ENERGIE-1', 'C-ENERGIE-4', 'C-ENERGIE-5', 'C-ENERGIE-7'],
  };
}

// ---------------------------------------------------------------- Progression et verdict

export async function progression(tx: Tx, userId: string) {
  const p = await profil(tx, userId);
  const points = await pointsE1rm(tx, 56);
  const parExo = new Map<string, { le: Date; e1rm: number }[]>();
  for (const x of points) parExo.set(x.exercice_id, [...(parExo.get(x.exercice_id) ?? []), x]);
  const { rows: noms } = await tx.query<{ id: string; nom: string }>(`select id, nom from exercice`);
  const nom = new Map(noms.map((n) => [n.id, n.nom]));
  const maintenant = Date.now();
  const pente = (serie: { le: Date; e1rm: number }[], fin: number) =>
    moteur.penteE1rm({
      points: serie
        .filter((x) => new Date(x.le).getTime() <= fin && new Date(x.le).getTime() > fin - 28 * JOUR)
        .map((x) => ({ jour: (new Date(x.le).getTime() - (fin - 28 * JOUR)) / JOUR, e1rm: x.e1rm })),
    });
  const seuil = moteur.SEUILS_PROGRESSION[p.niveau];
  const exercices = [...parExo.entries()].map(([id, serie]) => {
    const actuelle = pente(serie, maintenant);
    let semainesSousSeuil = 0;
    for (let k = 0; k < 4; k += 1) {
      const pk = pente(serie, maintenant - k * 7 * JOUR);
      if (pk.suffisant && pk.pctParSemaine < seuil) semainesSousSeuil += 1;
      else break;
    }
    return {
      exerciceId: id,
      nom: nom.get(id) ?? id,
      dernier: serie.at(-1)!.e1rm,
      points: serie.map((x) => ({ le: x.le, e1rm: Math.round(x.e1rm * 10) / 10 })),
      ...actuelle,
      semainesSousSeuil,
    };
  });
  const n = await nuits(tx, 7);
  const sommeilMoyenMin = n.length ? moyenne(n.map((x) => x.dormi_min)) : 480;
  const e = await energie(tx, userId);
  const { rows: jj } = await tx.query<{ n: number }>(
    `select count(*)::int as n from jeune where debut > now() - interval '7 days' and type <> 'partiel'
       and coalesce(fin_reelle, now()) - debut > interval '16 hours'`,
  );
  const { rows: malade } = await tx.query<{ m: boolean }>(`select bool_or(maladie) as m from ressenti where le > now() - interval '7 days'`);
  const contexte = moteur.contexteDefavorable({
    sommeilMoyenMin,
    bilanPct: e.bilan.pct,
    joursJeune: jj[0]?.n ?? 0,
    maladie: Boolean(malade[0]?.m),
  });
  const suffisants = exercices.filter((x) => x.suffisant);
  const pctGlobal = suffisants.length ? moyenne(suffisants.map((x) => x.pctParSemaine)) : 0;
  const verdict = suffisants.length
    ? moteur.verdictProgression({
        pctParSemaine: pctGlobal,
        niveau: p.niveau,
        contexteDefavorable: contexte.defavorable,
        semainesSousSeuil: Math.min(...suffisants.map((x) => x.semainesSousSeuil)),
      }).verdict
    : 'donnees_insuffisantes';
  const tour = await mesures(tx, 'tour_taille', 35);
  return {
    verdict,
    explication: explicationVerdict(verdict, contexte.causes, sommeilMoyenMin),
    pctParSemaine: pctGlobal,
    seuil,
    contexte,
    exercices,
    energie: e.bilan,
    poidsLisse: e.poidsLisse,
    tourTaille: tour.at(-1)?.valeur ?? null,
    sommeilMoyenMin: Math.round(sommeilMoyenMin),
    regles: ['C-PROG-1', 'C-PROG-3', 'C-VERDICT'],
  };
}

function explicationVerdict(verdict: string, causes: string[], sommeilMin: number) {
  const h = `${Math.floor(sommeilMin / 60)} h ${String(Math.round(sommeilMin % 60)).padStart(2, '0')}`;
  switch (verdict) {
    case 'progression':
      return 'Ta force estimée monte au rythme attendu pour ton niveau.';
    case 'maintien_reussite':
      return `Ta force reste stable malgré ${causes.includes('sommeil') ? `des nuits de ${h} en moyenne` : causes.includes('jeune') ? 'tes jours de jeûne' : causes.includes('deficit') ? 'un déficit marqué' : 'une période difficile'}.`;
    case 'stagnation':
      return 'Pas de progression depuis 3 semaines sans cause identifiée : un deload ou une variante est proposé.';
    case 'patience':
      return 'Progression sous le seuil cette semaine : on réévalue la semaine prochaine.';
    default:
      return 'Pas encore assez de séances (4 sur 4 semaines) pour conclure.';
  }
}

// ---------------------------------------------------------------- Effet du jeûne et accueil

export async function effetJeune(tx: Tx) {
  const { rows } = await tx.query<{ jour: string; clarte: number | null; energie: number | null; en_jeune: boolean }>(
    `select r.le::date::text as jour, avg(r.clarte) as clarte, avg(r.energie) as energie,
       bool_or(exists (select 1 from jeune j where j.type <> 'partiel' and r.le between j.debut and coalesce(j.fin_reelle, now())
                       and r.le - j.debut > interval '16 hours')) as en_jeune
     from ressenti r where r.le > now() - interval '180 days' group by 1`,
  );
  const indic = (k: 'clarte' | 'energie') => {
    const pendant = rows.filter((r) => r.en_jeune && r[k] != null).map((r) => Number(r[k]));
    const hors = rows.filter((r) => !r.en_jeune && r[k] != null).map((r) => Number(r[k]));
    return { ...moteur.effetJeune({ pendant, hors }), n: pendant.length };
  };
  return { clarte: indic('clarte'), energie: indic('energie'), regle: 'J-EFFET' };
}

export async function aujourdhui(tx: Tx, userId: string) {
  const s = await seanceDuJour(tx, userId);
  const e = await energie(tx, userId);
  return { forme: s.forme, seance: { decision: s.decision, raison: s.raison, nom: s.modele.nom, type: s.modele.type }, energie: e, jeune: s.jeune };
}

export async function exporter(tx: Tx, userId: string) {
  const tables = ['seance', 'serie', 'modele_seance', 'plat', 'repas', 'nuit', 'mesure', 'ressenti', 'jeune', 'evenement_jeune', 'exercice_lien'];
  const out: Record<string, unknown> = { profil: await profil(tx, userId), exporte_le: new Date().toISOString() };
  for (const t of tables) out[t] = (await tx.query(`select * from ${t}`)).rows;
  out.aliments_perso = (await tx.query(`select * from aliment where user_id is not null`)).rows;
  return out;
}
