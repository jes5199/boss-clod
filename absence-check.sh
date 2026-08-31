#!/bin/bash
# Prove an absence, or refuse to.
#
# ⭐ WHY THIS EXISTS (2026-08-31): twice in eleven minutes I ran `find -maxdepth 4`
# to prove something was missing, validated it with a control that shared the same
# depth limit, and reported the silence as absence. /tmp holds 190,354 files deeper
# than 4 components. Both times the wrong answer was PLAUSIBLE, so nothing summoned
# the filed rule — a lesson file only fires when a result looks absurd.
# ⇒ The check has to ride the action, not the memory.
#
# Usage: absence-check.sh DIR [find-predicates...]
#   rc 0 = ABSENT, and the corpus was proven reachable
#   rc 1 = PRESENT (hits printed)
#   rc 2 = BLIND — the traversal itself found nothing at all, so a zero means nothing
usage() { echo "usage: $0 DIR [find-predicates...]" >&2; exit 2; }
[ $# -ge 1 ] || usage
dir="$1"; shift
[ -d "$dir" ] || { echo "BLIND|not a directory: $dir" >&2; exit 2; }

# ⛔ A depth bound is exactly how both failures happened. Refuse it outright.
for a in "$@"; do
  case "$a" in
    -maxdepth) echo "BLIND|-maxdepth passed to an absence check; the bound is how a blind search looks clean" >&2; exit 2 ;;
  esac
done

# CONTROL FIRST, and it must share the traversal but NOT the discriminating predicate.
control=$(find "$dir" -type f 2>/dev/null | head -1)
if [ -z "$control" ]; then
  echo "BLIND|traversal of $dir returned no files at all — a zero here is uninformative" >&2
  exit 2
fi

hits=$(find "$dir" "$@" 2>/dev/null)
if [ -n "$hits" ]; then
  printf '%s\n' "$hits"
  echo "PRESENT|$(printf '%s\n' "$hits" | wc -l) hit(s)" >&2
  exit 1
fi
echo "ABSENT|0 hits; corpus proven reachable (control: $control)" >&2
exit 0
