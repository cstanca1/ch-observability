#!/bin/bash
set -e

sleep 15

kafka-topics \
  --create \
  --if-not-exists \
  --topic app_logs \
  --bootstrap-server kafka:9092 \
  --partitions 3 \
  --replication-factor 1

echo "Kafka topic app_logs created"