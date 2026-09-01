#!/usr/bin/env bash
# Dispatch one bounded coding slice to Sol via `codex exec`, in a DEDICATED TMUX PANE.
#
# ⭐ jes, 2026-09-01: "we were having better luck with Opus in each repo, dispatching to Sol in
# codexes over tmux" — and, on the earlier proxy attempt, "Sol through the proxy is too reticent."
# The difference is NOT the model: a Sol worker was a full Claude Code session with ANTHROPIC_BASE_URL
# pointed at the proxy. This runs the codex CLI itself.
#
# ⛔ WHY A PANE AND NOT A CHILD PROCESS (sol-tmux-run.sh, 2026-08-07): two prior codex dispatches were
# killed unexplained while parented to a Claude session's process tree. tmux gives it a parent that
# outlives the dispatching turn.
#
# Usage:  sol-codex-pane.sh <workdir> <prompt-file> [label]
# Prints: the log path (poll it; the pane is also visible in tmux)
# Exit:   0 launched · 2 BLIND (bad args, missing workdir/prompt, codex absent, tmux absent)
set -o pipefail
wd="${1-}"; pf="${2-}"; label="${3-sol}"
die(){ echo "BLIND|$1"; exit 2; }
[ -n "$wd" ] && [ -n "$pf" ] || die "usage: sol-codex-pane.sh <workdir> <prompt-file> [label]"
[ -d "$wd" ]  || die "workdir does not exist: $wd"
[ -r "$pf" ]  || die "prompt file not readable: $pf"
[ -s "$pf" ]  || die "prompt file is EMPTY: $pf — an empty prompt is not a dispatch"
command -v codex >/dev/null || die "codex not on PATH"
command -v tmux  >/dev/null || die "tmux not on PATH"
ts=$(date -u +%Y%m%dT%H%M%SZ)
log="/home/jes/boss-clod/logs/sol-codex-${label}-${ts}.log"
mkdir -p /home/jes/boss-clod/logs
win="sol-${label}"
tmux kill-window -t "$win" 2>/dev/null
tmux new-window -d -n "$win" -c "$wd" \
  "echo '=== $(date -u +%FT%TZ) codex start label=${label} wd=${wd} ===' | tee -a '$log'; \
   codex exec -m gpt-5.6-sol --sandbox workspace-write \"\$(cat '$pf')\" 2>&1 | tee -a '$log'; \
   rc=\${PIPESTATUS[0]}; echo \"=== $(date -u +%FT%TZ) codex EXIT rc=\$rc ===\" | tee -a '$log'; \
   exec bash" || die "tmux new-window failed"
echo "$log"
