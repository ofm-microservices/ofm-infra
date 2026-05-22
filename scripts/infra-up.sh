#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${script_dir}/infra-builder.sh"

compose_cmd="$(infra::compose docker-compose.nats.yaml docker-compose.user-service.yaml docker-compose.auth-service.yaml docker-compose.gig-service.yaml docker-compose.registration-saga-service.yaml docker-compose.order-saga-service.yaml docker-compose.order-service.yaml docker-compose.payment-service.yaml docker-compose.file-service.yaml)"

set -- ${compose_cmd}

infra::wait_all_exited \
  "$(infra::container_name user-service-yugabyte-init)" \
  "$(infra::container_name auth-service-yugabyte-init)" \
  "$(infra::container_name gig-service-yugabyte-init)" \
  "$(infra::container_name registration-saga-service-scylla-init)" \
  "$(infra::container_name order-saga-service-scylla-init)" \
  "$(infra::container_name order-service-yugabyte-init)" \
  "$(infra::container_name payment-service-yugabyte-init)" \
  "$(infra::container_name file-service-scylla-init)"

infra::rm_containers \
  "$(infra::container_name user-service-yugabyte-init)" \
  "$(infra::container_name auth-service-yugabyte-init)" \
  "$(infra::container_name gig-service-yugabyte-init)" \
  "$(infra::container_name registration-saga-service-scylla-init)" \
  "$(infra::container_name order-saga-service-scylla-init)" \
  "$(infra::container_name order-service-yugabyte-init)" \
  "$(infra::container_name payment-service-yugabyte-init)" \
  "$(infra::container_name file-service-scylla-init)"
