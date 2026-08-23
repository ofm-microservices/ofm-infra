#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
scan="$root/.production-write-scan.$$"
trap 'rm -f "$scan"' EXIT

rg -n -i -g '*.go' -g '!**/*_test.go' \
  '(INSERT[[:space:]]+INTO|UPDATE[[:space:]]+[A-Za-z_][A-Za-z0-9_]*|DELETE[[:space:]]+FROM)' \
  "$root"/ofm-*-service/internal/infra >"$scan"

declare -A covered=(
  [auth_credentials]=1 [email_verification_codes]=1 [auth_user_roles]=1 [refresh_tokens]=1
  [users]=1 [gigs]=1 [gig_packages]=1 [gig_questions]=1 [gig_media]=1
  [orders]=1 [order_gig_snapshot]=1 [order_question_snapshots]=1 [order_requirement_answers]=1
  [order_buyer_messages]=1 [order_attachments]=1 [order_checkout_sessions]=1 [order_deliveries]=1
  [order_revision_requests]=1 [order_disputes]=1 [order_delivery_files]=1
  [payment_intents]=1 [payment_webhook_events]=1 [connect_accounts]=1 [payment_releases]=1
  [reviews]=1 [chats_by_order]=1 [chat_messages_by_order]=1 [chat_messages_by_id]=1
  [files]=1 [order_saga_sessions]=1 [order_saga_steps]=1
  [registration_sessions]=1 [registration_sessions_by_email]=1
  [registration_sessions_by_username]=1 [registration_steps]=1
)

declare -A nonSQL=(
  [SET]=1 [basic]=1 [failures]=1 [gig]=1 [payment]=1 [registration]=1 [seller]=1
)

uncovered=0
locations=0
while IFS= read -r source_line; do
  table="$(sed -E 's/.*(INSERT[[:space:]]+INTO|UPDATE|DELETE[[:space:]]+FROM)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\2/I' <<<"$source_line")"
  [[ -z "$table" ]] && continue
  [[ -n "${nonSQL[$table]+x}" ]] && continue
  locations=$((locations + 1))
  location="${source_line%%:*}:${source_line#*:}"
  if [[ -z "${covered[$table]+x}" ]]; then
    printf 'UNMAPPED production write location: %s table=%s\n' "$location" "$table"
    uncovered=1
  elif [[ "$table" == chats_by_order || "$table" == chat_messages_by_order || "$table" == chat_messages_by_id || "$table" == files || "$table" == order_saga_sessions || "$table" == order_saga_steps || "$table" == registration_sessions || "$table" == registration_sessions_by_email || "$table" == registration_sessions_by_username || "$table" == registration_steps ]]; then
    printf 'COVERED %s table=%s route=scylla-cdc\n' "$location" "$table"
  else
    printf 'COVERED %s table=%s route=yugabyte-outbox-debezium\n' "$location" "$table"
  fi
done < "$scan"

if (( uncovered != 0 )); then
  exit 1
fi

printf 'All production write tables are mapped to Outbox trigger or native Scylla CDC coverage.\n'
printf 'Source mutation locations: %s\n' "$locations"
