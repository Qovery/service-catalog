output "aws_region" {
  description = "Region the credentials are scoped to call Bedrock in"
  value       = var.aws_region
}

output "account_id" {
  description = "AWS account the Bedrock access was created in"
  value       = data.aws_caller_identity.current.account_id
}

output "policy_arn" {
  description = "ARN of the Bedrock invoke policy, for attaching to further principals"
  value       = aws_iam_policy.invoke.arn
}

output "iam_user_name" {
  description = "IAM user holding the invoke policy (empty when create_iam_user is false)"
  value       = var.create_iam_user ? aws_iam_user.app[0].name : ""
}

output "access_key_id" {
  description = "Access key id for the created IAM user — set it as AWS_ACCESS_KEY_ID (empty when create_iam_user is false)"
  value       = var.create_iam_user ? aws_iam_access_key.app[0].id : ""
  sensitive   = true
}

output "secret_access_key" {
  description = "Secret access key for the created IAM user — set it as AWS_SECRET_ACCESS_KEY (empty when create_iam_user is false)"
  value       = var.create_iam_user ? aws_iam_access_key.app[0].secret : ""
  sensitive   = true
}

output "bedrock_endpoint" {
  description = "Bedrock runtime endpoint for the region, built from the partition DNS suffix so it is correct in GovCloud and China too"
  value       = "https://bedrock-runtime.${var.aws_region}.${data.aws_partition.current.dns_suffix}"
}

output "allowed_model_arns" {
  description = "Model and inference profile ARNs the credentials may invoke"
  value       = concat(local.foundation_model_arns, local.inference_profile_arns)
}
