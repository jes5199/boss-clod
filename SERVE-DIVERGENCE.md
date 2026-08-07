# ⚠️ THE LIVE SERVE IS RUNNING CODE THAT IS **OLDER** THAN MAIN

**Opened 2026-08-07 ~19:45Z. REVERSED 2026-08-07 ~23:10Z — read the direction carefully, it changed.
Delete this file when it stops being true.**

If you are debugging the commonplace serve and its behaviour does not match
`main`, **read this before anything else**.

## The direction reversed at the merge

- **Before ~23:05Z:** the serve ran code `main` did not have (hot-loaded from an
  unmerged branch).
- **Now:** `sol/cx-mchn-scanner` merged as **`7dd1b5a`**, and BRIEF-4 + BRIEF-6
  changed `mixed_plane_history.ex` **after** the hot-load. So the serve holds a
  module that `main` has since **superseded**. The merge did not clear the
  divergence — **it inverted it.**

## What the running node holds

| module | serve-resident md5 | status |
|---|---|---|
| `Commonplace.Projection` | `5C8E00468EAC209D88B1952B77226B4B` | hot-loaded 19:40Z; semantically additive (`project_history/3` + helpers) |
| `…Projection.MixedPlaneHistory` | `4A96FEC1DF428D926C501E48A9324529` | ⚠️ **STALE — pre-dates the default flip** |
| `…Projection.MixedPlaneHistoryFixture` | `EB5B4AA0F6D4E8191CFC4D0681736240` | unchanged throughout |

⚠️ **THE CONCRETE HAZARD:** the serve-resident `MixedPlaneHistory` still defaults
to **`:incremental`** — the strategy measured **1.43× slower** on this corpus, whose
fix is exactly what `7dd1b5a` merged. `main` now defaults to `:oracle`
(`mixed_plane_history.ex:268`). **A sweep launched against the running node today
silently takes the slow path, with no signal in its output.**

**Stakes are low but not zero:** nothing on the serve calls `MixedPlaneHistory`
except a sweep someone chooses to launch, so the stale copy is **inert until then**.

## How to clear it

**Restart the serve.** Hot-loaded code does not survive a restart, so the node
reloads from `_build/dev`. ⚠️ **Verify `_build/dev` actually reflects `7dd1b5a`
first** — it will not until something compiles main, so a restart before a rebuild
reverts to whatever was last built there, which may be neither version.

**Nothing on disk in `~/commonplace` was ever changed by this** — the divergence
has only ever existed in the running BEAM.

## Why it was done

To run the CX-mchn mixed-plane sweep against the live store: the sweep runs
**inside** the serve via one erpc, so the module must exist there, and an unmerged
module cannot be erpc'd into a running node. See `project_mixed_plane_scanner` in
boss-clod memory for the full state.

## Live-state notes

- Live store **byte-identical** across a full sweep — the scan path does not write.
- `:global` names 0 before and after; no `/tmp/commonplace-mixed-plane-control-*` leaked.
- `/tmp/mixed-plane-live` = **25 oracle-scanned docs, KEEP** (the real resumable checkpoint).
  `/tmp/mixed-plane-ab` (32 docs) is a disposable A/B artifact.
- `/home/jes/sol-storecopy` is a consistent `CubDB.back_up` of the live store
  (542,723,092 bytes, 71,042 entries), taken **by the serve itself** — never a
  second opener. Safe to delete once profiling work is done.
- ⚠️ The commonplace test suite has **shared generated state** (`tmp/test_data`)
  that **overlapping runs can corrupt** — one was quarantined at
  `/tmp/commonplace_test_data_quarantine_20260807_2156`. Serialise suite runs.
