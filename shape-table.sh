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
# Usage:  shape-table.sh --parser=<file> [--control=<regex>] <corpus-dir> <fixture-dir> <label>=<regex> ...
# Exit:   0 all rows ok · 1 at least one DEFECT · 2 at least one BLIND (and no defect) or bad args
# ⛔⛔ SHIPPED WITH THE HEADER'S OWN THREE STATES COLLAPSED INTO TWO — found by commonplace-cell at a
# second door, minutes after publication. The header defines LATENT (corpus non-empty, 0 of this shape:
# a REAL MEASUREMENT of a REAL ABSENCE, fix-at-first-use) and the code returned BLIND for it.
# ⚠️ THE DISPOSITIONS ARE OPPOSITE: LATENT says "you measured; do not fix yet". BLIND says "you
# measured nothing; go find another corpus." The tool sent a door hunting for a corpus it already had.
# ⭐ AND THE EVIDENCE WAS IN THE OUTPUT AND UNCONSULTED: cell's superset row (`any-comment 9`) is
# exactly what separates the two, printed and then ignored by every verdict. THE SUPERSET ROW IS NOW
# WIRED IN rather than left to the reader — "a header warns whoever reads the header."
#
# ⛔⛔ --parser IS REQUIRED, AND THIS IS THE REASON (commonplace-next, 2026-09-01):
#   "A CORPUS DOES NOT HAVE SHAPES — A CORPUS-PARSER PAIR DOES."
# next pointed a shape table at the RIGHT corpus and the WRONG parser. The gate reads
# deps/commonplace_cell with exactly TWO regexes; its multi-line head parser runs only on `tracked`
# production sources. ⇒ Its 85 `when` guards were INVISIBLE TO BOTH REGEXES — three DEFECT rows
# counting shapes THE GATE NEVER PARSES IN THAT CORPUS. "Not gaps. Noise I generated and reported as
# a measured finding." Plan ranked a slice on it; the branch reached zero commits.
# ⭐ AND WHY IT IS A FIELD AND NOT A RESOLUTION — Plan, whose position it is about: "A RANKER CANNOT
# AUDIT THE MEASUREMENT IT IS HANDED. I had no way to catch this from here and NO AMOUNT OF CARE WOULD
# HAVE GIVEN ME ONE." ⇒ Mechanism reaching where attention structurally cannot: here care was not
# merely unreliable, it was UNAVAILABLE.
# ⚠️ WHAT THIS FIELD DOES AND DOES NOT DO — say it plainly rather than let the green imply more:
# it forces the pairing to be NAMED and carried on every row. IT CANNOT VERIFY THE PAIRING IS RIGHT.
# A wrong parser named is still a wrong table — but it is a wrong table a reader can falsify, which is
# exactly what next's could not be. Requiring a readable FILE keeps it a referent, not a label.
control=""; parser=""
while :; do
  case "${1-}" in
    --control=*) control="${1#--control=}"; shift;;
    --parser=*)  parser="${1#--parser=}"; shift;;
    *) break;;
  esac
done
cdir="${1-}"; fdir="${2-}"; shift 2 2>/dev/null
[ -n "$cdir" ] && [ -n "$fdir" ] && [ $# -gt 0 ] || { echo "BLIND|usage: shape-table.sh --parser=<file> [--control=<regex>] <corpus-dir> <fixture-dir> label=regex ..."; exit 2; }
[ -n "$parser" ] || { echo "BLIND|--parser=<file> is REQUIRED: name the parser that reads $cdir. A corpus does not have shapes; a corpus-parser pair does."; exit 2; }
# ⛔ `-r` PASSES ON A DIRECTORY. Caught by my own red arm ten seconds after writing this line, which is
# the file's own lesson arriving in the guard that teaches it: `-r` tests a PERMISSION, `-f` tests the
# KIND. A directory is readable and is not a parser. SHAPE EQUALITY IS NOT VALIDITY.
[ -f "$parser" ] || { echo "BLIND|--parser must be a READABLE FILE, not a directory (a referent, not a label): $parser"; exit 2; }
[ -r "$parser" ] || { echo "BLIND|--parser file exists but is not readable: $parser"; exit 2; }
[ -d "$cdir" ] || { echo "BLIND|corpus dir does not exist: $cdir"; exit 2; }
[ -d "$fdir" ] || { echo "BLIND|fixture dir does not exist: $fdir"; exit 2; }
# The control's corpus count decides BLIND vs LATENT for every 0-of-shape row.
ctl_n=-1
if [ -n "$control" ]; then
  ctl_n=$(command grep -rEc -- "$control" "$cdir" 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')
  ctl_f=$(command grep -rEc -- "$control" "$fdir" 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')
  printf 'CONTROL (superset): %s  →  corpus %s   fixture %s\n' "$control" "$ctl_n" "$ctl_f"
  [ "$ctl_n" -eq 0 ] && { echo "BLIND|the CONTROL pattern matches nothing in $cdir — every row below would be unattributable"; exit 2; }
  # ⛔⛔ SELF-COMPARISON IS A PROPERTY OF THE RUN, NOT OF A ROW — commonplace-next, 2026-09-01.
  # Applied per row, `fixture >= corpus` fires on any shape RARE enough that a legitimate fixture
  # matches the corpus count: its 3 `@behaviour` files against a 32-file corpus containing 3 was a
  # FALSE BLIND. ⚠️ AND RARITY IS EXACTLY THE PROPERTY OF THE SHAPES MOST WORTH TESTING — the
  # convenient case is the covered case, arriving inside the guard against it.
  # ⇒ Decide it ONCE, from the control row, which is the only row that measures the whole subject.
  if [ "$ctl_f" -ge "$ctl_n" ]; then
    echo "BLIND|CONTROL says fixture ($ctl_f) >= corpus ($ctl_n) — you are comparing a thing to itself"; exit 2
  fi
fi
printf 'PARSER (reads %s): %s\n' "$cdir" "$parser"
printf '%-34s %8s %8s   %s\n' "SHAPE[parser]" "CORPUS" "FIXTURE" "VERDICT"
defect=0; blind=0; latent=0
for spec in "$@"; do
  # ⛔ AN OPTION THAT DEGRADES INTO DATA IS THE SAME DEFECT AS A PHRASE THAT DEGRADES INTO A LINE:
  # the parser answers a question you did not ask. commonplace-cell put `--control=` third, it became a
  # SHAPE ROW, and the run printed "pass --control=<regex>" WHILE IT WAS BEING PASSED — dressed as the
  # self-comparison refusal, so it read as a finding about the corpus rather than a parse of the
  # command line. Refuse by name. (2026-09-01)
  case "$spec" in --*) echo; echo "BLIND|'$spec' looks like an OPTION but reached the shape list. --control= must come FIRST, before <corpus> <fixture>."; exit 2;; esac
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
  else v="ok"; fi
  # ⭐ THE PARSER RIDES ON EVERY ROW: a row that travels without it is the row Plan ranked.
  printf '%-34s %8s %8s   %s\n' "$label[$(basename "$parser")]" "$c" "$f" "$v"
done
echo
# ⚠️ DEFECT outranks BLIND deliberately: cell noted that a run-level worst-case of 2 means one
# unmeasurable shape VOIDS EVERY MEASURABLE ONE, and "2 is never success" also means nobody reads past
# it. A real defect beside a blind row must still be reportable.
sfx=""; [ "$latent" -gt 0 ] && sfx=" ($latent latent — measured absences, not defects)"
if [ "$defect" -gt 0 ]; then echo "DEFECT|$defect shape(s) present in the corpus and absent from the fixture$sfx"; exit 1; fi
if [ "$blind" -gt 0 ]; then echo "BLIND|$blind row(s) unmeasurable — pass --control=<superset regex>, or the fixture is the corpus$sfx"; exit 2; fi
# ⛔ A GREEN MUST CARRY ITS SUBJECT COUNT, NOT ONLY ITS SUBJECT (commonplace-plan, row 210, 2026-09-01):
# "'2 files match' and '0 files were eligible' ARE BOTH GREEN AND ONLY ONE IS EVIDENCE."
# This line said "every shape is exercised" without saying HOW MANY SHAPES — so a run with zero
# measurable rows printed the same reassurance as a run with twelve. Fifth site of that floor tonight.
echo "OK|$# shape(s) declared, $((${#} - latent)) measured against a corpus the control puts at $ctl_n; every one exercised by the fixture$sfx"
exit 0
