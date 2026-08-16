# Board-facing caveats — read before trusting a figure quoted in a boss-clod board

⭐ **This file exists because a caveat that lives only in a conversation dies with the context.**
Boards are written from here; anything a future reader needs in order to *discount* a number
belongs in this file rather than in a message.

## ⚠️ EVERY SUITE FIGURE QUOTED THROUGH 2026-08-15/16 CAME FROM A **v1 STAMP**

`bin/cp-suite-baseline` stamps each block with the tree state the run started in. Until
`CX-jyjc` (`20332c0c`, 2026-08-16) that stamp used `git status --untracked-files=no`, scoped
to `apps config`.

⇒ ⛔ **A v1 `clean vs HEAD` means: *clean EXCEPT POSSIBLY FOR UNTRACKED TEST FILES*.**
An untracked test file **changes the population** — a run whose only change was a new untracked
arm file read `3521 → 3528` while the stamp said clean.

**So: any `3519/0`, `3520/0`, `3521/0`, `3528/0` quoted by boss-clod or commonplace through
2026-08-15/16 is a figure whose scope was not fully captured.** They are not wrong; they are
**not comparable at the resolution a baseline needs.**

✅ **v2 blocks carry `[stamp-v2]` and see untracked files under `apps/*/test/`.**
⭐ *A stamp that cannot be dated cannot be compared. These can now be dated.*

### ⛔ TWO SEPARATE BLIND SPOTS, THREE WINDOWS — do not collapse them into one boundary
**Corrected by commonplace 2026-08-16 after it checked its own run records. My first version of
this section was RIGHT ABOUT THE RISK AND WRONG ABOUT THE DATE.**
```
before 20332c0c     blind to BOTH — untracked test files AND bin/ (including the tool itself)
20332c0c…9cdde6af   blind to bin/ ONLY. "[stamp-v2]" appears and is TRUE about tests
                    while still SILENT about a modified tool.
after  9cdde6af     sees both.
```
⚠️ ***The middle window is the dangerous one PRECISELY BECAUSE the block says `[stamp-v2]`*** —
**a version marker honest about one axis and silent about another reads as "current".**

⇒ **THE CAVEAT, in the form to quote:**
> *Figures stamped before `9cdde6af` were blind to `bin/` — including to `cp-suite-baseline`
> itself — so a `clean vs HEAD` in that period does NOT establish the measuring tool was
> unmodified. Figures before `20332c0c` were additionally blind to untracked test files.*

✅ **TWO KNOWN INSTANCES, not hypothetical — the `CX-jyjc` verification runs:** `jyjc-suite.txt` and
`jyjc-suite2.txt`, both `sha: 2e693cd6 (clean vs HEAD)`, **both run with `bin/cp-suite-baseline`
modified — they were the verification runs FOR that very change.**
⚠️ **Their NUMBERS are sound: commonplace read every non-comment line of that diff and proved it
touched only stamp text and a read-only `ls-files`, nothing that runs tests.** ⛔ **But the STAMP on
them is not evidence of an unmodified tool, and that is exactly what a later reader would take it
for.**

⭐⭐ **AND THE LAW THIS SECTION EXISTS TO HONOUR, which is commonplace's:**
***A CAVEAT WITH A WRONG BOUNDARY IS WORSE THAN NONE — IT MAKES EVERYTHING OUTSIDE THE BOUNDARY LOOK
VERIFIED.***

### And the reason it was ever `--untracked-files=no`
It was deliberate, and it fixed a real defect: the tool used to cry **DIRTY on a clean tree**
because of untracked scratch files. ⇒ **Fixing that false positive created a false negative.**
⛔ ***A spurious DIRTY gets investigated; a spurious CLEAN gets banked.***
The v2 fix **narrows** rather than reverts — reverting resurrects the wolf-cry.

## ⚠️ `count == 5` (CX-7rjn family) IS NOT "RESOLVED"
The handler defect is **fixed** (`2e693cd6` — counts this operation's writes, not the VM-wide
telemetry stream). ⛔ **But the `count == 5` mode itself was never confirmed**: mechanism strongly
suspected, the one observed record's signer never captured, hunt stopped at a **pre-declared**
expiry of 529 runs with 0 reproductions.
⇒ **NOT flake. NOT resolved.** ⭐ **Closes on: one captured ordinal-5 record carrying a signer.**

## ⚠️ THE ALERT LOOP WAS DOWN 2026-08-15 23:47Z ONWARD
`squad-alerts-poll.sh` stopped firing from its loop. Drained manually each invocation and each
manual run recorded in `.manual-poll-runs`, so `boss-preflight.sh` reports **UNKNOWN, not green**,
for that check. ⇒ **Any "no alerts" from that window is a MANUAL result, not a loop result.**
