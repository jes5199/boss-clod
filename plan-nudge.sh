#!/bin/bash
# Plan nudge check: should commonplace-plan be asked to QUEUE UP MORE WORK?
#
# jes, 2026-08-14 16:04Z: "let's have a daily scheduled nudge for
# commonplace-plan to queue up more work."
#
# Prints NOTHING when no nudge is warranted — boss-clod stays silent.
# Prints "PLAN_NUDGE|<reason>" when plan should be asked to rank.
# Every declined check prints WHY to stderr: a silent no-op and a broken
# script look identical otherwise, which is the failure this squad keeps
# hitting.
#
# Exit codes: 0 = checked (nudge or not), 2 = could not determine
#
# Deliberately does NOT send the nudge: a shell script has no clod-squad
# access. boss-clod sends when this prints PLAN_NUDGE.

set -uo pipefail

# LIVENESS HEARTBEAT — touched on EVERY run, declines and errors included.
# These loops are session-only (CronCreate is not persisted by the harness);
# on 2026-08-08 only 1 of 3 was registered and nobody noticed for three days,
# because A DECLINING LOOP AND AN ABSENT LOOP ARE BOTH SILENT. LOOPS.md
# documented them and that did not help — a file only works if someone reads
# it. This makes absence OBSERVABLE FROM DISK.
touch "${HEARTBEAT:-/home/jes/boss-clod/.heartbeat-plan-nudge}" 2>/dev/null || true

WORKER="${WORKER:-commonplace-plan}"

# ⛔ THIS LOOP IS DELIBERATELY *NOT* GATED AT THE EPIC THERMOSTAT'S 0.95.
# epic-nudge asks commonplace to BUILD; this asks plan to RANK. Ranking is
# cheap, and it is what unblocks SOL — which runs on codex, a SEPARATE POOL
# from the Anthropic quota the thermostat measures.
# ⭐ Gating ranking on the build threshold would empty the queue at exactly the
# moment Sol most needs ranked work: on 2026-08-14 the thermostat sat shut for
# ~18h while Sol was idle and unaffected, and the only thing missing was a rank.
# ⚠️ It still respects a HARD CEILING, because at some point even cheap work
# should stop. That ceiling is absolute utilisation, not a burn ratio: a ratio
# says "faster than sustainable", a ceiling says "nearly out".
UTIL_MAX="${UTIL_MAX:-90}"   # 7d utilisation %, hard stop. quota-guard STOPs at 95.

# Daily cadence. 20h rather than 24 so a tick with drift still fires once a
# day: a 24h cooldown against a ~daily tick silently becomes every OTHER day,
# which is the same off-by-one-tick defect that made epic-nudge's 60 into ~90.
COOLDOWN_MIN="${COOLDOWN_MIN:-1200}"

# ⛔ A hold I have to remember is not installed. States its own age, because
# forgetting to RELEASE fails silently — a stalled queue looks like an empty one.
PLAN_HOLD="${PLAN_HOLD:-/home/jes/boss-clod/.plan-hold}"
if [ -f "$PLAN_HOLD" ]; then
  held_min=$(( ( $(date +%s) - $(stat -c %Y "$PLAN_HOLD") ) / 60 ))
  echo "DECLINED: plan hold, HELD ${held_min}m — $(cat "$PLAN_HOLD" 2>/dev/null || echo 'NO REASON GIVEN')" >&2
  [ "$held_min" -gt 1440 ] && echo "  ⛔ HELD OVER 24h. Is that release condition still true?" >&2
  echo "  (clear with: rm $PLAN_HOLD)" >&2
  exit 0
fi

IDLE_MARKER="${IDLE_MARKER:-/home/jes/boss-clod/.plan-nudge-last}"
say() { echo "$*" >&2; }

# --- 1. locate plan's tmux window BY NAME, never by index -------------
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

# --- 2. alive and actually a claude session? --------------------------
CMD=$(tmux list-panes -t "0:$WIN" -F '#{pane_current_command}' 2>/dev/null | head -1)
if [ "$CMD" != "claude" ]; then
  say "DECLINED: 0:$WIN is running '$CMD', not claude (crashed or exited?)"
  exit 0
fi

# --- 3. busy? the SPINNER is the reliable signal, not "esc to interrupt"
# ⚠️ unit class MUST include h — see the note in epic-nudge.sh: [ms] alone
# missed "(1h 6m 57s" and read a 67-minute generation as idle.
BUSY=$(printf '%s\n' "$PANE" | grep -oE '^[✻✽✢·✶*] [A-Za-z]+…* \([0-9]+[hms]' | tail -1)
if [ -n "$BUSY" ]; then
  say "DECLINED: $WORKER is generating ($BUSY)"
  exit 0
fi

# --- 4. queued input waiting on a keypress ----------------------------
if printf '%s\n' "$PANE" | grep -q 'Press up to edit queued'; then
  say "DECLINED: $WORKER has queued messages awaiting Enter"
  exit 0
fi

# --- 5. cooldown ------------------------------------------------------
if [ -f "$IDLE_MARKER" ]; then
  LAST=$(stat -c %Y "$IDLE_MARKER" 2>/dev/null || echo 0)
  AGE_MIN=$(( ( $(date +%s) - LAST ) / 60 ))
  if [ "$AGE_MIN" -lt "$COOLDOWN_MIN" ]; then
    say "DECLINED: nudged ${AGE_MIN}m ago, cooldown is ${COOLDOWN_MIN}m ($(( (COOLDOWN_MIN-AGE_MIN)/60 ))h left)"
    exit 0
  fi
fi

# --- 6. hard quota ceiling (NOT the burn ratio — see UTIL_MAX above) ---
READ=$(/home/jes/.local/bin/claude-quota --json 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print('ERR'); raise SystemExit
w = d.get('seven_day')
# A window can be PRESENT with resets_at NULL right after a roll. We only need
# utilisation here, not elapsed, so a null reset does not blind this check.
if not w or w.get('utilization') is None:
    print('ERR')
else:
    print('%.1f' % w['utilization'])
" 2>/dev/null)

if [ -z "$READ" ] || [ "$READ" = "ERR" ]; then
  say "CANNOT DETERMINE: quota read failed"
  exit 2
fi

if awk -v u="$READ" -v m="$UTIL_MAX" 'BEGIN{exit !(u>=m)}'; then
  say "DECLINED: 7d utilisation ${READ}% >= ${UTIL_MAX}% hard ceiling"
  exit 0
fi

# --- 7. all checks passed --------------------------------------------
# ⛔ THE MARKER RECORDS "GATE PASSED", NOT "NUDGE SENT", and those diverge
# whenever boss reads the output and decides not to dispatch. DRY=1 evaluates
# the gate WITHOUT committing the claim, so the file keeps saying something true.
if [ "${DRY:-0}" = "1" ]; then
  echo "(DRY=1: gate passed, marker NOT touched — nothing has been claimed)" >&2
else
  touch "$IDLE_MARKER"
fi
echo "PLAN_NUDGE|plan idle, 7d utilisation ${READ}% < ${UTIL_MAX}% ceiling"
exit 0
