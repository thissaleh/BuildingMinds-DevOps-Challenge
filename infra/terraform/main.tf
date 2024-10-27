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












