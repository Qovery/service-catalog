# Qovery-injected variables (auto-filled from cluster context)
variable "region" {
  type        = string
  description = "Scaleway region"
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name (for tagging)"
}

# User-provided variables
variable "bucket_name" {
  type        = string
  description = "Object Storage bucket name (globally unique, 3–63 chars, letters/digits/hyphens only — automatically lowercased)"

  validation {
    condition     = length(var.bucket_name) >= 3 && length(var.bucket_name) <= 63
    error_message = "bucket_name must be between 3 and 63 characters."
  }

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", lower(var.bucket_name)))
    error_message = "bucket_name must contain only letters, digits, and hyphens, and must start and end with a letter or digit. Underscores are not allowed."
  }

  validation {
    condition     = !can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+$", var.bucket_name))
    error_message = "bucket_name must not be formatted as an IP address."
  }
}

variable "acl" {
  type        = string
  default     = "private"
  description = "Bucket ACL (private, public-read, public-read-write)"

  validation {
    condition     = contains(["private", "public-read", "public-read-write"], var.acl)
    error_message = "acl must be one of: private, public-read, public-read-write."
  }
}

variable "versioning_enabled" {
  type        = bool
  default     = false
  description = "Enable object versioning"
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Allow bucket deletion even if it contains objects"
}
