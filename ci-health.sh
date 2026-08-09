#!/usr/bin/env bash
# ci-health — is CI a usable signal right now, and if not, what is failing?
#
# ⚠️ WHY THIS EXISTS: on 2026-08-09 I answered "how is CI?" twice with ad-hoc
# one-liners and got it wrong BOTH times in ways that changed decisions:
#   1. A 5-run window read "red since 12:08" out of a field that had been red
#      for twelve hours. A WINDOW ARTIFACT — the sample was the finding.
#   2. I relayed "22 of 30 runs failed" with no test-level shape, which reads
#      as a burning codebase when the content was 1-2 flaky tests per run.
# ⭐ Both errors are the same one: a number computed at the wrong resolution,
# by hand, under time pressure, with no record of the window it came from.
#
# ⛔ AND THE RATE ALONE CANNOT DECIDE ANYTHING. A real regression fails the
# SAME test every run; contamination fails DIFFERENT tests each run. That is
# a property of the SHAPE, and no pass-rate can express it. This prints both,
# always, so neither can be quoted without the other.
#
# ⛔ REFUSES (rc=2) rather than printing zeros when gh is unavailable or the
# repo has no runs — a count against no subject is undefined, not zero.
#
# Usage:  ci-health.sh [repo_dir] [n_runs]      default: ~/commonplace, 40

set -uo pipefail

REPO="${1:-/home/jes/commonplace}"
N="${2:-40}"

cd "$REPO" 2>/dev/null || { echo "REFUSED: no such repo dir: $REPO" >&2; exit 2; }

command -v gh >/dev/null || { echo "REFUSED: gh not on PATH" >&2; exit 2; }

RUNS=$(gh run list --limit "$N" --json conclusion,createdAt,displayTitle,databaseId 2>/dev/null)
rc=$?
# The rc that matters never comes through a pipe: capture, then test.
if [ "$rc" -ne 0 ] || [ -z "$RUNS" ] || [ "$RUNS" = "[]" ]; then
  echo "REFUSED: could not read runs from gh (rc=$rc). Not reporting 0." >&2
  exit 2
fi

echo "$RUNS" | python3 -c '
import json, sys, collections
rs = json.load(sys.stdin)
done = [r for r in rs if r["conclusion"] in ("success", "failure")]
if not done:
    print("REFUSED: no completed runs in window", file=sys.stderr); sys.exit(2)

ok  = sum(1 for r in done if r["conclusion"] == "success")
bad = len(done) - ok
pct = 100.0 * ok / len(done)

first, last = rs[-1]["createdAt"][:16], rs[0]["createdAt"][:16]
print(f"WINDOW: {len(done)} completed runs  ({first} .. {last})")
print(f"BY RUN:  {ok} green / {bad} red   =>  {pct:.0f}% pass")
print()
if pct < 60:
    print("  ** AT THIS PASS RATE A GREEN IS NOT EVIDENCE OF CORRECTNESS. **")
    print("  ** It is evidence of a lucky draw. Do not gate on one green.  **")
    print(f"  ** Two independent greens ~= {(pct/100)**2*100:.0f}% by luck.       **")
    print()
print("A rate says HOW OFTEN; only the shape says WHETHER it is one flaky")
print("pool or real breakage. Never quote one without the other.")
' || exit 2

cat <<'EOF'

⚠️  THE SHAPE IS THE OTHER HALF AND IT IS NOT AUTOMATED HERE YET.
    To attribute by test name across the red runs:
      gh run view <id> --log-failed | grep -E '^\s+\d+\) test '
    Then COUNT BY MODULE. Same test every run  => real regression.
    Different tests each run                   => contamination.
    ⭐ And check whether any failing test is itself a POSITIVE CONTROL:
       while a control is red, every other result in that suite is
       uninterpretable in BOTH directions.
EOF
