#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${script_dir}/infra-builder.sh"

compose_cmd="$(infra::compose docker-compose.nats.yaml docker-compose.auth-service.yaml docker-compose.gig-service.yaml docker-compose.order-saga-service.yaml docker-compose.order-service.yaml docker-compose.payment-service.yaml docker-compose.file-service.yaml)"

set -- ${compose_cmd}
"$@" up -d --remove-orphans

infra::wait_all_exited \
  "$(infra::container_name auth-service-yugabyte-init)" \
  "$(infra::container_name gig-service-yugabyte-init)" \
  "$(infra::container_name order-saga-service-scylla-init)" \
  "$(infra::container_name order-service-yugabyte-init)" \
  "$(infra::container_name payment-service-yugabyte-init)" \
  "$(infra::container_name file-service-scylla-init)"

infra::wait_exec "$(infra::container_name auth-service-yugabyte)" 300 ysqlsh -h 127.0.0.1 -U yugabyte -d yugabyte -c "SELECT 1" &
infra::wait_exec "$(infra::container_name gig-service-yugabyte)" 300 ysqlsh -h 127.0.0.1 -U yugabyte -d yugabyte -c "SELECT 1" &
infra::wait_exec "$(infra::container_name order-service-yugabyte)" 300 ysqlsh -h 127.0.0.1 -U yugabyte -d yugabyte -c "SELECT 1" &
infra::wait_exec "$(infra::container_name payment-service-yugabyte)" 300 ysqlsh -h 127.0.0.1 -U yugabyte -d yugabyte -c "SELECT 1" &
infra::wait_exec "$(infra::container_name order-saga-service-scylla)" 300 cqlsh -u admin -p admin -e "DESCRIBE KEYSPACES;" &
infra::wait_exec "$(infra::container_name file-service-scylla)" 300 cqlsh -u admin -p admin -e "DESCRIBE KEYSPACES;" &
wait

infra::rm_containers \
  "$(infra::container_name auth-service-yugabyte-init)" \
  "$(infra::container_name gig-service-yugabyte-init)" \
  "$(infra::container_name order-saga-service-scylla-init)" \
  "$(infra::container_name order-service-yugabyte-init)" \
  "$(infra::container_name payment-service-yugabyte-init)" \
  "$(infra::container_name file-service-scylla-init)"
