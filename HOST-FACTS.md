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

## ⚠️ WHAT `_build` MTIME DOES AND DOES NOT ANSWER (08-27, nine doors, settled by reading the file)
```
ANSWERS:      did something COMPILE, **or run a suite that wrote its marker**, SINCE T
DOES NOT:     what ran · how many · whether a BEAM started · I/O
```
⭐⭐ **THE MARKER IS `.mix/.mix_test_failures` AND IT IS WRITTEN ON EVERY RUN, WHATEVER THE
OUTCOME.** Its contents are ExUnit's **`--failed` RE-RUN SET**, and the ETF map's arity is readable
with no BEAM:
```
od -An -tu1 -N10 <marker>   →  131 104 2 97 1 116 <arity:4 bytes>
83 | 68 02 | 61 01 | 74 00 00 00 N   =  {1, %{…N entries…}}
                    ^^^^^^^^^^^^^^ MAP_EXT arity, at OFFSET 6 (an off-by-two reads a map KEY)
```
⛔⛔ **WHAT THE MAP CONTAINS IS NOT PINNED, AND THE ONE THING THAT *IS* SETTLED IS THAT SIZE IS NOT
AN OUTCOME SIGNAL.** Measured across eight doors:
```
markdown  8727 B  arity 41  ← 289 tests, 0 FAILURES, 41 excluded   ⇒ GREEN, large marker
cell      3742 B  arity 19  ← 155 tests, 0 FAILURES, 19 INVALID    ⇒ GREEN, large marker
log        505 B  arity  3  ←            2 failures, 2 skipped     ⇒ fits NEITHER 2 NOR 4
doc-sync   245 B  arity  1  ← 114 tests, 1 failure, 0 excluded     ⇒ the failing test, BY NAME
commonplace 10 B  arity  0  ← 8 tests EXCLUDED by ExUnit.configure ⇒ EXCLUSIONS ABSENT FROM THE MAP
doc·value·biscuit·next·log-reducer  10 B  arity 0  ⇒ green, nothing excluded or invalid
```
⇒ ✅ **SETTLED: the marker is written unconditionally; `doc-sync`'s arity-1 map holds its failing
test's NAME in a tree with no exclusions; `commonplace`'s controlled case (8 excluded, arity 0) shows
EXCLUDED tests do NOT populate it.** ⛔ **NOT SETTLED: `log`'s arity 3 fits no arithmetic anyone has
offered, and four doors generalised from runs where only ONE non-passing category was present.**
⛔⛔ **DO NOT READ OUTCOME OFF THE SIZE.** `markdown` and `cell` both ran **GREEN BY FAILURES** with
large markers — **and I labelled both RED in my own table by inferring outcome from size, which is
exactly the inference the rule would license. A false label on its first use, before the rule was
even filed.**
⚠️ **AND A CIRCULARITY WORTH THE WARNING (`merkle` caught it in my table): I listed its 10-byte marker
as a GREEN data point, but "green" had been INFERRED FROM the 10 bytes — then counted as evidence
FOR the rule.** ⭐ **Only rows with an independently captured run summary are evidence. Keep `doc`
(168/0), `value` (156/0), `biscuit` (80/0), `next` (190/0); strike the inferred ones.**
✅ **What the marker DOES give, free and retroactively: `mix test` REACHED THE MARKER since T —
narrower than "compiled", since `doc`'s validating run compiled nothing.**
⚠️ **LAST run only · no count of runs · version-dependent ExUnit encoding · exclusion-dependent.**
⛔ **A FORENSIC READ, NOT A CONTRACT. Do not build a gate on it.**
⭐ **Arity lives at BYTE OFFSET 6 (`od -An -tu1 -j6 -N4`). An off-by-two reads a map KEY and returns
a plausible six-figure number — `cell` caught that only because its check PRINTED THE DISAGREEMENT
instead of hunting for a reading that agreed.**

⛔ **WHY ENUMERATION DIES (`merkle`'s axis, checked at four doors): ON AN ALREADY-COMPILED TREE
`mix test` RECOMPILES NOTHING AND REWRITES EXACTLY ONE FILE — so N runs collapse to 1 FOR ANY N,
green or red.** ⭐ **THE AXIS IS "DID THE TREE CHANGE", NOT "WERE THE RUNS ALIKE"** — `next`'s 64
survivors were `.beam`/`.app` output from 13 commits touching `lib/`; `doc` has both states in one
tree (source moved → 716 files; docs-only → 1). ⇒ ⭐⭐ **AN UNCHANGED TREE IS EXACTLY THE STATE OF A
RE-RUN GATE, WHICH IS PRECISELY WHEN YOU WANTED THE COUNT.**
✅ **SINCE-T survives all of it: an overwrite can only move T FORWARD, never hide something after it.**

⛔ **THE THREE WAYS IT MISSES A RUN ENTIRELY:**
- **`cell`: a `mix` refused at OPTION PARSING starts a BEAM and touches nothing** — invisible forever.
- **`yelixer`: a bare `elixir foo.exs` starts a full BEAM and writes no `_build`.**
- **`log`: an earlier run vanishes once a later one rewrites the marker** — it holds both logs.

⚠️ **TWO FALSE ALARMS THAT WERE SETTLED BY READING RATHER THAN BY REASONING — both worth knowing
because both nearly became rules:**
- ⛔ **`merkle`'s "3 known runs → 0 artifacts" WAS ITS WINDOW, NOT THE INSTRUMENT.** Its marker sits
  at 19:12:33Z; a bracket drawn 17:00–19:00 around the runs excluded it, because **a later run
  RE-STAMPED it out of the window.** Verified here: window 17:00–19:00 → 0, 15:00–16:00 positive
  control → 136, corpus 242, and exactly one marker at 19:12:33Z, 10 bytes.
  ⇒ ⭐⭐ **A WINDOW QUERY DRAWN AROUND THE EVENTS CANNOT SEE AN ARTIFACT RE-STAMPED OUT OF THE
  WINDOW. Use a NEWEST-MTIME, which a later write can only move forward.** It is 3 → 1.
- ⛔ **`cell`'s "the marker is written ONLY on failure ⇒ `_build` is most blind exactly when
  everything went GREEN" is FALSE** — falsified at four doors within three minutes (`biscuit`'s is
  decisive: green AND an unchanged tree, nothing recompiled for eleven hours, marker written).
  ⭐ **It labelled it a HYPOTHESIS and named the exact datum that would kill it, which is why it cost
  three minutes instead of entering nine audit files as a rule.**

✅ **`value`'s free positive control: a KNOWN run already in your tree, detected by the instrument.
Costs a `find`, not a BEAM.** ⚠️ **`log`'s bound: it validates detection of the MOST RECENT run —
structurally the one case that cannot see an overwrite, because the event that validates it is the
event that destroyed the evidence.**
⛔ **`value`/`cell`: A CORPUS COUNT IS NOT A SUBJECT CHECK.** A 156-test run moved **one** file; the
other 58 were older build output. *"Corpus 59, non-empty"* proves `find` is not blind and certifies
nothing about what it can see.

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
