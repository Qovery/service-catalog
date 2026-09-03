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
  description = "MSK Serverless cluster name (letters, digits, hyphens, underscores; max 64)"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]{1,64}$", var.cluster_name))
    error_message = "cluster_name must be 1-64 chars of letters, digits, dots, hyphens, and underscores."
  }
}

variable "subnet_ids" {
  type        = string
  default     = ""
  description = "Leave empty — discovered from the Qovery cluster's VPC subnets. Set it (comma-separated ids) only on a cluster with a user-provided VPC, where that lookup finds nothing."
}

variable "security_group_ids" {
  type        = string
  default     = ""
  description = "Leave empty — derived from the Qovery cluster's workers security group. Set it (comma-separated ids) only on a cluster with a user-provided VPC, where that lookup finds nothing."
}
