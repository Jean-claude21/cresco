#!/usr/bin/env node
// Provisionne et déploie un environnement de Cresco (modèle : struo/scripts/deploy.mjs) :
// projet et branche Neon, rôle applicatif, secrets générés, projet et application Coolify construite
// depuis le dépôt GitHub public (Dockerfile), variables, redémarrage, santé.
//   node scripts/deploy.mjs --env staging      (branche Neon dev,  branche git main)
//   node scripts/deploy.mjs --env production   (branche Neon main, branche git main)
// Les secrets sont lus hors du dépôt et ne sont JAMAIS affichés :
//   CRESCO_ADMIN_SECRETS (défaut ../.secrets/.admin.env) : NEON_API_TOKEN, COOLIFY_URL, COOLIFY_API_TOKEN
//   CRESCO_SECRETS (défaut ../.secrets/cresco.env) : valeurs générées pour ce projet (écrites ici)
import { randomBytes } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const { values: args } = parseArgs({ options: { env: { type: 'string', default: 'staging' }, 'no-deploy': { type: 'boolean' } } });
const TARGETS = {
  staging: { branch: 'dev', git: 'main', app: 'cresco-staging', environment: 'staging' },
  production: { branch: 'main', git: 'main', app: 'cresco', environment: 'production' },
};
const target = TARGETS[args.env];
if (!target) throw new Error(`Environnement inconnu : ${args.env}`);
const ENV = args.env.toUpperCase();
const REPO = 'https://github.com/Jean-claude21/cresco';

const ADMIN = process.env.CRESCO_ADMIN_SECRETS ?? path.resolve(ROOT, '../.secrets/.admin.env');
const OWN = process.env.CRESCO_SECRETS ?? path.resolve(ROOT, '../.secrets/cresco.env');
const unquote = (v) => (/^(["']).*\1$/su.test(v) ? v.slice(1, -1) : v);
const readEnv = (file) =>
  existsSync(file)
    ? Object.fromEntries(
        readFileSync(file, 'utf8')
          .split(/\r?\n/u)
          .filter((l) => /^[A-Z][A-Z0-9_]*=/u.test(l))
          .map((l) => [l.slice(0, l.indexOf('=')), unquote(l.slice(l.indexOf('=') + 1).trim())]),
      )
    : {};
const admin = readEnv(ADMIN);
let own = readEnv(OWN);
const remember = (name, value) => {
  const text = existsSync(OWN) ? readFileSync(OWN, 'utf8') : '# Cresco — généré par scripts/deploy.mjs. Ne jamais versionner.\n';
  const pattern = new RegExp(`^${name}=.*$`, 'mu');
  writeFileSync(OWN, pattern.test(text) ? text.replace(pattern, `${name}=${value}`) : `${text.trimEnd()}\n${name}=${value}\n`);
  own = readEnv(OWN);
};
const secret = (name, make) => {
  if (!own[name]) {
    remember(name, make());
    console.log(`${name} : généré et conservé`);
  }
  return own[name];
};
for (const name of ['NEON_API_TOKEN', 'COOLIFY_URL', 'COOLIFY_API_TOKEN']) if (!admin[name]) throw new Error(`${name} est vide dans ${ADMIN}.`);

const client = (base, token) => async (route, init = {}) => {
  const res = await fetch(`${base}${route}`, { ...init, headers: { Authorization: `Bearer ${token}`, Accept: 'application/json', 'Content-Type': 'application/json' } });
  const text = await res.text();
  if (!res.ok) throw new Error(`${init.method ?? 'GET'} ${route} : HTTP ${res.status} ${text.slice(0, 300)}`);
  return text ? JSON.parse(text) : {};
};
const neon = client('https://console.neon.tech/api/v2', admin.NEON_API_TOKEN);
const coolify = client(`${admin.COOLIFY_URL.replace(/\/$/u, '')}/api/v1`, admin.COOLIFY_API_TOKEN);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------------------------------------------------------------- Neon (Francfort, PostgreSQL 17)
async function waitOperations(projectId) {
  for (let i = 0; i < 60; i += 1) {
    const { operations } = await neon(`/projects/${projectId}/operations?limit=10`);
    if (!operations.some((op) => ['running', 'scheduling'].includes(op.status))) return;
    await sleep(2000);
  }
}
let projectId = own.NEON_PROJECT_ID;
if (!projectId) {
  const { projects } = await neon('/projects?limit=100');
  projectId = projects.find((p) => p.name === 'cresco')?.id;
  if (!projectId) {
    const created = await neon('/projects', { method: 'POST', body: JSON.stringify({ project: { name: 'cresco', region_id: 'aws-eu-central-1', pg_version: 17 } }) });
    projectId = created.project.id;
    console.log('Neon : projet « cresco » créé (Francfort, PostgreSQL 17)');
  }
  remember('NEON_PROJECT_ID', projectId);
}
await waitOperations(projectId);
let { branches } = await neon(`/projects/${projectId}/branches`);
const main = branches.find((b) => b.default) ?? branches.find((b) => b.name === 'main');
if (!branches.some((b) => b.name === 'dev')) {
  await neon(`/projects/${projectId}/branches`, { method: 'POST', body: JSON.stringify({ branch: { name: 'dev', parent_id: main.id }, endpoints: [{ type: 'read_write' }] }) });
  console.log('Neon : branche « dev » créée');
  await waitOperations(projectId);
}
({ branches } = await neon(`/projects/${projectId}/branches`));
const branch = target.branch === 'main' ? main : branches.find((b) => b.name === target.branch);
const { roles } = await neon(`/projects/${projectId}/branches/${branch.id}/roles`);
const ownerRole = roles.find((r) => r.name !== 'cresco_app' && !r.protected)?.name ?? 'neondb_owner';
const { databases } = await neon(`/projects/${projectId}/branches/${branch.id}/databases`);
const database = databases[0]?.name ?? 'neondb';
const { uri: ownerUrl } = await neon(`/projects/${projectId}/connection_uri?branch_id=${branch.id}&database_name=${database}&role_name=${ownerRole}&pooled=false`);
const appPassword = secret(`APP_DB_PASSWORD_${ENV}`, () => randomBytes(24).toString('base64url'));
const appUrl = (() => {
  const url = new URL(ownerUrl);
  url.username = 'cresco_app';
  url.password = appPassword;
  return url.toString();
})();
console.log(`Neon : branche « ${branch.name} » prête`);

// ---------------------------------------------------------------- Coolify
const projects = await coolify('/projects');
let project = projects.find((p) => p.name === 'Cresco');
if (!project) {
  project = await coolify('/projects', { method: 'POST', body: JSON.stringify({ name: 'Cresco', description: 'Cresco - muscu, nutrition, sommeil, jeûne' }) });
  console.log('Coolify : projet « Cresco » créé');
}
const detail = await coolify(`/projects/${project.uuid}`);
if (!(detail.environments ?? []).some((e) => e.name === target.environment)) {
  await coolify(`/projects/${project.uuid}/environments`, { method: 'POST', body: JSON.stringify({ name: target.environment }) });
  console.log(`Coolify : environnement « ${target.environment} » créé`);
}
const servers = await coolify('/servers');
const server = servers.find((s) => s.uuid === own.COOLIFY_SERVER_UUID) ?? servers[0];
if (!server) throw new Error('Aucun serveur Coolify.');
const domain = (own[`DOMAIN_${ENV}`] || `https://${target.app}.${server.ip}.sslip.io`).replace(/\/$/u, '');
let application = (await coolify('/applications')).find((a) => a.name === target.app);
if (!application) {
  application = await coolify('/applications/public', {
    method: 'POST',
    body: JSON.stringify({
      project_uuid: project.uuid,
      server_uuid: server.uuid,
      environment_name: target.environment,
      name: target.app,
      description: `Cresco - ${args.env}`,
      git_repository: REPO,
      git_branch: target.git,
      build_pack: 'dockerfile',
      ports_exposes: '3000',
      domains: domain,
      health_check_enabled: true,
      health_check_path: '/api/health',
      health_check_port: '3000',
      instant_deploy: false,
    }),
  });
  console.log(`Coolify : application « ${target.app} » créée`);
} else {
  await coolify(`/applications/${application.uuid}`, { method: 'PATCH', body: JSON.stringify({ domains: domain, git_branch: target.git }) });
}
remember(`COOLIFY_APP_UUID_${ENV}`, application.uuid);
remember(`DOMAIN_${ENV}`, domain);

const variables = {
  APP_ENV: args.env,
  APP_BASE_URL: domain,
  DATABASE_URL: appUrl,
  DATABASE_OWNER_URL: ownerUrl,
  APP_DB_PASSWORD: appPassword,
};
await coolify(`/applications/${application.uuid}/envs/bulk`, {
  method: 'PATCH',
  body: JSON.stringify({ data: Object.entries(variables).map(([key, value]) => ({ key, value: String(value), is_preview: false, is_literal: true })) }),
});
console.log(`Coolify : ${Object.keys(variables).length} variables définies (${Object.keys(variables).join(', ')})`);

if (!args['no-deploy']) {
  const res = await coolify(`/deploy?uuid=${application.uuid}&force=false`, { method: 'POST' });
  const deployment = res?.deployments?.[0]?.deployment_uuid;
  console.log(`Coolify : déploiement demandé → ${domain}`);
  for (let i = 0; deployment && i < 90; i += 1) {
    await sleep(10_000);
    const state = await coolify(`/deployments/${deployment}`).catch(() => null);
    if (state?.status === 'finished') break;
    if (state?.status === 'failed' || state?.status === 'cancelled-by-user') {
      console.log(`Coolify : déploiement ${state.status}`);
      process.exit(1);
    }
  }
  for (let i = 0; i < 60; i += 1) {
    await sleep(10_000);
    try {
      const r = await fetch(`${domain}/api/health`);
      if (r.ok) {
        console.log(`En bonne santé : ${domain}/api/health`);
        process.exit(0);
      }
    } catch {
      /* pas encore prêt */
    }
  }
  console.log('Pas en bonne santé après 10 minutes : voir les journaux Coolify.');
  process.exit(1);
}
