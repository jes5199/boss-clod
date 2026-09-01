#!/bin/bash
# ⛔ pipefail: without it a pipeline reports the LAST stage, so a failing script read through
# a filter looks green. NOTE it does NOT save 1-vs-2 when a second stage also fails -- for a
# 0/1/2 script CAPTURE FIRST: out=$(script); rc=$?   (boss-clod, 2026-09-01)
set -o pipefail
# Sol run for CX-a449, launched OUTSIDE commonplace's process tree.
# Two prior codex dispatches died as children of commonplace's session;
# one completed cleanly when parented to the tmux server instead.
# Flags match that PROVEN run (-m gpt-5.6-sol --sandbox workspace-write),
# deliberately not --full-auto, which was never the tested configuration.
cd /home/jes/sol-a449/wt || exit 2
LOG=/home/jes/boss-clod/logs/sol-a449.log
echo "=== $(date -u +%FT%TZ) sol a449 start (pid $$, ppid $PPID) ===" >> "$LOG"
codex exec -m gpt-5.6-sol --sandbox workspace-write "$(cat /home/jes/sol-a449/BRIEF.md)" >> "$LOG" 2>&1
echo "=== $(date -u +%FT%TZ) sol a449 EXITED rc=$? ===" >> "$LOG"
