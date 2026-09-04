#!/bin/bash
# Quota guard: checks burn rate and outputs SLOW_DOWN or OK
# Used by boss-clod to decide whether to broadcast a throttle message
#
# Exit codes:
#   0 = OK
#   1 = SLOW DOWN (any window projected to exhaust EARLY: burn ratio >= 1.05)
#   2 = STOP (7d >= 99%, hard backstop)

# ⛔ 2026-08-09: pipefail added. This script has SEVEN pipelines and its exit
# code IS its output — 0/1/2 decide whether boss broadcasts a throttle. Without
# pipefail a pipeline's status is the LAST command's, so a failing producer
# feeding a succeeding consumer reports success, and this guard would return
# "OK" from a computation that never ran. ⚠️ Note it is deliberately NOT `set
# -e`: this script must keep reaching its own explicit exit codes rather than
# dying partway, because a guard that exits early is indistinguishable from a
# guard that said OK.
set -o pipefail

JSON=$(/home/jes/.local/bin/claude-quota --json 2>/dev/null)
NOW=$(date -u +%s)

# Parse 5h window
FIVE_UTIL=$(echo "$JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['five_hour']['utilization'] if d['five_hour'] else 0)")
# resets_at goes null right after the 5h window rolls over, while five_hour
# itself stays a (truthy) dict — so guard on the timestamp, not the dict, or
# fromisoformat(None) raises. Only the informational burn ratio depends on this;
# the decision below is burn-ratio based and computes its own elapsed time.
FIVE_RESET=$(echo "$JSON" | python3 -c "
import sys, json
from datetime import datetime
d = json.load(sys.stdin)
r = (d.get('five_hour') or {}).get('resets_at')
print(int(datetime.fromisoformat(r).timestamp()) if isinstance(r, str) else 0)
")

# Parse 7d window
SEVEN_UTIL=$(echo "$JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['seven_day']['utilization'] if d['seven_day'] else 0)")

# Calculate 5h burn ratio
if [ "${FIVE_RESET:-0}" -gt 0 ]; then
  FIVE_START=$((FIVE_RESET - 18000))  # 5 hours = 18000 seconds
  ELAPSED=$((NOW - FIVE_START))
  TOTAL=18000
  if [ "$ELAPSED" -gt 0 ]; then
    # Use python for float math
    BURN=$(python3 -c "
u = $FIVE_UTIL
e = $ELAPSED / $TOTAL * 100
burn = u / e if e > 0 else 0
print(f'{burn:.2f}')
")
  else
    BURN="0.00"
  fi
else
  BURN="0.00"
fi

# ⛔ 2026-08-09, jes: "it competes with my keep-working threshold."
# THAT WAS THE REAL DEFECT, not the number. A guard keyed to HOW MUCH YOU HAVE
# USED will always fight "keep working", because late in a window high usage is
# the GOAL, not a warning. At 84% used / 89% elapsed the fleet is landing just
# under the ceiling exactly at reset — optimal — and the old rule had been
# firing since ~80%.
# ⇒ NEW RULE: fire on PROJECTED EXHAUSTION, i.e. sustained BURN RATIO
# (utilization / time-elapsed), not raw percentage. jes set the number: 1.05.
#   ratio >= 1.05  => SLOW_DOWN  (we would hit the wall EARLY and stop mid-work)
#   7d >= 99%      => STOP       (jes 2026-08-09: "no hard stop under 99%")
# ⭐ Finishing a window AT the limit is success. Only finishing it EARLY is a
# problem — that is the one this is allowed to interrupt work for.
# ⛔ ENV-OVERRIDABLE SO THE GREEN ARM CAN BE DEMONSTRATED. Found 2026-09-04: I 'proved' the OK
#   branch with `BURN_LIMIT=99 ./quota-guard.sh` and it printed SLOW_DOWN anyway, because this
#   line hard-set it. ⭐ MY GREEN ARM TESTED NOTHING AND LOOKED LIKE IT PASSED A CHECK.
#   The default is unchanged; only the ability to exercise the other branch is added.
BURN_LIMIT=${BURN_LIMIT:-1.05}
STOP_PCT=99

# ─────────────────────────────────────────────────────────────────────────────
# ⛔ SCOPED / ACTIVE LIMITS — added 2026-08-12 after this guard missed a
#    Fable-scoped weekly cap sitting at 90% CRITICAL while the two windows it
#    DID read showed 8% and 56%. The cap was in the same JSON response all day,
#    in a `limits` array this script never parsed.
#
# ⭐ THE LESSON (LESSONS 7ax, arriving in the quota reader): a check that reads
#    a MAINTAINED LIST OF NAMED FIELDS fails on the first field nobody listed —
#    silently, because an unparsed limit looks exactly like an absent one.
#    ⇒ So do NOT add 'seven_day_fable' to the window list. Read the API's OWN
#      severity/active flags, which cover limits that do not exist yet.
SCOPED=$(echo "$JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
out = []
for l in (d.get('limits') or []):
    pct = l.get('percent')
    if pct is None:
        continue
    sev    = (l.get('severity') or 'normal').lower()
    active = bool(l.get('is_active'))
    if sev in ('critical', 'warning') or active:
        sc = l.get('scope') or {}
        m  = ((sc.get('model') or {}).get('display_name')) or l.get('kind') or 'unknown'
        out.append('%s=%s%%:%s%s' % (m, pct, sev, ':ACTIVE' if active else ''))
print(' '.join(out))
" 2>/dev/null)

# Anything the API itself calls critical, or names as the binding limit, is a
# throttle signal regardless of which window it belongs to.
SCOPED_CRIT=$(echo "$JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
bad = [l for l in (d.get('limits') or [])
       if (l.get('percent') or 0) >= 90
       and ((l.get('severity') or '').lower() == 'critical' or l.get('is_active'))]
print(1 if bad else 0)
" 2>/dev/null)

# Highest-BURN window across all non-null windows (was: highest utilization).
read MAX_RATIO MAX_LABEL MAX_UTIL <<<"$(echo "$JSON" | python3 -c "
import sys, json, datetime as dt
d = json.load(sys.stdin)
now = dt.datetime.now(dt.timezone.utc)
windows = {'5h': ('five_hour', 5), '7d': ('seven_day', 168),
           '7d-opus': ('seven_day_opus', 168), '7d-sonnet': ('seven_day_sonnet', 168)}
best = (0.0, 'none', 0.0)
for label, (key, hours) in windows.items():
    w = d.get(key)
    # A window can be PRESENT with resets_at NULL, right after it rolls.
    if not w or w.get('utilization') is None or not w.get('resets_at'):
        continue
    reset = dt.datetime.fromisoformat(w['resets_at'])
    elapsed_pct = 100.0 * (now - (reset - dt.timedelta(hours=hours))).total_seconds() / (hours * 3600)
    if elapsed_pct <= 1:      # too early to be meaningful; a tiny denominator
        continue              # makes any usage look like a runaway burn
    u = float(w['utilization'])
    ratio = u / elapsed_pct
    if ratio > best[0]:
        best = (ratio, label, u)
print(f'{best[0]:.2f} {best[1]} {best[2]:.0f}')
")"


# ⛔⛔ 2026-08-10: FAIL CLOSED, NOT OPEN — observed once, live, at 20:22Z.
# `claude-quota --json` returned unparseable output. json.load raised, so the
# read got an empty line, so MAX_RATIO/MAX_LABEL/MAX_UTIL were all EMPTY, so
# `print(1 if  >= 1.05 else 0)` was a SyntaxError, so OVER was empty, so the
# `[ "$OVER" = "1" ]` test was false — and control fell through to the else
# branch, which printed:
#     OK|worst  x (limit 1.05) — 5h=% 7d=%
# and exited 0. ⚠️ THE GUARD REPORTED *OK* BECAUSE IT COULD NOT MEASURE. The
# cron log records `rc=0 OK|...`, which is byte-comparable to a healthy run, so
# an API outage would read as "burn is fine" for as long as it lasted — and the
# empty fields are the ONLY tell, in a line nobody reads when it says OK.
# ⭐ Same family as this repo's squad-alerts bare-`exit 0`, fixed 2026-08-09:
# A BROKEN CHECK MUST NOT BE ABLE TO EMIT THE REASSURING ANSWER. "I measured and
# you are fine" and "I could not measure" must never share an exit code.
# ⇒ rc=3 GUARD_BROKEN is neither OK(0), SLOW_DOWN(1) nor STOP(2): callers that
# treat nonzero as "do not dispatch" now fail safe by default.
case "$MAX_RATIO" in
  ''|*[!0-9.]*)
    echo "GUARD_BROKEN|quota JSON unparseable — ratio='$MAX_RATIO' label='$MAX_LABEL' util='$MAX_UTIL'"
    echo "  This is NOT 'OK'. No throttle decision was made this run."
    exit 3 ;;
esac
if [ "$MAX_LABEL" = "none" ]; then
  echo "GUARD_BROKEN|no usable window (all null, or every window <1% elapsed)"
  echo "  This is NOT 'OK'. No throttle decision was made this run."
  exit 3
fi
case "$SEVEN_UTIL" in
  ''|*[!0-9.]*)
    echo "GUARD_BROKEN|7d utilization unparseable: '$SEVEN_UTIL'"
    echo "  This is NOT 'OK'. No throttle decision was made this run."
    exit 3 ;;
esac

# Decision logic
SEVEN_INT=$(python3 -c "print(int($SEVEN_UTIL))")

OVER=$(python3 -c "print(1 if $MAX_RATIO >= $BURN_LIMIT else 0)")

# ⛔ A scoped cap only THROTTLES if the fleet actually runs that model.
# Fable sat at 92% critical/ACTIVE after every agent moved to Opus — firing on
# that would have paused the loops for 4.5 days over a model nobody uses.
# ⇒ The API knows the cap; only .fleet-models knows whether it BINDS US.
SCOPED_BINDS=0
if [ "$SCOPED_CRIT" = "1" ] && [ -s /home/jes/boss-clod/.fleet-models ]; then
  for m in $(echo "$SCOPED" | tr ' ' '\n' | cut -d= -f1); do
    grep -qiFx "$m" /home/jes/boss-clod/.fleet-models && SCOPED_BINDS=1
  done
fi

# ⭐ 2026-08-31 — CODEX/SOL ADMISSION. The fleet is majority-Sol, and this guard was
# Claude-only: it returned OK while having measured nothing about the species most of the
# workers actually run on. ⛔ A guard blind to half the fleet reports the same word as a
# healthy one. sol-usage.sh emits QUOTA|scope=..|window=..|used_percent=..|reset_after=..
# on stdout and exits 2 with BLIND| when it cannot measure.
# ⚠️ rc=2 is NOT "Sol is fine" — it is no information, and per our standing rule a blind
# instrument means unavailable capacity, so it degrades the verdict rather than being ignored.
SOL_OUT=""; SOL_RC=0
if [ -x /home/jes/boss-clod/sol-usage.sh ]; then
  SOL_OUT=$(/home/jes/boss-clod/sol-usage.sh --machine 2>/dev/null); SOL_RC=$?
else
  SOL_RC=2
fi
SOL_VERDICT="ok"; SOL_NOTE=""
if [ "$SOL_RC" != "0" ]; then
  SOL_VERDICT="blind"; SOL_NOTE="codex=BLIND(rc=$SOL_RC)"
else
  SOL_WORST=$(printf '%s\n' "$SOL_OUT" | awk -F'used_percent=' 'NF>1{split($2,a,"|"); if (a[1]+0>m) {m=a[1]+0; w=$0}} END{print m+0}')
  SOL_WORST_LBL=$(printf '%s\n' "$SOL_OUT" | awk -F'used_percent=' 'NF>1{split($2,a,"|"); if (a[1]+0>=m) {m=a[1]+0; split($1,b,"scope="); split(b[2],c,"|"); l=c[1]}} END{print l}')
  SOL_NOTE="codex worst ${SOL_WORST_LBL}=${SOL_WORST}%"
  if [ "${SOL_WORST:-0}" -ge "$STOP_PCT" ]; then SOL_VERDICT="stop"
  elif [ "${SOL_WORST:-0}" -ge 90 ]; then SOL_VERDICT="slow"; fi
fi

# ⭐⭐ DISPATCH CONSEQUENCE, AUTHORIZED BY jes 2026-09-04T01:44:50Z ("sounds good to me") ON THE RULE
#   HE PROPOSED AT 01:42:59Z: "we should switch to Sol workers when the quota gets above some threshold."
#   ⇒ THE THRESHOLD IS THIS GUARD'S OWN VERDICT, not a second number nobody maintains: SLOW_DOWN or STOP
#     ⇒ NEW ROUNDS GO TO SOL. Claude doors finish IN-FLIGHT work only. Reverses on rc 0.
# ⛔ WHY IT IS PRINTED HERE AND NOT REMEMBERED: a remembered rule does not fire. This session has paid
#   for that four separate times tonight. The consequence rides on the measurement that triggers it.
# ⚠️ AND THE TWO BOUNDS GO WITH IT EVERY TIME, because a capacity number without them reads as free
#   capacity: (1) SOL IS NOT A DROP-IN — its demonstrated strength is orchestrated implementation
#   against a written spec WITH A CLAUDE DOOR REVIEWING; the verification discipline (pre-registered
#   arms, seen reds, controls in the same command) is carried by the Claude doors and is NOT known to
#   hold unsupervised. (2) CODEX IS METERED AND COSTS MONEY WHERE CLAUDE DOES NOT.
_dispatch_line() {
  printf 'DISPATCH|new rounds -> SOL; Claude doors finish IN-FLIGHT only (jes 2026-09-04T01:44:50Z). Reverses on rc 0. Sol implements + a Claude door reviews; Codex is metered.\n'
  # ⛔⛔ CARVE-OUT, hermes 2026-09-04T01:47Z, BEFORE it was ever load-bearing:
  #   A REVIEWER'S APPROVAL IS NOT A SUBSTITUTE FOR AN OWNER'S AUTHORIZATION.
  #   "Sol implements + a Claude door reviews" is sufficient for ordinary repos and NOT for
  #   hermes's live-money paths — order placement, sizing, capital limits, arming flags — which
  #   need jes's OWN WORD PER CHANGE, cited to a message with a timestamp. Five changes there in
  #   two days each trace to a verbatim quote; THAT CHAIN IS THE ARTIFACT, and an implementer
  #   that cannot produce it should not be editing lib/hermes/jobs/ or lib/hermes/trading/.
  # ⭐⭐ ROUTING TEST, chit 2026-09-04T01:47Z — NOT "is it small" and NOT "is there a spec":
  #   WHAT IS THE DELIVERABLE MADE OF?
  #   ✅ GOOD Sol candidate: the deliverable is CODE against a spec, and the arms CHECK it.
  #   ⛔ WORST Sol candidate: the deliverable IS THE ARM — because the part being delegated is
  #     then exactly the part bound ① says does not transfer unsupervised.
  #   ⚠️ A round whose remaining work is "a test that must be SEEN RED on a mutation a real
  #     defect would produce" tests the transfer at its weakest point AND is worth almost
  #     nothing if it succeeds. Send code-shaped rounds first.
  printf 'DISPATCH-TEST|route by WHAT THE DELIVERABLE IS MADE OF: code-against-a-spec -> Sol (arms check it). If the deliverable IS the arm, keep it on a Claude door -- that is the part bound (1) says does not transfer.\n'
  printf 'DISPATCH-EXCEPT|hermes live-money paths (lib/hermes/jobs/, lib/hermes/trading/) are NOT routable to any implementer: they need jes'"'"'s own word PER CHANGE, cited. A review does not substitute for an authorization.\n'
}

if [ "$SOL_VERDICT" = "stop" ]; then
  echo "STOP|${SOL_NOTE} — Codex weekly at or over ${STOP_PCT}%, hard backstop${SCOPED:+ | scoped: $SCOPED}"
  # ⛔ NOT here: the Codex side is the one exhausted, so routing TO Sol is the wrong remedy.
  exit 2
elif [ "$SOL_VERDICT" = "slow" ]; then
  echo "SLOW_DOWN|${SOL_NOTE} — Codex window >=90%, the fleet is majority-Sol"
  # ⛔ NOT here either, and for the same reason: this verdict is ABOUT Sol being short.
  exit 1
elif [ "$SOL_VERDICT" = "blind" ]; then
  echo "GUARD_BROKEN|${SOL_NOTE} — Codex side unmeasured; treat as unavailable capacity, not as healthy"
  exit 3
fi

if [ "$SCOPED_BINDS" = "1" ]; then
  echo "SLOW_DOWN|scoped limit critical AND IN USE by the fleet: ${SCOPED} — binding cap is not the all-models weekly"
  _dispatch_line
  exit 1
elif [ "$SEVEN_INT" -ge "$STOP_PCT" ]; then
  echo "STOP|7d at ${SEVEN_UTIL}% — over ${STOP_PCT}%, hard backstop"
  _dispatch_line
  exit 2
elif [ "$OVER" = "1" ]; then
  echo "SLOW_DOWN|${MAX_LABEL} burning ${MAX_RATIO}x (>= ${BURN_LIMIT}) at ${MAX_UTIL}% used — would exhaust EARLY"
  _dispatch_line
  exit 1
else
  echo "OK|worst ${MAX_LABEL} ${MAX_RATIO}x (limit ${BURN_LIMIT}) — 5h=${FIVE_UTIL}% 7d=${SEVEN_UTIL}%${SCOPED:+ | scoped: $SCOPED} | ${SOL_NOTE}"
  exit 0
fi
