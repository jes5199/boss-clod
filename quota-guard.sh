#!/bin/bash
# Quota guard: checks burn rate and outputs SLOW_DOWN or OK
# Used by boss-clod to decide whether to broadcast a throttle message
#
# Exit codes:
#   0 = OK
#   1 = SLOW DOWN (any window projected to exhaust EARLY: burn ratio >= 1.05)
#   2 = STOP (7d >= 99%, hard backstop)

# ⛔ 2026-08-09: pipefail added. This script has SEVEN pipelines and its exit
# code IS its output — 0/1/2 decide whether boss broadcasts a throttle. Without
# pipefail a pipeline's status is the LAST command's, so a failing producer
# feeding a succeeding consumer reports success, and this guard would return
# "OK" from a computation that never ran. ⚠️ Note it is deliberately NOT `set
# -e`: this script must keep reaching its own explicit exit codes rather than
# dying partway, because a guard that exits early is indistinguishable from a
# guard that said OK.
set -o pipefail

JSON=$(/home/jes/.local/bin/claude-quota --json 2>/dev/null)
NOW=$(date -u +%s)

# Parse 5h window
FIVE_UTIL=$(echo "$JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['five_hour']['utilization'] if d['five_hour'] else 0)")
# resets_at goes null right after the 5h window rolls over, while five_hour
# itself stays a (truthy) dict — so guard on the timestamp, not the dict, or
# fromisoformat(None) raises. Only the informational burn ratio depends on this;
# the decision below is burn-ratio based and computes its own elapsed time.
FIVE_RESET=$(echo "$JSON" | python3 -c "
import sys, json
from datetime import datetime
d = json.load(sys.stdin)
r = (d.get('five_hour') or {}).get('resets_at')
print(int(datetime.fromisoformat(r).timestamp()) if isinstance(r, str) else 0)
")

# Parse 7d window
SEVEN_UTIL=$(echo "$JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['seven_day']['utilization'] if d['seven_day'] else 0)")

# Calculate 5h burn ratio
if [ "${FIVE_RESET:-0}" -gt 0 ]; then
  FIVE_START=$((FIVE_RESET - 18000))  # 5 hours = 18000 seconds
  ELAPSED=$((NOW - FIVE_START))
  TOTAL=18000
  if [ "$ELAPSED" -gt 0 ]; then
    # Use python for float math
    BURN=$(python3 -c "
u = $FIVE_UTIL
e = $ELAPSED / $TOTAL * 100
burn = u / e if e > 0 else 0
print(f'{burn:.2f}')
")
  else
    BURN="0.00"
  fi
else
  BURN="0.00"
fi

# ⛔ 2026-08-09, jes: "it competes with my keep-working threshold."
# THAT WAS THE REAL DEFECT, not the number. A guard keyed to HOW MUCH YOU HAVE
# USED will always fight "keep working", because late in a window high usage is
# the GOAL, not a warning. At 84% used / 89% elapsed the fleet is landing just
# under the ceiling exactly at reset — optimal — and the old rule had been
# firing since ~80%.
# ⇒ NEW RULE: fire on PROJECTED EXHAUSTION, i.e. sustained BURN RATIO
# (utilization / time-elapsed), not raw percentage. jes set the number: 1.05.
#   ratio >= 1.05  => SLOW_DOWN  (we would hit the wall EARLY and stop mid-work)
#   7d >= 99%      => STOP       (jes 2026-08-09: "no hard stop under 99%")
# ⭐ Finishing a window AT the limit is success. Only finishing it EARLY is a
# problem — that is the one this is allowed to interrupt work for.
BURN_LIMIT=1.05
STOP_PCT=99

# Highest-BURN window across all non-null windows (was: highest utilization).
read MAX_RATIO MAX_LABEL MAX_UTIL <<<"$(echo "$JSON" | python3 -c "
import sys, json, datetime as dt
d = json.load(sys.stdin)
now = dt.datetime.now(dt.timezone.utc)
windows = {'5h': ('five_hour', 5), '7d': ('seven_day', 168),
           '7d-opus': ('seven_day_opus', 168), '7d-sonnet': ('seven_day_sonnet', 168)}
best = (0.0, 'none', 0.0)
for label, (key, hours) in windows.items():
    w = d.get(key)
    # A window can be PRESENT with resets_at NULL, right after it rolls.
    if not w or w.get('utilization') is None or not w.get('resets_at'):
        continue
    reset = dt.datetime.fromisoformat(w['resets_at'])
    elapsed_pct = 100.0 * (now - (reset - dt.timedelta(hours=hours))).total_seconds() / (hours * 3600)
    if elapsed_pct <= 1:      # too early to be meaningful; a tiny denominator
        continue              # makes any usage look like a runaway burn
    u = float(w['utilization'])
    ratio = u / elapsed_pct
    if ratio > best[0]:
        best = (ratio, label, u)
print(f'{best[0]:.2f} {best[1]} {best[2]:.0f}')
")"


# ⛔⛔ 2026-08-10: FAIL CLOSED, NOT OPEN — observed once, live, at 20:22Z.
# `claude-quota --json` returned unparseable output. json.load raised, so the
# read got an empty line, so MAX_RATIO/MAX_LABEL/MAX_UTIL were all EMPTY, so
# `print(1 if  >= 1.05 else 0)` was a SyntaxError, so OVER was empty, so the
# `[ "$OVER" = "1" ]` test was false — and control fell through to the else
# branch, which printed:
#     OK|worst  x (limit 1.05) — 5h=% 7d=%
# and exited 0. ⚠️ THE GUARD REPORTED *OK* BECAUSE IT COULD NOT MEASURE. The
# cron log records `rc=0 OK|...`, which is byte-comparable to a healthy run, so
# an API outage would read as "burn is fine" for as long as it lasted — and the
# empty fields are the ONLY tell, in a line nobody reads when it says OK.
# ⭐ Same family as this repo's squad-alerts bare-`exit 0`, fixed 2026-08-09:
# A BROKEN CHECK MUST NOT BE ABLE TO EMIT THE REASSURING ANSWER. "I measured and
# you are fine" and "I could not measure" must never share an exit code.
# ⇒ rc=3 GUARD_BROKEN is neither OK(0), SLOW_DOWN(1) nor STOP(2): callers that
# treat nonzero as "do not dispatch" now fail safe by default.
case "$MAX_RATIO" in
  ''|*[!0-9.]*)
    echo "GUARD_BROKEN|quota JSON unparseable — ratio='$MAX_RATIO' label='$MAX_LABEL' util='$MAX_UTIL'"
    echo "  This is NOT 'OK'. No throttle decision was made this run."
    exit 3 ;;
esac
if [ "$MAX_LABEL" = "none" ]; then
  echo "GUARD_BROKEN|no usable window (all null, or every window <1% elapsed)"
  echo "  This is NOT 'OK'. No throttle decision was made this run."
  exit 3
fi
case "$SEVEN_UTIL" in
  ''|*[!0-9.]*)
    echo "GUARD_BROKEN|7d utilization unparseable: '$SEVEN_UTIL'"
    echo "  This is NOT 'OK'. No throttle decision was made this run."
    exit 3 ;;
esac

# Decision logic
SEVEN_INT=$(python3 -c "print(int($SEVEN_UTIL))")

OVER=$(python3 -c "print(1 if $MAX_RATIO >= $BURN_LIMIT else 0)")

if [ "$SEVEN_INT" -ge "$STOP_PCT" ]; then
  echo "STOP|7d at ${SEVEN_UTIL}% — over ${STOP_PCT}%, hard backstop"
  exit 2
elif [ "$OVER" = "1" ]; then
  echo "SLOW_DOWN|${MAX_LABEL} burning ${MAX_RATIO}x (>= ${BURN_LIMIT}) at ${MAX_UTIL}% used — would exhaust EARLY"
  exit 1
else
  echo "OK|worst ${MAX_LABEL} ${MAX_RATIO}x (limit ${BURN_LIMIT}) — 5h=${FIVE_UTIL}% 7d=${SEVEN_UTIL}%"
  exit 0
fi
