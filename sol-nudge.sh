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

# LIVENESS HEARTBEAT -- touched on EVERY run, including declines and errors.
# The three loops are CronCreate jobs: session-only, gone on restart. On
# 2026-08-08 only 1 of 3 was actually registered and nobody noticed for
# THREE DAYS, because a declining loop and an absent loop are both silent.
# LOOPS.md documented them, which did not help -- a file only works if
# someone reads it after a restart. This makes absence OBSERVABLE FROM DISK.
touch /home/jes/boss-clod/.heartbeat-sol-nudge 2>/dev/null || true


WORKER="${WORKER:-commonplace}"
RATIO_MAX="${RATIO_MAX:-1.60}"        # floor for brief+review only — see note above
SEVEN_DAY_STOP="${SEVEN_DAY_STOP:-95}" # absolute: matches quota-guard's STOP
# ⛔ 2026-08-09: 30 -> 15, AND THE REASON IS THE WHOLE POINT — A COOLDOWN EQUAL
# TO THE CRON INTERVAL SILENTLY HALVES THE CADENCE.
# The marker is touched when the DISPATCH happens, which is always LATER than
# the tick that triggered it (script runtime + my turn). Measured: tick 13:13,
# marker 13:23 = 10 min late. So the next tick at 13:43 sees age = 30 - 10 = 20m,
# reads it as "dispatched 29m ago" against a 30m cooldown, and DECLINES.
# ⇒ Every other tick lost. jes asked for 30 minutes on 2026-08-08 and was
# getting 60 — observed declining at 29m TWICE today before anyone noticed.
# ⚠️ It never looks broken: each decline is individually correct and prints a
# sensible reason. The defect is only visible ACROSS runs, which is why a
# per-run log could never show it.
# ⇒ RULE: cooldown must be STRICTLY LESS than (cron interval − worst dispatch
# delay). 15 leaves 15 min of slack against a 30 min interval.
COOLDOWN_MIN="${COOLDOWN_MIN:-15}"   # jes 2026-08-08: 60 -> 30. The cron alone
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

# --- 1b. measurement hold -----------------------------------------------
# 2026-08-09: a Sol run is a LOAD EVENT, not just a token spend. commonplace
# took a wrong diagnosis today from exactly this — CommitHoistTest read as a
# regression when it was a 10s budget inside a 9.9-13.9s variance, and the
# load was boss's own Sol dispatch. When someone is running a timing- or
# contamination-sensitive measurement, dispatching Sol contaminates it.
# ⭐ A hold I have to REMEMBER is not installed (today's own lesson), so it
# is a file. Write it with a reason; delete it to resume.
# ⛔ AND IT MUST ANNOUNCE ITS OWN AGE (commonplace-plan, 2026-08-09): making
# forgetting-to-HOLD impossible does not make forgetting-to-RELEASE
# impossible, and the second failure is worse shaped because ITS SYMPTOM IS
# SILENCE — Sol stays held, nothing reports it, and a stalled queue looks
# exactly like "nothing was ready". A hold that cannot state its age is an
# rc=0 with empty output: correct, silent, and indistinguishable from fine.
HOLD="/home/jes/boss-clod/.sol-hold"
if [ -f "$HOLD" ]; then
  held_min=$(( ( $(date +%s) - $(stat -c %Y "$HOLD") ) / 60 ))
  say "DECLINED: measurement hold, HELD ${held_min}m — $(cat "$HOLD" 2>/dev/null || echo 'NO REASON GIVEN')"
  if [ "$held_min" -gt 90 ]; then
    say "  ⛔ HELD OVER 90m. Is that release condition still true? A stale hold"
    say "     stops dispatch silently and looks like an empty queue."
  fi
  say "  (clear with: rm $HOLD)"
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
