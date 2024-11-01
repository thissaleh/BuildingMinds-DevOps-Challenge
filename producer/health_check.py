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

try:
    # Retrieve Kafka username from Kubernetes secret
    username_secret = v1.read_namespaced_secret(USERNAME_SECRET_NAME, NAMESPACE)
    kafka_username = base64.b64decode(username_secret.data["username"]).decode("utf-8")

    # Retrieve Kafka password from Kubernetes secret
    password_secret = v1.read_namespaced_secret(PASSWORD_SECRET_NAME, NAMESPACE)
    kafka_password = base64.b64decode(password_secret.data["client-passwords"]).decode("utf-8").split(",")[0]

    # Set up Kafka producer with SASL authentication
    producer = KafkaProducer(
        bootstrap_servers=[KAFKA_BROKER],
        security_protocol="SASL_PLAINTEXT",
        sasl_mechanism="SCRAM-SHA-256",
        sasl_plain_username=kafka_username,
        sasl_plain_password=kafka_password,
        value_serializer=lambda v: json.dumps(v).encode("utf-8")
    )

    # Send a test message to verify functionality
    test_message = {"sender": "health_check", "content": "health test", "timestamp": datetime.now().isoformat()}
    producer.send(KAFKA_TOPIC, test_message)
    producer.flush()  # Ensures the message is sent

    print("Kafka is reachable, and message was sent successfully.")
    sys.exit(0)  # Exit with 0 if successful

except Exception as e:
    print(f"Health check failed: {e}", file=sys.stderr)
    sys.exit(1)  # Exit with 1 if there was an error
