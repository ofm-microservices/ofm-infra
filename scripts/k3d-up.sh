#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
chart_dir="$repo_root/ofm-infra/helm/ofm"
namespace="${OFM_K3D_NAMESPACE:-ofm}"
release="${OFM_K3D_RELEASE:-ofm}"
cluster="${OFM_K3D_CLUSTER:-ofm}"
kubeconfig="${OFM_K3D_KUBECONFIG:-$HOME/.kube/k3d-ofm.yaml}"
# k3d nodes have their own image store. Import local hash-tagged images by
# default so a host reboot cannot leave a rollout trying to pull from Docker
# Hub. Set OFM_K3D_IMPORT=0 only when the images are already present in k3d.
import_images="${OFM_K3D_IMPORT:-1}"
run_linkerd_proxy_check="${OFM_K3D_LINKERD_PROXY_CHECK:-0}"
services_to_manage=(
    monolith
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

source "$repo_root/ofm-infra/scripts/file-service-port-forward.sh"

kubectl_cmd=(kubectl --kubeconfig "$kubeconfig")
helm_cmd=(helm --kubeconfig "$kubeconfig")

resolve_host_ip() {
    local resolved="${OFM_K3D_EXTERNAL_HOST:-}"
    if [[ -n "$resolved" ]]; then
        printf '%s\n' "$resolved"
        return 0
    fi

    resolved="$(docker network inspect "k3d-$cluster" --format '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null || true)"
    if [[ -n "$resolved" ]]; then
        printf '%s\n' "$resolved"
        return 0
    fi

    resolved="$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i == "src") {print $(i+1); exit}}' || true)"
    if [[ -n "$resolved" ]]; then
        printf '%s\n' "$resolved"
        return 0
    fi

    printf '%s\n' "172.19.0.1"
}

host_ip="$(resolve_host_ip)"
image_tag="${OFM_K3S_IMAGE_TAG:-$(bash "$repo_root/ofm-infra/scripts/k3d-image-tag.sh")}"

# PostgreSQL's migrate driver uses a persistent row as its lock. If a previous
# local run was killed during migration, that row survives and blocks the next
# one even though no migration process is running. Clear only this service's
# migration-lock table; schema and application data remain untouched.
clear_auth_migration_lock() {
    local container="${OFM_AUTH_DB_CONTAINER:-ofm-auth-service-postgres}"
    if ! docker inspect "$container" >/dev/null 2>&1; then
        return 0
    fi
    for _ in {1..20}; do
        if docker exec "$container" psql -h 127.0.0.1 -p 5432 \
            -U admin -d auth_service \
            -c 'DELETE FROM migrations_locks;' >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done
    echo "warning: could not clear auth-service migration lock" >&2
}

if ! command -v k3d >/dev/null 2>&1; then
    echo "k3d is not installed" >&2
    exit 1
fi

if ! k3d cluster list | awk 'NR>1 {print $1}' | grep -qx "$cluster"; then
    k3d cluster create "$cluster" \
        --agents 1 \
        --servers 1 \
        --port "80:80@loadbalancer" \
        --host-alias "${host_ip}:host.k3d.internal"
else
    # `k3d cluster stop` leaves the cluster definition behind; start its
    # containers before trying to access the API server or run Helm.
    k3d cluster start "$cluster"
    # Older local clusters may predate the ingress port mapping. Add it
    # idempotently so the experiment UI remains reachable after reboot.
    if ! docker port "k3d-$cluster-serverlb" 80/tcp 2>/dev/null | grep -q '0.0.0.0:80'; then
        k3d node edit "k3d-$cluster-serverlb" --port-add "80:80"
    fi
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

# The API server may be ready before k3d nodes reconnect after a host reboot.
# Wait for every node before deploying Linkerd-injected application pods.
for _ in {1..90}; do
    if "${kubectl_cmd[@]}" wait --for=condition=Ready nodes --all --timeout=2s >/dev/null 2>&1; then
        break
    fi
    sleep 2
done

if ! "${kubectl_cmd[@]}" wait --for=condition=Ready nodes --all --timeout=2s >/dev/null 2>&1; then
    echo "kubernetes nodes are not ready" >&2
    "${kubectl_cmd[@]}" get nodes -o wide >&2 || true
    exit 1
fi

# HPA and experiment verification require the k3s metrics API to be live.
for _ in {1..60}; do
    if "${kubectl_cmd[@]}" get --raw=/apis/metrics.k8s.io/v1beta1 >/dev/null 2>&1; then
        break
    fi
    sleep 2
done

if ! "${kubectl_cmd[@]}" get --raw=/apis/metrics.k8s.io/v1beta1 >/dev/null 2>&1; then
    echo "metrics API is not ready" >&2
    exit 1
fi

# Do not enumerate the persistent broker's topic catalog here.  This stack has
# many retained topics, and an admin list RPC can be slow or temporarily block
# during broker recovery even while the broker is healthy.  The compose health
# check already verifies the listener and controller state; topic creation and
# connector reconciliation happen independently after deployment.
kafka_ready=0
for _ in {1..90}; do
    if [[ "$(docker inspect -f '{{.State.Health.Status}}' ofm-migration-kafka 2>/dev/null || true)" == "healthy" ]]; then
        kafka_ready=1
        break
    fi
    sleep 2
done
if [[ "$kafka_ready" != "1" ]]; then
    echo "Kafka broker is not healthy before Kubernetes deployment" >&2
    docker inspect -f '{{json .State.Health}}' ofm-migration-kafka >&2 || true
    exit 1
fi

clear_auth_migration_lock

if command -v linkerd >/dev/null 2>&1; then
    if ! "${kubectl_cmd[@]}" -n linkerd get configmap linkerd-config >/dev/null 2>&1; then
        "${kubectl_cmd[@]}" apply --server-side --force-conflicts -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
        linkerd install --crds | "${kubectl_cmd[@]}" apply -f -
        linkerd install | "${kubectl_cmd[@]}" apply -f -
        "${kubectl_cmd[@]}" -n linkerd rollout status deploy/linkerd-identity --timeout=600s
        "${kubectl_cmd[@]}" -n linkerd rollout status deploy/linkerd-destination --timeout=600s
        "${kubectl_cmd[@]}" -n linkerd rollout status deploy/linkerd-proxy-injector --timeout=600s
    fi
fi

# Keep Linkerd discovery/policy highly available during local load tests. A
# single control-plane pod can be evicted or fail probes under k3d pressure,
# which turns healthy application calls into cascading gRPC Unavailable errors.
if "${kubectl_cmd[@]}" -n linkerd get deployment linkerd-destination >/dev/null 2>&1; then
    "${kubectl_cmd[@]}" -n linkerd scale deployment/linkerd-destination --replicas=2 >/dev/null
fi

"${kubectl_cmd[@]}" get namespace "$namespace" >/dev/null 2>&1 || "${kubectl_cmd[@]}" create namespace "$namespace"
"${kubectl_cmd[@]}" label namespace "$namespace" linkerd.io/inject=enabled --overwrite
"${kubectl_cmd[@]}" label namespace "$namespace" app.kubernetes.io/managed-by=Helm --overwrite
"${kubectl_cmd[@]}" annotate namespace "$namespace" meta.helm.sh/release-name="$release" meta.helm.sh/release-namespace="$namespace" --overwrite

if [[ "$import_images" == "1" ]]; then
    bash "$repo_root/ofm-infra/scripts/k3d-import-images.sh"
fi

"${helm_cmd[@]}" upgrade --install "$release" "$chart_dir" \
    --namespace "$namespace" \
    -f "$chart_dir/common-values.yaml" \
    -f "$chart_dir/local-values.yaml" \
    -f "$chart_dir/local-secrets.yaml" \
    --set global.externalHost="$host_ip" \
    --set global.kafkaHost="172.22.0.10" \
    --set global.imagePullPolicy=IfNotPresent \
    --set-string migrationFailureRelay.image="ofm/migration-bridge:${image_tag}" \
    --set-string services.monolith.image="ofm/monolith:${image_tag}" \
    --set-string services.api-gateway.image="ofm/api-gateway:${image_tag}" \
    --set-string services.auth-service.image="ofm/auth-service:${image_tag}" \
    --set-string services.user-service.image="ofm/user-service:${image_tag}" \
    --set-string services.registration-saga-service.image="ofm/registration-saga-service:${image_tag}" \
    --set-string services.gig-service.image="ofm/gig-service:${image_tag}" \
    --set-string services.file-service.image="ofm/file-service:${image_tag}" \
    --set-string services.chat-service.image="ofm/chat-service:${image_tag}" \
    --set-string services.payment-service.image="ofm/payment-service:${image_tag}" \
    --set-string services.order-service.image="ofm/order-service:${image_tag}" \
    --set-string services.order-saga-service.image="ofm/order-saga-service:${image_tag}" \
    --set-string services.review-service.image="ofm/review-service:${image_tag}" \
    --set-string services.search-service.image="ofm/search-service:${image_tag}" \
    --set-string services.realtime-service.image="ofm/realtime-service:${image_tag}" \
    --set-string services.mail-service.image="ofm/mail-service:${image_tag}" \
    --set-string loadTestService.image="ofm/load-test-service:${image_tag}" \
    --set-string loadTestService.k6Image="ofm/k6-full-system:${image_tag}" \
    --server-side=true \
    --force-conflicts

# The experiment runner is intentionally kept outside the application Helm
# release, but it must still be reconciled to the same content-derived image
# tag. Applying the manifest alone leaves old server-side fields (including
# removed NATS variables), so remove those explicitly after the apply.
"${kubectl_cmd[@]}" apply -f "$repo_root/ofm-infra/load-test-service/k8s.yaml"
"${kubectl_cmd[@]}" -n "$namespace" set image deployment/load-test-service \
    load-test-service="ofm/load-test-service:${image_tag}"
"${kubectl_cmd[@]}" -n "$namespace" set env deployment/load-test-service \
    NATS_URL- K6_IMAGE="ofm/k6-full-system:${image_tag}"

# Helm apply does not reliably remove legacy server-side environment entries.
# Realtime delivery is Kafka-only; remove the obsolete NATS variable explicitly
# so the running pod cannot be mistaken for a NATS-backed deployment.
"${kubectl_cmd[@]}" -n "$namespace" set env deployment/realtime-service NATS_URL-

# The relay is a CronJob, so it is not covered by the Deployment rollout loop.
# Keep its image aligned with the imported local image as well; otherwise an
# old CronJob template can recreate an ImagePullBackOff every minute after a
# host or k3d restart.
if "${kubectl_cmd[@]}" -n "$namespace" get cronjob migration-failure-relay >/dev/null 2>&1; then
    "${kubectl_cmd[@]}" -n "$namespace" set image \
        cronjob/migration-failure-relay \
        migration-failure-relay="ofm/migration-bridge:${image_tag}"
fi

for svc in "${services_to_manage[@]}"; do
    "${kubectl_cmd[@]}" -n "$namespace" rollout status "deploy/$svc" --timeout=600s
done

ofm_file_service_port_forward_start

if [[ "$run_linkerd_proxy_check" == "1" ]] && command -v linkerd >/dev/null 2>&1; then
    linkerd --kubeconfig "$kubeconfig" check --proxy --namespace "$namespace"
fi

echo "k3d release '$release' deployed in namespace '$namespace' using cluster '$cluster'"
