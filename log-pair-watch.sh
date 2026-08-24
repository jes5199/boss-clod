#!/usr/bin/env bash

# ⛔ REFUSE UNKNOWN ARGUMENTS — exit 2 (BLIND), never a normal verdict.
# ⚠️ Found 2026-08-23: all four of these scripts SILENTLY IGNORED any argument and
# printed a healthy verdict. A typo'd flag or env var meant the script answered the
# NO-FLAG question correctly while the caller believed a different question was asked.
# ⭐ These take NO positional arguments. Overrides are ENV VARS and are named in the
# body; a mistyped env var still silently defaults, which is why the ones that matter
# are echoed in the output line rather than assumed.
if [ "$#" -gt 0 ]; then
  echo "BLIND|$(basename "$0") takes no arguments (got: $*) — overrides are env vars. NOT a verdict." >&2
  exit 2
fi
# Watch the two commonplace-log* worker panes and report state.
#
# jes, 2026-08-23: "check the two commonplace-logs claudes every 15 minutes to
# make sure they're still working (unless they finish or get stuck!)"
#
# ⭐ WHY THIS IS A SCRIPT AND NOT A REMEMBERED CHECKLIST: a filed artifact fires,
# a remembered rule does not. The stuck-detection needs state across invocations
# (a hash + a first-seen timestamp), which cannot live in a session's memory.
#
# ⛔ RESOLVE WINDOWS BY NAME, NEVER BY INDEX -- indices shift on every renumber.
# ⛔ NO pgrep -f / pkill -f ANYWHERE: the pattern would match this script itself.
#
# Exit codes:  0 = printed a report   2 = instrument blind (no tmux server / no windows)
# Prints one STATUS| line per worker plus a SUMMARY| line. Silence is never a result.

set -uo pipefail

WORKERS=(commonplace-log commonplace-log-reducer commonplace-merkle-crdt yepochs commonplace-doc)
WORKER_LIST=/home/jes/boss-clod/.watch-workers
# ⭐ ONE list, two scripts. If the file is missing or empty we KEEP the literal
# fallback below rather than silently watching nothing — an empty watch list is
# the one failure that reports perfect health forever.
if [ -r "$WORKER_LIST" ]; then
  mapfile -t _wl < <(grep -v '^#' "$WORKER_LIST" | grep -v '^[[:space:]]*$')
  [ "${#_wl[@]}" -gt 0 ] && WORKERS=("${_wl[@]}")
fi
STATE_DIR=/home/jes/boss-clod/.log-pair-watch
mkdir -p "$STATE_DIR"

# Minutes of byte-identical pane content before we call it stuck.
STUCK_MIN=${STUCK_MIN:-25}

# Workers finished by decision — see .watch-retired for why this exists.
RETIRED_FILE=/home/jes/boss-clod/.watch-retired
is_retired() { [ -r "$RETIRED_FILE" ] && grep -qE "^$1[[:space:]]" "$RETIRED_FILE"; }
retired_reason() { grep -E "^$1[[:space:]]" "$RETIRED_FILE" 2>/dev/null | head -1 | sed "s/^$1[[:space:]]*//"; }

# Workers waiting on a named external party — see .watch-blocked.
BLOCKED_FILE=/home/jes/boss-clod/.watch-blocked
is_blocked()   { [ -r "$BLOCKED_FILE" ] && grep -qE "^$1[[:space:]]" "$BLOCKED_FILE"; }
blocked_line() { grep -E "^$1[[:space:]]" "$BLOCKED_FILE" 2>/dev/null | head -1 | sed "s/^$1[[:space:]]*//"; }

now=$(date -u +%s)
nowiso=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if ! tmux list-windows -a >/dev/null 2>&1; then
  echo "BLIND|no tmux server reachable — this is an instrument failure, NOT a clean report"
  exit 2
fi

found=0
declare -a REPORT=()

for w in "${WORKERS[@]}"; do
  # ⛔ RESOLVE BY PROCESS IDENTITY FIRST, NAME ONLY AS A FALLBACK.
  #
  # ⚠️ 2026-08-23: window 0:17 was AUTO-RENAMED from "commonplace-log" to
  # "worker" (Claude Code emits a title escape derived from its cwd, and a
  # /compact moved it through a worktree). The name-only lookup then reported
  # MISSING -- which reads exactly like a CRASHED-and-gone worker. The session
  # was untouched, same pid 1443494.
  # ⭐ A WINDOW NAME IS A LABEL THE APP CAN REWRITE; THE --mcp-config PATH IS SET
  # AT LAUNCH AND NAMES THE WORKER. Resolve on the thing that cannot drift.
  target=""
  while read -r cand cname; do
    [ -z "$cand" ] && continue
    pp=$(tmux list-panes -t "$cand" -F '#{pane_pid}' 2>/dev/null | head -1)
    [ -z "$pp" ] && continue
    for cc in $(pgrep -P "$pp" 2>/dev/null); do
      if grep -qa "mcp-config-${w}\.json" "/proc/$cc/cmdline" 2>/dev/null; then
        target="$cand"; break 2
      fi
    done
  done < <(tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}' 2>/dev/null)

  # Fallback: exact window-name match (covers a worker not yet launched under a
  # per-project mcp-config, and keeps the check working if the flag shape changes).
  if [ -z "$target" ]; then
    target=$(tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}' 2>/dev/null \
             | awk -v n="$w" '$2 == n {print $1; exit}')
    [ -n "$target" ] && REPORT+=("NOTE|$w|resolved by window NAME, not process identity — check the launch flags")
  fi

  if [ -z "$target" ]; then
    REPORT+=("STATUS|$w|MISSING|no pane whose claude cmdline names mcp-config-${w}.json, and no window with that name — this worker is GONE, not merely renamed")
    continue
  fi
  found=$((found+1))

  cmd=$(tmux list-panes -t "$target" -F '#{pane_current_command}' 2>/dev/null | head -1)
  pane_raw=$(tmux capture-pane -t "$target" -p 2>/dev/null)
  # ⚠️ The prompt line ends in U+00A0 NON-BREAKING SPACE, not an ASCII space, so
  # under LANG=C.UTF-8 a `[[:space:]]*$` anchor does NOT match it. That is what
  # made window 0:17 fall through to UNKNOWN on the first fixed run. Normalise
  # NBSP -> space before any matching. (Found by cat -A on the captured line.)
  pane=$(printf '%s' "$pane_raw" | sed 's/\xc2\xa0/ /g')
  tail_txt=$(printf '%s' "$pane" | grep -v '^[[:space:]]*$' | tail -25)

  # --- change tracking (stuck detection) -------------------------------------
  h=$(printf '%s' "$pane_raw" | sha256sum | cut -c1-16)
  hf="$STATE_DIR/$w.hash"; tf="$STATE_DIR/$w.since"
  if [ -r "$hf" ] && [ "$(cat "$hf")" = "$h" ]; then
    since=$(cat "$tf" 2>/dev/null || echo "$now")
  else
    since=$now
    printf '%s' "$h" > "$hf"
  fi
  printf '%s' "$since" > "$tf"
  still_min=$(( (now - since) / 60 ))

  # --- classify. Order matters: hard faults before soft ones. ----------------
  #
  # ⛔ THE BUG THIS BLOCK WAS BORN WITH (2026-08-23, first run): the original
  # version tested only for "esc to interrupt" and fell through to IDLE. BOTH
  # workers were busy and BOTH were reported IDLE -- a false green, on a gate's
  # first run, in an environment unlike the one it was written against. See
  # LESSONS.md 7x75.
  # ⭐ THE FIX IS THE THREAD'S OWN ANSWER: "no pattern matched" and "genuinely
  # idle" must NOT share an observable. Unrecognised now reports UNKNOWN, and
  # IDLE is only claimed when an idle-prompt is POSITIVELY matched.
  state=""; detail=""
  busy=""
  # Busy signals, any one of which means work is in flight:
  #   spinner with elapsed time+tokens:  "* Jitterbugging… (2m 12s · ↓ 1.9k tokens)"
  #   backgrounded agents:               "Waiting for 1 background agent to finish"
  #   agent tray row with a duration:    "◯ general-purpose  Reading … 2m 18s · ↓ 47.4k"
  #   classic foreground hint:           "esc to interrupt"
  printf '%s' "$pane" | grep -qE '\([0-9]+m ?[0-9]*s ·|\([0-9]+s ·' && busy="${busy}spinner "
  printf '%s' "$pane" | grep -qiE 'Waiting for [0-9]+ background agent' && busy="${busy}bg-agent "
  printf '%s' "$pane" | grep -qE '^[[:space:]]*[◯●][[:space:]]+[a-z].*[0-9]+m ?[0-9]*s ·' && busy="${busy}agent-tray "
  printf '%s' "$pane" | grep -qi 'esc to interrupt' && busy="${busy}esc-hint "
  # ⚠️ 2026-08-24T16:43Z — ADDED, BUT ITS RED ARM HAS NEVER BEEN SEEN TO FIRE. Read this before
  #   trusting it. I believed commonplace-doc was reported IDLE while working, and patched on that.
  # ⛔ THE BELIEF WAS UNSOUND: the IDLE verdict was stamped 16:40:57Z; my "it's working" evidence
  #   was captured at 16:42, and the spinner then read "(1m 45s ...)" — i.e. that turn STARTED
  #   ~16:41:26Z, AFTER the verdict. The classifier was very likely RIGHT and something woke doc.
  #   ⇒ I compared a verdict to evidence from a LATER moment. A pane is a MOVING corpus; two
  #     separate captures cannot test one verdict. Freeze ONE frame and test that.
  #   ⇒ My own check compounded it: `grep -o` extracted the glyph+word and DISCARDED the
  #     "(1m 45s · ↓ tokens)" suffix, so a suffixed spinner LOOKED bare. The instrument I used to
  #     diagnose the gate removed the exact evidence that would have cleared it.
  # ✅ KEPT anyway on its own (weak) merits: a spinner's suffix appears only after ~1s and is
  #   truncated at narrow pane widths, so a bare frame is REACHABLE — but that is an ARGUMENT, not
  #   a MEASUREMENT. Green arm IS verified: 3 declared-STOPPED panes (0:19, 0:23, 0:3) stayed quiet.
  # ⇒ If you ever see "spinner-bare" WITHOUT "spinner" in a busy list, that is the first real
  #   sighting — record it here and this comment can be replaced with a fact.
printf '%s' "$pane" | grep -qE '[✻✽✳✢·*][[:space:]]+[A-Za-z]+…' && busy="${busy}spinner-bare "

  if [ "$cmd" = "bash" ] || [ "$cmd" = "sh" ]; then
    state=CRASHED; detail="pane is at a $cmd prompt, not claude — needs workerclaude relaunch"
  elif printf '%s' "$pane" | grep -qi 'rate-limit-options\|Stop and wait for reset'; then
    state=RATE_LIMITED; detail="sitting at the rate-limit prompt — send Enter to select stop-and-wait"
  elif printf '%s' "$pane" | grep -qi 'Press up to edit queued messages'; then
    state=QUEUED; detail="has queued messages waiting — send Enter"
  elif [ -n "$busy" ]; then
    if [ "$still_min" -ge "$STUCK_MIN" ]; then
      state=STUCK; detail="busy [$busy] but pane byte-identical for ${still_min}m (threshold ${STUCK_MIN}m)"
    else
      state=WORKING; detail="busy [$busy], pane changed within ${still_min}m"
      is_retired "$w" && detail="$detail ⚠️ marked RETIRED but is WORKING — remove it from .watch-retired"
      # ⭐ 2026-08-24T17:09Z — the RETIRED arm above has existed for a day; .declared-stopped had
      #   NO equivalent, so a STOPPED worker that resumed was silently reclassified WORKING and the
      #   stale suppression reasserted the moment it idled again. §7x142 is exactly this shape, and
      #   I filed that lesson while THIS half of it was still missing — the fix went to the file I
      #   had just been burned by, not to its twin.
      # ⛔ Both suppression files now warn. A suppression with no expiry is a gate held open.
      # ✅ RED ARM FIRED 2026-08-24T17:26Z, on TWO independent live subjects at once:
      #   commonplace-doc and commonplace-merkle-crdt both resumed (dir's D11 surfaced a seam gap)
      #   while still carrying .declared-stopped entries, and this warning printed for both.
      #   It was marked UNVERIFIED for 16 minutes because no worker was busy when I wrote it and I
      #   would not nudge a stopped agent to manufacture a subject. ⭐ The subject arrived on its own.
      # ⇒ Both arms now proven: RETIRED twin (long-standing) and this one. Do not re-mark unverified.
      grep -v '^#' /home/jes/boss-clod/.declared-stopped 2>/dev/null | grep -q "^${w}|" \
        && detail="$detail ⚠️ marked STOPPED but is WORKING — the .declared-stopped entry is stale; re-record it or remove it"
    fi
  elif printf '%s' "$pane" | grep -qE '^❯[[:space:]]*$|^[[:space:]]*❯[[:space:]]*$'; then
    # ⭐ ONE SOURCE OF TRUTH for "is this idle expected?". The detector owns the
    # declared-pause protocol (agent emits the literal token "nothing queued"); the
    # pane watch must not form its own opinion, or the two instruments disagree about
    # the same worker — which is exactly what happened at 08:53Z, one hour after I
    # wrote that they must not. ⇒ Ask the detector rather than re-deriving.
    # ⚠️ 2026-08-24T17:24Z — I changed this to capture stderr believing `2>/dev/null` had hidden a
    #   failing detector, because yepochs read RETIRED at 17:08 and PAUSED at 17:24 unchanged.
    # ⛔ THAT DIAGNOSIS WAS WRONG: the detector's stderr is EMPTY, so the redirect hid nothing and
    #   this change fixed nothing. The real cause was in turn-end-detector.sh — it counted codex
    #   processes GLOBALLY, so yepochs's verdict moved when commonplace-dir launched a round.
    #   Fixed there (attribution by -C worktree -> git-common-dir), not here.
    # ✅ Keeping the stderr capture anyway: it is equivalent when stderr is empty, and it makes a
    #   future detector failure VISIBLE instead of silently reading as "no declared pause".
    _ted=$(/home/jes/boss-clod/turn-end-detector.sh "$w" 2>&1 | head -1)
    if [ ! -x /home/jes/boss-clod/turn-end-detector.sh ]; then
      state=IDLE; detail="⚠️ turn-end-detector.sh NOT EXECUTABLE — pause protocol UNREADABLE, this is a blind instrument not a healthy worker"
    elif printf '%s' "$_ted" | grep -q 'DECLARED PAUSE'; then
      state=PAUSED; detail="agent DECLARED a pause ('nothing queued'); not a finding — quiet ${still_min}m"
    # ⛔ 2026-08-23T23:55Z — I taught .declared-stopped to stall-sweep.sh at 23:53Z and NOT to
    # this script, so two minutes later the two watchers disagreed about commonplace-doc again:
    # STOPPED there, IDLE here. ⚠️ That is commonplace-dir's 23:52Z lesson landing on me inside
    # the hour — fixing a defect in ONE instrument does not fix the reflex that built it, and the
    # second instrument is where you find that out.
    # ⭐ ONE record, BOTH consumers — the same rule this file already carries about the worker list.
    elif [ -r /home/jes/boss-clod/.declared-stopped ] \
         && grep -v '^#' /home/jes/boss-clod/.declared-stopped | grep -q "^${w}|"; then
      _rel=$(grep -v '^#' /home/jes/boss-clod/.declared-stopped | grep "^${w}|" | head -1 | cut -d'|' -f2)
      state=STOPPED; detail="declared stop, mechanism accepted — not a finding; release: ${_rel}"
    elif is_blocked "$w"; then
      bl=$(blocked_line "$w"); bts=${bl%% *}; brest=${bl#* }
      bage="?"
      bsec=$(date -u -d "$bts" +%s 2>/dev/null) && bage="$(( (now - bsec) / 60 ))m"
      # ⭐ The AGE is the point: a block that outlives its answer is idle-with-permission.
      state=BLOCKED; detail="waiting on $brest (blocked ${bage} ago); not a stall — REMOVE the .watch-blocked line when answered"
    elif is_retired "$w"; then
      # ⭐ Idle is the EXPECTED state here. Report it as such so it stops
      # generating findings — but keep printing it, because a silently dropped
      # worker is how a retirement becomes a blind spot.
      state=RETIRED; detail="idle BY DECISION — $(retired_reason "$w"); not a finding"
    else
      # ⭐ 2026-08-24T16:56Z — .awaiting-watcher was read by stall-sweep ONLY, so a worker
      #   legitimately waiting on a dispatched codex round read as plain IDLE here. The two
      #   loops then DISAGREED about the same worker: stall-sweep said "not stalled", this
      #   said "IDLE" — and the IDLE rule escalates on the second consecutive sighting.
      # ⛔ That is how a correctly-waiting agent gets nudged mid-round. Same file, same
      #   pid-conditional rule, so the two instruments answer the same question the same way.
      _aw=$(grep -E "^${w}\|" /home/jes/boss-clod/.awaiting-watcher 2>/dev/null | head -1)
      _awpid=$(printf '%s' "$_aw" | cut -d'|' -f2)
      if [ -n "$_awpid" ] && kill -0 "$_awpid" 2>/dev/null; then
        # ⭐ PID-CONDITIONAL, never on the file alone: a stale entry would mask a real stall
        #   forever, which is strictly worse than the nudge it prevents.
        state=WAITING; detail="armed watcher pid $_awpid ALIVE — waiting, not idle: $(printf '%s' "$_aw" | cut -d'|' -f3-)"
      elif [ -n "$_awpid" ]; then
        # ⚠️ FINISHED and DIED are indistinguishable from here — say so, do not pick one.
        state=IDLE; detail="⚠️ .awaiting-watcher names pid $_awpid which is GONE (finished or died — indistinguishable); ENTRY IS STALE, remove it. Treating as idle; quiet ${still_min}m"
      else
        state=IDLE; detail="idle prompt POSITIVELY matched, no busy signal — finished or awaiting input; quiet ${still_min}m"
      fi
    fi
  else
    # ⭐ The vacuous branch, made loud on purpose.
    state=UNKNOWN; detail="no known pattern matched — classifier may be blind to a new UI state; quiet ${still_min}m"
  fi

  # ⛔ 2026-08-23: the statusline is TRUNCATED AT PANE WIDTH. With a long project
  # name (commonplace_attribute_map, 64-col pane) it renders "📊 40…" -- no "%".
  # The old pattern required the % and yielded ctx=?, which NOTHING ACTED ON.
  # ⇒ A CONTEXT GATE THAT GOES BLIND EXACTLY WHEN THE PROJECT NAME IS LONG, and
  # announces it with a silent "?", is a check whose result changes nothing.
  # Now: accept the truncated form, mark it, and make a TOTAL failure LOUD.
  ctx=$(printf '%s' "$pane" | grep -o '📊 [0-9]\+%' | tail -1)
  ctx_trunc=""
  if [ -z "$ctx" ]; then
    ctx=$(printf '%s' "$pane" | grep -o '📊 [0-9]\+' | tail -1)
    [ -n "$ctx" ] && ctx_trunc="~"   # digits present but cut off before the %
  fi
  model=$(printf '%s' "$pane" | grep -o '\[[A-Za-z0-9. ]*\]' | tail -1)
  REPORT+=("STATUS|$w|$state|$detail|ctx=${ctx:-BLIND}${ctx_trunc}|model=${model:-?}|win=$target")

  # ⛔⛔ CONTEXT: THE COMPACT LEVER IS MINE, NOT THE WORKER'S.
  # A worker CANNOT run /compact -- it is a CLI/user command, not a tool in its
  # hand. Asking it to compact is asking for a thing it cannot do, and a worker
  # that banks durably and cannot compact looks EXACTLY like one that ignored
  # you. I have now made this mistake a FOURTH time (2026-08-18 x3, 2026-08-23),
  # despite the warning sitting at the top of the memory file. ⇒ Moving it to the
  # top of a file I might not open was not enough; it belongs HERE, in the output
  # of the thing that measures the number.
  ctx_n=${ctx//[^0-9]/}
  if [ -z "$ctx_n" ]; then
    # ⭐ Blind, and it says so. Never a silent "?" that no branch reads.
    REPORT+=("ACTION|$w|CONTEXT GATE BLIND — no 📊 figure parsed from the pane.")
    REPORT+=("ACTION|$w|  This is NOT 'context is fine'. Read the pane, or widen the window:")
    REPORT+=("ACTION|$w|  tmux resize-window -t $target -x 130   (statusline truncates at pane width)")
  elif [ "$ctx_n" -gt 70 ]; then
    REPORT+=("ACTION|$w|ctx ${ctx_n}% > 70 — DRIVE THE COMPACT YOURSELF VIA TMUX. Do NOT ask the worker.")
    REPORT+=("ACTION|$w|  ask it only for the DURABILITY PASS (state written where a successor will look)")
    REPORT+=("ACTION|$w|  tmux send-keys -t $target C-u; send-keys \"/compact\"; send-keys Enter")
    REPORT+=("ACTION|$w|  ⛔ NO Escape. MEASURED 2026-08-24T00:33Z: Escape CLEARS THE INPUT rather")
    REPORT+=("ACTION|$w|  than dismissing the suggestion menu — C-u+/compact+Escape+Enter left an")
    REPORT+=("ACTION|$w|  EMPTY prompt still at 75%, silently. With /compact typed the exact match")
    REPORT+=("ACTION|$w|  is highlighted and ONE Enter submits it.")
    REPORT+=("ACTION|$w|  ⭐ \"Press up to edit queued messages\" = SUCCESS mid-turn, not a stuck prompt.")
    REPORT+=("ACTION|$w|  then VERIFY BY EFFECT: ctx drops to ~0%. If the pane is mid-turn the")
    REPORT+=("ACTION|$w|  command QUEUES and runs when the turn ends — that is fine, keep watching.")
  fi
done

# ⭐ POSITIVE CONTROL: prove the corpus was non-empty before trusting any verdict.
# Zero windows found and two healthy-but-silent workers look identical otherwise.
if [ "$found" -eq 0 ]; then
  echo "BLIND|resolved 0 of ${#WORKERS[@]} worker windows by name — instrument blind, not a clean report"
  printf '%s\n' "${REPORT[@]}"
  exit 2
fi

printf '%s\n' "${REPORT[@]}"
# ⛔ 2026-08-23T23:26Z — I told several agents, and my own handoff notes, that this
# script "reads REPO-BOUNDARIES.md aloud every cycle". IT DID NOT. Zero references;
# the file's atime equalled its mtime, so nothing had opened it since it was written.
# ⭐ Caught by doc-sync's detector: list what you QUOTED today, then ask when you last
# OPENED it. Citation is an act of USE, and use is what confidence is built from — so
# the most-quoted document accrues the FEELING of being checked and zero actual reads.
# ⇒ The ledger is the thing new workers are handed, so its existence must FIRE rather
# than be remembered. One line, every cycle, naming the file and its live count.
_led=/home/jes/boss-clod/REPO-BOUNDARIES.md
if [ -r "$_led" ]; then
  _n=$(command grep -c '^### ' "$_led")
  # ⚠️ the count is asserted, not printed blind: 0 would mean the heading level moved
  # and the pointer had gone stale, which is the failure this line exists to prevent.
  if [ "$_n" -gt 0 ]; then
    echo "LEDGER|REPO-BOUNDARIES.md|$_n rulings|hand this to any new worker"
  else
    echo "LEDGER|BLIND|REPO-BOUNDARIES.md matched 0 '### ' headings — selector stale, NOT an empty ledger"
  fi
else
  echo "LEDGER|BLIND|REPO-BOUNDARIES.md unreadable at $_led"
fi
# ⛔⛔ 2026-08-24T00:23Z — REVERSE DIRECTION. commonplace-dir found its error gate computed
# declared-minus-produced and never produced-minus-declared, so an atom produced but never
# declared passed silently. ⭐ "A ⊆ B" and "B ⊆ A" are DIFFERENT CLAIMS and "the catalogue and
# the world agree" needs BOTH.
# ⇒ My watch had the identical shape: it asked "does every LISTED worker resolve?" and never
# "is every RUNNING worker LISTED?" — which is exactly how I dispatched commonplace at 00:15Z
# into a set that did not contain it and got examined=7|stalled=0 back.
# ⚠️ This REPORTS and does not enrol. Auto-enrolling would put hermes (live money) and halted
# agents under a nudge loop, which is a worse failure than the one it fixes.
_me=boss-clod
_unwatched=0
while read -r _r; do
  [ -z "$_r" ] && continue
  [ "$_r" = "$_me" ] && continue
  if ! grep -v '^#' "$WORKER_LIST" 2>/dev/null | grep -qx "$_r"; then
    _note=""
    grep -q "^${_r}[[:space:]]" /home/jes/boss-clod/.watch-halted 2>/dev/null && _note=" (HALTED — visible, not nudged)"
    [ "$_r" = "hermes" ] && _note=" (LIVE MONEY — deliberate: never auto-nudge)"
    echo "UNWATCHED|$_r|running but NOT in .watch-workers — no loop asks about it${_note}"
    _unwatched=$((_unwatched+1))
  fi
done < <(ps -eo args= | grep -oE 'mcp-config-[a-z0-9-]+\.json' | sed 's/mcp-config-//;s/\.json//' | sort -u)
# ⭐ the count is ASSERTED, not printed blind: 0 running workers means the PROBE failed, not that
# the fleet is empty — the same distinction the LEDGER line makes.
_runcount=$(ps -eo args= | grep -coE 'mcp-config-[a-z0-9-]+\.json')
if [ "$_runcount" -eq 0 ]; then
  echo "UNWATCHED|BLIND|found 0 running workers — probe failed, NOT an empty fleet"
else
  echo "COVERAGE|running=$_runcount|listed=${#WORKERS[@]}|unwatched=$_unwatched"
fi
echo "SUMMARY|$nowiso|resolved $found of ${#WORKERS[@]} windows|stuck_threshold=${STUCK_MIN}m"
