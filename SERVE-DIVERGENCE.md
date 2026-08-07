# ⚠️ THE LIVE SERVE IS RUNNING CODE THAT IS NOT ON MAIN

**Opened 2026-08-07 ~19:45Z by boss-clod. Delete this file when it stops being true.**

If you are debugging the commonplace serve and its behaviour does not match
`main`, **read this before anything else** — you are probably looking at the
reason.

## What diverges

Three modules were **hot-loaded** into the live serve (pid `887503` at the time
of writing) from the **unmerged** branch `sol/cx-mchn-scanner` @`7a46773` +
unstaged work, in the worktree `/home/jes/sol-scanner/wt`:

| module | on-node md5 after load | note |
|---|---|---|
| `Commonplace.Projection` | `5C8E00468EAC209D88B1952B77226B4B` | ⚠️ **a live core module, REPLACED** (was `48774E51C0427CD354DAC3B7EC5604C7`) |
| `Commonplace.Projection.MixedPlaneHistory` | `4A96FEC1DF428D926C501E48A9324529` | new scanner |
| `Commonplace.Projection.MixedPlaneHistoryFixture` | `EB5B4AA0F6D4E8191CFC4D0681736240` | unchanged by the last load — was already resident |

The `Projection` change was verified **semantically additive** line by line
before loading: a new `project_history/3` plus private helpers, and the diff's
only three removed lines are an extended `alias`, one re-wrapped `raise`, and
one space of indentation. **Zero `- def` / `- defp` lines** — no existing
function was removed or altered. `project_at/3`, `project_doc_at/3`,
`fetch_commit`, `verify_chain_integrity` are behaviourally untouched. Two
independent line-by-line readings (boss + commonplace) agreed.

## How to clear it

**Restart the serve.** Hot-loaded code does not survive a restart, so a restart
reverts all three to whatever `main` has. **Nothing on disk in `~/commonplace`
was changed** — this divergence exists only in the running BEAM.

The alternative is that `sol/cx-mchn-scanner` merges, at which point the serve
is merely *ahead of its restart*, not diverged from main.

## Why it was done

To run the CX-mchn mixed-plane sweep against the live store. The sweep's design
runs **inside** the serve via one erpc, so the module has to exist there; an
unmerged module cannot be erpc'd into a running node. See
`project_mixed_plane_scanner` in boss-clod memory for the full state.

## Live-state notes taken at the time

- Serve stable for 2h+ under real traffic after the load.
- Live store **byte-identical** across the first full sweep (the scan path does
  not write): `23.cub` unchanged in size, mtime, and `commits/` listing md5.
- `:global` names 0 before and after; no `/tmp/commonplace-mixed-plane-control-*`
  leaked.
- `/tmp/mixed-plane-live` holds **25 oracle-scanned docs** — the real resumable
  checkpoint, **KEEP**. `/tmp/mixed-plane-ab` (32 docs) is a disposable A/B artifact.
- `/home/jes/sol-storecopy` is a consistent `CubDB.back_up` of the live store
  (542,723,092 bytes, 71,042 entries), taken **by the serve itself** — never a
  second opener. Safe to delete once the profiling work is done.
