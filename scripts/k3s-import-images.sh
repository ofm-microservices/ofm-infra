#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
image_tag="${OFM_K3S_IMAGE_TAG:-k3s}"
cluster="${OFM_K3D_CLUSTER:-${OFM_K3S_CLUSTER:-ofm}}"

import_image() {
    local service="$1"
    local image="$2"

    if ! docker image inspect "$image" >/dev/null 2>&1; then
        echo "missing local docker image: $image" >&2
        exit 1
    fi

    echo "== import $image into k3d cluster $cluster =="
    if [[ $EUID -ne 0 ]]; then
        sudo k3d image import -c "$cluster" "$image"
    else
        k3d image import -c "$cluster" "$image"
    fi
}

# import_image "api-gateway" "ofm/api-gateway:${image_tag}"
# import_image "auth-service" "ofm/auth-service:${image_tag}"
import_image "user-service" "ofm/user-service:${image_tag}"
# import_image "registration-saga-service" "ofm/registration-saga-service:${image_tag}"
# import_image "gig-service" "ofm/gig-service:${image_tag}"
# import_image "file-service" "ofm/file-service:${image_tag}"
# import_image "payment-service" "ofm/payment-service:${image_tag}"
# import_image "order-service" "ofm/order-service:${image_tag}"
# import_image "order-saga-service" "ofm/order-saga-service:${image_tag}"
# import_image "realtime-service" "ofm/realtime-service:${image_tag}"
# import_image "mail-service" "ofm/mail-service:${image_tag}"
import_image "review-service" "ofm/review-service:${image_tag}"
