output "valkey_identifier" {
  description = "ElastiCache replication group id (what the AWS console shows as the cluster name)"
  value       = aws_elasticache_replication_group.this.replication_group_id
}

output "valkey_host" {
  description = "Hostname applications connect to (configuration endpoint in cluster mode, primary endpoint otherwise)"
  value       = local.valkey_host
}

output "valkey_port" {
  description = "Valkey port"
  value       = aws_elasticache_replication_group.this.port
}

output "valkey_username" {
  description = "Valkey user applications authenticate as — always the built-in 'default' user"
  value       = "default"
}

output "valkey_password" {
  description = "Auth token (generated when the input was left empty)"
  value       = local.valkey_password
  sensitive   = true
}

output "valkey_url" {
  description = "Connection URL over TLS"
  value = format(
    "rediss://default:%s@%s:%s/0",
    urlencode(local.valkey_password),
    local.valkey_host,
    aws_elasticache_replication_group.this.port,
  )
  sensitive = true
}

output "valkey_primary_endpoint_address" {
  description = "Primary endpoint hostname (empty in cluster mode)"
  value       = local.primary_endpoint
}

output "valkey_reader_endpoint_address" {
  description = "Reader endpoint hostname, load-balanced across replicas (empty in cluster mode)"
  value       = local.reader_endpoint
}

output "valkey_configuration_endpoint_address" {
  description = "Configuration endpoint hostname, for cluster-mode clients (empty when instances_number = 1)"
  value       = local.configuration_endpoint
}

output "valkey_arn" {
  description = "Replication group ARN"
  value       = aws_elasticache_replication_group.this.arn
}

output "valkey_engine_version_actual" {
  description = "Engine version actually running (may include the patch AWS chose)"
  value       = aws_elasticache_replication_group.this.engine_version_actual
}

output "valkey_member_clusters" {
  description = "Cache cluster ids that make up the replication group"
  value       = aws_elasticache_replication_group.this.member_clusters
}
