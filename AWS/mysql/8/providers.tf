terraform {
  # Cross-variable validation (e.g. allocated_storage referencing storage_type) requires TF 1.9+.
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}
