# Stored telemetry follow-up: HOLD

Boss request #38981, 2026-09-19. Offline source/documentation/receipt inspection only.
No live telemetry query, credential read, user export, raw-event dump, new diagnostic, or cloud write.
The collector and reservation remain held and unchanged.

**A minimal sanitized GET-only telemetry collector is not supportable on the inspected evidence.**
There are two independent blockers: the documented telemetry methods are POST, and no inspected
event proves the relationship between an admitted/configured human organization and the app's
provider realm. Do not rewrite a POST query as GET, infer authentication from a URL, or infer
realm binding from temporal proximity.

## API documentation available offline

Installed primary-provider SDK code and its API comments are embedded in
`/home/jes/commonplace-log/worker/node_modules/wrangler/wrangler-dist/cli.js:108955-109050`.
The bundle identifies its source as `cloudflare@5.2.0/.../workers/observability/telemetry.mjs`:

| Method | Exact API v4 path | Documented implementation |
|---|---|---|
| keys | `/accounts/{account_id}/workers/observability/telemetry/keys` | `getAPIList(..., {body, method: "post"})` |
| query | `/accounts/{account_id}/workers/observability/telemetry/query` | `_client.post(..., {body})`; described as running a temporary or saved query |
| values | `/accounts/{account_id}/workers/observability/telemetry/values` | `getAPIList(..., {body, method: "post"})` |

`getAPIList` is a pagination helper, **not evidence of HTTP GET**. These methods read telemetry,
but they do not meet GET-only scope. The local historical instruments
`cf-records/live-container-keys-1/query.py` and `cf-records/live-navigation-service-1/query.py`
also use POST with JSON bodies. No GET query endpoint or equivalent allowlisted field projection
is established by the inspected documentation. No online documentation was fetched under the
offline constraint; this is not a claim that no other endpoint exists anywhere in Cloudflare.

## Emitted schema and configuration

At acceptance source `0fdf8a1fe0ba747a491ed7dbd5de5ba2dbc93790`:

- `worker/src/authentication-diagnostic.js:3-24,45-49` has a closed failure vocabulary and emits
  `authentication_rejected_from_app` with stage, reason and status. It explicitly excludes raw
  identity and request identifiers. A rejection is not an admitted human identity.
- `worker/src/input-client-report.js:14-19` emits an authenticated tree-response client report,
  but `assets/src/input-report-schema.js:1-46` admits only version/timing, bounded event enums and
  booleans, and optional provider connection/save flags. There is no organization, realm, or
  cross-service correlation field. The source describes this as client-reported state, not a
  trusted account fact.
- `worker/src/outbound.js:20-34,49-80` builds the provider URL and installs realm capability in
  memory. It does not emit a realm identity or correlation event; errors return a fixed generic
  upstream-unavailable response. `worker/src/index.js` keeps storage endpoint/capability outside
  the container. The internal `storage.internal` hostname cannot identify the external realm.
- `worker/wrangler.jsonc:9-19` enables persistent logs, disables invocation logs and disables
  traces. The same settings were checked via local `git show` for recorded deployed human source
  `7eca4a26f5efb65faa67d9406c22e61a9454a66e`. Neither tracked configuration nor this old deployment
  mapping is a fresh readback of current settings. Do not infer that source flags prohibit every
  possible platform log, or that trace correlation was recorded.

## Stored evidence inspected, without printing events

`TELEMETRY-OFFLINE-38981.json` binds the exact files/source by SHA-256 and retains only counts.
The recursive offline scan counts key names containing organization/realm and string values
matching `/o/<coordinate>/` or `/realms/<hex-and-hyphen-id>`. It emits no coordinates, raw URLs,
headers, messages, tokens, or event payloads.

| Historical `cf-records/.../events-merged.json` | Records | Organization-route string occurrences | Realm-route occurrences | Named organization / realm fields |
|---|---:|---:|---:|---:|
| live-navigation-service-1 | 0 | 0 | 0 | 0 / 0 |
| live-typing-acks-1 | 2 | 3 | 0 | 0 / 0 |
| live-browser-typing-retrieve-1 | 1 | 0 | 0 | 0 / 0 |
| live-container-navigation-1 | 0 | 0 | 0 | 0 / 0 |

Occurrences may duplicate one event's coordinate; they are not distinct identities or evidence
of successful admission. These four files are a bounded historical sample, not an exhaustive
inventory of all retained telemetry. `live-container-keys-1/summary.json` separately records
22 metadata keys and zero container-related keys for its old interval. Neither an empty sample
nor a missing key proves global absence. None of these artifacts binds the two required facts.

## Decision and evidence/privacy limits

Return definitive **HOLD for this proposed GET-only collector and the current acceptance packet**.
No exact supported GET query or sufficient event schema exists in the inspected evidence, so no
collector or executable request is proposed. No telemetry permission expansion is requested.
The existing readback instrument must not treat a metadata service name, caller-supplied route,
account ID, or a registry realm key as the missing binding.

Only fixed file paths, source hashes, record counts, boolean methodology/state and the aggregate
counts above are retained in this research. Existing raw receipts were read locally, not copied,
printed, changed, or assigned a new retention policy. No fresh raw-event retention is introduced.
This artifact proves the bounded source/schema and sample findings; it cannot prove present-day
cloud settings, a human organization UUID, admission, the active realm, or complete log absence.
The historical human source defaults its organization to the non-UUID string `commonplace-next`;
that remains source-only context, not an accepted live comparator.

Resolving the blocker would require new evidence or a separately authorized observation design;
this research does not authorize either, and does not reopen user export, diagnostics, Access
bypass, secret inspection, runtime calls, or a live telemetry query.
