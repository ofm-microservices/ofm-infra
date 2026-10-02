#!/bin/sh
set -eu

rest="http://127.0.0.1:8083"
connector_dir="/kafka/config/ofm-connectors"

properties_json() {
  awk -F= '
    BEGIN { printf "{"; first=1 }
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    {
      key=$1; value=substr($0, index($0,"=")+1)
      gsub(/\\/, "\\\\", key); gsub(/"/, "\\\"", key)
      gsub(/\\/, "\\\\", value); gsub(/"/, "\\\"", value)
      if (!first) printf ","; first=0
      printf "\"%s\":\"%s\"", key, value
    }
    END { print "}" }
  ' "$1"
}

until curl -fsS "$rest/" >/dev/null 2>&1; do sleep 1; done

# Connector ownership belongs to migration-cdc-reconciler. Keeping this
# worker-side script wait-only prevents two startup controllers from deleting
# and recreating the same connectors concurrently after a host restart.
printf '%s\n' 'Debezium REST is ready; connector reconciliation is delegated'
