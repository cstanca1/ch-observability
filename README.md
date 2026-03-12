# Observability Pipeline

![GitHub stars](https://img.shields.io/github/stars/cstanca1/ch-observability)
![GitHub forks](https://img.shields.io/github/forks/cstanca1/ch-observability)
![GitHub issues](https://img.shields.io/github/issues/cstanca1/ch-observability)
![License](https://img.shields.io/badge/license-MIT-green)
![Architecture Demo](https://img.shields.io/badge/demo-observability-blue)
![Docker Compose](https://img.shields.io/badge/Docker-Compose-blue)
![Kafka](https://img.shields.io/badge/Kafka-Streaming-black)
![ClickHouse](https://img.shields.io/badge/ClickHouse-Analytics-yellow)
![Grafana](https://img.shields.io/badge/Grafana-Dashboards-orange)
![Python](https://img.shields.io/badge/Python-Generator-green)

A self-contained **streaming observability pipeline demo** showing how modern telemetry systems are built using:

- **Kafka** — streaming ingestion  
- **ClickHouse** — high-performance analytics  
- **Grafana** — observability dashboards  
- **Python synthetic log generator** — simulated microservice telemetry  

The project models how production observability systems ingest logs, compute latency metrics, simulate incidents, and visualize system health in real time.

---

# Architecture Overview

<p align="center">
  <img src="docs/images/architecture1.png" width="900">
</p>

Synthetic microservice logs are generated and streamed through Kafka into ClickHouse for analytical processing.  
Latency rollups and incident simulations are visualized through Grafana dashboards.

---

# 30-Second Demo

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
- Incident simulation
- Error analytics
- Latency metrics
- p95/p99 rollups

---

# Demo Controller

The repository includes an interactive **demo controller** that allows running observability scenarios.

Run:

```bash
./scripts/demo.sh
```

Menu:

```
ClickHouse Observability Demo Controller

Scenarios

1) Baseline Observability
2) Latency Spike
3) Authentication Failure
4) Cascading Failure
5) Recovery
6) Rollup Analytics
7) Full Pipeline Demo
8) Replay Kafka -> Reload ClickHouse

Operations

p) Purge demo data
s) Show pipeline status
q) Quit
```

---

# Recommended Demo Flow

```
1 → Baseline system behavior
2 → Latency spike
4 → Cascading failure
5 → Recovery
6 → Rollup analytics
7 → Full pipeline demo
```

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
Finalized Rollup View
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
│   ├── 05_latency_rollup_mv.sql
│   └── 06_latency_rollup_final_view.sql
│
├── grafana
│   ├── provisioning
│   │   ├── datasources
│   │   └── dashboards
│   └── dashboards
│
├── scripts
│   ├── demo.sh
│   ├── purge_demo_data.sh
│   └── scenarios
│
└── Makefile
```

---

# Requirements

Install:

- Docker Desktop
- Docker Compose
- Git

Verify installation:

```
docker version
docker compose version
```

---

# Starting the Environment

Clone the repository.

```bash
git clone https://github.com/cstanca1/ch-observability.git
cd ch-observability
```

Start the stack.

```bash
docker compose up --build
```

---

# Services Started

The following containers run:

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

Grafana dashboards are **automatically provisioned**.

### Service Health

Displays:

- event throughput
- latency metrics
- error counts
- service traffic

### Incident Timeline

Shows:

- errors per minute
- latency spikes
- incident progression

### Error Analysis

Displays:

- errors by service
- HTTP status codes
- top error combinations

### Dependency Propagation

Visualizes cascading failure impact across services.

---

# Synthetic Log Generator

Each event contains:

```
timestamp
service
log level
latency
status code
incident mode
dependency status
dependency_count
depends_on
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

Controlled by:

```
INCIDENT_MODE
```

Available modes:

```
normal
latency_spike
auth_failure
recovery
cascading_failure
```

---

# Cascading Failure Model

Dependency chain:

```
auth → checkout → payment
```

Behavior:

- auth becomes unstable
- checkout slows due to auth dependency
- payment degrades due to checkout failures
- catalog experiences minor pressure

---

# Verifying the Pipeline

Generator logs:

```
docker compose logs -f generator
```

Kafka topic creation:

```
docker compose logs kafka-init
```

ClickHouse ingestion:

```
docker compose exec clickhouse clickhouse-client \
  --user default --password clickhouse \
  --query "SELECT count() FROM logs"
```

---

# Latency Rollups (p95 / p99)

Implemented using:

- AggregatingMergeTree
- Materialized Views
- quantileState / quantileMerge

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

# Kafka Replay into ClickHouse

Scenario **8** demonstrates how retained Kafka telemetry can rebuild analytics state.

The replay process:

```
Kafka retained logs
        ↓
Reset ClickHouse consumer group
        ↓
Replay messages
        ↓
Rebuild ClickHouse tables
```

This models recovery workflows used in real streaming systems.

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

```
make demo
make reset
make rollups
make logs
```

---

# What This Demo Models

This architecture reflects patterns used in real observability platforms such as:

- Datadog
- New Relic
- Elastic
- Honeycomb
- Snowflake observability workloads

Key concepts demonstrated:

- streaming ingestion
- real-time analytics
- percentile latency metrics
- incident simulation
- distributed system failure propagation

---

# Next Steps

Potential improvements:

- service dependency graph
- traffic burst simulation
- OpenTelemetry integration
- distributed tracing
- ClickHouse cluster mode

---

# License

MIT