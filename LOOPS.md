# Boss-clod recurring loops — the ACTUAL prompts

**Written 2026-08-08 because they existed only inside one session's memory.**
`CronCreate` jobs are **session-only**: they die when boss-clod restarts and are
NOT written to disk by the harness. If this file didn't exist, a restart would
lose them and they'd have to be reconstructed from memory.

⚠️ `CLAUDE.md`'s "Startup Loops" section describes an OLDER set (worker health
check / usage report / auto-compact). It is not what has been running.
**This file is the current truth; CLAUDE.md's list is historical.**

## Recreate on session start

Three loops, via `CronCreate`. Suggested schedules avoid `:00`/`:30`.

### 1. squad-alerts poll — every ~10 min
Closes the delivery gap found 2026-07-31: the squad-alerts MCP server runs
standalone in the tmux window **named `squad-alerts`** (index 12 after the 2026-08-10
renumber — resolve it by NAME, indices shift) and binds `:5777`, so boss-clod's own copy never
starts and the channel delivers nothing into the session. The store marks
alerts delivered regardless.

```
Run /home/jes/boss-clod/squad-alerts-poll.sh

If it prints nothing, do nothing and stay silent.

If it prints one or more alerts, relay them to jes on telegram (chat_id 160085044)
IMMEDIATELY — this is the alert path he explicitly asked me to be part of, and the
whole failure mode we are fixing is a working detector reaching someone who does not
act on it. Include severity, source, title and what it means. If a critical alert
concerns the trading stack or a security compromise, verify the underlying claim
yourself from the DB/logs before relaying, and say what you verified versus what you
are passing on.

Ignore alerts that are obviously hermes test fixtures (e.g. fake "bot COMPROMISED" or
"SHARES entry placed: COIN" during a test run) — but say so rather than silently
dropping them, and mention it if test noise is still reaching the live channel.
```

### 2. epic-nudge — every 10 min at :8,:18,:28,:38,:48,:58 (job df9e3aca)
**Polls often; the 50 min COOLDOWN does the pacing.** Changed 2026-08-09 from :7,:37.

> ⛔⛔ **HANDOFF CHANGE ADOPTED 2026-08-10 — SAY "HERE IS THE BOARD", NOT "TAKE THIS ITEM".**
> The stigmergy doc's **invariant 9** is *"the wake mechanism proposes attention; it does not
> secretly become a central scheduler."* I read that as indicting these loops;
> commonplace-plan corrected me, and the correction is sharper than my self-criticism:
> **a timer that fires and says "look at the board" is the invariant's own COMPLIANT case.**
> The ranked queue survives too, because it is a **public challengeable trace** — it was
> challenged four times on 2026-08-09/10 and **lost three**, which is self-selection against a
> published affordance rather than assignment.
> ⇒ **THE ACTUAL VIOLATION IS THE DISPATCH STEP: converting a ranking into an INSTRUCTION on
> the way to a worker.** That is a handoff change, not an architecture change, and it costs
> nothing to try.
> ⇒ **So when composing the clod-squad message, point at the board and let the worker
> self-select.** Prefer *"the queue's top unblocked row is X; Sol is free; here is what
> changed"* over *"take X"*. Keep everything that is a CONSTRAINT (brief discipline, safety
> rules, quota facts) — those are properties of the world, not instructions about what to pick.
> ⚠️ The cron prompt text below is UNCHANGED on purpose: rewriting the CronCreate jobs risks
> losing session-only loops, and the phrasing that actually reaches a worker is the message I
> compose, not the prompt that wakes me. **Change the handoff, not the plumbing.**
```
Run /home/jes/boss-clod/epic-nudge.sh (capture stderr too — it explains every declined check).

If it prints nothing on stdout, do nothing and stay silent.

If it prints a line starting with NUDGE|, send commonplace this via clod-squad:

Take the top unblocked item from commonplace-plan's docs/plans/QUEUE.md and do it autonomously —
no need to check back with jes or me first. If you believe the ranking is wrong, say why and
propose a re-rank; do not silently choose something else, and do not default to whatever is
freshest in your context (jes, 2026-08-09: "I want commonplace-plan to be in charge of queue
priority, not just whatever we thought of most recently"). You own the REVIEW, not the ORDER.
Anything not in QUEUE.md is UNRANKED, not deprioritised — publish it to plan rather than assuming
it was considered.

Working shape jes wants (2026-08-05): FABLE AT TOP LEVEL, OPUS IMPLEMENTERS. Reserve your own
turns for judgment, design, review and deciding what is worth doing; delegate the mechanical
build work to Opus subagents. You review their diffs against the intent you briefed, not against
a summary of it. If a subagent reports a test failure as "pre-existing" or "unrelated", check it
yourself — that phrase hid a P1 today.

Standing constraints: deploy verified work (gate is lifted); targeted tests one app at a time
with the count checked; :code.is_loaded before probing a live module and treat a call to an
unloaded module as a write; prove non-perturbation with a before/after count; report counts with
their scope; correct your own claims visibly. Do NOT start the tix migration, chit itself, or the
EC2 transport work unless commonplace-plan's design for it has landed. Stop and ask only if
something genuinely needs jes.

Do not tell jes about a routine nudge — he asked for this to run without him in the loop. Only
message him if the script exits 2 (could not determine) twice in a row, or if commonplace reports
something that needs him.
```

### 3. sol-nudge — every 10 min at :1,:11,:21,:31,:41,:51 (job 4104154e)
**Polls often; the 15 min COOLDOWN does the pacing.** Changed 2026-08-09 from :13,:43.
```
Run /home/jes/boss-clod/sol-nudge.sh (capture stderr too — it explains every declined check).

If it prints nothing on stdout, do nothing and stay silent.

If it prints a line starting with SOL_NUDGE|, send commonplace this via clod-squad:

Sol is free and there is headroom — dispatch the next ticket. TAKE THE TOP UNBLOCKED ITEM FROM
commonplace-plan's docs/plans/QUEUE.md; if you believe it is wrong, say why and propose a re-rank
rather than silently choosing something else. You own the REVIEW, not the ORDER (jes, 2026-08-09:
"I want commonplace-plan to be in charge of queue priority, not just whatever we thought of most
recently"). Prefer tickets whose acceptance can be checked from an artifact rather than a report.

Use /home/jes/boss-clod/sol-egress-run.sh (set SOL_WORKDIR to an isolated worktree — it
hard-refuses /home/jes/commonplace). Sol has network access now, so deps fetch instead of failing.

BRIEF DISCIPLINE — this is where the last run lost time, so treat it as part of the work, not
overhead:
- Include the sandbox preamble (CX-z5rm). The store path is workspace-relative:
  /home/jes/commonplace/workspace/.commonplace/commits/ — process-derived, NOT repo-root, and NOT
  data/ (that path exists but is stale, a decoy the escript bug itself minted).
- Never give Sol an instruction it cannot satisfy. An omitted warning costs TIME; a contradictory
  instruction costs JUDGMENT, because an agent told to do the impossible improvises around the fence.
- State acceptance criteria as artifacts to produce, and say explicitly which ones Sol cannot verify
  in-sandbox. If a criterion needs a live serve, Sol must report it UNVERIFIED and stop — the fence
  matters more than the criterion. I run those outside, read-only, on your word.
- Demand red-first: reproduce before fixing.

Standing constraints: verify by effect, never by a config loading or a report's number; report
counts with their scope AND their baseline; a negative result needs its error shape checked,
because "blocked" and "not there" share an exit code; every negative-result table needs a positive
control or it is unfalsifiable. Correct your own claims visibly.

If Sol reports codex credits exhausted, tell me and I will set
/home/jes/boss-clod/.sol-codex-exhausted to stop the loop — jes's standing instruction is to stop
when codex runs out.

Do not tell jes about a routine dispatch — he asked for this to run without him in the loop.
Message him only if the script exits 2 (could not determine) twice in a row, if codex credits run
out, or if commonplace reports something that genuinely needs him.
```

## System cron — survives everything, NOT session-scoped

```
*/5 * * * * /home/jes/boss-clod/watchdog-cron.sh
17  * * * * /home/jes/boss-clod/state-render-cron.sh
```

## Guard scripts these loops call

| script | purpose | key thresholds |
|---|---|---|
| `epic-nudge.sh` | is commonplace idle AND is there quota headroom? | `RATIO_MAX=0.85`, 60m cooldown |
| `sol-nudge.sh` | should we feed Sol another ticket? | `RATIO_MAX=1.60` (deliberately loose — Sol burns **codex** credits, a separate limit, so dispatching Sol is the ANSWER to Claude quota pressure, not a casualty of it), `SEVEN_DAY_STOP=95`, 60m cooldown, in-flight check, credit sentinel |
| `squad-alerts-poll.sh` | drain undelivered alerts | — |
| `sol-egress-run.sh` | run Sol with network + credentials masked | refuses `SOL_WORKDIR` under `/home/jes/commonplace` |

**All three loop scripts print NOTHING on stdout when no action is warranted, and
explain every declined check on stderr** — so a silent no-op and a broken script
never look alike. That property is deliberate; preserve it in anything new.

⚠️ `.sol-codex-exhausted` stops the Sol loop and **fails closed**. Delete it to resume.

## ⭐ WHY THE NUDGES POLL EVERY 10 MINUTES (changed 2026-08-09)

jes: *"do we need to stagger the Claude crons more or do them more frequently so they don't
bump into reviewing Sol code?"* — **more frequently, and the cooldown is what paces them.**

⛔ **THE OLD FAILURE: a 30-minute schedule meant a decline COST 30 MINUTES.** commonplace is
busy reviewing a Sol artifact when the nudge fires → DECLINED → the next opportunity is a
full interval away, even if it went idle 30 seconds later. **A busy moment pushed work back
by a whole cycle.** Same shape as the cooldown-equals-interval bug: fixed schedules lose
whole ticks to transient state.

⇒ **Poll often, gate on state.** The scripts already decline on: commonplace generating ·
a run in flight · cooldown not elapsed · headroom exceeded · a measurement hold. **Polling
more often does NOT dispatch more** — the cooldowns (sol 15 min, epic 50 min) still set the
rate. It only shortens the gap between *"commonplace becomes free"* and *"the next dispatch"*.

⭐ **STAGGERED so no two land together:** alerts :4,:14,… · sol :1,:11,… · epic :8,:18,…
**Three minutes apart, never simultaneous.**

⚠️ **Cost:** ~18 turns/hour instead of ~10, and almost all of them are a script run plus
silence. Cheap against a 7d window sitting at 0.93x.


## 4. Plan queue nudge — DAILY (added 2026-08-14, jes: "let's have a daily scheduled nudge for commonplace-plan to queue up more work")

**Script:** `/home/jes/boss-clod/plan-nudge.sh` · **heartbeat:** `.heartbeat-plan-nudge` ·
**marker:** `.plan-nudge-last` · **hold:** `.plan-hold` (states its own age; warns past 24h)

```
/loop 6h run /home/jes/boss-clod/plan-nudge.sh (capture stderr too — it explains every declined check).

If it prints nothing on stdout, do nothing and stay silent.

If it prints a line starting with PLAN_NUDGE|, send commonplace-plan this via clod-squad:

Daily queue check — is there ranked, unblocked work available? If QUEUE.md's ranked
set is empty or everything on it is blocked, that is the thing to fix: rank what is
filed but unranked, and say explicitly if something is deliberately NOT being ranked
so it reads as a decision rather than an oversight. You own the ORDER; commonplace owns
the REVIEW (jes, 2026-08-09).

State I can measure and will include: what is in flight, what is filed-and-unranked,
current burn ratios and which POOL each governs. Anything I send is inventory, not a
ranking — I do not attach priority.

⭐ SOL IS NOT GATED BY THE THERMOSTAT — codex is a separate pool. A Sol-dispatchable
item is worth more on a shut-thermostat day than one that waits for it.

Do not tell jes about a routine plan nudge. Message him if the script exits 2 twice in
a row, or if plan reports something that needs him.
```

### Why this loop is NOT gated at the epic thermostat's 0.95
⛔ **epic-nudge asks commonplace to BUILD; this asks plan to RANK.** Ranking is cheap, and
it is what unblocks **Sol — which runs on codex, a SEPARATE POOL** from the Anthropic quota
the thermostat measures.
⭐ **Gating ranking on the build threshold empties the queue exactly when Sol most needs
ranked work.** Observed 2026-08-14: the thermostat sat shut ~18h while Sol was idle and
unaffected, and the only missing input was a rank.
⇒ It respects a **hard ceiling instead** (`UTIL_MAX=90`, 7d absolute utilisation) — *a ratio
says "faster than sustainable", a ceiling says "nearly out"*, and they are different questions.

### Cadence
`COOLDOWN_MIN=1200` (20h), not 1440. ⚠️ **A 24h cooldown against a ~daily tick silently
becomes every OTHER day** — the same off-by-one-tick defect that turned epic-nudge's
intended 60 min into ~90. Run the loop more often than daily (6h is fine); the cooldown
is what makes it daily.

### Gate demonstrated RED and GREEN at install (2026-08-14)
⭐ *A gate nobody has seen fail is not known to work, and one that fires on correct state is
worse than no gate.* Both directions shown before first use:
```
DRY=1 UTIL_MAX=50   → DECLINED: 7d utilisation 66.0% >= 50% hard ceiling      (red)
DRY=1 + .plan-hold  → DECLINED: plan hold, HELD 0m — <reason>                 (red)
DRY=1 WORKER=nosuch → CANNOT DETERMINE: no tmux window named 'nosuchwindow'   rc=2
DRY=1               → PLAN_NUDGE|plan idle, 7d utilisation 66.0% < 90%        (green)
```
⭐ `DRY=1` evaluates the gate **without touching the marker** — verified: `.plan-nudge-last`
still absent after four dry runs. **The marker records "gate passed", not "nudge sent".**

---

# ⛔⛔ 2026-08-18 — TWO LOOPS DIED SILENTLY FOR 31 HOURS, AND THE CHECK THAT WOULD HAVE CAUGHT IT WAS NEVER RUN

```
heartbeat ages measured 2026-08-17 22:20Z:
  .heartbeat-epic-nudge   1881m  (31h)   ⛔ DEAD
  .heartbeat-sol-nudge    1856m  (31h)   ⛔ DEAD
  .heartbeat-plan-nudge      0m          ✅ alive
  .heartbeat-quota-guard     8m          ✅ alive  (system cron)
  .heartbeat-state-render   36m          ✅ alive  (system cron)
```
⇒ **`CronList` confirmed it: only the plan-nudge job existed. epic, sol and the alerts poll
were gone.** Symptom jes saw: *"fable and sol both building"* → measured, both IDLE, and my
first answer blamed a cooldown that was working correctly.

## ⭐ WHAT MADE IT INVISIBLE — AND IT IS THE SAME SHAPE AS THE FOUR-DAY CI RED
⛔ **A dead loop and a loop that keeps correctly declining are INDISTINGUISHABLE from the
outside.** Both produce silence, and silence is what a healthy no-op looks like BY DESIGN
(the scripts print nothing on stdout when no action is warranted — a property that is
deliberate and correct, and which also hides their absence).
⇒ ⭐⭐ ***THE HEARTBEAT FILES EXIST FOR EXACTLY THIS, AND `boss-preflight.sh` READS THEM AND
CALLS A STALE ONE RED. IT WAS NOT RUN.*** ⚠️ **I built that check on 2026-08-15 after a loop
died unnoticed for three days. It found nothing this time because nothing invoked it — a
check with no caller is a filed rule, not a mechanism.**

## ✅ FIX APPLIED, AND THE PART THAT MATTERS IS THE CALLER
- **Re-armed:** sol `:1,:11,…` (9d083b05) · epic `:8,:18,…` (4a78d072) · alerts `:4,:14,…`
  (97c4a216) · plan 6h `:23` (b342363d, never died). **Staggered 3 min apart as before.**
- ⭐ **The nudge prompts now carry today's corrections rather than the 2026-08-10 text:**
  the Fable-writes-code directive (his 2026-08-17 reversal of delegate-to-a-subagent), the
  KNOWN-REDS-from-the-file rule with `bin/cp-brief-known-reds --check`, base-as-a-relation,
  counts-carry-selectors, and the `sol-egress-run.sh` name warning.
- ⛔⛔ **STILL SESSION-ONLY. `CronCreate` writes nothing to disk and dies with the session.**
  ⇒ ***THIS FILE IS THE ONLY DURABLE COPY, AND IT IS ONLY DURABLE IF SOMEONE READS IT.***
  ⭐ **On every session start: run `CronList`, compare against this file, and re-arm what is
  missing. If the heartbeats disagree with `CronList`, believe the heartbeats — they record
  what RAN, not what was SCHEDULED.**

### 4. commonplace-log pair watch — every 15 min at :4,:19,:34,:49 (job 8a545fd6)
**Added 2026-08-23 at jes's request:** *"can you check the two commonplace-logs claudes every 15
minutes to make sure they're still working (unless they finish or get stuck!)"*

Script: `/home/jes/boss-clod/log-pair-watch.sh` — resolves windows **by name**
(`commonplace-log`, `commonplace-log-reducer`), never by index. Prints `STATUS|` per worker plus
`SUMMARY|`; `BLIND|` + rc=2 when the instrument itself failed.

⭐ **BOTH ARMS DEMONSTRATED BEFORE TRUSTING IT** (see `LESSONS.md` §7x75):
- **RED:** a bogus window name → `MISSING`; *both* names bogus → `BLIND|` and **rc=2**, not a clean
  "nothing wrong".
- **GREEN:** real windows → clean report, rc=0.

⛔ **AND IT SHIPPED WITH THE EXACT DEFECT THE LESSON DESCRIBES, CAUGHT ON ITS FIRST RUN.** v1 tested
only for `esc to interrupt` and **fell through to IDLE** — so it reported **both busy workers as
IDLE**. A false green, on a gate's first run, in an environment unlike the one it was written
against. **Fixes, both structural:**
1. Busy is now detected from four independent signals — spinner-with-elapsed `(2m 12s · ↓ …)`,
   `Waiting for N background agent`, an agent-tray row carrying a duration, and `esc to interrupt`.
2. ⭐ **`IDLE` now requires a POSITIVELY matched idle prompt.** Anything unrecognised reports
   **`UNKNOWN`**, so *"no pattern matched"* and *"genuinely idle"* stop sharing an observable —
   the thread's own answer applied to my own script.

⚠️ **And UNKNOWN immediately earned its keep:** it fired on window 0:17 and the cause was that the
prompt line ends in **U+00A0 NON-BREAKING SPACE**, so `[[:space:]]*$` does not match it under
`LANG=C.UTF-8`. Found with `cat -A`. The script now normalises NBSP→space before matching, and
**hashes the RAW pane** so normalisation can never mask a change.

**Silence policy:** stay quiet while both are `WORKING`. Report only CRASHED / QUEUED /
RATE_LIMITED / STUCK / UNKNOWN / BLIND, or an IDLE that persists two consecutive checks. jes does
not want a 15-minute heartbeat.



⚠️ **Job re-created 2026-08-23 03:39Z (was `45f66f9d`, now `8a545fd6`) to fix TWO defects in the
prompt itself, not the script:**
1. ⛔ **The old prompt told me to "tell it on clod-squad to ... /compact".** Workers have no such
   tool — it is a user command. **I wrote that instruction myself and then followed it**, which is
   the fourth time that mistake has been made here. The prompt now says the lever is mine via tmux
   and points at the script's `ACTION|` lines; the worker is asked only for the DURABILITY PASS.
2. ⭐ **The IDLE branch now names the mechanism instead of just the threshold:** an agent that ends
   a turn saying *"continuing to Task N"* does **not** continue, and a post-`/compact` pane is the
   same shape — **a turn that ends returns it to the prompt and nothing restarts it.** ⇒ In both
   cases **a clod-squad message IS the input that resumes it.** Both were observed the same hour:
   the reducer stalled on an announced continuation, commonplace-log stalled after a compact I
   drove. Reporting either as "finished" would have been wrong.

Also now covers **three** workers (added `commonplace-merkle-crdt`).

### 5. Fable recovery watch — hourly at :23 (job 2a35bc3a)
**Added 2026-08-23.** Script: `/home/jes/boss-clod/fable-recovery-check.sh`.

⚠️ **WHY IT EXISTS:** the **Fable-scoped weekly meter** hit **100% at 2026-08-22T03:16Z**, and
`quota-guard.sh` watches **5h and 7d only** — it does not watch that scope. ⇒ **hermes and
commonplace-log ran ~24h on Opus while everyone, including jes, believed they were on Fable.**
The discrepancy surfaced only because a pane check compared `/proc/<pid>/cmdline` against the
rendered statusline.

⭐ **THE LOAD-BEARING HALF OF THE STANDING DIRECTIVE IS THE SWITCH-BACK** (jes 2026-07-06: the Opus
fallback is fine *"as long as we remember to switch back"*). **A remembered rule does not fire.**
This loop is the artifact that does. Fable resets **2026-08-24T10:00Z**.

**Silence policy:** `FABLE|EXHAUSTED` → stay completely silent, that is expected until reset.
`FABLE|RECOVERED` → the event it exists for; telegram jes with the affected workers and ask which
to switch (a relaunch costs context; ⛔ never restart hermes without asking, live money).
`BLIND`/rc=2 → **instrument failure, NOT evidence Fable is healthy.**

⭐ **ALL FOUR ARMS DEMONSTRATED BEFORE TRUSTING IT** — including the one that matters:
- **RED:** quota tool yields nothing → `BLIND` rc=2. Fable entry absent from the payload →
  `BLIND` rc=2 (**a shape change must not read as "Fable is fine"**).
- ⭐ **RED, the important one:** a synthetic payload with `percent=12` **flips it to the
  switch-back branch.** Without planting that, the recovery path would never have been seen fire
  until the real reset — **a branch that only runs once, at the moment it matters, is the worst
  possible place for an untested arm.**
- **GREEN:** the real payload → `EXHAUSTED`, correct reset time, correct affected list.

⭐ **The check reads its POSITIVE CONTROL FIRST:** it proves the `scope.model.display_name=Fable`
entry exists before believing any percentage, because **a missing entry and a healthy meter are
indistinguishable to a `percent >= 100` test.**

### 6. Unbacked-work sweep — hourly at :47 (job c3f44737)
**Added 2026-08-23.** Script: `/home/jes/boss-clod/unbacked-work-sweep.sh`.

⚠️ **WHY IT EXISTS:** commonplace-log-reducer reported a doc *"filed at main `1df1015`"*. It was
**committed, not pushed** — 13 commits on `main` plus the **entire implementation branch**
(Tasks 1–7, 133 tests) existed on one disk. Caught only by the verify-pushed-before-relaying rule,
because ⭐ **a commit SHA is a local claim with the syntax of a published one.**

⛔⛔ **AND THE SAME SWEEP FOUND boss-clod ITSELF 15 COMMITS UNBACKED** — the whole §7x75 lesson
thread and both watch scripts — **while I was telling another agent about durability.** ⇒ **Nobody
is exempt, which is exactly why this is a script and not a resolution.**

⭐ **THE DISTINCTION IT ENFORCES:** *durable to a compaction* and *durable to a machine* are
different properties. Writing state to files defends the first. **Only a push defends the second,
and the failure that actually loses work is losing the machine.**

**Silence policy:** `unbacked_repos=0` → silent. boss-clod unbacked → push it, no message.
Another agent's repo, agent online → ask that agent. Agent offline, or still unbacked after a
previous sighting → push it (a push of an existing branch to its existing upstream is a pure
addition). **No remote at all** → that is worse and goes to jes.

⭐ **VACUITY KEYED TO THE READ, not the count** (§7x75 addendum 9): zero findings is the *healthy*
state and must stay legal, so the gate is `examined > 0` — *did the sweep look?* — not
`findings > 0`. `examined == 0` → `BLIND`, rc=2, explicitly **not** "everything is pushed".

**Both arms demonstrated:** planting an empty commit in `yepochs` made it appear (and vanish after
reset); pointing `REPOS` at a nonexistent path produced `BLIND` rc=2 rather than a clean sweep.

#### ⛔⛔ Sweep §6 correction, 2026-08-23 04:12Z — THE SWEEP ITSELF WAS THE 17-OF-82 CASE

It shipped with a hardcoded 17-name `REPOS=()` list and reported **`unbacked_repos=0,
examined=17`** while **82 git repos existed at depth 1 under `/home/jes`.** Sixty-five were never
looked at — including `postage-stamp`, which is *known* to have no remote.

⭐⭐ **AND MY OWN VACUITY GATE PASSED, BECAUSE `examined=17 > 0`.** ⇒ ***`examined > 0` proves the
instrument RAN. IT SAYS NOTHING ABOUT COVERAGE.*** A non-zero denominator drawn from the wrong
population is a **distinct** failure from a zero one — **and far more convincing**, because it looks
exactly like a healthy measurement. This is §7x75's corpus door, held open by the gate meant to
guard it.

✅ **Fixed twice over:** the corpus is now **DISCOVERED** (`ls -d /home/jes/*/.git`), never
enumerated by hand; and a **coverage gate** refuses to report unless `examined == discovered`. It
fired immediately on `48 of 82` — because `.git` is a **FILE** in a linked worktree and the loop
tested `-d`. **Both defects were invisible in the old output; both are now loud.**

**First full-corpus run: 28 unbacked repos**, none of which the sweep had ever been able to see.
Pushed `bartleby` (4 commits, sitting since 2026-01-03) and `friendly-claude-message-alerts`
(1, since 2026-03-18). ⚠️ Four repos have **no remote at all** — `postage-stamp` (35 commits),
`hyperstition` (9, believed deliberate — employer-IP-gated), `grimoire` (2), `test-worker` (1).
Escalated, not invented.

### 7. Stall sweep — every 5 min at :2,:7,:12,… (job 202bc9c9)
**Added 2026-08-23 07:53Z.** Scripts: `stall-sweep.sh` + `turn-end-detector.sh`.

⚠️ **WHY, in numbers:** a stalled agent costs **~half the check interval**. `yepochs` stalled **four
times in one hour**; at the 15-minute pane-watch floor that is **~30 minutes of an agent sitting at a
prompt with unblocked work in front of it.** ⇒ The pane watch answers *"is the fleet healthy"*; this
answers the narrower and more perishable *"is anyone stopped who should not be"*, so it can run far
more often for far less.

⭐ **The verdict does NOT depend on matching English** (see `LESSONS.md` §7x82 and its corrections):
it is **`stop=end_turn` PLUS nothing running** — a fact about the machine. The forward-looking phrase
is printed as a *detail explaining why*, never as the decider. **I tried the wording-based version
first and it produced a false negative on "Starting with X…" within the hour.**

⛔ **It does not decide what anyone works on.** Resuming a stalled agent is **unsticking, not
scheduling** — the agent chose the work and only the turn boundary interrupted it. ⇒ RETIRED and
BLOCKED workers are skipped by the detector itself, so it **cannot fire on correct state**.

**Silence policy:** `stalled=0` → silent. `BLIND`/rc=2 → the detector failed, **not** "nobody is
stalled". ⛔ **Never telegram jes for a stall** — internal fleet mechanics, explicitly not what he
asked to hear about.

⭐ **Built-in stop condition:** if one worker stalls **three times in an hour despite this**, stop
nudging and say so. **At that point the nudge is a substitute for a fix, not a fix.**

### 7-ter. ONE-SHOT OBSERVERS ARMED TODAY (session-only — recreate if this session dies)

⛔ **CronCreate jobs are NOT persisted. If boss restarts, these are gone and their silence looks
exactly like a clean run.**

| fires | id | subject |
|---|---|---|
| **15:13Z 2026-09-02** | `6b59fcfa` | hermes wheel expiry-fallback change (`HERMES-56k4v`) |
| **16:41Z 2026-09-02** | `220f856f` | **`MarginDebtCover`'s FIRST-EVER REAL RUN** (16:30Z) — pre-committed expectation: **CLEAN NO-OP** (`debit_since` nil, cash +$1,748.85 at 14:26Z). **An action taken is the surprising result.** Also checks the 15:00Z allocator skip and whether hermes's own 15:07Z recorder produced a file. |

⭐ **WHY AN INDEPENDENT OBSERVER WHEN THE DOOR ALREADY RECORDS ITSELF: a door that is wedged cannot
report that it is wedged**, and *"hermes will tell me"* is a claim about a future capability with no
instrument. ⚠️ **A recorder that never ran looks exactly like a quiet system.**

### 8-bis. OPEN-WITH-JES BOARD — read it during the hourly check

⛔ **THE HOURLY CHECK ASKS "IS A WORKER BLOCKED?" AND MY CONTEXT IS NOT THE PLACE THAT ANSWERS IT.**
Read **[OPEN-WITH-JES.md](OPEN-WITH-JES.md)** on every hourly fleet check, and add a row the moment a
door says it is waiting on jes.

⭐ **EARNED 2026-09-02:** biscuit closed a message *"still awaiting jes on the restart"* and I had no
record of it — **though it was in my transcript twice, once in my own words.** ⚠️ **In context and not
in the record**, which is the same failure the fleet had just fixed for facts, arriving in board state.
⭐⭐ **biscuit: *"You were saved by the item being unimportant, NOT by the record."***

⚠️ **Every row says BLOCKED or WAITING, and never infer which — ask the door.** **Blocked goes to
Telegram now; waiting sits in the file.**

## 8. Hourly fleet health check — every hour at :38 (session-scoped)

📌 **This check also READS [OPEN-WITH-JES.md](OPEN-WITH-JES.md) — see §8-bis immediately above.**

⛔⛔ **FOUND MISSING 2026-09-02 03:42Z BY THE CHECK ITSELF.** The stall sweep (§7) and the one-shot
observer were both filed here; **this loop was not** — for seven hours, while it ran every hour and
told me each time to *"recreate from LOOPS.md if the list is missing the stall sweep."*
⭐ **It named ONE job as the thing to check for. A loop that verifies ANOTHER loop's persistence and
not its own is exactly the shape it exists to catch** — and it is the same defect as
`the board that supersedes everything is the board nobody re-reads`.

**EXACT PROMPT — recreate with `CronCreate`, cron `38 * * * *`, recurring:**
```
Hourly fleet health check. For every worker: call list_peers, then inspect each tmux pane by
identity (never a broad pattern match). Look for and fix: a pane sitting at bash instead of claude
(relaunch with the recipe in reference_worker_restart_recipes / LOOPS.md); a generation stuck over
30 minutes; queued messages needing Enter; any modal dialog holding the session — drafted-feedback
review, rate-limit prompt, permission prompt, suggestion menu; and a session whose statusline model
is not the one it is supposed to be running. Also read each worker's context percentage from its
statusline and note anything above 70%. Separately confirm this session's own recurring jobs still
exist with CronList — if the list is empty or missing the stall sweep, recreate from
/home/jes/boss-clod/LOOPS.md, because session-scoped jobs are lost on restart and that silence looks
identical to health. Verify what you find rather than trusting a pane's own summary. Send jes a
Telegram summary ONLY if you fixed something, something is actually broken, or a worker is genuinely
blocked; if everything is healthy, stay silent — do not send a routine all-clear.
```
**Tools it uses:** `pane-ctx.sh` (reads context % by identity, reports BLIND vs UNMEASURED) ·
`recoverability-check.sh` (does boss's own filed state survive a restart) · `CronList`.
⚠️ **When recreating, check ALL FOUR jobs exist, not just the one the prompt names:** stall sweep
(§7) · this check (§8) · any one-shot observer · and whatever else `CronList` showed before the
restart.

## ONE-SHOT OBSERVER — hermes wheel fallback first live run (2026-09-02 15:13 UTC)

⚠️ **SESSION-ONLY: `CronCreate` job `6b59fcfa` is NOT persisted. If this session restarts before
2026-09-02T15:13Z, RECREATE IT FROM HERE — its absence looks exactly like health.**

**Why it exists (hermes, and it is a named mechanism, not babysitting):** `HERMES-56k4v` / `320a8d5`
deployed 2026-09-01T18:05Z is the first code that can place a live order on the new expiry-fallback
path. ⛔ **A crash IS alerted — `run_entry_check` containment fires Telegram. A WRONG-BUT-NON-CRASHING
SELECTION IS NOT.** ⇒ ⭐ **The system's appointment produces the DATA; it does not produce the
READING.** The observer is for the one run where "the data exists" is insufficient. **It lapses after
2026-09-02.**

**What to ask hermes for, mechanically:**
1. `oban_jobs` — did `WheelEntryCheck` for 2026-09-02T15:05Z complete at all?
2. `signal_decisions` `decision_date=2026-09-02` — RXRX expiry `2026-10-16` = fallback fired as
   designed · `2026-10-09` = did NOT fire, read details · expect
   `details =~ fallback_from=2026-10-09(thin_credit)`. DNA unchanged, no `fallback_from`.
3. `wheel_positions` — any NEW row (a real order placed)? Only expected if the Oct-16 monthly bid
   still clears $0.15; it was 0.19 at 17:42Z on 2026-09-01.
4. **`WheelTrader` module md5 MUST be `04a08f3710bf8bc467da472cd0ccff78`.** Anything else means the
   VM and the tree have DIVERGED.
   ⛔⛔ **CORRECTED 2026-09-02 03:56Z — THE TWO VALUES THAT WERE HERE (`ca2603b0…`, `b21f8dd6…`) WERE
   WRONG, AND SO WAS THE MODEL UNDER THEM.** They came from a relay of MINE and **I gated on them
   without ever reproducing one**: the value entered the fleet through boss-clod and every later use
   raised its standing WITHOUT ADDING AN INSTRUMENT.
   ⭐ **hermes measured it — PRE-restart (hot-reloaded) `04a08f37…`, POST-restart (FULL RECOMPILE from
   a tree whose `wheel_trader.ex` is byte-identical to `320a8d5`'s) `04a08f37…` — IDENTICAL.**
   ⇒ ⛔ **The premise that hot-reload and recompile give DIFFERENT hashes IS FALSE, so even a
   corrected PAIR would have encoded a distinction that does not exist** — a wrong MODEL, not merely
   a wrong number, and it would have made *"the md5 changed"* read as meaningful.
   ✅ **Absence checked with a control: 0 hits for either string across the hermes repo + `.beads`;
   positive control `"WheelTrader"` = 215 files in a 79,156-file corpus. The only place either string
   existed on this box was THIS FILE — it had no origin outside the relay chain.**
   ⚠️ **The replacement is worth exactly the two commands that produced it, which hermes named so
   they can be RE-RUN rather than trusted.**

**Relay to jes ONLY** if the fallback behaved unexpectedly, an order was placed, or the job did not
run. **A clean expected no-fire is internal — file it, do not text him.**
