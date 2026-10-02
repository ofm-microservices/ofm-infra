#!/usr/bin/env bash
set -euo pipefail

kafka="ofm-migration-kafka"
source_topic="migration-registration-saga.registration_saga_service.registration_sessions"
dlq_topic="migration.dead-letter"
id="${1:-cdc-dlq-$(date +%s)}"
expected_delivery_count="${EXPECTED_DLQ_DELIVERY_COUNT:-5}"

offsets() {
  docker exec "$kafka" /opt/kafka/bin/kafka-get-offsets.sh \
    --bootstrap-server kafka:19092 --topic "$dlq_topic" 2>/dev/null \
    | awk -F: '$2 == 0 {print $3}'
}

before="$(offsets)"
payload="{\"source\":{\"db\":\"registration_saga_service\",\"table_name\":\"registration_sessions\",\"ts_ms\":1700000000000},\"after\":{\"marker\":\"$id\"},\"op\":\"c\"}"
printf '%s\n' "$payload" | docker exec -i "$kafka" /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server kafka:19092 --topic "$source_topic" >/dev/null

for _ in $(seq 1 18); do
  after="$(offsets)"
  if [[ "$after" -gt "$before" ]]; then
    docker exec "$kafka" /opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server kafka:19092 --topic "$dlq_topic" --partition 0 \
      --offset "$before" --max-messages 20 --timeout-ms 4000 \
      --property print.headers=true 2>/dev/null | tee /tmp/ofm-dlq-smoke.out | rg -q "$id" && break
  fi
  sleep 5
done

test -s /tmp/ofm-dlq-smoke.out
rg -q "$id" /tmp/ofm-dlq-smoke.out
rg -q "delivery-count:${expected_delivery_count}" /tmp/ofm-dlq-smoke.out
rg -q 'original-topic:' /tmp/ofm-dlq-smoke.out
rg -q 'dead-letter-reason:' /tmp/ofm-dlq-smoke.out
echo "retry/DLQ smoke passed for $id"
