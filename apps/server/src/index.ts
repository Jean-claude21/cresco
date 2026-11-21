import { serve } from '@hono/node-server';
import path from 'node:path';
import { createApp } from './app.ts';
import { createPool, migrate } from './db.ts';
import { chargerSources } from './sources.ts';

const racine = process.env.APP_ROOT ?? process.cwd();
const url = process.env.DATABASE_URL;
if (!url) throw new Error('DATABASE_URL manquant');

// Migrations au démarrage avec le rôle propriétaire (comme struo), sauf MIGRATE_ON_START=false.
const ownerUrl = process.env.DATABASE_OWNER_URL;
if (ownerUrl && process.env.MIGRATE_ON_START !== 'false') {
  const owner = createPool(ownerUrl, 1);
  try {
    const applied = await migrate(owner, {
      directory: process.env.MIGRATIONS_DIR ?? path.join(racine, 'apps/server/db/migrations'),
      ...(process.env.APP_DB_PASSWORD ? { appPassword: process.env.APP_DB_PASSWORD } : {}),
      log: (l) => console.info(`[migrate] ${l}`),
    });
    console.info(`[migrate] ${applied.length} migration(s) appliquée(s)`);
  } finally {
    await owner.end();
  }
}

const db = createPool(url);
const app = createApp({ db, sources: chargerSources(racine), version: process.env.APP_VERSION ?? 'dev' });
const port = Number(process.env.PORT ?? 3000);
serve({ fetch: app.fetch, port }, () => console.info(`Cresco écoute sur :${port}`));
