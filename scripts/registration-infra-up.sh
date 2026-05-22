#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${script_dir}/infra-builder.sh"

compose_cmd="$(infra::compose docker-compose.nats.yaml docker-compose.user-service.yaml docker-compose.auth-service.yaml docker-compose.registration-saga-service.yaml)"

set -- ${compose_cmd}
"$@" up -d --remove-orphans

infra::wait_all_exited \
  "$(infra::container_name auth-service-yugabyte-init)" \
  "$(infra::container_name user-service-yugabyte-init)" \
  "$(infra::container_name registration-saga-service-scylla-init)"

infra::wait_exec "$(infra::container_name auth-service-yugabyte)" 300 ysqlsh -h 127.0.0.1 -U yugabyte -d yugabyte -c "SELECT 1" &
infra::wait_exec "$(infra::container_name user-service-yugabyte)" 300 ysqlsh -h 127.0.0.1 -U yugabyte -d yugabyte -c "SELECT 1" &
infra::wait_exec "$(infra::container_name registration-saga-service-scylla)" 300 cqlsh -u admin -p admin -e "DESCRIBE KEYSPACES;" &
wait

infra::rm_containers \
  "$(infra::container_name auth-service-yugabyte-init)" \
  "$(infra::container_name user-service-yugabyte-init)" \
  "$(infra::container_name registration-saga-service-scylla-init)"
