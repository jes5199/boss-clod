# Acceptance reservation readback — review stage

Request: boss-clod #38923; candidate `672cec4af4aab57217b87bd35ace5fc45b30c09f`, tree
`f5ea56a6a04be92de6e2c037bef3f04e7659e356`. No cloud requests have been executed for this packet.

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
owner/mode/symlink checks. No subprocess receives it. Redirects and environment proxies are disabled.
API responses may contain unrelated sensitive fields: raw bodies stay in memory and are never
written. Projection emits counts, fixed known control identifiers, verdicts, and a validated
public realm UUID only. Exceptions and HTTP error bodies are not emitted. Policy membership,
client IDs/secrets, credentials, capabilities, cookies, JWTs and arbitrary names are not recorded.

## Bounds, controls, and limitations

At most 10 pages per list, 100 rows/page, 1,000 total rows, 4 MiB/response, 15s/request and a
180s whole-run alarm. Missing/inconsistent pagination, duplicate IDs, unsupported match syntax,
missing controls, invalid schemas and failures all produce HOLD. Empty service-token lists
cannot provide a known-live positive control. The human-policy observation is application-local,
not proof about every policy. Wildcard host collisions are conservative; any path on the reserved
route host counts as collision. This is a point-in-time observation, not a provider lock or
atomic snapshot. Repeat before any separately authorized provisioning.

The candidate source must be the exact clean branch/commit/tree before and after reads. Output
uses exclusive creation and mode 0600, with a fixed HOLD exit code 2. The original reservation
is never overwritten. The configured 300s verifier limit is **not** a Cloudflare JWT lifetime
claim. No JWT acquisition or lifetime test is included.

Offline controls cover controlled absence/collision, wildcard paths, empty corpus, pagination
success/failures, account-control stop, secret/error canaries, public realm projection, secret
binding refusal, malformed URLs, redirect refusal, and fixed GET/no-body requests. Socket use
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
