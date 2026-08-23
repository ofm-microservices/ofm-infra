#!/bin/sh
set -eu

base='http://127.0.0.1:8083'
for _ in $(seq 1 60); do
  if wget -qO- "$base/" >/dev/null 2>&1; then break; fi
  sleep 1
done

register() {
  name="$1"
  prefix="$2"
  host="$3"
  tables="$4"
  config="{\"connector.class\":\"com.scylladb.cdc.debezium.connector.ScyllaConnector\",\"topic.prefix\":\"$prefix\",\"key.converter\":\"org.apache.kafka.connect.json.JsonConverter\",\"key.converter.schemas.enable\":\"false\",\"value.converter\":\"org.apache.kafka.connect.json.JsonConverter\",\"value.converter.schemas.enable\":\"false\",\"tasks.max\":\"1\",\"scylla.cluster.ip.addresses\":\"$host\",\"scylla.user\":\"admin\",\"scylla.password\":\"admin\",\"scylla.initial.lookback.ms\":\"60000\",\"scylla.name\":\"$prefix\",\"scylla.table.names\":\"$tables\"}"
  payload="{\"name\":\"$name\",\"config\":$config}"
  # Connector definitions are durable in Kafka Connect. Delete a stale
  # definition before replacing it so restarts cannot leave a connector with
  # an old Scylla host/table set or a missing task status.
  curl -sS -X DELETE "$base/connectors/$name" >/dev/null 2>&1 || true
  response=$(curl -sS --max-time 120 -X PUT "$base/connectors/$name/config" -H 'Content-Type: application/json' --data "$config" 2>&1)
  echo "connector $name registration response: $response"
  case "$response" in
    *error*)
    echo "connector $name registration failed: $response" >&2
    exit 1
    ;;
  esac
}

register cdc-chat migration-chat chat-service-scylla:9042 'chat_service.chats_by_order,chat_service.chat_messages_by_order,chat_service.chat_messages_by_id'
register cdc-file migration-file file-service-scylla:9042 'file_service.files'
register cdc-order-saga migration-order-saga order-saga-service-scylla:9042 'order_saga.order_saga_sessions,order_saga.order_saga_steps'
register cdc-registration-saga migration-registration-saga registration-saga-service-scylla:9042 'registration_saga_service.registration_sessions,registration_saga_service.registration_sessions_by_email,registration_saga_service.registration_sessions_by_username,registration_saga_service.registration_steps'

wait
