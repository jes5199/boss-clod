# Acceptance reservation readback — review stage

Request: boss-clod #38923, review fixes #38949 and source update #38953;
candidate `282a6ca9bd8d8d5b11474ecafdf59692ef0c3bcf`, tree
`c447e8351c80f0f9ed4c0e4a49148c4831b389dd`. No cloud requests have been executed for this packet.

This instrument is deliberately incapable of returning overall GREEN. The human application
organization has no reviewed read-only live endpoint in the available instruments. Cloudflare's
account/Access team is not `CommonplaceNext.Organization`. Historical configuration and candidate
defaults are not live readbacks. The documented human realm binding is `secret_text`; Cloudflare
settings do not expose its value. Such a binding remains `REQUIRED_PENDING_READBACK`.
If the live settings instead return exactly one public `plain_text` realm URL with the strict
reviewed shape, only its UUID and collision boolean are retained. No secret-value endpoint,
custody binding file, application request, container exec, or realm data call is attempted.
Obtaining both missing live facts requires a separately reviewed safe observation surface;
this packet does not invent one or authorize deploying it.

## Endpoint and permission scope

All URLs are fixed HTTPS Cloudflare API v4 paths in `SPECS`. Every request is GET with no body:

| Surface | Fixed scope | Read capability required |
|---|---|---|
| Accounts | `/accounts` positive control for Commonplace Systems ID | account visibility |
| Zones | `/zones?account.id=d5c4856e9cb4dd41c12b39fb9df29726` | zone read |
| DNS | fixed commonplace.st zone `/dns_records` | DNS read |
| Routes | same zone `/workers/routes` | Worker routes read |
| Workers | fixed account `/workers/scripts` | Worker scripts read |
| Containers | fixed account `/containers/applications` | container applications read |
| Access apps | fixed account `/access/apps` | Access applications read |
| Policies | fixed human app `/policies` | Access policies read |
| Service tokens | fixed account `/access/service_tokens` | Access service tokens read |
| Human bindings | fixed Worker `commonplace-next/settings` | Worker settings read |

These are required functional capabilities, not a claim that the existing credential has them
or verified provider permission-label spelling. Missing permission produces HOLD. No permission
expansion is performed. Only the existing `do-worker.env` API token is read, in memory, after
regular-file/owner/mode checks on the same descriptor used for the bounded read. Opening uses
O_NOFOLLOW/O_NONBLOCK, and descriptor metadata is checked before/after reading. No subprocess
receives it. Redirects and environment proxies are disabled.
API responses may contain unrelated sensitive fields: raw bodies stay in memory and are never
written. Projection emits counts, fixed known control identifiers, verdicts, and a validated
public realm UUID only. Exceptions and HTTP error bodies are not emitted. Policy membership,
client IDs/secrets, credentials, capabilities, cookies, JWTs and arbitrary names are not recorded.

## Bounds, controls, and limitations

Accounts/Zones request and enforce 50 rows/page; other paginated lists request and enforce 100.
Worker Routes/Scripts are unpaginated lists: no pagination query or result_info requirement,
with an enforced 1,000-row bound. Paginated lists allow at most 10 pages and 1,000 total rows.
All responses have a 4 MiB bound, requests 15s timeout, and the run a 180s alarm.
Missing/inconsistent pagination on paginated endpoints, duplicate IDs, unsupported match syntax,
missing controls, invalid schemas and failures all produce HOLD. Empty service-token lists
cannot provide a known-live positive control. A missing positive control forces HOLD even when
the returned corpus has a reserved match; the match count is retained without a COLLISION verdict.
The human-policy observation is application-local,
not proof about every policy. Wildcard host collisions are conservative; any path on the reserved
route host counts as collision. This is a point-in-time observation, not a provider lock or
atomic snapshot. Repeat before any separately authorized provisioning.

The candidate source must be the exact clean branch/commit/tree before and after reads; status
explicitly requests all untracked files regardless of Git configuration. The entrypoint reads
the collector bytes once, hashes and compiles that same buffer, then runs that compiled payload.
The receipt retains this loaded hash and a separate post-run path hash; missing/changed post-run
bytes add HOLD_INSTRUMENT_DRIFT. Output
uses exclusive creation and mode 0600, with a fixed HOLD exit code 2. The original reservation
is never overwritten. The configured 300s verifier limit is **not** a Cloudflare JWT lifetime
claim. No JWT acquisition or lifetime test is included.

Offline controls cover controlled absence/collision, wildcard paths, empty corpus, pagination
success/failures, account-control stop, secret/error canaries, public realm projection, secret
binding refusal, malformed URLs, redirect refusal, actual opener handler wiring, endpoint query
limits, unpaginated lists, oversize pages, descriptor/path-swap/FIFO/symlink controls, explicit
untracked status, and loaded-byte/post-drift binding. Socket use
is blocked during controls.

```
PYTHONDONTWRITEBYTECODE=1 python3 tools/acceptance-readback/test_readback.py
```

After separate read-execution review only (NOT executed for this delivery):

```
python3 tools/acceptance-readback/readback.py --execute-reads --output cf-records/acceptance-readback-UNIQUE.json
```

Even a successful collection exits HOLD because the human organization readback is unresolved.
The flag is an execution guard, not authorization. Cloud mutation remains held.
