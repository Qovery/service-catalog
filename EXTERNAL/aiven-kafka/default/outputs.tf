output "service_uri" {
  description = "Full Kafka connection URI"
  value       = aiven_kafka.this.service_uri
  sensitive   = true
}

output "host" {
  description = "Kafka broker host (bootstrap)"
  value       = aiven_kafka.this.service_host
}

output "port" {
  description = "Kafka broker port"
  value       = aiven_kafka.this.service_port
}

output "username" {
  description = "SASL username"
  value       = aiven_kafka.this.service_username
}

output "password" {
  description = "SASL password"
  value       = aiven_kafka.this.service_password
  sensitive   = true
}
