#!/bin/bash
# Check that every referent a Queue row names actually resolves where a reader stands.
#
# ⭐ WHY (2026-08-31): tonight's expensive failures were not bad arguments, they were
# referents that did not resolve — a "frozen root-claim function" never created, a
# run-root name scoped to a superseded candidate, a deps path that resolves only with
# deps fetched. Four stops, ~2h. None from flawed reasoning.
#
# ⛔ IT CANNOT catch a referent that resolves and means the wrong thing (`origin`
# answering from the wrong repo; `r`/`t` nested inside `oth`). Those need a reader.
# The point is to stop spending a reader on the mechanical half.
#
# Usage: row-referents.sh <queue-file> <row-number> [--at-publish]
#   rc 0 = all referents consistent with their intent
#   rc 1 = at least one RED
#   rc 2 = BLIND (bad input; a zero would be uninformative)
#
# INTENT is inferred, because a checker that flags a correct row is worse than none:
#   MUST-BE-ABSENT  path sits near absence language -> RED if it RESOLVES
#   EPHEMERAL       /tmp path -> only checked with --at-publish; a stale run root is
#                   expected to vanish, and reds on old rows are how a gate gets ignored
#   MUST-RESOLVE    everything else -> RED if it does not resolve

set -o pipefail  # ⛔ 2026-08-31: a pipeline eats the status of the command that matters —
                 # `cmd | tail` reports tail's success. Without this, a verdict printed
                 # through a pipe can say FAILED and exit 0. quota-guard.sh already had it.
usage() { echo "usage: $0 <queue-file> <row-number> [--at-publish]" >&2; exit 2; }

if [ "${1:-}" = "--self-test" ]; then
  # ⛔ $0 is a bare relative name under `bash row-referents.sh` and cannot be re-invoked:
  # every arm returns 127 and the self-test reports 4/4 RED. A harness that cannot start
  # fails every arm identically — which is the tell. ⭐ WHEN EVERY ARM FAILS THE SAME WAY,
  # SUSPECT THE HARNESS, NOT THE SUBJECT.
  self=$(readlink -f "$0") || { echo "SELF-TEST BLIND: cannot resolve \$0"; exit 2; }
  [ -x "$self" ] || { echo "SELF-TEST BLIND: resolved self is not executable: $self"; exit 2; }
  t=$(mktemp -d); fails=0
  # a row with a real path, a deliberate absence, and an ephemeral run root
  cat > "$t/good.md" <<'ROW'
r1
require exact new path `/tmp/definitely-not-here-xyz` absent immediately before action, and `/tmp/also-absent-xyz` absent, and `/tmp/third-absent-xyz` absent. Instrument at `/etc/hostname`.
ROW
  # a row naming a path that was never created
  cat > "$t/bad.md" <<'ROW'
r1
use the same frozen root-claim function at `/tmp/never-created-by-anyone-xyz` and the checker `/etc/hostname`.
ROW
  "$self" "$t/good.md" 2 >/dev/null 2>&1
  [ $? -eq 0 ] && echo "  ok   green on correct row with 3 deliberate absences" || { echo "  RED  green-arm failed"; fails=$((fails+1)); }
  "$self" "$t/bad.md" 2 >/dev/null 2>&1
  [ $? -eq 1 ] && echo "  ok   red on 'the same frozen X' that was never created" || { echo "  RED  red-arm failed"; fails=$((fails+1)); }
  # a /tmp path the row will CREATE must stay ephemeral, not red
  cat > "$t/creates.md" <<'ROW'
r1
create the receipt at `/tmp/will-be-made-later-xyz` when the run completes.
ROW
  "$self" "$t/creates.md" 2 >/dev/null 2>&1
  [ $? -eq 0 ] && echo "  ok   ephemeral output path does not red on re-read" || { echo "  RED  ephemeral-arm failed"; fails=$((fails+1)); }
  "$self" "$t/nope.md" 2 >/dev/null 2>&1
  [ $? -eq 2 ] && echo "  ok   BLIND on missing input" || { echo "  RED  blind-arm failed"; fails=$((fails+1)); }
  rm -rf "$t"
  [ "$fails" -eq 0 ] && { echo "SELF-TEST OK (4 arms)"; exit 0; }
  echo "SELF-TEST FAILED: $fails arm(s)"; exit 1
fi

[ $# -ge 2 ] || usage
file="$1"; row="$2"; at_publish="${3:-}"
[ -r "$file" ] || { echo "BLIND|unreadable: $file" >&2; exit 2; }
line=$(sed -n "${row}p" "$file")
[ -n "$line" ] || { echo "BLIND|row $row is empty in $file" >&2; exit 2; }

red=0
# Absolute paths inside backticks are the citable form these rows use.
paths=$(printf '%s' "$line" | grep -oE '`/[A-Za-z0-9._/-]+`' | tr -d '`' | sort -u)
for p in $paths; do
  # intent: absence language within 120 chars after the mention
  ctx=$(printf '%s' "$line" | grep -oE "\`${p//\//\\/}\`[^\`]{0,120}")
  # ⭐ Reuse language is the signal that cost us a stop: "the SAME frozen root-claim
  # function" names something that must ALREADY exist. A /tmp path is only ephemeral
  # when the row is going to CREATE it; when the row says it is reusing one, absence
  # is the defect. Look before the mention as well as after.
  pre=$(printf '%s' "$line" | grep -oE "[^\`]{0,80}\`${p//\//\\/}\`")
  # ⛔ Absence language must come from AFTER the mention and reuse language from BEFORE
  # it. Matching both windows against both vocabularies lets one referent's "absent"
  # bleed onto the next referent in the same sentence — which it did, and turned a
  # correct row red. A gate that fires on correct state is worse than no gate.
  case "$ctx" in
    *absent*|*"must not exist"*|*"never created"*|*"no such"*) intent=MUST-BE-ABSENT ;;
    *)
      case "$pre" in
        *"the same "*|*frozen*|*existing*|*already*|*retained*|*reuse*) intent=MUST-RESOLVE ;;
        *) case "$p" in /tmp/*) intent=EPHEMERAL ;; *) intent=MUST-RESOLVE ;; esac ;;
      esac ;;
  esac
  if [ -e "$p" ]; then exists=yes; else exists=no; fi
  case "$intent" in
    MUST-BE-ABSENT)
      if [ "$exists" = yes ]; then echo "RED   |MUST-BE-ABSENT but resolves: $p"; red=1
      else echo "ok    |absent as required: $p"; fi ;;
    EPHEMERAL)
      if [ "$at_publish" = "--at-publish" ]; then
        if [ "$exists" = yes ]; then echo "ok    |ephemeral present at publish: $p"
        else echo "RED   |ephemeral missing at publish: $p"; red=1; fi
      else echo "skip  |ephemeral, not checked on re-read: $p"; fi ;;
    MUST-RESOLVE)
      if [ "$exists" = yes ]; then echo "ok    |resolves: $p"
      else echo "RED   |UNRESOLVABLE: $p"; red=1; fi ;;
  esac
done

# SHAs must name their repo; an unscoped SHA cannot be checked and says so.
for sha in $(printf '%s' "$line" | grep -oE '\b[0-9a-f]{7,40}\b' | sort -u); do
  found=""
  for r in commonplace-plan commonplace-next boss-clod commonplace-cell commonplace-biscuit hermes; do
    case "$line" in *"$r"*) [ -d "/home/jes/$r/.git" ] && git -C "/home/jes/$r" cat-file -e "$sha" 2>/dev/null && { echo "ok    |sha $sha resolves in $r"; found=1; break; } ;; esac
  done
  [ -z "$found" ] && echo "note  |sha $sha unscoped or unresolved — name its repository"
done

[ "$red" -eq 0 ] && exit 0 || exit 1
