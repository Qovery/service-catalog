# AWS RDS PostgreSQL 14

Creates an AWS RDS PostgreSQL 14 instance with configurable instance class, storage, backups, maintenance window, monitoring, and network settings. Storage is encrypted by default.

When the blueprint creates the instance, the RDS identifier is derived from `db_name`: lowercased, each run of underscores turned into one hyphen, and a trailing hyphen dropped (AWS requirement). An adopted instance keeps its existing identifier (`import_identifier`), which can differ from `db_name`. The actual PostgreSQL database name is kept as provided.

## Variables

### Required

| Name          | Type   | Sensitive | Description                                                                                                                   |
| ------------- | ------ | --------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `db_name`     | string |           | PostgreSQL database name. Letters, digits, underscores only; must start with a letter; max 63 chars. Hyphens are not allowed. |
| `instance_class`    | string |           | RDS instance class. Default suggestion: `db.t3.micro`.                                             |
| `allocated_storage` | number |           | Allocated storage in GiB (min 20; max 65536 for gp3/io1/io2, 16384 for gp2). A value below the instance's current disk size is a no-op: RDS cannot shrink storage. Default suggestion: `20`. |

Available instance classes: every RDS instance class Qovery offers for native managed PostgreSQL and MySQL — the `db.t3`, `db.t4g`, `db.m5`–`db.m8g`, `db.r5`–`db.r8g` (including `db.r5b`), `db.x2g`, `db.x2idn` and `db.x2iedn` families, with their Graviton (`g`), Intel (`i`), local-storage (`d`) and network-optimized (`n`) variants. `db.c6gd` is left out because RDS offers it only for Multi-AZ DB clusters. The full list is in `qbm.yml`.

### Credentials

Both are optional — omit them and Qovery supplies the values, the way native managed
databases did. In the console, leaving the field blank omits it. Through the API or
Terraform, omit the variable rather than sending an empty string: the platform rejects an
empty variable value.

| Name | Type | Sensitive | Default | Description |
| ---- | ---- | --------- | ------- | ----------- |
| `db_username` | string |  | `qoveryadmin` | Leave empty to use qoveryadmin, the login used by native managed databases. To set your own: letters, digits, underscores; must start with a letter; max 63 chars. Reserved names not allowed: admin, rdsadmin, rdsrepladmin, rdstopmgr, or any name starting with 'pg_'. |
| `db_password` | string | yes | _generated_ | Leave empty when creating a database and Qovery generates a 32-character alphanumeric password; when adopting an existing instance this must carry the current master password of that instance, because RDS never returns it. To set your own: 8–128 chars, must not contain /, @, ", or spaces. Changing it rotates the master password on the live instance (adopted instances: only once `manage_db_password` is true). |
| `manage_db_password` | bool |  | `false` | Adopted instances only, and one-way: once true, leave it true. Switching it on applies `db_password` to the instance, so confirm that value is the one the instance already has. Changing `db_password` then rotates it. An instance this blueprint created always owns its password. |

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

| Name                 | Type   | Default | Description                                                                                                                                                                                                                                     |
| -------------------- | ------ | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `port`               | number | `5432`  | Database port                                                                                                                                                                                                                                   |
| `max_allocated_storage` | number |      | Leave empty to keep the current storage autoscaling setting: off on a new database, the primary's on a new read replica. `0` turns autoscaling off. Otherwise the ceiling in GiB RDS may grow the disk to: at least 10% above `allocated_storage` (AWS recommends 26%), at most 65536 (16384 for gp2). Takes effect immediately, whatever `apply_changes_now` says. |
| `storage_type`       | string | `gp3`   | EBS storage type: `gp2`, `gp3`, `io1`, `io2`                                                                                                                                                                                                    |
| `storage_encrypted`  | bool   | `true`  | Encrypt storage at rest                                                                                                                                                                                                                         |
| `disk_iops`          | number | `0`     | Provisioned IOPS. Only meaningful with io1/io2 (always) or gp3 (≥400 GiB). 0 lets AWS choose the default. |
| `storage_throughput` | number | `0`     | 0 = AWS baseline on a new instance; an existing one keeps its current value. Otherwise provisioned storage throughput in MiB/s, 500-4000, gp3 with `allocated_storage` ≥400 GiB only (below that AWS fixes it at 125 MiB/s). Needs `disk_iops` set too, 12000 or more (on an existing instance, its current IOPS): AWS rejects a throughput without IOPS. Max 0.25 × `disk_iops`. To return throughput to baseline, set 500 and keep `disk_iops` at the instance's current IOPS (12000 at the gp3 baseline). |

**Storage autoscaling.** With `max_allocated_storage` set, RDS grows the disk on its own when free
space stays at or below 10% for 5 minutes, up to that ceiling. Left empty, the blueprint keeps
whatever the instance has, including a ceiling set in the AWS console.

- **The ceiling must be at least 10% above the current disk**, not only above `allocated_storage`,
  and on each read replica above that replica's own disk. Once autoscaling has grown a disk, the
  deploy fails before changing anything if the ceiling is too close to it, and names the minimum.
  An unchanged ceiling is not checked, except when `allocated_storage` raises the disk or a new
  replica is about to be created with it. A replacement that keeps the identifier is not caught:
  if its disk sits within 10% of the ceiling, AWS refuses it at apply, so raise the ceiling first.
- **It applies immediately**, without a reboot, whatever `apply_changes_now` says.
- **A disk never shrinks.** The blueprint asks for the larger of `allocated_storage` and the live
  disk size, so a grown disk does not show as a change, and setting `0` after a growth turns
  autoscaling off at the current size.
- With io1/io2 storage, AWS also requires the IOPS-to-ceiling ratio to stay within a range, and
  rejects a ceiling outside it when the deploy applies.

### Network

| Name                   | Type   | Default | Description                                                                                              |
| ---------------------- | ------ | ------- | -------------------------------------------------------------------------------------------------------- |
| `multi_az`             | bool   | `true`  | Enable Multi-AZ deployment                                                                               |
| `publicly_accessible`  | bool   | `false` | Expose the database to the public internet                                                               |
| `db_subnet_group_name` | string |         | Leave empty — derived from the Qovery cluster's DB subnet group. Set it only on a cluster with a user-provided VPC, where that lookup finds nothing. |
| `security_group_ids`   | string |         | Leave empty — derived from the Qovery cluster's workers security group. Set it (comma-separated ids) only on a cluster with a user-provided VPC, where that lookup finds nothing. |

By default the instance is attached to the Qovery cluster network: the DB subnet group created at cluster bootstrap (named after the cluster VPC id) and the cluster workers security group, so pods in the cluster can reach the database out of the box. On clusters deployed into an existing VPC (user-provided network), the `ClusterId` tag lookup may not resolve; set `db_subnet_group_name` and `security_group_ids` explicitly in that case.

### Read replicas

| Name                               | Type   | Default | Description                                                                            |
| ---------------------------------- | ------ | ------- | -------------------------------------------------------------------------------------- |
| `read_replica_count`               | number | `0`     | Number of same-region read replicas (0 disables; max 15). Point analytics tools (Metabase, BI dashboards) at the replica endpoints to offload reads. Requires `backup_retention_period` > 0. |
| `read_replica_instance_class`      | string |         | Instance class for read replicas. Empty = same as the primary. Analytics workloads often want a larger class here. |
| `read_replica_publicly_accessible` | bool   | `false` | Expose replicas to the public internet.                                                |
| `read_replica_allowed_cidrs`       | string |         | Empty = replicas use the primary's security groups. Comma-separated IPv4 network CIDRs, max 50 (e.g. Metabase Cloud IPs; 10.0.0.0/24, not 10.0.0.5/24): replicas then accept only these and the VPC on the database `port`. Needs `read_replica_count` > 0; public addresses also need `read_replica_publicly_accessible` = true. |
| `read_replica_multi_az`            | bool   | `false` | Enable Multi-AZ for replicas.                                                           |

Read replicas are asynchronous read-only copies of the primary — point analytics/BI tools (Metabase, Superset, dashboards, ad-hoc reporting) at their endpoints to keep heavy read traffic off the primary. They inherit the primary's engine version, storage size, storage type, and encryption, and share its database name, master username, and password; connect with the same credentials at the replica endpoint. `max_allocated_storage` and `cloudwatch_logs_export_enabled` apply to every replica too: left unset, an existing replica keeps its own autoscaling ceiling and log exports, and a new one starts from the primary's. Because replication is asynchronous, replicas are eventually consistent (fine for analytics, not for read-after-write). Creating replicas requires automated backups on the primary (`backup_retention_period > 0`, the default). Replica endpoints are exposed via the `read_replica_endpoints` output. Analytics tools running inside the cluster can reach them over the cluster network out of the box; set `read_replica_publicly_accessible = true` only for tools that live outside the VPC. To let such a tool in without opening the primary, set `read_replica_publicly_accessible = true` and list its egress IPs in `read_replica_allowed_cidrs` (e.g. the Metabase Cloud IPs for your region): the blueprint creates a dedicated security group allowing those CIDRs plus the VPC's own CIDRs on the database port, and attaches it to the replicas **instead of** the primary's groups. Replacing rather than adding is deliberate: on a Qovery-managed network the cluster workers group also carries the cluster-wide `database.postgresql.allowed_cidrs` rule (`0.0.0.0/0` by default), which would otherwise leave a public replica reachable from anywhere. Clients inside the VPC keep access through the VPC CIDR rule. With the variable unset, replicas carry the primary's security groups, including on an adopted instance.

### Maintenance & upgrades

| Name                           | Type   | Default               | Description                                          |
| ------------------------------ | ------ | --------------------- | ---------------------------------------------------- |
| `apply_changes_now`            | bool   | `false`               | Apply changes immediately                            |
| `allow_major_version_upgrade`  | bool   | `true`                | Allow major engine version upgrades on apply         |
| `auto_minor_version_upgrade`   | bool   | `true`                | Auto-apply minor version upgrades during maintenance |
| `preferred_maintenance_window` | string | `Tue:02:00-Tue:04:00` | Maintenance window (UTC), `ddd:hh24:mi-ddd:hh24:mi`  |

### Backups

| Name                       | Type   | Default       | Description                                  |
| -------------------------- | ------ | ------------- | -------------------------------------------- |
| `preferred_backup_window`  | string | `00:00-01:00` | Daily backup window (UTC), `hh24:mi-hh24:mi` |
| `backup_retention_period`  | number | `14`          | Days to retain backups (0–35). `0` disables. |
| `skip_final_snapshot`      | bool   | `false`       | Skip final snapshot on deletion              |
| `delete_automated_backups` | bool   | `false`       | Delete automated backups when the instance is deleted. Default keeps them for `backup_retention_period` days; set true for throwaway instances |
| `copy_tags_to_snapshot`    | bool   | `true`        | Propagate instance tags to snapshots         |

Deleting the service keeps a final snapshot and the automated backups by default, and both keep
costing storage until deleted by hand: the snapshot indefinitely, the backups for
`backup_retention_period` days. For a throwaway or test instance, set both `skip_final_snapshot` and
`delete_automated_backups` to `true`. The final snapshot is named
`<cluster name>-<db name>-<YYYYMMDDhhmmss>`: `db_name` slugged as for the identifier, the UTC
time the name was stamped. From the cluster name, in this order: any character AWS rejects is
removed, hyphen runs are collapsed, it is cut to 160 characters to stay within the 255-character
limit, then leading and trailing hyphens are dropped (prefixed `snap-` if the result does not start
with a letter). It is stamped once at creation, so successive
create/destroy cycles of the same name do not collide.

### Monitoring

| Name                                    | Type   | Default             | Description                                                                    |
| --------------------------------------- | ------ | ------------------- | ------------------------------------------------------------------------------ |
| `performance_insights_enabled`          | bool   | `true`              | Enable RDS Performance Insights                                                |
| `performance_insights_retention_period` | number | `7`                 | Performance Insights retention in days. Only used when `performance_insights_enabled` is true. Valid: 7, 731, or a multiple of 31. |
| `monitoring_interval`                   | number | `0`                 | Enhanced monitoring interval in seconds (0 disables). Allowed values: 0, 1, 5, 10, 15, 30, 60. |
| `monitoring_role_arn`                   | string |                     | IAM role ARN for enhanced monitoring. Required when `monitoring_interval > 0`. |
| `cloudwatch_logs_export_enabled`        | bool   | `false`             | Off keeps the current CloudWatch log exports: none on a new database, the primary's on a new read replica. On also exports the PostgreSQL log to CloudWatch Logs, on the primary and every read replica, immediately. Turning it back off does not stop an export. |
| `ca_cert_identifier`                    | string | `rds-ca-rsa2048-g1` | CA certificate identifier                                                      |

**CloudWatch log export.** `cloudwatch_logs_export_enabled = true` adds the `postgresql` log to
what the instance already exports; RDS publishes it to the log group
`/aws/rds/instance/<identifier>/postgresql`. `false` does not remove anything: the instance keeps
the exports it has, so an export set in the AWS console (`upgrade`, for instance) survives every
deploy.

- **To stop the export, disable it in the AWS console** and keep the input `false`. With `true`,
  the next deploy turns it back on.
- **The log group is not managed by the blueprint.** RDS creates it; the blueprint neither sets its
  retention (CloudWatch defaults to never expire) nor deletes it with the instance.
- **What gets logged follows the parameter group.** The RDS default logs errors, failed logins and
  deadlocks; set `log_min_duration_statement` or `auto_explain` through `db_parameters` for more.

### Misc

| Name                                  | Type   | Default | Description                                        |
| ------------------------------------- | ------ | ------- | -------------------------------------------------- |
| `option_group_name`                   | string |         | Optional option group name. Empty = AWS default. |
| `deletion_protection`                 | bool   | `false` | Prevent deletion via TF/API                        |
| `iam_database_authentication_enabled` | bool   | `false` | Enable IAM DB authentication                       |
| `dedicated_log_volume`                | bool   | `false` | Provision a dedicated EBS volume for database logs |

### Parameters

| Name            | Type   | Default | Description |
| --------------- | ------ | ------- | ----------- |
| `db_parameters` | string |         | Empty = the instance keeps its current parameter group, except one this blueprint created: that one is deleted and the instance and its read replicas return to the family default. JSON object of PostgreSQL parameters, e.g. {"log_connections":"1","shared_preload_libraries":{"value":"pg_stat_statements,auto_explain","apply_method":"pending-reboot"}}: the blueprint creates a parameter group with them and attaches it to the instance and its read replicas. Static parameters need apply_method pending-reboot and take effect at the next reboot. |

Each value is either the parameter value, or an object carrying `apply_method` too. RDS applies a
dynamic parameter with `immediate` (the default here) and refuses it for a static one, which needs
`pending-reboot`:

```json
{
  "log_connections": "1",
  "max_wal_size": "16384",
  "checkpoint_timeout": "1800",
  "idle_in_transaction_session_timeout": "600000",
  "shared_preload_libraries": { "value": "pg_stat_statements,auto_explain", "apply_method": "pending-reboot" },
  "auto_explain.log_min_duration": "5000"
}
```

- **Write values the way RDS stores them** — plain integers in the parameter's own unit (`max_wal_size` in MB, `checkpoint_timeout` in seconds). Anything else is
  normalised by AWS and shows up as a change on every deploy. JSON `true`/`false` are sent as
  `1`/`0`.
- **Overriding `shared_preload_libraries` replaces the RDS default**, `pg_stat_statements`. Keep it
  in the list, or Performance Insights' SQL statistics stop.
- **The blueprint never reboots the instance to apply parameters.** A new instance starts on the group. On an existing
  one, attaching the group for the first time, and every change to a `pending-reboot` parameter,
  waits for a reboot: the instance shows `pending-reboot` in the AWS console until you reboot it
  there. Changes to dynamic parameters apply without one.
- The group is named `<identifier>-params-<suffix>` and its family follows the engine major
  (`postgres14`). With `db_parameters` set, a major upgrade creates a group of the new family with
  the same parameters and moves the instance onto it along with the engine. RDS upgrades the read
  replicas as part of the primary's upgrade, so they move onto the new group in the same deploy, and
  only then is the old group deleted: it is never sent a parameter its version may not know.
- **A major upgrade with `db_parameters` set, or being cleared, needs `apply_changes_now = true`**,
  and the deploy fails before changing anything otherwise. Deferred to the maintenance window, the
  upgrade would keep the old group attached, and it could not be deleted. Either apply the upgrade
  now, or upgrade first and set `db_parameters` afterwards.
- Clearing `db_parameters` moves the instance and replicas back to `default.postgres14` and deletes
  the group; dynamic parameters revert straight away, static ones at the next reboot. Left unset, the
  blueprint does not touch the parameter group, so a group attached by other means stays in place.
  The blueprint recognises its own group by name, `<identifier>-params-` followed by 26 hex
  characters: do not give a group of your own a name of that shape.

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

### Upgrading from an earlier blueprint version

Read this before repointing a deployment at this version.

- **Repointing a service from an older PostgreSQL major upgrades its engine in place.** Qovery
  sets `engine_version` to the highest 14.x that RDS lists as a valid upgrade target from the
  running version, and Terraform runs the major upgrade (downtime; with `apply_changes_now = false`,
  in the next maintenance window). An instance already upgraded through RDS to 14 is only
  relabelled. An instance on a custom parameter group needs a group of the new family first: RDS
  refuses the upgrade otherwise. From a newer major, do not repoint here: RDS cannot downgrade.

- Deleting now keeps a final snapshot and the automated backups for services **created** on this
  version. An existing service does not change behaviour: Qovery stores every variable default when
  the service is created, so repointing it here keeps `skip_final_snapshot = true` and
  `delete_automated_backups = true`. To keep a snapshot and backups on delete, set both to `false`
  on the service. The upgrade itself adds `time_static.created` and, with those set to `false`,
  updates `skip_final_snapshot`, `delete_automated_backups` and `final_snapshot_identifier` in
  place — Terraform-only arguments, nothing is sent to AWS and the instance is not rebooted.
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
- `parameter_group_name` is no longer ignored. Left unset (`db_parameters` empty), nothing changes:
  Terraform sends no value and a group attached in the AWS console stays. Setting `db_parameters`
  replaces that group with the blueprint's, so copy any parameters you still need into it first.
- On an **adopted** instance with read replicas, the replicas are now given the primary's security
  groups explicitly, even with `read_replica_allowed_cidrs` unset. If they currently carry other
  groups (typically the VPC default group), the first apply swaps them in place: no replacement,
  no reboot. An instance this blueprint created is unaffected; its replicas already had these groups.
- `max_allocated_storage` and `enabled_cloudwatch_logs_exports` are no longer ignored, and nothing
  changes until you set the new inputs: repointing leaves `max_allocated_storage` empty and
  `cloudwatch_logs_export_enabled` false, and both keep what the primary and each replica have,
  including autoscaling and exports set in the AWS console. `allocated_storage` now follows the live
  disk when that is larger, so a disk grown by autoscaling no longer shows as a change. Qovery can
  turn the log export on but not off; disable it in the AWS console.

## Lifecycle ignore_changes

On the primary instance, `engine_version` is no longer ignored. Terraform requests the exact
version held in the internal `engine_version` variable, which Qovery sets on every deploy:

- the live version, while the service stays on this major
- the highest valid upgrade target, when the service moves here from an older major.

With `auto_minor_version_upgrade` enabled, AWS may still move the running minor forward; the next
deploy then requests that newer version, so Terraform never tries to go back. Read replicas inherit
the primary's version.

A bare major such as `"14"` is never sent to a live instance, because AWS resolves it to the
region's default minor, which upgrades an older minor and is refused on a newer one. Without the
variable, an existing instance keeps its live version (read through the `aws_db_instance` data
source) and only a new instance gets the bare major.

`enabled_cloudwatch_logs_exports` and `max_allocated_storage` are managed, on the primary and on
the read replicas, but an unset input keeps the live value instead of clearing it: the blueprint
reads each instance through the `aws_db_instance` data source on every plan, so an empty
`max_allocated_storage` keeps the live ceiling and `cloudwatch_logs_export_enabled = false` keeps
the live exports. A replacement that changes the identifier (a `db_name` change on an instance this
blueprint created) finds no live instance and starts from the inputs alone. One that keeps it (an
adopted instance, whose identifier is `import_identifier`, or a `storage_encrypted` toggle) reads
the old instance, so the new one inherits its disk size, autoscaling ceiling and log exports.

Two attributes remain ignored on the primary:

- `password` — the master password moved to the write-only `password_wo`; ignoring the plain attribute stops the value left in older state reading as a removal.
- `tags` — an adopted instance keeps its AWS tags: the native path tags managed RDS with `cluster_id`, which the YACE CloudWatch exporter filters DB metrics on.

## Required AWS IAM permissions

The credentials used to deploy this blueprint must allow the actions below. The RDS actions target instances in any region you deploy to; EC2 read actions are needed so Terraform can look up the default VPC, subnets, and security groups when none are explicitly configured. The EC2 write actions are used while `read_replica_allowed_cidrs` is set, and on the apply that clears it (Terraform revokes the rules and deletes the group), so keep them until that apply has run.

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
        "rds:CreateDBParameterGroup",
        "rds:ModifyDBParameterGroup",
        "rds:DeleteDBParameterGroup",
        "rds:DescribeDBParameterGroups",
        "rds:ResetDBParameterGroup",
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
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:ModifySecurityGroupRules",
        "ec2:DescribeSecurityGroupRules",
        "ec2:CreateTags"
      ],
      "Resource": "*"
    }
  ]
}
```

When `monitoring_interval > 0`, the supplied `monitoring_role_arn` must be assumable by RDS (`monitoring.rds.amazonaws.com` trust relationship) and grant the `AmazonRDSEnhancedMonitoringRole` managed policy.
