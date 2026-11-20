# Qovery-injected variables: required for the module to plan, and filled automatically
# from cluster context. They carry no default on purpose — see AGENTS.md.
variable "region" {
  type        = string
  description = "AWS region"
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name, used as a prefix for resource naming"
}

variable "qovery_cluster_id" {
  type        = string
  description = "Qovery cluster short id (engine kubernetes_cluster_id); YACE matches ElastiCache metrics on it."
}

variable "qovery_cluster_long_id" {
  type        = string
  description = "Qovery cluster long id."
}

# User-provided variables
variable "valkey_name" {
  type        = string
  description = "Letters, digits, single hyphens; must start with a letter and end with a letter or digit; max 32 chars. No underscores."

  validation {
    # The user id and user group id are built from this name plus a suffix, and ElastiCache caps
    # both at 40 characters.
    condition     = length(var.valkey_name) >= 1 && length(var.valkey_name) <= 32
    error_message = "valkey_name must be between 1 and 32 characters."
  }

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.valkey_name))
    error_message = "valkey_name must start with a letter and contain only letters, digits, and hyphens. Underscores are not allowed."
  }

  validation {
    # ElastiCache ids refuse two consecutive hyphens.
    condition     = !can(regex("--", var.valkey_name)) && !endswith(var.valkey_name, "-")
    error_message = "valkey_name must not contain two consecutive hyphens and must not end with a hyphen."
  }
}

variable "valkey_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Password of the application user (16-128 chars; no comma, /, @, \", or spaces). Empty generates a 32-character alphanumeric one."

  validation {
    condition     = var.valkey_password == "" || (length(var.valkey_password) >= 16 && length(var.valkey_password) <= 128)
    error_message = "valkey_password must be between 16 and 128 characters."
  }

  validation {
    # ElastiCache forbids , " / @ in a user password. Spaces are refused here too: they break
    # connection URLs.
    condition     = !can(regex("[,/@\" ]", var.valkey_password))
    error_message = "valkey_password must not contain ',', '/', '@', '\"', or spaces."
  }
}

variable "data_storage_max_gb" {
  type        = number
  default     = 0
  description = "0 = the AWS maximum, 5000 GB. Else the most data the cache may store, in GB (1-5000)."

  validation {
    condition     = var.data_storage_max_gb >= 0 && var.data_storage_max_gb <= 5000 && floor(var.data_storage_max_gb) == var.data_storage_max_gb
    error_message = "data_storage_max_gb must be a whole number between 0 and 5000 (0 = the AWS maximum)."
  }
}

variable "ecpu_per_second_max" {
  type        = number
  default     = 0
  description = "0 = the AWS maximum, 15000000. Else the most ECPUs per second the cache may use (1000-15000000)."

  validation {
    condition     = var.ecpu_per_second_max == 0 || (var.ecpu_per_second_max >= 1000 && var.ecpu_per_second_max <= 15000000 && floor(var.ecpu_per_second_max) == var.ecpu_per_second_max)
    error_message = "ecpu_per_second_max must be 0 (the AWS maximum) or a whole number between 1000 and 15000000."
  }
}

variable "subnet_ids" {
  type        = string
  default     = ""
  description = "Leave empty — derived from the cluster's ElastiCache subnet group. Set it (comma-separated, one per AZ) only on a user-provided VPC; read at creation."
}

variable "security_group_ids" {
  type        = string
  default     = ""
  description = "Leave empty for the blueprint's own group (opens 6379-6380 to allowed_cidrs). Else comma-separated ids."
}

variable "allowed_cidrs" {
  type        = string
  default     = ""
  description = "Leave empty to allow the whole VPC (every cluster pod). Else comma-separated IPv4 CIDRs; only affects the blueprint's security group."

  validation {
    # cidrhost also accepts IPv6, which the IPv4-only cidr_blocks would reject at apply.
    condition     = var.allowed_cidrs == "" || alltrue([for c in split(",", var.allowed_cidrs) : can(regex("^[0-9.]+/[0-9]+$", trimspace(c))) && can(cidrhost(trimspace(c), 0))])
    error_message = "allowed_cidrs must be comma-separated IPv4 CIDRs, e.g. 10.0.0.0/16,192.168.1.0/24."
  }

  validation {
    # AWS stores a rule under its network address, so 10.0.0.5/24 would come back as 10.0.0.0/24
    # and show as a change on every plan.
    condition     = var.allowed_cidrs == "" || alltrue([for c in split(",", var.allowed_cidrs) : try(cidrhost(trimspace(c), 0) == split("/", trimspace(c))[0], false)])
    error_message = "allowed_cidrs entries must be network addresses, e.g. 10.0.0.0/24 rather than 10.0.0.5/24."
  }
}

variable "backup_retention_period" {
  type        = number
  default     = 14
  description = "Days to retain daily automatic snapshots (0 disables)"

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35 && floor(var.backup_retention_period) == var.backup_retention_period
    error_message = "backup_retention_period must be a whole number between 0 and 35."
  }
}

variable "daily_snapshot_time" {
  type        = string
  default     = "00:00"
  description = "UTC, format hh24:mi. Only used when backup_retention_period > 0."

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.daily_snapshot_time))
    error_message = "daily_snapshot_time must use the hh24:mi format, e.g. 03:30."
  }
}

# Set through the blueprint `role_arn` override (qbm.yml spec.engine.roleArn); q-core injects it.
variable "role_arn" {
  description = "Unset = use the cluster credentials directly. Set an IAM role ARN from the cluster's AWS account to assume it; cross-account roles are not supported."
  type        = string
  default     = ""

  validation {
    condition     = var.role_arn == "" || can(regex("^arn:aws(-cn|-us-gov|-iso|-iso-[bef])?:iam::[0-9]{12}:role(/|/[!-~]{1,510}/)[A-Za-z0-9+=,.@_-]{1,64}$", var.role_arn))
    error_message = "role_arn must be an IAM role ARN (arn:aws:iam::<account-id>:role/<name>)."
  }
}
