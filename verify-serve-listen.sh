#!/bin/bash
# Post-deploy listener audit — does this BEAM expose anything off-host that it shouldn't?
#
# ⛔ WHY THIS EXISTS (CX-vvn4, 2026-08-10 02:40Z): a serve relaunch dropped
# ELIXIR_ERL_OPTIONS and Erlang distribution came up on 0.0.0.0 instead of
# loopback. Distribution reachable off-host + a shared cookie is a REMOTE CODE
# EXECUTION surface. It was live ~90 seconds.
#
# ⭐⭐ THE DESIGN POINT — THIS CHECKS THE EFFECT, NOT THE MECHANISM.
# The obvious guard is "assert ELIXIR_ERL_OPTIONS is present". That is the
# WRONG check: it names the one cause we happen to have seen. The env var is a
# MECHANISM; the exposure is an EFFECT, and other mechanisms reach the same
# effect (a changed vm.args, an erl_inetrc edit, a different launcher, someone
# adding -name without the pin). ⇒ Assert the property that must hold — NOTHING
# LISTENS OFF-HOST EXCEPT WHAT IS EXPLICITLY ALLOWED — and every mechanism that
# breaks it is caught by one check.
#
# ⛔ AND IT EXISTS BECAUSE EVERY LIVENESS CHECK PASSED WHILE THE HOLE WAS OPEN:
# the bad process answered HTTP 200 five times out of five and its launch
# returned rc=0. A working service with a silently widened attack surface is
# indistinguishable from a correct one by any check that asks "is it up?".
#
# Usage:  verify-serve-listen.sh <pid> [allowed_public_port ...]
#         verify-serve-listen.sh 2551162 5199
#
# Exit: 0 = clean · 1 = FINDING (something exposed) · 2 = could not determine
#       ⚠️ 2 is NOT a pass. "Could not look" and "looked and it was fine" are
#       different answers and must never share an exit code.

set -uo pipefail

PID="${1:-}"
shift || true
ALLOWED=("$@")

if [ -z "$PID" ]; then
  echo "usage: $0 <pid> [allowed_public_port ...]" >&2
  exit 2
fi

if ! [ -d "/proc/$PID" ]; then
  echo "CANNOT DETERMINE: no process $PID" >&2
  exit 2
fi

# Resolve identity before reporting on it — a recycled pid would otherwise be
# audited as if it were the serve.
COMM=$(cat "/proc/$PID/comm" 2>/dev/null || echo "?")
CWD=$(readlink "/proc/$PID/cwd" 2>/dev/null || echo "?")
echo "AUDITING pid $PID  comm=$COMM  cwd=$CWD"

LISTEN=$(ss -ltnp 2>/dev/null | grep "pid=$PID,")
if [ -z "$LISTEN" ]; then
  echo "CANNOT DETERMINE: ss returned no listening sockets for pid $PID" >&2
  echo "  (it may genuinely listen on nothing — but this script cannot tell" >&2
  echo "   that apart from ss failing, so it refuses rather than passing.)" >&2
  exit 2
fi

RC=0
PUBLIC=0
LOOPBACK=0

while IFS= read -r line; do
  # local address is field 4 in ss -ltn output
  ADDR=$(printf '%s' "$line" | awk '{print $4}')
  PORT="${ADDR##*:}"
  HOST="${ADDR%:*}"
  case "$HOST" in
    127.0.0.1|[::1]|::1)
      LOOPBACK=$((LOOPBACK + 1))
      echo "  ✅ loopback  $ADDR"
      ;;
    *)
      PUBLIC=$((PUBLIC + 1))
      OK=0
      for a in ${ALLOWED[@]+"${ALLOWED[@]}"}; do
        [ "$PORT" = "$a" ] && OK=1
      done
      if [ "$OK" = 1 ]; then
        echo "  ✅ public    $ADDR  (explicitly allowed)"
      else
        echo "  ⛔ EXPOSED   $ADDR  — NOT in the allowed list"
        RC=1
      fi
      ;;
  esac
done <<< "$LISTEN"

echo "  ($LOOPBACK loopback, $PUBLIC public)"

# ⚠️ NON-VACUITY: a check that found nothing to look at must not report success.
# Zero sockets parsed means the parse broke, not that the process is safe.
if [ "$((LOOPBACK + PUBLIC))" -eq 0 ]; then
  echo "CANNOT DETERMINE: parsed zero sockets from non-empty ss output" >&2
  exit 2
fi

# Secondary, reported but NOT the verdict: the known mechanism. Absence here is
# suspicious, but presence proves nothing about the effect — which is exactly
# why the verdict above keys on listeners instead.
if tr '\0' '\n' < "/proc/$PID/environ" 2>/dev/null | grep -q '^ELIXIR_ERL_OPTIONS=.*inet_dist_use_interface'; then
  echo "  (note: ELIXIR_ERL_OPTIONS carries the loopback pin)"
else
  echo "  ⚠️ (note: no inet_dist_use_interface pin in environ — not the verdict,"
  echo "      but worth knowing when the listener check is clean anyway)"
fi

if [ "$RC" = 0 ]; then
  echo "CLEAN: nothing exposed off-host beyond the allowed ports"
else
  echo "⛔ FINDING: this process listens off-host on a port that was not allowed."
  echo "   If that is Erlang distribution, it is an RCE surface with a shared cookie."
  echo "   Kill it and relaunch with the full environ diffed against a clean baseline."
fi
exit $RC
