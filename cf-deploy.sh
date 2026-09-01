#!/usr/bin/env bash
# Deploy a Cloudflare Worker AND write its provenance, in ONE path so they cannot drift.
#
# ⭐ commonplace-plan row 194: A PROVENANCE RECORD WRITTEN BY THE DEPLOY PATH CANNOT DRIFT FROM
# WHAT IS DEPLOYED; ONE MAINTAINED BESIDE IT CAN. So there is no manifest file to update — the
# record lives ON the artifact and is written by the same call that deploys it.
#
# ⛔ MEASURED 2026-09-01, AND IT DECIDES THE DESIGN — the two channels are NOT equivalent:
#     plain_text bindings  a later PUT that omits them ERASES them, HTTP 200, silently
#     script tags          SURVIVE a script redeploy that says nothing about tags
#   ⇒ TAGS ARE THE DURABLE HALF. Bindings carry the prose; tags carry the identity that must
#     survive someone else deploying over this worker from wrangler or the dashboard.
#   ⚠️ This is the decline-flag family: the forgetful redeploy SUCCEEDS. There is no wrong value
#     to notice — which is why the durable channel had to be measured rather than reasoned about.
#
# ⭐ FIELD TEST (boss-clod): "could I recover this in two minutes from the API if the record were
#   lost?" WHAT and WHEN are recoverable — the API already returns them, so this does not copy
#   them. WHY and WHO AUTHORIZED are not recoverable by any means. They are the record's whole job.
set -uo pipefail
: "${CLOUDFLARE_API_TOKEN:?load ~/.config/cloudflare/do-worker.env first}"
ACC="${CF_ACCOUNT:-d5c4856e9cb4dd41c12b39fb9df29726}"
API="https://api.cloudflare.com/client/v4/accounts/$ACC/workers/scripts"

usage() { echo "usage: $0 deploy <name> <module.mjs> <why> <authorized-by> | remove <name> | show <name> | inventory" >&2; exit 2; }
cf() { curl -sS -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "$@"; }
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  RED  %s\n' "$1"; fail=1; }
fail=0

# ⭐ Presence is asked BY NAME, never by scanning a list: "some worker exists" is not "this one does".
exists() { local code; code=$(cf -o /dev/null -w '%{http_code}' "$API/$1"); [ "$code" = "200" ]; }

case "${1:-}" in
deploy)
  [ $# -eq 5 ] || usage
  NAME=$2; MOD=$3; WHY=$4; AUTH=$5
  [ -f "$MOD" ] || { echo "  BLIND: module $MOD does not exist"; exit 2; }
  # ⭐ TRANSITION, source half — recorded BEFORE, so the post-check asserts a CHANGE and not a state.
  if exists "$NAME"; then before=present; else before=absent; fi
  BASE=$(basename "$MOD")
  python3 - "$BASE" "$WHY" "$AUTH" "$NAME" > /tmp/cf-meta.json <<'PY'
import json,sys
base,why,auth,name=sys.argv[1:5]
json.dump({"main_module":base,"compatibility_date":"2026-08-01","bindings":[
  {"type":"plain_text","name":"PROV_WHY","text":why},
  {"type":"plain_text","name":"PROV_AUTHORIZED_BY","text":auth},
  {"type":"plain_text","name":"PROV_REMOVE","text":"cf-deploy.sh remove %s"%name},
]},sys.stdout)
PY
  code=$(cf -o /tmp/cf-put.json -w '%{http_code}' -X PUT \
      -F "metadata=@/tmp/cf-meta.json;type=application/json" \
      -F "$BASE=@$MOD;type=application/javascript+module" "$API/$NAME")
  [ "$code" = "200" ] && ok "deployed $NAME (HTTP $code)" || bad "deploy failed HTTP $code: $(head -c 200 /tmp/cf-put.json)"
  # ⭐ The DURABLE half, written by the same path. A tag survives someone else's redeploy; a
  #   binding does not. Both are written every time, so this path can never be the forgetful one.
  tcode=$(cf -o /dev/null -w '%{http_code}' -X PUT -H 'Content-Type: application/json' \
      --data "$(python3 -c 'import json,sys;print(json.dumps(["prov:managed-by-cf-deploy","prov:authorized="+sys.argv[1][:100]]))' "$AUTH")" \
      "$API/$NAME/tags")
  [ "$tcode" = "200" ] && ok "provenance tags written (HTTP $tcode)" || bad "tags failed HTTP $tcode"
  # ⭐ POST-CHECK ASSERTS THE TRANSITION, not the destination: absent→present, and the record
  #   readable back FROM THE API — not from the file we just wrote, which would assert nothing.
  if exists "$NAME"; then
    [ "$before" = absent ] && ok "transition: absent -> present" || ok "transition: present -> updated (was already there)"
  else
    bad "post-check: $NAME is NOT present after a deploy that returned $code"
  fi
  cf "$API/$NAME/settings" > /tmp/cf-set.json
  n=$(python3 -c "import json;print(len([b for b in (json.load(open('/tmp/cf-set.json')).get('result') or {}).get('bindings') or [] if b.get('name','').startswith('PROV_')]))")
  [ "$n" -ge 3 ] && ok "provenance readable back from the API: $n PROV_ fields" || bad "only $n PROV_ fields readable — the record did not land"
  ;;
remove)
  [ $# -eq 2 ] || usage
  NAME=$2
  exists "$NAME" || { echo "  BLIND: $NAME is not present — nothing to remove, and this is not a successful removal"; exit 2; }
  code=$(cf -o /dev/null -w '%{http_code}' -X DELETE "$API/$NAME")
  [ "$code" = "200" ] && ok "delete returned HTTP $code" || bad "delete HTTP $code"
  # ⭐ The record's removal half — proven at the same moment as the deploy's, per row 194.
  #   A provenance file whose deletion path has never run is one that outlives its subject.
  if exists "$NAME"; then bad "post-check: $NAME is STILL PRESENT after a delete that returned $code"
  else ok "transition: present -> absent (record removed with its subject)"; fi
  ;;
show)
  [ $# -eq 2 ] || usage
  # ⛔ THIS ARM SHIPPED WITH THE NIGHT'S OWN DEFECT AND THE RED CASE CAUGHT IT: it PRINTED
  #    "BLIND" AND EXITED 0, because the python status died in a pipe and the tags call ran
  #    afterwards and succeeded. ⭐ A verdict word beside a contradicting status is invisible
  #    on a green and glaring on a red — the whole argument for exercising the red case.
  cf "$API/$2/settings" > /tmp/cf-show.json
  python3 - "$2" <<'PYSHOW' || exit $?
import json,sys
d=json.load(open('/tmp/cf-show.json'))
if not d.get('success'):
    print('  BLIND: no settings for %s — it does not exist, or the listing failed'%sys.argv[1]); sys.exit(2)
rows=[b for b in (d.get('result') or {}).get('bindings') or [] if b.get('name','').startswith('PROV_')]
if not rows:
    print('  ⚠️  NO PROVENANCE BINDINGS — deployed, but not by a path that records why'); sys.exit(1)
for b in rows: print('  %-20s %s'%(b['name'],b.get('text')))
PYSHOW
  cf "$API/$2/tags" > /tmp/cf-tags.json
  python3 -c "import json;print('  tags:',json.load(open('/tmp/cf-tags.json')).get('result'))"
  ;;
inventory)
  cf "$API" > /tmp/cf-inv.json
  n=$(python3 -c "import json;print(len(json.load(open('/tmp/cf-inv.json')).get('result') or []))")
  # ⭐ EMPTY CORPUS IS BLIND, NEVER A CLEAN BILL: "no workers" and "the listing failed" are the
  #   same observable, and only this requirement separates them.
  [ "$n" -ge 1 ] || { echo "  BLIND: the account lists ZERO workers — that is an instrument result, not an inventory"; exit 2; }
  echo "  $n worker(s):"
  for w in $(python3 -c "import json;print(' '.join(x['id'] for x in json.load(open('/tmp/cf-inv.json'))['result']))"); do
    t=$(cf "$API/$w/tags" | python3 -c "import json,sys;print(','.join(json.load(sys.stdin).get('result') or []) or 'NONE')")
    case "$t" in *prov:*) printf '    %-34s provenance: %s\n' "$w" "$t" ;;
                 *) printf '    %-34s ⚠️  NO PROVENANCE RECORD\n' "$w" ;; esac
  done
  ;;
*) usage ;;
esac
[ "$fail" = 0 ] || exit 1
