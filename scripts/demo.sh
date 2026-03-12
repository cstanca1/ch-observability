#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="scripts/scenarios"
KAFKA_CONSUMER_GROUP="clickhouse_consumer"

show_menu() {
echo
echo "=================================================="
echo " ClickHouse Observability Demo Controller"
echo "=================================================="
echo
echo "Scenarios"
echo
echo "1) Baseline Observability"
echo "2) Latency Spike"
echo "3) Authentication Failure"
echo "4) Cascading Failure"
echo "5) Recovery"
echo "6) Rollup Analytics"
echo "7) Full Pipeline Demo"
echo "8) Replay Kafka -> Reload ClickHouse"
echo
echo "Operations"
echo
echo "p) Purge demo data"
echo "s) Show pipeline status"
echo "q) Quit"
echo
}

is_running() {
  docker compose ps --status running --services | grep -qx "$1"
}

service_status() {
  local service="$1"
  if is_running "$service"; then
    echo "running"
  else
    echo "stopped"
  fi
}

get_total_lag() {
  docker compose exec -T kafka kafka-consumer-groups \
    --bootstrap-server kafka:9092 \
    --group "$KAFKA_CONSUMER_GROUP" \
    --describe 2>/dev/null | awk '
      NR > 1 && $1 != "" && $1 != "TOPIC" {
        lag = $6
        if (lag ~ /^[0-9]+$/) sum += lag
      }
      END { print sum + 0 }
    '
}

get_log_rows() {
  docker compose exec -T clickhouse clickhouse-client \
    --query "SELECT count() FROM logs" 2>/dev/null || echo "unknown"
}

print_pipeline_status() {
  local kafka_state
  local clickhouse_state
  local grafana_state
  local generator_state
  local lag
  local rows

  kafka_state="$(service_status kafka)"
  clickhouse_state="$(service_status clickhouse)"
  grafana_state="$(service_status grafana)"
  generator_state="$(service_status generator)"

  if [[ "$kafka_state" == "running" ]]; then
    lag="$(get_total_lag 2>/dev/null || echo "unknown")"
  else
    lag="unknown"
  fi

  if [[ "$clickhouse_state" == "running" ]]; then
    rows="$(get_log_rows 2>/dev/null || echo "unknown")"
  else
    rows="unknown"
  fi

  echo
  echo "--------------------------------------------------"
  echo " Pipeline Status"
  echo "--------------------------------------------------"
  printf "%-18s %s\n" "kafka" "$kafka_state"
  printf "%-18s %s\n" "clickhouse" "$clickhouse_state"
  printf "%-18s %s\n" "grafana" "$grafana_state"
  printf "%-18s %s\n" "generator" "$generator_state"
  printf "%-18s %s\n" "consumer lag" "$lag"
  printf "%-18s %s\n" "clickhouse rows" "$rows"
  echo "--------------------------------------------------"
  echo
}

run_scenario() {
  local script="$1"

  if [[ ! -f "$script" ]]; then
    echo
    echo "Scenario script not found:"
    echo "  $script"
    echo
    return
  fi

  bash "$script"
  print_pipeline_status
}

while true
do
  show_menu
  read -rp "Enter choice: " choice

  case "$choice" in
    1)
      run_scenario "$SCENARIO_DIR/01_baseline.sh"
      ;;
    2)
      run_scenario "$SCENARIO_DIR/02_latency_spike.sh"
      ;;
    3)
      run_scenario "$SCENARIO_DIR/03_auth_failure.sh"
      ;;
    4)
      run_scenario "$SCENARIO_DIR/04_cascading_failure.sh"
      ;;
    5)
      run_scenario "$SCENARIO_DIR/05_recovery.sh"
      ;;
    6)
      run_scenario "$SCENARIO_DIR/06_rollup_analytics.sh"
      ;;
    7)
      run_scenario "$SCENARIO_DIR/07_full_pipeline.sh"
      ;;
    8)
      run_scenario "$SCENARIO_DIR/08_replay_from_kafka.sh"
      ;;
    p|P)
      ./scripts/purge_demo_data.sh
      print_pipeline_status
      ;;
    s|S)
      print_pipeline_status
      ;;
    q|Q)
      echo
      echo "Exiting demo controller."
      echo
      exit 0
      ;;
    *)
      echo
      echo "Invalid option."
      echo
      ;;
  esac
done
