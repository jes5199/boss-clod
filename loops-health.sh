#!/usr/bin/env bash
# Are the boss-clod loops actually alive?
#
# ⚠️ WHY THIS EXISTS: the three loops are CronCreate jobs — SESSION-ONLY, gone
# on restart, never written to disk. On 2026-08-08 only ONE of three was
# registered and nobody noticed for THREE DAYS. LOOPS.md documented all three,
# which did not help: a file only works if someone reads it after a restart,
# and the failure is silent because a DECLINING loop and an ABSENT loop look
# identical from outside — both produce nothing.
#
# ⭐ So this checks the one thing a dead loop cannot fake: recent evidence that
# it RAN. Each script touches .heartbeat-<name> on every invocation, including
# declines and errors. Absence becomes observable from disk.
#
# Exit 0 = all alive, 1 = at least one stale/missing (i.e. re-arm it).

set -uo pipefail
cd "$(dirname "$0")"

# name : max minutes between runs before we call it dead (2x its interval)
LOOPS=(
  "sol-nudge:60"            # every 30m at :13,:43
  "epic-nudge:60"           # every 30m at :07,:37
  "squad-alerts-poll:20"    # every 10m
)

NOW=$(date +%s)
fail=0

printf '%-22s %-10s %s\n' "LOOP" "AGE" "STATE"
for entry in "${LOOPS[@]}"; do
  name="${entry%%:*}"
  max="${entry##*:}"
  hb=".heartbeat-$name"

  if [ ! -f "$hb" ]; then
    printf '%-22s %-10s %s\n' "$name" "-" "⛔ NEVER RAN — not armed?"
    fail=1
    continue
  fi

  age_min=$(( (NOW - $(stat -c %Y "$hb")) / 60 ))
  if [ "$age_min" -gt "$max" ]; then
    printf '%-22s %-10s %s\n' "$name" "${age_min}m" "⛔ STALE (>${max}m) — cron probably gone"
    fail=1
  else
    printf '%-22s %-10s %s\n' "$name" "${age_min}m" "✅ alive"
  fi
done

if [ "$fail" -ne 0 ]; then
  echo
  echo "⇒ Re-arm with CronCreate. The exact prompts are in LOOPS.md — that file is"
  echo "  the ONLY durable copy, because CronCreate jobs are session-only."
fi
exit "$fail"
