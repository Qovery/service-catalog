# AWS ElastiCache for Redis 6 (legacy single node)

Adopts an existing single-node AWS ElastiCache for Redis 6 cluster (`aws_elasticache_cluster`), the shape native Qovery-managed Redis created when the login was `qoveryadmin`. It brings the live cluster under a blueprint via `terraform import`, with no re-provision and no data movement.

**Import only.** `import_identifier` is required, so this blueprint cannot create a cluster. A single-node ElastiCache cluster supports neither an auth token nor TLS, so a new Redis must use the `aws-elasticache-redis` blueprint instead. Applications keep connecting as before: `redis://<host>:6379/0`, published as the `redis_url` output.

## Variables

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `import_identifier` | string | | Live cluster id to adopt. Required. Not shown in the console: Qovery's migration sets it. |
| `redis_name` | string | | Display name, set as the `Name` tag |
| `engine_version` | string | `6.2` | Engine version of the adopted cluster: `6.0`, `6.2`. Ignored after adoption. |
| `instance_class` | string | | Node type of the adopted cluster |
| `port` | number | `6379` | Redis port |
| `parameter_group_name` | string | | Parameter group of the adopted cluster (native: `default.redis6.x`) |
| `legacy_connection_username`, `legacy_connection_password` | string | | Values held in the legacy connection variables, republished as `db_username` / `db_password` so those variables keep refreshing. Not used for auth. Qovery's migration sets them. |
| `apply_changes_now` | bool | `false` | Apply changes immediately instead of during the maintenance window |
| `preferred_maintenance_window` | string | `Tue:02:00-Tue:04:00` | Maintenance window (UTC). Ignored after adoption. |
| `preferred_backup_window` | string | `00:00-01:00` | Daily snapshot window (UTC), used when `backup_retention_period > 0` |
| `backup_retention_period` | number | `14` | Days to retain automatic snapshots (0 disables) |
| `skip_final_snapshot` | bool | `false` | Skip the final snapshot on deletion |

The node count is fixed at 1, like the native template.

## Outputs

| Name | Sensitive | Description |
| ---- | --------- | ----------- |
| `redis_identifier` | | ElastiCache cluster id |
| `redis_host` | | Hostname to connect to |
| `redis_port` | | Redis port |
| `redis_url` | | `redis://<host>:<port>/0` (no auth, no TLS) |
| `redis_arn` | | Cluster ARN |
| `redis_engine_version_actual` | | Engine version actually running |
| `db_username`, `db_password` | `db_password` | Legacy connection values, republished unchanged |
| `db_identifier`, `db_address`, `db_port`, `db_name` | | Aliases of the `redis_*` outputs above (`db_name` is always `0`), named like the RDS blueprints so Qovery can take over a native managed Redis |

## Lifecycle ignore_changes

- `engine_version` — AWS reports its own version format back; an adopted engine is never mutated.
- `maintenance_window`, `log_delivery_configuration`, `notification_topic_arn`, `auto_minor_version_upgrade` — the same list the native template ignores.
- `tags` — preserves native tags (`cluster_id` drives YACE metrics).

## Required AWS IAM permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticache:DescribeCacheClusters",
        "elasticache:ModifyCacheCluster",
        "elasticache:DeleteCacheCluster",
        "elasticache:DescribeCacheParameterGroups",
        "elasticache:DescribeCacheSubnetGroups",
        "elasticache:CreateSnapshot",
        "elasticache:DescribeSnapshots",
        "elasticache:AddTagsToResource",
        "elasticache:RemoveTagsFromResource",
        "elasticache:ListTagsForResource"
      ],
      "Resource": "*"
    }
  ]
}
```
