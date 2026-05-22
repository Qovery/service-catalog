# Scaleway Managed Database PostgreSQL 16

Creates a Scaleway Managed Database for PostgreSQL instance with a database and user. Supports configurable node type, storage, and optional high availability cluster mode. Backups are enabled by default.

## Variables

| Name | Type | Required | Sensitive | Default | Description |
|------|------|----------|-----------|---------|-------------|
| `instance_name` | string | yes | | — | Database instance name |
| `db_name` | string | yes | | — | Database name |
| `db_username` | string | yes | | — | Database user name |
| `db_password` | string | yes | yes | — | Database user password (min 8 characters) |
| `node_type` | string | no | | `DB-DEV-S` | Node type (e.g. DB-DEV-S, DB-GP-XS) |
| `volume_size_gb` | number | no | | `5` | Volume size in GB |
| `is_ha_cluster` | bool | no | | `false` | Enable high availability cluster mode |

## Outputs

| Name | Description |
|------|-------------|
| `endpoint_ip` | Database endpoint IP |
| `endpoint_port` | Database endpoint port |
| `db_name` | Database name |
