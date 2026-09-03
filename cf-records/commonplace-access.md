# commonplace-beta — Cloudflare Access application (LIVE)

⭐ **Written to the format `cool-recipe-d18f.md` earned: the field that cannot be recovered from the
API later is WHY, so it is written first and at length.** What / when / how-to-remove are all
retrievable in two minutes; WHY is not.

| field | value |
|---|---|
| **WHAT** | Cloudflare Access application `bdf850ac-8749-48f0-9568-c31390a8099c`, name `commonplace-beta`, account `Commonplace Systems` (`d5c4856e…`) |
| **WHEN** | Created 2026-09-03T09:2xZ by commonplace-biscuit under `ACCESS-1a` (plan rows 625–637) |
| **WHO AUTHORIZED** | jes, telegram 2026-09-03: enabled Access himself (09:17Z), granted `Account → Access: Apps and Policies → Edit` (verified 09:19Z by a create that succeeded), named the team `commonplace-systems.cloudflareaccess.com` (09:14Z, id 10828) and the allow-list identity `jes5199@gmail.com` (09:25Z, id 10835) |

## The objects

```
application   bdf850ac-8749-48f0-9568-c31390a8099c   name commonplace-beta
  domain      beta.commonplace.st    type self_hosted    session_duration 8h
  AUD         9eab32ce360b636aee3c06cfcebc7f1b8c4d03aa7353d3af075b09bc1ece80a6
policy        d41759c0-5604-47b7-a5da-4eafdd7dd6d9   "commonplace-beta owners allow-list"
              decision allow · include [{email: jes5199@gmail.com}] · ONE policy, ONE entry
issuer        https://commonplace-systems.cloudflareaccess.com
JWKS          https://commonplace-systems.cloudflareaccess.com/cdn-cgi/access/certs
              kids 482f151d1077188e…, bc56009df6891d89…
```

⚠️ **`session_duration` is 8h and the brief's fallback was 24h — a DEVIATION, flagged not buried.**
The fallback was conditional on the spec being silent; spec §12.3 is NOT silent (*"Access application
session: several hours"*). 8h is biscuit's concrete reading of "several hours". **If plan reads it
differently it is one PUT to change.**

## ⭐ WHY — the field the API cannot give back

> `beta.commonplace.st` is the Commonplace beta origin, and the application's own login path was
> removed in `R11a` — so with nothing in front of it there is no way for a human to authenticate at
> all, and with the Access plug unconfigured the app fails closed *silently*. This Access application
> is the only thing that admits a human to the beta, and its AUD and issuer are the values the app's
> assertion verifier is pinned to; deleting it does not "open" the site, it makes the beta unreachable
> by anyone. The single-email allow-list is deliberately an **implementer-only demo topology**
> (spec §9.3) and **MUST NOT be mistaken for the Organization membership model** — Commonplace never
> infers membership from an Access policy.

## ⭐⭐ The attribution is MEASURED, not testimony (retires the caveat on plan row 636)

**The question was: does `commonplace-systems.cloudflareaccess.com` belong to THIS account?** It could
not be answered by the endpoint that would say so directly (`access/organizations` returns `10000` —
a Zero Trust *organization read*, a permission separate from Apps-and-Policies and still ungranted).
⛔ **It was NOT answered by testimony in the end.** A three-link chain, every link an object we made:

1. We created the app in our own account by an authenticated API call — **unambiguously ours**.
2. `GET https://beta.commonplace.st/` → **302 to `commonplace-systems.cloudflareaccess.com`**.
3. That redirect carries a `meta` JWT naming **our AUD** and **our hostname**, signed by
   `kid 482f151d1077188e…`:

```
commonplace-systems  JWKS contains that kid:  True
commonplace          JWKS contains that kid:  False   ⭐ NEGATIVE CONTROL — the stranger's team
```

⇒ **Cloudflare itself routes our application to that team domain and signs the handoff with that
team's key.**

⛔ **WHY THE CONTROL IS THE POINT: `commonplace.cloudflareaccess.com` also returns 200 with 2 live
keys and is SOMEONE ELSE'S TEAM** — cloudflareaccess names are a **global namespace**, so existence
identifies nobody. Had that 200 been read as "the team", the app would have pinned its verified issuer
to a stranger's IdP. The disjoint kids, and then this signing-kid intersection, are what separate them.

## HOW TO REMOVE IT

`DELETE /accounts/d5c4856e…/access/apps/bdf850ac-8749-48f0-9568-c31390a8099c` — **ONE delete.** An
Access app owns no DNS record and no route, so the Worker's three-step order does not apply.

⛔ **LABEL, honestly: REHEARSED ON A DISPOSABLE OBJECT, NOT TESTED ON THIS ONE.** The rehearsal's
control is the part to carry: after the delete, a **direct `GET` on the id returned `11021
unknown_application`** — because **an empty list and a stale-but-hidden object are the same
observable.**

## HOW TO RESTORE IT

Re-POST the body in *The objects*. ⚠️ **THE AUD IS REGENERATED ON RESTORE, so a restore INVALIDATES
the pinned `COMMONPLACE_ACCESS_AUDIENCE`** and the app's config must be re-read from the API. **That
is the field a stranger will get wrong.**

## What is proven, and what is NOT

✅ **C2** — before/after on three paths: `/`, `/healthz`, `/access-check` all went `200` → `302` to the
team domain.
✅ **C3, forged half** — before Access, a bogus `cf-access-jwt-assertion` was echoed verbatim by the
Worker (`kid: FORGED-KID`, `iss: https://evil.example`). ⭐ **That is a real positive baseline: it
proves the arm CAN go red and that `/access-check` genuinely reads the header.** The same forged
request now never reaches the Worker.
✅ **C3, the other half — DONE 2026-09-03T09:39Z. jes ran the interactive login himself and pasted
the result (telegram id 10841), verbatim and complete:**
```json
{"assertion_present":true,
 "kid":"482f151d1077188e58747ed89c7f36542dc470a82a6c92f946f2608465ac328a",
 "iss":"https://commonplace-systems.cloudflareaccess.com"}
```
⭐ **All three fields match what was recorded BEFORE the login: `assertion_present` true · `kid`
non-null AND A MEMBER OF this team's JWKS · `iss` byte-equal to the pinned issuer.**
⛔ **NOT "the first kid" — I wrote that and it is wrong. KEY ORDER IS NOT STABLE: the same pair came
back in OPPOSITE ORDERS at 09:15Z and 09:28Z (biscuit, plan row 644-bis).** ⇒ **The claim that holds
is MEMBERSHIP, and any resolver must LOOK UP BY KID AND NEVER INDEX THE ARRAY.** A verifier written
against position would pass every test today and fail whenever Cloudflare reorders.
⇒ **ACCESS DELIVERS THE SIGNED ASSERTION TO THE ORIGIN. The assumption spec §9.1 forbids leaving
untested is now tested by the only instrument that could: a human at a browser.**
⚠️ **AND IT IS A PREDICTION CONFIRMED, NOT A VALUE READ BACK — the issuer and kid were written into
this record before anyone logged in, so the match is evidence rather than bookkeeping.**

📌 **A FOURTH, INDEPENDENT CONFIRMATION OF THE ATTRIBUTION arrived on the way (telegram 10839):** the
`state` parameter of jes's mid-login redirect decodes to `authDomain
commonplace-systems.cloudflareaccess.com`, `hostname beta.commonplace.st`, `aud 9eab32ce…` — **our
application's audience, named by Cloudflare's own handshake in a browser we do not control.**
⛔ That URL carries a nonce and is credential-shaped; it was decoded locally and is not reproduced here.
📌 **C4 — DECIDED, not discovered: `/healthz` IS behind Access.** §9.4 says the origin should be
reachable only through Access and names no exemption, so none was taken. ⚠️ **Consequence:
`/healthz` is no longer externally pollable — any uptime check will see a 302, not a failure.**

## ⚠️ THE WORKER'S SOURCE — and the gap the deploy path does not cover

**Worker `commonplace-beta` serves `/access-check`, and its source is `cf-src/commonplace-beta.mjs`
at commit `5863efa`.**

⛔ **THAT COMMIT EXISTS BECAUSE THE SOURCE WAS UNTRACKED WHEN THIS RECORD WAS FIRST WRITTEN.**
commonplace-biscuit found it on a post-landing sweep: the deployed Worker carried `/access-check`,
the committed source did not, and this record was describing an edge behaviour that lived only in a
working tree.

⭐ **THE DESIGN RULE HELD AND STILL LEFT THE HOLE: *a provenance record written by the deploy path
cannot drift from what is deployed* — true. But THE DEPLOY PATH WRITES TO CLOUDFLARE, NOT TO GIT, so
the SOURCE sits outside the loop that cannot drift.** The live artifact and the API-side provenance
agreed with each other and both disagreed with git.

⚠️ **HOW IT BITES, and it is a silent one:** anyone redeploying from a clean checkout — **including
the RESTORE path in this very record** — would have **silently reverted `/access-check` to the
catch-all HTML.** The deploy succeeds, the site serves, Access keeps working, ⛔ **and the only thing
lost is the arm that proves the assertion reaches the origin.**

✅ **VERIFIED RATHER THAN ASSUMED before committing:** fetched the LIVE script from
`GET /accounts/{id}/workers/scripts/commonplace-beta` and diffed it against the working tree. **The
only difference is the multipart form wrapper the API adds** — 3 boundary/`Content-Disposition` lines
at the head, 2 at the tail. **The body is identical.** `node --check` passes.

📌 **CHECK THIS BEFORE TRUSTING ANY `cf-records` ENTRY: `git status --porcelain cf-src/` must be
empty.** A record can be accurate about Cloudflare and wrong about the repository, and only that
command tells the two apart.

## ⛔⛔ THE RE-TARGET WRITE SHAPE — AND IT INVERTS THE WORKERS RULE

**When Access moves off `beta.commonplace.st` to the internal hostname (plan row 651: ordering (a),
Access stays until AuthKit serves, the move is the LAST act before the front door opens), the write is
a `PUT` — and the SAFE shape OMITS `policies`.** [measured by commonplace-biscuit, 2026-09-03T10:03Z,
on two DISPOSABLE apps; the real application untouched, account back to n=1]

```
PATCH /access/apps/{id}                  → 10405 "Method not allowed for this authentication scheme"
                                           independent re-read: NOTHING changed
PUT  {…, domain:new, policies:[…]}       → success. POLICY DESTROYED AND RECREATED, NEW id
PUT  {…, domain:new}   ← policies OMITTED → success. POLICY PRESERVED, SAME id
AUD across all of these                  → UNCHANGED
```

⇒ ⭐ **One write verb. Sending the allow-list "to be safe" is what destroys it.**

⛔⛔ **THIS IS THE OPPOSITE OF THE WORKERS FINDING, AND THE ANALOGY IS THE TRAP.** The measured Workers
rule is *a later PUT that omits a `plain_text` binding ERASES it, HTTP 200, silently*. Access
applications: **omitting PRESERVES, including REPLACES.** ⇒ **Same API, same account, same verb,
OPPOSITE SEMANTICS — so "omit = erase" is a fact about the WORKERS SURFACE, not a Cloudflare-wide
law.** ⚠️ **Anyone who has internalised the Workers lesson will reach for the wrong call here, and
reach for it CAREFULLY** — which is why this is a section and not a footnote.

⚠️ **AND BOTH VARIANTS RETURN `success: true` WITH THE RIGHT DOMAIN**, so the destructive one has no
wrong value to notice. **Decline-flag family: the failure is invisible in the response.**

📌 **Relation to the RESTORE trap above, which remains the sharper one:** delete-and-recreate
regenerates the AUD and silently invalidates the pinned `COMMONPLACE_ACCESS_AUDIENCE`. ✅ **The
re-target does NOT need a recreate — a `PUT` with `policies` absent moves the domain while preserving
BOTH the AUD and the policy id.**
