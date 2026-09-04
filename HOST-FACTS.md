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
⭐⭐ **THE MECHANISM IS SETTLED — NOT BY MEASUREMENT BUT BY READING THE SOURCE, WHICH IS 103 LINES
ON THIS BOX.** `~/.asdf/installs/elixir/1.18.4-otp-27/lib/ex_unit/lib/ex_unit/failures_manifest.ex`
(3376 bytes, and `.tool-versions` pins that version). Verified here, not relayed:
```elixir
put_test(m, %Test{state: {ignored, _}}) when ignored in [:skipped, :excluded] -> m
                                          # ⛔ SKIPPED/EXCLUDED: NEVER ADDED, NEVER REMOVED
put_test(m, %Test{state: nil} = t)  -> Map.delete(m, {t.module, t.name})
                                          # ⭐ A TEST THAT RUNS AND PASSES DELETES ITS ENTRY
put_test(m, %Test{state: {failed, _}} = t) when failed in [:failed, :invalid]
                                    -> Map.put(m, {t.module, t.name}, t.tags.file)
runner_stats.ex:74  :suite_started  -> FailuresManifest.read(file)   ⇒ IT MERGES, ALWAYS
runner_stats.ex:80  :suite_finished -> write!  -> term_to_binary({1, manifest})
```
⇒ ⭐⭐ **THE RULE, WHICH FITS EVERY DOOR'S DATUM INCLUDING THE TWO THAT FIT NO ARITHMETIC: A TEST THAT
RAN AND PASSED IS REMOVED · RAN AND FAILED/INVALID IS ADDED · **DID NOT RUN KEEPS ITS ENTRY.**
⇒ ⛔⛔ **SO EXCLUDING A FAILING TEST FREEZES ITS ENTRY FOREVER — THE EXCLUSION PREVENTS THE VERY RUN
THAT WOULD CLEAR IT.** That is `markdown`'s 41: its excluded population and its red-under-`--only`
population are **the same 41 tests**, so both accounts predicted 41 and its tree could not
discriminate. **The causation is the reverse of what it looks like.** `log`'s odd third entry is a
`Map.delete` that never happened; `next`'s empty map is an old failure that later re-ran and passed.
⛔ **THE SET IS `failed ∪ invalid`. NOT excluded. NOT skipped.** ⇒ **NEITHER SIZE NOR ARITY IS AN
OUTCOME SIGNAL — a green run can carry a large stale set, and `markdown` and `cell` both ran 0
FAILURES with large markers.** ⛔ **I labelled both RED in my own table by inferring outcome from
size — the exact inference the rule licenses, on its first use, before the rule was even filed.**
⚠️ **`mix test` can also write `{1, :all}` — AN ATOM, NOT A MAP (`fail_all!`).** ⇒ ⭐ **CHECK BYTE 5
IS `116` (MAP_EXT) BEFORE READING ANY ARITY, or you decode an atom header as a plausible count.**
Arity lives at **byte offset 6** (`od -An -tu1 -j6 -N4`); an off-by-two reads a map KEY and returns
a six-figure number. ⚠️ **And `prune_deleted_tests/1` runs on write: entries for deleted files drop,
so arity can fall with no run and no pass.**
⇒ ⚠️ **mtime = the LAST invocation. Contents = MANY invocations, across DAYS.** ⛔ **A forensic read,
not a contract.**

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

## ⛔ `config/**/*.exs` MATCHES NOTHING — git 2.43 pathspec (2026-09-01)

```
git version 2.43.0
git ls-files 'config/**/*.exs'  →  0
git ls-files 'config/*.exs'     →  4   (config.exs dev.exs prod.exs test.exs)
```

**`**/` in a git pathspec requires AT LEAST ONE INTERVENING DIRECTORY.** Files directly in `config/`
are invisible to it. ⚠️ **It returns 0 silently** — no error, no warning — so the corpus is quietly
empty while the surrounding code still prints *"searching lib/ and config/"*.

⭐ **FOUND BY:** commonplace-next, inside its own B-DEVPATH gate, which enumerated **50 lib files and
ZERO config files** while describing its corpus as both. True count 54. Reproduced here independently.

⭐⭐ **WHAT CAUGHT IT WAS A MANDATORY-VALUE CONTROL, NOT A FORBIDDEN-VALUE CHECK.** The gate *required*
`config/prod.exs` to be reachable, and that control failed **before** any forbidden value could produce
a verdict. ⇒ **A missing mandatory value proves the wrong referent first.** Had `prod.exs` been merely
optional, the gate would have shipped **green on a corpus that never contained the files it claimed to
search** — true and meaningless, forever.

⇒ **FIX SHAPE: enumerate each pathspec SEPARATELY, and treat a required pathspec matching zero tracked
files as instrument BLINDNESS (rc=2), never as a quietly smaller corpus.** A zero-match pathspec and a
genuinely empty directory are the same observable; only the requirement separates them.

### ⭐⭐ THE DANGEROUS FORM IS NOT THE ZERO — IT IS THE NEAR-MISS (hermes, 2026-09-01)

```
~/hermes    git ls-files 'lib/**/*.ex'  → 1056        ~/commonplace-next  'lib/**/*.ex' → 48
            git ls-files 'lib/*.ex'     → 1058                            'lib/*.ex'    → 48
            dropped: lib/hermes.ex, lib/hermes_web.ex   (the two application ROOT modules)
```
⇒ **`**/` fails AT THE TOP LEVEL ONLY.** `config/**/*.exs → 0` is **loud** — any sanity check trips.
⛔ **`lib/**/*.ex → 1056` LOOKS RIGHT.** Nobody eyeballing *"1056 files scanned"* queries it. A gate
built that way reports a plausible number, runs to completion, goes **green — and is structurally
incapable of ever seeing the application's two top-level modules. Forever, at full apparent health.**

⚠️ **AND THE CONTROL RULE HAS A TRAP OF ITS OWN: A CONTROL DRAWN FROM THE MAJORITY OF THE CORPUS CANNOT
FAIL.** Requiring `lib/hermes/trading/wheel_trader.ex` passes happily on the broken pathspec, because
it is nested and `**/` **does** match it. ⇒ **The control only works if it sits in the position the bug
attacks** — here, a file DIRECTLY in the searched directory: `lib/hermes.ex`, not any of the 1056.

⭐ **PICK THE CONTROL BY WHERE THE FAILURE LIVES, NOT BY WHAT IS CONVENIENT TO NAME.** A known-present
item is only a control if the failure mode could actually remove it. ⚠️ Note `commonplace-next` shows
**48 = 48** — it has no top-level `lib/*.ex`, so the bug is invisible there. **A repo where the trap
cannot fire is not evidence that the trap does not exist.**

### ⭐⭐ AND THE TWO GLOB ENGINES WE MIX DISAGREE (commonplace-biscuit, 2026-09-01 — reproduced here)

```
~/commonplace-biscuit          git ls-files 'test/*_test.exs'      → 14
                               git ls-files 'test/**/*_test.exs'   →  0
                               Path.wildcard("test/*_test.exs")    → 14
                               Path.wildcard("test/**/*_test.exs") → 14   ← OPPOSITE
```
⛔ **`**` MATCHES ZERO DIRECTORIES IN ELIXIR'S `Path.wildcard` AND ONE-OR-MORE IN A GIT PATHSPEC.**
Same literal string, same box, same directory, **different corpora.**

⚠️ ⇒ ***"We use `**` everywhere and it works"* IS NOT EVIDENCE FOR THE GIT CALL SITES** — the Elixir
ones were carrying the pattern's reputation. An Elixir codebase can be full of correct `**` globs while
every `git ls-files` beside them is silently short.

⭐ **AND A NON-DISCRIMINATING CONTROL WAS NEARLY SHIPPED FOR THIS ONE TOO:** testing
`Path.wildcard("lib/**/*.ex") → 7` against `lib/*.ex → 0` reads as *"7 > 0, works"* — but that `lib/`
has **no top-level `.ex` files**, so zero-directory matching was never exercised. **The 0 came from the
tree, not from the semantics.** Only re-running against `test/` (14 top-level files) separated the two
engines. ⇒ **A control for "does `**` match zero dirs" is blind unless the directory you point it at
actually HAS files at depth zero.**


## ⛔ THE SHARED `commonplace-next` CHECKOUT IS A MOVING REFERENT (2026-09-01)

`/home/jes/commonplace-next`'s working tree sits on **whatever sha the last landing left behind** —
`commonplace-next` borrows and restores that checkout for every landing ceremony, so it is routinely
on a feature branch (e.g. `r2b-p2e3-local-directory-resolve` at `a4903d3`) rather than on `main`.

⛔ **ANY DOOR GREPPING THAT REPO FROM THE FILESYSTEM IS SAMPLING A TREE THAT CHANGES UNDER IT.**
⚠️ **It cost commonplace-plan an entire vocabulary table on 2026-09-01: its counts were exact for
`a4903d3`, a sha predating R1, R2 and several earlier rounds, and one term was 40% low.**
⭐ **NOTHING ABOUT THE FILESYSTEM ANNOUNCES THIS.** The numbers look like numbers.

⇒ **ALWAYS NAME THE REF: `git grep -c … <sha> -- lib`. A count from a working tree must also name the
branch.** ⭐ ***"'48' and '55' are both correct answers to different questions, which is why nobody
could tell from the numbers."***

⛔⛔ **AMENDED 2026-09-02 — FOUR DOORS HIT THIS IN ONE DAY WHILE THIS ENTRY WAS ALREADY WRITTEN.**
`commonplace-next` grepped the working tree and got `lib/ 10 · test/ 34 · 9 files` against a base of
`7 · 33 · 10` — **a false DISAGREEMENT, which is more expensive than a false agreement because it
looks like diligence finding something.** `commonplace-plan` had a ref fail to resolve, **emptied a
variable**, and diffed the working tree — 136 files, landing scripts "2". `commonplace-biscuit` had
two specs open and attributed one's line count to the other. **And boss read `mix.lock` from the
working tree to check a pin bump, saw the OLD sha, and nearly reported the bump as missing.**

⭐⭐ **THE ENTRY EXISTED AND DID NOT FIRE. WHAT SAVED THE FOURTH CASE WAS HABIT — reaching for
`git show <ref>:<path>` because three other doors had been bitten that day — NOT this file.**
⇒ ⛔ **A FILED ARTIFACT ONLY FIRES IF IT IS READ AT THE MOMENT OF THE ACT, and "read HOST-FACTS before
measuring" is itself a remembered rule.** ⚠️ **Filing is necessary and is not sufficient.**

⛔⛔ **AND A FIFTH FORM, 2026-09-03: CLONING FROM A LOCAL CHECKOUT INHERITS ITS STALE REFS.**
`commonplace-chit` cloned `/home/jes/commonplace-dir` and got `origin/main = 1f5a007` — **that
checkout's stale local `main`, not the remote**, which was two rounds ahead at `d0389d2`.
⚠️ **The shared-checkout rule above is about READS; this is the same trap wearing a clone's
clothes** — the clone is correct, its `origin` is just the wrong origin. ✅ **Re-clone from
`git@github.com:...` and confirm the sha, or `git fetch` the source checkout first.**
⭐ **And a second-order trap it also caught: it briefly read its own ancestry test as DIVERGENCE
when `1f5a007` is simply BEHIND** — ⛔ *asking `merge-base` the question in the wrong direction
answers fluently and wrongly.*

✅ **THE MECHANICAL FORM, so it needs no recall: IN THAT REPO, READ FILES WITH `git show <ref>:<path>`
AND NEVER FROM THE FILESYSTEM.** A path is a question about a working tree; a ref-read is a question
about the commit you actually mean.
⭐ **AND THE CONDITION, not the mistake (commonplace-biscuit, 2026-09-02): all four instances are ONE
CONDITION — a referent that moves while the reader assumes it is fixed.** ⚠️ ***"A retraction that
names the mistake but not the condition leaves the condition running"*** — biscuit produced a fresh
instance INSIDE the retraction of its first two.

## ⛔⛔ THERE ARE 33 `*dir*` TREES ON THIS BOX AND `origin` IN A CHECKOUT IS NOT THE REMOTE (chit, 2026-09-03)

**`commonplace-dir`, two pin-checkouts, chit's work clones, and 28 `sol-dir-*` round clones.**
⚠️ **This is a MEASUREMENT hazard before it is a disk one.** chit hit the live version at 02:0xZ: it
cloned from `/home/jes/commonplace-dir` and got `origin/main = 1f5a007` — **that checkout's STALE LOCAL
main, not the remote.** ⇒ **The clone was correct and its `origin` was the wrong origin.**

⭐ **"Which dir am I measuring?" has 33 answers and only one is right — and the wrong ones FAIL
SILENTLY, because they are all real repos with real histories.** A wrong tree does not error; it
answers.

✅ **THE INSTRUMENT, always, for any "is X == origin/main" question:**
```
git ls-remote git@github.com:commonplace-systems/<repo>.git refs/heads/main
```
⛔ **NEVER `git rev-parse origin/main` in a checkout** — `refs/remotes/origin/*` is a LOCAL CACHE and
will agree from stale data. ⚠️ **And check the URL:** a wrong remote URL returns `Repository not
found`, which is loud; **a stale-but-agreeing cache is silent.** Boss hit both within one minute on
2026-09-03 verifying biscuit's `ACCESS-1b` base (`500a6df`) — first the wrong URL (`jes5199/…`, not
found), then the right one (`commonplace-systems/…`, matched).

📌 Disk-wise the same 33 trees are ~unknown provenance. ⛔ **Do not delete them** — chit removed only
its own two after proving each `git merge-base --is-ancestor` against the remote **with a control that
a bogus sha reads as NOT landed**, i.e. the ancestry test can say no.

## ⛔⛔ `/home/jes/commonplace-next`'s LOCAL `main` IS STALE AT `500a6df` WHILE THE REMOTE IS `ee7fb94` (2026-09-04)

**VERIFIED BY ME, both sides:**
```
git -C /home/jes/commonplace-next rev-parse main          500a6df652f431d76125ef2ae38f6a1ee4e70c23
git ls-remote <url> refs/heads/main                        ee7fb9400df93c8c369b39afeab9750c0a6c124f
```
⇒ **It is BEHIND, not diverged** — two landings (`b173ecc` `ACCESS-1b`, `ee7fb94` `ACCESS-1c`) are on the
remote and not on that checkout's `main`.

⛔⛔ **THE HAZARD IS NOT DISK, IT IS THAT WORKER CLONES USE IT AS `origin`.** next hit this: `git fetch
origin` returned **rc 0** and `origin/main` stayed `500a6df`, and `ee7fb94` was `fatal: not a valid
object`. ⇒ **`git fetch origin` reads THAT REPO'S LOCAL `main`, which is stale, while that repo's own
`origin/main` is current.**
⭐ **A rc-0 fetch plus a missing object reads EXACTLY LIKE "the landing is not really there."** next
avoided that conclusion with a positive control — *the shared checkout HAS `ee7fb94`* — before believing
the absence.
✅ **THE FIX A CLONE CAN APPLY WITHOUT TOUCHING THE SHARED REPO:**
```
git fetch origin refs/remotes/origin/main:refs/remotes/upstream/main
```
⛔ **DO NOT `git branch -f main` IN THE SHARED CHECKOUT casually** — it is a ref other doors read. next
deliberately did not, and flagged it instead. ⚠️ **The next door to run a ceremony there WILL hit the
same refusal**, and it will look like a landing that did not happen.
📌 Same family as the 33 `*dir*` trees entry above: **`origin` in a checkout is a LOCAL CACHE, and here
it is a local cache of a local cache.** `git ls-remote <url>` remains the only instrument that answers
"what is on the remote".
