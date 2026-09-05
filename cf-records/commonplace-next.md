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
