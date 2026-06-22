# Qovery-injected variables (auto-filled from cluster context)
variable "region" {
  type        = string
  description = "AWS region"
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name, used as a prefix for resource naming"
}

# User-provided variables
variable "db_name" {
  type        = string
  description = "MySQL database name (letters, digits, underscores; must start with a letter; max 64 chars)"

  validation {
    condition     = length(var.db_name) >= 1 && length(var.db_name) <= 64
    error_message = "db_name must be between 1 and 64 characters."
  }

  validation {
    # MySQL database names: letters, digits, underscores. Hyphens require quoting and are rejected here.
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "db_name must start with a letter and contain only letters, digits, and underscores. Hyphens are not allowed."
  }
}

variable "db_username" {
  type        = string
  description = "Master username (letters, digits, underscores; must start with a letter; max 32 chars)"

  validation {
    condition     = length(var.db_username) >= 1 && length(var.db_username) <= 32
    error_message = "db_username must be between 1 and 32 characters (MySQL limit)."
  }

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_username))
    error_message = "db_username must start with a letter and contain only letters, digits, and underscores."
  }
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Master password (8–128 chars; must not contain /, @, \", or spaces)"

  validation {
    condition     = length(var.db_password) >= 8 && length(var.db_password) <= 128
    error_message = "db_password must be between 8 and 128 characters."
  }

  validation {
    # RDS forbids / @ " and space in passwords.
    condition     = !can(regex("[/@\" ]", var.db_password))
    error_message = "db_password must not contain '/', '@', '\"', or spaces."
  }
}

variable "port" {
  type        = number
  default     = 3306
  description = "Database port"

  validation {
    condition     = var.port >= 1024 && var.port <= 65535
    error_message = "port must be between 1024 and 65535."
  }
}

variable "instance_class" {
  type        = string
  default     = "db.t3.micro"
  description = "RDS instance class"
}

variable "allocated_storage" {
  type        = number
  default     = 20
  description = "Allocated storage in GiB (minimum 20 for gp3)"

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "allocated_storage must be at least 20 GiB for gp3 storage."
  }

  validation {
    # gp2 caps at 16384 GiB; io1/io2/gp3 go to 65536.
    condition     = var.storage_type != "gp2" || var.allocated_storage <= 16384
    error_message = "allocated_storage must not exceed 16384 GiB for gp2 storage."
  }
}

variable "storage_type" {
  type        = string
  default     = "gp3"
  description = "EBS storage type (gp2, gp3, io1, io2)"

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.storage_type)
    error_message = "storage_type must be one of: gp2, gp3, io1, io2."
  }
}

variable "storage_encrypted" {
  type        = bool
  default     = true
  description = "Encrypt storage at rest"
}

variable "disk_iops" {
  type        = number
  default     = 0
  description = "Provisioned IOPS. 0 lets AWS choose the default."

  validation {
    condition     = var.disk_iops >= 0 && var.disk_iops <= 256000
    error_message = "disk_iops must be between 0 and 256000."
  }
}

variable "multi_az" {
  type        = bool
  default     = false
  description = "Enable Multi-AZ deployment"
}

variable "publicly_accessible" {
  type        = bool
  default     = false
  description = "Expose the database to the public internet"
}

variable "db_subnet_group_name" {
  type        = string
  default     = ""
  description = "Optional DB subnet group. Empty = AWS default for the VPC."
}

variable "apply_changes_now" {
  type        = bool
  default     = false
  description = "Apply changes immediately instead of during the maintenance window"
}

variable "allow_major_version_upgrade" {
  type        = bool
  default     = false
  description = "Allow major engine version upgrades on apply"
}

variable "auto_minor_version_upgrade" {
  type        = bool
  default     = true
  description = "Automatically apply minor version upgrades during the maintenance window"
}

variable "preferred_maintenance_window" {
  type        = string
  default     = "Tue:02:00-Tue:04:00"
  description = "Maintenance window (UTC) — ddd:hh24:mi-ddd:hh24:mi"
}

variable "preferred_backup_window" {
  type        = string
  default     = "00:00-01:00"
  description = "Daily backup window (UTC) — hh24:mi-hh24:mi"
}

variable "backup_retention_period" {
  type        = number
  default     = 7
  description = "Days to retain automated backups (0 disables)"

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "backup_retention_period must be between 0 and 35."
  }
}

variable "skip_final_snapshot" {
  type        = bool
  default     = true
  description = "Skip the final snapshot on deletion"
}

variable "delete_automated_backups" {
  type        = bool
  default     = true
  description = "Delete automated backups on instance deletion"
}

variable "copy_tags_to_snapshot" {
  type        = bool
  default     = true
  description = "Propagate instance tags to snapshots"
}

variable "performance_insights_enabled" {
  type        = bool
  default     = false
  description = "Enable RDS Performance Insights"
}

variable "performance_insights_retention_period" {
  type        = number
  default     = 7
  description = "Performance Insights retention in days. Only used when performance_insights_enabled is true. Valid: 7, 31, or a multiple of 31 up to 731."

  validation {
    # AWS only accepts 7, 731, or a multiple of 31 — a plain range check lets invalid values (e.g. 30) reach apply.
    condition     = contains([7, 731], var.performance_insights_retention_period) || (var.performance_insights_retention_period % 31 == 0 && var.performance_insights_retention_period >= 31 && var.performance_insights_retention_period <= 731)
    error_message = "performance_insights_retention_period must be 7, 731, or a multiple of 31 (e.g. 31, 62, 93)."
  }
}

variable "ca_cert_identifier" {
  type        = string
  default     = "rds-ca-rsa2048-g1"
  description = "CA certificate identifier"
}

variable "monitoring_interval" {
  type        = number
  default     = 0
  description = "Enhanced monitoring interval in seconds (0 disables)"

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "monitoring_interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }
}

variable "monitoring_role_arn" {
  type        = string
  default     = ""
  description = "IAM role ARN for enhanced monitoring. Required when monitoring_interval > 0."

  validation {
    condition     = var.monitoring_interval == 0 || var.monitoring_role_arn != ""
    error_message = "monitoring_role_arn is required when monitoring_interval > 0."
  }
}

variable "option_group_name" {
  type        = string
  default     = ""
  description = "Optional option group name. Empty = AWS default."
}

variable "deletion_protection" {
  type        = bool
  default     = false
  description = "Prevent the database from being deleted via TF or the API"
}

variable "iam_database_authentication_enabled" {
  type        = bool
  default     = false
  description = "Enable IAM database authentication"
}

variable "dedicated_log_volume" {
  type        = bool
  default     = false
  description = "Provision a dedicated EBS volume for database logs"
}
