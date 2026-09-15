# AWS RDS MySQL 8.4

Creates an AWS RDS MySQL 8.4 instance with configurable instance class, storage, backups, maintenance window, monitoring, and network settings. Storage is encrypted by default.

A dedicated parameter group is attached with `log_bin_trust_function_creators = 1` so the master user can create triggers/stored procedures without superuser privileges.

The RDS identifier is derived from `db_name` by lowercasing and replacing underscores with hyphens (AWS requirement). The actual MySQL database name is kept as provided.

## Variables

### Required

| Name          | Type   | Sensitive | Description                                                                                                              |
| ------------- | ------ | --------- | ------------------------------------------------------------------------------------------------------------------------ |
| `db_name`     | string |           | MySQL database name. Letters, digits, underscores only; must start with a letter; max 64 chars. Hyphens are not allowed. |
| `instance_class`    | string |           | RDS instance class. Default suggestion: `db.t3.micro`.                                             |
| `allocated_storage` | number |           | Allocated storage in GiB (min 20, max 65536). Default suggestion: `20`.                             |

### Credentials

Both are optional — omit them and Qovery supplies the values, the way native managed
databases did. In the console, leaving the field blank omits it. Through the API or
Terraform, omit the variable rather than sending an empty string: the platform rejects an
empty variable value.

| Name | Type | Sensitive | Default | Description |
| ---- | ---- | --------- | ------- | ----------- |
| `db_username` | string |  | `qoveryadmin` | Omit to use qoveryadmin, the login used by native managed databases. To set your own: letters, digits, underscores; must start with a letter; max 32 chars (MySQL limit). Reserved names not allowed: admin, rdsadmin, mysql. |
| `db_password` | string | yes | _generated_ | Omit when creating a database and Qovery generates a 32-character alphanumeric password; when adopting an existing instance, this must carry that instance's current master password, because RDS never returns it. To set your own: 8–128 chars, must not contain /, @, ", or spaces. |
| `manage_db_password` | bool |  | `false` | Adopted instances only, and one-way: once true, leave it true. Changing `db_password` then rotates the live instance's master password. An instance this blueprint created always owns its password. |

Changing `db_password` rotates the live instance's master password: the value is sent as a
write-only argument, triggered by a version derived from the password itself, so a change
reaches RDS and an unchanged password sends nothing.

An adopted instance does not take part until `manage_db_password` is set to true. That keeps
its import plan clean, and it has a consequence worth stating plainly: **while the flag is
false, editing `db_password` changes what the blueprint publishes without changing anything on
the instance.** Consumers pick up a credential RDS will reject. On an adopted instance, either
set the flag before touching the password, or do not touch the password at all.

Setting the flag is itself a write. Until then the version that triggers the send is null in
state, so switching it to true moves that value and applies `db_password` to the instance —
harmless when the two already agree, and an overwrite of the live password when they do not.
Confirm the stored password is the one the instance actually has before opting in.

A rotation also obeys `apply_changes_now`. Left false, RDS defers the password change to the
maintenance window while the new value is published immediately — consumers redeployed in
between cannot connect. Set `apply_changes_now` when you rotate.

Adoption (`import_identifier` set) requires both explicitly. `username` is `ForceNew` on
`aws_db_instance`, so a defaulted value would plan a replacement and destroy the live
database; and RDS never returns the master password, so a generated one would be published
as the credential without ever being applied.

### Instance & storage

| Name                | Type   | Default       | Description                                                    |
| ------------------- | ------ | ------------- | -------------------------------------------------------------- |
| `port`              | number | `3306`        | Database port                                                  |
| `storage_type`      | string | `gp3`         | EBS storage type: `gp2`, `gp3`, `io1`, `io2`                   |
| `storage_encrypted` | bool   | `true`        | Encrypt storage at rest                                        |
| `disk_iops`         | number | `0`           | Provisioned IOPS (io1/io2 or gp3 ≥400 GiB). `0` = AWS default. |

### Network

| Name                   | Type   | Default | Description                                                                                              |
| ---------------------- | ------ | ------- | -------------------------------------------------------------------------------------------------------- |
| `multi_az`             | bool   | `false` | Enable Multi-AZ deployment                                                                               |
| `publicly_accessible`  | bool   | `false` | Expose the database to the public internet                                                               |
| `db_subnet_group_name` | string |         | Leave empty — the Qovery cluster DB subnet group. Set only on a user-provided VPC.                       |
| `security_group_ids`   | string |         | Leave empty — the Qovery cluster workers security group. Set only on a user-provided VPC.                |

By default the instance is attached to the Qovery cluster network: the DB subnet group created at cluster bootstrap (named after the cluster VPC id) and the cluster workers security group, so pods in the cluster can reach the database out of the box. On clusters deployed into an existing VPC (user-provided network), the `ClusterId` tag lookup may not resolve; set `db_subnet_group_name` and `security_group_ids` explicitly in that case.

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

### Upgrading from an earlier blueprint version

Read this before repointing a deployment at this version.

- For an instance this blueprint created, and for an adopted instance already opted in with
  `manage_db_password`, the first apply writes the master password once. Old state carries no record of
  what was last sent, so the value Qovery holds is applied. An instance whose password was rotated
  outside Terraform — which earlier versions of this document told you to do — is reset to the
  Qovery-held value, and applications using the out-of-band password stop connecting. Make the two agree
  before you upgrade. An adopted instance left at `manage_db_password = false` is not touched: nothing is
  sent, and an out-of-band rotation survives.
- `manage_db_password` is one-way. Setting it back to false after an adopted instance has been handed
  over leaves Terraform with a change AWS rejects as "no modifications were requested".
- Terraform moves from 1.9.7 to 1.13.3, and `1.9.7` is no longer an accepted override. State written by
  1.13.3 cannot be read by 1.9.7, so a deployment cannot be repointed at an earlier blueprint version
  once it has applied.

## Lifecycle ignore_changes

A few attributes remain ignored:

- `password` — the master password moved to the write-only `password_wo`; ignoring the plain attribute stops the value left in older state reading as a removal.
- `final_snapshot_identifier` — `timestamp()` rotates the name every plan; only meaningful when a final snapshot is actually taken.
- `enabled_cloudwatch_logs_exports` — list type, not yet supported by the qbm.yml schema.
- `max_allocated_storage` — will turn into a managed input when the storage autoscale feature is added.

Note: `parameter_group_name` is **not** ignored — the blueprint owns its parameter group.

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
        "rds:CreateDBParameterGroup",
        "rds:DeleteDBParameterGroup",
        "rds:ModifyDBParameterGroup",
        "rds:DescribeDBParameterGroups",
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
