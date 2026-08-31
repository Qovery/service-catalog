# Cloudflare Workers

Deploys a [Cloudflare Worker](https://developers.cloudflare.com/workers/) script (`cloudflare_workers_script`) with an optional route (`cloudflare_workers_route`), via the official `cloudflare/cloudflare` Terraform provider (`~> 5.0`).

## Credentials

Authentication is a **Cloudflare API token** supplied as the sensitive `cloudflare_api_token` variable (`credentials.default: env` — there are no cluster credentials to reuse for a third-party provider). The token needs *Workers Scripts: Edit* (and *Workers Routes: Edit* if you set a route).

## Variables

### Required

| Name                   | Type   | Sensitive | Description                                                        |
| ---------------------- | ------ | --------- | ------------------------------------------------------------------ |
| `cloudflare_api_token` | string | yes       | Cloudflare API token with Workers Scripts edit permission          |
| `account_id`           | string |           | Cloudflare account ID that owns the Worker                         |
| `script_name`          | string |           | Worker script name (`^[a-z0-9_-]+$`)                               |

### Optional

| Name                 | Type   | Default        | Description                                                         |
| -------------------- | ------ | -------------- | ------------------------------------------------------------------- |
| `script_content`     | string | hello-world    | Worker script source. Defaults to a service-worker hello-world.     |
| `main_module`        | string |                | Entrypoint module for ES-module Workers (e.g. `worker.js`).         |
| `compatibility_date` | string | `2024-09-23`   | Workers runtime compatibility date (`YYYY-MM-DD`)                   |
| `route_zone_id`      | string |                | Zone ID to attach a route on. Unset = no route.                     |
| `route_pattern`      | string |                | Route pattern (e.g. `example.com/*`). Required when `route_zone_id` set. |

## Outputs

| Name          | Description                                              |
| ------------- | ------------------------------------------------------- |
| `script_name` | Deployed Worker script name                             |
| `script_id`   | Worker script ID                                        |
| `route_id`    | Worker route ID (empty when no route is configured)     |
| `route_pattern` | URL pattern the Worker responds on (empty if no route) |

## Notes

- The default `script_content` uses service-worker syntax (`addEventListener`), so `main_module` is left empty. For ES-module Workers (`export default { fetch }`), set `main_module` (e.g. `worker.js`).
- Provider pinned to `cloudflare/cloudflare ~> 5.0` (v5 renamed the resource from `cloudflare_worker_script` to `cloudflare_workers_script`).
