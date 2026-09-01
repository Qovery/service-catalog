# Attach to the Qovery cluster network by default (like the managed RDS blueprints). The
# cluster VPC is tagged ClusterId = <cluster short id>; workers share a known SG. Lookups are
# skipped when the user provides explicit subnet/security-group overrides.
data "aws_vpc" "cluster" {
  count = var.subnet_ids == "" ? 1 : 0

  filter {
    name   = "tag:ClusterId"
    values = [var.qovery_cluster_id]
  }
}

data "aws_subnets" "cluster" {
  count = var.subnet_ids == "" ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.cluster[0].id]
  }
}

data "aws_security_group" "cluster_workers" {
  count = var.security_group_ids == "" ? 1 : 0

  # A user-provided VPC's worker security group follows no Qovery naming convention, so the name
  # filter would match nothing there. The cluster-ownership tag below identifies it in both cases.
  dynamic "filter" {
    for_each = var.qovery_user_provided_network ? [] : [1]

    content {
      name   = "tag:Name"
      values = ["qovery-${var.qovery_cluster_id}-sg-workers", "qovery-eks-workers"]
    }
  }

  filter {
    name   = "tag:kubernetes.io/cluster/qovery-${var.qovery_cluster_id}"
    values = ["owned"]
  }
}

locals {
  subnet_ids = (
    var.subnet_ids != "" ? [for s in split(",", var.subnet_ids) : trimspace(s)]
    : data.aws_subnets.cluster[0].ids
  )
  security_group_ids = (
    var.security_group_ids != "" ? [for id in split(",", var.security_group_ids) : trimspace(id)]
    : [data.aws_security_group.cluster_workers[0].id]
  )
}

resource "aws_msk_serverless_cluster" "this" {
  cluster_name = var.cluster_name

  vpc_config {
    subnet_ids         = local.subnet_ids
    security_group_ids = local.security_group_ids
  }

  # Serverless MSK supports SASL/IAM auth only — clients authenticate with their AWS IAM identity.
  client_authentication {
    sasl {
      iam {
        enabled = true
      }
    }
  }

  tags = {
    Name        = var.cluster_name
    ManagedBy   = "qovery-blueprint"
    Blueprint   = "aws-msk"
    ClusterName = var.qovery_cluster_name
  }
}
