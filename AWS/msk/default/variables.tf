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
  description = "Qovery cluster name, used for resource tagging."
}

variable "qovery_cluster_long_id" {
  type        = string
  description = "Qovery cluster long id."
}

# User-provided variables
variable "cluster_name" {
  type        = string
  description = "Letters, digits, dots, hyphens, underscores; max 64 chars."

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]{1,64}$", var.cluster_name))
    error_message = "cluster_name must be 1-64 chars of letters, digits, dots, hyphens, and underscores."
  }
}

variable "subnet_ids" {
  type        = string
  default     = ""
  description = "Leave empty — discovered from the cluster's VPC subnets. Set it (comma-separated ids) only on a user-provided VPC."
}

variable "security_group_ids" {
  type        = string
  default     = ""
  description = "Leave empty — derived from the cluster's workers security group. Set it (comma-separated ids) only on a user-provided VPC."
}
