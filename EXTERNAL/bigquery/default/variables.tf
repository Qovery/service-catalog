variable "gcp_service_account_key" {
  type        = string
  sensitive   = true
  description = "JSON key of the Google service account Terraform authenticates as. Needs BigQuery Admin on the project, plus Service Account Admin and Service Account Key Admin when create_service_account is true."

  validation {
    condition     = can(jsondecode(var.gcp_service_account_key))
    error_message = "gcp_service_account_key must be the raw JSON key file contents, not a file path or a base64 blob."
  }
}

variable "gcp_project_id" {
  type        = string
  description = "Google Cloud project the dataset is created in"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.gcp_project_id))
    error_message = "gcp_project_id must be 6-30 chars: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "dataset_id" {
  type        = string
  description = "BigQuery dataset id, up to 1024 chars of letters, digits and underscores (BigQuery rejects hyphens)"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_]+$", var.dataset_id)) && length(var.dataset_id) <= 1024
    error_message = "dataset_id must be 1-1024 chars of letters, digits and underscores."
  }
}

variable "location" {
  type        = string
  default     = "US"
  description = "Dataset location: a multi-region (US, EU) or a region (europe-west1, us-central1). Immutable — changing it recreates the dataset and destroys its tables."
}

variable "friendly_name" {
  type        = string
  default     = ""
  description = "Display name shown in the BigQuery console. Empty = show the dataset id."
}

variable "dataset_description" {
  type        = string
  default     = ""
  description = "Free-text description attached to the dataset. Empty = no description."
}

variable "default_table_expiration_ms" {
  type        = number
  default     = 0
  description = "Lifetime in milliseconds of a table created without its own expiration. 0 = tables never expire. BigQuery rejects anything below 3600000 (1 hour)."

  validation {
    condition     = var.default_table_expiration_ms == 0 || var.default_table_expiration_ms >= 3600000
    error_message = "default_table_expiration_ms must be 0 (no expiration) or at least 3600000 (1 hour)."
  }
}

variable "default_partition_expiration_ms" {
  type        = number
  default     = 0
  description = "Lifetime in milliseconds of a partition in a partitioned table created without its own expiration. 0 = partitions never expire."

  validation {
    condition     = var.default_partition_expiration_ms == 0 || var.default_partition_expiration_ms >= 3600000
    error_message = "default_partition_expiration_ms must be 0 (no expiration) or at least 3600000 (1 hour)."
  }
}

variable "delete_contents_on_destroy" {
  type        = bool
  default     = false
  description = "Allow destroying the dataset while it still holds tables. Left false, a destroy fails rather than silently dropping data."
}

variable "create_service_account" {
  type        = bool
  default     = true
  description = "Create a dedicated service account with a key so an application running on any cloud can reach the dataset. Set false to manage access yourself."
}

variable "service_account_id" {
  type        = string
  default     = ""
  description = "Leave empty — derived from the dataset id as qovery-bq-<dataset>. Set it only when that derived id collides with an existing service account in the project."

  validation {
    condition     = var.service_account_id == "" || can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.service_account_id))
    error_message = "service_account_id must be 6-30 chars: lowercase letters, digits and hyphens, starting with a letter and ending with a letter or digit."
  }
}

variable "service_account_role" {
  type        = string
  default     = "roles/bigquery.dataEditor"
  description = "Dataset-level role granted to the created service account"

  validation {
    condition = contains([
      "roles/bigquery.dataViewer",
      "roles/bigquery.dataEditor",
      "roles/bigquery.dataOwner",
    ], var.service_account_role)
    error_message = "service_account_role must be one of: roles/bigquery.dataViewer, roles/bigquery.dataEditor, roles/bigquery.dataOwner."
  }
}

variable "grant_job_user" {
  type        = bool
  default     = true
  description = "Also grant the created service account roles/bigquery.jobUser on the project. Without it the account can read and write table data but cannot run a query — job creation is a project-level right that no dataset role carries."
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name, injected from the qbm.yml `cluster.name` context variable"
}
