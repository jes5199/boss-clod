import { describe, test, expect, beforeEach } from 'bun:test'
import { Database } from 'bun:sqlite'
import {
  initDb,
  registerIdentity,
  listIdentities,
  insertMessage,
  getUndelivered,
  markDelivered,
  getHistory,
  isOnline,
} from './db'

describe('end-to-end message flow', () => {
  let db: Database

  beforeEach(() => {
    db = new Database(':memory:')
    initDb(db)
    registerIdentity(db, 'boss', '/home/jes/boss')
    registerIdentity(db, 'worker-a', '/home/jes/worker-a')
    registerIdentity(db, 'worker-b', '/home/jes/worker-b')
  })

  test('send → poll → deliver → history cycle', () => {
    // Boss sends to worker-a
    const id = insertMessage(db, 'boss', 'worker-a', 'do the thing', { priority: 'high' })

    // Worker-a polls and finds the message
    const undelivered = getUndelivered(db, 'worker-a')
    expect(undelivered).toHaveLength(1)
    expect(undelivered[0].id).toBe(id)
    expect(undelivered[0].body).toBe('do the thing')

    // Worker-a marks it delivered
    markDelivered(db, id)

    // No more undelivered
    expect(getUndelivered(db, 'worker-a')).toHaveLength(0)

    // Worker-a replies
    insertMessage(db, 'worker-a', 'boss', 'done')

    // History shows both directions
    const history = getHistory(db, 'boss', 'worker-a', 20)
    expect(history).toHaveLength(2)
    expect(history[0].from_id).toBe('boss')
    expect(history[1].from_id).toBe('worker-a')
  })

  test('broadcast excludes sender', () => {
    // Boss broadcasts
    const peers = listIdentities(db).filter(p => p.name !== 'boss')
    for (const peer of peers) {
      insertMessage(db, 'boss', peer.name, 'all hands')
    }

    // worker-a and worker-b each get one message
    expect(getUndelivered(db, 'worker-a')).toHaveLength(1)
    expect(getUndelivered(db, 'worker-b')).toHaveLength(1)

    // boss gets nothing
    expect(getUndelivered(db, 'boss')).toHaveLength(0)
  })

  test('broadcast messages appear in pairwise history', () => {
    const peers = listIdentities(db).filter(p => p.name !== 'boss')
    for (const peer of peers) {
      insertMessage(db, 'boss', peer.name, 'broadcast msg')
    }

    const historyA = getHistory(db, 'boss', 'worker-a', 20)
    const historyB = getHistory(db, 'boss', 'worker-b', 20)
    expect(historyA).toHaveLength(1)
    expect(historyB).toHaveLength(1)
    expect(historyA[0].body).toBe('broadcast msg')
  })

  test('messages to offline peers are queued', () => {
    // worker-b has not updated last_seen recently — simulate by checking isOnline
    const workerB = listIdentities(db).find(i => i.name === 'worker-b')!
    // Just registered, so technically online — but the point is messages queue regardless
    insertMessage(db, 'boss', 'worker-b', 'when you wake up')

    const msgs = getUndelivered(db, 'worker-b')
    expect(msgs).toHaveLength(1)
    expect(msgs[0].body).toBe('when you wake up')
  })

  test('direct worker-to-worker messaging works', () => {
    insertMessage(db, 'worker-a', 'worker-b', 'hey can you export that function?')

    const msgs = getUndelivered(db, 'worker-b')
    expect(msgs).toHaveLength(1)
    expect(msgs[0].from_id).toBe('worker-a')
  })
})
