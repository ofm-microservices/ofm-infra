#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="${REVIEW_API_BASE_URL:-http://api.ofm.local/v1}"
LOG_FILE="${REVIEW_LOG_FILE:-review-log.txt}"

timestamp="$(date +%s)"
order_id="${ORDER_ORDER_ID:-}"
buyer_id="${REVIEW_BUYER_ID:-${ORDER_BUYER_ID:-7c1d1af1-6be8-4e77-8e57-0b1f2d12e9aa}}"
buyer_email="${REVIEW_BUYER_EMAIL:-${buyer_id}@example.com}"
buyer_username="${REVIEW_JWT_USERNAME:-review-flow}"
jwt_secret="${REVIEW_JWT_SECRET:-${JWT_ACCESS_SECRET:-local-dev-secret-change-me}}"
jwt_ttl_seconds="${REVIEW_JWT_TTL_SECONDS:-3600}"
gig_id="${ORDER_GIG_ID:-${REVIEW_GIG_ID:-}}"
review_content="${REVIEW_CONTENT:-Great work. Thanks for the delivery.}"
review_rating="${REVIEW_RATING:-5}"
idempotency_key="${REVIEW_IDEMPOTENCY_KEY:-review-${timestamp}}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${script_dir}/api-gateway-curl.sh"
ofm_api_gateway_configure "$API_BASE_URL" || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --order-id)
      order_id="${2:-}"
      shift 2
      ;;
    --order-id=*)
      order_id="${1#*=}"
      shift
      ;;
    --buyer-id)
      buyer_id="${2:-}"
      shift 2
      ;;
    --buyer-id=*)
      buyer_id="${1#*=}"
      shift
      ;;
    --buyer-email)
      buyer_email="${2:-}"
      shift 2
      ;;
    --buyer-email=*)
      buyer_email="${1#*=}"
      shift
      ;;
    --gig-id)
      gig_id="${2:-}"
      shift 2
      ;;
    --gig-id=*)
      gig_id="${1#*=}"
      shift
      ;;
    --content)
      review_content="${2:-}"
      shift 2
      ;;
    --content=*)
      review_content="${1#*=}"
      shift
      ;;
    --rating)
      review_rating="${2:-}"
      shift 2
      ;;
    --rating=*)
      review_rating="${1#*=}"
      shift
      ;;
    --idempotency-key)
      idempotency_key="${2:-}"
      shift 2
      ;;
    --idempotency-key=*)
      idempotency_key="${1#*=}"
      shift
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${order_id}" ]]; then
  echo "ORDER_ORDER_ID is required." >&2
  exit 1
fi

base64url_encode() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

generate_jwt() {
  local now exp header payload signing_input signature

  now="$(date +%s)"
  exp="$((now + jwt_ttl_seconds))"
  header='{"alg":"HS256","typ":"JWT"}'
  payload="$(
    jq -nc \
      --arg sub "$buyer_id" \
      --arg email "$buyer_email" \
      --arg username "$buyer_username" \
      --argjson iat "$now" \
      --argjson exp "$exp" \
      '{
        sub: $sub,
        email: $email,
        username: $username,
        iat: $iat,
        exp: $exp
      }'
  )"

  signing_input="$(
    {
      printf '%s' "$header" | base64url_encode
      printf '.'
      printf '%s' "$payload" | base64url_encode
    }
  )"

  signature="$(
    printf '%s' "$signing_input" |
      openssl dgst -binary -sha256 -hmac "$jwt_secret" |
      base64url_encode
  )"

  printf '%s.%s' "$signing_input" "$signature"
}

access_token="${REVIEW_ACCESS_TOKEN:-$(generate_jwt)}"
auth_header="Authorization: Bearer $access_token"

touch "$LOG_FILE"
: > "$LOG_FILE"

log() {
  printf '%s\n' "$*" | tee -a "$LOG_FILE"
}

log_blank() {
  printf '\n' | tee -a "$LOG_FILE"
}

log_json_file() {
  local file="$1"
  if jq . "$file" >/dev/null 2>&1; then
    jq . "$file" | tee -a "$LOG_FILE"
  else
    cat "$file" | tee -a "$LOG_FILE"
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "missing required command: $1"
    exit 1
  fi
}

request_json() {
  local method="$1"
  local url="$2"
  local payload="$3"
  local body_file="$4"
  local status

  if [[ -n "$payload" ]]; then
    status="$(
      curl -sS \
        "${OFM_API_GATEWAY_CURL_ARGS[@]}" \
        -X "$method" \
        -H 'Content-Type: application/json' \
        -H "$auth_header" \
        -H "Idempotency-Key: $idempotency_key" \
        -d "$payload" \
        -o "$body_file" \
        -w '%{http_code}' \
        "$url"
    )"
  else
    status="$(
      curl -sS \
        "${OFM_API_GATEWAY_CURL_ARGS[@]}" \
        -X "$method" \
        -H "$auth_header" \
        -H "Idempotency-Key: $idempotency_key" \
        -o "$body_file" \
        -w '%{http_code}' \
        "$url"
    )"
  fi

  printf '%s' "$status"
}

require_command curl
require_command jq
require_command openssl
require_command python3

print_section() {
  log_blank
  log "== $1 =="
}

review_payload() {
  jq -nc --arg content "$review_content" --argjson rating "$review_rating" '{content: $content, rating: $rating}'
}

log "----- OFM review flow $(date --iso-8601=seconds) -----"
log "Log file: $LOG_FILE"
log "API base URL: $API_BASE_URL"
log ""
log "Buyer ID: $buyer_id"
log "Buyer email: $buyer_email"
log "Order ID: $order_id"
log "Gig ID: ${gig_id:-<not provided>}"
log "Rating: $review_rating"
log "Idempotency key: $idempotency_key"

print_section "Create review"
create_file="$(mktemp)"
payload="$(review_payload)"
log "$payload"
status="$(request_json POST "${API_BASE_URL}/orders/${order_id}/reviews" "$payload" "$create_file")"
log "HTTP $status"
log_json_file "$create_file"
rm -f "$create_file"
if [[ "$status" != 2* ]]; then
  log "create review failed"
  exit 1
fi

log_blank
log "Review flow finished successfully."
