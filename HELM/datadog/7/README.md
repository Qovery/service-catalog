# Datadog

Deploys the [Datadog Agent](https://docs.datadoghq.com/agent/kubernetes/) on Kubernetes via the official `datadog/datadog` Helm chart (`3.240.0`, Agent v7) — a per-node metrics/logs DaemonSet plus the Datadog cluster agent.

## Credentials

A **Datadog API key** supplied as the sensitive `datadog_api_key` variable, plus the `datadog_site` matching your account's region. Data appears in your Datadog account (no in-cluster endpoint to connect to).

## Variables

| Name              | Type   | Sensitive | Default           | Description                                                       |
| ----------------- | ------ | --------- | ----------------- | ----------------------------------------------------------------- |
| `datadog_api_key` | string | yes       | —                 | Datadog API key (required)                                        |
| `datadog_site`    | string |           | `datadoghq.com`   | Datadog site (`datadoghq.com`, `datadoghq.eu`, `us3/us5/ap1`, gov) |
| `cluster_name`    | string |           | `qovery-cluster`  | Cluster name tag on all telemetry (lowercase RFC1123)             |
| `enable_logs`     | string |           | `true`            | Collect container logs from all pods (`true`/`false`)             |
| `enable_apm`      | string |           | `false`           | Enable the APM trace-agent port (`true`/`false`)                  |
| `agent_memory`    | string |           | `512Mi`           | Memory request/limit for the node agent container                 |

## Outputs

| Name                            | Description                                    |
| ------------------------------- | ---------------------------------------------- |
| `datadog_cluster_agent_service` | In-cluster Datadog cluster-agent service name  |

## Notes

- Deploys cluster-wide resources (DaemonSet, ClusterRole/Binding, cluster agent) — `allowClusterWideResources: true`.
- Resources are set explicitly for the node agent (`agent_memory`) and the cluster agent (256Mi); tune `agent_memory` for high-cardinality nodes.
- APM: with `enable_apm=true`, point tracers at the agent on the node (or the `datadog.apm` socket) per Datadog's APM setup docs.
- Chart pinned to `3.240.0`. This is the official Datadog chart (not Bitnami).
