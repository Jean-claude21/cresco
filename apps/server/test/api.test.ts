// Test de bout en bout de l'API et du MCP sur un vrai PostgreSQL (TEST_DATABASE_URL, rôle propriétaire).
// Ignoré sans base : `node scripts/db-local.mjs start` puis TEST_DATABASE_URL=… pnpm test.
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createApp } from '../src/app.ts';
import { createPool, migrate, type Db } from '../src/db.ts';
import { chargerSources } from '../src/sources.ts';

const TEST_URL = process.env.TEST_DATABASE_URL;
const ici = path.dirname(fileURLToPath(import.meta.url));
const racine = path.resolve(ici, '../../..');

describe.skipIf(!TEST_URL)('API Cresco (Postgres réel)', () => {
  let owner: Db;
  let db: Db;
  let app: ReturnType<typeof createApp>;
  let jeton = '';
  let autreJeton = '';

  const appel = async (methode: string, route: string, corps?: unknown, j = jeton) => {
    const res = await app.request(route, {
      method: methode,
      headers: { 'Content-Type': 'application/json', ...(j ? { Authorization: `Bearer ${j}` } : {}) },
      ...(corps === undefined ? {} : { body: JSON.stringify(corps) }),
    });
    const texte = await res.text();
    return { status: res.status, corps: texte ? JSON.parse(texte) : null };
  };

  beforeAll(async () => {
    owner = createPool(TEST_URL!, 2);
    await owner.query('drop schema public cascade; create schema public; grant all on schema public to public;');
    await owner.query(`do $$ begin if exists (select 1 from pg_roles where rolname = 'cresco_app') then
      execute 'drop owned by cresco_app'; drop role cresco_app; end if; end $$;`);
    await migrate(owner, { directory: path.join(racine, 'apps/server/db/migrations'), appPassword: 'mot-de-passe-test' });
    const url = new URL(TEST_URL!);
    url.username = 'cresco_app';
    url.password = 'mot-de-passe-test';
    db = createPool(url.toString(), 4);
    app = createApp({ db, sources: chargerSources(racine), version: 'test' });
  });
  afterAll(async () => {
    await db?.end();
    await owner?.end();
  });

  it('répond à la santé', async () => {
    const r = await appel('GET', '/api/health');
    expect(r.corps.status).toBe('ok');
  });

  it('inscrit, connecte et refuse sans jeton', async () => {
    const ins = await appel('POST', '/v1/auth/inscription', { email: 'test@cresco.test', motDePasse: 'un-mot-de-passe-long', nom: 'Test' }, '');
    expect(ins.status).toBe(201);
    jeton = ins.corps.jeton;
    const cnx = await appel('POST', '/v1/auth/connexion', { email: 'test@cresco.test', motDePasse: 'un-mot-de-passe-long' }, '');
    expect(cnx.status).toBe(200);
    const mauvais = await appel('POST', '/v1/auth/connexion', { email: 'test@cresco.test', motDePasse: 'mauvais-mot-de-passe' }, '');
    expect(mauvais.status).toBe(401);
    expect((await appel('GET', '/v1/moi', undefined, '')).status).toBe(401);
    const autre = await appel('POST', '/v1/auth/inscription', { email: 'autre@cresco.test', motDePasse: 'un-autre-mot-de-passe' }, '');
    autreJeton = autre.corps.jeton;
  });

  it('met à jour le profil', async () => {
    const r = await appel('PATCH', '/v1/moi', { sexe: 'homme', naissance: '1995-03-10', taille_cm: 180, niveau: 'intermediaire', objectif: 'maintien' });
    expect(r.status).toBe(200);
    expect(r.corps.taille_cm).toBe(180);
  });

  it('enregistre une séance et calcule e1RM et sRPE', async () => {
    const r = await appel('POST', '/v1/seances', {
      type: 'muscu',
      rpe: 7,
      dureeMin: 60,
      series: [{ exerciceId: 'developpe-couche-barre', reps: 5, chargeKg: 100, rir: 2 }],
    });
    expect(r.status).toBe(201);
    expect(r.corps.srpe).toBe(420);
    const liste = await appel('GET', '/v1/seances');
    expect(liste.corps[0].series[0].e1rm).toBeCloseTo(120, 1);
  });

  it('computes weekly effective sets per muscle (C-PERF-5)', async () => {
    const r = await appel('GET', '/v1/muscles');
    expect(r.status).toBe(200);
    expect(r.corps.rule).toBe('C-PERF-5');
    expect(r.corps.guideline).toBe(10);
    const sets = Object.fromEntries(r.corps.muscles.map((m: { muscle: string; effectiveSets: number }) => [m.muscle, m.effectiveSets]));
    expect(sets).toEqual({ pectoraux: 1, triceps: 0.5, epaules: 0.5 });
  });

  it('isole les données entre utilisateurs (RLS)', async () => {
    const liste = await appel('GET', '/v1/seances', undefined, autreJeton);
    expect(liste.corps).toHaveLength(0);
  });

  it('propose la séance du jour avec charges calculées', async () => {
    await appel('POST', '/v1/nuits', { coucher: new Date(Date.now() - 9 * 3_600_000).toISOString(), lever: new Date(Date.now() - 3_600_000).toISOString(), dormiMin: 365 });
    await appel('POST', '/v1/ressentis', { energie: 3 });
    const r = await appel('GET', '/v1/seances/du-jour');
    expect(r.status).toBe(200);
    expect(['NORMALE', 'ADAPTEE', 'LEGERE']).toContain(r.corps.decision.decision);
    const dc = r.corps.modele.blocs[0].etapes[0];
    expect(dc.exercice_id).toBe('developpe-couche-barre');
    expect(dc.cible.charge_kg).toBe(90);
  });

  it('garde le plan normal tant que la confiance est basse (nouveau compte, une séance)', async () => {
    const nouveau = await appel('POST', '/v1/auth/inscription', { email: 'debutant@cresco.test', motDePasse: 'un-mot-de-passe-long' }, '');
    const j = nouveau.corps.jeton;
    await appel('POST', '/v1/seances', { type: 'muscu', rpe: 7, dureeMin: 1, series: [{ exerciceId: 'squat-barre', reps: 5, chargeKg: 60, rir: 2 }] }, j);
    const r = await appel('GET', '/v1/seances/du-jour', undefined, j);
    expect(r.corps.forme.confiance).toBe('basse');
    expect(r.corps.forme.composantes.ratioAiguChronique).toBeNull();
    expect(r.corps.decision).toEqual({ decision: 'NORMALE', volume: 0 });
    expect(r.corps.raison).toMatch(/pas encore assez de données/u);
  });

  it('refuse une séance hors bornes', async () => {
    const r = await appel('POST', '/v1/modeles-seance', {
      nom: 'Trop',
      type: 'muscu',
      blocs: [{ repeter: 30, etapes: [{ exercice_id: 'squat-barre', duree: { reps: 5 }, cible: { rir: 1 } }, { exercice_id: 'squat-barre', duree: { reps: 5 }, cible: { rir: 1 } }] }],
    });
    expect(r.status).toBe(422);
  });

  it('crée un plat, un repas et calcule l’énergie', async () => {
    const riz = await appel('POST', '/v1/aliments', { nom: 'Riz cuit', kcal100: 130, proteines100: 2.7, glucides100: 28, lipides100: 0.3 });
    const oeuf = await appel('POST', '/v1/aliments', { nom: 'Œuf', kcal100: 165, proteines100: 31, glucides100: 1, lipides100: 11 });
    const plat = await appel('POST', '/v1/plats', { nom: 'Riz aux œufs', ingredients: [{ alimentId: riz.corps.id, masse: 200 }, { alimentId: oeuf.corps.id, masse: 100 }], masseCuite: 400 });
    expect(plat.status).toBe(201);
    expect(plat.corps.nutriments.kcal100).toBeCloseTo(106.25, 2);
    const repas = await appel('POST', '/v1/repas', { type: 'dejeuner', portions: [{ platId: plat.corps.id, masse: 200 }] });
    expect(repas.corps.kcal).toBeCloseTo(212.5, 1);
    const e = await appel('GET', '/v1/energie');
    expect(e.corps.bmr).toBeGreaterThan(1500);
    expect(e.corps.cibles.proteines).toBeGreaterThan(0);
  });

  it('gère un jeûne : décision, limite du jeûne sec, symptôme', async () => {
    const debut = new Date(Date.now() - 20 * 3_600_000).toISOString();
    const j = await appel('POST', '/v1/jeunes', { type: 'eau', motif: 'spirituel', intention: 'Silence', debut });
    expect(j.status).toBe(201);
    const d = await appel('GET', '/v1/jeunes/en-cours/decision');
    expect(d.corps.decision.decision).toBe('ADAPTEE');
    expect(d.corps.jeune.phase).toBe('bascule');
    const e = await appel('GET', '/v1/energie');
    expect(e.corps.ciblesSuspendues).toBe(true);
    await appel('POST', `/v1/jeunes/${j.corps.id}/evenements`, { type: 'symptome', valeur: 'vertiges' });
    const arret = await appel('GET', '/v1/jeunes/en-cours/decision');
    expect(arret.corps.decision.decision).toBe('ARRET');
    expect((await appel('POST', `/v1/jeunes/${j.corps.id}/terminer`)).status).toBe(200);
    const sec = await appel('POST', '/v1/jeunes', { type: 'sec', debut: new Date().toISOString(), finPrevue: new Date(Date.now() + 30 * 3_600_000).toISOString() });
    expect(sec.status).toBe(422);
  });

  it('limite les permissions d’un jeton tiers', async () => {
    const t = await appel('POST', '/v1/jetons', { nom: 'lecture seule', scopes: ['entrainement:lecture'] });
    expect(t.status).toBe(201);
    expect((await appel('GET', '/v1/seances', undefined, t.corps.token)).status).toBe(200);
    expect((await appel('POST', '/v1/nuits', { coucher: new Date().toISOString(), lever: new Date().toISOString(), dormiMin: 0 }, t.corps.token)).status).toBe(403);
  });

  it('expose le moteur, les règles et les sources', async () => {
    const c = await appel('POST', '/v1/calculs/e1rm', { charge: 100, reps: 5, rir: 2 });
    expect(c.corps.resultat.valeur).toBeCloseTo(120, 5);
    expect((await appel('GET', '/v1/regles')).corps.length).toBeGreaterThan(10);
    const sources = (await appel('GET', '/v1/sources')).corps;
    expect(sources.find((s: { id: string }) => s.id === 'S-23').statut).toBe('verifie');
  });

  it('répond en MCP (liste et appel d’outil)', async () => {
    const mcp = async (corps: unknown) => {
      const res = await app.request('/mcp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json, text/event-stream', Authorization: `Bearer ${jeton}` },
        body: JSON.stringify(corps),
      });
      return res.json() as Promise<{ result: { tools?: { name: string }[]; content?: { text: string }[] } }>;
    };
    await mcp({ jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'test', version: '1' } } });
    const outils = await mcp({ jsonrpc: '2.0', id: 2, method: 'tools/list' });
    expect(outils.result.tools!.map((t) => t.name)).toContain('obtenir_seance_du_jour');
    const appelOutil = await mcp({ jsonrpc: '2.0', id: 3, method: 'tools/call', params: { name: 'calculer', arguments: { fonction: 'phaseJeune', entree: { heures: 30 } } } });
    expect(JSON.parse(appelOutil.result.content![0]!.text).phase).toBe('cetose');
  });

  it('exporte et supprime le compte', async () => {
    const ex = await appel('GET', '/v1/export');
    expect(ex.corps.seance.length).toBeGreaterThan(0);
    expect((await appel('DELETE', '/v1/moi')).status).toBe(204);
    expect((await appel('GET', '/v1/moi')).status).toBe(401);
  });
});
