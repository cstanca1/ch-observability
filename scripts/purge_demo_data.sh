#!/usr/bin/env bash
set -euo pipefail

TOPIC="app_logs"
CLICKHOUSE_SERVICE="clickhouse"
KAFKA_SERVICE="kafka"
GENERATOR_SERVICE="generator"
CONSUMER_GROUP="clickhouse_consumer"

echo
echo "=================================================="
echo " Purge Demo Data (ClickHouse Only)"
echo "=================================================="
echo
echo "Meaning:"
echo "  - Purge ClickHouse demo data only"
echo "  - Kafka retained messages are NOT deleted"
echo "  - Purge is allowed only when ClickHouse consumer lag is zero"
echo

echo "Stopping generator so no new messages are produced during purge..."
docker compose stop "${GENERATOR_SERVICE}" >/dev/null
echo "Generator stopped."
echo

echo "Checking Kafka consumer lag for ClickHouse group '${CONSUMER_GROUP}'..."
echo

LAG_OUTPUT="$(docker compose exec -T "${KAFKA_SERVICE}" kafka-consumer-groups \
  --bootstrap-server kafka:9092 \
  --group "${CONSUMER_GROUP}" \
  --describe 2>/dev/null || true)"

if [[ -z "${LAG_OUTPUT}" ]]; then
  echo "Could not read Kafka consumer group '${CONSUMER_GROUP}'."
  echo "Refusing to purge for safety."
  echo
  exit 1
fi

echo "${LAG_OUTPUT}"
echo

TOTAL_LAG="$(echo "${LAG_OUTPUT}" | awk '
  NR > 1 && $1 != "" && $1 != "TOPIC" {
    lag = $6
    if (lag ~ /^[0-9]+$/) sum += lag
  }
  END { print sum + 0 }
')"

echo "Total ClickHouse consumer lag: ${TOTAL_LAG}"
echo

if [[ "${TOTAL_LAG}" -gt 0 ]]; then
  echo "ClickHouse is NOT fully caught up with Kafka."
  echo "Kafka still has messages that ClickHouse has not consumed."
  echo "For safety, ClickHouse data will NOT be purged."
  echo
  echo "Wait for consumer lag to reach zero, then run purge again."
  echo
  exit 1
fi

echo "ClickHouse IS fully caught up with Kafka."
echo "Kafka may still retain messages, but consumer lag is zero."
echo "Purging ClickHouse demo tables only..."
echo

docker compose exec -T "${CLICKHOUSE_SERVICE}" clickhouse-client \
  --query "TRUNCATE TABLE logs;"

docker compose exec -T "${CLICKHOUSE_SERVICE}" clickhouse-client \
  --query "TRUNCATE TABLE latency_rollup_1m;"

echo
echo "ClickHouse demo tables purged:"
echo "  - logs"
echo "  - latency_rollup_1m"
echo
echo "Kafka retained messages were NOT deleted."
echo
echo "You can now either:"
echo "  - restart generator for a fresh scenario"
echo "      docker compose up -d --build generator"
echo
echo "  - or run scenario 8 to replay retained Kafka messages into ClickHouse"
echo
