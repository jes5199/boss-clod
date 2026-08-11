# CX-vghh — the BEFORE state, for S13-fix's live acceptance

⚠️ **This is a FILTERED artifact, not a raw boot block.** The 11:52 pane scrollback rotated before
I could persist it (rotation is minutes under load, not the hour we assumed). What survives is what
I quoted at the time — which is sufficient for a count-and-identity comparison and NOT sufficient
for anything else about that boot. Stated so the comparison is not over-read.

## Boot of 2026-08-11 11:52Z — serve pid 3515796, code 3f1dd52
Three `CommitStore: local write DENIED by trust gate (enforce)` warnings:

| # | doc_uuid | note |
|---|---|---|
| 1 | 967027b6-ecbe-4a20-a64e-5cd3ef3ff30f | matches NOTHING in the schema — no root entry, nothing under chat/ or bd/ |
| 2 | 6fd72a7f-0f4c-4e31-8d2f-3b27312ecf4a | IS the workspace root — plan's named root-attach check targets this one |
| 3 | 967027b6-ecbe-4a20-a64e-5cd3ef3ff30f | same uuid as #1 (fired twice in one boot) |

**Count: 3 denials, 2 distinct uuids.**

## Boot of 2026-08-11 13:13Z — serve pid 3558563, code cb6d9f9
⛔ **UNKNOWN — NOT MEASURED.** I grepped the pane 15 min later and got 0, but the positive control
failed (the posture block I KNOW was in that boot was also absent at 3000 lines), so the pane had
rotated. **The zero is vacuous and must not be cited as evidence the denials stopped.**

## The AFTER, when S13-fix lands
⇒ Next deploy: `tmux capture-pane -t 0:8 -p -S -3000 > boot-<sha>.log` IMMEDIATELY after boot,
then question the file. Expected per plan's ruling: attempt-once-then-skip-loudly, so a NAMED SKIP
line replaces the denials — **the acceptance is the named skip appearing, not merely the denials
being absent.** An absence alone would be indistinguishable from another rotated capture.

### ⭐ REFINED ACCEPTANCE (commonplace, 2026-08-11 15:13Z, msg #11268 — merged locally @0741fd9)
**The pass is a DISJUNCTION of two NAMED outcomes, selected by whether the live serve's SecretStore
holds bridge-agent custody for the mount. I do not get to pick which; the custody state does.**

| custody | required in the boot log |
|---|---|
| **present** | presence **LANDS SIGNED** + **zero** `DENIED by trust gate` lines |
| **absent** | `GitBridge…: skipped …bridge_agent_signing_key_missing (unsigned fallback disabled)` appearing **EXACTLY ONCE** |

⛔ **SILENCE ON BOTH IS A FINDING, NOT A PASS.** ⇒ This is what closes the vacuity: a rotated or
truncated capture produces neither branch, and so is now *distinguishable* from success instead of
masquerading as the "no denials" reading. **Exactly once** also fails a retry loop, which a bare
absence would have hidden.

⚠️ Note the asymmetry with the BEFORE table above: it has a baseline for the **11:52 boot only**.
The 13:13 boot is UNKNOWN, so *"zero denials across two boots"* has a before-state for one of them.
The disjunction above does not depend on that baseline — it is checkable from the after-file alone,
which is precisely why it is the better criterion.

**Timing:** commonplace says the word once the push lands (gated on a merged-tree full core run —
S13-fix's base predates S15's landing). **No restart is needed before the next natural deploy**
unless we want the acceptance early. My part is read-only and outside their sandbox.

---

# ⛔ THE AFTER — MEASURED 2026-08-11 16:22Z. **BOTH BRANCHES FAIL.**

> ## ✅⚠️ RESOLVED 2026-08-11 16:29Z — **THE FIX PASSED. MY READING OF THIS CAPTURE WAS WRONG.**
> **Read the resolution at the bottom before believing anything in this section.** The measurements
> below are all accurate; the *conclusion drawn from them* — that S13-fix did not take — is not.

**Deploy: serve pid 3671069, sha bba7d56, `merge-base --is-ancestor 0741fd9 bba7d56` = TRUE**
(reverse check returns false, so the ancestry test is not vacuous). **S13-fix IS in the running
tree** — this is not a "the fix wasn't deployed" result.

**Capture: `boot-bba7d56-t75.log`, whole block to a FILE, 57 lines, taken at listener-up+4s and
again at +75s (identical).** ✅ **POSITIVE CONTROL PASSES** — the posture block is present in the
capture, so the absence claims below are meaningful. *This is the control that failed on 13:13 and
made that boot's zero vacuous.*

| branch | required | measured | |
|---|---|---|---|
| A — custody present | signed landing + **zero** denials | **3 denials** | ⛔ FAIL |
| B — custody absent | named skip line **exactly once** | **0 occurrences** (3 spellings grepped) | ⛔ FAIL |

## ⭐ THE SHAPE CHANGED — the part worth having
| | denials | distinct uuids | distribution |
|---|---|---|---|
| BEFORE 11:52 (3f1dd52, pre-fix) | 3 | 2 | 967027b6 ×2, 6fd72a7f ×1 |
| AFTER 16:22 (bba7d56, post-fix) | 3 | **1** | **6fd72a7f ×3**, all `reason=:unsigned` |

⇒ **The 967027b6 denials are GONE; 6fd72a7f went 1 → 3.** Same total, different distribution.
**NEW line, not in the before-state, interleaved one-per-denial** (lines 37/40/43, each immediately
after a denial): `[info] Presence reaper removed 1 stale entries: __git-bridge.bot`.
Also `[info] Bursar started for 6fd72a7f…, 48 active tokens` at line 4, *before* the posture block.

⚠️ **A BARE "3 DENIALS BEFORE, 3 DENIALS AFTER" WOULD HAVE READ AS "NOTHING CHANGED" AND IT IS
FALSE.** The count is identical and the *composition* is not. ⇒ **This is why the before-doc records
uuids and not just a total** — a count alone would have hidden the entire result in a coincidence.

**Reported to commonplace as a measurement (msg #11277). Diagnosis is theirs; I proposed no
mechanism.** CX-vghh stays OPEN. Deploy itself verified clean: HTTP 200 ×3, no dist on 0.0.0.0,
hermes untouched, whole-environ diff old→new dropped only `SCDIR` (a scratchpad var, not Mode-B).

⚠️ **Also corrected to commonplace:** `d8769fa..bba7d56` was described as docs-only briefs; it in
fact contains **S16 code** (7887187 + merge 9d60445), so this deploy shipped S16 too.

---

# ✅ THE RESOLUTION — commonplace, 2026-08-11 16:29Z (msg #11278). **CX-vghh CLOSED, fix PASSED.**

**Took three store reads to separate.** Measured live from the store, not reported:
- The bridge presence **LANDED SIGNED this boot** — root entry `__git-bridge.bot` exists, presence
  doc `bound_identity: git-bridge:6fd72a7f…`, heartbeat written once at **16:22:46**.
- **ZERO bridge-side denials.** Branch A was actually satisfied *by the writer the acceptance was
  about.*

## ⭐ THE THREE DENIALS I MEASURED WERE A **THIRD WRITER** — `Presence.Reaper`
Its stale threshold is **30 SECONDS**. The bridge heartbeats **once** and never again ⇒ 30s after
boot the entry is permanently stale ⇒ the reaper attempts an **UNSIGNED root removal every cycle**,
**DENIED under enforce**, and logs `removed 1 stale entries` **AFTER EACH DENIAL**.
⇒ **The interleaving I photographed (denial 37 → reaper 40, ×3) IS that loop.** My capture was
correct and complete; it contained two writers' stories and I attributed both to one.

⛔ **THE REAPER'S SUCCESS LINE IS A FALSE SUCCESS** — the action reporting on *itself*, not on the
outcome. Under enforce the reaper's entire function is **dead without saying so**. ⚠️ And under
**permissive** this pair would **silently DELETE the bridge presence 30s after every boot** — so
*the denial is the only reason it is visible at all.* **Filed CX-9jds (p2).**

## ⭐⭐ THE LESSON — AND IT IS NOT "THE DISJUNCTION WAS WRONG"
commonplace's words: *"the disjunction wasn't wrong, the world had one more writer than the
acceptance modeled."* **A two-branch acceptance with silence-as-finding turned a confusing result
into a mechanism instead of a shrug** — neither-branch forced the investigation that found CX-9jds.
⇒ ⭐ **AN ACCEPTANCE MODELS A SET OF WRITERS.** Both branches keyed on *what the log shows*, with an
unstated premise that **the only thing writing to this doc during boot is the thing under test.**
Same family as the count that hid the composition change: **the artifact was never ambiguous — my
model of who could have produced it was too small.**
⇒ **NEXT TIME: name the expected writers, not just the expected lines.** An unattributed line is not
evidence about the writer you had in mind.

⚠️ **I reported "the fix did not take" to its author.** It cost commonplace three store reads to
show otherwise. **Reporting the measurement without a mechanism was right and is what made the
correction cheap** — had I also shipped a theory, the theory is what would have been argued with.

**CX-vghh CLOSED with a RECORDED REASON — the first production reasoned close**, S15's idiom
demonstrated live (closed_reason re-read, naming the fix sha, the live verification, and CX-9jds as
the unmasked successor).
