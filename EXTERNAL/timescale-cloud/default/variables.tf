variable "timescale_project_id" {
  type        = string
  description = "Timescale Cloud project ID"

  validation {
    condition     = length(var.timescale_project_id) > 0
    error_message = "timescale_project_id must not be empty."
  }
}

variable "timescale_access_key" {
  type        = string
  sensitive   = true
  description = "Timescale Cloud client credentials — access key"

  validation {
    condition     = length(var.timescale_access_key) > 0
    error_message = "timescale_access_key must not be empty."
  }
}

variable "timescale_secret_key" {
  type        = string
  sensitive   = true
  description = "Timescale Cloud client credentials — secret key"

  validation {
    condition     = length(var.timescale_secret_key) > 0
    error_message = "timescale_secret_key must not be empty."
  }
}

variable "service_name" {
  type        = string
  description = "Timescale service name"

  validation {
    condition     = length(var.service_name) > 0 && length(var.service_name) <= 128
    error_message = "service_name must be 1-128 characters."
  }
}

variable "region_code" {
  type        = string
  default     = "us-east-1"
  description = "Region for the service (AWS-style code, e.g. us-east-1, eu-west-1)"
}

variable "milli_cpu" {
  type        = number
  default     = 500
  description = "CPU allocation in milli-CPU. Must pair with memory_gb per Timescale's allowed sizes."

  validation {
    condition     = contains([500, 1000, 2000, 4000, 8000, 16000, 32000], var.milli_cpu)
    error_message = "milli_cpu must be one of: 500, 1000, 2000, 4000, 8000, 16000, 32000."
  }
}

variable "memory_gb" {
  type        = number
  default     = 2
  description = "Memory in GB. Timescale pairs this with milli_cpu (500m/2GB, 1000m/4GB, 2000m/8GB, ...)."

  validation {
    condition     = contains([2, 4, 8, 16, 32, 64, 128], var.memory_gb)
    error_message = "memory_gb must be one of: 2, 4, 8, 16, 32, 64, 128."
  }
}

variable "ha_replicas" {
  type        = number
  default     = 0
  description = "Number of high-availability replicas (0-2)"

  validation {
    condition     = var.ha_replicas >= 0 && var.ha_replicas <= 2
    error_message = "ha_replicas must be between 0 and 2."
  }
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name, injected by the engine on every Terraform blueprint"
}

variable "qovery_cluster_id" {
  type        = string
  default     = ""
  description = "Qovery cluster short id (engine kubernetes_cluster_id); YACE matches RDS metrics on it."
}

variable "qovery_cluster_long_id" {
  type        = string
  default     = ""
  description = "Qovery cluster long id."
}

variable "qovery_user_provided_network" {
  type        = bool
  default     = false
  description = "True when the cluster VPC was provided by the user, so Qovery resource naming conventions do not apply to it."
}

variable "region" {
  type        = string
  description = "Qovery cluster region, injected by the engine on every Terraform blueprint"
}
