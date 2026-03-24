import { Database } from 'bun:sqlite'

export function initDb(db: Database): void {
  db.exec('PRAGMA journal_mode=WAL')
  db.exec('PRAGMA foreign_keys=ON')

  db.exec(`
    CREATE TABLE IF NOT EXISTS identities (
      name TEXT PRIMARY KEY,
      full_path TEXT NOT NULL UNIQUE,
      last_seen_at TEXT,
      registered_at TEXT NOT NULL
    )
  `)

  db.exec(`
    CREATE TABLE IF NOT EXISTS messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      from_id TEXT NOT NULL REFERENCES identities(name),
      to_id TEXT NOT NULL REFERENCES identities(name),
      body TEXT NOT NULL,
      metadata TEXT,
      created_at TEXT NOT NULL,
      delivered_at TEXT
    )
  `)

  db.exec(`
    CREATE INDEX IF NOT EXISTS idx_messages_to_undelivered
      ON messages(to_id, delivered_at)
      WHERE delivered_at IS NULL
  `)
}

export interface Identity {
  name: string
  full_path: string
  last_seen_at: string
  registered_at: string
}

export function registerIdentity(db: Database, name: string, fullPath: string): void {
  const existing = db.query('SELECT full_path FROM identities WHERE name = ?').get(name) as { full_path: string } | null

  if (existing && existing.full_path !== fullPath) {
    throw new Error(
      `Identity collision: "${name}" is already registered to ${existing.full_path} (you are ${fullPath})`
    )
  }

  const now = new Date().toISOString()
  db.run(
    `INSERT INTO identities (name, full_path, last_seen_at, registered_at)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(name) DO UPDATE SET last_seen_at = ?`,
    [name, fullPath, now, now, now]
  )
}

export function listIdentities(db: Database): Identity[] {
  return db.query('SELECT * FROM identities ORDER BY name').all() as Identity[]
}

export function updateLastSeen(db: Database, name: string): void {
  db.run('UPDATE identities SET last_seen_at = ? WHERE name = ?', [new Date().toISOString(), name])
}

export function pruneStaleIdentities(db: Database): void {
  const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()
  db.run('DELETE FROM identities WHERE last_seen_at < ?', [cutoff])
}
