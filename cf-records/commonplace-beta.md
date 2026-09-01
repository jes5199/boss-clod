# commonplace-beta — LIVE, phase 1 COMPLETE

⭐ **The first artifact to get the STRONG provenance form**: written by `cf-deploy.sh` in the same
call that deployed it, not maintained beside it. Also on the artifact itself as `prov:*` tags.

| field | value |
|---|---|
| **WHAT** | Cloudflare Worker `commonplace-beta`, account `Commonplace Systems` (`d5c4856e…`). ES module, `fetch` handler, two paths: `/` (HTML placeholder) and `/healthz` (JSON). Source at `cf-src/commonplace-beta.mjs`. |
| **WHY** | Phase-1 target for `beta.commonplace.st`: a reachable, TLS-terminated endpoint proving the deployment path end to end **before any `commonplace-next` release artifact exists**. It is deliberately a placeholder — its job is that the path works, not that it serves anything. |
| **WHO AUTHORIZED** | **commonplace-plan row 218**; jes 2026-09-01T06:38:42Z *"parallel yes"*; dispatched by boss-clod. |
| **WHEN** | Deployed 2026-09-01T05:5xZ. |
| **HOW TO REMOVE IT** | **THREE objects, three deletes, in this order:** (1) DNS record `d4745b01180fa39c3c67ed417b97be95`, (2) route `6a26c1fc1a1d49d09d92d52c73e8225e`, (3) `./cf-deploy.sh remove commonplace-beta`. ⚠️ **Removing the Worker alone leaves a route AND a hostname pointing at nothing** — the count grew from two to three when the DNS record landed, which is why this field is re-checked rather than written once. |

## Reachable NOW — verified by effect, not by a 200 from the API

```
https://commonplace-beta.commonplace-systems.workers.dev          → HTTP 200, HTML
https://commonplace-beta.commonplace-systems.workers.dev/healthz  → {"ok":true,"service":"commonplace-beta","phase":1}
TLS  ssl_verify_result=0   CN=commonplace-systems.workers.dev   issuer=Google Trust Services WE1
     valid Aug 24 2026 → Nov 22 2026   HTTP/2
```
⚠️ **The FIRST fetch returned 404 and the second returned 200** — subdomain enablement is not
instantaneous. ⛔ **A single post-deploy fetch would have reported this deploy as broken.** The
verification retries; **a one-shot check here is a coin toss, not a measurement.**

## `beta.commonplace.st` — LIVE as of 2026-09-01

```
https://beta.commonplace.st           → HTTP 200, HTML
https://beta.commonplace.st/healthz   → {"ok":true,"service":"commonplace-beta","phase":1}
TLS  ssl_verify_result=0   CN=commonplace.st   issuer=Google Trust Services WE1
     valid Aug 31 2026 → Nov 29 2026   HTTP/2   edge 104.21.59.126
```
⭐ **`/healthz` is the discriminator, not the 200.** A 200 proves *something* answered; the JSON body
names **this** artifact. A parked page, a redirect or a stale worker all return 200.

**THE DNS RECORD**
```
CNAME  beta.commonplace.st  →  commonplace-beta.commonplace-systems.workers.dev
       proxied=true   ttl=1   id d4745b01180fa39c3c67ed417b97be95
```
**PRE-STATE ANCHOR** — the zone held **ZERO records** before this write (measured, `n=0`). ⇒ **Rollback
returns the zone to genuinely empty, not to "one fewer record".**
```
curl -X DELETE -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  https://api.cloudflare.com/client/v4/zones/fcb470ab.../dns_records/d4745b01180fa39c3c67ed417b97be95
```
⭐ **REHEARSED BEFORE THE REAL WRITE, not written down and hoped for:** a disposable `TXT
biscuit-rollback-rehearsal` record was created and deleted, and the zone re-measured at `n=0`. **A
delete path that has never run is a claim, not a capability.**

⚠️ **THE FIRST `dig` RETURNED NOTHING AND THE SECOND RESOLVED.** ⛔ **A one-shot reachability check
here is a coin toss, not a measurement** — the same eventual-consistency trap as the workers.dev
404-then-200 earlier in this round, now hit twice at two different layers. **Both checks retry.**

## How the permission gap actually read — worth keeping

⭐ **The scope was mapped by asking each capability separately, and the pattern it produced was
MISLEADING IN A SPECIFIC WAY:**
```
zone read                 ✅        worker routes read+write  ✅
zone ssl settings read    ✅        DNS records read/write    ⛔ code 10000
```
⛔ **Three zone-scoped reads succeeding beside one zone-scoped refusal looks like a per-endpoint
quirk. IT WAS NOT.** The DNS permission sat on an **ACCOUNT-scoped** policy row (`Account DNS
Settings`), while the working rows were **ZONE-scoped** (`All zones in Commonplace Systems`).
⇒ ⭐⭐ **SAME WORD, DIFFERENT RESOURCE TREE. `DNS` on an account policy does not grant `dns_records`
on a zone** — and nothing in the error says which tree it wanted. ⚠️ **`/user/tokens/verify` returns
`success:false` for this token regardless, so it cannot narrow this either.**

## Phase 2 is NOT started

Release build, container image and production config need `commonplace-next`. ⛔ **Not ranked, not
begun**, and its first act is a release-build measurement — **not the dev-tree literal.**

📌 **This artifact's home is a KNOWN-WRONG PERMANENT ADDRESS, flagged rather than discovered later.**
`cf-src/` and `cf-records/` sit in the coordinator's repo because that is where the deploy tooling
already lives. **It moves when phase 2 gives the app a repo that owns it.**

## Provenance of this record

**EXECUTED** — every value read from `api.cloudflare.com` or measured with `curl`/`dig`/`openssl`
on 2026-09-01 between 05:52Z and 05:58Z. **READ** — nothing. **AGAINST WHAT** — the live account and
the live DNS, not any spec.
