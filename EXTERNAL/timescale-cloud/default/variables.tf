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
  description = "1–128 chars"

  validation {
    condition     = length(var.service_name) > 0 && length(var.service_name) <= 128
    error_message = "service_name must be 1-128 characters."
  }
}

variable "region_code" {
  type        = string
  default     = "us-east-1"
  description = "AWS-style code, e.g. us-east-1, eu-west-1"
}

variable "milli_cpu" {
  type        = number
  default     = 500
  description = "CPU in milli-CPU; must pair with memory_gb"

  validation {
    condition     = contains([500, 1000, 2000, 4000, 8000, 16000, 32000], var.milli_cpu)
    error_message = "milli_cpu must be one of: 500, 1000, 2000, 4000, 8000, 16000, 32000."
  }
}

variable "memory_gb" {
  type        = number
  default     = 2
  description = "Memory in GB; must pair with milli_cpu (500m/2GB, 1000m/4GB, …)"

  validation {
    condition     = contains([2, 4, 8, 16, 32, 64, 128], var.memory_gb)
    error_message = "memory_gb must be one of: 2, 4, 8, 16, 32, 64, 128."
  }
}

variable "ha_replicas" {
  type        = number
  default     = 0
  description = "High-availability replicas, 0–2"

  validation {
    condition     = var.ha_replicas >= 0 && var.ha_replicas <= 2
    error_message = "ha_replicas must be between 0 and 2."
  }
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name, injected from the qbm.yml `cluster.name` context variable"
}

variable "region" {
  type        = string
  description = "Qovery cluster region, injected from the qbm.yml `cluster.region` context variable"
}
