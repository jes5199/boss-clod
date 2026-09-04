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

## TAGGED 2026-09-01T05:44:39Z — and it cost a signal nobody predicted

**Authorized by boss-clod on the measurement that `PUT .../tags` is a separate metadata endpoint,
account holds nothing production, small and reversible.**

**PRE-STATE ANCHOR** — captured *before* the write, which is what makes the rollback a command:
```
tags          []
etag          b40f16a4ab5be14dcda736cd56ff98bdb91341c4fec8282b346fa5c7374b0582
modified_on   2026-08-25T20:08:52.829288Z     ← THE REAL LAST CODE CHANGE. See below.
created_on    2026-08-24T18:25:47.866948Z
handlers      CommonplaceLog RealmContainer RealmNode handleIngress ContainerProxy
DO namespaces 3
```
**ROLLBACK — one command, and it was REHEARSED on a disposable worker before the live write:**
```
curl -X PUT -H "Content-Type: application/json" --data '[]' \
  https://api.cloudflare.com/client/v4/accounts/d5c4856e…/workers/scripts/commonplace-log/tags
```
⭐ **The rehearsal is the point.** A restore path that has never run is a claim, not a capability —
so it was run, on `biscuit-rollback-rehearsal-20260901`: `[] → [prov:x,prov:y] → []`, all 200,
worker deleted after.

**VERIFIED BY EFFECT, not by the 200:**
```
✅ etag           unchanged   ← the running code was not touched
✅ handlers       unchanged
✅ DO namespaces  unchanged (3)
✅ tags           [] → 4 prov: entries   (the only thing that may move)
⛔ modified_on    2026-08-25T20:08:52Z → 2026-09-01T05:44:39Z
```

⛔⛔ **THE COST, AND IT WAS NOT PREDICTED BY ANYONE INCLUDING ME: A TAG-ONLY WRITE MOVES
`modified_on`. THE PROVENANCE WRITE DESTROYED A PROVENANCE SIGNAL.**

⭐ **Measured, not argued** — a fresh disposable worker, code never touched, tagged once:
`modified_on 05:45:02 → 05:45:06`, `etag` identical. ⇒ **`modified_on` records ANY write, tags
included. It is a property of the endpoint, not of this worker.**

⚠️ **Why that matters: `modified_on` was being READ AS "when the code last changed" — boss-clod's
own inventory reported `commonplace-log modified 2026-08-25` as a provenance signal.** For this
worker that reading is now **false**, and nothing in the API says so. ⇒ **The pre-state anchor above
is the only surviving record of the real last code change, `2026-08-25T20:08:52.829288Z`.**

⭐⭐ **THE GENERAL RULE: `etag` IS THE CODE'S IDENTITY; `modified_on` IS THE RECORD'S.** Anything
that writes metadata advances `modified_on` while leaving `etag` fixed. **Compare `etag` to ask
"did the code change"; `modified_on` cannot answer it once anything else may write.**

⚠️ **AND MY OWN GATE FIRED ON CORRECT STATE, WHICH IS THE FAILURE MODE boss-clod NAMED TONIGHT.**
I asserted `modified_on unchanged` as a condition of a metadata-only write, and it is not one.
⛔ **The requirement was mis-specified; the world was fine.** ⇒ **It was resolved by MEASURING the
endpoint on an independent disposable worker — not by relaxing the assertion until it passed, which
is what that situation always invites.** The invariant I actually meant, `etag` unchanged, held.

**Applied tags:**
`prov:managed-by-cf-deploy` · `prov:record=cf-records/commonplace-log.md` ·
`prov:why=UNKNOWN-predates-tracking` · `prov:live-do-not-delete`

## The stronger form, and why it was not taken without authorization

⭐ **MEASURED 2026-09-01:** `PUT .../workers/scripts/<name>/tags` succeeds with this token, and
**tags survive a script redeploy that says nothing about tags** — unlike `plain_text` bindings,
which a forgetful redeploy **erases silently at HTTP 200**. ⇒ **Tagging `commonplace-log` with
`prov:*` would move this record onto the artifact, where it cannot drift and where
`cf-deploy.sh inventory` stops flagging it.**

✅ **DONE, ON AN EXPLICIT RULING, NOT QUIETLY.** The fence predated knowing tags survive a redeploy,
so it was a decision to be re-made on new information rather than one to slip through on smallness.
⭐ **boss-clod granted it WITH ITS REASONING EXPOSED SO IT COULD BE REFUSED IF A FACT WERE WRONG** —
and the fact that turned out to be wrong was mine, not theirs: `modified_on` does move. **The grant
survives it; the record above states the cost.**

## Provenance of this record

**EXECUTED** — every value above read from `api.cloudflare.com` on 2026-09-01 between 05:31Z and
05:47Z, account `d5c4856e9cb4dd41c12b39fb9df29726`, control `/accounts` (**not**
`/user/tokens/verify`, which returns `success:false` for this working token).
**READ** — nothing. No field was taken from a document, a memory, or another door's summary.
**AGAINST WHAT** — the live account, not any spec. Written by `commonplace-biscuit`, dispatched by
`boss-clod` under commonplace-plan rows 185/194, authorized by jes 2026-09-01.

---

## ✅ `WHY` AND `WHO AUTHORIZED` RECOVERED 2026-09-01T06:04Z — FROM OUR OWN HISTORY, NOT FROM jes

**jes, 06:03:02Z:** *"man i have no idea what that DO is. you guys made it."* ⇒ **The blank was never
his to fill. It was recoverable at `/home/jes/commonplace-log`, and nobody had looked.**

**WHAT IT IS** [READ · `/home/jes/commonplace-log/README.md`]: the Cloudflare realm deployment of the
**Commonplace Monotonic Log** — *"gateway, per-realm Durable Objects with per-realm secrets, BEAM
engine in Containers, single-lane documents over the sidecar"* — **deployed on a development account**
and verified by hand and by env-gated tests. Milestone **SP4b**. The three DO namespaces
(`CommonplaceLog`, `RealmContainer`, `RealmNode`) are that deployment's per-realm objects.

**WHY** [READ · commit trail, `/home/jes/commonplace-log`]:
```
0eb3d72  2026-08-23  plan: SP4 Cloudflare realm sidecar, split at the verifiability line
22f2566  2026-08-24  feat(sp4b): realm gateway deployed; two-realm isolation verified against real Cloudflare
6c433ed  2026-08-24  feat(sp4b): RealmNode container DO and the storage.internal outbound handler
```

**WHO AUTHORIZED** [READ · commit `4e94986`]: **`feat(protocol): operation_id is REQUIRED in entry
version 2 (jes ruling 2026-08-25 19:48Z)`** — a jes ruling cited in the commit itself.

⚠️ **AND ONE INFERENCE, LABELLED AS ONE RATHER THAN STATED AS FACT.** The worker's pre-tag
`modified_on` was **`2026-08-25T20:08:52Z`**, which falls **42 seconds after** `4e94986` (20:08:10) and
**37 seconds before** `7e3f6d2 chore: bump container build stamp for the v2 image rollout` (20:09:29).
⇒ **The last code deploy was almost certainly that v2 rollout.** ⛔ **This is a TIMESTAMP CORRELATION,
not a recorded deploy. It is the best available evidence and it is not a receipt** — which is the exact
gap `cf-deploy.sh` exists to close for every artifact deployed from here on.

⭐⭐ **AND THE ENV-FILE COMMENT biscuit REFUSED TO USE TURNS OUT TO HAVE BEEN RIGHT.** `do-worker.env`
says `commonplace-log SP4b`, and SP4b is exactly what this is. ⇒ ⛔ **THE REFUSAL WAS STILL CORRECT.**
**That comment explains the TOKEN, not the deploy; it was a plausible adjacent string, and it happened
to be true.** ⭐ ***A guess that turns out right is still a guess, and the way you tell the difference
is that this entry cites a README and a commit sha and that one cited proximity.*** ⚠️ **Had it been
wrong, nothing downstream would ever have caught it — the same property that makes a self-claim that
comes true invisible.**

---

## ⛔ DEPLOY HAZARDS — WRITTEN 2026-09-04 ~09:2xZ, BEFORE ANY FUTURE DEPLOY, NOT AFTER ONE

**Why this section exists:** a deploy window for `STORE-3b` was granted at 09:15Z (boss-clod) and
**expired unused at 09:45Z by the deploying door's own STOP**. ⭐ **No write was made — every call
below is a `GET`.** These hazards were found while writing the grant's closing control (*"a control
that something you meant to leave alone is untouched"*) — **the control was written, discovered the
thing would be touched, and stopped the act.** They are recorded here because **the second one is
unmeasurable without performing the thing it warns about, so it can only ever be a WRITTEN HAZARD,
never a check.**

### ⭐⭐ HAZARD 1 — `wrangler deploy` ON THIS WORKER IS NOT "UPLOAD A SCRIPT". IT ROLLS OUT A BEAM IMAGE.

`worker/wrangler.jsonc` carries a `containers` block; the deploy verb builds and pushes an image.
```
containers[0]  name=commonplace-log-realm  image=../commonplace_log/Dockerfile  context=../commonplace_log
Dockerfile     COPY config config  ·  COPY lib lib        ⇒ THE IMAGE *IS* commonplace_log/lib
```
The repo's own `docs/sp4b-deployment-readiness.md` states the verb: *"new image digest pushed,
application modified, changes applied"*, and separately that **the rollout is STAGED** — the
application sits in `provisioning` for ~6 minutes and containers started in that window still run
the OLD image. ⇒ **"Deployed" means the Worker; the container image follows on its own schedule.**

⛔⛔ **THE CLASS, AND IT IS THE GENERAL LESSON, NOT A FACT ABOUT THIS REPO:**
> ⭐ **A WARRANT SCOPED TO A DIFF DOES NOT SCOPE THE ACT THAT SHIPS IT, AND NOTHING IN THE
> WARRANT'S OWN LANGUAGE REVEALS THE DIFFERENCE.**

`STORE-3b`'s landing was **"3 files, all under `worker/`"** — **TRUE about the LANDING and FALSE
about the DEPLOY.** At `d0aff782` the same act would also have shipped **three `commonplace_log/lib`
files belonging to another door's `STORE-1a` work, unreviewed by the deploying door and outside
`STORE-3b`'s range of 1**, to a live application:
```
lib/commonplace/log/document_profile/lane/sqlite.ex
lib/commonplace/log/persistence/sqlite_server.ex
lib/commonplace/log_store/sqlite/server.ex
```
⇒ **RULED (boss-clod 09:18Z, option C): the deploy stays OWED and becomes ONE act deploying ONE
tree, after the container half is warranted by whoever owns it.**

### ⚠️ HAZARD 2 — THE ACCOUNT HAS TWO CONTAINER APPLICATIONS; THE CONFIG DECLARES ONE.

`[measured 2026-09-04 ~09:1xZ · GET /accounts/d5c4856e…/containers/applications · success:true, 2 results]`
```
commonplace-log-realm   a03e41ce-bee3-4a63-a157-4c51a62bfb61   version 5   instances 7   ← IN wrangler.jsonc
   image  registry.cloudflare.com/d5c4856e…/commonplace-log-realm@sha256:97a89b1bd5180e1dd8b8de1a9a7bed424c08d8e77189d1d1d3c1e6c03eaabc53
commonplace-log-probe   a0340b11-036b-47b5-b483-fc9b595fe95f   version 1   instances 2   ← NOT IN wrangler.jsonc
   image  registry.cloudflare.com/d5c4856e…/commonplace-log-probe@sha256:a5a031013655ae25f8ce16277843b8d208a48c1449c1e4b2dc592c6592164b58
```
⛔ **Whether `wrangler deploy` (local `4.125.0`) reconciles an UNDECLARED application away is
UNKNOWN, and the only instrument that answers it is the deploy itself.** ⭐ **That is a coin-flip on
a live object with two running instances, which is not a measurement.** ⇒ **Anyone deploying this
worker must decide about `commonplace-log-probe` DELIBERATELY and in advance — its absence from
`wrangler.jsonc` is not evidence that it is disposable, only that the config does not know it.**

### 📌 HAZARD 3 — A DEPLOY RE-ASSERTS A TEST LEVER, AND THE CONFIG SAYS SO ITSELF.

`worker/wrangler.jsonc`: `"vars": { "REALM_TEST_LEVERS": "1" }`, carrying its own comment —
*"Development deployment only. This must be `""` or absent in every other deployment."*
⇒ **This IS the development account, so it stays.** It is recorded because **a deploy re-asserts it
every time**, and it should be read off a record before the act rather than discovered after one.

### ✅ AND THE FIELD THIS RECORD WAS WRITTEN FOR, PAYING OUT THREE DAYS LATER

```
live worker etag  b40f16a4ab5be14dcda736cd56ff98bdb91341c4fec8282b346fa5c7374b0582
                  IDENTICAL to the PRE-STATE ANCHOR captured above on 2026-09-01T05:44:39Z
```
⇒ ⭐ **The serving code is still the 2026-08-25 code; nothing has deployed over it since.** So
`deployed ≠ <any later tree>` is **MEASURED, not inferred** — and it is measurable *only* because
the anchor was written down before the tag write moved `modified_on` and destroyed the other signal.
⛔ **`last-modified` on the same read says `2026-09-01 05:44:39` — the TAG write, not a code change.
Reading it as a deploy date would be wrong, exactly as this record warned.**

**Provenance of this section:** EXECUTED — `etag` and the applications list read from
`api.cloudflare.com` 2026-09-04 between ~09:16Z and ~09:22Z with the account token; **GET only, no
write, nothing to roll back**. READ — `worker/wrangler.jsonc`, `commonplace_log/Dockerfile` and
`docs/sp4b-deployment-readiness.md` at `commonplace-log` `origin/main`
`d0aff782eed27ad1c40f594c135942bd1c1c8b1f`; ranges by `git diff` against `7e3f6d2`. Written by
`commonplace-biscuit`, ruled by `boss-clod` 09:18Z.
