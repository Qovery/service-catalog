# Aiven for Apache Kafka

Provisions a managed [Aiven for Apache Kafka](https://aiven.io/kafka) service (`aiven_kafka`) via the official `aiven/aiven` provider (`~> 4.0`). A single resource yields a usable, connectable cluster with SASL credentials.

## Credentials

An **Aiven API token** supplied as the sensitive `aiven_api_token` variable (`credentials.default: env`), plus an existing Aiven `project`.

## Variables

| Name              | Type   | Sensitive | Default          | Description                                            |
| ----------------- | ------ | --------- | ---------------- | ------------------------------------------------------ |
| `aiven_api_token` | string | yes       | —                | Aiven API token (required)                             |
| `project`         | string |           | —                | Existing Aiven project (required)                      |
| `service_name`    | string |           | —                | Service name, immutable (required)                     |
| `cloud_name`      | string |           | `aws-eu-west-1`  | `<provider>-<region>` (e.g. `google-europe-west1`)     |
| `plan`            | string |           | `startup-2`      | Sizing tier (`startup-2`, `business-4`, `premium-8`)   |
| `kafka_version`   | string |           | `3.9`            | Apache Kafka version                                   |

## Outputs

| Name          | Sensitive | Description                     |
| ------------- | --------- | ------------------------------- |
| `service_uri` | yes       | Full Kafka connection URI       |
| `host`        |           | Broker host (bootstrap)         |
| `port`        |           | Broker port                     |
| `username`    |           | SASL username                   |
| `password`    | yes       | SASL password                   |

## Notes

- No free tier — the cheapest Kafka plan is `startup-2` (hourly-billed). The Aiven `project` must exist with billing attached.
- Aiven also issues mTLS client certs (`access_cert`/`access_key`) on the service; this blueprint surfaces the SASL host/port/username/password path. Connect with `host:port` + SASL.
