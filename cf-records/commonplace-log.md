# commonplace-log — LIVE, provenance INCOMPLETE

⚠️ **This record is honest rather than complete, and that is the point.** Every field below is
either measured from the API or explicitly `UNKNOWN`. ⛔ **Nothing here is reconstructed from what
would be plausible** — a plausible reconstruction is the failure mode this tool exists to prevent,
and it is indistinguishable from a real answer once written down.

| field | value |
|---|---|
| **WHAT** | Cloudflare Worker `commonplace-log`, account `Commonplace Systems` (`d5c4856e…`). ES modules, `fetch` handler, **5 named handlers**: `CommonplaceLog`, `RealmContainer`, `RealmNode`, `handleIngress`, `ContainerProxy`. Three Durable Object namespaces: `commonplace-log_{CommonplaceLog,RealmContainer,RealmNode}` (`d7514b9cdbcb`, `83aeca8fa2e9`, `2daca0e3cf9d`). Subdomain `commonplace-systems`. `logpush=false`, no placement mode. |
| **WHY** | ⛔ **UNKNOWN — PREDATES TRACKING.** boss-clod is getting the real answer from jes. ⚠️ It is *related to* the `commonplace-log SP4b` work named in `~/.config/cloudflare/do-worker.env`'s own comment — **but that comment explains the TOKEN, not this deploy**, and treating one as the other is exactly the inference this field must not make. |
| **WHO AUTHORIZED** | ⛔ **UNKNOWN — PREDATES TRACKING.** |
| **WHEN** | Deployed `2026-08-24T18:25:47.866948Z`. Last modified `2026-08-25T20:08:52.829288Z`. **Measured, not remembered.** |
| **HOW TO REMOVE IT** | `DELETE /accounts/d5c4856e…/workers/scripts/commonplace-log`. ⛔ **DO NOT.** This is the one live artifact on the account and its three DO namespaces hold state. ⚠️ **The removal path is recorded because the record's format requires it, NOT because removal is sanctioned.** |
| **HOW TO RESTORE IT** | ⛔ **No captured body.** Unlike `cool-recipe-d18f`, nothing here was archived — because nothing was deleted. **A restore path for a live worker is a claim nobody has tested, and this file will not pretend otherwise.** |

## Why this record is a FILE, and why that is a weaker guarantee

⭐⭐ **row 194's rule — *a provenance record written by the deploy path cannot drift; one maintained
beside it can* — CANNOT BE SATISFIED FOR AN ARTIFACT THAT ALREADY EXISTS.** `cf-deploy.sh` writes the
record as part of the deploy call. **This worker was not deployed by that path, so its record is a
file beside the artifact: precisely the drifting kind.**

⇒ **This is a real limit of the design, not an oversight in this file.** Every pre-existing artifact
gets the weak form; only artifacts deployed *through* the path get the strong one. ⚠️ **The set of
weak records shrinks only by redeploying, and nobody should redeploy a live worker to improve its
bookkeeping.**

## The stronger form is available and was NOT taken without authorization

⭐ **MEASURED 2026-09-01:** `PUT .../workers/scripts/<name>/tags` succeeds with this token, and
**tags survive a script redeploy that says nothing about tags** — unlike `plain_text` bindings,
which a forgetful redeploy **erases silently at HTTP 200**. ⇒ **Tagging `commonplace-log` with
`prov:*` would move this record onto the artifact, where it cannot drift and where
`cf-deploy.sh inventory` stops flagging it.**

⛔ **NOT DONE.** That is a **write to the one live worker on the account**, which row 185 fenced as
listed-only. ⚠️ **The fence was written before anyone knew tags were durable, so this is a decision
someone should now make on new information — not one I should make quietly because it is small.**
⇒ **Pending: jes or boss-clod ruling whether `commonplace-log` may be tagged.**

## Provenance of this record

**EXECUTED** — every value above read from `api.cloudflare.com` on 2026-09-01 between 05:31Z and
05:47Z, account `d5c4856e9cb4dd41c12b39fb9df29726`, control `/accounts` (**not**
`/user/tokens/verify`, which returns `success:false` for this working token).
**READ** — nothing. No field was taken from a document, a memory, or another door's summary.
**AGAINST WHAT** — the live account, not any spec. Written by `commonplace-biscuit`, dispatched by
`boss-clod` under commonplace-plan rows 185/194, authorized by jes 2026-09-01.
