# cool-recipe-d18f — DELETED 2026-09-01

⭐ **The first provenance record, written for an artifact that had none.** It exists because nobody
could answer WHY this worker was deployed, and that single missing field cost more than everything
else about it combined.

| field | value |
|---|---|
| **WHAT** | Cloudflare Worker `cool-recipe-d18f`, account `Commonplace Systems` (`d5c4856e…`) |
| **WHY** | ⛔ **Nothing intentional.** Verbatim `npm create cloudflare` scaffold — *"Welcome to Cloudflare Workers! This is your first worker."*, returning `Hello World!`. Created `2026-08-24T17:56:05.718Z`, modified `…06.281Z` — **0.5s later, never edited.** Deployed during the Aug 22–24 wrangler session as a getting-started run or connectivity check, then abandoned. |
| **WHO AUTHORIZED** | Deletion: **jes, 2026-09-01T04:33:52Z — "delete it when you want to"**, after inspection answered the provenance question. Original deploy: unattributed; that absence is the reason this file exists. |
| **WHEN** | Deployed 2026-08-24. Deleted 2026-09-01T04:35Z. |
| **HOW TO REMOVE IT** | Done. `DELETE /accounts/<id>/workers/scripts/cool-recipe-d18f`. |
| **HOW TO RESTORE IT** | Body at `cf-records/cool-recipe-d18f.body.txt` (752 B, sha256 `9aa4104581a38f97…`), metadata at `…meta.json`. ⚠️ Untested — no redeploy was attempted. **A restore path that has never run is a claim, not a capability.** |

## The transition, asserted — not the API's answer

⛔ **`success: true` is the command's answer, not the world's.**
```
present before   1        present after   0
total workers    2   →    1
CONTROL  commonplace-log still present          ✅
CONTROL  3 durable-object namespaces untouched  ✅
```
⭐ **Both controls are the half that matters: they prove the delete hit ONLY its target.** A
post-check that asks *"is it gone?"* passes equally if everything is gone.

## What this artifact taught, at the cost of nothing

⭐ **WHY IS THE ONLY FIELD NOT RECOVERABLE AFTERWARD.** What, when, and how-to-remove were all
retrievable from the API in two minutes. **The provenance question was expensive precisely because it
was the one thing the platform does not store.**
⇒ **Test for any record's format: could I recover this field in two minutes from the API if the record
were lost? If yes, it is convenience. If no, it is the record's entire job.**

⭐ **AND THE FENCE WAS DISCHARGED, NOT OVERRIDDEN.** commonplace-plan row 194: *an unknown-provenance
artifact is the last thing to delete, because deletion makes the unknown permanent.* ⇒ **The rule
bought the ten minutes it took to look, then stopped applying.** It was not waived because the
artifact seemed harmless — **it was satisfied by answering the question it was protecting.**

---

## ⚠️ ANNOTATION 2026-09-01T05:46Z — THIS RECORD'S "NEVER EDITED" INFERENCE IS SOUND BY LUCK

This record leans on the **0.5-second create→modify gap** as evidence the worker was never edited
after deployment. ⭐ **That inference is still true HERE — nothing ever wrote metadata to this
worker — but it is true by accident of history, not by construction.**

⛔ **`modified_on` ADVANCES ON A TAG-ONLY WRITE** (measured by commonplace-biscuit on a disposable
worker, 2026-09-01: `05:45:02 → 05:45:06`, **`etag` identical, code never touched**). ⇒ **Under the
`cf-deploy.sh` tooling that now exists, recording provenance would have destroyed exactly the signal
this record cites.** It happened to `commonplace-log` within the hour:
`modified_on 2026-08-25T20:08:52Z → 2026-09-01T05:44:39Z`, `etag b40f16a4…` unchanged.

⇒ ⭐⭐ **`etag` IS THE CODE'S IDENTITY; `modified_on` IS THE RECORD'S.** Any future record asking
*"did the code change"* must compare **`etag`**. `cf-inventory.sh` now prints `etag` first and says so.
