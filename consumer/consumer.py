import os
import sys
import json
import base64
from kafka import KafkaConsumer
from kubernetes import client, config

# Kafka broker and topic information from environment variables
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "posts")
KAFKA_BROKER = os.getenv("KAFKA_BROKER", "kafka.default.svc.cluster.local:9092")

# Kubernetes secret names and namespace
USERNAME_SECRET_NAME = os.getenv("USER_SECRET_NAME", "kafka-username")  
PASSWORD_SECRET_NAME = os.getenv("PWD_SECRET_NAME", "kafka-user-passwords") 
NAMESPACE = os.getenv("NAMESPACE", "default")

# Load Kubernetes in-cluster configuration
config.load_incluster_config()

# Initialize Kubernetes client
v1 = client.CoreV1Api()

try:
    # Retrieve Kafka username from custom Kubernetes secret
    username_secret = v1.read_namespaced_secret(USERNAME_SECRET_NAME, NAMESPACE)
    kafka_username = base64.b64decode(username_secret.data["username"]).decode("utf-8")

    # Retrieve Kafka password from Kubernetes secret
    password_secret = v1.read_namespaced_secret(PASSWORD_SECRET_NAME, NAMESPACE)
    kafka_password = base64.b64decode(password_secret.data["client-passwords"]).decode("utf-8").split(",")[0]

except Exception as e:
    print(f"Error retrieving Kafka credentials: {e}")
    sys.exit(1)

# Set up the Kafka consumer
consumer = KafkaConsumer(
    KAFKA_TOPIC,
    bootstrap_servers=[KAFKA_BROKER],
    security_protocol="SASL_PLAINTEXT",
    sasl_mechanism="SCRAM-SHA-256",
    sasl_plain_username=kafka_username,
    sasl_plain_password=kafka_password,
    value_deserializer=lambda v: json.loads(v.decode("utf-8")),
    auto_offset_reset="earliest",
    enable_auto_commit=True,
    group_id="consumer-group-1"
)

print(f"Listening for messages on topic '{KAFKA_TOPIC}'...")

# Consume messages and print them
for message in consumer:
    print(f"Received message: {message.value}")
