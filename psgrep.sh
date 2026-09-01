#!/bin/bash
# ⛔ pipefail: without it a pipeline reports the LAST stage, so a failing script read through
# a filter looks green. NOTE it does NOT save 1-vs-2 when a second stage also fails -- for a
# 0/1/2 script CAPTURE FIRST: out=$(script); rc=$?   (boss-clod, 2026-09-01)
set -o pipefail
# psgrep — pgrep -af without matching your own shell or the grep itself.
#
# WHY THIS EXISTS: on 2026-08-06/07, `pgrep -f <pattern>` returned phantom
# matches to EVERY agent on this box — boss-clod three times in one night,
# commonplace twice. The mechanism: the searching shell's own command line
# ("bash -c 'pgrep -f codex'") contains the pattern, so the search finds
# itself and reports a process that is only the act of looking.
#
# Consequences seen: "hermes not running" on a box where hermes was fine
# (nearly a broad-kill incident), and "Sol still running" when it had exited.
# A rule in a notes file did not prevent any of the five occurrences. This is
# the mechanism version.
#
# Usage:  psgrep <pattern>          # like pgrep -af, minus the lies
#         psgrep -q <pattern>       # quiet: exit 0 if a REAL match exists
psgrep() {
  local quiet=0
  [ "$1" = "-q" ] && { quiet=1; shift; }
  local pat="$1" out
  out=$(pgrep -af -- "$pat" 2>/dev/null \
        | grep -vE "^($$|$PPID) " \
        | grep -vE "bash -c|/bin/sh -c|psgrep")
  [ "$quiet" = "1" ] && { [ -n "$out" ]; return $?; }
  printf '%s' "$out"
  [ -n "$out" ]
}

# ⛔ 2026-08-09: THIS FILE ONLY DEFINED THE FUNCTION AND NEVER CALLED IT.
# The moment I put it on PATH as `psgrep`, running it EXECUTED NOTHING and
# exited 0 with no output — i.e. it answered "no matches" for every query,
# on a box where the processes plainly existed.
# ⭐ A silent, well-formed, confident WRONG ANSWER — the exact class this
# file was written to prevent, reintroduced by making it reachable.
# ⚠️ Sourcing it worked; executing it did not. Nothing announced the
# difference. Hence: dispatch when executed, still safe to source.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  if [ $# -eq 0 ]; then
    echo "usage: psgrep [-q] <pattern>" >&2
    exit 64
  fi
  psgrep "$@"
  rc=$?
  # printf above emits no trailing newline; add one for terminal use.
  [ $rc -eq 0 ] && echo
  exit $rc
fi
