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
# ⚠️ WHAT IT STILL CANNOT DO, stated because the next reader will meet it: it cannot see a sentence
# that STAYED TRUE-LOOKING WHILE THE WORLD MOVED UNDER IT — the roadmap's "Organization Space is an
# open question" was never edited; jes's answer simply arrived elsewhere. PIN A BYTE STRING AND THE
# CITATION CANNOT DECAY; NAME A STATE AND IT ALWAYS CAN (commonplace-cell). This covers struck and
# reworded text. It does not cover state claims.
#
# Usage:  cite-check.sh <repo-path> <file-in-that-repo> <quoted-phrase> [more phrases...]
# Exit:   0 = every phrase still present at origin/main
#         1 = at least one phrase MOVED, GONE, or is PRESENT INSIDE A STRIKE (far end moved)
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
# ⛔⛔ LINE-WRAPPED CITATIONS READ AS DRIFT — found by commonplace-cell from a second door, 2026-09-01.
# Every markdown doc in this fleet hard-wraps at ~100 columns, so ANY citation long enough to be worth
# checking is the one most likely to CROSS A WRAP. A line-oriented check called those DRIFT.
# ⚠️ AND IT DID NOT FAIL SAFE: rc=1 is a FINDING, so it MANUFACTURED strikes — and a door that gets one
# for a phrase plainly still there stops trusting the tool on the day it is right.
# ⭐ AND IT WAS THE EASY-END WITNESS AGAIN, IN THE ARMS OF THE TOOL BUILT TO FIX THE LAST ONE: my six
# arms all used phrases that HAPPENED NOT TO WRAP. Probes ①②③ all pass on that fixture.
# ⇒ FIX: fold newlines to spaces and collapse runs on BOTH sides, so the subject is THE DOCUMENT'S
# TEXT rather than THE DOCUMENT'S LINES. Widening the subject cannot narrow it.
fold(){ printf '%s' "$1" | tr '\n' ' ' | tr -s ' '; }
folded_body=$(fold "$body")
for phrase in "$@"; do
  checked=$((checked+1))
  fp=$(fold "$phrase")
  # ⛔ FALSE DRIFT FROM A TRANSCRIPTION SLIP — found by commonplace-next, 2026-09-01: a lowercased
  # first letter read as a strike. ⚠️ THE TWO FAILURE DIRECTIONS ARE ASYMMETRIC IN COST:
  #   FALSE CURRENT — a struck ruling preserved inside the strike. Silent, and it is the house style.
  #   FALSE DRIFT   — the citer's own case/whitespace slip. LOUD, and it ACCUSES THE FAR END of a
  #                   change that never happened.
  # The second erodes the tool fastest: a gate that fires on correct state is worse than no gate, and
  # a door that gets two false DRIFTs stops running it — then the true one arrives unread.
  # ⇒ Compare case-insensitively, and NEVER assert the far end moved when the phrase is simply absent.
  if ! printf '%s' "$folded_body" | grep -qiF -- "$fp"; then
    printf 'NOTFOUND| %s\n' "$phrase"
    printf '        └ not present at origin/main. Check YOUR TRANSCRIPTION first — this does not\n'
    printf '          establish that the far end changed.\n'
    moved=$((moved+1)); continue
  fi
  # ⛔ A STRUCK RULING WHOSE WORDING IS PRESERVED INSIDE THE STRIKE READS AS PRESENT (next, 2026-09-01).
  # Striking in place with the original preserved IS the house style, so this is the DOMINANT form.
  # Presence cannot see a strike; the marker can. Two syntaxes measured in the real corpus:
  #   `~~struck text~~`  ·  `⛔ … is struck: *"quoted wording"*` / `CORRECTED yyyy-mm-dd`
  # Look in a WINDOW BEFORE the match, since folding removed the line that used to bound it.
  win=$(printf '%s' "$folded_body" | awk -v IGNORECASE=1 -v p="$fp" '{i=index($0,p); if(i){s=i-260; if(s<1)s=1; print substr($0,s,i-s+length(p))}}')
  if printf '%s' "$win" | grep -qE '~~|is struck|CORRECTED [0-9]{4}-|SUPERSEDED|WITHDRAWN'; then
    printf 'STRUCK  | %s\n' "$phrase"
    printf '        └ present INSIDE A STRIKE — the text survives, the ruling does not\n'
    moved=$((moved+1))
  else
    printf 'PRESENT | %s\n' "$phrase"
  fi
done
if [ "$moved" -gt 0 ]; then
  echo "DRIFT|$moved of $checked cited phrase(s) STRUCK or NOT FOUND in $file at origin/main $head"
  exit 1
fi
echo "CURRENT|$checked of $checked cited phrase(s) still present in $file at origin/main $head"
exit 0
