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
  # ⛔ The alert is a FILE first: this script has no session and no channel, and a watchdog that needs
  #    the thing it watches in order to report is not a watchdog.
  # ⭐⭐ BUT A FILE ONLY BOSS READS IS STILL A FILE ONLY BOSS READS. The real cost of the 2026-09-03
  #    wedge landed on the OBEDIENT doors: chit and plan waited two hours for a grant from a
  #    coordinator that was not there, while doors that would have started anyway lost nothing.
  #    ⇒ SO TELL A LIVE DOOR. This inserts straight into clod-squad's queue — the same path
  #    watchdog.sh uses — so the notice does not depend on boss being alive to relay it.
  # ⚠️ ONCE PER WEDGE, not once per tick: a watchdog that repeats every 5 minutes for two hours is
  #    noise, and the doors it is warning are the ones already sitting still.
  if [ ! -f "$ALERT.notified" ]; then
    # ⛔⛔ DO NOT BUILD THIS INSERT WITH sed/printf QUOTING. My first version wrapped EACH LINE of a
    #    multi-line body in single quotes, produced invalid SQL, and — because stderr was sent to
    #    /dev/null — WROTE THE ALERT FILE AND SILENTLY DELIVERED NOTHING. The red arm "fired"
    #    (the file appeared) while the thing the arm exists for did not happen.
    # ⭐ CAUGHT ONLY BY COUNTING ROWS BEFORE AND AFTER. The file was the observable; the row count
    #    was the measurement. Another decline-flag: success-shaped and empty.
    AGE="$age" MAXAGE="$MAX_AGE" python3 - <<'PY' 2>>"$STAMP.log"
import os, sqlite3, datetime
body = ("\u26d4 SWEEP-HEARTBEAT (system cron, outside boss's session): boss-clod's 5-minute stall "
        "sweep has not stamped for %ss (limit %ss). BOSS IS PROBABLY WEDGED AND CANNOT TELL YOU SO "
        "ITSELF.\n\u21d2 DO NOT WAIT ON BOSS for a box window, a release or a relay while this "
        "stands. If you were holding for a grant, use your own judgement about contention: check the "
        "box directly (ps for a beam.smp running mix test) and say in your next message that you "
        "proceeded without a grant and why.\n\u26a0\ufe0f This notice is written by a cron script "
        "with no session. It CANNOT answer questions, and boss may be wedged for an unknown further "
        "period. When boss returns it will say so explicitly."
        % (os.environ["AGE"], os.environ["MAXAGE"]))
now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")
db = sqlite3.connect("/home/jes/.claude/channels/clod-squad/queue.db", timeout=10)
for who in ("commonplace-plan","commonplace-next","commonplace-chit",
            "commonplace-cell","commonplace-biscuit","hermes"):
    db.execute("INSERT INTO messages (from_id,to_id,body,created_at) VALUES (?,?,?,?)",
               ("boss-clod", who, body, now))
db.commit(); db.close()
PY
    touch "$ALERT.notified"
  fi
else
  rm -f "$ALERT" "$ALERT.notified"   # ⭐ clearing BOTH re-arms the one-shot for the next wedge
  echo "$(date -u +%FT%TZ) ok age=${age}s" >> "$STAMP.log"
fi
