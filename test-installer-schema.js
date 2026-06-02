import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { ENV_SCHEMA } from './tools/installer/env-schema.js';

const ORIGINAL_KEYS = [
  'SESSION_SECRET', 'DB_ENCRYPTION_KEY', 'OPENWEATHER_API_KEY',
  'OPENWEATHER_CITY', 'OPENWEATHER_UNITS', 'OPENWEATHER_LANG',
  'GOOGLE_CLIENT_ID', 'GOOGLE_CLIENT_SECRET', 'GOOGLE_REDIRECT_URI',
  'APPLE_USERNAME', 'APPLE_APP_SPECIFIC_PASSWORD', 'SYNC_INTERVAL_MINUTES',
];

test('ENV_SCHEMA enthält alle 12 Original-Keys plus TZ und OIKOS_HTTP_PORT (14 gesamt)', () => {
  assert.equal(ENV_SCHEMA.length, 14);
  const keys = ENV_SCHEMA.map(e => e.key);
  for (const k of ORIGINAL_KEYS) {
    assert.ok(keys.includes(k), `Key fehlt: ${k}`);
  }
  assert.ok(keys.includes('TZ'), 'Key fehlt: TZ');
  assert.ok(keys.includes('OIKOS_HTTP_PORT'), 'Key fehlt: OIKOS_HTTP_PORT');
});

test('TZ und OIKOS_HTTP_PORT haben writeToEnv: true', () => {
  for (const key of ['TZ', 'OIKOS_HTTP_PORT']) {
    const entry = ENV_SCHEMA.find(e => e.key === key);
    assert.ok(entry, `${key} nicht in ENV_SCHEMA`);
    assert.equal(entry.writeToEnv, true, `${key}.writeToEnv ist nicht true`);
  }
});

test('Alle Schema-Einträge haben die Pflichtfelder key, type, label, group, writeToEnv', () => {
  for (const entry of ENV_SCHEMA) {
    assert.ok(typeof entry.key === 'string' && entry.key, `key fehlt oder leer`);
    assert.ok(typeof entry.type === 'string' && entry.type, `type fehlt für ${entry.key}`);
    assert.ok(typeof entry.label === 'string' && entry.label, `label fehlt für ${entry.key}`);
    assert.ok(typeof entry.group === 'string' && entry.group, `group fehlt für ${entry.key}`);
    assert.equal(entry.writeToEnv, true, `writeToEnv !== true für ${entry.key}`);
  }
});

test('Schema-Datei enthält genau 14 key-Felder (grep-Parität)', () => {
  const src = readFileSync(new URL('./tools/installer/env-schema.js', import.meta.url), 'utf8');
  const matches = src.match(/\bkey:/g);
  assert.equal(matches?.length ?? 0, 14, 'Anzahl "key:"-Vorkommen in env-schema.js stimmt nicht mit 14 überein');
});

test('/api/defaults-Route in install-server.js liefert ENV_SCHEMA (Snapshot)', () => {
  const src = readFileSync(new URL('./tools/installer/install-server.js', import.meta.url), 'utf8');
  assert.ok(src.includes("import { ENV_SCHEMA }"), 'install-server.js importiert ENV_SCHEMA nicht');
  assert.ok(src.includes('catalog: ENV_SCHEMA'), '/api/defaults gibt ENV_SCHEMA nicht unter dem Schlüssel "catalog" zurück');
});

// ── Phase 1: Zeitzone und Port wirken ───────────────────────────────────────

test('install.html nimmt TZ und OIKOS_HTTP_PORT ins gesendete env-Objekt auf', () => {
  const src = readFileSync(new URL('./tools/installer/install.html', import.meta.url), 'utf8');
  assert.match(src, /TZ:\s*S\.tz/, 'install.html sendet TZ nicht im env-Objekt');
  assert.match(src, /OIKOS_HTTP_PORT:\s*S\.port/, 'install.html sendet OIKOS_HTTP_PORT nicht im env-Objekt');
});

test('docker-compose.yml mappt den Host-Port über OIKOS_HTTP_PORT mit Default 3000', () => {
  const src = readFileSync(new URL('./docker-compose.yml', import.meta.url), 'utf8');
  assert.match(
    src,
    /\$\{OIKOS_HTTP_PORT:-3000\}:3000/,
    'Port-Mapping nutzt OIKOS_HTTP_PORT nicht mit Default :-3000 (Container-Port muss 3000 bleiben)'
  );
  assert.doesNotMatch(
    src,
    /^\s*-\s*"0\.0\.0\.0:3000:3000"/m,
    'Hartkodiertes Port-Mapping 3000:3000 darf nicht mehr vorhanden sein'
  );
});

test('install.sh schreibt TZ und OIKOS_HTTP_PORT in die generierte .env', () => {
  const src = readFileSync(new URL('./install.sh', import.meta.url), 'utf8');
  assert.match(src, /^TZ=\$\{OIKOS_TZ\}/m, 'install.sh schreibt TZ=${OIKOS_TZ} nicht in den .env-Block');
  assert.match(src, /^OIKOS_HTTP_PORT=\$\{OIKOS_PORT\}/m, 'install.sh schreibt OIKOS_HTTP_PORT=${OIKOS_PORT} nicht in den .env-Block');
});

test('.env.example dokumentiert OIKOS_HTTP_PORT', () => {
  const src = readFileSync(new URL('./.env.example', import.meta.url), 'utf8');
  assert.match(src, /OIKOS_HTTP_PORT/, '.env.example dokumentiert OIKOS_HTTP_PORT nicht');
});
