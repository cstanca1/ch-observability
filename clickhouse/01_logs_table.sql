CREATE TABLE logs
(
    ts DateTime64(3),
    service String,
    level String,
    latency_ms Float32,
    message String,
    status_code UInt16,
    incident_mode String,
    dependency_status String,
    dependency_count UInt8,
    depends_on String
)
ENGINE = MergeTree
ORDER BY (service, ts);