# Temporal Cloud Namespace

Provisions a [Temporal Cloud](https://temporal.io/cloud) namespace (`temporalcloud_namespace`) via the official `temporalio/temporalcloud` provider (`~> 1.0`).

> **Temporal Cloud only.** There is no official Terraform provider for self-hosted Temporal — deploy that via Helm/containers. This blueprint manages the SaaS offering.

## Credentials

A **Temporal Cloud API key** supplied as the sensitive `temporal_cloud_api_key` variable (`credentials.default: env`). Generate it in the Temporal Cloud UI / `tcld` with permission to manage namespaces.

## Variables

### Required

| Name                     | Type   | Sensitive | Description                                              |
| ------------------------ | ------ | --------- | -------------------------------------------------------- |
| `temporal_cloud_api_key` | string | yes       | Temporal Cloud API key                                   |
| `namespace_name`         | string |           | Namespace name (`^[a-z0-9-]{2,64}$`)                     |

### Optional

| Name                 | Type   | Default         | Description                                                       |
| -------------------- | ------ | --------------- | ----------------------------------------------------------------- |
| `regions`            | string | `aws-us-east-1` | Comma-separated regions (1-2), e.g. `aws-us-east-1`               |
| `retention_days`     | number | `30`            | Workflow execution retention (1-90 days)                          |
| `accepted_client_ca` | string |                 | Base64 PEM CA bundle to additionally enable mTLS. Unset = api-key only. |

API-key client auth is always enabled; supplying `accepted_client_ca` additionally enables mTLS.

## Outputs

| Name                 | Description                                    |
| -------------------- | ---------------------------------------------- |
| `namespace_id`       | Full namespace id (`name.accountId`)           |
| `namespace_name`     | Namespace name                                 |
| `grpc_endpoint`      | gRPC endpoint for API-key clients              |
| `mtls_grpc_endpoint` | gRPC endpoint for mTLS clients                 |

## Notes

- The namespace's full id is `namespace_name` + your Temporal Cloud account suffix (see `namespace_id`).
- Clients connect at `grpc_endpoint` (with an API key) or `mtls_grpc_endpoint` (with a client cert chained to `accepted_client_ca`).
