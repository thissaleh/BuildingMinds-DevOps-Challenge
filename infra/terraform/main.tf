provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

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

# Docker Hub registry secret for pulling images
resource "kubernetes_secret" "dockerhub_secret" {
  metadata {
    name      = "my-dockerhub-secret"
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
  values = [file("${path.module}/../../kafka/kafka-values.yaml")]
  timeout   = 600 

 }

resource "helm_release" "kafka_producer" {
  name       = "kafka-producer"
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

resource "kubernetes_role" "kafka_secret_role" {
  metadata {
    name      = "kafka-secret-role"
    namespace = "default"
  }
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get"]
  }
}

resource "kubernetes_role_binding" "kafka_secret_role_binding" {
  metadata {
    name      = "kafka-secret-role-binding"
    namespace = "default"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "kafka-secret-role" 
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "default"
  }
}

# resource "kubernetes_manifest" "kafka_jmx_service_monitor" {
#   manifest = {
#     "apiVersion" = "monitoring.coreos.com/v1"
#     "kind"       = "ServiceMonitor"
#     "metadata" = {
#       "name"      = "kafka-jmx"
#       "namespace" = "default"
#     }
#     "spec" = {
#       "selector" = {
#         "matchLabels" = {
#           "app.kubernetes.io/name" = "kafka"
#         }
#       }
#       "endpoints" = [
#         {
#           "port"     = "metrics"
#           "path"     = "/metrics"
#           "interval" = "15s"
#         }
#       ]
#     }
#   }
# }

# resource "kubernetes_service" "kafka_jmx_metrics" {
#   metadata {
#     name      = "kafka-jmx-metrics"
#     namespace = "default"  # Ensure this matches your Kafka namespace
#     labels = {
#       "app.kubernetes.io/name" = "kafka"
#     }
#   }
#   spec {
#     selector = {
#       "app.kubernetes.io/name" = "kafka"
#     }
#     port {
#       name        = "metrics"
#       port        = 5556
#       target_port = 5556
#     }
#   }
# }


# # Add the Prometheus Helm chart repository
# resource "helm_repository" "prometheus_repo" {
#   name = "prometheus-community"
#   url  = "https://prometheus-community.github.io/helm-charts"
# }

# # Prometheus Helm release
# resource "helm_release" "prometheus" {
#   name       = "prometheus"
#   repository = helm_repository.prometheus_repo.url
#   chart      = "prometheus"
#   namespace  = "default"
#   values     = [file("${path.module}/../../monitoring/prometheus/prometheus-values.yaml")]
#   timeout   = 1200  
#   depends_on = [helm_repository.prometheus_repo]
# }

# # Add the Grafana Helm chart repository
# resource "helm_repository" "grafana_repo" {
#   name = "grafana"
#   url  = "https://grafana.github.io/helm-charts"
# }

# # Grafana Helm release
# resource "helm_release" "grafana" {
#   name       = "grafana"
#   repository = helm_repository.grafana_repo.url
#   chart      = "grafana"
#   namespace  = "default"
#   depends_on = [helm_repository.grafana_repo]
#   timeout   = 1200  

# }

# # Deploy Prometheus using Helm chart
# resource "helm_release" "prometheus" {
#   name       = "prometheus"
#   repository = "oci://registry-1.docker.io/bitnamicharts"
#   chart      = "prometheus"
#   values     = [file("${path.module}/../../monitoring/prometheus/prometheus-values.yaml")]
#   timeout   = 1200  
# }

# # Deploy Grafana using Helm chart
# resource "helm_release" "grafana" {
#   name       = "grafana"
#   repository = "oci://registry-1.docker.io/bitnamicharts"
#   chart      = "grafana"
#   values     = [file("${path.module}/../../monitoring/grafana/grafana-values.yaml")]
#   timeout   = 600  
# }









