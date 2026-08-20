output "environment_id" {
  description = "Confluent environment ID"
  value       = confluent_environment.this.id
}

output "cluster_id" {
  description = "Kafka cluster ID (lkc-...)"
  value       = confluent_kafka_cluster.this.id
}

output "bootstrap_endpoint" {
  description = "Kafka bootstrap endpoint (connect target)"
  value       = confluent_kafka_cluster.this.bootstrap_endpoint
}

output "rest_endpoint" {
  description = "Kafka REST proxy endpoint"
  value       = confluent_kafka_cluster.this.rest_endpoint
}

output "kafka_api_key" {
  description = "Client Kafka API key (SASL username)"
  value       = confluent_api_key.app.id
}

output "kafka_api_secret" {
  description = "Client Kafka API secret (SASL password)"
  value       = confluent_api_key.app.secret
  sensitive   = true
}
