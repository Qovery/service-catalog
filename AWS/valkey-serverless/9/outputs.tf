output "valkey_identifier" {
  description = "ElastiCache serverless cache name"
  value       = aws_elasticache_serverless_cache.this.name
}

output "valkey_host" {
  description = "Hostname applications connect to (cluster-mode clients only)"
  value       = aws_elasticache_serverless_cache.this.endpoint[0].address
}

output "valkey_port" {
  description = "Port of the primary endpoint, for writes and consistent reads"
  value       = aws_elasticache_serverless_cache.this.endpoint[0].port
}

output "valkey_reader_port" {
  description = "Port of the reader endpoint, on the same hostname"
  value       = aws_elasticache_serverless_cache.this.reader_endpoint[0].port
}

output "valkey_username" {
  description = "Valkey user applications authenticate as"
  value       = aws_elasticache_user.app.user_name
}

output "valkey_password" {
  description = "Password of that user (generated when the input was left empty)"
  value       = local.valkey_password
  sensitive   = true
}

output "valkey_url" {
  description = "Connection URL over TLS, on the primary endpoint"
  value = format(
    "rediss://%s:%s@%s:%s",
    aws_elasticache_user.app.user_name,
    urlencode(local.valkey_password),
    aws_elasticache_serverless_cache.this.endpoint[0].address,
    aws_elasticache_serverless_cache.this.endpoint[0].port,
  )
  sensitive = true
}

output "valkey_arn" {
  description = "Serverless cache ARN"
  value       = aws_elasticache_serverless_cache.this.arn
}

output "valkey_engine_version_actual" {
  description = "Engine version actually running (including the patch AWS chose)"
  value       = aws_elasticache_serverless_cache.this.full_engine_version
}

output "valkey_security_group_id" {
  description = "Security group created for the cache (empty when security_group_ids is set)"
  value       = local.create_security_group ? aws_security_group.cache[0].id : ""
}
