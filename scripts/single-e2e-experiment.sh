#!/usr/bin/env bash
set -euo pipefail

# Run one explicit end-to-end flow. Transient HTTP failures are retried with
# bounded backoff so asynchronous saga/projection state can settle.

API_BASE_URL="${API_BASE_URL:-http://api.ofm.local/api/v2}"
KUBECONFIG_PATH="${OFM_K3D_KUBECONFIG:-$HOME/.kube/k3d-ofm.yaml}"
NAMESPACE="${OFM_K3D_NAMESPACE:-ofm}"
REGISTRATION_WAIT_SECONDS="${REGISTRATION_WAIT_SECONDS:-20}"
PROJECTION_WAIT_SECONDS="${PROJECTION_WAIT_SECONDS:-10}"
FAULT_SERVICE_DOWN="${FAULT_SERVICE_DOWN:-true}"
CLEAN_ONLY="${CLEAN_ONLY:-false}"
PASSWORD="${K6_TEST_PASSWORD:-Password123!}"
KAFKA_CONTAINER="${OFM_KAFKA_CONTAINER:-ofm-migration-kafka}"
gig_service_disabled=0

tmp_dir="$(mktemp -d)"
cleanup() {
  if [[ "$gig_service_disabled" == "1" ]]; then
    kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" scale deployment/gig-service --replicas=1 >/dev/null 2>&1 || true
  fi
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

api() {
  curl -sS --resolve api.ofm.local:80:172.22.0.2 "$@"
}

payment_api() {
  curl -sS --resolve payment.ofm.local:80:172.22.0.2 "$@"
}

request_json() {
  local method="$1" path="$2" token="$3" payload="$4" expected="$5" name="$6" body="$tmp_dir/body"
  local status attempt delay
  local delays=(0 1 5 10 30 60)
  for attempt in "${!delays[@]}"; do
    delay="${delays[$attempt]}"
    (( delay > 0 )) && { printf '%s retry %s/%s after %ss\n' "$name" "$attempt" "$((${#delays[@]} - 1))" "$delay"; sleep "$delay"; }
    status="$(api -H "authorization: Bearer $token" -H 'content-type: application/json' \
      -X "$method" "$API_BASE_URL$path" -d "$payload" -o "$body" -w '%{http_code}')"
    printf '%s HTTP %s attempt=%s\n' "$name" "$status" "$((attempt + 1))"
    jq . "$body" 2>/dev/null || sed -n '1,120p' "$body"
    if [[ "$expected" == "2xx" && "$status" =~ ^2[0-9][0-9]$ ]] || [[ "$expected" != "2xx" && "$status" == "$expected" ]]; then
      cp "$body" "$tmp_dir/${name//[^a-zA-Z0-9_-]/_}.json"
      return 0
    fi
    if [[ ! "$status" =~ ^(408|409|412|425|429|5[0-9][0-9])$ || "$attempt" -eq $((${#delays[@]} - 1)) ]]; then
      break
    fi
  done
  echo "FAILED: $name expected $expected, got $status after retry backoff" >&2
  exit 1
}

request_media() {
  local token="$1" gig_id="$2" file="$3" name="$4" body="$tmp_dir/body"
  local status attempt delay
  local delays=(0 1 5 10 30 60)
  for attempt in "${!delays[@]}"; do
    delay="${delays[$attempt]}"
    (( delay > 0 )) && { printf '%s retry %s/%s after %ss\n' "$name" "$attempt" "$((${#delays[@]} - 1))" "$delay"; sleep "$delay"; }
    status="$(api -H "authorization: Bearer $token" -X PUT "$API_BASE_URL/gigs/$gig_id/media" \
      -F "gig_id=$gig_id" -F "files=@$file;filename=single-e2e.txt" -o "$body" -w '%{http_code}')"
    printf '%s HTTP %s attempt=%s\n' "$name" "$status" "$((attempt + 1))"
    jq . "$body" 2>/dev/null || cat "$body"
    [[ "$status" =~ ^2[0-9][0-9]$ ]] && { cp "$body" "$tmp_dir/${name//[^a-zA-Z0-9_-]/_}.json"; return 0; }
    [[ "$status" =~ ^(408|409|425|429|5[0-9][0-9])$ && "$attempt" -lt $((${#delays[@]} - 1)) ]] || break
  done
  echo "FAILED: $name expected a 2xx response, got $status after retry backoff" >&2
  exit 1
}

kafka_cli() {
  local duration="$1"
  shift
  local exit_code
  # Keep timeout and the Kafka JVM in one process group. Otherwise a timed
  # Kafka shell command can leave GetOffsetShell/DeleteRecords running and
  # eventually saturate the local broker.
  docker exec "$KAFKA_CONTAINER" timeout --foreground -k 2s "$duration" "$@"
  exit_code=$?
  return "$exit_code"
}

clear_recovery_backlog() {
  command -v docker >/dev/null || { echo 'FAILED: docker is required to clear the Kafka recovery backlog' >&2; exit 1; }
  docker inspect "$KAFKA_CONTAINER" >/dev/null 2>&1 || {
    echo "FAILED: Kafka container $KAFKA_CONTAINER was not found" >&2
    exit 1
  }

  local topics=(
    migration.recovery.commands
    migration.recovery.commands.gig
    migration.recovery.commands.user
    migration.recovery.commands.auth
    migration.recovery.commands.chat
    migration.recovery.commands.file
    migration.recovery.commands.order
    migration.recovery.commands.orders
    migration.recovery.commands.payment
    migration.recovery.commands.review
    migration.recovery.commands.order_saga
    migration.recovery.commands.registration
    migration.recovery.commands.dlq
    migration.recovery.completed
  )
  local offsets_file topic line partition offset topic_list topic_offsets topic_count=0 partition_count=0
  offsets_file="$tmp_dir/recovery-delete-offsets.json"
  printf '{"partitions":[' > "$offsets_file"
  local first=1
  topic_list="$tmp_dir/recovery-topics"
  if ! kafka_cli 25s /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server kafka:19092 --list > "$topic_list" 2>"$tmp_dir/recovery-topics.err"; then
    echo 'FAILED: Kafka did not return the topic list; recovery backlog was not cleared' >&2
    sed -n '1,80p' "$tmp_dir/recovery-topics.err" >&2 || true
    exit 1
  fi
  for topic in "${topics[@]}"; do
    if ! rg -Fxq "$topic" "$topic_list"; then
      continue
    fi
    topic_count=$((topic_count + 1))
    topic_offsets=''
    local offsets_ready=0
    for offsets_attempt in {1..5}; do
      if topic_offsets="$(kafka_cli 25s /opt/kafka/bin/kafka-get-offsets.sh \
        --bootstrap-server kafka:19092 --topic "$topic" --time -1 2>"$tmp_dir/recovery-offsets.err")" \
        && [[ -n "$topic_offsets" ]]; then
        offsets_ready=1
        break
      fi
      sleep 2
    done
    if (( offsets_ready == 0 )); then
      echo "FAILED: Kafka did not return offsets for topic $topic; recovery backlog was not cleared" >&2
      sed -n '1,80p' "$tmp_dir/recovery-offsets.err" >&2 || true
      exit 1
    fi
    while IFS=: read -r _ partition offset; do
      [[ "$partition" =~ ^[0-9]+$ && "$offset" =~ ^[0-9]+$ ]] || continue
      (( first == 0 )) && printf ',' >> "$offsets_file"
      printf '{"topic":"%s","partition":%s,"offset":%s}' "$topic" "$partition" "$offset" >> "$offsets_file"
      first=0
      partition_count=$((partition_count + 1))
    done <<< "$topic_offsets"
  done
  if (( topic_count == 0 || partition_count == 0 )); then
    echo "FAILED: Kafka returned no recovery topics/partitions (topics=$topic_count partitions=$partition_count); backlog was not cleared" >&2
    exit 1
  fi
  printf '],"version":1}\n' >> "$offsets_file"
  docker cp "$offsets_file" "$KAFKA_CONTAINER:/tmp/recovery-delete-offsets.json" >/dev/null
  if ! kafka_cli 50s /opt/kafka/bin/kafka-delete-records.sh \
    --bootstrap-server kafka:19092 --offset-json-file /tmp/recovery-delete-offsets.json \
    > "$tmp_dir/recovery-delete-result" 2>"$tmp_dir/recovery-delete.err"; then
    echo 'FAILED: Kafka delete-records failed; recovery backlog was not cleared' >&2
    sed -n '1,120p' "$tmp_dir/recovery-delete.err" >&2 || true
    sed -n '1,120p' "$tmp_dir/recovery-delete-result" >&2 || true
    exit 1
  fi
  if rg -qi 'error|failed|unknown topic|exception' "$tmp_dir/recovery-delete-result"; then
    echo 'FAILED: Kafka delete-records reported an error; recovery backlog was not cleared' >&2
    sed -n '1,120p' "$tmp_dir/recovery-delete-result" >&2
    exit 1
  fi

  printf 'Kafka recovery backlog cleared topics=%s partitions=%s\n' "$topic_count" "$partition_count"
}

restart_recovery_consumers() {
  local deployments=(
    auth-service chat-service file-service gig-service monolith
    order-service order-saga-service payment-service registration-saga-service
    review-service user-service
  )
  kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" rollout restart \
    "${deployments[@]/#/deployment/}" >/dev/null
  local deployment
  for deployment in "${deployments[@]}"; do
    kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" rollout status \
      "deployment/$deployment" --timeout=180s >/dev/null
  done
  printf 'Recovery consumers restarted count=%s\n' "${#deployments[@]}"
}

if [[ "$FAULT_SERVICE_DOWN" == "true" ]]; then
  kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" scale deployment/gig-service --replicas=0 >/dev/null
  gig_service_disabled=1
  kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" get deployment/gig-service -o jsonpath='gig-service replicas={.spec.replicas}\n'
  clear_recovery_backlog
  restart_recovery_consumers
  if [[ "$CLEAN_ONLY" == "true" ]]; then
    printf 'Kafka recovery cleanup completed; business flow not started\n'
    exit 0
  fi
fi

suffix="$(date +%s%N)"
email="single_e2e_${suffix}@example.test"
username="single_e2e_${suffix}"

signup_payload="$(jq -cn --arg email "$email" --arg password "$PASSWORD" --arg username "$username" \
  '{email:$email,password:$password,username:$username,firstName:"SingleE2E",surname:"Test"}')"
request_json POST /auth/sign-up '' "$signup_payload" 202 signup
session_id="$(jq -r '.session_id' "$tmp_dir/signup.json")"
client_id="$(jq -r '.client_id' "$tmp_dir/signup.json")"

verify_payload="$(jq -cn --arg session_id "$session_id" --arg client_id "$client_id" \
  '{session_id:$session_id,client_id:$client_id,code:"123456"}')"
sleep "$REGISTRATION_WAIT_SECONDS"
request_json POST /auth/sign-up/verify-email '' "$verify_payload" 202 verify_email

complete_payload="$(jq -cn --arg session_id "$session_id" --arg client_id "$client_id" \
  '{session_id:$session_id,client_id:$client_id}')"
sleep "$REGISTRATION_WAIT_SECONDS"
request_json POST /auth/sign-up/complete '' "$complete_payload" 200 complete
token="$(jq -r '.access_token' "$tmp_dir/complete.json")"
[[ -n "$token" && "$token" != null ]] || { echo 'FAILED: signup returned no access token' >&2; exit 1; }

# Register a distinct buyer. A seller must never place an order for their own
# gig; order-saga treats that as a permanent business rejection.
buyer_suffix="$(date +%s%N)"
buyer_email="single_e2e_buyer_${buyer_suffix}@example.test"
buyer_username="single_e2e_buyer_${buyer_suffix}"
buyer_signup_payload="$(jq -cn --arg email "$buyer_email" --arg password "$PASSWORD" --arg username "$buyer_username" \
  '{email:$email,password:$password,username:$username,firstName:"SingleE2EBuyer",surname:"Test"}')"
request_json POST /auth/sign-up '' "$buyer_signup_payload" 202 buyer_signup
buyer_session_id="$(jq -r '.session_id' "$tmp_dir/buyer_signup.json")"
buyer_client_id="$(jq -r '.client_id' "$tmp_dir/buyer_signup.json")"
buyer_verify_payload="$(jq -cn --arg session_id "$buyer_session_id" --arg client_id "$buyer_client_id" \
  '{session_id:$session_id,client_id:$client_id,code:"123456"}')"
sleep "$REGISTRATION_WAIT_SECONDS"
request_json POST /auth/sign-up/verify-email '' "$buyer_verify_payload" 202 buyer_verify_email
buyer_complete_payload="$(jq -cn --arg session_id "$buyer_session_id" --arg client_id "$buyer_client_id" \
  '{session_id:$session_id,client_id:$client_id}')"
sleep "$REGISTRATION_WAIT_SECONDS"
request_json POST /auth/sign-up/complete '' "$buyer_complete_payload" 200 buyer_complete
buyer_token="$(jq -r '.access_token' "$tmp_dir/buyer_complete.json")"
[[ -n "$buyer_token" && "$buyer_token" != null ]] || { echo 'FAILED: buyer signup returned no access token' >&2; exit 1; }

# Publishing requires completed freelancer Connect onboarding in both the
# monolith fallback and gig-service. Start it through the public API, then
# complete the local fake-Stripe webhook before creating the gig.
request_json POST /freelancer/onboarding/start "$token" \
  '{"country":"US","return_url":"http://localhost/fake-stripe/return","refresh_url":"http://localhost/fake-stripe/refresh"}' 2xx freelancer_onboarding
stripe_account_id="$(jq -r '.stripe_account_id // empty' "$tmp_dir/freelancer_onboarding.json")"
onboarding_user_id="$(jq -r '.user_id // empty' "$tmp_dir/freelancer_onboarding.json")"
[[ -n "$stripe_account_id" && "$stripe_account_id" != null ]] || { echo 'FAILED: onboarding returned no stripe_account_id' >&2; exit 1; }
[[ -n "$onboarding_user_id" && "$onboarding_user_id" != null ]] || { echo 'FAILED: onboarding returned no user_id' >&2; exit 1; }
connect_webhook_payload="$(jq -cn --arg event "single-e2e-connect-$stripe_account_id" --arg user_id "$onboarding_user_id" --arg account_id "$stripe_account_id" \
  '{event_id:$event,provider:"fake-stripe",event_type:"account.updated",user_id:$user_id,stripe_account_id:$account_id,details_submitted:true,charges_enabled:true,payouts_enabled:true}')"
for webhook_delay in 0 1 5 10 30 60; do
  (( webhook_delay > 0 )) && { printf 'connect_webhook retry after %ss\n' "$webhook_delay"; sleep "$webhook_delay"; }
  status="$(payment_api -H 'content-type: application/json' -H "authorization: Bearer $token" \
    -X POST http://payment.ofm.local/v1/fake-stripe/webhooks/connect -d "$connect_webhook_payload" \
    -o "$tmp_dir/connect_webhook.json" -w '%{http_code}')"
  printf 'connect_webhook HTTP %s\n' "$status"; jq . "$tmp_dir/connect_webhook.json" 2>/dev/null || cat "$tmp_dir/connect_webhook.json"
  [[ "$status" =~ ^2[0-9][0-9]$ ]] && break
  [[ "$status" =~ ^(408|409|425|429|5[0-9][0-9])$ ]] || { echo "FAILED: connect webhook expected a 2xx response, got $status" >&2; exit 1; }
done
[[ "$status" =~ ^2[0-9][0-9]$ ]] || { echo "FAILED: connect webhook did not succeed after retry backoff" >&2; exit 1; }
sleep 2

request_json POST /gigs/drafts "$token" \
  '{"title":"single E2E gig","description":"single E2E description"}' 202 gig_draft
gig_id="$(jq -r '.gig_id // .resource_id' "$tmp_dir/gig_draft.json")"
[[ -n "$gig_id" && "$gig_id" != null ]] || { echo 'FAILED: gig draft returned no gig_id' >&2; exit 1; }

request_json PATCH "/gigs/$gig_id/basic-info" "$token" \
  "$(jq -cn --arg gig_id "$gig_id" '{gig_id:$gig_id,title:"single E2E gig",short_info:"single E2E",description:"single E2E description",category_id:1001,currency:"usd"}')" 2xx gig_basic_info
request_json PUT "/gigs/$gig_id/packages" "$token" \
	"$(jq -cn --arg gig_id "$gig_id" '{gig_id:$gig_id,packages:[{tier:"basic",description:"basic",delivery_days:3,price_cents:10000},{tier:"standard",description:"standard",delivery_days:5,price_cents:20000},{tier:"premium",description:"premium",delivery_days:7,price_cents:30000}]}')" 2xx gig_packages
request_json PUT "/gigs/$gig_id/requirements" "$token" \
  "$(jq -cn --arg gig_id "$gig_id" '{gig_id:$gig_id,questions:[{content:"What do you need?"},{content:"Reference?"}]}')" 2xx gig_requirements

printf 'media payload uses the same multipart contract as k6\n'
printf 'single E2E media\n' > "$tmp_dir/media.txt"
request_media "$token" "$gig_id" "$tmp_dir/media.txt" gig_media

request_json POST "/gigs/$gig_id/publish" "$token" "$(jq -cn --arg gig_id "$gig_id" '{gig_id:$gig_id}')" 2xx gig_publish

sleep "$PROJECTION_WAIT_SECONDS"
status="$(api -H "authorization: Bearer $token" "$API_BASE_URL/gigs/$gig_id/draft" -o "$tmp_dir/draft.json" -w '%{http_code}')"
printf 'gig_draft_read HTTP %s\n' "$status"; jq . "$tmp_dir/draft.json"
[[ "$status" == 200 ]] || { echo "FAILED: gig draft read expected HTTP 200, got $status" >&2; exit 1; }
package_id="$(jq -r '.packages[0].id // .packages[0].package_id // empty' "$tmp_dir/draft.json")"
[[ -n "$package_id" ]] || { echo 'FAILED: no committed package in gig draft; order was not attempted' >&2; exit 1; }

# While gig-service is down, intentionally continue through the legacy fallback.
# The fallback draft returns numeric IDs; keep those IDs together for order start.
order_gig_id="$(jq -r '.gig_id // .id // empty' "$tmp_dir/draft.json")"
[[ -n "$order_gig_id" ]] || { echo 'FAILED: fallback draft returned no gig_id' >&2; exit 1; }

request_json POST /orders/start "$buyer_token" \
  "$(jq -cn --arg gig_id "$order_gig_id" --arg package_id "$package_id" '{gig_id:$gig_id,package_id:$package_id}')" 201 order_start
order_id="$(jq -r '.order_id // .resource_id // .id' "$tmp_dir/order_start.json")"
[[ -n "$order_id" && "$order_id" != null ]] || { echo 'FAILED: order returned no order_id' >&2; exit 1; }

if [[ "$gig_service_disabled" == "1" ]]; then
  sleep 10
  kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" scale deployment/gig-service --replicas=1 >/dev/null
  kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" rollout status deployment/gig-service --timeout=120s
  gig_service_disabled=0
  projection_ready=0
  projection_delays=(1 5 10 30 60)
  for projection_delay in "${projection_delays[@]}"; do
    sleep "$projection_delay"
    status="$(api -H "authorization: Bearer $token" "$API_BASE_URL/gigs/$gig_id/draft" -o "$tmp_dir/projected_draft.json" -w '%{http_code}')"
    projection_complete="$(jq -r '[.basic_info_completed,.packages_completed,.requirements_completed,.media_completed] | all' "$tmp_dir/projected_draft.json" 2>/dev/null || printf 'false')"
    package_count="$(jq '.packages | length' "$tmp_dir/projected_draft.json" 2>/dev/null || printf '0')"
    printf 'microservice_gig_draft HTTP %s complete=%s packages=%s\n' "$status" "$projection_complete" "$package_count"
    jq . "$tmp_dir/projected_draft.json"
    projected_gig_id="$(jq -r '.gig_id // .id // empty' "$tmp_dir/projected_draft.json")"
    if [[ "$status" == 200 && "$projected_gig_id" == "$gig_id" && "$projection_complete" == true && "$package_count" == 3 ]]; then
      projection_ready=1
      break
    fi
  done
  [[ "$projection_ready" == 1 ]] || {
    echo 'FAILED: recovered microservice projection did not become complete after 1s, 5s, 10s, 30s, and 60s' >&2
    exit 1
  }

  # The order was accepted while gig-service was down.  Verify that the
  # recovery consumers subsequently materialized both order projections.
  postgres_query() {
    local container="$1" database="$2" query="$3"
    docker exec "$container" psql -U admin -d "$database" -At -c "$query"
  }

  order_projection_count="$(postgres_query ofm-order-service-postgres order_service \
    "SELECT count(*) FROM orders WHERE order_id = '$order_id';")"
  order_snapshot_count="$(postgres_query ofm-order-service-postgres order_service \
    "SELECT count(*) FROM order_gig_snapshot WHERE order_id = '$order_id';")"
  saga_projection_count="$(postgres_query ofm-order-saga-service-postgres order_saga \
    "SELECT count(*) FROM order_saga_sessions WHERE order_id = '$order_id';")"

  printf 'order projection rows=%s snapshot rows=%s saga projection rows=%s\n' \
    "$order_projection_count" "$order_snapshot_count" "$saga_projection_count"

  if [[ "$order_projection_count" != 1 || "$order_snapshot_count" != 1 || "$saga_projection_count" != 1 ]]; then
    echo "FAILED: recovery did not complete order projections for $order_id" >&2
    echo '--- order-service recovery logs ---' >&2
    kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" logs deploy/order-service --since=15m 2>&1 | rg "$order_id|recovery|DLQ|retry" >&2 || true
    echo '--- order-saga-service recovery logs ---' >&2
    kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" logs deploy/order-saga-service --since=15m 2>&1 | rg "$order_id|recovery|DLQ|retry" >&2 || true
    exit 1
  fi
fi

printf '\nSUCCESS\nusername=%s\ngig_id=%s\npackage_id=%s\norder_id=%s\n' "$username" "$gig_id" "$package_id" "$order_id"
