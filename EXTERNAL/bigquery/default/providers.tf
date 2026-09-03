terraform {
  # Cross-variable validation (default_table_expiration_ms against its "0 = unset" sentinel)
  # requires TF 1.9+.
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

# EXTERNAL blueprint: there are no cluster cloud credentials to reuse, so the caller supplies a
# service account key. That is also what makes the blueprint usable from an AWS, Azure or
# Scaleway cluster — nothing here reads the cluster's own cloud identity.
provider "google" {
  project     = var.gcp_project_id
  credentials = var.gcp_service_account_key
}
