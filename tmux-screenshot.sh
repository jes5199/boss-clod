#!/bin/bash
# Capture a tmux pane and render it to PNG using freeze
# Usage: tmux-screenshot.sh [window.pane] [output.png]
# Examples:
#   tmux-screenshot.sh 3.0              # capture pane 3.0, output to /tmp/tmux-screenshot.png
#   tmux-screenshot.sh 3.0 output.png   # capture pane 3.0, output to output.png

PANE="${1:-0.0}"
OUTPUT="${2:-/tmp/tmux-screenshot.png}"

# Capture pane content with ANSI escape codes
tmux capture-pane -t "$PANE" -e -p > /tmp/tmux-capture.txt

# Render to PNG with freeze
freeze /tmp/tmux-capture.txt \
  --language "" \
  --theme "Dracula" \
  --font.family "DejaVu Sans Mono" \
  --font.size 14 \
  --window \
  --padding "10,10,10,10" \
  --output "$OUTPUT" 2>/dev/null

if [ -f "$OUTPUT" ]; then
  echo "$OUTPUT"
else
  echo "Error: failed to generate screenshot" >&2
  exit 1
fi
