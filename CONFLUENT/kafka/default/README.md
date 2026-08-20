# Confluent Cloud Kafka

Provisions a [Confluent Cloud](https://www.confluent.io/confluent-cloud/) Kafka cluster (Basic) via the official `confluentinc/confluent` provider (`~> 2.0`), along with the environment, a service account, and a client API key so an app can connect immediately.

Resource chain: `confluent_environment` → `confluent_kafka_cluster` (`basic {}`) → `confluent_service_account` → `confluent_api_key`.

## Credentials

A Confluent Cloud **API key/secret** (Cloud-level) as sensitive `confluent_cloud_api_key` / `confluent_cloud_api_secret` (`credentials.default: env`).

## Variables

### Required

| Name                         | Type   | Sensitive | Description                          |
| ---------------------------- | ------ | --------- | ------------------------------------ |
| `confluent_cloud_api_key`    | string | yes       | Cloud API key (provider auth)        |
| `confluent_cloud_api_secret` | string | yes       | Cloud API secret                     |
| `cluster_name`               | string |           | Kafka cluster display name           |

### Optional

| Name                   | Type   | Default       | Description                              |
| ---------------------- | ------ | ------------- | ---------------------------------------- |
| `environment_name`     | string | `qovery`      | Confluent environment to create          |
| `availability`         | string | `SINGLE_ZONE` | `SINGLE_ZONE` or `MULTI_ZONE`            |
| `cloud`                | string | `AWS`         | `AWS`, `AZURE`, `GCP`                    |
| `region`               | string | `us-east-2`   | Cloud region                             |
| `service_account_name` | string | `qovery-app`  | Service account for the client API key   |

## Outputs

| Name                 | Sensitive | Description                             |
| -------------------- | --------- | --------------------------------------- |
| `environment_id`     |           | Confluent environment ID                |
| `cluster_id`         |           | Kafka cluster ID (`lkc-...`)            |
| `bootstrap_endpoint` |           | Kafka bootstrap endpoint (connect here) |
| `rest_endpoint`      |           | Kafka REST proxy endpoint               |
| `kafka_api_key`      |           | Client Kafka API key (SASL username)    |
| `kafka_api_secret`   | yes       | Client Kafka API secret (SASL password) |

## Notes

- No free tier — Basic has no base cost but bills throughput/storage; Standard/Dedicated/Enterprise cost more.
- Connect with `bootstrap_endpoint` using SASL/PLAIN and the `kafka_api_key` / `kafka_api_secret`.
- Creates a **new environment** (`environment_name`); the client API key is scoped to this cluster + service account.
