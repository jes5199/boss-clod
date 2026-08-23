#!/usr/bin/env bash
# Watch the two commonplace-log* worker panes and report state.
#
# jes, 2026-08-23: "check the two commonplace-logs claudes every 15 minutes to
# make sure they're still working (unless they finish or get stuck!)"
#
# ⭐ WHY THIS IS A SCRIPT AND NOT A REMEMBERED CHECKLIST: a filed artifact fires,
# a remembered rule does not. The stuck-detection needs state across invocations
# (a hash + a first-seen timestamp), which cannot live in a session's memory.
#
# ⛔ RESOLVE WINDOWS BY NAME, NEVER BY INDEX -- indices shift on every renumber.
# ⛔ NO pgrep -f / pkill -f ANYWHERE: the pattern would match this script itself.
#
# Exit codes:  0 = printed a report   2 = instrument blind (no tmux server / no windows)
# Prints one STATUS| line per worker plus a SUMMARY| line. Silence is never a result.

set -uo pipefail

WORKERS=(commonplace-log commonplace-log-reducer)
STATE_DIR=/home/jes/boss-clod/.log-pair-watch
mkdir -p "$STATE_DIR"

# Minutes of byte-identical pane content before we call it stuck.
STUCK_MIN=${STUCK_MIN:-25}

now=$(date -u +%s)
nowiso=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if ! tmux list-windows -a >/dev/null 2>&1; then
  echo "BLIND|no tmux server reachable — this is an instrument failure, NOT a clean report"
  exit 2
fi

found=0
declare -a REPORT=()

for w in "${WORKERS[@]}"; do
  # Resolve by NAME. Exact match on the window name field.
  target=$(tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}' 2>/dev/null \
           | awk -v n="$w" '$2 == n {print $1; exit}')

  if [ -z "$target" ]; then
    REPORT+=("STATUS|$w|MISSING|no tmux window with that name")
    continue
  fi
  found=$((found+1))

  cmd=$(tmux list-panes -t "$target" -F '#{pane_current_command}' 2>/dev/null | head -1)
  pane_raw=$(tmux capture-pane -t "$target" -p 2>/dev/null)
  # ⚠️ The prompt line ends in U+00A0 NON-BREAKING SPACE, not an ASCII space, so
  # under LANG=C.UTF-8 a `[[:space:]]*$` anchor does NOT match it. That is what
  # made window 0:17 fall through to UNKNOWN on the first fixed run. Normalise
  # NBSP -> space before any matching. (Found by cat -A on the captured line.)
  pane=$(printf '%s' "$pane_raw" | sed 's/\xc2\xa0/ /g')
  tail_txt=$(printf '%s' "$pane" | grep -v '^[[:space:]]*$' | tail -25)

  # --- change tracking (stuck detection) -------------------------------------
  h=$(printf '%s' "$pane_raw" | sha256sum | cut -c1-16)
  hf="$STATE_DIR/$w.hash"; tf="$STATE_DIR/$w.since"
  if [ -r "$hf" ] && [ "$(cat "$hf")" = "$h" ]; then
    since=$(cat "$tf" 2>/dev/null || echo "$now")
  else
    since=$now
    printf '%s' "$h" > "$hf"
  fi
  printf '%s' "$since" > "$tf"
  still_min=$(( (now - since) / 60 ))

  # --- classify. Order matters: hard faults before soft ones. ----------------
  #
  # ⛔ THE BUG THIS BLOCK WAS BORN WITH (2026-08-23, first run): the original
  # version tested only for "esc to interrupt" and fell through to IDLE. BOTH
  # workers were busy and BOTH were reported IDLE -- a false green, on a gate's
  # first run, in an environment unlike the one it was written against. See
  # LESSONS.md 7x75.
  # ⭐ THE FIX IS THE THREAD'S OWN ANSWER: "no pattern matched" and "genuinely
  # idle" must NOT share an observable. Unrecognised now reports UNKNOWN, and
  # IDLE is only claimed when an idle-prompt is POSITIVELY matched.
  state=""; detail=""
  busy=""
  # Busy signals, any one of which means work is in flight:
  #   spinner with elapsed time+tokens:  "* Jitterbugging… (2m 12s · ↓ 1.9k tokens)"
  #   backgrounded agents:               "Waiting for 1 background agent to finish"
  #   agent tray row with a duration:    "◯ general-purpose  Reading … 2m 18s · ↓ 47.4k"
  #   classic foreground hint:           "esc to interrupt"
  printf '%s' "$pane" | grep -qE '\([0-9]+m ?[0-9]*s ·|\([0-9]+s ·' && busy="${busy}spinner "
  printf '%s' "$pane" | grep -qiE 'Waiting for [0-9]+ background agent' && busy="${busy}bg-agent "
  printf '%s' "$pane" | grep -qE '^[[:space:]]*[◯●][[:space:]]+[a-z].*[0-9]+m ?[0-9]*s ·' && busy="${busy}agent-tray "
  printf '%s' "$pane" | grep -qi 'esc to interrupt' && busy="${busy}esc-hint "

  if [ "$cmd" = "bash" ] || [ "$cmd" = "sh" ]; then
    state=CRASHED; detail="pane is at a $cmd prompt, not claude — needs workerclaude relaunch"
  elif printf '%s' "$pane" | grep -qi 'rate-limit-options\|Stop and wait for reset'; then
    state=RATE_LIMITED; detail="sitting at the rate-limit prompt — send Enter to select stop-and-wait"
  elif printf '%s' "$pane" | grep -qi 'Press up to edit queued messages'; then
    state=QUEUED; detail="has queued messages waiting — send Enter"
  elif [ -n "$busy" ]; then
    if [ "$still_min" -ge "$STUCK_MIN" ]; then
      state=STUCK; detail="busy [$busy] but pane byte-identical for ${still_min}m (threshold ${STUCK_MIN}m)"
    else
      state=WORKING; detail="busy [$busy], pane changed within ${still_min}m"
    fi
  elif printf '%s' "$pane" | grep -qE '^❯[[:space:]]*$|^[[:space:]]*❯[[:space:]]*$'; then
    state=IDLE; detail="idle prompt POSITIVELY matched, no busy signal — finished or awaiting input; quiet ${still_min}m"
  else
    # ⭐ The vacuous branch, made loud on purpose.
    state=UNKNOWN; detail="no known pattern matched — classifier may be blind to a new UI state; quiet ${still_min}m"
  fi

  ctx=$(printf '%s' "$pane" | grep -o '📊 [0-9]\+%' | tail -1)
  model=$(printf '%s' "$pane" | grep -o '\[[A-Za-z0-9. ]*\]' | tail -1)
  REPORT+=("STATUS|$w|$state|$detail|ctx=${ctx:-?}|model=${model:-?}|win=$target")
done

# ⭐ POSITIVE CONTROL: prove the corpus was non-empty before trusting any verdict.
# Zero windows found and two healthy-but-silent workers look identical otherwise.
if [ "$found" -eq 0 ]; then
  echo "BLIND|resolved 0 of ${#WORKERS[@]} worker windows by name — instrument blind, not a clean report"
  printf '%s\n' "${REPORT[@]}"
  exit 2
fi

printf '%s\n' "${REPORT[@]}"
echo "SUMMARY|$nowiso|resolved $found of ${#WORKERS[@]} windows|stuck_threshold=${STUCK_MIN}m"
