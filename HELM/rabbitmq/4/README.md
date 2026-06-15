# RabbitMQ (Helm)

Deploys RabbitMQ message broker via the Bitnami Helm chart. Data is not persisted — pod restarts will clear queues and messages.

## Variables

| Name            | Type   | Required | Sensitive | Default | Description                                                                                         |
| --------------- | ------ | -------- | --------- | ------- | --------------------------------------------------------------------------------------------------- |
| `replica_count` | number | no       |           | `1`     | Number of RabbitMQ replicas. Min 1, max 10.                                                         |
| `username`      | string | no       |           | `user`  | RabbitMQ default username. Use letters, digits, hyphens, underscores, and dots only.                |
| `password`      | string | yes      | yes       | —       | RabbitMQ authentication password (min 10 chars recommended).                                        |
| `memory_limit`  | string | no       |           | `256Mi` | Memory limit for RabbitMQ pods. Must be a valid Kubernetes quantity (e.g. `256Mi`, `512Mi`, `1Gi`). |

## Outputs

| Name            | Description               |
| --------------- | ------------------------- |
| `rabbitmq_host` | RabbitMQ service hostname |
| `rabbitmq_port` | RabbitMQ AMQP port        |
