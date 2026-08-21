terraform {
  required_version = ">= 1.9"

  required_providers {
    redpanda = {
      source  = "redpanda-data/redpanda"
      version = "~> 2.0"
    }
  }
}

provider "redpanda" {
  client_id     = var.redpanda_client_id
  client_secret = var.redpanda_client_secret
}
