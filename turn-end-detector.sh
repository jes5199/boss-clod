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
import subprocess, os
# The worker's own claude process, resolved by its --mcp-config path (the same identity the pane
# watch uses). ⛔ NOT pgrep -f on a bare name: that pattern would appear in this process's own
# command line. We scan /proc and skip ourselves.
def _worker_claude_pid(name):
    me = os.getpid()
    for ent in os.listdir('/proc'):
        if not ent.isdigit() or int(ent) == me:
            continue
        try:
            argv = open(f'/proc/{ent}/cmdline','rb').read().decode().split('\0')
        except Exception:
            continue
        if not any(a.endswith(f'mcp-config-{name}.json') for a in argv):
            continue
        if any(os.path.basename(a) == 'claude' for a in argv[:2]):
            return int(ent)
    return -1
worker_claude_pid = _worker_claude_pid(w)
def live_work():
    # ⛔⛔ 2026-08-24T17:28Z — THIS COUNTED EVERY CODEX ON THE BOX, GLOBALLY, WITH NO
    #   ATTRIBUTION TO THE WORKER BEING JUDGED. One agent's Sol round therefore made EVERY
    #   OTHER WORKER read "legitimately waiting", so NO STALL COULD BE DETECTED ANYWHERE while
    #   any round ran — and rounds ran most of 2026-08-24. The 5-minute sweep was structurally
    #   incapable of firing for hours, and its silence was indistinguishable from health.
    # ⭐ Found because yepochs flipped PAUSED -> RETIRED with nothing about yepochs changing;
    #   what changed was that commonplace-dir launched a round. A verdict that moves when an
    #   UNRELATED subject changes is not a verdict about this subject.
    # ⇒ Attribute each codex to a repo via its -C worktree: git rev-parse --git-common-dir
    #   resolves /home/jes/sol-dir-d11a/wt -> /home/jes/commonplace-dir/.git.
    mine, unattributable = 0, 0
    try:
        pids = subprocess.run(['pgrep','-u','jes','-x','codex'],
                              capture_output=True,text=True).stdout.split()
    except Exception:
        return -1, 0          # BLIND — the probe itself failed
    for pid in pids:
        try:
            argv = open(f'/proc/{pid}/cmdline','rb').read().decode().split('\0')
            tgt = argv[argv.index('-C')+1] if '-C' in argv else None
            if not tgt:
                unattributable += 1; continue
            cd = subprocess.run(['git','-C',tgt,'rev-parse','--path-format=absolute',
                                 '--git-common-dir'],capture_output=True,text=True)
            if cd.returncode != 0:
                unattributable += 1; continue
            repo = os.path.basename(os.path.dirname(cd.stdout.strip()))
            if repo == w:
                mine += 1
        except Exception:
            unattributable += 1

    # ⛔⛔ 2026-08-25T04:48Z — A WAITER IS WORK, AND THIS COULD NOT SEE ONE. commonplace-dir was
    #   reported STALLED while /home/jes/sol-dir-d14b/wait-and-launch.sh had been alive 54s,
    #   holding a queued D14B round behind the cap. A waiter that has NOT YET launched codex is
    #   not a codex process, so the -C attribution above is structurally blind to it.
    # ⭐ Same family as the two failures above: each time the instrument could not SEE the kind
    #   of work in front of it, and each time its blindness rendered as a confident verdict.
    # ⛔ Deliberately NOT pgrep -f 'wait-and-launch.sh' — that pattern would appear in this very
    #   process's own command line and match itself. Scanning /proc and skipping our own pid is
    #   the only form that cannot match the searcher.
    # ⛔⛔ 2026-08-25T05:09Z — A HELD SHELL IS WORK, AND THIS COULD NOT SEE ONE EITHER.
    #   commonplace-doc-sync read STALL-CANDIDATE while pid 993502 — a /bin/bash -c retry loop it
    #   had started — sat in `for i in $(seq 1 60) … sleep 60`, retrying dispatch-round.sh until a
    #   cap slot freed, then waiting on the outer pid. Its own pane said "1 shell still running";
    #   BOTH of my instruments said idle. A background shell holds the turn open and re-invokes the
    #   worker when it exits, so it is exactly the thing that makes waiting legitimate.
    # ⭐ FOURTH member of the family (global count / in-process subagent / waiter script / held
    #   shell). ⇒ Stop enumerating kinds of work and attribute by PARENTAGE instead: a live child
    #   of the worker's own claude pid.
    # ⛔ BUT NOT EVERY CHILD — the MCP servers (`bun run … clod-squad`, `… irc-channel`) are
    #   permanent children. Counting those would make EVERY worker read "legitimately waiting"
    #   forever, which is the 17:28Z catastrophe with the sign flipped and no way to notice.
    #   ⇒ Count only the Bash-tool shape: argv[0] is a shell AND '-c' is present.
    for ent in os.listdir('/proc'):
        if not ent.isdigit():
            continue
        try:
            with open(f'/proc/{ent}/stat','rb') as fh:
                ppid = int(fh.read().decode().rsplit(')',1)[1].split()[1])
        except Exception:
            continue
        if ppid != worker_claude_pid:
            continue
        try:
            argv = open(f'/proc/{ent}/cmdline','rb').read().decode().split('\0')
        except Exception:
            continue
        argv = [a for a in argv if a]
        if not argv:
            continue
        if os.path.basename(argv[0]) in ('bash','sh','zsh') and '-c' in argv:
            mine += 1

    my_pid = os.getpid()
    for ent in os.listdir('/proc'):
        if not ent.isdigit() or int(ent) == my_pid:
            continue
        try:
            argv = open(f'/proc/{ent}/cmdline','rb').read().decode().split('\0')
        except Exception:
            continue
        script = next((a for a in argv if a.endswith('/wait-and-launch.sh')), None)
        if not script:
            continue
        try:
            cd = subprocess.run(['git','-C',os.path.join(os.path.dirname(script),'wt'),
                                 'rev-parse','--path-format=absolute','--git-common-dir'],
                                capture_output=True,text=True)
            if cd.returncode != 0:
                unattributable += 1; continue
            if os.path.basename(os.path.dirname(cd.stdout.strip())) == w:
                mine += 1
        except Exception:
            unattributable += 1
    return mine, unattributable
running, unattr = live_work()

# ⛔⛔ 2026-08-24T17:30Z — A CODEX COUNT CANNOT SEE AN IN-PROCESS SUBAGENT. commonplace-merkle-crdt
#   was reported STALLED while its author/4 implementer ran as a background Claude subagent. Those
#   live INSIDE the worker's own claude process — there is no separate process to count, so
#   "turn ended + no codex" is its NORMAL WORKING STATE, not an idle one. Its words.
# ⭐ The pane watch already saw this correctly (busy [bg-agent]) while this instrument said STALLED.
#   ⇒ The two disagreed and the SCRAPER was right. Same lesson as §7x146 inverted: there I trusted
#     the transcript over the pane; the rule is not "prefer one", it is ASK WHICH ONE CAN SEE THE
#     THING IN QUESTION. A process count cannot see work that is not a process.
# ⇒ Reuse the pane patterns rather than inventing a second opinion (§7x142: one source of truth).
def bg_agent_running():
    try:
        win = subprocess.run(['tmux','list-windows','-a','-F','#{window_id} #{window_name}'],
                             capture_output=True,text=True).stdout
        wid = next((l.split()[0] for l in win.splitlines() if l.split()[1:2] == [w]), None)
        if not wid:
            return False, True          # could not locate pane -> BLIND, not "no subagent"
        pane_full = subprocess.run(['tmux','capture-pane','-p','-t',wid],
                                   capture_output=True,text=True).stdout
        # ⛔⛔ 2026-08-24T20:24Z — capture-pane RETURNS SCROLLBACK. The line
        #   "Waiting for 1 background agent to finish" SURVIVES in the visible pane long after
        #   that agent finished, so matching anywhere in the capture reported a FINISHED agent as
        #   RUNNING — and that MASKED A REAL STALL for ~30 minutes on commonplace-merkle-crdt.
        # ⭐ I introduced this at 17:30 fixing the OPPOSITE bug (a codex count could not see an
        #   in-process subagent). The first fix missed real WORK; the fix for it missed real STALLS.
        #   ⇒ Both arms of one predicate, and I only ever tested the arm I had just been burned by.
        # ⇒ The live status region is the BOTTOM of the pane; scrollback cannot reach it. Match
        #   only there. A completed summary ("Cogitated for 15m 34s") sits above the prompt box.
        pane = "\n".join(pane_full.splitlines()[-7:])
        # ⚠️ pure-Python regex: re has NO POSIX classes. My first attempt used [[:space:]];
        #   python read it as a NESTED SET, warned, and printed NO VERDICT AT ALL for every
        #   worker — the detector was down until I noticed. A malformed pattern is not a
        #   narrower match, it is a DEAD INSTRUMENT.
        hit = re.search(r'Waiting for \d+ background agent|^\s*[\u25ef\u25cf]\s+\w.*\d+m ?\d*s ', pane, re.M|re.I)
        return bool(hit), False
    except Exception:
        return False, True
bg, bg_blind = bg_agent_running()
if bg:
    running = running + 1
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
    verdict = f"ended on text, but {running} unit(s) of work running FOR THIS WORKER (codex and/or background subagent) — legitimately waiting"
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
