# Qovery-injected variables (auto-filled from cluster context)
variable "region" {
  type        = string
  description = "Scaleway region"
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name, used as a prefix for resource naming"
}

# User-provided variables
variable "instance_name" {
  type        = string
  description = "Database instance name (letters, digits, hyphens, underscores; must start with a letter or digit; max 100 chars)"

  validation {
    condition     = length(var.instance_name) >= 1 && length(var.instance_name) <= 100
    error_message = "instance_name must be between 1 and 100 characters."
  }

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]*$", var.instance_name))
    error_message = "instance_name must start with a letter or digit and contain only letters, digits, hyphens, and underscores."
  }
}

variable "db_name" {
  type        = string
  description = "PostgreSQL database name (letters, digits, underscores; must start with a letter; max 63 chars)"

  validation {
    condition     = length(var.db_name) >= 1 && length(var.db_name) <= 63
    error_message = "db_name must be between 1 and 63 characters."
  }

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "db_name must start with a letter and contain only letters, digits, and underscores. Hyphens are not allowed."
  }
}

variable "db_username" {
  type        = string
  description = "Database username (letters, digits, underscores; must start with a letter; max 63 chars)"

  validation {
    condition     = length(var.db_username) >= 1 && length(var.db_username) <= 63
    error_message = "db_username must be between 1 and 63 characters."
  }

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_username))
    error_message = "db_username must start with a letter and contain only letters, digits, and underscores."
  }
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Database user password (8–128 chars; must not contain /, @, \", or spaces)"

  validation {
    condition     = length(var.db_password) >= 8 && length(var.db_password) <= 128
    error_message = "db_password must be between 8 and 128 characters."
  }

  validation {
    condition     = !can(regex("[/@\" ]", var.db_password))
    error_message = "db_password must not contain '/', '@', '\"', or spaces."
  }
}

variable "engine_version" {
  type        = string
  default     = "PostgreSQL-16"
  description = "Engine version (e.g. PostgreSQL-16, PostgreSQL-15)"

  validation {
    condition     = contains(["PostgreSQL-16", "PostgreSQL-15", "PostgreSQL-14"], var.engine_version)
    error_message = "engine_version must be one of: PostgreSQL-16, PostgreSQL-15, PostgreSQL-14."
  }
}

variable "node_type" {
  type        = string
  default     = "DB-DEV-S"
  description = "Node type (e.g. DB-DEV-S, DB-GP-XS)"
}

variable "volume_type" {
  type        = string
  default     = "lssd"
  description = "Volume backend type: lssd (local SSD), sbs_5k or sbs_15k (block SSD, 5k/15k IOPS)"

  validation {
    condition     = contains(["lssd", "sbs_5k", "sbs_15k"], var.volume_type)
    error_message = "volume_type must be one of: lssd, sbs_5k, sbs_15k."
  }
}

variable "volume_size_gb" {
  type        = number
  default     = 5
  description = "Volume size in GB (minimum 5)"

  validation {
    condition     = var.volume_size_gb >= 5 && var.volume_size_gb <= 10000
    error_message = "volume_size_gb must be between 5 and 10000."
  }
}

variable "is_ha_cluster" {
  type        = bool
  default     = false
  description = "Enable high availability cluster mode"
}

variable "activate_backups" {
  type        = bool
  default     = true
  description = "Enable automated backups"
}

variable "publicly_accessible" {
  type        = bool
  default     = false
  description = "Open the database to traffic from acl_allowed_cidr. When false, no ACL is created."
}

variable "acl_allowed_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "Single CIDR allowed to reach the instance (only used when publicly_accessible)."

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.acl_allowed_cidr))
    error_message = "acl_allowed_cidr must be a valid CIDR (e.g. 10.0.0.0/8)."
  }
}
