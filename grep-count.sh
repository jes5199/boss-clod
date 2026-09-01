#!/usr/bin/env bash
# ⭐ REFUSES TO REPORT A ZERO THAT NO CONTROL SUPPORTS.
#
# WHY THIS EXISTS (2026-09-01, commonplace-plan): four times in one evening a zero of mine was my
# SELECTOR rather than the world — a -maxdepth that hid the corpus, a pipe pattern that matched only
# four sinks, a jose pin grep, and "invocation"/"positional" against a report that names the same
# arms differently. absence-check.sh already existed for exactly this and I grepped by hand anyway.
# ⛔ THE ARTIFACT EXISTED AND THE MOMENT DID NOT SUMMON IT. A remembered rule does not fire; a
# script you must call does. This is the wrapper, so "I am about to believe a zero" has a command.
#
# Usage:  ./grep-count.sh PATTERN FILE [FILE...]        (add -i / -E before PATTERN if needed)
# Exit:   0 = PRESENT (n>0)   1 = ABSENT, corpus proven readable AND non-vacuous   2 = BLIND
#
# The control is derived FROM THE DATA, not guessed: a literal token taken out of the corpus itself
# must match. If that fails, the instrument is blind and you get rc=2, never a clean-looking zero.
set -o pipefail
opts=(); while [ $# -gt 0 ]; do case "$1" in -*) opts+=("$1"); shift;; *) break;; esac; done
pat="${1-}"; shift || true
if [ -z "$pat" ] || [ $# -eq 0 ]; then echo "BLIND|no pattern or no corpus given"; exit 2; fi
missing=0; readable=0; bytes=0
for f in "$@"; do
  if [ -r "$f" ]; then readable=$((readable+1)); bytes=$((bytes + $(stat -c%s "$f" 2>/dev/null || echo 0)))
  else missing=$((missing+1)); fi
done
if [ "$readable" -eq 0 ]; then echo "BLIND|no readable file among $# named ($missing unreadable/absent)"; exit 2; fi
if [ "$bytes" -eq 0 ]; then echo "BLIND|corpus readable but ZERO BYTES across $readable file(s) — a zero here means empty, not absent"; exit 2; fi
n=$(command grep "${opts[@]}" -c -- "$pat" "$@" 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')
if [ "$n" -gt 0 ]; then
  echo "PRESENT|$n hit(s) for '$pat' across $readable file(s), $bytes bytes"
  exit 0
fi
# n==0 — prove the instrument can see SOMETHING before believing the absence.
ctl=$(command grep -m1 -oE '[A-Za-z0-9_]{4,}' -- "$@" 2>/dev/null | head -1 | sed 's/^.*://')
if [ -z "$ctl" ]; then echo "BLIND|corpus has $bytes bytes but no extractable control token — cannot prove the reader works"; exit 2; fi
cn=$(command grep -c -- "$ctl" "$@" 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')
if [ "$cn" -eq 0 ]; then
  echo "BLIND|POSITIVE CONTROL FAILED: '$ctl' was taken from the corpus and still matched 0 — the reader is blind, the subject is not absent"
  exit 2
fi
echo "ABSENT|0 hits for '$pat'; corpus proven non-vacuous ($readable file(s), $bytes bytes; control '$ctl' matched $cn)"
echo "       ⚠️ 0 hits for YOUR pattern is not 0 hits for the CONCEPT — check the corpus's own vocabulary before reporting it missing."
exit 1
