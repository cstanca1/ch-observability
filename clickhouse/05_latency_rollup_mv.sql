CREATE MATERIALIZED VIEW latency_rollup_1m_mv
TO latency_rollup_1m
AS
SELECT
    toStartOfMinute(ts) AS minute,
    service,
    incident_mode,
    dependency_status,
    countState() AS event_count_state,
    countIfState(level = 'ERROR') AS error_count_state,
    avgState(latency_ms) AS avg_latency_state,
    quantileState(0.95)(latency_ms) AS p95_latency_state,
    quantileState(0.99)(latency_ms) AS p99_latency_state
FROM logs
GROUP BY
    minute,
    service,
    incident_mode,
    dependency_status;