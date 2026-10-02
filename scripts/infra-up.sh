#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${script_dir}/infra-builder.sh"

compose_cmd="$(infra::compose docker-compose.postgres.yaml docker-compose.search-service.yaml docker-compose.migration.yaml docker-compose.monolith.yaml)"

set -- ${compose_cmd}

echo "PostgreSQL containers use healthchecks; application containers run their own migrations."
