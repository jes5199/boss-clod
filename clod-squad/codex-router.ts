#!/usr/bin/env bun
import { Database } from 'bun:sqlite'
import { homedir } from 'node:os'
import { join, dirname } from 'node:path'
import { mkdirSync } from 'node:fs'
import { AppServer } from './codex-rpc'
import { initDb } from './db'
import { discoverSessions, dedicatedIdentities, SessionRouter } from './codex-sessions'

const codexHome = process.env.CODEX_HOME || join(homedir(), '.codex')
const stateDir = join(codexHome, 'clod-squad')
mkdirSync(stateDir, { recursive: true, mode: 0o700 })
if (process.argv[2] !== '--locked') {
  const child = Bun.spawn(['/usr/bin/flock', '--nonblock', join(stateDir, 'router.lock'), process.execPath, import.meta.path, '--locked'], { stdin: 'inherit', stdout: 'inherit', stderr: 'inherit' })
  let requestedStop = false
  for (const signal of ['SIGINT', 'SIGTERM'] as const) process.on(signal, () => { requestedStop = true; child.kill(signal) })
  const code = await child.exited
  process.exit(requestedStop ? 0 : code)
}
const dbPath = process.env.CLOD_SQUAD_DB || join(homedir(), '.claude/channels/clod-squad/queue.db')
mkdirSync(dirname(dbPath), { recursive: true })
const db = new Database(dbPath)
initDb(db)
// This app-server only submits native queue requests. It creates no model threads.
const rpc = new AppServer([process.env.CLOD_SQUAD_CODEX || 'codex', 'app-server'], process.cwd())
let stopped = false
const stop = (code = 0) => {
  if (stopped) return
  stopped = true
  rpc.close()
  setTimeout(() => process.exit(code), 100)
}
rpc.onExit = () => stop(1)
process.on('SIGINT', () => stop())
process.on('SIGTERM', () => stop())
try {
  await rpc.request('initialize', { clientInfo: { name: 'clod_squad_router', version: '1.0.0' }, capabilities: { experimentalApi: true } })
  rpc.notify('initialized')
  const router = new SessionRouter(db, rpc, dbPath)
  console.error('clod-squad: automatic Codex session router ready')
  let lastError = ''
  while (!stopped) {
    try { await router.poll(discoverSessions(codexHome), dedicatedIdentities(codexHome)); lastError = '' }
    catch (error) {
      if (String(error) !== lastError) console.error(error)
      lastError = String(error)
    }
    await Bun.sleep(2000)
  }
} catch (error) { console.error(error); stop(1) }
