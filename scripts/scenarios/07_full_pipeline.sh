#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="docker-compose.yml"
GRAFANA_URL="http://localhost:3000"

is_running() {
  docker compose ps --status running --services | grep -qx "$1"
}

ensure_service_running() {
  local service="$1"

  if is_running "$service"; then
    echo "$service is already running."
    return 0
  fi

  echo "$service is not running. Starting it..."
  docker compose start "$service" >/dev/null 2>&1 || docker compose up -d "$service" >/dev/null
  echo "$service started."
}

wait_for_clickhouse() {
  echo "Waiting for ClickHouse to become ready..."
  for _ in {1..30}; do
    if docker compose exec -T clickhouse clickhouse-client --query "SELECT 1" >/dev/null 2>&1; then
      echo "ClickHouse is ready."
      return 0
    fi
    sleep 2
  done

  echo "ClickHouse did not become ready in time."
  return 1
}

set_mode() {
  python3 - <<PY
import re
from pathlib import Path

p = Path("${COMPOSE_FILE}")
t = p.read_text()

t = re.sub(r'(^\s+INCIDENT_MODE:\s*")[^"]+(")', r'\1cascading_failure\2', t, count=1, flags=re.M)

p.write_text(t)
print("INCIDENT_MODE set to cascading_failure")
PY
}

print_rows() {
  docker compose exec -T clickhouse clickhouse-client --query "SELECT count() FROM logs" 2>/dev/null || echo "unknown"
}

echo
echo "=================================================="
echo " Scenario 7: Full Pipeline Demo"
echo "=================================================="
echo
echo "What this scenario does:"
echo "  - Ensures kafka, clickhouse, and grafana are running"
echo "  - Sets INCIDENT_MODE to cascading_failure"
echo "  - Restarts the generator"
echo "  - Produces end-to-end pipeline activity across generator, Kafka, ClickHouse, rollups, and Grafana"
echo
echo "What to show:"
echo "  - Generator logs producing events"
echo "  - Kafka feeding ClickHouse"
echo "  - ClickHouse row count increasing"
echo "  - Rollup analytics from latency_rollup_1m"
echo "  - Grafana dashboards updating live"
echo "  - Dependency propagation: auth -> checkout -> payment"
echo

ensure_service_running kafka
ensure_service_running clickhouse
ensure_service_running grafana
wait_for_clickhouse

echo
echo "Current ClickHouse row count before scenario:"
echo "  $(print_rows)"
echo

set_mode

echo "Restarting generator for full pipeline demo..."
docker compose up -d --build generator >/dev/null
echo "Generator restarted."
echo

echo "Scenario 7 is now active."
echo "Grafana: ${GRAFANA_URL}"
echo
echo "Suggested demo flow:"
echo "  1. Show generator logs:"
echo "       docker compose logs -f generator"
echo
echo "  2. Show ClickHouse row count:"
echo "       docker compose exec clickhouse clickhouse-client --query \"SELECT count() FROM logs\""
echo
echo "  3. Show dependency impact query:"
echo "       SELECT service, dependency_status, round(avg(latency_ms), 2) AS avg_latency_ms, countIf(level = 'ERROR') AS errors FROM logs WHERE incident_mode = 'cascading_failure' GROUP BY service, dependency_status ORDER BY avg_latency_ms DESC;"
echo
echo "  4. Show rollup query:"
echo "       SELECT service, dependency_status, round(quantileMerge(0.95)(p95_latency_state), 2) AS p95_latency_ms, round(quantileMerge(0.99)(p99_latency_state), 2) AS p99_latency_ms FROM latency_rollup_1m WHERE minute >= toStartOfMinute(now()) - INTERVAL 15 MINUTE GROUP BY service, dependency_status ORDER BY p99_latency_ms DESC;"
echo
echo "Current ClickHouse row count after scenario start:"
echo "  $(print_rows)"
echo
