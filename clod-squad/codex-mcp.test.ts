import { test, expect } from 'bun:test'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { Database } from 'bun:sqlite'
import { Client } from '@modelcontextprotocol/sdk/client/index.js'
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js'
import { initDb, registerIdentity, insertMessage, getUndelivered } from './db'

test('Codex MCP coexists with Claude and never consumes queued inbound messages', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'clod-mcp-test-'))
  const db = new Database(join(dir, 'queue.db'))
  initDb(db)
  registerIdentity(db, 'claude', dir)
  const client = new Client({ name: 'test', version: '1' })
  const env = { ...process.env, CLOD_SQUAD_TRANSPORT: 'codex', CLOD_SQUAD_PROJECT_DIR: dir, CLOD_SQUAD_IDENTITY: 'codex-test', CLOD_SQUAD_DB: join(dir, 'queue.db') } as Record<string, string>
  try {
    await client.connect(new StdioClientTransport({ command: process.execPath, args: [join(import.meta.dir, 'server.ts')], env, stderr: 'pipe' }))
    expect(client.getServerCapabilities()?.experimental?.['claude/channel']).toBeUndefined()
    insertMessage(db, 'claude', 'codex-test', 'must remain queued')
    await Bun.sleep(2300)
    expect(getUndelivered(db, 'codex-test')).toHaveLength(1)
    const result = await client.callTool({ name: 'send', arguments: { to: 'claude', text: 'reply' } })
    expect(result.isError).not.toBe(true)
    expect(getUndelivered(db, 'claude')[0].body).toBe('reply')
  } finally {
    await client.close()
    db.close()
    rmSync(dir, { recursive: true, force: true })
  }
}, 10_000)
