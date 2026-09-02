#!/usr/bin/env bash
# ⭐ WHAT WOULD A SESSION WITH NONE OF MY CONTEXT READ? (biscuit + plan, 2026-09-01)
#
# ⛔ THE INSTRUMENT WAS NEVER AN AUDIT — it was that question, and it only ever got asked because
# somebody OFFERED TO CREATE such a session. plan: "A QUESTION THAT FIRES ONLY ON AN EXTERNAL OFFER
# IS NOT AN INSTRUMENT, IT IS A COINCIDENCE." This makes it fire on demand.
#
# ⚠️ EARNED THE HARD WAY AT THREE DOORS IN ONE HOUR: plan's RESUME POINT was FIVE DAYS stale in the
# file its own CLAUDE.md says supersedes everything · biscuit's Cloudflare note was fourteen hours
# stale and self-consistent · and BOSS scored ZERO OF TEN across 127 memory files WHILE RESTARTING
# FOUR OTHER SESSIONS. ⭐ biscuit on why that is structural and not a character flaw:
# "THE DOOR RUNNING THE OPERATION IS THE ONE WITH NO REASON TO ASK, because the operation is not
# happening to it." ⇒ Which is exactly why it wants to be a script and not a discipline.
#
# ⛔ IT NEVER READS MEMORY.md. The index is the trap: biscuit's matched perfectly — 3 indexed,
# 3 present — and it read that as recoverable. INDEX CONSISTENCY AND STATE RECOVERABILITY ARE TWO
# QUESTIONS WITH ONE GREEN LIGHT.
#
# ⚠️ BOUNDED, because it is weaker than it looks: IT CHECKS THAT A STRING IS PRESENT, NOT THAT THE
# FILED FACT IS STILL TRUE. It catches ABSENT; it cannot catch STALE. Staleness needs another
# instrument and this is not one.
#
# Exit: 0 every fact present · 1 at least one ABSENT · 2 BLIND (no corpus, or an unfailable query)
set -o pipefail
MEM="${MEMORY_DIR:-/home/jes/.claude/projects/-home-jes-boss-clod/memory}"
[ -d "$MEM" ] || { echo "BLIND|memory dir does not exist: $MEM"; exit 2; }
n=$(ls "$MEM"/*.md 2>/dev/null | wc -l)
[ "$n" -gt 0 ] || { echo "BLIND|no .md files in $MEM — the corpus cannot speak"; exit 2; }
# Facts a fresh boss-clod must recover. ⭐ DELIBERATELY SPECIFIC STRINGS: boss's own run returned
# 5 healthy-looking files for "observer" while every specific fact was absent —
# A NON-ZERO SOMEWHERE IS NOT COVERAGE ANYWHERE.
FACTS=(
  "busy_timeout"                      # the transport hazard and its fix
  "check .read_history. BEFORE|CHECK .read_history. BEFORE|before resending"
  # ⚠️ THIS ROW FAILED FALSE ON ITS FIRST RUN: I wrote "no worker can restart itself" while the
  # memory file says "No worker can restart its own Claude session". THE FACT WAS PRESENT AND MY
  # SELECTOR WAS WRONG — an ABSENT that was about the instrument, caught only because I read the
  # file instead of believing the red. Widened to the phrase both wordings share.
  "restart its own|restart itself"
  "ActiveEnterTimestamp"              # proving a NON-restart of the live-money BEAM
  "condition ⑥|merge-base --is-ancestor"
  "X-REALM"
  "R10b"
  "LogStore.Cloudflare"               # the beta storage answer
  "realm/create|first-caller-wins"    # serving precondition 2
  "cross-realm workspace edge|DevScoped"  # serving precondition 1 — no public multi-BEAM while it holds
  "monthl"                            # hermes' wheel fallback, live money
  "jes-send|price is the ticket|PRICE IS THE TICKET"
  "per-claim|PER-CLAIM"
)
echo "CORPUS: $n memory files in $MEM   (MEMORY.md deliberately NOT consulted)"
miss=0
for f in "${FACTS[@]}"; do
  # ⛔⛔ biscuit shipped this script's ancestor with the defect it exists to prevent: AN EMPTY QUERY
  # matched every file and returned rc=0. "A VACUOUS GREEN FROM A QUERY THAT CANNOT FAIL — a fact you
  # cannot fail is not a check." It guarded the POPULATION and left the PREDICATE unguarded.
  [ -n "$f" ] || { echo "BLIND|empty fact string — a query that cannot fail is not a check"; exit 2; }
  hits=$(command grep -rilE -- "$f" "$MEM" 2>/dev/null | command grep -v '/MEMORY.md$' | wc -l)
  if [ "$hits" -eq 0 ]; then printf '  ABSENT      %s\n' "$f"; miss=$((miss+1))
  else printf '  present %-3s %s\n' "$hits" "$f"; fi
done
echo
[ "$miss" -eq 0 ] && { echo "RECOVERABLE|${#FACTS[@]} facts, all present in a corpus of $n files"; exit 0; }
echo "ABSENT|$miss of ${#FACTS[@]} facts would not survive a restart of this session"; exit 1
