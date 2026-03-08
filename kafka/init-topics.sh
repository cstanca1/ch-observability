#!/bin/bash
set -e

echo "Waiting for Kafka..."

cub kafka-ready -b kafka:9092 1 40

kafka-topics \
  --create \
  --if-not-exists \
  --topic app_logs \
  --bootstrap-server kafka:9092 \
  --partitions 3 \
  --replication-factor 1

echo "Kafka topic app_logs created"