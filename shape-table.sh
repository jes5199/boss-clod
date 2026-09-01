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
# ⛔⛔ SHIPPED WITH THE HEADER'S OWN THREE STATES COLLAPSED INTO TWO — found by commonplace-cell at a
# second door, minutes after publication. The header defines LATENT (corpus non-empty, 0 of this shape:
# a REAL MEASUREMENT of a REAL ABSENCE, fix-at-first-use) and the code returned BLIND for it.
# ⚠️ THE DISPOSITIONS ARE OPPOSITE: LATENT says "you measured; do not fix yet". BLIND says "you
# measured nothing; go find another corpus." The tool sent a door hunting for a corpus it already had.
# ⭐ AND THE EVIDENCE WAS IN THE OUTPUT AND UNCONSULTED: cell's superset row (`any-comment 9`) is
# exactly what separates the two, printed and then ignored by every verdict. THE SUPERSET ROW IS NOW
# WIRED IN rather than left to the reader — "a header warns whoever reads the header."
control=""
case "${1-}" in --control=*) control="${1#--control=}"; shift;; esac
cdir="${1-}"; fdir="${2-}"; shift 2 2>/dev/null
[ -n "$cdir" ] && [ -n "$fdir" ] && [ $# -gt 0 ] || { echo "BLIND|usage: shape-table.sh <corpus-dir> <fixture-dir> label=regex ..."; exit 2; }
[ -d "$cdir" ] || { echo "BLIND|corpus dir does not exist: $cdir"; exit 2; }
[ -d "$fdir" ] || { echo "BLIND|fixture dir does not exist: $fdir"; exit 2; }
# The control's corpus count decides BLIND vs LATENT for every 0-of-shape row.
ctl_n=-1
if [ -n "$control" ]; then
  ctl_n=$(command grep -rEc -- "$control" "$cdir" 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')
  printf 'CONTROL (superset): %s  →  %s in corpus\n' "$control" "$ctl_n"
  [ "$ctl_n" -eq 0 ] && { echo "BLIND|the CONTROL pattern matches nothing in $cdir — every row below would be unattributable"; exit 2; }
fi
printf '%-34s %8s %8s   %s\n' "SHAPE" "CORPUS" "FIXTURE" "VERDICT"
defect=0; blind=0; latent=0
for spec in "$@"; do
  label="${spec%%=*}"; rx="${spec#*=}"
  c=$(command grep -rEc -- "$rx" "$cdir" 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')
  f=$(command grep -rEc -- "$rx" "$fdir" 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')
  # ⛔ CORPUS COLUMN FIRST — this ordering is the floor.
  if [ "$c" -eq 0 ] && [ "$ctl_n" -gt 0 ]; then
    v="LATENT  ← real absence: corpus speaks (control=$ctl_n) and this shape is not in it. fix-at-first-use"; latent=$((latent+1))
  elif [ "$c" -eq 0 ]; then
    v="BLIND   ← shape absent AND no control: this row is NOT a measurement"; blind=$((blind+1))
  elif [ "$f" -eq 0 ]; then
    v="DEFECT  ← fixture never exercises a shape the corpus contains"; defect=$((defect+1))
  # ⛔ cell: "a fixture column within an order of magnitude of the corpus should itself be a REFUSAL,
  # not a note in the header." My own first use passed a whole repo as the fixture and got `ok`.
  elif [ "$f" -ge "$c" ]; then
    v="BLIND   ← fixture >= corpus: you are comparing a thing to itself"; blind=$((blind+1))
  else v="ok"; fi
  printf '%-34s %8s %8s   %s\n' "$label" "$c" "$f" "$v"
done
echo
# ⚠️ DEFECT outranks BLIND deliberately: cell noted that a run-level worst-case of 2 means one
# unmeasurable shape VOIDS EVERY MEASURABLE ONE, and "2 is never success" also means nobody reads past
# it. A real defect beside a blind row must still be reportable.
sfx=""; [ "$latent" -gt 0 ] && sfx=" ($latent latent — measured absences, not defects)"
if [ "$defect" -gt 0 ]; then echo "DEFECT|$defect shape(s) present in the corpus and absent from the fixture$sfx"; exit 1; fi
if [ "$blind" -gt 0 ]; then echo "BLIND|$blind row(s) unmeasurable — pass --control=<superset regex>, or the fixture is the corpus$sfx"; exit 2; fi
echo "OK|every shape in the corpus is exercised by the fixture$sfx"
exit 0
