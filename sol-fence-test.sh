#!/usr/bin/env bash
# Regression test for sol-egress-run.sh's fence.
#
# WHY THIS EXISTS: the Erlang-cookie hole (closed 2026-08-08) was not a
# mistake in the mask -- it was a mask that was CORRECT until egress was
# opened, after which BEAM distribution became reachable and nobody
# re-tested. "Egress changed the fence and nobody re-tested distribution."
# A fence with no test degrades silently every time its environment changes.
#
# DESIGN, per the day's lessons:
#   * every negative assertion is paired with a POSITIVE CONTROL, because
#     "blocked" and "not there" share an exit code and an all-negative
#     table is unfalsifiable
#   * the rc acted on never comes through a pipe
#   * this walks the path Sol actually walks (the same MASK array), rather
#     than testing a reconstruction of it
#
# Does NOT invoke codex -- costs no credits, safe to run any time.

set -uo pipefail
cd "$(dirname "$0")"

pass=0; fail=0
ok()   { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }

# Extract the live MASK from the wrapper rather than duplicating it, so this
# test cannot drift from the thing it tests.
# ⚠️ STRIP COMMENT LINES FIRST. 2026-08-09: a hazard note added INSIDE the
# MASK array contained the literal strings "--ro-bind /dev/null" and
# "--tmpfs OR ANYTHING" as prose, and this parser turned them into bwrap
# arguments -- 4 of 11 assertions failed on a wrapper that was completely
# fine. The DOCUMENTATION of a hazard broke the CHECKER for that hazard.
# (Same shape as a boundary comment quoting the pattern it forbids, so the
# checker matches its own commentary.) A parser that reads a file must
# ignore the parts of that file written for humans.
mapfile -t MASK < <(
  sed -n '/^MASK=(/,/^)/p' sol-egress-run.sh |
  grep -vE '^[[:space:]]*#' |
  grep -oE '\-\-(tmpfs|ro-bind) [^ ]+( [^ ]+)?' |
  tr ' ' '\n' | grep -v '^$'
)
[ "${#MASK[@]}" -gt 0 ] || { echo "FATAL: could not parse MASK from sol-egress-run.sh"; exit 2; }

insandbox() { bwrap --dev-bind / / "${MASK[@]}" -- bash -c "$1" >/dev/null 2>&1; }
outside()   { bash -c "$1" >/dev/null 2>&1; }

echo "== masked secrets are UNREADABLE inside (each with a positive control outside) =="
check_masked() { # $1=human name  $2=path
  if outside "test -s '$2'"; then
    if insandbox "test -s '$2'"; then bad "$1 STILL READABLE inside the sandbox"
    else ok "$1 masked inside; present outside (control held)"; fi
  else
    bad "$1: control FAILED -- not present outside, so the inside result proves nothing"
  fi
}
check_masked "ssh private key"    /home/jes/.ssh/id_ed25519
check_masked "gh oauth token"     /home/jes/.config/gh/hosts.yml
check_masked "node signing key"   /home/jes/commonplace/workspace/.commonplace/node_signing_key
check_masked "erlang cookie"      /home/jes/.erlang.cookie

echo "== the store IS still reachable (jes: 'if Claude can do it, then Sol can do it') =="
if insandbox "test -d /home/jes/commonplace/workspace/.commonplace/commits"; then
  ok "commits/ readable inside -- fence removes secrets, not access"
else
  bad "commits/ unreachable inside -- the fence is over-tight, Sol cannot do its job"
fi

echo "== bd resolves to the guard, not the frozen archive =="
if insandbox "cd /home/jes/commonplace && bd show CX-mchn"; then
  bad "bd answered inside the sandbox -- the shadow is not in the path Sol walks"
else
  ok "bd refused inside the sandbox"
fi
if insandbox "cd /home/jes/commonplace && CP_BD_ARCHIVE=1 bd show CX-mchn"; then
  ok "CP_BD_ARCHIVE=1 escape hatch works (deliberate archive read stays available)"
else
  bad "escape hatch BROKEN -- a guard with an unusable escape hatch teaches people to ignore guards"
fi
if outside "cd /home/jes/hermes && bd list"; then
  ok "host bd untouched: hermes still lists its live tickets"
else
  bad "HOST bd BROKEN -- the shadow leaked out of the sandbox onto live beads repos"
fi

echo "== secrets are scrubbed from the environment =="
for v in LETTA_API_KEY SQUAD_ALERTS_PUBLISHER_TOKEN; do
  if env -u "$v" bwrap --dev-bind / / "${MASK[@]}" -- bash -c "test -z \"\${$v:-}\"" >/dev/null 2>&1; then
    ok "$v absent inside"
  else
    bad "$v PRESENT inside"
  fi
done

echo "== the live-checkout refusal still fires =="
SOL_WORKDIR=/home/jes/commonplace ./sol-egress-run.sh true >/dev/null 2>&1
[ $? -eq 64 ] && ok "refuses SOL_WORKDIR=/home/jes/commonplace with exit 64" \
              || bad "live-checkout refusal did NOT fire"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
