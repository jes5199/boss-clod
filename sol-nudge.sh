#!/bin/bash
# Sol feed check: should we dispatch another ticket to Sol (codex) right now?
#
# jes 2026-08-07: "this is working so let's do an hourly loop to feed work to sol"
#
# Prints NOTHING when no dispatch is warranted — boss-clod stays silent.
# Prints "SOL_NUDGE|<reason>" when commonplace should pick the next ticket
# and dispatch it to Sol.
#
# Every declined check prints WHY to stderr. A silent no-op and a broken
# script look identical otherwise — the failure mode this squad keeps hitting.
#
# Exit codes: 0 = checked (nudge or not), 2 = could not determine
#
# Deliberately does NOT dispatch: a shell script has no clod-squad access,
# and commonplace — not boss — picks the ticket and owns the review.
#
# ⭐ WHY THE CLAUDE-QUOTA GATE HERE IS DELIBERATELY LOOSE, unlike epic-nudge:
# Sol burns CODEX credits, which are a SEPARATE limit from Claude's. Dispatching
# Sol is the ANSWER to Claude quota pressure, not a casualty of it — gating this
# at epic-nudge's 0.85 would switch off the relief valve exactly when it is most
# useful. commonplace still needs Claude tokens to brief and review, so there IS
# a floor, but it sits near the STOP line rather than the slow-down line.

set -uo pipefail

WORKER="${WORKER:-commonplace}"
RATIO_MAX="${RATIO_MAX:-1.60}"        # floor for brief+review only — see note above
SEVEN_DAY_STOP="${SEVEN_DAY_STOP:-95}" # absolute: matches quota-guard's STOP
COOLDOWN_MIN="${COOLDOWN_MIN:-30}"   # jes 2026-08-08: 60 -> 30. The cron alone
                                     # cannot set the cadence — a 30m cron under a
                                     # 60m cooldown still fires hourly. Safe because
                                     # the busy-check declines while commonplace is
                                     # briefing, which is the case the cooldown was
                                     # really covering.
MARKER="/home/jes/boss-clod/.sol-nudge-last"
CREDIT_SENTINEL="/home/jes/boss-clod/.sol-codex-exhausted"

say() { echo "$*" >&2; }

# --- 1. codex credits exhausted? --------------------------------------
# jes 2026-08-07: "if codex starts running out of tokens, then stop".
# codex exposes no credit API (no usage table in state_5.sqlite), so this
# is a sentinel boss writes when a run reports exhaustion. Fails CLOSED on
# a stale sentinel by design: a human clearing it is cheaper than burning
# a quota we were told to protect.
if [ -f "$CREDIT_SENTINEL" ]; then
  say "DECLINED: codex credit sentinel set ($CREDIT_SENTINEL) — clear it to resume"
  exit 0
fi

# --- 2. is a Sol run already in flight? -------------------------------
# Don't stack runs. Exact-match the codex binary; never a broad pattern —
# hermes runs a live-money BEAM on this box.
INFLIGHT=$(pgrep -f '(^|/)codex (exec|resume)' 2>/dev/null | head -3)
if [ -n "$INFLIGHT" ]; then
  say "DECLINED: codex run already in flight (pids: $(echo $INFLIGHT | tr '\n' ' '))"
  exit 0
fi

# --- 3. locate commonplace BY NAME, not by index ----------------------
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

CMD=$(tmux list-panes -t "0:$WIN" -F '#{pane_current_command}' 2>/dev/null | head -1)
if [ "$CMD" != "claude" ]; then
  say "DECLINED: 0:$WIN is running '$CMD', not claude (crashed or exited?)"
  exit 0
fi

# --- 4. busy? use the SPINNER line, not "esc to interrupt" ------------
BUSY=$(printf '%s\n' "$PANE" | grep -oE '^[✻✽✢·✶*] [A-Za-z]+…* \([0-9]+[ms]' | tail -1)
if [ -n "$BUSY" ]; then
  say "DECLINED: $WORKER is generating ($BUSY)"
  exit 0
fi

if printf '%s\n' "$PANE" | grep -q 'Press up to edit queued'; then
  say "DECLINED: $WORKER has queued messages awaiting Enter"
  exit 0
fi

# --- 5. cooldown ------------------------------------------------------
if [ -f "$MARKER" ]; then
  LAST=$(stat -c %Y "$MARKER" 2>/dev/null || echo 0)
  AGE_MIN=$(( ( $(date +%s) - LAST ) / 60 ))
  if [ "$AGE_MIN" -lt "$COOLDOWN_MIN" ]; then
    say "DECLINED: dispatched ${AGE_MIN}m ago, cooldown is ${COOLDOWN_MIN}m"
    exit 0
  fi
fi

# --- 6. Claude floor (brief + review only) ----------------------------
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
  # absolute 7d stop — a ratio can look fine late in a nearly-spent window
  case "$f" in
    seven_day:*)
      USE=$(printf '%s' "$f" | cut -d: -f2)
      if awk -v u="$USE" -v s="$SEVEN_DAY_STOP" 'BEGIN{exit !(u>=s)}'; then
        say "DECLINED: 7d utilisation ${USE}% >= ${SEVEN_DAY_STOP}% (STOP line)"
        exit 0
      fi
      ;;
  esac
done

if awk -v r="$WORST" -v m="$RATIO_MAX" 'BEGIN{exit !(r>=m)}'; then
  say "DECLINED: below brief+review floor — worst ratio ${WORST} >= ${RATIO_MAX} ($READ)"
  exit 0
fi

# --- 7. all checks passed --------------------------------------------
touch "$MARKER"
echo "SOL_NUDGE|idle, no run in flight, codex credits presumed ok | worst ratio ${WORST} < ${RATIO_MAX} | ${READ}"
exit 0
