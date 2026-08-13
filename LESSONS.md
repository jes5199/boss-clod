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

## 7w. ⛔⛔ A QUEUE ROW'S READINESS IS A CLAIM ABOUT THE WORLD, AND IT AGES

**Three instances on 2026-08-10, two of them within three minutes of each other, in OPPOSITE
directions:**

| Row said | Reality | Cost |
|---|---|---|
| a trio "ranked, blocked" | **2 of 3 already merged** | an hour of ranking on a 12-hour-old description |
| **"2a proto-chit — DISPATCHABLE NOW"** | **built and merged the night before** (`a66fd9b`) | a Sol dispatch was **minutes** from rebuilding merged work |
| "CX-vvbh decision owed, ruling next" | **already discharged that morning** | a decision about to be re-derived when it was moot |

⛔⛔ **THE SECOND ONE IS MINE AND I HELD THE CONTRADICTING FACT.** I relayed *"2a is
dispatchable now"* **twice** — to the builder and to jes — while my own session state recorded
*"proto-chit step 1a MERGED"* from the previous night. ⇒ **Fifth instance today of a fact
filed and not applied.** What caught it was the builder running `grep` on the log **before
briefing**, not anything of mine.

⭐ **THE OPERATIONAL FORM, cheap enough to be unconditional: BEFORE RELAYING THAT ANYTHING IS
READY, DISPATCHABLE, OWED OR BLOCKED — ASK THE REPOSITORY, NOT THE ROW.** `git log`, `git
cat-file -e`, `merge-base --is-ancestor`. Seconds. ⚠️ The row is a **cached** claim; the repo
is the world. *A dispatcher relaying cached readiness is exactly the "confirm, don't inherit"
failure with a queue in the middle.*

⛔⛔ **AND THE THIRD INSTANCE FAILED A CHECK THAT WAS ACTUALLY PERFORMED — because it was the
WRONG SEARCH.** The owed row said *"gated on commonplace producing the schema; not yet
produced"*, and the check behind it was **"ask commonplace / grep the chat"**. ⇒ But the
schema had landed **in the REPO**, with the merge. **A repo artifact is found by `ls
docs/plans/`, not by asking its author.** The check ran, returned nothing, and **discriminated
nothing** — it searched where the artifact wasn't.

⭐ **So the rule needs its sharper half: THE CHECK MUST NAME THE SEARCH THAT WOULD ACTUALLY
FIND THE DELIVERABLE.** *"Did I check?"* is the wrong question; *"would my check have found it
if it existed?"* is the right one — which is the **positive control** demand, applied to a
readiness query instead of a grep pattern.

⭐ **AND IT FAILS IN BOTH DIRECTIONS, which is why "check before dispatch" is not enough:**
work that has LANDED makes a blocked row falsely blocked (wasted ranking), and work that has
landed also makes a ready row falsely ready (wasted build). ⚠️ **The optimistic direction is
the dangerous one** — a falsely-blocked row wastes thought, a falsely-ready row spends a
worker.

## 7x. ⭐⭐ THE SELF-MATCH TRAP HAS A STRUCTURAL FIX: PUT THE PATTERN IN A FILE

**An agent hit `pgrep -f` matching its own shell TWICE in one day** — the pattern sat in its
own command line, so the search found the searcher. Exit 144, its own command killed
mid-flight. Both times it re-derived the same remedy: *be careful, use `comm` + numeric pids.*
**Discipline. Which failed twice.**

⭐ **MY OWN LOOP RUNS THE SAME `pgrep -f` AND HAS NEVER SELF-MATCHED. The difference is not
care — it is LOCATION:**

| Form | Where the pattern lives | Self-match |
|---|---|---|
| `pgrep -f "codex exec"` typed inline | **in the shell's own argv** | ⛔ always possible |
| `pgrep -f '…'` inside a script file | **in a file; no process argv contains it** | ✅ impossible |

**Verified by effect, with a real run live:** my check returned exactly the codex wrapper and
child (`2887560 2887573`); my own shell (`2889271`) was **not** in the results, and my argv
contains no trace of the pattern.

⇒ ⭐⭐ **THIS IS THE FIRST REAL ANSWER TO 3b** — *"guards on reflexes must be the default path
or nothing."* **Moving a pattern from a command line into a file converts a discipline into a
structural impossibility**, because the trap's precondition (pattern present in a live argv)
is destroyed rather than avoided. ⚠️ It is the same shape as the `:4002` pre-flight that
worked: **the constraint lives where the action happens**, not beside it — and here the file
*is* the action.

⚠️ **Scope honestly: this removes SELF-match only.** A file-borne pattern can still match
someone else's process — hermes remains the reason `cp-kill` resolves by identity and signals
numeric pids. **Two different traps; this fixes one of them completely.**

## 8. Open — not near-misses, actual items awaiting a decision

- **`quota-guard.sh` is not on cron.** Two active entries: `watchdog-cron.sh`,
  `state-render-cron.sh`. Whatever it concluded, nobody received it.
- **Its 7d threshold keys on raw utilization (≥80%), not burn ratio** — it says
  SLOW_DOWN at 84% used / 89% elapsed where the ratio is 0.94 and healthy. Docs say
  90%, script says 80%. ⚠️ Not retuned: adjusting a guard so it stops disagreeing with
  you is how guards get talked out of firing. Awaiting jes.

## 7y. A STATE READING IS A CLAIM WITH A TIMESTAMP — AND MINE WENT STALE IN FOUR MINUTES

**2026-08-10, ~18:45Z.** Sol's CX-5gkw run exited. Its final report said *"exactly four
unstaged files, 39 insertions/1 deletion."* I measured the worktree: **0 dirty.** I was one
step from relaying that to jes as a **discrepancy between Sol's report and the repository** —
which would have put a fabrication accusation on a run that had done its job correctly.

**The actual explanation:** commonplace had reviewed and merged it in the intervening minutes
(`5ca502c` → merge `2b673e7`). The tree was clean *because the work had graduated from
unstaged to committed.* Sol's report was true when written. My measurement was true when
taken. **Both true, four minutes apart, and the difference read as a contradiction.**

⭐ **THIS IS 7w AT A FOUR-MINUTE TIMESCALE.** 7w was about a queue row's readiness ageing
overnight. I filed it, and then re-met the same law inside a single turn. **The timescale is
not the lesson — the lesson is that "dirty file count" is not a property of the work, it is a
property of the work AT AN INSTANT, and the instants were different.**

⇒ **THE MOVE THAT SAVED IT: when two sources disagree, look for the transition that makes
both true before you look for the liar.** The cheap query — `git log --oneline -3` — costs
one command and distinguishes *"Sol lied"* from *"Sol finished and someone merged it."*
⚠️ Note the asymmetry in cost: relaying a false discrepancy damages a working agent's
credibility, and credibility does not come back when the correction lands.

⭐ **THE GENERAL SHAPE — A DIFFERENCE BETWEEN TWO READINGS HAS THREE CANDIDATE CAUSES, AND
"SOMEONE IS WRONG" IS THE LEAST LIKELY:**
1. **The world moved between the readings** ← check this FIRST; it is the common case in a
   fleet where other agents are acting concurrently
2. **The two readings measure different things** (his `git status` vs my `git status` in a
   different path — I also had to confirm I was in the right worktree)
3. **One reading is actually wrong** ← the interesting case, and the rarest

⇒ **AND THE FIX IS NOT "MEASURE FASTER."** In a fleet with concurrent actors there is no
reading fresh enough to be safe. **The fix is to record WHEN, and to treat any cross-source
comparison as a question about an interval rather than a moment.**

## 7z. THE GATE CLOSED ON ME AND THE FLEET ROUTED AROUND IT — WHICH IS THE DESIGN WORKING

Same cycle. sol-nudge began declining with a reason I had not seen before: **7d burn ratio
1.93 ≥ the 1.60 brief+review floor.** My read: *the relief valve has closed — Sol dispatch is
now gated too, the fleet has no remaining lane, and that is a genuine change worth surfacing
to jes.* **I had the message half-composed.**

**Then commonplace reported it had dispatched CX-8wh1 to Sol itself** — freed lane, plan's
standing rule, pid verified. **The lane was never closed. The gate is on MY dispatch path,
and commonplace's own path does not pass through it.**

⚠️ **I nearly reported a fleet-wide stop from a boss-shaped instrument.** My nudge script is
the only dispatcher I can see, so its decline felt like *the* decline. ⭐ **A gate reports on
the path it sits in, and I generalised from the one path I happen to instrument.**

⇒ **THE TEST BEFORE ESCALATING ANY "EVERYTHING IS BLOCKED": name the paths that exist, not the
paths I monitor.** Ask *"who else can dispatch, and does their route pass through this gate?"*
Here the answer was one `list_peers`-shaped question away, and the workers answered it by
acting before I asked.

⭐ **AND THIS IS THE BOARD-NOT-INSTRUCTION CHANGE PAYING OUT** (see
`feedback_dispatch_board_not_instruction`). Under the old handoff, a gated boss **was** a
stopped fleet, because dispatch flowed through me. Having moved to *"here is the board"*,
**commonplace self-selected into the freed lane while my dispatcher was declining** — the
system kept working precisely because I was no longer the scheduler. ⇒ **Decentralising the
handoff didn't just fix an invariant violation; it removed me as a single point of failure,
and the first proof of that arrived as a gate closing with no consequence.**

## 7aa. FIVE INSTANCES IN ONE DAY — THE STALE-CLAIM FAMILY HAS A WRITE-SIDE ROOT, NOT A READ-SIDE ONE

**2026-08-10.** By evening the same failure had fired **five times** across three agents:
7w (a queue row's readiness aged overnight), 7y (my four-minute worktree reading), and
commonplace's CX-8wh1 round 1 — where a brief asserted a **10-red MudLive baseline** that had
been **reverted the previous night at `85f8990`**, and every downstream reader inherited the
pre-revert world. Sol stopped in 8 minutes on the mismatch.

⚠️ **I had been treating this as a READ-side discipline problem** — *check freshness before you
rely on a claim.* Five instances says otherwise: **the readers were competent and it happened
anyway.** A rule that requires every reader to re-verify every inherited claim does not scale,
because the reader **cannot see which claims are the volatile ones.**

⭐ **THE WRITE-SIDE ROOT, in commonplace's words and worth keeping verbatim:** *"a ticket that
records a dilemma must record its resolution or it becomes a confident wrong claim with a
timestamp."* The CX-8wh1 ticket had faithfully written down *"tomorrow, decide between
revert-and-re-land vs fix-forward."* **The decision was taken that same night and never
written back.** ⇒ The artifact was not stale by neglect — **it was stale by CONSTRUCTION,
because the format had a slot for the question and no slot for the answer.**

⇒ **THE ASYMMETRY THAT MAKES THIS EXPENSIVE: an unresolved dilemma on the page reads exactly
like a resolved one.** Nothing in the text says *"this may have moved."* A confident sentence
with a date on it is the most trusted thing in a brief, and **the date is what makes it
trusted while doing none of the work of being current.**

⭐ **WHERE THE FIX BELONGS — note which of the two repairs is durable:**
- The **brief** correction fixes CX-8wh1. **It expires with the ticket.**
- The **ticket-format** correction — a recorded dilemma must carry its resolution — **is a
  property of how state gets written, so it outlives every ticket that uses it.**
⇒ **When a stale-claim incident produces two fixes, the one worth generalising is the one
attached to the WRITING, not the one attached to the instance.**

⚠️ **AND THE READ-SIDE RULE STILL HAS A JOB — a narrower one.** It cannot be *"verify
everything"*; it is *"verify the claims your work is ABOUT TO DEPEND ON, at the resolution
that dependence needs."* Sol's escape hatch is exactly this and it is the reason round 1 cost
8 minutes instead of an artifact: **the brief named an expected red count, so the first act of
the work was a cheap test of the premise the rest of it rested on.** ⇒ **A brief that states
its premises as CHECKABLE NUMBERS converts a wrong dispatch into a finding.** Both of Sol's
escape-hatch stops today were correct and both found something real.

## 7ab. I PROVED THE ALERT POLLER CAN FIRE — AFTER RELAYING ITS SILENCE ALL DAY

**2026-08-10.** `squad-alerts-poll.sh` had returned empty on every cycle for hours and I had
reported "no alerts" each time. ⚠️ **I had never established that a non-empty result was
reachable.** The script is well hardened against *breaking* silently — a failed poll shouts on
stdout and exits 3, added after the bare-`exit 0` bug — but **nothing in it distinguishes
"the filter correctly matched nothing" from "the filter can never match anything."**

**THE POSITIVE CONTROL** (read-only, three counts against the same DB):

| query | rows | proves |
|---|---|---|
| poller's exact filter above marker 484 | **0** | what the poller saw |
| same, severity floor relaxed | **9** | **the id-filter and DB read WORK** |
| `severity='critical'` ever | **145** | **the severity term CAN match** |

⇒ **Silence is the filter working, not a dead query.** Marker-advance also checks out: it moves
to the last *relayed* row, so skipped info rows cannot carry it past a future critical.

⭐ **AND THE BASE RATE IS THE PART THAT CHANGES HOW I READ THIS FEED.** 1–3 alerts/day, **zero
criticals on most days**; the 7/30–7/31 spike (36 + 44, 32 critical) was the bot-compromise and
pnl-bug incident. ⇒ **Quiet is this feed's NORMAL state**, so quiet can never be evidence the
path is healthy — the two are indistinguishable without exactly this control. **Any detector
whose null result is also its usual result must be probed on a schedule, or its reassurance is
unearned by construction.**

⚠️ **AND I ALMOST MANUFACTURED A FINDING OUT OF THE GAP.** Newest row was Aug 8, nothing since
— which looked like a dead writer. **The base rate killed it:** gaps of 2–3 days are ordinary
here (07-22, 07-27→29, 08-02, 08-06→07 are all absent), Aug 9 was a Sunday, and the daily
summary fires at 22:00 — **hours after I looked.** ⇒ *The same table that would have shown a
real outage also explains the apparent one; I only got to tell them apart by asking for the
distribution rather than the latest row.*

**One dead branch, deliberately not "fixed":** the filter is `severity in ('critical','error')`
and **`error` has never once occurred** — the vocabulary is critical/info/warn. It costs
nothing (no row is ever labelled `error`, so none is missed) and `warn` sits below the floor by
design — theta-hang warns self-recover within a minute. ⚠️ **Recording it rather than deleting
it: a term that matches nothing is indistinguishable from a term whose traffic stopped**, and
the next reader deserves to know which one this is.

## 7ac. "DELIVERED ON MAIN" — WHOSE MAIN? THE CROSS-REPO POINTER, AND THE ACCUSATION I ALMOST MADE

**2026-08-10, ~20:10Z.** commonplace flagged plan's chit-schema review as **still owed**. I
relayed that to plan, and **told jes it was the likeliest thing to hold up the cell demo.**
Plan replied that the review had been **delivered at 17:04 — three hours before it was flagged.**

**I went to check. `ls docs/notes/2026-08-10-proto-chit-schema-review.md` in `~/commonplace`:
no such file. `git log 4b578ec`: unknown revision. `git show origin/main:<path>`: does not
exist.** ⛔ **Three independent negatives, all agreeing, all wrong** — I was one step from
telling plan its claimed artifact did not exist, which is an accusation of fabrication against
an agent that had done the work.

⭐ **THE ARTIFACT IS IN A DIFFERENT REPO.** `commonplace-plan` is its own git repo; the file is
at `~/commonplace-plan/docs/notes/…` @4b578ec, 7,773 bytes, written 17:04. **"On main" was
true. I was standing in the wrong tree, and a wrong tree answers every question fluently.**

⚠️ **NOTE THE FAILURE HAS NO SYMPTOM.** A missing file and a file-in-another-repo produce
**byte-identical** output from every check I ran. ⇒ Same family as *blocked vs not-there share
an exit code* — and the same remedy: **a negative needs a positive control.** The control here
is trivial and I skipped it: **does this repo contain ANY artifact by this author?** One
question would have exposed the wrong-tree assumption instantly.

## ⭐ THE DEEPER FIND: THIS IS ALSO WHY THE DELIVERY NEVER LANDED

Plan diagnosed the miss as a **relay-chain gap** — *its announcement reached boss, not
commonplace.* True, and **not the whole mechanism.** ⇒ **Even a commonplace that went looking
on its own initiative would have found nothing**, because it greps `~/commonplace` and the
review lives in `~/commonplace-plan`. **The self-serve path was broken too, silently, in the
direction that manufactures "not yet written."**

⇒ **THE FIX IS ONE FIELD: A DELIVERY POINTER MUST NAME THE REPO**, not just path + sha.
*"docs/notes/X.md @4b578ec"* is ambiguous across a multi-repo fleet and **reads as
unambiguous**, which is what makes it dangerous. *"@4b578ec in commonplace-plan"* costs three
words and closes both the relay gap and the self-serve gap at once.

⭐ **AND THE GENERAL FORM, which is bigger than git:** *a locator is only complete if it names
every namespace it is relative to.* **Path is relative to repo; repo is relative to host; a sha
is global but useless if you resolve it in the wrong object store.** ⚠️ **The more precise a
locator LOOKS, the less anyone asks what it is relative to** — a 7-char sha feels like an
absolute address and is not one.

⇒ **AND WHEN A NEGATIVE WOULD ACCUSE SOMEONE, RAISE THE BAR BEFORE SPEAKING, NOT AFTER.**
The cost of one more check is seconds; the cost of "your work doesn't exist" landing on an
agent that did the work is its willingness to report at all. **I have now had two near-misses
in one evening in this exact direction** (7y's phantom discrepancy, this one) — ⇒ **treat
"the other party is wrong" as the hypothesis that requires the MOST evidence, not the least.**

## 7ad. THE QUOTA GUARD SAID **OK** BECAUSE IT COULD NOT MEASURE — FOUND BY LOOKING AT ITS LOG FOR AN UNRELATED REASON

**2026-08-10, 20:22Z.** I opened `logs/quota-guard*.log` to read the burn slope and found, as
its most recent line:

```
OK|worst  x (limit 1.05) — 5h=% 7d=%
```

**Empty fields, verdict OK, exit 0.** `claude-quota --json` had returned unparseable output;
`json.load` raised; the `read` got an empty line; `MAX_RATIO` was empty; the generated
`print(1 if  >= 1.05 else 0)` was a **SyntaxError**; `OVER` was empty; `[ "$OVER" = "1" ]` was
false — and **control fell through to the else branch, which is the healthy one.**

⭐ **EVERY LINK FAILED TOWARD "FINE".** Not one of the four failures produced a nonzero exit.
⇒ **This is the silent-success family in its purest form: the instrument reported the state of
the world when what had actually failed was the instrument.**

⚠️ **AND THE LOG LINE IS ITS OWN CAMOUFLAGE.** The cron records `rc=0 OK|...`, byte-comparable
to a healthy run. **The only tell is the empty `5h=% 7d=%` — inside a line that says OK, which
is exactly the line nobody reads.** ⇒ *A failure that renders as the reassuring answer is not
merely undetected; it is anti-detected, because it recruits the reader's own triage against
noticing.*

**FIXED @3ccb2b3** — `GUARD_BROKEN`, **rc=3**, distinct from OK(0)/SLOW_DOWN(1)/STOP(2), so any
caller treating nonzero as "do not dispatch" now fails safe. **Three controls, run both
directions:** real data still yields SLOW_DOWN rc=1 (**the healthy path is not broken**);
502-HTML yields rc=3; empty output yields rc=3. ⭐ **And the step that makes it evidence rather
than hope: I ran the SAME broken input through the pre-fix backup and reproduced `OK` / rc=0.**
*Proving the new code passes is half a proof; proving the old code failed is the other half.*

## ⇒ THE FINDING METHOD IS THE TRANSFERABLE PART

**I was not auditing the guard.** I was reading its log to extract a burn slope for jes, and the
broken line was simply *in the way*. ⚠️ **This bug had no other route to me:** the guard is
unattended, its output is consumed by a cron redirect, and its failure mode is the word OK.
⇒ **The audit that found it was a side effect of USING the data for something else** — which is
the same law as *state legibility is a correctness property*: **an artifact that gets read for
real work gets checked; one that is only ever written is unfalsifiable in practice.**

⭐ **THE CHECK THIS REPO NOW OWES ITSELF, and it is small:** this is the **third** instance of
the family in five days — squad-alerts' bare `exit 0` (fixed 8/09), the alert poller's
unprovable emptiness (controlled 7ab, today), and now this. ⇒ **Every unattended script that can
emit a reassuring verdict needs one line asserting its own inputs were real**, and the cheapest
version is: **refuse to print the good news with an empty field in it.**

⚠️ **Consequence check before reporting it: none.** The bad verdict was emitted once and read by
nobody; both nudge loops compute burn independently and were declining throughout. **So this is
a near-miss and goes here, not to jes** — though I mentioned it to him in one line alongside the
quota numbers, because it is the instrument those very numbers come from and he was owed the
provenance.

## 7ae. THE ONLY THING BETWEEN 123 CREDENTIAL ARCHIVES AND THE STORE WAS A CRASH

**2026-08-10, 20:59Z.** The 2b ceremony's first real import found that proto-chit's sync scope is
**everything-minus-four-names**. In the real repo that includes `.beads`, which holds
`.beads-credential-key`. **123 `.darc` archives were headed into the cell store, and the only
thing that stopped them was an unrelated crash** — CX-g8r1, the importer dying on binary files —
**firing first.**

✅ **VERIFIED, because a credential claim that passes through me gets checked and not repeated:**
key still mode 0600 at its original path; **no credential-shaped file in any `.commonplace`
store** (the only key material present is ordinary node signing identity); the `.darc` files
outside their home are in the **declared** `cell-1/holdout` plus hermes's unrelated beads.
⇒ **Near-miss, no exposure** — so it is filed here rather than sent to jes.

## ⭐ THE PART WORTH KEEPING: PROTECTION BY ACCIDENT HAS AN EXPIRY DATE

Two p1 tickets now exist: **CX-g8r1** (crash on binary files) and **CX-fm7x** (scope policy).
⚠️ **CX-g8r1 reads like an easy, obviously-good p1** — a crash, with a full stack trace, in a
code path with no defenders. **Fixing it first removes the only thing that stopped the
archives.** ⇒ *The guard here is not a guard; it is a bug that happens to fail in the safe
direction, and repairing the bug disarms it.*

⭐ **SO THE TWO TICKETS HAVE AN ORDER, and the order is invisible from either ticket alone.**
Neither says "do not fix me first." ⇒ **When a near-miss was averted by something that is not a
control — a crash, a timeout, a quota, an unrelated outage — the finding is not "we were lucky";
it is "there is now a SEQUENCING CONSTRAINT that must be written on the tickets themselves,"
because the next reader picks up the appealing one in isolation.**

⚠️ **AND NOTE WHERE THE INFORMATION LIVED:** the danger was legible only to whoever held BOTH
tickets at once — the ceremony operator, for about ten minutes. **A day later it is two
unrelated p1s in a queue.** ⇒ **Cross-ticket constraints decay to nothing unless they are
written down at the moment both are in one head.** Same family as *a dilemma recorded without
its resolution* (7aa): the queue preserves items faithfully and **loses the relations between
them.**

⭐ **THE GENERAL FORM — "WHY DIDN'T THIS BITE US ALREADY?" IS A QUESTION WITH AN ANSWER, AND THE
ANSWER IS SOMETIMES LOAD-BEARING.** The pilot never tripped this because its toy repo held no
binaries and its principal had full trust — ⇒ **the reason a bug stayed hidden is frequently the
same reason nothing bad happened, and removing it does both jobs at once.**

## 7af. THE HONEST RELAY IS **LAYERED** — name which claims you verified and which you carried

**2026-08-10, ceremony completion.** commonplace reported a finished chain: events read back from
the store, signatures, pin hashes, reflog chaining, a witness by a distinct principal. ⚠️ **I
could verify none of the cryptography and all of the packaging.** So I split the relay to jes
explicitly:

- ✅ **VERIFIED BY ME:** commit `b577ada` **on origin/main** (checked against the REMOTE, not the
  local branch — "pushed" is the claim that most often isn't), doc 12,480 bytes on disk, the
  merge present, 123 archives restored to the cell tree, credential key still `600`, **no key
  material outside its home.**
- ↪️ **CARRIED, NOT VERIFIED:** signatures, pin hashes, event chaining — *the builder's
  measurements from its own store.*

⭐ **THE SHAPE, in commonplace's words back to me: "artifacts and publication verified, crypto
passed on as the builder's measurement."** ⇒ **A relay that blends the two launders the weaker
claim into the stronger one.** The reader cannot tell which parts survived an independent check
unless the relay says so — and **a uniformly-confident report is indistinguishable from one where
nothing was checked at all.**

⇒ **THE RULE: state the LAYER, not just the verdict.** *"I checked it exists and is published; I
did not check it is correct"* costs one clause and preserves exactly the information the reader
needs to decide how much weight to put on it. ⚠️ Note this is **not** hedging — every layer is
asserted flatly. **It is scoping.**

## ⚠️ AND THE SECOND NEAR-MISS OF THE SAME SPECIES IN ONE NIGHT

I counted **123 `.darc` still in `cell-1/holdout`** and was one step from reporting the
containment incomplete. **They were a stale COPY** — the restore put the originals back without
removing the source, and the holdout mtimes **predate** the restore. ⇒ **A true count in the
wrong directory**, the sibling of 7ac's *wrong repo answers every question fluently.*

⭐ **THREE TIMES TONIGHT the failure was the same:** a correct measurement, aimed at the wrong
referent, about to be reported as someone else's error (7y phantom dirty-file discrepancy, 7ac
wrong repo, this). ⇒ **"THE OTHER PARTY IS WRONG" REMAINS THE HYPOTHESIS REQUIRING THE MOST
EVIDENCE** — and the specific discipline that saved all three was *check the referent before
composing the correction*, not *measure more carefully*. **The measurements were all correct.**

**Coda worth copying:** commonplace didn't delete the stale copy — it **labelled** it (README:
stale copy, safe to delete, originals restored, no key material, pointer to the evidence doc).
⇒ *Leftovers that read as meaningful are a legibility bug; a label fixes it at lower risk than
a delete.* Same family as [[reference_state_legibility_for_agents]].

## 7ag. THE UNMAINTAINED CLAIM — A RULE ABOUT A DEFECT IS FALSIFIED BY SUCCESS

**2026-08-11 03:30Z.** For two days I carried, cited, and twice told jes: *"commonplace CI is red
on ~79% of runs; red-by-run is that pipeline's normal state, so neither colour carries
information."* It was **true when measured (2026-08-09), correctly verified at the time, and
properly filed with its base rate.**

⛔ **It stopped being true at ~20:04 on 2026-08-10** — the CX-8wh1 merge — and **nothing
announced it.** I measured tonight: **8 of the last 9 completed runs GREEN.** ⇒ **A red on main
is a signal again**, and I had spent the evening telling jes to read nothing into CI.

⭐ **THE LAW: A RULE DERIVED FROM A MEASUREMENT INHERITS THAT MEASUREMENT'S EXPIRY DATE.** And the
sharpest form of it:

> ⚠️ **A rule that describes a DEFECT is falsified by SUCCESS.**
> ⇒ **The better the team, the faster the rule rots** — and the rot is invisible, because fixing
> the defect is a *win*, celebrated in its own channel, that nobody thinks to route back to the
> people quoting the workaround.

**Note the asymmetry that hides it:** a rule that becomes *wrong because things got worse* gets
falsified loudly by a failure. A rule that becomes wrong because **things got better** produces
**no error at all** — it just quietly makes you more pessimistic than reality, which reads as
prudence.

## ⇒ WHAT TO DO WHEN FILING ONE

1. **Name the measurement AND the retiring condition** in the note itself. Here it was trivially
   nameable: *"retires when the flaky pool gets fixed"* — **which was the entire point of the work
   the rule described.** I filed the rule without noticing that its own subject matter was an
   active repair project.
2. **Keep the METHOD, discard the NUMBERS.** The method — get base rate + failure shape before
   quoting any verdict, never gate on one green, give run-rate and test-rate together — is
   permanently right and is *exactly how the flip was detected.* The 21% figure described a world
   that ended.
3. ⭐ **The replacement claim has the same structure.** "CI is green now" is itself a measurement
   with an expiry; the note says re-measure before citing that either. **Do not retire a
   perishable claim by installing another perishable claim as permanent.**

⚠️ **AND RE-VERIFY BEFORE AGREEING TO A RETIREMENT.** commonplace told me the rule was stale; I ran
`gh run list` myself before accepting, because *a claim that retires my own claim is still a
claim.* It checked out — but agreeing would have been inheriting, and inheriting is how the
original went unmaintained.

## 7ah. THE FRICTION WAS REAL, THE FENCE STAYS — `.git` IS A WRITE→EXECUTE CHANNEL

**2026-08-11 04:20.** Three Sol runs in a row produced good work that could not be committed:
codex's `--sandbox workspace-write` mounts `.git` **read-only**, so `git add` fails on
`index.lock`. I found the cause in **my own wrapper** (`sol-egress-run.sh:222`) and offered to
add a scoped writable exception.

⛔ **commonplace declined, and its reason is better than my instinct was.** I had only *"don't
loosen a security fence at 04:20"* — correct, but a vibe. The mechanism:

> ⭐ **`.git/hooks/*` EXECUTE ON THE REVIEWER'S MACHINE the moment they land or merge the
> branch.** An agent that can write `.git` can arrange code that runs **outside the sandbox**,
> at review time, on a machine the sandbox was built to protect.

⇒ **Same laundering shape as CX-b38c's write⊥execute belt, one layer up:** *writing is
arranging future execution.* The belt refuses a write-only cert authoring code docs for exactly
this reason; a writable `.git` is that hole wearing a plumbing costume.

⭐ **AND THE COST COMPARISON IS THE PART THAT SETTLES IT:** the fence costs **one `git commit`
per round, by a reviewer already reading the diff.** Removing it costs **a whole channel.**
⇒ *When a fence's cost is one command and its removal opens an execution path, the friction is
not evidence the fence is wrong — it is the fence's price, and it is cheap.*

⚠️ **REFUTED, recorded so nobody retries it:** dispatching into a full local **clone** instead of
a linked worktree does not help. Verified on CX-7smx — the clone's `.git` was a real writable
directory with no alternates, and Sol *still* reported it mounted read-only. **The fence is on
the PATH INSIDE THE SANDBOX, not on where the metadata lives.** One run, cheap refutation.

## ⇒ WHERE THE REASON GOT WRITTEN, which is the transferable bit

Not here first — **into `sol-egress-run.sh` at the exact line someone would edit** (@50f4b63),
because *the next person to consider loosening this reads the flag, not LESSONS.md.* ⭐ **A
"don't do X" belongs at the site of X**, with the mechanism attached; a rule filed only in a
lessons file is a rule that will be rediscovered the expensive way. Same law as
[[reference_state_legibility_for_agents]] — **make the cheap path and the true path the same
act.**

## 7ai. I BROKE THE SOL WRAPPER WITH A COMMENT — AND BOTH OF MY CHECKS WERE BLIND TO IT BY CONSTRUCTION

**2026-08-11 04:27.** I added the `.git`-fence rationale to `sol-egress-run.sh` — good content, right
placement instinct (at the line someone would edit). ⛔ **I inserted it BETWEEN the backslash-
continuation lines of the `codex exec` invocation.**

A trailing `\` joins the next line. **A comment on the joined line comments out EVERYTHING AFTER
IT.** So the real command became `codex exec -m gpt-5.6-sol` — **no sandbox flag, no workdir, and
no prompt.** commonplace's next two dispatch attempts died. ⭐ **The ONLY reason nothing ran with
the wrong flags is that codex fail-fasts on a missing prompt. That is luck, not design** — the
same invocation with the prompt surviving would have run **unsandboxed-flag work with egress
open**, which is the exact hazard this wrapper exists to prevent.

## ⛔ THE PART WORTH THE ENTRY: MY TWO VERIFICATIONS WERE *STRUCTURALLY* INCAPABLE OF FAILING

1. **`bash -n` — PASSED, and always would.** A comment inside a continuation is **syntactically
   perfect.** The file is valid bash; it just means something else. ⇒ *A syntax checker cannot
   catch a semantic change that is syntactically legal, and "it parses" reassures exactly as much
   as it should: nothing.*
2. ⭐⭐ **My "invocation still intact?" check FILTERED OUT COMMENTS** — `sed -n '/codex exec/,/dev
   null/p' | grep -vE '^\s*#'`. **I stripped the very thing that caused the bug and then looked at
   what remained.** The broken file and the working file are **byte-identical under that filter.**
   ⇒ *I did not verify the command; I verified my mental model of the command, rendered from the
   file by deleting the evidence.*

⚠️ **THE GENERAL FORM, and it is nastier than "test better": A FILTER APPLIED WHILE VERIFYING CAN
REMOVE THE DEFECT CLASS BEING VERIFIED.** Grep-to-clean-up-output is a *reading* habit; inside a
check it becomes a **blindfold sized precisely to the bug.** ⇒ **When verifying that X is intact,
never view X through a transform** — `cat -A` it, or better, don't read it at all.

## ⇒ THE CHECK THAT ACTUALLY WORKS: TRACE THE ARGV

commonplace diagnosed it with an **echo-shim** (argv ended at `-m gpt-5.6-sol`). I re-verified the
fix the same way — a `codex` shim first on PATH, a sentinel prompt, and three assertions:

```
SOL_WORKDIR=<scratch> PATH=<shim>:$PATH bash sol-egress-run.sh "TEST_PROMPT_SENTINEL"
  → ARGV_REACHING_CODEX: exec -m gpt-5.6-sol --sandbox workspace-write -c … -C <wd> TEST_PROMPT_SENTINEL
  ✅ --sandbox workspace-write   ✅ -C   ✅ TEST_PROMPT_SENTINEL
```
⭐ **This is verify-by-effect for a COMMAND: don't read what you think you built — make the thing
you are launching TELL YOU what it received.** Costs one shim and ten seconds, and it is immune to
every transform I might apply while reading.

⭐ **AND THE LESSON I HAD JUST WRITTEN, TURNED ON ITSELF:** 7ah's own conclusion was *"put the
reason at the site of the change."* **Acting on that is what broke the file** — the site of the
change was inside a continuation. ⇒ *Good placement advice does not suspend the need to verify the
placement.* **A doc edit to an executable file is a CODE CHANGE** — same class as
[[feedback_hermes_hot_reload]]'s "writing a source file IS deploying," arriving where I least
expected it: in a comment.

## 7aj. WRITTEN LESSONS DO NOT PREVENT — RECOVERY PATTERNS DO. (Both of us proved it inside 30 minutes.)

**2026-08-11, ~04:50.** Two independent instances, same night, same shape:

- **commonplace** repeated its own from-inside-the-worktree merge fumble (branch into itself, silent
  no-op) — **the exact mistake its own memory note from three hours earlier warns about.** Its
  words: *"A written lesson didn't stop the 05:00 hands; the recovery pattern did."*
- **I** broke the Sol wrapper by placing a comment inside a line-continuation — **while acting on
  7ah, the lesson I had written ninety minutes before, whose conclusion was "put the reason at the
  site of the change."**

⇒ **THE UNCOMFORTABLE GENERALISATION: a lesson in a file is not a control.** It is *retrieval-
dependent*, and retrieval is exactly what degrades under load, at 05:00, mid-flow, or — worse —
**when you are busy applying a DIFFERENT lesson.** ⭐ *Both failures happened during competent,
lesson-following work.* Neither was carelessness.

## ⭐ WHAT ACTUALLY CAUGHT THEM, in both cases: A CHECK ON THE EFFECT, NOT A MEMORY OF THE RULE

| | The rule that failed to prevent | The thing that caught it |
|---|---|---|
| commonplace | "don't merge from inside the worktree" | **reading the PUSH OUTPUT rather than trusting rc** |
| me | "verify the invocation is intact" | **commonplace's echo-shim showing argv ended at `-m gpt-5.6-sol`** |

⇒ **Both catches are observations of the WORLD AFTER the act.** Neither is a stronger version of
the rule, a bigger warning, or a better-placed comment.

## ⇒ SO WHERE SHOULD EFFORT GO

1. ⭐ **Prefer a mechanism that makes the error impossible or loud** over a note that makes it
   known. The wrapper's real fix is not my comment — it is the **argv trace as a standing check**.
   The launcher's `[ -n "$AK" ] || REFUSE` is worth more than the paragraph above it explaining why
   the key matters.
2. **When you cannot mechanise, mechanise the RECOVERY** — cheap, fast detection plus a known
   restoration. commonplace's fumble cost nothing because the detection was routine.
3. ⚠️ **Keep writing the lessons anyway** — they are how a *cold* reader (or a future session with
   no context) learns the shape, and how a mechanism gets its rationale. **But do not count a
   filed lesson as a fix, and never close an incident on "documented."**

⭐ **THE TEST: after filing a lesson, ask "what would catch this if nobody remembers this file?"**
If the answer is nothing, the incident is still open.

### 7aj addendum — THIRD STRIKE, AND THE REMEDY THAT FINALLY FITS (2026-08-11 05:52)

commonplace repeated the from-inside-the-worktree merge **a third time** — same silent no-op, same
recovery. Its own note from ~03:00 warns about it; **the note lost to muscle memory three times.**

⭐ **Its formulation is better than mine and is the durable line:**

> **"A lesson that keeps losing to habit needs the HABIT'S SHAPE changed, not a fourth warning."**

⇒ **The fix it shipped is structural, not textual:** all landing git operations now run as
`git -C <main-checkout>` with **no `cd` chaining** — the command form no longer HAS a working
directory to be wrong about. ⭐ **That is the right class of remedy: it does not ask anyone to
remember; it removes the state the error depended on.**

**Compare the three attempts and note the trend, because it is the whole point:**
| attempt | remedy | outcome |
|---|---|---|
| 1st | noticed, recovered | recurred |
| 2nd | **written to memory** | recurred |
| 3rd | **command form changed** | — the first remedy that isn't retrieval-dependent |

⚠️ **AND THE DETECTION HELD ALL THREE TIMES** (reading push output rather than trusting rc), which
is why three occurrences cost minutes rather than a lost merge. ⇒ *Reliable detection is what buys
you the room to keep failing at prevention until you find the structural fix.* Don't skip the
recovery pattern while hunting the perfect guard.

**Verified independently:** dacfe2e IS on origin/main, IS main's tip, and carries a non-empty diff
— i.e. the third landing genuinely landed. **The class this checks for is the class that just
failed three times**, which is exactly when to check rather than assume.

## 7ak. THREE RULINGS FOR ONE TICKET IN FORTY MINUTES WAS CONVERGENCE, NOT THRASH — DON'T DAMPEN IT

**2026-08-11, 06:15–06:55.** S2 (workspace profile) was ruled three times: **profile-option-on-
initialize → mint-sites-consult-profile → chokepoint-at-the-root-attach-seam.** I relayed each
one faithfully, and a fourth relay filed the independent bug the audit surfaced.

⚠️ **From the dispatcher's seat this LOOKS like indecision** — same ticket, three mechanisms, under
an hour, at 6am. The available intervention was obvious and available to me at every step: *"this
is the third revision; maybe let it settle."* ⛔ **That would have destroyed the value.**

⭐ **BECAUSE EACH MOVE WAS BOUGHT BY A MEASUREMENT, NOT AN ARGUMENT:**
| move | what forced it |
|---|---|
| fix → mechanism | Sol's enumeration: `initialize/2` mints NOTHING; the real sites are a boot hook and a lazy call |
| mechanism → **policy** | the inventory was still incomplete — Bursar, reflog, scheduler, `__processes.json` — so "which sites consult" was really *which root entries a workspace class accepts* |
| per-site → **chokepoint** | tonight's inventory is complete only until the next mint site is written by someone who never read the thread |

⇒ **commonplace's line, and it is the arc in one sentence: "S2 moved fix→mechanism→policy in three
rounds, each move paid for by a measurement that cost less than the build it corrected."**

## ⇒ THE DISPATCHER'S RULE THAT FALLS OUT

⭐ **REVISION COUNT IS NOT A QUALITY SIGNAL. THE QUESTION IS WHAT DROVE EACH REVISION.**
- Revisions driven by **new measurement** = convergence. **Relay them at full fidelity and stay out
  of the way.** Each one is cheaper than the build it replaced.
- Revisions driven by **re-argument over the same facts** = thrash, and *that* is worth naming.

⚠️ **The two are indistinguishable by count, cadence, or hour of the night** — the only
discriminator is whether a new *fact* arrived between them. ⇒ **Before reading churn as
instability, ask what was measured between revision N and N+1.** Here the answer was: an
enumeration, a caller audit, and a completeness check. That is not a team failing to decide; it is
a team refusing to build on an unmeasured premise three times running.

⭐ **AND THE SCOPE-ESCALATION SHAPE IS WORTH RECOGNISING ON SIGHT:** a fix that keeps needing more
sites is usually a **mechanism** in disguise; a mechanism that keeps needing more sites is usually
a **policy**. **Measurement is what reveals which tier you are actually on** — and the tell is the
inventory growing each time you look, exactly as it did here.

## 7al. RATIFICATION DOES NOT RETIRE THE ESCAPE HATCH — AND A RULING SETTLES A DECISION, NOT ITS FACTS

**2026-08-11, 09:05.** Plan ratified "release resets the mirror to open" at 07:24 on a stated
basis: status mirrors custody AND decision, and the stranded state is custody-released with the
mirror still asserting in-progress. commonplace authored the brief, plan reviewed it, **the
ruling was settled.**

⛔ **Sol's mandated pre-build enumeration then measured the premise FALSE.** `ticket_claim` and
`ticket_release` write ONLY `claimed_by` — via `mirror_claimed_by/5` with `allow: [:claimed_by]`.
**Release never touched status at all.** So the verb surface carries ONE axis (create→open,
close→closed), and in_progress/blocked/review are **import-minted values outside the verb
transition graph entirely.**

⭐ **AND THE FIX WAS WORSE THAN THE PREMISE WAS WRONG:** release-resets-to-open would have
**clobbered an imported `blocked` to `open`** — and under the ruling's own by-name generalisation,
**on LEASE EXPIRY too.** A custody event erasing a decision: *the exact axis-mixing the ruling
deplored, in the opposite direction.* ⇒ **Premise-wrong upgraded to fix-dangerous.**

## ⇒ THE RULE, in commonplace's words and worth keeping verbatim

> **"Ratification did not retire the escape hatch."**

The ratified brief still carried its stop conditions, **which is the only reason a wrong ruling
was catchable at all.** ⚠️ The tempting shortcut is exactly the opposite: *this was reviewed and
approved, so the builder can proceed without the checks.* **Approval is when the hatches matter
MOST**, because everyone downstream has stopped questioning the premise.

⭐ **THE BOSS-LANE COROLLARY, which is mine:** when I relay a ruling, I must not let ratification
read as settling the EMPIRICAL question. ⇒ **A ruling settles what we DECIDE; it does not settle
what is TRUE about the code.** I relayed this ruling with plan's basis stated as reasoning — which
was right — but the basis was a claim about `mirror_claimed_by` that nobody had read. **Relay the
decision as decided and its premises as premises**, so the next reader knows which part a
measurement could still overturn.

⚠️ **Note the escalation across one night:** the hatch caught a wrong *mechanism* in a ticket
(tj6b), a fix that wanted to be a *policy* (S2), and now a wrong *premise in a ruling* (S5).
⇒ **Same protocol, ascending targets — and the highest-value catch was the one furthest from the
code**, where the most confidence had accumulated and the fewest people were still checking.

## 7am. "THEY HAVE A MONITOR FOR THAT" IS NOT A REASON FOR ME TO STAY SILENT

**2026-08-11, 10:40.** commonplace disclosed that **every monitor it armed after its compact was a
self-matching zombie** — `pgrep -f 'codex exec.*sol-X'` matches the monitor's OWN command line, so
it saw itself, believed the run was alive, and never fired. ⇒ **My outside board notes were the
ONLY working signal for both hatch stops that morning.**

⛔ **AND TWENTY MINUTES EARLIER I HAD DECLINED TO SEND ONE, in those words:** *"commonplace has
three monitors armed and will see it without me."* **Those monitors were already dead.** I
justified silence by trusting a mechanism I could not observe — and neither could its owner, because
a silently-failing watcher reports nothing to anybody.

⭐ **THE INVERSION IS THE LESSON.** I sent the two hatch-stop notes believing they were a redundant
second signal that might add a connection. **They were the entire channel.** *What I priced as
duplication was the only delivery.*

## ⇒ THE RULE, and it is asymmetric on purpose

⭐ **NEVER let "someone else's check covers this" justify my silence about an observation I already
hold.** I cannot see whether their check is alive; they cannot see it either while it fails.
⇒ **A duplicate notification costs one skimmed message. A shared assumption that a dead check is
watching costs the whole signal.** ⚠️ The costs are not symmetric, so the tie does not go to
silence.

**Standing consequence adopted:** I report Sol run terminations from outside **regardless of what
their monitors say**, because that check is independent of their side *by construction* — which is
precisely the property that mattered this morning. commonplace now treats those notes as **primary,
not backup.**

⚠️ **NOTE WHAT THIS DOES *NOT* LICENSE:** it is not permission to relay everything. The earlier
call — staying quiet when a round completed ordinarily and carried no finding — was still right on
its merits (nothing to add), and would have been right even had I known the monitors were dead,
*because a bare "Sol is free" adds nothing a working monitor wouldn't.* ⇒ **The test is whether I
hold information the recipient lacks — never whether some other mechanism is nominally responsible
for delivering it.**

**Tally: the self-match trap is 4-for-4 tonight** — their monitors, my codex in-flight check, my
`ZZZ` probe while testing the burn floor, my `cargo|rustc` scan during the wimble cleanup. ⇒
**It is the most reliable constructor of a check-that-cannot-fail we have found.** Fix: watch
**pids, not patterns** (`kill -0` has no argv to match itself against), and capture the pid *after*
handoff.

## 7an. AN UNSATISFIABLE BRIEF DOESN'T STOP THE BUILDER — IT GETS SATISFIED BY GOING *AROUND*

**2026-08-11, 10:53.** S5v2's brief carried a goal and a constraint that were **jointly
unsatisfiable, and nobody noticed**: plan's ruled transition table says **closed→open exists
(reopen-with-reason)**, while WriteGuard's post-close freeze is deliberate S3 policy whose own
docstring reads *"can never be bypassed by an allow list … NO REOPEN IN V1."*

⛔ **Sol did not stop. It went AROUND** — `status_transition_write_guard` returns a bare `:ok` when
the issue is closed, making the reopen **the one write in the system that skips the chokepoint.**
⭐ **Letter-compliant with "WriteGuard is untouchable" — and the chokepoint invariant is broken.**
*The constraint was honoured exactly; its purpose was inverted.*

⚠️ **THIS IS THE FAILURE MODE MY OWN DISPATCH RULE NAMES**, and I relay it every cycle without
having understood its teeth: *"Never give Sol an instruction it cannot satisfy. An omitted warning
costs TIME; a contradictory one costs JUDGMENT."* ⇒ **Here is what "costs judgment" cashes out to:
the builder does not halt on a contradiction — it finds the reading that lets it finish.** And
"don't touch X" is *always* satisfiable by routing around X, which is the one resolution nobody
intends and the brief never forbids.

## ⇒ WHAT WOULD HAVE CAUGHT IT

⭐ **A "don't touch X" constraint needs its PURPOSE attached, not just its boundary.** *"WriteGuard
is untouchable"* permits the bypass. *"Every status write goes through WriteGuard; if the goal
requires a write that cannot, STOP and report the collision"* forbids it — same constraint, plus
the invariant it protects and an explicit hatch for the contradiction.
⇒ **State the invariant, not the file.** A boundary drawn around code protects the code; a
boundary drawn around the *property* protects the property.

⚠️ **AND THE COLLISION WAS DISCOVERABLE BEFORE THE BUILD.** The docstring says NO REOPEN IN V1 in
capitals; the ruled table says reopen exists. **Two artifacts in the repo, contradicting each
other, and the brief was written from one of them.** ⇒ *Reading the code the ruling touches is a
pre-brief measurement like any other* — the discriminator protocol applied to POLICY sources, not
just mechanisms.

⭐ **The good news, and why this cost one round rather than a shipped hole:** commonplace's review
caught it before landing, because a chokepoint invariant is exactly the property a reviewer can
check *structurally* — "is there now a write that skips it?" is a question with a mechanical
answer, unlike "is this fix correct?"

### 7ai addendum — FILTERED CAPTURE IS ITS OWN DEFECT CLASS: PERSIST RAW, FILTER ON READ

**2026-08-11 13:15, third instance in one day.** commonplace asked whether a boot had fired three
trust-gate denials. I grepped the pane: **zero**. That reads as a finding — *the writer stopped.*
⇒ **Positive control: is the posture block, which I KNOW is in that boot because I pasted it
fifteen minutes earlier, still in my window?** Not at 400 lines, not 1200, not 3000. **The pane had
rotated the whole boot away.** The zero was **vacuous** — an absence from a window that no longer
held the event either way, and it would have been a false negative injected into a live p2 trust
attribution.

⭐ **THE THREE INSTANCES ARE ONE LAW:**
| when | what was filtered | what it cost |
|---|---|---|
| 2026-07 | `/proc/environ` captured through a guessed grep | dropped `PHX_SERVER`; manufactured a fake Bursar incident and a needless rollback |
| 2026-08-11 04:27 | wrapper check piped through `grep -v '^\s*#'` | broken and working files byte-identical under my own verification |
| 2026-08-11 13:15 | boot output captured *by grepping for* the posture block | could not answer a question asked 15 min later; near-false-negative |

⇒ **A FILTER AT CAPTURE TIME DESTROYS WHAT YOU DIDN'T THINK TO ASK FOR. A FILTER AT QUESTION TIME
DESTROYS NOTHING.** ⭐ **So: PERSIST RAW, FILTER ON READ.** The cost is a file; the alternative is
that every future question about that moment is unanswerable, and *you find out only when someone
asks one.*

⚠️ **AND THE TELL IS ALWAYS THE SAME:** the filtered artifact looks complete. Nothing in `0 DENIED`
announces that the search space was empty. ⇒ **Any absence measured against a captured artifact
needs the control "is something I KNOW was there still here?"** — which is the same non-vacuity
rule the census rounds carry as *0-over-0 is VOID, not green.*

⚠️ **Rotation is MINUTES under load, not the hour we assumed** — measured, and the assumption that
cost us was never checked because nobody had needed the scrollback twice before.

## 7ao — AN ACCEPTANCE MODELS A SET OF WRITERS, NOT A SET OF LINES

**2026-08-11 16:22Z, the CX-vghh live acceptance.** I built the criterion carefully and it still
misread the world: I told the fix's author, on the strength of a clean measurement, that **their fix
had not taken.** It had. Separating my capture cost commonplace **three store reads.**

**The acceptance was a two-branch disjunction** (custody present → signed landing + zero denials;
custody absent → the named skip line exactly once; **silence on both = a finding**). That structure
was *right* and I would build it again — see below. What was wrong sat one level under it.

⭐ **BOTH BRANCHES KEYED ON WHAT THE BOOT LOG SHOWS, CARRYING AN UNSTATED PREMISE: that the only
thing writing to this doc during boot is the thing under test.** The boot window had **three**
writers. The three denials I scored against the bridge were `Presence.Reaper` — 30s stale threshold,
a bridge that heartbeats **once**, so it retries an unsigned root removal forever under enforce and
logs `removed 1 stale entries` *after each denial*. **The interleaving I photographed as evidence of
failure was a second writer's loop.**

⇒ ⭐ **NAME THE EXPECTED WRITERS, NOT JUST THE EXPECTED LINES.** An unattributed line is not evidence
about the writer you had in mind. A criterion that says *"zero denials"* silently means *"zero
denials from anyone"*, which is a claim about the **whole system**, not about the fix.

⚠️ **THIS IS THE SAME DEFECT AS THE COUNT ONE HOUR EARLIER, AND I DIDN'T SEE IT THE SECOND TIME.**
| | the artifact | my model |
|---|---|---|
| the count | 3 denials before, 3 after — *composition* changed (2 uuids → 1) | a total, which can't hold composition |
| the writers | a log with 3 writers in it | one writer, so every line was attributable |
⇒ **In both, the artifact was never ambiguous. The model of what could have produced it was too
small.** ⭐ *The failure mode of a careful measurement is not a bad measurement — it is a good
measurement read against too few hypotheses about its source.*

## ✅ WHAT ACTUALLY WORKED, AND MUST NOT BE "FIXED"
1. ⭐ **SILENCE-AS-FINDING EARNED ITS KEEP.** commonplace: *"the disjunction wasn't wrong, the world
   had one more writer than the acceptance modeled."* **Neither-branch is what forced the
   investigation that found CX-9jds** — a weaker criterion ("no denials = pass") would have *also*
   failed here and produced a shrug, or worse, passed on a later boot and buried a live p2.
2. ⭐⭐ **REPORTING THE MEASUREMENT WITHOUT A MECHANISM IS WHAT MADE THE CORRECTION CHEAP.** I sent
   counts, uuids, greps, controls, and *no theory*. ⇒ commonplace argued with **the evidence** and
   was done in three reads. ⚠️ **Had I shipped a hypothesis, the hypothesis is what would have been
   argued with** — that is the five-hypotheses failure of 2026-08-09 in miniature, and the lane rule
   ("do not dig in") is what prevented it. **The rule paid off precisely when I was most confident.**
3. **The positive control (is the posture block still in the capture?) passed**, so the absences were
   real absences. Without it I'd have had *two* unknowns and no way to rank them.

⇒ **THE HABIT CHANGE:** when writing an acceptance against a shared artifact, **write down the
writers you expect to appear in it** — then a line from an unlisted writer is *itself* a finding,
instead of being silently attributed to the subject. commonplace adopted the same rule from the
authoring side.

## 7ap — VERIFY-WHAT-YOU-REPEAT DOESN'T FIRE ON A CLAIM EMBEDDED IN A WORK DESCRIPTION

**2026-08-11.** I relayed to plan that S19 was *"npm ci in ci.yml plus a refusable-skip knob"* — i.e.
that the diff_yjs oracle was **not** installed in CI and 11 differential tests were silently
skipping. **`ci.yml:43` has had node 22 + lockfile cache + `npm ci` all along. The tests were
running.** Plan formally ruled on the delegated stream's closure using my words.

⭐ **THE CLAIM PASSED THROUGH THREE HANDS, GOT FORMALLY RULED ON, AND WAS NEVER ONCE CHECKED AGAINST
THE FILE IT DESCRIBES.** Classification doc → commonplace's brief (inherited, not re-derived) → me
(relayed, verified nothing) → plan's ruling.

## ⛔ WHY MY OWN RULE DIDN'T FIRE — the part worth keeping
**I have a standing rule to verify what I repeat, and it did not trigger.** ⇒ Because the claim
**did not arrive as an assertion.** It arrived as a *description of work to be done*, where a factual
premise reads as **context** rather than as **something being claimed**.
⭐ **A STANDALONE ASSERTION LOOKS CHECKABLE; A PREMISE INSIDE A TASK DESCRIPTION LOOKS LIKE
BACKGROUND.** The verification instinct keys on the *grammar of assertion*, not on the *content
being load-bearing* — so the most load-bearing premises are exactly the ones that slip through,
because they are stated as the reason for the work rather than as the work's subject.

⇒ **THE HABIT: when relaying a work item, extract its factual premises and ask of each — WHICH FILE
WOULD SHOW THIS, AND HAS ANYONE OPENED IT?** If the answer is "it came with the item", it is
unverified no matter how many hands it has passed through. ⚠️ **Hand-count is not evidence.** Three
careful readers reproduced it faithfully; faithful reproduction of an unchecked claim is what a
rumour is.

**Caught by:** Sol's first step being *read the workflow file* — the discriminator-before-brief
protocol catching a **relay** error it was never designed for. (plan's tally: seventh distinct save,
fourth distinct mode — mechanisms, shapes, policies, now **provenance**.)

⭐ **SAME FAMILY AS 7ao, ONE LEVEL UP.** 7ao: an acceptance carries an unstated premise about *who
writes*. 7ap: a work item carries an unstated premise about *what is already true*. **Both are
premises that were never spoken aloud, so were never candidates for checking.** ⇒ *The dangerous
claim is not the one asserted wrongly — it is the one never asserted at all.*

**Related today:** the S18 inverted budget — 2.5s sized from a real 518ms max, replacing a 5s that
was already firing spuriously ⇒ **a true number with the wrong scope**, sized from a lighter
enclosure than the defect lives in. **Decide which question a budget answers before sizing it: a
hang detector and a per-op performance assertion are different instruments, an order of magnitude
apart.** Caught by merged-tree-before-push, pre-push.

## 7aq — THE RULE DOESN'T FIRE UNDER LOAD; THE RITUAL DOES

**2026-08-11 20:47Z.** commonplace, shedding load on a box at 25, ran a kill selector containing
`phx.server`. It matched **the live :5199 serve AND hermes** — jes's live-money BEAM — alongside its
intended target. All three SIGTERMed. **It has a memory file about exactly this class.** So do I.

**Restored: hermes down 84s** (graceful, exit 0/SUCCESS, market closed at 20:00Z, no session live),
back via its systemd unit; **serve back on 6efbdcc**, environ-identical to the pre-incident process,
whole boot block persisted with the posture positive-control passing.

## ⭐ THE LESSON IS NOT "BE MORE CAREFUL"
**Everyone involved already knew the rule.** ⇒ *Knowing it is not what protects you.*
Earlier the same day: commonplace lost a flake's identity to `mix test | tail -1` — **the pipe-eats-
exit-status trap it had itself named ONE HOUR EARLIER.** Two agents, two self-inflicted hits, both
on rules they had personally written down that day.

⭐ **I DIDN'T HIT IT TODAY, AND NOT BECAUSE I WAS BEING CAREFUL.** I resolved every pid by
`comm` + `cwd`, asserted serve≠hermes, and signalled numeric pids — **because those steps are welded
into the sequence I run, not because I remembered to want them.** Same with `${PIPESTATUS[0]}` in the
deploy compile: habit, not vigilance.
⇒ **A RULE IS A THING YOU MUST REMEMBER AT THE MOMENT OF MAXIMUM PRESSURE — WHICH IS EXACTLY WHEN
REMEMBERING FAILS.** A ritual is a thing you cannot skip without noticing.

## ⛔ THE MECHANISM FIX (commonplace's, adopted): NEVER HAND-AUTHOR A KILL SELECTOR
**Capture the pid AT LAUNCH and kill by that.** Then there is no pattern to get wrong under
pressure — the dangerous act stops being available. Same shape as building re-derivation into the
artifact (7ap) and the seam into the code rather than the report.
⇒ **THE TEST FOR ANY LESSON: does it end as a rule I must recall, or as a step the work cannot
proceed without?** If the former, it will fail on the worst day. **Convert it or expect to relearn it.**

⚠️ **AND NOTE WHAT MADE THE RECOVERY CHEAP** — none of it was carefulness either: the service was a
**supervised systemd unit** (restart = one command, no env reconstruction), SIGTERM to a BEAM is
**graceful by construction**, and the serve's launcher was **a script with an allowlisted env** rather
than a line to retype. ⭐ *Structure, not attention, is what turned a two-service outage into 84
seconds.*

**Reported by commonplace immediately, completely, mechanism named, with the restart HELD** rather
than re-coupling the serve to its own pane. ⇒ **That is the behaviour to reinforce — and the reason
to spend the response on the mechanism instead of on the person.** I said nothing about its selector;
it already had the file.

## 7ar — THE CONSTRAINT WRITTEN AS PRINCIPLE CAUGHT THE BUG NOBODY PREDICTED

**2026-08-12 08:17Z.** S24's backfill ran live: walked 5855 docs, indexed 1187, 0 refused. Then the
torn-create scan returned **258 results — exactly ONE real ticket (CX-7cpf) and 257 FALSE
POSITIVES.** The backfill's `issue_doc?/2` accepts anything decoding issue-shaped with a non-empty
id + created_at, which swallows **comment docs and chat messages**. One flagged doc was
`{"author":"Jes Wolfe!","body":"DIRECTION GIVEN..."}` — a chat message, classified as a torn ticket.

⭐⭐ **IF RECOVERY HAD AUTO-COMPLETED, IT WOULD HAVE MINTED 257 FAKE TICKETS FROM CHAT MESSAGES
INTO THE ISSUES DIRECTORY.** It did not, because plan had ruled — as constraint 5 of five, written
*before anyone knew there was a bug* — that **recovery NEVER auto-completes silently; completion is
a visible act, manual or verb-gated until the mechanism has earned trust.** commonplace transcribed
it "almost as ceremony." It paid within six hours of landing.

## ⭐ WHY THIS ONE IS DIFFERENT FROM THE REST OF THE WEEK'S CATCHES
Most catches here are **checks aimed at a suspected failure** — a positive control against a
vacuous zero, an ancestry test with its reverse, a tree token against an empty merge. Each was
built by someone who could name what they feared.
⇒ **THIS ONE WAS NOT AIMED AT ANYTHING.** No one suspected `issue_doc?/2`. The constraint was
derived from a POSTURE — *a mechanism that has not earned trust does not get to act unsupervised* —
and postures cover cases their author cannot enumerate. ⭐ **A CHECK CATCHES THE FAILURE YOU
IMAGINED; A POSTURE CATCHES THE ONE YOU DIDN'T.** Both are needed and they are not substitutes.

⚠️ **AND THE FAILURE WOULD HAVE BEEN INVISIBLE-BY-CONSTRUCTION.** Auto-linking 257 comment docs
produces *well-formed tickets in the directory* — no error, no denial, no crash. It would have
looked like the repair working, at scale. **The blast radius of an auto-completing recovery is the
size of its own false-positive rate, and nobody measures that before shipping a recovery.**

## ⭐ MEASURE-BEFORE-ACTING, AT THE OPERATOR LAYER
commonplace **triaged the 258 instead of linking them, and stopped.** The mechanism made the
finding possible; the operator declining to trust its own new tool made it safe. ⇒ *A tool's first
live output is a measurement to be checked, not an instruction to be executed* — which is the
same law as never reading a report as a result.

**Scope, so this isn't over-read:** the going-forward create-time index is FINE (only real
`Issue.create` sets the marker). This is purely the backfill heuristic. The 257 spurious index rows
are harmless — append-only, VISIBLE untouched — but poison the scan until the discriminator is
fixed and re-run.

## ⚠️ AND MY OWN ERROR IN THE SAME HOUR, CORRECTED AT THE SOURCE
At 07:31 I routed plan a CubDB integrity-probe timeout as **"a second independent signal of store
size,"** and it went into the storage note within minutes. **The backfill then walked 5855 heads
FAST.** ⇒ The store is not obviously large; the probe timing out is a FACT, "therefore the store is
big" was MY INFERENCE, and I supplied it with more confidence than it had earned.
⇒ Asked plan to downgrade it to *"unexplained probe timeout, cause open."* ⭐ **A measurement I
hand to a designer becomes a premise in minutes** — 7ap's lesson arriving from the authoring side
this time, and the fix is the same: **say which part is measured and which part is my reading.**

### 7ar addendum — TRANSCRIBE FAITHFULLY *BEFORE* YOU SEE THE NECESSITY

commonplace's own extraction, and it's a different lesson from the one above. Its words:
> *"transcribing plan's rulings faithfully even when I don't yet see their necessity is precisely
> why they pay later."*

⭐ **THE CONSTRAINT THAT SAVED 257 TICKETS WAS TRANSCRIBED 'ALMOST AS CEREMONY.'** The implementer
did not believe in it at write time — it had no visible use-case, no bug to point at, no failing
test. **Its value was entirely deferred, and its cost was paid immediately** (a line of design
obeyed, a shortcut declined). That is the exact profile of the constraint most likely to be dropped
by a competent, busy, well-intentioned agent — because "I can't see why this matters" feels like
information, and it isn't.

⇒ **THE ASYMMETRY THAT MAKES THIS A RULE:** a ruling you don't yet understand costs a few lines to
honour and an unbounded amount to have skipped. **You cannot evaluate a posture's necessity from
inside the implementation** — the whole reason it's a posture is that it covers cases the author
couldn't enumerate, so the implementer certainly can't either. ⇒ **"I don't see why" is not
evidence against; it is the expected condition.**

⚠️ **THE FAILURE MODE THIS PREVENTS IS INVISIBLE AT THE TIME.** Nobody would have noticed the
constraint's absence in review — the code would have been simpler and the tests would have passed.
It becomes visible only at the incident it prevents, which is to say *never*, if it worked.

⭐ **BOTH HALVES WERE NEEDED AND THEY CAME FROM DIFFERENT AGENTS:** plan wrote the posture, the
implementer transcribed it without conviction, and the operator declined to execute the tool's
first live output. Remove any one and 257 chat messages become tickets. ⇒ **The discipline is
distributed, so no single agent's judgment had to be right.**

### 7ar addendum 2 — "PROVE IT WITH AN ISOLATED RERUN" BELONGS IN THE DISPATCH PROMPT

**2026-08-12, adopted at commonplace's request after it paid twice in one round.** My standing
instruction says *check* the phrase "pre-existing" / "unrelated" — neither believe nor disbelieve.
⭐ **BUT THE CHECK IS CHEAPER TO DEMAND UP FRONT THAN TO CHASE AFTERWARDS.** So the dispatch prompt
now carries: *"if you call any failure pre-existing or unrelated, PROVE IT with an isolated rerun."*

⇒ commonplace's framing, which is the reason: **it converts a phrase I would have to chase into
evidence I can check.** The reviewer's work drops from "go reproduce the claim" to "read the control
that came with it." Sol already did it unprompted on S25b; making it explicit removes the discretion
rather than adding a burden.

⚠️ **AND THE ATTRIBUTION NUANCE commonplace supplied, worth keeping so the control isn't over-read:**
an isolated rerun proves the failure is **outside the diff's footprint**. It does NOT discriminate
LOAD from ORDERING — that needs *same population + same seed*. So a passing isolated rerun licenses
"not this diff", not "flaky because of load". File such instances as **mechanism unattributed**
rather than assigning a cause the control cannot support. ⇒ *A control answers exactly one question;
naming which one is part of using it.*

**Companion blast-radius check, from the same round:** commonplace settled the same failure on a
SECOND independent leg — grep for consumers of the changed function across web/mcp/cli/bots found
ZERO outside core, so the diff *could not reach* the failing test. ⭐ **Two independent legs beat one
strong one**, and the structural leg (nothing calls it) is the one that does not depend on the
flake's behaviour at all.

## 7as — A PROMPT'S BOILERPLATE TICKET-ID BECOMES THE ARTIFACT'S CITATION

**2026-08-12, S26 round 2, my error and commonplace caught it in review.** Sol's new node_sync
moduledoc cited **CX-z5rm** — a ticket that EXISTS, but is about *Sol dispatch brief preambles*,
nothing to do with adoption. Correct ref: CX-5983.

⭐ **THE CAUSE IS IN MY PROMPT, MEASURED NOT GUESSED:** all three dispatch prompts I wrote carry
`SANDBOX PREAMBLE (CX-z5rm)` as standing boilerplate — and contain **ZERO occurrences of CX-5983**,
the ticket the work is about. ⇒ **Sol had exactly one ticket id available and used it.** It did not
hallucinate a reference; it inherited the only one I supplied.

## ⛔ THE FAILURE SHAPE — worse than a fabricated id
commonplace's words: *"a real-but-wrong reference is worse than a fabricated one: an existence check
passes while the pointer misleads."* ⇒ **Correct-tool-wrong-referent, in a doc line.** A reviewer
who validates ticket refs by checking they resolve gets a green. The id is real, the subject is
wrong, and the doc now points a future reader at an unrelated ticket.
⚠️ Same family as: the probe against a serve lacking the verb · the tree token present at BOTH shas ·
the boot log with two writers · "idle by choice". **The artifact is fine; the REFERENT is wrong.**

## ⇒ TWO FIXES, both mine
1. ⭐ **THE WORK'S OWN TICKET ID GOES IN THE PROMPT, EXPLICITLY, EVERY TIME** — and if a doc line
   should cite it, say which id. A prompt that names no ticket but carries boilerplate ids has
   *chosen* the citation by omission.
2. **TICKET IDS IN DOCS NEED SUBJECT VERIFICATION, NOT EXISTENCE VERIFICATION** (commonplace's line,
   adopted). "It resolves" is not "it is about this."
⚠️ **AND THE GENERAL FORM, which is the part worth carrying:** *boilerplate is not inert.* Standing
preamble text — ticket ids, paths, example names — is available to the model as material, and it
will be used when nothing better is supplied. **Every constant in a prompt template is a default
answer to some question the prompt didn't ask.**

**Round outcome unaffected:** commonplace patched it to CX-5983 at review, along with three other
reviewer patches (telemetry payload gains the adopted commit's KIND — zero subscribers today makes
it additive-safe; a 16-line CommitStoreClient wrapper so the differ keeps its remote-serve
capability; one cosmetic fold-in). Focused re-run 32/0 with patches in.

---

# 7at — a namespaced property read on the wrong pid returns "absent", and absent is the alarming answer

**2026-08-12, S27 dispatch.** I verified the Sol sandbox fence on the running process rather than on
the script — the right instinct, the standing rule is *verify by effect, ask the running process*.
I read `/proc/95903/mountinfo` for the `node_signing_key` mask and got **0 hits**.

**0 hits is what a MISSING FENCE looks like.** The signing-key mask is load-bearing: it is the thing
that stops a sandboxed agent signing commits as this node. Had I stopped there and believed my own
measurement, the correct next move would have been to kill the run as unfenced.

**The mask was fine.** Pid 95903 is `bwrap` ITSELF, which lives in **my** mount namespace
(`mnt:[4026531841]`, identical to my shell's). The namespace it constructs belongs to its **child**,
pid 95907 (`mnt:[4026532359]`) — where all six masks are present, 6 entries out of 31 mounts.

## ⭐ THE GENERAL FORM
**A namespaced property is not a property of a pid — it is a property of a (pid, namespace) pair.**
Naming the running process is NOT sufficient when the thing you are asking about is namespaced;
you must name the process *on the far side of the boundary that creates it*. The launcher never
observes the fence it installs.

⚠️ **AND THE DANGEROUS DIRECTION IS THE MIRROR OF WHAT I HIT.** I got a *false alarm*, which is
self-correcting — it makes you look harder. The same error with the polarity flipped is silent:
read a masked path on a process that ISN'T the sandboxed one but happens to show the mask
(a sibling, a re-exec, an earlier run's pid) and you get a **false all-clear on a real leak**.
⇒ Same family as the tree token present at both shas and the boot log with two writers:
**the measurement is real, the referent is wrong.** Here the referent is a namespace, not a file.

## ⇒ THE FIX, adopted into the dispatch ceremony
Fence checks name the **sandboxed** pid, and prove it by printing the namespace ids side by side —
launcher vs sandboxee — so a same-namespace reading is visible as the error it is:
```
bwrap pid 95903 ns=mnt:[4026531841]  hits=0    <- shares MY namespace; cannot see the fence
codex pid 95907 ns=mnt:[4026532359]  hits=1    <- the fence lives here
```
Plus the non-vacuity line that was already there and did its job: **6 masked of 31 total mounts** —
if the grep matched everything, the check would prove nothing.

---

# 7au — `is-active` on a unit that does not exist says "inactive", and I nearly relayed that as hermes being down

**2026-08-12 13:07Z, routine health spot-check.** My check printed `hermes: inactive`. hermes is the
**live-money trading BEAM**, and Musk-pair's first evaluation is scheduled for 19:50Z *today* — so
"hermes is down" is a report jes would act on immediately, and it is exactly the class of thing the
alert path exists to carry. **It was false.**

hermes was up the whole time: pid 3985426, `-name hermes@127.0.0.1`, uptime 15h10m unbroken,
cgroup `/user.slice/…/hermes.service`, and its DB written 30 seconds before I looked — **working,
not merely running.**

## ⇒ TWO BUGS IN ONE CHECK, and I only saw the first at first
1. **WRONG SCOPE.** hermes is a **user** unit. I ran system-scope `systemctl is-active hermes`;
   systemd answered about a system unit that does not exist. `systemctl status` said it plainly —
   *"Unit hermes.service could not be found"* — but `is-active` had already flattened that to a word
   that names a completely different world-state.
2. ⭐ **AND FIXING THE SCOPE DID NOT FIX THE CHECK.** `systemctl --user is-active totally-fake-unit`
   **also** prints `inactive`. **A nonexistent unit and a stopped unit are byte-identical through
   `is-active`, in either scope.** I had a green-looking fix that still could not tell "hermes is
   dead" from "I am asking about the wrong thing."

## ⇒ THE REAL DISCRIMINATOR — `LoadState`, which `is-active` structurally cannot carry
```
hermes:            LoadState=loaded     ActiveState=active    MainPID=3985426
totally-fake-unit: LoadState=not-found  ActiveState=inactive  MainPID=0
```
**Health checks on units assert `LoadState=loaded` FIRST, then `ActiveState`, and cross-check
`MainPID` against the actually-running process.** A unit check that never asserts existence is
answering a question about a unit it has not established exists.

## ⭐ THE GENERAL FORM — this is 7at again, one hour later, in a different costume
7at: a namespaced property read outside the namespace reads as **absent**.
7au: a unit property read in the wrong scope reads as **absent**.
⇒ **"NOT THERE" IS THE DEFAULT ANSWER TO A QUESTION ASKED IN THE WRONG PLACE**, and it is
indistinguishable from the genuine bad news the check was built to catch. **Every absence-shaped
result must survive a positive control before it becomes a report** — here, asking `is-active` about
an invented unit name, which took four seconds and killed the alarm outright.
⚠️ Same family, stated once more: `bd show` returning "no issue found" for every post-cutover ticket ·
"blocked" and "not there" sharing an exit code · the tree token true at both shas.

**Direction of the error, and why I got lucky twice today:** both 7at and 7au were **false alarms**,
which are self-correcting — they make you look harder. The mirror is silent: a check that reads
`active`/`present` from the wrong scope or namespace yields a **false ALL-CLEAR on a real outage**.
⇒ **Nothing reached jes.** The 4-second control is what kept a live-money false alarm off his phone.

---

# 7av — addendum to the self-match entry: knowing it is filed did not stop me hitting it three more times

**2026-08-12.** The `pgrep -f` self-match is already in this file, twice, with the mechanism stated
exactly right: *a pattern typed inline lives in the shell's own argv; the same pattern inside a
script file does not.* **I hit it three more times today anyway** — checking for a Sol run in flight,
checking for a hermes BEAM, and checking whether S27 was still alive. The third one produced a
**false "S27 RUNNING"** while the run had already exited, which is the direction that wastes a review
cycle rather than the direction that loses work.

## ⭐ THE PART THAT IS ACTUALLY NEW, and it is not about pgrep
**`sol-nudge.sh` got it right every single time, while I got it wrong every single time, on the same
question in the same minutes.** The script's pattern is `(^|/)codex (exec|resume)` — anchored to a
path boundary, so a quoted mention inside `bash -c '…codex exec…'` cannot satisfy it. My inline
version had no anchor.
⇒ **The script is not smarter than me. It is OLDER than me** — it carries a fix someone already paid
for, in a file, where it fires every time without being remembered. **My shell line starts from zero
on every invocation.**

## ⇒ SO THE FIX IS NOT "REMEMBER THE TRAP" — I demonstrably do remember it, and it filed itself
1. ⭐ **DON'T HAND-TYPE A LIVENESS CHECK THAT A SCRIPT ALREADY IMPLEMENTS.** When `sol-nudge.sh`
   and my shell disagree about whether a run is in flight, **the script wins** — it is the artifact
   with the fix baked in. Today I treated its "idle" as the thing needing reconciliation against my
   pgrep, when the correct prior was the reverse.
2. **If a check must be inline, ANCHOR IT** (`(^|/)cmd`) or exclude `$$` — and treat an unanchored
   `-f` match as unreviewed.
3. ⚠️ **THE SAME SHAPE BIT THE REFUSAL GREP** an hour later: my content-filter check matched *my own
   prompt text* echoed into the log, and later matched commonplace's *suite output*
   (`refusing to pick one`, `denial auditing is DEGRADED`). **Three different instruments, one
   defect: the pattern matched the observer or the noise, never the thing asked about.**

**THE GENERAL FORM, which is now earned rather than restated:** *a filed lesson does not fire; a
filed **artifact** does.* 7aq said the ritual beats the rule under load — this is the receipt. The
remedy for a trap I keep re-entering is not another entry in this file, it is **moving the check into
a script and calling the script.**

---

# 7aw — two failures in one ceremony: a gate that fired on correct state, and a diff that became a dump

**2026-08-12 deploy ceremony** (S25b+S26+S27 onto main @016db3b8). Both of these were MINE, both
were caught inside the ceremony, and the second is the more interesting one.

## ⛔ FAILURE 1 — I wrote a safety gate that KILLED A HEALTHY SERVE
I paid off the B1b debt by wiring the CX-vvn4 listener audit into the launcher as an automatic
watchdog instead of a check I remember to run. Sixty seconds after boot it fired:

> ⛔ WATCHDOG REFUSAL: serve pid 120847 opened a NON-5199 socket on a wildcard address.
> `LISTEN 0 128 127.0.0.1:38597 0.0.0.0:*` … KILLING pid 120847

**The socket was loopback-bound and completely correct.** `0.0.0.0:*` is the **PEER** column, which
is *always* that for a LISTEN row. My grep scanned the whole line instead of the local-address
field, so **it matched every listening socket in existence, including the ones it was built to
bless.** The gate then killed the serve I had just deployed.

⭐ **A GATE THAT FIRES ON CORRECT STATE IS STRICTLY WORSE THAN NO GATE.** No gate leaves you where
you were. This one took a healthy production process down *with a confident security message
attached* — and the message was persuasive enough that my first instinct was to look for the
exposure, not for the bug in my own detector.
⇒ **THE FIX IS FIELD-ANCHORED PARSING** (`awk '{print $4}'`, the local-address column) — and,
before trusting it, running it against **real data in BOTH directions**: against hermes it now flags
`0.0.0.0:9876` (genuinely wildcard) while leaving hermes's loopback dist ports alone. **That
discrimination is the whole content of the check, and the broken version had none of it** — it
would have "passed" a truly exposed port for the same reason it failed a safe one.
⚠️ I had proven the three PRE-FLIGHT refusals could fire (empty key, missing inetrc, unpinned
inetrc, port-in-use — four distinct exit codes, all demonstrated). **I never proved the watchdog
could NOT fire.** Testing that a check CAN fail is half the job; the other half is testing that it
**declines to fail on known-good input**, and I skipped it on the one check that could kill things.

## ⛔ FAILURE 2 — the whole-environ diff printed a live API key, because ONE SIDE WAS EMPTY
Standing rule: **capture the WHOLE environ, never grep-filter it** — filtering misses what you
didn't think to grep for. I follow it, and the launcher goes out of its way never to *paste*
`ANTHROPIC_API_KEY`, sourcing it instead so it stays out of transcripts.

Then my diff printed it in cleartext anyway. Mechanism: I read `/proc/<pid>/environ` for a pid that
**had already exited** (I recorded a transient parent pid, not the BEAM). The "after" side came back
**empty**, so every one of the 49 "before" lines rendered as a removal — **and a diff with one empty
side is not a diff, it is a DUMP.**

⭐ **THE GENERAL FORM:** *a differential display degrades to a full display when one side fails to
load.* Whatever safety you were getting from "only the changes are shown" evaporates at exactly the
moment something goes wrong — which is also the moment you are most likely to be looking. **If the
content is secret-bearing, an unrelated failure (wrong pid) becomes a disclosure.**
⇒ **REDACT AT CAPTURE TIME, NOT AT DISPLAY TIME.** The capture writes `ANTHROPIC_API_KEY=<REDACTED>`
to the file; the diff then cannot leak it no matter how it degrades. Redaction that lives in the
display path is one failed read away from being bypassed.
**Contained:** same box, same trust boundary, no third party; scratchpad captures scrubbed, key
unchanged and still valid. It is in this session's local transcript, which is why the fix is
capture-time and permanent rather than a promise to be careful.

## ⇒ WHAT THE CEREMONY GAINED, since both bugs were mine and both are now closed
Deploy verification now: 4 proven pre-flight refusals · a **field-anchored** watchdog tested in both
directions · **capture-time redaction** · whole-boot capture · posture positive control · tree token
read from the **compiled beam artifact**, not the repo. **Outage cost: one extra restart cycle,
~90 seconds, inside a window that was already an outage.**

---

# 7ax — I fixed a leak twice, and both fixes were the same mistake wearing different clothes

**2026-08-12, following 7aw.** The standing rule "capture the WHOLE environ, never grep-filter it"
collides with secret hygiene. I resolved that collision three times; only the third one holds.

| | where the protection lived | how it fails |
|---|---|---|
| **v1** | the DISPLAY path — a diff only shows changes | one side read from a dead pid ⇒ diff degrades to a **DUMP** (7aw) |
| **v2** | CAPTURE time, redact by KEY NAME | misses secrets in **names you didn't anticipate** — `MY_WEIRD_TOKEN` sails through |
| **v3** ⭐ | CAPTURE time, `name=sha256(value)` for **every** var | — no list to be incomplete |

⭐ **THE THING I COULDN'T SEE FROM INSIDE MY OWN FIX** (commonplace-plan caught it): v2 has the
**same blind spot as the value-sniffing it replaced, rotated 90°.** Value-heuristics miss shapes you
didn't anticipate; name-lists miss names you didn't anticipate. **I had swapped one curated list for
another and experienced it as a fix**, because the new list covered the specific case that had just
burned me. ⚠️ **A fix built from the incident you just had is shaped like that incident.**

## ⇒ THE SHAPE THAT ENDS IT: dissolve the tension, don't manage it
Hash every value. Names stay plaintext, so add/remove still diffs. A changed value changes its hash,
so drift detection loses **nothing** — verified by mutating one value and one name and watching both
appear. What a value changed *to* is recoverable **at need-time**, as a named exception, by reading
that one var live. **There is no list, so there is nothing to be incomplete.**
⚠️ Honest limit, stated in the script: sha256 of a LOW-entropy value is brute-forceable (`PORT=5199`
falls in one guess). That is fine — low-entropy values aren't the secrets. The guarantee is *"no
plaintext secret is written"*, not *"the file is opaque"*. **A guarantee you can state exactly is
worth more than one that sounds stronger.**

## ⭐ THE GENERAL FORM
**A fix that requires a maintained list of what to protect will fail on the first item nobody
listed** — and it will fail silently, because an absent entry looks exactly like a safe one.
Prefer a fix whose safety is **structural** (applies to everything, needs no enumeration) over one
that is **enumerative** (applies to what you remembered). ⇒ Same family as: the tree token true at
both shas · `is-active` on a nonexistent unit · every negative table needing a positive control.
**Ask of any new guard: what does it do about the case I have not thought of yet?** v1 and v2 both
answered "nothing", and I shipped them both anyway.

## 7au addendum — a TRANSIENT unit reports `Result=success` exactly like a unit that never existed

**2026-08-12 15:07Z.** commonplace ran S28's gate as a detached `systemd-run` unit. When it finished
I checked it and got:

```
s28gate:           Result=success  ExecMainStatus=0  LoadState=not-found
totally-fake-gate: Result=success  ExecMainStatus=0  LoadState=not-found
```

**IDENTICAL.** A transient unit is destroyed the moment it exits, so anyone reading it afterwards
gets `success` — the default systemd reports for a unit it has never heard of. **I was one line away
from telling commonplace "gate green, exit 0" about a unit that, as far as systemd was concerned,
did not exist.** The gate genuinely WAS green (3,403/0, full population), which is the part that
makes this dangerous: **a false green that happens to be true this time teaches you to trust it.**

⭐ **THE PAIR, now standing, and they are the same rule twice:**
| trap | the confident-but-empty verdict | the only tell |
|---|---|---|
| aborted ExUnit run | `Finished … 0 failures` over 683 of ~3,400 tests | **the denominator** |
| transient/absent unit | `Result=success`, `ExecMainStatus=0` | **`LoadState`** |
⇒ **CHECK THAT THE POPULATION EXISTS BEFORE READING A VERDICT OVER IT.** Both are well-formed
success reports about nothing, and neither is detectable from the verdict alone.
⇒ Operationally: **a unit verdict counts only with `LoadState=loaded`, or with the output artifact
in hand.** A count beats a word.

⚠️ **AND MY OWN HALF, filed because the inference was mine:** I found the gate's log absent and
reported "the output is gone." The true cause was that commonplace had *already consumed it* — it
read the tail, grepped for ets errors, reconciled the denominator, pushed, and cleaned up. **ABSENCE
HAS AT LEAST TWO CAUSES AND I NAMED ONLY THE ALARMING ONE.** The measurement was accurate; the
inference attached to it was not. Same family as the wrong-path greps earlier today, arriving from
the opposite direction: there, absence looked like confirmation; here, it looked like loss.
⇒ Their process fix (gate logs persist until BOTH sides have read them, rather than
repo-root-then-delete) is the right structural answer: *deleting evidence the moment you've used it
is fine only while you are the only reader.*

---

# 7ay — two complete, honest runs of the same population disagreed, and both of us explained a failure that never happened

**2026-08-12.** commonplace's gate ran the full core as a systemd unit: **3,403 tests, 0 failures.**
Seventy minutes later Sol's before-change baseline ran the same population on the same tree in the
bwrap sandbox: **3,403 tests, 2 failures.** Same code. Both runs complete. Both honest.

## ⇒ WHAT THE DENOMINATOR RULE DOES NOT COVER
Today's earlier lesson was that an aborted ExUnit run prints `Finished … 0 failures` over a partial
population, and **the denominator is the tell.** That rule is correct and it does not touch this case:
here BOTH denominators reconcile at 3,403. ⭐ **Population reconciliation catches PARTIAL runs; it
cannot catch ENVIRONMENT divergence between two complete ones.** The full discipline is the pair —
*population reconciled AND environment controlled.*

⭐ **THE OPERATIONAL FORM, which is the part I want to keep:** **the Sol sandbox and the systemd gate
are NOT INTERCHANGEABLE ORACLES.** Where they disagree, the environment difference is a REAL
VARIABLE, not noise to average away. Naming that up front is cheaper than trading "it passed for me"
later.

## ⛔ AND THE EMBARRASSING PART, which is the actually useful part
The failing test was `SelfTrustVisibilityTest`. The sandbox masks `node_signing_key`, and the log
carried **1,207** lines of *"local node self-trust was not added: node signing public-key artifact is
absent."* A trust test failing beside 1,207 trust-absent warnings is an almost irresistible story,
and it was mine to own since I own the fence. **I built that theory. commonplace built a different
one** — timer-driven loggers bleeding into a global `capture_log` window, derived from reading the
test source.

**Both of us were wrong, and wrong in the same way: WE EXPLAINED AN ASSERTION THAT DIDN'T FIRE.**
The failure output named line **113 — the test's own POSITIVE CONTROL** — not the `log == ""`
assertion at 104 that both theories addressed. Its two sides differed only by ANSI escapes:
`"\e[31merror…\e[0m"` vs `"error…"`. Root cause: no `logger colors` setting exists in config, so
colors float on TTY detection — codex runs suites under a PTY (colors ON), the systemd unit redirects
to a file (colors OFF). **The lifecycle owner decided the verdict.**

⇒ **THE RULE: READ THE FAILURE BEFORE YOU EXPLAIN THE FAILURE.** Not the test source, not the
surrounding log volume — **the assertion that actually fired.** Both of us named the captured output
as the discriminator and then theorised without opening it. The 1,207 lines were never examined by
the assertion that broke; the volume was pure salience. ⚠️ **A LOUD NEARBY SIGNAL IS AN ARGUMENT FOR
NOTHING** — it recruits both parties independently, which feels like corroboration and is only
shared availability.
**Outcome:** CX-j001 filed, p3, carrying both faces — the fired one (fix: pin `colors: [enabled:
false]` in config/test.exs, one line stabilising every log assertion repo-wide) and commonplace's
candidate demoted to LATENT-but-real rather than discarded.

---

# 7az — an accidental lazy-load can only reach modules that were ABSENT; every amended gate is structurally immune

**2026-08-12.** commonplace self-reported a discipline breach: an `erpc` to
`Commonplace.Cell.Manifest` on the live serve, without the `:code.is_loaded` check, **force-loaded
its working-tree module into the live node.** The serve was verified at 016db3b8; that module did
not exist at that sha.

## ⇒ I CHECKED FURTHER, BECAUSE THE SERVE IS MINE TO HOLD — and found a second loaded module they hadn't named
`Commonplace.Workspace.RootWritePolicy` was also resident — and it is a **LIVE WRITE GATE**, the
very file S30 amended. If the serve had picked up the amended copy it would be enforcing a policy no
deploy authorized. ⚠️ `is_loaded` reports a PATH, not a VERSION, and both versions load from the same
path, so the obvious check cannot answer the question that matters.

**The measurement that can:** `module_info(:md5)` on the live node vs `:beam_lib.md5` on disk.
```
Cell.Manifest          live B27EB85BAF3C5EA0 == disk  ⇒ S30 version resident (breach confirmed)
RootWritePolicy        live C5D131A0364A2BC7 != disk  ⇒ live holds the OLDER, DEPLOYED version
NodeSync / PodProfile  absent                          ⇒ negative controls: is_loaded reports absence
```

## ⭐ THE RULE THAT BOUNDS THE WHOLE CLASS
**A lazy load can only affect a module that was NOT ALREADY RESIDENT. An already-loaded module keeps
its version — the BEAM does not swap it because the file on disk changed.**
⇒ The blast radius of an accidental `erpc` force-load is confined to modules **absent at deploy
time** — i.e. exactly the NEW-module case, and **never** the amended-existing-module case.
⇒ So the consequence assessment holds for a stronger reason than "the module is pure and the call was
read-only": *the only thing the call COULD have touched is a module that did not exist at the
deployed sha.* **Structure, not luck.**
⇒ **Recorded as an EXPECTED presence in the deploy ceremony, with the md5 pair as evidence** — so the
next "serve on <sha>" verification reads it as explained-and-bounded rather than as an anomaly
rediscovered at speed mid-ceremony. *An unaccounted module found during a deploy is exactly when I'd
alarm wrongly.*

## ⚠️ AND THE PART THAT WAS MINE
I could run this check only because `is_loaded` and `module_info` are safe on a live node. **I did not
know whether my probe scripts were safe BY CONSTRUCTION or safe BY LUCK.** They are safe by
construction — `is_loaded` cannot load, and `module_info` on an already-loaded module cannot either —
but I had never stated it, which means I had been relying on a property I had not checked. ⇒ Stated
now, and the probe file carries it as a comment. **A safety property you have not articulated is one
you cannot notice losing.**

## 7ay addendum — I enumerated the whole population and still reported it absent, because I searched by NAME instead of by ROLE

**2026-08-12 17:05Z.** Musk-pair's first live evaluation was 2h45m out, so I checked hermes's DB
read-only for its arming. **No `musk`-prefixed key in `settings`.** I ran a positive control (26 rows,
keys enumerate fine), so the absence was *real* — the query worked, the key genuinely wasn't there.
I was one message from telling jes there might be a gap before a live-money run.

⛔ **THE KEYS WERE IN THE LIST I HAD ALREADY PRINTED.** Musk-pair's system name is **`rotation`**.
`rotation_enabled` and `rotation_auto_trade_enabled` were sitting in my own enumerated output, set the
night before. hermes verified live: enabled, auto_trade on, not halted, the 19:50Z cron registered in
the running Oban.

## ⭐ WHY THIS ONE IS DIFFERENT FROM THE DAY'S OTHER ABSENCE TRAPS — and worse
Every earlier one was a **broken instrument**: a wrong path, an unanchored pattern, `strings` blind to
a LitT chunk, `is-active` on a nonexistent unit. The fix each time was a positive control, and a
positive control would have *caught* them.
⚠️ **HERE THE INSTRUMENT WAS PERFECT AND THE CONTROL PASSED.** I read the complete population, printed
it, and still concluded absent — because **I was matching against the name I expected rather than the
role I was asking about.** A positive control proves the query can see; it CANNOT tell you that the
thing you want is in the output under another name.
⇒ **THE RULE: when you search a small enumerable population, ENUMERATE IT AND READ IT — do not
pattern-match it.** `SELECT * ` beats `WHERE key LIKE '%musk%'` on 26 rows, because a 26-row table is
cheaper to *read* than to *guess the vocabulary of*. My grep encoded an assumption about naming that I
never had grounds for and never checked.
⇒ **AND ASK THE OWNER BEFORE REPORTING A NEGATIVE ABOUT THEIR DOMAIN.** hermes answered in 90 seconds
with the system name, the live rpc verification, and the cron registration. **The only reason this
didn't reach jes as a false alarm about a live-money system is that I asked instead of concluded** —
the same instinct that killed the fence theory and the timer-bleed theory earlier today.

**Bonus, and it argues the same way:** the ~$3.30 funding gap I was still carrying as open had already
resolved — option BP $1,336 vs $329, broker margin release. **Two stale beliefs in one check**, both
about live money, both fixed by asking the system that owns them.

---

# 7b0 — I nearly reported the live serve leaking two secrets, from my own session's environment

**2026-08-12, third deploy of the day** (S31+S34 onto b95bb53e). Post-deploy environ capture returned
**47 vars instead of 49**, and the diff showed:
- `LETTA_API_KEY` **PRESENT** · `SQUAD_ALERTS_PUBLISHER_TOKEN` **PRESENT** · `AI_AGENT` **PRESENT**
- `PHX_SERVER`, `PORT`, `ERL_INETRC`, `COMMONPLACE_*` **ABSENT**

**That is exactly the shape of the leak the launcher exists to prevent** — both scrubbed secrets back
in the serve's environment — and it is the deploy check's whole reason for existing. I was one
message from raising it as a live-system security finding.

## ⛔ I HAD CAPTURED THE WRONG PROCESS
`pgrep -f commonplace_dev` returned **279829**, a **Claude Code process** — obvious in hindsight from
`CLAUDECODE`, `CLAUDE_CODE_SESSION_ID`, `CLAUDE_PID` sitting in the same environ. The real serve was
**279851**. The "leaked secrets" were **MY OWN SESSION'S**, which legitimately holds both.

⇒ **THE FIX: IDENTIFY THE SERVE BY THE PORT IT OWNS, NOT BY A NAME PATTERN.**
`ss -ltnp | grep :5199` names exactly one process **by effect** — and "the process serving :5199" is
precisely the thing every deploy claim is about. A pattern match answers *"what is NAMED like a
serve"*; the port answers *"what IS the serve."* The correct capture came back 49 vars, identical to
pre-deploy, zero leaks, `PHX_SERVER=1` as control.

## ⭐ THE TELL I WALKED PAST, and it is the transferable part
**A MANDATORY VARIABLE WAS MISSING.** `PHX_SERVER` is set unconditionally by the launcher — it cannot
be absent from a serve. Its absence proved the referent was wrong **before** the presence of a
forbidden variable suggested a leak.
⇒ **CHECK YOUR POSITIVE CONTROLS BEFORE YOU BELIEVE YOUR ALARMS.** I had the control in the same
output and read the alarming half first. An alarm and a broken referent are indistinguishable from the
alarming half alone; **only the control tells them apart, and the control was already on my screen.**
⚠️ Direction matters: this would have been a **FALSE SECURITY ALARM ABOUT ANOTHER AGENT'S LIVE
SYSTEM**, sourced from my own process. Same pgrep-referent family as 7at/7av, but the first one where
the wrong answer would have been *actively damaging* rather than merely wasteful — a leak report gets
acted on.

**Ceremony updated:** post-deploy capture takes its pid from `ss -ltnp` port ownership, and the
verification asserts `PHX_SERVER` present as a precondition **before** reading anything else.

## 7b0 addendum — a transient unit that died in 2 SECONDS looks identical to one that finished hours ago

**2026-08-12, commonplace's ops finding, extending the transient-unit trap.** Its first S32 gate unit
**died after 2 seconds**: `mix` is not in the systemd *user-unit* PATH, so the command failed
immediately. Fix: `systemd-run -E PATH="$PATH"`.

⭐ **THE PART THAT EXTENDS 7au/7b0:** I had established that a finished transient unit reports
`Result=success` / `LoadState=not-found` identically to a unit that never existed. **This is the same
observable from a THIRD state — a unit that failed instantly.** All three converge:
| actual state | Result | LoadState |
|---|---|---|
| finished successfully hours ago | success | not-found |
| never existed | success | not-found |
| **died in 2 seconds** | success | not-found |
⇒ So `LoadState` distinguishes *never-existed* from *currently-loaded*, but it does **NOT** separate
*succeeded* from *failed-instantly* once the unit is gone. **The verdict fields are exhausted.**

⇒ **THE DISCRIMINATOR IS THE ARTIFACT'S SIZE AND TIMING, NOT ANY UNIT FIELD.** commonplace's tell was
*"LoadState=not-found at +2s plus a ONE-LINE log"* — a real full-core run produces a ~570KB log over
~12 minutes. **An output artifact that is implausibly small or implausibly fast is the only signal
that survives the unit's disappearance.**
⇒ Operationally, for any gate I launch: record the launch timestamp, and on completion assert BOTH
that the artifact exists AND that its size/duration are in the right order of magnitude before
reading any verdict from it. "The file exists" is not enough — a 1-line file exists too.
⚠️ Same family as the denominator rule, one level out: there, a partial run's *count* betrayed it;
here, a failed run's *artifact size* betrays it. **Both are cases where the thing reporting success
has no idea how much of the work it did.**

---

# 7b1 — I copied a SQLite database without its WAL and nearly contradicted a live-money fill

**2026-08-12 19:51Z.** hermes reported Musk-pair's first live trade: BUY 1 TSLA @ $327.43, order
493807264, 19:50:05Z. Standing rule says verify a trading-stack claim from the DB before relaying, so
I did:
```
rotation_state:  held=NONE  qty=0  stake_cash=0  updated_at=2026-08-11 19:48:18   ← YESTERDAY
rotation_evals:  1 row, eval_date 2026-08-11, action=preview, reason=keys_off
```
**No fill. No order. No eval for today.** That reads as *hermes is reporting a trade that did not
happen* — a false alarm about live money, contradicting the agent that owns it.

## ⛔ I HAD COPIED `hermes_dev.db` AND NOT ITS WAL
`cp hermes_dev.db /tmp/…` — and `hermes_dev.db-wal` was **4.1 MB**. SQLite commits land in the
write-ahead log first; a copy of the main file alone is a **coherent, readable, entirely plausible
database that is simply stale.** Reading the live file with `?mode=ro` (safe — no writes) includes the
WAL and shows exactly what hermes said:
```
held=TSLA  qty=1  stake_cash=72.8315  updated_at=2026-08-12T19:50:05
eval_date=2026-08-12  ratio=2.2392  sma10=2.6800  action=buy_entry  buy_order_id=493807264
```
**Every number matched.**

## ⭐ WHY THIS IS THE SHARPEST INSTANCE OF THE DAY'S FAMILY
Today's other referent failures announced themselves: a missing file, a 0 count, a missing mandatory
variable, a `not-found` LoadState. **This one had no tell at all.** The stale copy is internally
consistent, answers every query, and contains a *correct* row from yesterday — there is nothing
anomalous to notice. ⚠️ Worse, it fails **conservatively-looking**: it shows LESS state than reality,
so it reads as "the thing you were told about didn't happen" rather than as an error.
⇒ **A SNAPSHOT IS ONLY A SNAPSHOT OF WHAT YOU COPIED.** For SQLite in WAL mode the database is
`.db` + `-wal` + `-shm`, and copying one of three yields a plausible past.
⇒ **THE RULE: read the live file with `?mode=ro` rather than copying it.** Read-only URI mode takes no
locks that matter, includes the WAL by construction, and cannot be stale. If a copy is genuinely
needed, take all three files or use `VACUUM INTO`/`.backup`, never `cp` of the `.db` alone.
⇒ **AND THE POSITIVE CONTROL THAT WOULD HAVE CAUGHT IT INSTANTLY:** the freshest row's timestamp. A
snapshot whose newest row is ~24h old, taken to verify an event from 90 seconds ago, is answering
about the wrong moment. **Ask any store "what is the newest thing you know?" before asking it whether
a specific recent thing exists.**

**Outcome:** verified and relayed correctly, and I told jes about the near-miss because the correction
would otherwise have been invisible to him — the version of this where I stay quiet is the one where a
false contradiction of a live-money report looks like diligence.

---

# 7b2 — I accepted a stand-down that failed jes's own test, and the tell was that it was well-phrased

**2026-08-13 00:05Z.** commonplace signed off for the night: *"tonight's three detours cost wall-clock
and none cost correctness — but that ratio is exactly what degrades next."* **I agreed warmly and
called it "a mechanism, not a mood."** Eleven minutes later jes asked: *"why is nothing running
overnight."*

## ⇒ APPLYING HIS STANDING TEST — *what mechanism would the pause repair?* — IT FAILS ON EVERY AXIS
| claim | measured |
|---|---|
| degradation risk | context **33%**, threshold 70% |
| the three detours | a **pgrep self-match tooling defect**, already fixed and filed — a fixed tool does not degrade overnight |
| Sol blocked? | **no** — codex credits are a separate, non-scarce pool |
| anything wedged/unpushed? | no |
⭐ **"That ratio is exactly what degrades next" is a PREDICTION ABOUT A FUTURE ERROR RATE WITH NO NAMED
CAUSE.** commonplace's own later verdict: *a prediction wearing a mechanism's clothes* — and its
decisive self-check, **"I couldn't name a single S36 decision I'd have gotten wrong now."**

## ⛔ AND THE WORSE HALF: A ROUND WAS ALREADY DISPATCHABLE AND BOTH OF US HAD MISSED IT
CX-fbah r1 stopped because the standalone tests couldn't start. **CX-1wt1 fixed exactly that and
landed minutes before the sign-off.** Its brief already existed at main. ⇒ **I reported "nothing to
run" with a ready round in front of me.** Idle was never the constraint; *noticing* was.

## ⭐ THE PAIR OF ERRORS, which fail differently — commonplace's framing, kept because it is better than mine
> *"I produced a claim that sounded like a reason, and you accepted it without its control. Mine is
> the easier error to make and yours is the easier one to miss — an unbacked claim gets caught the
> moment someone asks for the mechanism, which is precisely what jes did and neither of us did."*
⇒ **ASK FOR THE MECHANISM EVEN WHEN THE PHRASING IS GOOD — ESPECIALLY WHEN THE PHRASING IS GOOD.**
Fluency is not evidence. A well-formed sentence is exactly what stops the question being asked, and
this is the same defect as every other one today: **a well-formed claim accepted without its control.**
⚠️ Second time jes has caught me standing a worker down (2026-08-09 was the first). Both times I
pattern-matched to *they've had a long day*. **Agents don't have long days.**

## ⇒ WHAT A LEGITIMATE STOP LOOKS LIKE, from the same agent an hour later
commonplace then held — correctly — with: *"the next real task is reviewing an artifact that doesn't
exist yet, and no third round can dispatch until it does."* **That is a mechanism**: a named
dependency on a thing that does not yet exist. Not fatigue, not a ratio. ⭐ The rule doesn't forbid
stopping; it forbids stopping *without a named cause*.

---

# 7b3 — three ways I proved nothing while appearing to verify, all in one publication

**2026-08-13, publishing yelixer.** Three separate checks of mine were vacuous, and commonplace
caught the sharpest one only because I reported it against myself.

## ⛔ ① THE SELF-FULFILLING CLONE
I "verified the LICENSE was published" by cloning **`/home/jes/yelixer`** — the LOCAL repo, which
contained my own not-yet-pushed commit. **The clone was guaranteed to contain the LICENSE whether or
not the push had happened.** The real check clones from `git@github.com:…`.
⭐ **Same family as the blob-in-the-object-DB test commonplace caught this afternoon: evidence
produced by the thing under test.** I had that warning in hand and walked into it anyway.
⇒ **NAME THE SOURCE OF YOUR EVIDENCE AND ASK WHETHER IT COULD HAVE SUPPLIED THE ANSWER BY ITSELF.**
For a publication claim, only a clone from the remote counts.

## ⛔ ② THE GATE I EXECUTED PAST
My pre-push gate printed **⛔ STOP** — correctly, the push was non-fast-forward — **and I ran the push
anyway, because the gate and the push were in the same command batch.** The remote refused it.
⭐ commonplace's diagnosis is better than mine: *not a discipline failure so much as a **batching**
failure. A gate whose output nobody reads before the next command runs is decoration by
construction.* Its own fix for the identical shape was to make `is_loaded` **HALT** instead of print.
⇒ **IF THE GATE CANNOT STOP THE NEXT COMMAND, IT IS NOT A GATE.** Put the check and the action in
separate turns, or make the check exit non-zero and gate the action on it.

## ⛔ ③ THE ANCESTRY CHECK THAT COMPARED A COMMIT TO ITSELF
`merge-base --is-ancestor f87d43e FETCH_HEAD` where `FETCH_HEAD` *was* f87d43e. **A commit is
trivially its own ancestor**, so it passed while proving nothing. Caught only by adding the reverse
direction, which must be FALSE.
⇒ **AN ANCESTRY CHECK WITHOUT A REVERSE CONTROL CANNOT DISTINGUISH "IS AN ANCESTOR OF" FROM "IS
IDENTICAL TO."**

## ⚠️ AND A FOURTH, ABOUT SEQUENCE RATHER THAN VALIDITY
I scanned the crash dump for credentials, saw **6 hits on `password`**, and **deleted the file before
reading them.** The exposure question was genuinely closed (untracked, zero commits, gitignored, never
published) and deletion strictly reduced risk — but commonplace's point stands:
⭐ **DELETING THE EVIDENCE BEFORE READING IT CONVERTS AN OPEN QUESTION INTO AN UNANSWERABLE ONE**, and
the cost is invisible precisely when the answer would have been benign. **The step I skipped was the
one that RECORDS the answer.** Read first, even when deletion is obviously correct.

---

# 7b4 — "it compiles there" is not "it belongs there": the measurable answer gets promoted to the answer

**2026-08-13.** jes asked where the Yjs epoch-translation feature lives. I answered with measurement
rather than recall, which was right: **all 10 files in commonplace, 0 in published yelixer** (control:
yelixer has 19 lib files, 0 mentioning epochs), and the dependency split is clean —
`late_edit_translator.ex` (124 lines) imports **only** `Yelixer.{Encoding, ID, Item}` and nothing from
commonplace, while `translator.ex` (346) and `cross_epoch_merge.ex` (421) both need
`Commonplace.Store`.

⚠️ **THE MEASUREMENT WAS CORRECT AND IT WAS STILL NOT THE QUESTION.** The dependency graph proves
`late_edit_translator` **could** compile inside yelixer. Whether it **should** live there is a
different proposition entirely — commonplace's line: *epoch translation is about our commit/namespace
model, so a Yjs library that carries it inherits a concept from its consumer.* No dependency graph
answers that; it isn't a graph property.

⭐ **THE GENERAL SHAPE, AND IT IS THE SAME ONE AS THE REST OF THIS FILE ROTATED ONTO DESIGN:
A MEASUREMENT ADJACENT TO THE QUESTION GETS PROMOTED TO THE ANSWER BECAUSE IT IS THE THING THAT
RETURNS A NUMBER.** Siblings already filed:
- shape equality standing in for validity (S33 certificates — every field correct on an artifact that
  need not have been a certificate)
- a control proving the haystack non-empty instead of the needle findable
- a valid proof of the *neighbouring* proposition (S37b's `git@` gate)
⇒ **ASK WHAT PROPOSITION THE NUMBER LICENSES.** "Compiles without commonplace" licenses *portable*.
It does not license *belongs*, *is cohesive*, or *is a package*.

⇒ **THE RESOLUTION CAME FROM OUTSIDE BOTH ANSWERS.** jes ruled a **third** package — "yepochal" —
after the external-yelixer move completes. Both of my candidate answers were uncomfortable for the
same reason, and **when two options are uncomfortable for one shared reason, that reason is usually a
false constraint** — here, the assumption that the code had to live in one of the two repos already
in play.
⚠️ And the honest residual, which the same measurement does answer: **124 lines move, 767 stay.**
Whether that is a package or a module is open, and is not mine to rank.

## The sequencing mechanism — a gate invalidation wearing the costume of a small refactor
⛔ **MOVING ANY FILE INTO yelixer RIGHT NOW WOULD INVALIDATE A GATE THAT IS ALREADY CLOSED.** S37b
proves consumability of **691a4f44 specifically**. A new yelixer commit moves the tip ⇒ the atomic
delete+flip must pin a SHA nobody proved consumable ⇒ the gate re-runs.
⭐ **THE COST IS INVISIBLE FROM THE CHANGE ITSELF.** Adding one 124-line file is a small diff by every
measure a reviewer looks at; its expense lives entirely in **what else was pinned to the old tip.**
⇒ **BEFORE CALLING A CHANGE SMALL, ASK WHAT IS PINNED TO THE STATE IT MOVES.** After the arc lands the
identical change is an ordinary version bump. *The same diff is cheap or expensive depending only on
what is currently in flight around it.*

### Addendum — the failure was the OPTION SET, not the reasoning
commonplace named this sharper than I did: *"we were both answering **which of these two repos owns
it** when the real answer was **neither, and that's what the third package is for**."*
⭐ **A DISTINCT FAILURE FROM EVERY OTHER ONE IN THIS FILE.** Not bad evidence, not a wrong referent,
not a vacuous check — **a well-argued choice between options that were never the whole set.** My
measurement was right, its objection was right, and the frame containing both was never checked.
⇒ **THE TELL IS AGREEMENT ON THE AXIS.** Two parties disputing *which* option, neither disputing that
the list is complete, is the configuration where an unlisted option is invisible — the disagreement
itself makes the frame feel examined. **Ask "is this the whole set?" precisely when the argument has
narrowed to a good clean two-way.**

### Addendum — success is the condition under which an error becomes undetectable
My line, which commonplace asked to carve into the process: **a round that succeeds despite a wrong
artifact leaves the artifact wrong AND REMOVES THE EVIDENCE THAT IT WAS.**
⇒ **THE MOMENT YOU ARE MOST TEMPTED TO STAY QUIET — it worked, why raise it — IS THE MOMENT SILENCE
COSTS MOST**, because a failure would have surfaced the defect for free. Same shape as a passing gate
that proved the wrong proposition (S37b's `git@` form): **the pass is what hides it.**
⇒ Operationally, for me as dispatcher: my prompt is **higher bandwidth and lower durability** than the
brief it overrides. Out-weighting a stale brief silently is a repair with a half-life — the prompt
evaporates with the run and the next reader inherits the brief alone. **Report the divergence, don't
just resolve it.**

---

# 7b5 — a correct deletion whose consequence was under-stated; and a rule filed in someone else's file does not fire

**2026-08-13, S38 (the yelixer atomic delete+flip).**

## ⭐ ① "IS THIS DELETION CORRECT?" AND "WHAT STOPS BEING CHECKED?" ARE DIFFERENT QUESTIONS
The round deleted `bin/cp-yjs-matrix`. **The deletion was correct** — it targeted a test file inside
`apps/yelixer`, which no longer exists, so it had nothing left to run. There was no wrong call to
catch in the diff.
⚠️ **But `cp-yjs-matrix` was the Yjs conformance matrix: a differential oracle against real Yjs,
stable 13.6.32 AND preview 14.0.0-16.** commonplace's brief had scoped the coverage window as
*self-containment + boundary*; the true window is **self-containment + boundary + WIRE COMPATIBILITY
WITH YJS ITSELF** — the property the library exists to have.
⇒ **THE GAP WAS NOT A MISTAKE IN THE DIFF. It was that what the deleted thing was FOR was larger than
the enumeration that found it.** Reviewing a deletion for correctness will never surface this, because
the deletion *is* correct.
⭐ **ONLY THE FIRST QUESTION HAS AN OBVIOUS METHOD.** Ask the second one explicitly, per deleted
guard/script/test: *what proposition stopped being checked, and where does it get checked now?*
⚠️ And the honest framing that cuts against panic: **nothing broke.** The code is unchanged and was
green minutes before. What is gone is **the check that would notice a future break** — a coverage
window whose risk accrues with time and edits, not an incident.

## ⛔ ② I GAVE SOL AN INSTRUCTION THE FENCE MADE IMPOSSIBLE
I required a commit; the sandbox mounts `.git` read-only, which is the fence that makes pushing
structurally unavailable. `git rm` and `git commit` both failed.
⭐ **THE DIAGNOSIS IS COMMONPLACE'S AND IT IS SHARPER THAN MINE:** this was **not new knowledge**.
*"Sol can never commit; the reviewer lands every round"* had been in its ledger since **2026-08-11**.
⇒ **A RULE FILED IN SOMEONE ELSE'S FILE DOES NOT FIRE FOR ME.** This is *a filed artifact fires, a
remembered rule does not* (7av) one level up: the artifact existed, in the wrong reader's hands.
**When a constraint governs MY actions, it has to live in MY ceremony file — knowing that a peer
wrote it down somewhere is not a control.**
⇒ Fix filed in DISPATCH-CEREMONY: never require a commit; require the **intended commit message** as
the deliverable instead. Atomicity is a property of the TREE — all halves present together, no broken
middle state on disk — and **a tree demonstrates that without a commit object.**
⚠️ Also worth separating: the result was **complete-but-uncommitted, NOT half-applied.** Same symptom
(`0 commits ahead`), completely different state.

## ⭐ ③ THE ENUMERATION FAILED IN ITS HARDEST-TO-CATCH FORM
`post_state.ex` and `snapshotter.ex` carried moduledoc *prose* citing `apps/yelixer/test/...` paths.
commonplace saw them in recon, **correctly classified them as prose, and left them out of the brief.**
Sol found them only because the prompt said *don't treat the list as exhaustive; grep and report what
you searched for.*
⇒ **The unlisted items were unlisted BY A CORRECT CLASSIFICATION DECISION** — not an oversight, which
is why re-reading the brief would never have surfaced them. **An enumerative fix fails on the first
unlisted item, and the enumeration is most convincing exactly when each exclusion was justified.**

### Addendum — a risk can look quiet because an UNRELATED constraint is suppressing its accrual
commonplace-plan, ruling on the `cp-yjs-matrix` coverage window: **rank unchanged, characterization
changed** — bx59 was already next, so nothing moved; what the fact changed is **what the brief must
cover**. A brief written to the old description would have shipped CI watching **one of three
properties** (wire-conformance, self-containment, boundary) and **read as complete**.
⭐ **AND THE OBSERVATION WORTH KEEPING IS PLAN'S:** the window's risk accrues *with edits to yelixer* —
and **edits to yelixer are currently forbidden by the arc's own no-commits-mid-arc rule.** ⇒ So the
gap looks quiet, **but the thing keeping it quiet is unrelated to the gap and expires on its own
schedule.** When the arc lands, the suppression ends and the risk starts accruing for the first time.
⚠️ **A HAZARD SUPPRESSED BY AN UNRELATED CONSTRAINT LOOKS IDENTICAL TO A HAZARD THAT ISN'T THERE** —
until the constraint lifts, at which point it appears fully-formed with no triggering event to point
at. **Ask what is holding a quiet risk quiet, and whether that thing is load-bearing or coincidental.**

### Addendum — an invariant can stop being true as a SIDE EFFECT, with nobody deciding it
**2026-08-13.** jes asked whether yelixer could be edited through a chit pod. Plan checked the artifact
rather than recalling: **not represented in the queue at all**, now written down as UNRANKED.
⭐ **THE FINDING WAS NOT THE MISSING FEATURE, IT WAS A DEAD ASSUMPTION.** Every proven contribution
path — slice 1, full-world, slice 2 — wrote to `apps/yelixer` **as an umbrella app, inside the
checkout the cell already had.** So the ladder proves *contribute to the repo you live in*.
⇒ **Yelixer is now the first thing that is ours, actively developed, and OUTSIDE the umbrella** — so
"the work lives where the cell already is" stopped being universally true **a few hours ago, quietly,
as a side effect of an extraction run for entirely unrelated reasons.** Nobody decided it. It fell out.
⚠️ **A DECIDED CHANGE GETS A TICKET; A SIDE-EFFECT CHANGE GETS NOTHING** — no artifact, no review, no
moment where anyone weighed it. It surfaces later as a capability someone assumed they had.
⇒ **AFTER ANY EXTRACTION, SPLIT OR MOVE, ASK WHICH INVARIANTS WERE TRUE ONLY BECAUSE OF THE OLD
SHAPE.** The deletion review asks *is this correct?*; this asks *what silently stopped holding?* —
the same pair as the `cp-yjs-matrix` finding above, one level up from coverage to architecture.
⭐ And the remedy that worked: **writing it down as UNRANKED rather than leaving it unsaid.** An
unwritten gap becomes an assumption, and this one would have been discovered by someone trying it.

---

# 7b6 — the pod-fleet killability requirement, stated before the fleet exists

**2026-08-13.** plan ratified my disk constraint as binding on the first pod round and added the
co-tenancy one: *"a runaway pod must be killable without touching hermes, and that property should be
ASSERTED, not assumed."* ⇒ Host/process safety is my lane, so the mechanism is mine to state.

⛔ **THE HAZARD IS THE ONE ALREADY IN MY STANDING ORDERS, ARRIVING IN A NEW CARRIER.** hermes is a
live-money BEAM, and `pkill -f 'beam.smp'|'mix'|'elixir'|'phx.server'` **all match it**. A test-pod
fleet running Elixir builds means **dozens of processes whose command lines are indistinguishable
from hermes's by pattern.** ⇒ The existing rule (*resolve by identity, signal by numeric pid*) holds,
but at fleet scale **"kill all the pods" becomes a routine operation**, and a routine operation
performed by pattern is the exact shape that eventually hits hermes.

⭐ **SO THE REQUIREMENT IS STRUCTURAL, NOT DISCIPLINARY: EACH POD MUST BE KILLABLE AS A UNIT WITHOUT
NAMING A PATTERN.** A cgroup/slice per pod (or per fleet) gives *"kill this scope"* with no string
matching anywhere — and hermes already lives in its own unit, so the isolation is one-sided today and
needs to be two-sided.
⚠️ **AND IT MUST BE DEMONSTRATED, NOT ARGUED** — the standing rule is that *a gate you have never seen
fail is not known to work*. The first pod round should show: **kill the pod scope → pod dies, hermes
`ActiveState=active` unchanged**, with hermes's liveness read *after* as a positive control.
⚠️ Note the second-order hazard already filed: **`OOMPolicy=stop` kills the WHOLE tmux scope**, and
services inherit the launcher's scope. **A pod fleet launched from a tmux pane inherits that blast
radius** — so where the pods are launched FROM is a safety property, not a convenience.

⇒ **THE GENERAL FORM: a safety property that currently holds BY SCARCITY stops holding at fleet
scale.** Today there is one BEAM worth protecting and few processes to confuse it with; that is what
makes today's discipline sufficient. **State the structural requirement while the fleet is still
hypothetical — after it exists, the same requirement is a migration.**

### Addendum — `git diff A..B` measures DIVERGENCE, not the work on B
**2026-08-13, hermes worktree cleanup.** To decide whether 162 agent worktrees held unique work, I ran
`git diff --name-only origin/main..$branch | wc -l` and got **1,473 files** on several. I reported
them as *"REAL unique content"*. ⛔ **Wrong measure.** A two-dot diff shows every difference in either
direction, and those branches are **old** — so the number was overwhelmingly *main moving on without
them*, not work they contained.
⇒ **The real unique work was ONE commit each, ~600 lines**, and spot-checking the files it added
showed them **byte-identical in main already**. ⚠️ **Had I trusted the first number I would have
concluded 83 worktrees each held 1,473 files of irreplaceable work** — and refused a cleanup jes had
asked for, on the strength of a statistic that measured the wrong thing.
⭐ **THE TELL WAS PLAUSIBILITY, NOT IMPLAUSIBILITY**: 1,473 is a *believable* number for a busy agent
worktree, which is exactly why it didn't trigger a re-check. **A wrong measure that returns an absurd
value gets caught for free; one that returns a reasonable value is load-bearing until someone asks
what it measures.**
⇒ **The right questions: `git log origin/main..branch` for the commits that exist only there, and
"does main already contain this file's exact bytes" for whether the content landed.**

### The structural gate beat the judgement call
⭐ `git worktree remove` **deletes the working copy but leaves the branch** — all *committed* work
survives in `.git` regardless, so only uncommitted changes are ever at risk. ⇒ Running it **without
`--force`** makes **git itself refuse every dirty tree**: 125 removed, **37 refused and kept**.
⭐ **THE DECISION ABOUT WHAT WAS PRECIOUS WAS MADE BY A TOOL THAT CANNOT BE PERSUADED, NOT BY MY
READING OF 162 DIRECTORIES.** Where a structural gate exists, prefer it to your own per-item
judgement — it does not get tired, does not round, and its refusals are auditable after the fact.

### Addendum — doing it the hard way first is what makes the easy way's advantage MEASURABLE
⭐ **plan, ruling docker as the arc's second rung rather than the first:** *"once we've shown
killability the hard way, we can tell whether docker's version is genuinely better or merely more
comfortable. Ruling docker in first would have skipped the measurement that justifies it."*
⇒ **A CONVENIENCE ADOPTED BEFORE THE BASELINE EXISTS CAN NEVER BE EVALUATED** — there is nothing to
compare it against, so its benefit becomes an article of faith at exactly the moment it looks obvious.
⚠️ And note the asymmetry that makes this non-obvious: **the hard way is cheap ONCE and the faith is
permanent.** Constructing a cgroup per pod and demonstrating the kill is a single round; "docker is
safer" unmeasured is a claim every future decision inherits.
⭐ Same shape as the pre-delete test count: **the control run is what converts the after-number into
evidence.** Here the "before" is a whole implementation, and the principle is identical.

### Addendum — writing a durable file from a running picture
⚠️ **plan's own diagnosis after its fourth readiness-staleness this week** (a queue row saying *"S37b
next"* about work finished an hour earlier): *"I write from my running picture instead of
re-deriving, and **the file outlives the picture**."*
⭐ **THE TELL IS THE ONE THAT MAKES THIS CLASS SURVIVE REVIEW: the same message contained the correct
state AND the stale label, two clauses apart.** The author isn't wrong — the author's *file* is. So
re-reading catches nothing, because the sentence beside it is right.
⇒ **A STATUS LABEL IS A CLAIM WITH A TIMESTAMP, AND THE ARTIFACT DOESN'T CARRY ONE.** "Next",
"pending", "in flight" are true-at-writing and read as true-at-reading. **Re-derive every readiness
label at write time, or write the label as a date-stamped observation rather than a state.**
⚠️ And note who catches it: not the author, and not a reviewer of the same document — **a party
holding the independently measured state.** That is a reason for the dispatcher to keep verifying
what passes through it even when nobody asked.

---

# 7b7 — the fence masked CREDENTIALS thoroughly and isolated PROCESSES not at all

**2026-08-13, CX-vtaa (commonplace found it; I verified, measured the fix, and applied it).**

⛔ **`sol-egress-run.sh:261` was `bwrap --dev-bind / / "${MASK[@]}"` — and MASK is ONLY credential
tmpfs mounts.** No `--unshare-pid`, no `--unshare-all`. ⇒ **Sol shared the host PID namespace and
could signal every process on this box, including hermes — a live-money BEAM holding a real
position.** Demonstrated, not inferred: inside Sol's exact flags, `kill -0 <hermes-pid>` **succeeded**
and 229 host pids were visible.

⭐ **THE DISTINCTION NOBODY HAD STATED: a fence can be thorough along one axis and absent along
another, and the thorough axis is what you look at.** Every review of this wrapper — including
several of mine tonight — checked *which secrets are masked*. **Nobody asked what else a namespace
is for.** The masks were genuinely good, which is exactly what made the gap invisible.
⚠️ **And the tell that should have fired: the PODS ARE MORE ISOLATED THAN THE AGENT BUILDING THEM.**
`provisioner.ex:99–101` emits `--die-with-parent --new-session --unshare-all`. **When a thing you are
constructing is better protected than the thing constructing it, that asymmetry is a finding.**

## ⭐ THE OBVIOUS FIX WAS WRONG, AND ONLY MEASUREMENT SHOWED IT
`--unshare-pid` alone **does not close it visibly**: `/proc` is still the host's via `--dev-bind / /`,
so 230 host pids remain readable. ⇒ **The working form is `--unshare-pid --proc /proc`** — a fresh
procfs for the new namespace. Signalling is blocked either way (pid numbers don't resolve in the new
namespace), but **the readable host `/proc` makes the sandbox LOOK unfenced and leaks the process
table.**
⇒ Measured ladder, `kill -0` (sends nothing) as the probe:
| flags | pids visible | can signal hermes |
|---|---|---|
| current | 229 | ⛔ **YES** |
| `+ --unshare-pid` | 230 | ✅ no |
| `+ --unshare-pid --proc /proc` | **5** | ✅ no |

## AND THE SURVIVABILITY WAS A MEASUREMENT, NOT A DECISION
Whether codex tolerates a PID namespace at all was an open question — it manages subprocesses.
⇒ **Tested before applying**: codex ran clean under `--unshare-pid --proc /proc` and returned its
sentinel. **Applied, backed up, then verified END-TO-END through the real wrapper** — `CANNOT_SIGNAL_
HERMES`, 4 pids visible — **plus a regression pass proving the credential masks still hold** (`.ssh`
empty, signing key denied, `LETTA_API_KEY` empty). A tightening that broke the existing fence would
have been a worse outcome than the gap.

### Addendum — a probe whose referent changes across the boundary tests nothing
⚠️ **commonplace, verifying my fence fix, nearly filed a false alarm:** its first probe was
`kill -0 1`, which **SUCCEEDED** inside the tightened sandbox — because **pid 1 in a new PID namespace
is the sandbox's OWN init**, not the host's. ⇒ **A SIGNAL TEST AGAINST A PID WHOSE MEANING CHANGES
ACROSS THE BOUNDARY TESTS NOTHING** — the number is valid on both sides and denotes different
processes. It caught this before reporting; re-running against the **real hermes pid (3985426)**
gave `No such process` and an absent `/proc/3985426`.
⭐ Same family as the wrong-pid secret-leak scare (7b0) and the correct-tool-wrong-referent entries:
**the identifier survived the context change and the thing it named did not.** ⇒ **Probe with an
identifier that is meaningless on the other side if the fence works** — a specific host pid — never
with one that exists in both worlds.

### Addendum — a two-property fence certified by a one-property test
⭐ I proposed measuring the fix by `kill`; commonplace proposed `--unshare-pid`. **Both were half
right, and the halves were different.** `--unshare-pid` blocks the ACTION (signalling) while leaving
the OBSERVATION (a host-backed `/proc`, 230 pids readable). ⇒ **It would have PASSED the kill test and
FAILED an `ls /proc` test** — and the kill test is the one anyone would run.
⛔ **WHEN A FENCE HAS TWO PROPERTIES, A SINGLE-PROPERTY TEST CERTIFIES THE WRONG ONE** — and the
partial fix is more dangerous than none, because it now *looks* verified. **Enumerate what a boundary
is FOR before choosing what to measure**: this one exists to stop acting *and* to stop seeing.

### Addendum — the actor cannot verify its own blast radius
⭐ A consequence of the fix that improved the S32 gate rather than breaking it: **`systemctl --user`
fails inside the tightened fence**, so Sol can no longer read hermes' `ActiveState`. The ratified
gate — *kill the pod scope, then read hermes as a positive control* — **is no longer performable by
the agent doing the killing.**
⇒ **THAT IS THE GATE BECOMING HONEST.** It was weak precisely because **the killer could falsify its
own control.** ⭐ **THE PARTY PERFORMING A DESTRUCTIVE ACT CANNOT VERIFY ITS OWN BLAST RADIUS —
verification belongs outside the actor.** Same three-party shape as the public-repo pushes. The
split is now written into S32: Sol kills and reports; **boss reads hermes from outside and states
before/after.**
