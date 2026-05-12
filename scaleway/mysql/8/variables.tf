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
  description = "Database instance name"
}

variable "db_name" {
  type        = string
  description = "Database name"
}

variable "db_username" {
  type        = string
  description = "Database user name"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Database user password (min 8 characters)"
}

variable "node_type" {
  type        = string
  default     = "DB-DEV-S"
  description = "Node type (e.g. DB-DEV-S, DB-GP-XS)"
}

variable "volume_size_gb" {
  type        = number
  default     = 5
  description = "Volume size in GB"
}

variable "is_ha_cluster" {
  type        = bool
  default     = false
  description = "Enable high availability cluster mode"
}
