#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${1:-8097}"

cd "$ROOT_DIR/ofm-infra"

env \
  GOCACHE=/tmp/go-build-cache \
  /home/alex/go/bin/pkgsite \
  -http "127.0.0.1:${PORT}" \
  ../ofm-common \
  ../ofm-api-gateway \
  ../ofm-auth-service \
  ../ofm-user-service \
  ../ofm-mail-service \
  ../ofm-registration-saga-service \
  ../ofm-monolith/backend \
  ../ofm-monolith/file-server
