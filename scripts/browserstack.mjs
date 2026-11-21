#!/usr/bin/env node
// Lance le parcours d'intégration Flutter (apps/cresco_app/integration_test) sur de vrais téléphones
// Android BrowserStack App Automate, attend la fin et affiche le résultat par appareil.
//   node scripts/browserstack.mjs [--devices "Samsung Galaxy S23-13.0,Google Pixel 8-14.0"]
// Prérequis : APK construits (voir docs/ETAT.md) :
//   flutter build apk --debug ; cd android ; gradlew app:assembleAndroidTest ;
//   gradlew app:assembleDebug -Ptarget=integration_test/parcours_test.dart
// Clés lues hors du dépôt (jamais affichées) : CRESCO_ADMIN_SECRETS (défaut ../.secrets/.admin.env),
// BROWSERSTACK_USERNAME et BROWSERSTACK_ACCESS_KEY. Résumé écrit dans .local/browserstack.json.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const { values: args } = parseArgs({
  options: {
    devices: { type: 'string', default: 'Samsung Galaxy S23-13.0,Google Pixel 8-14.0,Samsung Galaxy S25-15.0,Motorola Moto G71 5G-11.0' },
    // Réutiliser des fichiers déjà téléversés (bs://…) au lieu de renvoyer les APK.
    app: { type: 'string' },
    'test-suite': { type: 'string' },
    'timeout-min': { type: 'string', default: '30' },
  },
});
const ADMIN = process.env.CRESCO_ADMIN_SECRETS ?? path.resolve(ROOT, '../.secrets/.admin.env');
const env = Object.fromEntries(
  readFileSync(ADMIN, 'utf8')
    .split(/\r?\n/u)
    .filter((l) => /^[A-Z][A-Z0-9_]*=/u.test(l))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).trim().replace(/^(["'])(.*)\1$/su, '$2')]),
);
for (const k of ['BROWSERSTACK_USERNAME', 'BROWSERSTACK_ACCESS_KEY']) if (!env[k]) throw new Error(`${k} est vide dans ${ADMIN}`);
const auth = `Basic ${Buffer.from(`${env.BROWSERSTACK_USERNAME}:${env.BROWSERSTACK_ACCESS_KEY}`).toString('base64')}`;
const BASE = 'https://api-cloud.browserstack.com/app-automate/flutter-integration-tests/v2/android';

async function api(route, init = {}) {
  const res = await fetch(`${BASE}${route}`, { ...init, headers: { Authorization: auth, ...(init.headers ?? {}) } });
  const text = await res.text();
  if (!res.ok) throw new Error(`${init.method ?? 'GET'} ${route} : HTTP ${res.status} ${text.slice(0, 400)}`);
  return text ? JSON.parse(text) : {};
}
async function televerser(route, fichier) {
  if (!existsSync(fichier)) throw new Error(`APK manquant : ${fichier}`);
  const form = new FormData();
  form.append('file', new Blob([readFileSync(fichier)]), path.basename(fichier));
  return api(route, { method: 'POST', body: form });
}

const apk = path.join(ROOT, 'apps/cresco_app/build/app/outputs/apk/debug/app-debug.apk');
const apkTest = path.join(ROOT, 'apps/cresco_app/build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk');
const app = args.app ?? (await televerser('/app', apk)).app_url;
console.log(`App téléversée (${app})`);
const testSuite = args['test-suite'] ?? (await televerser('/test-suite', apkTest)).test_suite_url;
console.log(`Tests téléversés (${testSuite})`);

const devices = args.devices.split(',').map((d) => d.trim()).filter(Boolean);
const { build_id: buildId } = await api('/build', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    app,
    testSuite,
    devices,
    project: 'Cresco',
    buildTag: new Date().toISOString().slice(0, 16),
    deviceLogs: true,
    networkLogs: true,
    video: true,
  }),
});
console.log(`Build lancé : ${buildId} sur ${devices.join(' · ')}`);
console.log(`Tableau de bord : https://app-automate.browserstack.com/dashboard/v2/builds/${buildId}`);

const fin = Date.now() + Number(args['timeout-min']) * 60_000;
let build;
for (;;) {
  build = await api(`/builds/${buildId}`);
  if (!['queued', 'running'].includes(build.status)) break;
  if (Date.now() > fin) throw new Error(`Toujours en cours après ${args['timeout-min']} min (statut ${build.status})`);
  await new Promise((r) => setTimeout(r, 20_000));
  process.stdout.write('.');
}
console.log(`\nStatut du build : ${build.status}`);

const resume = { buildId, status: build.status, appareils: [] };
for (const d of build.devices ?? []) {
  for (const s of d.sessions ?? []) {
    const detail = await api(`/builds/${buildId}/sessions/${s.id}`).catch(() => null);
    const cas = (detail?.testcases?.data ?? []).flatMap((g) => g.testcases ?? []);
    console.log(`\n${d.device} (Android ${d.os_version}) : ${s.status}`);
    const echecs = [];
    for (const c of cas) {
      console.log(`  ${c.status === 'passed' ? '✔' : '✘'} ${c.name ?? c.method_name ?? ''} ${c.duration ? `(${c.duration} s)` : ''}`);
      if (c.status === 'passed') continue;
      // Extrait de l'erreur Flutter tiré du journal d'instrumentation de l'appareil.
      let extrait = null;
      if (c.instrumentation_log) {
        const journal = await fetch(c.instrumentation_log, { headers: { Authorization: auth } }).then((r) => r.text()).catch(() => '');
        const i = journal.search(/The following .* was thrown/u);
        extrait = i >= 0 ? journal.slice(i, i + 900).split('\n\tat ')[0].trim() : null;
        if (extrait) console.log(`    ${extrait.split('\n').slice(0, 8).join('\n    ')}`);
      }
      echecs.push({ nom: c.name, statut: c.status, extrait, video: c.video ?? null });
    }
    resume.appareils.push({ appareil: d.device, os: d.os_version, statut: s.status, session: s.id, echecs });
  }
}
mkdirSync(path.join(ROOT, '.local'), { recursive: true });
writeFileSync(path.join(ROOT, '.local/browserstack.json'), JSON.stringify(resume, null, 2));
console.log('\nRésumé : .local/browserstack.json');
process.exit(build.status === 'passed' ? 0 : 1);
