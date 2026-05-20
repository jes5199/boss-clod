# squad-alerts

Fleet-wide operational alerts MCP channel. Modeled on `~/boss-clod/clod-squad/`.

Publishers POST to a local HTTP endpoint; consumers receive alerts as `<channel source="squad-alerts" ...>` blocks in their Claude Code session and can `ack`, `escalate`, `history`, or `silence` via MCP tools.

## Layout

```
db.ts            SQLite schema + queries (publishers, alerts, silences)
http.ts          HTTP fetch handler — POST /publish, GET /healthz
server.ts        Bun MCP server + Bun.serve HTTP + push delivery loop
new-token.ts     CLI: provision/rotate a publisher's bearer token
*.test.ts        bun:test
```

## Runtime state

```
~/.claude/channels/squad-alerts/
  queue.db                 SQLite WAL
  telegram-outbox/         JSON files boss-clod's forwarder picks up
```

## Operation

### Provision a publisher

```
bun run new-token hermes
```

The 32-byte token is printed to stdout once. Store it in the publisher's env
(`SQUAD_ALERTS_PUBLISHER_TOKEN`). Re-running rotates: prior tokens stop working.

The 5 canonical publishers per HERMES-6e1u are `hermes`, `commonplace`,
`dirigible`, `boss-clod`, `workspace` — but `new-token` accepts any name
matching `^[a-z0-9][a-z0-9-]{0,63}$`.

### Publish an alert

```
curl -X POST http://127.0.0.1:5777/publish \
  -H "Authorization: Bearer $SQUAD_ALERTS_PUBLISHER_TOKEN" \
  -H "content-type: application/json" \
  -d '{
    "publisher": "hermes",
    "severity": "warn",
    "source": "hermes:theta_watchdog",
    "title": "Theta recovered",
    "body": "killed pid 96692, restart probe 70ms",
    "related_bead": "HERMES-45zj",
    "dedup_key": "theta-recovery-2026-05-20",
    "reply_via": "bead"
  }'
```

Response: `{"id": <n>, "suppressed": <bool>, "silence_until": <iso|null>}`.

### Consumer MCP tools

- `squad_alerts_ack(id, note?)` — first ack wins; second returns
  `already_acked`. Records the acking consumer's identity.
- `squad_alerts_escalate(id, body?)` — writes a JSON entry to
  `telegram-outbox/`. boss-clod's forwarder is expected to pick it up and
  reply via the telegram MCP.
- `squad_alerts_history(filter?)` — newest-first, up to 500 entries.
  Filters: publisher, source (prefix), severity, since, limit.
- `squad_alerts_silence(dedup_key, until)` — suppresses subsequent publishes
  with this dedup_key until `until` (ISO-8601). Alerts that would have been
  delivered are stored with `suppressed_at` set and never fan out.

## Severity routing

| severity | channel push | telegram outbox auto-write |
|---------:|:------------:|:--------------------------:|
| info     | ✓            |                            |
| warn     | ✓            |                            |
| error    | ✓            | `[ERROR]`                  |
| critical | ✓            | `[CRITICAL]`               |

A silenced dedup_key skips BOTH paths — the alert is stored with
`suppressed_at` set and neither channel-pushed nor outbox-written.

## Failure mode

If a publisher's POST fails entirely (server down, network), the publisher's
client library is expected to fall back to telegram directly with a
`[FALLBACK]` prefix. The server doesn't try to recover dropped publishes;
its responsibility starts at "POST succeeded."

## Channel three-piece (other beads)

This repo holds piece (2). The other two are owned elsewhere:

- HERMES-7bx4: `~/.claude/plugins/squad-alerts/` channel plugin
- HERMES-x5pn: `~/.claude/channels/squad-alerts/mcp-config-*.json`
- HERMES-2o2g: workerclaude launch script update
- HERMES-i82b: per-agent token provisioning
- HERMES-2w2w: E2E test

## Tests

```
cd ~/boss-clod/squad-alerts && bun test
```
