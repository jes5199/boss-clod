# Serve deploy ceremony

The checklist for restarting the commonplace serve onto a new sha. Written down because
**a filed artifact fires where a remembered rule does not** (LESSONS 7av) — every step below
exists because skipping it cost something.

Launcher: `serve-launch5.sh` · environ capture: `capture-environ.sh`

---

## 0. Identify the serve BY THE PORT IT OWNS
```bash
SP=$(ss -ltnp | grep -E '[:.]5199 ' | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2)
```
⛔ **NEVER `pgrep -f commonplace_dev`.** On 2026-08-12 that returned a *Claude Code* process, whose
environ legitimately holds `LETTA_API_KEY` and `SQUAD_ALERTS_PUBLISHER_TOKEN` — one message from a
false "the serve is leaking both secrets" alarm (LESSONS 7b0). A pattern match answers *what is NAMED
like a serve*; the port answers *what IS the serve*.

## 1. Pre-flight
- `git fetch`, confirm HEAD == origin/main, note the target sha.
- ⛔ **DIRTY-SOURCE CHECK** — unmerged code must not ride along:
  ```bash
  git status --porcelain | grep -cE '^( M|M |MM|\?\?) .*(apps/.*/(lib|test)/.*\.(ex|exs)|mix\.exs|mix\.lock)$'
  ```
  Must be 0. **Prove the pattern works** by piping a fake ` M apps/commonplace/lib/x.ex` line through it.
  (Runtime churn in `.beads/`, `.commonplace-state/`, `STATE.md` is expected and fine.)
- Capture pre-deploy environ: `capture-environ.sh $SP $SC/env-pre.txt` (values hashed at capture).
- ⭐ **CHECK WHAT IS ACTUALLY PENDING** with `git merge-base --is-ancestor <sha> <deployed>`, plus a
  control that must return NO. Twice now a peer's bundle list has included rounds already live.

## 2. Stop — by numeric pid, never a pattern
`C-c` on a BEAM opens the **BREAK menu**; it does not terminate. Sequence: `C-c` → `a` → `Enter`,
then `kill -TERM <numeric pid>` if still alive.
⛔ `pkill -f 'beam.smp'|'mix'|'elixir'` ALL MATCH HERMES, which trades live money.
Confirm `:5199` has 0 listeners and hermes `ActiveState=active` before continuing.

## 3. Launch + verify (all of these, none optional)
- `serve-launch5.sh` — 4 pre-flight refusals, each demonstrated able to fire: empty API key (1),
  missing inetrc (2), inetrc not pinning loopback (2), port already listening (3).
- **Whole-boot capture** via `tee`.
- **Posture block, whole** — never grep a field out of it.
- **Environ diff pre→post** — must be identical; both sides hashed at capture.
- **Leak check on the real serve**: `LETTA_API_KEY`, `SQUAD_ALERTS_PUBLISHER_TOKEN`, `AI_AGENT` = 0,
  with `PHX_SERVER`=1 as the positive control.
  ⭐ **READ THE CONTROL FIRST.** A missing mandatory var proves a wrong referent *before* a present
  forbidden one suggests a leak.
- **Watchdog** (60s, automatic): parses the **local-address column only** (`awk '{print $4}'`).
  ⛔ A line-wide `0.0.0.0` grep matches the PEER column of every LISTEN row — that bug killed a
  healthy serve (LESSONS 7aw). Expect `✅ … no wildcard sockets besides :5199`.
- **Deployed code, from the compiled artifact not the repo**: `module_info(:md5)` on the live node vs
  `:beam_lib.md5` on disk. ⛔ `is_loaded` gives a PATH, not a VERSION. ⛔ `strings` cannot see a
  beam's compressed literal table — it reads 0 for entries that are certainly present (LESSONS 7ay).

## 4. Standing per-bundle checks
- ⭐ **`Runner.Provisioner` has ZERO production callers** — re-verify each ceremony while that holds.
  It mutates node-global Application env during birth; harmless while unreachable, and **lazy-load
  makes it reachable the moment anything names it.**
  ```bash
  git ls-tree -r --name-only origin/main -- 'apps/**/lib/**' | wc -l   # must be ~434, NOT 0
  git grep -l 'PodProfile\.'   origin/main -- 'apps/**/lib/**'        # control: must find >=1
  git grep -l 'Provisioner\.'  origin/main -- 'apps/**/lib/**'        # the check: must find 0
  ```
  ⛔ **The pathspec `apps/*/lib` MATCHES ZERO FILES** — git's `*` does not cross `/`. On 2026-08-12
  that made both the check AND its control return 0, so a safety check read as PASSED while reading
  nothing. **Count the files the pathspec matches before trusting what it found in them.**
- ⭐ **`Runner.Provisioner` also puts pod stores in the GLOBAL name registry during birth**
  (`{:global, {Module, :role, make_ref()}}` — unique per call, supervisor stopped in an `after`, so no
  singleton hazard today). Together with the node-global env mutation, that is **two independent
  reasons the worker-launch round's seam replacement is load-bearing** — both harmless while
  unreachable, both reachable the moment that round names them.
- **CX-2h03** (GitBridge.InboundTest pin 9, teardown `:noproc`) is load-sensitive. If a gate hits it,
  the isolated-rerun license is already established — **do not let it stall the deploy.**

## 5. Suite verdicts (when a gate gates the deploy)
- ⭐ **A COUNT, NEVER THE WORD "GREEN."** An aborted ExUnit run prints `Finished … 0 failures` over a
  PARTIAL population; the denominator is the only tell.
- Reconcile the denominator against baseline + new tests, exactly.
- ⛔ **A transient systemd unit reports `Result=success` / `LoadState=not-found` identically whether it
  succeeded hours ago, never existed, or died in 2 seconds.** The verdict fields are exhausted —
  **judge by the artifact's size and duration** (a real full core ≈ 570KB over ~12 min, not a 1-line
  log at +2s). Gate units need `systemd-run -E PATH="$PATH"` or `mix` is not found.
- ⭐ Sandbox runs and systemd-unit runs are **NOT interchangeable oracles** — same tree, same
  reconciling population, different verdicts, neither dishonest (LESSONS 7ay).


---

## Appendix — what a check actually proves

⭐ **ASSERTING SHAPE IS NOT ASSERTING VALIDITY, and shape is what is easy to assert.**
commonplace's S33 patch is the case that names it: two tests asserted a certificate's audience,
verbs, scope and caveats — every field correct — on an artifact that need not have been a
certificate at all. **Shape equality cannot distinguish a real certificate from a well-formed
record.** The fix was to make the artifact prove itself: `verify_id/1` (the id matches its own
bytes) and `verify_sig/1` (the signature verifies against the issuer key).
⇒ Most checks in this file are shape checks — a token present at one sha and absent at another, a
mask named in a list, a refusal naming its field. **A forgery would satisfy all of them.** Where an
artifact can prove itself cryptographically or by reconstruction, prefer that over equality.

⭐ **AND A CONTROL SHOULD PROVE THE NEEDLE IS FINDABLE, not merely that the haystack is non-empty.**
Checking "0 `get_env` added against 437 added lines" proves the diff isn't empty. Checking that
**the touched files already contain 4 such calls** proves the grep can find that pattern *in this
exact haystack* and still found none added. The second is strictly stronger and costs the same.
