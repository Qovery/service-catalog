output "cluster_arn" {
  description = "MSK Serverless cluster ARN"
  value       = aws_msk_serverless_cluster.this.arn
}

output "cluster_name" {
  description = "MSK Serverless cluster name"
  value       = aws_msk_serverless_cluster.this.cluster_name
}

output "cluster_uuid" {
  description = "MSK cluster UUID (used in IAM resource ARNs)"
  value       = aws_msk_serverless_cluster.this.cluster_uuid
}

output "bootstrap_brokers_sasl_iam" {
  description = "Bootstrap broker endpoints for SASL/IAM clients (connect target)"
  value       = aws_msk_serverless_cluster.this.bootstrap_brokers_sasl_iam
}
