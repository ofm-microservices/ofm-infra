#!/usr/bin/env bash
set -euo pipefail

namespace="${OFM_K3D_NAMESPACE:-ofm}"
release="${OFM_K3D_RELEASE:-ofm}"
cluster="${OFM_K3D_CLUSTER:-ofm}"
kubeconfig="${OFM_K3D_KUBECONFIG:-$HOME/.kube/k3d-ofm.yaml}"

kubectl_cmd=(kubectl --kubeconfig "$kubeconfig")
helm_cmd=(helm --kubeconfig "$kubeconfig")

if [[ ! -r "$kubeconfig" ]]; then
    kubectl_cmd=(sudo kubectl --kubeconfig "$kubeconfig")
    helm_cmd=(sudo helm --kubeconfig "$kubeconfig")
fi

"${helm_cmd[@]}" uninstall "$release" --namespace "$namespace" || true
"${kubectl_cmd[@]}" delete namespace "$namespace" || true
k3d cluster delete "$cluster" || true
