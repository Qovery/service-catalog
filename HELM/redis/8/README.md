# Redis (Helm)

Deploys Redis cache via the community [groundhog2k](https://github.com/groundhog2k/helm-charts) Helm chart, which wraps the official `docker.io/redis` image (Redis 8). Standalone, single instance. Data is not persisted — pod restarts clear all keys.

> **Security note:** the official Redis image has no password env var, so `requirepass` is set via `redis.conf`, which the chart renders into a **ConfigMap in plaintext** (not a Secret). Fine for a non-persistent dev cache; do not store sensitive data.

## Variables

| Name           | Type   | Required | Sensitive | Default | Description                                                                                |
| -------------- | ------ | -------- | --------- | ------- | ------------------------------------------------------------------------------------------ |
| `memory_limit` | string | no       |           | `512Mi` | Memory limit for Redis pods. Must be a valid Kubernetes quantity (e.g. `512Mi`, `1Gi`).    |
| `password`     | string | yes      | yes       | —       | Redis authentication password (min 10 chars recommended).                                  |

## Outputs

| Name         | Description           |
| ------------ | --------------------- |
| `redis_host` | Redis service hostname |
| `redis_port` | Redis service port     |
