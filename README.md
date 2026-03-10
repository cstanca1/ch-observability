# ClickHouse Observability Demo

A self-contained **streaming observability pipeline demo** using:

- **Kafka** for streaming ingestion
- **ClickHouse** for high-performance analytics
- **Grafana** for dashboards
- **Python log generator** simulating microservice traffic

The project demonstrates how modern observability platforms ingest logs, analyze latency metrics, and visualize system health in near real time.

---

# 30-Second Observability Demo

Run the entire observability stack locally.

```bash
git clone https://github.com/cstanca1/ch-observability.git
cd ch-observability
docker compose up --build
```

Open Grafana:

```
http://localhost:3000
```

Login:

```
admin / admin
```

You will immediately see:

- Service health dashboards
- Error analytics
- Latency metrics
- Incident simulation

---

# What This Demo Demonstrates

This repository models several real observability patterns used in production systems.

- Streaming telemetry ingestion
- Microservice log generation
- Kafka event pipelines
- ClickHouse analytics
- Grafana observability dashboards
- Incident simulation
- Percentile latency metrics (p95 / p99)
- Materialized view rollups

---

# Architecture

```
Synthetic Services
(Log Generator)
        │
        ▼
      Kafka
  Streaming Logs
        │
        ▼
ClickHouse Kafka Engine
        │
        ▼
Materialized View
        │
        ▼
ClickHouse Logs Table
        │
        ▼
Latency Rollups (p95 / p99)
        │
        ▼
     Grafana
Observability Dashboards
```

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
│   ├── 03_materialized_view.sql
│   ├── 04_latency_rollup.sql
│   └── 05_latency_rollup_mv.sql
│
├── grafana
│   ├── provisioning
│   │   ├── datasources
│   │   └── dashboards
│   └── dashboards
│
└── Makefile
```

---

# Requirements

Install:

- Docker Desktop
- Docker Compose
- Git

Verify:

```
docker version
docker compose version
```

---

# Starting the Stack

Clone the repository.

```bash
git clone https://github.com/cstanca1/ch-observability.git
cd ch-observability
```

Start the environment.

```bash
docker compose up --build
```

---

# Services Started

The following containers will run:

```
zookeeper
kafka
kafka-init
clickhouse
grafana
generator
```

---

# Accessing the Services

## Grafana

```
http://localhost:3000
```

Credentials:

```
admin / admin
```

---

## ClickHouse HTTP Interface

```
http://localhost:8123
```

---

# Observability Dashboards

Dashboards are **automatically provisioned**.

Included dashboards:

### Service Health

Displays:

- total events
- average latency
- error counts
- service traffic

---

### Incident Timeline

Shows:

- errors per minute
- latency spikes
- service behavior over time

---

### Error Analysis

Displays:

- errors by service
- HTTP status codes
- top error combinations

---

# Synthetic Log Generator

The generator simulates microservice telemetry.

Each event includes:

```
timestamp
service
log level
latency
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
  "incident_mode": "normal"
}
```

---

# Incident Simulation

The generator supports several incident scenarios.

Configured via:

```
INCIDENT_MODE
```

Available modes:

```
normal
latency_spike
auth_failure
recovery
```

---

## Normal Mode

Healthy behavior.

Characteristics:

- balanced traffic
- low error rates
- stable latency

---

## Latency Spike

Simulates a performance incident affecting **checkout**.

Effects:

- latency increases
- error rate rises
- service degradation

---

## Auth Failure

Simulates authentication problems affecting **auth**.

Typical errors:

```
401
403
429
500
```

---

## Recovery

Simulates partial recovery after an incident.

Effects:

- latency improves
- error rate decreases

---

# Verifying the Pipeline

### Generator logs

```
docker compose logs -f generator
```

---

### Kafka topic creation

```
docker compose logs kafka-init
```

Expected output:

```
Kafka topic app_logs created
```

---

### ClickHouse ingestion

```
docker compose exec clickhouse clickhouse-client \
  --user default --password clickhouse \
  --query "SELECT count() FROM logs"
```

The count should continuously increase.

---

# Latency Rollups (p95 / p99)

The system includes **ClickHouse latency rollups**.

Rollups provide efficient analytics for latency percentiles.

Implemented using:

- AggregatingMergeTree
- Materialized Views
- quantileState / quantileMerge

---

# Rollup Architecture

```
Raw Logs
   │
   ▼
Materialized View
   │
   ▼
Latency Rollup Table
   │
   ▼
Grafana Percentile Metrics
```

---

# Verify Rollup Tables

```
docker compose exec clickhouse clickhouse-client \
  --user default --password clickhouse \
  --query "SHOW TABLES"
```

Expected tables:

```
latency_rollup_1m
latency_rollup_1m_mv
```

---

# Example Rollup Query

```sql
SELECT
  service,
  incident_mode,
  round(quantileMerge(0.95)(p95_latency_state),2) AS p95_latency_ms,
  round(quantileMerge(0.99)(p99_latency_state),2) AS p99_latency_ms
FROM latency_rollup_1m
WHERE minute >= toStartOfMinute(now()) - INTERVAL 5 MINUTE
GROUP BY service, incident_mode
ORDER BY p99_latency_ms DESC
```

---

# Useful Commands

Start environment

```
docker compose up --build -d
```

Stop environment

```
docker compose down
```

Reset environment

```
docker compose down -v
docker compose up --build -d
```

Follow logs

```
docker compose logs -f
```

---

# Makefile Commands

Convenience commands:

Start demo

```
make demo
```

Reset environment

```
make reset
```

Check rollups

```
make rollups
```

View logs

```
make logs
```

---

# What This Demo Models

This architecture mirrors patterns used in production observability platforms such as:

- Datadog
- New Relic
- Elastic
- Honeycomb
- Snowflake Observability workloads

Key concepts demonstrated:

- streaming ingestion
- real-time analytics
- percentile metrics
- observability dashboards
- incident simulation

---

# Next Steps

Possible enhancements:

### Cascading Failure Simulation

Simulate service dependency failures.

```
auth → checkout → payments
```

---

### Service Dependency Graph

Visualize service topology.

---

### Time-Series Dashboards

Use rollup tables for time-series panels.

---

### Traffic Burst Simulation

Generate traffic spikes.

---

### OpenTelemetry Integration

Replace generator with OTEL telemetry.

---

### Distributed Tracing

Simulate spans and trace IDs.

---

### ClickHouse Cluster Mode

Extend to multi-node ClickHouse.

---

# License

MIT