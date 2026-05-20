import { Database } from 'bun:sqlite'
import { createHash, randomBytes } from 'crypto'

// --- Types ---

export type Severity = 'info' | 'warn' | 'error' | 'critical'

export interface Publisher {
  name: string
  token_hash: string
  created_at: string
  revoked_at: string | null
}

export interface Alert {
  id: number
  publisher: string
  severity: Severity
  source: string
  title: string
  body: string
  target: string | null
  related_bead: string | null
  dedup_key: string | null
  reply_via: string | null
  created_at: string
  delivered_at: string | null
  suppressed_at: string | null
  ack_by: string | null
  ack_at: string | null
  ack_note: string | null
}

export interface Silence {
  dedup_key: string
  until_ts: string
  set_by: string
  created_at: string
}

// --- Token helpers ---

/** Constant-time-ish SHA-256; we use HMAC-free hashing because tokens are
 *  high-entropy random bytes (256 bits) generated server-side. */
export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex')
}

export function generateToken(): string {
  return randomBytes(32).toString('base64url')
}

// --- Schema ---

export function initDb(db: Database): void {
  db.exec('PRAGMA journal_mode=WAL')
  db.exec('PRAGMA foreign_keys=ON')

  db.exec(`
    CREATE TABLE IF NOT EXISTS publishers (
      name        TEXT PRIMARY KEY,
      token_hash  TEXT NOT NULL,
      created_at  TEXT NOT NULL,
      revoked_at  TEXT
    )
  `)

  db.exec(`
    CREATE TABLE IF NOT EXISTS alerts (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      publisher     TEXT NOT NULL,
      severity      TEXT NOT NULL
                     CHECK (severity IN ('info','warn','error','critical')),
      source        TEXT NOT NULL,
      title         TEXT NOT NULL,
      body          TEXT NOT NULL,
      target        TEXT,
      related_bead  TEXT,
      dedup_key     TEXT,
      reply_via     TEXT,
      created_at    TEXT NOT NULL,
      delivered_at  TEXT,
      suppressed_at TEXT,
      ack_by        TEXT,
      ack_at        TEXT,
      ack_note      TEXT
    )
  `)

  db.exec(`
    CREATE INDEX IF NOT EXISTS idx_alerts_undelivered
      ON alerts(id)
      WHERE delivered_at IS NULL AND suppressed_at IS NULL
  `)

  db.exec(`
    CREATE INDEX IF NOT EXISTS idx_alerts_dedup
      ON alerts(dedup_key)
      WHERE dedup_key IS NOT NULL
  `)

  db.exec(`
    CREATE TABLE IF NOT EXISTS silences (
      dedup_key  TEXT PRIMARY KEY,
      until_ts   TEXT NOT NULL,
      set_by     TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  `)
}

// --- Publishers ---

export function upsertPublisher(db: Database, name: string, token: string): void {
  const hash = hashToken(token)
  const now = new Date().toISOString()
  db.run(
    `INSERT INTO publishers (name, token_hash, created_at, revoked_at)
     VALUES (?, ?, ?, NULL)
     ON CONFLICT(name) DO UPDATE SET token_hash = excluded.token_hash, revoked_at = NULL`,
    [name, hash, now],
  )
}

export function revokePublisher(db: Database, name: string): boolean {
  const result = db.run(
    `UPDATE publishers SET revoked_at = ?
     WHERE name = ? AND revoked_at IS NULL`,
    [new Date().toISOString(), name],
  )
  return result.changes > 0
}

export function verifyPublisher(db: Database, name: string, token: string): boolean {
  const row = db
    .query('SELECT token_hash, revoked_at FROM publishers WHERE name = ?')
    .get(name) as { token_hash: string; revoked_at: string | null } | null
  if (!row || row.revoked_at) return false
  return row.token_hash === hashToken(token)
}

export function listPublishers(db: Database): Publisher[] {
  return db.query('SELECT * FROM publishers ORDER BY name').all() as Publisher[]
}

// --- Alerts ---

export interface InsertAlertArgs {
  publisher: string
  severity: Severity
  source: string
  title: string
  body: string
  target?: string | null
  related_bead?: string | null
  dedup_key?: string | null
  reply_via?: string | null
}

export interface InsertAlertResult {
  id: number
  suppressed: boolean
  silence_until: string | null
}

/** Insert an alert. If `dedup_key` matches an active silence, the row is
 *  inserted with `suppressed_at` set and `suppressed: true` is returned so
 *  the caller knows not to fan it out for delivery. */
export function insertAlert(db: Database, args: InsertAlertArgs): InsertAlertResult {
  const now = new Date().toISOString()
  let suppressed = false
  let silenceUntil: string | null = null

  if (args.dedup_key) {
    silenceUntil = getActiveSilence(db, args.dedup_key)
    if (silenceUntil) suppressed = true
  }

  const result = db.run(
    `INSERT INTO alerts
       (publisher, severity, source, title, body, target, related_bead,
        dedup_key, reply_via, created_at, suppressed_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      args.publisher,
      args.severity,
      args.source,
      args.title,
      args.body,
      args.target ?? null,
      args.related_bead ?? null,
      args.dedup_key ?? null,
      args.reply_via ?? null,
      now,
      suppressed ? now : null,
    ],
  )
  return { id: Number(result.lastInsertRowid), suppressed, silence_until: silenceUntil }
}

export function getUndeliveredAlerts(db: Database): Alert[] {
  return db
    .query(
      `SELECT * FROM alerts
       WHERE delivered_at IS NULL AND suppressed_at IS NULL
       ORDER BY id`,
    )
    .all() as Alert[]
}

export function markAlertDelivered(db: Database, id: number): void {
  db.run('UPDATE alerts SET delivered_at = ? WHERE id = ?', [new Date().toISOString(), id])
}

export function getAlert(db: Database, id: number): Alert | null {
  return (db.query('SELECT * FROM alerts WHERE id = ?').get(id) as Alert) || null
}

export interface HistoryFilter {
  publisher?: string
  source?: string
  severity?: Severity
  since?: string
  limit?: number
}

export function getAlertHistory(db: Database, filter: HistoryFilter = {}): Alert[] {
  const conds: string[] = []
  const params: unknown[] = []
  if (filter.publisher) {
    conds.push('publisher = ?')
    params.push(filter.publisher)
  }
  if (filter.source) {
    conds.push('source LIKE ?')
    params.push(filter.source.includes('%') ? filter.source : filter.source + '%')
  }
  if (filter.severity) {
    conds.push('severity = ?')
    params.push(filter.severity)
  }
  if (filter.since) {
    conds.push('created_at >= ?')
    params.push(filter.since)
  }
  const where = conds.length ? 'WHERE ' + conds.join(' AND ') : ''
  const limit = Math.max(1, Math.min(500, filter.limit ?? 50))
  return db
    .query(`SELECT * FROM alerts ${where} ORDER BY id DESC LIMIT ?`)
    .all(...params, limit) as Alert[]
}

export function ackAlert(db: Database, id: number, by: string, note: string | null): boolean {
  const result = db.run(
    `UPDATE alerts SET ack_by = ?, ack_at = ?, ack_note = ?
     WHERE id = ? AND ack_at IS NULL`,
    [by, new Date().toISOString(), note ?? null, id],
  )
  return result.changes > 0
}

// --- Silences ---

export function setSilence(
  db: Database,
  dedup_key: string,
  until_ts: string,
  set_by: string,
): void {
  const now = new Date().toISOString()
  db.run(
    `INSERT INTO silences (dedup_key, until_ts, set_by, created_at)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(dedup_key) DO UPDATE SET until_ts = excluded.until_ts,
       set_by = excluded.set_by, created_at = excluded.created_at`,
    [dedup_key, until_ts, set_by, now],
  )
}

/** Returns until_ts of an active (not-yet-expired) silence for the key,
 *  or null if none. */
export function getActiveSilence(db: Database, dedup_key: string): string | null {
  const row = db
    .query('SELECT until_ts FROM silences WHERE dedup_key = ?')
    .get(dedup_key) as { until_ts: string } | null
  if (!row) return null
  return row.until_ts > new Date().toISOString() ? row.until_ts : null
}
