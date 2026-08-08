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

### 2. epic-nudge — every 29 min
```
Run /home/jes/boss-clod/epic-nudge.sh (capture stderr too — it explains every declined check).

If it prints nothing on stdout, do nothing and stay silent.

If it prints a line starting with NUDGE|, send commonplace this via clod-squad:

Ask commonplace-plan what the highest-value work in the tix/chit/EC2-worker/sub-agent-identity
epic is right now, pick something, and do it autonomously — no need to check back with jes or
me first.

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

### 3. sol-nudge — hourly at :23
```
Run /home/jes/boss-clod/sol-nudge.sh (capture stderr too — it explains every declined check).

If it prints nothing on stdout, do nothing and stay silent.

If it prints a line starting with SOL_NUDGE|, send commonplace this via clod-squad:

Sol is free and there is headroom — pick the next ticket and dispatch it. You choose which; you
own the review. Prefer correctness and performance work, and prefer tickets whose acceptance can
be checked from an artifact rather than from a report.

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
