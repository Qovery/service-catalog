terraform {
  # Write-only arguments (password_wo) require TF 1.11+.
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # password_wo on aws_db_instance is not in early 5.x.
      version = ">= 5.100.0, < 6.0.0"
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
