# AWS RDS PostgreSQL 16

Creates an AWS RDS PostgreSQL 16 instance with configurable instance class, storage, backups, maintenance window, monitoring, and network settings. Storage is encrypted by default.

The RDS identifier is derived from `db_name` by lowercasing and replacing underscores with hyphens (AWS requirement). The actual PostgreSQL database name is kept as provided.

## Variables

### Required

| Name          | Type   | Sensitive | Description                                                                                                                   |
| ------------- | ------ | --------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `db_name`     | string |           | PostgreSQL database name. Letters, digits, underscores only; must start with a letter; max 63 chars. Hyphens are not allowed. |
| `instance_class`    | string |           | RDS instance class. Default suggestion: `db.t3.micro`.                                             |
| `allocated_storage` | number |           | Allocated storage in GiB (min 20, max 65536). Default suggestion: `20`.                             |

### Credentials

Both are optional — omit them and Qovery supplies the values, the way native managed
databases did. Omit the variable entirely rather than sending an empty string: the platform
rejects an empty variable value.

| Name | Type | Sensitive | Default | Description |
| ---- | ---- | --------- | ------- | ----------- |
| `db_username` | string |  | `qoveryadmin` | Leave empty to use qoveryadmin, the login the native managed databases used. To set your own: letters, digits, underscores; must start with a letter; max 63 chars. Reserved names not allowed: admin, rdsadmin, rdsrepladmin, rdstopmgr, or any name starting with 'pg_'. |
| `db_password` | string | yes | _generated_ | Leave empty and Qovery generates a 32-character alphanumeric password. To set your own: 8–128 chars, must not contain /, @, ", or spaces. |

Adoption (`import_identifier` set) requires both explicitly. `username` is `ForceNew` on
`aws_db_instance`, so a defaulted value would plan a replacement and destroy the live
database; and RDS never returns the master password, so a generated one would be published
as the credential without ever being applied.

### Instance & storage

| Name                | Type   | Default       | Description                                                    |
| ------------------- | ------ | ------------- | -------------------------------------------------------------- |
| `port`              | number | `5432`        | Database port                                                  |
| `storage_type`      | string | `gp3`         | EBS storage type: `gp2`, `gp3`, `io1`, `io2`                   |
| `storage_encrypted` | bool   | `true`        | Encrypt storage at rest                                        |
| `disk_iops`         | number | `0`           | Provisioned IOPS (io1/io2 or gp3 ≥400 GiB). `0` = AWS default. |

### Network

| Name                   | Type   | Default | Description                                                                                              |
| ---------------------- | ------ | ------- | -------------------------------------------------------------------------------------------------------- |
| `multi_az`             | bool   | `false` | Enable Multi-AZ deployment                                                                               |
| `publicly_accessible`  | bool   | `false` | Expose the database to the public internet                                                               |
| `db_subnet_group_name` | string |         | Leave empty — the Qovery cluster DB subnet group. Set only on a user-provided VPC.                       |
| `security_group_ids`   | string |         | Leave empty — the Qovery cluster workers security group. Set only on a user-provided VPC (comma-separated ids if multiple). |

By default the instance is attached to the Qovery cluster network: the DB subnet group created at cluster bootstrap (named after the cluster VPC id) and the cluster workers security group, so pods in the cluster can reach the database out of the box. On clusters deployed into an existing VPC (user-provided network), the `ClusterId` tag lookup may not resolve; set `db_subnet_group_name` and `security_group_ids` explicitly in that case.

### Read replicas

| Name                               | Type   | Default | Description                                                                            |
| ---------------------------------- | ------ | ------- | -------------------------------------------------------------------------------------- |
| `read_replica_count`               | number | `0`     | Number of same-region read replicas (0 disables; max 15). Requires backups enabled.    |
| `read_replica_instance_class`      | string |         | Instance class for replicas. Unset = same as the primary.                              |
| `read_replica_publicly_accessible` | bool   | `false` | Expose replicas to the public internet.                                                |
| `read_replica_multi_az`            | bool   | `false` | Enable Multi-AZ for replicas.                                                           |

Read replicas are asynchronous read-only copies of the primary — point analytics/BI tools (Metabase, Superset, dashboards, ad-hoc reporting) at their endpoints to keep heavy read traffic off the primary. They inherit the primary's engine version, storage size, storage type, and encryption, and share its database name, master username, and password; connect with the same credentials at the replica endpoint. Because replication is asynchronous, replicas are eventually consistent (fine for analytics, not for read-after-write). Creating replicas requires automated backups on the primary (`backup_retention_period > 0`, the default). Replica endpoints are exposed via the `read_replica_endpoints` output. Analytics tools running inside the cluster can reach them over the cluster network out of the box; set `read_replica_publicly_accessible = true` only for tools that live outside the VPC.

### Maintenance & upgrades

| Name                           | Type   | Default               | Description                                          |
| ------------------------------ | ------ | --------------------- | ---------------------------------------------------- |
| `apply_changes_now`            | bool   | `false`               | Apply changes immediately                            |
| `allow_major_version_upgrade`  | bool   | `false`               | Allow major engine version upgrades on apply         |
| `auto_minor_version_upgrade`   | bool   | `true`                | Auto-apply minor version upgrades during maintenance |
| `preferred_maintenance_window` | string | `Tue:02:00-Tue:04:00` | Maintenance window (UTC), `ddd:hh24:mi-ddd:hh24:mi`  |

### Backups

| Name                       | Type   | Default       | Description                                  |
| -------------------------- | ------ | ------------- | -------------------------------------------- |
| `preferred_backup_window`  | string | `00:00-01:00` | Daily backup window (UTC), `hh24:mi-hh24:mi` |
| `backup_retention_period`  | number | `7`           | Days to retain backups (0–35). `0` disables. |
| `skip_final_snapshot`      | bool   | `true`        | Skip final snapshot on deletion              |
| `delete_automated_backups` | bool   | `true`        | Delete automated backups on deletion         |
| `copy_tags_to_snapshot`    | bool   | `true`        | Propagate instance tags to snapshots         |

### Monitoring

| Name                                    | Type   | Default             | Description                                                                    |
| --------------------------------------- | ------ | ------------------- | ------------------------------------------------------------------------------ |
| `performance_insights_enabled`          | bool   | `false`             | Enable RDS Performance Insights                                                |
| `performance_insights_retention_period` | number | `7`                 | PI retention in days (only when enabled). 7, 31, or k·31 ≤ 731.                |
| `monitoring_interval`                   | number | `0`                 | Enhanced monitoring interval seconds. `0` disables. 0/1/5/10/15/30/60.         |
| `monitoring_role_arn`                   | string |                     | IAM role ARN for enhanced monitoring. Required when `monitoring_interval > 0`. |
| `ca_cert_identifier`                    | string | `rds-ca-rsa2048-g1` | CA certificate identifier                                                      |

### Misc

| Name                                  | Type   | Default | Description                                        |
| ------------------------------------- | ------ | ------- | -------------------------------------------------- |
| `option_group_name`                   | string |         | Optional option group. Unset = AWS default.        |
| `deletion_protection`                 | bool   | `false` | Prevent deletion via TF/API                        |
| `iam_database_authentication_enabled` | bool   | `false` | Enable IAM DB authentication                       |
| `dedicated_log_volume`                | bool   | `false` | Provision a dedicated EBS volume for database logs |

## Outputs

| Name                       | Sensitive | Description                                                |
| -------------------------- | --------- | ---------------------------------------------------------- |
| `db_identifier`            |           | RDS instance identifier (AWS console instance name)        |
| `db_endpoint`              |           | RDS instance endpoint (host:port)                          |
| `db_address`               |           | RDS instance hostname                                      |
| `db_port`                  |           | RDS instance port                                          |
| `db_name`                  |           | Database name                                              |
| `db_username`              |           | Master username                                            |
| `db_password`              | yes       | Master password (generated when the input was left empty)                        |
| `db_resource_id`           |           | RDS internal resource ID (used in IAM DB auth ARNs)        |
| `db_arn`                   |           | RDS instance ARN                                           |
| `db_engine_version_actual` |           | Engine version actually running (incl. AWS-chosen minor)   |
| `read_replica_identifiers` |           | Read replica instance identifiers (empty when count = 0)   |
| `read_replica_endpoints`   |           | Read replica endpoints (host:port) for read-only clients   |
| `read_replica_addresses`   |           | Read replica hostnames                                     |
| `read_replica_host_1..5`       |       | Per-replica hostname, one output each (empty if not provisioned) |
| `read_replica_port_1..5`       |       | Per-replica port, one output each (empty if not provisioned)     |
| `read_replica_identifier_1..5` |       | Per-replica instance identifier, one output each                 |

## Lifecycle ignore_changes

A few attributes remain ignored:

- `final_snapshot_identifier` — `timestamp()` rotates the name every plan; only meaningful when a final snapshot is actually taken.
- `enabled_cloudwatch_logs_exports` — list type, not yet supported by the qbm.yml schema.
- `parameter_group_name` — AWS may auto-replace it during minor upgrades; override via the AWS console if needed.
- `max_allocated_storage` — will turn into a managed input when the storage autoscale feature is added.

## Required AWS IAM permissions

The credentials used to deploy this blueprint must allow the actions below. The RDS actions target instances in any region you deploy to; EC2 read actions are needed so Terraform can look up the default VPC, subnets, and security groups when none are explicitly configured.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "rds:CreateDBInstance",
        "rds:CreateDBInstanceReadReplica",
        "rds:DeleteDBInstance",
        "rds:ModifyDBInstance",
        "rds:DescribeDBInstances",
        "rds:DescribeDBParameters",
        "rds:DescribeDBSubnetGroups",
        "rds:DescribeDBSecurityGroups",
        "rds:AddTagsToResource",
        "rds:RemoveTagsFromResource",
        "rds:ListTagsForResource"
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

When `monitoring_interval > 0`, the supplied `monitoring_role_arn` must be assumable by RDS (`monitoring.rds.amazonaws.com` trust relationship) and grant the `AmazonRDSEnhancedMonitoringRole` managed policy.
