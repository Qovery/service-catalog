# Datadog

Deploys the [Datadog Agent](https://docs.datadoghq.com/agent/kubernetes/) on Kubernetes via the official `datadog/datadog` Helm chart (`3.240.0`, Agent v7) — a per-node metrics/logs DaemonSet plus the Datadog cluster agent.

## Credentials

A **Datadog API key** supplied as the sensitive `datadog_api_key` variable, plus the `datadog_site` matching your account's region. Data appears in your Datadog account (no in-cluster endpoint to connect to).

## Variables

| Name              | Type   | Sensitive | Default           | Description                                                       |
| ----------------- | ------ | --------- | ----------------- | ----------------------------------------------------------------- |
| `datadog_api_key` | string | yes       | —                 | Datadog API key (required)                                        |
| `datadog_site`    | string |           | `datadoghq.com`   | Datadog site (`datadoghq.com`, `datadoghq.eu`, `us3/us5/ap1`, gov) |
| `cluster_name`    | string |           | Qovery cluster name | Cluster name tag on all telemetry. Empty = the Qovery cluster's name, slugified |
| `enable_logs`     | string |           | `true`            | Collect container logs from all pods (`true`/`false`)             |
| `enable_apm`      | string |           | `false`           | Enable the APM trace-agent port (`true`/`false`)                  |
| `agent_memory`    | string |           | `512Mi`           | Memory request/limit for the node agent container                 |

## Outputs

| Name                            | Description                                    |
| ------------------------------- | ---------------------------------------------- |
| `datadog_cluster_agent_service` | In-cluster Datadog cluster-agent service name  |

## Notes

- `cluster_name` is optional and defaults to the **actual Qovery cluster name**, taken from the `qovery_cluster_name` variable the engine injects into every blueprint and passed through Tera's `slugify`. `1.x` defaulted it to the placeholder `qovery-cluster`, so installs that never touched the field tagged all telemetry with a name matching no real cluster. Slugifying is required because Qovery cluster names are unconstrained while Datadog demands lowercase RFC1123, so a name carrying uppercase or underscores is lowercased and hyphenated. Set the variable explicitly to use a different tag; it must already be valid RFC1123 (the `pattern` enforces it).
- The Datadog Operator is explicitly disabled (`datadog.operator.enabled: false`). Chart `3.240.0` enables it by default, which adds 7 cluster-scoped CRDs; because CRDs are singular per cluster, the first environment to install would own them and every later Datadog install on that cluster would fail with a Helm ownership error. The agent is deployed directly by this chart, so the Operator was unused. `1.x` shipped it.
- The Cluster Agent's admission controller is disabled (`clusterAgent.admissionController.enabled: false`). Its Service is named `<release>-cluster-agent-admission-controller`, and since Qovery release names are `helm-z<id>-<service name>`, a service name longer than 13 characters pushes it past Kubernetes' 63-character limit and the deploy fails. It injects APM/DogStatsD config only into pods labelled `admission.datadoghq.com/enabled=true`, which Qovery services do not carry, so nothing is lost — configure tracers as described below. `1.x` shipped it enabled.
- **Service name length.** With the admission controller gone the longest suffix the chart appends is `-kpi-telemetry-configmap` (24 characters), so a Qovery service name above ~24 characters will still breach the 63-character limit on a resource name. Keep the service name short.
- Deploys cluster-wide resources (DaemonSet, ClusterRole/Binding, cluster agent) — `allowClusterWideResources: true`.
- Resources are set explicitly for the node agent (`agent_memory`) and the cluster agent (256Mi); tune `agent_memory` for high-cardinality nodes.
- APM: with `enable_apm=true`, point tracers at the agent on the node (or the `datadog.apm` socket) per Datadog's APM setup docs.
- Chart pinned to `3.240.0`. This is the official Datadog chart (not Bitnami).
