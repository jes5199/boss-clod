# boss-clod lessons — near-misses and the shapes behind them

**File things here. Do not text them.** jes, 2026-08-09: *"these updates about the
meta problems. save them to doc files instead of texting me. I want to hear about:
quotas, what's getting done, actual problems. not diagnosis of near-misses, file
that stuff but don't text it."*

A near-miss is not an actual problem. It goes here with enough detail that the next
session can act on it, and it stays out of Telegram.

---

## 1. The enclosure error — the most expensive class we have

**A correct pattern applied to the wrong extent.** Four instances on 2026-08-09
alone, across three agents, in four different artifacts:

| Artifact | The window | What it produced |
|---|---|---|
| `gh run list` | 5 runs | "CI red since 12:08" — it had been red twelve hours |
| ExUnit output | first `Finished in` | 390 tests read as a 4,200-test umbrella result |
| grep anchor | `^CELL` | 2 of 4 cells seen; the 2 missing were the load-bearing ones |
| `head -20 "$f"` | first 20 lines | `ci-health.sh` falsely reported as missing `pipefail` (it is on line 23) |

**Trigger to watch for:** any `head` / `--limit` / `-n` / window literal whose output
then feeds a claim about a *whole*.

### 1c. ⛔ THE FIFTH INSTANCE WAS HIDING INSIDE THE ARTIFACT BUILT TO FIX THE FOURTH

2026-08-10, CX-q9sa. **"41 offenders" was quoted for a day — by the brief, by the revert
commit, by the queue row, and by me — and the measured number is 58** (mcp 21, web 20,
**CLI 17**, others zero). ⭐ **41 was never the umbrella's count: it was "fires in the two
suites someone happened to run after the merge."** CLI was never measured at all.

⇒ **The count was not wrong by arithmetic. It was SCOPED, and it travelled without its
scope** — which is 7a's "a headline is what survives quoting" and §1's enclosure error
turning out to be *the same defect seen from two sides*. ⚠️ It survived a revert, a brief,
and a queue ranking, all written by people actively hunting this exact class.

### 1d. ⛔⛔ THE SAME DEFECT THREE TIMES IN ONE NIGHT — a hand-built list treated as complete

| # | The curated list | What it missed | Cost |
|---|---|---|---|
| 1 | `grep -c FileRmRfGuard test_helper.exs` | module name lives in the REQUIRED file | a misleading **0** that read as "guard never installed" |
| 2 | env allowlist `^(PHX_SERVER\|PORT\|MIX_ENV\|COMMONPLACE_\|ERL_)` | `ELIXIR_ERL_OPTIONS` starts `ELIXIR_`, not `ERL_` | **Erlang distribution on 0.0.0.0** — an RCE surface, live ~90s |
| 3 | suite list naming `.../test/commonplace/process` + `/trust` | those are **SUBTREES**: 70+213 of the app's **3278** tests | **95 guard fires shipped red to main** |

⭐ **Each was hand-built, looked complete, and wasn't.** ⇒ **A pattern-built list is a
HYPOTHESIS; only an enumeration of the whole is a measurement.**

⛔ **#3 is the sharpest, because the brief CONTAINED ITS OWN CORRECT RULE.** Its §6 header
read *"NAMED BY BLAST RADIUS = ALL SIX APPS … believing otherwise is exactly what caused the
revert"* — and **the table one line beneath it named two subtrees.** ⇒ **Prose stating the
rule does not constrain the table implementing it.** The contradiction was inside a single
document, written in one sitting, by someone enforcing that exact rule on others all night.
⚠️ ⇒ **When a doc states a scope rule, the artifact that USES the scope must be checked
against it mechanically** — a count, an expansion, anything but re-reading your own prose and
agreeing with it.

⭐⭐ **FINAL NUMBER: 153.** The sequence ran **41 → 58 → 153** — the prior, then an honest
enumeration of the *named* suites, then the whole app once the scope error was fixed. **3.7×
the number everyone quoted for a day.**
⇒ **THE REUSABLE FORM, better than "check your scope": A GUARD'S FIRST FIRING IS A LOWER BOUND
ON ITS OFFENDERS, NEVER A CENSUS.** It reports **where the guard was looking**, not how much
there is. ⚠️ Never size work from an initial firing.

⭐⭐ **THE SIBLING TELL — REPEATED ACCIDENTAL DISCOVERY MEANS THE CLASS WAS NEVER ENUMERATED.**
One commit (`a4e708d`, making `public_keys/0` artifact-only) produced **three silent-degradation
sites in one subsystem, found by three different investigations across twelve hours, every one
of them BY ACCIDENT**: nothing published the artifact at boot; two consumers collapsed
`:absent` and `{:error,_}` into `[]`; self-trust dropped through a silent `else`.
⇒ **Three found by accident is not three bugs — it is a CLASS**, here *"consumers of
`public_keys/0` that treat absence as empty."* **One grep answers it for the whole class**,
and it costs less than the third accident did.

⛔ **NARROWED BY THE ENUMERATION ITSELF — my first wording said "a class the review MISSED",
and that is wrong.** At **3 of 4 already correct**, it was never systematically missed. ⭐ The
accurate statement: **the class has four members, and INCIDENTS WERE FIXING THEM ONE AT A
TIME** — the originating commit covered two, another ticket covered a third the same night.
**The enumeration found THE LAST ONE instead of waiting for a third accident to surface it.**
⚠️ That distinction matters for what you conclude about the reviewers: *"nobody was looking"*
and *"attrition was working, slowly, one incident at a time"* are different diagnoses with
different remedies, and only the census tells them apart.
⚠️ **The tell is the MODE of discovery, not the count.** Bugs arriving through unrelated
investigations mean nobody has asked the population question — so **enumerate the callers
BEFORE fixing the instances**, or the fourth site is found by the next accident.

⭐⭐ **AND IT CLOSED THE CLASS RATHER THAN OPENING IT — which is the half people avoid
enumeration expecting NOT to get.** Run within minutes of being proposed: **four** non-test
callers of `public_keys/0`, and **three were already correct** (boot-publish distinguishes
`{:ok,keys}` / `:absent` / `{:error,_}`; `public_key/0` distinguishes all four including
`{:ok,[]}`; `anchor_keys/1` fixed earlier the same day). **Exactly one is the known defect.**
⇒ The enumeration converted *"how many more of these are there?"* — an unbounded worry that
would have shadowed every future fix in the subsystem — into a **bounded fact with a
denominator**. ⭐ **A population check that finds nothing new is not wasted; it is the only
thing that can retire the fear**, and it is cheaper than carrying the doubt.

⭐⭐ **AND THE SAME DISEASE TWICE IN ONE ARTIFACT: A CONTROL THAT ENCODES AN ENVIRONMENTAL
ACCIDENT PASSES EXACTLY WHERE IT CANNOT MATTER.** The guard's own child-delete control assumed
CubDB's file is `0.cub` — true on a fresh checkout, **false after any compaction** — so it
**passed on clean trees and failed on every tree that had done real work.** Its sibling defect
was verifying an umbrella-wide guard against three suites in **one app**. ⇒ **Name the
environmental facts your control depends on — filenames, fresh state, empty dirs, one app, one
seed — then ask which of them production violates.**

⭐ What made the new number trustworthy rather than merely different: the brief said
*"41 is a PRIOR, not a target; the measured number WINS; do not reconcile toward 41"* — and
an independent second instrument agreed exactly where the two overlapped (both measured mcp
21, from the same two files). **Pre-registering that the measurement beats the prior is what
lets a builder report 58 instead of quietly finding 41.**

### 1a. The window that spans a fix — a count over a repaired period measures HISTORY, not STATE

**The most expensive instance of the day, because it reached jes twice and moved a queue.**
CI failures were counted over 40 runs. `289894c` (03:47, *"Stage B's index left the
mixed-plane fixture blind"*) sits **inside** that window, so the count summed a
pre-fix world and a post-fix one.

Consequences, all wrong, all confidently stated:
- *"The positive control is failing, 11 of 31 runs"* — **fixed thirteen hours before
  I said it.** The 11 failures were contiguous in time (2026-08-08 23:34 → 03:39),
  not scattered across seeds. Last red 03:39, fix 03:47, **zero after**.
- *"The centre of mass is a mixed-plane cluster, not `ViewActionDispatch`"* — this
  **overturned a correct belief.** Post-fix only: `ViewActionDispatch` 15 of 20,
  mixed-plane **zero**.
- The `isolate-vs-full` proof ("green isolated, red in umbrella") was run against the
  **already-fixed** projection suite, so *"contamination, not broken code"* is
  currently an inference about the wrong cluster.

⭐ **CONTIGUOUS-IN-TIME vs SCATTERED is the discriminator, and a rate cannot see it** —
identical to the audit-capture 0.003%, which was 100% for one second then 0% for 25
hours. **Twice in one day, opposite domains: a ratio erased a step function.**
⇒ **Before counting anything over a time window, ask what LANDED inside it.**
⚠️ What survived: CI is still not a signal — **20 red / 8 green post-fix (71%)** — and
that conclusion rests on its own numbers, not on the mixed-plane story.

⭐ **The audit built to find this class failed of this class**, and only a positive
control caught it. That is why the positive control is non-optional rather than
diligent: check the pattern against a case you *know* matches before trusting a zero.

⚠️ Related: a pipe-count of `\|[^|]` counted `||` (logical OR) as a pipeline and
inflated an exposure from 4 scripts to 12.

## 1b. ⭐⭐ You cannot infer an internal cadence from an external artifact

**Three independent instances on 2026-08-09, in unrelated subsystems:**

| Question | The external proxy reached for | Why it lied | What it actually needs |
|---|---|---|---|
| Where do audit denials get lost? | 148,647 log lines in / 5 records out | the middle was **inferred**, never measured | per-stage counters (CX-rp33) |
| How far behind is the deploy? | beam mtimes as a merged-commit proxy | moves when Sol compiles into shared `_build` | key on **serve age**, one writer, no contention |
| How long is the unpublished-key window? | store flush times as a sign-rate proxy | CubDB flush ≠ node signing; **n=2 compaction artifacts** | instrument `signing_context/0` |

⛔ **Each proxy was REAL, MEASURABLE, and ABOUT SOMETHING ELSE.** ⇒ That is far more dangerous
than a missing measurement, because **it yields a confident number instead of an error**. In all
three the wrong number was available immediately and the right one required instrumenting the
thing itself.

⚠️ I nearly shipped the third: `median=18,844s` from two CubDB compaction files, which would have
survived being quoted. **Reporting that the method didn't answer the question was worth more than
the number would have been.**
⭐ **Test before quoting a proxy: is the thing I measured written by the same actor, at the same
moment, for the same reason as the thing I'm asking about?** If any of the three differ, it is a
different population.

## 2. Silent success — "it worked" and "it never ran" sharing an exit code

- **`squad-alerts-poll.sh` ended in a bare `exit 0`** with the DB query's status
  unchecked. A locked DB or schema change would print nothing, exit 0, and be read as
  *"nothing undelivered"* — the exact reassurance the poller exists to prevent.
  Fixed @0df2840: a failed poll shouts on stdout and exits 3.
- **`psgrep.sh` only defined its function and never called it.** On PATH it answered
  *"no matches"* to every query at rc=0. ⚠️ "No matches" is the answer that precedes a
  broad kill. Fixed @7c0d6cf.
- ⭐ **`rc=0` with empty output passes every check you would think to write.** An exit
  code is a claim about the program; only an *answer* is a claim about the world.

## 3. Reachability is a change to the program

Putting three tools on PATH broke two of them, both silently, both in the alarming
direction (`psgrep` above; `loops-health` reported all loops "NEVER RAN" because
`dirname "$0"` resolved to `~/.local/bin`). ⭐ commonplace-plan's generalisation:
**implicit location is what breaks under reachability** — a tool whose every input is
named on the command line has no surface for it.

**Check before calling a tool done:** different cwd · through a symlink · with no
arguments · and a *positive control that it returns a real answer*, not merely rc=0.

## 3a. ⭐ Failures that mimic *working* — the appearance of patience

Three separate defects on 2026-08-09, different causes, **identical signature**:

| Defect | What it looked like |
|---|---|
| waiter matching its own `pgrep` pattern | "the job is still running" |
| cron outcomes truncated by their own payload | "the cron is fine" |
| `codex` backgrounded without `< /dev/null` | "Sol is thinking about a hard brief" |

⭐ **Each fails into the appearance of patience — and patience is the one state nobody
investigates, because investigating it feels like impatience.** That is why all three
survived: not because they were subtle, but because the correct-looking response to
each was to *wait*.

⇒ **A failure mode that mimics "working" needs an AFFIRMATIVE LIVENESS SIGNAL, not a
longer timeout.** The fixes: outcome logs that record rc *and* the effect (`STATE.md`'s
mtime), holds that state their own age, and a redirect that makes the hang impossible
rather than detectable. Commits @7c0d6cf, @f882029, @f8a9536.

## 3b. ⛔ OPEN — no working pattern for guarding a REFLEX

`cp-kill` worked on its first real use; `psgrep` didn't. **The difference was not
quality — killing is a deliberate act you must invoke, and looking something up is a
reflex.** Every lookup guard either agent wrote got bypassed by someone typing the
short thing instead.

⇒ **Guards on deliberate acts can be scripts. Guards on reflexes must be the default
path or nothing** — and we do not have a working shape for that yet. Making `psgrep`
the thing my scripts call helps *scripts*; it does nothing for a hand-typed command.
⚠️ **Recorded as unsolved on purpose**, because three neighbouring things got fixed the
same day and this one is at risk of being filed as done by association.

### 3b-bis. ⭐ FOURTH INSTANCE — and the guard that EXISTS covers less than everyone assumed

2026-08-10: an agent killed a contaminated test run with `pkill -f "mix test … --seed 404"`.
**It matched its own shell** — exit 144, its command died mid-way. Its own diagnosis:
*"I reached past my own tool for the raw pattern,"* and *"the remedy that would work is making
the raw form UNAVAILABLE, not making the safe form available."*

⛔ **I went to build that and found the mechanism doesn't reach — twice over.** Recorded
because both failures are the kind that get installed and believed:

| Attempt | Why it fails |
|---|---|
| guard function in `~/.bashrc` | **Agent Bash-tool shells do NOT source it.** `$-` had no `i`, and `type bossclaude` (defined in bashrc) returned nothing. Installing it would have looked like a fix and guarded nobody. |
| shim at `~/.local/bin/pkill` | **A shell FUNCTION shadows any PATH lookup**, and the harness injects one per shell. The shim would never run. |

⭐⭐ **AND THE REAL FINDING: A `pkill` GUARD ALREADY EXISTS — it just covers something
narrower than its name suggests.** The harness injects a `pkill` function that probes the
pattern with `pgrep` and **refuses only if it matches `$CLAUDE_PID`, the CLI process itself.**
⇒ It did not fire because it was **never meant to**: it protects the agent process, **not the
agent's own shell, not another agent's processes, and NOT hermes.**
⚠️ *"There is a pkill guard"* is true and was read as broader protection than it provides —
**the same headline-versus-caveat failure as everything else tonight, this time about a
safety mechanism.** ⛔ **Which is the worst place for it: a guard you believe covers you stops
you looking for the one that does.** ⇒ **Read the guard before relying on the guard.**

⭐⭐ **THE TELL, and it generalises to every guard on this box: A GUARD NAMED FOR A COMMAND
(`pkill`) RATHER THAN FOR THE PROPERTY IT PROTECTS (`$CLAUDE_PID` surviving) WILL BE READ AS
COVERING THAT COMMAND'S WHOLE BLAST RADIUS.** The name advertises the surface it intercepts,
not the invariant it defends, and the gap between those two is invisible until someone reads
the source. ⇒ When you meet a guard, **ask what property it asserts, not what command it
wraps** — and note this is the same rule as *bind the check to the property, not the story of
how it broke*, arriving from the reader's side instead of the author's.

⭐⭐ **THE SHAPE THAT WORKS — AND WHY IT DOESN'T REACH `pkill`.** Later the same day, an agent
that had violated *"run umbrella suites one at a time"* three times fixed it for good by
putting a **`:4002` pre-flight INSIDE every run**, so a violation **refuses** instead of
producing an empty summary that reads as data. ⇒ **THE CONSTRAINT HAS TO LIVE WHERE THE ACTION
HAPPENS, NOT IN A DOCUMENT ABOUT THE ACTION** — same shape as the denominator clause living in
the brief's acceptance rather than its prose.
⚠️ **But that is exactly why `pkill` resists it: there is no "thing you run" to put the check
inside.** A suite run goes through a script somebody owns; an ad-hoc `pkill -f` typed under
time pressure passes through nothing but the shell. ⇒ **The pattern generalises to every
action that flows through an artifact you control, and to none that don't** — which is a
sharper statement of why 3b stays open than "guards on reflexes are hard."

⚠️ **NO REMEDY EXISTS AT THE SHELL LAYER**, so this stays a discipline with a tool
(`cp-kill`, which resolves by identity) — **which means it can fail again.** Carried honestly
rather than closed with a placebo: two mechanisms that *look* like fixes and guard nobody
would make the next incident **more** likely by supplying false confidence.

## 4. Tools only help if they are what you reach for

I wrote `psgrep` for the `pgrep -f` phantom-match trap, then hand-typed the trap three
days later. commonplace hit its kill rule three times in one session, the third thirty
seconds after being handed it. ⭐ **Guards on deliberate acts can be scripts; guards on
reflexes must be the default path or nothing.** Writing the tool is the easy half.

## 5. Asymmetric failures — take the recoverable one

`.sol-hold` deliberately has **no auto-expiry**. A stale hold costs wasted time; a
premature auto-release corrupts a measurement someone then acts on. Loud beats
automatic where the automatic failure is the one you cannot undo. It states its age
instead, and `loops-health` surfaces it past 90m as a failure state.

## 6. The rc you act on never comes through a pipe

Written three times in one day and violated while verifying a guard against silent
failure. ⭐ `set -o pipefail` at the top of the file is the survivable form;
`${PIPESTATUS[0]}` is a per-site reflex that has to fire every time.
**Real exposure: 4 boss-clod scripts pipe without it** (`quota-guard` fixed @8aa94bf;
`agent-status`, `psgrep`, `squad-alerts-poll` outstanding).

## 7. A recurring check whose value never changes

Deploy gap read 0 at 14:57 and 5 at 16:11. Without someone re-running the command the
row would still say 0 and look settled. ⭐ **A check that always reports the same value
is indistinguishable from one nobody is running** — the tabular form of a green that
cannot go red.

## 7a. ⭐ A headline is what survives quoting — a caveat one line below it is not part of the claim

2026-08-10, on #2's acceptance. commonplace-plan's first verdict read **"all five clauses
PASS"** with a footnote that clause ④ (red-first) was **REPORTED, not re-derived**. Both
sentences were true and the footnote was voluntarily offered — but only the headline
travels. I flagged it while relaying rather than letting it through, and plan's reply named
the general shape: **put the qualification in the field that travels, or accept that it
won't.** Same shape as a ticket title carrying its own refutation.

⇒ **When relaying someone else's verdict, check what the summary sentence claims on its
own.** A qualification that survives only in the paragraph is already lost.

### 7b. ⭐ The free verification: a red-first claim is checkable FROM THE DIFF

The flag cost nothing and **upgraded the clause from REPORTED to DERIVED** (@e567a1d):
the test asserts `{:error, {:worker_role_requires_strict_trust, _}}`, and **that atom is
introduced by the same diff**. Before the change no code path could produce it, so the
assertion was *unsatisfiable* — the test **cannot** have been green beforehand. No re-run,
no contention with an in-flight lane.

⭐ **Generalisation: whenever an assertion names a symbol the diff introduces, red-first is
provable by reading, not by running.**

⚠️ **Keep the two halves separate — they are different claims.** This proves the test is
**NON-VACUOUS** (it genuinely discriminates). It does **NOT** prove the *process* claim that
the builder ran red before writing the fix; that stays on their word, and it is the weaker
half. Collapsing both into "verified" is exactly the flattening 7a warns about.

### 7c. ⛔ PRICE THE RE-RUN BEFORE SETTLING FOR THE DERIVATION

**Same night, and it corrects 7b rather than extending it.** commonplace then re-derived the
red *by measurement* — restored the pre-fix orchestrator from `fa8a13d`, kept the test file,
ran it, got `left: {:error, {:worker_role_requires_strict_trust, message}}` vs
`right: {:ok, #PID<0.744.0>}`, 4 tests / 1 failure. **Cost: 40 seconds.** That closes the
process half a derivation *structurally cannot reach*, so #2 went to **five clauses verified,
zero on report**.

⛔ **plan's correction on itself: it reached for the free check on an UNMEASURED ASSUMPTION
that re-running would contend with two in-flight lanes — and never checked what the run
actually cost.** ⇒ The fence-fact shape one level up: **a constraint inherited, never measured.**

⭐ **The rule 7b needs: the diff argument is what you use when re-running is genuinely
expensive or contended — never a substitute chosen on principle.** Measure the cost of the
real check first; "the cheap check will do" is itself a claim requiring evidence.
⚠️ Neither replaces the other. Reach for the derivation when a lane is truly in flight.

## 7d. ⭐ GREEN-ISOLATED IS NOT "NOT MINE" — the four-arm attribution table

2026-08-10. A worker's post-change run came back **trust 213/1**, a teardown failure in an
out-of-scope guard. Every incentive said *load-marginal, out of scope, move on* — the
"pre-existing / unrelated" label this fleet is told to CHECK rather than disbelieve. It
attributed instead:

| Arm | Result |
|---|---|
| full suite @ seed 422078, WITH change | rc=2, 1 failure — **reproducible** |
| that file ISOLATED @ 422078, WITH change | rc=0 GREEN |
| ⭐ full suite @ 422078 on **UNMODIFIED** code | rc=0, **213/0** |

⇒ **The unmodified-code arm at the same seed is the only one that separates "my change
caused this" from "this was here already."** Green-isolated is the classic contamination /
load signature — and here it was **WRONG**.

⛔ **This SHARPENS the rule written 40 minutes earlier** (same-population + same-seed +
now-green ⇒ load), which is true as far as it goes but **does not license reading
green-isolated as "not mine" once the suite REPRODUCES at a fixed seed.** Reproduction has
already excluded load; isolated-green then means only **"needs the neighbours."**

### 7d-bis. ⭐ TWO DISCRIMINATORS THAT SEPARATE A REAL ALARM FROM NOISE

**① ⛔ RETRACTED BY THE THIRD DATA POINT — AND THE RETRACTION IS THE BETTER LESSON.**

**What I filed:** *"noise scatters; a monotonic climb tracks something"* — the same test read
**3.213** (round 2) then **4.941** (round 3), with more teardown work added in between, so the
climb was measuring the change.
⛔ **A rerun of the SAME tree at the SAME seed then returned 2.815** (all three arms passing,
zero guard fires). Sol's tree reads **3.213 → 4.941 → 2.815**. ⇒ **That is SCATTER, not
escalation.**

⭐⭐ **THE REAL LESSON: TWO POINTS ALWAYS LOOK MONOTONIC.** Any two distinct numbers form a
monotonic sequence — so *"it climbed"* from **n=2** is not evidence of a trend, it is a
restatement of *"they differ."* I had just filed **"one seed is not a sample"** and then
accepted **a two-point trend** without noticing it was the same error wearing a different
costume. ⚠️ **A trend claim needs enough points that scatter COULD have contradicted it.**
⇒ And note which way this cuts: the escalation argument was the strongest evidence for a real
regression, and it is gone. *(The dismissal in 7k was still a real miss — a signature seen
twice and not joined. **Wrong to dismiss it, and wrong to promote it to a trend.** And with
the trend dead, the original "load-sensitive" label may have been right on the merits, even
though it was a label standing in for a mechanism.)*

### ⭐⭐ WHAT THE THREE POINTS ACTUALLY SAY — a stronger finding than either story

**The deny-offered ratio spans 2.815 → 4.941 on the SAME tree at the SAME seed, against a
limit of 3.0.** ⇒ **The statistic's own run-to-run spread STRADDLES its threshold.**

⛔ **A GATE WHOSE MEASUREMENT NOISE IS WIDER THAN ITS MARGIN CANNOT DECIDE ANYTHING, IN EITHER
DIRECTION.** It will **fire on good trees and pass on bad ones**, and *every one of those
results is unattributable.* That is the same disease as the third arm sitting at 2.995 vs
3.0 — one arm merely closer to the line. **The whole file has one illness: arms whose variance
exceeds their budget.**

⇒ **CONSEQUENCE THAT INVALIDATES THE CHEAP TEST:** a single matched run on the other branch
answers nothing — *a pass does not clear, a fail does not convict*. **Compare DISTRIBUTIONS,
not draws:** ~5 runs of the file alone per branch, compare medians *and* spreads. Still
minutes; unlike one draw, it can actually answer.
⭐ **And "cannot decide" is not "cleared"** — the hold stands on the absence of a verdict,
not on a verdict against.

**② "IT PASSES ISOLATED" IS NOT AN EXONERATION WHEN PRODUCTION HAS THE CONDITION.** The
standard move on a full-suite-only failure is to run it alone, see green, and close. ⛔ Here
that is backwards: full-suite-only means the regression is **conditional on store churn** —
**and production HAS store churn** (compaction, restarts, concurrent workers). ⇒ Isolated-pass
reads as *"conditional on concurrent store pressure"*, **not** as *"not real."*
⭐ **Ask whether the condition you removed to get a clean run is a condition production also
lacks.** If production has it, isolation deleted the test, not the doubt.

⚠️ **And what the failing test NAME meant, which reframed the whole thing:** *"the DENY path's
OFFERED work is bounded"* is not a performance nicety — it is the **bounded-work invariant on
the deny path**, i.e. the property that stops a denial from becoming a DoS surface. **A guard
whose name states an invariant is not reporting slowness; it is reporting the invariant
degrading.** ⇒ Read the assertion's name before classifying its failure.
⚠️ Still open at time of writing: whether this is a genuine regression or the sequential-arm
**trend confound** above. Both readings remain live, and the baseline-twice test separates them.

⭐ The mechanism, invisible in the diff: swapping `rename` for a hard link left the temp as a
**second directory entry** for the whole read-back, widening the window for a concurrent
recursive walk to hit an entry appearing mid-walk. **A change to how long a file EXISTS is a
change to TIMING**, and reaches every recursive walk over that directory — teardown, sync
scan, compaction. **Nothing on a diff's surface says "timing."**

## 7e. ⭐ A brief can name the SYMPTOM correctly and still prescribe the WRONG REMEDY

2026-08-10, CX-q9sa. The brief got the offender list right, the count right (21 fires
reproduced exactly), and the two dangerous fixes forbidden by name. **The one line saying
what to actually DO was wrong.** §4 said *"each offender should delete only what it owns;
the normal fix is an isolated per-test directory"* — **unachievable, because the directory
was ALREADY isolated and unique.** The test had replaced the production-named `CommitStore`
child *inside* its own tmp dir and never stopped it before `rm_rf`, so the singleton was left
alive holding a deleted directory. The real fix is **teardown ORDERING**, not isolation.

⇒ **The remedy is the part the builder acts on.** Symptom-correct + remedy-wrong is more
dangerous than a vague brief, because everything checkable about it checks out.
⭐ The escape hatch is what saved it: the brief also said *"if an offender is legitimately
pointed at the real store, that is a FINDING."* **Always leave the builder a way to report
that the prescribed remedy doesn't fit** — it is the only clause that survives an author
who is wrong.

⚠️ Related and healthy: the author was suspicious of the premise, re-derived it
independently, and it **CONFIRMED the claim it doubted**. Report that outcome as loudly as a
refutation; a check that only gets mentioned when it overturns something is a biased
instrument.

### 7f. ⛔ OPEN — a dispatched Sol run CANNOT BE CORRECTED MID-FLIGHT

Sol is a `codex` process behind a shell script, not an agent with a mailbox. When the author
discovered §4 was wrong at ~52 min into the run, **there was no way to tell it.** The only
available move was to convert the correction into a **REVIEW CRITERION** ("did it fix by
ordering, or chase the bad hint?").

⇒ That downgrade is currently forced, and it is a real limit of the dispatch machinery rather
than a workflow preference. **Every brief therefore has to carry its own escape hatches up
front**, because there is no second chance to add one. Worth solving properly (a drop-file
the wrapper polls? a mid-run addendum channel?) — recorded here so it is not mistaken for
a thing nobody noticed.

## 7g. ⛔⛔ ONE GREEN RUN IS NOT A VERDICT FOR AN ORDER-DEPENDENT DEFECT

2026-08-10, CX-q9sa round 1. **Two agents independently made the same error and neither
caught it, because they made it the same way.** Sol reported mcp 156/0; commonplace
replicated the fix in its own tree, also got 156/0, and reported to me in writing that the
open question was **"settled"** and its worry **"measured false."** I relayed that as settled.

Measured properly across seeds:

| seed | result |
|---|---|
| 839791 | **156/9** — deterministic, re-ran and got 9 again |
| 111111 | 156/0 ⚠️ **the lucky one** |
| 222222 | **156/9** |

⭐ **The failure is ORDER-DEPENDENT** — `CatTest` only dies when it runs after the bd tests —
**which is the same class as the bug the ticket is about.** The teardown's
`terminate_child` + `delete_child` correctly stops the store before deleting (so the guard
stops firing) but `delete_child` **removes the child spec permanently**, leaving no
production-named `CommitStore` for the rest of the run. *The teardown stops the world and
never puts it back.*

⇒ **A single green is not evidence when the seed decides the order and the order decides the
outcome.** Acceptance now requires a **five-seed sweep per suite including the known-red
seeds, counts reported PER SEED**, never "all green."
⭐ And better than any suite result: **assert the PROPERTY directly** — show
`Process.whereis(CommitStore)` alive again with the ORIGINAL data_dir. **A green suite is
circumstantial; the property is not.**

### 7g-bis. ⭐ A FAIR SAMPLE FOR A LOAD-MARGINAL TEST MEANS MATCHED LOAD, NOT MATCHED SEED

2026-08-10, extending 7g rather than repeating it. Two only-in-Sol failures appeared at one
seed. **Both names had independent same-night priors as load-marginal**, each with isolation
evidence: one had already been read as *"pre-existing, EARNED rather than asserted"* in a
different ticket's blast radius; the other is a ratio guard that is **load-sensitive by
construction**.

⛔ **The trap in the pre-commitment's second branch:** if a re-run of the baseline shows
neither name, that is **NOT** evidence the failures belong to the change. **It is evidence the
sample was too small for a test whose failure is LOAD-CONDITIONED.** Seed-matching controls
for *order*; it does not control for *saturation*, and a load-marginal test passes cleanly in
a quiet re-run precisely because the run is quiet.

⇒ **Match the variable the failure is conditioned on.** Order-dependent ⇒ multi-seed.
Load-conditioned ⇒ **matched load**, which a repeat run at the same seed does not provide.

⛔⛔ **THE THIRD POSSIBILITY BOTH READINGS MISSED — and my first version of this entry got it
WRONG, so it is corrected here rather than quietly edited.**

**What I wrote (8d7980f), now RETRACTED:** *"the change itself can be the load"* — Sol's fix
adds teardown work in 13 more files, so a heavier suite trips a timing guard.
⛔ **It does not follow, because that guard is SELF-BASELINED.** Its own moduledoc: *"an
absolute millisecond budget on shared CI hardware is a coin flip… the baseline is measured IN
THIS RUN, on THIS machine, with the audit wiring detached, and the comparison is a ratio."*
⇒ **A heavier suite raises BOTH arms**, so the ratio is robust to "the suite does more work."
⚠️ The claim was asserted by someone who **had not read the test** — and retracted by them
minutes later, after reading it. *(Same act it had praised commonplace for refusing, six
minutes earlier. Nobody is immune to this one.)*

⭐ **WHAT SURVIVES IS NARROWER AND BETTER: added work can add VARIANCE rather than LOAD.**
p99 over 200 samples is effectively an **outlier detector** (the 2nd-worst sample), so **one**
`CommitStore` restart pause landing in the with-audit arm and not the baseline arm blows the
p99 ratio while p50 stays healthy. Stop+restart in 13 more files is precisely a variance
source.
⇒ **The deciding read needs NO new run — it is already in the failure output: did p50 fail,
or p99, or both?** p99-only ⇒ variance, and the guard's fragility is its **sample count**, not
its calibration (fix: more samples or a trimmed statistic, *not* a bigger ratio).

**MEASURED:** baseline p50 798µs / p99 3729µs · with-audit p50 3943µs / p99 49082µs ·
**ratios p50 4.941, p99 13.162** against a limit of 3.0. **p50 failed**, so it is not the
variance reading.

⛔⛔ **AND THAT DICHOTOMY WAS ALSO INCOMPLETE — a third branch, and it is the likeliest:
SELF-BASELINING CANCELS A CONSTANT OFFSET, NOT A TREND.** The two arms are measured
**sequentially** — baseline first, with-audit second — so **if machine load RISES DURING THE
RUN, the second arm is systematically penalised and BOTH ratios inflate with no regression
anywhere.** ⚠️ And the added teardown makes precisely that more likely: 13 more store
stop/restarts changes the suite's load profile **over** the run rather than holding it
constant, which is the one thing an in-run baseline cannot subtract.
⇒ **Both-failing is consistent with a real regression AND with a trend confound.**

⭐ **THE SEPARATING TEST IS CHEAP AND STRUCTURAL: MEASURE THE BASELINE TWICE**, once before
the with-audit arm and once after. `baseline_after ≈ baseline_before` ⇒ the machine was
stable and the ratio means what it says. `baseline_after > baseline_before` ⇒ load trended,
the comparison is confounded, and the guard needs **interleaved or alternating arms** rather
than sequential ones.

⭐⭐ **RESOLVED — AND THE CONTROL WAS ALREADY IN THE OUTPUT. NOBODY LOOKED BEFORE THEORISING.**
The same test, same run, same sequential structure, **ALLOW path**: baseline p50 18638µs →
with-audit p50 **16096µs**, **ratio 0.864**. ⇒ **The second-measured arm was FASTER.** A
rising-load trend penalises *every* second-measured arm; this one it **rewarded**. So a
machine trend cannot produce 0.864 in one arm and 4.941 in another **within one run**, and the
DENY-offered regression is **path-specific**. ⇒ The baseline-twice test was unnecessary here:
**the ALLOW arm already IS the second baseline, embedded and free.**

⛔ **THE LESSON IS BIGGER THAN THE RESULT: before designing a new experiment, check whether
the output you already hold contains a control.** Three of us proposed mechanisms and a new
run; the discriminating datum was sitting in the same failure block the whole time. *(A third
arm in that block: ratio p50 2.009 / p99 2.995 — passing, but pressed right against the 3.0
limit. Its own quiet finding.)*

⚠️ **What remains open, stated honestly:** the DENY-offered path is 5× its own in-run baseline
**on that branch**. That is *not* the same claim as *"the branch's changes caused it"* — there
is **no matched observation on main**, and the mechanism is not obvious, since test-file
teardowns should not touch that path at all.
⚠️ That is a change to the **TEST**, not to the branch under review — and it is the guard law
again: **bind the check to the property** (does the audit wiring cost more?) rather than to an
arrangement a moving machine can fake.
⚠️ **Note the direction:** this correction makes a **regression MORE likely**, not less — it
cuts against the merge. *A retraction that only ever loosens the gate is a retraction worth
distrusting.*

⭐ **"Flaky" is a terminal label that ends inquiry; "load-conditioned, and here is what added
the load" is a hypothesis with a next step.** That much stands — but note that the first
hypothesis with a next step was still WRONG, and only reading the test settled it.

⭐⭐ **CONFIRMED BY THE RUN THAT FOLLOWED, AND THE ORDER MATTERS: the correction was issued
BEFORE the data landed.** Main re-run at seed 202 → **3 failures, NEITHER disputed name
present.** Under the original pre-commitment that reads as *"they're Sol's"* — **which would
have been wrong.** ⇒ This is a **pre-registered prediction that paid**, not a rule fitted to
an outcome afterwards, which is the only version of this evidence worth anything.
⚠️ And plan's own caveat on its own priors, which is the discipline worth copying: **two
priors agreeing is weaker evidence than one measurement**, and converging on "both are flaky"
because it *fits* is the primed-plausible error. A prior raises probability; the discriminator
decides.

⚠️ **My own failure here was relaying "settled" without asking how many runs it rested on.**
7d said green-isolated is not "not mine"; this is its twin — **green-once is not "fixed."**
When someone reports a worry as *measured false*, the follow-up question is **"across how
many seeds?"**, and it costs one sentence.

## 7h. ⭐ A PRE-COMMITMENT THAT NAMES THE WRONG AXIS ONLY ROUTES CORRECTLY BY LUCK

2026-08-10. Pre-registering the reading before the number lands is the technique that stops a
result being absorbed on arrival, and it worked twice tonight. But commonplace-plan recorded
a failure of it **against itself**, and the failure is more instructive than the successes.

It pre-committed a **binary** on the yelixer coverage question:
*"≈390 real ⇒ proceed to CI"* vs *"thousands genuinely not running ⇒ CI waits."*
⇒ **Reality had a third state:** the tests all run **AND** 5,220 of them parse their expected
map/array and **discard it**. ⭐ The pre-commitment named **TEST COUNT**; the live axis was
**ASSERTION DEPTH**.

⚠️ **The routing still came out right — and that is the point.** CI would honestly report what
runs, so no false green. But it landed correctly **by luck**, not because the pre-commitment
covered the case.

⇒ **When pre-registering a reading, ask what OTHER axis could carry the answer** — and leave
an explicit *"neither branch fits"* arm.

⭐ **AND ASK WHICH WAY IT FAILS, BEFORE USING IT.** A second pre-commitment tonight was
mis-specified but failed toward the **recoverable** branch — an extra round trip rather than a
shipped regression. ⚠️ Its author refused the credit, correctly: *"I didn't DESIGN it that
way, I just happened to write the conservative branch."* **"Wrong in the safe direction" is a
weaker defence than it sounds when the safety was accidental.**
⇒ **A pre-commitment should be checked for which way it fails BEFORE it is used, not after** —
which is the same question as *"what states does this rule fail to distinguish"*, asked about
**consequences** instead of **inputs**. A binary with no escape hatch is the same defect as
a brief with no "the remedy doesn't fit is a FINDING" clause: it forces an arriving result
into one of two boxes it may not belong in.

### 7i. ⛔ EXCLUDING AN UNMEASURED SUITE TO OBTAIN GREEN IS THE FALSE-GREEN CLASS WITH A RATIONALE ATTACHED

Same ruling, and it generalises past CI. Faced with a suite that is rc=2 in a fresh tree, the
options were *run the oracle* or *exclude it deliberately*. ⭐ **plan's ordering IS the
ruling: never choose exclusion before MEASURING whether the excluded thing passes.**
If it passes ⇒ assert on it, since the oracle is already installed and already paid for.
If it fails ⇒ **that is a finding**, and any exclusion is loud and ticketed, never silent.
⚠️ A deliberate exclusion and a convenient one look identical in the config; only the
measurement that preceded it tells them apart.

## 7j. ⚠️ OPERATIONAL — UMBRELLA TEST RUNS ARE MUTUALLY EXCLUSIVE ON THIS BOX

`commonplace_web`'s endpoint binds **:4002**, so two concurrent `mix test` runs collide. ⛔ The
loser dies with `:eaddrinuse`, **rc=1, EMPTY summary, ZERO failure names** — which looks like
a catastrophic failure and is a port conflict. ⇒ *"Blocked" and "not there" share an exit
code*, in the instrument this fleet uses most.

**Rules adopted:** run umbrella suites **sequentially, never in parallel**; treat
**rc=1-with-no-summary as ENVIRONMENT** until proven otherwise.

⭐ **WHY THIS IS A DISPATCH CONCERN AND NOT ONLY A TEST CONCERN — it is mine.** A Sol run and a
commonplace suite run are two umbrella test runs on one box. On 2026-08-10 a yelixer
measurement overlapped Sol's round 3, and **two of the four failures Sol reported as blocking
were TIMEOUTS — which is exactly what contention produces.** ⇒ Sol dispatch timing can
manufacture the failures the review then has to explain.
⚠️ Note this interacts with sol-nudge's deliberate *"dispatch anyway, the message queues"*
behaviour: the message queuing is still right, because **commonplace chooses when to launch**
and can sequence. But **when a review is puzzling over timeouts, ask what else was running**
before anyone theorises about the code.

⭐⭐ **SERIALIZATION CONVERTS ORDERING FROM A PREFERENCE INTO A SCHEDULE — and my dispatches
insert into that schedule.** When runs can overlap, order barely matters and choosing wrong
costs nothing. When a shared resource forces one at a time, **order IS the plan**, and a
suboptimal choice stops being suboptimal and becomes *expensive*. Observed: four umbrella runs
stacked behind :4002 with the **decisive one-minute matched datum LAST**, behind runs whose
interpretation depended on it — two of which it might have made unnecessary.
⇒ **Rank a stacked set the way a queue is ranked: highest information per unit cost first.**
⇒ **My consequence:** a Sol dispatch does not merely add load, it **takes a slot** in a
serialized queue someone is waiting on. Two distinct costs — *corruption* (below) and *delay*.

⭐ **CONFIRMED INSTANCE, and it makes this concrete rather than hypothetical:** one arm of
`AuditChokePerfTest` **passes at p99 = 2.995 against a limit of 3.0** — 0.005 from red, one
busy machine from failing on any given run, and **green every other time**. That is the exact
profile of something that never gets attributed. ⇒ **A run I cause can flip it**, so some
fraction of the "non-deterministic main" set is *load I introduced*. ⚠️ It is currently
invisible **because it passes** — correct-and-unread, the same law as a gate that declines
150k times and is never read.

## 7k. ⭐⭐ HAVING THE ANSWER AND FILING IT AS A SYMPTOM

**Twice in one night, same shape, different people.** Not a failure to *find* evidence — a
failure to *read what was already written* as an answer.

| Instance | What was recorded | What it actually was |
|---|---|---|
| CX-8wh1 fixtures | a revert message describing the breakage: *"a workspace that has been through init but has no identity — **a state real nodes never occupy**"* | **the ruling itself** — there is no context in which the modelled state is real, so the fixtures are entrenchment, not intent |
| CX-q9sa round 2 | *"one unrelated trust failure, load-sensitive"* — `AuditChokePerfTest`, **p50 ratio 3.213** | **the same signature, one round earlier.** Round 3 measured p50 **4.941** (baseline p50 798µs vs with-audit 3943µs). A systematic slowdown, seen twice and joined once. |

⇒ **The remedy in both cases was a SECOND READER, not a new measurement.** The author wrote
the decisive sentence and moved past it; someone else read the same words as a verdict.
⚠️ **A dismissive label is what closes the file** — *"unrelated"*, *"load-sensitive"*,
*"flaky"*, *"symptom"*. ⭐ **Before filing a finding under a label that ends inquiry, ask
whether the sentence you just wrote answers an open question elsewhere.**

### 7k-bis. ⛔ CHASE THE RETRACTION THAT TIGHTENS THE GATE

commonplace's own admission, and it generalises: *"I had been reading retractions as noise to
route around."* ⇒ **A retraction that makes a REGRESSION MORE LIKELY is the one to chase
hardest** — it cuts against the outcome its author probably wants. Tonight the self-baselined
correction did exactly that, and following it produced the p50 measurement that **held the
merge**. *A correction that only ever loosens the gate is the one to distrust.*

## 7l. ⚠️ A FAILURE COUNT IS PER TEST *NAME*, NOT PER ASSERTION (CX-dsqc)

A test file is a **container for independent assertions with different reliabilities**, and
**every tool keys on the container** — CI, `bin/cp-ci-failures`, and every summary I wrote
tonight. ⇒ *"AuditChokePerfTest failed 3 times"* cannot distinguish a **systematic
4.941-vs-3.0 regression** from a **2.995-vs-3.0 coin flip** living in the same file. ⭐ **No
ranking discipline downstream can recover what the container threw away.** Quote such counts
with the caveat attached, or don't quote them.

⛔ **AND THE ACCEPTANCE ON THE FIX FORBIDS THE OBVIOUS REPAIR, correctly: do not recalibrate
the degrading arm's budget.** That arm is currently reporting a possibly-real invariant
degradation, and "recalibrating" it would **erase an alarm while claiming to fix a flake** —
which is exactly how a correct alarm gets dismissed a *third* time. Load-bearing acceptance is
**"each arm reported under its own identity, demonstrated by a run where ONE arm fails and the
report names WHICH"**; calibration can follow.

⚠️ *Filed after I nearly edited a `cp-ci-failures` line into the wrong file — the reference I
"remembered" was in a message I had sent, not in this document. One `grep` cost nothing and
caught it. **Check that the thing you are about to correct exists where you think it does.***

## 7m. ⭐⭐ BEFORE TREATING FAILURES AS A POOL, RUN THE TOP MEMBER ALONE

**The single cheapest check of the night, available the entire time, and none of the three of
us suggested it.** After a night of statistical reasoning about a "flaky pool" of ≥8 tests —
seeds, distributions, matched methods, variance-vs-load — the answer was:

> `TrustConfigFailClosedTest` — present in **all three** seeds while the rest of the set
> churned; `cp-ci-failures` ranks it **#1 with 12 occurrences**. Isolated: **1 failure,
> deterministically, in 0.4 SECONDS.**

⛔ **THE POOL WAS NEVER UNIFORMLY FLAKY.** It contained a **stable red** hiding inside a
population everyone had agreed was noise. ⇒ **A heterogeneous set given a homogeneous label is
worse than an unlabelled one, because the label licenses not looking.**

⇒ **PROCEDURE, not insight: before treating a set of failures as a pool, RUN ITS MOST FREQUENT
MEMBER ALONE.** Seconds. It either falls out of the pool or earns its place in it.
⚠️ Note what made it invisible: the members that *were* flaky validated the label, and a label
that is right about most of its members is the hardest kind to doubt.

⭐ **And the finding under it was a production defect, not a test bug:** the node's self-trust
fold sits in a `with` whose `else` is **silent**, so a node that cannot source its own public
key **silently stops trusting its own commits** under strict mode. ⚠️ **The function's comment
says the degraded case is "visible, not silent."** ⇒ **A comment asserting a property the code
does not have is evidence of INTENT, and intent is a better lead than a symptom** — it tells
you what someone meant to build. *(Second fixture of this exact class; treat as a population,
not an instance.)*

## 7n. ⭐⭐ THE QUESTION WAS MALFORMED — "is there a SECOND mechanism?" presupposed ONE

The row asked whether a **second** mechanism existed behind an unstable failure set. Isolating
every member answered something better: **there is no single second mechanism. There are at
least THREE, and the word "flaky" was carrying all of them.**

| Class | Evidence | What it needs |
|---|---|---|
| **STABLE RED** — not flaky at all | `TrustConfigFailClosed` fails in **0.4s** alone | a fix |
| **INTERACTION-DEPENDENT** — green alone, red together | `DocBuilder` 22/0 isolated, `Green.Bursar` 44/0 isolated | an **attribution METHOD**, before any fix |
| **INSTRUMENT NOISE** | `AuditChokePerf` passes alone; spread 2.815–4.941 vs limit 3.0 | a quieter measurement, *never* a looser threshold |

⛔⛔ **SUPERSEDED — CLASSES 2 AND 3 ARE ONE MECHANISM, and I had a member in the wrong class.**
An exhaustive read of the failure MODE of every failure instance across all 8 round-3 logs:
**all 16 non-constant failures are TIME-BUDGET crossings** — 14× the inherited ExUnit 60s
default, 1× a `Task.await` 10s, 1× the ratio guard. **Zero behavioural assertions failed.**
⇒ *Tests whose wall-clock cost sits near a fixed budget, crossed stochastically with load.*
**The "neighbour" that reddens a victim is not a test — it is the LOAD any neighbour set
generates**, which is why set, population and order bisections could never converge.
⚠️ **And my table above was wrong about `BotPresenceCert`:** filed as class-1 stable red, it
actually failed **4 of 8 runs, always by timeout**. Two members are worse than flaky-looking —
one dies in FIXTURE BUILD before reaching its assertion, and `BotPresenceCert`'s race
assertion **has never been observed firing at all**; its loop simply exceeds 60s.

⇒ **THREE PIECES OF WORK WITH THREE DIFFERENT ACCEPTANCES.** ⛔ *A fix for one is not progress
on the others, and any plan treating them as one queue item will fix the cheapest and report
the pool as handled.*

⭐ **A QUESTION THAT NAMES A CARDINALITY SMUGGLES IN AN ASSUMPTION.** *"What is the second
mechanism"* cannot return "three"; it can only return a wrong single answer or nothing.
⇒ **Ask "how many, and of what kinds?" — the enumerating form — whenever a set has been
given one label.**

⛔⛔ **AND THE LABEL DOES NOT HAVE TO BE WRONG TO DO THE DAMAGE — "flaky" was TRUE of four of
the six members.** ⭐ **A mostly-accurate label is the most dangerous kind, because the
counterexamples sit inside the very set the label tells you not to open.** A label that were
simply false would be challenged; one that fits most of its members earns the trust that
protects the rest from inspection.

⚠️ **AND THE PRE-COMMITMENT IS WHAT MADE CLASS 2 VISIBLE.** Two members came back **GREEN
alone**, which under the lazy reading is exoneration. Because *isolated-pass = "needs
neighbours", not "not real"* was written down **before** the runs, a green result became a
**finding** instead of an absence. *(The first success of the pool rule rested on a member
appearing in 4/4 samples; these were 2/4, so the signature was weaker and the pass branch was
doing all the work.)*

## 7o. ⭐⭐ A COMPACTION DESTROYS COMMITMENTS, NOT KNOWLEDGE

The best statement of why durable state matters, and it is not the obvious one:

> **Facts survive in tickets because they can be RE-DERIVED. A pre-registered reading CANNOT
> be re-derived after the result exists — because by then you know the answer, and any
> reconstruction is contaminated by it.**

⇒ So the thing to write down before a context boundary is **not what you know** (recoverable)
but **what you have COMMITTED TO** — what each possible outcome will mean, decided while the
answer is still unknown.

⚠️ **The specific gap:** a brief holds the **ACCEPTANCE** (what the builder must produce); the
**READING** (what each outcome means for what *I* do next) is a different document, and only
the second one is unrecoverable. A dispatch-then-compact sequence loses exactly the reading.
⭐ Closed here by writing the four outcomes down **while the run was still in flight**,
including what **no** outcome licenses.

⛔ **The branch that most needs writing is the one a tired reader converts into progress:**
*"it didn't reproduce"* reads as *"the problem went away"* and licenses bisecting anyway.
**A bisection run on an unreproducible failure produces a CONFIDENT WRONG ANSWER DRESSED IN
METHOD** — the tidiest possible artifact and entirely false. Same shape as every dead theory
today, except it would arrive wearing a procedure.

⚠️ *And my own miss in the same exchange: I read "3 shells running" as its measurements and
warned against compacting mid-flight. They were **Sol's process tree** — nothing of its own was
running, so the safe window was NOW, not later. I inferred a fact that was one command away
from being checked.*

## 7p. ⛔⛔ RETRACTED — "INVOCATION FORM MATTERS" WAS ONE DRAW PER ARM

⛔ **Status: NOT SUPPORTED. I marked this CONFIRMED and I was wrong to.** Retracted within the
hour, on a third measurement.

| Invocation | Seed | Result |
|---|---|---|
| `mix test <directory>` | 303 | **5 failures** |
| explicit 370-file list | 303 | **1 failure** |
| ⭐ `mix test <directory>` **again** | 303 | **victim GREEN** |

⇒ **TWO DIR-FORM DRAWS, DIFFERENT OUTCOMES.** The directory arm is *itself* a wide
distribution, so one sample per arm cannot distinguish *"invocation form matters"* from
*"both arms are noisy and I drew high once and low once."*

⛔⛔ **MY FAILURE, PLAINLY: I DID NOT ASK HOW MANY DRAWS PER ARM.** That is the same question
7g records me failing to ask — *"across how many seeds?"* — and the same shape as 7d-bis's
retracted two-point trend. **Third time in one day, and this time I had already written both
rules down.** ⇒ A rule filed is not a rule applied; I applied it to claims I was *suspicious*
of and not to one I *liked*.

⭐⭐ **THE SHARPEST FORM OF THAT, and it is the line to keep: A RULE APPLIED ASYMMETRICALLY IS
NOT A RULE — IT IS A PREFERENCE WITH A CITATION.** The rule was about the **shape of the
evidence**, and shape does not care which direction you hope the answer points. ⚠️ Both of us
committed it on the same problem within hours, each while writing the rule *into a brief for
someone else*.

⚠️ **AND THE FALSIFIER WAS AIMED AT THE WRONG HYPOTHESIS**, which is the subtlest part: the
pre-committed branch tested *"does dir-form reproduce at all?"* — not *"does invocation form
EXPLAIN the difference?"* ⭐ **A falsifier aimed at the wrong claim is worse than none, because
it produces the FEELING of having tested.** *(I cited that pre-commitment as what made the
confirmation "worth anything." It was worth nothing to the claim I was making.)*

⚠️ **IT PROPAGATED, which is the cost of my part:** I upgraded my entry to CONFIRMED, and the
next round's brief opened with 5-vs-1 as established fact — so a builder executed against an
unearned premise. **It refused for an unrelated and correct reason; that is luck, not a
control.**

✅ **What still stands on its own merits:** the *no-regret* clause — **same seed AND same
invocation form on both arms** — costs nothing and is correct regardless, which is exactly why
adopting it before confirmation was right. **The clause survives; the finding that motivated
it does not.**

A bisection returned a **fifth** outcome nobody had pre-registered: the failure **reproduces
under one INVOCATION FORM and not another** — `mix test <directory>` reproduces at seed 303,
while a **count-equivalent explicit 370-file list** at the same seed does not.

⭐ **The proposed mechanism (untested):** a seed shuffles a *starting order*, and a directory
glob and `find | sort` do not produce the same starting order. ⇒ **`--seed 303` is not one
order; it is one order PER INVOCATION FORM.**

⚠️ **Why this lands on ME:** *"same-seed set comparison"* is a standing clause I put in
briefs. If the hypothesis holds, that clause is **under-specified** — two arms can share a
seed and still differ in order.
⭐ **SHARPENING, adopted before the confirmation and now vindicated:** require **SAME SEED AND
SAME INVOCATION FORM** on both arms. *(The comparisons run so far happen to satisfy it — both
arms used the dir form — but by **habit, not design**. Nobody reasoned about it, and the next
person inherits no habit, which is exactly why it had to be written down.)*

⭐⭐ **AND THE VALID METHOD FALLS OUT OF THE FINDING: shrink the population while PRESERVING
the invocation form** — temporarily MOVE files out of the directory and keep running
`mix test <directory> --seed N`. **Invocation constant, set variable, bisection valid again.**
⚠️ With two guards: **restore the moved files via a trap**, and **report the TEST COUNT per
step** so a silently-empty selection cannot masquerade as green — the same denominator trap
that voided a whole round earlier the same day.

⛔ **What was deliberately NOT decided: whether the difference is purely ORDER or also
concurrency grouping** (async batching / `max_cases`). Recorded as **UNKNOWN and not guessed** —
several plausible-and-wrong mechanisms died on this exact problem within twelve hours.

⛔ **AND THE DISTINCTION THAT DECIDES WHAT HAPPENS NEXT**, which is why filing this under the
nearest label would have been costly: branch 3 ("no reproducer") says **the phenomenon is
gone** — go re-measure. This says **the phenomenon is real and the instrument is blind on this
axis**, because the variable is not a member of any file set. ⇒ **A bisection over sets cannot
find a variable that is not in a set**, so bisecting anyway would have converged on an innocent
file *with a clean halving trace* — the wrong artifact, arriving wearing a method.

## 7q. ⭐⭐ PROTECT THE BEHAVIOUR YOU NEED TO SURVIVE — say so in the brief

A builder was asked to bisect, **discovered the method could not work**, and returned
**UNKNOWN with the reason** instead of a halving trace. That refusal was the most valuable
output of the day.

⇒ So round 2's brief **opens by stating round 1 was a SUCCESS**, and that is not politeness —
it is load-bearing:

> ⛔ **If a third round reads as "you failed twice", the next agent facing an impossible
> method produces a bisection instead of a refusal** — and hands back a clean halving trace
> pointing at an innocent file.

⭐ **A refusal is a behaviour with an incentive attached, and repeated dispatch on the same
ticket reads as dissatisfaction whether or not you mean it.** ⇒ **Name the behaviour you are
protecting, in the artifact, or the next iteration quietly trains it out.** This is the
dispatcher's version of *the constraint has to live where the action happens*.

### 7q-bis. ⭐ A KNOWN-CONSTANT FAILURE IS A FREE CONTROL FOR POPULATION DRIFT

The same brief reframes an **out-of-scope, always-red test** as an instrument: it must stay
red for the whole run, and **if it ever goes green, the population changed in a way the
operator did not intend.**

⇒ **Turning a nuisance failure into a drift detector is the cheapest control available** — it
costs nothing, it is already running, and it catches the exact failure mode (a selection
silently collapsing) that a per-step count catches only numerically. ⚠️ Pairs with: report the
**test count at every step**, since a population shrinking toward zero yields a **vacuous
green**.

## 7r. ⭐⭐ ONE LAW, THREE DISGUISES — consolidated, because filing by symptom is the same container error

**This file committed tonight's own container error.** The same law is written up three times
under three symptom-names, so no reader recognises them as one thing:

| Filed as | Disguise | Entry |
|---|---|---|
| *"two points are always monotone"* | a **trend** | 7d-bis |
| *"one seed is not a sample"* | a **subset comparison** | 7g |
| *"one draw per arm"* | a **factor comparison** | 7p |

⇒ **ONE TRIGGER COVERS ALL THREE, and it keys on the ACT rather than the symptom:**

> ⭐ **BEFORE ATTRIBUTING A DIFFERENCE BETWEEN TWO CONDITIONS, ASK HOW MANY DRAWS PER ARM.
> One draw means you have a HYPOTHESIS, not a finding.**

⚠️ **Rules filed by symptom do not fire** — you only recognise the symptom you already met.
Three of us hit this law in one day *with the rules already written in our own files*.

### 7r-bis. ⛔ PRE-REGISTRATION PROTECTS THE TIMING, NOT THE TARGETING

We spent the night treating *pre-registered* as *trustworthy*. It only rules out **post-hoc
rationalisation**; it says nothing about whether the falsifier is **aimed at the claim you are
actually making**. ⇒ **A falsifier pointed at the wrong hypothesis is worse than none, because
it produces the feeling of having tested while leaving the real claim untouched.**

⭐ **THE MECHANICAL TEST:** read your falsifier and ask —

> **"If this comes out the other way, WHICH SENTENCE DO I HAVE TO DELETE?"**
> **If you cannot name the sentence, it is not aimed at your claim.**

### 7r-ter. ✅ THE NO-REGRET CLAUSE SURVIVED ITS OWN MOTIVATING FINDING

⚠️ **Restated standalone so nobody later removes it as "part of the retracted thing":**
**run both arms with the SAME SEED AND THE SAME INVOCATION FORM.** Its basis is that it
**costs nothing and removes a variable** — it never depended on the invocation-form finding
being true, and that finding is retracted while this stands.

⭐⭐ **AND THE BASIS IS A PRIORI, NOT EMPIRICAL, which is what makes it sturdy:** *a seed does
not define an order — it SHUFFLES A STARTING ORDER, and a directory glob and an explicit file
list are different inputs, so there is no reason to expect the same permutation.* ⇒ **Two arms
differing in invocation form differ in an UNCONTROLLED VARIABLE, whether or not that variable
turns out to matter.**
⛔ **Note what it is NOT:** it is *not* the retracted claim that invocation form **has been
shown** to change outcomes. It is the weaker, sturdier statement that **an uncontrolled
variable should not be left uncontrolled in an attribution** — which needs no measurement at
all, and therefore cannot be taken down by one.

⭐⭐ **AND THE EMPIRICAL JUSTIFICATION WAS NOT MERELY WEAKER — IT WAS CIRCULAR.** To establish
*"invocation form matters"* you need a multi-draw comparison, **and the uncontrolled variable
is what confounds that very comparison.** ⇒ You would have needed **the control in place to
earn the fact that justifies the control.** So the structural argument is not the better of
two available arguments; it is **the only non-circular one**.

⇒ **GENERALISES: a control justified by a MEASUREMENT inherits that measurement's fragility
AND its confounds; a control justified by the STRUCTURE of the situation costs nothing to
defend and survives every finding.**

⇒ **PRACTICAL FORM: when a control and a finding are adopted together, FILE THE CONTROL
SEPARATELY WITH ITS OWN BASIS** — otherwise whoever tidies up the retracted finding takes the
control with it.

⇒ **General form: adopt a no-regret change BEFORE its motivating finding is confirmed, and
when the finding falls, check separately whether the change stands on its own.** Adopting it
early was the right *order*, not luck.

## 7s. ⛔⛔ THE SET COMPARISON IS UNDERPOWERED — and the class was named after an unestablished mechanism

**The distribution finally got measured.** Same tree, same seed 303, **same invocation form**,
repeated: **5 · 3 · 4 · 1 failures** (plus a fifth run with the victim green).

⇒ ⛔ **SEED + INVOCATION FORM FIX THE TEST ORDER, AND THE OUTCOME STILL VARIES. THE VARIABLE
IS NOT ORDER.**

**① The invocation claim is now POSITIVELY DEAD, not merely unsupported.** The file-list run's
1 failure sits **inside** the dir-form distribution — one dir-form run also gave exactly 1.
Nothing requires an invocation explanation at all.

**② ⛔ THE CLASS NAME WAS A MECHANISM CLAIM IN DISGUISE.** *"Class 2 = interaction/
order-dependent"* was named after a mechanism nobody had established — **and the name then
shaped two rounds of method**, file-set bisection and then population bisection, *both
structurally incapable of finding a variable that is neither the set nor the order.*
⭐ **Naming a class after a suspected cause spends the next two rounds inside that cause.**
Name classes after the OBSERVATION (*"green alone, red together"*), never the explanation.

**③ ⚠️ AND IT DOWNGRADES AN INSTRUMENT I HAVE BEEN PUTTING IN BRIEFS ALL DAY.** A
**single-run same-seed SET COMPARISON is weaker than I thought**: a 1-vs-4 difference between
two arms sits **inside the noise**, so it **can miss a real regression**.
⇒ It remains the best available instrument and the merges that used it used it correctly —
but it needs **REPEATED RUNS PER ARM to have power**. ⭐ That is the *how many draws per arm*
trigger (7r) arriving from a **third** direction: first as a trend, then as a factor
comparison, now as **the power of a comparison I was already recommending**.

⚠️ **Consequence I must carry honestly: every merge verified this way tonight rests on a
weaker instrument than I described when relaying it.** Nothing is known to be wrong; the
confidence was overstated, not the conclusion.

## 7t. ⭐⭐ A HEARTBEAT PROVES THE PROCESS LIVES, NOT THAT WORK ADVANCES

A design doc specified **lease renewal driven by a worker heartbeat**. ⛔ commonplace-plan's
standing ruling: **renewal requires a PROGRESS WITNESS — a new trace since the last renewal —
never a heartbeat.** Otherwise a **healthy zombie** holds a lease forever: the process is up,
the work is dead, and custody never returns to the frontier.

⚠️ **This lands on MY machinery, not just theirs.** `.heartbeat-sol-nudge` /
`.heartbeat-epic-nudge` prove **the loop RAN**. They do not prove a dispatch was sent, a
decline was correct, or anything reached a worker. ⇒ Same family as the marker that records
*gate passed* rather than *nudge sent* (7-series), and the same law as **verify by effect, not
by existence** — arriving this time as a *renewal* condition rather than a check.

⭐ **General form: when something renews, extends, or re-authorises on a signal, ask whether
that signal is evidence of LIFE or evidence of PROGRESS.** Life is cheap to emit and a stalled
worker emits it perfectly.

### 7t-bis. ⭐ AN AUDIT OF "WHAT THE SYSTEM ALREADY PROVIDES" MUST DATE THE SNAPSHOT

Two independent design docs both rest on the **same stale bullet** — `bd` tickets, which have
been a frozen archive since the tix migration. One says *"TTL on `bd_claim`"*, the other
*"dependency-aware `bd` tickets"*. ⇒ **They share a WORLDVIEW DATE, not merely an error.**
⭐ So the audit's job is not only to grade each bullet SHIPPED / PARTIAL / STALE — it is to
**date the snapshot the document is written against**, because that predicts which *other*
bullets are stale without checking each one.

⚠️ And the inversion worth keeping: the audit is **not a precondition for adopting a
roadmap — it IS the roadmap's use**, once the roadmap is understood as a lens for finding gaps
rather than a queue of features.

## 7u. ⭐⭐ WHEN TWO READINGS AGREE UNTIL A DISTANT DIVERGENCE, PUBLISH WITH A NAMED FLIP POINT — don't block on the question

jes gave **two explicit priority instructions** hours apart and never ranked them against each
other. I flagged the conflict and offered plan the choice: rule, or ask him. ⭐ It did neither
of the obvious things — it **published a resolution with the divergence point named and a
one-word reversal**.

**The test it applied, which is the reusable part:**
> **Do the two readings produce DIFFERENT ACTION right now?** If not, when do they first
> diverge? If that moment is hours away, **publish the resolution, name the divergence, and
> make the flip cheap.**

⇒ Its reasoning: *"If he flips it, we lose nothing; if I'd asked, we'd have gained nothing."*
A published resolution with a named flip point gives the decider **the same decision power as
a question** — **without blocking the work in the meantime.**

⚠️ **This sharpens "ask once, then act" rather than replacing it.** Asking is right when the
answer changes what you do NEXT. When both readings agree on the next action, a question buys
nothing and costs the interval. ⛔ And the honest failure mode to avoid: this only works if the
divergence is **named precisely** — an unnamed flip point is just a decision made quietly.

⭐ *Contributing fact from my seat that made the resolution possible: #1 was blocked on a
MEASUREMENT, not on attention — so the two instructions did not contend for the scarce
resource at all. **"They conflict" was true of the ranking and false of the schedule.***

## 7v. ⛔⛔ THE MOST EXPENSIVE INSTANCE OF "A RULE FILED IS NOT A RULE APPLIED"

**Three dispatched Sol rounds — file-set bisection, population bisection, a 2h40m
concurrency measurement — were settled in MINUTES by reading the failure MODE of failures
already sitting in logs we already had.**

⭐ **The answer: all 16 non-constant failures were TIME-BUDGET crossings** (14× an inherited
60s ExUnit default, 1× a `Task.await`, 1× a ratio guard). **Zero behavioural assertions
failed.** Classes 2 and 3 collapse into one mechanism: *wall-clock cost sitting near a fixed
budget, crossed stochastically under load.* ⇒ The "neighbour" reddening a victim was never a
test — **it was the LOAD any neighbour set generates**, which is exactly why set, population
and order bisections could not converge.

⛔ **AND THE RULE WAS ALREADY ON FILE THE WHOLE TIME.** An existing discriminator said
*"check for fixed time budgets first."* It sat unapplied while three mechanism hunts ran.
⇒ **Fourth instance today of the same law** — and the most expensive, measured in hours of
dispatched compute rather than a wrong sentence.

⭐ **THE OPERATIONAL FORM, which is cheap enough that there is no excuse: BEFORE DESIGNING AN
EXPERIMENT, READ THE FAILURE MODE OF THE DATA YOU ALREADY HOLD.** Not the counts — the
**mode**: what kind of failure is each one? A timeout and an assertion failure are different
phenomena that a failure COUNT renders identical. *(Cf. the container law: a count erases the
distinction that would have answered the question.)*

⚠️ **Two members were worse than "flaky-looking", and only the mode-read revealed it:** one
dies in FIXTURE BUILD before reaching its assertion, and another's race assertion **has never
been observed firing** — its loop merely exceeds 60s. **Both had been reasoned about for hours
as if their assertions were the thing failing.**

## 8. Open — not near-misses, actual items awaiting a decision

- **`quota-guard.sh` is not on cron.** Two active entries: `watchdog-cron.sh`,
  `state-render-cron.sh`. Whatever it concluded, nobody received it.
- **Its 7d threshold keys on raw utilization (≥80%), not burn ratio** — it says
  SLOW_DOWN at 84% used / 89% elapsed where the ratio is 0.94 and healthy. Docs say
  90%, script says 80%. ⚠️ Not retuned: adjusting a guard so it stops disagreeing with
  you is how guards get talked out of firing. Awaiting jes.
