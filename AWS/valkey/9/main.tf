locals {
  # On adoption, keep the live id so the import is a no-op (renaming forces replacement).
  valkey_identifier = var.import_identifier != "" ? var.import_identifier : lower(var.valkey_name)

  # Stamped from time_static, not timestamp(): unique per create so successive create/destroy
  # cycles don't collide on an existing snapshot id, yet stable across plans, so the attribute
  # needs no ignore_changes and skip_final_snapshot keeps working after creation.
  final_snapshot_timestamp = replace(time_static.created.rfc3339, "/[-:TZ]/", "")
  final_snapshot_raw       = "${local.valkey_identifier}-final-snap-${local.final_snapshot_timestamp}"
  # AWS requires the snapshot id to begin with a letter and contain only alphanumerics/hyphens.
  final_snapshot_cleaned = replace(local.final_snapshot_raw, "/[^a-zA-Z0-9-]/", "")
  final_snapshot_name    = can(regex("^[a-zA-Z]", local.final_snapshot_cleaned)) ? local.final_snapshot_cleaned : "snap-${local.final_snapshot_cleaned}"

  cluster_mode = var.instances_number > 1
  # A sharded group needs the cluster-mode parameter group family; default.valkey9 is rejected there.
  parameter_group_name = (
    var.parameter_group_name != "" ? var.parameter_group_name
    : local.cluster_mode ? "default.valkey9.cluster.on" : "default.valkey9"
  )
}

# Adopt an existing replication group when import_identifier is set (migration), else create.
import {
  for_each = var.import_identifier != "" ? toset([var.import_identifier]) : toset([])
  to       = aws_elasticache_replication_group.this
  id       = each.value
}

# Attach to the Qovery cluster network by default, like native managed databases: bootstrap tags
# the cluster VPC with ClusterId and creates an "elasticache-<vpc id>" subnet group. Skipped on
# override or adoption — both attributes are Optional+Computed, so null keeps the live values.
data "aws_vpc" "cluster" {
  count = var.subnet_group_name == "" && var.import_identifier == "" ? 1 : 0

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
  subnet_group_name = (
    var.subnet_group_name != "" ? var.subnet_group_name
    : var.import_identifier != "" ? null
    : "elasticache-${data.aws_vpc.cluster[0].id}"
  )
  security_group_ids = (
    var.security_group_ids != "" ? [for id in split(",", var.security_group_ids) : trimspace(id)]
    : var.import_identifier != "" ? null
    : [data.aws_security_group.cluster_workers[0].id]
  )
}

resource "time_static" "created" {}

resource "random_password" "auth_token" {
  length      = 32
  special     = false
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
}

locals {
  valkey_password = var.valkey_password != "" ? var.valkey_password : random_password.auth_token.result
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = local.valkey_identifier
  description          = "Qovery's elasticache"

  engine               = "valkey"
  engine_version       = var.engine_version
  node_type            = var.instance_class
  port                 = var.port
  parameter_group_name = local.parameter_group_name

  # num_cache_clusters conflicts with num_node_groups, so exactly one is ever set. A sharded
  # group needs one replica per shard, which AWS only accepts with failover and Multi-AZ on.
  num_cache_clusters         = local.cluster_mode ? null : var.instances_number
  num_node_groups            = local.cluster_mode ? var.instances_number : null
  replicas_per_node_group    = local.cluster_mode ? 1 : null
  multi_az_enabled           = local.cluster_mode
  automatic_failover_enabled = local.cluster_mode

  # Always on: ElastiCache only accepts an auth token on a TLS-enabled group, so turning it off
  # would leave a Valkey reachable with no password at all.
  transit_encryption_enabled = true
  auth_token                 = local.valkey_password
  at_rest_encryption_enabled = var.at_rest_encryption_enabled

  # Network
  subnet_group_name  = local.subnet_group_name
  security_group_ids = local.security_group_ids

  # Maintenance / upgrades. AWS stores the window lowercased and reports it back that way, so it
  # is lowercased here to keep it out of every subsequent plan.
  apply_immediately          = var.apply_changes_now
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  maintenance_window         = lower(var.preferred_maintenance_window)

  # Backups
  snapshot_window           = var.backup_retention_period > 0 ? var.preferred_backup_window : null
  snapshot_retention_limit  = var.backup_retention_period
  final_snapshot_identifier = var.skip_final_snapshot ? null : local.final_snapshot_name
  # Read at creation only.
  snapshot_name = var.snapshot_name == "" ? null : var.snapshot_name

  tags = {
    Name          = var.valkey_name
    ManagedBy     = "qovery-blueprint"
    Blueprint     = "aws-elasticache-valkey"
    ClusterName   = var.qovery_cluster_name
    ServiceFamily = "valkey"
    creationDate  = time_static.created.rfc3339

    # Native-parity tags, filled from the qbm.yml context variables. cluster_id is what the YACE
    # CloudWatch exporter filters on for database metrics; the rest mirror native database_tags.
    cluster_id      = var.qovery_cluster_id
    cluster_long_id = var.qovery_cluster_long_id
    region          = var.region
  }

  lifecycle {
    ignore_changes = [
      # Write-only: ElastiCache never returns it, so an adopted group shows a perpetual diff.
      # ignore_changes can't be conditional, so rotation isn't managed here — rotate out-of-band.
      auth_token,
      # Set outside the blueprint (console, CloudWatch wiring, RBAC), same as the native path
      log_delivery_configuration,
      notification_topic_arn,
      user_group_ids,
      # AWS picks the mode ("preferred" vs "required") and reports its own value back
      transit_encryption_mode,
      # Preserve native tags on adoption: cluster_id is what the YACE exporter reads for metrics
      tags,
    ]
  }
}

# Endpoint attributes come back null, not "", on the topology that does not publish them:
# configuration_endpoint_address in non-cluster mode, primary/reader in cluster mode. Normalise
# to "" here so a null never reaches format() or an output.
locals {
  configuration_endpoint = aws_elasticache_replication_group.this.configuration_endpoint_address != null ? aws_elasticache_replication_group.this.configuration_endpoint_address : ""
  primary_endpoint       = aws_elasticache_replication_group.this.primary_endpoint_address != null ? aws_elasticache_replication_group.this.primary_endpoint_address : ""
  reader_endpoint        = aws_elasticache_replication_group.this.reader_endpoint_address != null ? aws_elasticache_replication_group.this.reader_endpoint_address : ""

  valkey_host = local.configuration_endpoint != "" ? local.configuration_endpoint : local.primary_endpoint
}
