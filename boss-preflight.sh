#!/bin/bash
# boss-clod preflight — EXECUTES checks that were previously prose in LESSONS.md.
#
# ⭐ WHY THIS EXISTS (2026-08-15, plan's challenge): "a filed rule in PROSE is still
# a remembered rule; it becomes a check only when something EXECUTES it." LESSONS.md
# had ~19 entries that night and zero executable checks. The transferable question
# for a lesson is not "is it true?" but "WHAT WOULD EXECUTE THIS, AND IN WHICH HABITAT?"
#
# ⛔ THE LOOP-HEARTBEAT CHECK IS THE POINT. squad-alerts-poll.sh has written
# .heartbeat-* on every run since 2026-08-08 specifically so that a DEAD LOOP is
# observable from disk -- because on 2026-08-08 only 1 of 3 loops was actually
# registered and nobody noticed for THREE DAYS. A declining loop and an ABSENT loop
# are both silent. Nothing ever read those files. This reads them.
#
# ⛔ NEVER GREP A PATTERN THAT APPEARS IN THIS SCRIPT'S OWN DEFINITION (7p3) --
# the documentation-layer form of "never pgrep -f a pattern in your own command line".
# The canary below lives in its OWN file for exactly that reason.
#
# Exit 0 = all green. Exit 1 = at least one check RED. Exit 2 = instrument broken.
set -uo pipefail
cd /home/jes/boss-clod || { echo "PREFLIGHT: cannot cd to boss-clod"; exit 2; }

NOW=$(date -u +%s)
RED=0
CANARY_FILE=.preflight-canary
CANARY_TOKEN="boss-preflight-canary-do-not-remove"

say() { printf '%s\n' "$*"; }

# ── CONTROL FIRST: read the control BEFORE believing any alarm ────────────────
# A canary in its own file, whose ONLY job is to be found. Its ABSENCE is the
# alarm. Printed on EVERY run so the control is READ, not merely passed.
if [ -f "$CANARY_FILE" ] && grep -qF "$CANARY_TOKEN" "$CANARY_FILE" 2>/dev/null; then
  say "CONTROL  ok      canary found -- this instrument can still read files and match"
else
  say "CONTROL  BROKEN  canary MISSING from $CANARY_FILE"
  say "         ⇒ every green below is meaningless. Not reporting them."
  exit 2
fi

# ── 1. LOOP LIVENESS ─────────────────────────────────────────────────────────
# max_age_minutes per loop, from its actual cadence in LOOPS.md.
check_heartbeat() {
  # ⛔ Split deliberately: `local a="$1" f=".x-$a"` trips `set -u` here, and the
  # failure surfaced as a RED on known-good input -- the exact defect class this
  # script exists to catch. Caught only because the green arm was tested too.
  local name="$1"
  local max_min="$2"
  local f=".heartbeat-$name"
  if [ ! -f "$f" ]; then
    say "LOOP     RED     $name -- NO heartbeat file at all (never ran, or removed)"
    RED=1; return
  fi
  local mtime age_min
  mtime=$(stat -c %Y "$f" 2>/dev/null) || { say "LOOP     RED     $name -- unreadable"; RED=1; return; }
  age_min=$(( (NOW - mtime) / 60 ))
  if [ "$age_min" -gt "$max_min" ]; then
    say "LOOP     RED     $name -- ${age_min}m since last run (max ${max_min}m)"
    RED=1
  else
    say "LOOP     ok      $name -- ${age_min}m (max ${max_min}m)"
  fi
}
# ⛔⛔ THE SQUAD-ALERTS HEARTBEAT IS NO LONGER A LOOP-LIVENESS SIGNAL, BECAUSE I
# BROKE IT: when the loop died at 23:47 I began draining the queue MANUALLY, and
# squad-alerts-poll.sh touches the SAME heartbeat on every run. So a fresh
# heartbeat now means "the loop fired OR boss ran it by hand" -- the observer
# perturbing the instrument, which is the confound class this file is full of.
# ⇒ Manual runs append to .manual-poll-runs. If any manual run is newer than
#   45m, loop liveness is UNKNOWN and must be REPORTED AS UNKNOWN, never green:
#   an instrument that cannot distinguish two states must say so.
if [ -f .manual-poll-runs ]; then
  last_manual=$(tail -1 .manual-poll-runs 2>/dev/null || echo 0)
  case "$last_manual" in ''|*[!0-9]*) last_manual=0 ;; esac
  manual_age=$(( (NOW - last_manual) / 60 ))
else
  manual_age=99999
fi
if [ "$manual_age" -le 45 ]; then
  say "LOOP     UNKNOWN squad-alerts-poll -- heartbeat fresh but a MANUAL run ${manual_age}m ago"
  say "                 ⇒ cannot distinguish loop-fired from boss-ran-it. NOT green."
  RED=1
else
  check_heartbeat squad-alerts-poll 45
fi
check_heartbeat epic-nudge        60
check_heartbeat sol-nudge         60
check_heartbeat plan-nudge        600
check_heartbeat quota-guard       45
check_heartbeat state-render      100

# ── 2. ARMED ONE-SHOT CRONS still present ────────────────────────────────────
# A scheduled promise that quietly left the crontab is indistinguishable from
# one that has not fired yet.
if crontab -l 2>/dev/null | grep -q 'fable-switch-trigger.sh'; then
  say "ARMED    ok      fable-switch-trigger present (fires 2026-08-17 10:00Z)"
else
  if [ "$(date -u +%s)" -lt 1786960800 ]; then   # 2026-08-17T10:00Z
    say "ARMED    RED     fable-switch-trigger MISSING and its fire time has not passed"
    RED=1
  else
    say "ARMED    ok      fable-switch-trigger absent, fire time passed (self-disarmed)"
  fi
fi

# ── 3. UNPUSHED WORK — jes and successors read the remote, not my disk ───────
if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
  br=$(git rev-parse --abbrev-ref HEAD)
  if git rev-parse --verify -q "origin/$br" >/dev/null 2>&1; then
    n=$(git rev-list --count "origin/$br..HEAD" 2>/dev/null || echo 0)
    # ⛔⛔ THIS CHECK WAS CALIBRATED TO THE WRONG INVARIANT ON ITS FIRST RUN.
    # It said "unpushed == undelivered, go push" -- which is right for a PRIVATE
    # repo and DANGEROUSLY WRONG here: jes5199/boss-clod is PUBLIC, and LESSONS.md
    # carries unfixed security findings with file:line detail. A gate that nags
    # toward publishing those is worse than no gate. So: report the DIVERGENCE as
    # a fact, and make PUBLICNESS the thing that decides the verdict.
    vis=$(gh repo view jes5199/boss-clod --json visibility -q .visibility 2>/dev/null || echo UNKNOWN)
    if [ "${n:-0}" -gt 0 ]; then
      if [ "$vis" = "PUBLIC" ]; then
        say "PUSH     note    $n commit(s) unpushed on $br -- repo is PUBLIC."
        say "                 NOT a red. Publishing is jes's call, never mine."
      else
        say "PUSH     RED     $n commit(s) on $br not pushed (repo $vis)"
        RED=1
      fi
    else
      say "PUSH     ok      $br in sync with origin (repo $vis)"
    fi
  else
    say "PUSH     note    no origin/$br -- boss-clod branch is local-only, nothing to compare"
  fi
fi

# ── 4. MEMORY.md link integrity — a [[link]] to nothing is a silent dead end ──
MEMDIR=/home/jes/.claude/projects/-home-jes-boss-clod/memory
if [ -d "$MEMDIR" ]; then
  total=0; missing=0
  while IFS= read -r target; do
    total=$((total+1))
    [ -f "$MEMDIR/$target" ] || { missing=$((missing+1)); say "MEMORY   RED     MEMORY.md points at missing $target"; }
  done < <(grep -oE '\]\([a-z0-9_.-]+\.md\)' "$MEMDIR/MEMORY.md" 2>/dev/null | tr -d ']()')
  if [ "$total" -eq 0 ]; then
    say "MEMORY   RED     0 links parsed from MEMORY.md -- the PARSER is broken, not the index"
    RED=1
  elif [ "$missing" -gt 0 ]; then
    RED=1
  else
    say "MEMORY   ok      $total links, all resolve"
  fi
fi

[ "$RED" -eq 0 ] && say "PREFLIGHT: all green" || say "PREFLIGHT: RED -- see above"
exit "$RED"
