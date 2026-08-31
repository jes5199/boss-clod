#!/usr/bin/env bash

# ⛔ REFUSE UNKNOWN ARGUMENTS — exit 2 (BLIND), never a normal verdict.
# ⚠️ Found 2026-08-23: all four of these scripts SILENTLY IGNORED any argument and
# printed a healthy verdict. A typo'd flag or env var meant the script answered the
# NO-FLAG question correctly while the caller believed a different question was asked.
# ⭐ These take NO positional arguments. Overrides are ENV VARS and are named in the
# body; a mistyped env var still silently defaults, which is why the ones that matter
# are echoed in the output line rather than assumed.

# ⭐ 2026-08-31 — A DEAD SESSION AND A STALLED ONE LOOK IDENTICAL FROM A TRANSCRIPT.
# commonplace-doc's last record is stop=end_turn from 2026-08-27 and its pane sits at a bash
# prompt: the session exited days ago. The detector read that as a stall and would have
# reported it every 5 minutes forever, which is how a sweep trains its reader to skim.
# ⛔ Resolve liveness by /proc identity, NEVER `pgrep -f` — the worker name appears in this
# script's own command line and the shell matches itself.
set -o pipefail  # ⛔ 2026-08-31: a pipeline eats the status of the command that matters —
                 # `cmd | tail` reports tail's success. Without this, a verdict printed
                 # through a pipe can say FAILED and exit 0. quota-guard.sh already had it.
_worker_session_alive() {
  local w="$1" p cmd self=$$
  for p in /proc/[0-9]*; do
    p=${p#/proc/}
    [ "$p" = "$self" ] && continue
    cmd=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null) || continue
    case "$cmd" in
      *"mcp-config-${w}.json"*)
        case "$cmd" in *claude*) return 0 ;; esac
        ;;
    esac
  done
  return 1
}

if [ "$#" -gt 0 ]; then
  echo "BLIND|$(basename "$0") takes no arguments (got: $*) — overrides are env vars. NOT a verdict." >&2
  exit 2
fi
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
        # ⛔ 2026-08-23T23:53Z — a DECLARED STOP is a STANDING STATE; the phrase check is
    # PER-TURN. commonplace-doc stopped at 23:42Z with a verified mechanism, then REPLIED
    # to a message at 23:45:31Z, and that reply carried no 'nothing queued' — so it read as
    # STALLED and a nudge would have re-dispatched an agent that deliberately yielded quota.
    # ⚠️ A reply to a message is not a retraction of a stop, and the LAST TURN is the wrong
    # place to look for a standing decision.
    # ⭐ NOT SUPPRESSION — these print STOPPED| and stay visible, because a silently skipped
    # worker is indistinguishable from one nobody is watching. The release condition prints
    # too, so a stale entry is READABLE rather than inert.
    # ⭐ 2026-08-24T00:48Z — an agent waiting on an ARMED watcher is not stalled. Suppression is
    # CONDITIONAL ON THE PID BEING ALIVE: a dead watcher re-exposes the stall rather than hiding it.
    _watchfile=/home/jes/boss-clod/.awaiting-watcher
    _wline=""
    [ -r "$_watchfile" ] && _wline=$(grep -v '^#' "$_watchfile" | grep "^${w}|" | head -1)
    if [ -n "$_wline" ]; then
      _wpid=$(echo "$_wline" | cut -d'|' -f2)
      if kill -0 "$_wpid" 2>/dev/null; then
        echo "WAITING|$w|armed watcher pid $_wpid ALIVE — not a stall|wakes on: $(echo "$_wline" | cut -d'|' -f3)"
        continue
      else
        # ⛔⛔ 2026-08-24T00:50Z — I FIRST WROTE THIS AS "pid GONE => the thing it was waiting
        # for will never arrive". THAT IS FALSE, and it is the global rule I break most: a
        # FINISHED watcher, a watcher that DIED, and one that NEVER STARTED all leave no process.
        # commonplace's monitor vanished between two of my own checks — because the run COMPLETED
        # and it exited normally, exactly as designed. I nearly filed that as a dead watcher.
        # ⭐ THE ARTIFACT IS THE VERDICT, NOT THE PROCESS'S ABSENCE. So say only what is true:
        # the watcher is no longer running, which is AMBIGUOUS, and fall through to normal stall
        # handling — the safe direction, since a nudge to a finished agent costs one turn while a
        # missed stall costs the interval.
        echo "WATCHER-GONE|$w|pid $_wpid no longer running — FINISHED or DIED, indistinguishable from here; falling through to stall handling"
      fi
    fi
    _stopfile=/home/jes/boss-clod/.declared-stopped
    _stopline=""
    [ -r "$_stopfile" ] && _stopline=$(grep -v '^#' "$_stopfile" | grep "^${w}|" | head -1)
    if [ -n "$_stopline" ]; then
      echo "STOPPED|$w|declared stop, mechanism accepted — NOT nudged|release: $(echo "$_stopline" | cut -d'|' -f2)"
      continue
    fi
    if ! _worker_session_alive "$w"; then
      # NOT suppression: printed and visible, like STOPPED. A dead session cannot be nudged,
      # and relaunching one with no ranked work is scheduling, not unsticking.
      echo "DEAD-SESSION|$w|no live claude process for this worker — exited, not stalled|release: relaunch only when it has ranked work"
      continue
    fi
    # ⭐ 2026-08-31 — A NUDGE THAT DOES NOT MOVE THE TURN-END TIMESTAMP IS NOT WORKING.
    # commonplace-plan reported STALLED three sweeps running with the SAME turn_end
    # (19:18:51.103Z) — it had finished its turn and was waiting on a peer agent, which from a
    # transcript is indistinguishable from being stuck. Re-nudging a worker whose turn_end has
    # not moved is repeating a thing already observed not to work, and the loop's own rule says
    # to stop and say so.
    # ⛔ NOT SUPPRESSION: still printed, with the repeat count, and it SELF-CLEARS the instant the
    # worker takes a turn. The state file records only what was already in the output.
    _seenfile=/home/jes/boss-clod/.stall-seen
    _turn_end=$(echo "${out#*|*|}" | cut -d'|' -f1)
    _prev=$(grep "^${w}|" "$_seenfile" 2>/dev/null | head -1)
    _prev_te=$(echo "$_prev" | cut -d'|' -f2)
    _prev_n=$(echo "$_prev" | cut -d'|' -f3)
    case "$_prev_n" in ''|*[!0-9]*) _prev_n=0 ;; esac
    if [ "$_turn_end" = "$_prev_te" ]; then
      _n=$((_prev_n+1))
    else
      _n=1
    fi
    if [ -w "$(dirname "$_seenfile")" ]; then
      { grep -v "^${w}|" "$_seenfile" 2>/dev/null; echo "${w}|${_turn_end}|${_n}"; } > "${_seenfile}.tmp" 2>/dev/null \
        && mv "${_seenfile}.tmp" "$_seenfile"
    fi
    if [ "$_n" -ge 3 ]; then
      echo "NUDGE-INEFFECTIVE|$w|${out#*|*|} · unchanged turn_end across $_n sweeps — the nudge is a substitute for a fix, not a fix; find why it cannot proceed"
      continue
    fi
    stalled=$((stalled+1)); echo "STALLED|$w|${out#*|*|}"
      fi
      ;;
  esac
done

# ⭐ Vacuity keyed to the READ, not the count: zero stalls is the healthy state and
# must stay legal. examined==0 means the sweep could not look.
[ "$examined" -eq 0 ] && { echo "BLIND|examined 0 workers — NOT 'nobody is stalled'"; exit 2; }
echo "SWEPT|examined=$examined|stalled=$stalled"
