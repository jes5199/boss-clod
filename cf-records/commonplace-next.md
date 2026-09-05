# commonplace-next — Cloudflare Worker (CREATE-NEW, first deploy pending)

**Record opened 2026-09-05T19:27Z by boss-clod. No Worker of this name exists on the account yet.**
**Source of truth for the first deploy: EXACT `a538fa18ccfc5ab50fd9adcf1a69dfa75c08d616`, no local overlay** (ranking
seat ruling msg 30264, and verified by me from a fresh clone at that sha).

## THE EGRESS FENCE IS IN CODE, NOT IN `wrangler.jsonc` — do not go looking for it in the wrong file
```
worker/src/index.js:11   enableInternet = false;
worker/src/index.js:12   interceptHttps = true;
worker/src/index.js:31   CommonplaceNextContainer.outboundByHost = { … }   ← static storage handler
worker/src/index.js:35   CommonplaceNextContainer.outbound = identityOutbound   ← default identity egress
worker/wrangler.jsonc:5  "workers_dev": false      :6 "preview_urls": false      :29 "max_instances": 1
```
⚠️ **I nearly reported the fence ABSENT because `enableInternet` does not appear in `wrangler.jsonc`.** It is a
class property on the Container subclass. **Absence of a property from the config file is not absence of the
fence.** (seat, 30264 — and I verified the lines above myself before writing this.)

## THE FULL BINDING SET — TEN NAMES, NOT THREE. Verified present in `worker/src/*.js` at `a538fa18`, with control.
```
SECRET_KEY_BASE                    1 ref     ┐
COMMONPLACE_ACCESS_ISSUER          2 refs    │ the original five (SECRET_KEY_BASE + four Access)
COMMONPLACE_ACCESS_AUDIENCE        1 ref     │
COMMONPLACE_ACCESS_JWKS_URI        2 refs    │
COMMONPLACE_ACCESS_ROSTER          1 ref     ┘
WORKOS_CLIENT_ID                   4 refs    ┐
WORKOS_API_KEY                     2 refs    │ the three WorkOS (the 5-var blocker, now forwarded in source)
WORKOS_REDIRECT_URI                1 ref     ┘
COMMONPLACE_LOG_REALM_URL          3 refs    ┐ Worker-only, PAIRED — the real store. ⛔ a URL without its
COMMONPLACE_LOG_REALM_CAPABILITY   1 ref     ┘ capability, or vice versa, is a half-configured store.
CONTROL  COMMONPLACE_NO_SUCH_VAR   0 refs    ← the grep is not answering "present" to everything
ERL_AFLAGS                         fixed IN CODE (index.js:18), points cacerts_path at the Cloudflare container CA
```
⛔ **I told the seat "three WorkOS secrets" as if that were the set. It is TEN bindings, two of them a PAIR.**
**A deploy that sets three and boots gets a `SECRET_KEY_BASE` refusal in `runtime.exs` — before application
start — and a naive reading calls that "the container is broken."**
⭐ **Custody: SECRET-class values (SECRET_KEY_BASE, WORKOS_API_KEY, COMMONPLACE_LOG_REALM_CAPABILITY, and the
Access ROSTER if it is a credential) go by stdin-to-secret from 600-mode files. Never echoed, never in argv.**

## ORDER OF ACTS (nothing below has happened)
① image built from clean pinned `a538fa18`; COPY inputs enumerated SEPARATELY from the landing range; no claim
   that anything was previously registry-pushed · ② create Worker; `workers_dev`/`preview_urls` false BEFORE
   it serves · ③ ALL TEN bindings, paired ones together · ④ readiness by MEASUREMENT — ⛔ do not predict
   "Access verified" before it is measured; the canonical parser may refuse · ⑤ route `6a26c1fc…` one field ·
   ⑥ receipt: TARGET · APP SHA · WORKER SHA · RANGE · ROLLBACK, image identity distinct.
⭐ **Milestone semantics (seat):** once real Access + editor + store pass, the SEPARATE known WorkOS-cache
failure does NOT block the internal-Access milestone. It blocks external login, which is a different journey.

## CUSTODY RULING FOR THE TEN BINDINGS (ranking seat msg 30267, 2026-09-05T19:27Z) — FOLLOW THIS, NOT MY DRAFT
```
secret_text   WORKOS_CLIENT_ID · WORKOS_API_KEY · WORKOS_REDIRECT_URI     ← ALL THREE, from the existing
              protected file. Client ID and redirect are not inherently secrets, but changing their
              handling buys nothing and diverges from the recorded custody choice.
secret_text   SECRET_KEY_BASE · COMMONPLACE_LOG_REALM_CAPABILITY · COMMONPLACE_ACCESS_ROSTER
              ← roster is sensitive membership config; "is it a credential" is not a question to decide.
plain var     COMMONPLACE_ACCESS_ISSUER · _AUDIENCE · _JWKS_URI · COMMONPLACE_LOG_REALM_URL
              ⛔ ONLY AFTER CHECKING each URL is credential-free: no bearer, no query secret, no userinfo.
              ⛔ realm URL stays PAIRED with the correct capability.
NEVER print a secret value. Anywhere.
```
⭐ **The seat's reasoning on the WorkOS three is the keeper: consistency with a recorded custody choice
outranks a per-value argument about which ones "really" need protecting.** A mixed scheme is a scheme
someone later has to reason about; a uniform one is not.

## ①+② EXECUTED 2026-09-05T20:05Z — CREATE, from EXACT a538fa18. NOTHING USER-VISIBLE CHANGED.
```
TARGET      commonplace-next Worker (CREATE — no prior script) · route 6a26c1fc UNTOUCHED (still → commonplace-beta)
APP SHA     a538fa18ccfc5ab50fd9adcf1a69dfa75c08d616   tree 3c3828229ea4604d26b2d0036d4f2975b4e1a3d6
WORKER SHA  version eab9c341-5678-403c-af10-b97707d37726
            image commonplace-next@sha256:299207be0c8b7d4a1e7b3adc2b58c9ce553a2cf21dccdbb1062ced0ceeaf3537 (tag eab9c341)
            container app a03286c5-d425-45b6-8d23-6c9a450b6bfb · instances 0 / max 1 · DO ns 581ccdd5223f4adeb4b4175b5759e363
RANGE       94abc915..a538fa18 (7 commits + the merge). ⛔ IMAGE INPUTS ARE A DIFFERENT OBJECT:
            COPY set = mix.exs 06a855d8 · mix.lock 29d61e15 · config c028506a · lib ffc53b5f · priv a3360df2
            + deps/ 34 dirs fetched --only prod on the host (identity = mix.lock + fetched set)
            Pins IN the image: yelixer bc35a0e9 · yepochs fdc808f · merkle 6608f3d  ⇐ OLD; Unicode defect ships, per seat
ROLLBACK    none needed — nothing routed. If ever routed: route field back to commonplace-beta (see rollback qualification)
GATE        --porcelain --ignored on COPY paths 0 · red arm proven (probe → 1) · 0 again
CONTROLS    scripts 2→3 · container apps 2→3 · DO ns 3→4 · route unmoved · beta etag db37a1f0 unmoved · beta.commonplace.st 302
            workers_dev=false previews=false read back from /subdomain
AUTHORIZED  jes tg 11101 "can we boot the beta app on cloudflare ASAP" + standing DEPLOY EARLY; seat 30264/30267
            scope: ordinary boot, no route switch before measured readiness
```
## ③ BLOCKED on values that do not exist — put to the seat (msg 30356). NO PARTIAL BINDING SET.
HAVE: WORKOS_CLIENT_ID, WORKOS_API_KEY (custody) · ACCESS_ISSUER, _JWKS_URI (public), _AUDIENCE 9eab32ce… (Access app AUD)
MISSING: WORKOS_REDIRECT_URI (path is the app's) · SECRET_KEY_BASE (generate) · ACCESS_ROSTER (⛔ a DECISION: who may
enter — jes's) · LOG_REALM_URL + _CAPABILITY (no realm exists for next; I can mint one on commonplace-log)

## ③ DONE 2026-09-05T20:18Z — ALL TEN BINDINGS SET, in one pass, read back by name
```
secret_text ×10 on commonplace-next (values NEVER returned by the API; read-back is NAMES + count):
  SECRET_KEY_BASE (generated, 64 random bytes b64) · COMMONPLACE_ACCESS_{ISSUER,AUDIENCE,JWKS_URI,ROSTER}
  WORKOS_{CLIENT_ID,API_KEY,REDIRECT_URI} · COMMONPLACE_LOG_REALM_{URL,CAPABILITY}
CONTROL after set: durable_object_namespace COMMONPLACE_NEXT_CONTAINER still present (the erase hazard did not fire)
```
⭐ **Set ALL ten as secret_text deliberately** — the four "may be plain var" values included — because the
only way to add plain vars without a redeploy is a settings PUT, and this file already records that
*a later PUT that omits bindings ERASES them, HTTP 200, silently.* Uniform secret_text via `wrangler
secret put` (stdin) touches nothing else. The non-secret values are recorded here in plaintext:
  ISSUER https://commonplace-systems.cloudflareaccess.com · AUDIENCE 9eab32ce…80a6 (Access app AUD)
  JWKS_URI …/cdn-cgi/access/certs · REALM_URL …/realms/36917f12-ac1c-4cba-806b-7ec5648b6214
  REDIRECT_URI https://beta.commonplace.st/auth/workos/callback · ROSTER {"0a97249d-…":"jes"} (1 owner, jes's word tg 11165)
**DURABLE CUSTODY: `/home/jes/.config/commonplace-next/` (700), one 600 file per binding — the seat ruled
the generated secrets must SURVIVE for restarts, not be shredded as the only copy.**
**REALM 36917f12… is RETAINED BETA STATE from first write. Never delete/reset. Its capability is WRITE authority.**

## ④ READINESS — STRUCTURAL FACT BEFORE MEASURING: THE WORKER HAS NO HOSTNAME
`workers_dev=false`, `preview_urls=false`, and NO route ⇒ **nothing outside Cloudflare can send it a request,
so nothing can boot the container to measure it.** Instances read 1/1 after deploy but boot happens on the
first DO request. ⇒ ④ needs a PROTECTED PRE-CUTOVER PATH (the seat's own phrase): a staging hostname on
the SAME Access app (same AUD 9eab32ce — a second app would have a different AUD and fail the assertion),
routed to commonplace-next, measured, then route 6a26c1fc flipped. Proposed to the seat; not built.

## ④ PRE-CUTOVER PATH BUILT — 2026-09-05T20:31Z, under seat #30367 ("proceed now, no further approval for those exact effects")

Order followed as the seat stated: **snapshot → additive Access update → read-back → DNS → route → gating check.**

| step | artifact | measured |
|---|---|---|
| snapshot | `cf-records/access-snapshots/bdf850ac-{before,after,policies-before}-20260905T2030Z.json` | full app + 1 policy captured before any write |
| Access PUT | app `bdf850ac-8749-48f0-9568-c31390a8099c` | `self_hosted_domains` `['beta.commonplace.st']` → `['beta.commonplace.st','beta-next.commonplace.st']`; `destinations` likewise; **AUD `9eab32ce…` UNCHANGED**; every other field diffed equal; policy `d41759c0` (allow, jes's email only) identical before/after, precedence 1, no new policy |
| DNS | record `8a82d8987ec3a099dfbe44675aa713f8` | CNAME `beta-next.commonplace.st` → `commonplace-next.commonplace-systems.workers.dev`, proxied, mirrors production's shape (`d4745b01…`) |
| route | `d1a198229f0445d5a3d8d2a7c86e52c4` | `beta-next.commonplace.st/*` → `commonplace-next` |
| production | route `6a26c1fc…` | still → `commonplace-beta` [read back after the route POST] |
| workers.dev / previews | subdomain endpoint | `enabled=false`, `previews_enabled=false` [read back after] |
| gating | `curl -I https://beta-next.commonplace.st/` | **302 → `commonplace-systems.cloudflareaccess.com/cdn-cgi/access/login/beta-next.commonplace.st?kid=9eab32ce…`** — same `kid` as production's redirect, `auth_status: NONE` in the meta JWT |
| control | `curl https://beta.commonplace.st/` | 302 to the same login with `kid=9eab32ce…` — production behaviour identical to before |

⚠️ **A first PUT went to `/accounts//access/apps/…` (my `$ACCT` was empty) and failed with 7003 —
a read-back afterwards showed `updated_at` unchanged, so it wrote nothing.** Recorded because a
failed write and a partial write share an HTTP error.

**NOT YET MEASURED:** the real Access assertion (needs jes's browser login on the staging hostname —
no service token, no new policy, per seat), container boot on first DO request, storage via realm
`36917f12…`, editor. ⛔ Not predicted.

**ROLLBACK (seat's order):** `DELETE zones/fcb470ab…/workers/routes/d1a198229f…` FIRST → then
`DELETE dns_records/8a82d898…` → then PUT the Access app back to
`access-snapshots/bdf850ac-before-…json` fields. Production route and realm untouched throughout.
