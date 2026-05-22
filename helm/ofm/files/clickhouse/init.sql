CREATE TABLE IF NOT EXISTS ofm_logs
(
    timestamp DateTime64(3) DEFAULT now64(3),
    service String,
    env String,
    module String,
    operation String DEFAULT '',
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
TTL timestamp + INTERVAL 7 DAY;

ALTER TABLE IF EXISTS ofm_logs ADD COLUMN IF NOT EXISTS operation String DEFAULT '';
ALTER TABLE IF EXISTS ofm_logs ADD COLUMN IF NOT EXISTS attempt UInt32 DEFAULT 1;
ALTER TABLE IF EXISTS ofm_logs ADD COLUMN IF NOT EXISTS retryable UInt8 DEFAULT 0;
ALTER TABLE IF EXISTS ofm_logs ADD COLUMN IF NOT EXISTS duration_ms Int64 DEFAULT 0;
ALTER TABLE IF EXISTS ofm_logs MODIFY TTL timestamp + INTERVAL 7 DAY;
