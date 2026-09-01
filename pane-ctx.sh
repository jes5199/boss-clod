#!/usr/bin/env bash
# ⭐ READ EACH WORKER'S CONTEXT % BY IDENTITY, AND NEVER LET AN ABSENT COLUMN READ AS HEALTHY.
#
# ⛔⛔ WHY THIS EXISTS (2026-09-01). My hourly health check reads context % from the statusline. For
# commonplace-biscuit the `📊` column DID NOT RENDER — a 43-character branch name
# (`r2b-p2e0-directory-resolve-issuer-vocabulary`) pushed it off a 64-column pane. ⚠️ A MISSING
# COLUMN AND A HEALTHY LOW NUMBER LOOK IDENTICAL TO A SCAN THAT ONLY COLLECTS WHAT IT FINDS: the
# worker simply does not appear in the "anything above 70%" list, which is exactly what a healthy
# worker also does.
# ⭐ I caught it that once by running a POSITIVE CONTROL — same-width panes elsewhere rendered `📊`
# fine, so the cause was the branch name and not the terminal. ⛔ But I caught it BY HAND, and a
# remembered rule does not fire. This script is the rule filed where the next reader trips over it.
#
# ⚠️ AND biscuit CORRECTED MY FRAMING, WHICH IS BUILT IN HERE: it has NO INSTRUMENT FOR ITS OWN
# CONTEXT % EITHER — the harness renders it into a statusline the session does not read. ⇒ The blank
# is UNMEASURED AT BOTH ENDS, not "boss cannot see biscuit's". A worker cannot supply this on request.
# ⛔ AND DO NOT SUBSTITUTE THE SESSION TOKEN BUDGET (~15M): different denominator — cumulative spend,
# not window occupancy. Reporting one as the other is the wrong-referent defect wearing a number.
#
# Usage:  pane-ctx.sh [worker ...]      (default: every pane whose cwd basename looks like a worker)
# Exit:   0 all workers readable · 1 at least one over threshold · 2 at least one UNREADABLE
THRESH="${CTX_THRESH:-70}"
mapfile -t PANES < <(tmux list-panes -a -F '#{pane_id} #{pane_current_path}' 2>/dev/null)
[ "${#PANES[@]}" -gt 0 ] || { echo "BLIND|tmux listed no panes — the instrument is dark, not the fleet"; exit 2; }
want=("$@")
rendered=0; unreadable=0; over=0; examined=0; skipped=0
for row in "${PANES[@]}"; do
  pid="${row%% *}"; path="${row#* }"; name="${path##*/}"
  case "$name" in ""|tmp|home|jes) continue;; esac
  if [ "${#want[@]}" -gt 0 ]; then
    hit=0; for w in "${want[@]}"; do [ "$w" = "$name" ] && hit=1; done
    [ "$hit" = 1 ] || continue
  fi
  # -J joins wrapped lines; the statusline is the last rendered row.
  cap=$(tmux capture-pane -p -J -t "$pid" 2>/dev/null)
  # ⛔⛔ ABSENCE HAS MORE THAN ONE CAUSE AND THEY SHARE THIS OBSERVABLE. First run of this script
  # reported 6/10 UNREADABLE — but squad-alerts, `wt` worktree shells and a bash pane HAVE NO CLAUDE
  # STATUSLINE AT ALL. "No claude here" and "claude here, column truncated" are different facts with
  # different remedies, and lumping them made the alarm useless by crying wolf on non-workers.
  # ⇒ `📁` is the claude-statusline marker. No 📁 = NOT A CLAUDE PANE (skipped, counted separately).
  #    📁 present but no 📊 = a real worker whose context is genuinely UNMEASURED.
  case "$cap" in *📁*) ;; *) skipped=$((skipped+1)); continue;; esac
  ctx=$(printf '%s' "$cap" | grep -oE '📊 [0-9]+%' | tail -1 | grep -oE '[0-9]+')
  br=$(printf '%s' "$cap" | grep -oE '🌿 [^|]*' | tail -1 | sed 's/^🌿 //;s/ *$//')
  examined=$((examined+1))
  if [ -z "$ctx" ]; then
    unreadable=$((unreadable+1))
    printf '%-26s %-8s UNREADABLE  ← column absent, NOT a low number. branch=%s\n' "$name" "$pid" "${br:-?}"
  else
    rendered=$((rendered+1))
    if [ "$ctx" -ge "$THRESH" ]; then over=$((over+1)); v="OVER $THRESH%"; else v="ok"; fi
    printf '%-26s %-8s %3s%%        %s\n' "$name" "$pid" "$ctx" "$v"
  fi
done
echo
[ "$skipped" -gt 0 ] && echo "(skipped $skipped pane(s) with no claude statusline — not workers, not unmeasured)"
[ "$examined" -gt 0 ] || { echo "BLIND|no worker panes matched — corpus empty, so a clean report here means nothing"; exit 2; }
# ⭐ THE POSITIVE CONTROL, WIRED IN RATHER THAN LEFT TO THE READER: if NOTHING rendered, the reader
# is blind (wrong capture, wrong statusline format) and no per-pane conclusion is available. If some
# rendered and others did not, the instrument works and those panes are genuinely missing the column.
if [ "$rendered" -eq 0 ]; then
  echo "BLIND|0 of $examined panes rendered 📊 — no positive control, so this is an INSTRUMENT failure, not a fleet fact"; exit 2
fi
if [ "$unreadable" -gt 0 ]; then
  echo "BLIND|$unreadable of $examined UNREADABLE (control: $rendered rendered, so the reader works) — those panes are UNMEASURED, not healthy"; exit 2
fi
if [ "$over" -gt 0 ]; then echo "OVER|$over of $examined at or above $THRESH% (control: $rendered rendered)"; exit 1; fi
echo "OK|$examined worker panes, all under $THRESH% (control: $rendered rendered)"
exit 0
