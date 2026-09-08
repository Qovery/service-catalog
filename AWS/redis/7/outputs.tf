output "redis_identifier" {
  description = "ElastiCache replication group id (what the AWS console shows as the cluster name)"
  value       = aws_elasticache_replication_group.this.replication_group_id
}

# Same endpoint the native path publishes: the configuration endpoint in cluster mode, the
# primary endpoint otherwise.
output "redis_host" {
  description = "Hostname applications connect to (configuration endpoint in cluster mode, primary endpoint otherwise)"
  value = (
    aws_elasticache_replication_group.this.configuration_endpoint_address != "" ?
    aws_elasticache_replication_group.this.configuration_endpoint_address :
    aws_elasticache_replication_group.this.primary_endpoint_address
  )
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.this.port
}

output "redis_username" {
  description = "Redis user applications authenticate as — always the built-in 'default' user, like native managed Redis"
  value       = "default"
}

output "redis_password" {
  description = "Auth token (generated when the input was left empty)"
  value       = local.redis_password
  sensitive   = true
}

output "redis_url" {
  description = "Connection URL over TLS"
  value = format(
    "rediss://default:%s@%s:%s/0",
    urlencode(local.redis_password),
    aws_elasticache_replication_group.this.configuration_endpoint_address != "" ?
    aws_elasticache_replication_group.this.configuration_endpoint_address :
    aws_elasticache_replication_group.this.primary_endpoint_address,
    aws_elasticache_replication_group.this.port,
  )
  sensitive = true
}

output "redis_primary_endpoint_address" {
  description = "Primary endpoint hostname (empty in cluster mode)"
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "redis_reader_endpoint_address" {
  description = "Reader endpoint hostname, load-balanced across replicas (empty in cluster mode)"
  value       = aws_elasticache_replication_group.this.reader_endpoint_address
}

output "redis_configuration_endpoint_address" {
  description = "Configuration endpoint hostname, for cluster-mode clients (empty when instances_number = 1)"
  value       = aws_elasticache_replication_group.this.configuration_endpoint_address
}

output "redis_arn" {
  description = "Replication group ARN"
  value       = aws_elasticache_replication_group.this.arn
}

output "redis_engine_version_actual" {
  description = "Engine version actually running (may include the patch AWS chose)"
  value       = aws_elasticache_replication_group.this.engine_version_actual
}

output "redis_member_clusters" {
  description = "Cache cluster ids that make up the replication group"
  value       = aws_elasticache_replication_group.this.member_clusters
}
