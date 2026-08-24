# -----------------------------------------------------------------------------
# GCP Memorystore for Redis
# -----------------------------------------------------------------------------

locals {
  # GCP label values allow only lowercase letters, digits, underscores, and hyphens.
  # Qovery short ids are already safe, but sanitize defensively (e.g. a hand-edited
  # qovery_cluster_name with spaces or uppercase letters).
  labels = {
    for k, v in {
      managed_by       = "qovery-blueprint"
      blueprint        = "gcp-memorystore-redis"
      cluster_name     = var.qovery_cluster_name
      cluster_id       = var.qovery_cluster_id
      q_client_id      = var.qovery_client_id
      q_environment_id = var.qovery_environment_id
      q_project_id     = var.qovery_project_id
    } : k => lower(replace(v, "/[^a-zA-Z0-9_-]/", "-"))
  }

  # GCP always requires a standby node once STANDARD_HA is selected: replicaCount must be
  # exactly 1 when read replicas are disabled, or 1-5 when enabled. 0 is only valid for BASIC.
  # var.replica_count stays the user-facing "extra read replicas" knob (0 = none exposed);
  # this floors the value GCP actually receives without changing that contract.
  gcp_replica_count = var.tier == "STANDARD_HA" ? max(var.replica_count, 1) : 0
}

resource "google_redis_instance" "this" {
  name         = var.redis_name
  display_name = var.redis_name
  region       = var.region

  tier           = var.tier
  memory_size_gb = var.memory_size_gb
  redis_version  = var.redis_version

  auth_enabled            = var.auth_enabled
  transit_encryption_mode = var.transit_encryption_mode

  # authorized_network and reserved_ip_range are Optional+Computed in the google provider:
  # leaving them null when unset keeps the GCP-assigned defaults in state instead of
  # producing a perpetual diff.
  authorized_network = var.authorized_network != "" ? var.authorized_network : null
  connect_mode        = var.connect_mode
  reserved_ip_range   = var.reserved_ip_range != "" ? var.reserved_ip_range : null

  redis_configs = {
    "maxmemory-policy" = var.maxmemory_policy
  }

  # Read replicas are only valid on STANDARD_HA; validated in variables.tf.
  replica_count      = local.gcp_replica_count
  read_replicas_mode = var.replica_count > 0 ? "READ_REPLICAS_ENABLED" : "READ_REPLICAS_DISABLED"

  persistence_config {
    persistence_mode    = var.persistence_mode
    rdb_snapshot_period = var.persistence_mode == "RDB" ? var.rdb_snapshot_period : null
  }

  dynamic "maintenance_policy" {
    for_each = var.maintenance_day != "" ? [1] : []
    content {
      weekly_maintenance_window {
        day = var.maintenance_day
        start_time {
          hours   = var.maintenance_start_hour
          minutes = 0
          seconds = 0
          nanos   = 0
        }
      }
    }
  }

  labels = local.labels
}
