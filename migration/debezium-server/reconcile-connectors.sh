#!/bin/sh
set -eu

rest="http://migration-debezium:8083"
connector_dir="/kafka/config/ofm-connectors"

properties_json() {
  awk -F= '
    BEGIN { printf "{"; first=1 }
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    {
      key=$1; value=substr($0, index($0,"=")+1)
      gsub(/\\/, "\\\\", key); gsub(/"/, "\\\"", key)
      gsub(/\\/, "\\\\", value); gsub(/"/, "\\\"", value)
      if (!first) printf ","; first=0
      printf "\"%s\":\"%s\"", key, value
    }
    END { print "}" }
  ' "$1"
}

until curl -fsS "$rest/" >/dev/null 2>&1; do sleep 2; done

for service in auth user gig order payment review chat file order-saga registration-saga; do
  name="cdc-$service"
  register() {
    payload="$(properties_json "$connector_dir/$service.properties")"
    curl --max-time 120 -fsS -X PUT "$rest/connectors/$name/config" \
      -H 'Content-Type: application/json' --data "$payload" >/dev/null
  }
  running() {
    status="$(curl -fsS "$rest/connectors/$name/status" 2>/dev/null || true)"
    printf '%s' "$status" | grep -q '"connector".*"state":"RUNNING"' &&
      printf '%s' "$status" | grep -q '"tasks".*"state":"RUNNING"'
  }

  curl -sS --max-time 10 -X DELETE "$rest/connectors/$name" >/dev/null 2>&1 || true
  register || true
  ready=0
  attempt=0
  while [ "$attempt" -lt 5 ]; do
    if running; then ready=1; break; fi
    sleep 1
    attempt=$((attempt + 1))
  done
  test "$ready" -eq 1
  printf 'reconciled %s\n' "$name"
done

printf '%s\n' 'all PostgreSQL Debezium connectors are RUNNING'

# Keep the one-shot reconciliation container alive so Compose does not restart
# it in a tight loop after a successful boot.
exec tail -f /dev/null
