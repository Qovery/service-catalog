# AWS ElastiCache for Valkey 8

Creates an AWS ElastiCache for Valkey 8 replication group with configurable node type, topology, backups, maintenance window, and network settings. Traffic is encrypted in transit and protected by an auth token, and data is encrypted at rest.

The replication group id is `valkey_name` lowercased (AWS requirement). Applications connect over TLS as the built-in `default` user with the auth token as password: `rediss://default:<token>@<host>:6379/0`, published as the `valkey_url` output.

The `rediss://` scheme is correct here and not a leftover: Valkey speaks the Redis protocol, so Redis clients and URLs work unchanged — which is what makes it a drop-in replacement. Engine versions `8.0`, `8.1` and `8.2` all share the `valkey8` parameter group family, so any of them can be selected without changing the derived parameter group.

## Variables

### Required

| Name | Type | Sensitive | Description |
| ---- | ---- | --------- | ----------- |
| `valkey_name` | string | | Replication group name. Letters, digits, hyphens; must start with a letter; max 40 chars. Underscores are not allowed. |
| `instance_class` | string | | ElastiCache node type. Default suggestion: `cache.t3.micro`. |

Available node types: `cache.t3.micro`, `cache.t3.small`, `cache.t3.medium`, `cache.t4g.micro`, `cache.r6g.large`, `cache.r6g.xlarge` — the same set the Redis blueprint offers.

### Credentials

| Name | Type | Sensitive | Default | Description |
| ---- | ---- | --------- | ------- | ----------- |
| `valkey_password` | string | yes | _generated_ | Omit and Qovery generates a 32-character alphanumeric auth token. To set your own: 16–128 chars, must not contain /, @, ", or spaces. |

In the Console, leaving the field blank omits it. Through the API or Terraform, omit the variable rather than sending an empty string: the platform rejects an empty variable value.

### Instance & topology

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `engine_version` | string | `8.0` | Valkey engine version: `8.0`, `8.1`, `8.2` |
| `port` | number | `6379` | Valkey port |
| `instances_number` | number | `1` | Node groups (shards). Above 1 enables cluster mode. |
| `parameter_group_name` | string | | Leave empty — derived from the topology. |

`instances_number = 1` creates a single node with no replica. Above 1, the group switches to cluster mode: `N` shards, one replica each (so `2N` nodes), with automatic failover and Multi-AZ enabled because AWS requires both there, and the `default.valkey8.cluster.on` parameter group instead of `default.valkey8`. Clients then need a cluster-aware Valkey library and the `valkey_configuration_endpoint_address` output.

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

By default the group is attached to the Qovery cluster network: the ElastiCache subnet group created at cluster bootstrap (named `elasticache-<cluster vpc id>`) and the cluster workers security group, so pods in the cluster can reach Valkey out of the box. On clusters deployed into an existing VPC (user-provided network), the `ClusterId` tag lookup may not resolve and the bootstrap subnet group may not exist; set both variables explicitly in that case.

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
| `valkey_identifier` | | ElastiCache replication group id (AWS console cluster name) |
| `valkey_host` | | Hostname to connect to (configuration endpoint in cluster mode, primary endpoint otherwise) |
| `valkey_port` | | Valkey port |
| `valkey_username` | | Always `default`, the built-in Valkey user |
| `valkey_password` | yes | Auth token (generated when the input was left empty) |
| `valkey_url` | yes | `rediss://default:<token>@<host>:<port>/0` |
| `valkey_primary_endpoint_address` | | Primary endpoint hostname (empty in cluster mode) |
| `valkey_reader_endpoint_address` | | Reader endpoint hostname, load-balanced across replicas (empty in cluster mode) |
| `valkey_configuration_endpoint_address` | | Configuration endpoint hostname (empty when `instances_number = 1`) |
| `valkey_arn` | | Replication group ARN |
| `valkey_engine_version_actual` | | Engine version actually running (incl. AWS-chosen patch) |
| `valkey_member_clusters` | | Cache cluster ids making up the replication group |

## Lifecycle ignore_changes

- `auth_token` — ElastiCache never returns it, so any configured value would show a perpetual diff. Rotation is therefore not managed here: rotate out-of-band and update `valkey_password` to keep the output truthful.
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
