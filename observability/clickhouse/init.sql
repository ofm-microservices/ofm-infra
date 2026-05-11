CREATE TABLE IF NOT EXISTS ofm_logs
(
    timestamp DateTime64(3) DEFAULT now64(3),
    service String,
    env String,
    module String,
    level String,
    msg String,
    message String,
    trace_id String,
    span_id String,
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
ORDER BY (service, env, timestamp, trace_id, span_id);
