variable "aiven_api_token" {
  type        = string
  sensitive   = true
  description = "Aiven API token (personal or application token)"

  validation {
    condition     = length(var.aiven_api_token) > 0
    error_message = "aiven_api_token must not be empty."
  }
}

variable "project" {
  type        = string
  description = "Existing Aiven project name the service is created in"

  validation {
    condition     = length(var.project) > 0
    error_message = "project must not be empty."
  }
}

variable "service_name" {
  type        = string
  description = "Aiven service name (immutable; lowercase letters, digits, hyphens)"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,63}$", var.service_name))
    error_message = "service_name must start with a letter and contain only lowercase letters, digits, and hyphens (max 64)."
  }
}

variable "cloud_name" {
  type        = string
  default     = "aws-eu-west-1"
  description = "Aiven cloud/region, formatted <provider>-<region> (e.g. aws-eu-west-1, google-europe-west1)"
}

variable "plan" {
  type        = string
  default     = "startup-2"
  description = "Aiven service plan / sizing tier (e.g. startup-2, business-4, premium-8)"
}

variable "kafka_version" {
  type        = string
  default     = "3.9"
  description = "Apache Kafka version"
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name, injected by the engine on every Terraform blueprint"
}

variable "qovery_user_provided_network" {
  type        = bool
  description = "True when the cluster VPC was provided by the user, so Qovery resource naming conventions do not apply to it."
}

variable "region" {
  type        = string
  description = "Qovery cluster region, injected by the engine on every Terraform blueprint"
}
