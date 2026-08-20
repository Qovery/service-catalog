output "namespace_id" {
  description = "Full Temporal Cloud namespace id (name.accountId)"
  value       = temporalcloud_namespace.this.id
}

output "namespace_name" {
  description = "Namespace name"
  value       = temporalcloud_namespace.this.name
}

output "grpc_endpoint" {
  description = "gRPC endpoint for API-key clients"
  value       = temporalcloud_namespace.this.endpoints.grpc_address
}

output "mtls_grpc_endpoint" {
  description = "gRPC endpoint for mTLS clients"
  value       = temporalcloud_namespace.this.endpoints.mtls_grpc_address
}
