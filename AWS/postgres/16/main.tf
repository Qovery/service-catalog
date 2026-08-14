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

# Attach to the Qovery cluster network by default, like native managed
# databases. Cluster bootstrap tags the cluster VPC with
# ClusterId = <cluster short id> and creates an RDS subnet group named after
# the VPC id. Lookups are skipped when the user overrides the value or when
# adopting an existing instance: both attributes are Optional+Computed in the
# AWS provider, so null keeps the live values.
data "aws_vpc" "cluster" {
  count = var.db_subnet_group_name == "" && var.import_identifier == "" ? 1 : 0

  filter {
    name   = "tag:ClusterId"
    values = [var.qovery_cluster_id]
  }
}

data "aws_security_group" "cluster_workers" {
  count = var.security_group_ids == "" && var.import_identifier == "" ? 1 : 0

  filter {
    name   = "tag:Name"
    values = ["qovery-${var.qovery_cluster_id}-sg-workers", "qovery-eks-workers"]
  }

  filter {
    name   = "tag:kubernetes.io/cluster/qovery-${var.qovery_cluster_id}"
    values = ["owned"]
  }
}

locals {
  db_subnet_group_name = (
    var.db_subnet_group_name != "" ? var.db_subnet_group_name
    : var.import_identifier != "" ? null
    : data.aws_vpc.cluster[0].id
  )
  vpc_security_group_ids = (
    var.security_group_ids != "" ? [for id in split(",", var.security_group_ids) : trimspace(id)]
    : var.import_identifier != "" ? null
    : [data.aws_security_group.cluster_workers[0].id]
  )
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
  multi_az               = var.multi_az
  publicly_accessible    = var.publicly_accessible
  db_subnet_group_name   = local.db_subnet_group_name
  vpc_security_group_ids = local.vpc_security_group_ids

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

    # Native-parity tags injected by the engine via TF_VAR_qovery_*. cluster_id is what the YACE
    # CloudWatch exporter filters on for DB metrics; the rest mirror the native database_tags.
    cluster_id            = var.qovery_cluster_id
    cluster_long_id       = var.qovery_cluster_long_id
    region                = var.region
    q_client_id           = var.qovery_client_id
    q_environment_id      = var.qovery_environment_id
    q_environment_long_id = var.qovery_environment_long_id
    q_project_id          = var.qovery_project_id
    q_project_long_id     = var.qovery_project_long_id
    "aws-apn-id"          = var.qovery_aws_apn_id
  }

  lifecycle {
    ignore_changes = [
      # Adoption: never mutate a live DB's running version. Catalog hard-codes the major per
      # version dir; adopted instances may run a different minor (e.g. 8.0 vs 8.4) or major.
      engine_version,
      # Master password is write-only (AWS never returns it) → on import the state is empty and any
      # configured value shows a perpetual diff, so ignore to keep adoption plans clean. ignore_changes
      # can't be conditional, so rotation isn't managed here either — rotate out-of-band.
      password,
      # timestamp() rotates every plan — only meaningful when a final snapshot is actually taken
      final_snapshot_identifier,
      # No list type in qbm.yml — defer to a manifest schema extension
      enabled_cloudwatch_logs_exports,
      # AWS may auto-replace the param group during minor upgrades; user can override via console
      parameter_group_name,
      # Will turn into a managed input when the storage autoscale feature is added
      max_allocated_storage,
      # Preserve existing AWS tags on adoption: the native path tags managed RDS with cluster_id
      # (used by the YACE CloudWatch exporter for DB metrics); overwriting them would break metrics.
      tags,
    ]
  }
}

# Same-region read replicas. Each is an asynchronous read-only copy of the primary; point
# analytics / BI tools at their endpoints to offload heavy reads. Replicas inherit engine
# version, storage size, storage type, and encryption from the source — those attributes
# cannot be set on a same-region replica, so they are intentionally absent here. A replica
# also has no db_name / username / password of its own (it shares the primary's).
resource "aws_db_instance" "read_replica" {
  count = var.read_replica_count

  # Identifier: primary base (already lowercased, underscores → hyphens) capped so the
  # "-replica-N" suffix keeps the total within the 63-char RDS limit.
  identifier          = "${substr(replace(lower(var.db_name), "_", "-"), 0, 50)}-replica-${count.index + 1}"
  replicate_source_db = aws_db_instance.this.identifier

  instance_class = var.read_replica_instance_class != "" ? var.read_replica_instance_class : var.instance_class
  port           = var.port

  ca_cert_identifier = var.ca_cert_identifier

  # Network. A same-region replica inherits the source's subnet group, so only the security
  # group and public exposure are set here — same cluster-workers SG the primary attaches to.
  multi_az               = var.read_replica_multi_az
  publicly_accessible    = var.read_replica_publicly_accessible
  vpc_security_group_ids = local.vpc_security_group_ids

  # Maintenance / upgrades — mirror the primary.
  apply_immediately          = var.apply_changes_now
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  maintenance_window         = var.preferred_maintenance_window

  # Replicas don't take a final snapshot on deletion.
  skip_final_snapshot   = true
  copy_tags_to_snapshot = var.copy_tags_to_snapshot

  # Monitoring — mirror the primary.
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  monitoring_interval                   = var.monitoring_interval
  monitoring_role_arn                   = var.monitoring_interval > 0 ? var.monitoring_role_arn : null

  deletion_protection = var.deletion_protection

  tags = {
    Name          = "${var.db_name}-replica-${count.index + 1}"
    ManagedBy     = "qovery-blueprint"
    Blueprint     = "aws-rds-postgresql"
    ClusterName   = var.qovery_cluster_name
    ServiceFamily = "postgres"
    Role          = "read-replica"

    # Native-parity tags injected by the engine via TF_VAR_qovery_*. cluster_id is what the YACE
    # CloudWatch exporter filters on for DB metrics; the rest mirror the native database_tags.
    cluster_id            = var.qovery_cluster_id
    cluster_long_id       = var.qovery_cluster_long_id
    region                = var.region
    q_client_id           = var.qovery_client_id
    q_environment_id      = var.qovery_environment_id
    q_environment_long_id = var.qovery_environment_long_id
    q_project_id          = var.qovery_project_id
    q_project_long_id     = var.qovery_project_long_id
    "aws-apn-id"          = var.qovery_aws_apn_id
  }

  lifecycle {
    ignore_changes = [
      # Same rationale as the primary above.
      engine_version,
      enabled_cloudwatch_logs_exports,
      parameter_group_name,
      max_allocated_storage,
      tags,
    ]
  }
}
