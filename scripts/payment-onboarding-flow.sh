#!/usr/bin/env bash
set -euo pipefail

api_gateway_url="${API_GATEWAY_URL:-http://api.ofm.local}"
jwt_token="${JWT_TOKEN:-}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${script_dir}/api-gateway-curl.sh"
ofm_api_gateway_configure "$api_gateway_url" || true
trap ofm_api_gateway_cleanup EXIT

if [[ -z "${jwt_token}" ]]; then
  jwt_token="$(bash ./scripts/payment-onboarding-token.sh)"
fi

response_file="$(mktemp)"
http_code="$(
  curl -sS \
    "${OFM_API_GATEWAY_CURL_ARGS[@]}" \
    -o "${response_file}" \
    -w '%{http_code}' \
    -X POST \
    -H "Authorization: Bearer ${jwt_token}" \
    -H "Content-Type: application/json" \
    "${api_gateway_url}/v1/freelancer/onboarding/start"
)"
response="$(cat "${response_file}")"
rm -f "${response_file}"

onboarding_url="$(
  printf '%s' "${response}" | jq -r '.onboarding_url // .onboardingUrl // empty'
)"

if [[ "${http_code}" != "200" ]]; then
  echo "onboarding request failed with HTTP ${http_code}" >&2
  echo "${response}" >&2
  exit 1
fi

if [[ -z "${onboarding_url}" || "${onboarding_url}" == "null" ]]; then
  echo "failed to extract onboarding URL" >&2
  echo "${response}" >&2
  exit 1
fi

printf '%s\n' "${onboarding_url}"
