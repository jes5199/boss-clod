#!/usr/bin/env bash
# Watch for next's serial test columns to go quiet in /home/jes/next-suite-load.
# ⛔ NEVER pgrep -f / pkill -f: the pattern would match this script's own command line.
#    Enumerate /proc and resolve each pid's cwd + cmdline directly; skip our own pid.
# ⭐ The trigger is SUSTAINED quiet, not a single clear read: consecutive runs leave a gap
#    between them, and one clear sample inside that gap is indistinguishable from "done".
# ⭐ THE SENTINEL IS A TRIGGER, NOT A VERDICT. Boss still confirms with next before
#    telling biscuit the box is clear.
# ⭐ WHY THIS SURVIVES cell's FINDING (2026-09-03, commonplace-cell via plan row 614):
#    `suites()` counters in land-round.sh / log's wrapper count BEAMs, not doors — a child BEAM
#    through `erl_child_setup` also matches `-extra … mix … test`, so ONE suite reads as 2.
#    ⛔ Every design that compares a count against an expected k is wrong by that factor.
#    ⭐ THIS WATCHER IS A BOOLEAN: it tests `n > 0` and never compares n to anything. The
#    double-count changes a number it does not use. (I logged busy=2 for one suite at 04:26:59Z
#    and got the same verdict.) ⚠️ KEEP IT THAT WAY — the moment someone makes this count
#    suites, cell's finding applies to it too.
SELF=$$
NEED=6            # consecutive clear samples required
INTERVAL=60       # seconds between samples
OUT=/home/jes/boss-clod/.next-box-clear
LOG=/home/jes/boss-clod/.next-box-watch.log
clear_n=0
busy_seen=0
while :; do
  n=0
  for d in /proc/[0-9]*; do
    pid=${d#/proc/}
    [ "$pid" = "$SELF" ] && continue
    cmd=$(tr '\0' ' ' < "$d/cmdline" 2>/dev/null) || continue
    case "$cmd" in
      *next-suite-load*) : ;;
      *) cwd=$(readlink "$d/cwd" 2>/dev/null); case "$cwd" in */next-suite-load*) : ;; *) continue;; esac ;;
    esac
    case "$cmd" in *mix*|*beam.smp*) n=$((n+1));; esac
  done
  ts=$(date -u +%FT%TZ)
  if [ "$n" -gt 0 ]; then
    busy_seen=1; clear_n=0
    echo "$ts busy=$n" >> "$LOG"
  else
    clear_n=$((clear_n+1))
    echo "$ts clear ($clear_n/$NEED) busy_seen=$busy_seen" >> "$LOG"
    # ⛔ POSITIVE CONTROL: never declare clear if we never once saw it busy — that is the
    #    difference between "the runs finished" and "I was watching the wrong path".
    if [ "$clear_n" -ge "$NEED" ] && [ "$busy_seen" -eq 1 ]; then
      echo "$ts CLEAR after $((NEED*INTERVAL))s quiet; busy was observed earlier so the selector is proven non-vacuous" > "$OUT"
      exit 0
    fi
  fi
  sleep "$INTERVAL"
done
