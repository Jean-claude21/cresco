import { FONCTIONS, REGLES, type NomFonction } from '@cresco/engine';
import { Hono, type Context } from 'hono';
import { cors } from 'hono/cors';
import { z, ZodError } from 'zod';
import { createToken, hashPassword, limiteConnexion, resolveToken, SCOPES, verifyPassword, type Principal } from './auth.ts';
import { asUser, type Db, type Tx } from './db.ts';
import { handleMcp } from './mcp.ts';
import { registerOauth } from './oauth.ts';
import * as ia from './ia.ts';
import * as svc from './services.ts';
import type { Source } from './sources.ts';

type Env = { Variables: { principal: Principal } };

export function createApp(deps: { db: Db; sources: Source[]; version: string }) {
  const { db } = deps;
  const app = new Hono<Env>();
  app.use('*', cors({ origin: '*', allowHeaders: ['Authorization', 'Content-Type', 'Mcp-Session-Id'], exposeHeaders: ['Mcp-Session-Id'] }));

  app.onError((err, c) => {
    if (err instanceof svc.Refus) return c.json({ erreur: err.message }, err.status);
    if (err instanceof ZodError) return c.json({ erreur: 'Entrée invalide', details: err.issues }, 400);
    // A missing or malformed JSON body is the client's mistake, not a server failure.
    if (err instanceof SyntaxError) return c.json({ erreur: 'Corps JSON invalide' }, 400);
    console.error(err);
    return c.json({ erreur: 'Erreur interne' }, 500);
  });

  // Docker probes /api/health every 30 s: it never touches the database, or Neon never sleeps
  // (LEARNINGS-BASES-SERVERLESS.md). The database is checked by hand on /api/health/db.
  app.get('/api/health', (c) => c.json({ status: 'ok', version: deps.version }));
  app.get('/api/health/db', async (c) => {
    try {
      await db.query('select 1');
      return c.json({ status: 'ok', base: 'ok' });
    } catch {
      return c.json({ status: 'degrade', base: 'injoignable' }, 503);
    }
  });
  app.get('/', (c) => c.json({ nom: 'Cresco', api: '/v1', mcp: '/mcp', sante: '/api/health', documentation: 'https://github.com/Jean-claude21/cresco' }));

  // ------------------------------------------------------------ Authentification
  const Identifiants = z.object({ email: z.string().email().max(200), motDePasse: z.string().min(10).max(200), nom: z.string().max(120).optional() });
  const ALL = [...SCOPES];

  app.post('/v1/auth/inscription', async (c) => {
    const e = Identifiants.parse(await c.req.json());
    const email = e.email.toLowerCase();
    if (!limiteConnexion(`ins:${c.req.header('x-forwarded-for') ?? ''}`)) return c.json({ erreur: 'Trop de tentatives' }, 429);
    const existe = await db.query('select 1 from utilisateur where email = $1', [email]);
    if (existe.rowCount) return c.json({ erreur: 'Adresse déjà utilisée' }, 409);
    const { rows } = await db.query<{ id: string }>('insert into utilisateur (email, mot_de_passe, nom) values ($1, $2, $3) returning id', [
      email,
      await hashPassword(e.motDePasse),
      e.nom ?? '',
    ]);
    const jeton = await createToken(db, rows[0]!.id, 'app mobile', ALL);
    return c.json({ utilisateurId: rows[0]!.id, jeton: jeton.token }, 201);
  });

  app.post('/v1/auth/connexion', async (c) => {
    const e = Identifiants.omit({ nom: true }).parse(await c.req.json());
    const email = e.email.toLowerCase();
    if (!limiteConnexion(`cnx:${email}`)) return c.json({ erreur: 'Trop de tentatives, réessaie dans 15 minutes' }, 429);
    const { rows } = await db.query<{ id: string; mot_de_passe: string }>('select id, mot_de_passe from utilisateur where email = $1', [email]);
    if (!rows[0] || !(await verifyPassword(e.motDePasse, rows[0].mot_de_passe))) return c.json({ erreur: 'Identifiants incorrects' }, 401);
    const jeton = await createToken(db, rows[0].id, 'app mobile', ALL);
    return c.json({ utilisateurId: rows[0].id, jeton: jeton.token });
  });

  registerOauth(app, db);

  // ------------------------------------------------------------ Tout le reste exige un jeton
  app.use('/v1/*', async (c, next) => {
    const principal = await resolveToken(db, c.req.header('authorization'));
    if (!principal) return c.json({ erreur: 'Jeton manquant ou invalide' }, 401);
    c.set('principal', principal);
    await next();
  });

  const exige = (c: Context<Env>, scope: string) => {
    if (!c.get('principal').scopes.has(scope)) throw new svc.Refus(403, `Permission manquante : ${scope}`);
  };
  const tx = <T>(c: Context<Env>, work: (t: Tx, userId: string) => Promise<T>) => asUser(db, c.get('principal').userId, (t) => work(t, c.get('principal').userId));
  const jours = (c: Context<Env>, defaut: number) => Math.min(365, Math.max(1, Number(c.req.query('jours') ?? defaut) || defaut));

  app.get('/v1/moi', async (c) => c.json(await tx(c, (t, u) => svc.profil(t, u))));
  app.patch('/v1/moi', async (c) => {
    const patch = svc.ProfilPatch.parse(await c.req.json());
    if (patch.preferences?.moduleFoi !== undefined || patch.preferences?.prioriteSpirituelle !== undefined) exige(c, 'foi:ecriture');
    return c.json(await tx(c, (t, u) => svc.modifierProfil(t, u, patch)));
  });

  app.get('/v1/jetons', async (c) => {
    const { rows } = await db.query('select id, nom, scopes, cree_le, dernier_usage from jeton where utilisateur_id = $1 and revoque_le is null order by cree_le desc', [
      c.get('principal').userId,
    ]);
    return c.json(rows);
  });
  app.post('/v1/jetons', async (c) => {
    const e = z.object({ nom: z.string().min(1).max(80), scopes: z.array(z.enum(SCOPES)).min(1) }).parse(await c.req.json());
    // Un jeton ne peut pas donner plus que celui qui le crée.
    const p = c.get('principal');
    const scopes = e.scopes.filter((s) => p.scopes.has(s));
    return c.json(await createToken(db, p.userId, e.nom, scopes), 201);
  });
  app.delete('/v1/jetons/:id', async (c) => {
    await db.query('update jeton set revoque_le = now() where id = $1 and utilisateur_id = $2', [c.req.param('id'), c.get('principal').userId]);
    return c.body(null, 204);
  });

  // ------------------------------------------------------------ Entraînement
  app.get('/v1/exercices', async (c) => {
    exige(c, 'entrainement:lecture');
    // ?gym=1: only what the user's gym allows (everything when no gym is described).
    const onlyGym = c.req.query('gym') === '1';
    return c.json(
      await tx(c, async (t) => {
        const rows = (await t.query(`select e.*, coalesce((select json_agg(l) from exercice_lien l where l.exercice_id = e.id), '[]') as liens from exercice e order by nom`)).rows;
        const available = await svc.exercisesAvailableAtGym(t);
        return rows
          .map((e) => ({ ...e, availableAtGym: available === null ? null : available.has(e.id) }))
          .filter((e) => !onlyGym || e.availableAtGym !== false);
      }),
    );
  });
  app.get('/v1/gym', async (c) => {
    exige(c, 'entrainement:lecture');
    return c.json(await tx(c, (t) => svc.getGym(t)));
  });
  app.put('/v1/gym', async (c) => {
    exige(c, 'entrainement:ecriture');
    const g = svc.GymInput.parse(await c.req.json());
    return c.json(await tx(c, (t, u) => svc.setGym(t, u, g)));
  });
  app.post('/v1/exercices/:id/liens', async (c) => {
    exige(c, 'entrainement:ecriture');
    const e = z.object({ url: z.string().url().startsWith('https://'), titre: z.string().max(120).default('') }).parse(await c.req.json());
    return c.json(
      await tx(c, async (t, u) => (await t.query(`insert into exercice_lien (user_id, exercice_id, url, titre) values ($1, $2, $3, $4) returning *`, [u, c.req.param('id'), e.url, e.titre])).rows[0]),
      201,
    );
  });
  app.get('/v1/modeles-seance', async (c) => {
    exige(c, 'entrainement:lecture');
    return c.json(await tx(c, async (t) => (await t.query(`select * from modele_seance order by cree_le desc`)).rows));
  });
  app.post('/v1/modeles-seance/valider', async (c) => {
    exige(c, 'entrainement:lecture');
    return c.json(svc.validerModele(svc.ModeleEntree.parse(await c.req.json())));
  });
  app.post('/v1/modeles-seance', async (c) => {
    exige(c, 'entrainement:ecriture');
    const m = svc.ModeleEntree.parse(await c.req.json());
    return c.json(await tx(c, (t, u) => svc.creerModele(t, u, m)), 201);
  });
  app.put('/v1/modeles-seance/:id', async (c) => {
    exige(c, 'entrainement:ecriture');
    const m = svc.ModeleEntree.parse(await c.req.json());
    return c.json(await tx(c, (t) => svc.updateTemplate(t, c.req.param('id'), m)));
  });
  app.delete('/v1/modeles-seance/:id', async (c) => {
    exige(c, 'entrainement:ecriture');
    await tx(c, (t) => svc.deleteTemplate(t, c.req.param('id')));
    return c.body(null, 204);
  });
  app.get('/v1/seances', async (c) => {
    exige(c, 'entrainement:lecture');
    return c.json(await tx(c, (t) => svc.seances(t, jours(c, 30))));
  });
  app.post('/v1/seances', async (c) => {
    exige(c, 'entrainement:ecriture');
    const s = svc.SeanceEntree.parse(await c.req.json());
    return c.json(await tx(c, (t, u) => svc.enregistrerSeance(t, u, s)), 201);
  });
  app.get('/v1/muscles', async (c) => {
    exige(c, 'entrainement:lecture');
    return c.json(await tx(c, (t) => svc.muscleVolume(t, jours(c, 7))));
  });
  app.get('/v1/seances/du-jour', async (c) => {
    exige(c, 'entrainement:lecture');
    // ?modele=<id>: today's adjustment applied to a template the user picked in "Mes séances".
    const templateId = c.req.query('modele');
    return c.json(await tx(c, (t, u) => svc.seanceDuJour(t, u, templateId)));
  });

  // ------------------------------------------------------------ Corps, sommeil, ressenti
  app.get('/v1/mesures', async (c) => {
    exige(c, 'corps:lecture');
    return c.json(await tx(c, (t) => svc.mesures(t, c.req.query('type') ?? 'poids', jours(c, 90))));
  });
  app.post('/v1/mesures', async (c) => {
    exige(c, 'corps:ecriture');
    const m = svc.MesureEntree.parse(await c.req.json());
    return c.json(await tx(c, (t, u) => svc.ajouterMesure(t, u, m)), 201);
  });
  app.get('/v1/nuits', async (c) => {
    exige(c, 'sommeil:lecture');
    return c.json(await tx(c, (t) => svc.nuits(t, jours(c, 30))));
  });
  app.post('/v1/nuits', async (c) => {
    exige(c, 'sommeil:ecriture');
    const n = svc.NuitEntree.parse(await c.req.json());
    return c.json(await tx(c, (t, u) => svc.ajouterNuit(t, u, n)), 201);
  });
  app.post('/v1/ressentis', async (c) => {
    exige(c, 'corps:ecriture');
    const r = svc.RessentiEntree.parse(await c.req.json());
    if (r.spirituel !== undefined) exige(c, 'foi:ecriture');
    return c.json(await tx(c, (t, u) => svc.ajouterRessenti(t, u, r)), 201);
  });
  app.get('/v1/forme', async (c) => {
    exige(c, 'sommeil:lecture');
    return c.json(await tx(c, (t, u) => svc.forme(t, u)));
  });

  // ------------------------------------------------------------ Nutrition
  app.get('/v1/aliments', async (c) => {
    exige(c, 'nutrition:lecture');
    const code = c.req.query('code');
    return c.json(await tx(c, (t) => (code ? svc.alimentParCode(t, code) : svc.chercherAliments(t, c.req.query('q') ?? ''))));
  });
  app.post('/v1/aliments', async (c) => {
    exige(c, 'nutrition:ecriture');
    const a = svc.AlimentEntree.parse(await c.req.json());
    return c.json(await tx(c, (t, u) => svc.creerAliment(t, u, a)), 201);
  });
  app.get('/v1/plats', async (c) => {
    exige(c, 'nutrition:lecture');
    return c.json(await tx(c, (t) => svc.plats(t)));
  });
  app.post('/v1/plats', async (c) => {
    exige(c, 'nutrition:ecriture');
    const p = svc.PlatEntree.parse(await c.req.json());
    return c.json(await tx(c, (t, u) => svc.creerPlat(t, u, p)), 201);
  });
  app.put('/v1/plats/:id/tags', async (c) => {
    exige(c, 'nutrition:ecriture');
    const { tags } = svc.DishTagsInput.parse(await c.req.json());
    return c.json(await tx(c, (t) => svc.setDishTags(t, c.req.param('id'), tags)));
  });
  // Integrated AI: proposes, the user confirms; the engine computes (src/ia.ts).
  app.get('/v1/ia', (c) => c.json({ disponible: ia.iaDisponible() }));
  app.post('/v1/ia/repas-texte', async (c) => {
    exige(c, 'nutrition:lecture');
    const r = ia.RepasTexte.parse(await c.req.json());
    return c.json(await tx(c, (t) => ia.repasDepuisTexte(t, r)));
  });
  app.post('/v1/ia/repas-photo', async (c) => {
    exige(c, 'nutrition:lecture');
    const r = ia.RepasPhoto.parse(await c.req.json());
    return c.json(await tx(c, (t) => ia.repasDepuisPhoto(t, r)));
  });
  app.get('/v1/ia/bilan', async (c) => {
    exige(c, 'entrainement:lecture');
    return c.json(await tx(c, (t, u) => ia.bilanSemaine(t, u)));
  });
  app.post('/v1/sante/import', async (c) => {
    exige(c, 'sommeil:ecriture');
    exige(c, 'corps:ecriture');
    const h = svc.HealthImport.parse(await c.req.json());
    return c.json(await tx(c, (t, u) => svc.importSante(t, u, h)));
  });
  app.put('/v1/plats/:id/portions', async (c) => {
    exige(c, 'nutrition:ecriture');
    const { portions } = svc.DishPortionsInput.parse(await c.req.json());
    return c.json(await tx(c, (t) => svc.setDishPortions(t, c.req.param('id'), portions)));
  });
  app.post('/v1/repas', async (c) => {
    exige(c, 'nutrition:ecriture');
    const r = svc.RepasEntree.parse(await c.req.json());
    return c.json(await tx(c, (t, u) => svc.ajouterRepas(t, u, r)), 201);
  });
  app.get('/v1/repas', async (c) => {
    exige(c, 'nutrition:lecture');
    return c.json(await tx(c, async (t) => (await t.query(`select * from repas where le > now() - make_interval(days => $1) order by le desc`, [jours(c, 7)])).rows));
  });
  app.get('/v1/energie', async (c) => {
    exige(c, 'nutrition:lecture');
    return c.json(await tx(c, (t, u) => svc.energie(t, u)));
  });

  // ------------------------------------------------------------ Jeûne
  app.get('/v1/jeunes', async (c) => {
    exige(c, 'jeune:lecture');
    return c.json(await tx(c, async (t) => (await t.query(`select * from jeune order by debut desc limit 50`)).rows));
  });
  app.post('/v1/jeunes', async (c) => {
    exige(c, 'jeune:ecriture');
    const j = svc.JeuneEntree.parse(await c.req.json());
    return c.json(await tx(c, (t, u) => svc.demarrerJeune(t, u, j)), 201);
  });
  app.get('/v1/jeunes/en-cours/decision', async (c) => {
    exige(c, 'jeune:lecture');
    const d = await tx(c, (t, u) => svc.decisionJeuneEnCours(t, u));
    return d ? c.json(d) : c.json({ erreur: 'Aucun jeûne en cours' }, 404);
  });
  app.post('/v1/jeunes/:id/terminer', async (c) => {
    exige(c, 'jeune:ecriture');
    return c.json(await tx(c, (t) => svc.terminerJeune(t, c.req.param('id'))));
  });
  app.post('/v1/jeunes/:id/evenements', async (c) => {
    exige(c, 'jeune:ecriture');
    const e = svc.EvenementJeuneEntree.parse(await c.req.json());
    if (e.type === 'spirituel') exige(c, 'foi:ecriture');
    return c.json(await tx(c, (t, u) => svc.noterJeune(t, u, c.req.param('id'), e)), 201);
  });
  app.get('/v1/jeunes/effet', async (c) => {
    exige(c, 'jeune:lecture');
    return c.json(await tx(c, (t) => svc.effetJeune(t)));
  });

  // ------------------------------------------------------------ Synthèses, moteur, références
  // ?tz=<minutes from UTC>: days of the streak in the user's local time.
  app.get('/v1/aujourdhui', async (c) => c.json(await tx(c, (t, u) => svc.aujourdhui(t, u, Number(c.req.query('tz') ?? 0) || 0))));
  app.get('/v1/progression', async (c) => {
    exige(c, 'entrainement:lecture');
    return c.json(await tx(c, (t, u) => svc.progression(t, u)));
  });
  app.post('/v1/calculs/:fonction', async (c) => {
    const f = FONCTIONS[c.req.param('fonction') as NomFonction] as ((e: unknown) => unknown) | undefined;
    if (!f) return c.json({ erreur: 'Fonction inconnue', disponibles: Object.keys(FONCTIONS) }, 404);
    try {
      return c.json({ fonction: c.req.param('fonction'), resultat: f(await c.req.json()) });
    } catch {
      return c.json({ erreur: 'Entrée invalide pour cette fonction' }, 400);
    }
  });
  app.get('/v1/regles', (c) => c.json(REGLES));
  app.get('/v1/sources', (c) => c.json(deps.sources));
  app.get('/v1/export', async (c) => {
    exige(c, 'export');
    return c.json(await tx(c, (t, u) => svc.exporter(t, u)));
  });
  app.delete('/v1/moi', async (c) => {
    // Suppression du compte et de toutes ses données (RGPD) : les tables suivent par cascade.
    await db.query('delete from utilisateur where id = $1', [c.get('principal').userId]);
    return c.body(null, 204);
  });

  // ------------------------------------------------------------ MCP
  app.all('/mcp', async (c) => {
    const principal = await resolveToken(db, c.req.header('authorization'));
    if (!principal) {
      // MCP authorization: tells the client where to find the OAuth server (RFC 9728).
      const b = process.env['APP_BASE_URL'] ?? new URL(c.req.url).origin;
      c.header('WWW-Authenticate', `Bearer resource_metadata="${b}/.well-known/oauth-protected-resource"`);
      return c.json({ erreur: 'Jeton manquant ou invalide (Authorization: Bearer cr_…)' }, 401);
    }
    return handleMcp(c.req.raw, { db, principal, sources: deps.sources });
  });

  return app;
}
