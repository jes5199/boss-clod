#!/usr/bin/env bash
# commonplace_dev serve launcher — deploy of 2026-08-12, target main @016db3b8
# (S25b + S26/CX-5983 + S27/CX-vddv bundle)
#
# ⛔ The env below is an ALLOWLIST, copied from the documented launch line, NOT
#    a strip-list built from what happened to be in the old environ. Both
#    directions of that bug are recorded in reference_mud_serve_deploy:
#    copying-forward misses what you didn't grep for; stripping misses what was
#    never there to see. The whole-environ diff old->new is what catches it.
#
# ANTHROPIC_API_KEY is DELIBERATE (the serve's agent paths need it) and is
# sourced here rather than pasted, so it never lands in a transcript or a file.
# LETTA_API_KEY and SQUAD_ALERTS_PUBLISHER_TOKEN are explicitly unset: both
# leaked into the serve on 2026-08-09 and LETTA_API_KEY is ambient in .bashrc.
#
# ⭐ NEW IN v5 — B1b PAID. The listener audit is no longer a check I run if I
#    remember; it is a PRE-FLIGHT REFUSAL plus a POST-BOOT WATCHDOG that kills
#    an exposed serve without me. Rationale is LESSONS 7av: a filed lesson does
#    not fire, a filed ARTIFACT does. CX-vvn4 was an Erlang distribution port
#    on 0.0.0.0 — a remote-code-execution surface — that HTTP 200 and rc=0 both
#    saw as perfectly healthy. Only the EFFECT on the listening sockets shows it.

set -euo pipefail

log() { echo "[launch5] $*" >&2; }

# --- REFUSAL 1: the API key must resolve non-empty -------------------------
ANTHROPIC_API_KEY="$(sed -n 's/^ANTHROPIC_API_KEY=//p' /home/jes/turingtest/.env | tr -d '"'"'"'"' | head -1)"
if [ -z "$ANTHROPIC_API_KEY" ]; then
  log "REFUSING TO LAUNCH: ANTHROPIC_API_KEY resolved empty from /home/jes/turingtest/.env"
  log "  (an empty key would boot a serve whose agent paths fail in a way HTTP 200 hides)"
  exit 1
fi
export ANTHROPIC_API_KEY

# --- REFUSAL 2: the loopback-dist config must EXIST and SAY SO -------------
# ⛔ Do not merely pass ERL_INETRC — verify the file it points at actually
#    binds to loopback. A missing or truncated inetrc is silently ignored by
#    the BEAM, and the result is CX-vvn4 all over again. "Not there" and
#    "not restricting" are the same observable from inside the launcher.
INETRC=/home/jes/boss-clod/erl_inetrc
if [ ! -s "$INETRC" ]; then
  log "REFUSING TO LAUNCH: $INETRC missing or empty — dist would not be pinned to loopback"
  exit 2
fi
if ! grep -q '127,0,0,1' "$INETRC"; then
  log "REFUSING TO LAUNCH: $INETRC does not pin 127.0.0.1 — refusing to boot an unpinned dist"
  log "  contents were: $(tr '\n' ' ' < "$INETRC")"
  exit 2
fi

# --- REFUSAL 3: don't double-boot onto a live port -------------------------
# A second serve on :5199 does not fail loudly; it fails by one of them losing
# the bind while the other keeps answering, which looks like a successful deploy.
if ss -ltn 2>/dev/null | grep -qE '[:.]5199 '; then
  log "REFUSING TO LAUNCH: something is already LISTENING on :5199."
  log "  Stop the existing serve first, by NUMERIC PID. Never a broad pattern kill —"
  log "  'beam.smp'/'mix'/'elixir' all match hermes, which trades live money."
  ss -ltnp 2>/dev/null | grep -E '[:.]5199 ' >&2
  exit 3
fi

# --- POST-BOOT WATCHDOG: audit the EFFECT, and act on it -------------------
# Backgrounded before exec so it survives the exec and needs no operator memory.
# It audits the sockets the serve ACTUALLY opened, not the flags we passed.
(
  sleep 60
  SPID="$(pgrep -f 'commonplace_dev' | head -1)"
  if [ -z "$SPID" ]; then
    log "WATCHDOG: no commonplace_dev process after 60s — nothing to audit"
    exit 0
  fi
  # Distribution sockets belonging to THIS pid that are bound to a wildcard.
  # :5199 is the intended public HTTP port and is excluded BY NUMBER.
  # ⛔ PARSE THE LOCAL-ADDRESS COLUMN ONLY (field 4). The peer column of a
  #    LISTEN row is ALWAYS "0.0.0.0:*", so a line-wide grep for 0.0.0.0
  #    matches EVERY listening socket including loopback-bound ones. That bug
  #    killed a healthy serve on 2026-08-12 — the gate was strictly worse than
  #    no gate, because it fired confidently on correct state. See LESSONS 7aw.
  EXPOSED="$(ss -ltnp 2>/dev/null \
    | grep "pid=$SPID," \
    | awk '{print $4"  "$0}' \
    | grep -E '^(0\.0\.0\.0|\[::\]|\*):' \
    | grep -vE '^[^ ]*[:.]5199 ' \
    | cut -d' ' -f3- || true)"
  if [ -n "$EXPOSED" ]; then
    log "⛔ WATCHDOG REFUSAL: serve pid $SPID opened a NON-5199 socket on a wildcard address."
    log "   This is the CX-vvn4 shape (Erlang distribution reachable off-box = RCE)."
    log "$EXPOSED"
    log "   KILLING pid $SPID by numeric pid. hermes is NOT touched."
    kill -TERM "$SPID" 2>/dev/null || true
    echo "$EXPOSED" > /home/jes/boss-clod/.serve-listener-refusal
    log "   Wrote /home/jes/boss-clod/.serve-listener-refusal"
  else
    log "✅ WATCHDOG: pid $SPID — no wildcard sockets besides :5199. Dist is loopback-only."
  fi
) &

cd /home/jes/commonplace

exec env -u LETTA_API_KEY -u SQUAD_ALERTS_PUBLISHER_TOKEN -u AI_AGENT \
  PORT=5199 \
  PHX_SERVER=true \
  COMMONPLACE_DATA_DIR=/home/jes/commonplace/workspace/.commonplace \
  COMMONPLACE_LOCAL_WRITE_GATE=enforce \
  COMMONPLACE_MUD_FULL_CITIZENSHIP=true \
  ERL_EPMD_ADDRESS=127.0.0.1 \
  ERL_INETRC="$INETRC" \
  ELIXIR_ERL_OPTIONS="-kernel inet_dist_use_interface {127,0,0,1}" \
  elixir --sname commonplace_dev -S mix phx.server
