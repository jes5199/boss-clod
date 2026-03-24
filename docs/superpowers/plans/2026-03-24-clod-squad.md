# clod-squad Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code channel plugin that enables bidirectional messaging between Claude instances via a shared SQLite database.

**Architecture:** Single shared SQLite DB (`~/.claude/channels/clod-squad/queue.db`) in WAL mode. Each Claude instance runs the plugin, which polls the DB every 2 seconds for new messages and surfaces them as `<channel>` notifications. Identity is derived from project directory basename. MCP tools (`send`, `list_peers`, `read_history`, `broadcast`) provide the outbound interface.

**Tech Stack:** Bun runtime, `bun:sqlite` (built-in), `@modelcontextprotocol/sdk`, TypeScript

**Spec:** `docs/superpowers/specs/2026-03-24-clod-squad-design.md`

**Reference implementation:** `~/.claude/plugins/cache/claude-plugins-official/telegram/0.0.4/server.ts`

---

## File Structure

```
clod-squad/
  .claude-plugin/
    plugin.json          # Plugin metadata
  .mcp.json              # MCP server launch config
  package.json           # Dependencies and scripts
  db.ts                  # SQLite operations (init, identity, messages)
  db.test.ts             # Unit tests for DB layer
  server.ts              # MCP server, tools, polling loop
  server.test.ts         # Integration tests for MCP server
```

**`db.ts`** — Pure data layer. Exports functions for schema migration, identity registration/pruning, message insert/query/deliver. All functions take a `Database` instance as first argument for testability (tests use in-memory `:memory:` DBs).

**`server.ts`** — MCP wiring. Instantiates the Server, registers tool handlers that call into `db.ts`, runs the polling loop, manages lifecycle. This is the entry point (`bun server.ts`).

---

### Task 1: Plugin Scaffolding

**Files:**
- Create: `clod-squad/.claude-plugin/plugin.json`
- Create: `clod-squad/.mcp.json`
- Create: `clod-squad/package.json`

- [ ] **Step 1: Create plugin.json**

```json
{
  "name": "clod-squad",
  "description": "Channel plugin for inter-Claude communication via shared SQLite queue",
  "version": "0.0.1",
  "keywords": ["channel", "coordination", "messaging", "mcp"]
}
```

- [ ] **Step 2: Create .mcp.json**

```json
{
  "mcpServers": {
    "clod-squad": {
      "command": "bun",
      "args": ["run", "--cwd", "${CLAUDE_PLUGIN_ROOT}", "--shell=bun", "--silent", "start"]
    }
  }
}
```

- [ ] **Step 3: Create package.json**

```json
{
  "name": "clod-squad",
  "version": "0.0.1",
  "type": "module",
  "bin": "./server.ts",
  "scripts": {
    "start": "bun install --no-summary && bun server.ts",
    "test": "bun test"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0"
  }
}
```

- [ ] **Step 4: Install dependencies**

Run: `cd clod-squad && bun install`
Expected: `bun.lock` created, `node_modules/` populated

- [ ] **Step 5: Commit**

```bash
git add clod-squad/
git commit -m "feat: scaffold clod-squad plugin structure"
```

---

### Task 2: Database Layer — Schema and Identity

**Files:**
- Create: `clod-squad/db.ts`
- Create: `clod-squad/db.test.ts`

- [ ] **Step 1: Write failing tests for DB init and identity**

In `clod-squad/db.test.ts`:

```typescript
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd clod-squad && bun test db.test.ts`
Expected: FAIL — `./db` module not found

- [ ] **Step 3: Implement DB init and identity functions**

In `clod-squad/db.ts`:

```typescript
import { Database } from 'bun:sqlite'

export function initDb(db: Database): void {
  db.exec('PRAGMA journal_mode=WAL')
  db.exec('PRAGMA foreign_keys=ON')

  db.exec(`
    CREATE TABLE IF NOT EXISTS identities (
      name TEXT PRIMARY KEY,
      full_path TEXT NOT NULL UNIQUE,
      last_seen_at TEXT,
      registered_at TEXT NOT NULL
    )
  `)

  db.exec(`
    CREATE TABLE IF NOT EXISTS messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      from_id TEXT NOT NULL REFERENCES identities(name),
      to_id TEXT NOT NULL REFERENCES identities(name),
      body TEXT NOT NULL,
      metadata TEXT,
      created_at TEXT NOT NULL,
      delivered_at TEXT
    )
  `)

  db.exec(`
    CREATE INDEX IF NOT EXISTS idx_messages_to_undelivered
      ON messages(to_id, delivered_at)
      WHERE delivered_at IS NULL
  `)
}

export interface Identity {
  name: string
  full_path: string
  last_seen_at: string
  registered_at: string
}

export function registerIdentity(db: Database, name: string, fullPath: string): void {
  const existing = db.query('SELECT full_path FROM identities WHERE name = ?').get(name) as { full_path: string } | null

  if (existing && existing.full_path !== fullPath) {
    throw new Error(
      `Identity collision: "${name}" is already registered to ${existing.full_path} (you are ${fullPath})`
    )
  }

  const now = new Date().toISOString()
  db.run(
    `INSERT INTO identities (name, full_path, last_seen_at, registered_at)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(name) DO UPDATE SET last_seen_at = ?`,
    [name, fullPath, now, now, now]
  )
}

export function listIdentities(db: Database): Identity[] {
  return db.query('SELECT * FROM identities ORDER BY name').all() as Identity[]
}

export function updateLastSeen(db: Database, name: string): void {
  db.run('UPDATE identities SET last_seen_at = ? WHERE name = ?', [new Date().toISOString(), name])
}

export function pruneStaleIdentities(db: Database): void {
  const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()
  db.run('DELETE FROM identities WHERE last_seen_at < ?', [cutoff])
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd clod-squad && bun test db.test.ts`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add clod-squad/db.ts clod-squad/db.test.ts
git commit -m "feat: add DB layer with schema init and identity management"
```

---

### Task 3: Database Layer — Message Operations

**Files:**
- Modify: `clod-squad/db.ts`
- Modify: `clod-squad/db.test.ts`

- [ ] **Step 1: Write failing tests for message operations**

Append to `clod-squad/db.test.ts`:

```typescript
import { insertMessage, getUndelivered, markDelivered, getHistory } from './db'

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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd clod-squad && bun test db.test.ts`
Expected: FAIL — functions not exported from `./db`

- [ ] **Step 3: Implement message functions**

Add to `clod-squad/db.ts`:

```typescript
export interface Message {
  id: number
  from_id: string
  to_id: string
  body: string
  metadata: string | null
  created_at: string
  delivered_at: string | null
}

export function insertMessage(
  db: Database,
  fromId: string,
  toId: string,
  body: string,
  metadata?: Record<string, unknown>,
): number {
  const recipient = db.query('SELECT name FROM identities WHERE name = ?').get(toId)
  if (!recipient) {
    throw new Error(`Recipient "${toId}" not found. Use list_peers to see registered identities.`)
  }

  const result = db.run(
    `INSERT INTO messages (from_id, to_id, body, metadata, created_at)
     VALUES (?, ?, ?, ?, ?)`,
    [fromId, toId, body, metadata ? JSON.stringify(metadata) : null, new Date().toISOString()]
  )
  return Number(result.lastInsertRowid)
}

export function getUndelivered(db: Database, toId: string): Message[] {
  return db.query(
    'SELECT * FROM messages WHERE to_id = ? AND delivered_at IS NULL ORDER BY id'
  ).all(toId) as Message[]
}

export function markDelivered(db: Database, messageId: number): void {
  db.run('UPDATE messages SET delivered_at = ? WHERE id = ?', [new Date().toISOString(), messageId])
}

export function getHistory(db: Database, peer1: string, peer2: string, limit: number): Message[] {
  return db.query(
    `SELECT * FROM (
       SELECT * FROM messages
       WHERE (from_id = ?1 AND to_id = ?2) OR (from_id = ?2 AND to_id = ?1)
       ORDER BY id DESC
       LIMIT ?3
     ) sub ORDER BY id ASC`,
  ).all(peer1, peer2, limit) as Message[]
}

export function isOnline(identity: Identity): boolean {
  if (!identity.last_seen_at) return false
  const lastSeen = new Date(identity.last_seen_at).getTime()
  return Date.now() - lastSeen < 30_000
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd clod-squad && bun test db.test.ts`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add clod-squad/db.ts clod-squad/db.test.ts
git commit -m "feat: add message insert, query, deliver, and history"
```

---

### Task 4: MCP Server Skeleton

**Files:**
- Create: `clod-squad/server.ts`

- [ ] **Step 1: Create server.ts with MCP server, tool definitions, and lifecycle**

```typescript
import { Server } from '@modelcontextprotocol/sdk/server/index.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} from '@modelcontextprotocol/sdk/types.js'
import { Database } from 'bun:sqlite'
import { homedir } from 'os'
import { join, basename } from 'path'
import { mkdirSync } from 'fs'
import {
  initDb,
  registerIdentity,
  listIdentities,
  updateLastSeen,
  pruneStaleIdentities,
  insertMessage,
  getUndelivered,
  markDelivered,
  getHistory,
  isOnline,
} from './db'

// --- Identity ---

const projectDir = process.env.CLAUDE_PROJECT_DIR || process.cwd()
const identity = basename(projectDir)
const fullPath = projectDir

// --- Database ---

const dbDir = join(homedir(), '.claude', 'channels', 'clod-squad')
mkdirSync(dbDir, { recursive: true })
const db = new Database(join(dbDir, 'queue.db'))
initDb(db)
pruneStaleIdentities(db)
registerIdentity(db, identity, fullPath)

process.stderr.write(`clod-squad: registered as "${identity}" (${fullPath})\n`)

// --- MCP Server ---

const mcp = new Server(
  { name: 'clod-squad', version: '0.0.1' },
  {
    capabilities: {
      tools: {},
      experimental: {
        'claude/channel': {},
      },
    },
    instructions: [
      `Messages from other Claude instances arrive as <channel source="clod-squad" from="..." message_id="...">. Reply with the send tool. Use list_peers to see who's online.`,
    ].join('\n'),
  },
)

// --- Tools ---

mcp.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'send',
      description: 'Send a message to another Claude instance.',
      inputSchema: {
        type: 'object' as const,
        properties: {
          to: { type: 'string', description: 'Recipient identity name' },
          text: { type: 'string', description: 'Message body' },
          metadata: {
            type: 'object',
            description: 'Optional structured fields (priority, tags, etc.)',
          },
        },
        required: ['to', 'text'],
      },
    },
    {
      name: 'list_peers',
      description: 'List all registered Claude instances with online/offline status.',
      inputSchema: { type: 'object' as const, properties: {} },
    },
    {
      name: 'read_history',
      description: 'Read past messages between you and a peer.',
      inputSchema: {
        type: 'object' as const,
        properties: {
          peer: { type: 'string', description: 'Peer identity name' },
          limit: { type: 'number', description: 'Max messages (default 20)' },
        },
        required: ['peer'],
      },
    },
    {
      name: 'broadcast',
      description: 'Send a message to all registered peers.',
      inputSchema: {
        type: 'object' as const,
        properties: {
          text: { type: 'string', description: 'Message body' },
          metadata: {
            type: 'object',
            description: 'Optional structured fields (priority, tags, etc.)',
          },
        },
        required: ['text'],
      },
    },
  ],
}))

mcp.setRequestHandler(CallToolRequestSchema, async (req) => {
  const args = (req.params.arguments ?? {}) as Record<string, unknown>
  try {
    switch (req.params.name) {
      case 'send': {
        const to = args.to as string
        const text = args.text as string
        const metadata = args.metadata as Record<string, unknown> | undefined

        const id = insertMessage(db, identity, to, text, metadata)
        const peer = listIdentities(db).find(i => i.name === to)
        const status = peer && isOnline(peer) ? 'online' : 'offline (queued)'

        return {
          content: [{ type: 'text', text: `Sent message #${id} to ${to} [${status}]` }],
        }
      }

      case 'list_peers': {
        const peers = listIdentities(db)
        const lines = peers.map(p => {
          const status = isOnline(p) ? 'online' : 'offline'
          const self = p.name === identity ? ' (you)' : ''
          return `${p.name}${self}: ${status} (last seen: ${p.last_seen_at})`
        })
        return {
          content: [{ type: 'text', text: lines.join('\n') || 'No peers registered.' }],
        }
      }

      case 'read_history': {
        const peer = args.peer as string
        const limit = (args.limit as number) ?? 20
        const msgs = getHistory(db, identity, peer, limit)
        const lines = msgs.map(m => {
          const dir = m.from_id === identity ? `→ ${m.to_id}` : `← ${m.from_id}`
          const meta = m.metadata ? ` [${m.metadata}]` : ''
          return `#${m.id} ${dir} (${m.created_at})${meta}: ${m.body}`
        })
        return {
          content: [{ type: 'text', text: lines.join('\n') || 'No messages found.' }],
        }
      }

      case 'broadcast': {
        const text = args.text as string
        const metadata = args.metadata as Record<string, unknown> | undefined
        const peers = listIdentities(db).filter(p => p.name !== identity)

        if (peers.length === 0) {
          return { content: [{ type: 'text', text: 'No peers to broadcast to.' }] }
        }

        let onlineCount = 0
        let offlineCount = 0
        for (const peer of peers) {
          insertMessage(db, identity, peer.name, text, metadata)
          if (isOnline(peer)) onlineCount++
          else offlineCount++
        }

        return {
          content: [{
            type: 'text',
            text: `Broadcast to ${peers.length} peers: ${onlineCount} online, ${offlineCount} offline (queued)`,
          }],
        }
      }

      default:
        return {
          content: [{ type: 'text', text: `Unknown tool: ${req.params.name}` }],
          isError: true,
        }
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    return {
      content: [{ type: 'text', text: `${req.params.name} failed: ${msg}` }],
      isError: true,
    }
  }
})

// --- Polling Loop ---

let polling = true

const pollInterval = setInterval(() => {
  if (!polling) return
  try {
    const messages = getUndelivered(db, identity)
    for (const msg of messages) {
      markDelivered(db, msg.id)

      const meta: Record<string, string> = {
        from: msg.from_id,
        message_id: String(msg.id),
        ts: msg.created_at,
      }

      // Spread metadata fields into meta attributes
      if (msg.metadata) {
        try {
          const parsed = JSON.parse(msg.metadata) as Record<string, unknown>
          for (const [k, v] of Object.entries(parsed)) {
            if (typeof v === 'string' || typeof v === 'number' || typeof v === 'boolean') {
              meta[k] = String(v)
            }
          }
        } catch {}
      }

      mcp.notification({
        method: 'notifications/claude/channel',
        params: { content: msg.body, meta },
      }).catch(err => {
        process.stderr.write(`clod-squad: failed to deliver message #${msg.id}: ${err}\n`)
      })
    }
    updateLastSeen(db, identity)
  } catch (err) {
    process.stderr.write(`clod-squad: poll error: ${err}\n`)
  }
}, 2000)

// --- Shutdown ---

let shuttingDown = false
function shutdown(): void {
  if (shuttingDown) return
  shuttingDown = true
  polling = false
  clearInterval(pollInterval)
  process.stderr.write('clod-squad: shutting down\n')
  db.close()
  process.exit(0)
}

process.stdin.on('end', shutdown)
process.stdin.on('close', shutdown)
process.on('SIGTERM', shutdown)
process.on('SIGINT', shutdown)

process.on('unhandledRejection', err => {
  process.stderr.write(`clod-squad: unhandled rejection: ${err}\n`)
})
process.on('uncaughtException', err => {
  process.stderr.write(`clod-squad: uncaught exception: ${err}\n`)
})

// --- Connect ---

await mcp.connect(new StdioServerTransport())
```

- [ ] **Step 2: Verify server starts without errors**

Run: `cd clod-squad && echo '{}' | timeout 3 bun server.ts 2>&1 || true`
Expected: stderr shows `clod-squad: registered as "clod-squad"` then shuts down on stdin EOF

- [ ] **Step 3: Commit**

```bash
git add clod-squad/server.ts
git commit -m "feat: add MCP server with tools and polling loop"
```

---

### Task 5: Integration Tests

**Files:**
- Create: `clod-squad/server.test.ts`

- [ ] **Step 1: Write integration tests**

These tests verify the tools work end-to-end through a real DB (in-memory is not possible here since the server opens its own DB — so we test the DB functions directly in more complex scenarios, and verify the server process starts cleanly).

```typescript
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
```

- [ ] **Step 2: Run all tests**

Run: `cd clod-squad && bun test`
Expected: All tests in both db.test.ts and server.test.ts PASS

- [ ] **Step 3: Commit**

```bash
git add clod-squad/server.test.ts
git commit -m "test: add integration tests for message flow"
```

---

### Task 6: Smoke Test — Server Process

**Files:**
- No new files — manual verification

- [ ] **Step 1: Verify server starts and registers identity**

Run: `cd clod-squad && echo '{}' | CLAUDE_PROJECT_DIR=/home/jes/test-project timeout 3 bun server.ts 2>&1 || true`
Expected: stderr includes `clod-squad: registered as "test-project"`

- [ ] **Step 2: Verify DB was created**

Run: `ls -la ~/.claude/channels/clod-squad/queue.db`
Expected: File exists

- [ ] **Step 3: Verify identity is in the DB**

Run: `sqlite3 ~/.claude/channels/clod-squad/queue.db "SELECT * FROM identities"`
Expected: Shows the registered identity row(s)

- [ ] **Step 4: Clean up test data**

Run: `rm ~/.claude/channels/clod-squad/queue.db`

- [ ] **Step 5: Commit (no changes needed, but verify all tests still pass)**

Run: `cd clod-squad && bun test`
Expected: All tests PASS
