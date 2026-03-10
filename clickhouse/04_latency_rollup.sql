CREATE TABLE latency_rollup_1m
(
    minute DateTime,
    service String,
    incident_mode String,
    dependency_status String,
    event_count_state AggregateFunction(count),
    error_count_state AggregateFunction(countIf, UInt8),
    avg_latency_state AggregateFunction(avg, Float32),
    p95_latency_state AggregateFunction(quantile(0.95), Float32),
    p99_latency_state AggregateFunction(quantile(0.99), Float32)
)
ENGINE = AggregatingMergeTree
ORDER BY (service, incident_mode, dependency_status, minute);