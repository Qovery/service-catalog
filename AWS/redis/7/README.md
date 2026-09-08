# AWS ElastiCache for Redis 7

Creates an AWS ElastiCache for Redis 7 replication group with configurable node type, topology, backups, maintenance window, and network settings. Traffic is encrypted in transit and protected by an auth token, and data is encrypted at rest.

The replication group id is `redis_name` lowercased (AWS requirement). Applications connect over TLS as the built-in `default` user with the auth token as password: `rediss://default:<token>@<host>:6379/0`, published as the `redis_url` output.

## Variables

### Required

| Name | Type | Sensitive | Description |
| ---- | ---- | --------- | ----------- |
| `redis_name` | string | | Replication group name. Letters, digits, hyphens; must start with a letter; max 40 chars. Underscores are not allowed. |
| `instance_class` | string | | ElastiCache node type. Default suggestion: `cache.t3.micro`. |

Available node types: `cache.t3.micro`, `cache.t3.small`, `cache.t3.medium`, `cache.t4g.micro`, `cache.r6g.large`, `cache.r6g.xlarge`.

### Credentials

| Name | Type | Sensitive | Default | Description |
| ---- | ---- | --------- | ------- | ----------- |
| `redis_password` | string | yes | _generated_ | Omit and Qovery generates a 32-character alphanumeric auth token. To set your own: 16–128 chars, must not contain /, @, ", or spaces. |

In the Console, leaving the field blank omits it. Through the API or Terraform, omit the variable rather than sending an empty string: the platform rejects an empty variable value.

### Instance & topology

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `engine_version` | string | `7.0` | Redis engine version: `7.0`, `7.1` |
| `port` | number | `6379` | Redis port |
| `instances_number` | number | `1` | Node groups (shards). Above 1 enables cluster mode. |
| `parameter_group_name` | string | | Leave empty — derived from the topology. |

`instances_number = 1` creates a single node with no replica. Above 1, the group switches to cluster mode: `N` shards, one replica each (so `2N` nodes), with automatic failover and Multi-AZ enabled because AWS requires both there, and the `default.redis7.cluster.on` parameter group instead of `default.redis7`. Clients then need a cluster-aware Redis library and the `redis_configuration_endpoint_address` output.

**Pick the topology at creation.** ElastiCache cannot turn cluster mode on for an existing group, so raising `instances_number` from 1 fails at apply rather than resharding — deploy a new service instead. Changing it between two cluster-mode values (2 → 4) does reshard in place.

### Security

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `at_rest_encryption_enabled` | bool | `true` | Encrypt data at rest |

Encryption in transit is always on and is not a variable: ElastiCache only accepts an auth token on a TLS-enabled group, so a group without TLS would also be a group reachable with no password by anything inside the cluster security group. Clients must connect with `rediss://`.

### Network

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `subnet_group_name` | string | | Leave empty — the Qovery cluster ElastiCache subnet group. Set only on a user-provided VPC. |
| `security_group_ids` | string | | Leave empty — the Qovery cluster workers security group. Set only on a user-provided VPC. |

By default the group is attached to the Qovery cluster network: the ElastiCache subnet group created at cluster bootstrap (named `elasticache-<cluster vpc id>`) and the cluster workers security group, so pods in the cluster can reach Redis out of the box. On clusters deployed into an existing VPC (user-provided network), the `ClusterId` tag lookup may not resolve and the bootstrap subnet group may not exist; set both variables explicitly in that case.

### Maintenance & upgrades

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `apply_changes_now` | bool | `false` | Apply changes immediately |
| `auto_minor_version_upgrade` | bool | `true` | Auto-apply minor version upgrades during maintenance |
| `preferred_maintenance_window` | string | `Tue:02:00-Tue:04:00` | Maintenance window (UTC), `ddd:hh24:mi-ddd:hh24:mi` |

The window is lowercased before it reaches AWS, which is how AWS stores and reports it, so a changed window applies without leaving a diff behind.

### Backups

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `preferred_backup_window` | string | `00:00-01:00` | Daily snapshot window (UTC), `hh24:mi-hh24:mi` |
| `backup_retention_period` | number | `14` | Days to retain automatic snapshots (0–35). `0` disables. |
| `skip_final_snapshot` | bool | `false` | Skip the final snapshot on deletion |
| `snapshot_name` | string | | Existing snapshot to seed the group from. Unset = start empty. |

With `skip_final_snapshot = false`, destroying the service leaves a snapshot named `<replication group id>-final-snap-<creation timestamp>` behind, which keeps costing storage until deleted. The timestamp is stamped once at creation, so it is unique per group — successive create/destroy cycles of the same name do not collide on an existing snapshot id — while staying stable across plans. `snapshot_name` is read at creation only: pointing it at a different snapshot later does nothing.

## Outputs

| Name | Sensitive | Description |
| ---- | --------- | ----------- |
| `redis_identifier` | | ElastiCache replication group id (AWS console cluster name) |
| `redis_host` | | Hostname to connect to (configuration endpoint in cluster mode, primary endpoint otherwise) |
| `redis_port` | | Redis port |
| `redis_username` | | Always `default`, the built-in Redis user |
| `redis_password` | yes | Auth token (generated when the input was left empty) |
| `redis_url` | yes | `rediss://default:<token>@<host>:<port>/0` |
| `redis_primary_endpoint_address` | | Primary endpoint hostname (empty in cluster mode) |
| `redis_reader_endpoint_address` | | Reader endpoint hostname, load-balanced across replicas (empty in cluster mode) |
| `redis_configuration_endpoint_address` | | Configuration endpoint hostname (empty when `instances_number = 1`) |
| `redis_arn` | | Replication group ARN |
| `redis_engine_version_actual` | | Engine version actually running (incl. AWS-chosen patch) |
| `redis_member_clusters` | | Cache cluster ids making up the replication group |

## Lifecycle ignore_changes

- `auth_token` — ElastiCache never returns it, so any configured value would show a perpetual diff. Rotation is therefore not managed here: rotate out-of-band and update `redis_password` to keep the output truthful.
- `log_delivery_configuration`, `notification_topic_arn`, `user_group_ids` — configured outside the blueprint.
- `transit_encryption_mode` — AWS picks `preferred` vs `required` and reports its own value back.
- `tags` — preserves tags set on the group outside the blueprint.

`engine_version` is deliberately *not* ignored, so a version change applies. ElastiCache only upgrades forward.

## Required AWS IAM permissions

The credentials used to deploy this blueprint must allow the actions below. EC2 read actions are needed so Terraform can look up the cluster VPC and workers security group when the network variables are left empty.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticache:CreateReplicationGroup",
        "elasticache:DeleteReplicationGroup",
        "elasticache:ModifyReplicationGroup",
        "elasticache:ModifyReplicationGroupShardConfiguration",
        "elasticache:DescribeReplicationGroups",
        "elasticache:DescribeCacheClusters",
        "elasticache:DescribeCacheParameters",
        "elasticache:DescribeCacheParameterGroups",
        "elasticache:DescribeCacheSubnetGroups",
        "elasticache:DescribeEngineDefaultParameters",
        "elasticache:CreateSnapshot",
        "elasticache:DescribeSnapshots",
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
        "ec2:DescribeAvailabilityZones"
      ],
      "Resource": "*"
    }
  ]
}
```
