#!/usr/bin/env bash
set -euo pipefail

namespace="${OFM_K3D_NAMESPACE:-ofm}"
kubeconfig="${OFM_K3D_KUBECONFIG:-$HOME/.kube/k3d-ofm.yaml}"

kubectl_cmd=(kubectl --kubeconfig "$kubeconfig")

if [[ ! -r "$kubeconfig" ]]; then
    kubectl_cmd=(sudo kubectl --kubeconfig "$kubeconfig")
fi

deployments=(
    api-gateway
    auth-service
    user-service
    registration-saga-service
    gig-service
    file-service
    payment-service
    order-service
    order-saga-service
    review-service
    search-service
    realtime-service
    mail-service
    prometheus
    tempo
    otel-collector
    clickhouse
    grafana
)

for deployment in "${deployments[@]}"; do
    if "${kubectl_cmd[@]}" -n "$namespace" get deploy "$deployment" >/dev/null 2>&1; then
        "${kubectl_cmd[@]}" -n "$namespace" scale deploy "$deployment" --replicas=0
    fi
done

echo "k3d release scaled down in namespace '$namespace' without deleting the cluster"
