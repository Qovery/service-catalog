output "script_name" {
  description = "Deployed Worker script name"
  value       = cloudflare_workers_script.this.script_name
}

output "script_id" {
  description = "Worker script ID"
  value       = cloudflare_workers_script.this.id
}

output "route_id" {
  description = "Worker route ID (empty when no route is configured)"
  value       = length(cloudflare_workers_route.this) > 0 ? cloudflare_workers_route.this[0].id : ""
}

output "route_pattern" {
  description = "URL pattern the Worker responds on (empty when no route is configured). Requests matching this pattern invoke the Worker."
  value       = length(cloudflare_workers_route.this) > 0 ? var.route_pattern : ""
}
