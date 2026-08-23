#!/usr/bin/env bash

# ⛔ HALT AWARENESS: never ask a halted agent to push. See .watch-halted.
HALTED_FILE=/home/jes/boss-clod/.watch-halted
is_halted() { [ -r "$HALTED_FILE" ] && grep -qE "^$1[[:space:]]" "$HALTED_FILE"; }
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
# ⛔ DEDUPE BY RESOLVED PATH. /home/jes/commonplace became a SYMLINK to
# commonplace-monolith on 2026-08-23, so the glob returned one repo under two names —
# same .git inode. The coverage gate still passed (85==85) because BOTH sides were
# inflated, which is exactly why it looked healthy.
# ⚠️ The real damage would have been a duplicate finding, and an ack keyed on repo|branch|count
# that no longer matches the second name — a KNOWN item reporting as NEW forever.
mapfile -t REPOS < <(for g in /home/jes/*/.git; do
    [ -e "$g" ] || continue
    r=$(readlink -f "$g" 2>/dev/null) || continue
    printf '%s\t%s\n' "$r" "${g#/home/jes/}"
  done | sort -k1,1 -k2,2r | sort -u -k1,1 | cut -f2 | sed 's|/\.git$||' | sort)
# ⭐ -k2,2r before the unique pass so the LONGER name wins a tie: commonplace-monolith over
# the commonplace symlink. Arbitrary either way for correctness — but a finding should name
# the real directory, because that is what someone will cd into.
discovered=${#REPOS[@]}

# ⭐⭐ THIRD STATE, found by commonplace 2026-08-23: LANDED-BY-CONTENT.
# `--contains <tip>` asks "is this REF reachable" and CANNOT see content that
# landed as a DIFFERENT commit (rebase / cherry-pick). Such a branch looks
# exactly like genuinely-unbacked work.
# ⇒ `git cherry <upstream> <branch>` is git's own answer: '-' = an equivalent
# patch exists upstream (by patch-id), '+' = genuinely absent. Verified against
# commonplace's independent patch-id measurement: hardening 2 landed / 0 unique,
# b2-mr 0 landed / 7 unique.
# ⛔ A subject line is shape-equality and a rebase that drops a hunk keeps it
# perfectly. The patch-id is the thing resemblance cannot fake.
# ⚠️⚠️ KNOWN LIMIT, named by commonplace 2026-08-23 and true BY DESIGN, not a bug:
# `git cherry` SKIPS MERGE COMMITS. A merge's conflict resolution is AUTHORED
# BYTES with no single parent to diff against, so patch-id comparison cannot see
# it EVEN IN PRINCIPLE. ⇒ LANDED-BY-CONTENT is detected for ordinary commits and
# UNDETECTED for merges: a branch whose only unique content lives in a merge
# resolution can read `unique=0` and still be the only copy.
# ⇒ The `merges=` field below exists so that gap is VISIBLE in the finding rather
# than discovered later. Nonzero merges means: hand-check before deleting.
content_verdict() {   # $1 = branch/ref ; echoes "unique=<n> landed=<n> merges=<n>" or "" if unusable
  local b="$1" base out
  for base in origin/main origin/master; do
    git rev-parse --verify -q "$base" >/dev/null 2>&1 || continue
    out=$(git cherry "$base" "$b" 2>/dev/null) || return 1
    local merges
    merges=$(git rev-list --count --merges "$base..$b" 2>/dev/null || echo 0)
    printf 'unique=%s landed=%s merges=%s' \
      "$(printf '%s\n' "$out" | grep -c '^+')" "$(printf '%s\n' "$out" | grep -c '^-')" "$merges"
    return 0
  done
  return 1
}

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
    # ⭐ SAME CORRECTION AS THE AHEAD-OF-UPSTREAM CASE: "no upstream" is not
    # "not backed up" either. A worktree branch cut for a landed round has no
    # upstream and is still fully reachable from origin/main. Ask the durability
    # question here too, or ~20 landed branches read as work at risk.
    tip=$(git rev-parse "$br" 2>/dev/null || git rev-parse HEAD 2>/dev/null)
    reach=""
    [ -n "$tip" ] && reach=$(git branch -r --contains "$tip" 2>/dev/null | head -3 | tr -d ' ' | paste -sd, -)
    if [ -n "$reach" ]; then
      FINDINGS+=("REACHABLE|$d|$br|0|no upstream, but REACHABLE from: $reach — nothing to push")
    else
      cv=$(content_verdict "$br" || true)
      case "$cv" in
        "unique=0 "*) case "$cv" in
                        *"merges=0") FINDINGS+=("LANDED|$d|$br|0|no upstream, ALL commits landed by CONTENT ($cv) — nothing at risk") ;;
                        *)           FINDINGS+=("LANDED?|$d|$br|0|landed by content BUT ($cv) — ⚠️ cherry SKIPS MERGES; hand-check the merge resolutions before deleting") ;;
                      esac ;;
        unique=*)     FINDINGS+=("UNBACKED|$d|$br|${cv%% *}|unreachable AND unique by content ($cv) — GENUINELY AT RISK") ;;
        *)            FINDINGS+=("UNBACKED|$d|$br|?|unreachable from any remote ref; content check unavailable — treat as at risk") ;;
      esac
    fi
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

  # ⛔⛔ 2026-08-23: "ahead of its upstream" IS NOT "not backed up". commonplace-s80
  # reported 1 unpushed against a MISNAMED upstream while the commit was fully
  # reachable from origin/main via its own landing merge -- nothing was at risk and
  # there was nothing to push. ⇒ THE INSTRUMENT WAS ANSWERING A NARROWER QUESTION
  # THAN THE ONE ASKED, and every finding of this kind is a candidate false positive.
  # ⭐ The durability question is "reachable from ANY remote ref?", so ask THAT.
  if [ "$n" -gt 0 ]; then
    tip=$(git rev-parse "$br" 2>/dev/null)
    reachable=""
    if [ -n "$tip" ]; then
      # --contains over remote refs: empty means no remote ref reaches this commit
      reachable=$(git branch -r --contains "$tip" 2>/dev/null | head -3 | tr -d ' ' | paste -sd, -)
    fi
    if [ -n "$reachable" ]; then
      FINDINGS+=("REACHABLE|$d|$br|$n|ahead of upstream but REACHABLE from: $reachable — nothing to push$mism")
    else
      cv=$(content_verdict "$br" || true)
      case "$cv" in
        "unique=0 "*) case "$cv" in
                        *"merges=0") FINDINGS+=("LANDED|$d|$br|$n|ahead of upstream, ALL commits landed by CONTENT ($cv) — nothing at risk$mism") ;;
                        *)           FINDINGS+=("LANDED?|$d|$br|$n|landed by content BUT ($cv) — ⚠️ cherry SKIPS MERGES; hand-check before deleting$mism") ;;
                      esac ;;
        unique=*)     FINDINGS+=("UNBACKED|$d|$br|$n|unique by content ($cv) — GENUINELY AT RISK$mism") ;;
        *)            FINDINGS+=("UNBACKED|$d|$br|$n|commits exist only on this disk; content check unavailable$mism") ;;
      esac
    fi
  fi
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

# ⭐ Split KNOWN-AND-TRIAGED from NEW so a new finding cannot hide in a familiar list.
# The ack is keyed on repo|branch|count — a GROWING count is new again, because growth
# means work is accumulating off-remote, which is exactly what this sweep is for.
ACK_FILE=/home/jes/boss-clod/.sweep-acknowledged
new_n=0; known_n=0
declare -a NEWF=() KNOWNF=()
for f in ${FINDINGS+"${FINDINGS[@]}"}; do
  case "$f" in
    UNBACKED\|*) : ;;
    *) continue ;;
  esac
  IFS='|' read -r _k repo br cnt _rest <<< "$f"
  if [ -r "$ACK_FILE" ] && grep -qF "$repo|$br|$cnt|" "$ACK_FILE"; then
    KNOWNF+=("$f"); known_n=$((known_n+1))
  else
    NEWF+=("$f"); new_n=$((new_n+1))
  fi
done
if [ "$new_n" -gt 0 ]; then
  echo "⛔ NEW FINDINGS — not previously triaged, or the count has GROWN:"
  printf '  %s\n' "${NEWF[@]}"
fi
[ "$known_n" -gt 0 ] && echo "ⓘ known-and-triaged: $known_n (see .sweep-acknowledged for owner and date)"
if [ ${#FINDINGS[@]} -gt 0 ]; then printf '%s\n' "${FINDINGS[@]}"; fi
real=0; for f in ${FINDINGS+"${FINDINGS[@]}"}; do case "$f" in UNBACKED\|*) real=$((real+1));; esac; done
echo "SWEPT|discovered=$discovered|examined=$examined|findings=${#FINDINGS[@]}|genuinely_unbacked=$real|NEW=$new_n|known=$known_n"
