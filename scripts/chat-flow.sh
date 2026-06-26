#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="${CHAT_API_BASE_URL:-http://api.ofm.local/v1}"
LOG_FILE="${CHAT_LOG_FILE:-chat-log.txt}"

timestamp="$(date +%s)"
order_id="${CHAT_ORDER_ID:-}"
buyer_id="${CHAT_BUYER_ID:-7c1d1af1-6be8-4e77-8e57-0b1f2d12e9aa}"
seller_id="${CHAT_SELLER_ID:-7c1d1af1-6be8-4e77-8e57-0b1f2d12e9ab}"
buyer_email="${CHAT_BUYER_EMAIL:-${buyer_id}@example.com}"
seller_email="${CHAT_SELLER_EMAIL:-${seller_id}@example.com}"
buyer_username="${CHAT_BUYER_USERNAME:-chat-buyer}"
seller_username="${CHAT_SELLER_USERNAME:-chat-seller}"
jwt_secret="${CHAT_JWT_SECRET:-${JWT_ACCESS_SECRET:-local-dev-secret-change-me}}"
jwt_ttl_seconds="${CHAT_JWT_TTL_SECONDS:-3600}"
chat_cursor="${CHAT_CURSOR:-}"
chat_limit="${CHAT_LIMIT:-20}"

buyer_hello="${CHAT_BUYER_HELLO:-Hello from the buyer.}"
seller_hello="${CHAT_SELLER_HELLO:-Hello from the seller.}"
buyer_followup="${CHAT_BUYER_FOLLOWUP:-I need a small update on the delivery.}"
buyer_followup_edited="${CHAT_BUYER_FOLLOWUP_EDITED:-I need a small update on the delivery, please.}"
seller_followup="${CHAT_SELLER_FOLLOWUP:-Here is a quick response and a file attached.}"
buyer_delete_reason="${CHAT_BUYER_DELETE_REASON:-No longer needed.}"

attachment_files_json="${CHAT_ATTACHMENT_FILES:-[]}"
buyer_attachment_files_json="${CHAT_BUYER_ATTACHMENT_FILES:-[]}"
seller_attachment_files_json="${CHAT_SELLER_ATTACHMENT_FILES:-[]}"

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
    --seller-id)
      seller_id="${2:-}"
      shift 2
      ;;
    --seller-id=*)
      seller_id="${1#*=}"
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
    --seller-email)
      seller_email="${2:-}"
      shift 2
      ;;
    --seller-email=*)
      seller_email="${1#*=}"
      shift
      ;;
    --buyer-username)
      buyer_username="${2:-}"
      shift 2
      ;;
    --buyer-username=*)
      buyer_username="${1#*=}"
      shift
      ;;
    --seller-username)
      seller_username="${2:-}"
      shift 2
      ;;
    --seller-username=*)
      seller_username="${1#*=}"
      shift
      ;;
    --cursor)
      chat_cursor="${2:-}"
      shift 2
      ;;
    --cursor=*)
      chat_cursor="${1#*=}"
      shift
      ;;
    --limit)
      chat_limit="${2:-}"
      shift 2
      ;;
    --limit=*)
      chat_limit="${1#*=}"
      shift
      ;;
    --buyer-hello)
      buyer_hello="${2:-}"
      shift 2
      ;;
    --buyer-hello=*)
      buyer_hello="${1#*=}"
      shift
      ;;
    --seller-hello)
      seller_hello="${2:-}"
      shift 2
      ;;
    --seller-hello=*)
      seller_hello="${1#*=}"
      shift
      ;;
    --buyer-followup)
      buyer_followup="${2:-}"
      shift 2
      ;;
    --buyer-followup=*)
      buyer_followup="${1#*=}"
      shift
      ;;
    --buyer-followup-edited)
      buyer_followup_edited="${2:-}"
      shift 2
      ;;
    --buyer-followup-edited=*)
      buyer_followup_edited="${1#*=}"
      shift
      ;;
    --seller-followup)
      seller_followup="${2:-}"
      shift 2
      ;;
    --seller-followup=*)
      seller_followup="${1#*=}"
      shift
      ;;
    --buyer-delete-reason)
      buyer_delete_reason="${2:-}"
      shift 2
      ;;
    --buyer-delete-reason=*)
      buyer_delete_reason="${1#*=}"
      shift
      ;;
    --attachment-file)
      attachment_files_json="$(jq -nc --argjson current "${attachment_files_json}" --arg path "${2:-}" '$current + [$path]')"
      shift 2
      ;;
    --attachment-file=*)
      attachment_files_json="$(jq -nc --argjson current "${attachment_files_json}" --arg path "${1#*=}" '$current + [$path]')"
      shift
      ;;
    --buyer-attachment-file)
      buyer_attachment_files_json="$(jq -nc --argjson current "${buyer_attachment_files_json}" --arg path "${2:-}" '$current + [$path]')"
      shift 2
      ;;
    --buyer-attachment-file=*)
      buyer_attachment_files_json="$(jq -nc --argjson current "${buyer_attachment_files_json}" --arg path "${1#*=}" '$current + [$path]')"
      shift
      ;;
    --seller-attachment-file)
      seller_attachment_files_json="$(jq -nc --argjson current "${seller_attachment_files_json}" --arg path "${2:-}" '$current + [$path]')"
      shift 2
      ;;
    --seller-attachment-file=*)
      seller_attachment_files_json="$(jq -nc --argjson current "${seller_attachment_files_json}" --arg path "${1#*=}" '$current + [$path]')"
      shift
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${order_id}" ]]; then
  echo "CHAT_ORDER_ID is required" >&2
  exit 1
fi

base64url_encode() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

generate_jwt() {
  local subject="$1"
  local email="$2"
  local username="$3"
  local roles_json="${4:-[]}"
  local now exp header payload signing_input signature

  now="$(date +%s)"
  exp="$((now + jwt_ttl_seconds))"
  header='{"alg":"HS256","typ":"JWT"}'
  payload="$(
    jq -nc \
      --arg sub "$subject" \
      --arg email "$email" \
      --arg username "$username" \
      --argjson roles "$roles_json" \
      --argjson iat "$now" \
      --argjson exp "$exp" \
      '{
        sub: $sub,
        email: $email,
        username: $username,
        roles: $roles,
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

buyer_access_token="${CHAT_BUYER_ACCESS_TOKEN:-$(generate_jwt "$buyer_id" "$buyer_email" "$buyer_username")}"
seller_access_token="${CHAT_SELLER_ACCESS_TOKEN:-$(generate_jwt "$seller_id" "$seller_email" "$seller_username")}"
buyer_auth_header="Authorization: Bearer $buyer_access_token"
seller_auth_header="Authorization: Bearer $seller_access_token"

touch "$LOG_FILE"
: > "$LOG_FILE"

log() {
  printf '%s\n' "$*" | tee -a "$LOG_FILE" >&2
}

log_blank() {
  printf '\n' | tee -a "$LOG_FILE" >&2
}

log_json_file() {
  local file="$1"
  if jq . "$file" >/dev/null 2>&1; then
    jq . "$file" | tee -a "$LOG_FILE" >&2
  else
    cat "$file" | tee -a "$LOG_FILE" >&2
  fi
}

print_section() {
  log_blank
  log "== $1 =="
}

request_json() {
  local auth_header="$1"
  local method="$2"
  local url="$3"
  local payload="$4"
  local body_file="$5"
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

upload_attachment_files() {
  local auth_header="$1"
  local user_id="$2"
  local username="$3"
  local files_json="$4"
  local label="$5"
  local file_ids file_path file_id upload_url content_type size_bytes upload_body upload_status put_status complete_body complete_status

  if ! jq -e . >/dev/null 2>&1 <<<"$files_json"; then
    echo "${label} attachment files must be valid JSON array" >&2
    exit 1
  fi

  if [[ "$(jq 'length' <<<"$files_json")" -eq 0 ]]; then
    printf '[]'
    return 0
  fi
  file_ids="[]"
  while IFS= read -r file_path; do
    if [[ -z "$file_path" ]]; then
      continue
    fi

    if [[ ! -f "$file_path" ]]; then
      echo "${label} attachment file not found: ${file_path}" >&2
      exit 1
    fi

    content_type="$(
      python3 - <<'PY' "$file_path"
import mimetypes
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
mime, _ = mimetypes.guess_type(str(path))
print(mime or "application/octet-stream")
PY
    )"
    size_bytes="$(wc -c <"$file_path" | tr -d ' ')"
    upload_body="$(mktemp)"
    upload_status="$(
      request_json \
        "$auth_header" \
        POST \
        "${API_BASE_URL}/users/${username}/orders/${order_id}/chat/attachments/upload-url" \
        "$(
          jq -nc \
            --arg order_id "$order_id" \
            --arg user_id "$user_id" \
            --arg filename "$(basename "$file_path")" \
            --arg content_type "$content_type" \
            --argjson size_bytes "$size_bytes" \
            '{
              order_id: $order_id,
              user_id: $user_id,
              filename: $filename,
              content_type: $content_type,
              size_bytes: $size_bytes
            }'
        )" \
        "$upload_body"
    )"
    log "HTTP ${upload_status}"
    log_json_file "$upload_body"
    if [[ "$upload_status" != "201" ]]; then
      rm -f "$upload_body"
      echo "${label} attachment upload-url request failed for ${file_path}" >&2
      exit 1
    fi

    file_id="$(jq -r '.file_id // .fileId // empty' "$upload_body")"
    upload_url="$(jq -r '.upload_url // .uploadUrl // empty' "$upload_body")"
    if [[ -z "$file_id" || -z "$upload_url" ]]; then
      rm -f "$upload_body"
      echo "${label} attachment upload-url response missing file metadata" >&2
      exit 1
    fi
    rm -f "$upload_body"

    log "PUT ${upload_url}"
    put_status="$(
      curl -sS \
        -X PUT \
        -H "Content-Type: ${content_type}" \
        --data-binary @"${file_path}" \
        -o /dev/null \
        -w '%{http_code}' \
        "${upload_url}"
    )"
    log "HTTP ${put_status}"
    if [[ "$put_status" != 2* ]]; then
      echo "${label} attachment upload failed for ${file_path}" >&2
      exit 1
    fi

    complete_body="$(mktemp)"
    complete_status="$(
      request_json "$auth_header" POST "${API_BASE_URL}/users/${username}/orders/${order_id}/chat/attachments/complete" "$(jq -nc --arg file_id "$file_id" '{file_id: $file_id}')" "$complete_body"
    )"
    log "HTTP ${complete_status}"
    log_json_file "$complete_body"
    if [[ "$complete_status" != "200" ]]; then
      rm -f "$complete_body"
      echo "${label} attachment completion failed for ${file_path}" >&2
      exit 1
    fi
    rm -f "$complete_body"
    file_ids="$(jq -nc --argjson current "$file_ids" --arg id "$file_id" '$current + [$id]')"
  done < <(jq -r '.[]' <<<"$files_json")

  log "Uploaded ${label} attachment IDs: ${file_ids}"
  printf '%s' "$file_ids"
}

send_message() {
  local auth_header="$1"
  local user_id="$2"
  local username="$3"
  local text="$4"
  local attachment_ids_json="$5"
  local method_label="$6"
  local body_file payload status

  body_file="$(mktemp)"
  payload="$(
    jq -nc \
      --arg order_id "$order_id" \
      --arg user_id "$user_id" \
      --arg text "$text" \
      --argjson attachment_ids "${attachment_ids_json}" \
      '{
        order_id: $order_id,
        user_id: $user_id,
        text: $text,
        attachment_ids: $attachment_ids
      }'
  )"

  log "POST ${API_BASE_URL}/users/${username}/orders/${order_id}/chat/messages"
  log "$payload"
  status="$(
    request_json "$auth_header" POST "${API_BASE_URL}/users/${username}/orders/${order_id}/chat/messages" "$payload" "$body_file"
  )"
  log "HTTP ${status}"
  log_json_file "$body_file"
  if [[ "$status" != "201" ]]; then
    rm -f "$body_file"
    echo "${method_label} message failed" >&2
    exit 1
  fi
  jq -r '.message.message_id // .message.messageId // .message_id // .messageId' "$body_file"
  rm -f "$body_file"
}

edit_message() {
  local auth_header="$1"
  local user_id="$2"
  local username="$3"
  local message_id="$4"
  local text="$5"
  local body_file payload status

  body_file="$(mktemp)"
  payload="$(jq -nc --arg text "$text" '{text: $text}')"
  log "PATCH ${API_BASE_URL}/users/${username}/orders/${order_id}/chat/messages/${message_id}"
  log "$payload"
  status="$(
    request_json "$auth_header" PATCH "${API_BASE_URL}/users/${username}/orders/${order_id}/chat/messages/${message_id}" "$payload" "$body_file"
  )"
  log "HTTP ${status}"
  log_json_file "$body_file"
  if [[ "$status" != "200" ]]; then
    rm -f "$body_file"
    echo "edit message failed" >&2
    exit 1
  fi
  rm -f "$body_file"
}

delete_message() {
  local auth_header="$1"
  local user_id="$2"
  local username="$3"
  local message_id="$4"
  local body_file status

  body_file="$(mktemp)"
  log "DELETE ${API_BASE_URL}/users/${username}/orders/${order_id}/chat/messages/${message_id}"
  status="$(
    request_json "$auth_header" DELETE "${API_BASE_URL}/users/${username}/orders/${order_id}/chat/messages/${message_id}" "" "$body_file"
  )"
  log "HTTP ${status}"
  log_json_file "$body_file"
  if [[ "$status" != "200" ]]; then
    rm -f "$body_file"
    echo "delete message failed" >&2
    exit 1
  fi
  rm -f "$body_file"
}

print_section "Chat conversation"
log "Order ID: $order_id"
log "Buyer ID: $buyer_id"
log "Seller ID: $seller_id"
log "Buyer username: $buyer_username"
log "Seller username: $seller_username"

if [[ "$(jq 'length' <<<"$buyer_attachment_files_json")" -eq 0 ]]; then
  demo_buyer_file="$(mktemp /tmp/chat-buyer-XXXXXX.txt)"
  printf '%s\n' "Buyer attachment demo for order ${order_id}" > "$demo_buyer_file"
  buyer_attachment_files_json="$(jq -nc --arg path "$demo_buyer_file" '[$path]')"
fi

if [[ "$(jq 'length' <<<"$seller_attachment_files_json")" -eq 0 ]]; then
  demo_seller_file="$(mktemp /tmp/chat-seller-XXXXXX.txt)"
  printf '%s\n' "Seller attachment demo for order ${order_id}" > "$demo_seller_file"
  seller_attachment_files_json="$(jq -nc --arg path "$demo_seller_file" '[$path]')"
fi

buyer_attachment_ids=()
seller_attachment_ids=()

if [[ "$(jq 'length' <<<"$buyer_attachment_files_json")" -gt 0 ]]; then
  print_section "Buyer uploads attachments"
  mapfile -t buyer_attachment_ids < <(
    upload_attachment_files "$buyer_auth_header" "$buyer_id" "$buyer_username" "$buyer_attachment_files_json" "buyer" | jq -r '.[]'
  )
fi

if [[ "$(jq 'length' <<<"$seller_attachment_files_json")" -gt 0 ]]; then
  print_section "Seller uploads attachments"
  mapfile -t seller_attachment_ids < <(
    upload_attachment_files "$seller_auth_header" "$seller_id" "$seller_username" "$seller_attachment_files_json" "seller" | jq -r '.[]'
  )
fi

print_section "Buyer hello"
buyer_hello_message_id="$(
  send_message "$buyer_auth_header" "$buyer_id" "$buyer_username" "$buyer_hello" '[]' "buyer hello"
)"
log "Buyer hello message ID: $buyer_hello_message_id"

print_section "Seller hello"
seller_hello_message_id="$(
  send_message "$seller_auth_header" "$seller_id" "$seller_username" "$seller_hello" '[]' "seller hello"
)"
log "Seller hello message ID: $seller_hello_message_id"

print_section "Buyer follow-up"
buyer_followup_message_id="$(
  send_message "$buyer_auth_header" "$buyer_id" "$buyer_username" "$buyer_followup" '[]' "buyer follow-up"
)"
log "Buyer follow-up message ID: $buyer_followup_message_id"

print_section "Buyer edits message"
edit_message "$buyer_auth_header" "$buyer_id" "$buyer_username" "$buyer_followup_message_id" "$buyer_followup_edited"

print_section "Buyer deletes message"
delete_message "$buyer_auth_header" "$buyer_id" "$buyer_username" "$buyer_followup_message_id"

if [[ "${#buyer_attachment_ids[@]}" -gt 0 ]]; then
  print_section "Buyer sends file message"
  buyer_file_message_id="$(
    send_message "$buyer_auth_header" "$buyer_id" "$buyer_username" "${CHAT_BUYER_FILE_MESSAGE:-Here is my file.}" "$(printf '%s\n' "${buyer_attachment_ids[@]}" | jq -R . | jq -s .)" "buyer file"
  )"
  log "Buyer file message ID: $buyer_file_message_id"
fi

if [[ "${#seller_attachment_ids[@]}" -gt 0 ]]; then
  print_section "Seller sends file message"
  seller_file_message_id="$(
    send_message "$seller_auth_header" "$seller_id" "$seller_username" "$seller_followup" "$(printf '%s\n' "${seller_attachment_ids[@]}" | jq -R . | jq -s .)" "seller file"
  )"
  log "Seller file message ID: $seller_file_message_id"
fi

print_section "Fetch chat"
final_body="$(mktemp)"
final_status="$(
  request_json "$buyer_auth_header" GET "${API_BASE_URL}/users/${buyer_username}/orders/${order_id}/chat?cursor=${chat_cursor}&limit=${chat_limit}" "" "$final_body"
)"
log "HTTP ${final_status}"
log_json_file "$final_body"
rm -f "$final_body"

log_blank
log "== Done =="
log "Chat flow completed."
