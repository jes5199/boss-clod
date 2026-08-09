#!/bin/bash
# Quota guard: checks burn rate and outputs SLOW_DOWN or OK
# Used by boss-clod to decide whether to broadcast a throttle message
#
# Exit codes:
#   0 = OK
#   1 = SLOW DOWN (5h window burning too fast)
#   2 = STOP (7d window critically high)

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
# the 80%/95% decision below reads utilization directly and is unaffected.
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

# Find the highest-utilization window across ALL non-null windows.
# Rule (jes 2026-05-28): pause if ANY window passes 80%.
read MAX_UTIL MAX_LABEL <<<"$(echo "$JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
windows = {
    '5h': 'five_hour',
    '7d': 'seven_day',
    '7d-opus': 'seven_day_opus',
    '7d-sonnet': 'seven_day_sonnet',
}
best_u, best_l = 0.0, 'none'
for label, key in windows.items():
    w = d.get(key)
    if w and w.get('utilization') is not None:
        u = float(w['utilization'])
        if u > best_u:
            best_u, best_l = u, label
print(f'{best_u:.0f} {best_l}')
")"

# Decision logic
SEVEN_INT=$(python3 -c "print(int($SEVEN_UTIL))")

if [ "$SEVEN_INT" -ge 95 ]; then
  echo "STOP|7d at ${SEVEN_UTIL}% — critically high"
  exit 2
elif [ "$MAX_UTIL" -ge 80 ]; then
  echo "SLOW_DOWN|${MAX_LABEL} at ${MAX_UTIL}% — over 80% (burn ${BURN}x on 5h) — pause"
  exit 1
else
  echo "OK|5h=${FIVE_UTIL}% (${BURN}x) 7d=${SEVEN_UTIL}% max=${MAX_LABEL}:${MAX_UTIL}%"
  exit 0
fi
