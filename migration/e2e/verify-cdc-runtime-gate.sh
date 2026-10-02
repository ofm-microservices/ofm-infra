#!/usr/bin/env bash
set -Eeuo pipefail

# Runtime gate for the shared compact migration stack. A running connector or
# non-empty topic proves wiring only; write-by-write E2E remains a separate gate.
kafka_container="${KAFKA_CONTAINER:-ofm-migration-kafka}"
debezium_container="${DEBEZIUM_CONTAINER:-ofm-migration-debezium}"

connect_status() {
  local container="$1"
  docker exec "$container" curl -fsS 'http://127.0.0.1:8083/connectors?expand=status' |
    jq -r 'to_entries[] | [.key,.value.status.connector.state,([.value.status.tasks[].state] | join(","))] | @tsv'
}

echo '## PostgreSQL Debezium connectors'
connect_status "$debezium_container"

echo '## Canonical topic offsets'
while IFS= read -r topic; do
  [[ -z "$topic" ]] && continue
  offset="$(docker exec "$kafka_container" /opt/kafka/bin/kafka-get-offsets.sh \
    --bootstrap-server kafka:19092 --topic "$topic" 2>/dev/null | awk -F: 'NR==1 {print $3}')"
  printf '%s\t%s\n' "$topic" "${offset:-0}"
done <<'TOPICS'
migration.auth.credentials.created
migration.auth.credentials.updated
migration.user.profile.created
migration.user.profile.updated
migration.gig-service.gigs.changed
migration.gig-service.gig_packages.changed
migration.gig-service.gig_questions.changed
migration.gig-service.gig_media.changed
migration.order-service.orders.changed
migration.order-saga-service.order_saga.changed
migration.payment-service.payment_intents.changed
migration.payment-service.payment_releases.changed
migration.payment-service.payment_webhook_events.changed
migration.payment-service.connect_accounts.changed
migration.review-service.reviews.changed
migration.chat-service.chat.changed
migration.file-service.files.changed
migration.registration-saga-service.registration.changed
TOPICS

echo '## Side-effect consumer groups'
for group in mail-service realtime-service search-service; do
  docker exec "$kafka_container" /opt/kafka/bin/kafka-consumer-groups.sh \
    --bootstrap-server kafka:19092 --describe --group "$group" 2>/dev/null || true
done

echo '## Schema Registry groups'
docker exec ofm-migration-schema-registry curl -fsS \
  'http://127.0.0.1:8080/apis/registry/v3/groups/default/artifacts' |
  jq '{artifact_count:(.artifacts|length), artifacts:(.artifacts|map(.artifactId))}'
