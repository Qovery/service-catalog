# Cloudflare DNS Zone

Manages a [Cloudflare DNS zone](https://developers.cloudflare.com/dns/zone-setups/) (`cloudflare_zone`) for a domain you already own, with an optional DNS record (`cloudflare_dns_record`), via the official `cloudflare/cloudflare` provider (`~> 5.0`).

> **This manages a DNS zone; it does not register domains.** The domain must already be registered (anywhere). For a `full` zone, point your registrar's name servers at the `name_servers` output. Cloudflare Registrar cannot purchase new domains via Terraform.

## Credentials

A **Cloudflare API token** supplied as the sensitive `cloudflare_api_token` variable (`credentials.default: env`). Needs *Zone: Edit* plus account-level permission to create zones.

## Variables

### Required

| Name                   | Type   | Sensitive | Description                                         |
| ---------------------- | ------ | --------- | --------------------------------------------------- |
| `cloudflare_api_token` | string | yes       | Cloudflare API token with Zone edit permission      |
| `account_id`           | string |           | Cloudflare account ID that will own the zone        |
| `zone_name`            | string |           | Domain to manage (e.g. `example.com`)               |

### Optional

| Name             | Type   | Default | Description                                                       |
| ---------------- | ------ | ------- | ----------------------------------------------------------------- |
| `zone_type`      | string | `full`  | `full` (Cloudflare hosts DNS) or `partial` (CNAME/partner setup)  |
| `record_name`    | string | `""`    | Optional DNS record name (`www`, `@`, or a host). Empty = none.   |
| `record_type`    | string | `A`     | `A`, `AAAA`, `CNAME`, `TXT`, `MX`, `NS`                            |
| `record_content` | string | `""`    | Record value. Required when `record_name` is set.                 |
| `record_ttl`     | number | `1`     | TTL seconds (`1` = automatic; must be `1` when proxied)           |
| `record_proxied` | bool   | `false` | Proxy through Cloudflare (orange cloud). A/AAAA/CNAME only.        |

## Outputs

| Name               | Description                                                        |
| ------------------ | ------------------------------------------------------------------ |
| `zone_id`          | Cloudflare zone ID                                                 |
| `zone_name`        | Managed domain name                                                |
| `name_servers`     | Cloudflare name servers to set at your registrar (full zones only) |
| `status`           | Zone activation status                                             |
| `verification_key` | TXT verification value for partial (CNAME) setups                  |
| `record_id`        | Created DNS record ID (empty when no record is configured)         |
