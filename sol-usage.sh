#!/usr/bin/env bash
# Usage: sol-usage.sh [--machine|--json]
# Reports upstream Codex quota windows through local CLIProxyAPI; rc=2 means BLIND.

set -uo pipefail

mode=human
case "$#" in
  0) ;;
  1)
    case "$1" in
      --machine) mode=machine ;;
      --json) mode=json ;;
      *) printf 'BLIND|invalid arguments; use --machine or --json\n' >&2; exit 2 ;;
    esac
    ;;
  *) printf 'BLIND|invalid arguments; use --machine or --json\n' >&2; exit 2 ;;
esac

blind() {
  # Do not interpolate request, credential, or response values here: responses can
  # contain the account, email, auth filename, or proxy-injected access token.
  printf 'BLIND|upstream Codex quota could not be measured\n' >&2
  exit 2
}

home=${HOME-}
if [ -n "${CPA_MANAGEMENT_KEY_FILE-}" ]; then
  key_file=$CPA_MANAGEMENT_KEY_FILE
else
  [ -n "$home" ] || blind
  key_file="$home/.cli-proxy-api/management.key"
fi
base_url=${CPA_BASE_URL:-http://127.0.0.1:8317}
# The management bearer is privileged. It may only be sent to the numeric IPv4
# loopback listener, never to a caller-supplied origin, userinfo, path, or query.
[[ "$base_url" =~ ^http://127\.0\.0\.1:([1-9][0-9]{0,4})$ ]] || blind
[ "${BASH_REMATCH[1]}" -le 65535 ] || blind

[ -r "$key_file" ] || blind
management_key=""
IFS= read -r management_key < "$key_file" || [ -n "$management_key" ] || blind
[ -n "$management_key" ] || blind
[[ "$management_key" != *$'\r'* && "$management_key" != *$'\n'* ]] || blind
command -v curl >/dev/null 2>&1 || blind
command -v python3 >/dev/null 2>&1 || blind

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/sol-usage.XXXXXX") || blind
chmod 700 "$tmpdir" 2>/dev/null || { rm -rf "$tmpdir"; blind; }
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM

auth_response="$tmpdir/auth-response.json"
api_request="$tmpdir/api-request.json"
usage_response="$tmpdir/usage-response.json"
curl_auth_header="$tmpdir/curl-auth-header"
printf 'Authorization: Bearer %s\n' "$management_key" > "$curl_auth_header" || blind
chmod 600 "$curl_auth_header" 2>/dev/null || blind

# `auth-files` is credential metadata, not an assertion that a Codex OAuth source
# exists. The Python gate below proves the returned corpus and selected identity.
curl --silent --show-error --fail --max-time 20 --connect-timeout 5 \
  -H "@$curl_auth_header" \
  "$base_url/v0/management/auth-files" >"$auth_response" 2>/dev/null || blind
[ -s "$auth_response" ] || blind

# Select one, and only one, enabled Codex OAuth entry. Emit only the subsequent
# proxy request into a private temporary file; never render credential metadata.
python3 - "$auth_response" "$api_request" <<'PY' >/dev/null 2>&1 || blind
import json
import math
import sys

source_path, request_path = sys.argv[1:]
try:
    with open(source_path, encoding="utf-8") as f:
        payload = json.load(f)
except Exception:
    raise SystemExit(2)

# CLIProxyAPI versions have returned the list directly and in these documented
# envelopes. Anything else is a shape change, not an empty quota report.
def list_corpus(value):
    if isinstance(value, list):
        return value
    if not isinstance(value, dict):
        return None
    candidates = []
    for key in ("files", "auth_files", "authFiles"):
        if key not in value:
            continue
        candidate = value[key]
        if not isinstance(candidate, list):
            return None
        candidates.append(candidate)
    if "data" in value:
        data = value["data"]
        if isinstance(data, list):
            candidates.append(data)
        elif isinstance(data, dict):
            nested_candidates = []
            for key in ("auth_files", "authFiles"):
                if key not in data:
                    continue
                candidate = data[key]
                if not isinstance(candidate, list):
                    return None
                nested_candidates.append(candidate)
            if not nested_candidates:
                return None
            candidates.extend(nested_candidates)
        else:
            return None
    if not candidates:
        return None
    try:
        rendered = [json.dumps(item, sort_keys=True, separators=(",", ":"))
                    for item in candidates]
    except Exception:
        return None
    if any(item != rendered[0] for item in rendered[1:]):
        return None
    return candidates[0]

corpus = list_corpus(payload)
if not isinstance(corpus, list) or not corpus:
    raise SystemExit(2)
if not all(isinstance(entry, dict) for entry in corpus):
    raise SystemExit(2)

def normalized_fields(entry, keys):
    values = []
    for key in keys:
        if key in entry:
            value = entry[key]
            if not isinstance(value, str) or not value.strip():
                return None
            values.append(value.strip().lower())
    return values

def codex_mode(entry):
    codex_names = ("codex", "codex-oauth", "codex_oauth")
    identities = normalized_fields(entry, ("type", "provider"))
    raw_identities = [entry[key] for key in ("type", "provider") if key in entry]
    claims_codex = any(
        isinstance(value, str) and value.strip().lower() in codex_names
        for value in raw_identities
    )
    if not claims_codex:
        return "other"
    if not identities or not all(value in codex_names for value in identities):
        return "malformed"
    modes = normalized_fields(
        entry, ("account_type", "accountType", "auth_type", "authType")
    )
    if not modes:
        return "malformed"
    if all(value == "oauth" for value in modes):
        return "oauth"
    if all(value in ("api_key", "api-key", "apikey") for value in modes):
        return "api_key"
    return "malformed"

def lifecycle(entry):
    values = {}
    for key in ("disabled", "enabled", "unavailable"):
        if key in entry:
            if not isinstance(entry[key], bool):
                return "malformed"
            values[key] = entry[key]
    status = None
    if "status" in entry:
        status = entry["status"]
        if not isinstance(status, str):
            return "malformed"
        status = status.strip().lower()
        if status not in ("active", "enabled", "pending", "refreshing", "error", "disabled"):
            return "malformed"
    disabled = values.get("disabled")
    enabled = values.get("enabled")
    unavailable = values.get("unavailable")
    if status == "disabled" and disabled is False:
        return "malformed"
    if status in ("active", "enabled") and (disabled is True or enabled is False):
        return "malformed"
    if enabled is True and disabled is True:
        return "malformed"
    if disabled is True or enabled is False or unavailable is True \
            or status in ("pending", "refreshing", "error", "disabled"):
        return "inactive"
    if disabled is False or enabled is True or unavailable is False \
            or status in ("active", "enabled"):
        return "active"
    return "malformed"

def account_id(entry):
    values = []
    for key in ("chatgpt_account_id", "chatgptAccountId"):
        if key in entry:
            values.append(entry[key])
    for token_key in ("id_token", "idToken"):
        if token_key not in entry:
            continue
        nested = entry[token_key]
        if not isinstance(nested, dict):
            return None
        for key in ("chatgpt_account_id", "chatgptAccountId"):
            if key in nested:
                values.append(nested[key])
    if not values or any(
        not isinstance(value, str) or not value or len(value) > 256
        or any(c in value for c in "\r\n\t")
        for value in values
    ):
        return None
    return values[0] if all(value == values[0] for value in values[1:]) else None

def valid_index(value):
    if isinstance(value, bool):
        return False
    if isinstance(value, int):
        return value >= 0
    return isinstance(value, str) and value and len(value) <= 256 \
        and not any(c in value for c in "\r\n\t")

matches = []
for entry in corpus:
    mode = codex_mode(entry)
    if mode == "other" or mode == "api_key":
        continue
    if mode == "malformed":
        raise SystemExit(2)
    state = lifecycle(entry)
    if state == "malformed":
        raise SystemExit(2)
    if state == "inactive":
        continue
    index = entry.get("auth_index")
    account = account_id(entry)
    if not valid_index(index) or not account:
        raise SystemExit(2)
    matches.append((entry, index, account))
if len(matches) != 1:
    raise SystemExit(2)

selected, index, account = matches[0]
request = {
    "auth_index": index,
    "method": "GET",
    "url": "https://chatgpt.com/backend-api/wham/usage",
    "header": {
        "Authorization": "Bearer $TOKEN$",
        "ChatGPT-Account-ID": account,
        "Originator": "codex-tui",
        "User-Agent": "codex-cli/0.76.0",
    },
}
try:
    with open(request_path, "w", encoding="utf-8") as f:
        json.dump(request, f, separators=(",", ":"))
except Exception:
    raise SystemExit(2)
PY

curl --silent --show-error --fail --max-time 30 --connect-timeout 5 \
  -X POST \
  -H "@$curl_auth_header" \
  -H 'Content-Type: application/json' \
  --data-binary "@$api_request" \
  "$base_url/v0/management/api-call" >"$usage_response" 2>/dev/null || blind
[ -s "$usage_response" ] || blind

# api-call returns a wrapper around the raw upstream response. Parse only known
# wrappers and demand a 2xx upstream status before accepting its JSON body.
python3 - "$mode" "$usage_response" <<'PY' || blind
import json
import math
import sys

mode, response_path = sys.argv[1:]
try:
    with open(response_path, encoding="utf-8") as f:
        outer = json.load(f)
except Exception:
    raise SystemExit(2)

# Permit the API's direct wrapper and its common data/response envelopes, but do
# not recurse arbitrarily: unrelated integers named `status` are not provenance.
WRAPPER_MISSING = object()

def wrapper_alias(value, keys):
    present = [value[key] for key in keys if key in value]
    if not present:
        return WRAPPER_MISSING
    try:
        rendered = [json.dumps(item, sort_keys=True, separators=(",", ":"))
                    for item in present]
    except Exception:
        raise SystemExit(2)
    if any(item != rendered[0] for item in rendered[1:]):
        raise SystemExit(2)
    return present[0]

def wrapper(value):
    if not isinstance(value, dict):
        return None
    candidates = []
    if any(key in value for key in ("status_code", "statusCode")):
        candidates.append(value)
    for key in ("data", "response"):
        nested = value.get(key)
        if isinstance(nested, dict) and any(
            name in nested for name in ("status_code", "statusCode")
        ):
            candidates.append(nested)
    if not candidates:
        return None
    rendered = [json.dumps(item, sort_keys=True, separators=(",", ":"))
                for item in candidates]
    if any(item != rendered[0] for item in rendered[1:]):
        return None
    return candidates[0]

result = wrapper(outer)
if result is None:
    raise SystemExit(2)
status = wrapper_alias(result, ("status_code", "statusCode"))
if status is WRAPPER_MISSING or isinstance(status, bool) \
        or not isinstance(status, int) or not 200 <= status < 300:
    raise SystemExit(2)
body = wrapper_alias(result, ("body", "raw_body", "rawBody"))
if body is WRAPPER_MISSING or not isinstance(body, str):
    raise SystemExit(2)
try:
    upstream = json.loads(body)
except Exception:
    raise SystemExit(2)

# A WHAM response puts the account-wide quota under `rate_limit` and may add
# independently metered groups. Reject conflicting snake/camel aliases rather
# than choosing whichever spelling happens to be checked first.
MISSING = object()

def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)

def alias_value(value, keys, default=MISSING):
    if not isinstance(value, dict):
        raise SystemExit(2)
    present = [value[key] for key in keys if key in value]
    if not present:
        return default
    try:
        rendered = [canonical(item) for item in present]
    except Exception:
        raise SystemExit(2)
    if any(item != rendered[0] for item in rendered[1:]):
        raise SystemExit(2)
    return present[0]

def quota_projection(value):
    projection = []
    for keys in (
        ("rate_limit", "rateLimit"),
        ("code_review_rate_limit", "codeReviewRateLimit"),
        ("additional_rate_limits", "additionalRateLimits"),
    ):
        item = alias_value(value, keys)
        projection.append(None if item is MISSING else canonical(item))
    return projection

if not isinstance(upstream, dict):
    raise SystemExit(2)
direct_main = alias_value(upstream, ("rate_limit", "rateLimit"))
nested = upstream.get("data")
nested_main = MISSING
if nested is not None:
    if not isinstance(nested, dict):
        raise SystemExit(2)
    nested_main = alias_value(nested, ("rate_limit", "rateLimit"))
if direct_main is not MISSING and nested_main is not MISSING:
    if quota_projection(upstream) != quota_projection(nested):
        raise SystemExit(2)
    root = upstream
elif direct_main is not MISSING:
    root = upstream
elif nested_main is not MISSING:
    root = nested
else:
    raise SystemExit(2)

main_limits = alias_value(root, ("rate_limit", "rateLimit"))
if not isinstance(main_limits, dict):
    raise SystemExit(2)

def finite_number(value):
    return (isinstance(value, (int, float)) and not isinstance(value, bool)
            and math.isfinite(value))

def metadata_text(value):
    if value is None:
        return None
    if not isinstance(value, str) or not value or len(value) > 256 \
            or any(c in value for c in "\r\n\t"):
        raise SystemExit(2)
    return value

def minutes_for(value):
    candidates = (
        ("limit_window_seconds", 1 / 60),
        ("limitWindowSeconds", 1 / 60),
        ("window_seconds", 1 / 60),
        ("windowSeconds", 1 / 60),
        ("limit_window_minutes", 1),
        ("limitWindowMinutes", 1),
        ("window_minutes", 1),
        ("windowMinutes", 1),
    )
    seen = []
    for key, multiplier in candidates:
        raw = value.get(key)
        if raw is not None:
            if not finite_number(raw) or raw <= 0:
                return None
            minutes = raw * multiplier
            if not float(minutes).is_integer():
                return None
            seen.append(int(minutes))
    if len(set(seen)) != 1:
        return None
    return seen[0] if seen else None

# Each group gets a reporter-owned scope label. Upstream descriptive strings are
# used only to recognize the known Spark meter and are never copied to output.
groups = [("main", main_limits)]
code_review = alias_value(
    root, ("code_review_rate_limit", "codeReviewRateLimit"), default=None
)
if code_review is not None:
    if not isinstance(code_review, dict):
        raise SystemExit(2)
    groups.append(("code_review", code_review))

additional = alias_value(
    root, ("additional_rate_limits", "additionalRateLimits"), default=[]
)
if additional is None:
    additional = []
if not isinstance(additional, list) or not all(isinstance(item, dict) for item in additional):
    raise SystemExit(2)
additional_identities = set()
for position, item in enumerate(additional, start=1):
    name = metadata_text(alias_value(item, ("limit_name", "limitName"), default=None))
    feature = metadata_text(
        alias_value(item, ("metered_feature", "meteredFeature"), default=None)
    )
    limits = alias_value(item, ("rate_limit", "rateLimit"))
    if (name is None and feature is None) or not isinstance(limits, dict):
        raise SystemExit(2)
    meter_identity = (name, feature)
    if meter_identity in additional_identities:
        raise SystemExit(2)
    additional_identities.add(meter_identity)
    scope = "codex_spark" if (
        name == "GPT-5.3-Codex-Spark" and feature == "codex_bengalfox"
    ) else f"additional_{position}"
    groups.append((scope, limits))

if len({scope for scope, _ in groups}) != len(groups):
    raise SystemExit(2)

windows = []
known_window_keys = {"primary_window", "primaryWindow", "secondary_window", "secondaryWindow"}
for scope, limits in groups:
    if not isinstance(limits, dict):
        raise SystemExit(2)
    for key in limits:
        if isinstance(key, str) and key.lower().endswith("window") \
                and key not in known_window_keys:
            raise SystemExit(2)
    group_windows = []
    for source_keys in (
        ("primary_window", "primaryWindow"),
        ("secondary_window", "secondaryWindow"),
    ):
        value = alias_value(limits, source_keys)
        if value is MISSING or value is None:
            continue
        if not isinstance(value, dict):
            raise SystemExit(2)
        minutes = minutes_for(value)
        if minutes is None:
            raise SystemExit(2)
        fields = {}
        used = alias_value(value, ("used_percent", "usedPercent"))
        if not finite_number(used) or not 0 <= used <= 100:
            raise SystemExit(2)
        fields["used_percent"] = used
        for output_key, source_keys in (
            ("reset_at", ("reset_at", "resetAt")),
            ("reset_after", ("reset_after", "resetAfter", "reset_after_seconds", "resetAfterSeconds")),
        ):
            reset = alias_value(value, source_keys)
            if reset is MISSING:
                continue
            if not finite_number(reset) or reset < 0:
                raise SystemExit(2)
            fields[output_key] = reset
        label = "5h" if minutes == 300 else "weekly" if minutes == 10080 else f"{minutes}m"
        group_windows.append({
            "scope": scope, "window": label, "minutes": minutes, **fields
        })
    if not group_windows:
        raise SystemExit(2)
    windows.extend(group_windows)

if not windows:
    raise SystemExit(2)
# A duration can legitimately recur in separate meters. A duplicate within the
# same meter would make downstream control ambiguous, so reject only that shape.
def identity(item):
    return (item["scope"], item["window"], item["minutes"])
if len({identity(item) for item in windows}) != len(windows):
    raise SystemExit(2)
windows.sort(key=lambda item: (item["scope"], item["minutes"], item["window"]))

if mode == "json":
    print(json.dumps({"windows": windows}, separators=(",", ":"), allow_nan=False))
    raise SystemExit(0)
for item in windows:
    fields = [f"scope={item['scope']}", f"window={item['window']}",
              f"minutes={item['minutes']}"]
    for key in ("used_percent", "reset_at", "reset_after"):
        if key in item:
            fields.append(f"{key}={item[key]}")
    print("QUOTA|" + "|".join(fields))
PY
