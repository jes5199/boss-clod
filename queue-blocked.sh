#!/usr/bin/env bash
# queue-blocked.sh — answers "IS ANYTHING ACTUALLY BLOCKED", which is NOT what stall-sweep asks.
#
# ⭐ WHY THIS EXISTS (boss, 2026-08-27T23:00Z). stall-sweep's verdict is `stop=end_turn` plus
#   nothing running, and that is exactly true every time. But FOUR TIMES in one hour it reported a
#   box holder as STALLED when the holder had LANDED, PUSHED and RELEASED inside the same minute
#   (doc 22:30 · markdown 22:37 · next 22:50 · doc-sync 22:53). I hand-ran the discriminator each
#   time and it lived nowhere. My own standing rule: if you catch a trap twice, move the check into
#   a file the next reader trips over.
# ⇒ ⭐ THE TWO INSTRUMENTS HAVE DIFFERENT SUBJECTS. stall-sweep measures TURN BOUNDARIES.
#   This measures RESOURCE CUSTODY. They coincided while the fleet was mid-round and stopped
#   coinciding once doors began finishing cleanly.
#
# ⛔ WHAT IT DOES NOT DO: it does not nudge, does not read panes, and starts no BEAM.
#   It answers ONE question and prints a verdict that can go red.
# ⭐ ALL THREE ARMS DEMONSTRATED 2026-08-27T23:01Z, in a THROWAWAY repo — never a real one, because
#   a stray tmp/SLOT_GRANTED makes a door believe it holds the box:
#     RED    token held 3804s, no BEAM  -> BLOCKED, rc 1   AND control token-paths-visible=1
#     GREEN  same repo, token removed   -> OK,      rc 0
#     BLIND  empty .watch-workers       -> BLIND,   rc 2
#   Cleanup verified BY EFFECT afterwards: probe dir gone, and 0 SLOT_GRANTED files on the box.
# ⚠️ THE CONTROL LINE EXISTS BECAUSE MY FIRST GREEN RUN PRINTED token-paths-visible=0 — i.e. it
#   passed VACUOUSLY. A zero-holder OK and a broken path-shape print the same verdict, so the
#   control is what separates "the box is free" from "I cannot see a token even if one exists".
#   ⛔ Read the CONTROL before believing the OK.
set -uo pipefail
FLEET_DIRS=$(sed 's/#.*//' "$(dirname "$0")/.watch-workers" 2>/dev/null | tr -d ' \t' | grep .)
[ -z "$FLEET_DIRS" ] && { echo "BLIND|.watch-workers unreadable or empty — NOT 'nothing blocked'"; exit 2; }
n_examined=0; n_holders=0; blocked=""
for w in $FLEET_DIRS; do
  d="/home/jes/$w"; [ -d "$d/.git" ] || continue
  n_examined=$((n_examined+1))
  tok=""; [ -f "$d/tmp/SLOT_GRANTED" ] && tok="yes"
  [ -z "$tok" ] && continue
  n_holders=$((n_holders+1))
  # a holder is only BLOCKING if it holds the token AND has no BEAM of its own
  beam=""
  for p in $(pgrep -x beam.smp 2>/dev/null); do
    case "$(readlink /proc/$p/cwd 2>/dev/null)" in "$d"*) beam="$p";; esac
  done
  age=$(( $(date -u +%s) - $(stat -c %Y "$d/tmp/SLOT_GRANTED" 2>/dev/null || date -u +%s) ))
  if [ -n "$beam" ]; then
    echo "HOLDER|$w|token held ${age}s|BEAM pid=$beam — RUNNING, not blocked"
  else
    echo "HOLDER|$w|token held ${age}s|NO BEAM — idle with the box"
    [ "$age" -gt 300 ] && blocked="$blocked $w"
  fi
done
# CONTROL: the token check must be able to SEE a token. Prove the path shape is right.
ctl=$(command find /home/jes -maxdepth 3 -name SLOT_GRANTED -path '*/tmp/*' 2>/dev/null | wc -l)
echo "CONTROL|token-paths-visible=$ctl|examined=$n_examined|holders=$n_holders"
if [ "$n_examined" -eq 0 ]; then echo "BLIND|examined 0 repos — the fleet list resolved to nothing"; exit 2; fi
if [ -n "$blocked" ]; then echo "BLOCKED|$blocked|holder idle >300s with the box — THE QUEUE CANNOT MOVE"; exit 1; fi
echo "OK|nothing blocked|holders=$n_holders (0 means the box is free, which is not the same as idle)"
exit 0
