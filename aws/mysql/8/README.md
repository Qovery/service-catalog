# AWS RDS MySQL 8

Creates an AWS RDS MySQL instance with configurable instance class, storage, and Multi-AZ deployment. Storage is encrypted by default with automated backups retained for 7 days.

## Variables

| Name | Type | Required | Sensitive | Default | Description |
|------|------|----------|-----------|---------|-------------|
| `db_name` | string | yes | | — | Database name |
| `db_username` | string | yes | | — | Master username |
| `db_password` | string | yes | yes | — | Master password (min 8 characters) |
| `instance_class` | string | yes | | `db.t3.micro` | RDS instance class |
| `allocated_storage` | number | no | | `20` | Allocated storage in GiB |
| `multi_az` | bool | no | | `false` | Enable Multi-AZ deployment |

## Outputs

| Name | Description |
|------|-------------|
| `db_endpoint` | RDS instance endpoint (host:port) |
| `db_address` | RDS instance hostname |
| `db_port` | RDS instance port |
| `db_name` | Database name |
