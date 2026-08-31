locals {
  regions = [for r in split(",", var.regions) : trimspace(r) if trimspace(r) != ""]
}

resource "temporalcloud_namespace" "this" {
  name               = var.namespace_name
  regions            = local.regions
  retention_days     = var.retention_days
  api_key_auth       = true
  accepted_client_ca = var.accepted_client_ca == "" ? null : var.accepted_client_ca
}
