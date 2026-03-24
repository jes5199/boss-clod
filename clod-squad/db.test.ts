import { describe, test, expect } from 'bun:test'
import { Database } from 'bun:sqlite'
import { initDb, registerIdentity, listIdentities, pruneStaleIdentities, insertMessage, getUndelivered, markDelivered, getHistory } from './db'

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

describe('insertMessage', () => {
  test('inserts a message and returns its id', () => {
    const db = new Database(':memory:')
    initDb(db)
    registerIdentity(db, 'boss', '/home/jes/boss')
    registerIdentity(db, 'worker', '/home/jes/worker')

    const id = insertMessage(db, 'boss', 'worker', 'do the thing')
    expect(id).toBeGreaterThan(0)
  })

  test('inserts with metadata', () => {
    const db = new Database(':memory:')
    initDb(db)
    registerIdentity(db, 'boss', '/home/jes/boss')
    registerIdentity(db, 'worker', '/home/jes/worker')

    const id = insertMessage(db, 'boss', 'worker', 'urgent task', { priority: 'high' })
    const msgs = getHistory(db, 'boss', 'worker', 20)
    expect(msgs[0].metadata).toBe(JSON.stringify({ priority: 'high' }))
  })

  test('throws on nonexistent recipient', () => {
    const db = new Database(':memory:')
    initDb(db)
    registerIdentity(db, 'boss', '/home/jes/boss')

    expect(() => insertMessage(db, 'boss', 'nobody', 'hello')).toThrow(/not found/)
  })
})

describe('getUndelivered', () => {
  test('returns only undelivered messages for recipient', () => {
    const db = new Database(':memory:')
    initDb(db)
    registerIdentity(db, 'boss', '/home/jes/boss')
    registerIdentity(db, 'worker', '/home/jes/worker')

    insertMessage(db, 'boss', 'worker', 'msg1')
    insertMessage(db, 'boss', 'worker', 'msg2')

    const msgs = getUndelivered(db, 'worker')
    expect(msgs).toHaveLength(2)
    expect(msgs[0].body).toBe('msg1')
    expect(msgs[1].body).toBe('msg2')
  })

  test('does not return messages for other recipients', () => {
    const db = new Database(':memory:')
    initDb(db)
    registerIdentity(db, 'boss', '/home/jes/boss')
    registerIdentity(db, 'w1', '/home/jes/w1')
    registerIdentity(db, 'w2', '/home/jes/w2')

    insertMessage(db, 'boss', 'w1', 'for w1')
    insertMessage(db, 'boss', 'w2', 'for w2')

    const msgs = getUndelivered(db, 'w1')
    expect(msgs).toHaveLength(1)
    expect(msgs[0].body).toBe('for w1')
  })
})

describe('markDelivered', () => {
  test('marks a message as delivered', () => {
    const db = new Database(':memory:')
    initDb(db)
    registerIdentity(db, 'boss', '/home/jes/boss')
    registerIdentity(db, 'worker', '/home/jes/worker')

    insertMessage(db, 'boss', 'worker', 'msg')
    const before = getUndelivered(db, 'worker')
    expect(before).toHaveLength(1)

    markDelivered(db, before[0].id)
    const after = getUndelivered(db, 'worker')
    expect(after).toHaveLength(0)
  })
})

describe('getHistory', () => {
  test('returns messages in both directions', () => {
    const db = new Database(':memory:')
    initDb(db)
    registerIdentity(db, 'boss', '/home/jes/boss')
    registerIdentity(db, 'worker', '/home/jes/worker')

    insertMessage(db, 'boss', 'worker', 'task for you')
    insertMessage(db, 'worker', 'boss', 'done')

    const history = getHistory(db, 'boss', 'worker', 20)
    expect(history).toHaveLength(2)
    expect(history[0].body).toBe('task for you')
    expect(history[1].body).toBe('done')
  })

  test('respects limit', () => {
    const db = new Database(':memory:')
    initDb(db)
    registerIdentity(db, 'a', '/home/jes/a')
    registerIdentity(db, 'b', '/home/jes/b')

    for (let i = 0; i < 5; i++) insertMessage(db, 'a', 'b', `msg${i}`)

    const history = getHistory(db, 'a', 'b', 3)
    expect(history).toHaveLength(3)
    // Should return the 3 most recent
    expect(history[0].body).toBe('msg2')
  })
})
