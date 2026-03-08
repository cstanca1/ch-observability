import json
import random
import time
from datetime import datetime

from kafka import KafkaProducer
from kafka.errors import NoBrokersAvailable

services = ["auth", "checkout", "catalog", "payment"]


def create_producer():
    while True:
        try:
            producer = KafkaProducer(
                bootstrap_servers="kafka:9092",
                value_serializer=lambda v: json.dumps(v).encode("utf-8"),
            )
            print("Connected to Kafka")
            return producer
        except NoBrokersAvailable:
            print("Kafka not ready yet, retrying in 5 seconds...")
            time.sleep(5)


producer = create_producer()

while True:
    event = {
        "ts": datetime.utcnow().isoformat(timespec="milliseconds"),
        "service": random.choice(services),
        "level": random.choice(["INFO", "WARN", "ERROR"]),
        "latency_ms": random.random() * 1000,
        "message": "demo event",
    }

    producer.send("app_logs", event)
    producer.flush()
    print(event)
    time.sleep(0.5)