# -----------------------------------------------------------------------------
# Scaleway Managed Database PostgreSQL
# -----------------------------------------------------------------------------

# Scaleway tags are bare strings (no KV) — flatten cluster context into "key:value" entries.
locals {
  rdb_tags = [
    "managed-by:qovery-blueprint",
    "blueprint:scaleway-managed-postgresql",
    "cluster:${var.qovery_cluster_name}",
    "region:${var.region}",
    "instance:${var.instance_name}",
  ]
}

resource "scaleway_rdb_instance" "this" {
  name           = "${var.qovery_cluster_name}-${var.instance_name}"
  node_type      = var.node_type
  engine         = var.engine_version
  is_ha_cluster  = var.is_ha_cluster
  disable_backup = !var.activate_backups

  volume_type       = var.volume_type
  volume_size_in_gb = var.volume_size_gb

  # Initial admin user — required by the Scaleway provider on instance create.
  user_name = var.db_username
  password  = var.db_password

  region = var.region

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
