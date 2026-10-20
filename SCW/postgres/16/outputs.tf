output "endpoint_ip" {
  description = "Database endpoint IP: the public endpoint when publicly_accessible, else the private network endpoint"
  value       = var.publicly_accessible ? try(scaleway_rdb_instance.this.load_balancer[0].ip, null) : scaleway_rdb_instance.this.private_network[0].ip
}

output "endpoint_port" {
  description = "Database endpoint port: the public endpoint when publicly_accessible, else the private network endpoint"
  value       = var.publicly_accessible ? try(scaleway_rdb_instance.this.load_balancer[0].port, null) : scaleway_rdb_instance.this.private_network[0].port
}

output "private_endpoint_ip" {
  description = "Database IP on the cluster's private network"
  value       = scaleway_rdb_instance.this.private_network[0].ip
}

output "private_endpoint_port" {
  description = "Database port on the cluster's private network"
  value       = scaleway_rdb_instance.this.private_network[0].port
}

output "db_name" {
  description = "Database name"
  value       = scaleway_rdb_database.this.name
}

output "db_username" {
  description = "Database username"
  value       = local.db_username
}

output "db_password" {
  description = "Database user password"
  value       = local.db_password
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
