# `commonplace-log-backup` — R2 bucket, created 2026-09-04T14:26:46Z

| field | value |
|---|---|
| **WHAT** | R2 bucket `commonplace-log-backup`, account `Commonplace Systems` (`d5c4856e…`). `creation_date 2026-09-04T14:26:46.034Z` · `location WNAM` · `storage_class Standard` · `jurisdiction default`. **The FIRST bucket on this account** (`r2-enabled.md`: R2 enabled 2026-09-01, 0 buckets, unused). ⛔ **No binding, no cron, no Worker reads or writes it yet.** |
| **WHY** | `BACKUP-1a` (commonplace-plan row 845, brief `2026-09-04-BACKUP-1-brief.md`): an **append-only backup of every realm's log**, walked under `STORE-3b`'s READ capability so the backup never holds a write secret. Roadmap row 10 / D5 — durability's second half, beta-gating. ⭐ **jes 2026-09-01T17:33:54Z, unprompted and BEFORE any round asked: *"i think we may want R2 for backups and long-term storage anyway"*.** ⇒ **The purpose was stated before the bucket existed, which is why this field is a citation and not a rationalisation.** ⛔ **Object storage has no append semantics: R2 is for the BACKUP, never the live log.** |
| **WHO AUTHORIZED** | **plan row 845 dispatched `BACKUP-1a`; boss-clod granted the write window 14:26Z→15:10Z for ONE bucket plus a rehearsal PUT/DELETE — no binding, no cron, no deploy;** standing posture is jes's 2026-08-05 deploy authorization. Executed by `commonplace-biscuit`. ⚠️ **boss flagged that this is the first BILLABLE resource in this arc — an empty bucket plus one deleted object is negligible and reversible in one call, and jes is TOLD as a fact. ⛔ If `BACKUP-1b`'s loop would accumulate real data, that is a QUESTION for jes BEFORE the loop.** |
| **WHEN** | Created `2026-09-04T14:26:46.034Z`. **Measured from the API, not remembered.** |
| **HOW TO REMOVE IT** | **RE-DERIVED from the artifact, not copied from another record** — and **RUN, not merely written**: `DELETE /accounts/d5c4856e…/r2/buckets/commonplace-log-backup` (the bucket must be empty first; delete objects with `DELETE …/r2/buckets/commonplace-log-backup/objects/<key>`). |
| **HOW TO RESTORE IT** | `POST /accounts/d5c4856e…/r2/buckets` `{"name":"commonplace-log-backup"}` — the exact call that created it, `success:true`. ⛔ **A new bucket is EMPTY: recreating the container does not restore contents, and nothing here is a claim that it would.** |

## The rehearsal — the removal path RUN, with the listing shown BOTH ways

⭐⭐ **This is the point of the round's Cloudflare half, not the bucket.** `cool-recipe-d18f` carries an
open item precisely here: **its restore path was recorded and never executed, and that record says so.**
**An untested removal path is a claim, not a capability.**
```
⓪ listing, bucket empty                       0 object(s)   []
① PUT rehearsal/2026-09-04T14-2xZ-removal-path.txt          success: true
② listing WITH the object present             1 object(s)   ['rehearsal/2026-09-04T14-2xZ-…']   ⇐ POSITIVE CONTROL
③ DELETE the same key                                        success: true
④ listing after the delete                    0 object(s)   []
```
⛔ **Step ② is what makes step ④ mean anything.** A listing that returns `0` and a listing that is
BROKEN are the same observable; only having seen it return `1` for a known-present object separates
them. ⇒ **The zero at ④ is a measurement; without ② it would be a hope.**
📌 The rehearsal object contained **no realm data and no capability value** — its whole text was a
sentence saying what it was for.

## The closing control — what this write did NOT touch

⭐ **boss granted the window on this, not on "did the bucket appear": a post-check that asks only about
the thing you changed passes equally if everything else is gone.**
```
                              BEFORE (14:2xZ)                         AFTER (14:2xZ)          verdict
worker commonplace-log        etag 8cb2680e52ed5852…                  etag 8cb2680e52ed5852…  ✅ unmoved
worker commonplace-beta       etag db37a1f0ffa6f434…                  etag db37a1f0ffa6f434…  ✅ unmoved
DO namespaces                 3                                       3                       ✅ unmoved
container commonplace-log-realm  v6 / 7 instances                     v6 / 7 instances        ✅ unmoved
container commonplace-log-probe  v1 / 2 instances                     v1 / 2 instances        ✅ unmoved
R2 buckets                    0                                       1 (the one named)       ✅ the ONLY change
```

## Provenance of this record

**EXECUTED** — every value read from `api.cloudflare.com` on 2026-09-04 between 14:2xZ and 14:3xZ with
the account token (`~/.config/cloudflare/do-worker.env`), account `d5c4856e9cb4dd41c12b39fb9df29726`.
The `WHY` citation is **READ** from `cf-records/r2-enabled.md`. **AGAINST WHAT** — the live account.
Written by `commonplace-biscuit` under plan row 845 and boss-clod's 14:26Z window.
⛔ **No capability value, no realm data, and no secret appears in this file or in the bucket.**
