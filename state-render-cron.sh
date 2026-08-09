#!/bin/bash
# Renders commonplace's STATE.md + runs the tracker-truth scan.
#
# WHY: post-compact agents re-derive finished work from design docs because
# reading real state is expensive. STATE.md + the session-start hook make the
# cheap path and the true path the same act. See commonplace
# docs/plans/2026-08-07-state-projection-*.md.
#
# CADENCE CONSTANT LIVES HERE (interval) AND IN bin/state-render (trust window).
# The trust window is DERIVED from the observed render gap, so changing this
# interval needs no coordination — the next render observes the new gap and
# writes a proportional trust window. Owner: boss-clod.
# ⚠️ Above a ~2h interval the 6h cap binds and the stale banner starts firing
# between renders; past that, an interval change IS a coordination message.
#
# Render MEASURED at ~13.5 min at 828 tickets (2026-08-07, boss; the 8.5m
# first-sample figure was optimistic). Inner timeout 2400s = ~3x headroom. and scales LINEARLY with ticket count.
# 60m chosen for ~14% duty on a box that also runs hermes.
#
# Output is captured deliberately: a failed render leaves STATE.md untouched
# and the reader-side banner covers the reader — this log covers the operator.
# A cron that fails quietly for a week is the failure this whole system exists
# to prevent.

# ⚠️ CRON HAS A MINIMAL PATH — asdf shims are NOT on it, so `mix` is not found
# and the render exits 2 while the scan (which needs no mix) still succeeds.
# Observed live: 02:17 and 03:17 runs both "render exit=2 / scan exit=1" with
# STATE.md untouched since 01:45. The reader-side banner correctly reported
# stale the whole time — the writer side was simply not running. Caught by
# this script's own output capture, which is why the capture exists.
export PATH="$HOME/.asdf/shims:$HOME/.asdf/bin:/usr/local/bin:/usr/bin:/bin"
[ -f "$HOME/.asdf/asdf.sh" ] && . "$HOME/.asdf/asdf.sh" 2>/dev/null

# ⚠️ AND cron has no locale either: without this the BEAM runs latin1 name
# encoding and Elixir warns it "may malfunction". STATE.md is full of non-ASCII
# (the woven expiry line uses an em dash, and ticket titles carry arrows and
# quotes), so a latin1 render is a corruption risk, not a cosmetic warning.
export LANG=C.UTF-8 LC_ALL=C.UTF-8
export ELIXIR_ERL_OPTIONS="${ELIXIR_ERL_OPTIONS:+$ELIXIR_ERL_OPTIONS }+fnu"

LOG=/home/jes/boss-clod/logs/state-render.log
cd /home/jes/commonplace || { echo "$(date -u +%FT%TZ) FATAL: no /home/jes/commonplace" >> "$LOG"; exit 2; }

# ⛔⛔ 2026-08-09: THE OUTCOME MARKERS WERE BEING TRUNCATED AWAY BY THEIR OWN
# PAYLOAD. `bin/state-render` emits thousands of lines (every ticket, plus a
# full compile), and the `tail -n 2000` below then discards the oldest lines —
# which are exactly the `render start` and `render exit=N` markers wrapping it.
# ⇒ Result: this log contained ticket listings and compile noise and ZERO
# timestamped outcomes. There was NO WAY to tell whether any run had ever
# succeeded. A grep for the markers returns nothing, and that zero is real:
# the pattern was fine, the lines were gone.
# ⭐ Same class as squad-alerts-poll's bare `exit 0` — a cron whose failures
# leave no trace looks exactly like a cron that is working.
# ⇒ FIX: outcomes go to their OWN small log that volume cannot drown. The
# verbose log stays bounded as before, for detail.
OUTCOMES=/home/jes/boss-clod/logs/state-render-outcomes.log
touch /home/jes/boss-clod/.heartbeat-state-render 2>/dev/null || true

{
  echo "=== $(date -u +%FT%TZ) render start (PATH=$PATH) ==="
  timeout 2400 bin/state-render 2>&1; rc=$?
  echo "--- render exit=$rc"
  echo "=== $(date -u +%FT%TZ) scan start ==="
  timeout 300 bin/tix-truth-scan 2>&1; src=$?
  echo "--- scan exit=$src"
} >> "$LOG" 2>&1

# ⭐ The outcome line records rc AND the effect (STATE.md's mtime), because a
# zero exit is a claim about the program and the mtime is a claim about the
# world. timeout kills with 124 — worth seeing distinctly from a real failure.
STATE_MTIME=$(stat -c %y /home/jes/commonplace/STATE.md 2>/dev/null | cut -c1-19 || echo "MISSING")
printf '%s render_exit=%s scan_exit=%s STATE.md=%s\n' \
  "$(date -u +%FT%TZ)" "${rc:-?}" "${src:-?}" "$STATE_MTIME" >> "$OUTCOMES"
tail -n 500 "$OUTCOMES" > "$OUTCOMES.tmp" && mv "$OUTCOMES.tmp" "$OUTCOMES"

# keep the verbose log bounded
tail -n 2000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
