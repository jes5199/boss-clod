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
# ⛔ 2026-08-09: WAS `cd "$(dirname "$0")"`, WHICH BROKE THE MOMENT I PUT THIS
# ON PATH AS A SYMLINK. Through ~/.local/bin/loops-health, dirname resolves to
# ~/.local/bin, the .heartbeat-* files aren't there, and every loop reports
# ⛔ NEVER RAN — a false alarm that would have had me re-arming healthy crons.
# ⭐ Making the tool reachable introduced the failure the tool exists to detect.
# readlink -f follows the symlink to the real script location.
cd "$(dirname "$(readlink -f "$0")")"

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

# ⛔ SURFACE ACTIVE HOLDS. A hold makes forgetting-to-hold impossible and
# forgetting-to-RELEASE easy, and the second failure's symptom is SILENCE:
# dispatch stops, nothing reports it, and a stalled queue is indistinguishable
# from an empty one. So the hold has to appear where someone is already
# looking (commonplace-plan, 2026-08-09).
# ⛔⛔ THE HARDCODED LIST ABOVE COST TWELVE HOURS (2026-09-04, LESSONS 7x630). It walked
# .sol-hold and .epic-hold; .state-render-HOLD was NOT in it, sat held from 21:58Z to 09:43Z,
# and its cron's HOLD path EXITS 0 — so the suppression's own success looked like the job's.
# ⭐ THE GATE CLASS IS NOW DISCOVERED FROM ITS CONSUMERS, so a hold added to any script is
# covered without anyone remembering to add it here. A list maintained by memory is the same
# defect one level up.
# ⚠️ commonplace-biscuit, same hour: boss-clod holds TWO kinds of file with ONE naming
# convention — *-hold that GATES (a script tests -f) and *-hold that is only a NOTE. Three
# notes recorded "HOLD LIFTED" INSIDE themselves and still existed; they were harmless ONLY
# because nothing read them. ⇒ Discovery draws the line where the consumers actually are.
# ⛔ AND LIFT BY DELETING OR RENAMING, NEVER BY APPENDING "HOLD LIFTED": every consumer tests
# EXISTENCE, so an annotation is invisible to all of them.
# ⛔⛔ EXCLUDE THIS SCRIPT FROM ITS OWN SCAN. Caught by my own BLIND arm minutes after writing
# it: the comments above NAME the holds, so the scan matched itself, _gates was never empty, and
# THE BLIND ARM COULD NOT FIRE. Same family as `pgrep -f` matching its own command line — an
# instrument that reads its own text is measuring the wrong corpus, and it fails GREEN.
_gates=$(grep -rhoE '\.[a-zA-Z0-9_-]+-(hold|HOLD)\b' --include='*.sh' \
           --exclude="$(basename "$0")" . 2>/dev/null | sort -u)
# ⛔ A ZERO HERE WOULD SILENTLY SKIP EVERY HOLD — the exact failure this block exists to catch.
if [ -z "$_gates" ]; then
  printf '%-22s %-10s %s\n' "hold-scan" "-" "⛔ BLIND — found no hold consumers in *.sh; not the same as no holds"
  fail=1
fi
for h in $_gates; do
  [ -f "$h" ] || continue
  age=$(( (NOW - $(stat -c %Y "$h")) / 60 ))
  # ⭐ THE DISCRIMINATOR THAT MAKES THE AGE GATE USABLE (2026-09-04): WHOSE ATTENTION DOES THE
  # LIFT WAIT ON? A hold jes lifts is not stale at 47h — the condition is simply still unmet,
  # and flagging it forever is noise that trains the reader to skim past the real one.
  # A hold *I* must notice is stale the moment it outlives its reason.
  if grep -qiE 'his word|jes lifts|jes.s word' "$h" 2>/dev/null; then
    printf '%-22s %-10s %s\n' "${h#.}" "${age}m" "⏸ HELD — lift is JES'S to give (age is the condition, not staleness)"
    continue
  fi
  state="⏸ HELD — $(head -c 90 "$h" 2>/dev/null)"
  [ "$age" -gt 90 ] && { state="⛔ HELD ${age}m — SELF-LIFTED CLASS AND OVERDUE: whose attention is it waiting on?"; fail=1; }
  printf '%-22s %-10s %s\n' "${h#.}" "${age}m" "$state"
done

if [ "$fail" -ne 0 ]; then
  echo
  echo "⇒ Re-arm with CronCreate. The exact prompts are in LOOPS.md — that file is"
  echo "  the ONLY durable copy, because CronCreate jobs are session-only."
fi
exit "$fail"
