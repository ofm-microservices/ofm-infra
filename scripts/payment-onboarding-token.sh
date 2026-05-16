#!/usr/bin/env bash
set -euo pipefail

auth_env_file="${AUTH_ENV_FILE:-../ofm-auth-service/.env}"
subject="${JWT_SUBJECT:-}"
username="${JWT_USERNAME:-demo}"

if [[ ! -f "${auth_env_file}" ]]; then
  echo "auth env file not found: ${auth_env_file}" >&2
  exit 1
fi

secret="$(
  grep -E '^JWT_SECRET=' "${auth_env_file}" | head -n1 | cut -d= -f2-
)"

issuer="$(
  grep -E '^JWT_ISSUER=' "${auth_env_file}" | head -n1 | cut -d= -f2-
)"

if [[ -z "${secret}" ]]; then
  echo "JWT_SECRET is missing in ${auth_env_file}" >&2
  exit 1
fi

if [[ -z "${issuer}" ]]; then
  issuer="ofm-auth-service"
fi

python3 - "${secret}" "${issuer}" "${subject}" "${username}" <<'PY'
import base64
import hashlib
import hmac
import json
import sys
import time
import uuid

secret, issuer, subject, username = sys.argv[1:5]
if not subject.strip():
    subject = str(uuid.uuid4())
now = int(time.time())
payload = {
    "sub": subject,
    "iss": issuer,
    "iat": now,
    "exp": now + 900,
    "username": username,
}
header = {"alg": "HS256", "typ": "JWT"}

def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

header_b64 = b64url(json.dumps(header, separators=(",", ":")).encode())
payload_b64 = b64url(json.dumps(payload, separators=(",", ":")).encode())
signing_input = f"{header_b64}.{payload_b64}".encode()
signature = hmac.new(secret.encode(), signing_input, hashlib.sha256).digest()
print(f"{header_b64}.{payload_b64}.{b64url(signature)}")
PY
