locals {
  # The live id: renaming forces replacement, so adoption keeps it as is.
  redis_identifier = var.import_identifier

  # Stamped from time_static, not timestamp(): stable across plans, so the attribute needs no
  # ignore_changes and skip_final_snapshot keeps working after adoption.
  final_snapshot_timestamp = replace(time_static.created.rfc3339, "/[-:TZ]/", "")
  final_snapshot_raw       = "${local.redis_identifier}-final-snap-${local.final_snapshot_timestamp}"
  # AWS requires the snapshot id to begin with a letter and contain only alphanumerics/hyphens.
  final_snapshot_cleaned = replace(local.final_snapshot_raw, "/[^a-zA-Z0-9-]/", "")
  final_snapshot_name    = can(regex("^[a-zA-Z]", local.final_snapshot_cleaned)) ? local.final_snapshot_cleaned : "snap-${local.final_snapshot_cleaned}"
}

# Adoption only: this blueprint never creates a cluster (see import_identifier in variables.tf).
import {
  to = aws_elasticache_cluster.this
  id = var.import_identifier
}

resource "time_static" "created" {
  triggers = {
    identifier = local.redis_identifier
  }
}

# Single-node cluster, the shape native Qovery-managed Redis used before replication groups.
# It has no auth token and no TLS: AWS only allows those on a replication group.
resource "aws_elasticache_cluster" "this" {
  cluster_id = local.redis_identifier

  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.instance_class
  num_cache_nodes      = 1
  port                 = var.port
  parameter_group_name = var.parameter_group_name

  # Maintenance / upgrades
  apply_immediately  = var.apply_changes_now
  maintenance_window = lower(var.preferred_maintenance_window)

  # Backups
  snapshot_window           = var.backup_retention_period > 0 ? var.preferred_backup_window : null
  snapshot_retention_limit  = var.backup_retention_period
  final_snapshot_identifier = var.skip_final_snapshot ? null : local.final_snapshot_name

  # subnet_group_name and security_group_ids are left unset: both are Optional+Computed, so the
  # adopted cluster keeps its live network.

  tags = {
    Name            = var.redis_name
    ManagedBy       = "qovery-blueprint"
    Blueprint       = "aws-elasticache-redis-node"
    ClusterName     = var.qovery_cluster_name
    ServiceFamily   = "redis"
    cluster_id      = var.qovery_cluster_id
    cluster_long_id = var.qovery_cluster_long_id
    region          = var.region
  }

  lifecycle {
    ignore_changes = [
      # AWS reports its own version format back (e.g. 5.0.6 vs 5.0); never mutate a live engine.
      engine_version,
      # ForceNew: a mismatch would replace the adopted cluster with a new one that has no auth.
      port,
      # Same list the native Qovery template ignores on this shape.
      maintenance_window,
      log_delivery_configuration,
      notification_topic_arn,
      auto_minor_version_upgrade,
      # Preserve native tags on adoption: cluster_id is what the YACE exporter reads for metrics
      tags,
    ]
  }
}

locals {
  redis_host = aws_elasticache_cluster.this.cache_nodes[0].address
}
