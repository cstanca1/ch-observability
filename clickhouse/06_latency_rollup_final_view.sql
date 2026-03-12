CREATE VIEW IF NOT EXISTS latency_rollup_final AS
SELECT
    minute,
    service,
    incident_mode,
    dependency_status,
    countMerge(event_count_state) AS events,
    countIfMerge(error_count_state) AS errors,
    round(avgMerge(avg_latency_state), 2) AS avg_latency_ms,
    round(quantileMerge(0.95)(p95_latency_state), 2) AS p95_latency_ms,
    round(quantileMerge(0.99)(p99_latency_state), 2) AS p99_latency_ms
FROM latency_rollup_1m
GROUP BY
    minute,
    service,
    incident_mode,
    dependency_status;
