output "bucket_arn" {
  description = "Bucket ARN"
  value       = aws_s3_bucket.this.arn
}

output "bucket_name" {
  description = "Bucket name"
  value       = aws_s3_bucket.this.id
}

output "bucket_region" {
  description = "Bucket region"
  value       = aws_s3_bucket.this.region
}
