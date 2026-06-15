output "endpoint_ip" {
  description = "Database endpoint IP"
  value       = scaleway_rdb_instance.this.endpoint_ip
}

output "endpoint_port" {
  description = "Database endpoint port"
  value       = scaleway_rdb_instance.this.endpoint_port
}

output "db_name" {
  description = "Database name"
  value       = scaleway_rdb_database.this.name
}
