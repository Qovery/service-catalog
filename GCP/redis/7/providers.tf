terraform {
  # Cross-variable validation (e.g. replica_count referencing tier) requires TF 1.9+.
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id != "" ? var.gcp_project_id : null
  region  = var.region
}
