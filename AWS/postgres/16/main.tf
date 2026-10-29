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
  engine_version = var.engine_version != "" ? var.engine_version : coalesce(one(data.aws_db_instance.live[*].engine_version), "16")

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

# Live instance: its version, when the deployment engine supplies none, its parameter group, its disk
# size, and the autoscaling ceiling and log exports that unset inputs keep. Read on every plan; gating
# it on an input would let a deploy turn off autoscaling or exports set in the AWS console.
# Covers created and adopted instances alike. Looked up through the list data source first: it returns
# nothing for an instance that does not exist yet (or is already gone), where the single-instance one fails.
data "aws_db_instances" "live" {
  filter {
    name   = "db-instance-id"
    values = [local.db_identifier]
  }
}

data "aws_db_instance" "live" {
  count                  = length(data.aws_db_instances.live.instance_identifiers)
  db_instance_identifier = local.db_identifier
}

locals {
  # RDS never shrinks a disk, and autoscaling or the 10% round-up of a manual increase leave it above
  # the input. Asking for less would fail, and would block turning autoscaling off after a growth.
  live_allocated_storage = try(one(data.aws_db_instance.live).allocated_storage, 0)
  allocated_storage      = max(var.allocated_storage, local.live_allocated_storage)

  # Unset keeps the live ceiling (none on a new instance); 0 turns autoscaling off.
  live_max_allocated_storage = try(one(data.aws_db_instance.live).max_allocated_storage, null)
  max_allocated_storage      = var.max_allocated_storage != null ? var.max_allocated_storage : local.live_max_allocated_storage

  # Only ever adds the postgresql log: false leaves the live exports as they are.
  live_cloudwatch_logs_exports = try(toset(one(data.aws_db_instance.live).enabled_cloudwatch_logs_exports), null)
  enabled_cloudwatch_logs_exports = (
    var.cloudwatch_logs_export_enabled
    ? setunion(coalesce(local.live_cloudwatch_logs_exports, toset([])), ["postgresql"])
    : local.live_cloudwatch_logs_exports
  )
}

# Custom parameter group, created only when db_parameters is set. The family follows the engine
# major, so a major upgrade replaces the group: the prefix plus create_before_destroy creates the new
# one, the instance moves onto it with the engine, and the old group is deleted untouched -- never
# sent parameters its major may not know. That deletion needs the upgrade applied now, which the
# precondition on the instance enforces.
locals {
  db_parameters = var.db_parameters == "" ? {} : {
    for name, v in jsondecode(var.db_parameters) : name => {
      # RDS stores booleans as 1/0; sending true/false would read back as a change on every plan.
      value        = try(v.value, v) == true ? "1" : try(v.value, v) == false ? "0" : tostring(try(v.value, v))
      apply_method = try(v.apply_method, "immediate")
    }
  }

  parameter_group_family = "postgres${split(".", local.engine_version)[0]}"
  live_parameter_family  = try("postgres${split(".", one(data.aws_db_instance.live).engine_version)[0]}", local.parameter_group_family)
  parameter_group_prefix = "${replace(substr(local.db_identifier, 0, 200), "/-$/", "")}-params-"
  live_parameter_group   = try(one(data.aws_db_instance.live).db_parameter_groups[0], "")

  # Owned = the prefix plus the 26-character suffix name_prefix generates (18-digit timestamp, 8-hex
  # counter). Group tags cannot be read back, so this shape is the ownership check.
  live_parameter_group_owned = can(regex("^${local.parameter_group_prefix}[0-9a-f]{26}$", local.live_parameter_group))

  # True while the blueprint's group is involved in a major upgrade: being set, or being cleared.
  parameter_group_major_upgrade = (
    local.live_parameter_family != local.parameter_group_family
    && (var.db_parameters != "" || local.live_parameter_group_owned)
  )

  # Unset leaves the live group alone (null is Optional+Computed): the AWS default, a group set in
  # the AWS console, or an adopted instance's own group. Only a group this blueprint created is
  # swapped back to the family default, so clearing db_parameters can delete it.
  parameter_group_name = (
    var.db_parameters != "" ? aws_db_parameter_group.this[0].name
    : local.live_parameter_group_owned ? "default.${local.parameter_group_family}"
    : null
  )

}

resource "aws_db_parameter_group" "this" {
  count = var.db_parameters != "" ? 1 : 0

  name_prefix = local.parameter_group_prefix
  family      = local.parameter_group_family
  description = "Parameters for the ${var.db_name} PostgreSQL instance"

  dynamic "parameter" {
    for_each = local.db_parameters
    content {
      name         = parameter.key
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = {
    Name            = "${var.db_name}-params"
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

  allocated_storage     = local.allocated_storage
  max_allocated_storage = local.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  # gp2 doesn't support provisioned IOPS — AWS rejects iops unless storage is io1/io2/gp3.
  iops = var.disk_iops == 0 || !contains(["io1", "io2", "gp3"], var.storage_type) ? null : var.disk_iops
  # gp3 only, and below 400 GiB AWS fixes throughput at 125 MiB/s and rejects the argument.
  storage_throughput = var.storage_throughput == 0 || var.storage_type != "gp3" || var.allocated_storage < 400 ? null : var.storage_throughput

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
  enabled_cloudwatch_logs_exports       = local.enabled_cloudwatch_logs_exports

  # Misc
  parameter_group_name                = local.parameter_group_name
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
    # Deferred, the upgrade keeps the old group attached until the maintenance window, so deleting
    # it would fail mid-apply.
    precondition {
      condition     = !local.parameter_group_major_upgrade || var.apply_changes_now
      error_message = "A major version upgrade with db_parameters set (or being cleared) needs apply_changes_now = true: RDS keeps the old parameter group attached until the upgrade runs, so it cannot be deleted before then."
    }

    # AWS wants the ceiling at least 10% above the disk, which autoscaling may have grown past
    # allocated_storage. Only an unchanged ceiling on a disk the input does not raise is never sent.
    precondition {
      condition = (
        coalesce(local.max_allocated_storage, 0) == 0
        || (local.max_allocated_storage == local.live_max_allocated_storage && var.allocated_storage <= local.live_allocated_storage)
        || coalesce(local.max_allocated_storage, 0) * 10 >= local.allocated_storage * 11
      )
      error_message = "The storage autoscaling ceiling (max_allocated_storage, or the instance's current one when unset) is ${coalesce(local.max_allocated_storage, 0)} GiB, less than 10% above the ${local.allocated_storage} GiB disk: raise max_allocated_storage to ${ceil(local.allocated_storage * 11 / 10)} or more, or set it to 0 to turn autoscaling off."
    }

    ignore_changes = [
      # Neutralises legacy state: instances created before password_wo carry a value here, and
      # password is no longer in the configuration, so without this the stale value reads as a removal.
      password,
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
# resolves on a user-provided VPC and on an adopted instance. The group name must not come from
# aws_db_instance.this: any pending change on the primary (a create, an engine_version pin)
# defers the lookup to apply, and the ingress rules' for_each keys become unknown at plan.
data "aws_db_instance" "adopted" {
  count                  = local.read_replica_ingress && var.import_identifier != "" ? 1 : 0
  db_instance_identifier = var.import_identifier
}

data "aws_db_subnet_group" "primary" {
  count = local.read_replica_ingress ? 1 : 0
  name  = coalesce(local.db_subnet_group_name, one(data.aws_db_instance.adopted[*].db_subnet_group))
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

  # Primary slug capped so the "-replica-N" suffix keeps the total within the 63-char RDS limit;
  # the cut can land on a hyphen, which would double against the suffix.
  read_replica_identifiers = [for i in range(var.read_replica_count) : "${replace(substr(local.db_name_slug, 0, 50), "/-$/", "")}-replica-${i + 1}"]
}

# Each replica's own autoscaling ceiling and log exports, kept while the inputs are unset, as on the
# primary. Keyed on identifiers built from inputs only, never on aws_db_instance.this, so the keys
# stay known at plan.
data "aws_db_instances" "replica_live" {
  count = var.read_replica_count > 0 ? 1 : 0

  filter {
    name   = "db-instance-id"
    values = local.read_replica_identifiers
  }
}

data "aws_db_instance" "replica_live" {
  for_each               = toset(flatten(data.aws_db_instances.replica_live[*].instance_identifiers))
  db_instance_identifier = each.value
}

locals {
  # A replica not created yet starts from the primary's values.
  read_replica_max_allocated_storage = [
    for id in local.read_replica_identifiers :
    var.max_allocated_storage != null ? var.max_allocated_storage
    : try(data.aws_db_instance.replica_live[id].max_allocated_storage, local.max_allocated_storage)
  ]
  # Each instance autoscales on its own, so a replica's disk can outgrow the primary's.
  read_replica_allocated_storage = [
    for id in local.read_replica_identifiers :
    try(data.aws_db_instance.replica_live[id].allocated_storage, local.allocated_storage)
  ]
  read_replica_live_max_allocated_storage = [
    for id in local.read_replica_identifiers :
    try(data.aws_db_instance.replica_live[id].max_allocated_storage, null)
  ]
  read_replica_live_cloudwatch_logs_exports = [
    for id in local.read_replica_identifiers :
    try(toset(data.aws_db_instance.replica_live[id].enabled_cloudwatch_logs_exports), local.enabled_cloudwatch_logs_exports)
  ]
  read_replica_cloudwatch_logs_exports = [
    for live in local.read_replica_live_cloudwatch_logs_exports :
    var.cloudwatch_logs_export_enabled ? setunion(coalesce(live, toset([])), ["postgresql"]) : live
  ]
}

# Same-region read replicas. Each is an asynchronous read-only copy of the primary; point
# analytics / BI tools at their endpoints to offload heavy reads. Replicas inherit engine
# version, storage size, storage type, and encryption from the source — those attributes
# cannot be set on a same-region replica, so they are intentionally absent here. Storage
# autoscaling and log exports are per instance, so each replica sets its own below. A replica
# also has no db_name / username / password of its own (it shares the primary's).
resource "aws_db_instance" "read_replica" {
  count = var.read_replica_count

  identifier          = local.read_replica_identifiers[count.index]
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
  enabled_cloudwatch_logs_exports       = local.read_replica_cloudwatch_logs_exports[count.index]

  # Without it a replica keeps its first disk while the primary grows, and fills up. Its own
  # allocated_storage stays unset, so turning autoscaling off sends its live size.
  max_allocated_storage = local.read_replica_max_allocated_storage[count.index]

  # A major upgrade of the primary waits for its in-Region replicas to be upgraded too, and RDS moves
  # them to the new family's default group, so they never hold the old group at deletion. Setting
  # db_parameters moves them on to the new blueprint group; clearing it during the upgrade leaves them
  # alone, as requesting the default they already have is refused as "no modifications".
  parameter_group_name = (
    local.live_parameter_family != local.parameter_group_family && var.db_parameters == "" ? null
    : local.parameter_group_name
  )
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
    # The primary's 10% rule against this replica's own disk. A new replica is created with the
    # primary's disk, then given its ceiling, which AWS refuses after the replica exists.
    precondition {
      condition = (
        coalesce(local.read_replica_max_allocated_storage[count.index], 0) == 0
        || local.read_replica_max_allocated_storage[count.index] == local.read_replica_live_max_allocated_storage[count.index]
        || coalesce(local.read_replica_max_allocated_storage[count.index], 0) * 10 >= local.read_replica_allocated_storage[count.index] * 11
      )
      error_message = "The storage autoscaling ceiling of read replica ${local.read_replica_identifiers[count.index]} is ${coalesce(local.read_replica_max_allocated_storage[count.index], 0)} GiB, less than 10% above its ${local.read_replica_allocated_storage[count.index]} GiB disk: raise max_allocated_storage to ${ceil(local.read_replica_allocated_storage[count.index] * 11 / 10)} or more, or set it to 0 to turn autoscaling off."
    }

    ignore_changes = [
      # A same-region replica runs the source's version and RDS upgrades it along with the
      # primary, so its version changes outside this configuration.
      engine_version,
      # Same rationale as the primary's tags.
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
