# Timescale Cloud Service

Provisions a [Timescale Cloud](https://www.timescale.com/cloud) service (`timescale_service`) — managed TimescaleDB/PostgreSQL — via the official `timescale/timescale` provider (`~> 2.0`).

> **Timescale Cloud only** (managed SaaS), not self-hosted TimescaleDB.

## Credentials

Timescale Cloud **client credentials**: `timescale_project_id` + a `timescale_access_key` / `timescale_secret_key` pair (both sensitive), supplied as variables (`credentials.default: env`).

## Variables

### Required

| Name                   | Type   | Sensitive | Description                               |
| ---------------------- | ------ | --------- | ----------------------------------------- |
| `timescale_project_id` | string |           | Timescale Cloud project ID                |
| `timescale_access_key` | string | yes       | Client credentials — access key           |
| `timescale_secret_key` | string | yes       | Client credentials — secret key           |
| `service_name`         | string |           | Service name (1-128 chars)                |

### Service shape

| Name          | Type   | Default     | Description                                                        |
| ------------- | ------ | ----------- | ------------------------------------------------------------------ |
| `region_code` | string | `us-east-1` | Region (AWS-style code, e.g. `us-east-1`, `eu-west-1`)             |
| `milli_cpu`   | number | `500`       | CPU in milli-CPU: 500/1000/2000/4000/8000/16000/32000              |
| `memory_gb`   | number | `2`         | Memory GB: 2/4/8/16/32/64/128 (paired with `milli_cpu`)            |
| `ha_replicas` | number | `0`         | High-availability replicas (0-2)                                   |

Timescale requires matching CPU/memory pairs — `500m ↔ 2GB`, `1000m ↔ 4GB`, `2000m ↔ 8GB`, and so on. Mismatched pairs are rejected at apply time.

## Outputs

| Name         | Sensitive | Description               |
| ------------ | --------- | ------------------------- |
| `service_id` |           | Timescale service ID      |
| `hostname`   |           | Service hostname          |
| `port`       |           | Service port              |
| `username`   |           | Master database username  |
| `password`   | yes       | Master database password  |
| `connection_uri` | yes   | Ready-to-use PostgreSQL URI (creds embedded, db `tsdb`, TLS) |

## Notes

- Provisioning a Timescale Cloud service is billable.
- The master `password` is only returned by the API at creation time; it is surfaced as a sensitive output.
