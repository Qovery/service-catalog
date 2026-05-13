# RabbitMQ (Helm)

Deploys RabbitMQ message broker via the Bitnami Helm chart.

## Variables
| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| replica_count | number | no | 1 | Number of RabbitMQ replicas |
| username | string | no | user | RabbitMQ default username |
| password | string | yes | - | RabbitMQ authentication password |
| memory_limit | string | no | 256Mi | Memory limit for RabbitMQ pods |

## Outputs
| Name | Description |
|------|-------------|
| rabbitmq_host | RabbitMQ service hostname |
| rabbitmq_port | RabbitMQ AMQP port |
