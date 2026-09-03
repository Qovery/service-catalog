terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# EXTERNAL blueprint: the AWS credentials come in as variables rather than from the cluster, which
# is what lets a GCP, Azure or Scaleway cluster consume Bedrock — and lets an AWS cluster reach a
# Bedrock account other than its own.
provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}
