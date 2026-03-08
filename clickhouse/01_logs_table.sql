CREATE TABLE logs
(
    ts DateTime64(3),
    service String,
    level String,
    latency_ms Float32,
    message String,
    status_code UInt16,
    incident_mode String
)
ENGINE = MergeTree
ORDER BY (service, ts);