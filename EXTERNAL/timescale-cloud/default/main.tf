resource "timescale_service" "this" {
  name        = var.service_name
  region_code = var.region_code
  milli_cpu   = var.milli_cpu
  memory_gb   = var.memory_gb
  ha_replicas = var.ha_replicas
}
