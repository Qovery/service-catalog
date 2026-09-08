# Qovery-injected variables (auto-filled from cluster context)
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

# Adoption-only: set to the live replication group id to import an existing ElastiCache
# replication group instead of creating one. Empty = normal create. Adoption must also state the
# live engine_version, instances_number, parameter_group_name and valkey_password — the defaults
# would otherwise downgrade the engine, drop replicas or reset tuned parameters.
variable "import_identifier" {
  type        = string
  default     = ""
  description = "Existing ElastiCache replication group id to adopt via terraform import. Empty = create a new replication group."
}

# User-provided variables
variable "valkey_name" {
  type        = string
  description = "Replication group name (letters, digits, single hyphens; must start with a letter, end alphanumeric; max 40 chars). Lowercased before it reaches AWS."

  validation {
    condition     = length(var.valkey_name) >= 1 && length(var.valkey_name) <= 40
    error_message = "valkey_name must be between 1 and 40 characters."
  }

  validation {
    # ElastiCache replication group ids accept only letters, digits and hyphens, and must
    # start with a letter. Underscores are not valid, unlike an RDS database name.
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.valkey_name))
    error_message = "valkey_name must start with a letter and contain only letters, digits, and hyphens. Underscores are not allowed."
  }

  validation {
    # Both rejected by AWS on create.
    condition     = !can(regex("--", var.valkey_name)) && !endswith(var.valkey_name, "-")
    error_message = "valkey_name must not contain two consecutive hyphens and must not end with a hyphen."
  }
}

variable "engine_version" {
  type        = string
  default     = "9.0"
  description = "Valkey engine version (9.0 or 9.1). Both share the valkey9 parameter group family."

  validation {
    condition     = contains(["9.0", "9.1"], var.engine_version)
    error_message = "engine_version must be 9.0 or 9.1 (this blueprint is the Valkey 9 major)."
  }
}

variable "instance_class" {
  type        = string
  default     = "cache.t3.micro"
  description = "ElastiCache node type"
}

variable "port" {
  type        = number
  default     = 6379
  description = "Valkey port"

  validation {
    # ElastiCache accepts 1024-65535.
    condition     = var.port >= 1024 && var.port <= 65535
    error_message = "port must be between 1024 and 65535."
  }
}

variable "valkey_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Auth token (16-128 chars; must not contain /, @, \", or spaces). Empty generates a 32-character alphanumeric token."

  validation {
    condition     = var.valkey_password == "" || (length(var.valkey_password) >= 16 && length(var.valkey_password) <= 128)
    error_message = "valkey_password must be between 16 and 128 characters."
  }

  validation {
    # ElastiCache forbids / @ " and space in an auth token.
    condition     = !can(regex("[/@\" ]", var.valkey_password))
    error_message = "valkey_password must not contain '/', '@', '\"', or spaces."
  }

  validation {
    # ElastiCache never returns the auth token, so an adopted group's real one cannot be read
    # back. Generating a fresh one here would publish a valkey_password output that does not
    # authenticate, and auth_token is ignored after create (see main.tf) so it would not be applied.
    condition     = var.import_identifier == "" || var.valkey_password != ""
    error_message = "valkey_password must be set to the existing replication group's auth token when import_identifier is set."
  }
}

variable "parameter_group_name" {
  type        = string
  default     = ""
  description = "Leave empty — derived from the topology: default.valkey9 for a single node group, default.valkey9.cluster.on when instances_number > 1."
}

variable "instances_number" {
  type        = number
  default     = 1
  description = "Node groups (shards). 1 = a single node group with no replica. Above 1 enables cluster mode with one replica per shard, plus the failover and Multi-AZ that AWS requires there. Create-time choice: ElastiCache cannot turn cluster mode on for an existing group."

  validation {
    # One replica per node group, so N shards means 2N nodes; the default AWS quota is 90 nodes
    # per replication group.
    condition     = var.instances_number >= 1 && var.instances_number <= 45
    error_message = "instances_number must be between 1 and 45 (each node group above 1 carries a replica, and AWS allows 90 nodes per replication group)."
  }
}

variable "at_rest_encryption_enabled" {
  type        = bool
  default     = true
  description = "Encrypt data at rest"
}

variable "subnet_group_name" {
  type        = string
  default     = ""
  description = "Leave empty — derived from the Qovery cluster's ElastiCache subnet group. Set it only on a cluster with a user-provided VPC, where that lookup finds nothing."
}

variable "security_group_ids" {
  type        = string
  default     = ""
  description = "Leave empty — derived from the Qovery cluster's workers security group. Set it (comma-separated ids) only on a cluster with a user-provided VPC, where that lookup finds nothing."
}

variable "apply_changes_now" {
  type        = bool
  default     = false
  description = "Apply changes immediately instead of during the maintenance window"
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
  description = "Skip the final snapshot on deletion. False keeps a snapshot behind after the group is destroyed."
}

variable "snapshot_name" {
  type        = string
  default     = ""
  description = "Existing ElastiCache snapshot to seed the new group from. Empty = start empty. Read only at creation."
}
