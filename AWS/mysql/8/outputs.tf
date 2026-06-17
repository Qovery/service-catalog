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
