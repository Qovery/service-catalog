output "redis_id" {
  description = "Memorystore instance ID"
  value       = google_redis_instance.this.name
}

output "redis_host" {
  description = "Primary endpoint hostname"
  value       = google_redis_instance.this.host
}

output "redis_port" {
  description = "Primary endpoint port"
  value       = google_redis_instance.this.port
}

output "redis_current_location_id" {
  description = "Zone the primary node currently runs in"
  value       = google_redis_instance.this.current_location_id
}

output "redis_auth_string" {
  description = "AUTH string for authenticating (set only when auth_enabled is true)"
  value       = google_redis_instance.this.auth_string
  sensitive   = true
}

output "redis_server_ca_certs" {
  description = "Server CA certificates (PEM) for TLS verification when transit_encryption_mode is SERVER_AUTHENTICATION"
  value       = google_redis_instance.this.server_ca_certs
}

output "redis_read_endpoint" {
  description = "Read replica endpoint hostname (empty when replica_count is 0)"
  value       = var.replica_count > 0 ? google_redis_instance.this.read_endpoint : ""
}

output "redis_read_endpoint_port" {
  description = "Read replica endpoint port (empty when replica_count is 0)"
  # read_endpoint_port is a number that the API returns as 0 (not absent) when there is no
  # read endpoint, so try() never falls back here — gate on replica_count instead and stringify
  # the active port so the output type is consistent ("" vs a string) either way.
  value       = var.replica_count > 0 ? tostring(google_redis_instance.this.read_endpoint_port) : ""
}
