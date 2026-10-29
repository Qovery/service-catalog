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
  description = "Qovery cluster short id (engine kubernetes_cluster_id); YACE matches RDS metrics on it."
}

variable "qovery_cluster_long_id" {
  type        = string
  description = "Qovery cluster long id."
}

# Adoption-only: set to the live RDS identifier to import an existing instance
# instead of creating one. Empty = normal create. See docs/db-blueprint-adoption-migration.md.
variable "import_identifier" {
  type        = string
  default     = ""
  description = "Existing RDS instance identifier to adopt via terraform import. Empty = create a new instance."
}

variable "engine_version" {
  type        = string
  default     = ""
  description = "Exact engine version Terraform requests (e.g. 16.4). Set by the deployment engine on every deploy: the live version, or the upgrade target on a major change. Empty = the live version of an existing instance, else the bare major for a new one."
}

# User-provided variables
variable "db_name" {
  type        = string
  description = "Letters, digits, underscores; must start with a letter; max 63 chars. No hyphens."

  validation {
    condition     = length(var.db_name) >= 1 && length(var.db_name) <= 63
    error_message = "db_name must be between 1 and 63 characters."
  }

  validation {
    # PostgreSQL identifiers: letters, digits, underscores only; must start with a letter.
    # Hyphens are not valid in PostgreSQL database names.
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "db_name must start with a letter and contain only letters, digits, and underscores. Hyphens are not allowed."
  }
}

variable "db_username" {
  type        = string
  default     = ""
  description = "Leave empty to use qoveryadmin. Letters, digits, underscores, starting with a letter, max 63; not admin, rdsadmin, rdsrepladmin, rdstopmgr or pg_*."

  validation {
    condition     = var.db_username == "" || (length(var.db_username) >= 1 && length(var.db_username) <= 63)
    error_message = "db_username must be between 1 and 63 characters."
  }

  validation {
    condition     = var.db_username == "" || (can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_username)))
    error_message = "db_username must start with a letter and contain only letters, digits, and underscores."
  }

  validation {
    # AWS RDS PostgreSQL reserved master user names (docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Limits.html)
    condition     = var.db_username == "" || (!contains(["admin", "rdsadmin", "rdsrepladmin", "rdstopmgr"], lower(var.db_username)) && !startswith(lower(var.db_username), "pg_"))
    error_message = "db_username must not be a reserved word. Reserved names: admin, rdsadmin, rdsrepladmin, rdstopmgr, and any name starting with 'pg_'."
  }

  validation {
    # username is ForceNew on aws_db_instance and is absent from the resource's ignore_changes list,
    # so adopting an instance whose master user differs from the fallback would plan a replacement
    # and destroy the live database. Adoption has to state the existing username.
    condition     = var.import_identifier == "" || var.db_username != ""
    error_message = "db_username must be set to the existing instance's master username when import_identifier is set."
  }
}

variable "db_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Leave empty and Qovery generates one (adopted: its current password). 8–128 chars, no /, @, \", spaces; edits rotate it (adopted: needs manage_db_password)."

  validation {
    condition     = var.db_password == "" || (length(var.db_password) >= 8 && length(var.db_password) <= 128)
    error_message = "db_password must be between 8 and 128 characters."
  }

  validation {
    # RDS forbids / @ " and space in passwords.
    condition     = !can(regex("[/@\" ]", var.db_password))
    error_message = "db_password must not contain '/', '@', '\"', or spaces."
  }

  validation {
    # RDS never returns the master password, so an adopted instance's real one cannot be read back.
    # Generating a fresh one here would publish a db_password output that does not authenticate.
    condition     = var.import_identifier == "" || var.db_password != ""
    error_message = "db_password must be set to the existing instance's master password when import_identifier is set."
  }
}

variable "manage_db_password" {
  type        = bool
  default     = false
  description = "Adopted instances only, one-way: once on, keep it on. Turning it on applies db_password, so it must match the instance's current one."
}


variable "port" {
  type        = number
  default     = 5432
  description = "Min 1150 (RDS reserves lower ports)."

  validation {
    # RDS reserves ports below 1150.
    condition     = var.port >= 1150 && var.port <= 65535
    error_message = "port must be between 1150 and 65535."
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
  description = "GiB, min 20, max 65536 (gp2: 16384). A value below the current disk is a no-op: RDS never shrinks storage."

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "allocated_storage must be at least 20 GiB for gp3 storage."
  }

  validation {
    condition     = var.allocated_storage <= 65536
    error_message = "allocated_storage must not exceed 65536 GiB."
  }

  validation {
    # gp2 caps at 16384 GiB; io1/io2/gp3 go to 65536.
    condition     = var.storage_type != "gp2" || var.allocated_storage <= 16384
    error_message = "allocated_storage must not exceed 16384 GiB for gp2 storage."
  }
}

# No default in qbm.yml: q-core writes a manifest default onto every service it repoints, which
# would turn off autoscaling set in the AWS console. Null keeps the live value instead.
variable "max_allocated_storage" {
  type        = number
  default     = null
  description = "Leave empty to keep the current autoscaling ceiling; 0 turns it off. Otherwise GiB, at least 10% above the disk, max 65536 (gp2: 16384)."

  validation {
    condition     = coalesce(var.max_allocated_storage, 0) >= 0 && floor(coalesce(var.max_allocated_storage, 0)) == coalesce(var.max_allocated_storage, 0)
    error_message = "max_allocated_storage must be a whole number, 0 or more."
  }

  validation {
    # AWS rejects a ceiling less than 10% above the current storage; integer form avoids float rounding.
    condition     = coalesce(var.max_allocated_storage, 0) == 0 || coalesce(var.max_allocated_storage, 0) * 10 >= var.allocated_storage * 11
    error_message = "max_allocated_storage must be 0 (off) or at least 10% above allocated_storage (22 for 20 GiB)."
  }

  validation {
    condition     = coalesce(var.max_allocated_storage, 0) <= (var.storage_type == "gp2" ? 16384 : 65536)
    error_message = "max_allocated_storage must not exceed 65536 GiB, or 16384 GiB for gp2 storage."
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
  description = "Only for io1/io2, or gp3 at ≥400 GiB. 0 lets AWS choose."

  validation {
    condition     = var.disk_iops >= 0 && var.disk_iops <= 256000
    error_message = "disk_iops must be between 0 and 256000."
  }

  validation {
    # io1/io2 have no baseline — AWS requires an explicit provisioned IOPS value.
    condition     = !contains(["io1", "io2"], var.storage_type) || var.disk_iops > 0
    error_message = "disk_iops must be greater than 0 when storage_type is io1 or io2."
  }

  validation {
    # gp3 only accepts custom IOPS at >= 400 GiB; below that AWS forces the baseline and rejects iops.
    condition     = var.storage_type != "gp3" || var.disk_iops == 0 || var.allocated_storage >= 400
    error_message = "disk_iops can only be set for gp3 when allocated_storage is at least 400 GiB; leave it 0 below that."
  }
}

variable "storage_throughput" {
  type        = number
  default     = 0
  description = "0 = AWS baseline (an existing instance keeps its value). Else 500–4000 MiB/s, gp3 ≥400 GiB only, ≤0.25 × disk_iops, with disk_iops ≥12000 set."

  validation {
    condition     = var.storage_throughput == 0 || (var.storage_throughput >= 500 && var.storage_throughput <= 4000)
    error_message = "storage_throughput must be 0 or between 500 and 4000 MiB/s."
  }

  validation {
    condition     = floor(var.storage_throughput) == var.storage_throughput
    error_message = "storage_throughput must be a whole number."
  }

  validation {
    condition     = var.storage_throughput == 0 || var.storage_type == "gp3"
    error_message = "storage_throughput can only be set when storage_type is gp3."
  }

  validation {
    # Below 400 GiB gp3 is one volume at a fixed 3000 IOPS / 125 MiB/s; AWS rejects a throughput.
    condition     = var.storage_throughput == 0 || var.allocated_storage >= 400
    error_message = "storage_throughput can only be set when allocated_storage is at least 400 GiB; leave it 0 below that."
  }

  validation {
    # CreateDBInstance rejects a gp3 throughput without IOPS, and gp3 at 400 GiB and up starts at 12000 IOPS.
    condition     = var.storage_throughput == 0 || var.disk_iops >= 12000
    error_message = "storage_throughput needs disk_iops set to 12000 or more (on an existing instance, its current IOPS)."
  }

  validation {
    # AWS caps gp3 throughput at 0.25 MiB/s per IOPS.
    condition     = var.storage_throughput == 0 || var.storage_throughput <= 0.25 * var.disk_iops
    error_message = "storage_throughput must not exceed 0.25 x disk_iops; raise disk_iops for more."
  }
}

variable "multi_az" {
  type        = bool
  default     = true
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
  description = "Leave empty — derived from the cluster's DB subnet group. Set it only on a user-provided VPC."
}

variable "security_group_ids" {
  type        = string
  default     = ""
  description = "Leave empty — derived from the cluster's workers security group. Set it (comma-separated ids) only on a user-provided VPC."
}

variable "apply_changes_now" {
  type        = bool
  default     = false
  description = "Apply changes immediately instead of during the maintenance window"
}

variable "allow_major_version_upgrade" {
  type        = bool
  default     = true
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
  description = "UTC, format ddd:hh24:mi-ddd:hh24:mi."
}

variable "preferred_backup_window" {
  type        = string
  default     = "00:00-01:00"
  description = "Daily, UTC, format hh24:mi-hh24:mi."
}

variable "backup_retention_period" {
  type        = number
  default     = 14
  description = "Days to retain automated backups (0 disables)"

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "backup_retention_period must be between 0 and 35."
  }
}

variable "skip_final_snapshot" {
  type        = bool
  default     = false
  description = "Off keeps a final snapshot on deletion, billed until deleted. Turn on for throwaway instances."
}

variable "delete_automated_backups" {
  type        = bool
  default     = false
  description = "Delete automated backups with the instance. Off keeps them backup_retention_period days; turn on for throwaway ones."
}

variable "copy_tags_to_snapshot" {
  type        = bool
  default     = true
  description = "Propagate instance tags to snapshots"
}

variable "performance_insights_enabled" {
  type        = bool
  default     = true
  description = "Enable RDS Performance Insights"
}

variable "performance_insights_retention_period" {
  type        = number
  default     = 7
  description = "Retention in days. Only used when performance_insights_enabled is true."

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
  description = "For enhanced monitoring. Required when monitoring_interval > 0."

  # TF 1.9+ supports cross-variable validation
  validation {
    condition     = var.monitoring_interval == 0 || var.monitoring_role_arn != ""
    error_message = "monitoring_role_arn is required when monitoring_interval > 0."
  }
}

# A bool has no "unset": the console sends false for one left untouched, so false has to keep
# what the instance has rather than remove exports set in the AWS console.
variable "cloudwatch_logs_export_enabled" {
  type        = bool
  default     = false
  description = "Off keeps the current CloudWatch log exports. On also exports the PostgreSQL log, replicas included; turning it off again does not stop it."
}

variable "option_group_name" {
  type        = string
  default     = ""
  description = "Empty = AWS default."
}

# A JSON string, not a map: qbm.yml has no map type. A value is either the parameter value or
# {"value": ..., "apply_method": "pending-reboot"}, the form RDS requires for static parameters.
variable "db_parameters" {
  type        = string
  default     = ""
  description = "Empty = keep the current group (one this blueprint made is deleted). Else JSON, e.g. {\"log_connections\":\"1\"}; static params need apply_method pending-reboot."

  validation {
    condition     = var.db_parameters == "" || can(keys(jsondecode(var.db_parameters)))
    error_message = "db_parameters must be a JSON object, e.g. {\"log_connections\":\"1\"}."
  }

  validation {
    # tostring(null) succeeds, so null is rejected explicitly; any evaluation error is a rejection.
    condition = var.db_parameters == "" || try(alltrue([
      for name, v in jsondecode(var.db_parameters) :
      try(v.value, v) != null
      && can(tostring(try(v.value, v)))
      && try(contains(["immediate", "pending-reboot"], try(v.apply_method, "immediate")), false)
    ]), false)
    error_message = "Each db_parameters value must be a string, number or bool, or {\"value\": ..., \"apply_method\": \"immediate\" | \"pending-reboot\"}."
  }
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

# Read replicas — same-region, read-only copies of the primary. Point analytics tools
# (Metabase, Superset, BI dashboards, ad-hoc reporting) at the replica endpoints to keep
# heavy read traffic off the primary. AWS replicates asynchronously, so replicas are
# eventually consistent — fine for analytics, not for read-after-write.
variable "read_replica_count" {
  type        = number
  default     = 0
  description = "Same-region read replicas (0 disables; max 15), e.g. for analytics tools. Requires backup_retention_period > 0."

  validation {
    condition     = var.read_replica_count >= 0 && var.read_replica_count <= 15 && floor(var.read_replica_count) == var.read_replica_count
    error_message = "read_replica_count must be a whole number between 0 and 15."
  }

  validation {
    # AWS refuses to create a read replica unless the source has automated backups enabled.
    condition     = var.read_replica_count == 0 || var.backup_retention_period > 0
    error_message = "read replicas require automated backups on the primary: set backup_retention_period > 0."
  }
}

variable "read_replica_instance_class" {
  type        = string
  default     = ""
  description = "Empty = same as the primary. Analytics workloads often want a larger class."
}

variable "read_replica_publicly_accessible" {
  type        = bool
  default     = false
  description = "Expose read replicas to the public internet. Keep false unless an external analytics tool must reach them directly."
}

variable "read_replica_allowed_cidrs" {
  type        = string
  default     = ""
  description = "Empty = the primary's security groups. Else up to 50 network CIDRs (10.0.0.0/24, not 10.0.0.5/24); public ones need read_replica_publicly_accessible."

  validation {
    # Network address only: EC2 stores 10.0.0.5/24 as 10.0.0.0/24, which would diff on every plan
    # and collide with a 10.0.0.0/24 entry. cidrnetmask rejects IPv6.
    condition = alltrue([
      for cidr in split(",", var.read_replica_allowed_cidrs) :
      can(cidrnetmask(trimspace(cidr))) && try(cidrhost(trimspace(cidr), 0) == split("/", trimspace(cidr))[0], false)
      if trimspace(cidr) != ""
    ])
    error_message = "read_replica_allowed_cidrs must be comma-separated IPv4 network CIDRs, e.g. 18.207.81.126/32,10.0.0.0/24 (not 10.0.0.5/24)."
  }

  validation {
    # Without a replica there is nothing to attach the group to; fail rather than ignore the value.
    condition     = trimspace(var.read_replica_allowed_cidrs) == "" || var.read_replica_count > 0
    error_message = "read_replica_allowed_cidrs requires read_replica_count > 0."
  }

  validation {
    # One rule per entry plus one per VPC CIDR (up to 5), under the default 60 inbound rules
    # per security group.
    condition     = length(compact([for cidr in split(",", var.read_replica_allowed_cidrs) : trimspace(cidr)])) <= 50
    error_message = "read_replica_allowed_cidrs accepts at most 50 CIDRs."
  }
}

variable "read_replica_multi_az" {
  type        = bool
  default     = false
  description = "Enable Multi-AZ for read replicas (higher availability, roughly doubles their cost)."
}
