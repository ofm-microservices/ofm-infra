#!/usr/bin/env bash
set -euo pipefail

# Smoke-test the Scylla CDC -> Kafka -> canonical bridge path. The caller must
# provide a unique ID and the migration runtime must already be running.
id="${1:-cdc-e2e-$(date +%s)}"
kafka="ofm-migration-kafka"

cql() {
  docker exec "$1" cqlsh -u admin -p admin -e "$2" >/dev/null
}

poll_topic() {
  local topic="$1" needle="$2"
  for _ in $(seq 1 18); do
    if docker exec "$kafka" /opt/kafka/bin/kafka-console-consumer.sh \
      --bootstrap-server kafka:9092 --topic "$topic" --from-beginning \
      --timeout-ms 4000 2>/dev/null | rg -q "$needle"; then
      return 0
    fi
    sleep 5
  done
  echo "canonical event not observed: topic=$topic needle=$needle" >&2
  return 1
}

cql ofm-order-saga-service-scylla "INSERT INTO order_saga.order_saga_steps (saga_id,step_key,status) VALUES ('$id','cdc','started'); UPDATE order_saga.order_saga_steps SET status='done' WHERE saga_id='$id' AND step_key='cdc'; DELETE FROM order_saga.order_saga_steps WHERE saga_id='$id' AND step_key='cdc';"
cql ofm-registration-saga-service-scylla "INSERT INTO registration_saga_service.registration_steps (session_id,step_key,status) VALUES ('$id','cdc','started'); UPDATE registration_saga_service.registration_steps SET status='done' WHERE session_id='$id' AND step_key='cdc'; DELETE FROM registration_saga_service.registration_steps WHERE session_id='$id' AND step_key='cdc';"

poll_topic migration.order-saga-service.order_saga.changed "$id"
poll_topic migration.registration-saga-service.registration.changed "$id"
echo "Scylla CDC canonical smoke passed for $id"
