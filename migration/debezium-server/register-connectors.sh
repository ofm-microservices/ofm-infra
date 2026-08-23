#!/bin/sh
set -eu

rest="http://127.0.0.1:8083"
connector_dir="/opt/kafka/config/ofm-connectors"

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

for connector in auth user gig order payment review; do
  name="cdc-$connector"
  config="$(properties_json "$connector_dir/$connector.properties")"
  # A persisted distributed Connect config can retain a stale Yugabyte stream
  # ID after a local database volume is recreated. Delete the old connector
  # before registering the checked-in configuration so the worker validates
  # and runs the current stream instead of silently keeping the old one.
  curl -fsS -X DELETE "$rest/connectors/$name" >/dev/null 2>&1 || true
  if ! curl --max-time 120 -fsS -X PUT "$rest/connectors/$name/config" \
    -H 'Content-Type: application/json' \
    --data "$config" >/dev/null; then
    # Keep the Connect worker alive when one Yugabyte cluster is temporarily
    # unavailable. The next compose restart retries registration; healthy
    # connectors must not be lost because another DB is still recovering.
    printf 'connector registration deferred: %s\n' "$name" >&2
    continue
  fi
done

printf '%s\n' 'registered auth user gig order payment review connectors'
