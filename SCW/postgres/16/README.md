# Scaleway Managed Database PostgreSQL 16

Creates a Scaleway Managed Database for PostgreSQL with a database and admin user. Supports configurable node type, storage, engine minor version, backups, HA cluster mode, and an optional network ACL.

The Scaleway instance name is composed as `{cluster_name}-{instance_name}`.

## Migration from 1.0.x

`1.1.0` drops the standalone `scaleway_rdb_user.this` resource — the admin user is now created via `user_name`/`password` on `scaleway_rdb_instance` (the canonical Scaleway provider pattern). For existing deployments at `1.0.x`, run once before upgrading:

```sh
terraform state rm scaleway_rdb_user.this
```

This removes the resource from state without touching the user in Scaleway; the instance then takes ownership on the next apply.

## Networking

The instance is always attached to the private network of the Qovery cluster, read from the
Kapsule cluster `qovery-<cluster short id>`. Applications in the cluster reach it there. With
`publicly_accessible`, a public endpoint filtered by `acl_allowed_cidr` is added. Public access
needs a narrower CIDR than the `0.0.0.0/0` default, which validation rejects in public mode.

## Upgrading to 1.5.0

Before 1.5.0, `publicly_accessible = false` did not make the instance private: Scaleway created
a public endpoint anyway, with its default ACL open to `0.0.0.0/0`. Upgrading an existing
instance attaches it to the private network and points `endpoint_ip` / `endpoint_port` at the
private endpoint, but the old public endpoint stays, because the provider never removes it once
the `load_balancer` block is gone. Delete that endpoint in the Scaleway console once the
applications use the private one.

## Variables

### Required

| Name            | Type   | Sensitive | Description                                                                                                                   |
| --------------- | ------ | --------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `instance_name` | string |           | Instance name suffix. Letters, digits, hyphens, underscores; must start with a letter or digit; max 100 chars.                |
| `db_name`       | string |           | PostgreSQL database name. Letters, digits, underscores only; must start with a letter; max 63 chars. Hyphens are not allowed. |
| `node_type`      | string |          | Scaleway node type (e.g. `DB-DEV-S`, `DB-GP-XS`). Default suggestion: `DB-DEV-S`.         |
| `volume_size_gb` | number |          | Volume size in GB (min 5, max 10000). Default suggestion: `5`.                     |

### Credentials

Both are optional — omit them and Qovery supplies the values, the way native managed
databases did. In the console, leaving the field blank omits it. Through the API or
Terraform, omit the variable rather than sending an empty string: the platform rejects an
empty variable value.

| Name | Type | Sensitive | Default | Description |
| ---- | ---- | --------- | ------- | ----------- |
| `db_username` | string |  | `qoveryadmin` | Omit to use qoveryadmin, the login used by native managed databases. To set your own: letters, digits, underscores; must start with a letter; max 63 chars. Reserved names not allowed: rdb_admin, postgres, or any name starting with 'pg_'. |
| `db_password` | string | yes | _generated_ | Omit and Qovery generates a 32-character password. To set your own: 8–128 chars, must not contain /, @, ", or spaces. |

### Engine & sizing

| Name             | Type   | Default         | Description                                               |
| ---------------- | ------ | --------------- | --------------------------------------------------------- |
| `engine_version` | string | `PostgreSQL-16` | Engine version. Allowed: `PostgreSQL-14`, `-15`, `-16`.   |
| `volume_type`    | string | `lssd`          | Volume backend: `lssd` (local SSD) or `bssd` (block SSD). |
| `is_ha_cluster`  | bool   | `false`         | Enable HA cluster mode (multi-node, automatic failover).  |

### Backups & ACL

| Name                  | Type   | Default     | Description                                                                                    |
| --------------------- | ------ | ----------- | ---------------------------------------------------------------------------------------------- |
| `activate_backups`    | bool   | `true`      | Enable automated backups.                                                                      |
| `publicly_accessible` | bool   | `false`     | Expose a public endpoint that accepts `acl_allowed_cidr`. When false, a new database is reachable only from the cluster's private network. An existing public endpoint is not removed (see Upgrading to 1.5.0). |
| `acl_allowed_cidr`    | string | `0.0.0.0/0` | Single CIDR allowed to reach the instance. Required and narrower than `0.0.0.0/0` when `publicly_accessible`. Use the Scaleway console for multi-CIDR allowlists. |

## Outputs

| Name            | Sensitive | Description                                                       |
| --------------- | --------- | ----------------------------------------------------------------- |
| `endpoint_ip`   |           | Database endpoint IP: the public endpoint when `publicly_accessible`, else the private network endpoint |
| `endpoint_port` |           | Database endpoint port: the public endpoint when `publicly_accessible`, else the private network endpoint |
| `private_endpoint_ip`   |  | Database IP on the cluster's private network |
| `private_endpoint_port` |  | Database port on the cluster's private network |
| `db_name`       |           | Database name                                                     |
| `db_username`   |           | Database username                                                 |
| `db_password`   | yes       | Database user password (generated when the input was left empty)                        |
| `instance_id`   |           | Scaleway RDB instance ID                                          |
| `certificate`   | yes       | TLS CA certificate served by the database (PEM, verify-full SSL)  |

## Required Scaleway IAM permissions

Scaleway IAM permissions are granted via **permission sets** on a policy attached to the application/user whose API key is used.

Attach a policy with the following permission sets, scoped to the target Project:

| Permission set                  | Why                                                                |
| ------------------------------- | ------------------------------------------------------------------ |
| `RelationalDatabasesFullAccess` | Create / read / update / delete RDB instance, database, user, ACL. |
| `PrivateNetworksFullAccess`     | Attach the instance to the cluster's private network.             |
| `KubernetesReadOnly`            | Read the cluster's private network id.                             |
| `ProjectReadOnly`               | Resolve the project context for the API call.                      |

The minimum scope is the Project where Qovery deploys this blueprint.
