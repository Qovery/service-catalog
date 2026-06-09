# AWS RDS PostgreSQL 17

Creates an AWS RDS PostgreSQL 17 instance with configurable instance class, storage, and Multi-AZ deployment. Storage is encrypted by default with automated backups retained for 7 days.

The RDS identifier is derived from `db_name` by lowercasing and replacing underscores with hyphens (AWS requirement). The actual PostgreSQL database name is kept as provided.

## Variables

| Name                | Type   | Required | Sensitive | Default       | Description                                                                                                                   |
| ------------------- | ------ | -------- | --------- | ------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `db_name`           | string | yes      |           | —             | PostgreSQL database name. Letters, digits, underscores only; must start with a letter; max 63 chars. Hyphens are not allowed. |
| `db_username`       | string | yes      |           | —             | Master username. Letters, digits, underscores; must start with a letter; max 63 chars.                                        |
| `db_password`       | string | yes      | yes       | —             | Master password. 8–128 chars. Must not contain `/`, `@`, `"`, or spaces.                                                      |
| `instance_class`    | string | no       |           | `db.t3.micro` | RDS instance class (e.g. `db.t3.micro`, `db.m5.large`)                                                                        |
| `allocated_storage` | number | no       |           | `20`          | Allocated storage in GiB. Min 20, max 65536 (gp3).                                                                            |
| `engine_version`    | string | no       |           | `17`          | PostgreSQL major version (e.g. `17`, `16`)                                                                                    |
| `multi_az`          | bool   | no       |           | `false`       | Enable Multi-AZ deployment for high availability                                                                              |

## Outputs

| Name          | Description                       |
| ------------- | --------------------------------- |
| `db_endpoint` | RDS instance endpoint (host:port) |
| `db_address`  | RDS instance hostname             |
| `db_port`     | RDS instance port                 |
| `db_name`     | Database name                     |
