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
# ⛔⛔ SECOND DEFECT, caught 2026-08-23 07:23Z: the verdict USED TO DEPEND ON MATCHING
# ENGLISH. It reported "no promise phrase" for a turn ending
#     "Starting with `derivation_map_inverse_test.exs` and ... , since those test ..."
# -- a bare present-participle promise the regex did not enumerate. ⇒ A detector that
# says "no promise" when there IS one is the false-green class it was built to catch,
# and it fails EXACTLY on the phrasings I did not think of, which is not a list I can
# finish.
# ⭐ FIX: the VERDICT no longer depends on the wording. stop=end_turn PLUS nothing
# running IS the stall candidate; the phrase is reported as a DETAIL explaining why,
# never as the thing that decides. ⇒ Stop asking "did it promise" (unbounded language
# problem) and ask "did it stop with nothing scheduled" (a fact about the machine).
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
        # ⭐ INCLUDE TOOL-CALL INPUT TEXT, NOT ONLY THE FINAL ASSISTANT TEXT.
        # commonplace-doc declared 'nothing queued' in the clod-squad MESSAGE it sent me
        # and not in its own user-facing summary — so the declared-pause gate fired on a
        # worker that had followed the protocol exactly. ⛔ A gate that fires on correct
        # state is worse than no gate: it gets routed around. The declaration is the token
        # the agent EMITTED, wherever it emitted it.
        parts=[]
        for x in c:
            if not isinstance(x,dict): continue
            if x.get('type')=='text': parts.append(x.get('text',''))
            elif x.get('type')=='tool_use':
                inp=x.get('input') or {}
                if isinstance(inp,dict):
                    for v in inp.values():
                        if isinstance(v,str): parts.append(v)
        txt=' '.join(parts)
    turns.append((d.get('timestamp',''), sr, txt.strip()))
if not turns:
    print("BLIND|transcript parsed but contained zero turns"); sys.exit(2)
ts,sr,txt = turns[-1]
# ⭐ THE DECLARATION SCOPE IS THIS RESPONSE, NOT THIS TURN.
# commonplace-doc said 'nothing queued' inside a clod-squad send at turn[-2]
# (stop=tool_use); its final turn was plain prose without the token. Checking only
# the last turn made the gate fire on a worker that had followed the protocol.
# ⇒ Walk back over the contiguous tool_use turns and stop at the previous end_turn:
# that span is exactly one agent response, from its last input to now. ⛔ Wider than
# that and a stale declaration would suppress a later, genuine stall.
decl_txt = txt
_i = len(turns) - 2
while _i >= 0 and turns[_i][1] == 'tool_use':
    decl_txt += ' ' + turns[_i][2]
    _i -= 1
tail = txt[-200:].replace('\n',' ')
# first-person future-tense promise, at the END of the turn
promise = re.search(r"\b(I'?ll|I will|I'?m going to|going to|next\b|I plan to|then I|starting with|first[,:]|reading .{0,30}next)\b",
                    txt[-900:], re.I)
import subprocess
def live_work():
    try:
        n=subprocess.run(['pgrep','-u','jes','-x','codex'],capture_output=True,text=True).stdout.split()
        return len(n)
    except Exception:
        return -1
running = live_work()
# ⭐ A legitimately-idle worker must not report STALL-CANDIDATE. Same files the pane
# watch uses, so the two instruments cannot disagree about who is expected to be idle.
def listed(path, name):
    try:
        for line in open(path):
            if line.startswith('#'): continue
            if line.split()[:1] == [name]: return True
    except Exception: pass
    return False
retired = listed('/home/jes/boss-clod/.watch-retired', w)
blocked = listed('/home/jes/boss-clod/.watch-blocked', w)

if sr != 'end_turn':
    verdict = f"WORKING (stop={sr})"
elif running > 0:
    verdict = f"ended on text, but {running} round(s) running — legitimately waiting"
elif running == 0 and re.search(r"\bnothing queued\b", decl_txt, re.I):
    # ⭐ AGENT-DECLARED PAUSE (protocol agreed with yepochs 2026-08-23 08:24Z).
    # My verdict is "end_turn + nothing running", which deliberately ignores wording —
    # and therefore CANNOT distinguish "stalled on a promise" from "finished a chunk
    # and said so". The agent CAN. ⇒ Rather than have the instrument guess, the agent
    # declares: a turn that ends with nothing pending says the literal words "nothing
    # queued", and the transcript then CONFIRMS OR CONTRADICTS the sweep instead of my
    # judgement arbitrating.
    # ⛔ This is the ONE place wording is load-bearing, and it is safe because it is a
    # PROTOCOL TOKEN, not an attempt to parse intent: a stalled agent has no reason to
    # emit it, and an agent that emits it falsely is making a checkable claim.
    verdict = "DECLARED PAUSE — agent said 'nothing queued'; not a stall"
elif running == 0 and retired:
    verdict = "idle BY DECISION (retired) — expected, not a stall"
elif running == 0 and blocked:
    verdict = "idle BLOCKED on a named party — expected, not a stall"
elif running == 0:
    verdict = "STALL-CANDIDATE — ended on text with NOTHING running"
else:
    verdict = "BLIND — could not determine whether anything is running"
why = " · forward-looking phrase present" if promise else " · no phrase matched (verdict does NOT depend on this)"
print(f"TURN|{w}|{ts}|stop={sr}|{verdict}{why if sr=='end_turn' else ''}")
print(f"TURN|{w}|  …{tail}")
print(f"TURN|{w}|turns_examined={len(turns)}  (control: nonzero => the parser saw real turns)")
PY
