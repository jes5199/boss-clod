#!/usr/bin/env bash
# ⭐ THE READER OUTSIDE THE FLEET. Runs from SYSTEM cron, not from boss's session.
#
# ⛔⛔ WHY IT EXISTS (2026-09-03T15:08Z): boss's 5-minute stall sweep WEDGED for ~2 hours. About
#   twenty invocations queued and arrived together. NOBODY WAS WATCHING, and boss could not know:
#   ⭐ NO VERDICT ARRIVING LOOKS EXACTLY LIKE `stalled=0`.
# ⭐ hermes named the precondition I had never written: "a filed artifact fires; a remembered rule
#   does not" IS ONLY TRUE IF ITS READER IS ALIVE. Filing moves the fragility from memory to a
#   reader; it does not remove it. My .box-queue, my hold record and my open-questions file were all
#   filed and none fired, because the thing that reads them was the thing that stopped.
# ⇒ hermes's systemd timers survived its session ending because THE READER IS THE OS. This script
#   is that: an out-of-session reader whose armed state a second door can query.
#
# It answers ONE question: has the in-session sweep touched its stamp recently?
# ⛔ It does NOT judge the fleet. A watchdog that duplicates the thing it watches shares its bugs.
STAMP=/home/jes/boss-clod/.sweep-heartbeat
ALERT=/home/jes/boss-clod/.sweep-heartbeat-ALERT
MAX_AGE=1200   # 20 min = 4 missed 5-minute sweeps; one missed sweep is noise, four is a wedge
now=$(date +%s)
if [ ! -f "$STAMP" ]; then
  # ⭐ NOT AN ALERT: a missing stamp means the sweep has never run since this script was installed,
  #    which is indistinguishable from a fresh install. Say so rather than crying wolf on minute one.
  echo "$(date -u +%FT%TZ) NO-STAMP (never seen a sweep yet; not an alert)" >> "$STAMP.log"
  exit 0
fi
age=$(( now - $(stat -c %Y "$STAMP") ))
if [ "$age" -gt "$MAX_AGE" ]; then
  msg="$(date -u +%FT%TZ) SWEEP-WEDGED: last sweep stamp is ${age}s old (limit ${MAX_AGE}s)"
  echo "$msg" >> "$STAMP.log"
  echo "$msg" > "$ALERT"
  # ⛔ The alert is a FILE, not a message: this script has no session and no channel, and a watchdog
  #    that needs the thing it watches in order to report is not a watchdog.
else
  rm -f "$ALERT"
  echo "$(date -u +%FT%TZ) ok age=${age}s" >> "$STAMP.log"
fi
