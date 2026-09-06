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

## ④ FIRST MEASURED TRAFFIC — 2026-09-05T20:51:54Z, jes's browser via Access (tail json, Monitor bo289oo20)

```
GET https://beta-next.commonplace.st/   cf-ray a3681d5a49e55d68 · a3681d64ba0e5d68 · a36820aa5f8eb18c
Worker event      outcome ok · status 200 · exceptions [] · logs []
headers present   cf-access-jwt-assertion (1, REDACTED) · cf-access-authenticated-user-email · cookie
DO event          entrypoint CommonplaceNextContainer · id 3851d2df… · wallTime 134025 ms (COLD BOOT, first hit) → 2950 ms (later)
serving version   cff5c078 (v11) — script etag 343cbd4fb60dd442 == v1 eab9c341; v2–v11 are the ten secret puts
container stdout  NOT in the Worker tail; observability disabled; logpush false ⇒ no operator log path for app-side reasons
page (jes)        exactly "Authentication required." — PageController.index anonymous branch (200)
```
⇒ Access admits · Worker forwards with the assertion present · container boots and serves · **the app's admission
chain declines, reason unobservable.** Instrument (allowlisted stage/reason, seat #30427) drafted by the next door
at `codex/auth-diagnostic-1 @ b8939ab`, unrun; AUTH-DIAGNOSTIC-1 window granted 20:55Z. ⛔ My earlier "401" and
"parser refusal" were unmarked inferences — LESSONS 7x688. ⛔ "tail blind" was an idle instrument — ledger 20:49Z.

## OBSERVABILITY ENABLED — 2026-09-05T20:59Z, seat #30460/#30463 (sink for the AUTH-DIAGNOSTIC-1 instrument)

**Shape: `PATCH …/scripts/commonplace-next/settings` with ONLY `{"observability":{"enabled":true,"logs":{"enabled":true,"invocation_logs":false}}}`.** Snapshot first: `access-snapshots/commonplace-next-settings-before-obs-20260905T2059Z.json`.
**Proven on a disposable worker `boss-obs-probe` (secret binding DUMMY) first — Arm A: setting took AND the binding survived. Arm B (PATCH with `bindings: []`) did NOT erase the binding either** — so PATCH does not reproduce the PUT erase hazard recorded 09-01; that hazard stays filed as PUT-specific and was not re-tested here. Probe deleted; scripts back to {beta, log, next}.
```
commonplace-next AFTER   bindings identical by (type,name): 10 secret_text + DO COMMONPLACE_NEXT_CONTAINER (11)
                         observability enabled=true · logs.enabled=true · invocation_logs=false · traces disabled · persist true
                         script etag 343cbd4fb60dd442 unchanged · routes 6a26c1fc→beta, d1a19822→next unchanged
                         ⚠️ settings write minted a NEW version/deployment: aa542c30 → version 20887173 (100%) — same bytes, new id
                         only other settings key changed: annotations (deployment message)
```
⛔ Seat's caveat, carried: `invocation_logs=false` does NOT make the sink emit only the allowlisted event — existing container stdout may appear. No public export; Dashboard/`wrangler tail` only. **Sink is NOT yet proven to receive a container line: a known application emission must arrive before silence is trusted.**
⚠️ **EFFECT OBSERVED 21:00:13Z (tail):** the DO's alarm handler threw `Durable Object reset because its code was updated` — the settings write, by minting a new version, **RESET the Durable Object and therefore the container instance.** Same bytes, but a restart. A settings-only write is not free of runtime effect on a Container-backed Worker; on production this would be a cold boot (~134 s measured today).

## STAGING DEPLOY — 2026-09-05T22:19Z, seat #30555 "CLEARED FOR STAGING BUILD/DEPLOY ONLY". JWT repair + AUTH-DIAGNOSTIC-1.
```
TARGET      commonplace-next Worker (EXISTING) via route d1a19822 beta-next.commonplace.st/* · route 6a26c1fc UNTOUCHED (→ commonplace-beta, read back after)
APP SHA     d8191cf4ef1d1aacc673a49abdbf7a9bdd4b662e   tree 79a07d15873f408f53c50f72582702c9e8a76b09   (local codex/jwt-auth-staging-1, UNPUSHED, built from a fresh clone of it)
            lineage 9e3ed17 (full-tested 603/0/1, door's number) → 57d49a3 (docs-only) → d8191cf4 (evidence-only); exec-path diff 0 lines across the chain [measured]
WORKER SHA  version f2753a6b-21be-4029-af3f-7b2382c75656 (v13) · script etag 343cbd4fb60dd442 UNCHANGED (Worker bytes identical; only the image changed)
            image commonplace-next@sha256:aec7ee6f6fd52ae87886b082b198ccc14a00738cdd13a60d7e1f7a1b61a06de7 (tag f2753a6b)
            container app a03286c5 · rollout 7d3b7dd0 COMPLETED 22:19:37Z to that digest (⚠️ /containers/applications listing still shows 299207be — lagging field; rollout is authoritative)
            then settings re-PATCH → version 5a2a608c / deployment d15d1d80 (observability restored; same bytes)
RANGE       a538fa18..d8191cf4: JWT-JSON-1 (07b86fb) + AUTH-DIAGNOSTIC-1 (6fd0d8a) + evidence. COPY set: mix.exs 06a855d8 · mix.lock 29d61e15 · config c028506a · priv a3360df2 (== a538) · lib cd460ad4 (was ffc53b5f — the ONLY changed input)
            deps/ = ①'s fetched set REUSED (mix.lock blob identical); 13 git deps' HEAD == lock ref [checked each]
            Dockerfile · worker/wrangler.jsonc · worker/src blob ids IDENTICAL to ① · docker: 10 CACHED, 7 RUN (compile 77 files, release) · wrangler 4.125.0 (①'s node_modules)
GATE        --porcelain --ignored on COPY paths 0 · red arm (probe → 1) · 0 again
ROLLBACK    route d1a19822 stays; to revert the app: redeploy from the ① clone (a538fa18, image 299207be still in registry) — ⚠️ untested path. Production never touched.
READ-BACK   bindings 10 secret_text + DO (11) ✅ · workers_dev false previews false ✅ · routes unchanged ✅ · etag unchanged ✅
            ⛔ observability ERASED by the deploy (None) — wrangler.jsonc has no observability block, so deploy reset it, as predicted → re-PATCHed (proven shape) → enabled/logs/invocation_logs=false ✅
            ⇒ FILE THIS: every future `wrangler deploy` of this Worker wipes the sink until observability is added to wrangler.jsonc (a code change for the app door).
EFFECT      new version ⇒ DO reset ⇒ container cold boot on next request (~134 s measured earlier)
ACCEPTANCE  (seat) known safe application emission at the sink + correlated real-browser status/reason OR authenticated success. Tail armed 22:22Z (Monitor bysof0z77). jes asked (tg 11190). NOT PREDICTED.
```
ACCEPTANCE RESULT 22:51–22:53Z — **NOT MET.** jes ×3 through Access: GET / → 200 each, assertion header present at the Worker; DO cold boot 88.8 s; container egress: Access JWKS ×2 (200), storage.internal frontier/take-lease/tail-local ×34 (200); **page still "Authentication required."** Diagnostic emission NOT observed: tail logs [] on all 38 events; telemetry API 0 events for the service (15 m) and **0 account-wide (60 m, unfiltered) ⇒ sink has no positive control — UNPROVEN.** JWT repair is in the served image and the refusal persists. My Telegram read "shape of a session" (11192) was an inference and was wrong within a minute (11191) — LESSONS.

## CONTAINER-APP LOGS ENABLED — 2026-09-05T23:17Z, seat #30666/#30668 option (A): same image, config-only
```
finding    wrangler 4.125.0 writes container-log enablement to the CONTAINER APPLICATION's configuration.observability.logs.enabled — a
           different object from the Worker script settings (app door, cli.js:271480/270075/270098). Live read-back: ABSENT on app a03286c5 v2.
shape      PATCH /containers/applications/a03286c5 with wrangler's modify body (configuration + max_instances/constraints/scheduling_policy/
           rollout_active_grace_period, ALL copied from the snapshot; only delta: observability {logs:{enabled:true}}) → success, but v2
           unchanged until → POST …/rollouts {strategy rolling, step_percentage 100, kind full_auto, target_configuration = same} →
           rollout afe7badd-ddc8-4ad5-854e-d998887dcfc6 progressing → COMPLETED 23:17:59Z
result     app version 2 → 3 · configuration.observability {logs:{enabled:true}} · image sha256:aec7ee6f… UNCHANGED · no other config key changed
           · instance 3851d2df now inactive (was already stopped for inactivity 23:02); next request cold-boots a NEW instance
controls   Worker untouched: deployment d15d1d80 / version 5a2a608c · 10 secret_text + DO · worker observability enabled/logs/invocation=false
           · routes 6a26c1fc→beta, d1a19822→next · workers_dev/previews false
snapshot   access-snapshots/commonplace-next-app-a03286c5-before-obs-20260905T2316Z.json
rollback   same PATCH+rollout with observability {logs:{enabled:false}} — config only; NOT a redeploy of an older app (seat #30668)
⛔ persist  a future `wrangler deploy` from a wrangler.jsonc WITHOUT observability would REVERT this (observabilityToConfiguration → logs.enabled=false
           when previously enabled). d2db7ff (observability in wrangler.jsonc) must ride every future deploy.
acceptance the Bandit startup line in Container Logs on the next cold boot — ⚠️ STRUCTURAL: a cold boot needs a request that passes Access,
           and only jes's browser can produce one (no service token, seat rule). So the startup-line control and the correlated login are the SAME request.
```

## STAGING PAIRED DEPLOY — 2026-09-05T23:39Z, seat #30698 "CLEARED STAGING PAIRED BUILD/DEPLOY AUTH-DIAGNOSTIC-RELAY"
```
TARGET      commonplace-next via route d1a19822 (beta-next) · prod route 6a26c1fc → commonplace-beta UNTOUCHED [read back]
APP SHA     5557f4b50d18387f3fbfa334e2ee7046e1a048c1   tree 5ff14a8b740299753078ae18d7b3196352403a61   (local codex/auth-diagnostic-relay-1, UNPUSHED; fresh clone)
            lineage d8191cf4 (served) → d2db7ff (wrangler.jsonc observability) → 42f5a2b (focused-tested: app 22/0, Worker 17/0 — door's numbers) → 5557f4b (docs-only)
            exec-path diff 42f5a2b..5557f4b = 0 lines [measured]
WORKER SHA  version 4d626658-0ae4-4ed4-8c24-6f559874a132 · script etag eab350f7482fa023 (CHANGED from 343cbd4f — new Worker code: authentication-diagnostic.js relay/strip)
            deployment f50c3e5b · image commonplace-next@sha256:adc8731792ba1d3c63bd14ebbaffad848ae48582006a3d0fe703b0e01d9864ed (tag 4d626658)
            container app a03286c5 version 3 → 4 · rollout 441e23ae COMPLETED · configuration.observability {logs:{enabled:true}} SET BY THE DEPLOY (wrangler.jsonc block) ← persistence path PROVEN
RANGE       d8191cf4..5557f4b — exec paths changed: lib/…/web/authentication_diagnostic.ex · test/…/authentication_diagnostic_test.exs · worker/src/authentication-diagnostic.js · worker/src/index.js · worker/wrangler.jsonc
            COPY set: mix.exs 06a855d8 · mix.lock 29d61e15 · config c028506a · priv a3360df2 (== a538) · lib 23f967ba (was cd460ad4) · worker/src 24bbbc2e (was 151558d1)
            deps = ①'s fetched set (locks identical) · gate: porcelain --ignored on COPY+worker/src 0, red arm 1, 0
PAIRING     wrangler uploaded the Worker FIRST (18: Uploaded), then built/pushed the image and rolled the app — so the "new app + old Worker" header-exposure window never existed; the "new Worker + old app" window lasted the rollout only. Both now active.
READ-BACK   10 secret_text + DO ✅ · worker observability enabled/logs/invocation=false ✅ (preserved — config carries it now) · app logs.enabled ✅ · routes ✅ · workers_dev/previews false ✅
EFFECT      new Worker version ⇒ DO reset; instance 3851d2df inactive → next request cold-boots the new image
ROLLBACK    redeploy from the d8191cf4 clone (Worker + image together — pairing matters in reverse too) — untested path; config-only changes revert with config
ACCEPTANCE  (seat #30698) one correlated real request → Worker-console event `authentication_rejected_from_app stage=<fixed> reason=<fixed> status=<actual>` OR authenticated success; `x-commonplace-auth-diagnostic` header ABSENT at the browser. Tail armed (b3wgiy0b7). NOT PREDICTED.
```

## STAGING PAIRED DEPLOY #2 — 2026-09-05T23:59Z, seat #30744 (AUTH-HEADER-DETAIL: six-code header-refusal refinement)
```
APP SHA     a95b7ccb662b2ab3f0fe78e15b04459a8c47d2da  tree 9636bf56  (docs-only over tested d84df1d: app 88/0, Worker 17/0 — door's numbers; exec-diff 0 [measured])
            exec paths changed vs served 5557f4b: assertion_verifier.ex · access_authentication.ex · authentication_diagnostic.ex · 2 tests · worker/src/authentication-diagnostic.js
            COPY: mix.exs 06a855d8 · mix.lock 29d61e15 · config c028506a · priv a3360df2 (unchanged) · lib cbe21308 (was 23f967ba) · worker/src 41794ded (was 24bbbc2e)
WORKER SHA  version 673ad351-e54c-4b4b-87d9-354ac2bb6e2e · etag 5bd04ccb178fe724 (was eab350f7) · deployment c2611bdf
            image commonplace-next@sha256:d6ec4bb88bfb56e0103b637def3f403efcc8a0ff4629549cfb5ece613b906750 (tag 673ad351) · app v4→v5 · rollout d8aefc1c COMPLETED
PAIRING     Worker uploaded first (log line 13), image built/pushed/rolled after — same safe order as #1
READ-BACK   10 secret_text + DO ✅ · worker obs enabled/logs/invocation=false ✅ · app obs logs.enabled ✅ (both from wrangler.jsonc) · routes ✅ · workers_dev/previews false ✅
EFFECT      DO reset (tail: "Durable Object reset because its code was updated") ⇒ cold boot on next request
GATE        porcelain --ignored on COPY+worker/src 0 · red arm 1 · 0
ACCEPTANCE  one correlated login → `authentication_rejected_from_app stage=… reason=<one of header_json_invalid|header_json_duplicate|header_json_exception|header_forbidden_parameter|header_b64_invalid|header_typ_invalid>` or another gate, or success. Browser header-absence check still OPEN (iPhone).
```

## STAGING PAIRED DEPLOY #3 — 2026-09-06T00:45Z, seat #30802 (ACCESS-TYP-COMPAT: verifier accepts Access assertions per provider profile)
```
APP SHA     a0145376c3c8e6101154049cd1dffd2ba7691c44  tree 8a64241d  (exec-diff 0 from reviewed 086ba266; focused 102/0, Worker 17/0 — door's numbers)
            exec paths vs served a95b7ccb: assertion_verifier.ex · access_authentication.ex · authentication_diagnostic.ex · access_typ_policy_test.exs · authentication_diagnostic_test.exs · worker/src/authentication-diagnostic.js
            COPY: mix.exs 06a855d8 · mix.lock 29d61e15 · config c028506a · priv a3360df2 (unchanged) · lib d6b5218d (was cbe21308) · worker/src bb9fa4c8 (was 41794ded)
WORKER SHA  version 4675ba7f-255d-4bc6-ae63-e0610fd4f6d3 · etag 4433e79bfb9c7caf (was 5bd04ccb) · deployment 1cf42d4a
            image commonplace-next@sha256:a0cc012915f61cd28b4acbc38c00247f286fa03ffbd870176cf1b15c1d8a01c7 (tag 4675ba7f) · app v5→v6 · rollout a1d2f139 COMPLETED
PAIRING     Worker uploaded first (log :13), image after — safe order
READ-BACK   10 secret_text + DO ✅ · worker obs ✅ · app obs logs.enabled ✅ · routes ✅ (prod 6a26c1fc untouched) · workers_dev/previews false ✅ · DO reset observed
GATE        porcelain --ignored on COPY+worker/src 0 · red arm 1 · 0
ACCEPTANCE  one correlated login → authenticated success (real page) OR fixed remaining reason. NOT PREDICTED.
```
ACCEPTANCE #3 — 2026-09-06T01:06:43Z — **AUTHENTICATED SUCCESS.** jes GET / on Worker 4675ba7f → 200, DO wallTime 13528 ms (cold boot of image a0cc0129), NO rejection line; Workspace rendered: canonical/mirror document UUIDs, editor Cell ID, matching selected heads, `relationship status ready`. ⇒ **④ Access-verified login on beta-next: MET.** The refusal since 20:33Z was the verifier's strict `typ == "JWT"` guard; the Access assertion does not satisfy it; a0145376 opts the Access path into a provider profile.
**NEW OPEN:** `GET /assets/app.js → 404` (01:06:57Z); page shows "connecting · local" — editor bundle not served by this image. Routed to the app door.
**STALE-INSTANCE HAZARD, filed for every future deploy receipt:** per Cloudflare's rollout docs (updated Aug 28) the Worker activates BEFORE the image replaces; a rollout's API status `completed` (00:47:17Z) preceded the old container's actual exit (≥00:48:49Z, "Runtime signalled the container to exit") by ≥90 s; jes's 00:48 requests were answered by the OLD image with no cold boot. ⇒ **After any paired deploy, treat the first request as unproven-provenance until a cold boot (DO wallTime ≫ 1 s) or the exit line is observed; a same-code result immediately after a deploy is NOT evidence about the new bytes.**

## STAGING PAIRED DEPLOY #4 — 2026-09-06T01:37Z, seat #30892 (BETA-ASSETS-1: image builds and ships the editor bundle)
```
APP SHA     17c22aca9251e0c4a80fed6fa5b1046b4e0d0f3d  tree e19fccca  (log door's reviewed source; docs-only receipt ae7cfb6 published on evidence/beta-assets-1-2026-09-06)
            vs served a0145376: Dockerfile (build stage installs nodejs/npm, `npm ci --prefix assets`, COPY assets/src, `mix assets.build --minify`, `test -s priv/static/assets/app.js`),
            .dockerignore, assets/package.json, config/config.exs, config/dev.exs; mix.lock now pins commonplace_doc_sync 483c545 (was 9d8aba8) — deps RE-FETCHED on host, 13 git deps == lock, 0 creds in .git configs
            COPY: mix.exs 036c44c3 · mix.lock c565a7aa · config 2a21e1b2 · lib 49e3edb5 · priv a3360df2 · assets dd05ea98 · worker/src bb9fa4c8 (unchanged) · Dockerfile e14d540e
WORKER SHA  version 96d8a39d-6be4-43b3-a8fe-c7d9e50a7fba · etag 4433e79bfb9c7caf UNCHANGED (worker/src identical) · deployment 678c552d
            image commonplace-next@sha256:dba6edfdfb68d7350ca7434e419050ca0e05d5b5597669d68be56ef92113b162 (tag 96d8a39d) — ≠ the door's locally tested digest 5a93b494 (non-deterministic apt/npm layers)
            ⭐ CONTROL: priv/static/assets/app.js inside MY image = sha256 28068d1817555d1e2d8e17b37f5b072148f2cfc4f27498fee8b597087532d3be, 711231 bytes == the door's tested bundle EXACTLY
            app v6→v7 · rollout d552e470 COMPLETED 01:37:42Z
READ-BACK   10 secret_text + DO ✅ · worker obs ✅ · app obs logs.enabled ✅ · routes ✅ (prod untouched) · workers_dev/previews false ✅ · DO reset observed · instance inactive on new image
GATE        porcelain --ignored on COPY+assets+worker/src+Dockerfile 0 · red arm 1 · 0
ACCEPTANCE  (seat) serving transition after old-runtime exit (cold boot), then one real login: GET /assets/app.js → 200 text/javascript, editor bootstrap, connection state. NOT PREDICTED.
```

## STAGING ROLLOUT #5 — 2026-09-06T02:19Z, seat #30958 (SESSION-GRANT-CONTINUITY: preserve mirror grants across same-login page→API)
```
SHAPE       the app door's TESTED image, pushed as-is and rolled by config — no rebuild, no Worker mint (worker/src + wrangler.jsonc identical 17c22aca→7a8aba77 [measured])
APP SHA     7a8aba77df15f304eff4668722039390a4e25d00  tree 861320c0   (exec paths vs 17c22aca: lib/…/web/session.ex + 2 tests)
IMAGE       sha256:82d786b694c863e8c93f9aa7814eec34bd14acf79b2a3e0ebe70a1d7f325fb8b — built by the app door in /home/jes/codex-sgc-image-1 (its receipt 0e8f5a00, 27 checksums, cookie matrix rc0);
            pushed by me via `wrangler containers push commonplace-next:sgc-7a8aba77` → registry digest identical 82d786b6 (manifest size 856)
ROLLOUT     PATCH application (only delta: image) → rollout 095e8746 COMPLETED 02:19:08Z · app v7→v8 · configuration.observability logs.enabled=true PRESERVED · no other key changed
WORKER      UNCHANGED: deployment 678c552d / version 96d8a39d · 10 secret_text + DO · obs enabled/logs/invocation=false · routes unchanged (prod untouched) · no DO reset (no Worker version)
INSTANCE    3851d2df inactive on the new image → next request cold-boots; per the stale-instance rule, first request provenance = cold boot observed
ACCEPTANCE  (seat) after transition: ONE page/API/socket observation — initial WS status vs 101/close/badge/content. Initial live 401 + storm NOT predicted fixed.
```
ACCEPTANCE #5 — 2026-09-06T02:20:18Z — **EDITOR CONNECTED ON FIRST LOAD.** jes (tg 11239 "worked first try!"). Tail: GET / → 200 (wall 4525 ms, cold boot of image 82d786b6) · /assets/app.js → 200 · /api/tree → 200 · exactly ONE yjs upgrade event (Worker `canceled`/no status = the long-lived socket held open) — **no 401, no reconnect storm** (contrast 01:41: 401 + 70 events/14 s). ⇒ **Full beta path on beta-next: Access login → page → bundle → API → live sync, first attempt.** Initial-401 was not separately diagnosed; its absence on this load is an observation, not a proof it is fixed (one sample).
**STANDING:** prod route 6a26c1fc still → commonplace-beta. Cutover is a ranking (seat) + jes decision; nothing here flips it.
LABEL CORRECTION (seat #30967): this is **"live authenticated editor bootstrap + sustained single upgrade, one sample"** — NOT "full beta path end to end". Still OPEN: user edits, durable reopen, Unicode acceptance. Cold-boot wallTime is not digest proof on its own; provenance = app v8 rollout of the tested image + prior instance inactive + request correlation, together. Initial-401 cause unattributed; its absence measured once. No cutover clearance follows from bootstrap success.

## STAGING ROLLOUT #6 — 2026-09-06T03:40Z, seat #31099 (BETA-LOOK-FEEL UI + STATUS-BINDING-LIFETIME: five asset paths + page_controller + status.js)
```
SHAPE       log door's TESTED image pushed as-is + config rollout — Worker/Dockerfile/pins identical to served 7a8aba77 [measured]
APP SHA     25bac41a87f295e5750fc04f34eec23d59190bda  tree e02156e3   (exec paths vs 7a8aba77: assets/src/{app,editor,status,tree}.js, workspace.css, lib/…/web/page_controller.ex)
            published evidence tip 2172fe10 on work/beta-look-feel-1-2026-09-06 (docs-only over 25bac41a, exec-diff 0)
IMAGE       sha256:59c21c7f7cd4f4a2a302205f04fd42f83502868c78209ee9e1292d7b06283b8c (tag status-lifetime-25bac41a), pushed by me; registry digest identical
            door's runtime asset hashes: JS b15c9a57 (712281 B) · CSS 264cd148 (5717 B)
ROLLOUT     PATCH app (image only) + rollout ceabd424 COMPLETED 03:40:37Z · app v8→v9 · obs preserved · no other key changed
WORKER      UNCHANGED 96d8a39d · 10 secrets + DO · routes unchanged (prod untouched) · instance inactive → cold boot next request
CAVEATS     (seat) prior 15 s navigation timeout unattributed, not "fixed"; no Unicode adoption in this image; no main clearance
ACCEPTANCE  one real desktop/mobile UI + file-reopen + status observation after transition; not a reload loop
```

## UNICODE WRITER-TRANSITION PLAN — read-only prep, seat #31171 (2026-09-06T04:55Z). NOT EXECUTED.
**Writer inventory for realm 36917f12 (measured):** exactly ONE application writer exists — container app a03286c5 (`max_instances 1`,
one DO id 3851d2df, one instance, currently INACTIVE on image 59c21c7f = UI/status build, pre-Unicode). Capability holders: the Worker
secret `COMMONPLACE_LOG_REALM_CAPABILITY` (write-only) and my custody file (600) — no door tree references the realm; commonplace-beta
has no realm bindings; commonplace-log holds the realm as its OWN storage (server side, not a writer INTO it). ⇒ No second writer to
inventory beyond the old/new instance of the same app.
**Hazard (measured today):** rollout API `completed` precedes the old container's exit by ≥90 s (up to 15 min drain per docs); during that
window the OLD image can still answer — and, after new-codec writes exist, an old-codec reader/writer must never touch the realm.
**Minimal exact act sequence:**
 1. QUIESCE: jes closes all beta-next tabs; wait for the SDK line `Activity expired, signalling container to stop` in the tail (10 min idle) and
    the instances API to read `inactive` for 3851d2df → **no live writer** [acceptance: tail line + API state, both].
 2. PUSH the reviewed Unicode image (tested by the door, by digest) to the registry — no rollout yet.
 3. ROLLOUT by config (image only) while the instance is inactive → rollout completes with NO old process to drain [acceptance: rollout
    completed AND instances API still shows a single instance, inactive or on the new digest — never two].
 4. FIRST REQUEST = cold boot on the new image [acceptance: DO wallTime ≫ 1 s on the first GET, no "Runtime signalled … exit" line, tail
    version/image correlation]; then one real login + edit + reopen (the seat's acceptance).
**Rollback identity:** config-only rollback to the previous digest is ONLY valid if NO new-codec write has occurred (i.e. before step 4's
first edit). After any new write: roll-forward only — fix on the new codec; never point an old-codec image at the realm.
**Not in this plan:** prod route flip; realm deletion/reset (⛔ never); WorkOS; second instance.
**REFINED per seat #31177 (still prep, not clearance):**
- Rollback cutoff corrected: the first possible new-codec write is at container boot / session open / mirror open — **not** at a human edit. ⇒ config-only rollback is valid only while NO request has reached the new image; from the first request onward, roll-forward unless durable evidence proves no new-codec write.
- Custody wording corrected: the Worker secret is *unreadable via the API* (values never returned); the capability itself is WRITE authority. The inventory is observed configuration/custody, not an exhaustive proof.
- **Request fence (reversible, prod untouched, Access retained):** DELETE zone route d1a19822 (`beta-next.commonplace.st/*` → commonplace-next) before the inactive check; with no route and workers.dev off, no request can reach the Worker/DO, so a stale tab cannot boot the old writer. Restore = POST the same pattern → commonplace-next (new route id; recorded). DNS record and Access app untouched throughout.
- **Identity, not count:** after rollout, all three must agree on the intended digest — app `configuration.image`, the rollout's `target_configuration.image`, and the instances API entry's `image` — and the instance state must be `inactive` (never a running instance on the old digest).
**Refined sequence:** F1 detach route (fence) → F2 wait: SDK "Activity expired" line AND instances API `inactive` → F3 push reviewed image by digest → F4 config rollout; verify triple-identity + inactive → F5 restore route (new id) → F6 first request = cold boot on intended image (wallTime ≫ 1 s, no exit line) → F7 seat's acceptance (login + edit + reopen). Rollback window closes at F6.
**FINAL PREP PRECISION (seat #31180):** the rollout itself booted an instance once today (23:17:39Z), so the first REQUEST is not guaranteed first activity ⇒ **from the config rollout (F4) onward, rollback = roll-forward** unless explicit durable no-new-write + old-reader-compat evidence exists. If an instance is unexpectedly RUNNING at F4: keep the route detached, report, no old-image fallback. F2 may reuse an existing historical stop + current inactive identity (preserve timestamps) instead of waiting for a fresh "Activity expired". Latency is never identity. F5 restore only after the reviewed target is established; live acceptance afterward. PREP ACCEPTED; execution awaits the reviewed integrated image.

## FENCED TRANSITION EXECUTED — 2026-09-06T05:17–05:20Z, seat #31202 (Unicode + UI/status, tested image, roll-forward from here)
```
F0 snapshot  05:17:43Z  routes {6a26c1fc→beta, d1a19822→next} · app v9 image 59c21c7f · instance 3851d2df inactive since 03:34:31Z
F1 fence     DELETE route d1a198229f0445d5a3d8d2a7c86e52c4 → only prod route remained; unauth GET still 302 (Access) — nothing reaches the Worker
F2 old writer last page GET 03:09:34Z · last SDK "Activity expired" 03:32:51Z · instances API inactive since 03:34:31Z · route detached 05:17Z ⇒ no live writer
F3 push      commonplace-next:ui-unicode-20d806e → registry digest sha256:98c200320fb4fb07729e3f7148fd51ca8fee86c3c69f08ffceb6023ae7a339c6 (identical to the door's local id)
F4 rollout   PATCH app (image only) + rollout 7428cdc2-a286-48ca-a3f0-9b657ec76f2e 05:18:48 → COMPLETED 05:19:26Z · app v9→v10
             TRIPLE IDENTITY: app configuration.image == rollout target == instances entry == 98c20032…; exactly ONE instance, state inactive ✅ (no old runtime)
F5 restore   POST route beta-next.commonplace.st/* → commonplace-next = NEW ID 8a173a1bcd1c4671b9fce5c936ee4379 (05:20Z); unauth 302 ✅
UNCHANGED    Worker 96d8a39d · 10 secret_text + DO · obs enabled/logs/inv=false · Access app domains+AUD · DNS 8a82d898 · prod route 6a26c1fc · realm untouched
APP SHA      20d806e1917e1e7389586aab9c7b8321d11d6d7e  tree 9dffe402  (door's clean build; receipt in codex-jwt-json-1 docs/measurements/ui-status-unicode-1; evidence tip 52048080 docs-only)
ROLLBACK     ⛔ roll-forward only from F4 onward (seat #31180): no old-codec image against realm 36917f12; no reset. Config-only rollback NOT offered.
NEXT (F6/F7) first request cold-boots 98c20032 (expect wallTime ≫ 1 s, no exit line); then jes: login + explicit synthetic Unicode edit + save + reload + reopen; report first write + exact observed text/status.
```
F6/F7 RESULT 05:21–05:25Z — first request cold-booted 98c20032 (GET / 4409 ms); assets/api 200; socket held; reload 05:23:52 clean; 0 exceptions/rejections. **Live editing BLOCKER (seat's label): jes lost the ability to type after entering 👩‍💻 in the marked line.** Attribution OPEN — "client-side" was my inference from a clean wire; the seat is right that no exceptions ≠ correct ACK/meaning/input state. **First new-codec write ≈05:22Z — APPROXIMATE, inferred from traffic, not a measured codec write.** Roll-forward only; cutover blocked. App door: bounded progressive-input reproduction on the exact image.
QUALIFICATION (seat #31221): the reload screenshot establishes VISUAL text only — it cannot distinguish precomposed é (U+00E9) from e+U+0301, nor prove exact code points of the emoji sequences; "persisted" above means visually, at page-reload scope. No server-restart claim. Byte-level evidence would need a store read by a door.

## PAIRED NATIVE-INPUT OBSERVER — 2026-09-06T06:17–06:19Z, seat #31260 (Worker FIRST, then tested image; diagnostic only)
```
APP+WORKER SHA  8d4373a9fe7590a3ec468fd448c63ed59e7b44ab  tree f84bd4d4   (vs served 20d806e: input-client-report {app assets, lib/web, worker/src}; page_controller; pins/wrangler.jsonc identical)
W1 WORKER       `wrangler deploy --containers-rollout=none` from a fresh clone → version 6b6d3f45-f6df-4c75-b06f-7b7a36a97902, deployment d9b53c1f, etag d66da710d91431a5 (changed: relay code)
                container app untouched by this step (v10, image 98c20032) ✅ — "new Worker + old app" is the safe direction (no header emitted)
W2 IMAGE        pushed commonplace-next:native-input-8d4373a9 → registry digest e0671c3b… identical to the door's local id
W3 ROLLOUT      PATCH (image only) + rollout 72c23a02-07c4-498c-8d4f-9311c5694821 06:18:45 → COMPLETED 06:19:31Z · app v10→v11
                TRIPLE IDENTITY OK (app config == rollout target == single instance == e0671c3b, state inactive since 05:55:11Z — no old runtime running)
UNCHANGED       10 secret_text + DO · worker obs enabled/logs/inv=false · app obs logs.enabled · routes 6a26c1fc (prod) + 8a173a1b (staging) · Access/DNS/realm untouched
ROLL-FORWARD    stands (realm has new-codec writes since ~05:22)
ACCEPTANCE      (seat) serving transition on first request (cold boot), then ONE bounded native report by jes: open Document identities BEFORE typing, editor focus, retry native keyboard after ZWJ + trailing ASCII, tap "Report typing problem" ONCE if blocked; log line `input_state_client_report status=200 report=<closed JSON>` at the Worker console. Client-reported, not app truth.
```
REFRESH-LOSS REPORT (seat #31295 label): **unconfirmed-save loss report** — jes recollects "saving" before a slow (~10 s) refresh; suffix did not return, he retyped. NOT a measured un-ACKed write, NOT a measured cold-boot cause ("saving" can include a durable commit with undelivered ACK; latency + status→running is not reboot proof). Tail unarmed for that window (7x692). Three-state fixture: first red was a fixture newline-expectation mismatch, not product.
