output "redis_identifier" {
  description = "ElastiCache cluster id (what the AWS console shows as the cluster name)"
  value       = aws_elasticache_cluster.this.cluster_id
}

output "redis_host" {
  description = "Hostname applications connect to"
  value       = local.redis_host
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_cluster.this.port
}

output "redis_url" {
  description = "Connection URL, plaintext with no auth (this shape supports neither)"
  value       = format("redis://%s:%s/0", local.redis_host, aws_elasticache_cluster.this.port)
}

output "redis_arn" {
  description = "Cluster ARN"
  value       = aws_elasticache_cluster.this.arn
}

output "redis_engine_version_actual" {
  description = "Engine version actually running"
  value       = aws_elasticache_cluster.this.engine_version_actual
}

# Same names as the RDS blueprints: Qovery reads db_* outputs to take over a native managed
# database. db_username / db_password echo the legacy connection values: this shape has no auth.
output "db_identifier" {
  description = "Alias of redis_identifier"
  value       = aws_elasticache_cluster.this.cluster_id
}

output "db_address" {
  description = "Alias of redis_host"
  value       = local.redis_host
}

output "db_port" {
  description = "Alias of redis_port"
  value       = aws_elasticache_cluster.this.port
}

output "db_name" {
  description = "Redis logical database applications use — always 0, like native managed Redis"
  value       = "0"
}

output "db_username" {
  description = "Legacy connection login, republished unchanged (not used for auth)"
  value       = var.legacy_connection_username
}

output "db_password" {
  description = "Legacy connection password, republished unchanged (not used for auth)"
  value       = var.legacy_connection_password
  sensitive   = true
}
