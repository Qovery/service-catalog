# MongoDB Atlas Cluster

Provisions a [MongoDB Atlas](https://www.mongodb.com/atlas) **dedicated** cluster (`mongodbatlas_advanced_cluster`) in an existing Atlas project, plus a database user (`mongodbatlas_database_user`) and an IP access-list entry (`mongodbatlas_project_ip_access_list`) so it's usable immediately. Uses the `mongodb/mongodbatlas` provider (`~> 1.20`).

## Credentials

A MongoDB Atlas **programmatic API key** (public + private) supplied as variables (`credentials.default: env`). The private key is sensitive. The key must have Project Owner (or cluster + user + access-list write) permission on the target project.

## Variables

### Required

| Name                | Type   | Sensitive | Description                                             |
| ------------------- | ------ | --------- | ------------------------------------------------------- |
| `atlas_public_key`  | string |           | Atlas programmatic API key — public key                 |
| `atlas_private_key` | string | yes       | Atlas programmatic API key — private key                |
| `project_id`        | string |           | Existing Atlas project ID                               |
| `cluster_name`      | string |           | Cluster name (`^[a-zA-Z0-9-]{1,64}$`)                   |

### Credentials

Both are optional — omit them and Qovery supplies the values, the way native managed
databases did. In the console, leaving the field blank omits it. Through the API or
Terraform, omit the variable rather than sending an empty string: the platform rejects an
empty variable value.

Atlas keys database users by (username, auth database) within a project, so two databases in
the same Atlas project cannot both take the default username — give the second one an
explicit `db_username` or its user creation collides with the first.

| Name | Type | Sensitive | Default | Description |
| ---- | ---- | --------- | ------- | ----------- |
| `db_username` | string |  | `qoveryadmin` | Database user to create (SCRAM auth, readWriteAnyDatabase). Omit to use qoveryadmin. |
| `db_password` | string | yes | _generated_ | Omit and Qovery generates a 32-character alphanumeric password. To set your own: min 8 chars. |

### Cluster shape

| Name                     | Type   | Default     | Description                                                      |
| ------------------------ | ------ | ----------- | ---------------------------------------------------------------- |
| `provider_name`          | string | `AWS`       | Backing cloud: `AWS`, `GCP`, `AZURE`                             |
| `region_name`            | string | `US_EAST_1` | Atlas region for the backing provider                            |
| `instance_size`          | string | `M10`       | Dedicated tier (M10+). Shared M0/M2/M5 are **not** supported.    |
| `mongo_db_major_version` | string | `7.0`       | MongoDB major version                                            |
| `backup_enabled`         | bool   | `true`      | Enable cloud backup                                              |
| `ip_access_list_cidr`    | string | `0.0.0.0/0` | CIDR allowed to connect (**restrict in production**)             |

## Outputs

| Name                         | Sensitive | Description                                            |
| ---------------------------- | --------- | ------------------------------------------------------ |
| `cluster_id`                 |           | Atlas cluster ID                                       |
| `cluster_name`               |           | Cluster name                                           |
| `connection_string_standard` |           | Standard connection string (`mongodb://`)              |
| `connection_string_srv`      |           | SRV connection string (`mongodb+srv://`)               |
| `mongo_db_version`           |           | Running MongoDB version                                |
| `db_username`                |           | Created database username                              |
| `db_password`                | yes       | Database user password (generated when the input was left empty)             |
| `connection_uri`             | yes       | Ready-to-use SRV URI with credentials embedded         |

## Notes

- This provisions a **dedicated** cluster (M10+), which is billable on Atlas. Shared tiers (M0 free / M2 / M5) use a different `provider_name: TENANT` shape and are intentionally out of scope.
- Uses `mongodbatlas_advanced_cluster` (the `mongodbatlas_cluster` resource is deprecated as of provider 2.0.0). Pinned to `~> 1.20`.
- The cluster is created in an **existing** project (`project_id`); this blueprint does not create the Atlas project or organization.
- Connect with `connection_string_srv`, injecting `db_username` / `db_password`.
