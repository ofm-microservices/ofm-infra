#!/usr/bin/env bash
set -euo pipefail

# Produce one content-derived tag for the local release. Any service source,
# shared package, Dockerfile, or local Helm configuration change creates a new
# tag and therefore cannot reuse an old image accidentally.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
{
    find "$repo_root/ofm-common" \
        "$repo_root" -maxdepth 2 -name Dockerfile \
        -type f -print
    for service in api-gateway auth-service chat-service file-service gig-service \
        mail-service monolith order-saga-service order-service payment-service \
        realtime-service registration-saga-service review-service search-service \
        user-service migration-bridge; do
        find "$repo_root/ofm-$service" -type f \
            ! -path '*/.git/*' ! -path '*/vendor/*' -print
    done
    find "$repo_root/ofm-experiment-service" -type f \
        ! -path '*/.git/*' ! -path '*/vendor/*' -print
} | sort -u | xargs sha256sum | sha256sum | cut -c1-12
