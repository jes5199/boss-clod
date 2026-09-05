#!/usr/bin/env bun
// Opt-in live test: two real conversations, same directory, isolated squad DB.
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { tmpdir, homedir } from 'node:os'
import { Database } from 'bun:sqlite'
import { Client } from '@modelcontextprotocol/sdk/client/index.js'
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js'
import { z } from 'zod'
import { AppServer } from './codex-rpc'
import { initDb } from './db'
import { discoverSessions, SessionRouter, sessionIdentity } from './codex-sessions'

const dir = mkdtempSync(join(tmpdir(), 'clod-auto-smoke-'))
const project = join(dir, 'same-project'); mkdirSync(project)
const dbPath = join(dir, 'queue.db')
const db = new Database(dbPath); initDb(db)
const events: any[] = []
const replies: { from: string; text: string }[] = []
const env = { ...process.env, CLOD_SQUAD_DB: dbPath, CLOD_SQUAD_PROJECT_DIR: project } as Record<string, string>
delete env.CLOD_SQUAD_IDENTITY; delete env.CLOD_SQUAD_TRANSPORT; delete env.CODEX_THREAD_ID
const claude = new Client({ name: 'clod-auto-smoke', version: '1' })
claude.setNotificationHandler(z.object({ method: z.literal('notifications/claude/channel'), params: z.object({ content: z.string(), meta: z.record(z.string(), z.string()) }) }), msg => {
  replies.push({ from: msg.params.meta.from, text: msg.params.content })
})
const command = ['codex', 'app-server', '-c', 'mcp_servers.clod_squad.enabled=false']
for (const [key, value] of Object.entries({ CLOD_SQUAD_TRANSPORT: 'codex', CLOD_SQUAD_DB: dbPath, CLOD_SQUAD_PROJECT_DIR: project })) {
  command.push('-c', `mcp_servers.clod-squad.env.${key}=${JSON.stringify(value)}`)
}
command.push('-c', `mcp_servers.clod-squad.command=${JSON.stringify(process.execPath)}`,
  '-c', `mcp_servers.clod-squad.args=${JSON.stringify([join(import.meta.dir, 'server.ts')])}`)
for (const tool of ['send', 'list_peers']) command.push('-c', `mcp_servers.clod-squad.tools.${tool}.approval_mode="approve"`)
const host = new AppServer(command, project, env)
const queue = new AppServer(['codex', 'app-server'], project, env)
const completed = new Set<string>()
host.onNotification = (method, params) => {
  events.push({ method, params })
  if (method === 'turn/completed') completed.add(params.turn.id)
}
const until = async (predicate: () => boolean, label: string) => {
  const end = Date.now() + 180_000
  while (!predicate()) {
    if (Date.now() > end) throw new Error(`Timeout: ${label}`)
    await Bun.sleep(200)
  }
}
let timer: ReturnType<typeof setInterval> | undefined
let busy = false
try {
  await claude.connect(new StdioClientTransport({ command: process.execPath, args: [join(import.meta.dir, 'server.ts')], env, stderr: 'pipe' }))
  for (const rpc of [host, queue]) {
    await rpc.request('initialize', { clientInfo: { name: 'clod_auto_smoke', version: '1' }, capabilities: { experimentalApi: true } })
    rpc.notify('initialized')
  }
  const ids: string[] = []
  for (let i = 0; i < 2; i++) {
    const result = await host.request('thread/start', {
      cwd: project,
      developerInstructions: 'This is a user-authorized clod-squad connectivity test. You may send test replies to same-project. When a peer message requests a token, use clod-squad send to reply with exactly that token to the sender. Never read_history, broadcast, run shell commands, or edit files. Other prompts require only a short reply.',
    })
    ids.push(result.thread.id)
    const turn = await host.request('turn/start', { threadId: result.thread.id, input: [{ type: 'text', text: 'Call clod-squad list_peers once to verify automatic identity registration, then reply READY.' }] })
    await until(() => completed.has(turn.turn.id), `warm session ${i}`)
    console.log(`Warm session ${i}: ${result.thread.id}`)
  }
  const router = new SessionRouter(db, queue, dbPath)
  const live = () => discoverSessions(process.env.CODEX_HOME || join(homedir(), '.codex')).filter(s => ids.includes(s.threadId))
  if (live().length !== 2) throw new Error('Did not discover both live sessions in the same directory')
  await router.poll(live())
  timer = setInterval(async () => {
    if (busy) return
    busy = true
    try { await router.poll(live()) } catch (error) { console.error(error) }
    finally { busy = false }
  }, 500)
  const send = async (index: number, token: string) => {
    const result = await claude.callTool({ name: 'send', arguments: { to: sessionIdentity(project, ids[index]), text: `Connectivity test: reply to same-project using clod-squad send with exactly ${token}.` } })
    if (result.isError) throw new Error(JSON.stringify(result))
  }
  for (let i = 0; i < 2; i++) {
    await send(i, `IDLE_${i}_OK`)
    await until(() => replies.some(r => r.from === sessionIdentity(project, ids[i]) && r.text === `IDLE_${i}_OK`), `idle roundtrip ${i}`)
    console.log(`PASS idle roundtrip ${i}`)
  }
  // Enqueue on turn/started, so this is demonstrably submitted while busy.
  let activeTurn = '', sentBusy: Promise<void> | undefined
  const previous = host.onNotification
  host.onNotification = (method, params) => {
    previous(method, params)
    if (method === 'turn/started' && params.threadId === ids[0] && !activeTurn) {
      activeTurn = params.turn.id
      sentBusy = send(0, 'BUSY_OK')
    }
  }
  await host.request('turn/start', { threadId: ids[0], input: [{ type: 'text', text: 'Write a short paragraph explaining why a queue preserves message order. Do not use tools.' }] })
  await until(() => Boolean(sentBusy), 'busy send')
  await sentBusy
  await until(() => replies.some(r => r.from === sessionIdentity(project, ids[0]) && r.text === 'BUSY_OK'), 'busy roundtrip')
  if (!completed.has(activeTurn)) throw new Error('Queued message bypassed active turn completion')
  console.log('PASS busy message delivered after active turn; replies reached Claude channel without history polling')
  console.log(`PASS automatic session discovery, distinct identities, two idle roundtrips, one busy roundtrip. Artifacts: ${dir}`)
} finally {
  clearInterval(timer)
  writeFileSync(join(dir, 'events.json'), JSON.stringify({ events, replies }, null, 2))
  host.close(); queue.close(); await claude.close()
  // Let any in-flight queue operation finish before process exit; artifacts retained.
}
