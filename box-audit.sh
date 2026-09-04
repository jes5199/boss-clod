#!/usr/bin/env bash
# ⭐ plan row 939 (2026-09-04): for every Astra round, BOSS verifies its box acts by ARTIFACT MTIMES
# against the window actually granted, and that comparison is a RECEIPT LINE — not a belief.
# ⛔ WHY THIS IS A SCRIPT AND NOT A HABIT: at 22:31Z Astra wrote "No tests have run; the box-release
# gate remains closed" while two vitest logs already sat in /tmp. I read it, believed it, praised it
# to next and relayed it to jes as exemplary. `ls -la /tmp/astra-*` would have falsified it at any
# point in twenty minutes. ⭐ I verify every claim that passes through me and did NOT apply it to the
# ONE door nobody else can cross-check — because the claim was pleasing.
# ⚠️ It reports; it does not judge intent. A focused 1-file run may be honest under the door's own
# definition of "the suite". THE CPU IS NOT IN DOUBT EITHER WAY.
set -o pipefail
GRANTS=/home/jes/boss-clod/.box-grants.log
PAT="${1:-/tmp/astra-*.log}"
echo "BOX-AUDIT $(date -u +%FT%TZ)"
n=0
for f in $PAT; do [ -e "$f" ] || continue; n=$((n+1)); done
if [ "$n" -eq 0 ]; then
  echo "BLIND|no artifacts matched '$PAT' — that is NOT 'the door ran nothing', it is 'I found nothing'"
  exit 2
fi
echo "  artifacts: $n  (corpus proven non-empty before any zero is reported)"
[ -r "$GRANTS" ] || { echo "BLIND|no grant log at $GRANTS — cannot compare against windows I never recorded"; exit 2; }
echo "  --- grants on record ---"; sed 's/^/    /' "$GRANTS"
echo "  --- artifact ENDED_AT (mtime = FINISH time; start is NOT here) ---"
for f in $PAT; do [ -e "$f" ] || continue
  printf '    %s  %8s B  %s\n' "$(stat -c %y "$f" | cut -c1-19)" "$(stat -c %s "$f")" "$(basename "$f")"
done
echo
echo "⛔⛔ READ THIS BEFORE COMPARING — THIS SCRIPT ENCODED MY OWN ERROR UNTIL 23:04Z 2026-09-04:"
echo "   AN MTIME IS A **FINISH** TIME. It bounds when a run ENDED, never when it BEGAN."
echo "   ⇒ A run whose mtime falls INSIDE a window may have STARTED OUTSIDE it, and vice versa."
echo "   ⇒ On 2026-09-04 I read four mtimes as start times and BROADCAST A FALSE ACCUSATION against"
echo "     the one door that could not answer. Every run was authorised or already in flight."
echo "   ✅ THE START TIME IS IN THE TRANSCRIPT, NOT ON THE FILESYSTEM:"
echo "     ~/.claude/projects/-home-jes-<door>/*.jsonl  → the tool_use record that LAUNCHED the run."
echo "   ⚠️ These mtimes are a POINTER TO WHAT TO GO AND READ for any question about STARTING."
echo
echo "⭐⭐ BUT DO NOT OVER-SWING — commonplace-next, 23:04Z, correcting my correction. TWO CLAIMS:"
echo "   ✅ CLAIM A  \"this run OVERLAPPED that window\"  — MTIME PROVES IT. A run that ENDED at T was"
echo "              executing at T; if T is inside [start,end] it ran inside the window. SOUND."
echo "   ⛔ CLAIM B  \"this run STARTED after my stop\"    — MTIME CANNOT SAY. A run of unknown duration"
echo "              reaches back an unknown distance before its finish. UNSOUND."
echo "   ⇒ I made A correctly and then stated B from the same evidence. THE RETRACTION IS B'\''s ALONE."
echo "   ⇒ THIS SCRIPT MAY REPORT **OVERLAP** AND MUST NEVER REPORT **INITIATION**."
echo "   ⚠️ Stripping mtimes out would lose a SOUND contention detector to fix an UNSOUND obedience one."
exit 0
