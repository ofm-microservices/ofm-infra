#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export OFM_K3S_IMAGE_TAG="${OFM_K3S_IMAGE_TAG:-$(bash "$repo_root/ofm-infra/scripts/k3d-image-tag.sh")}"
bash "$repo_root/ofm-infra/scripts/k3s-build-images.sh" "$@"
