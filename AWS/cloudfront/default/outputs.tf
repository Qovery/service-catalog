output "distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.this.arn
}

output "domain_name" {
  description = "CloudFront domain name (the *.cloudfront.net hostname to point traffic at)"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "url" {
  description = "Full HTTPS URL of the distribution (https://<domain_name>)"
  value       = "https://${aws_cloudfront_distribution.this.domain_name}"
}

output "hosted_zone_id" {
  description = "CloudFront hosted zone ID (use for a Route53 alias record)"
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}

output "status" {
  description = "Distribution deployment status"
  value       = aws_cloudfront_distribution.this.status
}

output "etag" {
  description = "Current version identifier (ETag) of the distribution"
  value       = aws_cloudfront_distribution.this.etag
}
