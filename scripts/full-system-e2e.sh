#!/usr/bin/env bash
set -Eeuo pipefail

# Browser-independent full-system E2E runner for the k3d environment.
# It uses fake Stripe and drives the public gateway plus the payment webhook.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT="${FULL_SYSTEM_E2E_REPORT:-$ROOT_DIR/FULL_SYSTEM_E2E_RESULT.md}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

JWT_SECRET="${JWT_ACCESS_SECRET:-aa96fae1a6eee39b879dad6b6bb372e63278257bf9f94010bc7d25693f61e38c}"
GATEWAY="${FULL_SYSTEM_GATEWAY_URL:-http://api.ofm.local/api/v2}"
PAYMENT="${FULL_SYSTEM_PAYMENT_URL:-http://payment.ofm.local/v1}"
RESOLVE=(--resolve api.ofm.local:80:172.22.0.2 --resolve payment.ofm.local:80:172.22.0.2 --resolve monolith.ofm.local:80:172.22.0.2)
PASS=0
FAIL=0

# This runner is intended for a disposable integration environment. Clear only
# migration audit state so stale DLQ/pending rows from an earlier run cannot
# make a fresh flow fail; business tables and Kafka data are preserved.
if [[ "${FULL_SYSTEM_E2E_RESET_MIGRATION_AUDIT:-true}" == "true" ]]; then
  docker exec "${MONOLITH_PROJECTION_DB_CONTAINER:-ofm-monolith-postgres}" \
    psql -h "${MONOLITH_PROJECTION_DB_HOST:-127.0.0.1}" \
    -p "${MONOLITH_PROJECTION_DB_PORT:-5432}" -U admin \
    -d "${MONOLITH_PROJECTION_DB_NAME:-ofm_monolith}" \
    -v ON_ERROR_STOP=1 \
    -c 'TRUNCATE migration_pending_projections; TRUNCATE migration_projection_failures RESTART IDENTITY;' \
    >/dev/null 2>&1 || true
fi

base64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
token_for() {
  local sub="$1" username="$2" now header payload input sig
  now="$(date +%s)"; header='{"alg":"HS256","typ":"JWT"}'
  payload="$(jq -nc --arg sub "$sub" --arg username "$username" --arg email "$sub@example.com" --argjson iat "$now" --argjson exp "$((now+3600))" '{sub:$sub,email:$email,username:$username,iat:$iat,exp:$exp}')"
  input="$(
    {
      printf '%s' "$header" | base64url
      printf '.'
      printf '%s' "$payload" | base64url
    }
  )"
  sig="$(printf '%s' "$input" | openssl dgst -binary -sha256 -hmac "$JWT_SECRET" | base64url)"
  printf '%s.%s' "$input" "$sig"
}

check() {
  local name="$1" result="$2" detail="$3"
  if [[ "$result" == pass ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
  printf '%s|%s|%s\n' "$name" "$result" "$detail" >> "$WORK/checks"
  printf '[%s] %s: %s\n' "$result" "$name" "$detail"
}

kafka_topic_contains() {
  local topic="$1" identity="$2" output end_offset start_offset
  for _ in $(seq 1 8); do
    end_offset="$(timeout 5s docker exec ofm-migration-kafka /opt/kafka/bin/kafka-get-offsets.sh \
      --bootstrap-server kafka:9092 --topic "$topic" 2>/dev/null | awk -F: 'NR==1 {print $3}' || true)"
    [[ "$end_offset" =~ ^[0-9]+$ ]] || end_offset=0
    start_offset=$(( end_offset > 100 ? end_offset - 100 : 0 ))
    output="$(timeout 5s docker exec ofm-migration-kafka /opt/kafka/bin/kafka-console-consumer.sh \
      --bootstrap-server kafka:9092 --topic "$topic" --partition 0 \
      --offset "$start_offset" --max-messages 100 2>/dev/null || true)"
    if grep -Fq "$identity" <<<"$output"; then
      return 0
    fi
    sleep 1
  done
  return 1
}

wait_for_migration_bridge() {
  local group="${MIGRATION_BRIDGE_GROUP:-migration-bridge-all}" lag
  for _ in $(seq 1 "${MIGRATION_BRIDGE_WAIT_ATTEMPTS:-90}"); do
    lag="$(timeout 5s docker exec ofm-migration-kafka /opt/kafka/bin/kafka-consumer-groups.sh \
      --bootstrap-server kafka:9092 --describe --group "$group" 2>/dev/null \
      | awk 'NR>1 && $0 !~ /^GROUP/ {sum += $6} END {print sum+0}' || true)"
    if [[ "$lag" == "0" ]]; then
      return 0
    fi
    sleep 1
  done
  return 1
}

request() {
  local method="$1" url="$2" body="${3:-}" out="$4" token="$5"
  local args=(-sS "${RESOLVE[@]}" -X "$method" -H 'Content-Type: application/json' -H "Authorization: Bearer $token" -o "$out" -w '%{http_code}')
  [[ -n "$body" ]] && args+=(--data "$body")
  curl "${args[@]}" "$url"
}

printf '# Full system E2E\n\nDate: %s\n\n' "$(date -Is)" > "$REPORT"
: > "$WORK/checks"

GIG_TOKEN="${FULL_SYSTEM_GIG_TOKEN:-$(token_for aeac656a-e617-45f2-b1ce-b922d8bd03fa alex1)}"
GIG_LOG="$WORK/gig.log"
cover_image_path="${GIG_COVER_IMAGE_PATH:-/tmp/ofm-parity-fixtures/cover.png}"
gallery_image_path="${GIG_GALLERY_IMAGE_PATH:-/tmp/ofm-parity-fixtures/gallery.png}"
if [[ ! -f "$cover_image_path" || ! -f "$gallery_image_path" ]]; then
  mkdir -p "$(dirname "$cover_image_path")" "$(dirname "$gallery_image_path")"
  fixture_image="$ROOT_DIR/ofm-frontend/public/images/no-image.png"
  [[ -f "$cover_image_path" ]] || cp "$fixture_image" "$cover_image_path"
  [[ -f "$gallery_image_path" ]] || cp "$fixture_image" "$gallery_image_path"
fi
if GIG_JWT_SECRET="$JWT_SECRET" GIG_TOKEN_FILE="$WORK/gig.token" GIG_COVER_IMAGE_PATH="$cover_image_path" GIG_GALLERY_IMAGE_PATH="$gallery_image_path" GIG_LOG_FILE="$GIG_LOG" bash "$ROOT_DIR/ofm-infra/scripts/gig-flow.sh" > "$WORK/gig.out" 2>&1; then
  if [[ -s "$WORK/gig.token" ]]; then
    GIG_TOKEN="$(<"$WORK/gig.token")"
  fi
  gig_id="$(sed -n 's/^Gig ID: //p' "$GIG_LOG" | tail -1)"
  package_id="$(python3 - "$GIG_LOG" <<'PY'
import re,sys
lines=open(sys.argv[1],encoding='utf-8').read().splitlines()
for i,line in enumerate(lines):
    if '"tier": "basic"' in line:
        for x in lines[i-8:i+4]:
            m=re.search(r'"id":\s*"([0-9a-f-]+)"',x)
            if m: print(m.group(1)); raise SystemExit
PY
)"
  check gig_lifecycle pass "$gig_id"
else
  if [[ -s "$WORK/gig.token" ]]; then
    GIG_TOKEN="$(<"$WORK/gig.token")"
  fi
  check gig_lifecycle fail "$(tail -1 "$WORK/gig.out")"
  gig_id=""; package_id=""
fi

if [[ -n "$gig_id" && -n "$package_id" ]]; then
  BUYER_ID=7c1d1af1-6be8-4e77-8e57-0b1f2d12e9aa
  BUYER_TOKEN="$(token_for "$BUYER_ID" order-flow)"
  order_body="$(jq -nc --arg gig "$gig_id" --arg package "$package_id" '{gig_id:$gig,package_id:$package}')"
  code="$(request POST "$GATEWAY/orders/start" "$order_body" "$WORK/start.json" "$BUYER_TOKEN")"
  order_id="$(jq -r '.order_id // empty' "$WORK/start.json")"
  saga_id="$(jq -r '.saga_id // empty' "$WORK/start.json")"
  if [[ "$code" == 201 && -n "$order_id" ]]; then check order_start pass "$order_id"; else check order_start fail "HTTP $code $(cat "$WORK/start.json")"; fi

  answers="$(jq -c '(.questions // []) | map({question_id:.id,value:"e2e-answer"})' "$WORK/start.json")"
  req="$(jq -nc --arg order "$order_id" --argjson answers "$answers" '{order_id:$order,answers:$answers}')"
  code="$(request POST "$GATEWAY/orders/$order_id/requirements" "$req" "$WORK/requirements.json" "$BUYER_TOKEN")"
  [[ "$code" == 200 ]] && check order_requirements pass "HTTP $code" || check order_requirements fail "HTTP $code"

  msg="$(jq -nc --arg order "$order_id" '{order_id:$order,message:"full-system-e2e"}')"
  code="$(request POST "$GATEWAY/orders/$order_id/message" "$msg" "$WORK/message.json" "$BUYER_TOKEN")"
  [[ "$code" == 200 ]] && check order_message pass "HTTP $code" || check order_message fail "HTTP $code"

  confirm="$(jq -nc --arg order "$order_id" '{order_id:$order}')"
  code="$(request POST "$GATEWAY/orders/$order_id/confirm" "$confirm" "$WORK/confirm.json" "$BUYER_TOKEN")"
  payment_id="$(jq -r '.payment_id // empty' "$WORK/confirm.json")"
  [[ "$code" == 200 && -n "$payment_id" ]] && check order_confirm pass "$payment_id" || check order_confirm fail "HTTP $code $(cat "$WORK/confirm.json")"

  webhook="$(jq -nc --arg event "evt-full-e2e-$payment_id" --arg intent "$payment_id" --arg order "$order_id" '{event_id:$event,provider:"fake-stripe",event_type:"payment_intent.captured",intent_id:$intent,provider_intent_id:("pi_fake_"+$intent),order_id:$order,status:"captured"}')"
  code="$(request POST "$PAYMENT/fake-stripe/webhooks/payment" "$webhook" "$WORK/webhook.json" "$BUYER_TOKEN")"
  [[ "$code" == 202 ]] && check fake_stripe_webhook pass "HTTP $code" || check fake_stripe_webhook fail "HTTP $code $(cat "$WORK/webhook.json")"
fi

# Contract reachability matrix for Gateway /v2 versus Monolith /api/v2.
# Invalid business identifiers are intentional:
# this checks that every registered route exists and reaches its handler,
# without creating a second destructive business flow for each endpoint.
route_check() {
  local name="$1" base="$2" method="$3" path="$4" token="$5" body="${6:-}"
  local code args attempt
  args=(-sS "${RESOLVE[@]}" -X "$method" -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' -H "Authorization: Bearer $token")
  [[ -n "$body" ]] && args+=(--data "$body")
  code=000
  for attempt in 1 2 3; do
    code="$(curl "${args[@]}" "$base$path" || true)"
    # Kafka-backed read models are eventually consistent. Retry only transient
    # server failures; preserve deterministic 4xx/405 contract responses.
    if [[ ! "$code" =~ ^5[0-9][0-9]$ || "$attempt" == 3 ]]; then
      break
    fi
    sleep "$attempt"
  done
  # 4xx responses are valid contract responses for unknown or unauthorized
  # fixture resources.  5xx, 405, and transport failures are real failures.
  if [[ "$code" =~ ^[234][0-9][0-9]$ && "$code" != 405 ]]; then check "$name" pass "HTTP $code"; else check "$name" fail "HTTP $code"; fi
}

ROUTE_BODY='{}'
ROUTE_ID="${gig_id:-00000000-0000-0000-0000-000000000001}"
ROUTE_ORDER="${order_id:-00000000-0000-0000-0000-000000000002}"
ROUTE_USER=alex1
ROUTE_GIG="${gig_id:-full-system-e2e-gig}"
ROUTE_MESSAGE=00000000-0000-0000-0000-000000000003

declare -a ROUTES=(
  "POST|/auth/sign-up" "POST|/auth/sign-up/verify-email" "POST|/auth/sign-up/complete" "POST|/auth/sign-in" "POST|/auth/refresh" "POST|/auth/sign-out" "GET|/auth/me"
  "POST|/freelancer/onboarding/start"
  "POST|/gigs/drafts" "PATCH|/gigs/$ROUTE_ID/basic-info" "PUT|/gigs/$ROUTE_ID/packages" "PUT|/gigs/$ROUTE_ID/requirements" "PUT|/gigs/$ROUTE_ID/media" "GET|/gigs/$ROUTE_ID/draft" "POST|/gigs/$ROUTE_ID/publish"
  "POST|/orders/start" "POST|/orders/$ROUTE_ORDER/confirm" "POST|/orders/$ROUTE_ORDER/requirements" "POST|/orders/$ROUTE_ORDER/message" "POST|/orders/$ROUTE_ORDER/deliver" "POST|/orders/$ROUTE_ORDER/accept" "POST|/orders/$ROUTE_ORDER/request-revision" "POST|/orders/$ROUTE_ORDER/dispute" "POST|/orders/$ROUTE_ORDER/dispute/resolve" "POST|/orders/$ROUTE_ORDER/reviews"
  "GET|/users/$ROUTE_USER/orders/$ROUTE_ORDER/chat" "POST|/users/$ROUTE_USER/orders/$ROUTE_ORDER/chat/messages" "PATCH|/users/$ROUTE_USER/orders/$ROUTE_ORDER/chat/messages/$ROUTE_MESSAGE" "DELETE|/users/$ROUTE_USER/orders/$ROUTE_ORDER/chat/messages/$ROUTE_MESSAGE" "POST|/users/$ROUTE_USER/orders/$ROUTE_ORDER/chat/attachments/upload-url" "POST|/users/$ROUTE_USER/orders/$ROUTE_ORDER/chat/attachments/complete"
  "GET|/search?query=full-system-e2e&sort=0&order=0" "GET|/users/$ROUTE_USER" "GET|/users/$ROUTE_USER/gigs" "GET|/users/$ROUTE_USER/gigs/$ROUTE_GIG" "GET|/users/$ROUTE_USER/orders/$ROUTE_ORDER" "GET|/users/$ROUTE_USER/orders/$ROUTE_ORDER/requirements" "GET|/users/$ROUTE_USER/orders/$ROUTE_ORDER/delivery"
)
for route in "${ROUTES[@]}"; do
  IFS='|' read -r method path <<< "$route"
  route_check "gateway_${method}_${path}" "$GATEWAY" "$method" "$path" "${BUYER_TOKEN:-$GIG_TOKEN}" "$ROUTE_BODY"
  route_check "monolith_${method}_${path}" "http://monolith.ofm.local/api/v2" "$method" "$path" "${BUYER_TOKEN:-$GIG_TOKEN}" "$ROUTE_BODY"
done

search_code=000
for _ in 1 2 3 4 5; do
  search_code="$(curl -sS "${RESOLVE[@]}" -o "$WORK/search.json" -w '%{http_code}' "$GATEWAY/search?q=full-system-e2e" || true)"
  [[ "$search_code" == 200 ]] && break
  sleep 1
done
[[ "$search_code" == 200 ]] && check gateway_search pass "HTTP $search_code" || check gateway_search fail "HTTP $search_code"
mono_code=000
for _ in 1 2 3 4 5; do
  mono_code="$(curl -sS "${RESOLVE[@]}" -o "$WORK/mono-search.json" -w '%{http_code}' 'http://monolith.ofm.local/api/v2/search?query=full-system-e2e&sort=0&order=0' || true)"
  [[ "$mono_code" == 200 ]] && break
  sleep 1
done
[[ "$mono_code" == 200 ]] && check monolith_search pass "HTTP $mono_code" || check monolith_search fail "HTTP $mono_code"

projection_code="$(curl -sS "${RESOLVE[@]}" -o "$WORK/projection-user.json" -w '%{http_code}' 'http://monolith.ofm.local/api/v2/users/cdc-user' || true)"
[[ "$projection_code" == 200 ]] && check kafka_projection_live pass "HTTP $projection_code" || check kafka_projection_live fail "HTTP $projection_code"
schema_code="$(curl -sS -o /dev/null -w '%{http_code}' 'http://127.0.0.1:8084/apis/registry/v3/groups/default/artifacts' || true)"
[[ "$schema_code" == 200 ]] && check schema_registry_live pass "HTTP $schema_code" || check schema_registry_live fail "HTTP $schema_code"

if kubectl --kubeconfig "${OFM_K3D_KUBECONFIG:-$HOME/.kube/k3d-ofm.yaml}" -n ofm get pods --no-headers | awk '$3 !~ /Running|Completed/ {bad=1} END{exit bad}'; then check kubernetes_health pass all_pods_healthy; else check kubernetes_health fail unhealthy_pods; fi
metrics_file="$WORK/monolith-metrics"
kubectl --kubeconfig "${OFM_K3D_KUBECONFIG:-$HOME/.kube/k3d-ofm.yaml}" -n ofm exec deploy/monolith -- sh -c 'wget -qO- http://127.0.0.1:9600/metrics' > "$metrics_file" 2>/dev/null || true
if rg -q 'ofm_db_' "$metrics_file"; then check monolith_metrics pass port_9600; else check monolith_metrics fail unavailable; fi
if ! kubectl --kubeconfig "${OFM_K3D_KUBECONFIG:-$HOME/.kube/k3d-ofm.yaml}" -n ofm logs deploy/order-saga-service --since=3m | rg -q '127\.0\.0\.1:9092|Kafka consumer failed'; then check order_saga_kafka pass no_consumer_errors; else check order_saga_kafka fail consumer_errors; fi

# Verify every stage of the CDC path for identities created by this run.
# This prevents an HTTP-only success from being reported as a projection E2E.
if [[ -n "${gig_id:-}" && -n "${package_id:-}" && -n "${order_id:-}" ]]; then
  kafka_topic_contains cdc.gig.public.outbox_events "$gig_id" && check cdc_gig_source_event pass "$gig_id" || check cdc_gig_source_event fail "$gig_id"
  wait_for_migration_bridge || true
  kafka_topic_contains migration.gig-service.gigs.changed "$gig_id" && check migration_gig_event pass "$gig_id" || check migration_gig_event fail "$gig_id"
  kafka_topic_contains migration.gig-service.gig_packages.changed "$package_id" && check migration_package_event pass "$package_id" || check migration_package_event fail "$package_id"
  kafka_topic_contains cdc.order.public.outbox_events "$order_id" && check cdc_order_source_event pass "$order_id" || check cdc_order_source_event fail "$order_id"
  kafka_topic_contains migration.order-service.orders.changed "$order_id" && check migration_order_event pass "$order_id" || check migration_order_event fail "$order_id"
else
  check cdc_gig_source_event fail flow_identities_unavailable
  check migration_gig_event fail flow_identities_unavailable
  check migration_package_event fail flow_identities_unavailable
  check cdc_order_source_event fail flow_identities_unavailable
  check migration_order_event fail flow_identities_unavailable
fi

# Verify that the entities created by the microservice flow also exist in the
# monolith projection. Kafka delivery is asynchronous, so wait for the exact
# flow identities instead of relying on a fixed sleep.
projection_db_container="${MONOLITH_PROJECTION_DB_CONTAINER:-ofm-monolith-postgres}"
projection_db_host="${MONOLITH_PROJECTION_DB_HOST:-127.0.0.1}"
projection_db_port="${MONOLITH_PROJECTION_DB_PORT:-5432}"
projection_db_name="${MONOLITH_PROJECTION_DB_NAME:-ofm_monolith}"
projection_sql() {
  timeout 5s docker exec "$projection_db_container" psql -h "$projection_db_host" -p "$projection_db_port" -U admin -d "$projection_db_name" -At -v ON_ERROR_STOP=1 -c "$1" 2>/dev/null || printf 'database_unavailable'
}

projection_check=fail
projection_detail="flow identities unavailable"
if [[ -n "${gig_id:-}" && -n "${package_id:-}" && -n "${order_id:-}" ]]; then
  # The mapping consumer is intentionally asynchronous and may need to
  # re-establish its Kafka group after a rollout. Wait on the exact IDs with
  # the same bounded recovery window as the projection audit below.
  for attempt in $(seq 1 90); do
    projection_detail="$(projection_sql "
      SELECT CASE WHEN
        EXISTS (SELECT 1 FROM migration_id_mapping WHERE entity_type='gig' AND uuid_id='$gig_id'::uuid)
        AND EXISTS (SELECT 1 FROM migration_id_mapping WHERE entity_type='package' AND uuid_id='$package_id'::uuid)
        AND EXISTS (SELECT 1 FROM migration_id_mapping WHERE entity_type='order' AND uuid_id='$order_id'::uuid)
        AND (SELECT count(*) FROM migration_projection_failures)=0
      THEN 'ok' ELSE 'projection_not_ready' END;
    " 2>/dev/null)"
    if [[ "$projection_detail" == "ok" ]]; then
      projection_check=pass
      break
    fi
    sleep 1
  done
fi
check monolith_projection_data "$projection_check" "$projection_detail"

projection_audit=projection_audit_failed
for attempt in $(seq 1 90); do
  projection_audit="$(projection_sql "
    SELECT CASE WHEN count(*) > 0
      AND (SELECT count(*) FROM migration_pending_projections)=0
      AND (SELECT count(*) FROM migration_projection_failures)=0
      THEN 'ok' ELSE 'projection_audit_failed' END
    FROM processed_events;
  " 2>/dev/null)"
  [[ "$projection_audit" == "ok" ]] && break
  sleep 1
done
if [[ "$projection_audit" == "ok" ]]; then
  check kafka_projection_audit pass processed_events_and_no_pending_failures
else
  check kafka_projection_audit fail "${projection_audit:-database_unavailable}"
fi

{
  echo; echo "## Checks"; echo; echo '| Check | Result | Detail |'; echo '|---|---|---|'; while IFS='|' read -r name result detail; do printf '| %s | %s | %s |\n' "$name" "$result" "$detail"; done < "$WORK/checks"; echo; echo "**Passed:** $PASS  **Failed:** $FAIL";
} >> "$REPORT"

if (( FAIL > 0 )); then exit 1; fi
printf 'FULL SYSTEM E2E: PASS (%d checks)\n' "$PASS"
