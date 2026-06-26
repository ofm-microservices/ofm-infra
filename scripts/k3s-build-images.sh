#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
image_tag="${OFM_K3S_IMAGE_TAG:-k3s}"
cache_dir="$repo_root/.cache/k3s"
import_images="${OFM_K3S_IMPORT:-0}"
target_service="${1:-all}"

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

if [[ "$target_service" == "all" || "$target_service" == "api-gateway" ]]; then build_image "api-gateway" "ofm-api-gateway/Dockerfile" "ofm/api-gateway:${image_tag}"; fi
if [[ "$target_service" == "all" || "$target_service" == "auth-service" ]]; then build_image "auth-service" "ofm-auth-service/Dockerfile" "ofm/auth-service:${image_tag}"; fi
if [[ "$target_service" == "all" || "$target_service" == "user-service" ]]; then build_image "user-service" "ofm-user-service/Dockerfile" "ofm/user-service:${image_tag}"; fi
if [[ "$target_service" == "all" || "$target_service" == "registration-saga-service" ]]; then build_image "registration-saga-service" "ofm-registration-saga-service/Dockerfile" "ofm/registration-saga-service:${image_tag}"; fi
if [[ "$target_service" == "all" || "$target_service" == "gig-service" ]]; then build_image "gig-service" "ofm-gig-service/Dockerfile" "ofm/gig-service:${image_tag}"; fi
if [[ "$target_service" == "all" || "$target_service" == "file-service" ]]; then build_image "file-service" "ofm-file-service/Dockerfile" "ofm/file-service:${image_tag}"; fi
if [[ "$target_service" == "all" || "$target_service" == "chat-service" ]]; then build_image "chat-service" "ofm-chat-service/Dockerfile" "ofm/chat-service:${image_tag}"; fi
if [[ "$target_service" == "all" || "$target_service" == "payment-service" ]]; then build_image "payment-service" "ofm-payment-service/Dockerfile" "ofm/payment-service:${image_tag}"; fi
if [[ "$target_service" == "all" || "$target_service" == "order-service" ]]; then build_image "order-service" "ofm-order-service/Dockerfile" "ofm/order-service:${image_tag}"; fi
if [[ "$target_service" == "all" || "$target_service" == "order-saga-service" ]]; then build_image "order-saga-service" "ofm-order-saga-service/Dockerfile" "ofm/order-saga-service:${image_tag}"; fi
if [[ "$target_service" == "all" || "$target_service" == "review-service" ]]; then build_image "review-service" "ofm-review-service/Dockerfile" "ofm/review-service:${image_tag}"; fi
if [[ "$target_service" == "all" || "$target_service" == "search-service" ]]; then build_image "search-service" "ofm-search-service/Dockerfile" "ofm/search-service:${image_tag}"; fi
if [[ "$target_service" == "all" || "$target_service" == "realtime-service" ]]; then build_image "realtime-service" "ofm-realtime-service/Dockerfile" "ofm/realtime-service:${image_tag}"; fi
if [[ "$target_service" == "all" || "$target_service" == "mail-service" ]]; then build_image "mail-service" "ofm-mail-service/Dockerfile" "ofm/mail-service:${image_tag}"; fi
