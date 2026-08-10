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

## 8. Open — not near-misses, actual items awaiting a decision

- **`quota-guard.sh` is not on cron.** Two active entries: `watchdog-cron.sh`,
  `state-render-cron.sh`. Whatever it concluded, nobody received it.
- **Its 7d threshold keys on raw utilization (≥80%), not burn ratio** — it says
  SLOW_DOWN at 84% used / 89% elapsed where the ratio is 0.94 and healthy. Docs say
  90%, script says 80%. ⚠️ Not retuned: adjusting a guard so it stops disagreeing with
  you is how guards get talked out of firing. Awaiting jes.
