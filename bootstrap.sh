#!/bin/bash

set -e

echo "Creating project structure..."

mkdir -p generator kafka clickhouse grafana/provisioning/datasources grafana/provisioning/dashboards grafana/dashboards

#######################################

# docker-compose.yml

#######################################
cat << 'EOF' > docker-compose.yml
version: "3.9"

services:

zookeeper:
image: confluentinc/cp-zookeeper:7.5.0
environment:
ZOOKEEPER_CLIENT_PORT: 2181
ports:
- "2181:2181"

kafka:
image: confluentinc/cp-kafka:7.5.0
depends_on:
- zookeeper
ports:
- "9092:9092"
environment:
KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1

clickhouse:
image: clickhouse/clickhouse-server:latest
ports:
- "8123:8123"
- "9000:9000"
volumes:
- ./clickhouse:/docker-entrypoint-initdb.d

grafana:
image: grafana/grafana:latest
ports:
- "3000:3000"
volumes:
- ./grafana/provisioning:/etc/grafana/provisioning
- ./grafana/dashboards:/var/lib/grafana/dashboards

generator:
build: ./generator
depends_on:
- kafka
EOF

#######################################

# Kafka init

#######################################
cat << 'EOF' > kafka/init-topics.sh
#!/bin/bash
sleep 15
kafka-topics 
--create 
--topic app_logs 
--bootstrap-server kafka:9092 
--partitions 3 
--replication-factor 1
EOF

chmod +x kafka/init-topics.sh

#######################################

# ClickHouse tables

#######################################
cat << 'EOF' > clickhouse/01_logs_table.sql
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
EOF

cat << 'EOF' > clickhouse/02_kafka_engine.sql
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
EOF

cat << 'EOF' > clickhouse/03_materialized_view.sql
CREATE MATERIALIZED VIEW logs_mv
TO logs
AS
SELECT *
FROM logs_kafka;
EOF

#######################################

# Log generator

#######################################
cat << 'EOF' > generator/generator.py
import json
import random
import time
from kafka import KafkaProducer
from datetime import datetime

services = ["auth", "checkout", "catalog", "payment"]

producer = KafkaProducer(
bootstrap_servers="kafka:9092",
value_serializer=lambda v: json.dumps(v).encode("utf-8"),
)

while True:
event = {
"ts": datetime.utcnow().isoformat(),
"service": random.choice(services),
"level": random.choice(["INFO","WARN","ERROR"]),
"latency_ms": random.random()*1000,
"message": "demo event"
}

```
producer.send("app_logs", event)
time.sleep(0.01)
```

EOF

#######################################

# Generator Dockerfile

#######################################
cat << 'EOF' > generator/Dockerfile
FROM python:3.11
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY generator.py .
CMD ["python","generator.py"]
EOF

#######################################

# requirements

#######################################
cat << 'EOF' > generator/requirements.txt
kafka-python
EOF

#######################################

# README

#######################################
cat << 'EOF' > README.md

# ClickHouse Observability Demo

Streaming observability demo using:

Kafka
ClickHouse
Grafana
Synthetic log generator

Start demo:

docker compose up --build

Grafana:
http://localhost:3000

ClickHouse:
http://localhost:8123
EOF

echo "Project files created."

