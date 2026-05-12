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

# -----------------------------------------------------------------------------
# User Variables
# -----------------------------------------------------------------------------

variable "bucket_name" {
  description = "S3 bucket name (must be globally unique)"
  type        = string
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
