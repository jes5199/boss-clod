#!/bin/bash
# ⛔ pipefail: without it a pipeline reports the LAST stage, so a failing script read through
# a filter looks green. NOTE it does NOT save 1-vs-2 when a second stage also fails -- for a
# 0/1/2 script CAPTURE FIRST: out=$(script); rc=$?   (boss-clod, 2026-09-01)
set -o pipefail
# Agent status report with progress bars
# Scrapes context window % from tmux status lines
# Usage: agent-status.sh

bar() {
  local pct=$1
  local width=20
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  printf '['
  printf '%0.s█' $(seq 1 $filled 2>/dev/null)
  printf '%0.s░' $(seq 1 $empty 2>/dev/null)
  printf '] %3d%%' "$pct"
}

echo "=== Agent Status ==="
echo ""

for pane in $(tmux list-panes -a -F '#{window_index}.#{pane_index}' 2>/dev/null); do
  # Skip weechat (0.0) and boss-clod (6.0)
  [[ "$pane" == "0.0" || "$pane" == "6.0" ]] && continue
  path=$(tmux display-message -t "$pane" -p '#{pane_current_path}' 2>/dev/null)
  name=$(basename "$path")
  cmd=$(tmux display-message -t "$pane" -p '#{pane_current_command}' 2>/dev/null)

  pct_line=$(tmux capture-pane -t "$pane" -p 2>/dev/null | grep -oP '📊 \d+%' | tail -1)
  pct=$(echo "$pct_line" | grep -oP '\d+')
  pct=${pct:-0}

  if [ "$cmd" = "claude" ]; then
    status="running"
  else
    status="STOPPED"
  fi

  printf "%-18s %s  %s\n" "$name" "$(bar $pct)" "$status"
done
