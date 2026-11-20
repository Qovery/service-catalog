# Amazon MSK (Serverless)

Provisions an [Amazon MSK Serverless](https://docs.aws.amazon.com/msk/latest/developerguide/serverless.html) cluster (`aws_msk_serverless_cluster`) — managed Apache Kafka with no broker sizing — via `hashicorp/aws` (`~> 5.0`).

## Credentials & networking

Uses the Qovery cluster's AWS credentials (`credentials.default: cluster`). By default the cluster attaches to the **Qovery cluster network**: the cluster VPC subnets and workers security group are auto-discovered via the `ClusterId` tag (like the managed RDS blueprints), so in-cluster apps can reach it. Override with `subnet_ids` / `security_group_ids` on clusters where the tag lookup doesn't resolve (user-provided VPC).

## Variables

### Required

| Name           | Type   | Description                                              |
| -------------- | ------ | -------------------------------------------------------- |
| `cluster_name` | string | MSK Serverless cluster name (letters, digits, dots, hyphens, underscores; max 64) |

### Network overrides

| Name                 | Type   | Default | Description                                                              |
| -------------------- | ------ | ------- | ------------------------------------------------------------------------ |
| `subnet_ids`         | string |         | Leave empty — discovered from the Qovery cluster's VPC subnets. Set it (comma-separated ids) only on a cluster with a user-provided VPC, where that lookup finds nothing. |
| `security_group_ids` | string |         | Leave empty — derived from the Qovery cluster's workers security group. Set it (comma-separated ids) only on a cluster with a user-provided VPC, where that lookup finds nothing. |

### IAM role

| Name       | Type   | Default | Description                                                                                                                                         |
| ---------- | ------ | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `role_arn` | string | —       | Unset = use the cluster credentials directly. Set an IAM role ARN of the cluster's AWS account to assume it; cross-account roles are not supported. |

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

## Assuming an IAM role

Optional. Set the `role_arn` variable to make the blueprint assume an IAM role instead of using the configured credentials directly; leave it unset to use them as is.

- Format: `arn:aws:iam::<account-id>:role/<name>`, with an optional path (`role/<path>/<name>`). The `aws-cn`, `aws-us-gov` and `aws-iso*` partitions are accepted too.
- The role must be in the **same AWS account** as the credentials; cross-account roles are not supported.
- The deploy credentials need `sts:AssumeRole` on that role, **and** the role's trust policy must allow the deploy credentials' IAM principal to assume it. Without both, the deployment fails with `AccessDenied`.
- The role itself must carry the permissions listed in [Required AWS IAM permissions](#required-aws-iam-permissions-to-deploy).

## Required AWS IAM permissions (to deploy)

> When `role_arn` is set, Terraform makes these AWS calls as the assumed role, so the permissions below belong to that role; the deploy credentials then only need `sts:AssumeRole` on it for those calls (see [Assuming an IAM role](#assuming-an-iam-role)). Access to a user-provided Terraform backend, if you use one, is not covered by `role_arn`: it keeps using the deploy credentials.

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
