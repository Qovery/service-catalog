variable "redpanda_client_id" {
  type        = string
  description = "Redpanda Cloud service-account client ID"

  validation {
    condition     = length(var.redpanda_client_id) > 0
    error_message = "redpanda_client_id must not be empty."
  }
}

variable "redpanda_client_secret" {
  type        = string
  sensitive   = true
  description = "Redpanda Cloud service-account client secret"

  validation {
    condition     = length(var.redpanda_client_secret) > 0
    error_message = "redpanda_client_secret must not be empty."
  }
}

variable "resource_group_name" {
  type        = string
  default     = "qovery"
  description = "Redpanda resource group name to create"
}

variable "cluster_name" {
  type        = string
  description = "Serverless cluster name"

  validation {
    condition     = length(var.cluster_name) > 0 && length(var.cluster_name) <= 60
    error_message = "cluster_name must be 1-60 characters."
  }
}

variable "serverless_region" {
  type        = string
  description = "Redpanda serverless region (e.g. us-east-1, eu-central-1). Must be a region Redpanda Serverless supports."

  validation {
    condition     = length(var.serverless_region) > 0
    error_message = "serverless_region must not be empty."
  }
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name, injected by the engine on every Terraform blueprint"
}

variable "region" {
  type        = string
  description = "Qovery cluster region, injected by the engine on every Terraform blueprint"
}
