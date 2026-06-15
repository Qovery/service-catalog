# -----------------------------------------------------------------------------
# Scaleway Managed Database PostgreSQL
# -----------------------------------------------------------------------------

resource "scaleway_rdb_instance" "this" {
  name           = "${var.qovery_cluster_name}-${var.instance_name}"
  node_type      = var.node_type
  engine         = "16"
  is_ha_cluster  = var.is_ha_cluster
  disable_backup = false

  volume_type       = "lssd"
  volume_size_in_gb = var.volume_size_gb

  tags = ["managed-by:qovery-blueprint", "cluster:${var.qovery_cluster_name}"]
}

resource "scaleway_rdb_database" "this" {
  instance_id = scaleway_rdb_instance.this.id
  name        = var.db_name
}

resource "scaleway_rdb_user" "this" {
  instance_id = scaleway_rdb_instance.this.id
  name        = var.db_username
  password    = var.db_password
  is_admin    = true
}
