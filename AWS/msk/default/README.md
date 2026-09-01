# Amazon MSK (Serverless)

Provisions an [Amazon MSK Serverless](https://docs.aws.amazon.com/msk/latest/developerguide/serverless.html) cluster (`aws_msk_serverless_cluster`) — managed Apache Kafka with no broker sizing — via `hashicorp/aws` (`~> 5.0`).

## Credentials & networking

Uses the Qovery cluster's AWS credentials (`credentials.default: cluster`). By default the cluster attaches to the **Qovery cluster network**: the cluster VPC subnets and workers security group are auto-discovered via the `ClusterId` tag (like the managed RDS blueprints), so in-cluster apps can reach it. Override with `subnet_ids` / `security_group_ids` on clusters where the tag lookup doesn't resolve (user-provided VPC).

## Variables

### Required

| Name           | Type   | Description                                              |
| -------------- | ------ | -------------------------------------------------------- |
| `cluster_name` | string | MSK Serverless cluster name (`^[a-zA-Z0-9._-]{1,64}$`)   |

### Network overrides

| Name                 | Type   | Default | Description                                                              |
| -------------------- | ------ | ------- | ------------------------------------------------------------------------ |
| `subnet_ids`         | string |         | Comma-separated subnet IDs. Unset = auto-discover the cluster VPC subnets. |
| `security_group_ids` | string |         | Comma-separated SG IDs. Unset = the cluster workers security group.       |

## Outputs

| Name                         | Description                                              |
| ---------------------------- | -------------------------------------------------------- |
| `cluster_arn`                | MSK Serverless cluster ARN                               |
| `cluster_name`               | Cluster name                                             |
| `cluster_uuid`               | Cluster UUID (used in IAM resource ARNs)                 |
| `bootstrap_brokers_sasl_iam` | Bootstrap brokers for SASL/IAM clients (connect target)  |

## Notes

- **Auth is SASL/IAM only** (MSK Serverless requirement): clients authenticate with their AWS IAM identity — no static passwords. The consuming workload's IAM role needs `kafka-cluster:*` permissions scoped to the cluster ARN/UUID, and its security group must be allowed by the cluster SG on the Kafka ports.
- MSK Serverless does not create networking; it attaches to existing subnets/SG (auto-discovered here).
- Billed per-throughput + storage (no idle broker-hour cost, unlike provisioned MSK).

## Required AWS IAM permissions (to deploy)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kafka:CreateClusterV2",
        "kafka:DeleteCluster",
        "kafka:DescribeClusterV2",
        "kafka:TagResource",
        "kafka:UntagResource",
        "kafka:ListTagsForResource",
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups"
      ],
      "Resource": "*"
    }
  ]
}
```
