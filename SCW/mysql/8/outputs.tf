output "endpoint_ip" {
  description = "Database endpoint IP (Load Balancer)"
  value       = scaleway_rdb_instance.this.load_balancer[0].ip
}

output "endpoint_port" {
  description = "Database endpoint port (Load Balancer)"
  value       = scaleway_rdb_instance.this.load_balancer[0].port
}

output "db_name" {
  description = "Database name"
  value       = scaleway_rdb_database.this.name
}

output "db_username" {
  description = "Database username"
  value       = var.db_username
}

output "db_password" {
  description = "Database user password"
  value       = var.db_password
  sensitive   = true
}

output "instance_id" {
  description = "Scaleway RDB instance ID"
  value       = scaleway_rdb_instance.this.id
}

output "certificate" {
  description = "TLS CA certificate served by the database (PEM). Use for verify-full SSL."
  value       = scaleway_rdb_instance.this.certificate
  sensitive   = true
}
