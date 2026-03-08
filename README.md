# ClickHouse Observability Demo

A lightweight **streaming observability pipeline** demonstrating how logs from microservices can be ingested, processed, and analyzed in near-real time using:

* Kafka for event streaming
* ClickHouse for high-performance analytics
* Grafana for visualization
* A synthetic log generator simulating microservices

The stack runs locally using Docker Compose and can be started with a single command.

---

# Architecture

The demo implements a simple observability data pipeline.

```
Synthetic Services
        │
        │ JSON logs
        ▼
   Kafka Topic (app_logs)
        │
        ▼
ClickHouse Kafka Engine
        │
        ▼
Materialized View
        │
        ▼
ClickHouse MergeTree Table
        │
        ▼
Grafana Dashboards
```

Flow description:

1. The **log generator** simulates microservice events.
2. Events are written to **Kafka** (`app_logs` topic).
3. ClickHouse reads the stream through a **Kafka engine table**.
4. A **materialized view** continuously inserts records into the analytics table.
5. Grafana queries ClickHouse for observability dashboards.

---

# Repository Structure

```
ch-observability
│
├── docker-compose.yml
│
├── generator
│   ├── generator.py
│   ├── Dockerfile
│   └── requirements.txt
│
├── kafka
│   └── init-topics.sh
│
├── clickhouse
│   ├── 01_logs_table.sql
│   ├── 02_kafka_engine.sql
│   └── 03_materialized_view.sql
│
└── grafana
    ├── provisioning
    │   ├── datasources
    │   └── dashboards
    └── dashboards
```

---

# Components

## Synthetic Log Generator

A small Python application that produces realistic microservice logs.

Each event contains:

```
timestamp
service
log level
latency
message
```

Example event:

```json
{
  "ts": "2026-03-07T21:10:11.223",
  "service": "checkout",
  "level": "INFO",
  "latency_ms": 231.4,
  "message": "demo event"
}
```

Events are produced continuously and sent to Kafka.

---

## Kafka

Kafka acts as the **streaming buffer** between applications and analytics.

Topic created automatically:

```
app_logs
```

Kafka provides:

* durability
* streaming ingestion
* decoupling between producers and consumers

---

## ClickHouse

ClickHouse consumes events directly from Kafka using the **Kafka table engine**.

Tables:

### Raw analytics table

```
logs
```

Engine:

```
MergeTree
```

Used for analytical queries.

### Kafka ingestion table

```
logs_kafka
```

Engine:

```
Kafka
```

Reads messages from Kafka.

### Materialized view

```
logs_mv
```

Continuously inserts Kafka events into `logs`.

---

## Grafana

Grafana connects to ClickHouse and allows creation of dashboards for:

* service traffic
* latency distribution
* error rates
* system health

---

# Requirements

You need:

* Docker Desktop
* Docker Compose
* Git

Test installation:

```
docker version
docker compose version
```

---

# Setup

Clone the repository:

```
git clone https://github.com/cstanca1/ch-observability.git
cd ch-observability
```

Start the stack:

```
docker compose up --build
```

Docker will start:

```
zookeeper
kafka
kafka-init
clickhouse
grafana
generator
```

---

# Access the Services

Grafana

```
http://localhost:3000
```

Login:

```
admin / admin
```

ClickHouse HTTP interface

```
http://localhost:8123
```

---

# Verifying the Pipeline

## 1. Check generator logs

```
docker compose logs -f generator
```

You should see events being produced.

---

## 2. Check Kafka topic creation

```
docker compose logs kafka-init
```

Expected output:

```
Kafka topic app_logs created
```

---

## 3. Check ClickHouse tables

```
docker compose exec clickhouse \
clickhouse-client --user default --password clickhouse \
--query "SHOW TABLES"
```

Expected:

```
logs
logs_kafka
logs_mv
```

---

## 4. Verify data ingestion

```
docker compose exec clickhouse \
clickhouse-client --user default --password clickhouse \
--query "SELECT count() FROM logs"
```

The count should increase continuously.

---

# Useful Commands

Start stack

```
docker compose up --build -d
```

View logs

```
docker compose logs -f
```

Stop stack

```
docker compose down
```

Clean environment

```
docker compose down -v
```

---

# Troubleshooting

## Generator cannot connect to Kafka

Check Kafka is running:

```
docker compose ps
```

Restart generator:

```
docker compose restart generator
```

---

## ClickHouse shows zero rows

Verify materialized view exists:

```
SHOW TABLES
```

Verify Kafka topic exists.

Restart stack if needed:

```
docker compose down -v
docker compose up --build
```

---

# Future Improvements

Planned enhancements:

* realistic microservice simulation
* traffic bursts
* failure injection
* latency spike simulation
* ClickHouse rollup tables
* Grafana dashboards
* OpenTelemetry compatibility

These will transform this project into a full **observability architecture demo**.

---

# License

MIT
