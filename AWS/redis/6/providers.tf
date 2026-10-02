terraform {
  # Cross-variable validation (redis_password referencing import_identifier) requires TF 1.9+.
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}

provider "aws" {
  region = var.region
}
