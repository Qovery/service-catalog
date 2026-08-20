# Redpanda Cloud (Serverless)

Provisions a [Redpanda Cloud](https://redpanda.com/redpanda-cloud) **serverless** Kafka-API-compatible cluster via the official `redpanda-data/redpanda` provider (`~> 2.0`).

Resource chain: `redpanda_resource_group` → `redpanda_serverless_cluster`.

## Credentials

A Redpanda Cloud **service account**: `redpanda_client_id` + sensitive `redpanda_client_secret` (`credentials.default: env`), created under Organization IAM.

## Variables

| Name                     | Type   | Sensitive | Default   | Description                                            |
| ------------------------ | ------ | --------- | --------- | ------------------------------------------------------ |
| `redpanda_client_id`     | string |           | —         | Service-account client ID (required)                   |
| `redpanda_client_secret` | string | yes       | —         | Service-account client secret (required)               |
| `resource_group_name`    | string |           | `qovery`  | Resource group to create                               |
| `cluster_name`           | string |           | —         | Serverless cluster name (required)                     |
| `serverless_region`      | string |           | —         | Redpanda serverless region (required, e.g. `us-east-1`)|

## Outputs

| Name                 | Description                                          |
| -------------------- | ---------------------------------------------------- |
| `cluster_id`         | Serverless cluster ID                                |
| `cluster_api_url`    | Cluster dataplane API URL                            |
| `kafka_seed_brokers` | Kafka bootstrap/seed broker endpoints (connect here) |
| `console_url`        | Redpanda Console URL                                 |

## Notes

- Paid SaaS (requires a Redpanda Cloud account + service account). Serverless is the low-friction path — Redpanda manages networking, no VPC resources.
- `serverless_region` has no default: set a region Redpanda Serverless supports (invalid regions are rejected at apply).
- To connect a client you also need SASL credentials — create a `redpanda_user` / ACL in the Redpanda console (or a follow-up Terraform step); this blueprint provisions the cluster and exposes `kafka_seed_brokers` + `cluster_api_url`.
