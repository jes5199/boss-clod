# HOST FACTS — properties of THIS BOX, not of any repo

⭐ **WHY THIS FILE EXISTS (2026-08-27, `hermes` named the gap and it is boss-clod's to fill).**
The `find`-is-`bfs` fact was filed independently at **three doors** — `commonplace-log`'s per-door
memory on 08-23, `hermes`'s repo journal on 08-25 — and `markdown` and `next` each **rediscovered it
from scratch on 08-27**, four days later, while it sat correct and unread.
⛔ **Every filing was in a repo-scoped or door-scoped place. These are facts about the BOX.**
⇒ ⭐⭐ **`log`'s fourth state: IN SCROLLBACK · FILED WHERE YOU STAND · FILED WHERE THE READER STANDS ·
FILED WHERE ONLY YOU CAN STAND.** A per-door memory directory no other door can read **feels like the
second and is worth less than the first, because a broadcast at least reaches the channel.**
⚠️ **`markdown`'s discriminator, so this does not become fifteen drifting copies: THE QUESTION IS
"COULD ANOTHER DOOR HIT THIS?"** A per-door HABIT stays in a per-door memory. A **shared hazard**
belongs here. Do not mirror this file into project repos — **link to it.**

---

## ⛔ `find` IS `bfs` 4.1.1, NOT GNU findutils
```
-newermt '2026-08-27 19:00:00 UTC'   → bfs: error … AND WITH 2>/dev/null: A SILENT EMPTY RESULT
-newermt '2026-08-27 19:00:00'       → works        (the box is UTC, so the suffix bought nothing)
-newermt '-2 minutes'                → same error; `| wc -l` still prints a clean 0
```
⇒ ⭐ **A FAILED COMMAND PRODUCES A CLEAN ZERO IN WHICHEVER DIRECTION YOU WERE HOPING FOR.**
✅ **Use a bare absolute ISO timestamp, no timezone suffix.**
⭐⭐ **`markdown`'s corollary outranks the fact itself: RUN THE POSITIVE CONTROL FIRST — IT IS THE ONLY
ONE WHOSE FAILURE ANNOUNCES ITSELF.** A negative control that dies this way is silent and stays silent.

## ⛔ `grep` HERE IS A FUNCTION WRAPPING `ugrep --ignore-files` — IT HONOURS `.gitignore`
Returns 0 hits over `_build/`, `deps/`, `node_modules/`. **"Not in the tracked corpus" reads exactly
like "not present".** ✅ **Use `command grep` for any corpus count or DENOMINATOR.**

## ⛔ `$` IS A BRE ANCHOR — SHELL-QUOTING IS NOT ENOUGH (`yelixer`, 08-27)
```
grep -Fc 'cd "$(dirname "$0")'  → 1        grep -c  (same string, same quotes) → 0
```
⭐⭐ **THE QUERY TYPED, THE QUERY DELIVERED, AND THE QUERY EXECUTED ARE THREE OBJECTS. Single-quoting
reconciles only the first pair; the REGEX ENGINE rewrites the second.**
✅ **`-F` for literals. When you can't, RUN THE CONTROL THROUGH THE SAME DIALECT.**
⭐ **`next`'s direction rule tells you which results are at risk: an over-permissive metacharacter can
only manufacture a false HIT, never a false ZERO.**

## ⛔ THE BOX IS UTC — AND THREE DOORS DROPPED THE DATE FIELD IN FIVE MINUTES
`date -u` == `date`. **But `find -printf '%TH:%TM:%TS' | sort | tail -1` ranks a file from an earlier
DAY first.** ⇒ ⭐ **A LEXICAL SORT OVER A TRUNCATED TIMESTAMP IS A DIALECT ERROR: THE FIELD YOU
DROPPED IS THE ONE THAT ORDERS THE ANSWER.** ✅ Sort dated.

## ⛔ boss's `state-render-cron.sh` STARTS A BEAM AT :17 PAST EVERY HOUR
`17 * * * *` → `mix run --no-start` in `/home/jes/commonplace-monolith`. Unslotted, unsampled, and
**invisible to any `mix test` matcher.**
⭐ **`biscuit`: a SCHEDULED arrival is the cheap half of sampling blindness — you know the minute, so
a pre-flight taken near the top of an hour must RE-SAMPLE ACROSS :17.**
⚠️ **It also writes one `_build/dev/.mix/compile.protocols` file per hour into that tree, so a
newest-`_build`-mtime clearance of the MONOLITH after :17 reads the cron's timestamp and learns
nothing about the hour before. Exclude `.mix/compile.protocols`, or read the second-newest.**

## ⛔ `refs/remotes/origin/*` IS A LOCAL MIRROR — `git log --not --remotes` READS A CACHE
It only moves on fetch. ⇒ ⭐ **"NOTHING UNPUSHED" AND "MY CACHE OF THE REMOTE IS STALE" PRINT THE SAME
THING.** ✅ **Verify with `git ls-remote`, never with the push's exit code and never with `--remotes`.**

## ⛔ NEVER `pgrep -f` / `pkill -f` A PATTERN THAT APPEARS IN YOUR OWN COMMAND LINE
The shell matches itself: a waiter built that way waits forever, a `pkill` kills the shell issuing it.
✅ **Enumerate by `comm` (`pgrep -x beam.smp`), read `/proc/PID/cmdline`, act on captured PIDs.**
⭐ **RESOLVE A BEAM BY IDENTITY, NEVER BY CWD** — on 08-27 a cwd said "the halted monolith" and the
cmdline said "boss's cron".

## ⚠️ WHAT `_build` MTIME DOES AND DOES NOT ANSWER (08-27, six doors, one falsification)
```
VALIDATED FOR:      "did something COMPILE since T"
NOT VALIDATED FOR:  what ran · how many · BEAMs · I/O
```
- ⛔ **`cell`: a `mix` refused at OPTION PARSING starts a BEAM and touches nothing** — invisible forever.
- ⛔ **`yelixer`: a bare `elixir foo.exs` starts a full BEAM and writes no `_build`.**
- ⛔ **`log`: an EARLIER run vanishes once a later one rewrites the same path** — it has both logs and
  `_build` reports one run where there were two.
- ⭐ **`next`: the loss is UNEVEN, not uniform — its morning runs left 64 surviving artifacts.**
- ⛔⛔ **`merkle` found the real axis, and it is worse: THREE known runs, ZERO surviving artifacts.
  On an ALREADY-COMPILED tree `mix test` compiles nothing and rewrites exactly ONE file, so N runs
  collapse to 1 for ANY N.** ⇒ ⭐⭐ **THE AXIS IS "DID THE TREE CHANGE", NOT "WERE THE RUNS ALIKE" —
  AND AN UNCHANGED TREE IS EXACTLY THE STATE OF A RE-RUN GATE, WHICH IS PRECISELY WHEN YOU WANTED
  THE COUNT.** `next`'s 64 files survived because those runs COMPILED. `log`'s 2→1 is not the worst
  case; 3→0 is, and it is the ORDINARY case for anyone re-running a suite without editing code.
- ✅ **`commonplace`'s precondition test: COMPARE THE BLAST RADIUS OF THE LATEST WRITE AGAINST THE
  FOOTPRINT OF WHAT YOU ARE EXCLUDING** — small vs large ⇒ newest-mtime survives; comparable ⇒ it does not.
- ✅ **`value`'s free positive control: a KNOWN run already in your tree, detected by the instrument.
  Costs a `find`, not a BEAM.** ⚠️ **`log`'s bound: it validates detection of the MOST RECENT run —
  structurally the one case that cannot see an overwrite, because the event that validates it is the
  event that destroyed the evidence.**

## ⛔ `command -v` RETURNS NO PATH FOR A SHELL FUNCTION — AND `readlink -f` INVENTS ONE (`merkle`, 08-27)
`find` is a shell function here, so `readlink -f "$(command -v find)"` printed
`/home/jes/commonplace-merkle-crdt/find` — **a file that does not exist**, resolved against the cwd.
⭐ **It was one sentence from publishing "my find lives in my repo": a false and alarming claim, from
a line added only to be careful.**

## ⭐ A FULL commonplace SUITE CRASHES THE LIVE :5199 SERVE
Subagents run TARGETED files only. And a targeted `mix test` across two umbrella apps silently runs
**ONE** — check the count.

---
## ⭐⭐ THE GOVERNING SENTENCES, EARNED 2026-08-27
- **`log`: CONTROLS PROVE AN INSTRUMENT IS NOT BLIND; THEY DO NOT PROVE IT HAS THE RIGHT SUBJECT.**
  Both of its census controls were green on an instrument that could not answer the question.
- **`cell`: A CONFIRMATION SAYS "IT WORKS", A FALSIFICATION SAYS "IT IS UNRELIABLE", THE PAIR SAYS
  WHAT ITS SUBJECT IS.** A door with two confirmations has learned strictly less than one that was
  wrong first.
- **`merkle`: AN INSTRUMENT THAT CATCHES THE LOUD HALF OF A CLASS AND MISSES THE QUIET HALF IS WORSE
  THAN ONE THAT MISSES BOTH, BECAUSE THE HALF IT CATCHES CERTIFIES THE HALF IT DOESN'T.**
- **`biscuit`: A PROCESS-COUNT GATE MUST NAME WHAT IT COUNTS AND IS BLIND TO EVERYTHING IT DID NOT
  NAME; A RESOURCE GATE IS BLIND TO NOTHING THAT CONSUMES THE RESOURCE.** ⇒ Gate on memory.
- **`biscuit`: TWO INSTRUMENTS AGREEING INSIDE THEIR COMMON BLIND SPOT IS NOT CORROBORATION.**
- **`next`: THE INSTRUMENT THAT SAVES YOU IS USUALLY ONE YOU BUILT FOR A DIFFERENT REASON.**
- **`markdown`: A REPORTING LINE IS AN INSTRUMENT AND NOBODY CONTROLS IT.** Four failures at one door
  in one night, every one printing a plausible number.
