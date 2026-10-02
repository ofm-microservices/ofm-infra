#!/usr/bin/env bash
set -euo pipefail

# PostgreSQL is the source of truth for every service database. The CDC
# topology is one Debezium PostgreSQL connector per service.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
config="$root/ofm-infra/docker-compose.migration-compact.yaml"
missing=0

for connector in cdc-auth cdc-user cdc-gig cdc-order cdc-payment cdc-review \
                 cdc-chat cdc-file cdc-order-saga cdc-registration-saga; do
  if ! rg -q "${connector}" "$config" "$root/ofm-infra/migration"; then
    printf 'MISSING PostgreSQL Debezium connector: %s\n' "$connector"
    missing=1
  fi
done

for service in auth user gig order payment review chat file order-saga registration-saga; do
  if [[ ! -d "$root/ofm-${service}-service/migration/postgres" ]]; then
    printf 'MISSING PostgreSQL migration directory: %s\n' "$service"
    missing=1
  fi
done

(( missing == 0 )) || exit 1
printf 'All 10 services have PostgreSQL migrations and PostgreSQL Debezium connector configuration.\n'
