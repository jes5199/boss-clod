#!/usr/bin/env bash
# ⛔ pipefail: without it a pipeline reports the LAST stage, so a failing script read through
# a filter looks green. NOTE it does NOT save 1-vs-2 when a second stage also fails -- for a
# 0/1/2 script CAPTURE FIRST: out=$(script); rc=$?   (boss-clod, 2026-09-01)
set -o pipefail
# Shadows ~/.local/bin/bd INSIDE SOL'S SANDBOX ONLY (bind-mounted by
# sol-egress-run.sh). The host binary is untouched; nothing outside the
# bwrap namespace sees this file.
#
# WHY: bd is a FROZEN ARCHIVE for commonplace as of the 2026-08-05 cutover.
# It answers "no issue found" for every ticket filed since -- accurately,
# confidently, and about the wrong world. tix (854 issues) is a strict
# superset of bd (798). On 2026-08-08 that cost boss an afternoon: a 6-row
# all-negative table that was 100% wrong, caught only by a positive control.
#
# Sol works exclusively on commonplace worktrees, so bd is ALWAYS the frozen
# store here -- which is why this shadow is safe in the sandbox and would be
# catastrophic on the host, where hermes/wimble/gastown/turingtest/starloom26/
# paravel all have LIVE, un-migrated beads stores. Repo-scoped claim, repo-
# scoped guard. See commonplace .claude/hooks/block-bd-reflex.sh, which covers
# Claude Code agents; this covers Sol, who is not a Claude Code agent.
#
# FAILS OPEN BY DESIGN: this guards a CLAIM ABOUT ONE REPO, so a wrong refusal
# is worse than a missed catch. That is the OPPOSITE of the store-opener rule
# (Commonplace CLI), where refusing is the feature because it guards an
# INVARIANT ABOUT A FILE and a missed catch is corruption. Same word, opposite
# defaults -- do not "make this consistent" with that one.

REAL_BD=/home/jes/.local/bin/bd.real

# Deliberate archive read -- the legitimate use stays available, on purpose
# rather than by accident.
if [ -n "${CP_BD_ARCHIVE:-}" ]; then
  exec "$REAL_BD" "$@"
fi

cat >&2 <<EOF
REFUSED: bd is the FROZEN ARCHIVE (commonplace cutover 2026-08-05).

  You ran: bd $*

bd cannot see ANY ticket filed since 2026-08-05. It does not error on those --
it prints "no issue found", which is well-formed, confident, and about a world
frozen in August. A negative from this tool is NOT evidence a ticket is absent.

  bd  = Dolt archive, 798 issues, frozen
  tix = live CubDB store, 854 issues, a strict SUPERSET

To read a ticket, use one of these instead:
  * MCP tool  bd_show / bd_ready        (routes ViewActionDispatch / Bd.CLI)
  * erpc      Bd.Issue.show(root, id, CommitStoreClient)

To WRITE a ticket: not from a CLI. The bd CLI passes no signing_context at its
create/update/close call sites (CX-3nf4), so under enforce it PRINTS AN ID FOR
A TICKET IT DID NOT STORE. Three tickets were lost that way on 2026-08-07.

If you genuinely want the frozen archive, re-run with:
  CP_BD_ARCHIVE=1 bd $*
EOF
exit 1
