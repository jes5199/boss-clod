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
#   rc 0  SAFE  — min_available − SUITE_COST >= FLOOR; start ONE suite
#   rc 1  DO NOT START
#   rc 2  BLIND — instrument failed, or the criterion is unreachable.
#         NOT "the box is fine". See RULES 5, 6 and 9.

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
# ⛔⛔ RULE 9 — A THRESHOLD MUST BE CHECKED AGAINST WHAT THE BOX CAN REACH.
#   THIRD TIME TODAY I SHIPPED AN UNREACHABLE GREEN ARM, and this one was inside
#   the artifact written to prevent exactly that. doc-sync did the arithmetic:
#     MemTotal 15993 · best `available` seen all evening ~4429
#     reserve (VmHWM 2854 − rss 382) = 2472
#     ⇒ best achievable headroom ~1957  <  my FLOOR of 2500
#   ⇒ VERDICT: DO NOT START on an IDLE box with ZERO suites, FOREVER.
#   ⭐ FIX (doc-sync's, one line not a redesign): GATE ON WHAT THE RUN NEEDS,
#   REPORT THE RESERVE AS INFORMATION. A suite costs ~180-500 MB here; the box
#   can satisfy `available - SUITE_COST > FLOOR`. It cannot satisfy a floor set
#   above its own ceiling.
#   ⚠️ The reserve stays PRINTED because it is real — dir watched the serve climb
#   295 → 1778 MB in ninety seconds with VmSwap PINNED at 74 MB throughout, which
#   is the allocation mechanism confirmed by an independent physical consequence
#   (a paging story REQUIRES swap to fall as rss rises; it did not move at all).
#   ⇒ It is a judgement about work it might do, not a certainty about pages it
#   must fault. Those deserve different sized reserves and only one was ever real.
SUITE_COST=500             # MB a single suite adds here, measured 180-500
FLOOR=1500                 # MB that must remain AFTER the suite starts
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

  # ⛔ RULE 10 — AN EMPTY OPERAND IS NOT ZERO, AND BASH DISAGREES.
  #   markdown measured it live in its own copy of this logic:
  #     min_avail=3000, hwm='', rss=''  →  $((3000 - ( - ))) = 3000
  #   ⇒ A FAILED /proc READ PRINTED headroom == available: THE MOST FLATTERING
  #   ANSWER POSSIBLE, FROM NO MEASUREMENT AT ALL. It had the not-found case
  #   guarded and thought that covered it — ⛔ the pid can be FOUND and the READ
  #   can still FAIL, and those two absences do not share a code path.
  #   log hit the same thing inside its own fix for it (sentinel −1 for both
  #   terms ⇒ available − (−1 − −1) = available). yepochs printed a
  #   "PESSIMISTIC headroom -2854 MB" from a missing reading the same way.
  #   ⇒ REQUIRE BOTH TERMS TO BE NUMERIC BEFORE ANY ARITHMETIC. Three doors,
  #   one hour, one trap: an unverifiable measurement resolving to the
  #   comfortable value.
  case "$srss" in ''|*[!0-9]*) srss="" ;; esac
  case "$shwm" in ''|*[!0-9]*) shwm="" ;; esac

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

# ⛔ RULE 8 — PRINT ALL THREE OF rss, VmHWM AND THE RESERVE, so the RATCHET IS
#   READABLE. commonplace's catch, and it lands on RULE 7: VmHWM only ever moves
#   UP and nothing resets it short of a process restart. ⇒ a criterion built on
#   it gets HARDER TO REACH FOREVER AND NEVER EASIER — and nobody notices it
#   drifting, because every individual reading is defensible. This serve has
#   been up 3d21h; if it touches 5 GB for one minute the fleet reserves 5 GB on
#   every future quiet night. VmPeak is already 6050 MB, the ceiling VmHWM is
#   free to climb toward.
#   ⭐ THAT IS `swap free > 1000` ARRIVING BY ANOTHER ROUTE — the failure I
#   corrected on myself at 17:52, recreated through a fix for a different bug.
#   ⇒ A single number has nothing to disagree with; a reserve that only grows
#   needs something printed beside it to show that it grew.
#   ⚠️ HONEST LABEL: VmHWM is "the most this process has EVER held SINCE IT
#   STARTED", not "the most it holds". Those diverge further every day it is up.
load1=$(cut -d' ' -f1 /proc/loadavg)
reserve=$(( shwm - srss ))
printf 'BOX|min_headroom=%sMB|min_available=%sMB|samples=%s|span=%ss|from=%s|load1=%s|suites<=%s|beams=%s|serve_rss=%sMB|serve_hwm=%sMB|reserve=%sMB\n' \
  "$min_head" "$min_avail" "$n" "$SPAN" "$started" "$load1" "$max_suites" "$max_beams" "$srss" "$shwm" "$reserve"

# RULE 9: the gate is on what a suite needs; the reserve is reported, not gated.
margin=$(( min_avail - SUITE_COST ))

# ⭐ REACHABILITY SELF-CHECK — the artifact refuses to ship a criterion this box
#   cannot satisfy. This is the guard I did not have when I published
#   `swap free > 1000 MB`, and again when I published `headroom >= 2500`.
memtotal=$(awk '/^MemTotal/{print int($2/1024)}' /proc/meminfo)
if [ $(( FLOOR + SUITE_COST )) -ge "$memtotal" ]; then
  echo "BLIND|UNREACHABLE CRITERION: FLOOR($FLOOR)+SUITE_COST($SUITE_COST) >= MemTotal($memtotal) — this gate can never go green"
  exit 2
fi

if [ "$margin" -ge "$FLOOR" ]; then
  echo "VERDICT|SAFE — ${margin}MB would remain after a ${SUITE_COST}MB suite. One at a time; re-read before the NEXT start (per-start, not per-session)."
  echo "NOTE|reserve ${reserve}MB is INFORMATION, not a gate — the serve may allocate back toward VmHWM. Watch it climb; do not subtract it twice."
  exit 0
else
  echo "VERDICT|DO NOT START — only ${margin}MB would remain after a ${SUITE_COST}MB suite (floor ${FLOOR}MB)"
  exit 1
fi
