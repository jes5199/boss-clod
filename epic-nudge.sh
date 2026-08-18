#!/bin/bash
# Epic nudge check: is commonplace idle AND is there quota headroom?
#
# Prints NOTHING when no nudge is warranted — boss-clod stays silent.
# Prints "NUDGE|<reason>" when commonplace should be pushed to pick up
# the next highest-value piece of the epic autonomously.
#
# Every declined check prints WHY to stderr, so a run that does nothing
# still says what it saw. A silent no-op and a broken script look
# identical otherwise — the failure mode this whole squad keeps hitting.
#
# Exit codes: 0 = checked (nudge or not), 2 = could not determine
#
# Deliberately does NOT send the nudge itself: a shell script has no
# clod-squad access. boss-clod sends the message when this says NUDGE.

set -uo pipefail

# LIVENESS HEARTBEAT -- touched on EVERY run, including declines and errors.
# The three loops are CronCreate jobs: session-only, gone on restart. On
# 2026-08-08 only 1 of 3 was actually registered and nobody noticed for
# THREE DAYS, because a declining loop and an absent loop are both silent.
# LOOPS.md documented them, which did not help -- a file only works if
# someone reads it after a restart. This makes absence OBSERVABLE FROM DISK.
touch "${HEARTBEAT:-/home/jes/boss-clod/.heartbeat-epic-nudge}" 2>/dev/null || true


WORKER="${WORKER:-commonplace}"
# ⛔ DO NOT "ALIGN" THIS WITH quota-guard.sh's 1.05. They are DIFFERENT
# QUESTIONS and jes ratified the difference on 2026-08-09 ("no this is
# correct") when this gate fired at 0.95 while the guard still read OK:
#   this file      → may we START NEW WORK?        stricter (0.95)
#   quota-guard.sh → tell the fleet to SLOW DOWN?  looser  (1.05 burn, 99% stop)
# ⭐ Being conservative about STARTING while permissive about CONTINUING is
# deliberate: in-flight work is unaffected by this gate, so a decline costs a
# delay, never a half-finished ticket. A future session seeing "two thresholds
# for quota" and unifying them would silently make the fleet start work it
# cannot finish before a reset.
RATIO_MAX="${RATIO_MAX:-0.95}"       # jes 2026-08-08: 0.85 → 0.95. At 0.85 the loop
                                     # was closed all mid-week: a 7d window spent
                                     # evenly SITS near 1.0, so 0.85 only opened when
                                     # underspending. quota-guard's absolute 80/95 lines
                                     # are the real backstop. (was 0.9 → 0.85 on 08-06)
# ⛔ 2026-08-09: 60 -> 50. Same defect as sol-nudge.sh, worse here.
# Cron ticks :07,:37 (30 min apart); intended cadence is 60 min. The marker is
# touched at DISPATCH, later than the tick: measured tick 12:37, marker 12:41.
# So the 13:37 tick sees age 56m, declines against 60 (observed: "57m ago"),
# and the next eligible tick is 14:07 => 86m. ⇒ EFFECTIVE CADENCE ~90 MIN, NOT 60.
# ⚠️ Individually every decline is correct; the loss is only visible across runs.
# ⇒ 50 keeps the 60 min intent with 10 min of slack for dispatch delay, and
# still cannot fire twice off one tick pair (ticks are 30 min apart).
COOLDOWN_MIN="${COOLDOWN_MIN:-50}"   # don't re-nudge inside this window

# ⛔ HOLD, added 2026-08-09 — sol-nudge had one and this did not, which is
# backwards: THIS nudge asks commonplace to do the work ITSELF, so it spends
# more of the attention a stand-down is protecting, not less.
# Found by inconsistency rather than by failure: I told commonplace to stop for
# the night and then noticed my own loops would keep waking it.
# ⭐ A hold I have to remember is not installed. It states its own age, because
# forgetting to RELEASE fails silently — a stalled queue looks like an empty one.
EPIC_HOLD="${EPIC_HOLD:-/home/jes/boss-clod/.epic-hold}"
if [ -f "$EPIC_HOLD" ]; then
  held_min=$(( ( $(date +%s) - $(stat -c %Y "$EPIC_HOLD") ) / 60 ))
  echo "DECLINED: epic hold, HELD ${held_min}m — $(cat "$EPIC_HOLD" 2>/dev/null || echo 'NO REASON GIVEN')" >&2
  [ "$held_min" -gt 90 ] && echo "  ⛔ HELD OVER 90m. Is that release condition still true?" >&2
  echo "  (clear with: rm $EPIC_HOLD)" >&2
  exit 0
fi
IDLE_MARKER="${IDLE_MARKER:-/home/jes/boss-clod/.epic-nudge-last}"

say() { echo "$*" >&2; }

# --- 0b. STAND-DOWN — THE SAME FILE sol-nudge READS (added 2026-08-18) -
# ⛔⛔ WHY THIS IS SHARED AND NOT A SECOND FILE. commonplace's stand-down at
# 10:45Z said BOTH halves in one breath: "nothing is Sol-dispatchable, and
# nothing is me-dispatchable either" — because the CONDITION is one condition,
# plan's QUEUE.md being empty of ranked work, quoted from the queue's own
# receipt at HEAD rather than from anyone's impression.
# ⚠️ I MECHANIZED ONLY THE SOL HALF FIRST. That is tonight's dominant defect
#   (LESSONS 7w7) reproducing inside the very fix for it: the remedy attaches to
#   the script I happen to be editing instead of to the class of act.
# ⇒ ⭐ ONE CONDITION, ONE FILE, BOTH READERS. If the two pools ever need
#   different stand-downs, set STANDDOWN_FILE in the environment — do not add a
#   second default, because two defaults is how they drift apart unnoticed.
# ⛔ IT EXPIRES, and the expiry is the point: a stand-down nobody clears is how
#   this loop went quiet for 31 HOURS on 2026-08-16. Failing toward ASKING TOO
#   EARLY costs one message; failing toward never asking costs the queue.
STANDDOWN="${STANDDOWN_FILE:-/home/jes/boss-clod/.queue-standdown}"
if [ -f "$STANDDOWN" ]; then
  SD_UNTIL=$(awk '{print $1}' "$STANDDOWN" 2>/dev/null)
  SD_WHY=$(cut -d' ' -f2- "$STANDDOWN" 2>/dev/null)
  case "$SD_UNTIL" in ''|*[!0-9]*) SD_UNTIL=0 ;; esac
  if [ "$(date +%s)" -lt "$SD_UNTIL" ]; then
    say "DECLINED: stand-down until $(date -u -d "@$SD_UNTIL" +%H:%MZ) — $SD_WHY"
    say "          (lift early with: rm $STANDDOWN)"
    exit 0
  else
    say "NOTE: stand-down EXPIRED at $(date -u -d "@$SD_UNTIL" +%H:%MZ) — asking again."
    say "      It expired rather than being lifted: $SD_WHY"
    rm -f "$STANDDOWN"
  fi
fi

# --- 1. locate the worker's tmux window BY NAME, not by index ---------
WIN=$(tmux list-windows -t 0 -F '#{window_index} #{window_name}' 2>/dev/null \
      | awk -v n="$WORKER" '$2 == n {print $1; exit}')
if [ -z "$WIN" ]; then
  say "CANNOT DETERMINE: no tmux window named '$WORKER'"
  exit 2
fi

PANE=$(tmux capture-pane -p -t "0:$WIN" -S -10 2>/dev/null)
if [ -z "$PANE" ]; then
  say "CANNOT DETERMINE: captured no pane content for 0:$WIN"
  exit 2
fi

# --- 2. is it alive and actually a claude session? --------------------
CMD=$(tmux list-panes -t "0:$WIN" -F '#{pane_current_command}' 2>/dev/null | head -1)
if [ "$CMD" != "claude" ]; then
  say "DECLINED: 0:$WIN is running '$CMD', not claude (crashed or exited?)"
  exit 0
fi

# --- 3. busy? use the SPINNER line, not "esc to interrupt" ------------
# The interrupt hint is not always in the last lines; the spinner is the
# reliable signal. Getting this wrong once produced a false "idle".
# ⚠️ 2026-08-18: the unit class MUST include h. It was [ms], so the elapsed
# field "(1h 6m 57s" did not match and the gate read a 67-minute generation
# as IDLE — blind exactly past the hour mark, i.e. on the longest rounds,
# failing silently toward the permissive answer.
BUSY=$(printf '%s\n' "$PANE" | grep -oE '^[✻✽✢·✶*] [A-Za-z]+…* \([0-9]+[hms]' | tail -1)
if [ -n "$BUSY" ]; then
  say "DECLINED: $WORKER is generating ($BUSY)"
  exit 0
fi

# --- 4. queued input waiting on a keypress? not idle, needs a human ---
if printf '%s\n' "$PANE" | grep -q 'Press up to edit queued'; then
  say "DECLINED: $WORKER has queued messages awaiting Enter"
  exit 0
fi

# --- 5. cooldown ------------------------------------------------------
if [ -f "$IDLE_MARKER" ]; then
  LAST=$(stat -c %Y "$IDLE_MARKER" 2>/dev/null || echo 0)
  AGE_MIN=$(( ( $(date +%s) - LAST ) / 60 ))
  if [ "$AGE_MIN" -lt "$COOLDOWN_MIN" ]; then
    say "DECLINED: nudged ${AGE_MIN}m ago, cooldown is ${COOLDOWN_MIN}m"
    exit 0
  fi
fi

# --- 6. quota headroom ------------------------------------------------
# Ratio = utilisation / elapsed. >= RATIO_MAX means no headroom.
READ=$(/home/jes/.local/bin/claude-quota --json 2>/dev/null | python3 -c '
import sys, json
from datetime import datetime, timezone
try:
    d = json.load(sys.stdin)
except Exception:
    print("ERR"); raise SystemExit
now = datetime.now(timezone.utc).timestamp()
out = []
for key, hours in (("five_hour", 5), ("seven_day", 168)):
    w = d.get(key)
    # A window can be PRESENT with resets_at NULL -- observed 2026-08-09
    # 00:20Z, right after the 5h window rolled. fromisoformat(None) then
    # raises, the whole read prints nothing, and the guard returns
    # CANNOT DETERMINE -- so the loop STALLED every time a window turned
    # over. Skip such a window; the other one still gates.
    if not w or not w.get("resets_at"):
        continue
    r = datetime.fromisoformat(w["resets_at"]).timestamp()
    el = (now - (r - hours * 3600)) / (hours * 3600) * 100
    use = w["utilization"]
    # A just-rolled window is OPEN BY DEFINITION (jes, 2026-08-05):
    # treat it as full headroom, not as unknown. The <2% guard exists
    # only to avoid dividing by a near-zero denominator; ratio 0.0 =
    # headroom, which is the correct reading, not a refusal to judge.
    ratio = (use / el) if el >= 2 else 0.0
    out.append(f"{key}:{use:.1f}:{el:.1f}:{ratio:.2f}")
print(" ".join(out) if out else "ERR")
' 2>/dev/null)

if [ -z "$READ" ] || [ "$READ" = "ERR" ]; then
  say "CANNOT DETERMINE: quota read failed"
  exit 2
fi

WORST=0
for f in $READ; do
  R=$(printf '%s' "$f" | cut -d: -f4)
  awk -v a="$R" -v b="$WORST" 'BEGIN{exit !(a>b)}' && WORST=$R
done

if awk -v r="$WORST" -v m="$RATIO_MAX" 'BEGIN{exit !(r>=m)}'; then
  say "DECLINED: no headroom — worst burn ratio ${WORST} >= ${RATIO_MAX} ($READ)"
  exit 0
fi

# --- 7. all checks passed --------------------------------------------
# ⛔ THE MARKER RECORDS "GATE PASSED", NOT "NUDGE SENT" — and those diverge
# whenever boss reads the output and decides NOT to dispatch (2026-08-10: the
# gate opened while commonplace had two background suite runs in flight, so
# sending would have queued work onto an agent mid-measurement). The touch then
# suppresses the next 50 minutes on the strength of a nudge that never happened.
# ⭐ Same defect class as everything else tonight: a name that does not match
# what it measures. DRY=1 lets the check be evaluated WITHOUT committing the
# claim, so the file keeps saying something true.
# ⚠️ Deliberately NOT solved by moving the touch to the caller: a guard that
# depends on boss remembering to touch a file is a guard on memory, which this
# workspace has repeatedly established does not hold.
#
# ⛔⛔ AND IT RECURRED ON 2026-08-18, IN THE EXACT SCENARIO THIS COMMENT DESCRIBES:
# the gate opened while commonplace had a Q2 verification running in a background
# shell, I held the board, and the marker suppressed the next 50 minutes anyway.
# ⭐ THE INTERESTING PART IS WHY, BECAUSE IT IS NOT FORGETFULNESS: I had used DRY=1
#   on EVERY sol-nudge.sh run for the previous two hours — flawlessly — because I
#   had just written that script's version of this comment. The habit attached to
#   the SCRIPT I EDITED instead of to the CLASS OF ACT.
# ⇒ ⛔ A FIX LEARNED IN ONE HABITAT DOES NOT TRAVEL TO ITS TWIN. Same defect as
#   `counted` (five greps fixed one at a time, the FORM never fixed) and as
#   commonplace's brief corrections landing in instances, not the template.
# ⇒ ✅ THE RULE, STATED WITHOUT A SCRIPT NAME IN IT: **any nudge script, whenever
#   the send is in doubt, runs DRY=1 FIRST and for real only in the same breath as
#   sending.** If you are reading this in one script, it applies to the other.
#
# ⛔ AND DO NOT "FIX" THIS BY MAKING DRY THE DEFAULT. Considered and rejected
#   2026-08-18: the loop prompts invoke these scripts bare, so a DRY default means
#   the marker is never touched by the loop itself, cooldowns stop working, and a
#   held-dispatch bug (which only ever DELAYS) becomes a repeat-dispatch bug (which
#   is unbounded). The current default fails in the safe direction. Leave it.
if [ "${DRY:-0}" = "1" ]; then
  echo "(DRY=1: gate passed, marker NOT touched — nothing has been claimed)" >&2
else
  touch "$IDLE_MARKER"
fi
echo "NUDGE|idle, headroom ok (worst ratio ${WORST} < ${RATIO_MAX}) | ${READ}"
exit 0
