terraform {
  # Cross-variable validation (e.g. aliases referencing acm_certificate_arn) requires TF 1.9+.
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
  # Credentials are injected by the Qovery engine from the cluster's cloud configuration
  # (credentials.default: cluster). CloudFront is a global service, but the AWS provider
  # still requires a region.

  # Optional: assume a role in the same AWS account as the engine-injected credentials.
  dynamic "assume_role" {
    for_each = var.role_arn != "" ? [var.role_arn] : []
    content {
      role_arn = assume_role.value
    }
  }
}
