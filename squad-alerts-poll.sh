#!/bin/bash
# ⛔ pipefail: without it a pipeline reports the LAST stage, so a failing script read through
# a filter looks green. NOTE it does NOT save 1-vs-2 when a second stage also fails -- for a
# 0/1/2 script CAPTURE FIRST: out=$(script); rc=$?   (boss-clod, 2026-09-01)
set -o pipefail

# LIVENESS HEARTBEAT -- touched on EVERY run, including declines and errors.
# The three loops are CronCreate jobs: session-only, gone on restart. On
# 2026-08-08 only 1 of 3 was actually registered and nobody noticed for
# THREE DAYS, because a declining loop and an absent loop are both silent.
# LOOPS.md documented them, which did not help -- a file only works if
# someone reads it after a restart. This makes absence OBSERVABLE FROM DISK.
touch /home/jes/boss-clod/.heartbeat-squad-alerts-poll 2>/dev/null || true

# Relay-gap closer for squad-alerts.
#
# WHY THIS EXISTS (2026-07-31): the squad-alerts MCP server runs standalone in
# tmux window 15 and binds 127.0.0.1:5777. boss-clod's own MCP copy therefore
# cannot start, so the channel delivers nothing into the boss session — its
# JSON-RPC notifications scroll past in a tmux pane nobody reads. The store
# marks them `delivered_at` regardless, which is what made this invisible:
# alert #481 was "delivered" at 21:58:41 and no human ever saw it.
#
# Until the server is run as a proper child of the boss session, this polls the
# queue directly. Prints alerts at or above the severity floor that are newer
# than the last relayed id, then advances the marker. Read-only against the
# alert DB; the marker is the only state it writes.
#
# Exit 0 always. Output empty means nothing new.

DB=/home/jes/.claude/channels/squad-alerts/queue.db
MARK=/home/jes/boss-clod/.squad-alerts-last-relayed
[ -f "$DB" ] || { echo "MISSING_DB $DB"; exit 0; }
[ -f "$MARK" ] || echo 0 > "$MARK"
LAST=$(cat "$MARK" 2>/dev/null || echo 0)
case "$LAST" in ''|*[!0-9]*) LAST=0 ;; esac

# ⛔⛔ 2026-08-09: THIS SCRIPT USED TO END IN A BARE `exit 0` WITH THE PYTHON
# EXIT CODE UNCHECKED. A locked DB, a schema change, or any sqlite error would
# print nothing to stdout, exit 0, and be read by boss as "nothing undelivered"
# — which is reported to jes in exactly those words, every few minutes.
# ⚠️ THE ALERT PATH'S WHOLE PURPOSE IS THAT A WORKING DETECTOR MUST REACH
# SOMEONE WHO ACTS. A silent failure here does not merely lose an alert: it
# manufactures the reassurance that there was none.
# ⇒ "No new alerts" and "the poll broke" MUST NOT share an exit code or an
# empty stdout. A broken poll now SHOUTS ON STDOUT (so it gets relayed like
# an alert) and exits 3.
python3 - "$DB" "$LAST" "$MARK" <<'PY'
import sqlite3, sys
db, last, mark = sys.argv[1], int(sys.argv[2]), sys.argv[3]
c = sqlite3.connect(f'file:{db}?mode=ro', uri=True)
c.row_factory = sqlite3.Row
rows = list(c.execute(
    "select id,severity,source,title,body,created_at,related_bead "
    "from alerts where id > ? and severity in ('critical','error') "
    "order by id", (last,)))
if not rows:
    sys.exit(0)
for r in rows:
    print(f"ALERT #{r['id']} [{r['severity']}] {r['source']} {r['created_at'][:19]}")
    print(f"  {r['title']}")
    body = (r['body'] or '').strip().replace('\n', '\n  ')
    if body:
        print(f"  {body[:600]}")
    if r['related_bead']:
        print(f"  bead: {r['related_bead']}")
    print()
open(mark, 'w').write(str(rows[-1]['id']))
print(f"({len(rows)} new; marker -> {rows[-1]['id']})")
PY
rc=$?   # captured immediately; the rc you act on never comes through a pipe
if [ "$rc" -ne 0 ]; then
  echo "POLL_FAILED rc=$rc — squad-alerts poll did NOT run to completion."
  echo "  This is NOT 'no new alerts'. Alerts may be undelivered and unseen."
  echo "  DB: $DB   marker: $MARK (last relayed: $LAST)"
  exit 3
fi
exit 0
