#!/usr/bin/env bash
# CX-v14m: PROVE THE SOCKET MASK CAN GO RED.
#
# The mask in sol-egress-run.sh is DERIVED AT LAUNCH. A derivation that silently
# returns an empty list produces a run that looks IDENTICAL to a correctly-masked
# one. So correctness of the derivation is not the question — its NON-EMPTINESS
# and its EFFECT are.
#
# Three arms, and arm B is the whole point:
#   A  DERIVATION      the list is non-empty AND contains docker.sock
#   B  MUST-FAIL       with the mask array EMPTY, the socket IS reachable inside
#                      the same bwrap  =>  the probe can SEE a reachable socket
#   C  MASKED          with the derived mask applied, it is NOT reachable
#
# Arm B is what makes arm C mean anything: without it, "not reachable" is also
# what a broken probe, a missing docker CLI, or a typo'd path would report.
#
# READ-ONLY with respect to sol-egress-run.sh. Nothing here edits the fence.
set -uo pipefail

SOCK=/run/docker.sock
say() { printf '\n=== %s ===\n' "$*"; }

say "PRE-FLIGHT: the socket exists and is reachable ON THE HOST"
ls -la "$SOCK" 2>&1 || { echo "FATAL: $SOCK absent — arm B could not fail even in principle"; exit 2; }
if [ -r "$SOCK" ] && [ -w "$SOCK" ]; then
  echo "host reachable as $(id -un): YES (r+w)"
else
  echo "FATAL: not reachable as this uid on the host — the hole this guards is not present, so no arm below is meaningful"
  exit 2
fi

say "ARM A — DERIVATION (the exact loop from sol-egress-run.sh:271-277)"
SYS_SOCKET_MASK=()
while IFS= read -r _sock; do
  case "$_sock" in /run/user/*) continue ;; esac
  if [ -r "$_sock" ] && [ -w "$_sock" ]; then
    SYS_SOCKET_MASK+=( --bind /dev/null "$_sock" )
  fi
done < <(find /run -maxdepth 2 -type s 2>/dev/null | sort -u)

echo "derived entries: ${#SYS_SOCKET_MASK[@]} array elements ($(( ${#SYS_SOCKET_MASK[@]} / 3 )) sockets)"
printf '  %s\n' "${SYS_SOCKET_MASK[@]}" | paste - - - 2>/dev/null || printf '  %s\n' "${SYS_SOCKET_MASK[@]}"

if [ "${#SYS_SOCKET_MASK[@]}" -eq 0 ]; then
  echo "ARM A: RED — derivation produced an EMPTY list. This is the silent-failure mode."
  exit 1
fi
if printf '%s\n' "${SYS_SOCKET_MASK[@]}" | grep -qx "$SOCK"; then
  echo "ARM A: GREEN — non-empty AND contains $SOCK"
else
  echo "ARM A: RED — non-empty but does NOT contain $SOCK"
  exit 1
fi

probe() {
  # $1: "masked" | "unmasked"
  local -a mask=()
  [ "$1" = masked ] && mask=( "${SYS_SOCKET_MASK[@]}" )
  bwrap --dev-bind / / --unshare-pid --proc /proc "${mask[@]}" -- \
    bash -c '
      if [ -S /run/docker.sock ] && [ -w /run/docker.sock ]; then
        echo "SOCKET-SHAPE: present and writable"
      else
        echo "SOCKET-SHAPE: absent or not a writable socket"
      fi
      if command -v docker >/dev/null 2>&1; then
        if out=$(timeout 20 docker version --format "{{.Server.Version}}" 2>&1); then
          echo "DOCKER-ANSWERS: YES server=$out"
        else
          echo "DOCKER-ANSWERS: NO ($(printf "%s" "$out" | head -1))"
        fi
      else
        echo "DOCKER-CLI: absent — falling back to socket shape only"
      fi
    ' 2>&1
}

say "ARM B — MUST-FAIL CONTROL (mask array EMPTY, same bwrap)"
b_out="$(probe unmasked)"
printf '%s\n' "$b_out"
if printf '%s' "$b_out" | grep -q "DOCKER-ANSWERS: YES"; then
  echo "ARM B: GREEN (as required) — the probe CAN see a reachable socket; arm C is therefore meaningful"
  B_OK=1
elif printf '%s' "$b_out" | grep -q "SOCKET-SHAPE: present and writable"; then
  echo "ARM B: GREEN (weaker form) — socket reachable by shape; docker CLI did not answer"
  B_OK=1
else
  echo "ARM B: RED — the probe could NOT see the socket even UNMASKED."
  echo "         => arm C proves nothing: a blind probe reports 'safe' for every input."
  B_OK=0
fi

say "ARM C — MASKED (the fence's derived mask applied)"
c_out="$(probe masked)"
printf '%s\n' "$c_out"
if printf '%s' "$c_out" | grep -q "DOCKER-ANSWERS: YES"; then
  echo "ARM C: RED — socket STILL reachable with the mask applied. THE FENCE DOES NOT HOLD."
  C_OK=0
else
  echo "ARM C: GREEN — not reachable with the mask applied"
  C_OK=1
fi

say "VERDICT"
if [ "$B_OK" = 1 ] && [ "$C_OK" = 1 ]; then
  echo "PASS — mask demonstrated RED-CAPABLE (arm B) and EFFECTIVE (arm C)."
  echo "       'not reachable' now distinguishes a working mask from a blind probe."
  exit 0
else
  echo "FAIL — B_OK=$B_OK C_OK=$C_OK"
  exit 1
fi
