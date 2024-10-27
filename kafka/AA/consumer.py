import os
from kafka import KafkaConsumer
import json
import base64
from kubernetes import client, config

# Load Kubernetes configuration
config.load_incluster_config()

# Initialize Kubernetes client
v1 = client.CoreV1Api()

# Retrieve the Kafka username and password from the secret
secret_name = "kafka-user-passwords"
namespace = "default"

try:
    secret = v1.read_namespaced_secret(secret_name, namespace)
    kafka_password = base64.b64decode(secret.data["client-passwords"]).decode("utf-8").split(",")[0]
except Exception as e:
    print(f"Error retrieving Kafka credentials: {e}")
    exit(1)
# Consumer-specific Kafka credentials (use environment variables or direct values)
kafka_username = "user1"  # Example: separate username for consumer
#kafka_password = "oiJBw48Kwt"  # Example: separate password for consumer

# Kafka broker and topic for the consumer
kafka_broker = "kafka.default.svc.cluster.local:9092"  # Consumer-specific broker URL
kafka_topic = "posts"  # Consumer-specific topic

# Set up the Kafka consumer
consumer = KafkaConsumer(
    kafka_topic,
    bootstrap_servers=[kafka_broker],
    security_protocol="SASL_PLAINTEXT",  # or SASL_SSL depending on configuration
    sasl_mechanism="SCRAM-SHA-256",
    sasl_plain_username=kafka_username,
    sasl_plain_password=kafka_password,
    value_deserializer=lambda v: json.loads(v.decode("utf-8")),
    auto_offset_reset="earliest",
    enable_auto_commit=True,
    group_id="consumer-group-1"  # Unique group ID for consumer
)

print(f"Listening for messages on topic '{kafka_topic}'...")

# Consume messages and print them
for message in consumer:
    print(f"Received message: {message.value}")
