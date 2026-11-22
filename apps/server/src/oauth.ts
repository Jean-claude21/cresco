/**
 * OAuth 2.1 for third-party apps and AI assistants (MCP authorization):
 * - discovery: /.well-known/oauth-authorization-server (RFC 8414) and
 *   /.well-known/oauth-protected-resource (RFC 9728, the /mcp resource);
 * - dynamic client registration (RFC 7591), public clients only;
 * - authorization code with PKCE S256 (required), refresh tokens rotated at each use.
 *
 * The consent page shows each permission; `foi:*` and `jeune:*` are never pre-checked
 * (CONFORMITE.md). Access tokens are ordinary Cresco tokens (`cr_…`), so they appear in Profil
 * and can be revoked there.
 */
import { createHash, randomBytes } from 'node:crypto';
import type { Hono } from 'hono';
import { html, raw } from 'hono/html';
import { z } from 'zod';
import { createToken, limiteConnexion, SCOPES, verifyPassword } from './auth.ts';
import type { Db } from './db.ts';

const hash = (v: string) => createHash('sha256').update(v).digest('hex');
const challengeOf = (verifier: string) => createHash('sha256').update(verifier).digest('base64url');

/** French labels of the permissions, as on the consent page. */
const LIBELLES: Record<string, string> = {
  'entrainement:lecture': 'Lire tes séances et ta salle',
  'entrainement:ecriture': 'Créer des séances',
  'nutrition:lecture': 'Lire tes repas et tes plats',
  'nutrition:ecriture': 'Ajouter des repas et des plats',
  'sommeil:lecture': 'Lire ton sommeil',
  'sommeil:ecriture': 'Ajouter des nuits',
  'jeune:lecture': 'Lire tes jeûnes',
  'jeune:ecriture': 'Gérer tes jeûnes',
  'corps:lecture': 'Lire tes mesures',
  'corps:ecriture': 'Ajouter des mesures',
  'foi:lecture': 'Lire ton module foi',
  'foi:ecriture': 'Modifier ton module foi',
  export: 'Exporter toutes tes données',
};
/** Never granted unless the user ticks them (CONFORMITE.md). */
const SENSIBLES = new Set(['foi:lecture', 'foi:ecriture', 'jeune:lecture', 'jeune:ecriture', 'export']);

const Registration = z.object({
  client_name: z.string().trim().min(1).max(80).default('Application'),
  redirect_uris: z
    .array(
      z
        .string()
        .url()
        .refine((u) => u.startsWith('https://') || /^http:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?\//u.test(u), 'https ou boucle locale'),
    )
    .min(1)
    .max(10),
});

const AuthorizeQuery = z.object({
  response_type: z.literal('code'),
  client_id: z.string().min(1).max(100),
  redirect_uri: z.string().url(),
  code_challenge: z.string().min(43).max(128),
  code_challenge_method: z.literal('S256'),
  state: z.string().max(500).optional(),
  scope: z.string().max(1000).optional(),
});

export function registerOauth(app: Hono<any>, db: Db) {
  const base = (url: string) => process.env['APP_BASE_URL'] ?? new URL(url).origin;

  app.get('/.well-known/oauth-authorization-server', (c) => {
    const b = base(c.req.url);
    return c.json({
      issuer: b,
      authorization_endpoint: `${b}/oauth/authorize`,
      token_endpoint: `${b}/oauth/token`,
      registration_endpoint: `${b}/oauth/register`,
      revocation_endpoint: `${b}/oauth/revoke`,
      response_types_supported: ['code'],
      grant_types_supported: ['authorization_code', 'refresh_token'],
      code_challenge_methods_supported: ['S256'],
      token_endpoint_auth_methods_supported: ['none'],
      scopes_supported: [...SCOPES],
    });
  });
  app.get('/.well-known/oauth-protected-resource', (c) => {
    const b = base(c.req.url);
    return c.json({ resource: `${b}/mcp`, authorization_servers: [b], scopes_supported: [...SCOPES], bearer_methods_supported: ['header'] });
  });

  app.post('/oauth/register', async (c) => {
    if (!limiteConnexion(`reg:${c.req.header('x-forwarded-for') ?? ''}`)) return c.json({ error: 'too_many_requests' }, 429);
    const r = Registration.safeParse(await c.req.json().catch(() => null));
    if (!r.success) return c.json({ error: 'invalid_client_metadata', error_description: r.error.issues[0]?.message }, 400);
    const id = `cl_${randomBytes(16).toString('base64url')}`;
    await db.query('insert into oauth_client (id, nom, redirect_uris) values ($1, $2, $3)', [id, r.data.client_name, r.data.redirect_uris]);
    return c.json(
      {
        client_id: id,
        client_name: r.data.client_name,
        redirect_uris: r.data.redirect_uris,
        token_endpoint_auth_method: 'none',
        grant_types: ['authorization_code', 'refresh_token'],
        response_types: ['code'],
      },
      201,
    );
  });

  const client = async (id: string) =>
    (await db.query<{ id: string; nom: string; redirect_uris: string[] }>('select id, nom, redirect_uris from oauth_client where id = $1', [id])).rows[0];

  app.get('/oauth/authorize', async (c) => {
    const q = AuthorizeQuery.safeParse(c.req.query());
    if (!q.success) return c.html(page('Demande invalide', html`<p>Cette demande d’accès est incomplète.</p>`), 400);
    const cl = await client(q.data.client_id);
    if (!cl || !cl.redirect_uris.includes(q.data.redirect_uri)) return c.html(page('Application inconnue', html`<p>Cette application n’est pas enregistrée.</p>`), 400);
    const demandes = (q.data.scope?.split(' ').filter((s) => (SCOPES as readonly string[]).includes(s)) ?? []) as string[];
    return c.html(consent(cl.nom, q.data, demandes.length ? demandes : [...SCOPES], null));
  });

  app.post('/oauth/authorize', async (c) => {
    const f = await c.req.parseBody({ all: true });
    const q = AuthorizeQuery.safeParse(f);
    if (!q.success) return c.html(page('Demande invalide', html`<p>Cette demande d’accès est incomplète.</p>`), 400);
    const cl = await client(q.data.client_id);
    if (!cl || !cl.redirect_uris.includes(q.data.redirect_uri)) return c.html(page('Application inconnue', html`<p>Cette application n’est pas enregistrée.</p>`), 400);
    const redirect = new URL(q.data.redirect_uri);
    if (q.data.state) redirect.searchParams.set('state', q.data.state);
    if (f['refuser'] != null) {
      redirect.searchParams.set('error', 'access_denied');
      return c.redirect(redirect.toString(), 302);
    }
    const demandes = String(f['demandes'] ?? '').split(' ').filter((s) => (SCOPES as readonly string[]).includes(s));
    const email = String(f['email'] ?? '').trim().toLowerCase();
    if (!limiteConnexion(`cnx:${email}`)) return c.html(consent(cl.nom, q.data, demandes, 'Trop de tentatives, réessaie dans 15 minutes.'), 429);
    const { rows } = await db.query<{ id: string; mot_de_passe: string }>('select id, mot_de_passe from utilisateur where email = $1', [email]);
    if (!rows[0] || !(await verifyPassword(String(f['motDePasse'] ?? ''), rows[0].mot_de_passe))) {
      return c.html(consent(cl.nom, q.data, demandes, 'Adresse ou mot de passe incorrect.'), 401);
    }
    const coches = [f['accorde']].flat().map(String);
    const scopes = demandes.filter((s) => coches.includes(s));
    if (!scopes.length) return c.html(consent(cl.nom, q.data, demandes, 'Choisis au moins une permission.'), 400);
    const code = randomBytes(32).toString('base64url');
    await db.query(
      `insert into oauth_code (empreinte, client_id, utilisateur_id, redirect_uri, scopes, challenge, expire_le)
       values ($1, $2, $3, $4, $5, $6, now() + interval '5 minutes')`,
      [hash(code), cl.id, rows[0].id, q.data.redirect_uri, scopes, q.data.code_challenge],
    );
    redirect.searchParams.set('code', code);
    return c.redirect(redirect.toString(), 302);
  });

  app.post('/oauth/token', async (c) => {
    const f = Object.fromEntries(Object.entries(await c.req.parseBody()).map(([k, v]) => [k, String(v)]));
    const erreur = (error: string, description: string) => c.json({ error, error_description: description }, 400);
    if (f['grant_type'] === 'authorization_code') {
      const { rows } = await db.query<{ client_id: string; utilisateur_id: string; redirect_uri: string; scopes: string[]; challenge: string }>(
        `update oauth_code set utilise = true where empreinte = $1 and not utilise and expire_le > now()
         returning client_id, utilisateur_id, redirect_uri, scopes, challenge`,
        [hash(f['code'] ?? '')],
      );
      const r = rows[0];
      if (!r || r.client_id !== f['client_id'] || r.redirect_uri !== f['redirect_uri']) return erreur('invalid_grant', 'Code invalide ou expiré');
      if (challengeOf(f['code_verifier'] ?? '') !== r.challenge) return erreur('invalid_grant', 'PKCE : code_verifier incorrect');
      return c.json(await emettre(r.client_id, r.utilisateur_id, r.scopes));
    }
    if (f['grant_type'] === 'refresh_token') {
      const { rows } = await db.query<{ client_id: string; utilisateur_id: string; scopes: string[]; jeton_id: string }>(
        `update oauth_refresh set revoque_le = now() where empreinte = $1 and revoque_le is null and expire_le > now()
         returning client_id, utilisateur_id, scopes, jeton_id`,
        [hash(f['refresh_token'] ?? '')],
      );
      const r = rows[0];
      if (!r || r.client_id !== f['client_id']) return erreur('invalid_grant', 'Jeton de rafraîchissement invalide');
      await db.query('update jeton set revoque_le = now() where id = $1', [r.jeton_id]);
      return c.json(await emettre(r.client_id, r.utilisateur_id, r.scopes));
    }
    return erreur('unsupported_grant_type', 'authorization_code ou refresh_token');
  });

  app.post('/oauth/revoke', async (c) => {
    const token = String((await c.req.parseBody())['token'] ?? '');
    const { rows } = await db.query<{ jeton_id: string }>('update oauth_refresh set revoque_le = now() where empreinte = $1 returning jeton_id', [hash(token)]);
    if (rows[0]) await db.query('update jeton set revoque_le = now() where id = $1', [rows[0].jeton_id]);
    await db.query('update jeton set revoque_le = now() where empreinte = $1', [hash(token)]);
    return c.body(null, 200);
  });

  async function emettre(clientId: string, userId: string, scopes: string[]) {
    const nom = (await client(clientId))?.nom ?? 'Application';
    const acces = await createToken(db, userId, `${nom} (OAuth)`, scopes);
    const refresh = `crr_${randomBytes(32).toString('base64url')}`;
    await db.query(
      `insert into oauth_refresh (empreinte, client_id, utilisateur_id, scopes, jeton_id, expire_le)
       values ($1, $2, $3, $4, $5, now() + interval '90 days')`,
      [hash(refresh), clientId, userId, acces.scopes, acces.id],
    );
    return { access_token: acces.token, token_type: 'Bearer', refresh_token: refresh, scope: acces.scopes.join(' ') };
  }
}

function page(titre: string, corps: ReturnType<typeof html>) {
  return html`<!doctype html>
    <html lang="fr">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>${titre} · Cresco</title>
        <style>
          ${raw(`body{font-family:system-ui,sans-serif;background:#fff;color:#111;margin:0;padding:24px;max-width:480px;margin:auto}
          h1{font-size:28px;margin:8px 0}label{display:block;margin:10px 0}input[type=email],input[type=password]{width:100%;box-sizing:border-box;
          height:48px;border:1.5px solid #111;border-radius:4px;padding:0 12px;font-size:16px}.p{display:flex;gap:10px;align-items:center;border:1.5px solid #e5e5e5;
          border-radius:4px;padding:10px;margin:6px 0}button{height:48px;border-radius:4px;font-size:16px;width:100%;margin-top:10px;border:1.5px solid #111}
          .ok{background:#111;color:#fff}.non{background:#fff;color:#111}.err{color:#b42318}small{color:#666}`)}
        </style>
      </head>
      <body>
        <h1>${titre}</h1>
        ${corps}
      </body>
    </html>`;
}

function consent(nomClient: string, q: z.infer<typeof AuthorizeQuery>, demandes: string[], erreur: string | null) {
  return page(
    'Autoriser l’accès',
    html`<p><strong>${nomClient}</strong> demande à accéder à ton compte Cresco.</p>
      ${erreur ? html`<p class="err">${erreur}</p>` : ''}
      <form method="post" action="/oauth/authorize">
        ${Object.entries(q).map(([k, v]) => (v == null ? '' : html`<input type="hidden" name="${k}" value="${v}" />`))}
        <input type="hidden" name="demandes" value="${demandes.join(' ')}" />
        <label>Adresse e-mail<input type="email" name="email" autocomplete="email" required /></label>
        <label>Mot de passe<input type="password" name="motDePasse" autocomplete="current-password" required /></label>
        <p><strong>Permissions</strong> <small>(décoche ce que tu ne veux pas donner)</small></p>
        ${demandes.map(
          (s) =>
            html`<label class="p"><input type="checkbox" name="accorde" value="${s}" ${SENSIBLES.has(s) ? '' : 'checked'} />${LIBELLES[s] ?? s}</label>`,
        )}
        <button class="ok" type="submit">Autoriser</button>
        <button class="non" type="submit" name="refuser" value="1" formnovalidate>Refuser</button>
      </form>
      <p><small>Tu pourras retirer cet accès à tout moment dans Profil.</small></p>`,
  );
}
