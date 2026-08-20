output "service_id" {
  description = "Timescale service ID"
  value       = timescale_service.this.id
}

output "hostname" {
  description = "Service hostname"
  value       = timescale_service.this.hostname
}

output "port" {
  description = "Service port"
  value       = timescale_service.this.port
}

output "username" {
  description = "Master database username"
  value       = timescale_service.this.username
}

output "password" {
  description = "Master database password"
  value       = timescale_service.this.password
  sensitive   = true
}

output "connection_uri" {
  description = "Ready-to-use PostgreSQL connection URI with credentials embedded (database: tsdb, TLS required)"
  value       = "postgres://${timescale_service.this.username}:${timescale_service.this.password}@${timescale_service.this.hostname}:${timescale_service.this.port}/tsdb?sslmode=require"
  sensitive   = true
}
