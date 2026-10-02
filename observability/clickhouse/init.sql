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
    test_run_id String DEFAULT '',
    scenario_id String DEFAULT '',
    architecture String DEFAULT '',
    correlation_id String DEFAULT '',
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

CREATE TABLE IF NOT EXISTS ofm_load_test_runs
(
    started_at DateTime64(3),
    finished_at DateTime64(3),
    run_id String,
    scenario_id String,
    environment String,
    profile String,
    architecture String,
    vus UInt32 DEFAULT 0,
    rate UInt32 DEFAULT 0,
    duration_seconds UInt32 DEFAULT 0,
    status LowCardinality(String),
    checks_total UInt64 DEFAULT 0,
    checks_failed UInt64 DEFAULT 0,
    expected_failures UInt64 DEFAULT 0,
    fault_injected UInt64 DEFAULT 0,
    fallback_accepted UInt64 DEFAULT 0,
    kafka_recovery_published UInt64 DEFAULT 0,
    kafka_recovery_completed UInt64 DEFAULT 0,
    projection_completed UInt64 DEFAULT 0,
    load_shed UInt64 DEFAULT 0,
    recovery_pass UInt8 DEFAULT 0,
    verdict LowCardinality(String) DEFAULT '',
    http_requests UInt64 DEFAULT 0,
    http_failed UInt64 DEFAULT 0,
    p95_duration_ms Float64 DEFAULT 0,
    kafka_lag Int64 DEFAULT 0,
    projection_pending Int64 DEFAULT 0,
    projection_failures Int64 DEFAULT 0,
    dlq_count Int64 DEFAULT 0,
    recovery_time_ms Int64 DEFAULT 0,
    projection_audit_pass UInt8 DEFAULT 0,
    projection_audit_json String DEFAULT '',
    result_json String DEFAULT ''
)
ENGINE = MergeTree
PARTITION BY toDate(started_at)
ORDER BY (run_id, architecture, started_at)
TTL started_at + INTERVAL 90 DAY;

ALTER TABLE ofm_logs ADD COLUMN IF NOT EXISTS operation String DEFAULT '';
ALTER TABLE ofm_logs ADD COLUMN IF NOT EXISTS gig_id String DEFAULT '';
ALTER TABLE ofm_logs ADD COLUMN IF NOT EXISTS attempt UInt32 DEFAULT 1;
ALTER TABLE ofm_logs ADD COLUMN IF NOT EXISTS retryable UInt8 DEFAULT 0;
ALTER TABLE ofm_logs ADD COLUMN IF NOT EXISTS duration_ms Int64 DEFAULT 0;
ALTER TABLE ofm_logs ADD COLUMN IF NOT EXISTS test_run_id String DEFAULT '';
ALTER TABLE ofm_logs ADD COLUMN IF NOT EXISTS scenario_id String DEFAULT '';
ALTER TABLE ofm_logs ADD COLUMN IF NOT EXISTS architecture String DEFAULT '';
ALTER TABLE ofm_logs ADD COLUMN IF NOT EXISTS correlation_id String DEFAULT '';
ALTER TABLE ofm_logs MODIFY TTL timestamp + INTERVAL 35 DAY;

ALTER TABLE ofm_load_test_runs ADD COLUMN IF NOT EXISTS fault_injected UInt64 DEFAULT 0;
ALTER TABLE ofm_load_test_runs ADD COLUMN IF NOT EXISTS fallback_accepted UInt64 DEFAULT 0;
ALTER TABLE ofm_load_test_runs ADD COLUMN IF NOT EXISTS kafka_recovery_published UInt64 DEFAULT 0;
ALTER TABLE ofm_load_test_runs ADD COLUMN IF NOT EXISTS kafka_recovery_completed UInt64 DEFAULT 0;
ALTER TABLE ofm_load_test_runs ADD COLUMN IF NOT EXISTS projection_completed UInt64 DEFAULT 0;
ALTER TABLE ofm_load_test_runs ADD COLUMN IF NOT EXISTS load_shed UInt64 DEFAULT 0;
ALTER TABLE ofm_load_test_runs ADD COLUMN IF NOT EXISTS projection_audit_pass UInt8 DEFAULT 0;
ALTER TABLE ofm_load_test_runs ADD COLUMN IF NOT EXISTS projection_audit_json String DEFAULT '';

ALTER TABLE ofm_business_events ADD COLUMN IF NOT EXISTS event_type String DEFAULT '';
ALTER TABLE ofm_business_events ADD COLUMN IF NOT EXISTS gig_id String DEFAULT '';
ALTER TABLE ofm_business_events ADD COLUMN IF NOT EXISTS order_id String DEFAULT '';
ALTER TABLE ofm_business_events ADD COLUMN IF NOT EXISTS review_id String DEFAULT '';
ALTER TABLE ofm_business_events ADD COLUMN IF NOT EXISTS user_id String DEFAULT '';
ALTER TABLE ofm_business_events ADD COLUMN IF NOT EXISTS amount_cents Int64 DEFAULT 0;
ALTER TABLE ofm_business_events MODIFY TTL timestamp + INTERVAL 35 DAY;
