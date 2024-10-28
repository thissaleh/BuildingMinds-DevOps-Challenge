provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.16.1"
    }
  }
}

# Docker Hub registry secret 
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

# Kafka Client
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

# Kafka
resource "helm_release" "kafka" {
  name       = "kafka"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "kafka"
  values = [file("${path.module}/../../kafka/kafka-values.yaml")]
  timeout   = 600 

 }

# Kafka Producer
resource "helm_release" "kafka_producer" {
  name       = "kafka-producer"
  chart      = "${path.module}/../../producer/helm"
  values = [file("${path.module}/../../producer/helm/values.yaml")]
  force_update = true
  timeout   = 600 
}

# Kafka Consumer
resource "helm_release" "kafka_consumer" {
  name       = "kafka-consumer"
  chart      = "${path.module}/../../consumer/helm"
  values = [file("${path.module}/../../consumer/helm/values.yaml")]
  force_update = true
  timeout   = 600  
}

# Kafka Secret Role
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

# Kafka Secret RoleBinding
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

# kafka Auth User Name
resource "kubernetes_secret" "kafka_username" {
  metadata {
     name      = "kafka-username"
     namespace = "default"
  }
  data = {
    username = var.kafka_username
  }
  type = "kubernetes.io/basic-auth"
}

# CRD YAML file
data "http" "servicemonitor_crd" {
  url = "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml"
}
resource "local_file" "servicemonitor_crd" {
  content  = data.http.servicemonitor_crd.response_body
  filename = "${path.module}/servicemonitor-crd.yaml"
}

# Apply the YAML file 
resource "null_resource" "apply_servicemonitor_crd" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local_file.servicemonitor_crd.filename} && sleep 10"
  }
  # Ensures the file is created before applying
  depends_on = [local_file.servicemonitor_crd]
}

# Prometheus Helm release
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"  
  chart      = "prometheus"                                         
  namespace  = "default"
  values     = [file("${path.module}/../../monitoring/prometheus/prometheus-values.yaml")]
  timeout    = 1200

}

# Deploy Grafana using Helm chart
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  values     = [file("${path.module}/../../monitoring/grafana/grafana-values.yaml")]
  namespace  = "default"
  timeout   = 600  
  depends_on = [helm_release.prometheus]
}









