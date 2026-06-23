terraform {
  # Cross-variable validation (acl_allowed_cidr referencing publicly_accessible) requires TF 1.9+.
  required_version = ">= 1.9"

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.0"
    }
  }
}

provider "scaleway" {
  region = var.region
}
