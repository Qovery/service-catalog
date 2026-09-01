variable "temporal_cloud_api_key" {
  type        = string
  sensitive   = true
  description = "Temporal Cloud API key (used by the provider to manage namespaces)"

  validation {
    condition     = length(var.temporal_cloud_api_key) > 0
    error_message = "temporal_cloud_api_key must not be empty."
  }
}

variable "namespace_name" {
  type        = string
  description = "Namespace name (2-64 chars: lowercase letters, digits, hyphens). Temporal appends the account suffix to form the full namespace id."

  validation {
    condition     = can(regex("^[a-z0-9-]{2,64}$", var.namespace_name))
    error_message = "namespace_name must be 2-64 chars of lowercase letters, digits, and hyphens."
  }
}

variable "regions" {
  type        = string
  default     = "aws-us-east-1"
  description = "Comma-separated Temporal Cloud regions (1-2), e.g. aws-us-east-1 or gcp-us-central1"

  validation {
    condition     = length([for r in split(",", var.regions) : trimspace(r) if trimspace(r) != ""]) >= 1 && length(split(",", var.regions)) <= 2
    error_message = "regions must list 1 or 2 comma-separated regions."
  }
}

variable "retention_days" {
  type        = number
  default     = 30
  description = "Workflow execution retention period in days"

  validation {
    condition     = var.retention_days >= 1 && var.retention_days <= 90
    error_message = "retention_days must be between 1 and 90."
  }
}

# API-key client auth is always enabled by this blueprint (see main.tf). Optionally add
# mTLS on top by supplying a CA bundle here.
variable "accepted_client_ca" {
  type        = string
  default     = ""
  description = "Base64-encoded PEM CA bundle to additionally enable mTLS client auth. Empty = API-key auth only."
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
