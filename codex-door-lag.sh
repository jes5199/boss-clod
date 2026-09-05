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
    echo "UNANSWERED|$name (pid $pid): I sent it something ${owed}m ago and it has not spoken since (last voice ${lag}m ago, thread ${th:0:8}). ⇒ ASK IT whether the dispatch reached its turn. Do NOT assume working, and do NOT assume stalled."
  else
    echo "SPOKE-LAST|$name (pid $pid): last voice ${lag}m ago, after anything I sent. Its turn has run since my last message."
  fi
done
[ "$found" -eq 0 ] && { echo "BLIND|no codex doors resolved from writer locks — NOT 'no doors running'"; exit 2; }
echo "DOORS|examined=$found|worst-silence=${worst}m"
exit 0
