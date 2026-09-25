# Grafana (Helm)

Deploys [Grafana](https://grafana.com/docs/grafana/latest/) 13 with the community `grafana-community/grafana` Helm chart (`13.2.5`), already connected to the observability stack Qovery installs on the cluster:

| Datasource   | Default URL                                                     | Notes |
| ------------ | --------------------------------------------------------------- | ----- |
| Thanos       | `http://thanos-query.prometheus.svc.cluster.local:9090`         | Default datasource. Same PromQL as Prometheus, with long-term history |
| Prometheus   | `http://prometheus-operated.prometheus.svc.cluster.local:9090`  | Recent data only |
| Loki         | `http://loki.logging.svc.cluster.local:3100`                    | Pod logs |
| Alertmanager | `http://alertmanager-operated.prometheus.svc.cluster.local:9093`| Silences and active alerts |

With `kubernetes_dashboards=true` (the default), a **Kubernetes** folder is preloaded with the Kubernetes Views dashboards (global, namespaces, nodes, pods), Node Exporter Full and a Loki logs dashboard. All of them read the metrics kube-prometheus-stack exposes, so they work on any Qovery cluster with metrics enabled.

## Credentials

The admin login is `admin_user` (default `admin`) and the sensitive `admin_password`, both entered in the Qovery console when creating the service. To change the password later, update `admin_password` on the blueprint and redeploy.

## Variables

### Required

| Name             | Type   | Sensitive | Description                                   |
| ---------------- | ------ | --------- | --------------------------------------------- |
| `admin_password` | string | yes       | Grafana admin password, at least 12 characters. |

### Optional

| Name                    | Type   | Default | Description |
| ----------------------- | ------ | ------- | ----------- |
| `admin_user`            | string | `admin` | Grafana admin login. Letters, digits, dots, hyphens, underscores and @ only. |
| `metrics_url`           | string | `http://thanos-query.prometheus.svc.cluster.local:9090` | Leave the default on AWS and Scaleway clusters. On GKE and AKS use `http://thanos-query.qovery.svc.cluster.local:9090`. Any Prometheus-compatible URL works. |
| `prometheus_url`        | string | `http://prometheus-operated.prometheus.svc.cluster.local:9090` | Leave the default on AWS and Scaleway clusters. On GKE and AKS use `http://prometheus-operated.qovery.svc.cluster.local:9090`. |
| `loki_url`              | string | `http://loki.logging.svc.cluster.local:3100` | Leave the default. Set it only to read logs from another Loki. |
| `alertmanager_url`      | string | `http://alertmanager-operated.prometheus.svc.cluster.local:9093` | Leave the default on AWS and Scaleway clusters. On GKE and AKS use `http://alertmanager-operated.qovery.svc.cluster.local:9093`. |
| `kubernetes_dashboards` | string | `true`  | Preload the Kubernetes, Node Exporter and Loki logs dashboards (`true`/`false`). |
| `storage_size`          | string | `10Gi`  | Persistent volume for Grafana's database (users, saved dashboards, alert rules). |
| `memory`                | string | `512Mi` | Memory request and limit for the Grafana container. |

## Outputs

| Name              | Description                                   |
| ----------------- | --------------------------------------------- |
| `grafana_service` | In-cluster Grafana service name (`grafana`, port 80) |

## Accessing Grafana

Blueprints cannot declare ports yet, so the service is created without a public URL. Reach it with a port-forward from the service's namespace:

```sh
kubectl port-forward -n <environment namespace> svc/grafana 3000:80
```

A port added by hand on the Helm service in the console is removed on the next blueprint deploy, because the engine applies the service without one.

## Notes

- **Data sources depend on the cluster.** Thanos, Prometheus, Loki and Alertmanager exist only when metrics and logs are enabled on the Qovery cluster. Without them Grafana starts normally and the datasources report a connection error.
- **GKE and AKS** host the metrics stack in the `qovery` namespace rather than `prometheus`; set `metrics_url`, `prometheus_url` and `alertmanager_url` accordingly. Loki lives in `logging` on every provider.
- **Dashboards are downloaded from grafana.com** by an init container on each start, so the pod needs outbound HTTPS. Set `kubernetes_dashboards=false` on clusters without egress.
- `deploymentStrategy: Recreate`: the data volume is ReadWriteOnce, so a rolling update would leave the new pod waiting on a multi-attach error.
- `fullnameOverride: grafana` gives a stable Service name. Deploy one Grafana blueprint per environment.
- The rendered values, admin password included, are stored in the Helm service's values override, like every Helm blueprint's inputs.
- Chart pinned to `13.2.5` (Grafana `13.2.2`). The `grafana/grafana` chart is deprecated upstream; this is its community successor, not Bitnami.
