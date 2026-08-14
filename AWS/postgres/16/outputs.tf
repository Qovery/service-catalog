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

# Per-replica host / port / identifier as maps with numbered keys. Terraform can't name
# output blocks dynamically, so the dynamic part lives in the map keys: exactly one entry
# per replica, in order, empty ({}) when read_replica_count = 0.
output "read_replica_hosts" {
  description = "Map of read replica hostnames keyed read_replica_host_1, read_replica_host_2, ... (empty when read_replica_count = 0)"
  value = {
    for i, r in aws_db_instance.read_replica :
    "read_replica_host_${i + 1}" => r.address
  }
}

output "read_replica_ports" {
  description = "Map of read replica ports keyed read_replica_port_1, read_replica_port_2, ... (empty when read_replica_count = 0)"
  value = {
    for i, r in aws_db_instance.read_replica :
    "read_replica_port_${i + 1}" => r.port
  }
}

output "read_replica_ids" {
  description = "Map of read replica instance identifiers keyed read_replica_identifier_1, read_replica_identifier_2, ... (empty when read_replica_count = 0)"
  value = {
    for i, r in aws_db_instance.read_replica :
    "read_replica_identifier_${i + 1}" => r.identifier
  }
}
