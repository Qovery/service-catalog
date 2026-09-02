# Qovery-injected variables (auto-filled from cluster context)
variable "region" {
  type        = string
  description = "GCP region"
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name, used as a label for resource naming"
}

variable "qovery_cluster_long_id" {
  type        = string
  description = "Qovery cluster long id."
}

variable "qovery_cluster_id" {
  type        = string
  description = "Qovery cluster short id (engine kubernetes_cluster_id)."
}

# User-provided variables
variable "redis_name" {
  type        = string
  description = "Memorystore instance ID (lowercase letters, digits, hyphens; must start with a letter and not end with a hyphen; max 40 chars)"

  validation {
    condition     = length(var.redis_name) >= 1 && length(var.redis_name) <= 40
    error_message = "redis_name must be between 1 and 40 characters."
  }

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,38}[a-z0-9])?$", var.redis_name))
    error_message = "redis_name must start with a lowercase letter, contain only lowercase letters, digits, and hyphens, and not end with a hyphen."
  }
}

variable "tier" {
  type        = string
  default     = "BASIC"
  description = "Service tier: BASIC (single node) or STANDARD_HA (cross-zone replication, automatic failover)"

  validation {
    condition     = contains(["BASIC", "STANDARD_HA"], var.tier)
    error_message = "tier must be one of: BASIC, STANDARD_HA."
  }
}

variable "memory_size_gb" {
  type        = number
  default     = 1
  description = "Instance memory size in GiB"

  validation {
    condition     = var.memory_size_gb >= 1 && var.memory_size_gb <= 300
    error_message = "memory_size_gb must be between 1 and 300."
  }

  validation {
    # google_redis_instance.memory_size_gb is an integer field; a fractional value here
    # would otherwise only fail with an opaque provider type-conversion error at apply time.
    condition     = var.memory_size_gb == floor(var.memory_size_gb)
    error_message = "memory_size_gb must be a whole number."
  }
}

variable "redis_version" {
  type        = string
  default     = "REDIS_7_2"
  description = "Redis version"

  validation {
    condition     = contains(["REDIS_7_2", "REDIS_7_0"], var.redis_version)
    error_message = "redis_version must be one of: REDIS_7_2, REDIS_7_0."
  }
}

variable "auth_enabled" {
  type        = bool
  default     = true
  description = "Require an AUTH string to connect"
}

variable "transit_encryption_mode" {
  type        = string
  default     = "DISABLED"
  description = "In-transit (TLS) encryption mode. DISABLED (the default) sends cache traffic, and (when auth_enabled is true) the AUTH string, unencrypted over the VPC."

  validation {
    condition     = contains(["DISABLED", "SERVER_AUTHENTICATION"], var.transit_encryption_mode)
    error_message = "transit_encryption_mode must be one of: DISABLED, SERVER_AUTHENTICATION."
  }
}

variable "authorized_network" {
  type        = string
  default     = ""
  description = "VPC network self-link to connect to. Empty = the project's default network."
}

variable "connect_mode" {
  type        = string
  default     = "DIRECT_PEERING"
  description = "How the instance connects to authorized_network"

  validation {
    condition     = contains(["DIRECT_PEERING", "PRIVATE_SERVICE_ACCESS"], var.connect_mode)
    error_message = "connect_mode must be one of: DIRECT_PEERING, PRIVATE_SERVICE_ACCESS."
  }
}

variable "reserved_ip_range" {
  type        = string
  default     = ""
  description = "CIDR /29 or named allocated range reserved for the instance. Empty = GCP picks one automatically."
}

variable "maxmemory_policy" {
  type        = string
  default     = "noeviction"
  description = "Redis eviction policy applied once memory_size_gb is full"

  validation {
    condition = contains([
      "noeviction", "allkeys-lru", "volatile-lru", "allkeys-random",
      "volatile-random", "volatile-ttl", "allkeys-lfu", "volatile-lfu"
    ], var.maxmemory_policy)
    error_message = "maxmemory_policy must be a valid Redis maxmemory-policy value."
  }
}

variable "persistence_mode" {
  type        = string
  default     = "DISABLED"
  description = "RDB snapshot persistence"

  validation {
    condition     = contains(["DISABLED", "RDB"], var.persistence_mode)
    error_message = "persistence_mode must be one of: DISABLED, RDB."
  }
}

variable "rdb_snapshot_period" {
  type        = string
  default     = "TWENTY_FOUR_HOURS"
  description = "RDB snapshot interval. Only used when persistence_mode is RDB."

  validation {
    condition     = contains(["ONE_HOUR", "SIX_HOURS", "TWELVE_HOURS", "TWENTY_FOUR_HOURS"], var.rdb_snapshot_period)
    error_message = "rdb_snapshot_period must be one of: ONE_HOUR, SIX_HOURS, TWELVE_HOURS, TWENTY_FOUR_HOURS."
  }
}

variable "maintenance_day" {
  type        = string
  default     = ""
  description = "Day of week for the scheduled maintenance window. Empty disables a fixed window."

  validation {
    condition     = contains(["", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"], var.maintenance_day)
    error_message = "maintenance_day must be empty or one of: MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY, SATURDAY, SUNDAY."
  }
}

variable "maintenance_start_hour" {
  type        = number
  default     = 2
  description = "Maintenance window start hour, UTC 24h. Only used when maintenance_day is set."

  validation {
    condition     = var.maintenance_start_hour >= 0 && var.maintenance_start_hour <= 23
    error_message = "maintenance_start_hour must be between 0 and 23."
  }

  validation {
    # Feeds google.type.TimeOfDay.hours, an integer field.
    condition     = var.maintenance_start_hour == floor(var.maintenance_start_hour)
    error_message = "maintenance_start_hour must be a whole number."
  }
}

variable "replica_count" {
  type        = number
  default     = 0
  description = "Number of exposed cross-zone read replicas (0-5). Only supported when tier is STANDARD_HA. STANDARD_HA always allocates a standby node for failover regardless of this value; 0 just means that node isn't exposed as a readable replica."

  validation {
    condition     = var.replica_count >= 0 && var.replica_count <= 5
    error_message = "replica_count must be between 0 and 5."
  }

  validation {
    # google_redis_instance.replica_count is an integer field.
    condition     = var.replica_count == floor(var.replica_count)
    error_message = "replica_count must be a whole number."
  }

  # TF 1.9+ cross-variable validation.
  validation {
    condition     = var.replica_count == 0 || var.tier == "STANDARD_HA"
    error_message = "replica_count requires tier = STANDARD_HA."
  }
}

variable "gcp_project_id" {
  type        = string
  default     = ""
  description = "GCP project ID override. Empty = inferred from the deploy credentials."
}
