#!/usr/bin/env sh
set -eu

grafana_url="${GRAFANA_URL:-http://ofm-grafana:3000}"
grafana_user="${GRAFANA_ADMIN_USER:-admin}"
grafana_pass="${GRAFANA_ADMIN_PASSWORD:-admin}"

wait_for_grafana() {
  until curl -fsS -u "${grafana_user}:${grafana_pass}" "${grafana_url}/api/health" >/dev/null 2>&1; do
    sleep 2
  done
}

datasource_exists() {
  name="$1"
  curl -fsS -u "${grafana_user}:${grafana_pass}" "${grafana_url}/api/datasources/name/${name}" >/dev/null 2>&1
}

upsert_datasource() {
  name="$1"
  uid="$2"
  payload="$3"

  if datasource_exists "$name"; then
    curl -fsS \
      -u "${grafana_user}:${grafana_pass}" \
      -X DELETE \
      "${grafana_url}/api/datasources/uid/${uid}"
  fi

  printf '%s' "${payload}" | curl -fsS \
    -u "${grafana_user}:${grafana_pass}" \
    -H 'Content-Type: application/json' \
    -X POST \
    -d @- \
    "${grafana_url}/api/datasources"
}

wait_for_grafana

if ! datasource_exists Prometheus; then
  upsert_datasource Prometheus prometheus '{"name":"Prometheus","type":"prometheus","uid":"prometheus","access":"proxy","orgId":1,"url":"http://prometheus:9090","isDefault":true}'
fi

upsert_datasource ClickHouse clickhouse '{"name":"ClickHouse","type":"grafana-clickhouse-datasource","uid":"clickhouse","access":"proxy","orgId":1,"url":"clickhouse:9000","version":1,"user":"admin","secureJsonData":{"password":"admin"},"jsonData":{"host":"clickhouse","server":"clickhouse","username":"admin","port":9000,"protocol":"native","secure":false,"defaultDatabase":"default"}}'

if ! datasource_exists Tempo; then
  upsert_datasource Tempo tempo '{"name":"Tempo","type":"tempo","uid":"tempo","access":"proxy","orgId":1,"url":"http://tempo:3200"}'
fi
