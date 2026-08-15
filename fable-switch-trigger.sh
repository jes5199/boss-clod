#!/bin/bash
# ONE-SHOT TRIGGER: fires at the 2026-08-17 10:00Z 7d quota reset so boss-clod
# actually performs jes's 2026-08-15 instruction to switch commonplace and
# commonplace-plan to Fable.
#
# ⛔ WHY A CRON ROW AND NOT A NOTE: CronCreate loop jobs are session-only and die
# with the session. 36 hours is long enough that the session holding the promise
# may compact or restart first. The squad-alerts queue is the ONLY durable path
# that reaches a running boss session, because squad-alerts-poll.sh runs from the
# loops every few minutes and its output is relayed by construction.
#
# ⚠️ severity MUST be 'error' or 'critical' -- squad-alerts-poll.sh filters
# `severity in ('critical','error')`. An 'info' or 'warn' row is written, stored,
# and NEVER SEEN: the exact silent-success shape this alert path exists to prevent.
#
# Self-disarming: removes its own crontab line after firing, so a boss that is
# slow to act does not get the same alert every day.
set -uo pipefail
DB=/home/jes/.claude/channels/squad-alerts/queue.db
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

sqlite3 "$DB" <<SQL
INSERT INTO alerts (publisher, severity, source, title, body, created_at)
VALUES (
  'boss-clod',
  'error',
  'boss-clod:scheduled',
  'SCHEDULED ACTION DUE: switch commonplace + commonplace-plan to Fable',
  'This is NOT an incident. It is a self-scheduled action arming jes''s instruction of 2026-08-15 21:25Z (telegram 9214): "when the anthropic quota resets I want you to switch commonplace and plan to Fable". The 7d quota window has now reset. READ /home/jes/boss-clod/.fable-switch-at-reset.md BEFORE ACTING -- it carries the who/how, the in-session-before-relaunch order, and the requirement to VERIFY THE MODEL FROM THE STATUSLINE rather than from the fact that the command was sent. Scope is commonplace and commonplace-plan ONLY; do not widen to hermes or the astro workers.',
  '$NOW'
);
SQL
rc=$?

# Disarm regardless of insert outcome -- a trigger that re-fires daily on a
# failed insert is worse than one that fired once and needs chasing.
#
# ⛔⛔ THE NAIVE FORM OF THIS IS DESTRUCTIVE AND I ALMOST SHIPPED IT:
#     crontab -l | grep -v pattern | crontab -
# If `crontab -l` fails or returns nothing, that pipeline installs an EMPTY
# crontab and silently deletes every other job on the box -- quota-guard,
# state-render, watchdog. The failure mode of the cleanup is worse than the
# thing it cleans up. So: capture first, refuse to write anything that does not
# still contain a known-present job.
current=$(crontab -l 2>/dev/null) || current=""
remaining=$(printf '%s\n' "$current" | grep -v 'fable-switch-trigger.sh')

if [ -n "$current" ] && printf '%s\n' "$remaining" | grep -q 'quota-guard-cron.sh'; then
  printf '%s\n' "$remaining" | crontab -
else
  # POSITIVE CONTROL FAILED: the survivor set does not contain a job that must
  # be there. Leave the crontab untouched and make the refusal loud rather than
  # tidy. A duplicate alert is cheap; a wiped crontab is not.
  echo "fable-switch-trigger: REFUSING to rewrite crontab -- control job quota-guard-cron.sh absent from survivor set" >&2
fi
exit $rc
