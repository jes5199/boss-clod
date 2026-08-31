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
# --self-test: the arms live HERE, not in the author's terminal. A future edit that
# adds a fast path or drops the control trips this rather than passing quietly.
if [ "${1:-}" = "--self-test" ]; then
  self="$0"; fails=0
  t=$(mktemp -d); mkdir -p "$t/a/b/c/d/e"; : > "$t/a/b/c/d/e/deep.txt"; : > "$t/shallow.txt"
  empty=$(mktemp -d)
  check() { # name expected_rc ; runs remaining args
    n="$1"; want="$2"; shift 2
    "$@" >/dev/null 2>&1; got=$?
    if [ "$got" = "$want" ]; then echo "  ok   $n (rc=$got)"; else echo "  RED  $n expected rc=$want got rc=$got"; fails=$((fails+1)); fi
  }
  check "PRESENT on a file that exists"        1 "$self" "$t" -type f -name 'deep.txt'
  check "ABSENT when corpus reachable"         0 "$self" "$t" -type f -name 'no-such-file-xyz'
  check "BLIND refuses -maxdepth"              2 "$self" "$t" -maxdepth 4 -type f -name 'deep.txt'
  check "BLIND on empty corpus"                2 "$self" "$empty" -type f -name 'anything'
  check "BLIND on non-directory"               2 "$self" "$t/shallow.txt" -type f
  # ⭐ The arm that matters: a deep file must be FOUND, so a future depth bound cannot hide it.
  check "finds a 5-deep file (no depth bound)" 1 "$self" "$t" -type f -name 'deep.txt'
  rm -rf "$t" "$empty"
  [ "$fails" -eq 0 ] && { echo "SELF-TEST OK (6 arms)"; exit 0; }
  echo "SELF-TEST FAILED: $fails arm(s)"; exit 1
fi

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
