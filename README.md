# Qovery Service Catalog

Pre-built blueprints for provisioning cloud resources and Kubernetes services through the Qovery platform.

## Available Blueprints

### AWS (Terraform)

| Service    | Path                     | Description                                          |
| ---------- | ------------------------ | ---------------------------------------------------- |
| S3         | `AWS/s3/default/`        | S3 bucket with encryption and versioning             |
| PostgreSQL | `AWS/postgres/17/`       | RDS PostgreSQL 17 instance                           |
| MySQL      | `AWS/mysql/8/`           | RDS MySQL 8.4 instance                               |
| CloudFront | `AWS/cloudfront/default/`| CloudFront CDN distribution in front of an HTTP/S origin |
| MSK        | `AWS/msk/default/`       | MSK Serverless (managed Kafka) with SASL/IAM auth    |

### GCP (Terraform)

| Service | Path             | Description                        |
| ------- | ---------------- | ----------------------------------- |
| Redis   | `GCP/redis/7/`   | Memorystore for Redis 7 instance    |

### Scaleway (Terraform)

| Service        | Path                          | Description                    |
| -------------- | ----------------------------- | ------------------------------ |
| Object Storage | `SCW/object-storage/default/` | Scaleway Object Storage bucket |
| PostgreSQL     | `SCW/postgres/16/`            | Managed Database PostgreSQL 16 |
| MySQL          | `SCW/mysql/8/`                | Managed Database MySQL 8       |

### Helm (Kubernetes)

| Service   | Path                     | Description                                                     |
| --------- | ------------------------ | --------------------------------------------------------------- |
| Redis     | `HELM/redis/8/`          | Redis 8 cache via community groundhog2k Helm chart              |
| RabbitMQ  | `HELM/rabbitmq/4/`       | RabbitMQ 4 message broker via community groundhog2k Helm chart  |
| Datadog   | `HELM/datadog/7/`        | Datadog Agent (metrics, logs, optional APM) via official chart  |
| New Relic | `HELM/newrelic/default/` | New Relic Kubernetes monitoring via official nri-bundle chart   |

### External (Terraform)

Third-party services not tied to the cluster's cloud provider — shown for every cloud in the console.
They authenticate through their own sensitive variables (`credentials` mode is `env`, never `cluster`).

| Service          | Path                                | Description                                    |
| ---------------- | ----------------------------------- | ---------------------------------------------- |
| Aiven Kafka      | `EXTERNAL/aiven-kafka/default/`     | Managed Kafka on Aiven                         |
| AWS Bedrock      | `EXTERNAL/bedrock/default/`         | Scoped Bedrock model access (IAM policy limited to named models, optional user + keys) |
| BigQuery         | `EXTERNAL/bigquery/default/`        | Google BigQuery dataset with an optional service account and key |
| Cloudflare DNS   | `EXTERNAL/cloudflare-dns-zone/default/` | Cloudflare DNS zone and records            |
| Cloudflare Workers | `EXTERNAL/cloudflare-workers/default/` | Cloudflare Worker script with optional route |
| Confluent Kafka  | `EXTERNAL/confluent-kafka/default/` | Managed Kafka on Confluent Cloud               |
| MongoDB Atlas    | `EXTERNAL/mongodb-atlas/default/`   | MongoDB Atlas cluster                          |
| PlanetScale      | `EXTERNAL/planetscale/default/`     | PlanetScale MySQL database                     |
| Redpanda Kafka   | `EXTERNAL/redpanda-kafka/default/`  | Managed Kafka-compatible Redpanda cluster      |
| Snowflake        | `EXTERNAL/snowflake/default/`       | Snowflake database, schema, warehouse and app role, with an optional SERVICE user |
| Temporal Cloud   | `EXTERNAL/temporal-cloud/default/`  | Temporal Cloud namespace                       |
| Timescale Cloud  | `EXTERNAL/timescale-cloud/default/` | Timescale Cloud service                        |

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
4. Deploy

## Blueprint Manifest (`qbm.yml`) Format

Every blueprint directory contains a `qbm.yml` file that describes the engine selection,
configuration knobs the user can tune, and what the deployment exposes back to dependent services.

### Top-level shape

```yaml
apiVersion: "qovery.com/v1"
kind: ServiceBlueprint
metadata:
  name: "aws-rds-postgresql"
  version: "1.2.0" # semver; CI auto-tags when this bumps
  description: "..." # short, one line
  icon: "app://qovery-console/postgresql"
  serviceFamily: "postgres"
  categories: ["database", "postgresql", "rds"]
spec:
  engine: { ... } # see below
  contextVariables: [...]
  variables: [...]
  outputs: [...]
```

### `spec.engine`

| Field                       | Required                   | Type              | Allowed values                              |
| --------------------------- | -------------------------- | ----------------- | ------------------------------------------- |
| `type`                      | yes                        | string            | `terraform` \| `opentofu` \| `helm`         |
| `provider`                  | yes (terraform / opentofu) | string            | `AWS` \| `GCP` \| `AZURE` \| `SCW` \| `EXTERNAL` — must match the top-level directory |
| `terraform`                 | yes if `type=terraform`    | block             | see below                                   |
| `opentofu`                  | yes if `type=opentofu`     | block             | same shape as `terraform`                   |
| `chart`                     | yes if `type=helm`         | block             | `{repository, name, version}`               |
| `credentials`               | optional                   | block             | see below — terraform/opentofu only         |
| `backend`                   | optional                   | block             | see below — terraform/opentofu only         |
| `timeout`                   | optional                   | integer (seconds) | platform default if omitted                 |
| `resources`                 | optional                   | block             | `{cpu, ram, storage}` for the apply job pod |
| `arguments`                 | optional (helm)            | `[string]`        | extra `helm install` args                   |
| `allowClusterWideResources` | optional (helm)            | bool              | default `false`                             |

#### Version block (`terraform` / `opentofu`)

```yaml
terraform:
  version: "1.9.7" # default the engine uses
  allowedValues: ["1.5.7", "1.9.7", "1.13.3"] # optional; user can pick from these
```

`version` is required when `type` is `terraform` or `opentofu`.

#### `credentials`

How the underlying terraform service authenticates against the cloud provider.

```yaml
credentials:
  default: cluster # cluster | env
  allowedValues: ["cluster", "env"] # optional; frontend dropdown
  overridable: true # optional; default false (omit = pinned to default)
```

| Mode      | Behavior                                                                                                            |
| --------- | ------------------------------------------------------------------------------------------------------------------- |
| `cluster` | Reuse the cluster's cloud credentials                                                                               |
| `env`     | User supplies cloud credentials as environment variables on the service. Manual setup required before first deploy. |

#### `backend`

Where the terraform state lives.

```yaml
backend:
  default: qovery # qovery | user_provided
  allowedValues: ["qovery", "user_provided"]
  overridable: true
  user_provided: # required iff default=user_provided
    type: s3 # s3 | gcs | azurerm | ...
    config:
      bucket: "..."
      region: "..."
      key: "..."
```

| Mode            | Behavior                                                                                                               |
| --------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `qovery`        | Managed by Qovery in a Kubernetes secret (default for managed blueprints).                                             |
| `user_provided` | User-controlled backend declared in the `user_provided` block (S3, GCS, …). Manual setup required before first deploy. |

#### `resources`

Sizing for the **apply pod** (the k8s Job running `terraform apply`).
For helm blueprints this block is ignored — the chart defines its own resources.

```yaml
resources:
  cpu: "500m" # Kubernetes-style CPU (millicores or whole cores)
  ram: "512Mi" # Mi / Gi
  storage: "1Gi" # ephemeral disk for state + provider plugins
```

### `allowedValues` and `overridable` semantics

Two layers govern what a user can pick for `credentials.default` / `backend.default` /
`terraform.version` / `opentofu.version`:

1. **Enum universe** — values supported by the platform (e.g. `cluster | env` for credentials).
2. **`allowedValues`** — subset a specific blueprint authorizes.

`overridable: false` pins the field to its `default` — any other value rejected.

### `spec.variables`

User-tunable inputs. Each variable must also exist in `variables.tf` (terraform blueprints).

```yaml
variables:
  - name: "db_name"
    type: "string" # string | number | bool
    required: true
    default: "mydb" # optional
    description: "PostgreSQL database name"
    pattern: "^[a-zA-Z][a-zA-Z0-9_]{0,62}$" # strings only — regex
    minLength: 1 # strings only
    maxLength: 63 # strings only
    min: 20 # numbers only
    max: 65536 # numbers only
    allowedValues: ["db.t3.micro", "db.t3.small"] # optional;
```

CI enforces:

- `sensitive` in `qbm.yml` must match `variables.tf` `sensitive = true`.
- Variable names matching `password|secret|token|api_key|access_key|private_key|credential` must
  be marked `sensitive: true` (or rename them).

### `spec.contextVariables`

Auto-sourced from the target cluster. Read-only for the user.

```yaml
contextVariables:
  - name: "region"
    source: "cluster.region" # cluster.region | cluster.name
    overridable: false
```

### `spec.outputs`

Values the deployed terraform/helm service publishes back to Qovery (consumable by other services
via variable interpolation).

```yaml
outputs:
  - name: "db_endpoint"
    description: "RDS instance endpoint (host:port)"
    sensitive: false
  - name: "db_password"
    description: "Master password"
    sensitive: true
```

## Versioning

Tags follow the format `{provider}/{service}/{major-version}/{semver}` (e.g. `AWS/s3/default/1.0.0`).
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
