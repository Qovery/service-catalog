variable "atlas_public_key" {
  type        = string
  description = "MongoDB Atlas programmatic API key — public key"

  validation {
    condition     = length(var.atlas_public_key) > 0
    error_message = "atlas_public_key must not be empty."
  }
}

variable "atlas_private_key" {
  type        = string
  sensitive   = true
  description = "MongoDB Atlas programmatic API key — private key"

  validation {
    condition     = length(var.atlas_private_key) > 0
    error_message = "atlas_private_key must not be empty."
  }
}

variable "project_id" {
  type        = string
  description = "Existing MongoDB Atlas project ID the cluster is created in"

  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must not be empty."
  }
}

variable "cluster_name" {
  type        = string
  description = "Cluster name (letters, digits, hyphens; max 64 chars)"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{1,64}$", var.cluster_name))
    error_message = "cluster_name must be 1-64 chars of letters, digits, and hyphens."
  }
}

variable "provider_name" {
  type        = string
  default     = "AWS"
  description = "Backing cloud provider for the cluster"

  validation {
    condition     = contains(["AWS", "GCP", "AZURE"], var.provider_name)
    error_message = "provider_name must be one of: AWS, GCP, AZURE."
  }
}

variable "region_name" {
  type        = string
  default     = "US_EAST_1"
  description = "Atlas region name for the backing provider (e.g. US_EAST_1 for AWS, US_CENTRAL1 for GCP, US_EAST_2 for AZURE)"
}

variable "instance_size" {
  type        = string
  default     = "M10"
  description = "Dedicated cluster instance size (M10 and up). Shared tiers (M0/M2/M5) are not supported by this blueprint."

  validation {
    condition     = can(regex("^M[0-9]+$", var.instance_size)) && var.instance_size != "M0" && var.instance_size != "M2" && var.instance_size != "M5"
    error_message = "instance_size must be a dedicated tier (M10 or larger); shared tiers M0/M2/M5 are not supported."
  }
}

variable "mongo_db_major_version" {
  type        = string
  default     = "7.0"
  description = "MongoDB major version (e.g. 6.0, 7.0, 8.0)"
}

variable "backup_enabled" {
  type        = bool
  default     = true
  description = "Enable cloud backup for the cluster"
}

# Database user
variable "db_username" {
  type        = string
  default     = "qoveryadmin"
  description = "Database user to create (SCRAM auth, readWriteAnyDatabase)"

  validation {
    condition     = length(var.db_username) > 0
    error_message = "db_username must not be empty."
  }
}

variable "db_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Password for the database user. Empty generates a 32-character alphanumeric password."

  validation {
    condition     = var.db_password == "" || length(var.db_password) >= 8
    error_message = "db_password must be at least 8 characters."
  }
}

# Network access
variable "ip_access_list_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "CIDR allowed to reach the cluster. Defaults to 0.0.0.0/0 (open); restrict this in production."
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name, injected from the qbm.yml `cluster.name` context variable"
}

variable "region" {
  type        = string
  description = "Qovery cluster region, injected from the qbm.yml `cluster.region` context variable"
}
