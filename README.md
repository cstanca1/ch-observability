# ClickHouse Observability Demo

This project demonstrates a **streaming observability pipeline** built with:

* **Kafka** – event streaming
* **ClickHouse** – high-performance analytics
* **Grafana** – observability dashboards
* **Python log generator** – synthetic microservice telemetry

The system simulates logs produced by microservices and processes them in near-real time for analysis.

The entire stack runs locally using Docker Compose.

---

# Architecture

The demo implements a simplified observability pipeline.

```
Synthetic Services (Generator)
          │
          │ JSON logs
          ▼
     Kafka Topic
       app_logs
          │
          ▼
ClickHouse Kafka Engine Table
          │
          ▼
   Materialized View
          │
          ▼
 ClickHouse MergeTree Table
          │
          ▼
      Grafana
   Observability UI
```

### Flow description

1. The **log generator** simulates application logs.
2. Logs are sent to **Kafka** (`app_logs` topic).
3. ClickHouse consumes Kafka messages through a **Kafka engine table**.
4. A **materialized view** inserts events into the analytics table.
5. Grafana queries ClickHouse for dashboards.

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

## Log Generator

A Python application that simulates microservice telemetry.

Each log event contains:

```
timestamp
service
log level
latency
message
status code
incident mode
```

Example event:

```json
{
  "ts": "2026-03-07T21:10:11.223",
  "service": "checkout",
  "level": "INFO",
  "latency_ms": 231.4,
  "status_code": 200,
  "message": "checkout completed",
  "incident_mode": "normal"
}
```

---

## Kafka

Kafka acts as the **streaming backbone**.

Topic created automatically:

```
app_logs
```

Kafka provides:

* buffering
* decoupling between producer and analytics
* scalable streaming ingestion

---

## ClickHouse

ClickHouse performs the analytical processing.

### Raw table

```
logs
```

Engine:

```
MergeTree
```

Stores events for analytics queries.

---

### Kafka ingestion table

```
logs_kafka
```

Engine:

```
Kafka
```

Consumes messages from the Kafka topic.

---

### Materialized view

```
logs_mv
```

Continuously inserts Kafka events into `logs`.

---

## Grafana

Grafana connects to ClickHouse and visualizes:

* service traffic
* latency distribution
* error rates
* incident behavior

---

# Requirements

You need:

* Docker Desktop
* Docker Compose
* Git

Verify installation:

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

### Grafana

```
http://localhost:3000
```

Login:

```
admin / admin
```

---

### ClickHouse HTTP interface

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

## 2. Verify Kafka topic creation

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
docker compose exec clickhouse clickhouse-client \
  --user default --password clickhouse \
  --query "SHOW TABLES"
```

Expected tables:

```
logs
logs_kafka
logs_mv
```

---

## 4. Verify ingestion

```
docker compose exec clickhouse clickhouse-client \
  --user default --password clickhouse \
  --query "SELECT count() FROM logs"
```

The count should continuously increase.

---

# Incident Simulation Modes

The generator supports **multiple incident simulation modes**.

Modes are controlled through the `INCIDENT_MODE` environment variable in `docker-compose.yml`.

Example:

```
INCIDENT_MODE: "normal"
```

Available modes:

```
normal
latency_spike
auth_failure
recovery
```

---

# Mode Overview

## Normal

Represents healthy system behavior.

Characteristics:

* balanced traffic across services
* low error rates
* stable latency

---

## Latency Spike

Simulates a performance degradation affecting **checkout**.

Effects:

* checkout latency increases significantly
* error rate rises
* traffic biased toward checkout

---

## Auth Failure

Simulates authentication problems affecting **auth**.

Effects:

* login failures increase
* HTTP errors such as:

```
401
403
429
500
```

become more frequent.

---

## Recovery

Represents partial system recovery.

Effects:

* latency improves
* error rates decline
* system stabilizes gradually

---

# Running Each Mode

## Normal Mode

Edit `docker-compose.yml`:

```
INCIDENT_MODE: "normal"
```

Restart generator:

```
docker compose up --build -d generator
```

Query service summary:

```
SELECT
  service,
  count() AS events,
  countIf(level='ERROR') AS errors,
  round(avg(latency_ms),2) AS avg_latency,
  round(quantile(0.95)(latency_ms),2) AS p95_latency
FROM logs
GROUP BY service
ORDER BY service
```

---

## Latency Spike Mode

Set:

```
INCIDENT_MODE: "latency_spike"
```

Restart generator:

```
docker compose up --build -d generator
```

Query latency:

```
SELECT
 service,
 round(avg(latency_ms),2) AS avg_latency,
 round(quantile(0.95)(latency_ms),2) AS p95_latency
FROM logs
GROUP BY service
ORDER BY avg_latency DESC
```

Expected:

```
checkout latency >> other services
```

---

## Auth Failure Mode

Set:

```
INCIDENT_MODE: "auth_failure"
```

Restart generator:

```
docker compose up --build -d generator
```

Query error codes:

```
SELECT
 service,
 status_code,
 count()
FROM logs
WHERE level='ERROR'
GROUP BY service,status_code
ORDER BY service
```

Expected:

```
auth service dominates errors
```

---

## Recovery Mode

Set:

```
INCIDENT_MODE: "recovery"
```

Restart generator:

```
docker compose up --build -d generator
```

Query recovery trend:

```
SELECT
 service,
 round(avg(latency_ms),2) AS latency,
 countIf(level='ERROR') AS errors
FROM logs
GROUP BY service
ORDER BY service
```

Expected:

* latency decreases
* errors decline

---

# Timeline Analysis

Use this query to observe incidents over time.

```
SELECT
 toStartOfMinute(ts) AS minute,
 service,
 countIf(level='ERROR') AS errors,
 round(avg(latency_ms),2) AS latency
FROM logs
GROUP BY minute, service
ORDER BY minute DESC
LIMIT 100
```

This helps visualize:

* incident start
* peak degradation
* recovery trend

---

# Useful Commands

Start stack:

```
docker compose up --build -d
```

View logs:

```
docker compose logs -f
```

Stop stack:

```
docker compose down
```

Clean environment:

```
docker compose down -v
```

---

# Troubleshooting

### Generator cannot connect to Kafka

Check containers:

```
docker compose ps
```

Restart generator:

```
docker compose restart generator
```

---

### ClickHouse shows zero rows

Check tables:

```
SHOW TABLES
```

Restart stack:

```
docker compose down -v
docker compose up --build
```

---

# Future Improvements

Planned enhancements include:

* realistic microservice traffic patterns
* cascading failure simulation
* ClickHouse rollup tables
* Grafana dashboards
* OpenTelemetry integration
* distributed tracing simulation

These improvements will transform the project into a **full observability architecture demo**.

---

# License

MIT
