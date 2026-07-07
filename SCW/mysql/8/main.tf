# -----------------------------------------------------------------------------
# Scaleway Managed Database MySQL
# -----------------------------------------------------------------------------

# Scaleway tags are bare strings (no KV) — flatten cluster context into "key:value" entries.
locals {
  rdb_tags = [
    "managed-by:qovery-blueprint",
    "blueprint:scaleway-mysql",
    "cluster:${var.qovery_cluster_name}",
    "region:${var.region}",
    "instance:${var.instance_name}",

    # Native-parity Qovery context tags — values injected by the engine via TF_VAR_qovery_*.
    # Mirrors the engine's native Scaleway tag set (lib/scaleway/services/mysql).
    "cluster_id:${var.qovery_cluster_id}",
    "q_client_id:${var.qovery_client_id}",
    "q_environment_id:${var.qovery_environment_id}",
    "q_project_id:${var.qovery_project_id}",
  ]
}

resource "scaleway_rdb_instance" "this" {
  name           = "${var.qovery_cluster_name}-${var.instance_name}"
  node_type      = var.node_type
  engine         = var.engine_version
  is_ha_cluster  = var.is_ha_cluster
  disable_backup = !var.activate_backups

  volume_type = var.volume_type
  # Scaleway rejects volume_size_in_gb for lssd — size is fixed by node_type there.
  volume_size_in_gb = var.volume_type == "lssd" ? null : var.volume_size_gb

  # Initial admin user — required by the Scaleway provider on instance create.
  user_name = var.db_username
  password  = var.db_password

  region = var.region

  settings = {
    slow_query_log = var.slow_query_log ? "true" : "false"
  }

  tags = local.rdb_tags
}

resource "scaleway_rdb_database" "this" {
  instance_id = scaleway_rdb_instance.this.id
  name        = var.db_name
}

# ACL is only created when publicly_accessible. Without an ACL, the instance is unreachable
# from outside Scaleway's private network — which is the expected default for private DBs.
resource "scaleway_rdb_acl" "this" {
  count       = var.publicly_accessible ? 1 : 0
  instance_id = scaleway_rdb_instance.this.id

  acl_rules {
    ip          = var.acl_allowed_cidr
    description = "qovery-blueprint allowed CIDR"
  }
}
