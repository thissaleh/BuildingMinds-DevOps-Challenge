import os
import sys
import json
import base64
from datetime import datetime
from kafka import KafkaProducer
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
v1 = client.CoreV1Api()

# Retrieve the Kafka username and password from Kubernetes secrets
try:
    print(f"Attempting to retrieve Kafka username from secret: {USERNAME_SECRET_NAME} in namespace: {NAMESPACE}")
    username_secret = v1.read_namespaced_secret(USERNAME_SECRET_NAME, NAMESPACE)
    kafka_username = base64.b64decode(username_secret.data["username"]).decode("utf-8")

    print(f"Attempting to retrieve Kafka password from secret: {PASSWORD_SECRET_NAME} in namespace: {NAMESPACE}")
    password_secret = v1.read_namespaced_secret(PASSWORD_SECRET_NAME, NAMESPACE)
    kafka_password = base64.b64decode(password_secret.data["client-passwords"]).decode("utf-8").split(",")[0]

except Exception as e:
    print(f"Error retrieving Kafka credentials from secrets: {e}")
    sys.exit(1)

# Set up the Kafka producer with the retrieved username and password
try:
    print("Attempting to create KafkaProducer with SASL authentication.")
    producer = KafkaProducer(
        bootstrap_servers=[KAFKA_BROKER],
        security_protocol="SASL_PLAINTEXT",
        sasl_mechanism="SCRAM-SHA-256",
        sasl_plain_username=kafka_username,
        sasl_plain_password=kafka_password,
        value_serializer=lambda v: json.dumps(v).encode("utf-8")
    )
    print("KafkaProducer successfully created.")
except Exception as e:
    print(f"Error setting up Kafka producer: {e}")
    sys.exit(1)

# Test message to confirm connection
for i in range(5):
    try:
        message = {"sender": "buildingminds", "content": "test message", "created_at": datetime.now().isoformat()}
        print(f"Sending test message to topic '{KAFKA_TOPIC}': {message}")
        producer.send(KAFKA_TOPIC, message)
        producer.flush()  # Ensures message is sent before checking
        print(f"Test message sent successfully to topic {KAFKA_TOPIC}")
    except Exception as e:
        print(f"Error sending test message: {e}")
