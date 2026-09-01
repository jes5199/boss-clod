#!/usr/bin/env bash
# ⭐ THE PATH FORM OF `THE PRICE IS THE TICKET` (commonplace-plan, rows 366–370, 2026-09-01).
#
# ⛔ A rule in a library fires only when someone ALREADY SUSPECTS THEY NEED IT — which is the case in
# which they least need it. Plan's pattern, and it costs nothing: PUT A RULE THAT MUST FIRE INTO A
# REQUIRED FIELD OF SOMETHING YOU ALREADY PRODUCE. Not a new artifact — a required field in the
# existing one. Condition ⑤ became real by joining a template every round must satisfy, NOT by being
# written down more emphatically.
#
# ⚠️ EARNED: boss sent jes a storage-backend DECISION with a suggested default and no price
# (telegram 10680). Plan's hold on that exact decision arrived 3 minutes later. THE FIX IS NOT FASTER
# RELAYING — a ruling that must arrive BEFORE an act cannot travel in the same channel as the act.
# This gate is checkable BY THE SENDER AT THE MOMENT OF SENDING and requires nothing of Plan's speed.
#
# Usage: jes-send.sh --kind=fact|decision|correction --subject=<what> [--price=<row>] <<'MSG'
# Exit:  0 composed (prints the body to paste into the telegram reply tool)
#        1 REFUSED — a decision with no price, or a missing required field
set -o pipefail
kind=""; subject=""; price=""
while :; do case "${1-}" in
  --kind=*)    kind="${1#--kind=}"; shift;;
  --subject=*) subject="${1#--subject=}"; shift;;
  --price=*)   price="${1#--price=}"; shift;;
  *) break;; esac
done
[ -n "$kind" ]    || { echo "REFUSED|--kind= is required: fact | decision | correction"; exit 1; }
[ -n "$subject" ] || { echo "REFUSED|--subject= is required: name what this is about"; exit 1; }
case "$kind" in
  fact|correction) ;;
  decision)
    # ⛔⛔ THE GATE. A decision without its pricing row is not sendable.
    [ -n "$price" ] || { cat <<'E'
REFUSED|A DECISION PUT TO jes CARRIES THE LEDGER ROW THAT PRICES IT. No row ⇒ it is a FACT: resend
        with --kind=fact and no recommendation attached.
        ⚠️ A dramatic finding is the CONDITION under which an unpriced question gets sent — the
        discipline fails against EXCITING cases, not hard ones. If sending this feels urgent, that
        is the symptom, not the exemption.
E
      exit 1; }
    ;;
  *) echo "REFUSED|--kind must be fact | decision | correction (got: $kind)"; exit 1;;
esac
body=$(cat)
[ -n "$body" ] || { echo "REFUSED|empty body on stdin"; exit 1; }
printf '%s\n' "$body"
[ -n "$price" ] && printf '\n**PRICE:** %s\n' "$price"
printf '\n<!-- kind=%s subject=%s -->\n' "$kind" "$subject"
exit 0
