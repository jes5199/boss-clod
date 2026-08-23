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
# ⭐ Seconds: a commit this recently before a turn end means the turn ENDED ON WORK.
COMMIT_GRACE="${COMMIT_GRACE:-180}"
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
    *STALL-CANDIDATE*)
      # ⭐ A TURN THAT ENDS JUST AFTER A COMMIT IS A COMPLETED UNIT OF WORK, NOT A STALL.
      # commonplace-merkle-crdt tripped this 3x in one hour; 2 of the 3 turn-ends were
      # within 40s of a push. The detector reports that a turn ENDED, never what happened
      # in it — a commit is the missing evidence, and it is on disk.
      # ⚠️ This DELAYS the nudge by one cycle, it does not suppress it: once the commit
      # ages past the window the same quiet pane reports STALLED again. A genuine stall
      # after a push is still caught, five minutes later.
      # ⛔ FIELD 2 IS THE WORKER NAME, FIELD 3 IS THE TIMESTAMP: TURN|<worker>|<iso>|...
      # Stripping only once fed `date -d <worker-name>`, which fails, leaving t_turn empty
      # and this whole branch DEAD — it never fired even with a 100000s window. Caught by
      # a positive control, because a gate that never fires is indistinguishable from a
      # gate whose subject never occurred.
      ts="${out#*|}"; ts="${ts#*|}"; ts="${ts%%|*}"
      repo="/home/jes/$w"
      grace=""
      if [ -d "$repo/.git" ] && [ -n "$ts" ]; then
        t_turn=$(date -u -d "$ts" +%s 2>/dev/null || echo "")
        t_commit=$(git -C "$repo" log -1 --format=%ct 2>/dev/null || echo "")
        if [ -n "$t_turn" ] && [ -n "$t_commit" ]; then
          delta=$(( t_turn - t_commit ))
          # committed at most COMMIT_GRACE before the turn ended (and not in the future)
          if [ "$delta" -ge -30 ] && [ "$delta" -le "$COMMIT_GRACE" ]; then
            grace="$delta"
          fi
        fi
      fi
      if [ -n "$grace" ]; then
        echo "COMPLETED|$w|${out#*|*|} · committed ${grace}s before turn end — NOT nudged this cycle"
      else
        stalled=$((stalled+1)); echo "STALLED|$w|${out#*|*|}"
      fi
      ;;
  esac
done

# ⭐ Vacuity keyed to the READ, not the count: zero stalls is the healthy state and
# must stay legal. examined==0 means the sweep could not look.
[ "$examined" -eq 0 ] && { echo "BLIND|examined 0 workers — NOT 'nobody is stalled'"; exit 2; }
echo "SWEPT|examined=$examined|stalled=$stalled"
