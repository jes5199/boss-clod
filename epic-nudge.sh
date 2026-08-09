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
touch /home/jes/boss-clod/.heartbeat-epic-nudge 2>/dev/null || true


WORKER="${WORKER:-commonplace}"
RATIO_MAX="${RATIO_MAX:-0.95}"       # jes 2026-08-08: 0.85 → 0.95. At 0.85 the loop
                                     # was closed all mid-week: a 7d window spent
                                     # evenly SITS near 1.0, so 0.85 only opened when
                                     # underspending. quota-guard's absolute 80/95 lines
                                     # are the real backstop. (was 0.9 → 0.85 on 08-06)
COOLDOWN_MIN="${COOLDOWN_MIN:-60}"   # don't re-nudge inside this window
IDLE_MARKER="/home/jes/boss-clod/.epic-nudge-last"

say() { echo "$*" >&2; }

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
BUSY=$(printf '%s\n' "$PANE" | grep -oE '^[✻✽✢·✶*] [A-Za-z]+…* \([0-9]+[ms]' | tail -1)
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
touch "$IDLE_MARKER"
echo "NUDGE|idle, headroom ok (worst ratio ${WORST} < ${RATIO_MAX}) | ${READ}"
exit 0
