import { Server } from '@modelcontextprotocol/sdk/server/index.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} from '@modelcontextprotocol/sdk/types.js'
import { Database } from 'bun:sqlite'
import { homedir } from 'os'
import { join, basename } from 'path'

// A message older than this at DELIVERY time is labelled stale. Chosen
// against how this fleet actually behaves: workers restart, crash and
// compact regularly, and a message that waited out one of those describes
// a world that has moved on. Not a hard expiry — the recipient still gets
// it, and still decides. The point is that it cannot arrive looking fresh.
const STALE_AFTER_MINUTES = 30
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

      // jes 2026-08-07: "durable mail is actually kinda risky, old messages
      // pile up in a way that confused workers." A queued message is written
      // at one time and read at another; `ts` is the SENDER's stamp, and a
      // reader has to notice it is old. That is the failure we keep paying
      // for elsewhere — so compute the age HERE, at delivery, against the
      // reader's own clock, and label it rather than leaving it to be
      // inferred. A recipient that was offline for hours now sees
      // stale="true" instead of a timestamp it has to do arithmetic on.
      const ageMinutes = Math.max(
        0,
        Math.round((Date.now() - new Date(msg.created_at).getTime()) / 60000),
      )
      const meta: Record<string, string> = {
        from: msg.from_id,
        message_id: String(msg.id),
        ts: msg.created_at,
        age_minutes: String(ageMinutes),
      }
      if (ageMinutes >= STALE_AFTER_MINUTES) {
        meta.stale = 'true'
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
