import { Server } from '@modelcontextprotocol/sdk/server/index.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} from '@modelcontextprotocol/sdk/types.js'
import { Database } from 'bun:sqlite'
import { homedir } from 'os'
import { join, basename } from 'path'
import { mkdirSync, writeFileSync } from 'fs'
import {
  initDb,
  getUndeliveredAlerts,
  markAlertDelivered,
  getAlert,
  getAlertHistory,
  ackAlert,
  setSilence,
  type Severity,
} from './db'
import { makeFetchHandler, type TelegramOutboxEntry } from './http'

// --- Identity (the consumer running this MCP server) ---

const projectDir = process.env.CLAUDE_PROJECT_DIR || process.cwd()
const identity = basename(projectDir)

// --- Paths ---

const dbDir = join(homedir(), '.claude', 'channels', 'squad-alerts')
mkdirSync(dbDir, { recursive: true })

const telegramOutbox = join(dbDir, 'telegram-outbox')
mkdirSync(telegramOutbox, { recursive: true })

const db = new Database(join(dbDir, 'queue.db'))
initDb(db)

process.stderr.write(`squad-alerts: started as consumer "${identity}"\n`)

// --- HTTP /publish endpoint (publisher-facing) ---

const HTTP_PORT = parseInt(process.env.SQUAD_ALERTS_HTTP_PORT || '5777', 10)
const SEVERITIES: Severity[] = ['info', 'warn', 'error', 'critical']

const httpServer = Bun.serve({
  port: HTTP_PORT,
  hostname: '127.0.0.1',
  fetch: makeFetchHandler({ db, telegramOutboxDir: telegramOutbox }),
})

process.stderr.write(`squad-alerts: HTTP listening on http://127.0.0.1:${httpServer.port}/publish\n`)

// --- Telegram outbox (file-drop for the escalate tool; auto-forwards
// from /publish go through makeFetchHandler's writeOutbox path). ---

function writeTelegramOutbox(entry: TelegramOutboxEntry): void {
  const fname = `${entry.ts.replace(/[:.]/g, '-')}_${entry.alert_id}_${entry.kind}.json`
  try {
    writeFileSync(join(telegramOutbox, fname), JSON.stringify(entry, null, 2))
  } catch (err) {
    process.stderr.write(`squad-alerts: failed to write telegram outbox: ${err}\n`)
  }
}

// --- MCP server (consumer-facing) ---

const mcp = new Server(
  { name: 'squad-alerts', version: '0.0.1' },
  {
    capabilities: {
      tools: {},
      experimental: { 'claude/channel': {} },
    },
    instructions: [
      `Operational alerts arrive as <channel source="squad-alerts" severity="..." publisher="..." source="..." message_id="..." ts="...">. `,
      `Use squad_alerts_ack to mark an alert handled by you, squad_alerts_escalate to forward to telegram for human attention, `,
      `squad_alerts_history to query past alerts, and squad_alerts_silence to suppress a flapping alert by dedup_key.`,
    ].join(''),
  },
)

mcp.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'squad_alerts_ack',
      description:
        'Mark an alert as acknowledged by this agent. Records who handled it and an optional note. Idempotent — second ack on the same alert returns already_acked.',
      inputSchema: {
        type: 'object' as const,
        properties: {
          id: { type: 'number', description: 'Alert id from the channel header message_id.' },
          note: { type: 'string', description: 'Optional disposition note.' },
        },
        required: ['id'],
      },
    },
    {
      name: 'squad_alerts_escalate',
      description:
        'Forward an alert to telegram for human attention. Optional body adds context to the forwarded message. Use when this agent cannot or should not handle the alert itself.',
      inputSchema: {
        type: 'object' as const,
        properties: {
          id: { type: 'number', description: 'Alert id to escalate.' },
          body: { type: 'string', description: 'Optional extra context to include in the telegram message.' },
        },
        required: ['id'],
      },
    },
    {
      name: 'squad_alerts_history',
      description:
        'Query past alerts with optional filters. Returns up to 50 (configurable) alert records, newest first.',
      inputSchema: {
        type: 'object' as const,
        properties: {
          publisher: { type: 'string', description: 'Filter by publisher name.' },
          source: { type: 'string', description: 'Filter by source. Supports trailing wildcard ("hermes:%").' },
          severity: { type: 'string', enum: SEVERITIES, description: 'Filter by severity.' },
          since: { type: 'string', description: 'ISO-8601 timestamp lower bound.' },
          limit: { type: 'number', description: 'Max results (1-500, default 50).' },
        },
      },
    },
    {
      name: 'squad_alerts_silence',
      description:
        'Suppress alerts with a given dedup_key until the supplied timestamp. Useful when actively debugging an alert source — alerts published with this dedup_key during the window are stored but not delivered to channel subscribers.',
      inputSchema: {
        type: 'object' as const,
        properties: {
          dedup_key: { type: 'string', description: 'The dedup_key to silence.' },
          until: { type: 'string', description: 'ISO-8601 timestamp; the silence expires at this point.' },
        },
        required: ['dedup_key', 'until'],
      },
    },
  ],
}))

mcp.setRequestHandler(CallToolRequestSchema, async (req) => {
  const args = (req.params.arguments ?? {}) as Record<string, unknown>
  try {
    switch (req.params.name) {
      case 'squad_alerts_ack': {
        const id = Number(args.id)
        const note = (args.note as string | undefined) ?? null
        if (!Number.isInteger(id) || id <= 0) {
          return { content: [{ type: 'text', text: 'invalid id' }], isError: true }
        }
        const alert = getAlert(db, id)
        if (!alert) {
          return { content: [{ type: 'text', text: `alert ${id} not found` }], isError: true }
        }
        const ok = ackAlert(db, id, identity, note)
        const msg = ok
          ? `acked alert ${id} (${alert.publisher}/${alert.source})`
          : `alert ${id} already acked by ${alert.ack_by ?? '?'} at ${alert.ack_at ?? '?'}`
        return { content: [{ type: 'text', text: msg }] }
      }

      case 'squad_alerts_escalate': {
        const id = Number(args.id)
        const body = (args.body as string | undefined) ?? ''
        if (!Number.isInteger(id) || id <= 0) {
          return { content: [{ type: 'text', text: 'invalid id' }], isError: true }
        }
        const alert = getAlert(db, id)
        if (!alert) {
          return { content: [{ type: 'text', text: `alert ${id} not found` }], isError: true }
        }
        const composedBody = body
          ? `${alert.body}\n\n---\n[escalated by ${identity}]\n${body}`
          : `${alert.body}\n\n[escalated by ${identity}]`
        writeTelegramOutbox({
          kind: 'escalate',
          alert_id: alert.id,
          prefix: `[ESCALATED:${alert.severity.toUpperCase()}]`,
          publisher: alert.publisher,
          source: alert.source,
          title: alert.title,
          body: composedBody,
          ts: new Date().toISOString(),
          escalated_by: identity,
          escalate_note: body || undefined,
        })
        return { content: [{ type: 'text', text: `escalated alert ${id} to telegram outbox` }] }
      }

      case 'squad_alerts_history': {
        const rows = getAlertHistory(db, {
          publisher: args.publisher as string | undefined,
          source: args.source as string | undefined,
          severity: args.severity as Severity | undefined,
          since: args.since as string | undefined,
          limit: typeof args.limit === 'number' ? (args.limit as number) : undefined,
        })
        const lines = rows.map((a) => {
          const ack = a.ack_at ? ` ack=${a.ack_by}@${a.ack_at}` : ''
          const sup = a.suppressed_at ? ' [suppressed]' : ''
          return `#${a.id} [${a.severity}] ${a.publisher}/${a.source} (${a.created_at})${sup}${ack}: ${a.title}`
        })
        return {
          content: [{ type: 'text', text: lines.join('\n') || 'no alerts match.' }],
        }
      }

      case 'squad_alerts_silence': {
        const dedup_key = String(args.dedup_key || '')
        const until = String(args.until || '')
        if (!dedup_key || !until) {
          return { content: [{ type: 'text', text: 'dedup_key and until are required' }], isError: true }
        }
        if (Number.isNaN(new Date(until).getTime())) {
          return { content: [{ type: 'text', text: 'until must be a valid ISO-8601 timestamp' }], isError: true }
        }
        setSilence(db, dedup_key, until, identity)
        return { content: [{ type: 'text', text: `silenced "${dedup_key}" until ${until} (by ${identity})` }] }
      }

      default:
        return {
          content: [{ type: 'text', text: `unknown tool: ${req.params.name}` }],
          isError: true,
        }
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    return { content: [{ type: 'text', text: `${req.params.name} failed: ${msg}` }], isError: true }
  }
})

// --- Push delivery loop (mirrors clod-squad pattern) ---

let polling = true

const pollInterval = setInterval(() => {
  if (!polling) return
  try {
    const alerts = getUndeliveredAlerts(db)
    for (const alert of alerts) {
      markAlertDelivered(db, alert.id)

      const meta: Record<string, string> = {
        severity: alert.severity,
        publisher: alert.publisher,
        source: alert.source,
        message_id: String(alert.id),
        ts: alert.created_at,
      }
      if (alert.target) meta.target = alert.target
      if (alert.related_bead) meta.related_bead = alert.related_bead
      if (alert.reply_via) meta.reply_via = alert.reply_via
      if (alert.dedup_key) meta.dedup_key = alert.dedup_key

      const content = `[${alert.title}] ${alert.body}`

      mcp
        .notification({
          method: 'notifications/claude/channel',
          params: { content, meta },
        })
        .catch((err) => {
          process.stderr.write(`squad-alerts: failed to deliver alert #${alert.id}: ${err}\n`)
        })
    }
  } catch (err) {
    process.stderr.write(`squad-alerts: poll error: ${err}\n`)
  }
}, 2000)

// --- Shutdown ---

let shuttingDown = false
function shutdown(): void {
  if (shuttingDown) return
  shuttingDown = true
  polling = false
  clearInterval(pollInterval)
  httpServer.stop(true)
  process.stderr.write('squad-alerts: shutting down\n')
  db.close()
  process.exit(0)
}

process.stdin.on('end', shutdown)
process.stdin.on('close', shutdown)
process.on('SIGTERM', shutdown)
process.on('SIGINT', shutdown)

process.on('unhandledRejection', (err) => {
  process.stderr.write(`squad-alerts: unhandled rejection: ${err}\n`)
})
process.on('uncaughtException', (err) => {
  process.stderr.write(`squad-alerts: uncaught exception: ${err}\n`)
})

// --- Connect ---

await mcp.connect(new StdioServerTransport())
