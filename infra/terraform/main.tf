provider "kubernetes" {
  config_path = "~/.kube/config"
}


# Namespace for Kafka
# resource "kubernetes_namespace" "kafka_ns" {
#   metadata {
#     name = "kafka"
#   }
# }


variable "registry_server" {
  type        = string
  description = "Docker registry server URL"
  default     = "https://index.docker.io/v1/"
}

variable "registry_username" {
  type        = string
  description = "Docker registry username"
  default     = "thissaleh"
}

variable "registry_password" {
  type        = string
  description = "Docker registry password"
  sensitive   = true
  default     = "dckr_pat_UE69JhCUs8O8lllAeg6ELdMnHws"
}

variable "registry_email" {
  type        = string
  description = "Docker registry email"
  default     = "thissaleh@gmail.com"
}



# Kafka credentials secret
# resource "kubernetes_secret" "kafka_secrets" {
#   metadata {
#     name      = "kafka-credentials"
#     #namespace = kubernetes_namespace.kafka_ns.metadata[0].name
#   }

#   data = {
#     KAFKA_USERNAME = base64encode("user1")
#     KAFKA_PASSWORD = base64encode("3dIy37mZ46")
#   }
#   type = "Opaque"  # Use Opaque for non-basic-auth secrets
# }

# Docker Hub registry secret for pulling images
resource "kubernetes_secret" "dockerhub_secret" {
  metadata {
    name      = "my-dockerhub-secret"
    #namespace = kubernetes_namespace.kafka_ns.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${var.registry_server}" = {
          "username" = var.registry_username
          "password" = var.registry_password
          "email"    = var.registry_email
          "auth"     = base64encode("${var.registry_username}:${var.registry_password}")
        }
      }
    })
  }
}


# resource "kubernetes_config_map" "kafka_config" {
#   metadata {
#     name      = "kafka-config"
#     #namespace = kubernetes_namespace.kafka_ns.metadata[0].name
#   }

#   data = {
#     KAFKA_BROKER_URL = "my-kafka.default.svc.cluster.local:9092"
#     KAFKA_TOPIC      = "posts"
#   }
# }

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}


# resource "helm_release" "zookeeper" {
#   name       = "zookeeper"
#   repository = "oci://registry-1.docker.io/bitnamicharts"
#   chart      = "zookeeper"
#   #namespace  = kubernetes_namespace.kafka_ns.metadata[0].name
#   values = [file("${path.module}/../../zookeeper/zookeeper-values.yaml")]
#   timeout   = 600  # Set to 10 minutes or more

#  }
 
resource "kubernetes_pod" "kafka_client" {
  metadata {
    name      = "kafka-client"
    namespace = "default"
    labels = {
      app = "kafka-client"
    }
  }

  spec {
    restart_policy = "Never"

    container {
      name  = "kafka-client"
      image = "docker.io/bitnami/kafka:3.8.0-debian-12-r5"

      command = ["sleep", "infinity"]

      resources {
        limits = {
          memory = "512Mi"
          cpu    = "500m"
        }
      }
    }
  }
}

resource "helm_release" "kafka" {
  name       = "kafka"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "kafka"
  #namespace  = kubernetes_namespace.kafka_ns.metadata[0].name
  values = [file("${path.module}/../../kafka/kafka-values.yaml")]
  timeout   = 600  # Set to 10 minutes or more
#   set {
#     name  = "auth.clientProtocol"
#     value = "sasl_plaintext"
#   }

#   # Additional Kafka configurations can go here
 }

resource "helm_release" "kafka_producer" {
  name       = "kafka-producer"
  #namespace  = kubernetes_namespace.kafka_ns.metadata[0].name
  chart      = "${path.module}/../../producer/helm"
  values = [file("${path.module}/../../producer/helm/values.yaml")]
  force_update = true
  timeout   = 600 

}

resource "helm_release" "kafka_consumer" {
  name       = "kafka-consumer"
  #namespace  = kubernetes_namespace.kafka_ns.metadata[0].name
  chart      = "${path.module}/../../consumer/helm"
  values = [file("${path.module}/../../consumer/helm/values.yaml")]
  force_update = true
  timeout   = 600  
}



# resource "kubernetes_horizontal_pod_autoscaler" "kafka_producer_hpa" {
#   metadata {
#     name      = "kafka-producer-hpa"
#     namespace = "default"  # Adjust if using a specific namespace
#   }

#   spec {
#     max_replicas = 5
#     min_replicas = 1
#     scale_target_ref {
#       kind = "Deployment"
#       name = "kafka-producer"  # Adjust according to the producer deployment name
#       api_version = "apps/v1"
#     }
#     # Set to use CPU or memory metrics
#     metric {
#       type = "Resource"
#       resource {
#         name = "cpu"
#         target {
#           type = "Utilization"
#           average_utilization = 70
#         }
#       }
#     }
#   }
# }

# resource "kubernetes_horizontal_pod_autoscaler" "kafka_consumer_hpa" {
#   metadata {
#     name      = "kafka-consumer-hpa"
#     namespace = "default"  # Adjust if using a specific namespace
#   }

#   spec {
#     max_replicas = 5
#     min_replicas = 1
#     scale_target_ref {
#       kind = "Deployment"
#       name = "kafka-consumer"  # Adjust according to the consumer deployment name
#       api_version = "apps/v1"
#     }
#     # Configure scaling based on memory metrics
#     metric {
#       type = "Resource"
#       resource {
#         name = "memory"
#         target {
#           type = "Utilization"
#           average_utilization = 80
#         }
#       }
#     }
#   }
# }


# Namespace for monitoring
# resource "kubernetes_namespace" "monitoring" {
#   metadata {
#     name = "monitoring"
#   }
# }

# Deploy Prometheus using Helm chart
# resource "helm_release" "prometheus" {
#   name       = "prometheus"
#   repository = "oci://registry-1.docker.io/bitnamicharts"
#   chart      = "prometheus"
#   #namespace  = kubernetes_namespace.monitoring.metadata[0].name
#   values     = [file("${path.module}/../../monitoring/prometheus/prometheus-values.yaml")]
#   timeout   = 1200  # Set to 10 minutes or more
# }

# Deploy Grafana using Helm chart
# resource "helm_release" "grafana" {
#   name       = "grafana"
#   repository = "oci://registry-1.docker.io/bitnamicharts"
#   chart      = "grafana"
#   #namespace  = kubernetes_namespace.monitoring.metadata[0].name
#   values     = [file("${path.module}/../../monitoring/grafana/grafana-values.yaml")]
#   timeout   = 600  # Set to 10 minutes or more
# }




resource "kubernetes_role" "kafka_secret_reader" {
  metadata {
    name      = "kafka-secret-reader-terraform"
    namespace = "default"
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get"]
  }
}

resource "kubernetes_role_binding" "kafka_secret_reader_binding" {
  metadata {
    name      = "kafka-secret-reader-binding-terraform"
    namespace = "default"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "kafka-secret-reader-terraform"  # Directly refer to the role's name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "default"
  }
}















# resource "kubernetes_job" "kafka_user_creation" {
#   metadata {
#     name      = "kafka-user-creation"
#     namespace = kubernetes_namespace.kafka_ns.metadata[0].name
#   }
#   spec {
#     template {
#       metadata {
#         name = "kafka-user-creation"
#       }
#       spec {
#         container {
#           name  = "kafka-admin"
#           image = "confluentinc/cp-kafka:latest"
#           command = ["sh"]
#           args    = ["-c", "sleep infinity"]  # Keep the Pod running without executing commands

#             #"-c",
#             #"kafka-configs --bootstrap-server my-kafka.default.svc.cluster.local:9092 --alter --add-config 'SCRAM-SHA-256=[password=my-secure-password]' --entity-type users --entity-name my-producer"          ]
#         }
#         restart_policy = "OnFailure"
#       }
#     }
#   }
# }

# resource "kubernetes_secret" "kafka_credentials" {
#   metadata {
#     name      = "kafka-credentials"
#     namespace = kubernetes_namespace.kafka_ns.metadata[0].name
#   }
#   data = {
#     KAFKA_USERNAME = base64encode("my-producer")
#     KAFKA_PASSWORD = base64encode("my-secure-password")
#   }

#   lifecycle {
#     ignore_changes = all
#   }
# }
