#!/usr/bin/env bash
# §3 ACCEPTED-HEAD BACKFILL — the ceremony, as a script rather than as a memory.
#
# ⭐ WHY THIS IS A FILE: every step below was agreed in conversation, and a step agreed
# in conversation fires only if the person who agreed it is still holding it an hour
# later. The eight-step ceremony has already changed shape twice tonight (⑦ turned out
# to be a 214-commit deploy; ① turned out to need a fourth field). A script is the only
# version that survives being wrong about my own attention.
#
# ⛔ THIS SCRIPT STOPS THE LIVE :5199 SERVE. It is not idempotent and it is not a check.
# Run it deliberately, once, with the serve's environ already captured.
#
# Usage:  ./s3-backfill-run.sh <phase>
#   phase 1 = preflight  (READ-ONLY, safe to run any number of times)
#   phase 2 = stop serve + compile + backfill under the capped unit
#   phase 3 = relaunch serve + verify by effect
set -uo pipefail

SC="${SC:-/home/jes/boss-clod/logs/s3-run-$(date -u +%Y%m%dT%H%M%SZ)}"
CP=/home/jes/commonplace
UNIT="cp-backfill-$(date -u +%H%M%S)"
CEILING=6442450944          # 6 GiB, asserted BYTE-EXACT — `grep MemoryMax` passes on `infinity`
ADJ=900                     # must outrank hermes' live BEAM (200) so WE die first, not it
ENVIRON_BEFORE=/tmp/claude-1000/-home-jes-boss-clod/59f429ae-7ded-4956-8d9f-f171e388a49d/scratchpad/serve-environ-before.txt

mkdir -p "$SC"
say() { echo "[$(date -u +%H:%M:%SZ)] $*" | tee -a "$SC/run.log"; }
die() { echo "[$(date -u +%H:%M:%SZ)] ⛔ ABORT: $*" | tee -a "$SC/run.log"; exit 1; }

# ── the serve, resolved by IDENTITY, never by a bare cmdline substring ──────────────
# ⛔ comm must be beam.smp AND cmdline must contain commonplace_dev AND NOT hermes.
# A pattern that matches my own state-render probe is exactly how the deploy-gap
# monitor came to report a stranger's pid as "the serve" (LESSONS 7x26).
find_serve() {
  local d p comm c hits=""
  for d in /proc/[0-9]*; do
    p=${d#/proc/}
    comm=$(cat "$d/comm" 2>/dev/null) || continue
    [ "$comm" = "beam.smp" ] || continue
    c=$(tr '\0' ' ' < "$d/cmdline" 2>/dev/null) || continue
    case "$c" in *hermes*) continue ;; esac
    case "$c" in *commonplace_dev*) ;; *) continue ;; esac
    # ⭐ the discriminator that separates the SERVE from a `mix run` probe:
    # only the serve holds the listening socket. Identity, not resemblance.
    ss -ltnp 2>/dev/null | grep -q "pid=$p," || continue
    hits="$hits $p"
  done
  echo $hits
}

phase1() {
  say "───── PHASE 1: PREFLIGHT (read-only) ─────"

  local serve; serve=$(find_serve)
  [ -n "$serve" ] || die "no serve found holding :5199 — refusing to proceed on an absence I cannot explain"
  [ "$(echo $serve | wc -w)" = 1 ] || die "expected exactly 1 serve, found: $serve"
  say "serve pid = $serve (comm=beam.smp, cmdline has commonplace_dev, NOT hermes, HOLDS the :5199 socket)"
  echo "$serve" > "$SC/serve-pid-before"

  # ⭐ POSITIVE CONTROL for the identity check: hermes' BEAM must be VISIBLE to the
  # scan and must be REJECTED by it. A filter that finds nothing because it is blind
  # looks identical to a filter that correctly excluded everything.
  local hermes_seen=0
  for d in /proc/[0-9]*; do
    [ "$(cat "$d/comm" 2>/dev/null)" = "beam.smp" ] || continue
    case "$(tr '\0' ' ' < "$d/cmdline" 2>/dev/null)" in *hermes*) hermes_seen=1 ;; esac
  done
  [ "$hermes_seen" = 1 ] \
    && say "control ✅ hermes' BEAM was seen by the scan and excluded by the rule (the filter is not blind)" \
    || die "control ✗ the scan cannot see hermes' BEAM at all — the instrument is blind, not the box empty"

  say "environ capture (whole, unfiltered): $(wc -l < "$ENVIRON_BEFORE") vars"
  for v in PORT PHX_SERVER COMMONPLACE_DATA_DIR COMMONPLACE_LOCAL_WRITE_GATE COMMONPLACE_MUD_FULL_CITIZENSHIP; do
    grep -q "^$v=" "$ENVIRON_BEFORE" || die "mandatory var $v absent from the captured environ — do NOT relaunch from this capture"
  done
  say "all five mandatory launch vars present in the capture ✅"

  # ④ RE-READ AT RUN TIME, never inherited — paravel's point: this is the one
  # criterion whose value moves on its own between agreeing it and doing it.
  local avail; avail=$(free -m | awk '/^Mem:/{print $7}')
  say "available memory NOW = ${avail}MB (ceiling is $((CEILING/1024/1024))MB)"
  [ "$avail" -gt 6500 ] || say "⚠️ available (${avail}MB) is at or below the ceiling — a runaway takes essentially all headroom before its cap fires"

  # ⛔ USE `ps -o lstart`, NOT `stat /proc/<pid>`. The /proc directory's mtime is NOT the
  # process start time — it moves. Measured 2026-08-21: proc-mtime said Aug 18 23:06
  # (36 commits), true start was Aug 14 19:03 (214 commits). Under-reported by 178, and
  # AGAIN in the flattering direction — the same failure as the deploy-gap monitor in
  # LESSONS 7x26, written into this script three hours after filing that lesson.
  local started; started=$(ps -o lstart= -p "$serve")
  local gap; gap=$(cd $CP && git log --oneline --since="$started" | wc -l)
  say "serve started $started -> the relaunch will land $gap commits of main"
  [ "$gap" -gt 50 ] && say "⚠️ that is a LARGE deploy riding inside a maintenance ceremony — it is the biggest thing happening tonight, not a footnote"
  say "───── PREFLIGHT COMPLETE — nothing was changed ─────"
}

phase2() {
  say "───── PHASE 2: STOP + COMPILE + BACKFILL ─────"
  local serve; serve=$(cat "$SC/serve-pid-before" 2>/dev/null) || die "no preflight pid on file — run phase 1 first"
  kill -0 "$serve" 2>/dev/null || die "serve $serve is already gone — re-run preflight rather than guessing"

  say "SIGTERM -> $serve (numeric pid, never a pattern)"
  kill -TERM "$serve"
  for i in $(seq 1 60); do kill -0 "$serve" 2>/dev/null || break; sleep 1; done
  kill -0 "$serve" 2>/dev/null && die "serve $serve still alive after 60s — NOT escalating unasked"
  say "serve down ✅ (verified by the pid being gone, not by kill returning 0)"
  ss -ltn 2>/dev/null | grep -q ':5199 ' && die ":5199 still listening after the serve died — something else holds it"
  say ":5199 free ✅"

  # ⭐ compile AFTER the stop, deliberately against the recipe's "pre-build to minimise
  # downtime": the serve lazily loads from _build, so compiling under a live serve
  # hot-deploys into it. Downtime is cheap tonight (0 established connections);
  # an unplanned partial hot-load is not.
  say "compiling at $(cd $CP && git rev-parse --short HEAD) ..."
  (cd $CP && mix compile) > "$SC/compile.log" 2>&1 || die "compile failed — see $SC/compile.log (serve is DOWN, relaunch with phase 3 on old code if needed)"
  say "compile ok ✅"

  say "launching backfill unit $UNIT (ceiling $CEILING, oom adj $ADJ)"
  systemd-run --user --unit="$UNIT" \
    -p MemoryMax=$CEILING -p OOMScoreAdjust=$ADJ \
    --working-directory=$CP \
    --setenv=MIX_ENV=dev \
    --setenv=COMMONPLACE_DATA_DIR=$CP/workspace/.commonplace \
    mix commonplace.backfill_accepted_heads --unit="$UNIT" >> "$SC/run.log" 2>&1 \
    || die "systemd-run failed to launch"

  sleep 2
  local mp; mp=$(systemctl --user show "$UNIT" -p MainPID --value)
  [ -n "$mp" ] && [ "$mp" != 0 ] || die "unit has no MainPID — cannot verify the ceiling WHILE ACTIVE, and it is unverifiable afterwards"

  # ① THE QUAD, READ FROM THE KERNEL WHILE THE UNIT IS ALIVE.
  # ⛔ This is the only moment any of it is readable: systemd garbage-collects the
  # transient unit, after which a correctly-capped run that finished is BYTE-IDENTICAL
  # to a unit name that never existed. Not retryable, not checkable afterwards.
  {
    echo "unit=$UNIT pid=$mp at $(date -u +%FT%TZ)"
    echo "LoadState=$(systemctl --user show "$UNIT" -p LoadState --value)"
    echo "ActiveState=$(systemctl --user show "$UNIT" -p ActiveState --value)"
    echo "MemoryMax(systemd-reported)=$(systemctl --user show "$UNIT" -p MemoryMax --value)"
    echo "memory.max(cgroup-ENFORCED)=$(cat /sys/fs/cgroup"$(cut -d: -f3 /proc/$mp/cgroup)"/memory.max 2>/dev/null)"
    echo "oom_score_adj(kernel)=$(cat /proc/$mp/oom_score_adj 2>/dev/null)"
    echo "oom_score(kernel)=$(cat /proc/$mp/oom_score 2>/dev/null)"
  } | tee "$SC/quad.txt" | tee -a "$SC/run.log"

  grep -q "^memory.max(cgroup-ENFORCED)=$CEILING$" "$SC/quad.txt" \
    || die "the ENFORCED ceiling is not $CEILING — systemd's echo is not evidence (paravel: undelegated controller = perfect false green)"
  grep -q "^oom_score_adj(kernel)=$ADJ$"        "$SC/quad.txt" || die "oom_score_adj did not take — refusing to run tied with hermes' BEAM"
  grep -q "^LoadState=loaded$"                  "$SC/quad.txt" || die "unit not loaded"
  grep -q "^ActiveState=active$"                "$SC/quad.txt" || die "unit not active"
  say "① QUAD VERIFIED BY EFFECT ✅ (ceiling enforced in the cgroup, adj $ADJ in the kernel) — durable at $SC/quad.txt"

  say "backfill running; follow with: journalctl --user -u $UNIT -f"
  echo "$UNIT" > "$SC/unit-name"
}

phase3() {
  say "───── PHASE 3: RELAUNCH + VERIFY BY EFFECT ─────"
  ss -ltn 2>/dev/null | grep -q ':5199 ' && die ":5199 already listening — a serve is up; refusing to start a second"
  say "launching serve in a dedicated detached tmux window (persistent + log-observable)"
  tmux new-window -d -n cp-serve -c $CP
  tmux send-keys -t cp-serve "cd $CP && PORT=5199 PHX_SERVER=true \
COMMONPLACE_DATA_DIR=$CP/workspace/.commonplace \
COMMONPLACE_LOCAL_WRITE_GATE=enforce \
COMMONPLACE_MUD_FULL_CITIZENSHIP=true \
ERL_EPMD_ADDRESS=127.0.0.1 ERL_INETRC=/home/jes/boss-clod/erl_inetrc \
ELIXIR_ERL_OPTIONS=\"-kernel inet_dist_use_interface {127,0,0,1}\" \
elixir --sname commonplace_dev -S mix phx.server 2>&1 | tee -a /home/jes/boss-clod/logs/commonplace-serve.log" Enter
  say "⚠️ NOW: capture the WHOLE boot block to a file within minutes — the pane rotates in MINUTES under load, and a grep of it faithfully omits whatever you did not think to ask for."
  say "   tmux capture-pane -t cp-serve -p -S -3000 > $SC/boot.log"
  say "then: whole-environ DIFF old->new, posture block shows local_write_gate: :enforce, and a live MUD re-verify (take + movement) — HTTP 200 is NOT proof."
}

case "${1:-}" in
  1|preflight) phase1 ;;
  2|run)       phase2 ;;
  3|relaunch)  phase3 ;;
  *) echo "usage: $0 {1|2|3}   (1=preflight read-only, 2=stop+compile+backfill, 3=relaunch+verify)"; exit 64 ;;
esac
