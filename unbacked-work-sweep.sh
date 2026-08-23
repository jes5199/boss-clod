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

# ⛔⛔ DO NOT GO BACK TO A HARDCODED LIST. 2026-08-23: this script shipped with a
# 17-name list and reported "unbacked_repos=0, examined=17" while **82 git repos
# existed at depth 1 under /home/jes**. Sixty-five were never looked at --
# including `postage-stamp`, which is KNOWN to have no remote and results that
# exist only on this disk.
# ⭐ AND MY OWN VACUITY GATE PASSED: examined=17 > 0. ⇒ `examined > 0` proves the
# instrument RAN. It says NOTHING ABOUT COVERAGE. A non-zero denominator drawn
# from the wrong population is a distinct failure from a zero one, and it is the
# more convincing of the two.
# ⇒ DISCOVER the corpus; never enumerate it by hand. And PRINT the coverage so a
# gap is visible rather than implied.
mapfile -t REPOS < <(ls -d /home/jes/*/.git 2>/dev/null | sed 's|^/home/jes/||; s|/\.git$||' | sort)
discovered=${#REPOS[@]}

examined=0
declare -a FINDINGS=()

for d in "${REPOS[@]}"; do
  [ -e "/home/jes/$d/.git" ] || continue
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
  # ⛔ 2026-08-23: the rule "push an existing branch to its existing upstream is a
  # pure addition" silently assumed upstream == a remote branch of the SAME NAME.
  # commonplace-s80's branch is sol/cx-721q-detector-land-s80 and its upstream is
  # origin/sol/cx-0ktk-round2-s75 -- a DIFFERENT branch. Pushing would either mint
  # an unrequested ref or advance someone else's branch with a foreign commit.
  # ⇒ Neither is the safe act the rule assumed, so the MISMATCH must be visible in
  # the finding, not discovered afterwards by whoever acts on it.
  up_short=${up#origin/}
  mism=""
  [ "$up_short" != "$br" ] && mism="|⚠️UPSTREAM-NAME-MISMATCH:$up (do NOT push blind)"
  [ "$n" -gt 0 ] && FINDINGS+=("UNBACKED|$d|$br|$n|commits exist only on this disk$mism")
  cd /home/jes
done

# ⭐ VACUITY, KEYED TO THE READ (LESSONS.md 7x75 addendum 9): the question is not
# "how many findings" -- zero findings is the healthy state and must stay legal.
# The question is whether the sweep LOOKED. examined==0 means it could not.
if [ "$examined" -eq 0 ]; then
  echo "BLIND|examined 0 repos — the sweep did not run, this is NOT 'everything is pushed'"
  exit 2
fi
# ⭐ Coverage gate: examined must equal what was discovered. A silent shortfall is
# the 17-of-82 failure returning.
if [ "$examined" -ne "$discovered" ]; then
  echo "BLIND|examined $examined of $discovered discovered repos — COVERAGE GAP, findings are not trustworthy"
  exit 2
fi

if [ ${#FINDINGS[@]} -gt 0 ]; then printf '%s\n' "${FINDINGS[@]}"; fi
echo "SWEPT|discovered=$discovered|examined=$examined|unbacked_repos=${#FINDINGS[@]}"
