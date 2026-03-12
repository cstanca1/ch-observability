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

t = re.sub(r'(^\s+INCIDENT_MODE:\s*")[^"]+(")', r'\1recovery\2', t, count=1, flags=re.M)

p.write_text(t)
print("INCIDENT_MODE set to recovery")
PY
}

print_rows() {
  docker compose exec -T clickhouse clickhouse-client --query "SELECT count() FROM logs" 2>/dev/null || echo "unknown"
}

echo
echo "=================================================="
echo " Scenario 5: Recovery"
echo "=================================================="
echo
echo "What this scenario does:"
echo "  - Ensures kafka, clickhouse, and grafana are running"
echo "  - Sets INCIDENT_MODE to recovery"
echo "  - Restarts the generator"
echo "  - Simulates stabilization after an incident"
echo
echo "What to show:"
echo "  - Grafana Service Health dashboard"
echo "  - Grafana Incident Timeline dashboard"
echo "  - Latency moving back toward baseline"
echo "  - Error rates declining"
echo "  - Comparison with the previous incident scenario"
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

echo "Restarting generator for recovery scenario..."
docker compose up -d --build generator >/dev/null
echo "Generator restarted."
echo

echo "Scenario 5 is now active."
echo "Grafana: ${GRAFANA_URL}"
echo
echo "Recommended ClickHouse query:"
echo
echo "SELECT"
echo "  service,"
echo "  round(avg(latency_ms), 2) AS avg_latency_ms,"
echo "  countIf(level = 'ERROR') AS errors"
echo "FROM logs"
echo "GROUP BY service"
echo "ORDER BY service;"
echo
echo "Current ClickHouse row count after scenario start:"
echo "  $(print_rows)"
echo
