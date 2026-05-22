#!/usr/bin/env bash
set -euo pipefail

compose=(docker compose -f docker-compose.nats.yaml -f docker-compose.payment-service.yaml)

"${compose[@]}" up -d --remove-orphans

until [[ -n "$("${compose[@]}" ps -q payment-service-yugabyte-init | tr -d '\n')" ]]; do
  sleep 1
done

container_id="$("${compose[@]}" ps -q payment-service-yugabyte-init | tr -d '\n')"

while true; do
  status="$(docker inspect -f '{{.State.Status}}' "${container_id}" 2>/dev/null || true)"
  if [[ "${status}" == "exited" ]]; then
    break
  fi
  sleep 1
done

infra::wait_exec "$(infra::container_name payment-service-yugabyte)" 300 ysqlsh -h 127.0.0.1 -U yugabyte -d yugabyte -c "SELECT 1" &
wait

"${compose[@]}" rm -fsv payment-service-yugabyte-init
