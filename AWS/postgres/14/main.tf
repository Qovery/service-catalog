locals {
  # RDS identifiers reject consecutive hyphens and a trailing one, which db_name's underscores
  # would otherwise produce (app__db, app_).
  db_name_slug = replace(replace(lower(var.db_name), "/_+/", "-"), "/-$/", "")

  # On adoption, keep the live identifier so the import is a no-op (renaming forces replacement).
  db_identifier = var.import_identifier != "" ? var.import_identifier : local.db_name_slug

  # Exact engine version. The deployment engine supplies the live version (or the upgrade target)
  # through var.engine_version. Without it, an existing instance (created or adopted) keeps its live
  # version and only a new one gets the bare major. A bare major is not safe on a live instance: AWS
  # resolves it to the region's default minor, which upgrades an older minor and is refused on a newer one.
  engine_version = var.engine_version != "" ? var.engine_version : coalesce(one(data.aws_db_instance.live[*].engine_version), "14")

  # Stamped from time_static, not timestamp(): unique per create so successive create/destroy
  # cycles don't collide on an existing snapshot id, yet stable across plans, so the attribute
  # needs no ignore_changes and an adopted instance gets a name too.
  final_snapshot_timestamp = replace(time_static.created.rfc3339, "/[-:TZ]/", "")
  # AWS requires the snapshot id to begin with a letter, contain only alphanumerics and single
  # hyphens, and stay within 255 chars. The cluster name is unconstrained, so only that part is
  # cleaned and cut: 160 leaves room for the db slug (max 63), the timestamp and a "snap-" prefix.
  final_snapshot_cluster = replace(substr(replace(replace(var.qovery_cluster_name, "/[^a-zA-Z0-9-]/", ""), "/-+/", "-"), 0, 160), "/^-|-$/", "")
  final_snapshot_cleaned = join("-", compact([local.final_snapshot_cluster, local.db_name_slug, local.final_snapshot_timestamp]))
  final_snapshot_name    = can(regex("^[a-zA-Z]", local.final_snapshot_cleaned)) ? local.final_snapshot_cleaned : "snap-${local.final_snapshot_cleaned}"
}

# Adopt an existing RDS instance when import_identifier is set (migration), else create.
import {
  for_each = var.import_identifier != "" ? toset([var.import_identifier]) : toset([])
  to       = aws_db_instance.this
  id       = each.value
}

# Live version of the instance, read only when the deployment engine supplies none. Covers created
# and adopted instances alike. Looked up through the list data source first: it returns nothing for an
# instance that does not exist yet (or is already gone), where the single-instance one fails.
data "aws_db_instances" "live" {
  count = var.engine_version == "" ? 1 : 0

  filter {
    name   = "db-instance-id"
    values = [local.db_identifier]
  }
}

data "aws_db_instance" "live" {
  count                  = length(flatten(data.aws_db_instances.live[*].instance_identifiers))
  db_instance_identifier = local.db_identifier
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

resource "random_password" "master" {
  length      = 32
  special     = false
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
}

locals {
  db_username = var.db_username != "" ? var.db_username : "qoveryadmin"
  db_password = var.db_password != "" ? var.db_password : random_password.master.result

  # An adopted instance keeps the password it already has until the operator hands it over, so the
  # import plans clean; an instance this blueprint created has always owned its password.
  manages_password = var.import_identifier == "" || var.manage_db_password

  # Derived, not typed: password_wo is only sent when this number changes, so hashing the password is
  # what makes changing it reach the instance. 13 hex digits keep the value an exact integer while
  # leaving a collision -- which would make a rotation a silent no-op -- out of reach.
  db_password_version = parseint(substr(sha256(local.db_password), 0, 13), 16)
}

resource "time_static" "created" {
  # Re-stamped whenever an input that can replace the instance changes, so a replacement that keeps
  # the same identifier cannot reuse the previous generation's final-snapshot name. A replacement
  # forced by hand (`-replace`, `taint`) is not covered: its later delete fails on the existing
  # snapshot name rather than losing data.
  triggers = {
    identifier        = local.db_identifier
    db_name           = var.db_name
    username          = local.db_username
    storage_encrypted = tostring(var.storage_encrypted)
  }
}

resource "aws_db_instance" "this" {
  identifier = local.db_identifier

  engine         = "postgres"
  engine_version = local.engine_version
  instance_class = var.instance_class
  port           = var.port

  allocated_storage = var.allocated_storage
  storage_type      = var.storage_type
  storage_encrypted = var.storage_encrypted
  # gp2 doesn't support provisioned IOPS — AWS rejects iops unless storage is io1/io2/gp3.
  iops = var.disk_iops == 0 || !contains(["io1", "io2", "gp3"], var.storage_type) ? null : var.disk_iops

  db_name  = var.db_name
  username = local.db_username
  # Write-only: never stored in state, so adopting a live instance has nothing to diff against.
  password_wo         = local.manages_password ? local.db_password : null
  password_wo_version = local.manages_password ? local.db_password_version : null

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
  final_snapshot_identifier = var.skip_final_snapshot ? null : local.final_snapshot_name
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

    # Native-parity tags, filled from the qbm.yml context variables. cluster_id is what the YACE
    # CloudWatch exporter filters on for DB metrics; the rest mirror the native database_tags.
    cluster_id      = var.qovery_cluster_id
    cluster_long_id = var.qovery_cluster_long_id
    region          = var.region
  }

  lifecycle {
    ignore_changes = [
      # Neutralises legacy state: instances created before password_wo carry a value here, and
      # password is no longer in the configuration, so without this the stale value reads as a removal.
      password,
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

# Opt-in ingress for read replicas only, so an external analytics tool (Metabase Cloud, BI SaaS)
# can reach a replica from an allow list without the rule ever touching the primary. When set,
# this group REPLACES the primary's groups on the replicas: on a Qovery network the workers group
# also carries the cluster-wide database.postgresql.allowed_cidrs rule (0.0.0.0/0 by default), so
# keeping it would leave a public replica open to the internet whatever the allow list says.
locals {
  read_replica_allowed_cidrs = toset(compact([for cidr in split(",", var.read_replica_allowed_cidrs) : trimspace(cidr)]))
  read_replica_ingress       = var.read_replica_count > 0 && length(local.read_replica_allowed_cidrs) > 0
}

# The VPC comes from the primary's subnet group rather than the ClusterId tag lookup, so it also
# resolves on a user-provided VPC and on an adopted instance.
data "aws_db_subnet_group" "primary" {
  count = local.read_replica_ingress ? 1 : 0
  name  = aws_db_instance.this.db_subnet_group_name
}

# Every CIDR of that VPC, secondary ones included, so in-cluster clients keep reaching the
# replicas once the workers group is no longer attached -- Karpenter nodes, which do not carry
# that group, included.
data "aws_vpc" "replica" {
  count = local.read_replica_ingress ? 1 : 0
  id    = data.aws_db_subnet_group.primary[0].vpc_id
}

resource "aws_security_group" "read_replica_ingress" {
  count = local.read_replica_ingress ? 1 : 0

  # A prefix plus create_before_destroy lets a replacement attach before the old group is
  # removed; a fixed name would collide with the group still attached to the replicas.
  name_prefix = "${substr(local.db_name_slug, 0, 40)}-replica-ingress-"
  description = "Allow-listed ingress to the ${var.db_name} read replicas"
  vpc_id      = data.aws_db_subnet_group.primary[0].vpc_id

  tags = {
    Name            = "${var.db_name}-replica-ingress"
    ManagedBy       = "qovery-blueprint"
    Blueprint       = "aws-rds-postgresql"
    ClusterName     = var.qovery_cluster_name
    cluster_id      = var.qovery_cluster_id
    cluster_long_id = var.qovery_cluster_long_id
    region          = var.region
  }

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  # Keyed by CIDR so an allow-list entry equal to a VPC CIDR yields one rule, not a duplicate
  # EC2 rejects.
  read_replica_ingress_cidrs = local.read_replica_ingress ? merge(
    { for cidr in data.aws_vpc.replica[0].cidr_block_associations[*].cidr_block : cidr => "VPC" },
    { for cidr in local.read_replica_allowed_cidrs : cidr => "allow list" },
  ) : {}
}

resource "aws_vpc_security_group_ingress_rule" "read_replica" {
  for_each = local.read_replica_ingress_cidrs

  security_group_id = aws_security_group.read_replica_ingress[0].id
  description       = "PostgreSQL from ${each.key} (${each.value})"
  ip_protocol       = "tcp"
  from_port         = var.port
  to_port           = var.port
  cidr_ipv4         = each.key
}

locals {
  # Replicas mirror the primary's groups. An adopted instance leaves local.vpc_security_group_ids
  # null, so read what the primary actually carries instead: null would mean "keep the live list"
  # on the replicas, and clearing the allow list could then never detach its group.
  read_replica_base_security_group_ids = (
    local.vpc_security_group_ids != null ? local.vpc_security_group_ids
    : tolist(aws_db_instance.this.vpc_security_group_ids)
  )
  read_replica_security_group_ids = (
    local.read_replica_ingress
    ? [aws_security_group.read_replica_ingress[0].id]
    : local.read_replica_base_security_group_ids
  )
}

# Same-region read replicas. Each is an asynchronous read-only copy of the primary; point
# analytics / BI tools at their endpoints to offload heavy reads. Replicas inherit engine
# version, storage size, storage type, and encryption from the source — those attributes
# cannot be set on a same-region replica, so they are intentionally absent here. A replica
# also has no db_name / username / password of its own (it shares the primary's).
resource "aws_db_instance" "read_replica" {
  count = var.read_replica_count

  # Identifier: primary slug capped so the "-replica-N" suffix keeps the total within the
  # 63-char RDS limit; the cut can land on a hyphen, which would double against the suffix.
  identifier          = "${replace(substr(local.db_name_slug, 0, 50), "/-$/", "")}-replica-${count.index + 1}"
  replicate_source_db = aws_db_instance.this.identifier

  # The allow-list group replaces the replica's groups, so its rules must exist before it is
  # attached or the replica is briefly unreachable, in-cluster clients included.
  depends_on = [aws_vpc_security_group_ingress_rule.read_replica]

  instance_class = var.read_replica_instance_class != "" ? var.read_replica_instance_class : var.instance_class
  port           = var.port

  ca_cert_identifier = var.ca_cert_identifier

  # Network. A same-region replica inherits the source's subnet group, so only the security
  # group and public exposure are set here — the primary's SGs, or the allow-list SG alone when set.
  multi_az               = var.read_replica_multi_az
  publicly_accessible    = var.read_replica_publicly_accessible
  vpc_security_group_ids = local.read_replica_security_group_ids

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

    # Native-parity tags, filled from the qbm.yml context variables. cluster_id is what the YACE
    # CloudWatch exporter filters on for DB metrics; the rest mirror the native database_tags.
    cluster_id      = var.qovery_cluster_id
    cluster_long_id = var.qovery_cluster_long_id
    region          = var.region
  }

  lifecycle {
    ignore_changes = [
      # A same-region replica runs the source's version and RDS upgrades it along with the
      # primary, so its version changes outside this configuration.
      engine_version,
      # Same rationale as the primary above for the rest.
      enabled_cloudwatch_logs_exports,
      parameter_group_name,
      max_allocated_storage,
      tags,
      # A same-region replica inherits encryption from the source and never sets
      # storage_encrypted here, but the provider stores it as true in state and then reads
      # config as null on the next plan — a phantom true->null diff that force-replaces the
      # replica on every apply (hashicorp/terraform-provider-aws#31325). Encryption is
      # immutable on a replica, so ignoring the attribute is correct and stops the churn.
      storage_encrypted,
    ]
  }
}
