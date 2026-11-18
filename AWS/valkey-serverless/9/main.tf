locals {
  # ElastiCache stores cache names and user ids lowercased.
  valkey_identifier = lower(var.valkey_name)

  tags = {
    Name          = var.valkey_name
    ManagedBy     = "qovery-blueprint"
    Blueprint     = "aws-elasticache-valkey-serverless"
    ClusterName   = var.qovery_cluster_name
    ServiceFamily = "valkey-serverless"

    # Filled from the qbm.yml context variables. cluster_id is what the YACE CloudWatch exporter
    # filters on for database metrics; the others identify the cluster for cost reporting.
    cluster_id      = var.qovery_cluster_id
    cluster_long_id = var.qovery_cluster_long_id
    region          = var.region
  }
}

# Attach to the Qovery cluster network by default, like the node-based ElastiCache blueprints:
# cluster bootstrap tags the VPC with ClusterId = <cluster short id> and creates an
# "elasticache-<vpc id>" subnet group over the cluster's private subnets. A serverless cache takes
# subnet ids rather than a subnet group, so the group is only read for its subnets.
data "aws_vpc" "cluster" {
  count = var.subnet_ids == "" ? 1 : 0

  filter {
    name   = "tag:ClusterId"
    values = [var.qovery_cluster_id]
  }
}

data "aws_elasticache_subnet_group" "cluster" {
  count = var.subnet_ids == "" ? 1 : 0

  name = "elasticache-${data.aws_vpc.cluster[0].id}"
}

data "aws_subnet" "cluster" {
  for_each = var.subnet_ids == "" ? data.aws_elasticache_subnet_group.cluster[0].subnet_ids : toset([])

  id = each.value
}

locals {
  # One subnet per availability zone, in a stable order, and three at most.
  subnet_by_az = {
    for az in distinct(sort([for s in data.aws_subnet.cluster : s.availability_zone])) :
    az => sort([for s in data.aws_subnet.cluster : s.id if s.availability_zone == az])[0]
  }
  discovered_subnet_ids = [for az in sort(keys(local.subnet_by_az)) : local.subnet_by_az[az]]

  subnet_ids = (
    var.subnet_ids != "" ? [for s in split(",", var.subnet_ids) : trimspace(s)]
    : slice(local.discovered_subnet_ids, 0, min(3, length(local.discovered_subnet_ids)))
  )

  # The cluster workers security group opens 6379 only, and Karpenter nodes do not carry it. A
  # serverless cache also serves reads on 6380, so it gets its own group unless ids are supplied.
  create_security_group = var.security_group_ids == ""
}

data "aws_subnet" "cache" {
  count = local.create_security_group ? 1 : 0

  id = local.subnet_ids[0]
}

data "aws_vpc" "cache" {
  count = local.create_security_group ? 1 : 0

  id = data.aws_subnet.cache[0].vpc_id
}

locals {
  allowed_cidrs = (
    !local.create_security_group ? []
    : var.allowed_cidrs != "" ? [for c in split(",", var.allowed_cidrs) : trimspace(c)]
    : [for a in data.aws_vpc.cache[0].cidr_block_associations : a.cidr_block]
  )
}

# Keep the description as is: changing it replaces the group, which fails while the cache uses it.
resource "aws_security_group" "cache" {
  count = local.create_security_group ? 1 : 0

  name        = "qovery-valkey-serverless-${local.valkey_identifier}"
  description = "ElastiCache Serverless ${local.valkey_identifier}: Valkey primary and reader endpoints"
  vpc_id      = data.aws_vpc.cache[0].id

  ingress {
    description = "Valkey: 6379 primary endpoint, 6380 reader endpoint"
    from_port   = 6379
    to_port     = 6380
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  tags = local.tags
}

locals {
  security_group_ids = (
    local.create_security_group ? [aws_security_group.cache[0].id]
    : [for id in split(",", var.security_group_ids) : trimspace(id)]
  )
}

resource "random_password" "user" {
  length      = 32
  special     = false
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
}

locals {
  valkey_username = "app"
  valkey_password = var.valkey_password != "" ? var.valkey_password : random_password.user.result
}

# A serverless cache has no auth token: access goes through a user group. The group holds one
# password-protected user with full access, so nothing can connect without credentials.
resource "aws_elasticache_user" "app" {
  user_id   = "${local.valkey_identifier}-app"
  user_name = local.valkey_username
  engine    = "valkey"

  # Every key, every pub/sub channel, every command.
  access_string = "on ~* &* +@all"

  authentication_mode {
    type      = "password"
    passwords = [local.valkey_password]
  }

  tags = local.tags
}

resource "aws_elasticache_user_group" "this" {
  user_group_id = "${local.valkey_identifier}-users"
  engine        = "valkey"
  user_ids      = [aws_elasticache_user.app.user_id]

  tags = local.tags
}

resource "aws_elasticache_serverless_cache" "this" {
  name        = local.valkey_identifier
  description = "Qovery's elasticache serverless"

  engine               = "valkey"
  major_engine_version = "9"

  # Network
  subnet_ids         = local.subnet_ids
  security_group_ids = local.security_group_ids

  # Access
  user_group_id = aws_elasticache_user_group.this.user_group_id

  # Usage caps. The block is always sent, with the AWS maximums standing for "no cap": removing
  # it from a cache that had limits makes the provider send an empty ModifyServerlessCache, which
  # AWS rejects with "No modifications were requested".
  cache_usage_limits {
    data_storage {
      maximum = var.data_storage_max_gb > 0 ? var.data_storage_max_gb : 5000
      unit    = "GB"
    }

    ecpu_per_second {
      maximum = var.ecpu_per_second_max > 0 ? var.ecpu_per_second_max : 15000000
    }
  }

  # Backups
  snapshot_retention_limit = var.backup_retention_period
  daily_snapshot_time      = var.backup_retention_period > 0 ? var.daily_snapshot_time : null

  tags = local.tags

  lifecycle {
    ignore_changes = [
      # ElastiCache cannot move a serverless cache to other subnets. Without this, a change in the
      # cluster's subnet group would plan a replacement and drop the data.
      subnet_ids,
    ]
  }
}
