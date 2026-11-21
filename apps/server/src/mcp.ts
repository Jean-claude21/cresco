// Serveur MCP (docs/architecture/API_MCP.md). Sans état : un serveur et un transport par requête,
// authentifiés par le même jeton que l'API. Chaque outil appelle les services, jamais la base en direct,
// et respecte les permissions du jeton. Aucun outil ne contourne une règle de sécurité.
import { FONCTIONS, REGLES, type NomFonction } from '@cresco/engine';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { WebStandardStreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/webStandardStreamableHttp.js';
import { z } from 'zod';
import type { Principal } from './auth.ts';
import { asUser, type Db, type Tx } from './db.ts';
import * as svc from './services.ts';
import type { Source } from './sources.ts';

type Ctx = { db: Db; principal: Principal; sources: Source[] };

function construire(ctx: Ctx) {
  const server = new McpServer({ name: 'cresco', version: '0.1.0' });
  const ok = (data: unknown) => ({ content: [{ type: 'text' as const, text: JSON.stringify(data, null, 2) }] });
  const echec = (message: string) => ({ content: [{ type: 'text' as const, text: message }], isError: true });
  const run = (scope: string | null, work: (tx: Tx, userId: string) => Promise<unknown>) => async () => {
    if (scope && !ctx.principal.scopes.has(scope)) return echec(`Permission manquante : ${scope}`);
    try {
      await ctx.db.query('insert into journal_acces (utilisateur_id, jeton_id, porte, action) values ($1, $2, $3, $4)', [
        ctx.principal.userId,
        ctx.principal.jetonId,
        'mcp',
        scope ?? 'lecture',
      ]);
      return ok(await asUser(ctx.db, ctx.principal.userId, (tx) => work(tx, ctx.principal.userId)));
    } catch (error) {
      return echec(error instanceof svc.Refus || error instanceof z.ZodError ? (error as Error).message : 'Erreur interne');
    }
  };

  server.registerTool('obtenir_profil', { description: 'Profil, objectifs et préférences de l’utilisateur.' }, run(null, (t, u) => svc.profil(t, u)));
  server.registerTool(
    'obtenir_aujourdhui',
    { description: 'Vue du jour : score de forme, séance ajustée et pourquoi, énergie du jour, jeûne en cours.' },
    run('entrainement:lecture', (t, u) => svc.aujourdhui(t, u)),
  );
  server.registerTool(
    'obtenir_seance_du_jour',
    { description: 'Séance du jour ajustée (volume, charges calculées par le moteur), avec la décision, la raison et les règles appliquées.' },
    run('entrainement:lecture', (t, u) => svc.seanceDuJour(t, u)),
  );
  server.registerTool(
    'programmer_seance',
    {
      description:
        'Crée un modèle de séance (blocs → étapes). Muscu : duree.reps + cible.rir + cible.charge_kg ("auto" = calculée par le moteur). Cardio : duree.temps_s + cible.vitesse_ms (m/s). Refusé si hors bornes de sécurité. Lis d’abord get_gym : la réponse liste dans unavailableAtGym les exercices absents de la salle.',
      inputSchema: svc.ModeleEntree.shape,
    },
    async (args) => run('entrainement:ecriture', (t, u) => svc.creerModele(t, u, svc.ModeleEntree.parse(args), 'ia'))(),
  );
  server.registerTool(
    'enregistrer_seance',
    { description: 'Enregistre une séance réalisée avec ses séries (reps, charge, RIR…). Le moteur calcule e1RM et sRPE.', inputSchema: svc.SeanceEntree.shape },
    async (args) => run('entrainement:ecriture', (t, u) => svc.enregistrerSeance(t, u, svc.SeanceEntree.parse(args)))(),
  );
  server.registerTool(
    'lister_seances',
    { description: 'Séances réalisées sur N jours.', inputSchema: { jours: z.number().int().min(1).max(365).default(30) } },
    async ({ jours }) => run('entrainement:lecture', (t) => svc.seances(t, jours))(),
  );
  server.registerTool(
    'obtenir_progression',
    { description: 'Verdict hebdomadaire (progression, maintien = réussite, stagnation, patience), tendances e1RM par exercice et contexte.' },
    run('entrainement:lecture', (t, u) => svc.progression(t, u)),
  );
  server.registerTool(
    'chercher_aliment',
    { description: 'Cherche un aliment par nom, ou par code-barres (Open Food Facts).', inputSchema: { q: z.string().optional(), codeBarres: z.string().optional() } },
    async ({ q, codeBarres }) => run('nutrition:lecture', (t) => (codeBarres ? svc.alimentParCode(t, codeBarres) : svc.chercherAliments(t, q ?? '')))(),
  );
  server.registerTool(
    'creer_aliment',
    { description: 'Ajoute un aliment personnel (valeurs pour 100 g).', inputSchema: svc.AlimentEntree.shape },
    async (args) => run('nutrition:ecriture', (t, u) => svc.creerAliment(t, u, svc.AlimentEntree.parse(args)))(),
  );
  server.registerTool(
    'creer_plat',
    {
      description: 'Crée un plat de « Mes plats » à partir d’ingrédients (identifiants d’aliments et masses crues en g). Le moteur calcule les nutriments.',
      inputSchema: svc.PlatEntree.shape,
    },
    async (args) => run('nutrition:ecriture', (t, u) => svc.creerPlat(t, u, svc.PlatEntree.parse(args), 'ia'))(),
  );
  server.registerTool(
    'ajouter_repas',
    { description: 'Ajoute un repas : portions d’aliments ou de plats (masse en g).', inputSchema: svc.RepasEntree.shape },
    async (args) => run('nutrition:ecriture', (t, u) => svc.ajouterRepas(t, u, svc.RepasEntree.parse(args)))(),
  );
  server.registerTool(
    'obtenir_bilan_energie',
    { description: 'BMR, TDEE (adaptatif si assez de données), cibles de macros, bilan du jour et verdict déficit / maintien / surplus avec confiance.' },
    run('nutrition:lecture', (t, u) => svc.energie(t, u)),
  );
  server.registerTool(
    'get_gym',
    {
      description:
        'The user’s main gym ("Ma salle"): checked equipment, full equipment catalog and chain presets. Only program exercises this equipment allows.',
    },
    run('entrainement:lecture', (t) => svc.getGym(t)),
  );
  server.registerTool(
    'set_gym',
    {
      description: 'Saves the user’s main gym and the equipment really available (keys from the get_gym catalog). Ask the user to confirm the list first.',
      inputSchema: svc.GymInput.shape,
    },
    async (args) => run('entrainement:ecriture', (t, u) => svc.setGym(t, u, svc.GymInput.parse(args)))(),
  );
  server.registerTool(
    'muscle_volume',
    { description: 'Effective sets per muscle over the last 7 days (C-PERF-5) and the 10-set weekly guideline.' },
    run('entrainement:lecture', (t) => svc.muscleVolume(t, 7)),
  );
  server.registerTool('obtenir_forme', { description: 'Score de forme du jour et ses composantes.' }, run('sommeil:lecture', (t, u) => svc.forme(t, u)));
  server.registerTool(
    'ajouter_nuit',
    { description: 'Ajoute une nuit de sommeil.', inputSchema: svc.NuitEntree.shape },
    async (args) => run('sommeil:ecriture', (t, u) => svc.ajouterNuit(t, u, svc.NuitEntree.parse(args)))(),
  );
  server.registerTool(
    'ajouter_mesure',
    { description: 'Ajoute une mesure : poids, tour_taille, masse_grasse, vfc, fc_repos.', inputSchema: svc.MesureEntree.shape },
    async (args) => run('corps:ecriture', (t, u) => svc.ajouterMesure(t, u, svc.MesureEntree.parse(args)))(),
  );
  server.registerTool(
    'demarrer_jeune',
    { description: 'Démarre un jeûne (intermittent, eau, sec ≤ 24 h, partiel/Daniel).', inputSchema: svc.JeuneEntree.shape },
    async (args) => run('jeune:ecriture', (t, u) => svc.demarrerJeune(t, u, svc.JeuneEntree.parse(args)))(),
  );
  server.registerTool(
    'terminer_jeune',
    { description: 'Termine le jeûne indiqué.', inputSchema: { jeuneId: z.string().uuid() } },
    async ({ jeuneId }) => run('jeune:ecriture', (t) => svc.terminerJeune(t, jeuneId))(),
  );
  server.registerTool(
    'noter_jeune',
    { description: 'Note un événement du jeûne : eau, electrolytes, symptome (déclenche l’arrêt de séance), clarte, energie.', inputSchema: { jeuneId: z.string().uuid(), ...svc.EvenementJeuneEntree.shape } },
    async ({ jeuneId, ...e }) => run(e.type === 'spirituel' ? 'foi:ecriture' : 'jeune:ecriture', (t, u) => svc.noterJeune(t, u, jeuneId, svc.EvenementJeuneEntree.parse(e)))(),
  );
  server.registerTool(
    'decision_jeune',
    { description: 'Décision d’entraînement pour le jeûne en cours (J-DECISION), phase, et plan de reprise.' },
    run('jeune:lecture', (t, u) => svc.decisionJeuneEnCours(t, u)),
  );
  server.registerTool('effet_jeune', { description: 'Effet personnel mesuré du jeûne (J-EFFET).' }, run('jeune:lecture', (t) => svc.effetJeune(t)));
  server.registerTool(
    'calculer',
    {
      description: `Exécute une fonction du moteur (formules sourcées). Fonctions : ${Object.keys(FONCTIONS).join(', ')}.`,
      inputSchema: { fonction: z.string(), entree: z.record(z.unknown()) },
    },
    async ({ fonction, entree }) => {
      const f = FONCTIONS[fonction as NomFonction] as ((e: unknown) => unknown) | undefined;
      if (!f) return echec(`Fonction inconnue. Disponibles : ${Object.keys(FONCTIONS).join(', ')}`);
      try {
        return ok(f(entree));
      } catch {
        return echec('Entrée invalide pour cette fonction');
      }
    },
  );
  server.registerTool(
    'expliquer_regle',
    { description: 'Catalogue des règles (identifiant, nom, niveau de preuve, sources) et bibliothèque de sources.', inputSchema: { regle: z.string().optional() } },
    async ({ regle }) => {
      const regles = regle ? REGLES.filter((r) => r.id === regle) : REGLES;
      const ids = new Set(regles.flatMap((r) => r.sources as readonly string[]));
      return ok({ regles, sources: ctx.sources.filter((s) => ids.has(s.id)) });
    },
  );
  return server;
}

export async function handleMcp(request: Request, ctx: Ctx): Promise<Response> {
  const server = construire(ctx);
  const transport = new WebStandardStreamableHTTPServerTransport({ sessionIdGenerator: undefined, enableJsonResponse: true });
  await server.connect(transport);
  try {
    return await transport.handleRequest(request);
  } finally {
    void server.close();
  }
}
