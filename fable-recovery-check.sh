#!/usr/bin/env bash
# Is the Fable-scoped weekly meter still exhausted, and which workers are affected?
#
# ⚠️ quota-guard.sh watches 5h and 7d ONLY. It does NOT watch the Fable scope, so
# a Fable wall is invisible to it -- which is how two workers ran ~24h on Opus
# while everyone believed they were on Fable (2026-08-22/23).
#
# ⭐ THE LOAD-BEARING PART OF THE STANDING DIRECTIVE IS SWITCHING BACK (jes
# 2026-07-06: "as long as we remember to switch back"). A remembered rule does
# not fire; this does.
#
# rc 0 = report printed   2 = instrument blind (no meter found / quota tool failed)

set -uo pipefail
Q=/home/jes/.local/bin/claude-quota

json=$("$Q" --json 2>/dev/null)
if [ -z "$json" ]; then
  echo "BLIND|claude-quota produced no JSON — instrument failure, NOT a clean 'Fable is fine'"
  exit 2
fi

# ⭐ POSITIVE CONTROL FIRST: a missing Fable entry and a healthy Fable meter look
# identical if we only test for "percent >= 100". Prove the entry EXISTS before
# believing anything it says. (Read the control before you believe the alarm.)
read -r found pct resets < <(printf '%s' "$json" | python3 -c '
import json,sys
d=json.load(sys.stdin)
for l in d.get("limits",[]):
    sc=(l.get("scope") or {}).get("model") or {}
    if (sc.get("display_name") or "").lower()=="fable":
        print(1, l.get("percent"), l.get("resets_at")); break
else:
    print(0, "-", "-")
')

if [ "$found" != "1" ]; then
  echo "BLIND|no weekly_scoped entry with scope.model.display_name=Fable in the quota payload"
  echo "BLIND|that is NOT evidence Fable is healthy — the shape may have changed. Fix this check."
  exit 2
fi

# Which running workers ASKED for Fable, and what are they actually on?
affected=""
while read -r win name; do
  [ -z "$win" ] && continue
  p=$(tmux list-panes -t "$win" -F '#{pane_pid}' 2>/dev/null | head -1)
  [ -z "$p" ] && continue
  for c in $(pgrep -P "$p" 2>/dev/null); do
    cl=$(tr '\0' ' ' < "/proc/$c/cmdline" 2>/dev/null)
    case "$cl" in
      *claude*--model*fable*)
        live=$(tmux capture-pane -t "$win" -p 2>/dev/null | grep -o '\[[A-Za-z0-9. ]*\]' | tail -1)
        affected="${affected}${name}(asked=fable,running=${live:-?}) "
        ;;
    esac
  done
done < <(tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}' 2>/dev/null)

if [ "${pct%.*}" -ge 100 ]; then
  echo "FABLE|EXHAUSTED|percent=$pct|resets_at=$resets"
  echo "FABLE|affected=${affected:-none — no running worker was launched asking for Fable}"
  echo "FABLE|action=none now; switch back AFTER $resets"
else
  echo "FABLE|RECOVERED|percent=$pct|resets_at=$resets"
  echo "FABLE|affected=${affected:-none}"
  echo "FABLE|action=SWITCH FABLE-INTENDED WORKERS BACK. A fresh 'workerclaude --model claude-fable-5'"
  echo "FABLE|       launch holds better than in-session /model, but costs context — weigh per worker."
fi
