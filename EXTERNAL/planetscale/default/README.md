# PlanetScale Database

Provisions a [PlanetScale](https://planetscale.com/) (Vitess / MySQL) database with a production branch (`planetscale_vitess_branch`) and an application password (`planetscale_vitess_branch_password`), via the official `planetscale/planetscale` provider (`~> 1.0`).

> **No free tier.** PlanetScale removed its hobby/free plan; the cheapest paid plan starts around **$39/month per database**. Deploying this blueprint is immediately billable.

## Credentials

A PlanetScale **service token**: `planetscale_service_token_id` + `planetscale_service_token` (both sensitive), supplied as variables (`credentials.default: env`). The token needs permission to create databases/branches and passwords in the organization.

## Variables

### Required

| Name                           | Type   | Sensitive | Description                                   |
| ------------------------------ | ------ | --------- | --------------------------------------------- |
| `planetscale_service_token_id` | string | yes       | Service token ID                              |
| `planetscale_service_token`    | string | yes       | Service token                                 |
| `organization`                 | string |           | PlanetScale organization name                 |
| `database_name`                | string |           | Database name (`^[a-zA-Z0-9_-]{1,64}$`)       |

### Optional

| Name            | Type   | Default      | Description                                                     |
| --------------- | ------ | ------------ | --------------------------------------------------------------- |
| `branch_name`   | string | `main`       | Production branch to create                                     |
| `cluster_size`  | string |              | Vitess cluster size (e.g. `PS-10`). Unset = plan default.       |
| `region`        | string |              | Region slug (e.g. `us-east`). Unset = org default.              |
| `role`          | string | `readwriter` | `reader`, `writer`, `readwriter`, or `admin`                    |

## Outputs

| Name                 | Sensitive | Description                                        |
| -------------------- | --------- | -------------------------------------------------- |
| `database_name`      |           | Database name                                      |
| `branch_name`        |           | Production branch name                             |
| `mysql_address`      |           | MySQL address for the branch                       |
| `mysql_edge_address` |           | MySQL edge address                                 |
| `access_host_url`    |           | Connection host for the generated password         |
| `username`           |           | Generated database username                        |
| `password`           | yes       | Generated password (only returned at creation)     |
| `connection_uri`     | yes       | Ready-to-use MySQL URI with credentials embedded   |

## Notes

- **The database is created implicitly with its first branch.** There is no separate database resource in the PlanetScale provider; destroying this blueprint deletes the branch and therefore the database and all its data — the same teardown semantics as the other managed-database blueprints in this catalog.
- The generated `password` is only returned by the API at creation time; it is surfaced as a sensitive output.
- Uses the **official v1** provider (a full rewrite of the deprecated v0); pinned `~> 1.0`.
