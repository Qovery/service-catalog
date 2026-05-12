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
  description = "Object Storage bucket name (must be unique within region)"
}

variable "acl" {
  type        = string
  default     = "private"
  description = "Bucket ACL (private, public-read, public-read-write)"
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
