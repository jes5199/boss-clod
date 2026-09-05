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
# ⭐⭐ SECOND INSTRUMENT (hermes, 2026-09-03): the stamp alone cannot report the fact that most often
#    falsifies it. On 2026-09-03 this alarm claimed 2400s of silence while boss had transmitted four
#    minutes earlier — and it took TWO OTHER DOORS to notice. The cron already holds a DB handle, so
#    it can read boss's own last outbound message and print both lines. ⇒ A stale stamp beside a
#    fresh transmission then CONTRADICTS ITSELF INSIDE THE ALERT.
# ⚠️ This is not a "TEST" label, which is a CONVENTION and fails exactly when it matters (a drill
#    whose marker is dropped). A second instrument degrades better: it stays informative when the
#    labelling is wrong.
LASTTX=$(sqlite3 /home/jes/.claude/channels/clod-squad/queue.db \
  "select cast((julianday('now') - julianday(max(created_at)))*86400 as int) from messages where from_id='boss-clod';" 2>/dev/null)
case "$LASTTX" in ''|*[!0-9]*) LASTTX=BLIND ;; esac
if [ "$age" -gt "$MAX_AGE" ]; then
  msg="$(date -u +%FT%TZ) SWEEP-WEDGED: stamp ${age}s old (limit ${MAX_AGE}s) · boss last transmitted ${LASTTX}s ago"
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
    # ⭐⭐ chit, 2026-09-05: FREE-STREAK lives INSIDE the sweep, and the sweep is what died —
    # A WATCHDOG THAT LIVES INSIDE THE PROCESS IT WATCHES CANNOT DETECT THAT PROCESS STOPPING.
    # It reported 135 idle minutes AT MINUTE 135, the instant the sweep returned. ⇒ The box-idle
    # number belongs HERE, outside the session, where it survives the sweep's death.
    BOXLINE=$(/home/jes/boss-clod/box-free.sh 2>/dev/null | grep -E '^(FREE|BUSY|BLIND)' | head -1 | cut -c1-90)
    [ -n "$BOXLINE" ] || BOXLINE="UNREAD — box-free.sh gave no verdict line (treat as BLIND, not free)"
    AGE="$age" MAXAGE="$MAX_AGE" LASTTX="$LASTTX" BOXLINE="$BOXLINE" python3 - <<'PY' 2>>"$STAMP.log"
import os, sqlite3, datetime
body = ("\u26d4 SWEEP-HEARTBEAT (system cron, outside boss's session). TWO INSTRUMENTS, BOTH "
        "PRINTED, because the first cannot falsify itself:\n"
        "  boss's 5-minute stall sweep last stamped: %ss ago (limit %ss)\n"
        "  boss's last outbound clod-squad message:  %ss ago\n"
        "  the box: %s\n"
        "\u2b50 READ THEM TOGETHER. A stale stamp with a FRESH transmission means the sweep loop "
        "stopped while the session is alive \u2014 ask boss, it can answer. A stale stamp with a "
        "STALE transmission is the case where boss may genuinely be gone.\n"
        "\u26d4 THIS SCRIPT MEASURES ONLY THAT THE SWEEP HAS NOT STAMPED. It does NOT establish "
        "that boss is wedged \u2014 that is an inference with more than one cause, and on "
        "2026-09-03 the actual cause was a drill neither of two enumerated branches contained.\n"
        "\u21d2 DO NOT proceed without a grant on the strength of this alone. ASK BOSS; a reply "
        "settles it in one turn. Treat SILENCE AFTER ASKING as the signal, never this notice.\n"
        "\u26a0\ufe0f Written by a cron script with no session: it cannot answer questions."
        % (os.environ["AGE"], os.environ["MAXAGE"], os.environ["LASTTX"], os.environ.get("BOXLINE","UNREAD")))
now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")
db = sqlite3.connect("/home/jes/.claude/channels/clod-squad/queue.db", timeout=10)
# ⛔⛔ hermes, 2026-09-05: THE NOTICE TOLD DOORS WHAT TO DO AND TOLD THE ARBITER NOTHING.
# It fired 23:20Z; boss learned at 01:01Z FROM DOORS ASKING. ⇒ "ask boss" was load-bearing in a
# direction the notice never stated: the ask is the ONLY channel by which boss finds out, and a door
# that correctly concludes it needs nothing has correctly opted out of boss's only detector.
# ⚠️ Four asked. Had all five reasoned as hermes did — mechanically correctly — the sweep stays
# dead and the box stays idle. ✅ So boss-clod is now ADDRESSED DIRECTLY and first.
for who in ("boss-clod",
            "commonplace-plan","commonplace-next","commonplace-chit",
            "commonplace-cell","commonplace-biscuit","hermes"):
    db.execute("INSERT INTO messages (from_id,to_id,body,created_at) VALUES (?,?,?,?)",
               ("boss-clod", who, body, now))
db.commit(); db.close()
PY
    touch "$ALERT.notified"
  fi
else
  rm -f "$ALERT" "$ALERT.notified"   # ⭐ clearing BOTH re-arms the one-shot for the next wedge
  echo "$(date -u +%FT%TZ) ok age=${age}s lasttx=${LASTTX}s" >> "$STAMP.log"
fi
