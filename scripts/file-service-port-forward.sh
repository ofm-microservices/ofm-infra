#!/usr/bin/env bash
set -euo pipefail

OFM_FILE_SERVICE_PORT_FORWARD_PID=""

ofm_file_service_port_forward_is_up() {
  local forward_port="${FILE_SERVICE_FORWARD_PORT:-9504}"
  if command -v nc >/dev/null 2>&1; then
    nc -z 127.0.0.1 "$forward_port" >/dev/null 2>&1
    return $?
  fi

  bash -lc ":</dev/tcp/127.0.0.1/${forward_port}" >/dev/null 2>&1
}

ofm_file_service_port_forward_start() {
  local kubeconfig_path="${OFM_K3D_KUBECONFIG:-$HOME/.kube/k3d-ofm.yaml}"
  local namespace="${OFM_K3D_NAMESPACE:-ofm}"
  local forward_port="${FILE_SERVICE_FORWARD_PORT:-9504}"
  local forward_log="${FILE_SERVICE_FORWARD_LOG:-/tmp/ofm-file-service-port-forward.log}"

  if ofm_file_service_port_forward_is_up; then
    return 0
  fi

  kubectl --kubeconfig "$kubeconfig_path" -n "$namespace" port-forward svc/file-service "${forward_port}:9504" --address 127.0.0.1 >"$forward_log" 2>&1 &
  OFM_FILE_SERVICE_PORT_FORWARD_PID="$!"

  for _ in {1..30}; do
    if ofm_file_service_port_forward_is_up; then
      return 0
    fi
    sleep 0.2
  done

  return 1
}

ofm_file_service_port_forward_cleanup() {
  if [[ -n "$OFM_FILE_SERVICE_PORT_FORWARD_PID" ]]; then
    kill "$OFM_FILE_SERVICE_PORT_FORWARD_PID" >/dev/null 2>&1 || true
  fi
}
