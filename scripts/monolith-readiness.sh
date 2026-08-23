#!/usr/bin/env bash
set -Eeuo pipefail

# Monolith v2 readiness runner. It deliberately uses curl so it can run from
# a CI runner or an operator shell without starting application processes.
# Writes are opt-in: use --run-writes against an isolated test environment.

BASE_URL="${MONOLITH_BASE_URL:-http://127.0.0.1:8000/api/v2}"
METRICS_URL="${MONOLITH_METRICS_URL:-http://127.0.0.1:9600/metrics}"
RESOLVE_IP="${MONOLITH_RESOLVE_IP:-}"
PROJECTION_CHECK_URL="${MONOLITH_PROJECTION_CHECK_URL:-}"
TOKEN="${MONOLITH_TOKEN:-}"
USERNAME="${MONOLITH_USERNAME:-}"
RUN_WRITES=false
REPORT="${MONOLITH_READINESS_REPORT:-monolith-readiness-report.json}"
FAILURES=0
CHECKS=0

usage() {
  cat <<'EOF'
Usage: monolith-readiness.sh [options]

Options:
  --base-url URL       v2 base URL (default: http://127.0.0.1:8000/api/v2)
  --token JWT          bearer token for authenticated routes
  --username NAME      username used for user-scoped routes
  --run-writes         run destructive/write flow against the test environment
  --report FILE        write JSON report (default: monolith-readiness-report.json)
  --help               show this help

The runner always checks route reachability, metrics, and optional projection
health. It checks write routes for a valid application response only when
--run-writes is supplied.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url) BASE_URL="$2"; shift 2;;
    --token) TOKEN="$2"; shift 2;;
    --username) USERNAME="$2"; shift 2;;
    --run-writes) RUN_WRITES=true; shift;;
    --report) REPORT="$2"; shift 2;;
    --help) usage; exit 0;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2;;
  esac
done

BASE_URL="${BASE_URL%/}"
if [[ -z "$RESOLVE_IP" && "$BASE_URL" =~ ^http://monolith\.ofm\.local(:[0-9]+)?/ ]]; then
  RESOLVE_IP="172.22.0.2"
fi
RESOLVE_ARGS=()
if [[ -n "$RESOLVE_IP" && "$BASE_URL" =~ ^http://([^/:]+)(:([0-9]+))?/ ]]; then
  RESOLVE_ARGS=(--resolve "${BASH_REMATCH[1]}:${BASH_REMATCH[3]:-80}:$RESOLVE_IP")
fi
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
record() {
  local name="$1" method="$2" path="$3" status="$4" result="$5"
  CHECKS=$((CHECKS + 1))
  [[ "$result" == "pass" ]] || FAILURES=$((FAILURES + 1))
  printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$method" "$path" "$status" "$result" >> "$TMP_DIR/results"
}

request() {
  local name="$1" method="$2" path="$3" body="${4:-}" allow_not_found="${5:-false}"
  local response status
  local args=(-sS -o "$TMP_DIR/body" -w '%{http_code}' -X "$method" "$BASE_URL$path" \
    -H 'Accept: application/json' -H 'Content-Type: application/json')
  args+=("${RESOLVE_ARGS[@]}")
  [[ -n "$TOKEN" ]] && args+=(-H "Authorization: Bearer $TOKEN")
  [[ -n "$body" ]] && args+=(--data "$body")
  status="$(curl "${args[@]}" 2>"$TMP_DIR/curl-error" || true)"
  if [[ -z "$status" || "$status" == "000" ]]; then
    record "$name" "$method" "$path" "000" fail
    return 0
  fi
  # 404/405/5xx mean the route is missing or the server is unhealthy. 401/403
  # are acceptable for authenticated reachability checks without a token.
  if [[ "$status" == "404" && "$allow_not_found" == true ]]; then
    record "$name" "$method" "$path" "$status" pass
  elif [[ "$status" =~ ^(404|405|5[0-9][0-9])$ ]]; then
    record "$name" "$method" "$path" "$status" fail
  else
    record "$name" "$method" "$path" "$status" pass
  fi
}

check_metrics() {
  local status body
  body="$(curl -fsS -o "$TMP_DIR/metrics" -w '%{http_code}' "$METRICS_URL" 2>/dev/null || true)"
  if [[ "$body" == "200" ]] && rg -q 'ofm_http_|ofm_db_|ofm_kafka_|ofm_projection|# HELP|# TYPE' "$TMP_DIR/metrics"; then
    record observability-metrics GET "$METRICS_URL" 200 pass
  else
    record observability-metrics GET "$METRICS_URL" "${body:-000}" fail
  fi
}

check_projection() {
  [[ -z "$PROJECTION_CHECK_URL" ]] && return 0
  local status
  status="$(curl -sS -o "$TMP_DIR/projection" -w '%{http_code}' "$PROJECTION_CHECK_URL" 2>/dev/null || true)"
  [[ "$status" == "200" ]] && record projection-health GET "$PROJECTION_CHECK_URL" "$status" pass || record projection-health GET "$PROJECTION_CHECK_URL" "$status" fail
}

check_metrics
check_projection

# Every public v2 route is listed explicitly. Safe GETs are always exercised.
request search GET '/search?q=test'
if [[ -n "$USERNAME" ]]; then
  request user-profile GET "/users/$USERNAME" '' true
  request user-gigs GET "/users/$USERNAME/gigs" '' true
  request user-orders GET "/users/$USERNAME/orders/00000000-0000-0000-0000-000000000000" '' true
  request user-requirements GET "/users/$USERNAME/orders/00000000-0000-0000-0000-000000000000/requirements" '' true
  request user-delivery GET "/users/$USERNAME/orders/00000000-0000-0000-0000-000000000000/delivery" '' true
fi

if [[ "$RUN_WRITES" == true ]]; then
  if [[ -z "$TOKEN" ]]; then
    echo '--run-writes requires --token' >&2
    exit 2
  fi
  id="$(date +%s)-$$"
  key="readiness-$id"
  request auth-refresh POST '/auth/refresh' '{"refresh_token":"invalid-readiness-token"}'
  request onboarding-start POST '/freelancer/onboarding/start' '{"idempotency_key":"'"$key"'"}'
  request gig-draft POST '/gigs/drafts' '{"title":"readiness-'"$id"'","description":"readiness probe"}'
  request order-start POST '/orders/start' '{"gig_id":"00000000-0000-0000-0000-000000000000","package_id":"00000000-0000-0000-0000-000000000000"}'

  # Reach every remaining write route as well. The intentionally invalid
  # aggregate IDs exercise routing, auth, validation and error mapping without
  # mutating a real aggregate; successful business flows are covered by the
  # dedicated flow scripts and E2E suites.
  for spec in \
    'auth-sign-up|POST|/auth/sign-up' \
    'auth-verify|POST|/auth/sign-up/verify-email' \
    'auth-complete|POST|/auth/sign-up/complete' \
    'auth-sign-in|POST|/auth/sign-in' \
    'auth-sign-out|POST|/auth/sign-out' \
    'gig-basic-info|PATCH|/gigs/00000000-0000-0000-0000-000000000000/basic-info' \
    'gig-media|PUT|/gigs/00000000-0000-0000-0000-000000000000/media' \
    'gig-packages|PUT|/gigs/00000000-0000-0000-0000-000000000000/packages' \
    'gig-publish|POST|/gigs/00000000-0000-0000-0000-000000000000/publish' \
    'gig-requirements|PUT|/gigs/00000000-0000-0000-0000-000000000000/requirements' \
    'order-confirm|POST|/orders/00000000-0000-0000-0000-000000000000/confirm' \
    'order-requirements|POST|/orders/00000000-0000-0000-0000-000000000000/requirements' \
    'order-message|POST|/orders/00000000-0000-0000-0000-000000000000/message' \
    'order-deliver|POST|/orders/00000000-0000-0000-0000-000000000000/deliver' \
    'order-accept|POST|/orders/00000000-0000-0000-0000-000000000000/accept' \
    'order-revision|POST|/orders/00000000-0000-0000-0000-000000000000/request-revision' \
    'order-dispute|POST|/orders/00000000-0000-0000-0000-000000000000/dispute' \
    'order-resolve-dispute|POST|/orders/00000000-0000-0000-0000-000000000000/dispute/resolve' \
    'order-review|POST|/orders/00000000-0000-0000-0000-000000000000/reviews' \
    'chat-message|POST|/users/readiness/orders/00000000-0000-0000-0000-000000000000/chat/messages' \
    'chat-edit|PATCH|/users/readiness/orders/00000000-0000-0000-0000-000000000000/chat/messages/00000000-0000-0000-0000-000000000000' \
    'chat-delete|DELETE|/users/readiness/orders/00000000-0000-0000-0000-000000000000/chat/messages/00000000-0000-0000-0000-000000000000' \
    'chat-upload-url|POST|/users/readiness/orders/00000000-0000-0000-0000-000000000000/chat/attachments/upload-url' \
    'chat-upload-complete|POST|/users/readiness/orders/00000000-0000-0000-0000-000000000000/chat/attachments/complete'; do
    IFS='|' read -r name method path <<< "$spec"
    request "$name" "$method" "$path" '{}'
  done
fi

{
  echo '{"base_url":"'"$(json_escape "$BASE_URL")"'","run_writes":'"$RUN_WRITES"',"checks":['
  first=true
  while IFS=$'\t' read -r name method path status result; do
    $first || echo ','
    first=false
    printf '  {"name":"%s","method":"%s","path":"%s","status":%s,"result":"%s"}' \
      "$(json_escape "$name")" "$(json_escape "$method")" "$(json_escape "$path")" "$status" "$result"
  done < "$TMP_DIR/results"
  echo '],"failures":'"$FAILURES"'}'
} > "$REPORT"

cat "$REPORT"
echo
if (( FAILURES > 0 )); then
  echo "READINESS: FAIL ($FAILURES/$CHECKS checks failed)" >&2
  exit 1
fi
echo "READINESS: PASS ($CHECKS checks)"
