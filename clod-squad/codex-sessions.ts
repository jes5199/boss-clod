import { Database } from 'bun:sqlite'
import { basename, join } from 'node:path'
import { readdirSync, readFileSync, readlinkSync } from 'node:fs'
import { createHash } from 'node:crypto'
import { registerIdentity, updateLastSeen, getUndelivered, markDelivered } from './db'
import { formatMessage, initDelivery } from './codex-delivery'
import { RpcError, type Rpc } from './codex-rpc'

export const threadPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
export function sessionIdentity(cwd: string, threadId: string) {
  if (!threadPattern.test(threadId)) throw new Error('Missing or invalid Codex thread ID')
  return `codex-${basename(cwd).replace(/[^a-zA-Z0-9_.-]/g, '_')}-${threadId}`
}

export interface LiveSession { threadId: string; cwd: string; pid: number }

/** Linux writer locks identify live owners, including idle CLI sessions. Never resume them. */
export function discoverSessions(codexHome: string, procRoot = '/proc'): LiveSession[] {
  const pids = new Set(readFileSync(join(procRoot, 'locks'), 'utf8').split('\n')
    .map(line => line.trim().split(/\s+/)).filter(parts => parts[1] === 'FLOCK' && parts[3] === 'WRITE')
    .map(parts => Number(parts[4])).filter(pid => pid > 0))
  const ids = new Map<string, number>()
  for (const pid of pids) {
    try {
      // Dedicated legacy participants already have their own delivery owner.
      const env = readFileSync(join(procRoot, String(pid), 'environ'), 'utf8').split('\0')
      if (env.some(value => value.startsWith('CLOD_SQUAD_IDENTITY='))) continue
      for (const fd of readdirSync(join(procRoot, String(pid), 'fd'))) {
        try {
          const path = readlinkSync(join(procRoot, String(pid), 'fd', fd))
          if (!path.startsWith(join(codexHome, 'thread-writer-locks') + '/')) continue
          const threadId = basename(path, '.lock')
          if (threadPattern.test(threadId)) ids.set(threadId, pid)
        } catch { /* descriptor closed during scan */ }
      }
    } catch { /* process exited or belongs to another user */ }
  }
  if (!ids.size) return []
  const stateFile = readdirSync(codexHome).filter(name => /^state_\d+\.sqlite$/.test(name))
    .sort((a, b) => Number(b.match(/\d+/)![0]) - Number(a.match(/\d+/)![0]))[0]
  if (!stateFile) return []
  const state = new Database(join(codexHome, stateFile), { readonly: true })
  try {
    const result: LiveSession[] = []
    for (const [threadId, pid] of ids) {
      const row = state.query('SELECT cwd, source FROM threads WHERE id = ? AND archived = 0').get(threadId) as { cwd: string; source: string } | null
      // Codex rejects external user input into spawned subagents.
      if (row && !/sub.?agent/i.test(row.source)) result.push({ threadId, cwd: row.cwd, pid })
    }
    return result
  } finally { state.close() }
}

export function registerSession(db: Database, session: Pick<LiveSession, 'cwd' | 'threadId'>) {
  const registered = db.query('SELECT name FROM identities WHERE full_path = ?').get(`codex-thread:${session.threadId}`) as { name: string } | null
  if (registered) return registered.name
  const identity = sessionIdentity(session.cwd, session.threadId)
  const exists = db.query('SELECT 1 FROM identities WHERE name = ?').get(identity)
  if (!exists) {
    registerIdentity(db, identity, `codex-thread:${session.threadId}`)
    // Registration alone is not proof that the inbound service is alive.
    db.run('UPDATE identities SET last_seen_at = NULL WHERE name = ?', [identity])
  }
  return identity
}

/** A legacy bridge's saved identity stays reserved even while that bridge is offline. */
export function dedicatedIdentities(codexHome: string): Set<string> {
  const identities = new Set<string>()
  const root = join(codexHome, 'clod-squad')
  try {
    for (const name of readdirSync(root)) {
      try {
        const saved = JSON.parse(readFileSync(join(root, name, 'thread.json'), 'utf8'))
        if (saved.identity === name && threadPattern.test(saved.threadId)) identities.add(name)
      } catch { /* not a saved dedicated participant */ }
    }
  } catch { /* no dedicated participants installed */ }
  return identities
}

/** Journal ambiguous submissions; a client ID alone is not proof of deduplication. */
export class SessionRouter {
  constructor(readonly db: Database, readonly rpc: Rpc, readonly dbPath: string) { initDelivery(db) }
  async deliver(identity: string, threadId: string) {
    for (const message of getUndelivered(this.db, identity).slice(0, 50)) {
      const clientUserMessageId = 'clod-squad-' + createHash('sha256')
        .update(`${this.dbPath}\0${message.id}\0${threadId}`).digest('hex')
      const previous = this.db.query('SELECT state FROM codex_deliveries WHERE message_id = ?').get(message.id) as { state: string } | null
      if (previous?.state === 'accepted') { markDelivered(this.db, message.id); continue }
      if (previous) throw new Error(`Message #${message.id} has uncertain delivery; inspect codex_deliveries and the native queue/history before retrying`)
      this.db.run('INSERT INTO codex_deliveries (message_id, thread_id, state) VALUES (?, ?, ?)', [message.id, threadId, 'pending'])
      try {
        await this.rpc.request('thread/queue/add', {
          threadId, clientUserMessageId,
          input: [{ type: 'text', text: formatMessage(message), text_elements: [] }],
        })
      } catch (error) {
        if (error instanceof RpcError) this.db.run('DELETE FROM codex_deliveries WHERE message_id = ?', [message.id])
        else this.db.run('UPDATE codex_deliveries SET error = ? WHERE message_id = ?', [String(error), message.id])
        throw error
      }
      this.db.transaction(() => {
        this.db.run("UPDATE codex_deliveries SET state = 'accepted' WHERE message_id = ?", [message.id])
        markDelivered(this.db, message.id)
      })()
    }
    updateLastSeen(this.db, identity)
  }
  async poll(sessions: LiveSession[], reserved = new Set<string>()) {
    const routes = new Map(sessions.map(session => [registerSession(this.db, session), session.threadId]))
    // Retain old directory addresses only when there is exactly one live target.
    const old = this.db.query("SELECT name, full_path FROM identities WHERE full_path LIKE 'codex:%'").all() as { name: string; full_path: string }[]
    for (const alias of old) {
      if (reserved.has(alias.name)) continue
      const matching = sessions.filter(s => alias.full_path === `codex:${alias.name}:${s.cwd}`)
      if (matching.length === 1) routes.set(alias.name, matching[0].threadId)
      else if (matching.length > 1) this.db.run('UPDATE identities SET last_seen_at = NULL WHERE name = ?', [alias.name])
    }
    const errors: string[] = []
    for (const [identity, threadId] of routes) {
      try { await this.deliver(identity, threadId) }
      catch (error) {
        this.db.run('UPDATE identities SET last_seen_at = NULL WHERE name = ?', [identity])
        errors.push(`${identity}: ${error}`)
      }
    }
    if (errors.length) throw new Error(errors.join('\n'))
  }
}
