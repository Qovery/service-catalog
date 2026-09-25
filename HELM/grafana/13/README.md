# Grafana (Helm)

Deploys [Grafana](https://grafana.com/docs/grafana/latest/) 13 with the community `grafana-community/grafana` Helm chart (`13.2.5`), already connected to the observability stack Qovery installs on the cluster:

| Datasource   | Default URL                                                     | Notes |
| ------------ | --------------------------------------------------------------- | ----- |
| Thanos       | `http://thanos-query.prometheus.svc.cluster.local:9090`         | Default datasource. Same PromQL as Prometheus, with long-term history |
| Prometheus   | `http://prometheus-operated.prometheus.svc.cluster.local:9090`  | Recent data only |
| Loki         | `http://loki.logging.svc.cluster.local:3100`                    | Pod logs |
| Alertmanager | `http://alertmanager-operated.prometheus.svc.cluster.local:9093`| Silences and active alerts |

With `kubernetes_dashboards=true` (the default), a folder (`dashboards_folder`, default **Kubernetes**) is preloaded with the Kubernetes Views dashboards (global, namespaces, nodes, pods), Node Exporter Full and a Loki logs dashboard. All of them read the metrics kube-prometheus-stack exposes, so they work on any Qovery cluster with metrics enabled.

## Credentials

The admin login is `admin_user` (default `admin`) and the sensitive `admin_password`, both entered in the Qovery console when creating the service.

- **Changing `admin_password`** and redeploying resets the admin password: an init container runs `grafana cli admin reset-admin-password` on every start, because Grafana otherwise reads the password only on its very first start.
- **`admin_user` is set once.** Grafana creates the admin account on first start and never renames it; changing the variable later has no effect. Rename the user in Grafana (Administration → Users) instead.

## Variables

### Required

| Name             | Type   | Sensitive | Description                                   |
| ---------------- | ------ | --------- | --------------------------------------------- |
| `admin_password` | string | yes       | Grafana admin password, at least 12 characters. Changing it and redeploying resets the admin password. |

### Optional

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `admin_user` | string | `admin` | Grafana admin login, set once at creation: changing it later has no effect. Letters, digits, dots, hyphens, underscores and @. |
| `root_url` | string | — | Unset = links use the address Grafana is reached on. Set it (e.g. `https://grafana.example.com`) behind a custom domain or path prefix. |
| `anonymous_access` | string | `false` | Let anyone who reaches Grafana browse dashboards without logging in, as Viewer (`true`/`false`). |
| `metrics_url` | string | `http://thanos-query.prometheus.svc.cluster.local:9090` | Leave the default on AWS and Scaleway. On GKE and AKS use `http://thanos-query.qovery.svc.cluster.local:9090`. Any Prometheus-compatible URL works. |
| `prometheus_url` | string | `http://prometheus-operated.prometheus.svc.cluster.local:9090` | Leave the default on AWS and Scaleway. On GKE and AKS use `http://prometheus-operated.qovery.svc.cluster.local:9090`. |
| `loki_url` | string | `http://loki.logging.svc.cluster.local:3100` | Leave the default. Set it only to read logs from another Loki. |
| `alertmanager_url` | string | `http://alertmanager-operated.prometheus.svc.cluster.local:9093` | Leave the default on AWS and Scaleway. On GKE and AKS use `http://alertmanager-operated.qovery.svc.cluster.local:9093`. |
| `default_datasource` | string | `thanos` | Datasource new panels and Explore open on (`thanos`/`prometheus`). |
| `enable_prometheus_datasource` | string | `true` | Add the direct Prometheus datasource next to Thanos. |
| `enable_loki_datasource` | string | `true` | Add the Loki datasource. `false` also drops the Loki logs dashboard. |
| `enable_alertmanager_datasource` | string | `true` | Add the Alertmanager datasource. |
| `scrape_interval` | string | `30s` | Scrape interval of the cluster's Prometheus, used as the minimum query step. Go duration. |
| `loki_max_lines` | number | `5000` | Maximum log lines a Loki query returns (100–50000). |
| `kubernetes_dashboards` | string | `true` | Preload the Kubernetes, Node Exporter and Loki logs dashboards. |
| `dashboards_folder` | string | `Kubernetes` | Folder for the preloaded and extra dashboards. Letters, digits, spaces, hyphens, underscores, max 40 chars. Renaming it moves the dashboards. |
| `extra_dashboards` | string | — | Unset = none. Otherwise grafana.com dashboards as `id:revision`, comma-separated (e.g. `7249:1,14584:2`). They use the default datasource. |
| `plugins` | string | — | Unset = none. Otherwise plugin ids, comma-separated, installed from grafana.com at pod start. |
| `default_theme` | string | `system` | UI theme for users who have not picked one (`system`/`dark`/`light`). |
| `default_timezone` | string | `browser` | Dashboard timezone for users who have not picked one: `browser`, `utc` or an IANA name (`Europe/Paris`). |
| `log_level` | string | `info` | Grafana server log level (`debug`/`info`/`warn`/`error`). |
| `persistence` | string | `true` | Keep Grafana's database on a volume. `false` = users, saved dashboards and alert rules are lost on every restart; switching an existing service to `false` deletes the volume. |
| `storage_size` | string | `10Gi` | Size of the data volume. It can only grow after creation, on a storage class that allows expansion. |
| `storage_class` | string | — | Unset = the cluster's default storage class. Choose it at creation: a volume cannot change class, so changing it later fails the deploy. |
| `cpu_request` | string | `100m` | CPU request for the Grafana container. |
| `memory` | string | `512Mi` | Memory request and limit for the Grafana container. |

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

- **Turning things off removes them.** A datasource switched off is deleted from Grafana (`deleteDatasources`), and a dashboard dropped from the form, or a renamed folder, has its downloaded file removed by the `blueprint-maintenance` init container, so Grafana stops provisioning it. A renamed folder leaves the old one behind, empty: Grafana never deletes folders. That container uses the plain `grafana/grafana:13.2.2` image, pinned to the chart's appVersion.

- **Volume settings are creation-time.** Kubernetes forbids changing a bound volume's class, so an update that changes `storage_class` fails with `spec is immutable after creation`, and Helm's automatic rollback fails for the same reason. Grafana keeps running on the previous release; set `storage_class` back to its original value and redeploy. `storage_size` can only grow.

- **Data sources depend on the cluster.** Thanos, Prometheus, Loki and Alertmanager exist only when metrics and logs are enabled on the Qovery cluster. Without them Grafana starts normally and the datasources report a connection error.
- **GKE and AKS** host the metrics stack in the `qovery` namespace rather than `prometheus`; set `metrics_url`, `prometheus_url` and `alertmanager_url` accordingly. Loki lives in `logging` on every provider.
- **Dashboards and plugins are downloaded from grafana.com** at each pod start, so the pod needs outbound HTTPS. On clusters without egress set `kubernetes_dashboards=false` and leave `extra_dashboards` and `plugins` unset.
- `deploymentStrategy: Recreate`: the data volume is ReadWriteOnce, so a rolling update would leave the new pod waiting on a multi-attach error.
- `fullnameOverride: grafana` gives a stable Service name. Deploy one Grafana blueprint per environment.
- One replica, no replica variable: Grafana's embedded SQLite database sits on a ReadWriteOnce volume, which one pod at a time can mount.
- `extra_dashboards` entries are `id:revision`; the revision must exist on grafana.com (the dashboard page lists them). A dashboard that cannot be downloaded does not block Grafana: it is skipped and logged as invalid, the others load.
- Sign-up is disabled and usage reporting to grafana.com is off.
- The rendered values, admin password included, are stored in the Helm service's values override, like every Helm blueprint's inputs.
- Chart pinned to `13.2.5` (Grafana `13.2.2`). The `grafana/grafana` chart is deprecated upstream; this is its community successor, not Bitnami.
