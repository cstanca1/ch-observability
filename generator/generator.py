import json
import random
import time
from kafka import KafkaProducer
from datetime import datetime

services = ["auth", "checkout", "catalog", "payment"]

producer = KafkaProducer(
bootstrap_servers="kafka:9092",
value_serializer=lambda v: json.dumps(v).encode("utf-8"),
)

while True:
event = {
"ts": datetime.utcnow().isoformat(),
"service": random.choice(services),
"level": random.choice(["INFO","WARN","ERROR"]),
"latency_ms": random.random()*1000,
"message": "demo event"
}

```
producer.send("app_logs", event)
time.sleep(0.01)
```

