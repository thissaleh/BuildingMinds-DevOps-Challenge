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
  default = "dckr_pat_UE69JhCUs8O8lllAeg6ELdMnHws"
}

variable "registry_email" {
  type        = string
  description = "Docker registry email"
  default     = "thissaleh@gmail.com"
}

variable "kafka_username" {
  description = "Kafka authentication username"
  type        = string
  default     = "user1"  
}
