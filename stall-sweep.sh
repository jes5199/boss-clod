#!/usr/bin/env bash
# Which live workers have ended a turn with nothing scheduled?
#
# ⭐ WHY THIS EXISTS SEPARATELY FROM THE 15-MINUTE PANE WATCH: a stalled agent costs
# ~half the check interval on average. yepochs stalled 4 times in one hour; at a
# 15-minute floor that is ~30 minutes of an agent sitting at a prompt with unblocked
# work in front of it. The pane watch answers "is the fleet healthy"; this answers the
# narrower and more perishable "is anyone stopped who should not be", so it can run
# far more often for far less.
#
# ⛔ IT DOES NOT DECIDE WHAT ANYONE WORKS ON. It reports who has stopped. Resuming a
# stalled agent is unsticking, not scheduling -- the difference being that the agent
# chose the work and only the turn boundary interrupted it.
#
# Retired and blocked workers are expected to be idle and are skipped by the detector
# itself, so this cannot fire on correct state.
#
# rc 0 = swept   2 = instrument blind

set -uo pipefail
WORKERS=(commonplace-log commonplace-log-reducer commonplace-merkle-crdt yepochs commonplace-doc)
WORKER_LIST=/home/jes/boss-clod/.watch-workers
# ⭐ ONE list, two scripts. If the file is missing or empty we KEEP the literal
# fallback below rather than silently watching nothing — an empty watch list is
# the one failure that reports perfect health forever.
if [ -r "$WORKER_LIST" ]; then
  mapfile -t _wl < <(grep -v '^#' "$WORKER_LIST" | grep -v '^[[:space:]]*$')
  [ "${#_wl[@]}" -gt 0 ] && WORKERS=("${_wl[@]}")
fi
D=/home/jes/boss-clod/turn-end-detector.sh
[ -x "$D" ] || { echo "BLIND|detector missing or not executable at $D"; exit 2; }

examined=0; stalled=0
for w in "${WORKERS[@]}"; do
  out=$("$D" "$w" 2>&1 | head -1) || true
  case "$out" in
    BLIND*) echo "BLIND|$w|$out"; continue ;;
  esac
  examined=$((examined+1))
  case "$out" in
    *STALL-CANDIDATE*) stalled=$((stalled+1)); echo "STALLED|$w|${out#*|*|}" ;;
  esac
done

# ⭐ Vacuity keyed to the READ, not the count: zero stalls is the healthy state and
# must stay legal. examined==0 means the sweep could not look.
[ "$examined" -eq 0 ] && { echo "BLIND|examined 0 workers — NOT 'nobody is stalled'"; exit 2; }
echo "SWEPT|examined=$examined|stalled=$stalled"
