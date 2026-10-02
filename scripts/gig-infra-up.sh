#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
docker compose -f docker-compose.postgres.yaml up -d --wait gig-service-postgres gig-service-redis payment-service-postgres payment-service-redis file-service-postgres
