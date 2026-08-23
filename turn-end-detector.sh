#!/usr/bin/env bash
# Did this worker's last TURN end on a promise instead of a tool call?
#
# ⭐ LESSONS.md 7x82: a turn ends when there is nothing left to emit. A sentence
# describing a future tool call IS something emitted, so it SATISFIES the exit
# condition the tool call would have blocked. The tell is exact:
#     a first-person future-tense sentence  followed by  stop_reason=end_turn
#
# ⛔ DEFECT THIS SCRIPT WAS BORN WITH (caught on its first run, 2026-08-23 06:39Z):
# the inline version printed the last N ROWS of the transcript. The file's tail is
# often metadata (mode / permission-mode / bridge-session rows), so it printed
# those and NO TURN AT ALL — and an empty result reads exactly like "no promise
# pattern found". ⇒ Select rows BY CONTENT (has a stop_reason), never by position.
#
# usage: turn-end-detector.sh <worker-name>
# rc 0 = report printed   2 = instrument blind (no transcript / no turns)

set -uo pipefail
w="${1:?usage: turn-end-detector.sh <worker-name>}"
D="/home/jes/.claude/projects/-home-jes-${w}"
[ -d "$D" ] || { echo "BLIND|no project dir for $w"; exit 2; }

# pick the transcript that actually HAS turns, not merely the newest file
F=""
for f in $(ls -t "$D"/*.jsonl 2>/dev/null); do
  n=$(python3 -c "
import json,sys
c=0
for line in open(sys.argv[1], errors='ignore'):
    try: d=json.loads(line)
    except: continue
    if (d.get('message') or {}).get('stop_reason'): c+=1
print(c)" "$f")
  [ "${n:-0}" -gt 0 ] && { F="$f"; break; }
done
[ -n "$F" ] || { echo "BLIND|no transcript with any stop_reason rows — cannot judge, NOT 'no promise'"; exit 2; }

python3 - "$F" "$w" <<'PY'
import json,sys,re
path,w=sys.argv[1],sys.argv[2]
turns=[]
for line in open(path, errors='ignore'):
    try: d=json.loads(line)
    except: continue
    m=d.get('message') or {}
    sr=m.get('stop_reason')
    if not sr: continue
    c=m.get('content'); txt=''
    if isinstance(c,list):
        txt=' '.join(x.get('text','') for x in c if isinstance(x,dict) and x.get('type')=='text')
    turns.append((d.get('timestamp',''), sr, txt.strip()))
if not turns:
    print("BLIND|transcript parsed but contained zero turns"); sys.exit(2)
ts,sr,txt = turns[-1]
tail = txt[-200:].replace('\n',' ')
# first-person future-tense promise, at the END of the turn
promise = re.search(r"\b(I'?ll|I will|I'?m going to|next[,:]|now\b.{0,40}\bdispatch|in this turn)\b",
                    txt[-400:], re.I)
verdict = "PROMISE-ENDED-TURN" if (sr=='end_turn' and promise) else \
          ("ended on text, no promise phrase" if sr=='end_turn' else f"stop={sr}")
print(f"TURN|{w}|{ts}|stop={sr}|{verdict}")
print(f"TURN|{w}|  …{tail}")
print(f"TURN|{w}|turns_examined={len(turns)}  (control: nonzero => the parser saw real turns)")
PY
