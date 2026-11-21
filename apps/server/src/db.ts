import { createHash } from 'node:crypto';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import pg from 'pg';

export type Db = pg.Pool;
export type Tx = pg.PoolClient;

// numeric et bigint en nombres ; dates en chaînes ISO.
pg.types.setTypeParser(20, (v) => Number(v));
pg.types.setTypeParser(1700, (v) => Number(v));
pg.types.setTypeParser(1082, (v) => v);

export function createPool(connectionString: string, max = 10): Db {
  return new pg.Pool({ connectionString, max, idleTimeoutMillis: 30_000 });
}

/** Exécute `work` dans une transaction au nom de `userId` : la RLS limite tout à ses lignes. */
export async function asUser<T>(db: Db, userId: string, work: (tx: Tx) => Promise<T>): Promise<T> {
  const tx = await db.connect();
  try {
    await tx.query('begin');
    await tx.query(`select set_config('cresco.user_id', $1, true)`, [userId]);
    const result = await work(tx);
    await tx.query('commit');
    return result;
  } catch (error) {
    await tx.query('rollback').catch(() => undefined);
    throw error;
  } finally {
    tx.release();
  }
}

/**
 * Applique les migrations SQL manquantes, chacune dans sa transaction, sous verrou consultatif.
 * Une migration appliquée puis modifiée bloque tout (migrations additives seulement).
 * À lancer avec le rôle propriétaire ; `appPassword` donne LOGIN au rôle cresco_app.
 */
export async function migrate(owner: Db, options: { directory: string; appPassword?: string; log?: (l: string) => void }) {
  const log = options.log ?? (() => undefined);
  const client = await owner.connect();
  const applied: string[] = [];
  try {
    await client.query('select pg_advisory_lock(727101)');
    await client.query(`create table if not exists schema_migration (
      name text primary key, checksum text not null, applied_at timestamptz not null default now())`);
    const { rows } = await client.query<{ name: string; checksum: string }>('select name, checksum from schema_migration');
    const done = new Map(rows.map((r) => [r.name, r.checksum]));
    const files = readdirSync(options.directory).filter((f) => /^\d{4}_.+\.sql$/u.test(f)).sort();
    for (const file of files) {
      const sql = readFileSync(path.join(options.directory, file), 'utf8');
      const checksum = createHash('sha256').update(sql.replace(/\r\n/gu, '\n')).digest('hex');
      const previous = done.get(file);
      if (previous) {
        if (previous !== checksum) throw new Error(`La migration ${file} a été modifiée après application.`);
        continue;
      }
      await client.query('begin');
      try {
        await client.query(sql);
        await client.query('insert into schema_migration (name, checksum) values ($1, $2)', [file, checksum]);
        await client.query('commit');
      } catch (error) {
        await client.query('rollback');
        throw new Error(`Échec de la migration ${file} : ${(error as Error).message}`);
      }
      applied.push(file);
      log(`appliquée ${file}`);
    }
    if (options.appPassword) {
      await client.query(`alter role cresco_app with login password ${client.escapeLiteral(options.appPassword)}`);
    }
  } finally {
    await client.query('select pg_advisory_unlock(727101)').catch(() => undefined);
    client.release();
  }
  return applied;
}
