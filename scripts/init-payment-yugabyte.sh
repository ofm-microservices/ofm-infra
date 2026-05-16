#!/usr/bin/env bash
set -euo pipefail

host="payment-service-yugabyte"
admin_db="yugabyte"
service_db="payment_service"
bootstrap_user="yugabyte"

until ysqlsh -h "${host}" -U "${bootstrap_user}" -d "${admin_db}" -c "SELECT 1" >/dev/null 2>&1; do
  sleep 2
done

ysqlsh -h "${host}" -U "${bootstrap_user}" -d "${admin_db}" <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin') THEN
    CREATE ROLE admin WITH LOGIN SUPERUSER PASSWORD 'admin';
  ELSE
    ALTER ROLE admin WITH LOGIN SUPERUSER PASSWORD 'admin';
  END IF;
END
$$;
SQL

if ! ysqlsh -h "${host}" -U "${bootstrap_user}" -d "${admin_db}" -tAc "SELECT 1 FROM pg_database WHERE datname = '${service_db}'" | grep -q 1; then
  ysqlsh -h "${host}" -U "${bootstrap_user}" -d "${admin_db}" -c "CREATE DATABASE ${service_db} OWNER admin;"
fi

ysqlsh -h "${host}" -U "${bootstrap_user}" -d "${service_db}" -c "ALTER DATABASE ${service_db} OWNER TO admin;" || true

exit 0
