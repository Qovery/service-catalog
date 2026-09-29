output "broker_id" {
  description = "Amazon MQ broker id"
  value       = aws_mq_broker.this.id
}

output "broker_arn" {
  description = "Amazon MQ broker ARN"
  value       = aws_mq_broker.this.arn
}

output "amqps_endpoint" {
  description = "AMQPS endpoint (amqps://host:5671)"
  value       = local.amqps_endpoint
}

output "host" {
  description = "Broker hostname"
  value       = local.host
}

output "port" {
  description = "AMQPS port (TLS only; Amazon MQ does not expose plain AMQP)"
  value       = 5671
}

output "console_url" {
  description = "RabbitMQ management UI URL"
  value       = aws_mq_broker.this.instances[0].console_url
}

output "username" {
  description = "Admin username the broker was created with"
  value       = terraform_data.admin_username.output
}

output "password" {
  description = "Admin password the broker was created with"
  value       = terraform_data.admin_password.output
  sensitive   = true
}

output "amqp_url" {
  description = "Full connection URL with credentials (amqps://user:password@host:5671)"
  value       = "amqps://${urlencode(terraform_data.admin_username.output)}:${urlencode(terraform_data.admin_password.output)}@${local.host}:5671"
  sensitive   = true
}

output "configuration_id" {
  description = "Amazon MQ configuration id holding the rabbitmq.conf settings"
  value       = aws_mq_configuration.this.id
}
