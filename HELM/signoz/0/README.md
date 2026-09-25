# SigNoz (Helm)

Deploys [SigNoz](https://signoz.io/docs/) `v0.143.0` with the official `signoz/signoz` Helm chart (`0.143.0`): the SigNoz UI and query server, an OpenTelemetry collector, ClickHouse (through the Altinity operator) and ZooKeeper.

Applications send traces, metrics and logs over OTLP to the in-cluster collector:

| Protocol | Endpoint |
| -------- | -------- |
| gRPC     | `signoz-otel-collector.<environment namespace>.svc.cluster.local:4317` |
| HTTP     | `http://signoz-otel-collector.<environment namespace>.svc.cluster.local:4318` |

With `prometheus_federation=true` (the default), the collector also copies container, pod and node metrics from the Prometheus Qovery installs with cluster metrics, so they can be queried with PromQL in SigNoz dashboards and alerts. Only data from the install onwards is copied; the history stays in Prometheus/Thanos.

## Credentials

The admin is SigNoz's **root user**, provisioned from `admin_email` and the sensitive `admin_password` entered in the Qovery console. SigNoz reconciles it on every start: changing either value and redeploying updates the admin's email or resets the password. The root user cannot be deleted, renamed or have its password changed from the SigNoz UI; use the Qovery form.

`org_name` is only used when SigNoz creates the organization. The organization id is pinned, so a later change of `org_name` neither renames the organization nor creates a second one.

The password must be at least 12 characters and contain an uppercase letter, a lowercase letter, a digit and one of ``~!@#$%^&*()_+`-={}|[]\:"<>?,./``, with no other characters (no spaces, single quotes `'` or semicolons; double quotes are allowed). The form rejects anything else: SigNoz would refuse it and never become ready.

## Variables

### Required

| Name             | Type   | Sensitive | Description |
| ---------------- | ------ | --------- | ----------- |
| `admin_email`    | string |           | Email of the SigNoz admin (root user). Changing it and redeploying updates the admin's email. |
| `admin_password` | string | yes       | At least 12 characters with an uppercase letter, a lowercase letter, a digit and a symbol from the list above; no spaces, single quotes or semicolons. Changing it and redeploying resets it. |

### Optional

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `org_name` | string | `SigNoz` | Name of the organization SigNoz creates on first start. Set once: changing it later has no effect; rename it in SigNoz settings. |
| `external_url` | string | — | Unset = links in alert notifications point to `http://localhost:8080`. Set the URL users reach SigNoz on so alert links work. |
| `usage_reporting` | string | `false` | Send anonymous usage statistics to the SigNoz team (`true`/`false`). |
| `prometheus_federation` | string | `true` | Copy metrics from the cluster's Prometheus into SigNoz (`true`/`false`). |
| `prometheus_address` | string | `prometheus-operated.prometheus.svc.cluster.local:9090` | Leave the default on AWS and Scaleway. On GKE and AKS use `prometheus-operated.qovery.svc.cluster.local:9090`. `host:port`, no scheme. |
| `federation_match` | string | `{job=~"kubelet\|kube-state-metrics\|node-exporter"}` | Prometheus series selector of what to copy. Every series is stored again in ClickHouse; widen it with care. |
| `federation_interval` | string | `60s` | How often metrics are copied, in `s` or `m`. At least `15s`. |
| `clickhouse_storage_size` | string | `50Gi` | Volume holding every trace, log and metric. Can only grow after creation, on a storage class that allows expansion. |
| `storage_class` | string | — | Unset = the cluster's default storage class, for every SigNoz volume. Choose it at creation: changing it later fails the deploy. |
| `clickhouse_cpu` | string | `500m` | CPU request for ClickHouse. |
| `clickhouse_memory` | string | `4Gi` | Memory limit for ClickHouse; requests are a quarter of it. `Gi` or `Mi`. |
| `collector_memory` | string | `4Gi` | Memory limit for the OpenTelemetry collector. Federation of the default selector needs about 2Gi on a mid-size cluster. `Gi` or `Mi`. |
| `signoz_memory` | string | `1Gi` | Memory limit for the SigNoz UI and query server. `Gi` or `Mi`. |

## Outputs

| Name                | Description |
| ------------------- | ----------- |
| `signoz_ui_service` | In-cluster SigNoz UI and API service (`signoz`, port 8080) |
| `otlp_endpoint`     | In-cluster OTLP endpoint (`signoz-otel-collector`, ports 4317 gRPC and 4318 HTTP) |

## Accessing SigNoz

Blueprints cannot declare ports yet, so the service is created without a public URL. Reach it with a port-forward from the service's namespace:

```sh
kubectl port-forward -n <environment namespace> svc/signoz 8080:8080
```

A port added by hand on the Helm service in the console is removed on the next blueprint deploy, because the engine applies the service without one.

## Deleting the service

**Deleting the service hangs until you clear one finalizer.** `helm uninstall` removes the ClickHouse operator in the same pass as the `ClickHouseInstallation` it manages. That resource carries the operator's finalizer, and with the operator gone nothing removes it: the resource stays `Terminating` and the Qovery deletion waits on it until the 30-minute Helm timeout.

Right after starting the deletion, from the service's namespace:

```sh
kubectl -n <environment namespace> patch clickhouseinstallation signoz-clickhouse \
  --type=merge -p '{"metadata":{"finalizers":[]}}'
```

The deletion then completes within a minute. Deleting the whole environment needs the same step: the namespace cannot go away while the resource is stuck.

**The data volumes outlive the service.** ClickHouse (`clickhouse_storage_size`), ZooKeeper (8Gi) and SigNoz (1Gi) volumes belong to StatefulSets, which Kubernetes never deletes with their pods. They stay, and bill, until the environment is deleted or you remove them:

```sh
kubectl -n <environment namespace> delete pvc \
  data-volumeclaim-template-chi-signoz-clickhouse-cluster-0-0-0 \
  data-signoz-zookeeper-0 signoz-db-signoz-0
```

Recreating the service in the same environment before that reuses the old volumes, data and admin included.

## Notes

- **Sizing.** The defaults request about 0.8 vCPU and 4.1Gi of memory with federation on (ClickHouse 500m/1Gi, collector 100m/2.5Gi, SigNoz 100m/256Mi, ZooKeeper 50m/256Mi, operator 30m/96Mi), with memory limits up to about 10.4Gi. Without federation the collector requests 512Mi, for about 2.1Gi in total.
- **Federation cost.** One `/federate` pull of the default selector is tens of MB on a busy cluster; the collector holds it in memory, which is where its memory goes. Narrow `federation_match` or raise `federation_interval` on large clusters.
- **Metric names are Prometheus names** (`container_cpu_usage_seconds_total`, `kube_pod_info`, …), queried with PromQL panels. SigNoz's built-in Infrastructure pages expect the OpenTelemetry names of its own `k8s-infra` agent and stay empty. No dashboard is preloaded: the chart offers no hook to create one.
- **Logs** come only from what applications send over OTLP. Pod logs stay in Qovery's Loki; this blueprint does not install a log agent on the nodes.
- **Retention** is SigNoz's default (traces and logs 15 days, metrics 30 days), changed in Settings → General.
- **Volume settings are creation-time.** Kubernetes forbids changing a bound volume's class, so an update that changes `storage_class` fails with `spec is immutable after creation`. `clickhouse_storage_size` can only grow.
- **Cluster-wide resources** (`allowClusterWideResources: true`): the ClickHouse operator CRDs, installed from the chart's `crds/` once per cluster and shared by every SigNoz install, and a ClusterRole the collector uses to read Kubernetes metadata. The operator itself is pinned to its own namespace (`WATCH_NAMESPACES`), so several SigNoz installs can share a cluster.
- **Fixed resource names**: `signoz`, `signoz-otel-collector`, `signoz-clickhouse`, `signoz-zookeeper`. The chart derives ClickHouse's names from the release, and the operator appends `-deploy-confd-cluster-0-0`: with Qovery's `helm-z<id>-<service>` release names, a service name over 7 characters exceeded Kubernetes' 63-character limit and ClickHouse was never created. Deploy one SigNoz blueprint per environment.
- The rendered values, admin password included, are stored in the Helm service's values override, like every Helm blueprint's inputs.
- Chart pinned to `0.143.0`. SigNoz is still `0.x`, hence the `HELM/signoz/0` directory; it is the official chart, not Bitnami.
