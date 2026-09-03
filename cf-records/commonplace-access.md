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
non-null AND equal to the first kid in this team's JWKS · `iss` byte-equal to the pinned issuer.**
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
