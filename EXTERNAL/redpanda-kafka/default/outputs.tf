output "cluster_id" {
  description = "Redpanda serverless cluster ID"
  value       = redpanda_serverless_cluster.this.id
}

output "cluster_api_url" {
  description = "Redpanda cluster dataplane API URL"
  value       = redpanda_serverless_cluster.this.dataplane_api.url
}

output "kafka_seed_brokers" {
  description = "Kafka bootstrap/seed broker endpoints (connect target)"
  value       = redpanda_serverless_cluster.this.kafka_api.seed_brokers
}

output "console_url" {
  description = "Redpanda Console URL"
  value       = redpanda_serverless_cluster.this.console_url
}
