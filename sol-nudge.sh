#!/bin/bash
# Sol feed check: should we dispatch another ticket to Sol (codex) right now?
#
# jes 2026-08-07: "this is working so let's do an hourly loop to feed work to sol"
#
# Prints NOTHING when no dispatch is warranted — boss-clod stays silent.
# Prints "SOL_NUDGE|<reason>" when commonplace should pick the next ticket
# and dispatch it to Sol.
#
# Every declined check prints WHY to stderr. A silent no-op and a broken
# script look identical otherwise — the failure mode this squad keeps hitting.
#
# Exit codes: 0 = checked (nudge or not), 2 = could not determine
#
# Deliberately does NOT dispatch: a shell script has no clod-squad access,
# and commonplace — not boss — picks the ticket and owns the review.
#
# ⭐ WHY THE CLAUDE-QUOTA GATE HERE IS DELIBERATELY LOOSE, unlike epic-nudge:
# Sol burns CODEX credits, which are a SEPARATE limit from Claude's. Dispatching
# Sol is the ANSWER to Claude quota pressure, not a casualty of it — gating this
# at epic-nudge's 0.85 would switch off the relief valve exactly when it is most
# useful. commonplace still needs Claude tokens to brief and review, so there IS
# a floor, but it sits near the STOP line rather than the slow-down line.

set -uo pipefail

# LIVENESS HEARTBEAT -- touched on EVERY run, including declines and errors.
# The three loops are CronCreate jobs: session-only, gone on restart. On
# 2026-08-08 only 1 of 3 was actually registered and nobody noticed for
# THREE DAYS, because a declining loop and an absent loop are both silent.
# LOOPS.md documented them, which did not help -- a file only works if
# someone reads it after a restart. This makes absence OBSERVABLE FROM DISK.
touch "${HEARTBEAT:-/home/jes/boss-clod/.heartbeat-sol-nudge}" 2>/dev/null || true


# ⛔ EXPIRED-BOUND SURFACER, 2026-08-10 — placed HERE, above every early exit,
# on purpose: a decline must not hide it. This loop is the only thing that runs
# every 10 min and whose stderr I actually read, which makes it the READER'S
# CLOCK — and today's lesson is that a freshness check belongs with the reader,
# never with the writer's promise.
# ⭐ WHY A FILE AND NOT A TIMER: commonplace armed a detached `sleep` for this
# same 03:00Z bound tonight and it was ALIVE BY ps AND USELESS — it fired into a
# log nobody reads, so the release would have expired in silence, which is the
# exact failure the bound exists to prevent. A timer also dies with its session.
# ⇒ The durable form is a file with a deadline, re-read by something that
# already runs. Verified by EFFECT (does the notice reach me?), not by existence.
BOUND="/home/jes/boss-clod/.deploy-bound"
if [ -f "$BOUND" ]; then
  DL=$(grep -oE '[0-9]{2}:[0-9]{2}Z REGARDLESS|RUNNING AT [0-9]{2}:[0-9]{2}Z' "$BOUND" 2>/dev/null | head -1)
  NOWHM=$(date -u +%H%M)
  # deadline is 03:00Z; compare as HHMM ints, and only inside the 03:00-11:00Z
  # band so this cannot scream all day about a bound someone forgot to delete.
  if [ "$NOWHM" -ge 0300 ] 2>/dev/null && [ "$NOWHM" -lt 1100 ] 2>/dev/null; then
    age_min=$(( ( $(date +%s) - $(stat -c %Y "$BOUND") ) / 60 ))
    echo "⛔ DEPLOY BOUND PAST ITS 03:00Z RELEASE — file written ${age_min}m ago ($DL)" >&2
    echo "   The hold was pre-authorised to release at 03:00Z. Check bin/cp-deploy-gap" >&2
    echo "   DIRECTLY — do not assume a restart happened. Delete $BOUND once confirmed." >&2
  fi
fi

# ⛔⛔ LISTENER AUDIT ON THE LIVE SERVE (CX-vvn4 / queue row B1, 2026-08-10).
# A serve relaunch dropped ELIXIR_ERL_OPTIONS and Erlang distribution came up
# on 0.0.0.0 — an RCE surface with a shared cookie, live ~90 seconds. It was
# invisible to every liveness check: HTTP 200 five for five, launch rc=0.
#
# ⭐ WHY IT LIVES HERE AND NOT IN THE DEPLOY SCRIPT: a gate in the deploy path
# only fires if whoever deploys runs it — a guard on a DELIBERATE ACT, which
# depends on memory. This loop runs every 10 min regardless of who deployed,
# whether they used the recipe, or whether they skipped the gate. ⇒ Worst case
# the exposure is caught within 10 minutes instead of never. It is DETECTION,
# not prevention, and is deliberately not a substitute for the recipe refusal
# (row B1's other half) — defence in depth, because the deploy path has more
# than one entrance.
#
# ⛔ SERVE RESOLVED BY IDENTITY (comm + cwd), NEVER BY BROAD PATTERN — hermes
# runs a live-money BEAM on this box and matches any naive beam.smp pattern.
SERVE_PID=$(for p in $(pgrep -x beam.smp 2>/dev/null); do
  [ "$(readlink "/proc/$p/cwd" 2>/dev/null)" = "/home/jes/commonplace" ] && echo "$p"
done | head -1)
if [ -n "${SERVE_PID:-}" ] && [ -x /home/jes/boss-clod/verify-serve-listen.sh ]; then
  AUDIT=$(/home/jes/boss-clod/verify-serve-listen.sh "$SERVE_PID" 5199 2>&1)
  ARC=$?
  # Silent when clean — this loop must not become noise. Loud on a finding,
  # AND loud on rc=2, because "could not look" is where this class hides.
  if [ "$ARC" != 0 ]; then
    echo "⛔⛔ LIVE SERVE LISTENER AUDIT FAILED (pid $SERVE_PID, rc=$ARC):" >&2
    printf '%s\n' "$AUDIT" >&2
    echo "   ⇒ If distribution is off-host this is an RCE surface. Kill by NUMERIC" >&2
    echo "     pid and relaunch with the FULL environ diffed against a clean" >&2
    echo "     baseline — never a curated grep (that is what caused CX-vvn4)." >&2
  fi
fi

WORKER="${WORKER:-commonplace}"
# ⭐⭐ 2026-08-11, jes: "I'm willing to burn extra Claude tokens to keep Sol warm."
# THIS RETIRES THE RATIO FLOOR FOR THE SOL LANE. The 1.60 floor existed for one
# reason: dispatching Sol costs ANTHROPIC tokens at the ends (commonplace writes
# the brief, reviews the artifact) even though the RUN itself spends codex
# credits from a SEPARATE pool. jes has now priced that trade explicitly — the
# brief+review spend is worth it to keep the Sol lane busy.
# ⚠️ Measured cost of the old floor, 2026-08-10: Sol sat IDLE ~5h (20:30→01:30)
# while this loop declined every cycle at 2.1–2.6x. The gate never touched Sol's
# capacity — commonplace's own dispatch bypasses it — so the floor slowed only
# the PROMPTING, which is exactly the part jes wants faster.
# ⛔ NOT REMOVED, RETIRED-IN-PLACE: SEVEN_DAY_STOP below is the real backstop and
# is untouched, so a nearly-spent week still halts Sol dispatch. Set RATIO_MAX in
# the environment to restore a ratio floor without editing this file.
# ⇒ Rollback: .sol-nudge.sh.bak-20260811T020441Z (RATIO_MAX=1.60).
# ⚠️ THIS DOES NOT TOUCH epic-nudge's 0.95 gate — jes ruled that one a thermostat
# working as designed on 2026-08-10 and it stays. Sol is the exception, by name.
RATIO_MAX="${RATIO_MAX:-99}"          # effectively off; SEVEN_DAY_STOP still guards
SEVEN_DAY_STOP="${SEVEN_DAY_STOP:-95}" # absolute: matches quota-guard's STOP
# ⛔ 2026-08-09: 30 -> 15, AND THE REASON IS THE WHOLE POINT — A COOLDOWN EQUAL
# TO THE CRON INTERVAL SILENTLY HALVES THE CADENCE.
# The marker is touched when the DISPATCH happens, which is always LATER than
# the tick that triggered it (script runtime + my turn). Measured: tick 13:13,
# marker 13:23 = 10 min late. So the next tick at 13:43 sees age = 30 - 10 = 20m,
# reads it as "dispatched 29m ago" against a 30m cooldown, and DECLINES.
# ⇒ Every other tick lost. jes asked for 30 minutes on 2026-08-08 and was
# getting 60 — observed declining at 29m TWICE today before anyone noticed.
# ⚠️ It never looks broken: each decline is individually correct and prints a
# sensible reason. The defect is only visible ACROSS runs, which is why a
# per-run log could never show it.
# ⇒ RULE: cooldown must be STRICTLY LESS than (cron interval − worst dispatch
# delay). 15 leaves 15 min of slack against a 30 min interval.
COOLDOWN_MIN="${COOLDOWN_MIN:-15}"   # jes 2026-08-08: 60 -> 30. The cron alone
                                     # cannot set the cadence — a 30m cron under a
                                     # 60m cooldown still fires hourly. Safe because
                                     # the busy-check declines while commonplace is
                                     # briefing, which is the case the cooldown was
                                     # really covering.
MARKER="${MARKER:-/home/jes/boss-clod/.sol-nudge-last}"
CREDIT_SENTINEL="${CREDIT_SENTINEL:-/home/jes/boss-clod/.sol-codex-exhausted}"

say() { echo "$*" >&2; }

# --- 1. codex credits exhausted? --------------------------------------
# jes 2026-08-07: "if codex starts running out of tokens, then stop".
# codex exposes no credit API (no usage table in state_5.sqlite), so this
# is a sentinel boss writes when a run reports exhaustion. Fails CLOSED on
# a stale sentinel by design: a human clearing it is cheaper than burning
# a quota we were told to protect.
if [ -f "$CREDIT_SENTINEL" ]; then
  say "DECLINED: codex credit sentinel set ($CREDIT_SENTINEL) — clear it to resume"
  exit 0
fi

# --- 1b. measurement hold -----------------------------------------------
# 2026-08-09: a Sol run is a LOAD EVENT, not just a token spend. commonplace
# took a wrong diagnosis today from exactly this — CommitHoistTest read as a
# regression when it was a 10s budget inside a 9.9-13.9s variance, and the
# load was boss's own Sol dispatch. When someone is running a timing- or
# contamination-sensitive measurement, dispatching Sol contaminates it.
# ⭐ A hold I have to REMEMBER is not installed (today's own lesson), so it
# is a file. Write it with a reason; delete it to resume.
# ⛔ AND IT MUST ANNOUNCE ITS OWN AGE (commonplace-plan, 2026-08-09): making
# forgetting-to-HOLD impossible does not make forgetting-to-RELEASE
# impossible, and the second failure is worse shaped because ITS SYMPTOM IS
# SILENCE — Sol stays held, nothing reports it, and a stalled queue looks
# exactly like "nothing was ready". A hold that cannot state its age is an
# rc=0 with empty output: correct, silent, and indistinguishable from fine.
HOLD="${HOLD:-/home/jes/boss-clod/.sol-hold}"
if [ -f "$HOLD" ]; then
  held_min=$(( ( $(date +%s) - $(stat -c %Y "$HOLD") ) / 60 ))
  say "DECLINED: measurement hold, HELD ${held_min}m — $(cat "$HOLD" 2>/dev/null || echo 'NO REASON GIVEN')"
  if [ "$held_min" -gt 90 ]; then
    say "  ⛔ HELD OVER 90m. Is that release condition still true? A stale hold"
    say "     stops dispatch silently and looks like an empty queue."
  fi
  say "  (clear with: rm $HOLD)"
  exit 0
fi

# --- 1b. STAND-DOWN, WITH AN EXPIRY (added 2026-08-18) ----------------
# ⭐ WHY THIS IS A FILE AND NOT A RESOLUTION. On 2026-08-18 commonplace answered
# the Sol board with a MECHANISM-CARRYING stand-down: it read plan's QUEUE.md
# receipts at HEAD and quoted them — "MINE IS EMPTY OF RANKED WORK" — so the
# board is empty by the queue's own evidence, not by anyone's impression. The
# correct response is to stop surfacing the pool until plan ranks something.
# ⛔ AND "I WILL REMEMBER TO STOP" IS EXACTLY THE KIND OF RULE THAT DID NOT FIRE
#   ALL NIGHT (see LESSONS 7w7). A stand-down that lives only in my head lasts
#   until my next context boundary and then silently ends.
#
# ⛔⛔ BUT A STAND-DOWN FILE THAT NOBODY CLEARS IS HOW A LOOP GOES QUIET FOR
# THIRTY-ONE HOURS — which happened here on 2026-08-16 and took a direct
# question from jes to notice. So this one EXPIRES.
# ⇒ ⭐ THE FAILURE DIRECTION IS CHOSEN DELIBERATELY: when the expiry is wrong we
#   ASK TOO EARLY (costs one message the worker can answer in one line) rather
#   than NEVER ASK AGAIN (costs the pool indefinitely, invisibly).
#
# Usage:  echo "$(( $(date +%s) + 4*3600 )) reason text" > .sol-standdown
#         rm .sol-standdown            # lift early, e.g. when plan ranks
STANDDOWN=".sol-standdown"
if [ -f "$STANDDOWN" ]; then
  SD_UNTIL=$(awk '{print $1}' "$STANDDOWN" 2>/dev/null)
  SD_WHY=$(cut -d' ' -f2- "$STANDDOWN" 2>/dev/null)
  case "$SD_UNTIL" in ''|*[!0-9]*) SD_UNTIL=0 ;; esac
  NOW_S=$(date +%s)
  if [ "$NOW_S" -lt "$SD_UNTIL" ]; then
    say "DECLINED: stand-down until $(date -u -d "@$SD_UNTIL" +%H:%MZ) — $SD_WHY"
    say "          (lift early with: rm $STANDDOWN)"
    exit 0
  else
    say "NOTE: stand-down EXPIRED at $(date -u -d "@$SD_UNTIL" +%H:%MZ) — asking again."
    say "      It expired rather than being lifted, so the question is live again:"
    say "      $SD_WHY"
    rm -f "$STANDDOWN"
  fi
fi

# --- 2. how many Sol runs are in flight? ------------------------------
# Exact-match the codex binary; never a broad pattern — hermes runs a
# live-money BEAM on this box.
#
# ⭐ 2026-08-16: this was `if [ -n "$INFLIGHT" ]` — DECLINE ON ANY RUN.
# jes: "we've been running Sol hourly for most of a week and never hit a
# codex quota… maybe we should consider having two in parallel?" ⇒ The
# serialization was MINE, one line, never a resource limit. Now a CAP.
#
# ⚠️ AND IT STAYS A WATCHED EXPERIMENT, NOT FREE CAPACITY: codex exposes no
# credit meter, and the exhaustion detector HAS NEVER BEEN SEEN TO FIRE — I
# grepped a week of logs for it and every hit was a test FILENAME. A gate
# never seen to fail is not known to work, and here the cost of blindness is
# discovering the ceiling by hitting it mid-round with a message neither
# boss nor commonplace would recognise. Keep the cap low; raise it on
# evidence, never on the absence of a complaint.
SOL_MAX_PARALLEL="${SOL_MAX_PARALLEL:-2}"
INFLIGHT=$(pgrep -f '(^|/)codex (exec|resume)' 2>/dev/null)
N_INFLIGHT=$(printf '%s\n' "$INFLIGHT" | grep -c '[0-9]')
if [ "$N_INFLIGHT" -ge "$SOL_MAX_PARALLEL" ]; then
  say "DECLINED: $N_INFLIGHT codex run(s) in flight, cap is $SOL_MAX_PARALLEL (pids: $(echo $INFLIGHT | tr '\n' ' '))"
  exit 0
fi
[ "$N_INFLIGHT" -gt 0 ] && say "NOTE: $N_INFLIGHT codex run(s) already in flight, cap $SOL_MAX_PARALLEL — dispatching alongside"

# --- 3. locate commonplace BY NAME, not by index ----------------------
WIN=$(tmux list-windows -t 0 -F '#{window_index} #{window_name}' 2>/dev/null \
      | awk -v n="$WORKER" '$2 == n {print $1; exit}')
if [ -z "$WIN" ]; then
  say "CANNOT DETERMINE: no tmux window named '$WORKER'"
  exit 2
fi

PANE=$(tmux capture-pane -p -t "0:$WIN" -S -10 2>/dev/null)
if [ -z "$PANE" ]; then
  say "CANNOT DETERMINE: captured no pane content for 0:$WIN"
  exit 2
fi

CMD=$(tmux list-panes -t "0:$WIN" -F '#{pane_current_command}' 2>/dev/null | head -1)
if [ "$CMD" != "claude" ]; then
  say "DECLINED: 0:$WIN is running '$CMD', not claude (crashed or exited?)"
  exit 0
fi

# --- 4. busy? use the SPINNER line, not "esc to interrupt" ------------
# ⛔⛔ 2026-08-09: THE "GENERATING" GATE NO LONGER BLOCKS A SOL DISPATCH, AND
# THE REASON IS THE PARALLEL SHAPE JES ASKED FOR.
# Under the old serial working shape, "commonplace is generating" meant "don't
# interrupt". Under Sol-and-Opus-in-parallel it means "commonplace is reviewing
# the OTHER builder" — which is the NORMAL state, not a busy signal. Declining
# on it starves Sol exactly when the fleet is working hardest, and Sol's
# credits are a separate pool that idling saves nothing.
# ⭐ A clod-squad message QUEUES; it does not interrupt a turn. commonplace
# reads it when it finishes reviewing, which is precisely when it can act.
# ⚠️ Duplicate dispatch is prevented by the COOLDOWN (marker touched at send)
# and the IN-FLIGHT check, not by this gate — so removing it costs no safety.
# ⛔ Still declined below: queued messages awaiting Enter, which IS a real
# stuck state rather than a working one.
# ⚠️ epic-nudge KEEPS its generating gate on purpose: that one asks commonplace
# to do work ITSELF, so stacking those up is noise. This one asks it to hand
# work to a different pool.
BUSY=$(printf '%s\n' "$PANE" | grep -oE '^[✻✽✢·✶*] [A-Za-z]+…* \([0-9]+[ms]' | tail -1)
if [ -n "$BUSY" ]; then
  say "NOTE: $WORKER is generating ($BUSY) — dispatching anyway; the message queues"
fi

# --- 4b. AN UNCONSUMED-BOARD BACKSTOP WAS BUILT HERE AND BACKED OUT ----
# ⛔⛔ 2026-08-18: I held a Sol dispatch by hand on the belief that three boards
# were "stacked unread" while commonplace generated for 55 minutes, and started
# to MECHANIZE that judgement here — a streak counter over consecutive
# dispatches-made-while-busy. Then I measured the premise and IT WAS FALSE:
# commonplace had replied at 01:07, 01:24, 02:04 and 02:08, consuming every
# board and proving the MUD mechanism by md5 in the middle of it.
# ⇒ ⭐ THE GATE WOULD HAVE FIRED ON CORRECT STATE — declining dispatch to the
#   worker having its best hour of the night. A gate that reds on known-good
#   input is worse than no gate, so this one does not ship.
# ⚠️ BOTH AVAILABLE PROXIES ARE MEASURED-BLIND, and that is the finding:
#   · tmux busy-ness  — was true the whole time WHILE it was consuming. A
#     worker that is generating may be generating ABOUT MY BOARD.
#   · clod-squad `delivered_at` — fills in ~2s on every message (checked:
#     12820/12823/12826 all delivered within 2s of send). It is a PUSH
#     receipt, not a READ receipt, and cannot distinguish the two states.
# ⇒ There is no read-signal available, so there is no honest gate to write.
#   The real signal is the one I used by hand: HAS THE WORKER SPOKEN SINCE MY
#   LAST BOARD (`messages where from_id=<worker> and id > <board id>`). That is
#   a query, not a proxy — if this ever needs mechanizing, mechanize THAT.

if printf '%s\n' "$PANE" | grep -q 'Press up to edit queued'; then
  say "DECLINED: $WORKER has queued messages awaiting Enter"
  exit 0
fi

# --- 5. cooldown ------------------------------------------------------
if [ -f "$MARKER" ]; then
  LAST=$(stat -c %Y "$MARKER" 2>/dev/null || echo 0)
  AGE_MIN=$(( ( $(date +%s) - LAST ) / 60 ))
  if [ "$AGE_MIN" -lt "$COOLDOWN_MIN" ]; then
    say "DECLINED: dispatched ${AGE_MIN}m ago, cooldown is ${COOLDOWN_MIN}m"
    exit 0
  fi
fi

# --- 6. Claude floor (brief + review only) ----------------------------
READ=$(/home/jes/.local/bin/claude-quota --json 2>/dev/null | python3 -c '
import sys, json
from datetime import datetime, timezone
try:
    d = json.load(sys.stdin)
except Exception:
    print("ERR"); raise SystemExit
now = datetime.now(timezone.utc).timestamp()
out = []
for key, hours in (("five_hour", 5), ("seven_day", 168)):
    w = d.get(key)
    # A window can be PRESENT with resets_at NULL -- observed 2026-08-09
    # 00:20Z, right after the 5h window rolled. fromisoformat(None) then
    # raises, the whole read prints nothing, and the guard returns
    # CANNOT DETERMINE -- so the loop STALLED every time a window turned
    # over. Skip such a window; the other one still gates.
    if not w or not w.get("resets_at"):
        continue
    r = datetime.fromisoformat(w["resets_at"]).timestamp()
    el = (now - (r - hours * 3600)) / (hours * 3600) * 100
    use = w["utilization"]
    ratio = (use / el) if el >= 2 else 0.0
    out.append(f"{key}:{use:.1f}:{el:.1f}:{ratio:.2f}")
print(" ".join(out) if out else "ERR")
' 2>/dev/null)

if [ -z "$READ" ] || [ "$READ" = "ERR" ]; then
  say "CANNOT DETERMINE: quota read failed"
  exit 2
fi

WORST=0
for f in $READ; do
  R=$(printf '%s' "$f" | cut -d: -f4)
  awk -v a="$R" -v b="$WORST" 'BEGIN{exit !(a>b)}' && WORST=$R
  # absolute 7d stop — a ratio can look fine late in a nearly-spent window
  case "$f" in
    seven_day:*)
      USE=$(printf '%s' "$f" | cut -d: -f2)
      if awk -v u="$USE" -v s="$SEVEN_DAY_STOP" 'BEGIN{exit !(u>=s)}'; then
        say "DECLINED: 7d utilisation ${USE}% >= ${SEVEN_DAY_STOP}% (STOP line)"
        exit 0
      fi
      ;;
  esac
done

if awk -v r="$WORST" -v m="$RATIO_MAX" 'BEGIN{exit !(r>=m)}'; then
  say "DECLINED: below brief+review floor — worst ratio ${WORST} >= ${RATIO_MAX} ($READ)"
  exit 0
fi

# --- 7. all checks passed --------------------------------------------
# ⛔ SAME DEFECT AS epic-nudge's, FIXED THE SAME WAY (2026-08-10). The marker
# records "GATE PASSED", not "DISPATCH SENT", and those diverge every time boss
# reads the output and decides not to send — including when boss runs this
# script purely to VERIFY it (e.g. confirming a hold actually blocks dispatch).
# ⚠️ Measured today: a post-hold verification run touched this marker and then
# suppressed the next 15 minutes on the strength of a dispatch that never
# happened. Checking a thing changed the thing.
# ⇒ DRY=1 evaluates every gate and commits no claim, so verification stops
# costing a slot and the file keeps saying something true.
# ⛔⛔ AND THE SAME DIVERGENCE HAPPENS ON A BOSS-HELD DISPATCH, WHICH THE COMMENT
# ABOVE DID NOT COVER (observed 2026-08-18 02:57Z). The gate passed, the marker
# was touched, and I then held the send by hand because commonplace had not yet
# spoken since the previous board. Fifteen minutes later the cooldown declined
# on the strength of a dispatch THAT NEVER HAPPENED.
# ⚠️ The harm is small — a hold that suppresses the next cycle DELAYS rather
#   than SKIPS — but the file is asserting something false, and this whole
#   script exists because false state in a marker is how a loop goes quiet.
# ⇒ ✅ THE HABIT, since the script cannot know my decision: run DRY=1 FIRST when
#   the outcome is in doubt, and run it for real ONLY in the same breath as
#   sending. "I ran it to see" and "I ran it to dispatch" must not be the same
#   invocation.
if [ "${DRY:-0}" = "1" ]; then
  echo "(DRY=1: gate passed, marker NOT touched — nothing has been claimed)" >&2
else
  touch "$MARKER"
fi
# ⛔ This string used to say "no run in flight" UNCONDITIONALLY, which was true
# only while the cap was 1. With a cap of 2 it would have asserted an absence
# that the very same script had just measured to be false — a status line that
# contradicts its own check is worse than no status line.
echo "SOL_NUDGE|idle, ${N_INFLIGHT} run(s) in flight (cap ${SOL_MAX_PARALLEL}), codex credits presumed ok | worst ratio ${WORST} < ${RATIO_MAX} | ${READ}"
exit 0
