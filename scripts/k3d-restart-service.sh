#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <service-name>" >&2
  exit 1
fi

service="$1"

just k3d-build-images "$service"
k3d image import -c ofm "ofm/${service}:k3s"
kubectl --kubeconfig "$HOME/.kube/k3d-ofm.yaml" -n ofm rollout restart "deploy/${service}"
