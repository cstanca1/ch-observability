CREATE TABLE logs
(
ts DateTime64(3),
service String,
level String,
latency_ms Float32,
message String
)
ENGINE = MergeTree
ORDER BY ts;
