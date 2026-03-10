CREATE TABLE logs_kafka
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
ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'app_logs',
    kafka_group_name = 'clickhouse_consumer',
    kafka_format = 'JSONEachRow';