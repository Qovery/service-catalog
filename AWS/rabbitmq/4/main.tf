# Attach to the Qovery cluster network by default, like the RDS blueprints: cluster bootstrap tags
# the VPC with ClusterId = <cluster short id> and creates a DB subnet group named after the VPC id,
# whose private subnets span the cluster's availability zones. A public broker takes none of this:
# Amazon MQ hosts it outside the VPC and refuses security groups on it.
data "aws_vpc" "cluster" {
  count = var.subnet_ids == "" && !var.publicly_accessible ? 1 : 0

  filter {
    name   = "tag:ClusterId"
    values = [var.qovery_cluster_id]
  }
}

data "aws_db_subnet_group" "cluster" {
  count = var.subnet_ids == "" && !var.publicly_accessible ? 1 : 0

  name = data.aws_vpc.cluster[0].id
}

data "aws_subnet" "cluster" {
  for_each = var.subnet_ids == "" && !var.publicly_accessible ? data.aws_db_subnet_group.cluster[0].subnet_ids : toset([])

  id = each.value
}

locals {
  # One subnet per availability zone, in a stable order: a single-instance broker takes exactly one
  # subnet, a cluster spreads its three nodes over up to three zones.
  subnet_by_az = {
    for az in distinct(sort([for s in data.aws_subnet.cluster : s.availability_zone])) :
    az => sort([for s in data.aws_subnet.cluster : s.id if s.availability_zone == az])[0]
  }
  discovered_subnet_ids = [for az in sort(keys(local.subnet_by_az)) : local.subnet_by_az[az]]

  all_subnet_ids = (
    var.subnet_ids != "" ? [for s in split(",", var.subnet_ids) : trimspace(s)]
    : local.discovered_subnet_ids
  )
  subnet_ids = (
    var.publicly_accessible ? null
    : var.deployment_mode == "SINGLE_INSTANCE" ? slice(local.all_subnet_ids, 0, 1)
    : slice(local.all_subnet_ids, 0, min(3, length(local.all_subnet_ids)))
  )

  # The cluster workers security group only opens the ports of the native databases, and Karpenter
  # nodes do not even carry it, so the broker gets its own group instead. The group exists for every
  # private broker, even one attached to security_group_ids: Amazon MQ never changes a RabbitMQ
  # broker's groups, so keying the group on security_group_ids would destroy it while still attached
  # (DependencyViolation on every apply) when that variable is set after creation.
  create_security_group = !var.publicly_accessible
}

data "aws_subnet" "broker" {
  count = local.create_security_group ? 1 : 0

  id = local.subnet_ids[0]
}

data "aws_vpc" "broker" {
  count = local.create_security_group ? 1 : 0

  id = data.aws_subnet.broker[0].vpc_id
}

locals {
  allowed_cidrs = (
    !local.create_security_group ? []
    : var.allowed_cidrs != "" ? [for c in split(",", var.allowed_cidrs) : trimspace(c)]
    : [for a in data.aws_vpc.broker[0].cidr_block_associations : a.cidr_block]
  )
}

resource "aws_security_group" "broker" {
  count = local.create_security_group ? 1 : 0

  name        = "qovery-amazonmq-${var.broker_name}"
  description = "Amazon MQ broker ${var.broker_name}: AMQPS and management UI"
  vpc_id      = data.aws_vpc.broker[0].id

  ingress {
    description = "AMQPS"
    from_port   = 5671
    to_port     = 5671
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  ingress {
    description = "RabbitMQ management UI and HTTP API"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  tags = local.tags
}

locals {
  security_group_ids = (
    var.publicly_accessible ? null
    : var.security_group_ids != "" ? [for id in split(",", var.security_group_ids) : trimspace(id)]
    : [aws_security_group.broker[0].id]
  )

  admin_password = var.admin_password != "" ? var.admin_password : random_password.admin.result

  configuration_lines = concat(
    [
      "consumer_timeout = ${var.consumer_timeout_ms}",
      "heartbeat = ${var.heartbeat_seconds}",
    ],
    [for line in split(";", var.extra_configuration) : trimspace(line) if trimspace(line) != ""],
  )

  tags = {
    Name          = var.broker_name
    ManagedBy     = "qovery-blueprint"
    Blueprint     = "aws-amazon-mq-rabbitmq"
    ClusterName   = var.qovery_cluster_name
    ServiceFamily = "rabbitmq"

    cluster_id      = var.qovery_cluster_id
    cluster_long_id = var.qovery_cluster_long_id
    region          = var.region
  }
}

resource "random_password" "admin" {
  length      = 32
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  # A fourth mandatory class guarantees the four distinct characters Amazon MQ requires. The set
  # leaves out , : = (refused by Amazon MQ) and $ ( (expanded by Kubernetes in consumers' env).
  special          = true
  min_special      = 1
  override_special = "-_.!"
}

resource "aws_mq_configuration" "this" {
  name           = var.broker_name
  description    = "Managed by the Qovery aws-amazon-mq-rabbitmq blueprint"
  engine_type    = "RabbitMQ"
  engine_version = var.engine_version
  data           = join("\n", local.configuration_lines)

  tags = local.tags
}

# Amazon MQ needs a CloudWatch Logs resource policy before it can publish broker logs.
resource "aws_cloudwatch_log_resource_policy" "mq" {
  count = var.general_logs ? 1 : 0

  policy_name = "qovery-amazonmq-${var.broker_name}"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "mq.amazonaws.com" }
      Action    = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource  = "arn:aws:logs:${var.region}:*:log-group:/aws/amazonmq/*"
    }]
  })
}

resource "aws_mq_broker" "this" {
  broker_name        = var.broker_name
  engine_type        = "RabbitMQ"
  engine_version     = var.engine_version
  host_instance_type = var.host_instance_type
  deployment_mode    = var.deployment_mode

  # Amazon MQ requires automatic minor upgrades on RabbitMQ 3.13 and later.
  auto_minor_version_upgrade = true
  apply_immediately          = var.apply_changes_now

  publicly_accessible = var.publicly_accessible
  subnet_ids          = local.subnet_ids
  security_groups     = local.security_group_ids

  configuration {
    id       = aws_mq_configuration.this.id
    revision = aws_mq_configuration.this.latest_revision
  }

  user {
    username = var.admin_username
    password = local.admin_password
  }

  encryption_options {
    use_aws_owned_key = var.kms_key_id == ""
    kms_key_id        = var.kms_key_id == "" ? null : var.kms_key_id
  }

  logs {
    general = var.general_logs
  }

  maintenance_window_start_time {
    day_of_week = var.maintenance_day_of_week
    time_of_day = var.maintenance_time_of_day
    time_zone   = var.maintenance_time_zone
  }

  tags = local.tags

  lifecycle {
    # Amazon MQ cannot update RabbitMQ users and never returns them, so a changed username or
    # password would plan an update on every run and never reach the broker. Credentials are set at
    # creation; the terraform_data resources below keep the outputs on the values the broker has.
    # Amazon MQ also refuses to change the security groups of a RabbitMQ broker, so they are set at
    # creation too; allowed_cidrs still applies, since it edits the rules of the group in place.
    ignore_changes = [user, security_groups]
  }

  depends_on = [aws_cloudwatch_log_resource_policy.mq]
}

# The credentials the broker was created with. Pinned (ignore_changes) so editing admin_username
# or admin_password later does not publish a login the broker rejects, and re-taken whenever the
# broker is replaced, since a new broker is created with the current values.
resource "terraform_data" "admin_username" {
  input = var.admin_username

  lifecycle {
    ignore_changes       = [input]
    replace_triggered_by = [aws_mq_broker.this.id]
  }
}

# Kept apart from the username so only the password is marked sensitive.
resource "terraform_data" "admin_password" {
  input = local.admin_password

  lifecycle {
    ignore_changes       = [input]
    replace_triggered_by = [aws_mq_broker.this.id]
  }
}

locals {
  # The endpoint list is not ordered by protocol: RabbitMQ 4 brokers list an https:// endpoint
  # first. Every entry carries the same host, so take it from the first and build the AMQPS URL.
  host           = regex("^[a-z+]+://([^:/]+)", aws_mq_broker.this.instances[0].endpoints[0])[0]
  amqps_endpoint = "amqps://${local.host}:5671"
}
