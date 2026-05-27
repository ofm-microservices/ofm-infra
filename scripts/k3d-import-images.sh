#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
image_tag="${OFM_K3S_IMAGE_TAG:-k3s}"
cluster="${OFM_K3D_CLUSTER:-${OFM_K3S_CLUSTER:-ofm}}"

if ! command -v k3d >/dev/null 2>&1; then
    echo "k3d is not installed" >&2
    exit 1
fi

if ! k3d cluster list | awk 'NR>1 {print $1}' | grep -qx "$cluster"; then
    host_ip="${OFM_K3D_EXTERNAL_HOST:-}"
    if [[ -z "$host_ip" ]]; then
        host_ip="$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i == "src") {print $(i+1); exit}}' || true)"
    fi
    if [[ -z "$host_ip" ]]; then
        host_ip="172.21.0.1"
    fi

    k3d cluster create "$cluster" \
        --agents 1 \
        --servers 1 \
        --host-alias "${host_ip}:host.k3d.internal"
fi

import_image() {
    local service="$1"
    local image="$2"

    if ! docker image inspect "$image" >/dev/null 2>&1; then
        echo "missing local docker image: $image" >&2
        exit 1
    fi

    echo "== import $image into k3d cluster $cluster =="
    k3d image import -c "$cluster" "$image"
}

import_image "api-gateway" "ofm/api-gateway:${image_tag}"
import_image "auth-service" "ofm/auth-service:${image_tag}"
import_image "user-service" "ofm/user-service:${image_tag}"
import_image "registration-saga-service" "ofm/registration-saga-service:${image_tag}"
import_image "gig-service" "ofm/gig-service:${image_tag}"
import_image "file-service" "ofm/file-service:${image_tag}"
import_image "payment-service" "ofm/payment-service:${image_tag}"
import_image "order-service" "ofm/order-service:${image_tag}"
import_image "order-saga-service" "ofm/order-saga-service:${image_tag}"
import_image "review-service" "ofm/review-service:${image_tag}"
import_image "search-service" "ofm/search-service:${image_tag}"
import_image "realtime-service" "ofm/realtime-service:${image_tag}"
import_image "mail-service" "ofm/mail-service:${image_tag}"
