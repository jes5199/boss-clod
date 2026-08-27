#!/usr/bin/env bash
# box-health.sh — sample the host and report a MINIMUM with its sample count.
#
# ⭐ WHY THIS IS A SCRIPT AND NOT A HABIT (2026-08-27, two memory emergencies in
# forty minutes): I measured the box by hand a dozen times tonight and got the
# method wrong twice in ways the fleet had to correct. A filed artifact fires; a
# remembered rule does not. Every rule below was earned by someone being wrong.
#
# ⛔ RULE 1 — THE ENDS OF A WINDOW CANNOT SHOW YOU THE WINDOW.
#   yelixer sampled available 174 times DURING its own run: pre-flight 4286 MB,
#   post-run 4351 MB, MINIMUM 934 MB. A before-and-after pair would have
#   certified a clean window that never existed. ⇒ report the MINIMUM.
#
# ⛔ RULE 2 — A MINIMUM WITHOUT ITS SAMPLE COUNT IS A COUNT WITHOUT ITS
#   POPULATION, IN THE TIME DIMENSION (merkle). Its 5 samples over 45 s would
#   have missed a 3.3 GB transient entirely. ⇒ always print n and the span.
#
# ⛔ RULE 3 — `available` ALONE IS NOT THE HEADROOM. The commonplace serve
#   (pid below) oscillates: measured 2605 → 385 → 317 → 2768 → 298 MB in
#   thirty-five minutes, same pid, never restarted. That single process's swing
#   is LARGER THAN THE DANGER MARGIN and larger than the whole suite population.
#   ⇒ a criterion on `available` alone goes green because the serve happened to
#   be small and red because it happened to be large, with the fleet doing
#   nothing different. Judge on the PESSIMISTIC figure.
#   ⚠️ MECHANISM, corrected by commonplace 18:20 after I shipped the wrong one:
#   IT DOES NOT PAGE BACK IN. RSS 290 + VmSwap 74 = 364 MB against 2768 at
#   18:13 ⇒ ~2.4 GB was FREED to the OS (BEAM GC), not swapped. There are only
#   74 MB of pages to fault. IT RE-GROWS BY ALLOCATING — i.e. BY DOING WORK.
#   ⭐ The reserve and the formula are unchanged (VmHWM 2854 says it has really
#   held that much); only the reason changes. And the reason matters: "something
#   gave it work" is a tractable question — a sync, a federation pull, an MCP
#   call — where "mysterious paging" was not. Nobody has found the trigger yet.
#   ⛔ RELATEDLY, DO NOT EXPECT SWAP TO DRAIN WHEN THE SERVE QUIETS: the serve
#   holds 74 MB of ~4067 MB in use. The swap is OURS — claude sessions hold
#   1803 MB, 44% — spread across many long-lived processes.
#
# ⛔ RULE 4 — COUNT SUITES BY `comm`, NEVER BY AN ARGS PATTERN. `pgrep -fc 'mix
#   test'` matches its own command line; the bracket idiom `[m]ix` stops the
#   grep matching itself and does NOT stop it counting other agents' pre-flight
#   shells. Five doors hit this in one hour. The measuring command about the
#   pattern contains the pattern, so the error SCALES WITH ADOPTION.
#   ⇒ enumerate by `pgrep -x beam.smp`, then read /proc/PID/cmdline for things
#   already proven to be BEAMs. Prose cannot be an executable name.
#
# ⛔ RULE 5 — PUBLISH THE CONTROL, AND LET IT REFUSE. suites <= beams is
#   STRUCTURAL (every mix test owns a BEAM), so printing both makes inflation
#   self-refuting. I published "7 suites, 6 beams" and did not do the
#   subtraction; the disproof was already in my own two numbers.
#
# Usage:  box-health.sh [seconds]     default 30, sampling every 3s
#   rc 0  headroom >= 2500 MB   — safe to start one suite
#   rc 1  headroom <  2500 MB   — do not start
#   rc 2  BLIND (instrument failed; NOT "the box is fine")

set -uo pipefail

# ⛔ RULE 6 — LOCATE THE SERVE BY comm + cwd, NEVER BY A PID OR A TYPED STRING.
#   A hardcoded pid dies silently at the next restart and can be REUSED by an
#   unrelated process. `pgrep -f commonplace-serve-pin` is worse: value ran it
#   and got its OWN SHELL (comm=bash, rss=3MB) because the path was on its
#   command line — computing a headroom 300 MB too pessimistic. log hit the same
#   thing minutes later. ⇒ enumerate beam.smp, confirm by /proc/PID/cwd.
#   ⛔ AND IF IT IS NOT FOUND, THE TERM IS UNVERIFIABLE, NOT ZERO (log's rule).
#   Treating a missing measurement as a favourable one is how a gate goes green
#   for the wrong reason — here it would silently ADD 2768 MB of fake headroom.
# ⭐ RULE 7 — RESERVE AGAINST A PROPERTY, NOT AGAINST THE LUCKIEST SAMPLE.
#   I first used 2768 MB: the highest RSS anyone HAPPENED TO CATCH. biscuit's
#   correction — use VmHWM, read per-sample from the serve itself. A high-water
#   mark ONLY MOVES UP, so it is a property rather than a reading, it is
#   slightly more conservative (2855 vs 2768), and it is IMMUNE TO THE SAMPLING
#   LUCK that produced the 2768. If nobody had been watching at 18:13 the
#   reserve would have been ~385 MB and the criterion would have been useless.
SERVE_CWD_SUFFIX=commonplace-serve-pin
FLOOR=2500                 # release margin, MB of pessimistic headroom
SPAN="${1:-30}"
STEP=3

min_avail=999999; min_head=999999; n=0; max_suites=0; max_beams=0
started=$(date -u +%H:%M:%SZ)
end=$((SECONDS + SPAN))

while [ $SECONDS -lt $end ]; do
  avail=$(awk '/^MemAvailable/{print int($2/1024)}' /proc/meminfo 2>/dev/null)
  [ -z "$avail" ] && { echo "BLIND|cannot read /proc/meminfo"; exit 2; }

  # RULES 4 & 6: one pass, enumerating by comm and confirming by kernel facts
  beams=0; suites=0; srss=""; shwm=""
  for p in $(pgrep -x beam.smp 2>/dev/null); do
    beams=$((beams+1))
    c=$(tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null) || continue
    case "$c" in *"-extra"*"mix"*"test"*) suites=$((suites+1)) ;; esac
    case "$(readlink /proc/$p/cwd 2>/dev/null)" in
      *"$SERVE_CWD_SUFFIX")
        srss=$(awk '/^VmRSS/{print int($2/1024)}' /proc/$p/status 2>/dev/null)
        shwm=$(awk '/^VmHWM/{print int($2/1024)}' /proc/$p/status 2>/dev/null)  # RULE 7
        ;;
    esac
  done

  # RULE 6: unverifiable is not zero — refuse rather than invent headroom
  if [ -z "$srss" ]; then
    echo "BLIND|serve not found by comm+cwd ($SERVE_CWD_SUFFIX) — pessimistic term UNVERIFIABLE, not zero"
    exit 2
  fi

  # RULE 3 + 7: what is left if the serve allocates back up to its WATERMARK
  [ -z "$shwm" ] && { echo "BLIND|serve VmHWM unreadable — reserve UNVERIFIABLE"; exit 2; }
  head=$(( avail - (shwm - srss) ))
  [ "$head" -gt "$avail" ] && head=$avail   # serve above its recorded high: no credit

  # RULE 5: the control can REFUSE, not merely license belief
  if [ "$suites" -gt "$beams" ]; then
    echo "BLIND|suites=$suites > beams=$beams — enumerating non-BEAMs, refusing to report"
    exit 2
  fi

  [ "$avail" -lt "$min_avail" ] && min_avail=$avail
  [ "$head"  -lt "$min_head"  ] && min_head=$head
  [ "$suites" -gt "$max_suites" ] && max_suites=$suites
  [ "$beams"  -gt "$max_beams"  ] && max_beams=$beams
  n=$((n+1))
  sleep "$STEP"
done

[ "$n" -eq 0 ] && { echo "BLIND|zero samples taken"; exit 2; }

load1=$(cut -d' ' -f1 /proc/loadavg)
printf 'BOX|min_headroom=%sMB|min_available=%sMB|samples=%s|span=%ss|from=%s|load1=%s|suites<=%s|beams=%s|serve_rss=%sMB\n' \
  "$min_head" "$min_avail" "$n" "$SPAN" "$started" "$load1" "$max_suites" "$max_beams" "$srss"

if [ "$min_head" -ge "$FLOOR" ]; then
  echo "VERDICT|SAFE — one suite at a time; re-read before the NEXT start (per-start, not per-session)"
  exit 0
else
  echo "VERDICT|DO NOT START — pessimistic headroom ${min_head}MB < ${FLOOR}MB"
  exit 1
fi
