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
# ⚠️ 60, NOT 180. 180 was a guess; the measured "just pushed then ended the turn" cases were
# 17s and 38s. The first production downgrade came in at 175s — an agent that committed,
# worked three more minutes, then went quiet, which is closer to a real stall than to a
# completed push. A window wide enough to swallow that is a window that suppresses the
# thing this sweep exists to catch.
COMMIT_GRACE="${COMMIT_GRACE:-60}"
# ⭐ How long a commit-backed downgrade may last. Beyond this the pane is just quiet.
QUIET_MAX="${QUIET_MAX:-300}"
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
      # ⛔ BLIND SPOT, NAMED BY merkle-crdt 19:14Z: this only sees the worker's OWN repo.
      # Work whose product is a MEASUREMENT IN A PEER'S TREE leaves no local commit and
      # reads as a stall. That case is real and recurring — its 19:07 trip was three
      # minutes spent measuring in commonplace's test tree to answer doc-sync.
      # ⇒ The declared-pause token is the only cover for it, because the evidence exists
      # somewhere this check cannot look. Do not widen the window to compensate.
      # ⛔ THE FIRST VERSION OF THIS COMMENT WAS FALSE AND THE CODE MATCHED THE COMMENT.
      # I wrote "delays the nudge by one cycle" — but delta is t_turn MINUS t_commit, and
      # BOTH ARE FIXED TIMESTAMPS. It never ages. commonplace-doc was suppressed at minute
      # one and still suppressed at minute ten, silently, forever for that turn.
      # ⇒ A SECOND condition makes the stated behaviour true: the turn must also be RECENT.
      # Past QUIET_MAX the pane reports STALLED regardless of how tidily it committed.
      # ⭐ A worker that commits, ends a turn, and goes quiet for an hour IS stalled — the
      # commit says the turn ended on work, it says nothing about the hour that followed.
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
          quiet=$(( $(date -u +%s) - t_turn ))
          if [ "$delta" -ge -30 ] && [ "$delta" -le "$COMMIT_GRACE" ] && [ "$quiet" -le "$QUIET_MAX" ]; then
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
