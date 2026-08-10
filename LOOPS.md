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
standalone in tmux window 15 and binds `:5777`, so boss-clod's own copy never
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
