# Scaleway Managed Database MySQL 8

Creates a Scaleway Managed Database for MySQL with a database and admin user. Supports configurable node type, storage, backups, slow query logging, HA cluster mode, and an optional network ACL.

The Scaleway instance name is composed as `{cluster_name}-{instance_name}`.

## Migration from 1.0.x

`1.1.0` drops the standalone `scaleway_rdb_user.this` resource — the admin user is now created via `user_name`/`password` on `scaleway_rdb_instance` (the canonical Scaleway provider pattern). For existing deployments at `1.0.x`, run once before upgrading:

```sh
terraform state rm scaleway_rdb_user.this
```

This removes the resource from state without touching the user in Scaleway; the instance then takes ownership on the next apply.

## Variables

### Required

| Name            | Type   | Sensitive | Description                                                                                                              |
| --------------- | ------ | --------- | ------------------------------------------------------------------------------------------------------------------------ |
| `instance_name` | string |           | Instance name suffix. Letters, digits, hyphens, underscores; must start with a letter or digit; max 100 chars.           |
| `db_name`       | string |           | MySQL database name. Letters, digits, underscores only; must start with a letter; max 64 chars. Hyphens are not allowed. |
| `db_username`   | string |           | Database username. Letters, digits, underscores; must start with a letter; max 32 chars (MySQL limit).                   |
| `db_password`   | string | yes       | Database user password. 8–128 chars. Must not contain `/`, `@`, `"`, or spaces.                                          |
| `node_type`      | string |          | Scaleway node type (e.g. `DB-DEV-S`, `DB-GP-XS`). Default suggestion: `DB-DEV-S`.         |
| `volume_size_gb` | number |          | Volume size in GB (min 5, max 10000). Default suggestion: `5`.                     |

### Engine & sizing

| Name             | Type   | Default    | Description                                               |
| ---------------- | ------ | ---------- | --------------------------------------------------------- |
| `engine_version` | string | `MySQL-8`  | Engine version.                                           |
| `volume_type`    | string | `lssd`     | Volume backend: `lssd` (local SSD) or `bssd` (block SSD). |
| `is_ha_cluster`  | bool   | `false`    | Enable HA cluster mode (multi-node, automatic failover).  |

### Backups, logging & ACL

| Name                  | Type   | Default     | Description                                                                                    |
| --------------------- | ------ | ----------- | ---------------------------------------------------------------------------------------------- |
| `activate_backups`    | bool   | `true`      | Enable automated backups.                                                                      |
| `slow_query_log`      | bool   | `true`      | Enable MySQL slow query log via the instance settings.                                         |
| `publicly_accessible` | bool   | `false`     | Create an ACL allowing `acl_allowed_cidr`. When false, no ACL — instance is private-only.      |
| `acl_allowed_cidr`    | string | `0.0.0.0/0` | Single CIDR allowed to reach the instance. Use the Scaleway console for multi-CIDR allowlists. |

## Outputs

| Name            | Sensitive | Description                                                       |
| --------------- | --------- | ----------------------------------------------------------------- |
| `endpoint_ip`   |           | Database endpoint IP (Load Balancer)                              |
| `endpoint_port` |           | Database endpoint port (Load Balancer)                            |
| `db_name`       |           | Database name                                                     |
| `db_username`   |           | Database username                                                 |
| `db_password`   | yes       | Database user password (echo of the input)                        |
| `instance_id`   |           | Scaleway RDB instance ID                                          |
| `certificate`   | yes       | TLS CA certificate served by the database (PEM, verify-full SSL)  |

## Required Scaleway IAM permissions

Scaleway IAM permissions are granted via **permission sets** on a policy attached to the application/user whose API key is used.

Attach a policy with the following permission sets, scoped to the target Project:

| Permission set                  | Why                                                                |
| ------------------------------- | ------------------------------------------------------------------ |
| `RelationalDatabasesFullAccess` | Create / read / update / delete RDB instance, database, user, ACL. |
| `ProjectReadOnly`               | Resolve the project context for the API call.                      |

The minimum scope is the Project where Qovery deploys this blueprint.
