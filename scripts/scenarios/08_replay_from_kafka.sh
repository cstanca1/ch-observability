#!/usr/bin/env bash
set -euo pipefail

TOPIC="app_logs"
CONSUMER_GROUP="clickhouse_consumer"

KAFKA_SERVICE="kafka"
CLICKHOUSE_SERVICE="clickhouse"
GENERATOR_SERVICE="generator"

is_running() {
  docker compose ps --status running --services | grep -qx "$1"
}

clickhouse_query_retry() {
  local query="$1"
  local attempts=30
  local delay=2

  for ((i=1;i<=attempts;i++)); do
    if docker compose exec -T "$CLICKHOUSE_SERVICE" clickhouse-client --query "$query" >/dev/null 2>&1; then
      return 0
    fi
    echo "ClickHouse not ready (attempt $i/$attempts)..."
    sleep "$delay"
  done

  echo "ClickHouse never became ready for query:"
  echo "  $query"
  return 1
}

wait_for_clickhouse() {
  echo "Waiting for ClickHouse to become ready..."
  clickhouse_query_retry "SELECT 1"
  echo "ClickHouse ready."
}

wait_for_consumer_group_inactive() {
  echo "Waiting for Kafka consumer group '$CONSUMER_GROUP' to become inactive..."
  echo "Kafka may keep the consumer session alive briefly after ClickHouse stops."

  for ((i=1;i<=60;i++)); do

    STATE_OUTPUT="$(docker compose exec -T "$KAFKA_SERVICE" kafka-consumer-groups \
      --bootstrap-server kafka:9092 \
      --group "$CONSUMER_GROUP" \
      --describe --state 2>/dev/null || true)"

    echo "$STATE_OUTPUT"
    echo

    echo "$STATE_OUTPUT" | grep -Eq 'State:[[:space:]]+(Empty|Dead)' && {
      echo "Consumer group is inactive."
      return 0
    }

    sleep 3
  done

  echo "Consumer group did not become inactive in time."
  echo "Kafka still thinks ClickHouse is a member."
  echo "Wait ~1 minute and run scenario 8 again."
  return 1
}

get_total_lag() {
  docker compose exec -T "$KAFKA_SERVICE" kafka-consumer-groups \
    --bootstrap-server kafka:9092 \
    --group "$CONSUMER_GROUP" \
    --describe 2>/dev/null | awk '
      NR > 1 && $1 != "" && $1 != "TOPIC" {
        lag = $6
        if (lag ~ /^[0-9]+$/) sum += lag
      }
      END { print sum + 0 }
    '
}

monitor_replay_progress() {
  echo
  echo "Monitoring replay progress..."
  echo

  while true; do
    ROWS="$(docker compose exec -T "$CLICKHOUSE_SERVICE" clickhouse-client \
      --query "SELECT count() FROM logs" 2>/dev/null || echo "0")"

    LAG="$(get_total_lag 2>/dev/null || echo "0")"

    printf "Rows in ClickHouse: %-12s | Consumer lag: %s\n" "$ROWS" "$LAG"

    if [[ "$LAG" == "0" ]]; then
      echo
      echo "Replay complete. Consumer lag is zero."
      break
    fi

    sleep 2
  done
}

echo
echo "=================================================="
echo " Scenario 8: Replay Kafka -> Reload ClickHouse"
echo "=================================================="
echo

echo "Safety and robustness features of this scenario:"
echo
echo "  - Handles ClickHouse readiness with retries"
echo "      Ensures ClickHouse is accepting queries before executing operations."
echo
echo "  - Waits long enough for Kafka consumer group to become inactive"
echo "      Kafka may keep a consumer session alive briefly after ClickHouse stops."
echo "      The script waits until the consumer group state becomes Empty or Dead."
echo
echo "  - Truncates ClickHouse tables before replay"
echo "      Ensures replay starts from a clean ClickHouse state."
echo
echo "  - Gracefully handles connection errors"
echo "      ClickHouse queries are retried automatically if the service is not yet ready."
echo
echo "  - Includes replay documentation"
echo "      The script prints the replay sequence so operators understand each step."
echo
echo "  - Includes live progress monitoring"
echo "      Displays ClickHouse row count and Kafka consumer lag until replay completes."
echo

echo "Replay sequence:"
echo "  1. Stop generator"
echo "  2. Verify ClickHouse consumer lag is zero"
echo "  3. Truncate ClickHouse tables"
echo "  4. Stop ClickHouse to release Kafka consumer"
echo "  5. Wait for consumer group to become inactive"
echo "  6. Reset Kafka offsets to earliest"
echo "  7. Start ClickHouse"
echo "  8. ClickHouse reconsumes retained Kafka messages"
echo "  9. Monitor replay until lag returns to zero"
echo
echo "Important:"
echo "  - Kafka retained messages are NOT deleted"
echo "  - Only ClickHouse data is purged"
echo "  - Replay works because Kafka retention is independent of consumption"
echo

read -p "Replay retained Kafka messages into ClickHouse? [y/N] " CONFIRM
[[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && { echo "Replay cancelled."; exit 0; }

echo

GENERATOR_WAS_RUNNING=false
CLICKHOUSE_WAS_RUNNING=false

if is_running "$GENERATOR_SERVICE"; then
  GENERATOR_WAS_RUNNING=true
fi

if is_running "$CLICKHOUSE_SERVICE"; then
  CLICKHOUSE_WAS_RUNNING=true
fi

echo "Generator running : $GENERATOR_WAS_RUNNING"
echo "ClickHouse running: $CLICKHOUSE_WAS_RUNNING"
echo

if $GENERATOR_WAS_RUNNING; then
  echo "Stopping generator..."
  docker compose stop "$GENERATOR_SERVICE" >/dev/null
  echo "Generator stopped."
  echo
fi

if ! $CLICKHOUSE_WAS_RUNNING; then
  echo "Starting ClickHouse so tables can be truncated..."
  docker compose start "$CLICKHOUSE_SERVICE" >/dev/null
  wait_for_clickhouse
  echo
fi

echo "Checking ClickHouse consumer lag..."

LAG="$(get_total_lag)"

echo "Total consumer lag: $LAG"
echo

if [[ "$LAG" -gt 0 ]]; then
  echo "ClickHouse is not fully caught up with Kafka."
  echo "Replay requires consumer lag = 0."
  exit 1
fi

echo "ClickHouse caught up with Kafka."
echo

echo "Truncating ClickHouse tables..."
clickhouse_query_retry "TRUNCATE TABLE logs;"
clickhouse_query_retry "TRUNCATE TABLE latency_rollup_1m;"
echo "Tables truncated."
echo

echo "Stopping ClickHouse to release Kafka consumer..."
docker compose stop "$CLICKHOUSE_SERVICE" >/dev/null
echo "ClickHouse stopped."
sleep 10
echo

wait_for_consumer_group_inactive

echo "Resetting Kafka offsets to earliest..."

docker compose exec -T "$KAFKA_SERVICE" kafka-consumer-groups \
  --bootstrap-server kafka:9092 \
  --group "$CONSUMER_GROUP" \
  --topic "$TOPIC" \
  --reset-offsets \
  --to-earliest \
  --execute

echo "Offsets reset."
echo

echo "Starting ClickHouse to begin replay..."
docker compose start "$CLICKHOUSE_SERVICE" >/dev/null

wait_for_clickhouse

echo
echo "Replay initiated."
echo

monitor_replay_progress

echo
echo "Generator remains stopped."
echo "Restart when ready:"
echo "  docker compose up -d --build generator"
echo
