terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 5.100 is the release this blueprint's resource schemas were checked against
      # (aws_elasticache_serverless_cache, and engine = "valkey" on users and user groups).
      version = "~> 5.100"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
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
