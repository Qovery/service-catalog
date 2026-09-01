variable "confluent_cloud_api_key" {
  type        = string
  sensitive   = true
  description = "Confluent Cloud API key (Cloud-level, used by the provider)"

  validation {
    condition     = length(var.confluent_cloud_api_key) > 0
    error_message = "confluent_cloud_api_key must not be empty."
  }
}

variable "confluent_cloud_api_secret" {
  type        = string
  sensitive   = true
  description = "Confluent Cloud API secret"

  validation {
    condition     = length(var.confluent_cloud_api_secret) > 0
    error_message = "confluent_cloud_api_secret must not be empty."
  }
}

variable "environment_name" {
  type        = string
  default     = "qovery"
  description = "Confluent environment display name to create"
}

variable "cluster_name" {
  type        = string
  description = "Kafka cluster display name"

  validation {
    condition     = length(var.cluster_name) > 0 && length(var.cluster_name) <= 64
    error_message = "cluster_name must be 1-64 characters."
  }
}

variable "availability" {
  type        = string
  default     = "SINGLE_ZONE"
  description = "Cluster availability"

  validation {
    condition     = contains(["SINGLE_ZONE", "MULTI_ZONE"], var.availability)
    error_message = "availability must be SINGLE_ZONE or MULTI_ZONE."
  }
}

variable "cloud" {
  type        = string
  default     = "AWS"
  description = "Cloud provider hosting the cluster"

  validation {
    condition     = contains(["AWS", "AZURE", "GCP"], var.cloud)
    error_message = "cloud must be one of: AWS, AZURE, GCP."
  }
}

variable "region" {
  type        = string
  default     = "us-east-2"
  description = "Cloud region for the cluster (e.g. us-east-2 for AWS)"
}

variable "service_account_name" {
  type        = string
  default     = "qovery-app"
  description = "Service account display name for the generated client API key"
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name, injected from the qbm.yml `cluster.name` context variable"
}

variable "qovery_user_provided_network" {
  type        = bool
  description = "True when the cluster VPC was provided by the user, so Qovery resource naming conventions do not apply to it."
}
