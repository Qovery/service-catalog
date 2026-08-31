resource "cloudflare_workers_script" "this" {
  account_id         = var.account_id
  script_name        = var.script_name
  content            = var.script_content
  main_module        = var.main_module == "" ? null : var.main_module
  compatibility_date = var.compatibility_date
}

# Optional: route a URL pattern on a zone to this Worker.
resource "cloudflare_workers_route" "this" {
  count = var.route_zone_id != "" && var.route_pattern != "" ? 1 : 0

  zone_id = var.route_zone_id
  pattern = var.route_pattern
  script  = cloudflare_workers_script.this.script_name
}

