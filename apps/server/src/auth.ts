import { createHash, randomBytes, scrypt as scryptCb, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import type { Db } from './db.ts';

const scrypt = promisify(scryptCb) as (pwd: string, salt: Buffer, len: number) => Promise<Buffer>;

/** Permissions (docs/architecture/API_MCP.md). `foi:*` et `jeune:*` jamais accordés par défaut aux tiers. */
export const SCOPES = [
  'entrainement:lecture', 'entrainement:ecriture',
  'nutrition:lecture', 'nutrition:ecriture',
  'sommeil:lecture', 'sommeil:ecriture',
  'jeune:lecture', 'jeune:ecriture',
  'corps:lecture', 'corps:ecriture',
  'foi:lecture', 'foi:ecriture',
  'export',
] as const;
export type Scope = (typeof SCOPES)[number];

export interface Principal {
  userId: string;
  jetonId: string;
  scopes: ReadonlySet<string>;
}

export async function hashPassword(password: string) {
  const salt = randomBytes(16);
  const hash = await scrypt(password, salt, 64);
  return `scrypt$${salt.toString('base64')}$${hash.toString('base64')}`;
}

export async function verifyPassword(password: string, stored: string) {
  const [, saltB64, hashB64] = stored.split('$');
  if (!saltB64 || !hashB64) return false;
  const expected = Buffer.from(hashB64, 'base64');
  const actual = await scrypt(password, Buffer.from(saltB64, 'base64'), expected.length);
  return timingSafeEqual(expected, actual);
}

const empreinte = (token: string) => createHash('sha256').update(token).digest('hex');

/** Crée un jeton ; la valeur n'est renvoyée qu'une fois et seule son empreinte est stockée. */
export async function createToken(db: Db, userId: string, nom: string, scopes: readonly string[]) {
  const valides = scopes.filter((s) => (SCOPES as readonly string[]).includes(s));
  const token = `cr_${randomBytes(32).toString('base64url')}`;
  const { rows } = await db.query<{ id: string }>(
    'insert into jeton (utilisateur_id, empreinte, nom, scopes) values ($1, $2, $3, $4) returning id',
    [userId, empreinte(token), nom, valides],
  );
  return { id: rows[0]!.id, token, scopes: valides };
}

export async function resolveToken(db: Db, header: string | undefined): Promise<Principal | null> {
  const token = header?.match(/^Bearer\s+(cr_[A-Za-z0-9_-]+)$/u)?.[1];
  if (!token) return null;
  const { rows } = await db.query<{ id: string; utilisateur_id: string; scopes: string[] }>(
    `update jeton set dernier_usage = now() where empreinte = $1 and revoque_le is null
     returning id, utilisateur_id, scopes`,
    [empreinte(token)],
  );
  const row = rows[0];
  return row ? { userId: row.utilisateur_id, jetonId: row.id, scopes: new Set(row.scopes) } : null;
}

/** Limite simple des tentatives de connexion (mémoire du processus). */
const tentatives = new Map<string, { n: number; jusqua: number }>();
export function limiteConnexion(cle: string) {
  const now = Date.now();
  const t = tentatives.get(cle);
  if (!t || t.jusqua < now) {
    tentatives.set(cle, { n: 1, jusqua: now + 15 * 60_000 });
    return true;
  }
  t.n += 1;
  return t.n <= 10;
}
