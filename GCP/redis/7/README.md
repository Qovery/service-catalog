# GCP Memorystore for Redis 7

Creates a GCP Memorystore for Redis 7 instance with configurable tier, memory size, auth, TLS, persistence, maintenance window, and optional cross-zone read replicas. There is no user-supplied password: when `auth_enabled` is true, GCP generates an AUTH string that is published via the `redis_auth_string` output.

## Variables

### Required

| Name             | Type   | Sensitive | Description                                                                                                       |
| ---------------- | ------ | --------- | ------------------------------------------------------------------------------------------------------------------ |
| `redis_name`     | string |           | Memorystore instance ID. Lowercase letters, digits, hyphens; must start with a letter and not end with a hyphen; max 40 chars. |
| `tier`            | string |           | Service tier: `BASIC` or `STANDARD_HA`. Default suggestion: `BASIC`.                                              |
| `memory_size_gb`  | number |           | Instance memory size in GiB (min 1, max 300). Default suggestion: `1`.                                            |

### Engine & sizing

| Name             | Type   | Default     | Description                                                                              |
| ---------------- | ------ | ----------- | ----------------------------------------------------------------------------------------- |
| `redis_version`  | string | `REDIS_7_2` | Redis version: `REDIS_7_2`, `REDIS_7_0`                                                   |
| `maxmemory_policy` | string | `noeviction` | Redis eviction policy applied once `memory_size_gb` is full                             |

### Auth & network

| Name                      | Type   | Default          | Description                                                                                                      |
| ------------------------- | ------ | ---------------- | ------------------------------------------------------------------------------------------------------------------ |
| `auth_enabled`            | bool   | `true`           | Require an AUTH string to connect                                                                                |
| `transit_encryption_mode` | string | `DISABLED`       | `DISABLED` or `SERVER_AUTHENTICATION` (TLS; clients must trust the CA cert from `redis_server_ca_certs`)         |
| `authorized_network`      | string | `""`             | VPC network self-link to connect to. Empty = the project's default network.                                      |
| `connect_mode`            | string | `DIRECT_PEERING` | `DIRECT_PEERING` or `PRIVATE_SERVICE_ACCESS`                                                                      |
| `reserved_ip_range`       | string | `""`             | CIDR /29 (or named allocated range for PSA) reserved for the instance. Empty = GCP picks one automatically.       |

By default the instance attaches to the project's **default** VPC network, which is usually *not* the Qovery cluster's VPC. Set `authorized_network` to the cluster's VPC self-link (and `connect_mode`/`reserved_ip_range` as required by that network's setup) so pods in the cluster can reach the instance without extra peering.

**Security note — plaintext by default:** `transit_encryption_mode` defaults to `DISABLED`. Since `auth_enabled` also defaults to `true`, the generated AUTH string and all cache traffic (including the data itself) travel **unencrypted** over the VPC on every connection — anyone able to observe traffic on that network path can capture both. Memorystore instances are never reachable from the public internet, but this offers no protection against other workloads sharing the same VPC. Set `transit_encryption_mode = SERVER_AUTHENTICATION` for anything beyond a trusted, fully isolated environment; clients then need to trust the CA certificate published via `redis_server_ca_certs` and connect over TLS (e.g. `rediss://`), which most Redis client libraries support but require explicit configuration for.

### Persistence

| Name                  | Type   | Default             | Description                                                     |
| --------------------- | ------ | ------------------- | ---------------------------------------------------------------- |
| `persistence_mode`    | string | `DISABLED`          | `DISABLED` or `RDB`                                               |
| `rdb_snapshot_period` | string | `TWENTY_FOUR_HOURS` | Snapshot interval. Only used when `persistence_mode` is `RDB`.   |

### Maintenance

| Name                     | Type   | Default | Description                                                                 |
| ------------------------ | ------ | ------- | ----------------------------------------------------------------------------- |
| `maintenance_day`        | string | `""`    | Day of week for the maintenance window. Empty disables a fixed window.       |
| `maintenance_start_hour` | number | `2`     | Maintenance window start hour, UTC 24h. Only used when `maintenance_day` is set. |

### Read replicas

| Name            | Type   | Default | Description                                                                                                        |
| --------------- | ------ | ------- | ---------------------------------------------------------------------------------------------------------------- |
| `replica_count` | number | `0`     | Number of *exposed* cross-zone read replicas (0-5). Only supported when `tier` is `STANDARD_HA`.                  |

Replicas are asynchronous, cross-zone, read-only copies of the primary; point analytics/BI tools at the `redis_read_endpoint` output to keep read traffic off the primary. Setting `replica_count > 0` requires `tier = STANDARD_HA`.

`STANDARD_HA` always allocates a standby node for automatic failover, independent of `replica_count` — GCP requires at least one such node once `STANDARD_HA` is selected. `replica_count = 0` (the default) just means that standby isn't exposed as a readable replica; the blueprint sends GCP the required minimum under the hood. Set `replica_count` to 1-5 to also expose it (or additional nodes) via `redis_read_endpoint`.

### Misc

| Name             | Type   | Default | Description                                                                       |
| ---------------- | ------ | ------- | ---------------------------------------------------------------------------------- |
| `gcp_project_id` | string | `""`    | GCP project ID override. Empty = inferred from the credentials used to deploy.    |

## Outputs

| Name                        | Sensitive | Description                                                                                  |
| --------------------------- | --------- | ---------------------------------------------------------------------------------------------- |
| `redis_id`                  |           | Memorystore instance ID                                                                       |
| `redis_host`                |           | Primary endpoint hostname                                                                      |
| `redis_port`                |           | Primary endpoint port                                                                          |
| `redis_current_location_id` |           | Zone the primary node currently runs in                                                       |
| `redis_auth_string`         | yes       | AUTH string for authenticating (set only when `auth_enabled` is true)                         |
| `redis_server_ca_certs`     |           | Server CA certificates (PEM) for TLS verification when `transit_encryption_mode` is `SERVER_AUTHENTICATION` |
| `redis_read_endpoint`       |           | Read replica endpoint hostname (empty when `replica_count` is 0)                              |
| `redis_read_endpoint_port`  |           | Read replica endpoint port (empty when `replica_count` is 0)                                  |

## Required GCP IAM permissions

The credentials used to deploy this blueprint must be able to manage Memorystore Redis instances in the target project:

```json
{
  "bindings": [
    {
      "role": "roles/redis.admin",
      "members": ["<the deploying principal>"]
    }
  ]
}
```

`roles/redis.admin` (or the underlying `redis.instances.*` permissions) is sufficient for create, read, update, and delete. If `authorized_network` points at a network in a different (Shared VPC host) project, grant `roles/compute.networkUser` on that network to the Memorystore Redis service agent of *this* project — the one hosting the instance (`service-PROJECT_NUMBER@cloud-redis.iam.gserviceaccount.com`, where `PROJECT_NUMBER` is `gcp_project_id`'s project, or the deploy credentials' default project when `gcp_project_id` is empty) — not a service agent from the network's project.
