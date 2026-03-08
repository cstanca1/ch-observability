CREATE TABLE logs
(
ts DateTime,
service String,
level String,
latency_ms Float32,
message String
)
ENGINE = MergeTree
ORDER BY ts;
