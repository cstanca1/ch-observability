CREATE TABLE logs_kafka
(
ts DateTime,
service String,
level String,
latency_ms Float32,
message String
)
ENGINE = Kafka
SETTINGS
kafka_broker_list = 'kafka:9092',
kafka_topic_list = 'app_logs',
kafka_group_name = 'clickhouse_consumer',
kafka_format = 'JSONEachRow';
