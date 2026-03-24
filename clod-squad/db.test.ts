import { describe, test, expect } from 'bun:test'
import { Database } from 'bun:sqlite'
import { initDb, registerIdentity, listIdentities, pruneStaleIdentities } from './db'

describe('initDb', () => {
  test('creates identities and messages tables', () => {
    const db = new Database(':memory:')
    initDb(db)
    const tables = db.query("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").all() as { name: string }[]
    const names = tables.map(t => t.name)
    expect(names).toContain('identities')
    expect(names).toContain('messages')
  })

  test('is idempotent', () => {
    const db = new Database(':memory:')
    initDb(db)
    initDb(db) // should not throw
  })
})

describe('registerIdentity', () => {
  test('registers a new identity', () => {
    const db = new Database(':memory:')
    initDb(db)
    registerIdentity(db, 'my-app', '/home/jes/my-app')
    const rows = listIdentities(db)
    expect(rows).toHaveLength(1)
    expect(rows[0].name).toBe('my-app')
    expect(rows[0].full_path).toBe('/home/jes/my-app')
  })

  test('updates last_seen_at on re-registration with same path', () => {
    const db = new Database(':memory:')
    initDb(db)
    registerIdentity(db, 'my-app', '/home/jes/my-app')
    const first = listIdentities(db)[0].last_seen_at
    registerIdentity(db, 'my-app', '/home/jes/my-app')
    const second = listIdentities(db)[0].last_seen_at
    expect(second >= first).toBe(true)
  })

  test('throws on basename collision with different path', () => {
    const db = new Database(':memory:')
    initDb(db)
    registerIdentity(db, 'my-app', '/home/jes/my-app')
    expect(() => registerIdentity(db, 'my-app', '/work/my-app')).toThrow(/collision/)
  })
})

describe('pruneStaleIdentities', () => {
  test('removes identities not seen for 7 days', () => {
    const db = new Database(':memory:')
    initDb(db)
    // Insert a stale identity (8 days ago)
    const staleDate = new Date(Date.now() - 8 * 24 * 60 * 60 * 1000).toISOString()
    db.run(
      'INSERT INTO identities (name, full_path, last_seen_at, registered_at) VALUES (?, ?, ?, ?)',
      ['old-app', '/home/jes/old-app', staleDate, staleDate]
    )
    // Insert a fresh identity
    registerIdentity(db, 'new-app', '/home/jes/new-app')

    pruneStaleIdentities(db)
    const rows = listIdentities(db)
    expect(rows).toHaveLength(1)
    expect(rows[0].name).toBe('new-app')
  })
})
