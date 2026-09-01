# commonplace-beta — LIVE, phase 1 partial

⭐ **The first artifact to get the STRONG provenance form**: written by `cf-deploy.sh` in the same
call that deployed it, not maintained beside it. Also on the artifact itself as `prov:*` tags.

| field | value |
|---|---|
| **WHAT** | Cloudflare Worker `commonplace-beta`, account `Commonplace Systems` (`d5c4856e…`). ES module, `fetch` handler, two paths: `/` (HTML placeholder) and `/healthz` (JSON). Source at `cf-src/commonplace-beta.mjs`. |
| **WHY** | Phase-1 target for `beta.commonplace.st`: a reachable, TLS-terminated endpoint proving the deployment path end to end **before any `commonplace-next` release artifact exists**. It is deliberately a placeholder — its job is that the path works, not that it serves anything. |
| **WHO AUTHORIZED** | **commonplace-plan row 218**; jes 2026-09-01T06:38:42Z *"parallel yes"*; dispatched by boss-clod. |
| **WHEN** | Deployed 2026-09-01T05:5xZ. |
| **HOW TO REMOVE IT** | `./cf-deploy.sh remove commonplace-beta`, **then** delete the route: `DELETE /zones/fcb470ab…/workers/routes/6a26c1fc1a1d49d09d92d52c73e8225e`. ⚠️ **Two objects, two deletes** — removing the Worker leaves the route behind pointing at a script that no longer exists. |

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

## `beta.commonplace.st` — BLOCKED ON EXACTLY ONE PERMISSION

⭐ **The scope was mapped by asking each capability separately, not by assuming a tier:**
```
zone read                 ✅   GET  /zones/{id}
worker routes read+write  ✅   route beta.commonplace.st/* → commonplace-beta  CREATED (6a26c1fc…)
workers.dev subdomain     ✅   enabled
zone ssl settings read    ✅   full, certificate_status=active
DNS records read          ⛔   code 10000 "Authentication error"
DNS records write         ⛔   (same boundary)
```
⛔ **`CLOUDFLARE_API_TOKEN` LACKS `Zone → DNS`.** Everything else phase 1 needs is already granted.
⚠️ **`/user/tokens/verify` cannot tell you this** — it returns `success:false` for this working
token regardless. **The boundary was found by asking the endpoints, one at a time.**

⭐ **AND THE ROUTE ALREADY EXISTS, so the remaining step is one DNS record and nothing else:**
```
beta  →  proxied A 192.0.2.1  (or AAAA 100::)   — content is irrelevant; PROXIED is what matters
```
The route then binds the Worker to the hostname. ⚠️ **Measured, not assumed:**
`dig beta.commonplace.st` is **NXDOMAIN**, the apex `commonplace.st` has **no A record**, and
`nonexistent-probe-zzz.commonplace.st` is also NXDOMAIN ⇒ **no wildcard to inherit.** The zone is
active on Cloudflare nameservers (`josh`/`meiling.ns.cloudflare.com`) with essentially nothing in it.

⇒ **TO UNBLOCK: jes adds `Zone → DNS → Edit` on `commonplace.st` to the token, or creates the one
`beta` record by hand in the dashboard.** Either finishes phase 1; the second needs no token change.

## Phase 2 is NOT started, deliberately

Release build, container image and production config need `commonplace-next`, which is running
R2–R7. ⛔ **Not ranked, not begun.** Row 218 splits phase 1 precisely so the Cloudflare side does not
touch that repo.

📌 **This artifact's home is a KNOWN-WRONG PERMANENT ADDRESS, flagged rather than discovered later.**
`cf-src/` and `cf-records/` sit in the coordinator's repo because that is where the deploy tooling
already lives. **It moves when phase 2 gives the app a repo that owns it.**

## Provenance of this record

**EXECUTED** — every value read from `api.cloudflare.com` or measured with `curl`/`dig`/`openssl`
on 2026-09-01 between 05:52Z and 05:58Z. **READ** — nothing. **AGAINST WHAT** — the live account and
the live DNS, not any spec.
