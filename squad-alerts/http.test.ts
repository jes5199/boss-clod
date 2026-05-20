import { describe, test, expect, beforeEach } from 'bun:test'
import { Database } from 'bun:sqlite'
import { initDb, upsertPublisher, generateToken, getUndeliveredAlerts, setSilence } from './db'
import { makeFetchHandler, type TelegramOutboxEntry } from './http'

function freshDb(): Database {
  const db = new Database(':memory:')
  initDb(db)
  return db
}

interface Harness {
  db: Database
  token: string
  outbox: TelegramOutboxEntry[]
  fetch: (req: Request) => Promise<Response>
}

function harness(publisher = 'hermes'): Harness {
  const db = freshDb()
  const token = generateToken()
  upsertPublisher(db, publisher, token)
  const outbox: TelegramOutboxEntry[] = []
  const fetchHandler = makeFetchHandler({
    db,
    telegramOutboxDir: '/tmp/unused',
    writeOutbox: (e) => {
      outbox.push(e)
    },
  })
  return { db, token, outbox, fetch: fetchHandler }
}

function post(
  h: Harness,
  body: Record<string, unknown>,
  init: { auth?: string | null; json?: boolean } = {},
): Promise<Response> {
  const headers: Record<string, string> = {}
  if (init.auth !== null) headers['authorization'] = init.auth ?? `Bearer ${h.token}`
  if (init.json !== false) headers['content-type'] = 'application/json'
  return h.fetch(
    new Request('http://127.0.0.1/publish', {
      method: 'POST',
      headers,
      body: init.json === false ? (body as unknown as string) : JSON.stringify(body),
    }),
  )
}

const VALID_BODY = {
  publisher: 'hermes',
  severity: 'info',
  source: 'hermes:theta',
  title: 'recovery',
  body: 'restarted',
}

describe('GET /healthz', () => {
  test('returns 200 ok', async () => {
    const h = harness()
    const res = await h.fetch(new Request('http://127.0.0.1/healthz'))
    expect(res.status).toBe(200)
    expect(await res.text()).toBe('ok\n')
  })
})

describe('POST /publish — auth', () => {
  test('rejects missing Authorization', async () => {
    const h = harness()
    const res = await post(h, VALID_BODY, { auth: null })
    expect(res.status).toBe(401)
    const j = (await res.json()) as { error: string }
    expect(j.error).toBe('missing_bearer')
  })

  test('rejects malformed Authorization (no Bearer prefix)', async () => {
    const h = harness()
    const res = await post(h, VALID_BODY, { auth: 'whatever' })
    expect(res.status).toBe(401)
  })

  test('rejects wrong token', async () => {
    const h = harness()
    const res = await post(h, VALID_BODY, { auth: 'Bearer not-the-token' })
    expect(res.status).toBe(401)
    const j = (await res.json()) as { error: string }
    expect(j.error).toBe('unauthorized')
  })

  test('rejects token from a different publisher', async () => {
    const h = harness('hermes')
    upsertPublisher(h.db, 'commonplace', 'other-token')
    const res = await post(h, { ...VALID_BODY, publisher: 'commonplace' })
    // We supplied hermes's token but claimed publisher=commonplace.
    expect(res.status).toBe(401)
  })

  test('accepts correct token', async () => {
    const h = harness()
    const res = await post(h, VALID_BODY)
    expect(res.status).toBe(200)
    const j = (await res.json()) as { id: number; suppressed: boolean }
    expect(j.id).toBeGreaterThan(0)
    expect(j.suppressed).toBe(false)
  })
})

describe('POST /publish — validation', () => {
  test('rejects invalid JSON', async () => {
    const h = harness()
    const res = await h.fetch(
      new Request('http://127.0.0.1/publish', {
        method: 'POST',
        headers: { authorization: `Bearer ${h.token}`, 'content-type': 'application/json' },
        body: '{ not json',
      }),
    )
    expect(res.status).toBe(400)
  })

  test('rejects missing required fields', async () => {
    const h = harness()
    const required = ['publisher', 'severity', 'source', 'title', 'body']
    for (const k of required) {
      const body = { ...VALID_BODY } as Record<string, unknown>
      delete body[k]
      const res = await post(h, body)
      expect(res.status).toBe(400)
      const j = (await res.json()) as { error: string }
      expect(j.error).toBe(`missing_field:${k}`)
    }
  })

  test('rejects invalid severity', async () => {
    const h = harness()
    const res = await post(h, { ...VALID_BODY, severity: 'bogus' })
    expect(res.status).toBe(400)
    const j = (await res.json()) as { error: string }
    expect(j.error).toBe('invalid_severity')
  })

  test('accepts all four valid severities', async () => {
    const h = harness()
    for (const sev of ['info', 'warn', 'error', 'critical']) {
      const res = await post(h, { ...VALID_BODY, severity: sev })
      expect(res.status).toBe(200)
    }
  })
})

describe('POST /publish — routing', () => {
  test('info does NOT write to telegram outbox', async () => {
    const h = harness()
    await post(h, { ...VALID_BODY, severity: 'info' })
    expect(h.outbox).toHaveLength(0)
  })

  test('warn does NOT write to telegram outbox', async () => {
    const h = harness()
    await post(h, { ...VALID_BODY, severity: 'warn' })
    expect(h.outbox).toHaveLength(0)
  })

  test('error writes to telegram outbox with [ERROR] prefix', async () => {
    const h = harness()
    await post(h, { ...VALID_BODY, severity: 'error', title: 'auth gone', body: 'reauth needed' })
    expect(h.outbox).toHaveLength(1)
    expect(h.outbox[0].prefix).toBe('[ERROR]')
    expect(h.outbox[0].kind).toBe('auto')
    expect(h.outbox[0].title).toBe('auth gone')
  })

  test('critical writes to telegram outbox with [CRITICAL] prefix', async () => {
    const h = harness()
    await post(h, { ...VALID_BODY, severity: 'critical', title: 'panic' })
    expect(h.outbox).toHaveLength(1)
    expect(h.outbox[0].prefix).toBe('[CRITICAL]')
  })
})

describe('POST /publish — silences', () => {
  test('publishing with a silenced dedup_key returns suppressed=true', async () => {
    const h = harness()
    const until = new Date(Date.now() + 60_000).toISOString()
    setSilence(h.db, 'flap', until, 'tester')
    const res = await post(h, { ...VALID_BODY, dedup_key: 'flap' })
    expect(res.status).toBe(200)
    const j = (await res.json()) as { suppressed: boolean; silence_until: string }
    expect(j.suppressed).toBe(true)
    expect(j.silence_until).toBe(until)
    expect(getUndeliveredAlerts(h.db)).toHaveLength(0)
  })

  test('suppressed critical does NOT trigger telegram outbox', async () => {
    const h = harness()
    const until = new Date(Date.now() + 60_000).toISOString()
    setSilence(h.db, 'flap', until, 'tester')
    await post(h, { ...VALID_BODY, severity: 'critical', dedup_key: 'flap' })
    expect(h.outbox).toHaveLength(0)
  })
})

describe('routing — unknown paths', () => {
  test('GET /publish returns 404', async () => {
    const h = harness()
    const res = await h.fetch(new Request('http://127.0.0.1/publish'))
    expect(res.status).toBe(404)
  })

  test('POST /other returns 404', async () => {
    const h = harness()
    const res = await h.fetch(
      new Request('http://127.0.0.1/other', {
        method: 'POST',
        headers: { authorization: `Bearer ${h.token}` },
        body: '{}',
      }),
    )
    expect(res.status).toBe(404)
  })
})
