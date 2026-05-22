#!/usr/bin/env bash

OFM_API_GATEWAY_CURL_ARGS=()
OFM_API_GATEWAY_PORT_FORWARD_PID=""

ofm_api_gateway_configure() {
  local base_url="$1"
  local host="api.ofm.local"
  local kubeconfig_path="${OFM_K3D_KUBECONFIG:-$HOME/.kube/k3d-ofm.yaml}"
  local namespace="${OFM_K3D_NAMESPACE:-ofm}"
  local ingress_ip="${API_GATEWAY_RESOLVE_IP:-}"
  local forward_port="${API_GATEWAY_FORWARD_PORT:-18080}"
  local forward_log="${API_GATEWAY_FORWARD_LOG:-/tmp/ofm-api-gateway-port-forward.log}"

  OFM_API_GATEWAY_CURL_ARGS=()

  if [[ "$base_url" != http://${host}* ]]; then
    return 0
  fi

  if [[ -z "$ingress_ip" ]] && command -v kubectl >/dev/null 2>&1; then
    ingress_ip="$(kubectl --kubeconfig "$kubeconfig_path" -n "$namespace" get ingress api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  fi
  if [[ -z "$ingress_ip" ]]; then
    ingress_ip="172.22.0.2"
  fi

  OFM_API_GATEWAY_CURL_ARGS=(--resolve "${host}:80:${ingress_ip}")
  if curl -sS "${OFM_API_GATEWAY_CURL_ARGS[@]}" --connect-timeout 1 -o /dev/null "$base_url" >/dev/null 2>&1; then
    return 0
  fi

  OFM_API_GATEWAY_CURL_ARGS=(--connect-to "${host}:80:127.0.0.1:${forward_port}")
  if curl -sS "${OFM_API_GATEWAY_CURL_ARGS[@]}" --connect-timeout 1 -o /dev/null "$base_url" >/dev/null 2>&1; then
    return 0
  fi

  kubectl --kubeconfig "$kubeconfig_path" -n "$namespace" port-forward svc/api-gateway "${forward_port}:8080" --address 127.0.0.1 >"$forward_log" 2>&1 &
  OFM_API_GATEWAY_PORT_FORWARD_PID="$!"

  for _ in {1..30}; do
    if curl -sS "${OFM_API_GATEWAY_CURL_ARGS[@]}" --connect-timeout 1 -o /dev/null "$base_url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done

  return 1
}

ofm_api_gateway_cleanup() {
  if [[ -n "$OFM_API_GATEWAY_PORT_FORWARD_PID" ]]; then
    kill "$OFM_API_GATEWAY_PORT_FORWARD_PID" >/dev/null 2>&1 || true
  fi
}
