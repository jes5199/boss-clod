#!/usr/bin/env bash
# ⭐ ANSWERS ONE QUESTION AND SAYS SO: has a codex door SPOKEN since the last thing I sent it?
#
# ⛔⛔ WHY THE OBVIOUS INSTRUMENTS DO NOT WORK — measured 2026-09-05T16:17Z, do not re-derive this:
#   messages.delivered_at        set 0.7 s after send. For the 75-minute ORG-2c stall it read
#                                "delivered 15:09:48" while the door did not see it until 16:13.
#   codex_deliveries.state       80 rows, 80 'accepted'. A COLUMN THAT HAS NEVER HELD A SECOND VALUE
#                                IS NOT A GATE — it cannot go red, so its green means nothing.
# ⇒ BOTH answer "did the transport accept it", in a voice that sounds like "did the door receive it".
#   Today's class one more time, and this time I found it by LOOKING rather than by being burned.
#
# ⭐ WHAT IS ACTUALLY AVAILABLE: a door's OWN outbound message is proof its turn ran. So:
#   lag = (now - last outbound from that door), and whether I sent it anything AFTER that.
# ⛔ THIS IS EVIDENCE, NOT PROOF. A door mid-round legitimately says nothing for a long time.
#   A door that has said nothing since before my dispatch is a door I should ASK, never nudge blindly.
set -uo pipefail
DB=/home/jes/.claude/channels/clod-squad/queue.db
[ -r "$DB" ] || { echo "BLIND|queue.db unreadable at $DB — this is no information, not silence"; exit 2; }
now=$(date -u +%s); found=0; worst=0
for lk in /home/jes/.codex/thread-writer-locks/*.lock; do
  [ -f "$lk" ] || continue
  pid=$(fuser "$lk" 2>/dev/null | tr -d ' '); [ -n "$pid" ] || continue
  cwd=$(readlink /proc/$pid/cwd 2>/dev/null) || continue
  name=${cwd##*/}
  th=$(basename "$lk" .lock)
  # the door's identities carry the thread id, or are the bare repo name
  last_out=$(sqlite3 "$DB" "SELECT MAX(created_at) FROM messages WHERE from_id LIKE 'codex-%$name%';" 2>/dev/null)
  last_in=$(sqlite3 "$DB"  "SELECT MAX(created_at) FROM messages WHERE to_id  LIKE 'codex-%$name%';" 2>/dev/null)
  found=$((found+1))
  [ -n "$last_out" ] || { echo "NO-VOICE|$name (pid $pid) has NEVER sent a clod-squad message — cannot be judged by this instrument"; continue; }
  lo=$(date -u -d "$last_out" +%s 2>/dev/null || echo 0)
  li=$(date -u -d "${last_in:-$last_out}" +%s 2>/dev/null || echo 0)
  lag=$(( (now - lo) / 60 ))
  [ "$lag" -gt "$worst" ] && worst=$lag
  if [ "$li" -gt "$lo" ]; then
    owed=$(( (now - li) / 60 ))
    # ⛔⛔ THRESHOLD, ADDED 16:22Z ON ITS FIRST LIVE RUN — WITHOUT IT THIS GATE FIRES ON CORRECT STATE.
    # I message a door, and one second later "inbound newer than outbound" is TRUE and says UNANSWERED.
    # Both doors read UNANSWERED at owed=0m while both were healthy and mid-turn.
    # ⭐ A GATE THAT FIRES ON KNOWN-GOOD INPUT IS WORSE THAN NO GATE: it trains its only reader to skim,
    # and the reader is me, every five minutes. The real signal is SILENCE ACROSS A TURN BOUNDARY, and
    # a turn takes minutes. 15m is chosen to sit above a normal turn and far below the 75m that cost us
    # the incident — it is a threshold I can defend, not a round number.
    # ⛔⛔ QUEUE SUPPRESSION, ADDED 19:08Z AFTER THIS GATE CRIED WOLF THREE TIMES IN ONE HOUR.
    #   UNANSWERED fired on codex-commonplace-log (26m) and codex-commonplace-next (32m) while BOTH were
    #   QUEUED FOR A BOX WINDOW I HAD NOT GRANTED. Each time I read the pane and found: only bun +
    #   codex-code-mode children, a coherent last turn, and an explicit "awaiting handover without polling".
    #   ⇒ THE DOORS WERE DOING EXACTLY WHAT I ASKED. The gate was measuring "I spoke last", which was TRUE
    #   and was not a finding.
    # ⭐ A GATE THAT FIRES ON KNOWN-GOOD STATE TRAINS ITS ONLY READER TO SKIM, AND THAT READER IS ME, EVERY
    #   FIVE MINUTES. Same defect I fixed with the 15m threshold at 16:22Z, one layer out: the threshold
    #   stopped it firing on a door I had JUST messaged; it did not stop it firing on a door that is
    #   CORRECTLY WAITING FOR ME.
    # ⛔ THE DISCRIMINATOR IS NOT TIME, IT IS WHETHER I OWE THE DOOR SOMETHING: a door named in .box-waiting
    #   is silent BECAUSE OF ME. Nudging it would be the "stall sweep as substitute for a fix" failure.
    # ⚠️ FAILS SAFE AND VISIBLY: it still PRINTS the door with its silence, as QUEUED-QUIET. It suppresses
    #   the ASK verb, not the row — an unqueued door crossing the threshold still says UNANSWERED.
    # ⛔⛔ MATCH THE LINE START, NOT THE LINE. Caught within 60 SECONDS of writing the suppression above:
    #   a bare `grep "$name"` marked the HOLDER (yelixer) as QUEUED, because a queue line of MY OWN PROSE
    #   said "waiting only on the yelixer window". ⇒ THE FILE DESCRIBES THE HOLDER IN ORDER TO EXPLAIN THE
    #   WAIT, so the holder's name is ALWAYS liable to appear in it.
    # ⭐ Same defect as `ls-remote | grep sha` (7x682) and `.licenseInfo.spdxId` (7x681): A GENERIC TEXT
    #   MATCH STANDING IN FOR A STRUCTURAL QUESTION. The question is "is this door AN ENTRY", not "does
    #   its name OCCUR". Entries begin at column 1; prose does not.
    if [ -f /home/jes/boss-clod/.box-waiting ] && command grep -q "^codex-[^ |]*${name}" /home/jes/boss-clod/.box-waiting 2>/dev/null; then
      echo "QUEUED-QUIET|$name (pid $pid): silent ${owed}m, and it is QUEUED IN .box-waiting for a window I have not granted. ⇒ waiting on ME. NOT a finding, and NOT to be nudged."
    elif [ "$owed" -lt "${LAG_ASK_MINUTES:-15}" ]; then
      echo "PENDING|$name (pid $pid): I wrote to it ${owed}m ago, no reply yet. NORMAL — under the ${LAG_ASK_MINUTES:-15}m ask-threshold. Not a finding."
    else
      echo "UNANSWERED|$name (pid $pid): I sent it something ${owed}m ago and it has not spoken since (last voice ${lag}m ago, thread ${th:0:8}). ⇒ ASK IT whether the dispatch reached its turn. Do NOT assume working, and do NOT assume stalled."
    fi
  else
    echo "SPOKE-LAST|$name (pid $pid): last voice ${lag}m ago, after anything I sent. Its turn has run since my last message."
  fi
done
[ "$found" -eq 0 ] && { echo "BLIND|no codex doors resolved from writer locks — NOT 'no doors running'"; exit 2; }
echo "DOORS|examined=$found|worst-silence=${worst}m"
exit 0
