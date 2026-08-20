terraform {
  required_version = ">= 1.9"

  required_providers {
    temporalcloud = {
      source  = "temporalio/temporalcloud"
      version = "~> 1.0"
    }
  }
}

provider "temporalcloud" {
  api_key = var.temporal_cloud_api_key
}
