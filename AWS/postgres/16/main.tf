# Suffix the final-snapshot name with a timestamp so successive create/destroy cycles
# don't collide on an existing snapshot id. Combined with ignore_changes on
# final_snapshot_identifier (below), this keeps plans clean — timestamp() rotates every plan.
locals {
  final_snapshot_timestamp = replace(timestamp(), "/[- TZ:]/", "")
  final_snapshot_raw       = "${var.qovery_cluster_name}-${replace(lower(var.db_name), "_", "-")}-${local.final_snapshot_timestamp}"
  # AWS requires the snapshot id to begin with a letter and contain only alphanumerics/hyphens.
  final_snapshot_cleaned = replace(local.final_snapshot_raw, "/[^a-zA-Z0-9-]/", "")
  final_snapshot_name    = can(regex("^[a-zA-Z]", local.final_snapshot_cleaned)) ? local.final_snapshot_cleaned : "snap-${local.final_snapshot_cleaned}"
}

# Adopt an existing RDS instance when import_identifier is set (migration), else create.
import {
  for_each = var.import_identifier != "" ? toset([var.import_identifier]) : toset([])
  to       = aws_db_instance.this
  id       = each.value
}

resource "aws_db_instance" "this" {
  # On adoption, keep the live identifier so the import is a no-op (renaming forces replacement).
  identifier = var.import_identifier != "" ? var.import_identifier : replace(lower(var.db_name), "_", "-")

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.instance_class
  port           = var.port

  allocated_storage = var.allocated_storage
  storage_type      = var.storage_type
  storage_encrypted = var.storage_encrypted
  # gp2 doesn't support provisioned IOPS — AWS rejects iops unless storage is io1/io2/gp3.
  iops = var.disk_iops == 0 || !contains(["io1", "io2", "gp3"], var.storage_type) ? null : var.disk_iops

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  ca_cert_identifier = var.ca_cert_identifier

  # Network
  multi_az             = var.multi_az
  publicly_accessible  = var.publicly_accessible
  db_subnet_group_name = var.db_subnet_group_name == "" ? null : var.db_subnet_group_name

  # Maintenance / upgrades
  apply_immediately           = var.apply_changes_now
  allow_major_version_upgrade = var.allow_major_version_upgrade
  auto_minor_version_upgrade  = var.auto_minor_version_upgrade
  maintenance_window          = var.preferred_maintenance_window

  # Backups
  backup_retention_period   = var.backup_retention_period
  backup_window             = var.preferred_backup_window
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = local.final_snapshot_name
  delete_automated_backups  = var.delete_automated_backups
  copy_tags_to_snapshot     = var.copy_tags_to_snapshot

  # Monitoring
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  monitoring_interval                   = var.monitoring_interval
  monitoring_role_arn                   = var.monitoring_interval > 0 ? var.monitoring_role_arn : null

  # Misc
  option_group_name                   = var.option_group_name == "" ? null : var.option_group_name
  deletion_protection                 = var.deletion_protection
  iam_database_authentication_enabled = var.iam_database_authentication_enabled
  dedicated_log_volume                = var.dedicated_log_volume

  tags = {
    Name          = var.db_name
    ManagedBy     = "qovery-blueprint"
    Blueprint     = "aws-rds-postgresql"
    ClusterName   = var.qovery_cluster_name
    ServiceFamily = "postgres"
  }

  lifecycle {
    ignore_changes = [
      # Adoption: never mutate a live DB's running version. Catalog hard-codes the major per
      # version dir; adopted instances may run a different minor (e.g. 8.0 vs 8.4) or major.
      engine_version,
      # Adoption: master password is write-only — AWS never returns it, so an import always shows
      # a spurious "password will be set" change. Ignore it so adoption never rotates the live password.
      password,
      # timestamp() rotates every plan — only meaningful when a final snapshot is actually taken
      final_snapshot_identifier,
      # No list type in qbm.yml — defer to a manifest schema extension
      enabled_cloudwatch_logs_exports,
      # AWS may auto-replace the param group during minor upgrades; user can override via console
      parameter_group_name,
      # Will turn into a managed input when the storage autoscale feature is added
      max_allocated_storage,
      # Adoption: enhanced monitoring needs a cluster-specific IAM role ARN the native path
      # resolved via a data source; not reproducible as a static default, so leave it as-is.
      monitoring_interval,
      monitoring_role_arn,
    ]
  }
}
