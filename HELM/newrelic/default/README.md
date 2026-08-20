# New Relic

Deploys [New Relic Kubernetes monitoring](https://docs.newrelic.com/docs/kubernetes-pixie/kubernetes-integration/get-started/introduction-kubernetes-integration/) via the official `newrelic/nri-bundle` Helm chart (`8.0.18`): the infrastructure agent (per-node DaemonSet), kube-state-metrics, metadata injection, Kubernetes events, and optional pod-log shipping.

## Credentials

A **New Relic ingest license key** supplied as the sensitive `newrelic_license_key` variable, plus a `cluster_name` reported to New Relic. Data appears in your New Relic account (no in-cluster endpoint to connect to).

## Variables

| Name                   | Type   | Sensitive | Default          | Description                                                        |
| ---------------------- | ------ | --------- | ---------------- | ------------------------------------------------------------------ |
| `newrelic_license_key` | string | yes       | —                | New Relic ingest license key (required)                            |
| `cluster_name`         | string |           | —                | Cluster name reported to New Relic (required)                      |
| `low_data_mode`        | string |           | `true`           | Reduce ingest to control cost (`true`/`false`)                     |
| `enable_kube_events`   | string |           | `true`           | Collect Kubernetes events (`true`/`false`)                         |
| `enable_logging`       | string |           | `false`          | Deploy the Fluent Bit log DaemonSet (`true`/`false`)               |
| `ksm_memory`           | string |           | `128Mi`          | Memory request/limit for kube-state-metrics                        |

## Notes

- Deploys cluster-wide resources (DaemonSets, ClusterRole/Binding across sub-charts) — `allowClusterWideResources: true`.
- **Resources:** `kube-state-metrics` is set explicitly (the bundle leaves it unbounded by default); the New Relic agent sub-charts (`newrelic-infrastructure`, logging) use New Relic's own tuned resource defaults. Override per sub-chart if you need tighter limits.
- `low_data_mode` defaults to `true` to keep ingest (and cost) down; set `false` for full-fidelity data.
- Chart pinned to `nri-bundle 8.0.18`. This is the official New Relic chart (not Bitnami).
- The `nri-bundle` meta-chart has no single `appVersion`, so this blueprint lives under `default` per the catalog's versioning convention.
