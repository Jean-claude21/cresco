/**
 * Integrated AI (ADR-0002: the engine computes, the AI proposes).
 *
 * - Meal in words or plate photo: the model names the foods and estimates their grams; the server
 *   matches each one in the food base (Ciqual, Open Food Facts, own foods) and the user confirms
 *   before anything is saved. Nutrients always come from the base and the engine, never from the AI.
 * - Weekly review: the model writes a short text from the figures the engine already computed
 *   (progression, energy, sleep), and is told not to produce any other number.
 *
 * Provider: OpenAI (Responses API, structured outputs), model OPENAI_MODEL (gpt-5.5 by default).
 * Off when OPENAI_API_KEY is not set: the endpoints answer 503 and the app hides the entries.
 */
import OpenAI from 'openai';
import { zodTextFormat } from 'openai/helpers/zod';
import { z } from 'zod';
import type { Tx } from './db.ts';
import * as svc from './services.ts';
import { Refus } from './services.ts';

const model = () => process.env['OPENAI_MODEL'] || 'gpt-5.5';

let client: OpenAI | null | undefined;
function openai(): OpenAI {
  if (client === undefined) client = process.env['OPENAI_API_KEY'] ? new OpenAI({ timeout: 80_000, maxRetries: 1 }) : null;
  if (!client) throw new Refus(503, 'L’assistant IA n’est pas configuré sur ce serveur.');
  return client;
}

export const iaDisponible = () => Boolean(process.env['OPENAI_API_KEY']);

/** Provider failures (no credit, rate limit, outage) become a clear 503 for the app. */
async function appel<T>(work: (c: OpenAI) => Promise<T>): Promise<T> {
  const c = openai();
  try {
    return await work(c);
  } catch (e) {
    if (e instanceof OpenAI.RateLimitError) {
      console.error('OpenAI', e.status, e.code);
      throw new Refus(503, 'L’assistant IA est indisponible pour le moment (quota du fournisseur). Réessaie plus tard.');
    }
    if (e instanceof OpenAI.APIError) {
      console.error('OpenAI', e.status, e.code);
      throw new Refus(503, 'L’assistant IA ne répond pas pour le moment. Réessaie plus tard.');
    }
    throw e;
  }
}

const Estimation = z.object({
  aliments: z
    .array(
      z.object({
        recherche: z
          .string()
          .describe('Nom court et générique pour chercher l’aliment dans la table Ciqual, en français (ex. « riz blanc cuit », « poulet, filet, rôti »).'),
        libelle: z.string().describe('Ce que la personne a décrit ou ce qui est visible, en français.'),
        grammes: z.number().describe('Masse estimée de la portion, en grammes.'),
      }),
    )
    .describe('Un élément par aliment ; vide si rien de mangeable n’est décrit.'),
  remarque: z.string().describe('Une phrase courte si une estimation est incertaine, sinon une chaîne vide.'),
});

const SYSTEME_REPAS = `Tu aides à noter un repas dans Cresco, une app de nutrition et de sport.
Décompose ce qui a été mangé en aliments simples, chacun avec une masse estimée en grammes (portions françaises courantes si rien n’est précisé).
Ne donne jamais de calories ni de nutriments : l’app les calcule à partir de la table Ciqual.
Pour « recherche », utilise le nom générique d’un aliment tel qu’il figure dans une table de composition (cru ou cuit selon le cas).`;

export const RepasTexte = z.object({ texte: z.string().trim().min(2).max(1000) });
export const RepasPhoto = z.object({
  image: z.string().min(100).max(7_000_000),
  mediaType: z.enum(['image/jpeg', 'image/png', 'image/webp']),
  precision: z.string().max(300).optional(),
});

type Proposition = { libelle: string; grammes: number; aliment: Record<string, unknown> | null };

/** Matches each estimated food in the base; the user confirms the list in the app. */
async function rapprocher(tx: Tx, estimation: z.infer<typeof Estimation>) {
  const propositions: Proposition[] = [];
  for (const a of estimation.aliments.slice(0, 15)) {
    const grammes = Math.min(Math.max(Math.round(a.grammes), 1), 2000);
    propositions.push({ libelle: a.libelle, grammes, aliment: await svc.meilleurAliment(tx, a.recherche) });
  }
  return { propositions, remarque: estimation.remarque || null };
}

async function estimer(content: OpenAI.Responses.ResponseInputMessageContentList) {
  const r = await appel((c) =>
    c.responses.parse({
      model: model(),
      instructions: SYSTEME_REPAS,
      input: [{ role: 'user', content }],
      reasoning: { effort: 'low' },
      text: { format: zodTextFormat(Estimation, 'estimation_repas') },
    }),
  );
  if (!r.output_parsed) throw new Refus(422, 'L’assistant n’a pas pu analyser ce repas.');
  return r.output_parsed;
}

export async function repasDepuisTexte(tx: Tx, { texte }: z.infer<typeof RepasTexte>) {
  return rapprocher(tx, await estimer([{ type: 'input_text', text: `Repas décrit : ${texte}` }]));
}

export async function repasDepuisPhoto(tx: Tx, p: z.infer<typeof RepasPhoto>) {
  return rapprocher(
    tx,
    await estimer([
      { type: 'input_image', image_url: `data:${p.mediaType};base64,${p.image}`, detail: 'auto' },
      { type: 'input_text', text: `Photo de l’assiette.${p.precision ? ` Précision : ${p.precision}` : ''}` },
    ]),
  );
}

const SYSTEME_BILAN = `Tu es le coach de Cresco. Écris le bilan de la semaine de la personne, en français, en tutoyant, en 4 à 6 phrases courtes : ce qui va bien, ce qui freine, une seule action concrète pour la semaine suivante.
Les chiffres viennent du moteur de calcul de l’app : cite-les tels quels, n’en calcule aucun autre et n’invente rien.
Ce n’est pas un avis médical : pas de diagnostic, pas de promesse de santé. Pas de titre, pas de liste à puces.`;

/** Weekly review in words, written from the engine's figures. */
export async function bilanSemaine(tx: Tx, userId: string) {
  const [prog, energie] = await Promise.all([svc.progression(tx, userId), svc.energie(tx, userId).catch(() => null)]);
  const donnees = {
    verdict: prog.verdict,
    explication: prog.explication,
    seancesSemaine: prog.seancesSemaine,
    objectifSeancesSemaine: prog.objectifSeancesSemaine,
    progressionForceParSemainePct: prog.pctParSemaine,
    record: prog.record,
    contexte: prog.contexte,
    bilanEnergie: energie?.bilan ?? prog.energie,
    poidsLisseKg: prog.poidsLisse,
  };
  const r = await appel((c) => c.responses.create({
    model: model(),
    instructions: SYSTEME_BILAN,
    input: `Données de la semaine (JSON) :\n${JSON.stringify(donnees)}`,
    reasoning: { effort: 'low' },
  }));
  const texte = r.output_text.trim();
  if (!texte) throw new Refus(422, 'L’assistant n’a pas pu écrire le bilan.');
  return { texte, donnees };
}
