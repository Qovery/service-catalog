resource "cloudflare_zone" "this" {
  name = var.zone_name
  type = var.zone_type

  account = {
    id = var.account_id
  }
}

# Optional single DNS record in the zone.
resource "cloudflare_dns_record" "this" {
  count = var.record_name != null ? 1 : 0

  zone_id = cloudflare_zone.this.id
  name    = var.record_name
  type    = var.record_type
  content = var.record_content
  ttl     = var.record_ttl
  proxied = var.record_proxied
}
