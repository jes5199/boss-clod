#!/usr/bin/env bun
// Opt-in live model test: isolated queue, actual Claude-channel MCP client,
// actual app-server, and an actual MCP reply. No production peers are contacted.
import { mkdtempSync, mkdirSync, readFileSync, openSync, closeSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { spawn } from 'node:child_process'
import { Database } from 'bun:sqlite'
import { Client } from '@modelcontextprotocol/sdk/client/index.js'
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js'
import { z } from 'zod'
import { initDb, registerIdentity } from './db'

const dir = mkdtempSync(join(tmpdir(), 'clod-codex-smoke-'))
const project = join(dir, 'smoke-peer')
mkdirSync(project)
const dbPath = join(dir, 'queue.db')
const db = new Database(dbPath)
initDb(db)
registerIdentity(db, 'codex-smoke', `codex:codex-smoke:${project}`)
db.close()
const env = { ...process.env, CLOD_SQUAD_DB: dbPath, CLOD_SQUAD_PROJECT_DIR: project }
delete env.CLOD_SQUAD_IDENTITY
delete env.CLOD_SQUAD_TRANSPORT
const client = new Client({ name: 'clod-smoke', version: '1.0.0' })
const transport = new StdioClientTransport({ command: process.execPath, args: [join(import.meta.dir, 'server.ts')], env: env as Record<string, string>, stderr: 'pipe' })
let received = ''
client.setNotificationHandler(z.object({ method: z.literal('notifications/claude/channel'), params: z.object({ content: z.string(), meta: z.record(z.string(), z.string()) }) }), msg => { received = msg.params.content })
await client.connect(transport)
const log = join(dir, 'bridge.log')
const fd = openSync(log, 'w')
const bridge = spawn(process.execPath, [join(import.meta.dir, 'codex-bridge.ts')], {
  cwd: project, env: { ...env, CLOD_SQUAD_IDENTITY: 'codex-smoke', CLOD_SQUAD_STATE_DIR: join(dir, 'state') },
  detached: true, stdio: ['ignore', fd, fd],
})
closeSync(fd)
try {
  const sent = await client.callTool({ name: 'send', arguments: { to: 'codex-smoke', text: 'This is an isolated integration test authorized by the user. Please call the clod-squad send tool to reply to smoke-peer with exactly CLOD_CODEX_ROUNDTRIP_OK. Do not use any other tools or change files.' } })
  if (sent.isError) throw new Error(JSON.stringify(sent))
  const deadline = Date.now() + 180_000
  while (!received && Date.now() < deadline) {
    if (bridge.exitCode !== null) throw new Error('bridge exited')
    await Bun.sleep(500)
  }
  if (received !== 'CLOD_CODEX_ROUNDTRIP_OK') throw new Error(`Expected reply, received ${JSON.stringify(received)}`)
  console.log(`PASS: Claude MCP send → Codex app-server turn → Codex MCP send → Claude channel notification. Logs: ${log}`)
} catch (error) {
  console.error(readFileSync(log, 'utf8'))
  throw error
} finally {
  try { process.kill(-bridge.pid!, 'SIGTERM') } catch {}
  await client.close()
}
