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
}

variable "multi_az" {
  type        = bool
  default     = false
  description = "Enable Multi-AZ deployment"
}
