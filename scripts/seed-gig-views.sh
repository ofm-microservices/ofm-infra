#!/usr/bin/env bash
set -euo pipefail

# Seeds the local ClickHouse business-events table with synthetic gig.viewed rows.
# The helper is intentionally small and explicit so it can be rerun for local
# popularity testing without touching application code.

NAMESPACE="${OFM_NAMESPACE:-ofm}"
CLICKHOUSE_DEPLOYMENT="${CLICKHOUSE_DEPLOYMENT:-clickhouse}"
VIEW_COUNT_PER_GIG="${VIEW_COUNT_PER_GIG:-50}"
WINDOW_SECONDS="${WINDOW_SECONDS:-604800}"

GIG_IDS=(
  "019e706c-616e-7473-9c1a-838c33b75013"
  "019e6ae5-904f-77eb-8922-069f50621794"
  "019e6656-f9f3-778a-a410-8909df7c64aa"
  "019e6653-92a0-7360-939e-256e9745b542"
  "019e6649-a8c0-74e5-9212-e2dee7b747ba"
  "019e6646-fedb-771b-89ab-cd6548616a2b"
  "019e5a89-da40-727c-afd5-8e81d0c6265e"
  "019e5a6e-09a0-7618-b7e8-c9db2bffbd09"
)

gig_ids_sql="$(printf "'%s', " "${GIG_IDS[@]}")"
gig_ids_sql="${gig_ids_sql%, }"
total_views="$((VIEW_COUNT_PER_GIG * ${#GIG_IDS[@]}))"

read -r -d '' sql <<EOF || true
CREATE TABLE IF NOT EXISTS ofm_business_events
(
    timestamp DateTime64(3) DEFAULT now64(3),
    service String,
    env String,
    operation String,
    event_type String DEFAULT '',
    gig_id String DEFAULT '',
    order_id String DEFAULT '',
    review_id String DEFAULT '',
    user_id String DEFAULT '',
    amount_cents Int64 DEFAULT 0,
    raw String
)
ENGINE = MergeTree
PARTITION BY toDate(timestamp)
ORDER BY (operation, gig_id, timestamp)
TTL timestamp + INTERVAL 35 DAY;

INSERT INTO ofm_business_events
SELECT
    now64(3) - toIntervalSecond(rand() % ${WINDOW_SECONDS}) AS timestamp,
    'gig-service' AS service,
    'local' AS env,
    'gig.viewed' AS operation,
    'gig.viewed' AS event_type,
    arrayElement([${gig_ids_sql}], intDiv(number, ${VIEW_COUNT_PER_GIG}) + 1) AS gig_id,
    '' AS order_id,
    '' AS review_id,
    '' AS user_id,
    0 AS amount_cents,
    concat('{\"gig_id\":\"', gig_id, '\",\"seed\":true,\"source\":\"manual-seed\"}') AS raw
FROM numbers(${total_views});
EOF

kubectl -n "${NAMESPACE}" exec deploy/"${CLICKHOUSE_DEPLOYMENT}" -- \
  clickhouse-client --user admin --password admin --multiquery --query "${sql}"
