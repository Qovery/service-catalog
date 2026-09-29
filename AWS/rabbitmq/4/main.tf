# Attach to the Qovery cluster network by default, like the RDS blueprints: cluster bootstrap tags
# the VPC with ClusterId = <cluster short id> and creates a DB subnet group named after the VPC id,
# whose private subnets span the cluster's availability zones. A public broker takes neither:
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

data "aws_security_group" "cluster_workers" {
  count = var.security_group_ids == "" && !var.publicly_accessible ? 1 : 0

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
  security_group_ids = (
    var.publicly_accessible ? null
    : var.security_group_ids != "" ? [for id in split(",", var.security_group_ids) : trimspace(id)]
    : [data.aws_security_group.cluster_workers[0].id]
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
    ignore_changes = [user]
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
  amqps_endpoint = aws_mq_broker.this.instances[0].endpoints[0]
  host           = regex("^amqps://([^:/]+)", local.amqps_endpoint)[0]
}
