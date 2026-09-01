# Qovery-injected variables (auto-filled from cluster context)
variable "region" {
  type        = string
  description = "AWS region"
}

variable "qovery_cluster_id" {
  type        = string
  description = "Qovery cluster short id; used to auto-discover the cluster VPC/subnets/security group."
}

variable "qovery_cluster_name" {
  type        = string
  default     = ""
  description = "Qovery cluster name, used for resource tagging."
}

variable "qovery_cluster_long_id" {
  type        = string
  description = "Qovery cluster long id."
}

variable "qovery_user_provided_network" {
  type        = bool
  description = "True when the cluster VPC was provided by the user, so Qovery resource naming conventions do not apply to it."
}

# User-provided variables
variable "cluster_name" {
  type        = string
  description = "MSK Serverless cluster name (letters, digits, hyphens, underscores; max 64)"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]{1,64}$", var.cluster_name))
    error_message = "cluster_name must be 1-64 chars of letters, digits, dots, hyphens, and underscores."
  }
}

variable "subnet_ids" {
  type        = string
  default     = ""
  description = "Optional comma-separated subnet IDs override. Empty = auto-discover the Qovery cluster VPC subnets."
}

variable "security_group_ids" {
  type        = string
  default     = ""
  description = "Optional comma-separated security group IDs override. Empty = the Qovery cluster workers security group."
}
