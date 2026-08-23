#!/usr/bin/env bash
# Which repos hold commits that exist ONLY on this droplet's disk?
#
# ⭐ WHY: 2026-08-23. commonplace-log-reducer reported a doc "filed at main
# 1df1015". It was COMMITTED, not PUSHED -- 13 commits on main and the entire
# implementation branch (Tasks 1-7, 133 tests) existed on one disk. Caught only
# by the verify-pushed-before-relaying rule.
# ⛔ AND THE SAME SWEEP FOUND boss-clod ITSELF 15 COMMITS UNBACKED -- the whole
# 7x75 lesson thread and both watch scripts -- WHILE I WAS TELLING ANOTHER AGENT
# ABOUT DURABILITY. Nobody is exempt; that is why this is a script.
#
# ⭐ "Durable to a compaction" and "durable to a machine" are different
# properties. Writing state to files defends the first. Only a push defends the
# second, and the failure that actually loses work is losing the machine.
#
# rc 0 = swept and reported   2 = instrument blind (nothing examined)

set -uo pipefail
cd /home/jes || exit 2

REPOS=(commonplace commonplace-plan commonplace-log commonplace-log-reducer
       commonplace-merkle-crdt yepochs hermes wimble dirigible tarot awakening
       claude-chat boss-clod paravel mater2026 a113028 clockwork)

examined=0
declare -a FINDINGS=()

for d in "${REPOS[@]}"; do
  [ -d "/home/jes/$d/.git" ] || continue
  cd "/home/jes/$d" || continue
  examined=$((examined+1))
  br=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ -z "$(git remote 2>/dev/null | head -1)" ]; then
    FINDINGS+=("UNBACKED|$d|$br|ALL|no git remote at all — nothing is backed up anywhere")
    cd /home/jes; continue
  fi
  up=$(git rev-parse --abbrev-ref "$br@{upstream}" 2>/dev/null)
  if [ -z "$up" ]; then
    FINDINGS+=("UNBACKED|$d|$br|?|branch has no upstream — never pushed")
    cd /home/jes; continue
  fi
  n=$(git log --oneline "$up..$br" 2>/dev/null | wc -l)
  [ "$n" -gt 0 ] && FINDINGS+=("UNBACKED|$d|$br|$n|commits exist only on this disk")
  cd /home/jes
done

# ⭐ VACUITY, KEYED TO THE READ (LESSONS.md 7x75 addendum 9): the question is not
# "how many findings" -- zero findings is the healthy state and must stay legal.
# The question is whether the sweep LOOKED. examined==0 means it could not.
if [ "$examined" -eq 0 ]; then
  echo "BLIND|examined 0 repos — the sweep did not run, this is NOT 'everything is pushed'"
  exit 2
fi

if [ ${#FINDINGS[@]} -gt 0 ]; then printf '%s\n' "${FINDINGS[@]}"; fi
echo "SWEPT|examined=$examined|unbacked_repos=${#FINDINGS[@]}"
