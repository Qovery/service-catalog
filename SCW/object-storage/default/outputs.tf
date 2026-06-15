output "bucket_name" {
  description = "Bucket name"
  value       = scaleway_object_bucket.this.name
}

output "bucket_endpoint" {
  description = "Bucket endpoint URL"
  value       = scaleway_object_bucket.this.endpoint
}
