#!/usr/bin/env bash
set -euo pipefail

compose=(docker compose -f docker-compose.nats.yaml -f docker-compose.gig-service.yaml -f docker-compose.payment-service.yaml -f docker-compose.file-service.yaml)

"${compose[@]}" up -d --remove-orphans

until [[ -n "$("${compose[@]}" ps -q gig-service-yugabyte-init | tr -d '\n')" ]]; do
  sleep 1
done

until [[ -n "$("${compose[@]}" ps -q payment-service-yugabyte-init | tr -d '\n')" ]]; do
  sleep 1
done

until [[ -n "$("${compose[@]}" ps -q file-service-scylla-init | tr -d '\n')" ]]; do
  sleep 1
done

gig_container_id="$("${compose[@]}" ps -q gig-service-yugabyte-init | tr -d '\n')"
payment_container_id="$("${compose[@]}" ps -q payment-service-yugabyte-init | tr -d '\n')"
file_container_id="$("${compose[@]}" ps -q file-service-scylla-init | tr -d '\n')"

while true; do
  gig_status="$(docker inspect -f '{{.State.Status}}' "${gig_container_id}" 2>/dev/null || true)"
  payment_status="$(docker inspect -f '{{.State.Status}}' "${payment_container_id}" 2>/dev/null || true)"
  file_status="$(docker inspect -f '{{.State.Status}}' "${file_container_id}" 2>/dev/null || true)"
  if [[ "${gig_status}" == "exited" && "${payment_status}" == "exited" && "${file_status}" == "exited" ]]; then
    break
  fi
  sleep 1
done

infra::wait_exec "$(infra::container_name gig-service-yugabyte)" 300 ysqlsh -h 127.0.0.1 -U yugabyte -d yugabyte -c "SELECT 1" &
infra::wait_exec "$(infra::container_name payment-service-yugabyte)" 300 ysqlsh -h 127.0.0.1 -U yugabyte -d yugabyte -c "SELECT 1" &
infra::wait_exec "$(infra::container_name file-service-scylla)" 300 cqlsh -u admin -p admin -e "DESCRIBE KEYSPACES;" &
wait

"${compose[@]}" rm -fsv gig-service-yugabyte-init payment-service-yugabyte-init file-service-scylla-init
