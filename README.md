# Qovery Service Catalog

Pre-built blueprints for provisioning cloud resources and Kubernetes services through the Qovery platform.

## Available Blueprints

### AWS (Terraform)

| Service    | Path               | Description                              |
| ---------- | ------------------ | ---------------------------------------- |
| S3         | `aws/s3/default/`  | S3 bucket with encryption and versioning |
| PostgreSQL | `aws/postgres/17/` | RDS PostgreSQL 17 instance               |
| MySQL      | `aws/mysql/8/`     | RDS MySQL 8.4 instance                   |

### Scaleway (Terraform)

| Service        | Path                               | Description                    |
| -------------- | ---------------------------------- | ------------------------------ |
| Object Storage | `scaleway/object-storage/default/` | Scaleway Object Storage bucket |
| PostgreSQL     | `scaleway/postgres/16/`            | Managed Database PostgreSQL 16 |
| MySQL          | `scaleway/mysql/8/`                | Managed Database MySQL 8       |

### Helm (Kubernetes)

| Service  | Path               | Description                                    |
| -------- | ------------------ | ---------------------------------------------- |
| Redis    | `helm/redis/7/`    | Redis cache via Bitnami Helm chart             |
| RabbitMQ | `helm/rabbitmq/4/` | RabbitMQ message broker via Bitnami Helm chart |

## Directory Structure

```
{provider}/{service}/{major-version}/
  qbm.yml          — Blueprint manifest
  main.tf           — Terraform code (for TF blueprints)
  variables.tf      — Terraform variables
  outputs.tf        — Terraform outputs
  providers.tf      — Provider configuration
  values.yaml       — Helm values template (for Helm blueprints)
  README.md         — Blueprint documentation
```

## How It Works

1. Browse the catalog in the Qovery Console
2. Select a blueprint and major version
3. Fill in the variables
4. Deploy — the engine creates the service via the Qovery Terraform provider
5. The created service runs through the existing deployment pipeline

## Versioning

Tags follow the format `{provider}/{service}/{major-version}/{semver}` (e.g. `aws/s3/1/1.0.0`).
Tags are auto-created by CI on merge to main when `metadata.version` in `qbm.yml` changes.

## Contributing

1. Create a directory: `{provider}/{service}/{version}/`
2. Add `qbm.yml` + Terraform files or Helm values
3. Add `README.md` describing what the blueprint creates
4. Regenerate `catalog.json` locally and commit it:
   ```sh
   mise run generate-catalog
   git add catalog.json
   ```
5. Open a PR — CI validates structure, variables, and that `catalog.json` is up to date
6. Merge — CI auto-tags the new blueprint version

### Marking variables sensitive

Add `sensitive: true` to any variable that holds a secret (passwords, tokens, API keys). The console renders these as password inputs and Qovery encrypts the value at rest. Omit the field for non-sensitive variables (it defaults to `false`).

```yaml
variables:
  - name: "db_password"
    type: "string"
    required: true
    sensitive: true
    description: "Master password"
```

CI enforces this two ways:
- For Terraform blueprints, `qbm.yml` `sensitive` must match `variables.tf` `sensitive = true`.
- For any blueprint, variable names that look secret (`password`, `secret`, `token`, `api_key`, `access_key`, `private_key`, `credential`) must be `sensitive: true` — or rename the variable.
