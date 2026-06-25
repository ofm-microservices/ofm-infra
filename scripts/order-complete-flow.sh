#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="${ORDER_API_BASE_URL:-http://api.ofm.local/v1}"
REALTIME_WS_HOST="${ORDER_REALTIME_WS_HOST:-realtime.ofm.local}"
LOG_FILE="${ORDER_LOG_FILE:-order-complete-log.txt}"
GIG_FLOW_LOG_FILE="${ORDER_GIG_FLOW_LOG_FILE:-gig-log.txt}"
FILE_SERVICE_GRPC_HOST="${ORDER_FILE_SERVICE_GRPC_HOST:-file.ofm.local}"
FILE_SERVICE_GRPC_PORT="${ORDER_FILE_SERVICE_GRPC_PORT:-80}"
FILE_SERVICE_GRPC_AUTHORITY="${ORDER_FILE_SERVICE_GRPC_AUTHORITY:-file.ofm.local}"
FILE_SERVICE_GRPC_ADDRESS="${ORDER_FILE_SERVICE_GRPC_ADDRESS:-}"
FILE_SERVICE_KUBE_NAMESPACE="${ORDER_FILE_SERVICE_KUBE_NAMESPACE:-${OFM_K3D_NAMESPACE:-ofm}}"
FILE_SERVICE_KUBE_CONFIG="${ORDER_FILE_SERVICE_KUBE_CONFIG:-${OFM_K3D_KUBECONFIG:-$HOME/.kube/k3d-ofm.yaml}}"
FILE_SERVICE_FORWARD_PORT="${ORDER_FILE_SERVICE_FORWARD_PORT:-9504}"
FILE_SERVICE_FORWARD_LOG="${ORDER_FILE_SERVICE_FORWARD_LOG:-/tmp/ofm-file-service-order-complete-port-forward.log}"
FILE_SERVICE_PORT_FORWARD_PID=""

timestamp="$(date +%s)"
buyer_id="${ORDER_BUYER_ID:-7c1d1af1-6be8-4e77-8e57-0b1f2d12e9aa}"
buyer_email="${ORDER_BUYER_EMAIL:-${buyer_id}@example.com}"
seller_id="${ORDER_SELLER_ID:-}"
seller_email="${ORDER_SELLER_EMAIL:-}"
admin_id="${ORDER_ADMIN_ID:-019e0000-0000-7000-8000-000000000001}"
admin_email="${ORDER_ADMIN_EMAIL:-${admin_id}@example.com}"
jwt_secret="${ORDER_JWT_SECRET:-${JWT_ACCESS_SECRET:-local-dev-secret-change-me}}"
jwt_ttl_seconds="${ORDER_JWT_TTL_SECONDS:-3600}"
gig_id="${ORDER_GIG_ID:-}"
package_id="${ORDER_PACKAGE_ID:-}"
order_id="${ORDER_ORDER_ID:-}"
idempotency_key="${ORDER_IDEMPOTENCY_KEY:-order-${timestamp}}"
delivery_message="${ORDER_DELIVERY_MESSAGE:-I finished the work. Please review the delivery.}"
dispute_reason="${ORDER_CANCEL_REASON:-${ORDER_DISPUTE_REASON:-The buyer is not satisfied with the delivery.}}"
dispute_resolution_reason="${ORDER_DISPUTE_RESOLUTION_REASON:-Admin resolved the disputed order.}"
freelancer_percentage="${ORDER_FREELANCER_PERCENTAGE:-50}"
customer_percentage="${ORDER_CUSTOMER_PERCENTAGE:-50}"
order_complete_mode="${ORDER_COMPLETE_MODE:-success}"
if [[ "${ORDER_CANCEL_FLOW:-0}" == "1" ]]; then
  order_complete_mode="cancel_after_delivery"
fi
delivery_attachment_files="${ORDER_DELIVERY_ATTACHMENT_FILES:-[\"/home/alex/Downloads/ainz.jpg\",\"/home/alex/Downloads/yagami.jpg\"]}"
delivery_attachment_ids="${ORDER_DELIVERY_ATTACHMENT_IDS:-[]}"
realtime_event_file="$(mktemp)"
realtime_listener_pid=""
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${script_dir}/api-gateway-curl.sh"
ofm_api_gateway_configure "$API_BASE_URL" || true

ofm_realtime_configure() {
  local base_url="${ORDER_REALTIME_WS_URL:-}"
  local kubeconfig_path="${OFM_K3D_KUBECONFIG:-$HOME/.kube/k3d-ofm.yaml}"
  local namespace="${OFM_K3D_NAMESPACE:-ofm}"
  local realtime_ip=""

  if [[ -n "$base_url" ]]; then
    REALTIME_WS_URL="$base_url"
    return 0
  fi

  if command -v kubectl >/dev/null 2>&1; then
    realtime_ip="$(
      kubectl --kubeconfig "$kubeconfig_path" -n "$namespace" get ingress realtime-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true
    )"
  fi

  if [[ -z "$realtime_ip" ]]; then
    realtime_ip="172.23.0.2"
  fi

  REALTIME_WS_URL="ws://${realtime_ip}/ws"
}

ofm_realtime_configure

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
    --delivery-message)
      delivery_message="${2:-}"
      shift 2
      ;;
    --delivery-message=*)
      delivery_message="${1#*=}"
      shift
      ;;
    --cancel)
      order_complete_mode="cancel_after_delivery"
      shift
      ;;
    --dispute)
      order_complete_mode="cancel_after_delivery"
      shift
      ;;
    --cancel-after-delivery)
      order_complete_mode="cancel_after_delivery"
      shift
      ;;
    --buyer-cancel)
      order_complete_mode="buyer_cancel"
      shift
      ;;
    --seller-cancel)
      order_complete_mode="seller_cancel"
      shift
      ;;
    --cancel-reason)
      dispute_reason="${2:-}"
      shift 2
      ;;
    --cancel-reason=*)
      dispute_reason="${1#*=}"
      shift
      ;;
    --delivery-attachment-file)
      delivery_attachment_files="$(jq -nc --argjson current "${delivery_attachment_files}" --arg path "${2:-}" '$current + [$path]' )"
      shift 2
      ;;
    --delivery-attachment-file=*)
      delivery_attachment_files="$(jq -nc --argjson current "${delivery_attachment_files}" --arg path "${1#*=}" '$current + [$path]' )"
      shift
      ;;
    --delivery-attachment-files)
      delivery_attachment_files="${2:-[]}"
      shift 2
      ;;
    --delivery-attachment-files=*)
      delivery_attachment_files="${1#*=}"
      shift
      ;;
    --delivery-attachment-id)
      delivery_attachment_ids="$(jq -nc --argjson current "${delivery_attachment_ids}" --arg id "${2:-}" '$current + [$id]' )"
      shift 2
      ;;
    --delivery-attachment-id=*)
      delivery_attachment_ids="$(jq -nc --argjson current "${delivery_attachment_ids}" --arg id "${1#*=}" '$current + [$id]' )"
      shift
      ;;
    --delivery-attachment-ids)
      delivery_attachment_ids="${2:-[]}"
      shift 2
      ;;
    --delivery-attachment-ids=*)
      delivery_attachment_ids="${1#*=}"
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

buyer_access_token="${ORDER_BUYER_ACCESS_TOKEN:-$(generate_jwt "$buyer_id" "$buyer_email" "${ORDER_JWT_USERNAME:-order-complete-buyer}")}"
buyer_auth_header="Authorization: Bearer $buyer_access_token"
admin_access_token="${ORDER_ADMIN_ACCESS_TOKEN:-$(generate_jwt "$admin_id" "$admin_email" "${ORDER_ADMIN_USERNAME:-order-complete-admin}" '["admin"]')}"
admin_auth_header="Authorization: Bearer $admin_access_token"

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

print_section() {
  log_blank
  log "== $1 =="
}

upload_delivery_files() {
  local files_json="$1"
  local owner_id="$2"
  local order_id="$3"
  local request_json response_file

  if ! jq -e . >/dev/null 2>&1 <<<"$files_json"; then
    echo "ORDER_DELIVERY_ATTACHMENT_FILES must be valid JSON array" >&2
    exit 1
  fi

  if [[ "$(jq 'length' <<<"$files_json")" -eq 0 ]]; then
    printf '[]'
    return 0
  fi

  request_json="$(
    python3 - "$files_json" "$owner_id" "$order_id" <<'PY'
import base64
import json
import mimetypes
import pathlib
import sys

files = json.loads(sys.argv[1])
owner_id = sys.argv[2]
order_id = sys.argv[3]

payload = {
    "ownerId": owner_id,
    "prefix": f"orders/{order_id}/delivery",
    "files": [],
}

for raw_path in files:
    path = pathlib.Path(raw_path)
    data = path.read_bytes()
    mime, _ = mimetypes.guess_type(str(path))
    payload["files"].append({
        "filename": path.name,
        "contentType": mime or "application/octet-stream",
        "data": base64.b64encode(data).decode("ascii"),
    })

print(json.dumps(payload))
PY
  )"

  response_file="$(mktemp)"
  if [[ -n "$FILE_SERVICE_GRPC_ADDRESS" ]]; then
    if ! grpcurl -plaintext -authority "$FILE_SERVICE_GRPC_AUTHORITY" -d "$request_json" "$FILE_SERVICE_GRPC_ADDRESS" file.v1.FileService/UploadFiles >"$response_file"; then
      cat "$response_file" >&2 || true
      rm -f "$response_file"
      echo "delivery file upload failed" >&2
      exit 1
    fi
  else
    OFM_K3D_KUBECONFIG="$FILE_SERVICE_KUBE_CONFIG" \
      OFM_K3D_NAMESPACE="$FILE_SERVICE_KUBE_NAMESPACE" \
      FILE_SERVICE_FORWARD_PORT="$FILE_SERVICE_FORWARD_PORT" \
      FILE_SERVICE_FORWARD_LOG="$FILE_SERVICE_FORWARD_LOG" \
      ofm_file_service_port_forward_start

    if ! grpcurl -plaintext -import-path "${script_dir}/../../ofm-common/proto" -proto file/v1/file.proto \
      -d "$request_json" "127.0.0.1:${FILE_SERVICE_FORWARD_PORT}" file.v1.FileService/UploadFiles >"$response_file"; then
      cat "$response_file" >&2 || true
      rm -f "$response_file"
      echo "delivery file upload failed" >&2
      exit 1
    fi
  fi

  jq -c '[.files[]? | (.file_id // .fileId)] | map(select(. != null and . != ""))' "$response_file"
  rm -f "$response_file"
}

require_command curl
require_command jq
require_command python3
require_command openssl
require_command grpcurl
require_command kubectl

. "${script_dir}/file-service-port-forward.sh"

start_realtime_listener() {
  python3 -u - "$REALTIME_WS_URL" "$REALTIME_WS_HOST" "$buyer_access_token" "$realtime_event_file" <<'PY' >>"$LOG_FILE" 2>&1 &
import base64
import hashlib
import json
import os
import socket
import ssl
import struct
import sys
import urllib.parse

ws_url, host_header, token, event_file = sys.argv[1:5]

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
    event_type = message.get("type", "") or message.get("kind", "")
    if event_type:
        with open(event_file, "w", encoding="utf-8") as fh:
            fh.write(event_type)
            fh.flush()
PY
  realtime_listener_pid=$!
}

stop_realtime_listener() {
  if [[ -n "${realtime_listener_pid}" ]]; then
    kill "${realtime_listener_pid}" >/dev/null 2>&1 || true
    wait "${realtime_listener_pid}" >/dev/null 2>&1 || true
  fi
  rm -f "$realtime_event_file"
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

start_body="$(mktemp)"
confirm_body="$(mktemp)"
deliver_body="$(mktemp)"
accept_body="$(mktemp)"
trap 'rm -f "$start_body" "$confirm_body" "$deliver_body" "$accept_body"; stop_realtime_listener; ofm_file_service_port_forward_cleanup' EXIT

log "----- OFM order complete flow $(date -Is) -----"
log "Log file: $LOG_FILE"
log "API base URL: $API_BASE_URL"
log_blank
log "Buyer ID: $buyer_id"
log "Buyer email: $buyer_email"
log "Order ID: $order_id"
log "Mode: $order_complete_mode"
log "Idempotency key: $idempotency_key"

print_section "Realtime handshake"
log "Connecting to realtime service: ${REALTIME_WS_URL}"
start_realtime_listener

case "$order_complete_mode" in
  success|cancel_after_delivery|buyer_cancel|seller_cancel)
    ;;
  *)
    echo "unknown ORDER_COMPLETE_MODE: $order_complete_mode" >&2
    exit 1
    ;;
esac

needs_seller="0"
case "$order_complete_mode" in
  success|cancel_after_delivery|seller_cancel)
    needs_seller="1"
    ;;
esac

seller_auth_header=""
if [[ "$needs_seller" == "1" ]]; then
  if [[ -z "${seller_id}" ]]; then
    echo "ORDER_SELLER_ID is required for this order complete mode" >&2
    exit 1
  fi
fi
if [[ -n "${seller_id}" ]]; then
  if [[ -z "${seller_email}" ]]; then
    seller_email="${seller_id}@example.com"
  fi
  seller_access_token="${ORDER_SELLER_ACCESS_TOKEN:-$(generate_jwt "$seller_id" "$seller_email" "${ORDER_SELLER_USERNAME:-order-complete-seller}")}"
  seller_auth_header="Authorization: Bearer $seller_access_token"
fi

if [[ "$order_complete_mode" == "success" || "$order_complete_mode" == "cancel_after_delivery" ]]; then
  print_section "Seller delivery"
  if ! jq -e . >/dev/null 2>&1 <<<"$delivery_attachment_files"; then
    echo "ORDER_DELIVERY_ATTACHMENT_FILES must be valid JSON array" >&2
    exit 1
  fi
  if ! jq -e . >/dev/null 2>&1 <<<"$delivery_attachment_ids"; then
    echo "ORDER_DELIVERY_ATTACHMENT_IDS must be valid JSON array" >&2
    exit 1
  fi

  if [[ "$(jq 'length' <<<"$delivery_attachment_files")" -gt 0 ]]; then
    if [[ -n "$FILE_SERVICE_GRPC_ADDRESS" ]]; then
      log "Uploading delivery files through file-service: ${FILE_SERVICE_GRPC_ADDRESS}"
    else
      log "Uploading delivery files through in-cluster file-service"
    fi
    delivery_attachment_ids="$(upload_delivery_files "$delivery_attachment_files" "$seller_id" "$order_id")"
    log "Uploaded delivery file IDs: $delivery_attachment_ids"
  fi

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
    deliver_error="$(jq -r '.error // empty' "$deliver_body" 2>/dev/null || true)"
    if [[ "$order_complete_mode" == "cancel_after_delivery" && "$deliver_error" == "order not deliverable" ]]; then
      log "Delivery step is not deliverable; continuing cancel-after-delivery flow in case the order was already delivered."
    else
      echo "deliver order failed" >&2
      exit 1
    fi
  fi
else
  print_section "Pre-delivery cancel"
  log "Skipping seller delivery for mode: $order_complete_mode"
fi

print_section "Buyer chooses outcome"
if [[ "$order_complete_mode" == "cancel_after_delivery" || "$order_complete_mode" == "buyer_cancel" || "$order_complete_mode" == "seller_cancel" ]]; then
  dispute_actor="Buyer"
  dispute_auth_header="$buyer_auth_header"
  if [[ "$order_complete_mode" == "seller_cancel" ]]; then
    dispute_actor="Seller"
    dispute_auth_header="$seller_auth_header"
  fi

  print_section "${dispute_actor} opens dispute"
  dispute_payload="$(
    jq -nc \
      --arg reason "$dispute_reason" \
      '{
        reason: $reason
      }'
  )"
  log "POST ${API_BASE_URL}/orders/${order_id}/dispute"
  log "$dispute_payload"
  dispute_status="$(
    request_json "$dispute_auth_header" POST "${API_BASE_URL}/orders/${order_id}/dispute" "$dispute_payload" "$accept_body"
  )"
  log "HTTP ${dispute_status}"
  log_json_file "$accept_body"

  if [[ "$dispute_status" != "200" ]]; then
    dispute_error="$(jq -r '.error // empty' "$accept_body" 2>/dev/null || true)"
    if [[ "$dispute_error" == "order not disputable" ]]; then
      log "Dispute step is not disputable; continuing cancel flow in case the order is already disputed."
    else
      echo "open dispute failed" >&2
      exit 1
    fi
  else
    log "Waiting for realtime dispute event..."
    wait_for_realtime_event "dispute" "order.disputed" "order_disputed"
  fi

  print_section "Admin resolves dispute"
  resolve_payload="$(
    jq -nc \
      --argjson freelancer_percentage "$freelancer_percentage" \
      --argjson customer_percentage "$customer_percentage" \
      --arg reason "$dispute_resolution_reason" \
      '{
        freelancer_percentage: $freelancer_percentage,
        customer_percentage: $customer_percentage,
        reason: $reason
      }'
  )"
  log "POST ${API_BASE_URL}/orders/${order_id}/dispute/resolve"
  log "$resolve_payload"
  resolve_status="$(
    request_json "$admin_auth_header" POST "${API_BASE_URL}/orders/${order_id}/dispute/resolve" "$resolve_payload" "$accept_body"
  )"
  log "HTTP ${resolve_status}"
  log_json_file "$accept_body"

  if [[ "$resolve_status" != "200" ]]; then
    echo "resolve dispute failed" >&2
    exit 1
  fi

  log "Waiting for realtime dispute resolution event..."
  wait_for_realtime_event "dispute resolution" "order.dispute_resolved" "order_dispute_resolved" "order_completed" "payment.funds_released"

  log_blank
  log "== Done =="
  log "Order complete flow finished with admin dispute resolution."
  log "Order ID: $order_id"
else
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
fi
