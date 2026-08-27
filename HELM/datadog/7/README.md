# Datadog

Deploys the [Datadog Agent](https://docs.datadoghq.com/agent/kubernetes/) on Kubernetes via the official `datadog/datadog` Helm chart (`3.240.0`, Agent v7) — a per-node metrics/logs DaemonSet plus the Datadog cluster agent.

## Credentials

A **Datadog API key** supplied as the sensitive `datadog_api_key` variable, plus the `datadog_site` matching your account's region. Data appears in your Datadog account (no in-cluster endpoint to connect to).

## Variables

| Name              | Type   | Sensitive | Default           | Description                                                       |
| ----------------- | ------ | --------- | ----------------- | ----------------------------------------------------------------- |
| `datadog_api_key` | string | yes       | —                 | Datadog API key (required)                                        |
| `datadog_site`    | string |           | `datadoghq.com`   | Datadog site (`datadoghq.com`, `datadoghq.eu`, `us3/us5/ap1`, gov) |
| `cluster_name`    | string |           | —                 | Cluster name tag on all telemetry, lowercase RFC1123 (required)    |
| `enable_logs`     | string |           | `true`            | Collect container logs from all pods (`true`/`false`)             |
| `enable_apm`      | string |           | `false`           | Enable the APM trace-agent port (`true`/`false`)                  |
| `agent_memory`    | string |           | `512Mi`           | Memory request/limit for the node agent container                 |

## Outputs

| Name                            | Description                                    |
| ------------------------------- | ---------------------------------------------- |
| `datadog_cluster_agent_service` | In-cluster Datadog cluster-agent service name  |

## Notes

- `cluster_name` is required and has no default. `1.x` defaulted it to the placeholder `qovery-cluster`, so installs that never touched the field tagged all telemetry with a name matching no real cluster. It is not auto-filled from the Qovery cluster because cluster names are unconstrained and Datadog requires lowercase RFC1123 — see QOV-2188.
- The Datadog Operator is explicitly disabled (`datadog.operator.enabled: false`). Chart `3.240.0` enables it by default, which adds 7 cluster-scoped CRDs; because CRDs are singular per cluster, the first environment to install would own them and every later Datadog install on that cluster would fail with a Helm ownership error. The agent is deployed directly by this chart, so the Operator was unused. `1.x` shipped it.
- Deploys cluster-wide resources (DaemonSet, ClusterRole/Binding, cluster agent) — `allowClusterWideResources: true`.
- Resources are set explicitly for the node agent (`agent_memory`) and the cluster agent (256Mi); tune `agent_memory` for high-cardinality nodes.
- APM: with `enable_apm=true`, point tracers at the agent on the node (or the `datadog.apm` socket) per Datadog's APM setup docs.
- Chart pinned to `3.240.0`. This is the official Datadog chart (not Bitnami).
