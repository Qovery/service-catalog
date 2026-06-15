# Scaleway Managed Database MySQL 8

Creates a Scaleway Managed Database for MySQL with a database and user. Supports configurable node type, storage, and optional high availability cluster mode. Backups are enabled by default.

The Scaleway instance name is composed as `{cluster_name}-{instance_name}`.

## Variables

| Name             | Type   | Required | Sensitive | Default    | Description                                                                                                              |
| ---------------- | ------ | -------- | --------- | ---------- | ------------------------------------------------------------------------------------------------------------------------ |
| `instance_name`  | string | yes      |           | —          | Instance name suffix. Letters, digits, hyphens, underscores; must start with a letter or digit; max 100 chars.           |
| `db_name`        | string | yes      |           | —          | MySQL database name. Letters, digits, underscores only; must start with a letter; max 64 chars. Hyphens are not allowed. |
| `db_username`    | string | yes      |           | —          | Database username. Letters, digits, underscores; must start with a letter; max 32 chars (MySQL limit).                   |
| `db_password`    | string | yes      | yes       | —          | Database user password. 8–128 chars. Must not contain `/`, `@`, `"`, or spaces.                                          |
| `node_type`      | string | no       |           | `DB-DEV-S` | Scaleway node type (e.g. `DB-DEV-S`, `DB-GP-XS`)                                                                         |
| `volume_size_gb` | number | no       |           | `5`        | Volume size in GB. Min 5, max 10000.                                                                                     |
| `is_ha_cluster`  | bool   | no       |           | `false`    | Enable high availability cluster mode                                                                                    |

## Outputs

| Name            | Description            |
| --------------- | ---------------------- |
| `endpoint_ip`   | Database endpoint IP   |
| `endpoint_port` | Database endpoint port |
| `db_name`       | Database name          |

## Required Scaleway IAM permissions

Scaleway IAM permissions are granted via **permission sets** on a policy attached to the application/user whose API key is used.

Attach a policy with the following permission sets, scoped to the target Project:

| Permission set                   | Why                                                  |
| -------------------------------- | ---------------------------------------------------- |
| `RelationalDatabasesFullAccess`  | Create / read / update / delete the RDB instance, database, and user. |
| `ProjectReadOnly`                | Resolve the project context for the API call.       |

The minimum scope is the Project where Qovery deploys this blueprint. If your cluster has its own project, attach the policy there.
