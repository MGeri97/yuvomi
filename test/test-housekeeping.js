/**
 * Modul: Housekeeping-Test
 * Zweck: Validiert Housekeeping-Schema, API-Abfragen und Constraints
 * Ausführen: node --experimental-sqlite test/test-housekeeping.js
 */

import assert from 'node:assert/strict';
import test from 'node:test';
import Database from 'better-sqlite3';
import { MIGRATIONS, _setTestDatabase, _resetTestDatabase } from '../server/db.js';

// In-Memory-DB mit allen Migrationen aufbauen
function buildTestDb() {
  const db = new Database(':memory:');
  db.pragma('foreign_keys = ON');
  db.exec(`CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY,
    description TEXT NOT NULL,
    applied_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
  )`);
  for (const m of MIGRATIONS) {
    if (typeof m.up === 'function') {
      m.up(db);
    } else {
      db.exec(m.up);
    }
    if (typeof m.afterUp === 'function') m.afterUp(db);
    db.prepare('INSERT INTO schema_migrations (version, description) VALUES (?, ?)').run(m.version, m.description);
  }
  return db;
}

const db = buildTestDb();
_setTestDatabase(db);

// Seed a test user for created_by references
db.prepare(`
  INSERT INTO users (username, display_name, password_hash, role)
  VALUES ('testuser', 'Test User', '$2b$12$test', 'member')
`).run();

test('housekeeping smoke: workers table exists', () => {
  const row = db.prepare(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='housekeeping_workers'"
  ).get();
  assert.equal(row?.name, 'housekeeping_workers');
});

test('housekeeping smoke: decay tasks table exists', () => {
  const row = db.prepare(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='housekeeping_decay_tasks'"
  ).get();
  assert.equal(row?.name, 'housekeeping_decay_tasks');
});

test('decay task: PATCH last_completed=null clears completion (undo)', () => {
  // 1) Task anlegen
  const created = db.prepare(`
    INSERT INTO housekeeping_decay_tasks (name, area, frequency_days, last_completed, created_by)
    VALUES ('Mop', 'Kitchen', 7, '2026-06-01T10:00:00Z', 1)
  `).run();
  const id = created.lastInsertRowid;
  // 2) Simuliere PATCH-Handler-Effekt: last_completed -> null
  db.prepare('UPDATE housekeeping_decay_tasks SET last_completed = ? WHERE id = ?').run(null, id);
  const row = db.prepare('SELECT last_completed FROM housekeeping_decay_tasks WHERE id = ?').get(id);
  assert.equal(row.last_completed, null);
});

test('GET /visits/:id: found returns visit with fields', async () => {
  // visit exists (created_by → user id=1, worker needed)
  const wId = db.prepare(`INSERT INTO housekeeping_workers (user_id, daily_rate) VALUES (1, 80)`).run().lastInsertRowid;
  const vRow = db.prepare(`
    INSERT INTO housekeeping_work_sessions (worker_id, check_in, daily_rate, extras, created_by)
    VALUES (?, '2026-06-01T09:00:00Z', 80, 10, 1)
  `).run(wId);
  const vId = vRow.lastInsertRowid;
  const row = db.prepare(`
    SELECT hws.*, u.display_name AS worker_name
    FROM housekeeping_work_sessions hws
    LEFT JOIN housekeeping_workers hw ON hw.id = hws.worker_id
    LEFT JOIN users u ON u.id = hw.user_id
    WHERE hws.id = ?
  `).get(vId);
  assert.ok(row);
  assert.equal(Number(row.daily_rate), 80);
  assert.ok(row.worker_name);
});

test('GET /visits/:id: unknown id returns null row', () => {
  const row = db.prepare('SELECT * FROM housekeeping_work_sessions WHERE id = 99999').get();
  assert.equal(row, undefined);
});

test('staff separation: hidden from task assignees but birthday stays visible', () => {
  // Staff-User + Worker + birthdays-Zeile anlegen
  const staff = db.prepare(`
    INSERT INTO users (username, display_name, password_hash, role, family_role)
    VALUES ('hk1','HK One','x','member','other')
  `).run().lastInsertRowid;
  db.prepare(`INSERT INTO housekeeping_workers (user_id, daily_rate) VALUES (?, 0)`).run(staff);
  db.prepare(`INSERT INTO birthdays (name, birth_date, created_by, family_user_id) VALUES ('HK One','1990-04-01',1,?)`).run(staff);

  // Normalen Familien-User anlegen
  const fam = db.prepare(`
    INSERT INTO users (username, display_name, password_hash, role, family_role)
    VALUES ('mom','Mom','x','member','mom')
  `).run().lastInsertRowid;

  // Task-Zuweisungsliste (NOT EXISTS Filter)
  const assignees = db.prepare(`
    SELECT id FROM users u
    WHERE NOT EXISTS (SELECT 1 FROM housekeeping_workers hw WHERE hw.user_id = u.id)
  `).all().map((r) => r.id);
  assert.ok(!assignees.includes(Number(staff)), 'staff should not be in assignees');
  assert.ok(assignees.includes(Number(fam)), 'family member should be in assignees');

  // Geburtstag bleibt (birthdays-Query unverändert)
  const bd = db.prepare('SELECT 1 FROM birthdays WHERE family_user_id = ?').get(staff);
  assert.ok(bd, 'staff birthday should remain visible');
});

test('staff login: blocked for housekeeping worker accounts', () => {
  // Staff-User anlegen (separater Username, damit kein Konflikt mit anderen Tests)
  const staffId = db.prepare(`
    INSERT INTO users (username, display_name, password_hash, role)
    VALUES ('hk_login_test','HK Login','$2b$12$test','member')
  `).run().lastInsertRowid;
  db.prepare(`INSERT INTO housekeeping_workers (user_id, daily_rate) VALUES (?, 0)`).run(staffId);

  // Simuliere den Guard: prüfe ob housekeeping_worker-Zeile existiert
  const isStaff = db.prepare('SELECT 1 FROM housekeeping_workers WHERE user_id = ?').get(staffId);
  assert.ok(isStaff, 'staff should be detectable by worker row');

  // Normaler User ist KEIN Staff
  const normalId = db.prepare(`
    INSERT INTO users (username, display_name, password_hash, role)
    VALUES ('normal_login_test','Normal User','$2b$12$test','member')
  `).run().lastInsertRowid;
  const notStaff = db.prepare('SELECT 1 FROM housekeeping_workers WHERE user_id = ?').get(normalId);
  assert.equal(notStaff, undefined, 'regular user should not be staff');
});
