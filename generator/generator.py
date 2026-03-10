import json
import os
import random
import time
from datetime import datetime

from kafka import KafkaProducer
from kafka.errors import NoBrokersAvailable

SERVICES = ["auth", "checkout", "catalog", "payment"]
INCIDENT_MODE = os.getenv("INCIDENT_MODE", "normal").strip().lower()
LOG_INTERVAL_SECONDS = float(os.getenv("LOG_INTERVAL_SECONDS", "0.5"))

SERVICE_PROFILES = {
    "auth": {
        "base_latency_ms": 80,
        "error_rate": 0.01,
        "messages": ["login success", "token refresh", "session validated"],
        "depends_on": [],
    },
    "checkout": {
        "base_latency_ms": 220,
        "error_rate": 0.02,
        "messages": ["cart priced", "checkout completed", "order submitted"],
        "depends_on": ["auth", "catalog"],
    },
    "catalog": {
        "base_latency_ms": 60,
        "error_rate": 0.005,
        "messages": ["search executed", "product page viewed", "inventory checked"],
        "depends_on": [],
    },
    "payment": {
        "base_latency_ms": 140,
        "error_rate": 0.015,
        "messages": ["payment authorized", "payment captured", "fraud check passed"],
        "depends_on": ["auth", "checkout"],
    },
}


def create_producer() -> KafkaProducer:
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


def choose_service() -> str:
    if INCIDENT_MODE == "latency_spike":
        return random.choices(
            population=SERVICES,
            weights=[2, 5, 2, 2],
            k=1,
        )[0]

    if INCIDENT_MODE == "auth_failure":
        return random.choices(
            population=SERVICES,
            weights=[5, 2, 2, 2],
            k=1,
        )[0]

    if INCIDENT_MODE == "cascading_failure":
        return random.choices(
            population=SERVICES,
            weights=[5, 4, 2, 4],
            k=1,
        )[0]

    return random.choice(SERVICES)


def cascade_impact(service: str):
    """
    Simulate dependency-driven degradation:
    auth is primary failure source
    checkout depends on auth
    payment depends on auth + checkout
    """
    added_latency = 0.0
    added_error_rate = 0.0
    message_suffix = ""
    dependency_status = "healthy"

    if INCIDENT_MODE != "cascading_failure":
        return added_latency, added_error_rate, message_suffix, dependency_status

    if service == "auth":
        added_latency = random.gauss(350, 90)
        added_error_rate = 0.30
        message_suffix = " - identity provider unstable"
        dependency_status = "root_failure"

    elif service == "checkout":
        added_latency = random.gauss(900, 180)
        added_error_rate = 0.16
        message_suffix = " - auth dependency degraded"
        dependency_status = "degraded_by_auth"

    elif service == "payment":
        added_latency = random.gauss(1200, 260)
        added_error_rate = 0.22
        message_suffix = " - checkout/auth dependency degraded"
        dependency_status = "degraded_by_checkout_auth"

    elif service == "catalog":
        added_latency = random.gauss(40, 12)
        added_error_rate = 0.01
        message_suffix = " - indirect pressure"
        dependency_status = "minor_indirect_pressure"

    return added_latency, added_error_rate, message_suffix, dependency_status


def apply_incident_profile(service: str, base_latency_ms: float, base_error_rate: float):
    latency_ms = random.gauss(base_latency_ms, base_latency_ms * 0.15)
    error_rate = base_error_rate
    message_suffix = ""
    status_code = 200
    dependency_status = "healthy"

    if INCIDENT_MODE == "latency_spike" and service == "checkout":
        latency_ms = random.gauss(2200, 450)
        error_rate = 0.18
        message_suffix = " - upstream dependency slow"
        dependency_status = "degraded"

    elif INCIDENT_MODE == "auth_failure" and service == "auth":
        latency_ms = random.gauss(350, 80)
        error_rate = 0.35
        message_suffix = " - token validation failures"
        dependency_status = "degraded"

    elif INCIDENT_MODE == "recovery":
        latency_ms = random.gauss(base_latency_ms * 1.15, base_latency_ms * 0.12)
        error_rate = max(base_error_rate * 1.5, 0.01)
        message_suffix = " - recovering"
        dependency_status = "recovering"

    elif INCIDENT_MODE == "cascading_failure":
        extra_latency, extra_error_rate, cascade_suffix, cascade_status = cascade_impact(service)
        latency_ms += extra_latency
        error_rate += extra_error_rate
        message_suffix = cascade_suffix
        dependency_status = cascade_status

    is_error = random.random() < error_rate
    level = "ERROR" if is_error else random.choices(
        population=["INFO", "WARN"],
        weights=[9, 1],
        k=1,
    )[0]

    if is_error:
        if service == "auth":
            status_code = random.choice([401, 403, 429, 500, 503])
        elif service == "checkout":
            status_code = random.choice([500, 502, 503, 504])
        elif service == "payment":
            status_code = random.choice([500, 502, 503, 504])
        else:
            status_code = random.choice([500, 503])

    latency_ms = max(latency_ms, 5.0)
    return round(latency_ms, 2), level, status_code, message_suffix, dependency_status


def build_event() -> dict:
    service = choose_service()
    profile = SERVICE_PROFILES[service]

    latency_ms, level, status_code, message_suffix, dependency_status = apply_incident_profile(
        service=service,
        base_latency_ms=profile["base_latency_ms"],
        base_error_rate=profile["error_rate"],
    )

    message = random.choice(profile["messages"]) + message_suffix

    return {
        "ts": datetime.utcnow().isoformat(timespec="milliseconds"),
        "service": service,
        "level": level,
        "latency_ms": latency_ms,
        "message": message,
        "status_code": status_code,
        "incident_mode": INCIDENT_MODE,
        "dependency_status": dependency_status,
        "dependency_count": len(profile["depends_on"]),
        "depends_on": ",".join(profile["depends_on"]),
    }


def main():
    print(f"Starting generator with INCIDENT_MODE={INCIDENT_MODE}")
    producer = create_producer()

    while True:
        event = build_event()
        producer.send("app_logs", event)
        producer.flush()
        print(event)
        time.sleep(LOG_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()