#!/usr/bin/env bash
# ⛔ pipefail: without it a pipeline reports the LAST stage. For a 0/1/2 script CAPTURE FIRST.
set -o pipefail
# ⭐ DOES A QUOTED LINE STILL EXIST AT THE FAR END?
#
# commonplace-next, 2026-09-01: "a citation is true of a MOMENT and decays silently from the FAR END.
# THE CITING DOCUMENT NEVER CHANGES, SO NOTHING LOCAL CAN DETECT IT." Three forms in one night:
# a claim false when written, a claim true then aged, and A CORRECT QUOTATION OF A STRUCK SOURCE.
#
# ⛔⛔ AND WHY THIS IS A SCRIPT AND NOT A HABIT — next's own critique of my first answer:
# "'I relay strikes as their own message from now on' IS A REMEMBERED RULE, AND TONIGHT'S FINDING IS
# THAT THOSE DO NOT FIRE." Three doors held a rule while writing its counterexample; one repo's
# CLAUDE.md carried "a filed artifact fires; a remembered rule does not" in context all night and the
# door still broke it twice. ⇒ THE REMEDY FOR A DECAYING CITATION CANNOT BE REMEMBERING TO CHECK.
#
# Usage:  cite-check.sh <repo-path> <file-in-that-repo> <quoted-phrase> [more phrases...]
# Exit:   0 = every phrase still present at origin/main
#         1 = at least one phrase HAS MOVED OR GONE  (the far end moved)
#         2 = BLIND (bad repo, unreachable remote, file absent at main, no phrases given)
repo="${1-}"; file="${2-}"; shift 2 2>/dev/null
[ -n "$repo" ] && [ -n "$file" ] && [ $# -gt 0 ] || { echo "BLIND|usage: cite-check.sh <repo> <file> <phrase>..."; exit 2; }
[ -d "$repo/.git" ] || { echo "BLIND|not a git repo: $repo"; exit 2; }
git -C "$repo" fetch -q origin 2>/dev/null || { echo "BLIND|fetch failed for $repo — the far end is unreachable, which is not the same as unchanged"; exit 2; }
head=$(git -C "$repo" rev-parse origin/main 2>/dev/null)
[ -n "$head" ] || { echo "BLIND|cannot resolve origin/main in $repo"; exit 2; }
body=$(git -C "$repo" show "$head:$file" 2>/dev/null)
[ -n "$body" ] || { echo "BLIND|$file does not exist (or is empty) at origin/main $head — a citation to a deleted file reads the same as a live one"; exit 2; }
moved=0; checked=0
for phrase in "$@"; do
  checked=$((checked+1))
  if printf '%s' "$body" | grep -qF -- "$phrase"; then
    printf 'PRESENT | %s\n' "$phrase"
  else
    printf 'MOVED   | %s\n' "$phrase"; moved=$((moved+1))
  fi
done
if [ "$moved" -gt 0 ]; then
  echo "DRIFT|$moved of $checked cited phrase(s) no longer present in $file at origin/main $head"
  exit 1
fi
echo "CURRENT|$checked of $checked cited phrase(s) still present in $file at origin/main $head"
exit 0
