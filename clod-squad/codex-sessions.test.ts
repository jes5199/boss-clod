import { test, expect } from 'bun:test'
import { Database } from 'bun:sqlite'
import { initDb, registerIdentity, insertMessage, getUndelivered, isOnline } from './db'
import { SessionRouter, registerSession, sessionIdentity, discoverSessions } from './codex-sessions'
import { RpcError } from './codex-rpc'
import { mkdtempSync, mkdirSync, writeFileSync, symlinkSync, rmSync } from 'node:fs'
import { join } from 'node:path'
import { tmpdir } from 'node:os'

const sessions = [1, 2].map(n => ({ threadId: `00000000-0000-0000-0000-00000000000${n}`, cwd: '/project', pid: n }))
function fixture(request: (method: string, params: any) => Promise<any>) {
  const db = new Database(':memory:'); initDb(db)
  registerIdentity(db, 'claude', '/claude')
  const names = sessions.map(s => registerSession(db, s))
  return { db, names, router: new SessionRouter(db, { request }, '/queue.db') }
}

test('two threads in one directory get distinct routes and retain sender provenance', async () => {
  const calls: any[] = []
  const { db, names, router } = fixture(async (method, params) => { calls.push({ method, params }) })
  try {
    expect(names[0]).not.toBe(names[1])
    for (const name of names) insertMessage(db, 'claude', name, name)
    await router.poll(sessions)
    expect(calls.map(c => c.params.threadId)).toEqual(sessions.map(s => s.threadId))
    expect(calls.every(c => c.method === 'thread/queue/add')).toBe(true)
    expect(calls[0].params.input[0].text).toContain('"from":"claude"')
    expect(getUndelivered(db, names[0])).toHaveLength(0)
  } finally { db.close() }
})

test('ambiguous directory alias stays queued, unique alias delivers to the live thread', async () => {
  const calls: any[] = []
  const { db, router } = fixture(async (_, params) => { calls.push(params) })
  try {
    registerIdentity(db, 'codex-project', 'codex:codex-project:/project')
    insertMessage(db, 'claude', 'codex-project', 'legacy')
    await router.poll(sessions)
    expect(calls).toHaveLength(0)
    expect(getUndelivered(db, 'codex-project')).toHaveLength(1)
    await router.poll([sessions[1]])
    expect(calls[0].threadId).toBe(sessions[1].threadId)
    insertMessage(db, 'claude', 'codex-project', 'reserved for a dedicated bridge')
    await router.poll([sessions[1]], new Set(['codex-project']))
    expect(calls).toHaveLength(1)
    expect(getUndelivered(db, 'codex-project')).toHaveLength(1)
    expect(registerSession(db, { ...sessions[0], cwd: '/renamed-project' })).toBe(sessionIdentity('/project', sessions[0].threadId))
  } finally { db.close() }
})

test('failed RPC preserves mail and marks route offline; explicit rejection can retry', async () => {
  let fail = true
  const { db, names, router } = fixture(async () => { if (fail) throw new RpcError('not ready') })
  try {
    insertMessage(db, 'claude', names[0], 'retry')
    await expect(router.poll([sessions[0]])).rejects.toThrow('not ready')
    expect(getUndelivered(db, names[0])).toHaveLength(1)
    expect(isOnline(db.query('SELECT * FROM identities WHERE name = ?').get(names[0]) as any)).toBe(false)
    fail = false
    await router.poll([sessions[0]])
    expect(getUndelivered(db, names[0])).toHaveLength(0)
  } finally { db.close() }
})

test('uncertain acceptance is not replayed after router restart', async () => {
  const { db, names, router } = fixture(async () => { throw new Error('connection lost') })
  try {
    insertMessage(db, 'claude', names[0], 'once')
    await expect(router.poll([sessions[0]])).rejects.toThrow('connection lost')
    let calls = 0
    const restarted = new SessionRouter(db, { request: async () => { calls++ } }, '/queue.db')
    await expect(restarted.poll([sessions[0]])).rejects.toThrow('uncertain delivery')
    expect(calls).toBe(0)
    expect(getUndelivered(db, names[0])).toHaveLength(1)
  } finally { db.close() }
})

test('discovery uses held locks, ignores stale files and dedicated bridge owners', () => {
  const dir = mkdtempSync(join(tmpdir(), 'clod-discovery-'))
  try {
    const home = join(dir, 'home'), proc = join(dir, 'proc')
    mkdirSync(home); mkdirSync(proc)
    const state = new Database(join(home, 'state_5.sqlite'))
    state.exec('CREATE TABLE threads (id TEXT, cwd TEXT, source TEXT, archived INTEGER)')
    for (const s of sessions) {
      state.run('INSERT INTO threads VALUES (?, ?, ?, 0)', [s.threadId, s.cwd, 'cli'])
      mkdirSync(join(proc, String(s.pid), 'fd'), { recursive: true })
      writeFileSync(join(proc, String(s.pid), 'environ'), s.pid === 2 ? 'CLOD_SQUAD_IDENTITY=dedicated\0' : '')
      symlinkSync(join(home, 'thread-writer-locks', s.threadId + '.lock'), join(proc, String(s.pid), 'fd', '42'))
    }
    state.close()
    writeFileSync(join(proc, 'locks'), '1: FLOCK ADVISORY WRITE 1 fd:01:123 0 EOF\n2: FLOCK ADVISORY WRITE 2 fd:01:124 0 EOF\n')
    expect(discoverSessions(home, proc)).toEqual([sessions[0]])
    writeFileSync(join(proc, 'locks'), '')
    expect(discoverSessions(home, proc)).toEqual([])
    expect(() => sessionIdentity('/project', 'bad')).toThrow()
  } finally { rmSync(dir, { recursive: true, force: true }) }
})
