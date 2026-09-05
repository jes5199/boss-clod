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

---

## D2 — KEY-SCHEME CONFIDENTIALITY POSTURE, **PROVISIONAL** (recorded 2026-09-05T16:02Z)

⚠️ **THIS IS A PROVISIONAL POSITION, NOT A DECISION.** Recorded by `boss-clod` because `cf-records` is
reserved to my window and `BACKUP-KEYS-1`'s D2 requires the position to live here. **I am the scribe,
not the decider** — if a later reader treats this row as settled because it is written down, that is
the failure this paragraph exists to prevent.

**Position, from `codex-commonplace-log` (msg 29909), marked by it as PROVISIONAL pending a measured
fixture oracle** — option **B, accept-and-document**:
- **Both the CONTENTS and the LISTINGS of the backup bucket are SENSITIVE**: a key listing is a
  **membership roster** and, because `document_id == log_id`, a **document inventory**.
- **Derived keys are retained** — they keep idempotence and require no mapping dependency, which is
  the durability property opaque keys would trade away.
- **Operational consequence, and it is the part that binds people rather than code: no live index is
  ever copied into a ticket, a channel, or a report.**

**Priced by `commonplace-plan`** (brief `00e6ce7`, ordering row 1011): changing the scheme costs
`O(1)` **now** and `O(whole backup)` **after the first real run**; exposure today is **nil** because
nothing reads the bucket. ⇒ **the ruling must precede the first cron tick, not the merge.**
Plan's recommendation: accept and document — *opaque keys trade a durability property for a
confidentiality one inside a durability feature* — **explicitly a recommendation with both costs
priced, not a ruling.**

⛔ **UNTIL A FINAL RULING EXISTS, THE DEPLOY HOLD IN `cf-records/commonplace-log.md` STANDS.**

### ⚠️ CORRECTION TO THE PRICING ABOVE, 2026-09-05T16:03Z — the cost of option A was mis-stated

**Source: `codex-commonplace-log` msg 29913, accepted by `commonplace-plan` (its msg 29910).**
Corrected **before** the posture reached any decision owner, which is the only reason it costs nothing.

⛔ **WRONG (do not carry):** that a missing mapping under opaque keys causes **inevitable duplication**.
✅ **RIGHT:** under **fail-closed** handling, a missing mapping causes a **NAMED BACKUP OUTAGE** — the
backup stops and says so.

⭐ **THE TWO ARE NOT THE SAME KIND OF COST AND THEY RANK DIFFERENTLY:** duplication is **silent data
growth** discovered later; a named outage is **loud and immediate**, and a loud failure in a durability
feature is the *good* failure — it is exactly what "frontier written last" buys elsewhere in this
system. ⇒ **The corrected pricing makes option A less bad than the original framing implied**, so
anyone who accepted B on the strength of the duplication claim accepted it on a wrong number.

**Whoever rules on D2 must be given the AVAILABILITY cost, not the duplication claim.** Carried here
so the file cannot hand a stale price to a later reader.

---

## ✅ D2 RULED — option (B), derived keys retained. `commonplace-plan`, 2026-09-05T16:03Z (msg 29915)

**Supersedes the PROVISIONAL row above. This is plan's ruling, recorded by boss-clod as scribe.**
I had asked whether it was plan's ruling or jes's acceptance. **Plan ruled it is plan's, and gave the
argument rather than the verdict**, which is why the reasoning is recorded here and not just the answer.

⭐ **THE TEST: is the INDEX exposure strictly dominated by the CONTENTS exposure?** Anyone who can list
the bucket can **read every backed-up document in it**. Contents ⊃ index. ⇒ **for the "who can read
the bucket" threat, derived keys add NOTHING to the threat model** — the bucket is already exactly as
sensitive as every document it holds, and no key scheme changes that. **There is no new disclosure
surface to accept in that case**, which is the case my "this is jes's to accept" reading was about.

⭐ **WHERE IT IS GENUINELY NOT DOMINATED — the index TRAVELLING ALONE:** a manifest pasted into a
ticket, a run log shared to debug a failure, an inventory quoted in a status report. There the reader
gets the **roster and the document inventory without the contents.** ⇒ **that is an INTERNAL HANDLING
RULE ABOUT OUR OWN ARTIFACTS, not a disclosure to anyone outside** — inside plan's fence, and exactly
what **D4 mechanises**, which is why the recommendation was (B) **plus a mechanism**, never (B) alone.

## ⛔⛔ THE TRIGGER THAT FLIPS THIS TO jes'S DECISION — measurable, not a matter of judgement

**IF the bucket, or any listing derived from it, is ever shared with a party who is NOT ENTITLED TO
THE CONTENTS** — an auditor · a customer taking their own export · a support tier with
listing-but-not-read access — **THE DOMINATION ARGUMENT FAILS AND D2 BECOMES jes'S DECISION**, because
that is a real outward-facing disclosure.
⇒ **Whoever proposes such a share re-opens D2 first. Do not treat this ruling as covering it.**

**Deploy hold status:** the `1b-ii` hold in `cf-records/commonplace-log.md` **lifts on plan's word once
D1 and D4 land** — not on this ruling alone. Pricing correction of 16:03Z (fail-closed outage, not
inevitable duplication) stands and was accepted by plan before the ruling.

### ⚠️ AMENDMENT 2026-09-05T16:10Z — the ACCEPTED EXPOSURE was recorded OVERSIZED. Ruling unchanged; its SIZE corrected.

**Source: `commonplace-plan` row 1014, plan `6645541`, correcting its own row 1004 after the log door
measured the finding's true size. Amended here BEFORE any reader inherited the exaggeration.**

⛔ **WRONG (as recorded above): the key listing is "a membership roster."**
✅ **RIGHT: it is a HISTORICAL roster.** `editor_cell_id` is keyed on `membership_epoch`, which carries
`membership_generation` — **a member removed and re-added derives a DIFFERENT id**, and the backup
retains historical objects. ⇒ **the oracle answers *"did `(org, member, generation)` exist at some
point"*, NOT *"is this member in the organization now."***

⚠️ **THIS REVERSES NOTHING.** A historical roster is still a roster, and the `document_id == log_id`
**document-inventory** half is untouched. The **flip trigger** and the **deploy hold** are unaffected.
⭐ **But it changes what the ruling is on the hook for:** an **oversized finding accepted by a ruling
makes the ruling look more permissive than it is**, and the next reader inherits the exaggeration as
the baseline.

## ⭐ AND A DEFECT IN THE **REJECTED** OPTION'S SPEC — recorded because nobody ever tests a rejected option

Plan's option **(A) was INCOMPLETE AS WRITTEN**: it described an opaque **key** mapping and **never
said the MANIFEST must be opaque too.** ⇒ an implementer following (A) faithfully would ship **opaque
keys plus a manifest leaking the same inventory** — a confidentiality change that **costs idempotence
and buys nothing.** The cheap variant (a random realm prefix) leaves raw log ids visible for the same
reason.

⭐⭐ **AUDITING THE OPTION THAT LOST COSTS NOTHING TO SKIP, WHICH IS EXACTLY WHY IT GETS SKIPPED.**
A rejected option is never built, so **its specification is never tested by anyone** — nobody would
have noticed (A) was unimplementable, **and a future round reversing this ruling would have inherited
it as a plan.**
⛔ **Recorded as a defect in the rejected option's spec, explicitly NOT as a further argument for (B).**
**(B) does not get credit for (A) having been described badly.**
