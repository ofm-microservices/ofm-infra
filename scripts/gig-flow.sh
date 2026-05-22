#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="${GIG_API_BASE_URL:-http://api.ofm.local/v1}"
NATS_MONITOR_URL="${GIG_NATS_MONITOR_URL:-http://127.0.0.1:8222/jsz?streams=1}"
LOG_FILE="${GIG_LOG_FILE:-gig-log.txt}"
GIG_STREAM_NAME="${GIG_STREAM_NAME:-GIG_EVENTS}"
GIG_CONNECTED="${GIG_CONNECTED:-true}"
GIG_CONNECTED_FREELANCER_ID="${GIG_CONNECTED_FREELANCER_ID:-aeac656a-e617-45f2-b1ce-b922d8bd03fa}"

timestamp="$(date +%s)"
freelancer_id="${GIG_FREELANCER_ID:-$GIG_CONNECTED_FREELANCER_ID}"
title="${GIG_TITLE:-Gig title ${timestamp}}"
description="${GIG_DESCRIPTION:-A gig created by the gig-flow script}"
category_id="${GIG_CATEGORY_ID:-1001}"
currency="${GIG_CURRENCY:-usd}"
jwt_secret="${GIG_JWT_SECRET:-${JWT_ACCESS_SECRET:-local-dev-secret-change-me}}"
jwt_ttl_seconds="${GIG_JWT_TTL_SECONDS:-3600}"
basic_description="${GIG_BASIC_DESCRIPTION:-Basic package for the gig}"
basic_delivery_days="${GIG_BASIC_DELIVERY_DAYS:-3}"
basic_price_cents="${GIG_BASIC_PRICE_CENTS:-10000}"
standard_description="${GIG_STANDARD_DESCRIPTION:-Standard package for the gig}"
standard_delivery_days="${GIG_STANDARD_DELIVERY_DAYS:-5}"
standard_price_cents="${GIG_STANDARD_PRICE_CENTS:-20000}"
premium_description="${GIG_PREMIUM_DESCRIPTION:-Premium package for the gig}"
premium_delivery_days="${GIG_PREMIUM_DELIVERY_DAYS:-7}"
premium_price_cents="${GIG_PREMIUM_PRICE_CENTS:-30000}"

question_1="${GIG_QUESTION_1:-What do you need built?}"
question_2="${GIG_QUESTION_2:-Do you have a reference or brand guide?}"

cover_image_path="${GIG_COVER_IMAGE_PATH:-/home/alex/Downloads/ainz.jpg}"
gallery_image_path="${GIG_GALLERY_IMAGE_PATH:-/home/alex/Downloads/yagami.jpg}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${script_dir}/api-gateway-curl.sh"
ofm_api_gateway_configure "$API_BASE_URL" || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --connected)
      GIG_CONNECTED="${2:-}"
      shift 2
      ;;
    --connected=*)
      GIG_CONNECTED="${1#*=}"
      shift
      ;;
    --freelancer-id)
      freelancer_id="${2:-}"
      shift 2
      ;;
    --freelancer-id=*)
      freelancer_id="${1#*=}"
      shift
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

case "${GIG_CONNECTED,,}" in
  true)
    freelancer_id="${freelancer_id:-$GIG_CONNECTED_FREELANCER_ID}"
    ;;
  false)
    freelancer_id="${freelancer_id:-freelancer-${timestamp}}"
    ;;
  *)
    echo "GIG_CONNECTED must be true or false" >&2
    exit 1
    ;;
esac

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
      --arg sub "$freelancer_id" \
      --arg email "$freelancer_id@example.com" \
      --arg username "${GIG_JWT_USERNAME:-gig-flow}" \
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

access_token="${GIG_ACCESS_TOKEN:-$(generate_jwt)}"
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
    return
  fi

  cat "$file" | tee -a "$LOG_FILE"
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
        -o "$body_file" \
        -w '%{http_code}' \
        "$url"
    )"
  fi

  printf '%s' "$status"
}

print_section() {
  log_blank
  log "== $1 =="
}

print_nats_state() {
  print_section "NATS stream state"
  if ! nats_json="$(curl -fsS "$NATS_MONITOR_URL")"; then
    log "<nats monitoring unavailable>"
    return
  fi

  stream_state="$(
    printf '%s\n' "$nats_json" | jq -c --arg stream "$GIG_STREAM_NAME" '
    .. | objects
    | select((.name? == $stream) or (.config?.name? == $stream))
    | {
        name: (.name // .config.name),
        messages: (.messages // .state.messages // null),
        bytes: (.bytes // .state.bytes // null),
        consumers: (.consumers // .state.consumers // null)
      }
    ' | head -n 1
  )"

  if [[ -z "$stream_state" ]]; then
    log "<stream not found>"
    return
  fi

  printf '%s\n' "$stream_state" | tee -a "$LOG_FILE"
}

require_command curl
require_command jq

draft_body="$(mktemp)"
basic_body="$(mktemp)"
packages_body="$(mktemp)"
questions_body="$(mktemp)"
media_body="$(mktemp)"
publish_body="$(mktemp)"
get_body="$(mktemp)"
trap 'rm -f "$draft_body" "$basic_body" "$packages_body" "$questions_body" "$media_body" "$publish_body" "$get_body"; ofm_api_gateway_cleanup' EXIT

log "----- OFM gig flow $(date -Is) -----"
log "Log file: $LOG_FILE"
log "API base URL: $API_BASE_URL"
log "NATS monitoring URL: $NATS_MONITOR_URL"
log_blank
log "Freelancer ID: $freelancer_id"
log "Connected: ${GIG_CONNECTED,,}"
log "Title: $title"
log "Description: $description"
log "Category ID: $category_id"
log "Currency: $currency"
log "JWT subject: $freelancer_id"
log "Cover image path: $cover_image_path"
log "Gallery image path: $gallery_image_path"
log_blank
log "Package tiers: basic, standard, premium"
log "Questions: 2"
log "Media files: 2"

if [[ ! -f "$cover_image_path" ]]; then
  log "cover image not found: $cover_image_path"
  exit 1
fi
if [[ ! -f "$gallery_image_path" ]]; then
  log "gallery image not found: $gallery_image_path"
  exit 1
fi

api_status="$(curl -sS "${OFM_API_GATEWAY_CURL_ARGS[@]}" --connect-timeout 2 -o /dev/null -w '%{http_code}' "$API_BASE_URL" || true)"
if [[ "$api_status" == "000" ]]; then
  log "api-gateway is not reachable at $API_BASE_URL"
  exit 1
fi

print_section "Create draft"
create_payload="$(
  jq -n '{}'
)"
log "POST $API_BASE_URL/gigs/drafts"
log "$create_payload"
create_status="$(request_json POST "$API_BASE_URL/gigs/drafts" "$create_payload" "$draft_body")"
log "HTTP $create_status"
log_json_file "$draft_body"
if [[ "$create_status" != "202" ]]; then
  log "create draft failed"
  exit 1
fi

gig_id="$(jq -r '.gig_id // empty' "$draft_body")"
if [[ -z "$gig_id" ]]; then
  log "create draft response did not include gig_id"
  exit 1
fi

log_blank
log "Gig ID: $gig_id"
print_nats_state

print_section "Update basic info"
basic_payload="$(
  jq -n \
    --arg gig_id "$gig_id" \
    --arg title "$title" \
    --arg description "$description" \
    --argjson category_id "$category_id" \
    --arg currency "$currency" \
    '{
      gig_id: $gig_id,
      title: $title,
      description: $description,
      category_id: $category_id,
      currency: $currency
    }'
)"
log "PATCH $API_BASE_URL/gigs/$gig_id/basic-info"
log "$basic_payload"
basic_status="$(request_json PATCH "$API_BASE_URL/gigs/$gig_id/basic-info" "$basic_payload" "$basic_body")"
log "HTTP $basic_status"
log_json_file "$basic_body"
if [[ "$basic_status" != "200" ]]; then
  log "update basic info failed"
  exit 1
fi
print_nats_state

print_section "Replace packages"
packages_payload="$(
  jq -n \
    --arg gig_id "$gig_id" \
    --arg basic_description "$basic_description" \
    --argjson basic_delivery_days "$basic_delivery_days" \
    --argjson basic_price_cents "$basic_price_cents" \
    --arg standard_description "$standard_description" \
    --argjson standard_delivery_days "$standard_delivery_days" \
    --argjson standard_price_cents "$standard_price_cents" \
    --arg premium_description "$premium_description" \
    --argjson premium_delivery_days "$premium_delivery_days" \
    --argjson premium_price_cents "$premium_price_cents" \
    '{
      gig_id: $gig_id,
      packages: [
        {
          tier: "basic",
          description: $basic_description,
          delivery_days: $basic_delivery_days,
          price_cents: $basic_price_cents
        },
        {
          tier: "standard",
          description: $standard_description,
          delivery_days: $standard_delivery_days,
          price_cents: $standard_price_cents
        },
        {
          tier: "premium",
          description: $premium_description,
          delivery_days: $premium_delivery_days,
          price_cents: $premium_price_cents
        }
      ]
    }'
)"
log "PUT $API_BASE_URL/gigs/$gig_id/packages"
log "$packages_payload"
packages_status="$(request_json PUT "$API_BASE_URL/gigs/$gig_id/packages" "$packages_payload" "$packages_body")"
log "HTTP $packages_status"
log_json_file "$packages_body"
if [[ "$packages_status" != "200" ]]; then
  log "replace packages failed"
  exit 1
fi
print_nats_state

print_section "Replace questions"
questions_payload="$(
  jq -n \
    --arg gig_id "$gig_id" \
    --arg q1 "$question_1" \
    --arg q2 "$question_2" \
    '{
      gig_id: $gig_id,
      questions: [
        {content: $q1},
        {content: $q2}
      ]
    }'
)"
log "PUT $API_BASE_URL/gigs/$gig_id/requirements"
log "$questions_payload"
questions_status="$(request_json PUT "$API_BASE_URL/gigs/$gig_id/requirements" "$questions_payload" "$questions_body")"
log "HTTP $questions_status"
log_json_file "$questions_body"
if [[ "$questions_status" != "200" ]]; then
  log "replace questions failed"
  exit 1
fi
print_nats_state

print_section "Replace media"
log "PUT $API_BASE_URL/gigs/$gig_id/media"
log "multipart form fields: files=@$cover_image_path, files=@$gallery_image_path"
media_status="$(
  curl -sS \
    "${OFM_API_GATEWAY_CURL_ARGS[@]}" \
    -X PUT \
    -H "$auth_header" \
    -F "files=@${cover_image_path}" \
    -F "files=@${gallery_image_path}" \
    -o "$media_body" \
    -w '%{http_code}' \
    "$API_BASE_URL/gigs/$gig_id/media"
)"
log "HTTP $media_status"
log_json_file "$media_body"
if [[ "$media_status" != "200" ]]; then
  log "replace media failed"
  exit 1
fi
print_nats_state

print_section "Get draft"
log "GET $API_BASE_URL/gigs/$gig_id/draft"
get_status="$(request_json GET "$API_BASE_URL/gigs/$gig_id/draft" "" "$get_body")"
log "HTTP $get_status"
log_json_file "$get_body"
if [[ "$get_status" != "200" ]]; then
  log "get draft failed"
  exit 1
fi

print_section "Publish"
publish_payload="$(
  jq -n \
    --arg gig_id "$gig_id" \
    '{
      gig_id: $gig_id
    }'
)"
log "POST $API_BASE_URL/gigs/$gig_id/publish"
log "$publish_payload"
publish_status="$(request_json POST "$API_BASE_URL/gigs/$gig_id/publish" "$publish_payload" "$publish_body")"
log "HTTP $publish_status"
log_json_file "$publish_body"
if [[ "$publish_status" != "202" ]]; then
  log "publish failed"
  exit 1
fi

print_nats_state

print_section "Done"
log "Gig flow completed successfully."
log "Gig ID: $gig_id"
log "Freelancer ID: $freelancer_id"
