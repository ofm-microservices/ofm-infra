#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
chart_dir="$repo_root/ofm-infra/helm/ofm"
namespace="${OFM_K3D_NAMESPACE:-ofm}"
release="${OFM_K3D_RELEASE:-ofm}"
cluster="${OFM_K3D_CLUSTER:-ofm}"
kubeconfig="${OFM_K3D_KUBECONFIG:-$HOME/.kube/k3d-ofm.yaml}"
import_images="${OFM_K3D_IMPORT:-1}"
services_to_manage=(user-service review-service)

kubectl_cmd=(kubectl --kubeconfig "$kubeconfig")
helm_cmd=(helm --kubeconfig "$kubeconfig")

host_ip="${OFM_K3D_EXTERNAL_HOST:-}"
if [[ -z "$host_ip" ]]; then
    host_ip="$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i == "src") {print $(i+1); exit}}' || true)"
fi
if [[ -z "$host_ip" ]]; then
    echo "failed to resolve host ip for k3d host alias" >&2
    exit 1
fi

if ! command -v k3d >/dev/null 2>&1; then
    echo "k3d is not installed" >&2
    exit 1
fi

if ! k3d cluster list | awk 'NR>1 {print $1}' | grep -qx "$cluster"; then
    k3d cluster create "$cluster" \
        --agents 1 \
        --servers 1 \
        --host-alias "${host_ip}:host.k3d.internal"
fi

mkdir -p "$(dirname "$kubeconfig")"
k3d kubeconfig get "$cluster" > "$kubeconfig"

if [[ ! -r "$kubeconfig" ]]; then
    kubectl_cmd=(sudo kubectl --kubeconfig "$kubeconfig")
    helm_cmd=(sudo helm --kubeconfig "$kubeconfig")
fi

for _ in {1..60}; do
    if "${kubectl_cmd[@]}" get --raw=/readyz >/dev/null 2>&1; then
        break
    fi
    sleep 2
done

if ! "${kubectl_cmd[@]}" get --raw=/readyz >/dev/null 2>&1; then
    echo "kubernetes apiserver is not ready" >&2
    exit 1
fi

"${kubectl_cmd[@]}" get namespace "$namespace" >/dev/null 2>&1 || "${kubectl_cmd[@]}" create namespace "$namespace"
"${kubectl_cmd[@]}" label namespace "$namespace" linkerd.io/inject=enabled --overwrite
"${kubectl_cmd[@]}" label namespace "$namespace" app.kubernetes.io/managed-by=Helm --overwrite
"${kubectl_cmd[@]}" annotate namespace "$namespace" \
    meta.helm.sh/release-name="$release" \
    meta.helm.sh/release-namespace="$namespace" \
    --overwrite

if [[ "$import_images" == "1" ]]; then
    bash "$repo_root/ofm-infra/scripts/k3s-import-images.sh"
fi

for svc in "${services_to_manage[@]}"; do
    "${kubectl_cmd[@]}" -n "$namespace" delete deploy "$svc" --ignore-not-found --wait=false
done

"${helm_cmd[@]}" upgrade --install "$release" "$chart_dir" \
    --namespace "$namespace" \
    -f "$chart_dir/common-values.yaml" \
    -f "$chart_dir/local-values.yaml" \
    -f "$chart_dir/local-secrets.yaml" \
    --set global.imagePullPolicy=IfNotPresent

for svc in "${services_to_manage[@]}"; do
    "${kubectl_cmd[@]}" -n "$namespace" rollout status "deploy/$svc" --timeout=600s
done

if command -v linkerd >/dev/null 2>&1; then
    if linkerd --kubeconfig "$kubeconfig" check >/dev/null 2>&1; then
        linkerd --kubeconfig "$kubeconfig" check --proxy --namespace "$namespace"
    else
        echo "linkerd is not installed in k3d cluster; skipping proxy check" >&2
    fi
fi

echo "k3d release '$release' deployed in namespace '$namespace' using cluster '$cluster'"
