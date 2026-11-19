terraform {
  # Cross-variable validation (valkey_password referencing import_identifier) requires TF 1.9+.
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # engine = "valkey" is absent from older 5.x releases; 5.100 is what this blueprint was validated against.
      version = "~> 5.100"
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

  # Optional: assume a role in the same AWS account as the engine-injected credentials.
  dynamic "assume_role" {
    for_each = var.role_arn != "" ? [var.role_arn] : []
    content {
      role_arn = assume_role.value
    }
  }
}
