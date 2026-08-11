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
