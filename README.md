---

# Latency Rollups (p95 / p99 Analytics)

This project now includes **ClickHouse latency rollups** to compute
**p95 and p99 latency metrics per service per minute**.

In real observability systems, dashboards rarely query raw logs directly.
Instead they rely on **pre-aggregated rollup tables** that make percentile
queries extremely fast.

This demo implements rollups using:

- ClickHouse **Materialized Views**
- **AggregatingMergeTree**
- `quantileState()` / `quantileMerge()` functions

### Extended Architecture

```
Generator
   │
   ▼
Kafka
   │
   ▼
ClickHouse Raw Logs
   │
   ▼
Materialized View
   │
   ▼
Latency Rollup Table
   │
   ▼
Grafana Dashboards
```

---

# Applying Schema Changes

Rollup tables are created automatically when ClickHouse initializes.

If you pull a new version of the repository containing schema changes,
restart the stack with a **clean ClickHouse volume**:

```bash
docker compose down -v
docker compose up --build -d
```

This allows ClickHouse to execute the initialization SQL files located in:

```
clickhouse/
```

---

# Verifying Rollup Tables

Check that the rollup tables were created:

```bash
docker compose exec clickhouse clickhouse-client \
  --user default --password clickhouse \
  --query "SHOW TABLES"
```

Expected output:

```
logs
logs_kafka
logs_mv
latency_rollup_1m
latency_rollup_1m_mv
```

---

# Querying Latency Rollups

Example query to compute **p95 and p99 latency by service**:

```bash
docker compose exec clickhouse clickhouse-client \
  --user default --password clickhouse \
  --query "
SELECT
  service,
  incident_mode,
  round(quantileMerge(0.95)(p95_latency_state), 2) AS p95_latency_ms,
  round(quantileMerge(0.99)(p99_latency_state), 2) AS p99_latency_ms
FROM latency_rollup_1m
WHERE minute >= toStartOfMinute(now()) - INTERVAL 5 MINUTE
GROUP BY service, incident_mode
ORDER BY p99_latency_ms DESC
"
```

Example result:

```
service    incident_mode   p95_latency_ms   p99_latency_ms
checkout   latency_spike   420              810
auth       auth_failure    210              330
catalog    normal          120              180
```

---

# Why Rollups Matter

Rollups provide several advantages:

- Faster Grafana dashboards
- Efficient percentile calculations
- Reduced query load on raw logs
- More realistic production observability architecture

---

# Optional Makefile Commands

The repository also includes convenient Makefile commands.

Reset the environment:

```bash
make reset
```

Check rollups:

```bash
make rollups
```

Follow logs:

```bash
make logs
```