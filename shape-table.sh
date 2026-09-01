#!/usr/bin/env bash
# ⛔ pipefail: without it a pipeline reports the LAST stage. For a 0/1/2 script CAPTURE FIRST.
set -o pipefail
# ⭐ PROBE ④, MECHANICAL: count the awkward shapes in the REAL CORPUS, count them in your FIXTURE.
#
# Probes ①②③ ask questions about the ARM. ④ asks a question about the CORPUS, and corpora can be
# counted — which is why it needs no adversarial imagination and no reviewer.
#
# ⛔⛔ THE FLOOR IS THE WHOLE POINT, AND THE TWO-COLUMN FORM WITHOUT IT IS WORSE THAN NOTHING:
#     `bad = corpus > 0 and fixture == 0`  PRINTS `ok` FOR A 0/0 ROW.
# Three states share one output and only two are safe (commonplace-next, 2026-09-01):
#   corpus EMPTY, fixture 0        → BLIND   the comparison cannot speak. NOT a measurement.
#   corpus NON-EMPTY, 0 of shape   → LATENT  a real measurement of a real absence. fix-at-first-use.
#   corpus N of shape, fixture 0   → DEFECT  fix now.
# ⚠️ ORDERING MATTERS: test the CORPUS column first. Testing the fixture column first collapses
# BLIND into DEFECT and hides the distinction in the other direction.
#
# ⭐ AND MAKE THE COUNTING PATTERN DELIBERATELY WIDER THAN THE PARSER IT AUDITS (commonplace-cell):
# "a narrower instrument than the thing it measures is how you get a comfortable zero." An extractor
# that only sees double-quoted literals scores 2.6% precision on a corpus it already filtered —
# A PRECISION FIGURE COMPUTED ON A CORPUS YOUR EXTRACTOR HAS ALREADY FILTERED IS A STATEMENT ABOUT
# THE FILTER, NOT ABOUT THE CORPUS (hermes, retracting its own number).
#
# ⭐ AND PRINT THE SUPERSET ROW (commonplace-cell): a narrow zero beside a broad NON-zero is a
# measurement; a narrow zero alone is an unanswered question. Pass the broad pattern as SHAPE 0.
#
# ⚠️⚠️ AND A HAZARD I HIT ON MY FIRST REAL USE, ten seconds after writing the floor: I POINTED THE
# FIXTURE ARGUMENT AT A WHOLE REPO and got `hard-wrapped-line  9540  614214  ok`. A fixture column in
# the hundreds of thousands is not a fixture — it is the corpus again, compared against itself, and it
# returns `ok` FOR EVERY SHAPE BY CONSTRUCTION. ⇒ SANITY-CHECK THE FIXTURE COLUMN: if it is the same
# order of magnitude as the corpus column, you are comparing a thing to itself. The tool worked; the
# invocation did not — and the output was the most reassuring one available.
#
# Usage:  shape-table.sh <corpus-glob-dir> <fixture-dir> <label>=<regex> [<label>=<regex> ...]
# Exit:   0 all rows ok · 1 at least one DEFECT · 2 at least one BLIND (and no defect) or bad args
cdir="${1-}"; fdir="${2-}"; shift 2 2>/dev/null
[ -n "$cdir" ] && [ -n "$fdir" ] && [ $# -gt 0 ] || { echo "BLIND|usage: shape-table.sh <corpus-dir> <fixture-dir> label=regex ..."; exit 2; }
[ -d "$cdir" ] || { echo "BLIND|corpus dir does not exist: $cdir"; exit 2; }
[ -d "$fdir" ] || { echo "BLIND|fixture dir does not exist: $fdir"; exit 2; }
printf '%-34s %8s %8s   %s\n' "SHAPE" "CORPUS" "FIXTURE" "VERDICT"
defect=0; blind=0
for spec in "$@"; do
  label="${spec%%=*}"; rx="${spec#*=}"
  c=$(command grep -rEc -- "$rx" "$cdir" 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')
  f=$(command grep -rEc -- "$rx" "$fdir" 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')
  # ⛔ CORPUS COLUMN FIRST — this ordering is the floor.
  if [ "$c" -eq 0 ]; then v="BLIND   ← shape absent from corpus: this row is NOT a measurement"; blind=$((blind+1))
  elif [ "$f" -eq 0 ]; then v="DEFECT  ← fixture never exercises a shape the corpus contains"; defect=$((defect+1))
  else v="ok"; fi
  printf '%-34s %8s %8s   %s\n' "$label" "$c" "$f" "$v"
done
echo
if [ "$defect" -gt 0 ]; then echo "DEFECT|$defect shape(s) present in the corpus and absent from the fixture"; exit 1; fi
if [ "$blind" -gt 0 ]; then echo "BLIND|$blind shape(s) absent from the corpus — substitute the corpus you FEED INTO"; exit 2; fi
echo "OK|every shape in the corpus is exercised by the fixture"
exit 0
