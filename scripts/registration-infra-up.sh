#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
docker compose -f docker-compose.postgres.yaml up -d --wait auth-service-postgres user-service-postgres registration-saga-service-postgres
