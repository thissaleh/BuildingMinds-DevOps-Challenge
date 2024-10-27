import os
from kafka import KafkaProducer
from datetime import datetime
import json
import base64
from kubernetes import client, config
import time

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


# Retrieve and decode the Kafka credentials from the Kubernetes secret
kafka_username = "user1" #base64.b64decode(secret.data["username"]).decode("utf-8")
#kafka_password = "oiJBw48Kwt" #base64.b64decode(secret.data["password"]).decode("utf-8")

# Kafka broker and topic from environment variables
kafka_broker = "kafka.default.svc.cluster.local:9092" #os.environ.get("KAFKA_BROKER_URL", "kafka.default.svc.cluster.local:9092")
kafka_topic = "posts" #os.environ.get("KAFKA_TOPIC", "posts")

# Set the authentication credentials
producer = KafkaProducer(
    bootstrap_servers=["kafka.default.svc.cluster.local:9092"],
    security_protocol="SASL_PLAINTEXT",  # or SASL_SSL depending on your configuration
    sasl_mechanism="SCRAM-SHA-256",
     sasl_plain_username=kafka_username,
    sasl_plain_password=kafka_password,
    value_serializer=lambda v: json.dumps(v).encode("utf-8")
)

for i in range(5):
    # Send a test message to confirm connection and authentication
    try:
        producer.send(
            kafka_topic, 
            {"sender": "buildingminds", "content": "test message", "created_at": datetime.now().isoformat()}
        )
        producer.flush()  # Ensures message is sent before checking
        print(f"Test message sent successfully to topic {kafka_topic}")
    except Exception as e:
        print(f"Error sending test message: {e}")

while True:
    time.sleep(30)  # Keeps the container alive, adjust the interval as needed