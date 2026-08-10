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

⛔⛔ **AND THE THIRD POSSIBILITY BOTH READINGS MISSED: THE CHANGE ITSELF CAN BE THE LOAD.**
Sol's fix **adds real teardown work** — stop + restart the `CommitStore` in 13 more files — so
the suite legitimately does more work than before. ⇒ A timing-sensitive ratio guard noticing
that is **not the guard being buggy, and not ambient flakiness**: it is a known-fragile guard
surfacing under a **genuinely heavier suite the change caused**. That is a **causal path, and
it is testable** — which is why *"flaky"* was the wrong label to reach for.
⭐ **"Flaky" is a terminal label that ends inquiry; "load-conditioned, and here is what added
the load" is a hypothesis with a next step.** Prefer the one that can be run.

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

## 8. Open — not near-misses, actual items awaiting a decision

- **`quota-guard.sh` is not on cron.** Two active entries: `watchdog-cron.sh`,
  `state-render-cron.sh`. Whatever it concluded, nobody received it.
- **Its 7d threshold keys on raw utilization (≥80%), not burn ratio** — it says
  SLOW_DOWN at 84% used / 89% elapsed where the ratio is 0.94 and healthy. Docs say
  90%, script says 80%. ⚠️ Not retuned: adjusting a guard so it stops disagreeing with
  you is how guards get talked out of firing. Awaiting jes.
