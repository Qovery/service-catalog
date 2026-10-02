# Qovery-injected variables: required for the module to plan, and filled automatically
# from cluster context. They carry no default on purpose — see AGENTS.md.
variable "region" {
  type        = string
  description = "AWS region"
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name"
}

variable "qovery_cluster_id" {
  type        = string
  description = "Qovery cluster short id (engine kubernetes_cluster_id); YACE matches ElastiCache metrics on it."
}

variable "qovery_cluster_long_id" {
  type        = string
  description = "Qovery cluster long id."
}

# Adoption-only blueprint: the live cluster id to import. There is no create path, because this
# shape cannot carry an auth token or TLS and a new Redis must not be reachable without them.
variable "import_identifier" {
  type        = string
  default     = ""
  description = "Existing ElastiCache cluster id to adopt via terraform import. Required."

  validation {
    condition     = var.import_identifier != ""
    error_message = "import_identifier is required: this blueprint only adopts an existing single-node ElastiCache cluster. Use the aws-elasticache-redis blueprint to create a new Redis."
  }
}

# User-provided variables
variable "redis_name" {
  type        = string
  description = "Display name, set as the Name tag (letters, digits, single hyphens; max 40 chars)."

  validation {
    condition     = length(var.redis_name) >= 1 && length(var.redis_name) <= 40
    error_message = "redis_name must be between 1 and 40 characters."
  }
}

variable "engine_version" {
  type        = string
  default     = "5.0.6"
  description = "Redis engine version of the adopted cluster (5.0 or 5.0.6)"

  validation {
    condition     = contains(["5.0", "5.0.6"], var.engine_version)
    error_message = "engine_version must be 5.0 or 5.0.6 (this blueprint is the Redis 5 major)."
  }
}

variable "instance_class" {
  type        = string
  description = "ElastiCache node type of the adopted cluster"
}

variable "port" {
  type        = number
  default     = 6379
  description = "Redis port"

  validation {
    condition     = var.port >= 1024 && var.port <= 65535
    error_message = "port must be between 1024 and 65535."
  }
}

variable "parameter_group_name" {
  type        = string
  description = "Parameter group of the adopted cluster (native Qovery Redis uses default.redis<major>)."
}

# This shape has no auth. Qovery still holds a login and password in the legacy connection
# variables; the module only republishes them unchanged (db_username / db_password) so those
# variables keep refreshing after the takeover.
variable "legacy_connection_username" {
  type        = string
  default     = ""
  description = "Login held in the legacy connection variables. Not used for auth."
}

variable "legacy_connection_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Password held in the legacy connection variables. Not used for auth: this shape has none."
}

variable "apply_changes_now" {
  type        = bool
  default     = false
  description = "Apply changes immediately instead of during the maintenance window"
}

variable "preferred_maintenance_window" {
  type        = string
  default     = "Tue:02:00-Tue:04:00"
  description = "Maintenance window (UTC) — ddd:hh24:mi-ddd:hh24:mi. Ignored after adoption, like the native template."
}

variable "preferred_backup_window" {
  type        = string
  default     = "00:00-01:00"
  description = "Daily snapshot window (UTC) — hh24:mi-hh24:mi. Only used when backup_retention_period > 0."
}

variable "backup_retention_period" {
  type        = number
  default     = 14
  description = "Days to retain automatic snapshots (0 disables)"

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "backup_retention_period must be between 0 and 35."
  }
}

variable "skip_final_snapshot" {
  type        = bool
  default     = false
  description = "Skip the final snapshot on deletion. False keeps a snapshot behind after the cluster is destroyed."
}
