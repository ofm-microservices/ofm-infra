#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
missing=0

yb_tables=(
  auth_credentials email_verification_codes auth_user_roles refresh_tokens
  users gigs gig_packages gig_questions gig_media
  orders order_gig_snapshot order_question_snapshots order_requirement_answers
  order_buyer_messages order_attachments order_checkout_sessions order_deliveries
  order_revision_requests order_disputes order_delivery_files
  payment_intents payment_webhook_events connect_accounts payment_releases reviews
)

for table in "${yb_tables[@]}"; do
  if ! rg -q "CREATE TRIGGER [A-Za-z0-9_]+ AFTER INSERT OR UPDATE OR DELETE ON ${table}\\b" "$root"/ofm-*-service/migration/yugabyte/*outbox_events.up.sql; then
    printf 'MISSING Yugabyte Outbox trigger: %s\n' "$table"
    missing=1
  fi
done

scylla_tables=(
  chats_by_order chat_messages_by_order chat_messages_by_id files
  order_saga_sessions order_saga_steps registration_sessions
  registration_sessions_by_email registration_sessions_by_username registration_steps
)
for table in "${scylla_tables[@]}"; do
  if ! rg -q "${table}" "$root/ofm-infra/docker-compose.migration-runtime.yaml"; then
    printf 'MISSING Scylla CDC declaration: %s\n' "$table"
    missing=1
  fi
done

(( missing == 0 )) || exit 1
printf 'All %s Yugabyte tables have Outbox triggers and all %s Scylla tables have CDC declarations.\n' "${#yb_tables[@]}" "${#scylla_tables[@]}"
