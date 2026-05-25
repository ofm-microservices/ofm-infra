#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
image_tag="${OFM_K3S_IMAGE_TAG:-k3s}"
cache_dir="$repo_root/.cache/k3s"
import_images="${OFM_K3S_IMPORT:-0}"

mkdir -p "$cache_dir/images"

build_image() {
    local service="$1"
    local dockerfile="$2"
    local image="$3"

    echo "== build $service =="
    docker build -t "$image" -f "$repo_root/$dockerfile" "$repo_root"

    if [[ "$import_images" == "1" ]]; then
        echo "== import $image into k3s =="
        docker save "$image" -o "$cache_dir/images/${service}.tar"
        if [[ -S /run/k3s/containerd/containerd.sock ]]; then
            if ! k3s ctr images import "$cache_dir/images/${service}.tar"; then
                sudo k3s ctr images import "$cache_dir/images/${service}.tar"
            fi
        else
            echo "skipping k3s import for $service; k3s containerd socket is not available"
        fi
    fi
}

build_image "api-gateway" "ofm-api-gateway/Dockerfile" "ofm/api-gateway:${image_tag}"
build_image "auth-service" "ofm-auth-service/Dockerfile" "ofm/auth-service:${image_tag}"
build_image "user-service" "ofm-user-service/Dockerfile" "ofm/user-service:${image_tag}"
build_image "registration-saga-service" "ofm-registration-saga-service/Dockerfile" "ofm/registration-saga-service:${image_tag}"
build_image "gig-service" "ofm-gig-service/Dockerfile" "ofm/gig-service:${image_tag}"
build_image "file-service" "ofm-file-service/Dockerfile" "ofm/file-service:${image_tag}"
build_image "payment-service" "ofm-payment-service/Dockerfile" "ofm/payment-service:${image_tag}"
build_image "order-service" "ofm-order-service/Dockerfile" "ofm/order-service:${image_tag}"
build_image "order-saga-service" "ofm-order-saga-service/Dockerfile" "ofm/order-saga-service:${image_tag}"
build_image "realtime-service" "ofm-realtime-service/Dockerfile" "ofm/realtime-service:${image_tag}"
build_image "mail-service" "ofm-mail-service/Dockerfile" "ofm/mail-service:${image_tag}"
build_image "review-service" "ofm-review-service/Dockerfile" "ofm/review-service:${image_tag}"
