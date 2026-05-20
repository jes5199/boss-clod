import { Database } from 'bun:sqlite'
import { writeFileSync } from 'fs'
import { join } from 'path'
import { verifyPublisher, insertAlert, type Severity } from './db'

const SEVERITIES: Severity[] = ['info', 'warn', 'error', 'critical']

export interface PublishBody {
  publisher: string
  severity: Severity
  source: string
  title: string
  body: string
  target?: string | null
  related_bead?: string | null
  dedup_key?: string | null
  reply_via?: string | null
}

export interface TelegramOutboxEntry {
  kind: 'auto' | 'escalate'
  alert_id: number
  prefix: string
  publisher: string
  source: string
  title: string
  body: string
  ts: string
  escalated_by?: string
  escalate_note?: string
}

export interface FetchHandlerDeps {
  db: Database
  telegramOutboxDir: string
  /** Override for tests; defaults to writeFileSync. */
  writeOutbox?: (entry: TelegramOutboxEntry) => void
}

export function parseBearer(req: Request): string | null {
  const h = req.headers.get('authorization') || req.headers.get('Authorization')
  if (!h) return null
  const m = /^Bearer\s+(.+)$/i.exec(h.trim())
  return m ? m[1].trim() : null
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  })
}

function defaultWriteOutbox(dir: string): (entry: TelegramOutboxEntry) => void {
  return (entry) => {
    const fname = `${entry.ts.replace(/[:.]/g, '-')}_${entry.alert_id}_${entry.kind}.json`
    writeFileSync(join(dir, fname), JSON.stringify(entry, null, 2))
  }
}

export function makeFetchHandler(deps: FetchHandlerDeps): (req: Request) => Promise<Response> {
  const writeOutbox = deps.writeOutbox ?? defaultWriteOutbox(deps.telegramOutboxDir)

  return async (req: Request) => {
    const url = new URL(req.url)

    if (req.method === 'GET' && url.pathname === '/healthz') {
      return new Response('ok\n')
    }
    if (req.method !== 'POST' || url.pathname !== '/publish') {
      return json({ error: 'not_found' }, 404)
    }

    const token = parseBearer(req)
    if (!token) return json({ error: 'missing_bearer' }, 401)

    let payload: PublishBody
    try {
      payload = (await req.json()) as PublishBody
    } catch {
      return json({ error: 'invalid_json' }, 400)
    }

    const required = ['publisher', 'severity', 'source', 'title', 'body'] as const
    for (const k of required) {
      if (typeof payload[k] !== 'string' || !payload[k]) {
        return json({ error: `missing_field:${k}` }, 400)
      }
    }
    if (!SEVERITIES.includes(payload.severity)) {
      return json({ error: 'invalid_severity' }, 400)
    }
    if (!verifyPublisher(deps.db, payload.publisher, token)) {
      return json({ error: 'unauthorized' }, 401)
    }

    const result = insertAlert(deps.db, payload)

    if (!result.suppressed && (payload.severity === 'error' || payload.severity === 'critical')) {
      try {
        writeOutbox({
          kind: 'auto',
          alert_id: result.id,
          prefix: payload.severity === 'critical' ? '[CRITICAL]' : '[ERROR]',
          publisher: payload.publisher,
          source: payload.source,
          title: payload.title,
          body: payload.body,
          ts: new Date().toISOString(),
        })
      } catch (err) {
        // Outbox failure is observability-only; the alert is already
        // stored + will deliver via the channel. Log and continue.
        process.stderr.write(`squad-alerts: outbox write failed for alert #${result.id}: ${err}\n`)
      }
    }

    return json({ id: result.id, suppressed: result.suppressed, silence_until: result.silence_until })
  }
}
