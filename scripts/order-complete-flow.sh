#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="${ORDER_API_BASE_URL:-http://api.ofm.local/v1}"
REALTIME_WS_URL="${ORDER_REALTIME_WS_URL:-ws://172.21.0.2/ws}"
REALTIME_WS_HOST="${ORDER_REALTIME_WS_HOST:-realtime.ofm.local}"
LOG_FILE="${ORDER_LOG_FILE:-order-complete-log.txt}"
GIG_FLOW_LOG_FILE="${ORDER_GIG_FLOW_LOG_FILE:-gig-log.txt}"

timestamp="$(date +%s)"
buyer_id="${ORDER_BUYER_ID:-7c1d1af1-6be8-4e77-8e57-0b1f2d12e9aa}"
buyer_email="${ORDER_BUYER_EMAIL:-${buyer_id}@example.com}"
seller_id="${ORDER_SELLER_ID:-}"
seller_email="${ORDER_SELLER_EMAIL:-}"
jwt_secret="${ORDER_JWT_SECRET:-${JWT_ACCESS_SECRET:-local-dev-secret-change-me}}"
jwt_ttl_seconds="${ORDER_JWT_TTL_SECONDS:-3600}"
gig_id="${ORDER_GIG_ID:-}"
package_id="${ORDER_PACKAGE_ID:-}"
order_id="${ORDER_ORDER_ID:-}"
realtime_connection_id="${ORDER_REALTIME_CONNECTION_ID:-}"
idempotency_key="${ORDER_IDEMPOTENCY_KEY:-order-${timestamp}}"
delivery_message="${ORDER_DELIVERY_MESSAGE:-I finished the work. Please review the delivery.}"
delivery_attachment_ids="${ORDER_DELIVERY_ATTACHMENT_IDS:-[]}"
realtime_event_file="$(mktemp)"
realtime_connection_file="$(mktemp)"
realtime_listener_pid=""
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${script_dir}/api-gateway-curl.sh"
ofm_api_gateway_configure "$API_BASE_URL" || true

while [[ $# -gt 0 ]]; do
  case "$1" in
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
    --seller-id)
      seller_id="${2:-}"
      shift 2
      ;;
    --seller-id=*)
      seller_id="${1#*=}"
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
    --gig-id)
      gig_id="${2:-}"
      shift 2
      ;;
    --gig-id=*)
      gig_id="${1#*=}"
      shift
      ;;
    --package-id)
      package_id="${2:-}"
      shift 2
      ;;
    --package-id=*)
      package_id="${1#*=}"
      shift
      ;;
    --order-id)
      order_id="${2:-}"
      shift 2
      ;;
    --order-id=*)
      order_id="${1#*=}"
      shift
      ;;
    --realtime-connection-id)
      realtime_connection_id="${2:-}"
      shift 2
      ;;
    --realtime-connection-id=*)
      realtime_connection_id="${1#*=}"
      shift
      ;;
    --delivery-message)
      delivery_message="${2:-}"
      shift 2
      ;;
    --delivery-message=*)
      delivery_message="${1#*=}"
      shift
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

load_gig_defaults_from_log() {
  local log_file="$1"
  local parsed

  if [[ ! -f "$log_file" ]]; then
    return 0
  fi

  parsed="$(
    python3 - "$log_file" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()

gig_id = ""
for line in lines:
    m = re.search(r'Gig ID:\s*([0-9a-f-]+)', line)
    if m:
        gig_id = m.group(1)

package_id = ""
for idx, line in enumerate(lines):
    if '"tier": "basic"' not in line:
        continue
    for back in range(idx, max(idx - 8, -1), -1):
        m = re.search(r'"id":\s*"([0-9a-f-]+)"', lines[back])
        if m:
            package_id = m.group(1)
            break

print(gig_id)
print(package_id)
PY
  )"

  if [[ -n "$parsed" ]]; then
    gig_id="${gig_id:-$(printf '%s\n' "$parsed" | sed -n '1p')}"
    package_id="${package_id:-$(printf '%s\n' "$parsed" | sed -n '2p')}"
  fi
}

if [[ -z "${order_id}" ]]; then
  echo "ORDER_ORDER_ID is required. This script continues an existing order and does not create or confirm checkout." >&2
  exit 1
fi

base64url_encode() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

generate_jwt() {
  local subject="$1"
  local email="$2"
  local username="$3"
  local now exp header payload signing_input signature

  now="$(date +%s)"
  exp="$((now + jwt_ttl_seconds))"
  header='{"alg":"HS256","typ":"JWT"}'
  payload="$(
    jq -nc \
      --arg sub "$subject" \
      --arg email "$email" \
      --arg username "$username" \
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

buyer_access_token="${ORDER_BUYER_ACCESS_TOKEN:-$(generate_jwt "$buyer_id" "$buyer_email" "${ORDER_JWT_USERNAME:-order-complete-buyer}")}"
buyer_auth_header="Authorization: Bearer $buyer_access_token"

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
  local auth_header="$1"
  local method="$2"
  local url="$3"
  local payload="$4"
  local body_file="$5"
  local connection_id="${6:-}"
  local status

  if [[ -n "$payload" ]]; then
    status="$(
      curl -sS \
        "${OFM_API_GATEWAY_CURL_ARGS[@]}" \
        -X "$method" \
        -H 'Content-Type: application/json' \
        -H "$auth_header" \
        -H "Idempotency-Key: $idempotency_key" \
        ${connection_id:+-H "X-Realtime-Connection-Id: $connection_id"} \
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
        ${connection_id:+-H "X-Realtime-Connection-Id: $connection_id"} \
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

require_command curl
require_command jq
require_command python3
require_command openssl

start_realtime_listener() {
  python3 -u - "$REALTIME_WS_URL" "$REALTIME_WS_HOST" "$buyer_access_token" "$realtime_connection_file" "$realtime_event_file" <<'PY' >>"$LOG_FILE" 2>&1 &
import base64
import hashlib
import json
import os
import socket
import ssl
import struct
import sys
import urllib.parse

ws_url, host_header, token, connection_file, event_file = sys.argv[1:6]

def fail(msg):
    print(msg, file=sys.stderr)
    sys.exit(1)

parsed = urllib.parse.urlparse(ws_url)
if parsed.scheme not in ("ws", "wss"):
    fail(f"unsupported websocket scheme: {parsed.scheme}")

host = parsed.hostname
if not host:
    fail("missing websocket host")

port = parsed.port or (443 if parsed.scheme == "wss" else 80)
host_header = host_header or host
path = parsed.path or "/ws"
if parsed.query:
    path = f"{path}?{parsed.query}"
if "token=" not in path:
    sep = "&" if "?" in path else "?"
    path = f"{path}{sep}token={urllib.parse.quote(token)}"

raw = socket.create_connection((host, port), timeout=10)
sock = ssl.create_default_context().wrap_socket(raw, server_hostname=host) if parsed.scheme == "wss" else raw

key = base64.b64encode(os.urandom(16)).decode()
request = (
    f"GET {path} HTTP/1.1\r\n"
    f"Host: {host_header}:{port}\r\n"
    "Upgrade: websocket\r\n"
    "Connection: Upgrade\r\n"
    f"Sec-WebSocket-Key: {key}\r\n"
    "Sec-WebSocket-Version: 13\r\n"
    "\r\n"
)
sock.sendall(request.encode())

response = b""
while b"\r\n\r\n" not in response:
    chunk = sock.recv(4096)
    if not chunk:
        fail("websocket handshake failed")
    response += chunk
header, remainder = response.split(b"\r\n\r\n", 1)
if b"101" not in header.split(b"\r\n", 1)[0]:
    fail(header.decode(errors="replace"))

accept = base64.b64encode(hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest()).decode()
if f"sec-websocket-accept: {accept}".lower().encode() not in header.lower():
    pass

sock.settimeout(None)

def recv_exact(n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise EOFError
        buf += chunk
    return buf

def read_frame(initial=b""):
    data = initial
    if len(data) < 2:
        data += recv_exact(2 - len(data))
    b1, b2 = data[0], data[1]
    opcode = b1 & 0x0F
    masked = bool(b2 & 0x80)
    length = b2 & 0x7F
    idx = 2
    if length == 126:
        more = data[idx:] if len(data) > idx else recv_exact(2)
        if len(more) < 2:
            more += recv_exact(2 - len(more))
        length = struct.unpack("!H", more[:2])[0]
        data = more[2:]
    elif length == 127:
        more = data[idx:] if len(data) > idx else recv_exact(8)
        if len(more) < 8:
            more += recv_exact(8 - len(more))
        length = struct.unpack("!Q", more[:8])[0]
        data = more[8:]
    else:
        data = data[idx:]
    if masked:
        if len(data) < 4:
            data += recv_exact(4 - len(data))
        mask = data[:4]
        data = data[4:]
    else:
        mask = None
    while len(data) < length:
        data += recv_exact(length - len(data))
    payload = data[:length]
    if masked and mask:
        payload = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
    return opcode, payload, data[length:]

buffer = remainder
connection_id = None
while True:
    if len(buffer) < 2:
        buffer += recv_exact(2 - len(buffer))
    opcode, payload, buffer = read_frame(buffer)
    if opcode == 8:
        break
    if opcode == 9:
        continue
    if opcode != 1:
        continue
    try:
        message = json.loads(payload.decode())
    except Exception:
        print(payload.decode(errors="replace"))
        continue
    print(json.dumps(message), flush=True)
    if message.get("type") == "connection.ready" and not connection_id:
        connection_id = message.get("connection_id", "")
        with open(connection_file, "w", encoding="utf-8") as fh:
            fh.write(connection_id)
            fh.flush()
    event_type = message.get("type", "") or message.get("kind", "")
    if event_type:
        with open(event_file, "w", encoding="utf-8") as fh:
            fh.write(event_type)
            fh.flush()
PY
  realtime_listener_pid=$!

  for _ in {1..20}; do
    if [[ -s "$realtime_connection_file" ]]; then
      realtime_connection_id="$(cat "$realtime_connection_file")"
      break
    fi
    sleep 1
  done

  if [[ -z "${realtime_connection_id}" ]]; then
    echo "failed to obtain realtime connection id" >&2
    exit 1
  fi
}

stop_realtime_listener() {
  if [[ -n "${realtime_listener_pid}" ]]; then
    kill "${realtime_listener_pid}" >/dev/null 2>&1 || true
    wait "${realtime_listener_pid}" >/dev/null 2>&1 || true
  fi
  rm -f "$realtime_event_file" "$realtime_connection_file"
}

wait_for_realtime_event() {
  local label="$1"
  shift
  local expected=("$@")
  local current

  while true; do
    if [[ -s "$realtime_event_file" ]]; then
      current="$(cat "$realtime_event_file")"
      for candidate in "${expected[@]}"; do
        if [[ "$current" == "$candidate" ]]; then
          log "Realtime event ($label): $current"
          : > "$realtime_event_file"
          return 0
        fi
      done
    fi
    if ! kill -0 "$realtime_listener_pid" >/dev/null 2>&1; then
      log "realtime listener exited before $label"
      exit 1
    fi
    sleep 1
  done
}

trap stop_realtime_listener EXIT

start_body="$(mktemp)"
confirm_body="$(mktemp)"
deliver_body="$(mktemp)"
accept_body="$(mktemp)"
trap 'rm -f "$start_body" "$confirm_body" "$deliver_body" "$accept_body"; stop_realtime_listener' EXIT

log "----- OFM order complete flow $(date -Is) -----"
log "Log file: $LOG_FILE"
log "API base URL: $API_BASE_URL"
log_blank
log "Buyer ID: $buyer_id"
log "Buyer email: $buyer_email"
log "Order ID: $order_id"
log "Idempotency key: $idempotency_key"

print_section "Realtime handshake"
log "Connecting to realtime service: ${REALTIME_WS_URL}"
start_realtime_listener
log "Realtime connection ID: ${realtime_connection_id}"

if [[ -z "${seller_id}" ]]; then
  echo "ORDER_SELLER_ID is required for delivery/completion flow" >&2
  exit 1
fi
if [[ -z "${seller_email}" ]]; then
  seller_email="${seller_id}@example.com"
fi
seller_access_token="${ORDER_SELLER_ACCESS_TOKEN:-$(generate_jwt "$seller_id" "$seller_email" "${ORDER_SELLER_USERNAME:-order-complete-seller}")}"
seller_auth_header="Authorization: Bearer $seller_access_token"

print_section "Seller delivery"
deliver_payload="$(
  jq -nc \
    --arg message "$delivery_message" \
    --argjson attachment_ids "$delivery_attachment_ids" \
    '{
      delivery_message: $message,
      attachment_ids: $attachment_ids
    }'
)"
log "POST ${API_BASE_URL}/orders/${order_id}/deliver"
log "$deliver_payload"
deliver_status="$(
  request_json "$seller_auth_header" POST "${API_BASE_URL}/orders/${order_id}/deliver" "$deliver_payload" "$deliver_body"
)"
log "HTTP ${deliver_status}"
log_json_file "$deliver_body"

if [[ "$deliver_status" != "200" ]]; then
  echo "deliver order failed" >&2
  exit 1
fi

print_section "Buyer accepts delivery"
accept_payload='{}'
log "POST ${API_BASE_URL}/orders/${order_id}/accept"
log "$accept_payload"
accept_status="$(
  request_json "$buyer_auth_header" POST "${API_BASE_URL}/orders/${order_id}/accept" "$accept_payload" "$accept_body"
)"
log "HTTP ${accept_status}"
log_json_file "$accept_body"

if [[ "$accept_status" != "200" ]]; then
  echo "accept delivery failed" >&2
  exit 1
fi

log "Waiting for realtime completion event..."
wait_for_realtime_event "completion" "order.completed" "order_completed" "payment.funds_released"

log_blank
log "== Done =="
log "Order complete flow finished successfully."
log "Order ID: $order_id"
