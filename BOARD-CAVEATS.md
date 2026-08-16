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
