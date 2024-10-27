# consumer_health_check.py
import sys
import json
import base64
from kafka import KafkaConsumer
from kubernetes import client, config

## Kafka broker and topic information
KAFKA_BROKER = "kafka.default.svc.cluster.local:9092"
KAFKA_TOPIC = "posts"
KAFKA_USERNAME = "user1"
SECRET_NAME = "kafka-user-passwords"
NAMESPACE = "default"

# Load Kubernetes in-cluster configuration
config.load_incluster_config()
v1 = client.CoreV1Api()

try:
    # Retrieve Kafka password from Kubernetes secret
    secret = v1.read_namespaced_secret(SECRET_NAME, NAMESPACE)
    kafka_password = base64.b64decode(secret.data["client-passwords"]).decode("utf-8").split(",")[0]

    # Set up Kafka consumer with SASL authentication
    consumer = KafkaConsumer(
        KAFKA_TOPIC,
        bootstrap_servers=[KAFKA_BROKER],
        security_protocol="SASL_PLAINTEXT",
        sasl_mechanism="SCRAM-SHA-256",
        sasl_plain_username=KAFKA_USERNAME,
        sasl_plain_password=kafka_password,
        value_deserializer=lambda v: json.loads(v.decode("utf-8")),
        auto_offset_reset="latest",
        enable_auto_commit=False,
        group_id="health-check-group"
    )

    # Poll the consumer briefly to check connectivity
    consumer.poll(timeout_ms=1000)
    print("Kafka is reachable, and consumer is connected successfully.")
    sys.exit(0)  # Exit with 0 if successful

except Exception as e:
    print(f"Health check failed: {e}", file=sys.stderr)
    sys.exit(1)  # Exit with 1 if there was an error
