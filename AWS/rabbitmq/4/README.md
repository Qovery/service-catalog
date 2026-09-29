# Amazon MQ for RabbitMQ 4

Creates an Amazon MQ for RabbitMQ 4 broker, reachable over AMQPS (port 5671, TLS only), on a single
node or as a three-node cluster spread across availability zones. By default the broker joins the
Qovery cluster network, in the private subnets of the cluster's DB subnet group, with its own
security group opening 5671 and 443 to the VPC, so pods reach it with no extra setup.

The broker carries an Amazon MQ configuration holding `consumer_timeout`, `heartbeat` and any
`extra_configuration` lines. Storage is EBS, encrypted at rest.

**Before the first deploy**, give the deploying identity the Amazon MQ permissions listed in
[Required AWS IAM permissions](#required-aws-iam-permissions). The Qovery IAM policy does not
include `mq:*`, so with the default cluster credentials the deploy fails on the first Amazon MQ
call with `AccessDeniedException: ... is not authorized to perform: mq:CreateConfiguration`.
No broker or configuration is created when that happens. With `general_logs = true`, the
CloudWatch Logs resource policy is created in parallel and can remain: delete the service to
remove it.

## Variables

### Required

| Name | Type | Description |
| ---- | ---- | ----------- |
| `broker_name` | string | Broker name, unique in the AWS account and region. Letters, digits, hyphens, underscores; max 50 chars. |
| `host_instance_type` | string | Broker instance type, `mq.m7g.medium` to `mq.m7g.16xlarge`. RabbitMQ 4 runs on `mq.m7g` only. Default suggestion: `mq.m7g.medium` (evaluation); use `mq.m7g.large` or above in production. |
| `deployment_mode` | string | `SINGLE_INSTANCE` or `CLUSTER_MULTI_AZ` (three nodes). Changing it replaces the broker. Default suggestion: `SINGLE_INSTANCE`. |

### Engine

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `engine_version` | string | `4.3` | `4.2` or `4.3`. Amazon MQ applies patch versions itself: automatic minor upgrades are required on RabbitMQ 3.13 and later, so they are always on. |

### Credentials

| Name | Type | Sensitive | Default | Description |
| ---- | ---- | --------- | ------- | ----------- |
| `admin_username` | string | | `qoveryadmin` | 2-100 chars: letters, digits, `-` `.` `_` `~`; `guest` is refused at deploy. |
| `admin_password` | string | yes | _generated_ | Omit and Qovery generates a 32-character password (letters, digits, - _ . !). To set your own: 12-250 chars, no comma, colon or equals sign, at least 4 distinct characters. |

Both are set **at creation only**. Amazon MQ cannot update RabbitMQ users and never returns them,
so the blueprint ignores later edits to the `user` block, and the `username`, `password` and
`amqp_url` outputs keep the values the broker was created with. Editing either variable afterwards
has no effect. Change the password in the RabbitMQ management UI instead, then update your
applications. A replaced broker (for example after a `deployment_mode` change) is created with the
current values, and the outputs follow.

### Network

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `publicly_accessible` | bool | `false` | Expose the broker to the internet. Changing it replaces the broker. |
| `subnet_ids` | string | | Leave empty — derived from the Qovery cluster's DB subnet group. Set it (comma-separated, one per AZ) only on a user-provided VPC. |
| `security_group_ids` | string | | Leave empty and the blueprint creates a security group opening 5671 and 443 to `allowed_cidrs`. Set it (comma-separated ids) to use your own groups. Set at creation only. |
| `allowed_cidrs` | string | | Leave empty to allow the whole VPC (every pod in the cluster). Set comma-separated CIDRs to narrow or widen access. Ignored when `security_group_ids` is set. |

A single-instance broker takes the first subnet (one per availability zone, sorted by zone name);
a cluster takes up to three. On a cluster deployed into an existing VPC, the `ClusterId` lookup may
find nothing: set `subnet_ids` explicitly. The security group is then created in the VPC of those
subnets.

The blueprint does not reuse the cluster workers security group, as the RDS blueprints do. That
group only opens the ports of the native databases (5432, 3306, 6379), and nodes started by
Karpenter carry the EKS cluster security group instead, so pods could not reach the broker.

Amazon MQ does not let a RabbitMQ broker change security groups, so `security_group_ids` is set at
creation and later edits are ignored. `allowed_cidrs` can change at any time: it edits the rules of
the blueprint's group, not the group attached to the broker.

A public broker is hosted by Amazon MQ outside the VPC and cannot have a security group: anyone who
has the credentials can connect. Keep it private unless a client outside AWS needs it.

### Maintenance

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `apply_changes_now` | bool | `false` | Apply changes at once (the broker reboots). Off: they wait for the maintenance window. |
| `maintenance_day_of_week` | string | `SUNDAY` | Maintenance window day |
| `maintenance_time_of_day` | string | `03:00` | Maintenance window start, `hh:mm` in 24-hour format |
| `maintenance_time_zone` | string | `UTC` | Maintenance window time zone, e.g. `UTC` or `Europe/Paris` |

Instance type, engine version and configuration changes all need a reboot. With
`apply_changes_now = false` the deploy succeeds but the broker keeps the old settings until the
next maintenance window, and Terraform may keep showing the change as pending until then.

### RabbitMQ settings

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `consumer_timeout_ms` | number | `1800000` | Ack timeout in ms: a consumer that does not ack in time has its channel closed. `0` = no timeout. |
| `heartbeat_seconds` | number | `60` | Seconds without traffic before RabbitMQ considers a connection dead (60-3600) |
| `extra_configuration` | string | | Extra `rabbitmq.conf` lines, separated by `;`. Amazon MQ rejects keys it does not allow at apply. |

For example, `management.restrictions.operator_policy_changes.disabled = false` lets you edit
operator policies. See
[Configurable values](https://docs.aws.amazon.com/amazon-mq/latest/developer-guide/configurable-values.html)
for the keys Amazon MQ accepts.

### Logs & encryption

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `general_logs` | bool | `false` | Send broker logs to CloudWatch Logs (billed by CloudWatch). |
| `kms_key_id` | string | | Empty = encrypted with an AWS-owned key. Set a KMS key ARN to use your own key. Changing it replaces the broker. |

Amazon MQ can only publish logs once a CloudWatch Logs resource policy lets it. With
`general_logs = true` the blueprint creates one, named `qovery-amazonmq-<broker_name>`. AWS allows
10 such policies per region.

## Outputs

| Name | Sensitive | Description |
| ---- | --------- | ----------- |
| `broker_id` | | Amazon MQ broker id |
| `broker_arn` | | Amazon MQ broker ARN |
| `amqps_endpoint` | | `amqps://<host>:5671` |
| `host` | | Broker hostname |
| `port` | | `5671` (TLS only; Amazon MQ does not expose plain AMQP) |
| `console_url` | | RabbitMQ management UI URL |
| `username` | | Admin username the broker was created with |
| `password` | yes | Admin password the broker was created with |
| `amqp_url` | yes | `amqps://<user>:<password>@<host>:5671`, URL-encoded |
| `configuration_id` | | Amazon MQ configuration holding the `rabbitmq.conf` settings |

## Required AWS IAM permissions

The identity that deploys the blueprint needs the actions below. With `credentials: cluster` (the
default) that is the cluster's IAM role, `qovery-user-role` on a standard installation: attach them
to it as an extra policy. With `credentials: env`, the keys you supply need them. The EC2 and RDS
read actions let Terraform find the cluster subnets, and the security group actions create the
broker's own group; the `logs` actions are only used with `general_logs = true`.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "mq:CreateBroker",
        "mq:DeleteBroker",
        "mq:DescribeBroker",
        "mq:UpdateBroker",
        "mq:RebootBroker",
        "mq:CreateConfiguration",
        "mq:DeleteConfiguration",
        "mq:DescribeConfiguration",
        "mq:DescribeConfigurationRevision",
        "mq:UpdateConfiguration",
        "mq:ListConfigurationRevisions",
        "mq:CreateTags",
        "mq:DeleteTags",
        "mq:ListTags",
        "mq:CreateUser",
        "mq:DescribeUser",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:CreateTags",
        "ec2:CreateNetworkInterface",
        "ec2:CreateNetworkInterfacePermission",
        "ec2:DeleteNetworkInterface",
        "ec2:DeleteNetworkInterfacePermission",
        "ec2:DetachNetworkInterface",
        "ec2:DescribeInternetGateways",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeNetworkInterfacePermissions",
        "ec2:DescribeRouteTables",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs",
        "rds:DescribeDBSubnetGroups",
        "logs:PutResourcePolicy",
        "logs:DeleteResourcePolicy",
        "logs:DescribeResourcePolicies"
      ],
      "Resource": "*"
    }
  ]
}
```
