#!/usr/bin/env bash
set -euo pipefail

infra::compose() {
  local -a files=("$@")
  local -a cmd=(docker compose)
  local file
  for file in "${files[@]}"; do
    cmd+=(-f "${file}")
  done
  printf '%s\n' "${cmd[@]}"
}

infra::container_name() {
  printf 'ofm-%s' "$1"
}

infra::wait_exited() {
  local container_name="$1"
  local max_attempts="${2:-300}"
  local attempt=0
  local status
  while true; do
    status="$(docker inspect -f '{{.State.Status}}' "${container_name}" 2>/dev/null || true)"
    if [[ "${status}" == "exited" ]]; then
      return 0
    fi
    attempt=$((attempt + 1))
    if [[ "${attempt}" -ge "${max_attempts}" ]]; then
      echo "timed out waiting for container ${container_name} to exit; last status=${status}" >&2
      docker logs --tail 80 "${container_name}" >&2 || true
      return 1
    fi
    sleep 1
  done
}

infra::wait_all_exited() {
  local name
  for name in "$@"; do
    infra::wait_exited "${name}"
  done
}

infra::wait_exec() {
  local container_name="$1"
  shift
  local max_attempts="${1:-300}"
  if [[ "${max_attempts}" =~ ^[0-9]+$ ]]; then
    shift
  else
    max_attempts=300
  fi
  local attempt=0
  while true; do
    if docker exec "${container_name}" "$@" >/dev/null 2>&1; then
      return 0
    fi
    attempt=$((attempt + 1))
    if [[ "${attempt}" -ge "${max_attempts}" ]]; then
      echo "timed out waiting for container ${container_name} to accept: $*" >&2
      docker logs --tail 80 "${container_name}" >&2 || true
      return 1
    fi
    sleep 1
  done
}

infra::rm_containers() {
  local name
  docker rm -f "$@" >/dev/null 2>&1 || true
}
