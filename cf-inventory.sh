#!/usr/bin/env bash
# ⛔ pipefail: without it a pipeline reports the LAST stage. NOTE it does NOT save 1-vs-2 when a
# second stage also fails -- for a 0/1/2 script CAPTURE FIRST: out=$(script); rc=$?
set -o pipefail
# Inventory of what is deployed to the Commonplace Systems Cloudflare account.
#
# ⭐ jes, 2026-09-01T04:10Z: "I don't remember what else is deployed to Commonplace Systems
# cloudflare. Nothing production. But we need a way to track."
#
# ⛔ READ-ONLY. This script never writes to Cloudflare. It exists so the answer to "what is out
# there" is a COMMAND rather than a memory -- a remembered inventory is the thing that was missing.
#
# ⚠️ DO NOT USE /user/tokens/verify AS A HEALTH CHECK. It returns success:false for this token
# because it requires a "User Token Read" permission the token lacks. A FAILED VERIFY IS NOT A DEAD
# TOKEN -- /accounts is the real control, and this script uses it. (boss-clod, 2026-09-01)
#
# rc 0 = inventory printed · rc 2 = BLIND (no token, unreadable, or the account probe failed)
ENVF=${CF_ENV_FILE:-/home/jes/.config/cloudflare/do-worker.env}
[ -r "$ENVF" ] || { echo "BLIND|cannot read $ENVF"; exit 2; }
TOK=$(grep -E '^CLOUDFLARE_API_TOKEN=' "$ENVF" | head -1 | cut -d= -f2- | tr -d '"'\'' ')
[ -n "$TOK" ] || { echo "BLIND|no CLOUDFLARE_API_TOKEN in $ENVF"; exit 2; }
api(){ curl -sS -m 20 -H "Authorization: Bearer $TOK" "https://api.cloudflare.com/client/v4/$1"; }
ACCT_JSON=$(api accounts)
ACCT=$(printf '%s' "$ACCT_JSON" | python3 -c 'import sys,json;d=json.load(sys.stdin);print((d.get("result") or [{}])[0].get("id","") if d.get("success") else "")' 2>/dev/null)
NAME=$(printf '%s' "$ACCT_JSON" | python3 -c 'import sys,json;d=json.load(sys.stdin);print((d.get("result") or [{}])[0].get("name","") if d.get("success") else "")' 2>/dev/null)
# ⭐ THE POSITIVE CONTROL: if the account probe cannot name an account, everything below would print
# an empty inventory that looks exactly like "nothing is deployed". Refuse instead.
[ -n "$ACCT" ] || { echo "BLIND|/accounts returned no account id -- token invalid, revoked, or network down. An empty inventory here would be indistinguishable from an empty account."; exit 2; }
echo "CLOUDFLARE INVENTORY  account=$NAME  ($(date -u +%FT%TZ))"
echo
echo "WORKERS"
api "accounts/$ACCT/workers/scripts" | python3 -c '
import sys,json;d=json.load(sys.stdin)
r=d.get("result") or []
print("  (none)" if not r else "", end="")
# etag IS THE CODES IDENTITY; modified_on IS THE RECORDS. A tag-only write advances modified_on
# while etag stays fixed (measured by commonplace-biscuit 2026-09-01 on a disposable worker:
# 05:45:02 -> 05:45:06, etag identical, code never touched). Printing modified= alone invited the
# reading "last code change", which this tools own sibling cf-deploy.sh now falsifies every time it
# records provenance. THE PROVENANCE WRITE DESTROYS THE PROVENANCE SIGNAL.
for s in r: print("  %-34s etag=%s  meta-touched=%s" % (s.get("id"), (s.get("etag") or "?")[:16], (s.get("modified_on") or "")[:19]))
print("  ^ etag answers \"did the CODE change\". meta-touched moves on ANY metadata write (tags included)")
print("    and CANNOT answer it. Compare etag across runs; never modified_on.")
'
echo
echo "DURABLE OBJECT NAMESPACES"
api "accounts/$ACCT/workers/durable_objects/namespaces" | python3 -c '
import sys,json;d=json.load(sys.stdin)
r=d.get("result") or []
print("  (none)" if not r else "", end="")
for n in r: print("  %-30s class=%-22s script=%s" % (n.get("name"), n.get("class"), n.get("script")))
'
echo
echo "ZONES"
api "zones?account.id=$ACCT" | python3 -c '
import sys,json;d=json.load(sys.stdin)
r=d.get("result") or []
print("  (none)" if not r else "", end="")
for z in r: print("  %-30s status=%s" % (z.get("name"), z.get("status")))
'
