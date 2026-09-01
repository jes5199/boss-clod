#!/bin/bash
# ⛔ pipefail: without it a pipeline reports the LAST stage, so a failing script read through
# a filter looks green. NOTE it does NOT save 1-vs-2 when a second stage also fails -- for a
# 0/1/2 script CAPTURE FIRST: out=$(script); rc=$?   (boss-clod, 2026-09-01)
set -o pipefail
# Isolation experiment: run Sol OUTSIDE commonplace's process tree.
# Two prior codex dispatches were killed unexplained while parented to
# commonplace's Claude session; general journal shows nothing machine-level.
# This changes exactly one variable — the parent tree. Boss-owned.
cd /home/jes/sol-perf/wt || exit 2
LOG=/home/jes/boss-clod/logs/sol-compact-tmux.log
echo "=== $(date -u +%FT%TZ) sol start (pid $$, ppid $PPID) ===" >> "$LOG"
codex exec -m gpt-5.6-sol --sandbox workspace-write "$(cat /home/jes/boss-clod/sol-compact-prompt.txt)" >> "$LOG" 2>&1
rc=$?
echo "=== $(date -u +%FT%TZ) sol EXITED rc=$rc ===" >> "$LOG"
