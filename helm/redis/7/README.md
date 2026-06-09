# Redis (Helm)

Deploys Redis in standalone mode via the Bitnami Helm chart. Authentication is enabled by default. Data is not persisted (in-memory only) — pod restarts will clear all data.

## Variables

| Name           | Type   | Required | Sensitive | Default | Description                                                                                      |
| -------------- | ------ | -------- | --------- | ------- | ------------------------------------------------------------------------------------------------ |
| `memory_limit` | string | no       |           | `256Mi` | Memory limit for Redis pods. Must be a valid Kubernetes quantity (e.g. `256Mi`, `512Mi`, `1Gi`). |
| `password`     | string | yes      | yes       | —       | Redis authentication password (min 10 chars recommended).                                        |

## Outputs

| Name         | Description            |
| ------------ | ---------------------- |
| `redis_host` | Redis service hostname |
| `redis_port` | Redis service port     |
