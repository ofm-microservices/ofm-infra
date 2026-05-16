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

"${compose[@]}" rm -fsv payment-service-yugabyte-init
