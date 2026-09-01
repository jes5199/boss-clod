#!/usr/bin/env bash
# ⭐ jes, 2026-09-01T02:40:13Z: "we can do some pure opus work until the burn hits like 0.75x"
#
# The fleet went all-Opus at 02:35 (topology change: Sol-through-proxy was too reticent).
# jes authorised PURE OPUS until burn reaches 0.75x — BELOW the guard's 1.05x SLOW_DOWN, so
# quota-guard.sh will NOT fire at this threshold. This is a separate, earlier tripwire.
#
# ⛔ A REMEMBERED THRESHOLD DOES NOT FIRE. This is the artifact so 0.75x is noticed by a script
# rather than by whoever happens to look at a number.
#
# rc 0 = under 0.75x, pure Opus still authorised
# rc 1 = AT OR OVER 0.75x — report to jes; the Sol-dispatch half of the topology is now the question
# rc 2 = BLIND — could not read the ratio; treat as no information, never as "we are fine"
set -o pipefail
THRESH="${OPUS_BURN_THRESH:-0.75}"
out=$(/home/jes/boss-clod/quota-guard.sh 2>&1)
rc=$?
# ⛔ ANCHOR ON THE 'x' SUFFIX. A bare [0-9.]+ against "worst 7d 0.50x" captures the 7 from "7d"
# and the gate fires RED on known-good input — caught by this script's own self-test, 2026-09-01.
ratio=$(printf '%s' "$out" | grep -oE '[0-9]+\.[0-9]+x' | head -1 | tr -d 'x')
case "$ratio" in
  ''|*[!0-9.]*) echo "BLIND|no burn ratio parsed from quota-guard (rc=$rc) — output was: $(printf '%s' "$out" | head -c 120)"; exit 2 ;;
esac
over=$(awk -v r="$ratio" -v t="$THRESH" 'BEGIN{print (r>=t)?1:0}')
if [ "$over" = "1" ]; then
  echo "OVER|burn ${ratio}x >= ${THRESH}x — jes's pure-Opus ceiling reached; the Sol-dispatch question is now live|guard says: $out"
  exit 1
fi
echo "UNDER|burn ${ratio}x < ${THRESH}x — pure Opus still authorised|guard: $(printf '%s' "$out" | head -c 80)"
exit 0
