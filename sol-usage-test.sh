#!/usr/bin/env bash
# Fixture controls for sol-usage.sh. No network access or real credentials.

set -euo pipefail

script="$(cd "$(dirname "$0")" && pwd)/sol-usage.sh"
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/bin"

cat > "$root/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

prev=
request_file=
for arg in "$@"; do
  # The management secret must never be visible in curl's process arguments.
  case "$arg" in *fixture-management-key*) exit 80 ;; esac
  if [ "$prev" = -H ] && [[ "$arg" == @* ]]; then
    file=${arg#@}
    command grep -qF 'Authorization: Bearer fixture-management-key' "$file"
    [ "$(stat -c %a "$file")" = 600 ]
  elif [ "$prev" = --data-binary ] && [[ "$arg" == @* ]]; then
    request_file=${arg#@}
  fi
  prev=$arg
done

if [ -n "$request_file" ]; then
  command grep -qF '"ChatGPT-Account-ID":"fixture-account-id"' "$request_file"
  ! command grep -qF 'fixture@example.test' "$request_file"
fi

n=0
[ -f "$MOCK_COUNT_FILE" ] && n=$(<"$MOCK_COUNT_FILE")
n=$((n + 1))
printf '%s' "$n" > "$MOCK_COUNT_FILE"

if [ "$n" -eq 1 ]; then
  case "$SCENARIO" in
    success|non2xx|malformed-body|bad-utilization|alias-conflict|unknown-window|missing-windows|wrapper-conflict|duplicate-additional)
      printf '%s\n' '{"files":[{"auth_index":"7","type":"codex","provider":"codex","account_type":"oauth","disabled":false,"unavailable":false,"status":"active","account":"fixture@example.test","id_token":{"chatgpt_account_id":"fixture-account-id"}}]}'
      ;;
    empty)
      printf '%s\n' '{"files":[]}'
      ;;
    ambiguous)
      printf '%s\n' '{"files":[{"auth_index":"7","type":"codex","provider":"codex","account_type":"oauth","disabled":false,"account":"one","id_token":{"chatgpt_account_id":"id-one"}},{"auth_index":"8","type":"codex","provider":"codex","account_type":"oauth","disabled":false,"account":"two","id_token":{"chatgpt_account_id":"id-two"}}]}'
      ;;
    ambiguous-invalid)
      printf '%s\n' '{"files":[{"auth_index":"7","type":"codex","provider":"codex","account_type":"oauth","disabled":false,"id_token":{"chatgpt_account_id":"fixture-account-id"}},{"auth_index":"8","type":"codex","provider":"openai","account_type":"oauth","disabled":false,"id_token":{"chatgpt_account_id":"other-id"}}]}'
      ;;
    auth-envelope-conflict)
      printf '%s\n' '{"files":[{"auth_index":"7","type":"codex","provider":"codex","account_type":"oauth","disabled":false,"id_token":{"chatgpt_account_id":"fixture-account-id"}}],"auth_files":[]}'
      ;;
    unavailable)
      printf '%s\n' '{"files":[{"auth_index":"7","type":"codex","provider":"codex","account_type":"oauth","disabled":false,"unavailable":true,"id_token":{"chatgpt_account_id":"fixture-account-id"}}]}'
      ;;
    api-key)
      printf '%s\n' '{"files":[{"auth_index":"7","type":"codex","provider":"codex","account_type":"api_key","disabled":false,"id_token":{"chatgpt_account_id":"fixture-account-id"}}]}'
      ;;
    provider-conflict)
      printf '%s\n' '{"files":[{"auth_index":"7","type":"codex","provider":"openai","account_type":"oauth","disabled":false,"id_token":{"chatgpt_account_id":"fixture-account-id"}}]}'
      ;;
    status-conflict)
      printf '%s\n' '{"files":[{"auth_index":"7","type":"codex","provider":"codex","account_type":"oauth","disabled":false,"status":"disabled","id_token":{"chatgpt_account_id":"fixture-account-id"}}]}'
      ;;
    status-null)
      printf '%s\n' '{"files":[{"auth_index":"7","type":"codex","provider":"codex","account_type":"oauth","disabled":false,"status":null,"id_token":{"chatgpt_account_id":"fixture-account-id"}}]}'
      ;;
    bad-management)
      exit 22
      ;;
    *) exit 81 ;;
  esac
  exit 0
fi

case "$SCENARIO" in
  success)
    printf '%s\n' '{"status_code":200,"body":"{\"rate_limit\":{\"primary_window\":{\"limit_window_seconds\":604800,\"used_percent\":15,\"reset_at\":1788452680},\"secondary_window\":null},\"code_review_rate_limit\":null,\"additional_rate_limits\":[{\"limit_name\":\"GPT-5.3-Codex-Spark\",\"metered_feature\":\"codex_bengalfox\",\"rate_limit\":{\"primary_window\":{\"limit_window_seconds\":18000,\"used_percent\":0,\"reset_after_seconds\":18000},\"secondary_window\":{\"limit_window_seconds\":604800,\"used_percent\":0,\"reset_after_seconds\":604800}}}]}"}'
    ;;
  non2xx)
    printf '%s\n' '{"status_code":429,"body":"{}"}'
    ;;
  malformed-body)
    printf '%s\n' '{"status_code":200,"body":"not-json"}'
    ;;
  bad-utilization)
    printf '%s\n' '{"status_code":200,"body":"{\"rate_limit\":{\"primary_window\":{\"limit_window_seconds\":604800,\"used_percent\":\"fixture@example.test\"}}}"}'
    ;;
  alias-conflict)
    printf '%s\n' '{"status_code":200,"body":"{\"rate_limit\":{\"primary_window\":{\"limit_window_seconds\":604800,\"used_percent\":15}},\"rateLimit\":{\"primaryWindow\":{\"limitWindowSeconds\":18000,\"usedPercent\":90}},\"code_review_rate_limit\":null,\"codeReviewRateLimit\":{\"primary_window\":{\"limit_window_seconds\":604800,\"used_percent\":25}},\"additional_rate_limits\":null,\"additionalRateLimits\":[{\"limit_name\":\"other\",\"rate_limit\":{\"primary_window\":{\"limit_window_seconds\":18000,\"used_percent\":1}}}]}"}'
    ;;
  unknown-window)
    printf '%s\n' '{"status_code":200,"body":"{\"rate_limit\":{\"primary_window\":{\"limit_window_seconds\":604800,\"used_percent\":15},\"mystery_window\":{\"limit_window_seconds\":18000,\"used_percent\":1}}}"}'
    ;;
  missing-windows)
    printf '%s\n' '{"status_code":200,"body":"{\"rate_limit\":{\"allowed\":true}}"}'
    ;;
  wrapper-conflict)
    printf '%s\n' '{"status_code":200,"statusCode":500,"body":"{\"rate_limit\":{\"primary_window\":{\"limit_window_seconds\":604800,\"used_percent\":15}}}","raw_body":"not-json"}'
    ;;
  duplicate-additional)
    printf '%s\n' '{"status_code":200,"body":"{\"rate_limit\":{\"primary_window\":{\"limit_window_seconds\":604800,\"used_percent\":15}},\"additional_rate_limits\":[{\"limit_name\":\"future-meter\",\"metered_feature\":\"future_feature\",\"rate_limit\":{\"primary_window\":{\"limit_window_seconds\":18000,\"used_percent\":1}}},{\"limit_name\":\"future-meter\",\"metered_feature\":\"future_feature\",\"rate_limit\":{\"primary_window\":{\"limit_window_seconds\":18000,\"used_percent\":1}}}]}"}'
    ;;
  *) exit 82 ;;
esac
MOCK
chmod +x "$root/bin/curl"
printf 'fixture-management-key\n' > "$root/management.key"

run_report() {
  local scenario=$1 mode=$2 stdout=$3 stderr=$4
  rm -f "$root/count"
  PATH="$root/bin:$PATH" MOCK_COUNT_FILE="$root/count" SCENARIO="$scenario" \
    CPA_MANAGEMENT_KEY_FILE="$root/management.key" CPA_BASE_URL=http://127.0.0.1:9 \
    "$script" "$mode" >"$stdout" 2>"$stderr"
}

expect_blind() {
  local scenario=$1 expected_calls=$2
  local stdout="$root/$scenario.out" stderr="$root/$scenario.err" rc
  set +e
  run_report "$scenario" --machine "$stdout" "$stderr"
  rc=$?
  set -e
  [ "$rc" = 2 ]
  [ "$(<"$root/count")" = "$expected_calls" ]
  [ ! -s "$stdout" ]
  command grep -q '^BLIND|' "$stderr"
  ! command grep -qE 'never-print-this|fixture-management-key' "$stderr"
}

# Green arm: a generic `account` identity, a null optional window, and duplicate
# weekly durations in separate scopes must produce three unambiguous windows.
run_report success --machine "$root/success.out" "$root/success.err"
[ "$(<"$root/count")" = 2 ]
[ ! -s "$root/success.err" ]
command grep -qF 'QUOTA|scope=main|window=weekly|minutes=10080|used_percent=15|reset_at=1788452680' "$root/success.out"
command grep -qF 'QUOTA|scope=codex_spark|window=5h|minutes=300|used_percent=0|reset_after=18000' "$root/success.out"
command grep -qF 'QUOTA|scope=codex_spark|window=weekly|minutes=10080|used_percent=0|reset_after=604800' "$root/success.out"
[ "$(command grep -c '^QUOTA|' "$root/success.out")" = 3 ]
! command grep -qE 'never-print-this|fixture-management-key' "$root/success.out"

run_report success --json "$root/success.json" "$root/success-json.err"
python3 - "$root/success.json" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as f:
    payload = json.load(f)
windows = payload.get("windows")
assert isinstance(windows, list) and len(windows) == 3
assert {(w["scope"], w["window"], w["used_percent"]) for w in windows} == {
    ("main", "weekly", 15),
    ("codex_spark", "5h", 0),
    ("codex_spark", "weekly", 0),
}
PY

# Red arms: corpus absence/ambiguity, unusable or contradictory credentials,
# transport failures, invalid quota values, alias conflicts, unknown windows, and
# absent windows must all fail closed.
expect_blind empty 1
expect_blind ambiguous 1
expect_blind ambiguous-invalid 1
expect_blind auth-envelope-conflict 1
expect_blind unavailable 1
expect_blind api-key 1
expect_blind provider-conflict 1
expect_blind status-conflict 1
expect_blind status-null 1
expect_blind bad-management 1
expect_blind non2xx 2
expect_blind malformed-body 2
expect_blind bad-utilization 2
expect_blind alias-conflict 2
expect_blind unknown-window 2
expect_blind missing-windows 2
expect_blind wrapper-conflict 2
expect_blind duplicate-additional 2

# A non-loopback management origin, including userinfo, must fail before curl can
# receive either the management key or the base URL in its argv.
for bad_base in https://example.invalid http://user:secret@127.0.0.1:9; do
  rm -f "$root/count"
  set +e
  PATH="$root/bin:$PATH" MOCK_COUNT_FILE="$root/count" SCENARIO=success \
    CPA_MANAGEMENT_KEY_FILE="$root/management.key" CPA_BASE_URL="$bad_base" \
    "$script" --machine >"$root/bad-base.out" 2>"$root/bad-base.err"
  rc=$?
  set -e
  [ "$rc" = 2 ]
  [ ! -e "$root/count" ]
  [ ! -s "$root/bad-base.out" ]
  command grep -q '^BLIND|' "$root/bad-base.err"
done

# An absent HOME must use the reporter's BLIND contract rather than Bash's rc=1
# unbound-variable abort.
rm -f "$root/count"
set +e
env -u HOME PATH="$root/bin:$PATH" MOCK_COUNT_FILE="$root/count" SCENARIO=success \
  CPA_BASE_URL=http://127.0.0.1:9 "$script" --machine \
  >"$root/no-home.out" 2>"$root/no-home.err"
rc=$?
set -e
[ "$rc" = 2 ]
[ ! -e "$root/count" ]
[ ! -s "$root/no-home.out" ]
command grep -q '^BLIND|' "$root/no-home.err"

# A key containing a carriage return must fail before curl is invoked.
printf 'fixture-management-key\rmalformed\n' > "$root/bad-key"
rm -f "$root/count"
set +e
PATH="$root/bin:$PATH" MOCK_COUNT_FILE="$root/count" SCENARIO=success \
  CPA_MANAGEMENT_KEY_FILE="$root/bad-key" CPA_BASE_URL=http://127.0.0.1:9 \
  "$script" --machine >"$root/bad-key.out" 2>"$root/bad-key.err"
rc=$?
set -e
[ "$rc" = 2 ]
[ ! -e "$root/count" ]
[ ! -s "$root/bad-key.out" ]
command grep -q '^BLIND|' "$root/bad-key.err"

printf 'PASS sol-usage controls\n'
