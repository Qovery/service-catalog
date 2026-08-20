terraform {
  required_version = ">= 1.9"

  required_providers {
    timescale = {
      source  = "timescale/timescale"
      version = "~> 2.0"
    }
  }
}

provider "timescale" {
  project_id = var.timescale_project_id
  access_key = var.timescale_access_key
  secret_key = var.timescale_secret_key
}
