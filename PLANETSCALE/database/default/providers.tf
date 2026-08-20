terraform {
  required_version = ">= 1.9"

  required_providers {
    planetscale = {
      source  = "planetscale/planetscale"
      version = "~> 1.0"
    }
  }
}

provider "planetscale" {
  service_token_id = var.planetscale_service_token_id
  service_token    = var.planetscale_service_token
}
