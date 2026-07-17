# -----------------------------------------------------------------------------
# Qovery Variables
# -----------------------------------------------------------------------------

variable "region" {
  description = "AWS region (from cluster, overridable)"
  type        = string
}

variable "qovery_cluster_name" {
  description = "Qovery cluster name (for tagging)"
  type        = string
}

# Qovery-injected infra tags (the engine sets them via base64 TF_VAR_qovery_*). Empty default so the
# module still plans if absent. Emitted as cost/identification tags on the bucket.
variable "qovery_cluster_id" {
  description = "Qovery cluster short id (engine kubernetes_cluster_id)."
  type        = string
  default     = ""
}

variable "qovery_cluster_long_id" {
  description = "Qovery cluster long id."
  type        = string
  default     = ""
}

variable "qovery_client_id" {
  description = "Qovery organization (client) short id."
  type        = string
  default     = ""
}

variable "qovery_environment_id" {
  description = "Qovery environment short id."
  type        = string
  default     = ""
}

variable "qovery_environment_long_id" {
  description = "Qovery environment long id."
  type        = string
  default     = ""
}

variable "qovery_project_id" {
  description = "Qovery project short id."
  type        = string
  default     = ""
}

variable "qovery_project_long_id" {
  description = "Qovery project long id."
  type        = string
  default     = ""
}

variable "qovery_aws_apn_id" {
  description = "AWS Partner Network id (AWS Marketplace measurement)."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# User Variables
# -----------------------------------------------------------------------------

variable "bucket_name" {
  description = "S3 bucket name (must be globally unique, 3–63 chars, letters/digits/hyphens only — automatically lowercased)"
  type        = string

  validation {
    condition     = length(var.bucket_name) >= 3 && length(var.bucket_name) <= 63
    error_message = "bucket_name must be between 3 and 63 characters."
  }

  validation {
    # Underscores, spaces, and other special chars are forbidden even after lowercasing.
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", lower(var.bucket_name)))
    error_message = "bucket_name must contain only letters, digits, and hyphens, and must start and end with a letter or digit. Underscores are not allowed."
  }

  validation {
    # AWS reserved prefix for S3 access point aliases.
    condition     = !startswith(lower(var.bucket_name), "xn--")
    error_message = "bucket_name must not start with 'xn--'."
  }

  validation {
    condition     = !endswith(lower(var.bucket_name), "-s3alias")
    error_message = "bucket_name must not end with '-s3alias'."
  }

  validation {
    # Bucket names that look like IP addresses are rejected by AWS.
    condition     = !can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+$", var.bucket_name))
    error_message = "bucket_name must not be formatted as an IP address (e.g. 192.168.1.1)."
  }
}

variable "versioning" {
  description = "Enable object versioning"
  type        = bool
  default     = true
}

variable "encryption" {
  description = "Enable server-side encryption (AES-256)"
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Allow bucket deletion even if it contains objects"
  type        = bool
  default     = false
}

variable "bucket_policy" {
  description = "Attach the default bucket policy"
  type        = bool
  default     = true
}
