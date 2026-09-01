variable "planetscale_service_token_id" {
  type        = string
  sensitive   = true
  description = "PlanetScale service token ID"

  validation {
    condition     = length(var.planetscale_service_token_id) > 0
    error_message = "planetscale_service_token_id must not be empty."
  }
}

variable "planetscale_service_token" {
  type        = string
  sensitive   = true
  description = "PlanetScale service token"

  validation {
    condition     = length(var.planetscale_service_token) > 0
    error_message = "planetscale_service_token must not be empty."
  }
}

variable "organization" {
  type        = string
  description = "PlanetScale organization name"

  validation {
    condition     = length(var.organization) > 0
    error_message = "organization must not be empty."
  }
}

variable "database_name" {
  type        = string
  description = "Database name. Created implicitly with the first branch (destroying the last branch destroys the database)."

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,64}$", var.database_name))
    error_message = "database_name must be 1-64 chars of letters, digits, hyphens, and underscores."
  }
}

variable "branch_name" {
  type        = string
  default     = "main"
  description = "Production branch name to create in the database"
}

variable "cluster_size" {
  type        = string
  default     = ""
  description = "Vitess production cluster size (e.g. PS-10, PS-20). Empty = provider/plan default."
}

variable "region" {
  type        = string
  default     = ""
  description = "PlanetScale region slug for the branch (e.g. us-east). Empty = organization default."
}

variable "role" {
  type        = string
  default     = "readwriter"
  description = "Access role for the generated password"

  validation {
    condition     = contains(["reader", "writer", "readwriter", "admin"], var.role)
    error_message = "role must be one of: reader, writer, readwriter, admin."
  }
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name, injected by the engine on every Terraform blueprint"
}

variable "qovery_cluster_id" {
  type        = string
  description = "Qovery cluster short id (engine kubernetes_cluster_id); YACE matches RDS metrics on it."
}

variable "qovery_cluster_long_id" {
  type        = string
  description = "Qovery cluster long id."
}

variable "qovery_user_provided_network" {
  type        = bool
  description = "True when the cluster VPC was provided by the user, so Qovery resource naming conventions do not apply to it."
}
