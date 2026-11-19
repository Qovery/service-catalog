terraform {
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
  # Credentials injected by the Qovery engine from the cluster (credentials.default: cluster).

  # Optional: assume a role in the same AWS account as the engine-injected credentials.
  dynamic "assume_role" {
    for_each = var.role_arn != "" ? [var.role_arn] : []
    content {
      role_arn = assume_role.value
    }
  }
}
