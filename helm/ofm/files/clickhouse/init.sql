CREATE TABLE IF NOT EXISTS ofm_logs
(
    timestamp DateTime64(3) DEFAULT now64(3),
    service String,
    env String,
    module String,
    operation String DEFAULT '',
    gig_id String DEFAULT '',
    level String,
    msg String,
    message String,
    trace_id String,
    span_id String,
    attempt UInt32 DEFAULT 1,
    retryable UInt8 DEFAULT 0,
    duration_ms Int64 DEFAULT 0,
    error String,
    stacktrace String,
    route String,
    subject String,
    status String,
    pid String,
    container_name String,
    raw String
)
ENGINE = MergeTree
PARTITION BY toDate(timestamp)
ORDER BY (service, env, timestamp, trace_id, span_id)
TTL timestamp + INTERVAL 35 DAY;

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

ALTER TABLE IF EXISTS ofm_logs ADD COLUMN IF NOT EXISTS operation String DEFAULT '';
ALTER TABLE IF EXISTS ofm_logs ADD COLUMN IF NOT EXISTS gig_id String DEFAULT '';
ALTER TABLE IF EXISTS ofm_logs ADD COLUMN IF NOT EXISTS attempt UInt32 DEFAULT 1;
ALTER TABLE IF EXISTS ofm_logs ADD COLUMN IF NOT EXISTS retryable UInt8 DEFAULT 0;
ALTER TABLE IF EXISTS ofm_logs ADD COLUMN IF NOT EXISTS duration_ms Int64 DEFAULT 0;
ALTER TABLE IF EXISTS ofm_logs MODIFY TTL timestamp + INTERVAL 35 DAY;

ALTER TABLE IF EXISTS ofm_business_events ADD COLUMN IF NOT EXISTS event_type String DEFAULT '';
ALTER TABLE IF EXISTS ofm_business_events ADD COLUMN IF NOT EXISTS gig_id String DEFAULT '';
ALTER TABLE IF EXISTS ofm_business_events ADD COLUMN IF NOT EXISTS order_id String DEFAULT '';
ALTER TABLE IF EXISTS ofm_business_events ADD COLUMN IF NOT EXISTS review_id String DEFAULT '';
ALTER TABLE IF EXISTS ofm_business_events ADD COLUMN IF NOT EXISTS user_id String DEFAULT '';
ALTER TABLE IF EXISTS ofm_business_events ADD COLUMN IF NOT EXISTS amount_cents Int64 DEFAULT 0;
ALTER TABLE IF EXISTS ofm_business_events MODIFY TTL timestamp + INTERVAL 35 DAY;
