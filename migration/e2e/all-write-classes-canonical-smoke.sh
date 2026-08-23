#!/usr/bin/env bash
set -euo pipefail

kafka="ofm-migration-kafka"
prefix="${1:-cdc-matrix-$(date +%s)}"
only="${2:-}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# service|database|table|source-topic|canonical-event-type|route
entries=(
  'auth-service|auth_service|auth_credentials|cdc.auth.public.outbox_events|auth.credentials|yb'
  'auth-service|auth_service|email_verification_codes|cdc.auth.public.outbox_events|auth.email_verification_codes.changed|yb'
  'auth-service|auth_service|auth_user_roles|cdc.auth.public.outbox_events|auth.auth_user_roles.changed|yb'
  'auth-service|auth_service|refresh_tokens|cdc.auth.public.outbox_events|auth.refresh_tokens.changed|yb'
  'user-service|user_service|users|cdc.user.public.outbox_events|user.profile|yb'
  'gig-service|gig_service|gigs|cdc.gig.public.outbox_events|gig-service.gigs.changed|yb'
  'gig-service|gig_service|gig_packages|cdc.gig.public.outbox_events|gig-service.gig_packages.changed|yb'
  'gig-service|gig_service|gig_questions|cdc.gig.public.outbox_events|gig-service.gig_questions.changed|yb'
  'gig-service|gig_service|gig_media|cdc.gig.public.outbox_events|gig-service.gig_media.changed|yb'
  'order-service|order_service|orders|cdc.order.public.outbox_events|order-service.orders.changed|yb'
  'order-service|order_service|order_gig_snapshot|cdc.order.public.outbox_events|order-service.orders.changed|yb'
  'order-service|order_service|order_question_snapshots|cdc.order.public.outbox_events|order-service.orders.changed|yb'
  'order-service|order_service|order_requirement_answers|cdc.order.public.outbox_events|order-service.orders.changed|yb'
  'order-service|order_service|order_buyer_messages|cdc.order.public.outbox_events|order-service.orders.changed|yb'
  'order-service|order_service|order_attachments|cdc.order.public.outbox_events|order-service.orders.changed|yb'
  'order-service|order_service|order_checkout_sessions|cdc.order.public.outbox_events|order-service.orders.changed|yb'
  'order-service|order_service|order_deliveries|cdc.order.public.outbox_events|order-service.orders.changed|yb'
  'order-service|order_service|order_revision_requests|cdc.order.public.outbox_events|order-service.orders.changed|yb'
  'order-service|order_service|order_disputes|cdc.order.public.outbox_events|order-service.orders.changed|yb'
  'order-service|order_service|order_delivery_files|cdc.order.public.outbox_events|order-service.orders.changed|yb'
  'payment-service|payment_service|payment_intents|cdc.payment.public.outbox_events|payment-service.payment_intents.changed|yb'
  'payment-service|payment_service|payment_webhook_events|cdc.payment.public.outbox_events|payment-service.payment_webhook_events.changed|yb'
  'payment-service|payment_service|connect_accounts|cdc.payment.public.outbox_events|payment-service.connect_accounts.changed|yb'
  'payment-service|payment_service|payment_releases|cdc.payment.public.outbox_events|payment-service.payment_releases.changed|yb'
  'review-service|review_service|reviews|cdc.review.public.outbox_events|review-service.reviews.changed|yb'
  'chat-service|chat_service|chats_by_order|migration-chat.chat_service.chats_by_order|chat-service.chat.changed|scylla'
  'chat-service|chat_service|chat_messages_by_order|migration-chat.chat_service.chat_messages_by_order|chat-service.chat.changed|scylla'
  'chat-service|chat_service|chat_messages_by_id|migration-chat.chat_service.chat_messages_by_id|chat-service.chat.changed|scylla'
  'file-service|file_service|files|migration-file.file_service.files|file-service.files.changed|scylla'
  'order-saga-service|order_saga|order_saga_sessions|migration-order-saga.order_saga.order_saga_sessions|order-saga-service.order_saga.changed|scylla'
  'order-saga-service|order_saga|order_saga_steps|migration-order-saga.order_saga.order_saga_steps|order-saga-service.order_saga.changed|scylla'
  'registration-saga-service|registration_saga_service|registration_sessions|migration-registration-saga.registration_saga_service.registration_sessions|registration-saga-service.registration.changed|scylla'
  'registration-saga-service|registration_saga_service|registration_sessions_by_email|migration-registration-saga.registration_saga_service.registration_sessions_by_email|registration-saga-service.registration.changed|scylla'
  'registration-saga-service|registration_saga_service|registration_sessions_by_username|migration-registration-saga.registration_saga_service.registration_sessions_by_username|registration-saga-service.registration.changed|scylla'
  'registration-saga-service|registration_saga_service|registration_steps|migration-registration-saga.registration_saga_service.registration_steps|registration-saga-service.registration.changed|scylla'
)

# Avoid metadata races while the bridge provisions a topic for the first time.
for topic in migration.auth.credentials.created migration.auth.credentials.updated migration.auth.credentials.deactivated migration.user.profile.created migration.user.profile.updated migration.user.profile.deactivated migration.auth.email_verification_codes.changed migration.auth.auth_user_roles.changed migration.auth.refresh_tokens.changed migration.gig-service.gigs.changed migration.gig-service.gig_packages.changed migration.gig-service.gig_questions.changed migration.gig-service.gig_media.changed migration.order-service.orders.changed migration.payment-service.payment_intents.changed migration.payment-service.payment_webhook_events.changed migration.payment-service.connect_accounts.changed migration.payment-service.payment_releases.changed migration.review-service.reviews.changed migration.chat-service.chat.changed migration.file-service.files.changed migration.order-saga-service.order_saga.changed migration.registration-saga-service.registration.changed; do
  docker exec "$kafka" /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --create --if-not-exists --topic "$topic" --partitions 1 --replication-factor 1 >/dev/null 2>&1 || true
done

declare -A source_files=()
selected_count=0
for entry in "${entries[@]}"; do
  IFS='|' read -r service db table source event_type route <<<"$entry"
  case "$only:$service" in
    yb-auth-user:auth-service|yb-auth-user:user-service|yb-domain:gig-service|yb-domain:order-service|yb-domain:payment-service|yb-domain:review-service|scylla-chat-file:chat-service|scylla-chat-file:file-service|scylla-sagas:order-saga-service|scylla-sagas:registration-saga-service) ;;
    yb-auth-user:*|yb-domain:*|scylla-chat-file:*|scylla-sagas:*) continue ;;
  esac
  selected_count=$((selected_count + 1))
  printf 'producing %s.%s\n' "$service" "$table"
  aggregate="${prefix}-${table}"
  for op in created updated deactivated; do
    marker="${aggregate}-${op}"
    canonical_type="$event_type"
    if [[ "$event_type" == auth.credentials || "$event_type" == user.profile ]]; then
      canonical_type="${event_type}.${op}"
    fi
    source_file="$work/source_$(printf '%s' "$source" | tr '.:' '__')"
    source_files["$source"]="$source_file"
    if [[ "$route" == yb ]]; then
      event="{\"event_id\":\"${marker}\",\"aggregate_type\":\"${table}\",\"aggregate_id\":\"${marker}\",\"event_type\":\"${canonical_type}\",\"operation\":\"${op}\",\"schema_version\":1,\"payload\":{\"id\":\"${marker}\"}}"
      printf '{"after":%s,"source":{"db":"%s","table":"outbox_events","ts_ms":1700000000000},"op":"c"}\n' "$event" "$db" >>"$source_file"
    else
      printf '{"after":{"id":"%s"},"source":{"db":"%s","table_name":"%s","ts_ms":1700000000000},"op":"%s"}\n' "$marker" "$db" "$table" "${op:0:1}" >>"$source_file"
    fi
  done
done

for source in "${!source_files[@]}"; do
  printf 'publishing source %s\n' "$source"
  docker exec -i "$kafka" /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server kafka:9092 --topic "$source" <"${source_files[$source]}" >/dev/null
done

case "$only" in
  yb-auth-user) consume_types=(auth.credentials.created auth.credentials.updated auth.credentials.deactivated user.profile.created user.profile.updated user.profile.deactivated auth.email_verification_codes.changed auth.auth_user_roles.changed auth.refresh_tokens.changed) ;;
  yb-domain) consume_types=(gig-service.gigs.changed gig-service.gig_packages.changed gig-service.gig_questions.changed gig-service.gig_media.changed order-service.orders.changed payment-service.payment_intents.changed payment-service.payment_webhook_events.changed payment-service.connect_accounts.changed payment-service.payment_releases.changed review-service.reviews.changed) ;;
  scylla-chat-file) consume_types=(chat-service.chat.changed file-service.files.changed) ;;
  scylla-sagas) consume_types=(order-saga-service.order_saga.changed registration-saga-service.registration.changed) ;;
  *) consume_types=(auth.credentials.created auth.credentials.updated auth.credentials.deactivated user.profile.created user.profile.updated user.profile.deactivated gig-service.gigs.changed gig-service.gig_packages.changed gig-service.gig_questions.changed gig-service.gig_media.changed order-service.orders.changed payment-service.payment_intents.changed payment-service.payment_webhook_events.changed payment-service.connect_accounts.changed payment-service.payment_releases.changed review-service.reviews.changed auth.email_verification_codes.changed auth.auth_user_roles.changed auth.refresh_tokens.changed chat-service.chat.changed file-service.files.changed order-saga-service.order_saga.changed registration-saga-service.registration.changed) ;;
esac
for event_type in "${consume_types[@]}"; do
  topic="migration.${event_type}"
  printf 'consuming %s\n' "$topic"
  docker exec "$kafka" /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic "$topic" --from-beginning --timeout-ms 200 2>/dev/null >"$work/${event_type//\//_}.out" || true
done

missing=0
for entry in "${entries[@]}"; do
  IFS='|' read -r _ _ table _ event_type _ <<<"$entry"
  service="$(cut -d'|' -f1 <<<"$entry")"
  case "$only:$service" in
    yb-auth-user:auth-service|yb-auth-user:user-service|yb-domain:gig-service|yb-domain:order-service|yb-domain:payment-service|yb-domain:review-service|scylla-chat-file:chat-service|scylla-chat-file:file-service|scylla-sagas:order-saga-service|scylla-sagas:registration-saga-service) ;;
    yb-auth-user:*|yb-domain:*|scylla-chat-file:*|scylla-sagas:*) continue ;;
  esac
  aggregate="${prefix}-${table}"
  # auth credentials/user profile use operation-specific topics.
  for op in created updated deactivated; do
    marker="${aggregate}-${op}"
    found=0
    while IFS= read -r file; do
      if rg -q "$marker" "$file"; then found=1; break; fi
    done < <(find "$work" -type f)
    if (( found == 0 )); then
      printf 'MISSING canonical marker: %s\n' "$marker"
      missing=1
    fi
  done
done
(( missing == 0 )) || exit 1
printf 'All %s production write-table classes passed canonical 3-operation smoke.\n' "$selected_count"
