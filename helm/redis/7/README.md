# Redis (Helm)

Deploys Redis via the Bitnami Helm chart.

## Variables
| Name | Type | Required | Sensitive | Default | Description |
|------|------|----------|-----------|---------|-------------|
| replica_count | number | no | | 1 | Number of Redis replicas |
| memory_limit | string | no | | 256Mi | Memory limit for Redis pods |
| password | string | yes | yes | - | Redis authentication password |

## Outputs
| Name | Description |
|------|-------------|
| redis_host | Redis service hostname |
| redis_port | Redis service port |
