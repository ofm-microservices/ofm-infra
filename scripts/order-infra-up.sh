#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
docker compose -f docker-compose.postgres.yaml up -d --wait auth-service-postgres gig-service-postgres order-saga-service-postgres order-service-postgres payment-service-postgres file-service-postgres
