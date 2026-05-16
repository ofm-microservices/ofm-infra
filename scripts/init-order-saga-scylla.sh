#!/usr/bin/env bash
set -euo pipefail

host="order-saga-service-scylla"
admin_db="system"
service_keyspace="order_saga"
bootstrap_user="cassandra"

until cqlsh "${host}" 9042 -u "${bootstrap_user}" -p "${bootstrap_user}" -e "DESCRIBE KEYSPACES" >/dev/null 2>&1; do
  sleep 2
done

cqlsh "${host}" 9042 -u "${bootstrap_user}" -p "${bootstrap_user}" <<'SQL'
CREATE KEYSPACE IF NOT EXISTS order_saga
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};
SQL

cqlsh "${host}" 9042 -u "${bootstrap_user}" -p "${bootstrap_user}" -e "CREATE ROLE IF NOT EXISTS admin WITH PASSWORD = 'admin' AND LOGIN = true AND SUPERUSER = true;"

exit 0
