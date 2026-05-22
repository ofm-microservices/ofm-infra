#!/usr/bin/env bash
set -euo pipefail

if ! command -v iptables >/dev/null 2>&1; then
  echo "iptables is not installed" >&2
  exit 1
fi

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

pod_cidrs=(
  "10.42.0.0/16"
  "10.43.0.0/16"
)

port_ranges=(
  "3000:3099"
  "4222"
  "4222:4299"
  "5433:5499"
  "6370:6399"
  "8000:8099"
  "9000:9099"
  "9040:9049"
  "9090:9099"
  "9500:9599"
  "9600:9699"
)

allow_rule() {
  local cidr="$1"
  local ports="$2"

  if iptables -C INPUT -s "${cidr}" -p tcp -m tcp --dport "${ports}" -j ACCEPT >/dev/null 2>&1; then
    echo "Skipping existing rule ${cidr} -> ${ports}/tcp"
    return 0
  fi

  iptables -I INPUT -s "${cidr}" -p tcp -m tcp --dport "${ports}" -j ACCEPT
  echo "Added rule ${cidr} -> ${ports}/tcp"
}

for cidr in "${pod_cidrs[@]}"; do
  for ports in "${port_ranges[@]}"; do
    allow_rule "${cidr}" "${ports}"
  done
done
