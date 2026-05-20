import { describe, test, expect } from 'bun:test'
import { Database } from 'bun:sqlite'
import {
  initDb,
  upsertPublisher,
  revokePublisher,
  verifyPublisher,
  listPublishers,
  insertAlert,
  getUndeliveredAlerts,
  markAlertDelivered,
  getAlert,
  getAlertHistory,
  ackAlert,
  setSilence,
  getActiveSilence,
  hashToken,
  generateToken,
} from './db'

function freshDb(): Database {
  const db = new Database(':memory:')
  initDb(db)
  return db
}

describe('initDb', () => {
  test('creates publishers, alerts, silences tables', () => {
    const db = freshDb()
    const tables = db
      .query("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
      .all() as { name: string }[]
    const names = tables.map((t) => t.name)
    expect(names).toContain('publishers')
    expect(names).toContain('alerts')
    expect(names).toContain('silences')
  })

  test('is idempotent', () => {
    const db = freshDb()
    initDb(db)
  })
})

describe('hashToken / generateToken', () => {
  test('hashToken is deterministic + 64 hex chars', () => {
    const t = 'abc123'
    const h1 = hashToken(t)
    const h2 = hashToken(t)
    expect(h1).toBe(h2)
    expect(h1).toMatch(/^[0-9a-f]{64}$/)
  })

  test('generateToken returns a base64url-shaped string of reasonable length', () => {
    const t = generateToken()
    expect(t.length).toBeGreaterThanOrEqual(40)
    expect(t).toMatch(/^[A-Za-z0-9_-]+$/)
  })
})

describe('publishers', () => {
  test('upsertPublisher inserts and verifyPublisher accepts the token', () => {
    const db = freshDb()
    const token = generateToken()
    upsertPublisher(db, 'hermes', token)
    expect(verifyPublisher(db, 'hermes', token)).toBe(true)
    expect(verifyPublisher(db, 'hermes', 'nope')).toBe(false)
  })

  test('rotation replaces the token', () => {
    const db = freshDb()
    const t1 = generateToken()
    const t2 = generateToken()
    upsertPublisher(db, 'hermes', t1)
    upsertPublisher(db, 'hermes', t2)
    expect(verifyPublisher(db, 'hermes', t1)).toBe(false)
    expect(verifyPublisher(db, 'hermes', t2)).toBe(true)
  })

  test('rotation clears revoked_at', () => {
    const db = freshDb()
    upsertPublisher(db, 'hermes', 'a')
    revokePublisher(db, 'hermes')
    upsertPublisher(db, 'hermes', 'b')
    expect(verifyPublisher(db, 'hermes', 'b')).toBe(true)
  })

  test('revoked publishers cannot publish', () => {
    const db = freshDb()
    const token = generateToken()
    upsertPublisher(db, 'hermes', token)
    revokePublisher(db, 'hermes')
    expect(verifyPublisher(db, 'hermes', token)).toBe(false)
  })

  test('unknown publishers cannot publish', () => {
    const db = freshDb()
    expect(verifyPublisher(db, 'ghost', 'whatever')).toBe(false)
  })

  test('listPublishers returns alphabetical order', () => {
    const db = freshDb()
    upsertPublisher(db, 'hermes', 'a')
    upsertPublisher(db, 'commonplace', 'b')
    upsertPublisher(db, 'boss-clod', 'c')
    const names = listPublishers(db).map((p) => p.name)
    expect(names).toEqual(['boss-clod', 'commonplace', 'hermes'])
  })
})

describe('insertAlert / getUndeliveredAlerts', () => {
  test('inserts a basic alert', () => {
    const db = freshDb()
    const r = insertAlert(db, {
      publisher: 'hermes',
      severity: 'warn',
      source: 'hermes:theta_watchdog',
      title: 'Theta recovered',
      body: 'pid 96692 killed; restart probe 70ms',
    })
    expect(r.id).toBeGreaterThan(0)
    expect(r.suppressed).toBe(false)
    expect(r.silence_until).toBeNull()
  })

  test('rejects invalid severity at SQL level', () => {
    const db = freshDb()
    expect(() =>
      // @ts-expect-error — testing runtime guard
      insertAlert(db, { publisher: 'hermes', severity: 'bogus', source: 'x', title: 'y', body: 'z' }),
    ).toThrow()
  })

  test('honors active silence on dedup_key', () => {
    const db = freshDb()
    const until = new Date(Date.now() + 60_000).toISOString()
    setSilence(db, 'theta-flap', until, 'commonplace')
    const r = insertAlert(db, {
      publisher: 'hermes',
      severity: 'warn',
      source: 'hermes:theta',
      title: 't',
      body: 'b',
      dedup_key: 'theta-flap',
    })
    expect(r.suppressed).toBe(true)
    expect(r.silence_until).toBe(until)
    const undelivered = getUndeliveredAlerts(db)
    expect(undelivered).toHaveLength(0)
  })

  test('expired silence does not suppress', () => {
    const db = freshDb()
    const past = new Date(Date.now() - 60_000).toISOString()
    setSilence(db, 'theta-flap', past, 'commonplace')
    const r = insertAlert(db, {
      publisher: 'hermes',
      severity: 'warn',
      source: 'hermes:theta',
      title: 't',
      body: 'b',
      dedup_key: 'theta-flap',
    })
    expect(r.suppressed).toBe(false)
    expect(getUndeliveredAlerts(db)).toHaveLength(1)
  })

  test('getUndeliveredAlerts returns only unsuppressed and undelivered', () => {
    const db = freshDb()
    const a = insertAlert(db, { publisher: 'hermes', severity: 'info', source: 's', title: 't', body: 'b' })
    insertAlert(db, { publisher: 'hermes', severity: 'info', source: 's', title: 't', body: 'b' })
    markAlertDelivered(db, a.id)
    const rows = getUndeliveredAlerts(db)
    expect(rows).toHaveLength(1)
  })
})

describe('markAlertDelivered / getAlert', () => {
  test('markAlertDelivered sets delivered_at', () => {
    const db = freshDb()
    const r = insertAlert(db, { publisher: 'hermes', severity: 'info', source: 's', title: 't', body: 'b' })
    markAlertDelivered(db, r.id)
    const a = getAlert(db, r.id)!
    expect(a.delivered_at).not.toBeNull()
  })

  test('getAlert returns null for unknown id', () => {
    const db = freshDb()
    expect(getAlert(db, 999)).toBeNull()
  })
})

describe('ackAlert', () => {
  test('first ack succeeds; second returns false', () => {
    const db = freshDb()
    const r = insertAlert(db, { publisher: 'hermes', severity: 'warn', source: 's', title: 't', body: 'b' })
    expect(ackAlert(db, r.id, 'commonplace', 'looks fine')).toBe(true)
    expect(ackAlert(db, r.id, 'dirigible', 'me too')).toBe(false)
    const a = getAlert(db, r.id)!
    expect(a.ack_by).toBe('commonplace')
    expect(a.ack_note).toBe('looks fine')
  })
})

describe('getAlertHistory', () => {
  test('filters by publisher', () => {
    const db = freshDb()
    insertAlert(db, { publisher: 'hermes', severity: 'info', source: 's', title: 't', body: 'b' })
    insertAlert(db, { publisher: 'commonplace', severity: 'info', source: 's', title: 't', body: 'b' })
    const rows = getAlertHistory(db, { publisher: 'commonplace' })
    expect(rows.map((r) => r.publisher)).toEqual(['commonplace'])
  })

  test('filters by source prefix', () => {
    const db = freshDb()
    insertAlert(db, { publisher: 'hermes', severity: 'info', source: 'hermes:auth', title: 't', body: 'b' })
    insertAlert(db, { publisher: 'hermes', severity: 'info', source: 'hermes:theta', title: 't', body: 'b' })
    insertAlert(db, { publisher: 'commonplace', severity: 'info', source: 'commonplace:sync', title: 't', body: 'b' })
    const rows = getAlertHistory(db, { source: 'hermes:' })
    expect(rows).toHaveLength(2)
  })

  test('filters by severity + respects limit', () => {
    const db = freshDb()
    for (let i = 0; i < 5; i++) {
      insertAlert(db, { publisher: 'hermes', severity: 'warn', source: 's', title: 't', body: 'b' })
    }
    insertAlert(db, { publisher: 'hermes', severity: 'error', source: 's', title: 't', body: 'b' })
    const rows = getAlertHistory(db, { severity: 'warn', limit: 3 })
    expect(rows).toHaveLength(3)
    expect(rows.every((r) => r.severity === 'warn')).toBe(true)
  })

  test('orders newest first', () => {
    const db = freshDb()
    const a = insertAlert(db, { publisher: 'hermes', severity: 'info', source: 's', title: 'first', body: 'b' })
    insertAlert(db, { publisher: 'hermes', severity: 'info', source: 's', title: 'second', body: 'b' })
    const rows = getAlertHistory(db, {})
    expect(rows[0].title).toBe('second')
    expect(rows[1].id).toBe(a.id)
  })
})

describe('silences', () => {
  test('setSilence + getActiveSilence round-trip', () => {
    const db = freshDb()
    const until = new Date(Date.now() + 60_000).toISOString()
    setSilence(db, 'k', until, 'who')
    expect(getActiveSilence(db, 'k')).toBe(until)
  })

  test('expired silence returns null', () => {
    const db = freshDb()
    const past = new Date(Date.now() - 1000).toISOString()
    setSilence(db, 'k', past, 'who')
    expect(getActiveSilence(db, 'k')).toBeNull()
  })

  test('setSilence is upsert', () => {
    const db = freshDb()
    const t1 = new Date(Date.now() + 60_000).toISOString()
    const t2 = new Date(Date.now() + 120_000).toISOString()
    setSilence(db, 'k', t1, 'a')
    setSilence(db, 'k', t2, 'b')
    expect(getActiveSilence(db, 'k')).toBe(t2)
  })
})
