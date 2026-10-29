variable "aiven_api_token" {
  type        = string
  sensitive   = true
  description = "Personal or application token"

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
  description = "Immutable. Lowercase letters, digits, hyphens; must start with a letter; max 64 chars."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,63}$", var.service_name))
    error_message = "service_name must start with a letter and contain only lowercase letters, digits, and hyphens (max 64)."
  }
}

variable "cloud_name" {
  type        = string
  default     = "aws-eu-west-1"
  description = "Format <provider>-<region>, e.g. aws-eu-west-1"
}

variable "plan" {
  type        = string
  default     = "startup-2"
  description = "Sizing tier, e.g. startup-2, business-4, premium-8"
}

variable "kafka_version" {
  type        = string
  default     = "3.9"
  description = "Apache Kafka version"
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name, injected from the qbm.yml `cluster.name` context variable"
}

variable "region" {
  type        = string
  description = "Qovery cluster region, injected from the qbm.yml `cluster.region` context variable"
}
