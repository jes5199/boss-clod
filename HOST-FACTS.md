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
⭐⭐ **ONE LOCAL-PATH `origin`, TWO DISTINCT WAYS TO LIE — biscuit, 2026-09-04, which had already been
bitten by the OTHER one:** its clone's `origin` was `/home/jes/commonplace-next` during `REL-1`, and
**`land-round.sh` would have printed `LANDED` while GitHub stayed at `2144a3a`.** ⇒
```
a PUSH that lands nowhere real        (biscuit, REL-1 — the write goes to a checkout, not the remote)
a FETCH that hides an object that exists   (next, tonight — rc 0, and the sha is "not a valid object")
```
⭐ **Same misconfiguration, opposite directions, and neither announces itself.** biscuit repointed its
clone to GitHub for the first reason, which is why its ceremonies are not exposed to the second —
**verified, not assumed: `origin/main` == `ls-remote <url>` == `ee7fb94`.**
⇒ ⭐⭐ **THE GENERAL FORM: `origin/main` IS A CACHE OF A CACHE WHENEVER `origin` IS ITSELF A CHECKOUT.
A `git fetch` returning rc 0 says the fetch SUCCEEDED — never that it fetched from where you think.**
⛔⛔ **IT IS NOT ONE REPO. I SWEPT EVERY SHARED CHECKOUT ON THE BOX (2026-09-04T01:59Z) — THREE ARE
STALE RIGHT NOW:**
```
repo                 shared checkout's local main   remote (ls-remote)      state
commonplace-next     500a6df6…                      ee7fb9400…              ⛔ STALE, 2 landings behind
commonplace-dir      1f5a0077…                      df25b5072…              ⛔ STALE, 8 landings behind (A43→A50)
commonplace-log      7f8e3b4d…                      778997e5…               ⛔ STALE
commonplace-cell     9b8a1428…                      9b8a1428…               ok
commonplace-doc      faeea17d…                      faeea17d…               ok
commonplace-chit     7d314853…                      7d314853…               ok
```
⭐ **dir found by chit, which had ALREADY BEEN BITTEN BY IT at 02:0xZ** — it cloned from
`/home/jes/commonplace-dir`, got `origin/main = 1f5a007`, and **the clone was correct while its `origin`
was the wrong origin.** It re-cloned from GitHub; that is why it is not exposed now.
⚠️ **`commonplace-log` is stale and NOBODY HAS BEEN BITTEN BY IT YET** — it was found by sweeping rather
than by a door hitting it, which is the only cheap way this class is ever found.
⭐⭐ **THE DISCRIMINATOR THAT MAKES THIS SWEEPABLE, and why it beats waiting for a door to trip:**
`git -C <checkout> rev-parse main` vs `git ls-remote <url> refs/heads/main`. **Two instruments, one
question. Neither alone can answer it, and the checkout's own `origin/main` is not a third opinion — it
is the first one again.**
✅ **CLONE FROM THE REMOTE, NEVER FROM A CHECKOUT:** `git clone git@github.com:commonplace-systems/<repo>.git`
⛔ **Nobody force-moves a shared `main`.** All three are BEHIND, not diverged; they are refs other doors
read; and the fix belongs in each clone.
📌 Same family as the 33 `*dir*` trees entry above: **`origin` in a checkout is a LOCAL CACHE, and here
it is a local cache of a local cache.** `git ls-remote <url>` remains the only instrument that answers
"what is on the remote".

## ⛔⛔ AN OVERWRITTEN `prompt.txt` IS INDISTINGUISHABLE FROM AN UNREAD ONE — CHECK THE CONTENT, NOT THE PATH (2026-09-04)

**plan rewrote `P2E3-ISO-1`'s brief after biscuit refused the round — and overwrote the file IN PLACE.**
⇒ ⛔ **The path is identical for both versions.** A re-dispatch that trusted the path would have
**re-run the REFUSED brief and looked entirely correct doing so** — same clone, same base, same launcher,
same green preflight.
⭐ **next caught it by checking the CONTENT, not the location: 10 `request_id` hits and the string
`sol/next-p2e3-iso-1b` present ⇒ this is the re-brief, not the refused text.**
⇒ ⭐⭐ **SAME CLASS AS THE STALE `main`: A NAME THAT RESOLVES TO THE WRONG CONTENT.** The name is stable,
the referent moved, and nothing in the read announces it.
✅ **STANDING RULE FOR EVERY RE-BRIEF: a freshness check on the prompt's TEXT before dispatch** — grep for
a token that exists only in the new version (a round name, a branch name, a term the rewrite introduced).
⚠️ **It costs one grep and it is the only thing that separates a re-dispatch from a repeat.**
📌 Sol rounds are metered, so a repeat costs money as well as a window.


## ⛔⛔ SECURING A SOL ROUND IS `git status --porcelain` **AND** `git diff` — THE DIFF ALONE IS NOT A BACKUP (biscuit, 2026-09-04T03:14Z)

**Sol's sandbox mounts `.git` READ-ONLY, so a finished round leaves an UNCOMMITTED WORKTREE and no
branch.** I told biscuit to *"secure the patch"*. ⛔ **`git diff` alone would have lost two of the round's
files.**
```
git status --porcelain  →  41 entries        git diff  →  39 files
⇒ the other two are UNTRACKED and appear in NO DIFF:
   ?? test/support/test_fixtures.ex               (the new helper — 12 lines)
   ?? test/commonplace_next/test_fixtures_test.exs (its arms — 60 lines)
```
⇒ ⭐⭐ **A NEW FILE IS INVISIBLE TO `git diff` IN AN UNCOMMITTED TREE — AND THIS ROUND'S ENTIRE SUBJECT WAS
A NEW FILE.** All 39 modified files CALL the helper the patch does not contain. ⛔ **A patch that applies
cleanly and produces a tree that does not compile.**
⭐ **THE CONTROL THAT CAUGHT IT WAS COUNTING: 41 status entries vs 39 diff files — two numbers in
different units, refusing to agree.**
✅ **PROCEDURE, both instruments, every time:**
```
git --no-optional-locks -C <wt> diff > round.patch          # modified files, and a read that does not write
git --no-optional-locks -C <wt> status --porcelain          # ⇒ copy every `??` entry OUT SEPARATELY
```
⚠️ **next's `--no-optional-locks` protects the tree from the read; IT DOES NOT MAKE THE READ COMPLETE.**
Two different defects, two different fixes, and having one is not having the other.


## ⛔⛔ A CLONE WHOSE `origin` IS A CHECKOUT CANNOT LAND — AND THE CEREMONY CANNOT DETECT THIS ABOUT ITSELF (next, 2026-09-04T04:33Z)

**next found this ONE COMMAND before spending a granted slot on a warranted round.** Its clone's `origin`
was `/home/jes/commonplace-next`, a local path, and `land-round.sh` **compares against `origin/main` and
PUSHES TO `origin`.**
```
BEFORE   local main 2144a3a · origin/main 500a6df · upstream/main 4085fee · ls-remote 4085fee
```
⇒ ⛔⛔ **THE CEREMONY WOULD HAVE PUSHED INTO THE SHARED CHECKOUT AND PRINTED `LANDED`, WHILE GITHUB STAYED
AT `4085fee`.** ⚠️ **It would not even have REFUSED — it would have SUCCEEDED AND BEEN WRONG.**
⭐⭐ **AND THE REASON NO GATE CATCHES IT: `land-round.sh`'s own `LANDED` line reads `origin/main`, so THE
SUCCESS MESSAGE IS COMPUTED FROM THE SAME WRONG REFERENT THAT MADE IT WRONG.** ⇒ **The ceremony cannot
detect this about itself, at any level of care, because its verdict and its defect share a source.**
✅ **CHECK BEFORE ANY CEREMONY, and it is two commands:**
```
git remote -v                                   # is origin a URL or a PATH?
git rev-parse origin/main  vs  git ls-remote <url> refs/heads/main   # cache vs endpoint
```
✅ **REPAIR, clone-only, nothing shared touched:** `git remote set-url origin <github url>` (and
`--push`), then confirm `origin/main == ls-remote`. **next's local main was 36 BEHIND, 0 AHEAD ⇒ a
fast-forward, not a force.**
⭐ **This is biscuit's `REL-1` failure (`land-round.sh` would print `LANDED` while GitHub stayed at
`2144a3a`) arriving at a second door — the "push that lands nowhere real" half of the two-ways-to-lie
entry above, now measured twice at two doors.** ⚠️ **Caught only because next pre-checks the ceremony's
preconditions at the desk: a refusal spends the token, and this one would not have refused.**

## ⭐ `state-render-cron.sh` TAKES ~25 MINUTES — A LONG RUN IS NOT A HANG (2026-09-04)

**The cron fires at `:17`; its outcome row is written at `:42`–`:43`.** ⇒ **A render still running at
`:28` is NORMAL.** ⛔ **I nearly read an 11-minute run as a wedge, and on 2026-09-04T09:43Z I DID
kill one at 2 minutes with a Bash timeout — SIGTERMing a BEAM mid-render and leaving `STATE.md`
untouched while the heartbeat advanced.**

⭐ **JUDGE IT BY `logs/state-render-outcomes.log` GAINING A ROW, or by `STATE.md`'s mtime — never by
the process still being alive and never by the heartbeat**, which is touched BEFORE the render runs.
⚠️ `loops-health.sh` now gates on `STATE.md`'s mtime for exactly this reason (three arms proven:
fresh ✅, stale ⛔, MISSING ⛔-louder).

## ⛔ `bash` READS A RUNNING SCRIPT LAZILY, BY BYTE OFFSET (commonplace-chit, 2026-09-04)

**Editing a shell script while an interpreter is executing it can make that interpreter resume at a
SHIFTED position and run garbage.** ⇒ **The safe form is kill-and-relaunch** — which for a driver
mid-round means stopping the round.

⭐ **WHY IT IS FILED HERE AND NOT IN A REPO: any door that edits a long-running `.sh` on this box
hits it**, and every ceremony driver, nudge script and watcher here is a long-running `.sh`.

⚠️ **EARNED BY A DECLINE, NOT A CRASH.** I told chit to drop a `:09–:18` straddle guard from its live
driver; it measured first and refused twice over: **(a)** no remaining start fell in that window, so
the edit bought **ZERO** — the ~8 minutes I was recovering was a hold that had already ended; **(b)**
the edit itself was the risk. ⇒ ⭐ **It applied the override to the NEXT driver and RECORDED it rather
than PERFORMING it.** ⛔ **A cheap-looking edit to a running script is never cheap, and "the change is
tiny" makes it worse, not better — a small edit still shifts every byte after it.**

### ⭐ COROLLARY (commonplace-cell, 2026-09-04): A SCRIPT CAN BE REPLACED ON DISK WHILE IT RUNS

`git merge` **REPLACES `bin/land-round.sh` on disk while bash is executing the copy it already read.**
⇒ ⛔ **A sha256 of that file taken AFTER the merge names the script that will LAND, not the one that
RAN.** ⭐ **cell found this INSIDE the field built to expose wrong referents** — `RECEIPT-SCRIPT-FIELD-1`
records which script executed, and the naive implementation would have recorded the wrong one.
✅ **Capture the executing script's hash BEFORE the merge.**
⛔⛔ **AND THE BOUND ON THAT CAPTURE, cell's own, travelling with the fix so it is not over-read:
IT HASHES THE FILE `$0` NAMES, NOT THE BYTES BASH EXECUTED.** ⇒ **A reader who takes it as "these are
the bytes that ran" has over-read it by one step.** ⭐ **The distinction is real precisely because of
the lazy-read fact above: bash may already have consumed a version of the file that no longer exists
on disk when the hash is taken.**
⚠️ **Same root as the entry above (bash reads lazily, by byte offset) with a different actor: there
the danger is an EDIT, here it is a MERGE — and a merge does not feel like editing a running script.**

## ⛔⛔ `cd X && cmd &` CAPTURES THE **SUBSHELL**, NOT THE COMMAND — THREE DOORS IN ONE HOUR (2026-09-04)

**`&` backgrounds the WHOLE `&&` LIST, so bash forks a subshell and `$!` is that subshell.** Killing
it leaves the real workload **orphaned at `PPID 1`** — and every door reported *"killed by captured
pid"* **truthfully** while the workload lived on.
```
biscuit  cd "$CL" && nohup node … &   ⇒ 2 orphans, PPID 1, in a gating path
chit     cd /home/jes && nohup node … &   ⇒ /proc/$!/comm read "bash"
boss     cd X && nohup node … &      ⇒ 2 orphans, ONE OF THEM GATING THE BOX
```
⚠️ **`nohup` is not the culprit and `setsid` does NOT fix it** — `setsid` returns its own pid unless
you add `--wait` or `exec`.

✅ **THE FIX IS FOUR CHARACTERS — make the subshell BECOME the command instead of parenting it:**
```
( cd "$X" && exec node -e '…' ) &     ⇒  $! IS the command's own pid
```
✅ **AND THE VERIFICATION THAT COSTS NOTHING AND WOULD HAVE CAUGHT ALL THREE:**
```
[ "$(basename "$(readlink /proc/$!/exe)")" = node ] || echo "captured the WRAPPER, not the workload"
```
⭐ **Same selector `box-free.sh` now uses for ⑨ — `exe`, never `comm`, never a pattern — applied to
your OWN child instead of to someone else's process.**

⛔ **WHY IT IS A HOST FACT AND NOT A RULE IN A CHANNEL (chit): three doors got it wrong independently
inside one hour, so the next door will too.** ⇒ **A remembered rule does not fire; a filed one does.**
⚠️ **KNOWN EDGE, named by chit rather than discovered later: a workload run DIRECTLY in a scratchpad
ROOT will NOTE when it should gate — the depth discriminator reads it as a session harness.**

## ⛔⛔ `docker build` IS A TENANCY NO INSTRUMENT ON THIS BOX CAN ATTRIBUTE (biscuit + boss, 2026-09-04)

**A multi-minute Elixir release build saturates four cores and reads `FREE`.** The work lives in
**root-owned** `dockerd` / `containerd` / buildkit — cwd `/`, not the door's, and not owned by it.
```
ps -o comm= -p 1006            dockerd            ⇐ VISIBLE by comm
readlink /proc/1006/exe        DENIED (root)      ⇐ INVISIBLE by exe — the selector box-free.sh uses
readlink /proc/1006/cwd        DENIED (root)      ⇐ and no cwd-in-fleet-path test can attribute it
POSITIVE CONTROL  readlink /proc/$$/exe → /usr/bin/bash   ⇒ the reader works; the target is opaque
docker info → 0 running / 0 total                 ⇐ a BUILD is not a container in `docker ps`
```
⭐ **WHAT *IS* COVERED, and I nearly reported otherwise before grepping: a BEAM INSIDE a running
container (cwd `/app` + a `docker-<id>.scope` cgroup) DOES gate as `BUSY-CONTAINER`.** ⇒ **biscuit's
`docker run` phase was correctly seen; only the `docker build` phase is invisible.**

⛔ **NOT FIXED, AND I AM NOT SHIPPING A TERM I CANNOT FIRE.** A `comm`-based term for
`containerd-shim*` / `runc` / `buildkitd` is plausible — those exist only during container work,
unlike the always-on daemons — **but `comm` is the field that LIED for node, and I would be shipping
a red arm I have never seen fire, which is exactly today's mistake.**
⇒ ⛔ **FIRST PLAN WAS WRONG AND biscuit CAUGHT IT: "measure during biscuit's next real build" is a
condition waiting on someone else's future act that NOBODY HAS SCHEDULED — the same shape as the
`.state-render-HOLD` that cost twelve hours.** biscuit has NO `docker build` queued and may not for
weeks (`1b-ii` is a Worker script; `1c` is HTTP).
⇒ ✅ **THE NEXT REAL CONTAINER BUILD ON THIS BOX IS MINE: `BACKUP-1b-i`'s DEPLOY.** `wrangler deploy`
on `commonplace-log` BUILDS AND PUSHES THE BEAM IMAGE — that is hazard 1, the thing that took
`commonplace-log-realm` v5 → v6. ⭐ **So the measurement happens during MY OWN act, on real work, with
nothing staged, while I am holding the box anyway.**
⚠️ **CAVEAT so the reading is not misused (biscuit): `wrangler` drives the build through the SAME
dockerd/buildkit but may use its own builder invocation. If the population differs from a plain
`docker build`, THAT DIFFERENCE IS DATA, NOT NOISE** — and biscuit's 12:50Z run is the plain-build
comparison point.
⛔ **biscuit OFFERED a throwaway rebuild and explicitly refused to propose it: "that is inventing
contention to measure contention, and I am not going to talk you into it sideways." DECLINED.**

⚠️ **UNTIL THEN, STATE IT PLAINLY: for a `docker build`, THE ANNOUNCEMENT IS NOT A SECOND WITNESS —
IT IS THE ONLY ONE.** ⭐ **Twice today a non-BEAM tenancy was carried entirely by an announcement
(biscuit's build at 12:50Z, its `1b-i` round at 14:41Z), and both times it held — because biscuit had
already ruled `FREE` undecidable alone and took the box on another door's ANNOUNCED release.**

## ⛔⛔ A DOOR'S LAUNCH WORKTREE HAS ONE WRITER — `git checkout` IS A WRITE (plan, against itself, 2026-09-04)

**`git checkout --detach <sha>` in ANOTHER door's worktree WRITES HEAD.** ⇒ **plan read shas that way
in `/home/jes/next-suite-load/wt` and caused at least two of the day's detached-HEAD incidents —
including one that cost a ceremony slot, and one next blamed on itself.**
✅ **Verified in that worktree's own reflog:** `HEAD@{16:11:20}: checkout: moving from main to c369e2d`
followed by next moving back.
✅ **RULE: read another door's tree with `show` / `grep` / `cat-file` / `diff` BY SHA. NEVER
`checkout`.** ⛔ **It belongs on the ban list beside `pkill -f`: both look like reads and are not.**
⚠️ **AND THE DETECTION PROBLEM IS THE REAL ONE: the writer sees a successful read; the OWNER sees an
unexplained state change in its own tree and blames itself.**

## codex 0.153.3 — MODEL IDS MEASURED 2026-09-04T21:09Z

**Invoked, not read off a list. `codex --help` does NOT enumerate models — `-m` is a free string,
so the only instrument that answers "is this model available" is calling it.**
```
gpt-5.6-sol      answers   ⇐ POSITIVE CONTROL, run FIRST so a probe failure is attributable
gpt-6-astra      answers   NEW in 0.153.3's binary
gpt-5.6-terra    answers   NEW
gpt-5.6-luna     unchanged
gpt-6-astra-mini 400 "not supported when using Codex with a ChatGPT account"  ⇐ NEGATIVE CONTROL
```
⭐ **The negative control is what makes the two greens mean anything: the endpoint DISCRIMINATES.**
Without it, "both answered" is equally consistent with an endpoint that accepts any string.

⛔ **`codex exec` OUTSIDE A GIT REPO REFUSES AND EXITS 0.** *"Not inside a trusted directory and
--skip-git-repo-check was not specified."* — **rc=0, no work done.** Another member of the
rc=0-with-empty-result family. Pass `--skip-git-repo-check` for scratchpad probes.

⛔⛔ **AND A CLAIM I COULD NOT TEST, RECORDED SO NOBODY REPEATS IT AS FACT: whether `gpt-6-astra`
was ALSO present in 0.146.1 is UNKNOWABLE FROM THIS BOX NOW.** `npm install -g` overwrote the old
binary, and `@openai/codex-linux-x64@0.146.1` **404s from the registry** (the platform packages are
published as `npm:@openai/codex@<ver>-linux-x64` aliases and that version is gone).
⚠️ **My first attempt LOOKED like a clean absence — `grep -c astra` → 0 — until the positive control
(`gpt-5.6-sol`) ALSO returned 0, proving the extracted file was empty.** ⭐ **A blind instrument and a
true absence are the same output, and only the control separates them.**
⇒ **I had already told jes "0.146.1 didn't have it" before testing. Corrected in `10949`.**

## ⛔ `worktree` / `index` / `HEAD` ARE THREE DIFFERENT ANSWERS TO "WHAT CHANGED" (commonplace-next, 2026-09-04)

**A gate's count is meaningless until you know WHICH ONE it reads.**
`commonplace-next/bin/check-dev-path-inventory.sh:87` builds its corpus with **`git ls-files`, which
reads the INDEX.** ⇒ **A Sol round's new files are UNTRACKED, so the gate is blind to exactly the
round's own additions and reds for a reason that is not the round's.** ✅ Resolved by **staging** the
files and re-running: rc 0.

⭐⭐ **AND THE SHARPER HALF, next's: Sol had checked the same gate using a TEMPORARY index — *"a
report about a tree that never existed."*** ⇒ **A synthetic index makes the gate answer a question
about a state nobody will ever ship.**

⚠️ **Same family as biscuit's `porcelain 2 · diff 1`** — two true counts of two different subjects,
where the disagreement looks like an error in one of them.
⇒ ⭐ **Before believing any "N files changed", ask: worktree, index, or HEAD?**

## docker on this box: ONE daemon, and it is EMPTY because I pruned it (2026-09-04T21:52Z)

```
pgrep -a dockerd            EXACTLY ONE — pid 1006, -H fd:// --containerd=…
/var/run/docker.sock        srw-rw---- root:docker   ⇐ reached by GROUP MEMBERSHIP, not a user socket
/run/user/1000/docker.sock  DOES NOT EXIST           ⇐ no rootless daemon
sudo -n docker …            "a password is required" ⇐ a root daemon cannot be queried separately
docker system df            Images 0 · Containers 0 · Volumes 0 · Build Cache 0
```
⇒ ⭐ **"as me" and "as root" are the SAME daemon here, so a user-run `docker system df` is not a
partial view.** ⚠️ **Limit: `/var/lib/docker` is unreadable at this privilege, so the one-daemon claim
rests on the socket and process lists, not on the directory.**

⛔ **`docker system prune` FREES ZERO — because it already ran.** My own reclamation earlier today:
`images 15 → 0 · build cache 86 → 0 · avail 10,124 → 12,350 MB (2,226 MB)`.
⇒ ⭐⭐ **THE ACT AND ITS CONSEQUENCE WERE RECORDED IN MY LEDGER AND THE QUESTION AROSE AT ANOTHER
DOOR** — biscuit measured a zero it could not explain and correctly reported it as an OPEN QUESTION
rather than a conclusion. **A box fact filed only where the actor stands is invisible to the next
measurer.** That is exactly why this file exists.

⚠️ **CONSEQUENCE STILL OUTSTANDING: the next `docker build` on this box is a COLD build, every layer
from scratch.** ⛔ **Do not read its wall time as evidence about the image, the deps, or the box.**
Slow is expected; a FAILURE is the real signal.
📌 `[measured]` I pruned 15 images to 0 today · `[INFERRED]` the commonplace-log image was among them —
I did not enumerate before deleting, so I cannot name it.

## ⛔ A `DELETE` ROUTE THAT RETURNS 204 AND DELETES NOTHING (commonplace-log Worker, found by biscuit 2026-09-04)

**The log Worker's ONLY `DELETE` route sits on the realm path and returns `204`. It revokes the READ
CAPABILITY. The realm, its meta row, and every entry SURVIVE it.**

⇒ ⭐⭐ **`grep DELETE` finds it · the verb matches · the status code is the one a deletion returns ·
and the thing is still there.** ⚠️ **This is not a near-miss, it is a TRAP THAT REWARDS THE CORRECT
INSTINCT:** a door asking *"is there a removal path?"* runs exactly the search that produces the wrong
answer, and gets a `204` to confirm it.
⛔ **A false positive that answers your question in the AFFIRMATIVE is worth ten that answer in the
negative — nobody re-checks a yes.**

📌 **The actual position (biscuit, `REALM-REMOVE-1a`):** the Cloudflare control plane has **no delete**
for a DO instance — two endpoints, both GET, no DELETE anywhere in the DO API. **The only per-instance
removal is `state.storage.deleteAll()` INSIDE the object**, and that it truly drops the SQL tables is
`[docs, fetched]`, **not measured**.

## commonplace-next's release container: BUILDS, BOOTS, needs FIVE env vars and a storage lane (measured 2026-09-04T22:03Z by biscuit, image verified by me)

```
image commonplace-next:2594dc7 · id 9cc01409c25f · 205 MB · amd64/linux
       [measured — `docker images` at MY door, control: 1 image now, 0 before this build]
① gh auth status rc 0 (account jes5199, scope repo)
② mix deps.get --only prod  ON THE HOST — 34 dep dirs, 53 MB. The builder has NO `gh` and no
  credential helper, which is WHY the fetch cannot happen inside the image.
```
⭐⭐ **REQUIRED ENV, IN REFUSAL ORDER — this inventory did not exist before tonight:**
`SECRET_KEY_BASE` → `COMMONPLACE_ACCESS_ISSUER` → `_AUDIENCE` → `_JWKS_URI` → `_ROSTER`.
**With all five the app STARTS** (keystore `count=1`), then exits: `storage.internal:80 nxdomain`
⇒ **the app REQUIRES the storage sidecar lane. A build fact and a deployment fact, separated.**

⛔⛔ **AND THE ACCEPTANCE ARM AS SPECIFIED COULD NOT SEE WHAT THE DOCKERFILE EXISTS TO PREVENT.**
The `SECRET_KEY_BASE` refusal fires in `runtime.exs`, which runs **BEFORE application start**; the
Rust NIF loads **AT application start**. ⇒ **A pass on that arm proves the release reaches config and
says NOTHING about glibc/NIF.** ⭐ **biscuit kept going rather than bank the specified pass.**
✅ **NIF proven by CALLING it:** `apply(Commonplace.Biscuit.Native, :rustler_init, [])` →
`{:error, {:reload, "NIF library already loaded"}}` — **"already loaded" is a POSITIVE result.**
⛔ **The alternative was inferring it from an absent `on_load_function_failed`, and an absence has
more than one cause.**

📌 **Kept on the box deliberately:** the 205 MB image (it is `DEPLOY-NEXT-1`'s artifact) and `nextsrc`
with its 53 MB `deps/`. **Disk / at 91%, 12 G free.** ⚠️ Build cache is no longer 0 — the next
`docker system df` will NOT read all-zero, and that is this build, not a leak.
