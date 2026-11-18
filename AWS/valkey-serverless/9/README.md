# AWS ElastiCache Serverless for Valkey 9

Creates an AWS ElastiCache Serverless cache on Valkey 9. There is no node type or shard count to pick: AWS scales the cache with the load and bills the data stored and the ECPUs consumed. Traffic is encrypted in transit, data is encrypted at rest, and access goes through a password-protected user.

For a cache with a fixed node type, use the `aws-elasticache-valkey` blueprint instead.

## Connecting

Three things differ from the node-based blueprint:

- **Use a cluster-mode client.** A serverless cache always runs in cluster mode, and AWS only supports clients that speak the cluster protocol. Multi-key commands only work on keys that share a hash slot; across slots they fail with `CROSSSLOT`.
- **Two ports.** The cache serves writes and consistent reads on `6379` and replica reads on `6380`, on the same hostname. Many clients open connections to both, so the security group opens both.
- **A user name is required.** Applications authenticate as the `app` user with `valkey_password`. There is no auth token and no usable `default` user.

The `valkey_url` output carries all of it: `rediss://app:<password>@<host>:6379`. The `rediss://` scheme is correct: Valkey speaks the Redis protocol, and TLS is always on.

## Variables

### Required

| Name | Type | Sensitive | Description |
| ---- | ---- | --------- | ----------- |
| `valkey_name` | string | | Cache name, lowercased by AWS. Must start with a letter, end with a letter or digit, and use single hyphens between them; max 32 chars. Underscores are not allowed. |

The limit is 32 characters to leave room for the suffixes of the user id (`<name>-app`) and the user group id (`<name>-users`), which ElastiCache caps at 40.

### Credentials

| Name | Type | Sensitive | Default | Description |
| ---- | ---- | --------- | ------- | ----------- |
| `valkey_password` | string | yes | _generated_ | Omit and Qovery generates a 32-character alphanumeric password. To set your own: 16–128 chars, must not contain a comma, /, @, ", or spaces. |

In the Console, leaving the field blank omits it. Through the API or Terraform, omit the variable rather than sending an empty string: the platform rejects an empty variable value.

Changing `valkey_password` replaces the password in place, without touching the cache or its data. AWS takes a few minutes to apply it (close to four in testing). Applications still holding the old one must be redeployed with the new value.

### Usage limits

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `data_storage_max_gb` | number | `0` | Most data the cache may store, in whole GB (1–5000). `0` = the AWS maximum, 5000 GB. |
| `ecpu_per_second_max` | number | `0` | Most ECPUs per second the cache may use, a whole number (1000–15000000). `0` = the AWS maximum, 15000000. |

With both at `0`, the cache scales as far as AWS allows. A cap bounds the bill as well as the capacity.

The blueprint always sends both limits, with `0` translated to the AWS maximum. A cache whose limits are removed altogether cannot be updated: AWS rejects the call with `No modifications were requested`.

### Network

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `subnet_ids` | string | | Leave empty — derived from the Qovery cluster's ElastiCache subnet group. Set it (comma-separated, one per Availability Zone) only on a cluster with a user-provided VPC, where that lookup finds nothing. Read at creation only. |
| `security_group_ids` | string | | Leave empty for the blueprint's own security group. Set it (comma-separated ids) to attach existing groups instead; they must open 6379 and 6380 to the cluster. |
| `allowed_cidrs` | string | | Leave empty to allow the whole VPC, which covers every pod of the cluster. Set it (comma-separated IPv4 network addresses, such as `10.0.0.0/24`) to narrow the blueprint's security group. Ignored when `security_group_ids` is set. |

By default the cache is attached to the Qovery cluster network. The subnets come from the ElastiCache subnet group created at cluster bootstrap (`elasticache-<cluster vpc id>`): one subnet per Availability Zone, three at most. The security group is created by the blueprint, named `qovery-valkey-serverless-<name>`, and opens 6379–6380 to every CIDR of the VPC. It does not reuse the cluster workers security group, which opens 6379 only.

ElastiCache cannot move a serverless cache to other subnets, so `subnet_ids` is read once. A later change to the variable or to the cluster's subnet group leaves the cache where it is.

### Backups

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `backup_retention_period` | number | `14` | Whole days to retain daily automatic snapshots (0–35). `0` disables. |
| `daily_snapshot_time` | string | `00:00` | Time of the daily snapshot (UTC), `hh24:mi`. Only used when `backup_retention_period > 0`. |

**Deleting the service deletes the cache without a final snapshot.** The AWS Terraform provider has no argument for one on a serverless cache. To keep the data, take a manual snapshot in AWS before deleting the service.

## Outputs

| Name | Sensitive | Description |
| ---- | --------- | ----------- |
| `valkey_identifier` | | ElastiCache serverless cache name |
| `valkey_host` | | Hostname to connect to, for cluster-mode clients |
| `valkey_port` | | Port of the primary endpoint (`6379`), for writes and consistent reads |
| `valkey_reader_port` | | Port of the reader endpoint (`6380`), on the same hostname |
| `valkey_username` | | Valkey user applications authenticate as (`app`) |
| `valkey_password` | yes | Password of that user (generated when the input was left empty) |
| `valkey_url` | yes | `rediss://app:<password>@<host>:<port>` on the primary endpoint |
| `valkey_arn` | | Serverless cache ARN |
| `valkey_engine_version_actual` | | Engine version actually running (incl. AWS-chosen patch) |
| `valkey_security_group_id` | | Security group created for the cache (empty when `security_group_ids` is set) |

## Access control

The blueprint creates one ElastiCache user and one user group, both on the `valkey` engine, and attaches the group to the cache:

- user `<name>-app`, user name `app`, access string `on ~* &* +@all` (every key, every pub/sub channel, every command), authenticated by password;
- user group `<name>-users`, holding that user.

Terraform manages the membership list of the group: a user added to it outside the blueprint is removed on the next deployment.

## Lifecycle ignore_changes

- `subnet_ids` — set at creation; see [Network](#network).

## Required AWS IAM permissions

The credentials used to deploy this blueprint must allow the actions below. The EC2 read actions let Terraform look up the cluster VPC and its subnets. `ec2:CreateVpcEndpoint`, the `ec2:CreateTags` that goes with it and `iam:CreateServiceLinkedRole` are the ones the AWS managed policy `AmazonElastiCacheFullAccess` grants for serverless caches: ElastiCache places a VPC endpoint in the chosen subnets.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticache:CreateServerlessCache",
        "elasticache:ModifyServerlessCache",
        "elasticache:DeleteServerlessCache",
        "elasticache:DescribeServerlessCaches",
        "elasticache:CreateUser",
        "elasticache:ModifyUser",
        "elasticache:DeleteUser",
        "elasticache:DescribeUsers",
        "elasticache:CreateUserGroup",
        "elasticache:ModifyUserGroup",
        "elasticache:DeleteUserGroup",
        "elasticache:DescribeUserGroups",
        "elasticache:DescribeCacheSubnetGroups",
        "elasticache:AddTagsToResource",
        "elasticache:RemoveTagsFromResource",
        "elasticache:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeAvailabilityZones",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:CreateTags",
        "ec2:CreateVpcEndpoint"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "iam:CreateServiceLinkedRole",
      "Resource": "arn:aws:iam::*:role/aws-service-role/elasticache.amazonaws.com/AWSServiceRoleForElastiCache",
      "Condition": {
        "StringEquals": { "iam:AWSServiceName": "elasticache.amazonaws.com" }
      }
    }
  ]
}
```
