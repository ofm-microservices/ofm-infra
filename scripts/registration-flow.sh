#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="${API_BASE_URL:-http://api.ofm.local/v1}"
COMPLETE_TIMEOUT_SECONDS="${COMPLETE_TIMEOUT_SECONDS:-60}"
COMPLETE_POLL_SECONDS="${COMPLETE_POLL_SECONDS:-2}"
LOG_FILE="${LOG_FILE:-registration-log.txt}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${script_dir}/api-gateway-curl.sh"
ofm_api_gateway_configure "$API_BASE_URL" || true

touch "$LOG_FILE"

log() {
  printf '%s\n' "$*" | tee -a "$LOG_FILE"
}

log_error() {
  printf '%s\n' "$*" | tee -a "$LOG_FILE" >&2
}

log_blank() {
  printf '\n' | tee -a "$LOG_FILE"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_error "missing required command: $1"
    exit 1
  fi
}

prompt_default() {
  local label="$1"
  local default="$2"
  local value

  read -r -p "$label [$default]: " value
  printf '%s' "${value:-$default}"
}

request_json() {
  local method="$1"
  local url="$2"
  local payload="$3"
  local body_file="$4"
  local status

  status="$(
    curl -sS \
      "${OFM_API_GATEWAY_CURL_ARGS[@]}" \
      -X "$method" \
      -H 'Content-Type: application/json' \
      -d "$payload" \
      -o "$body_file" \
      -w '%{http_code}' \
      "$url"
  )"

  printf '%s' "$status"
}

print_response() {
  local body_file="$1"

  if jq . "$body_file" >/dev/null 2>&1; then
    jq . "$body_file" | tee -a "$LOG_FILE"
    return
  fi

  tee -a "$LOG_FILE" < "$body_file"
  log_blank
}

require_command curl
require_command jq

timestamp="$(date +%s)"
email="${REGISTRATION_EMAIL:-oleksandr.antoniuk@proton.me}"
username="${REGISTRATION_USERNAME:-ofm_user_${timestamp}}"
password="${REGISTRATION_PASSWORD:-Password123!}"
first_name="${REGISTRATION_FIRST_NAME:-Alex}"
surname="${REGISTRATION_SURNAME:-Tester}"
client_id="${REGISTRATION_CLIENT_ID:-cli-${timestamp}}"

log "----- OFM registration flow $(date -Is) -----"
log "Log file: $LOG_FILE"
log "API base URL: $API_BASE_URL"
log_blank
log 'Make sure api-gateway, registration-saga-service, user-service, auth-service, mail-service, NATS, Scylla, and Yugabyte are running.'
log_blank

if ! curl -sS "${OFM_API_GATEWAY_CURL_ARGS[@]}" --connect-timeout 2 "$API_BASE_URL/auth/sign-up" >/dev/null 2>&1; then
  log_error "api-gateway is not reachable at $API_BASE_URL"
  log_error 'Start the services first, then rerun this script.'
  exit 1
fi

log "Email: $email"
log "Username: $username"
log "Password: [configured]"
log "First name: $first_name"
log "Surname: $surname"
log "Client ID: $client_id"
log_blank

signup_payload="$(
  jq -n \
    --arg client_id "$client_id" \
    --arg email "$email" \
    --arg password "$password" \
    --arg username "$username" \
    --arg firstName "$first_name" \
    --arg surname "$surname" \
    '{
      client_id: $client_id,
      email: $email,
      password: $password,
      username: $username,
      firstName: $firstName,
      surname: $surname
    }'
)"

signup_body="$(mktemp)"
verify_body="$(mktemp)"
complete_body="$(mktemp)"
trap 'rm -f "$signup_body" "$verify_body" "$complete_body"; ofm_api_gateway_cleanup' EXIT

log 'Starting registration and triggering verification email...'
log "POST $API_BASE_URL/auth/sign-up"
log "$signup_payload"
signup_status="$(request_json POST "$API_BASE_URL/auth/sign-up" "$signup_payload" "$signup_body")"
log "HTTP $signup_status"
print_response "$signup_body"

if [[ "$signup_status" != "202" ]]; then
  log_error "sign-up failed with HTTP $signup_status"
  exit 1
fi

session_id="$(jq -r '.session_id // empty' "$signup_body")"
response_client_id="$(jq -r '.client_id // empty' "$signup_body")"

if [[ -z "$session_id" || -z "$response_client_id" ]]; then
  log_error 'sign-up response did not include session_id/client_id'
  exit 1
fi

log_blank
log 'Registration accepted.'
log "Session ID: $session_id"
log "Client ID:  $response_client_id"
log_blank
log 'Wait for the email, then enter the verification code.'
read -r -p 'Verification code: ' code
log 'Verification code: [entered]'

verify_payload="$(
  jq -n \
    --arg session_id "$session_id" \
    --arg client_id "$response_client_id" \
    --arg code "$code" \
    '{
      session_id: $session_id,
      client_id: $client_id,
      code: $code
    }'
)"

log_blank
log 'Submitting verification code...'
log "POST $API_BASE_URL/auth/sign-up/verify-email"
log "$verify_payload"
verify_status="$(request_json POST "$API_BASE_URL/auth/sign-up/verify-email" "$verify_payload" "$verify_body")"
log "HTTP $verify_status"
print_response "$verify_body"

if [[ "$verify_status" != "202" ]]; then
  log_error "verify-email failed with HTTP $verify_status"
  exit 1
fi

complete_payload="$(
  jq -n \
    --arg session_id "$session_id" \
    --arg client_id "$response_client_id" \
    '{
      session_id: $session_id,
      client_id: $client_id
    }'
)"

log_blank
log 'Waiting for saga completion and token exchange...'
deadline=$((SECONDS + COMPLETE_TIMEOUT_SECONDS))
while (( SECONDS <= deadline )); do
  log "POST $API_BASE_URL/auth/sign-up/complete"
  log "$complete_payload"
  complete_status="$(request_json POST "$API_BASE_URL/auth/sign-up/complete" "$complete_payload" "$complete_body")"
  log "HTTP $complete_status"
  if [[ "$complete_status" == "200" ]]; then
    log 'Registration completed. Tokens:'
    print_response "$complete_body"
    exit 0
  fi

  if [[ "$complete_status" != "409" ]]; then
    log_error "complete failed with HTTP $complete_status"
    print_response "$complete_body"
    exit 1
  fi

  print_response "$complete_body"
  log "Registration not completed yet. Retrying in ${COMPLETE_POLL_SECONDS}s..."
  sleep "$COMPLETE_POLL_SECONDS"
done

log_error "timed out waiting for registration completion after ${COMPLETE_TIMEOUT_SECONDS}s"
print_response "$complete_body"
exit 1
