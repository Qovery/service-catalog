# Qovery-injected variables (auto-filled from cluster context)
variable "region" {
  type        = string
  description = "Scaleway region"
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name, used as a prefix for resource naming"
}

variable "qovery_cluster_id" {
  type        = string
  default     = ""
  description = "Qovery cluster short id (engine kubernetes_cluster_id)."
}

variable "qovery_client_id" {
  type        = string
  default     = ""
  description = "Qovery organization (client) short id."
}

variable "qovery_environment_id" {
  type        = string
  default     = ""
  description = "Qovery environment short id."
}

variable "qovery_project_id" {
  type        = string
  default     = ""
  description = "Qovery project short id."
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

  validation {
    # Scaleway managed PostgreSQL reserved user names (rdb_admin is Scaleway's internal admin)
    condition     = !contains(["rdb_admin", "postgres"], lower(var.db_username)) && !startswith(lower(var.db_username), "pg_")
    error_message = "db_username must not be a reserved word. Reserved names: rdb_admin, postgres, and any name starting with 'pg_'."
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
    # Reject out-of-range octets (>255) and prefixes (>32).
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])/(3[0-2]|[12]?[0-9])$", var.acl_allowed_cidr))
    error_message = "acl_allowed_cidr must be a valid IPv4 CIDR with octets 0-255 and a prefix 0-32 (e.g. 10.0.0.0/8)."
  }

  validation {
    # Don't expose the database to the entire internet — force an explicit, narrower CIDR.
    condition     = !var.publicly_accessible || var.acl_allowed_cidr != "0.0.0.0/0"
    error_message = "acl_allowed_cidr must not be 0.0.0.0/0 when publicly_accessible is true; specify a narrower CIDR."
  }
}
