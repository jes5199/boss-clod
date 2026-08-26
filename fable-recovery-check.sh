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
# Is the Fable-scoped weekly meter still exhausted, and which workers are affected?
#
# ⚠️ quota-guard.sh watches 5h and 7d ONLY. It does NOT watch the Fable scope, so
# a Fable wall is invisible to it -- which is how two workers ran ~24h on Opus
# while everyone believed they were on Fable (2026-08-22/23).
#
# ⭐ THE LOAD-BEARING PART OF THE STANDING DIRECTIVE IS SWITCHING BACK (jes
# 2026-07-06: "as long as we remember to switch back"). A remembered rule does
# not fire; this does.
#
# rc 0 = report printed   2 = instrument blind (no meter found / quota tool failed)

set -uo pipefail
Q=/home/jes/.local/bin/claude-quota

json=$("$Q" --json 2>/dev/null)
if [ -z "$json" ]; then
  echo "BLIND|claude-quota produced no JSON — instrument failure, NOT a clean 'Fable is fine'"
  exit 2
fi

# ⭐ POSITIVE CONTROL FIRST: a missing Fable entry and a healthy Fable meter look
# identical if we only test for "percent >= 100". Prove the entry EXISTS before
# believing anything it says. (Read the control before you believe the alarm.)
read -r found pct resets < <(printf '%s' "$json" | python3 -c '
import json,sys
d=json.load(sys.stdin)
for l in d.get("limits",[]):
    sc=(l.get("scope") or {}).get("model") or {}
    if (sc.get("display_name") or "").lower()=="fable":
        print(1, l.get("percent"), l.get("resets_at")); break
else:
    print(0, "-", "-")
')

if [ "$found" != "1" ]; then
  echo "BLIND|no weekly_scoped entry with scope.model.display_name=Fable in the quota payload"
  echo "BLIND|that is NOT evidence Fable is healthy — the shape may have changed. Fix this check."
  exit 2
fi

# Which running workers ASKED for Fable, and what are they actually on?
on_fable=""
affected=""
overridden=""
while read -r win name; do
  [ -z "$win" ] && continue
  p=$(tmux list-panes -t "$win" -F '#{pane_pid}' 2>/dev/null | head -1)
  [ -z "$p" ] && continue
  for c in $(pgrep -P "$p" 2>/dev/null); do
    cl=$(tr '\0' ' ' < "/proc/$c/cmdline" 2>/dev/null)
    case "$cl" in
      *claude*)
        live=$(tmux capture-pane -t "$win" -p 2>/dev/null | grep -o '\[[A-Za-z0-9. ]*\]' | tail -1)
        asked=$(printf '%s' "$cl" | grep -o -- '--model [a-z0-9-]*' | head -1)
        asked=${asked#--model }
        # ⛔ 2026-08-23: the ORIGINAL version matched only *--model*fable* in the
        # cmdline, and therefore MISSED commonplace entirely -- which carries NO
        # --model flag and was on Fable by SESSION STATE. It sat wedged with 10
        # inbound messages and 10 "reached your Fable 5 limit" errors, dropping
        # 100% of its traffic, invisible to this check.
        # ⭐ A LAUNCH FLAG IS WHAT WAS ASKED FOR; THE STATUSLINE IS WHAT IS
        # RUNNING. Key on the statusline -- the only source that reflects now.
        case "$live" in
          # ⛔⛔ 2026-08-24T14:28Z — THIS LABEL WAS WRITTEN FOR THE EXHAUSTED WORLD AND FIRED IN
          # THE RECOVERED ONE. Running Fable is WEDGED only while the meter is exhausted; once it
          # resets, a worker that asked for Fable and IS on Fable is exactly right, and calling it
          # "affected" tells me to restart two healthy workers for nothing.
          # ⭐ Second instance today of a check correct about the world it was written in. The
          # verdict has to be conditioned on the METER, not on the statusline alone.
          *Fable*)
            if [ "${pct%.*}" -ge 100 ]; then
              affected="${affected}${name}(asked=${asked:-none},RUNNING-FABLE-WHILE-EXHAUSTED=WEDGED) "
            else
              on_fable="${on_fable}${name} "
            fi ;;
          *) case "$asked" in
               *fable*)
                 # ⭐ 2026-08-26T21:26Z — A DELIBERATE SWITCH AND A SILENT FALLBACK SHARE THIS
                 # OBSERVABLE (asked=fable, running=other). The discriminator is NOT readable from
                 # the worker; it lives in .model-overrides, written by whoever made it deliberate.
                 # ⛔ Without it this check told me to ask jes to undo his own 20:39Z order.
                 _ovr=no
                 if [ -r "$(dirname "$0")/.model-overrides" ]; then
                   _ovr_out=$(grep -v '^#' "$(dirname "$0")/.model-overrides")
                   case "
$_ovr_out" in *"
${name}"*) _ovr=yes ;; esac
                 fi
                 if [ "$_ovr" = yes ]; then
                   overridden="${overridden}${name} "
                 else
                   affected="${affected}${name}(asked=$asked,running=${live:-?}) "
                 fi ;;
             esac ;;
        esac
        ;;
    esac
  done
done < <(tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}' 2>/dev/null)

# ⚠️ 2026-08-23: `claude-quota` can hit "HTTP Error 429: Too Many Requests" on the
# usage API and STILL PRINT NUMBERS -- identical across repeated calls, i.e. a
# cached value, with nothing marking it stale. A frozen cache would make the
# RECOVERED branch fire late or never, which is the one branch this loop exists
# for. ⭐ Cheap staleness gate: resets_at must be in the FUTURE. A cache frozen
# past the reset betrays itself here; a fresh read cannot fail it.
# ⛔⛔ 2026-08-24T10:09Z — THIS GATE BLINDED THE LOOP AT THE EXACT MOMENT IT EXISTS FOR.
# At the reset, the Fable entry goes percent=100 -> percent=0 AND resets_at -> null, because a
# meter at 0 has nothing left to reset. The staleness gate demanded a FUTURE resets_at, so the
# RECOVERED case — the one branch this loop was built to catch — reported BLIND instead.
# ⭐ A gate written for the exhausted state fired on the recovered state. Same family as a fence
# that refuses in the one place it is supposed to run.
# ⇒ A null resets_at is only suspicious WHEN THE METER IS NON-ZERO. At percent=0 it is EXPECTED,
# and the recovery is corroborated by the entry still being present and readable.
now_s=$(date -u +%s)
res_s=$(date -u -d "$resets" +%s 2>/dev/null || echo "")
if [ -z "$res_s" ] && [ "${pct%.*}" -eq 0 ]; then
  echo "FABLE|RECOVERED|percent=$pct|resets_at=none (expected at 0% — nothing left to reset)"
  echo "FABLE|already-on-fable=${on_fable:-none} (correct, NOT affected)"
  echo "FABLE|affected=${affected:-none}"
  [ -n "$overridden" ] && echo "FABLE|deliberate-opus=${overridden}(jes 2026-08-26T20:39Z \"we can go back to Opus now\" — NOT a fallback; see .model-overrides)"
  echo "FABLE|action=ask jes which to switch back; do NOT switch hermes without asking (live money)"
  exit 0
fi
if [ -z "$res_s" ]; then
  echo "BLIND|resets_at unparseable ('$resets') AT percent=$pct — a null reset is only expected at 0%"
  exit 2
fi
if [ "$res_s" -le "$now_s" ]; then
  echo "BLIND|resets_at $resets is in the PAST — this payload is stale (429 cache?), NOT a live reading"
  echo "BLIND|do not act on percent=$pct until a fresh read succeeds"
  exit 2
fi

if [ "${pct%.*}" -ge 100 ]; then
  echo "FABLE|EXHAUSTED|percent=$pct|resets_at=$resets"
  echo "FABLE|affected=${affected:-none — no running worker was launched asking for Fable}"
  echo "FABLE|action=none now; switch back AFTER $resets"
else
  echo "FABLE|RECOVERED|percent=$pct|resets_at=$resets"
  echo "FABLE|already-on-fable=${on_fable:-none} (correct, NOT affected)"
  echo "FABLE|affected=${affected:-none}"
  [ -n "$overridden" ] && echo "FABLE|deliberate-opus=${overridden}(jes 2026-08-26T20:39Z \"we can go back to Opus now\" — NOT a fallback; see .model-overrides)"
  echo "FABLE|action=SWITCH FABLE-INTENDED WORKERS BACK. A fresh 'workerclaude --model claude-fable-5'"
  echo "FABLE|       launch holds better than in-session /model, but costs context — weigh per worker."
fi
