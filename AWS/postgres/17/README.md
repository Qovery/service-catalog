# AWS RDS PostgreSQL 17

Creates an AWS RDS PostgreSQL 17 instance with configurable instance class, storage, backups, maintenance window, monitoring, and network settings. Storage is encrypted by default.

The RDS identifier is derived from `db_name` by lowercasing and replacing underscores with hyphens (AWS requirement). The actual PostgreSQL database name is kept as provided.

## Variables

### Required

| Name          | Type   | Sensitive | Description                                                                                                                   |
| ------------- | ------ | --------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `db_name`     | string |           | PostgreSQL database name. Letters, digits, underscores only; must start with a letter; max 63 chars. Hyphens are not allowed. |
| `db_username` | string |           | Master username. Letters, digits, underscores; must start with a letter; max 63 chars.                                        |
| `db_password` | string | yes       | Master password. 8–128 chars. Must not contain `/`, `@`, `"`, or spaces.                                                      |

### Instance & storage

| Name                | Type   | Default       | Description                                                    |
| ------------------- | ------ | ------------- | -------------------------------------------------------------- |
| `instance_class`    | string | `db.t3.micro` | RDS instance class                                             |
| `port`              | number | `5432`        | Database port                                                  |
| `allocated_storage` | number | `20`          | Allocated storage in GiB (min 20, max 65536)                   |
| `storage_type`      | string | `gp3`         | EBS storage type: `gp2`, `gp3`, `io1`, `io2`                   |
| `storage_encrypted` | bool   | `true`        | Encrypt storage at rest                                        |
| `disk_iops`         | number | `0`           | Provisioned IOPS (io1/io2 or gp3 ≥400 GiB). `0` = AWS default. |

### Network

| Name                   | Type   | Default | Description                                                |
| ---------------------- | ------ | ------- | ---------------------------------------------------------- |
| `multi_az`             | bool   | `false` | Enable Multi-AZ deployment                                 |
| `publicly_accessible`  | bool   | `false` | Expose the database to the public internet                 |
| `db_subnet_group_name` | string | `""`    | Optional DB subnet group. Empty = AWS default for the VPC. |

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
| `monitoring_role_arn`                   | string | `""`                | IAM role ARN for enhanced monitoring. Required when `monitoring_interval > 0`. |
| `ca_cert_identifier`                    | string | `rds-ca-rsa2048-g1` | CA certificate identifier                                                      |

### Misc

| Name                                  | Type   | Default | Description                                        |
| ------------------------------------- | ------ | ------- | -------------------------------------------------- |
| `option_group_name`                   | string | `""`    | Optional option group. Empty = AWS default.        |
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
| `db_password`              | yes       | Master password (echo of the input)                        |
| `db_resource_id`           |           | RDS internal resource ID (used in IAM DB auth ARNs)        |
| `db_arn`                   |           | RDS instance ARN                                           |
| `db_engine_version_actual` |           | Engine version actually running (incl. AWS-chosen minor)   |

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
