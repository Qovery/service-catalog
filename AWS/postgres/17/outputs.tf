output "db_identifier" {
  description = "RDS instance identifier (what AWS console shows as the instance name)"
  value       = aws_db_instance.this.identifier
}

output "db_endpoint" {
  description = "RDS instance endpoint (host:port)"
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "RDS instance hostname"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "RDS instance port"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.this.db_name
}

output "db_username" {
  description = "Master username"
  value       = aws_db_instance.this.username
}

output "db_password" {
  description = "Master password"
  value       = var.db_password
  sensitive   = true
}

output "db_resource_id" {
  description = "RDS internal resource ID (used in IAM DB auth ARNs)"
  value       = aws_db_instance.this.resource_id
}

output "db_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.this.arn
}

output "db_engine_version_actual" {
  description = "Engine version actually running (may include the minor AWS chose)"
  value       = aws_db_instance.this.engine_version_actual
}

output "read_replica_identifiers" {
  description = "Read replica instance identifiers (empty when read_replica_count = 0)"
  value       = aws_db_instance.read_replica[*].identifier
}

output "read_replica_endpoints" {
  description = "Read replica endpoints (host:port) — point analytics / read-only clients here"
  value       = aws_db_instance.read_replica[*].endpoint
}

output "read_replica_addresses" {
  description = "Read replica hostnames"
  value       = aws_db_instance.read_replica[*].address
}

# Per-replica host / port / identifier as individual outputs so each surfaces as its own
# env var (READ_REPLICA_HOST_1, ...) instead of a JSON map. Terraform can't name output
# blocks dynamically, so they're pre-declared for up to 5 replicas; slots beyond the
# current read_replica_count return "" (try() falls back when the index doesn't exist).
output "read_replica_host_1" {
  description = "Read replica 1 hostname (empty if not provisioned)"
  value       = try(aws_db_instance.read_replica[0].address, "")
}

output "read_replica_host_2" {
  description = "Read replica 2 hostname (empty if not provisioned)"
  value       = try(aws_db_instance.read_replica[1].address, "")
}

output "read_replica_host_3" {
  description = "Read replica 3 hostname (empty if not provisioned)"
  value       = try(aws_db_instance.read_replica[2].address, "")
}

output "read_replica_host_4" {
  description = "Read replica 4 hostname (empty if not provisioned)"
  value       = try(aws_db_instance.read_replica[3].address, "")
}

output "read_replica_host_5" {
  description = "Read replica 5 hostname (empty if not provisioned)"
  value       = try(aws_db_instance.read_replica[4].address, "")
}

output "read_replica_port_1" {
  description = "Read replica 1 port (empty if not provisioned)"
  value       = try(aws_db_instance.read_replica[0].port, "")
}

output "read_replica_port_2" {
  description = "Read replica 2 port (empty if not provisioned)"
  value       = try(aws_db_instance.read_replica[1].port, "")
}

output "read_replica_port_3" {
  description = "Read replica 3 port (empty if not provisioned)"
  value       = try(aws_db_instance.read_replica[2].port, "")
}

output "read_replica_port_4" {
  description = "Read replica 4 port (empty if not provisioned)"
  value       = try(aws_db_instance.read_replica[3].port, "")
}

output "read_replica_port_5" {
  description = "Read replica 5 port (empty if not provisioned)"
  value       = try(aws_db_instance.read_replica[4].port, "")
}

output "read_replica_identifier_1" {
  description = "Read replica 1 instance identifier (empty if not provisioned)"
  value       = try(aws_db_instance.read_replica[0].identifier, "")
}

output "read_replica_identifier_2" {
  description = "Read replica 2 instance identifier (empty if not provisioned)"
  value       = try(aws_db_instance.read_replica[1].identifier, "")
}

output "read_replica_identifier_3" {
  description = "Read replica 3 instance identifier (empty if not provisioned)"
  value       = try(aws_db_instance.read_replica[2].identifier, "")
}

output "read_replica_identifier_4" {
  description = "Read replica 4 instance identifier (empty if not provisioned)"
  value       = try(aws_db_instance.read_replica[3].identifier, "")
}

output "read_replica_identifier_5" {
  description = "Read replica 5 instance identifier (empty if not provisioned)"
  value       = try(aws_db_instance.read_replica[4].identifier, "")
}
